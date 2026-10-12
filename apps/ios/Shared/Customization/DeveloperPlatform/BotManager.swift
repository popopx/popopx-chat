// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/14-FEATURE-DEVELOPER-BRIDGE.md
import Foundation
import Security

struct BotInfo: Identifiable {
    let id: String
    var name: String
    var description: String
    var webhookUrl: String
    var apiKey: String
    var isPublic: Bool
    var installCount: Int
}

struct MiniApp: Identifiable {
    let id: String
    var name: String
    var url: String
    var icon: String
    var description: String
}

@MainActor
class BotManager: ObservableObject {
    static let shared = BotManager()

    @Published var bots: [BotInfo] = []
    @Published var miniApps: [MiniApp] = [
        MiniApp(id: "1", name: "Polls", url: "https://apps.popopxchat.com/polls", icon: "chart.bar", description: "Create and vote on polls"),
        MiniApp(id: "2", name: "Wallet", url: "https://apps.popopxchat.com/wallet", icon: "wallet.pass", description: "Manage digital assets"),
    ]

    func registerBot(name: String, description: String, webhookUrl: String) {
        var keyBytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, keyBytes.count, &keyBytes) == errSecSuccess else { return }
        let apiKey = keyBytes.map { String(format: "%02x", $0) }.joined()
        let bot = BotInfo(
            id: UUID().uuidString, name: name, description: description,
            webhookUrl: webhookUrl, apiKey: apiKey,
            isPublic: false, installCount: 0
        )
        bots.append(bot)
    }

    func deleteBot(_ botId: String) {
        bots.removeAll { $0.id == botId }
    }
}
