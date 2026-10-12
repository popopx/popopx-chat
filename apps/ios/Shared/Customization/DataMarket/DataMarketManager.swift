// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit
import os

struct DataListing: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var category: DataCategory
    var price: Double
    var dataHash: String
    var sellerDID: String
    var status: ListingStatus
    var createdAt: Date
    var buyerCount: Int

    enum ListingStatus: String, Codable {
        case active = "Active"
        case sold = "Sold"
        case expired = "Expired"
        case revoked = "Revoked"
    }
}

enum DataCategory: String, CaseIterable, Codable {
    case browsingHistory = "Browsing History"
    case appUsage = "App Usage Stats"
    case locationData = "Location Data"
    case preferences = "Preferences"
    case healthMetrics = "Health Metrics"
    case socialGraph = "Social Graph"

    var icon: String {
        switch self {
        case .browsingHistory: return "globe"
        case .appUsage: return "app.badge"
        case .locationData: return "location.fill"
        case .preferences: return "heart.fill"
        case .healthMetrics: return "waveform.path.ecg"
        case .socialGraph: return "person.2.fill"
        }
    }
}

struct DataPurchase: Identifiable, Codable {
    let id: String
    let listingId: String
    let listingTitle: String
    var price: Double
    var purchasedAt: Date
    var accessExpiry: Date
}

@MainActor
class DataMarketManager: ObservableObject {
    static let shared = DataMarketManager()

    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.popopxchat.popopx") ?? .standard
    private static let myListingsKey = "dataMarketMyListings"
    private static let marketplaceKey = "dataMarketMarketplace"
    private static let purchasesKey = "dataMarketPurchases"
    private static let totalEarningsKey = "dataMarketTotalEarnings"

    @Published var myListings: [DataListing] = [] {
        didSet { saveMyListings() }
    }
    @Published var marketplace: [DataListing] = [] {
        didSet { saveMarketplace() }
    }
    @Published var purchases: [DataPurchase] = [] {
        didSet { savePurchases() }
    }
    @Published var totalEarnings: Double = 0 {
        didSet { saveTotalEarnings() }
    }

    init() {
        loadPersistedState()
        if marketplace.isEmpty {
            loadSampleMarketplace()
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let defaults = Self.appGroupDefaults
        if let encrypted = defaults.data(forKey: Self.myListingsKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encrypted)
                myListings = try JSONDecoder().decode([DataListing].self, from: data)
            } catch {
                os_log(.error, "DataMarketManager: failed to decrypt/decode myListings: %{public}@", error.localizedDescription)
            }
        }
        if let encrypted = defaults.data(forKey: Self.marketplaceKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encrypted)
                marketplace = try JSONDecoder().decode([DataListing].self, from: data)
            } catch {
                os_log(.error, "DataMarketManager: failed to decrypt/decode marketplace: %{public}@", error.localizedDescription)
            }
        }
        if let encrypted = defaults.data(forKey: Self.purchasesKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encrypted)
                purchases = try JSONDecoder().decode([DataPurchase].self, from: data)
            } catch {
                os_log(.error, "DataMarketManager: failed to decrypt/decode purchases: %{public}@", error.localizedDescription)
            }
        }
        if let encrypted = defaults.data(forKey: Self.totalEarningsKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encrypted)
                totalEarnings = try JSONDecoder().decode(Double.self, from: data)
            } catch {
                os_log(.error, "DataMarketManager: failed to decrypt/decode totalEarnings: %{public}@", error.localizedDescription)
            }
        }
    }

    private func saveMyListings() {
        do {
            let data = try JSONEncoder().encode(myListings)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: Self.myListingsKey)
        } catch {
            os_log(.error, "DataMarketManager: failed to encrypt/save myListings: %{public}@", error.localizedDescription)
        }
    }

    private func saveMarketplace() {
        do {
            let data = try JSONEncoder().encode(marketplace)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: Self.marketplaceKey)
        } catch {
            os_log(.error, "DataMarketManager: failed to encrypt/save marketplace: %{public}@", error.localizedDescription)
        }
    }

    private func savePurchases() {
        do {
            let data = try JSONEncoder().encode(purchases)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: Self.purchasesKey)
        } catch {
            os_log(.error, "DataMarketManager: failed to encrypt/save purchases: %{public}@", error.localizedDescription)
        }
    }

    private func saveTotalEarnings() {
        do {
            let data = try JSONEncoder().encode(totalEarnings)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: Self.totalEarningsKey)
        } catch {
            os_log(.error, "DataMarketManager: failed to encrypt/save totalEarnings: %{public}@", error.localizedDescription)
        }
    }

    func createListing(title: String, description: String, category: DataCategory, price: Double) -> DataListing {
        let content = "\(title)\(description)\(category.rawValue)\(price)"
        let hash = SHA256.hash(data: Data(content.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        let listing = DataListing(
            id: UUID().uuidString,
            title: title,
            description: description,
            category: category,
            price: price,
            dataHash: hashString.prefix(16).description,
            sellerDID: "did:popopx:me",
            status: .active,
            createdAt: Date(),
            buyerCount: 0
        )

        myListings.insert(listing, at: 0)
        return listing
    }

    func purchaseListing(_ listing: DataListing) -> Bool {
        guard listing.status == .active else { return false }
        guard !purchases.contains(where: { $0.listingId == listing.id }) else { return false }

        let purchase = DataPurchase(
            id: UUID().uuidString,
            listingId: listing.id,
            listingTitle: listing.title,
            price: listing.price,
            purchasedAt: Date(),
            accessExpiry: Date().addingTimeInterval(30 * 24 * 3600)
        )
        purchases.insert(purchase, at: 0)
        let myDID = "did:popopx:me"
        if listing.sellerDID != myDID {
            totalEarnings += listing.price
        }

        if let idx = marketplace.firstIndex(where: { $0.id == listing.id }) {
            marketplace[idx].buyerCount += 1
        }
        return true
    }

    func revokeListing(_ listingId: String) {
        if let index = myListings.firstIndex(where: { $0.id == listingId }) {
            myListings[index].status = .revoked
        }
    }

    private func loadSampleMarketplace() {
        marketplace = [
            DataListing(id: "1", title: NSLocalizedString("data_market_sample1_title", comment: "Sample data listing 1 title"), description: NSLocalizedString("data_market_sample1_desc", comment: "Sample data listing 1 description"), category: .browsingHistory, price: 5.0, dataHash: "a1b2c3d4e5f6g7h8", sellerDID: "did:popopx:user1", status: .active, createdAt: Date().addingTimeInterval(-3600), buyerCount: 12),
            DataListing(id: "2", title: NSLocalizedString("data_market_sample2_title", comment: "Sample data listing 2 title"), description: NSLocalizedString("data_market_sample2_desc", comment: "Sample data listing 2 description"), category: .appUsage, price: 3.0, dataHash: "i9j0k1l2m3n4o5p6", sellerDID: "did:popopx:user2", status: .active, createdAt: Date().addingTimeInterval(-7200), buyerCount: 8),
            DataListing(id: "3", title: NSLocalizedString("data_market_sample3_title", comment: "Sample data listing 3 title"), description: NSLocalizedString("data_market_sample3_desc", comment: "Sample data listing 3 description"), category: .locationData, price: 10.0, dataHash: "q7r8s9t0u1v2w3x4", sellerDID: "did:popopx:user3", status: .active, createdAt: Date().addingTimeInterval(-1800), buyerCount: 3),
            DataListing(id: "4", title: NSLocalizedString("data_market_sample4_title", comment: "Sample data listing 4 title"), description: NSLocalizedString("data_market_sample4_desc", comment: "Sample data listing 4 description"), category: .preferences, price: 2.0, dataHash: "y5z6a7b8c9d0e1f2", sellerDID: "did:popopx:user4", status: .active, createdAt: Date().addingTimeInterval(-5400), buyerCount: 25),
        ]
    }
}
