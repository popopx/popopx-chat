// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import OSLog

@MainActor
class WalletManager: ObservableObject {
    static let shared = WalletManager()

    private let logger = Logger(subsystem: "im.popopx", category: "WalletManager")
    private let storageKey = "im.popopx.wallet.entries"
    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.popopxchat.popopx") ?? .standard

    struct WalletEntry: Codable, Identifiable {
        let id: UUID
        let asset: String
        let amount: String
        let action: String
        let sourceText: String
        let createdAt: Date

        init(id: UUID = UUID(), asset: String, amount: String, action: String, sourceText: String, createdAt: Date = Date()) {
            self.id = id
            self.asset = asset
            self.amount = amount
            self.action = action
            self.sourceText = sourceText
            self.createdAt = createdAt
        }
    }

    @Published private(set) var entries: [WalletEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private init() {
        loadEntries()
    }

    func addEntry(from extraction: Extraction) {
        guard extraction.type == .asset else { return }

        let asset = extraction.data["asset"] ?? "unknown"
        let amount = extraction.data["amount"] ?? "0"
        let action = extraction.data["action"] ?? "unknown"

        let entry = WalletEntry(
            asset: asset,
            amount: amount,
            action: action,
            sourceText: extraction.sourceText
        )

        entries.append(entry)
        saveEntries()

        #if DEBUG
        logger.info("Added wallet entry: \(asset) \(amount) (\(action))")
        #endif
    }

    func removeEntry(at index: Int) {
        guard index < entries.count else { return }
        entries.remove(at: index)
        saveEntries()
    }

    func clearAllEntries() {
        entries.removeAll()
        saveEntries()
        CryptoEncrypt.shared.deleteKey()
        logger.warning("All wallet entries cleared")
    }

    func getBalance(for asset: String) -> Double {
        let assetEntries = entries.filter { $0.asset == asset }
        var balance: Double = 0

        for entry in assetEntries {
            guard let amount = Double(entry.amount) else { continue }
            switch entry.action.lowercased() {
            case "invest", "receive", "buy":
                balance += amount
            case "send", "sell", "spend":
                balance -= amount
            default:
                break
            }
        }

        return balance
    }

    func getAllAssets() -> [String] {
        return Array(Set(entries.map { $0.asset })).sorted()
    }

    func getEntries(for asset: String) -> [WalletEntry] {
        return entries.filter { $0.asset == asset }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private Methods

    private func loadEntries() {
        isLoading = true
        defer { isLoading = false }

        do {
            if let encryptedData = Self.appGroupDefaults.data(forKey: storageKey) {
                let decryptedData = try CryptoEncrypt.shared.decrypt(encryptedData)
                entries = try JSONDecoder().decode([WalletEntry].self, from: decryptedData)
            }
        } catch {
            logger.error("Failed to load wallet entries: \(error)")
            lastError = error.localizedDescription
            entries = []
        }
    }

    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            let encryptedData = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encryptedData, forKey: storageKey)
        } catch {
            logger.error("Failed to save wallet entries: \(error)")
            lastError = error.localizedDescription
        }
    }
}
