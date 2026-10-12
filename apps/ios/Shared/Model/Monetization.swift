//
//  Monetization.swift
//  POPOPX (iOS)
//
//  Complete StoreKit 2 payment system:
//  - Auto-renewable subscriptions (monthly + yearly, Basic + Premium)
//  - Server-side receipt validation via JWS
//  - Consumable token packs with backend verification
//  - 3-day free trial, refund/revocation handling
//  - Subscription management via iOS system sheet
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import StoreKit
import SwiftUI
import POPOPXSwitch
import os

// MARK: - Persistence keys (shared app group)

let MON_KEY_TRIAL_START = "monTrialStart"
let MON_KEY_TIER = "monUserTier"
let MON_KEY_SUBSCRIPTION_EXPIRY = "monSubscriptionExpiry"
let MON_KEY_TOKEN_BALANCE = "monTokenBalance"
let MON_KEY_STORE_BASE_URL = "monComputeStoreBaseURL"
let MON_KEY_CLAIMED_PACKETS = "monClaimedPackets"
let MON_KEY_DEVICE_ID = "device_id"
let MON_KEY_AUTO_RENEW = "monAutoRenew"
let MON_KEY_SUBSCRIPTION_ENV = "monSubscriptionEnv"

let MON_RENEWAL_REMINDER_DAYS = 10

// MARK: - Product identifiers (must match App Store Connect)

let PRODUCT_BASIC_MONTHLY = "com.popopxchat.popopx.basic.monthly"     // $9.99/month
let PRODUCT_BASIC_YEARLY = "com.popopxchat.popopx.basic.yearly"       // $99/year
let PRODUCT_PREMIUM_MONTHLY = "com.popopxchat.popopx.premium.monthly" // $29.99/month
let PRODUCT_PREMIUM_YEARLY = "com.popopxchat.popopx.premium.yearly"   // $299/year

let ALL_SUBSCRIPTION_PRODUCT_IDS = [
    PRODUCT_BASIC_MONTHLY, PRODUCT_BASIC_YEARLY,
    PRODUCT_PREMIUM_MONTHLY, PRODUCT_PREMIUM_YEARLY
]

let PRODUCT_TOKENS_STARTER = "com.popopxchat.popopx.tokens.starter"    // $9.99 — 100 tokens
let PRODUCT_TOKENS_PLUS = "com.popopxchat.popopx.tokens.plus"          // $29.99 — 350 tokens
let PRODUCT_TOKENS_PRO = "com.popopxchat.popopx.tokens.pro"            // $99.99 — 1300 tokens
let PRODUCT_TOKENS_QUANTUM = "com.popopxchat.popopx.tokens.quantum"   // $299.99 — 4500 tokens

let ALL_TOKEN_PRODUCT_IDS = [PRODUCT_TOKENS_STARTER, PRODUCT_TOKENS_PLUS, PRODUCT_TOKENS_PRO, PRODUCT_TOKENS_QUANTUM]

let MON_TRIAL_SECONDS: TimeInterval = 3 * 24 * 60 * 60

// MARK: - Types

enum UserTier: String, Codable, Comparable {
    case free
    case basic
    case premium

    static func < (lhs: UserTier, rhs: UserTier) -> Bool {
        let order: [UserTier] = [.free, .basic, .premium]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }

    var displayName: String {
        switch self {
        case .free: return NSLocalizedString("Free", comment: "")
        case .basic: return NSLocalizedString("Standard", comment: "")
        case .premium: return NSLocalizedString("Premium", comment: "")
        }
    }
}

enum BillingPeriod: String, CaseIterable {
    case monthly
    case yearly

    var label: String {
        switch self {
        case .monthly: return NSLocalizedString("Monthly", comment: "")
        case .yearly: return NSLocalizedString("Yearly", comment: "")
        }
    }

    var storeKitPeriod: String {
        switch self {
        case .monthly: return "P1M"
        case .yearly: return "P1Y"
        }
    }
}

enum SubscriptionError: LocalizedError, Equatable {
    case networkError(String)
    case verificationFailed
    case serverVerificationPending
    case serverRejected(String)
    case productNotAvailable
    case pendingApproval
    case revoked(reason: String)

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return String(format: NSLocalizedString("Network error: %@", comment: ""), msg)
        case .verificationFailed: return NSLocalizedString("Purchase could not be verified.", comment: "")
        case .serverVerificationPending: return NSLocalizedString("Purchase received but server verification is pending. It will be confirmed automatically.", comment: "")
        case .serverRejected(let msg): return String(format: NSLocalizedString("Server rejected: %@", comment: ""), msg)
        case .productNotAvailable: return NSLocalizedString("This product is not available.", comment: "")
        case .pendingApproval: return NSLocalizedString("Purchase is pending approval.", comment: "")
        case .revoked(let reason): return String(format: NSLocalizedString("Subscription revoked: %@", comment: ""), reason)
        }
    }
}

struct SubscriptionInfo: Equatable {
    let tier: UserTier
    let expiresAt: Date
    let autoRenew: Bool
    let environment: String
    let productId: String
}

// MARK: - Local entitlement persistence
// monUserTier and monTokenBalance are cached in UserDefaults for UI display.
// The authoritative source is StoreKit Transaction.currentEntitlements, checked in
// validateEntitlement() and updateEntitlements() on every refresh, purchase, and
// app activation. If the cached tier exceeds what StoreKit confirms, it is downgraded.

final class EntitlementStore {
    static let shared = EntitlementStore()
    private let defaults = groupDefaults
    // POPOPX: Cache trial start to avoid KeyChain reads on every access
    private var cachedTrialStart: Date?

    func startTrialIfNeeded() async {
        // Don't start client-side trial if user has already redeemed a StoreKit introductory offer
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if #available(iOS 17.2, *) {
                if transaction.offer?.type == .introductory {
                    return
                }
            } else if transaction.offerType == .introductory {
                return
            }
        }
        if kcTrialStart.get() == nil {
            _ = kcTrialStart.set(String(Date().timeIntervalSince1970))
            // Invalidate cache so next read picks up the new value
            cachedTrialStart = nil
        }
    }

    var trialStart: Date {
        // POPOPX: Return cached value to avoid KeyChain read on every access
        if let cached = cachedTrialStart {
            return cached
        }
        if let stored = kcTrialStart.get(), let ts = Double(stored) {
            let date = Date(timeIntervalSince1970: ts)
            cachedTrialStart = date
            return date
        }
        return Date()
    }
    var trialEnd: Date { trialStart.addingTimeInterval(MON_TRIAL_SECONDS) }

    // POPOPX: Reset trial and clear cache (called from compliance settings)
    func resetTrial() {
        _ = kcTrialStart.remove()
        cachedTrialStart = nil
    }

    func setTier(_ tier: UserTier) {
        defaults.set(tier.rawValue, forKey: MON_KEY_TIER)
    }
    var storedTier: UserTier {
        guard let raw = defaults.string(forKey: MON_KEY_TIER), let t = UserTier(rawValue: raw) else { return .free }
        return t
    }

    var subscriptionExpiryDate: Date? {
        get {
            guard let timestamp = defaults.object(forKey: MON_KEY_SUBSCRIPTION_EXPIRY) as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: MON_KEY_SUBSCRIPTION_EXPIRY)
            } else {
                defaults.removeObject(forKey: MON_KEY_SUBSCRIPTION_EXPIRY)
            }
        }
    }

    var tokenBalance: Int {
        get { defaults.integer(forKey: MON_KEY_TOKEN_BALANCE) }
        set { defaults.set(newValue, forKey: MON_KEY_TOKEN_BALANCE) }
    }

    private static let allowedStoreHosts: Set<String> = [
        "api.popopxchat.com"
    ]

    /// Validates that a store URL uses HTTPS, has an allowed host, and is well-formed.
    private static func isValidStoreURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "https",
              let host = url.host,
              !host.isEmpty,
              allowedStoreHosts.contains(host) else {
            return false
        }
        return true
    }

    private static let defaultStoreBaseURL = "https://api.popopxchat.com"

    var storeBaseURL: String {
        get {
            let stored = defaults.string(forKey: MON_KEY_STORE_BASE_URL) ?? Self.defaultStoreBaseURL
            return Self.isValidStoreURL(stored) ? stored : Self.defaultStoreBaseURL
        }
        set {
            guard Self.isValidStoreURL(newValue) else { return }
            defaults.set(newValue, forKey: MON_KEY_STORE_BASE_URL)
        }
    }

    var claimedPackets: Set<String> {
        get { Set(defaults.stringArray(forKey: MON_KEY_CLAIMED_PACKETS) ?? []) }
        set { defaults.set(Array(newValue), forKey: MON_KEY_CLAIMED_PACKETS) }
    }
    func markClaimed(_ id: String) { var s = claimedPackets; s.insert(id); claimedPackets = s }
    func isClaimed(_ id: String) -> Bool { claimedPackets.contains(id) }

    private static let deviceIdLock = NSLock()

    var deviceId: String {
        if let existing = defaults.string(forKey: MON_KEY_DEVICE_ID), !existing.isEmpty {
            return existing
        }
        return Self.deviceIdLock.withLock {
            if let existing = defaults.string(forKey: MON_KEY_DEVICE_ID), !existing.isEmpty {
                return existing
            }
            let newId = UUID().uuidString
            defaults.set(newId, forKey: MON_KEY_DEVICE_ID)
            return newId
        }
    }

    var autoRenew: Bool {
        get { defaults.bool(forKey: MON_KEY_AUTO_RENEW) }
        set { defaults.set(newValue, forKey: MON_KEY_AUTO_RENEW) }
    }

    var subscriptionEnvironment: String {
        get { defaults.string(forKey: MON_KEY_SUBSCRIPTION_ENV) ?? "Sandbox" }
        set { defaults.set(newValue, forKey: MON_KEY_SUBSCRIPTION_ENV) }
    }
}

// MARK: - Subscription manager (StoreKit 2)

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var purchasedTier: UserTier = EntitlementStore.shared.storedTier
    @Published var subscriptionExpirationDate: Date? = EntitlementStore.shared.subscriptionExpiryDate
    @Published var loading = false
    @Published var lastSubscriptionError: SubscriptionError?
    @Published var subscriptionInfo: SubscriptionInfo?
    @Published var subscriptionRevoked: Bool = false
    @Published var revocationMessage: String?
    @Published var purchaseSuccess: Bool = false
    @Published var purchasedTierName: String = ""

    private var updatesTask: Task<Void, Never>?
    private var lastValidationDate: Date = .distantPast
    private static let validationInterval: TimeInterval = 3600

    func ensureValidated() {
        guard Date().timeIntervalSince(lastValidationDate) > Self.validationInterval else { return }
        lastValidationDate = Date()
        Task { await validateEntitlement() }
    }

    private var backendBaseURL: URL? {
        let s = EntitlementStore.shared.storeBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : URL(string: s)
    }

    private func addDeviceAuth(_ request: inout URLRequest) {
        let deviceId = EntitlementStore.shared.deviceId
        request.addValue(deviceId, forHTTPHeaderField: "X-Device-ID")
    }

    init() {
        Task { await EntitlementStore.shared.startTrialIfNeeded() }
        updatesTask = listenForTransactions()
        Task { await refresh() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: Derived state

    var trialActive: Bool { Date() < EntitlementStore.shared.trialEnd }

    var trialDaysLeft: Int {
        max(0, Int(ceil(EntitlementStore.shared.trialEnd.timeIntervalSinceNow / 86_400)))
    }

    var effectiveTier: UserTier {
        ensureValidated()
        if purchasedTier != .free { return purchasedTier }
        return trialActive ? .premium : .free
    }

    var isLocked: Bool { purchasedTier == .free && !trialActive }

    var canAddSMPServer: Bool { effectiveTier >= .basic }

    var daysUntilExpiration: Int? {
        guard let expiry = subscriptionExpirationDate else { return nil }
        return max(0, Int(ceil(expiry.timeIntervalSinceNow / 86_400)))
    }

    var needsRenewalReminder: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days <= MON_RENEWAL_REMINDER_DAYS && days >= 0
    }

    var showTrialReminder: Bool { trialActive && purchasedTier == .free }

    var hasActiveSubscription: Bool {
        purchasedTier != .free && (subscriptionExpirationDate ?? .distantPast) > Date()
    }

    enum TrialUrgency {
        case low, medium, high, critical

        func message(days: Int) -> String {
            switch self {
            case .low: return NSLocalizedString("Your free trial is active", comment: "")
            case .medium: return String(format: NSLocalizedString("%d days left in your trial", comment: ""), days)
            case .high: return NSLocalizedString("Trial ends tomorrow — subscribe now", comment: "")
            case .critical: return NSLocalizedString("Trial ends today — subscribe to keep access", comment: "")
            }
        }
    }

    var trialUrgency: TrialUrgency {
        switch trialDaysLeft {
        case 0: return .critical
        case 1: return .high
        case 2...3: return .medium
        default: return .low
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func products(for period: BillingPeriod) -> [Product] {
        let ids: [String]
        switch period {
        case .monthly: ids = [PRODUCT_BASIC_MONTHLY, PRODUCT_PREMIUM_MONTHLY]
        case .yearly: ids = [PRODUCT_BASIC_YEARLY, PRODUCT_PREMIUM_YEARLY]
        }
        return ids.compactMap { product($0) }
    }

    // MARK: StoreKit

    func refresh() async {
        await loadProducts()
        await validateEntitlement()
        await updateEntitlements()
        await refreshSubscriptionStatus()
    }

    /// Validates the stored entitlement tier against StoreKit's
    /// Transaction.currentEntitlements, which is the authoritative source.
    /// If the locally stored tier (from UserDefaults) is higher than what
    /// StoreKit confirms, it is downgraded to prevent spoofing.
    func validateEntitlement() async {
        var storeKitTier: UserTier = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            let productTier = tierForProductId(t.productID)
            if productTier > storeKitTier {
                storeKitTier = productTier
            }
        }
        let storedTier = EntitlementStore.shared.storedTier
        if storedTier != storeKitTier {
            EntitlementStore.shared.setTier(storeKitTier)
            purchasedTier = storeKitTier
        }
        lastValidationDate = Date()
    }

    func loadProducts() async {
        loading = true
        lastSubscriptionError = nil
        defer { loading = false }
        do {
            let loaded = try await Product.products(for: Set(ALL_SUBSCRIPTION_PRODUCT_IDS))
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            lastSubscriptionError = .networkError(error.localizedDescription)
        }
    }

    func updateEntitlements() async {
        var tier: UserTier = .free
        var expiryDate: Date? = nil
        var info: SubscriptionInfo? = nil

        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }

            let productTier = tierForProductId(t.productID)
            guard productTier != .free else { continue }

            if productTier > tier {
                tier = productTier
                expiryDate = t.expirationDate
                info = SubscriptionInfo(
                    tier: productTier,
                    expiresAt: t.expirationDate ?? Date.distantFuture,
                    autoRenew: EntitlementStore.shared.autoRenew,
                    environment: EntitlementStore.shared.subscriptionEnvironment,
                    productId: t.productID
                )
            }
        }

        purchasedTier = tier
        subscriptionExpirationDate = expiryDate
        subscriptionInfo = info
        EntitlementStore.shared.setTier(tier)
        EntitlementStore.shared.subscriptionExpiryDate = expiryDate
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        loading = true
        lastSubscriptionError = nil
        purchaseSuccess = false
        defer { loading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    let verified = await submitSubscriptionVerification(verification)
                    if verified {
                        await transaction.finish()
                        await updateEntitlements()
                        let tier = tierForProductId(transaction.productID)
                        purchasedTierName = tier.displayName
                        purchaseSuccess = true
                        return true
                    } else {
                        // Finish transaction even if server verification failed to prevent StoreKit from re-delivering it indefinitely.
                        // The server can still verify it later via Transaction.updates listener or AppStore.sync().
                        await transaction.finish()
                        lastSubscriptionError = .serverVerificationPending
                        // Schedule a background retry to update entitlements
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                            await self?.updateEntitlements()
                        }
                        return false
                    }
                } else {
                    lastSubscriptionError = .verificationFailed
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                lastSubscriptionError = .pendingApproval
                return false
            @unknown default:
                logger.error("Monetization: unexpected purchase result in subscription purchase")
                lastSubscriptionError = .verificationFailed
                return false
            }
        } catch {
            lastSubscriptionError = .networkError(error.localizedDescription)
            return false
        }
    }

    func restore() async {
        loading = true
        lastSubscriptionError = nil
        defer { loading = false }
        let maxAttempts = 3
        for attempt in 0..<maxAttempts {
            do {
                try await AppStore.sync()
                await updateEntitlements()
                await refreshSubscriptionStatus()
                return
            } catch {
                if attempt < maxAttempts - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    do {
                        try await Task.sleep(nanoseconds: delay)
                    } catch {
                        return
                    }
                } else {
                    lastSubscriptionError = .networkError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: Server-side receipt validation

    private func submitSubscriptionVerification(_ verification: VerificationResult<StoreKit.Transaction>) async -> Bool {
        guard let url = backendBaseURL?.appendingPathComponent("api/v1/subscription/verify") else { return false }

        let jws = verification.jwsRepresentation
        let body: [String: Any] = [
            "device_id": EntitlementStore.shared.deviceId,
            "jws": jws
        ]

        for attempt in 1...3 {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addDeviceAuth(&request)
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                logger.error("Monetization: JSON serialization failed: \(error)")
                return false
            }
            request.timeoutInterval = 15

            do {
                let (data, response) = try await PinnedURLSession.shared.data(for: request)
                guard let httpResp = response as? HTTPURLResponse else { continue }

                if httpResp.statusCode == 200 {
                    do {
                        let resp = try JSONDecoder().decode(SubscriptionVerifyResponse.self, from: data)
                        applyServerSubscriptionResponse(resp)
                    } catch {
                        os_log(.error, "Monetization: failed to decode subscription response: %{public}@", error.localizedDescription)
                    }
                    return true
                } else {
                    os_log(.error, "Monetization: subscription verification returned HTTP %{public}d", httpResp.statusCode)
                    if httpResp.statusCode >= 400 && httpResp.statusCode < 500 && httpResp.statusCode != 429 {
                        return false
                    }
                }
            } catch {
                os_log(.debug, "Monetization: server verification attempt %{public}d failed: %{public}@", attempt, error.localizedDescription)
            }

            if attempt < 3 {
                let delay = pow(2.0, Double(attempt)) * Double.random(in: 0.8...1.2)
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return false
                }
            }
        }
        return false
    }

    private func applyServerSubscriptionResponse(_ resp: SubscriptionVerifyResponse) {
        if let tier = UserTier(rawValue: resp.tier) {
            EntitlementStore.shared.setTier(tier)
        }
        EntitlementStore.shared.autoRenew = resp.autoRenew
        EntitlementStore.shared.subscriptionEnvironment = resp.environment

        let iso8601Frac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        let iso8601Plain: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
        let simpleDF: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss'Z'"
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }()

        if let expiresAt = iso8601Frac.date(from: resp.expiresAt)
            ?? iso8601Plain.date(from: resp.expiresAt)
            ?? simpleDF.date(from: resp.expiresAt) {
            EntitlementStore.shared.subscriptionExpiryDate = expiresAt
            subscriptionExpirationDate = expiresAt
        }

        if let tier = UserTier(rawValue: resp.tier) {
            subscriptionInfo = SubscriptionInfo(
                tier: tier,
                expiresAt: subscriptionExpirationDate ?? Date.distantFuture,
                autoRenew: resp.autoRenew,
                environment: resp.environment,
                productId: ""
            )
        }
    }

    // date parsing uses cached static formatters above

    // MARK: Server-side subscription status

    func refreshSubscriptionStatus() async {
        guard let base = backendBaseURL else { return }
        var components = URLComponents(url: base.appendingPathComponent("api/v1/subscription/status"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "device_id", value: EntitlementStore.shared.deviceId)]
        guard let url = components?.url else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await PinnedURLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else { return }
            do {
                let resp = try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
                applyServerSubscriptionResponse(SubscriptionVerifyResponse(
                    tier: resp.tier,
                    status: resp.status,
                    expiresAt: resp.expiresAt ?? "",
                    autoRenew: resp.autoRenew,
                    environment: resp.environment ?? "Sandbox"
                ))
            } catch {
                os_log(.error, "Monetization: failed to decode subscription status: %{public}@", error.localizedDescription)
            }
        } catch {
            os_log(.debug, "Monetization: entitlement claim failed (local is source of truth): %{public}@", error.localizedDescription)
        }
    }

    // MARK: Refund / revocation handling

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                // Only handle subscription products here; consumable token products
                // are handled by ComputeStore.startListeningForConsumableUpdates()
                if ALL_TOKEN_PRODUCT_IDS.contains(transaction.productID) { continue }
                await transaction.finish()

                if let revocationDate = transaction.revocationDate {
                    await self?.handleRevocation(transaction: transaction, date: revocationDate)
                }

                await self?.updateEntitlements()
            }
        }
    }

    private func handleRevocation(transaction: StoreKit.Transaction, date: Date) async {
        subscriptionRevoked = true
        if transaction.revocationReason != nil {
            revocationMessage = NSLocalizedString("Subscription was refunded and is no longer active.", comment: "")
        } else {
            revocationMessage = NSLocalizedString("Subscription has been revoked.", comment: "")
        }
    }

    // MARK: Subscription management

    #if canImport(UIKit)
    func showManageSubscriptions(in windowScene: UIWindowScene) async {
        do {
            try await AppStore.showManageSubscriptions(in: windowScene)
        } catch {
            lastSubscriptionError = .networkError(NSLocalizedString("Could not open subscription management.", comment: ""))
        }
    }
    #endif

    // MARK: Refresh on app activation

    func refreshOnActivation() async {
        await updateEntitlements()
        await refreshSubscriptionStatus()
    }

    // MARK: Helpers

    private func tierForProductId(_ productId: String) -> UserTier {
        switch productId {
        case PRODUCT_PREMIUM_YEARLY, PRODUCT_PREMIUM_MONTHLY: return .premium
        case PRODUCT_BASIC_YEARLY, PRODUCT_BASIC_MONTHLY: return .basic
        default: return .free
        }
    }
}

// MARK: - Server response types

private struct SubscriptionVerifyResponse: Codable {
    let tier: String
    let status: String
    let expiresAt: String
    let autoRenew: Bool
    let environment: String
}

private struct SubscriptionStatusResponse: Codable {
    let tier: String
    let status: String
    let expiresAt: String?
    let autoRenew: Bool
    let environment: String?
}

// MARK: - Compute-token store

enum PurchaseResult {
    case success
    case pending
    case cancelled
    case failure(String)
}

struct ComputeProduct: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var priceUSD: Double
    var tokenAmount: Double
    var icon: String
    var storeKitProductId: String
}

@MainActor
final class ComputeStore: ObservableObject {
    static let shared = ComputeStore()

    @Published var products: [ComputeProduct] = []
    @Published var balance: Double = Double(EntitlementStore.shared.tokenBalance)
    @Published var loading = false
    @Published var lastError: String?
    @Published var purchasingProductId: String?
    @Published var storeKitProducts: [Product] = []

    private var baseURL: URL? {
        let s = EntitlementStore.shared.storeBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : URL(string: s)
    }

    private var consumableUpdatesTask: Task<Void, Never>?

    /// Creates a URLRequest for the given URL with the X-Device-ID header attached.
    private func authenticatedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue(EntitlementStore.shared.deviceId, forHTTPHeaderField: "X-Device-ID")
        request.timeoutInterval = 15
        return request
    }

    static let mockProducts: [ComputeProduct] = [
        ComputeProduct(id: "starter", title: String(localized: "Starter pack"), priceUSD: 9.99, tokenAmount: 100, icon: "bolt", storeKitProductId: PRODUCT_TOKENS_STARTER),
        ComputeProduct(id: "plus", title: String(localized: "Plus pack"), priceUSD: 29.99, tokenAmount: 350, icon: "bolt.badge.a", storeKitProductId: PRODUCT_TOKENS_PLUS),
        ComputeProduct(id: "pro", title: String(localized: "Pro pack"), priceUSD: 99.99, tokenAmount: 1300, icon: "cpu", storeKitProductId: PRODUCT_TOKENS_PRO),
        ComputeProduct(id: "max", title: String(localized: "Quantum pack"), priceUSD: 299.99, tokenAmount: 4500, icon: "atom", storeKitProductId: PRODUCT_TOKENS_QUANTUM)
    ]

    init() {
        startListeningForConsumableUpdates()
    }

    deinit { consumableUpdatesTask?.cancel() }

    // MARK: - Product loading

    func loadProducts() async {
        loading = true
        defer { loading = false }
        guard let url = baseURL?.appendingPathComponent("products") else {
            products = Self.mockProducts
            return
        }
        do {
            let request = authenticatedRequest(for: url)
            let (data, _) = try await PinnedURLSession.shared.data(for: request)
            products = try JSONDecoder().decode([ComputeProduct].self, from: data)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            products = Self.mockProducts
        } catch {
            lastError = error.localizedDescription
            products = Self.mockProducts
        }
    }

    func loadStoreKitProducts() async {
        do {
            let ids = products.map(\.storeKitProductId)
            storeKitProducts = try await Product.products(for: Set(ids))
        } catch {
            lastError = String(format: NSLocalizedString("Could not load products: %@", comment: ""), error.localizedDescription)
        }
    }

    // MARK: - Balance

    func refreshBalance() async {
        guard let url = balanceURL else {
            balance = Double(EntitlementStore.shared.tokenBalance)
            return
        }
        struct BalanceResp: Codable { var balance: Double }
        do {
            let request = authenticatedRequest(for: url)
            let (data, _) = try await PinnedURLSession.shared.data(for: request)
            let resp = try JSONDecoder().decode(BalanceResp.self, from: data)
            balance = resp.balance
            EntitlementStore.shared.tokenBalance = Int(resp.balance.rounded())
        } catch {
            balance = Double(EntitlementStore.shared.tokenBalance)
        }
    }

    private var balanceURL: URL? {
        guard let base = baseURL?.appendingPathComponent("balance") else { return nil }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "device_id", value: EntitlementStore.shared.deviceId)]
        return components?.url
    }

    // MARK: - Purchase

    func purchase(_ product: ComputeProduct) async -> PurchaseResult {
        guard baseURL != nil else {
            lastError = NSLocalizedString("Store is currently unavailable. Please try again later.", comment: "")
            return .failure("Store unavailable")
        }

        guard let skProduct = storeKitProducts.first(where: { $0.id == product.storeKitProductId }) else {
            lastError = NSLocalizedString("Product not available in StoreKit", comment: "")
            return .failure("Product not available")
        }

        loading = true
        purchasingProductId = product.id
        defer {
            loading = false
            purchasingProductId = nil
        }

        do {
            let result = try await skProduct.purchase()
            switch result {
            case .success(let verification):
                return await submitVerification(verification, for: product)
            case .pending:
                lastError = NSLocalizedString("Awaiting price confirmation. Tokens will be credited once confirmed.", comment: "")
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                logger.error("Monetization: unexpected purchase result in compute product purchase")
                return .failure(NSLocalizedString("Unknown purchase result", comment: ""))
            }
        } catch {
            lastError = error.localizedDescription
            return .failure(error.localizedDescription)
        }
    }

    private func submitVerification(_ verification: VerificationResult<StoreKit.Transaction>, for product: ComputeProduct) async -> PurchaseResult {
        let jws = verification.jwsRepresentation
        guard case .verified(let transaction) = verification else {
            lastError = NSLocalizedString("Transaction could not be verified", comment: "")
            return .failure(NSLocalizedString("Transaction could not be verified", comment: ""))
        }

        guard let url = baseURL?.appendingPathComponent("orders") else {
            return .failure(NSLocalizedString("No backend configured", comment: ""))
        }

        let body: [String: Any] = [
            "device_id": EntitlementStore.shared.deviceId,
            "transaction_id": String(transaction.id),
            "product_id": transaction.productID,
            "jws": jws
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Monetization: JSON serialization failed: \(error)")
            return .failure(NSLocalizedString("Failed to serialize purchase request", comment: ""))
        }

        let maxRetries = 3
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await PinnedURLSession.shared.data(for: request)
                guard let httpResp = response as? HTTPURLResponse else {
                    return .failure(NSLocalizedString("Invalid server response", comment: ""))
                }

                if httpResp.statusCode == 200 {
                    if let resp = try? JSONDecoder().decode(OrderResponse.self, from: data) {
                        if resp.balance >= self.balance {
                            await transaction.finish()
                            self.balance = resp.balance
                            EntitlementStore.shared.tokenBalance = Int(resp.balance.rounded())
                        } else {
                            logger.error("Monetization: server balance (\(resp.balance)) less than local (\(self.balance)), deferring transaction finish")
                            await refreshBalance()
                        }
                    } else {
                        await transaction.finish()
                        await refreshBalance()
                    }
                    return .success
                } else if httpResp.statusCode >= 400 && httpResp.statusCode < 500 {
                    let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                    let msg = errorBody?.error ?? String(format: NSLocalizedString("Server error (%d)", comment: ""), httpResp.statusCode)
                    lastError = msg
                    return .failure(msg)
                } else {
                    if attempt < maxRetries - 1 {
                        let delay = min(UInt64(1) << min(attempt, 30), 30_000_000_000)
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                    let msg = errorBody?.error ?? String(format: NSLocalizedString("Server error (%d)", comment: ""), httpResp.statusCode)
                    lastError = msg
                    return .failure(msg)
                }
            } catch {
                if attempt < maxRetries - 1 {
                    let delay = min(UInt64(1) << min(attempt, 30), 30_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                lastError = String(format: NSLocalizedString("Network error: %@", comment: ""), error.localizedDescription)
                return .failure(lastError ?? NSLocalizedString("Network error", comment: ""))
            }
        }
        return .failure(NSLocalizedString("Max retries exceeded", comment: ""))
    }

    // MARK: - Transaction listener for consumables

    private func startListeningForConsumableUpdates() {
        consumableUpdatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                guard ALL_TOKEN_PRODUCT_IDS.contains(transaction.productID) else { continue }
                let product = Self.mockProducts.first { $0.storeKitProductId == transaction.productID }
                guard let product else { continue }
                _ = await self?.submitVerification(update, for: product)
            }
        }
    }

    // MARK: - Local credit/debit (mock mode or red packets)

    func credit(_ amount: Double) {
        guard amount > 0 else { return }
        balance += amount
        EntitlementStore.shared.tokenBalance = Int(balance.rounded())
    }

    @discardableResult
    func debit(_ amount: Double) -> Bool {
        guard balance >= amount, amount > 0 else { return false }
        balance -= amount
        EntitlementStore.shared.tokenBalance = Int(balance.rounded())
        return true
    }

    func claimGift(id: String, amount: Double) async -> Bool {
        guard let url = baseURL?.appendingPathComponent("gift/\(id)/claim") else {
            lastError = NSLocalizedString("Server not configured", comment: "")
            return false
        }

        let body: [String: Any] = ["device_id": EntitlementStore.shared.deviceId]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Monetization: JSON serialization failed: \(error)")
            return false
        }

        do {
            let (data, response) = try await PinnedURLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                lastError = NSLocalizedString("Server rejected claim", comment: "")
                return false
            }
            struct ClaimResponse: Codable { let balance: Double }
            if let resp = try? JSONDecoder().decode(ClaimResponse.self, from: data) {
                balance = resp.balance
                EntitlementStore.shared.tokenBalance = Int(resp.balance.rounded())
            } else {
                await refreshBalance()
            }
            return true
        } catch {
            lastError = String(format: NSLocalizedString("Network error during claim: %@", comment: ""), error.localizedDescription)
            return false
        }
    }
}

// MARK: - API response types

private struct OrderResponse: Codable {
    let status: String
    let balance: Double
    let tokens_credited: Double?
}

private struct ErrorResponse: Codable {
    let error: String?
}
