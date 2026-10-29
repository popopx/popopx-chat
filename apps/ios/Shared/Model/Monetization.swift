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
    case productNotAvailable
    case pendingApproval
    case revoked(reason: String)

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return String(format: NSLocalizedString("Network error: %@", comment: ""), msg)
        case .verificationFailed: return NSLocalizedString("Purchase could not be verified.", comment: "")
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
                    await transaction.finish()
                    await updateEntitlements()
                    let tier = tierForProductId(transaction.productID)
                    purchasedTierName = tier.displayName
                    purchaseSuccess = true
                    return true
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

    // MARK: Subscription status (local StoreKit only)

    func refreshSubscriptionStatus() async {
        await updateEntitlements()
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

    private var consumableUpdatesTask: Task<Void, Never>?

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
        products = Self.mockProducts
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
        do {
            let bal = try await apiGetComputeBalance()
            balance = bal.balance
            EntitlementStore.shared.tokenBalance = Int(bal.balance.rounded())
        } catch {
            balance = Double(EntitlementStore.shared.tokenBalance)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: ComputeProduct) async -> PurchaseResult {
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
                return await processVerifiedPurchase(verification, for: product)
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

    private func processVerifiedPurchase(_ verification: VerificationResult<StoreKit.Transaction>, for product: ComputeProduct) async -> PurchaseResult {
        guard case .verified(let transaction) = verification else {
            lastError = NSLocalizedString("Transaction could not be verified", comment: "")
            return .failure(NSLocalizedString("Transaction could not be verified", comment: ""))
        }

        await transaction.finish()

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let purchase = ComputePurchaseFFI(
            transactionId: String(transaction.id),
            productId: transaction.productID,
            purchaseType: "token_pack",
            tokenAmount: product.tokenAmount,
            priceUsd: product.priceUSD,
            status: "completed",
            metadata: nil,
            createdAt: dateFormatter.string(from: transaction.purchaseDate)
        )

        do {
            let bal = try await apiRecordComputePurchase(purchase: purchase)
            balance = bal.balance
            EntitlementStore.shared.tokenBalance = Int(bal.balance.rounded())
        } catch {
            credit(product.tokenAmount)
            logger.error("Monetization: FFI purchase record failed, credited locally: \(error)")
        }
        return .success
    }

    // MARK: - Transaction listener for consumables

    private func startListeningForConsumableUpdates() {
        consumableUpdatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                guard ALL_TOKEN_PRODUCT_IDS.contains(transaction.productID) else { continue }
                let product = Self.mockProducts.first { $0.storeKitProductId == transaction.productID }
                guard let product else { continue }
                await transaction.finish()

                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime]
                let purchase = ComputePurchaseFFI(
                    transactionId: String(transaction.id),
                    productId: transaction.productID,
                    purchaseType: "token_pack",
                    tokenAmount: product.tokenAmount,
                    priceUsd: product.priceUSD,
                    status: "completed",
                    metadata: nil,
                    createdAt: dateFormatter.string(from: transaction.purchaseDate)
                )

                do {
                    let bal = try await apiRecordComputePurchase(purchase: purchase)
                    await MainActor.run {
                        self?.balance = bal.balance
                        EntitlementStore.shared.tokenBalance = Int(bal.balance.rounded())
                    }
                } catch {
                    await self?.credit(product.tokenAmount)
                }
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
        guard !EntitlementStore.shared.isClaimed(id) else {
            lastError = NSLocalizedString("Gift already claimed", comment: "")
            return false
        }
        credit(amount)
        EntitlementStore.shared.markClaimed(id)
        return true
    }
}

// MARK: - API response types

