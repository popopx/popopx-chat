//
//  MonetizationTests.swift
//  Tests iOS
//
//  Unit tests for red packet encoding, claim tracking, token formatting,
//  and compute store credit/debit logic.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import XCTest
@testable import POPOPX

final class MonetizationTests: XCTestCase {

    // MARK: - Red packet encoding roundtrip

    func testRedPacketEncodeDecodeRoundtrip() {
        let packet = RedPacketInfo(id: "abc-123", amount: 50, message: "Happy New Year", from: "Alice")
        let encoded = encodeRedPacketMessage(packet)

        XCTAssertTrue(encoded.hasPrefix(SX_RP_PREFIX))

        let decoded = parseRedPacketMessage(encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.id, "abc-123")
        XCTAssertEqual(decoded?.amount, 50)
        XCTAssertEqual(decoded?.message, "Happy New Year")
        XCTAssertEqual(decoded?.from, "Alice")
    }

    func testRedPacketDecodeWithEmptyMessage() {
        let packet = RedPacketInfo(id: "pkt-2", amount: 10, message: "", from: "Bob")
        let encoded = encodeRedPacketMessage(packet)
        let decoded = parseRedPacketMessage(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.message, "")
        XCTAssertEqual(decoded?.amount, 10)
    }

    func testRedPacketDecodeWithFractionalAmount() {
        let packet = RedPacketInfo(id: "pkt-3", amount: 12.5, message: "Thanks", from: "Carol")
        let encoded = encodeRedPacketMessage(packet)
        let decoded = parseRedPacketMessage(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.amount, 12.5, accuracy: 0.001)
    }

    func testParseRedPacketFromNonRedPacketMessage() {
        let decoded = parseRedPacketMessage("Hello, world!")
        XCTAssertNil(decoded)
    }

    func testParseRedPacketFromLocationMessage() {
        let loc = SharedLocation(lat: 51.5, lng: -0.12, name: "London")
        let encoded = encodeLocationMessage(loc)
        let decoded = parseRedPacketMessage(encoded)
        XCTAssertNil(decoded)
    }

    // MARK: - Shared location encoding roundtrip

    func testLocationEncodeDecodeRoundtrip() {
        let loc = SharedLocation(lat: 40.7128, lng: -74.006, name: "New York")
        let encoded = encodeLocationMessage(loc)

        XCTAssertTrue(encoded.hasPrefix(SX_LOC_PREFIX))

        let decoded = parseLocationMessage(encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.lat, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(decoded?.lng, -74.006, accuracy: 0.0001)
        XCTAssertEqual(decoded?.name, "New York")
    }

    // MARK: - Token formatting

    func testFormatTokensWholeNumber() {
        XCTAssertEqual(formatTokens(100), "100")
        XCTAssertEqual(formatTokens(0), "0")
        XCTAssertEqual(formatTokens(1), "1")
        XCTAssertEqual(formatTokens(4500), "4500")
    }

    func testFormatTokensFractional() {
        XCTAssertEqual(formatTokens(12.5), "12.50")
        XCTAssertEqual(formatTokens(0.01), "0.01")
        XCTAssertEqual(formatTokens(99.99), "99.99")
    }

    // MARK: - EntitlementStore claim tracking

    func testClaimTracking() {
        let store = EntitlementStore.shared
        let testId = "test-packet-\(UUID().uuidString)"

        XCTAssertFalse(store.isClaimed(testId))

        store.markClaimed(testId)
        XCTAssertTrue(store.isClaimed(testId))
    }

    func testClaimTrackingIdempotent() {
        let store = EntitlementStore.shared
        let testId = "test-idempotent-\(UUID().uuidString)"

        store.markClaimed(testId)
        store.markClaimed(testId)

        XCTAssertTrue(store.isClaimed(testId))

        let packets = store.claimedPackets.filter { $0 == testId }
        XCTAssertEqual(packets.count, 1)
    }

    func testClaimTrackingMultiplePackets() {
        let store = EntitlementStore.shared
        let id1 = "multi-1-\(UUID().uuidString)"
        let id2 = "multi-2-\(UUID().uuidString)"

        store.markClaimed(id1)
        store.markClaimed(id2)

        XCTAssertTrue(store.isClaimed(id1))
        XCTAssertTrue(store.isClaimed(id2))
    }

    // MARK: - Device ID persistence

    func testDeviceIdIsPersistent() {
        let store = EntitlementStore.shared
        let first = store.deviceId
        let second = store.deviceId
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
    }

    func testDeviceIdIsValidUUID() {
        let store = EntitlementStore.shared
        let id = store.deviceId
        XCTAssertNotNil(UUID(uuidString: id), "Device ID should be a valid UUID: \(id)")
    }

    // MARK: - ComputeStore credit/debit

    func testCreditIncreasesBalance() {
        let store = ComputeStore.shared
        let before = store.balance
        store.credit(50)
        XCTAssertEqual(store.balance, before + 50, accuracy: 0.001)
        store.debit(50)
    }

    func testDebitDecreasesBalance() {
        let store = ComputeStore.shared
        store.credit(100)
        let before = store.balance
        let result = store.debit(30)
        XCTAssertTrue(result)
        XCTAssertEqual(store.balance, before - 30, accuracy: 0.001)
        store.debit(70)
    }

    func testDebitFailsWhenInsufficient() {
        let store = ComputeStore.shared
        let balance = store.balance
        let result = store.debit(balance + 999)
        XCTAssertFalse(result)
        XCTAssertEqual(store.balance, balance, accuracy: 0.001)
    }

    func testDebitFailsForZeroAmount() {
        let store = ComputeStore.shared
        let result = store.debit(0)
        XCTAssertFalse(result)
    }

    func testDebitFailsForNegativeAmount() {
        let store = ComputeStore.shared
        let result = store.debit(-10)
        XCTAssertFalse(result)
    }

    // MARK: - Red packet send/claim flow integration

    func testRedPacketSendDebitsBalance() {
        let store = ComputeStore.shared
        store.credit(100)
        let balanceBefore = store.balance

        let packet = RedPacketInfo(id: UUID().uuidString, amount: 25, message: "Test", from: "Tester")
        let debited = store.debit(packet.amount)

        XCTAssertTrue(debited)
        XCTAssertEqual(store.balance, balanceBefore - 25, accuracy: 0.001)

        store.debit(75)
    }

    func testRedPacketClaimCreditsBalance() {
        let store = ComputeStore.shared
        let balanceBefore = store.balance
        let packet = RedPacketInfo(id: "claim-test-\(UUID().uuidString)", amount: 15, message: "Gift", from: "Sender")

        store.credit(packet.amount)
        EntitlementStore.shared.markClaimed(packet.id)

        XCTAssertEqual(store.balance, balanceBefore + 15, accuracy: 0.001)
        XCTAssertTrue(EntitlementStore.shared.isClaimed(packet.id))

        store.debit(15)
    }

    // MARK: - Mock products

    func testMockProductsHaveStoreKitIds() {
        for product in ComputeStore.mockProducts {
            XCTAssertFalse(product.storeKitProductId.isEmpty, "\(product.title) missing StoreKit product ID")
            XCTAssertTrue(ALL_TOKEN_PRODUCT_IDS.contains(product.storeKitProductId),
                          "\(product.title) StoreKit ID not in ALL_TOKEN_PRODUCT_IDS")
        }
    }

    func testMockProductsHavePositiveTokens() {
        for product in ComputeStore.mockProducts {
            XCTAssertGreaterThan(product.tokenAmount, 0, "\(product.title) should have positive tokens")
        }
    }

    // MARK: - UserTier

    func testUserTierComparable() {
        XCTAssertTrue(UserTier.free < UserTier.basic)
        XCTAssertTrue(UserTier.basic < UserTier.premium)
        XCTAssertTrue(UserTier.free < UserTier.premium)
        XCTAssertFalse(UserTier.premium < UserTier.basic)
        XCTAssertFalse(UserTier.basic < UserTier.free)
    }

    func testUserTierDisplayName() {
        XCTAssertEqual(UserTier.free.displayName, "Free")
        XCTAssertEqual(UserTier.basic.displayName, "Standard")
        XCTAssertEqual(UserTier.premium.displayName, "Premium")
    }

    func testUserTierCodable() throws {
        let tier = UserTier.premium
        let encoded = try JSONEncoder().encode(tier)
        let decoded = try JSONDecoder().decode(UserTier.self, from: encoded)
        XCTAssertEqual(decoded, tier)
    }

    // MARK: - BillingPeriod

    func testBillingPeriodAllCases() {
        XCTAssertEqual(BillingPeriod.allCases.count, 2)
        XCTAssertTrue(BillingPeriod.allCases.contains(.monthly))
        XCTAssertTrue(BillingPeriod.allCases.contains(.yearly))
    }

    func testBillingPeriodLabels() {
        XCTAssertEqual(BillingPeriod.monthly.label, "Monthly")
        XCTAssertEqual(BillingPeriod.yearly.label, "Yearly")
    }

    func testBillingPeriodStoreKitPeriod() {
        XCTAssertEqual(BillingPeriod.monthly.storeKitPeriod, "P1M")
        XCTAssertEqual(BillingPeriod.yearly.storeKitPeriod, "P1Y")
    }

    // MARK: - SubscriptionError

    func testSubscriptionErrorDescriptions() {
        let networkError = SubscriptionError.networkError("timeout")
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("timeout"))

        let verificationFailed = SubscriptionError.verificationFailed
        XCTAssertNotNil(verificationFailed.errorDescription)

        let serverRejected = SubscriptionError.serverRejected("invalid JWS")
        XCTAssertTrue(serverRejected.errorDescription!.contains("invalid JWS"))

        let pending = SubscriptionError.pendingApproval
        XCTAssertNotNil(pending.errorDescription)

        let revoked = SubscriptionError.revoked(reason: "refund")
        XCTAssertTrue(revoked.errorDescription!.contains("refund"))
    }

    func testSubscriptionErrorEquatable() {
        XCTAssertEqual(SubscriptionError.verificationFailed, SubscriptionError.verificationFailed)
        XCTAssertEqual(
            SubscriptionError.networkError("timeout"),
            SubscriptionError.networkError("timeout")
        )
        XCTAssertNotEqual(
            SubscriptionError.networkError("timeout"),
            SubscriptionError.networkError("refused")
        )
        XCTAssertNotEqual(SubscriptionError.verificationFailed, SubscriptionError.pendingApproval)
    }

    // MARK: - SubscriptionInfo

    func testSubscriptionInfoEquatable() {
        let date = Date()
        let info1 = SubscriptionInfo(tier: .premium, expiresAt: date, autoRenew: true, environment: "Sandbox", productId: "test")
        let info2 = SubscriptionInfo(tier: .premium, expiresAt: date, autoRenew: true, environment: "Sandbox", productId: "test")
        XCTAssertEqual(info1, info2)

        let info3 = SubscriptionInfo(tier: .basic, expiresAt: date, autoRenew: true, environment: "Sandbox", productId: "test")
        XCTAssertNotEqual(info1, info3)
    }

    // MARK: - Product ID consistency

    func testAllSubscriptionProductIdsContainsFourProducts() {
        XCTAssertEqual(ALL_SUBSCRIPTION_PRODUCT_IDS.count, 4)
        XCTAssertTrue(ALL_SUBSCRIPTION_PRODUCT_IDS.contains(PRODUCT_BASIC_MONTHLY))
        XCTAssertTrue(ALL_SUBSCRIPTION_PRODUCT_IDS.contains(PRODUCT_BASIC_YEARLY))
        XCTAssertTrue(ALL_SUBSCRIPTION_PRODUCT_IDS.contains(PRODUCT_PREMIUM_MONTHLY))
        XCTAssertTrue(ALL_SUBSCRIPTION_PRODUCT_IDS.contains(PRODUCT_PREMIUM_YEARLY))
    }

    func testSubscriptionProductIdsAreUnique() {
        let set = Set(ALL_SUBSCRIPTION_PRODUCT_IDS)
        XCTAssertEqual(set.count, ALL_SUBSCRIPTION_PRODUCT_IDS.count, "Subscription product IDs must be unique")
    }

    func testTokenProductIdsAreUnique() {
        let set = Set(ALL_TOKEN_PRODUCT_IDS)
        XCTAssertEqual(set.count, ALL_TOKEN_PRODUCT_IDS.count, "Token product IDs must be unique")
    }

    func testSubscriptionAndTokenProductIdsDoNotOverlap() {
        let subSet = Set(ALL_SUBSCRIPTION_PRODUCT_IDS)
        let tokenSet = Set(ALL_TOKEN_PRODUCT_IDS)
        XCTAssertTrue(subSet.isDisjoint(with: tokenSet), "Subscription and token product IDs must not overlap")
    }

    func testConstantsMatchMonetizationProductIds() {
        XCTAssertEqual(Constants.subscriptionProductBasicMonthly, PRODUCT_BASIC_MONTHLY)
        XCTAssertEqual(Constants.subscriptionProductBasicYearly, PRODUCT_BASIC_YEARLY)
        XCTAssertEqual(Constants.subscriptionProductPremiumMonthly, PRODUCT_PREMIUM_MONTHLY)
        XCTAssertEqual(Constants.subscriptionProductPremiumYearly, PRODUCT_PREMIUM_YEARLY)
    }

    // MARK: - EntitlementStore new properties

    func testAutoRenewPersistence() {
        let store = EntitlementStore.shared
        let original = store.autoRenew

        store.autoRenew = true
        XCTAssertTrue(store.autoRenew)

        store.autoRenew = false
        XCTAssertFalse(store.autoRenew)

        store.autoRenew = original
    }

    func testSubscriptionEnvironmentPersistence() {
        let store = EntitlementStore.shared
        let original = store.subscriptionEnvironment

        store.subscriptionEnvironment = "Production"
        XCTAssertEqual(store.subscriptionEnvironment, "Production")

        store.subscriptionEnvironment = "Sandbox"
        XCTAssertEqual(store.subscriptionEnvironment, "Sandbox")

        store.subscriptionEnvironment = original
    }

    // MARK: - SubscriptionManager derived state

    func testSubscriptionManagerHasActiveSubscriptionWhenFree() {
        let sub = SubscriptionManager.shared
        if sub.purchasedTier == .free {
            XCTAssertFalse(sub.hasActiveSubscription)
        }
    }

    func testTrialDaysLeftIsNonNegative() {
        let sub = SubscriptionManager.shared
        XCTAssertGreaterThanOrEqual(sub.trialDaysLeft, 0)
    }

    func testDaysUntilExpirationIsNonNegative() {
        let sub = SubscriptionManager.shared
        if let days = sub.daysUntilExpiration {
            XCTAssertGreaterThanOrEqual(days, 0)
        }
    }
}
