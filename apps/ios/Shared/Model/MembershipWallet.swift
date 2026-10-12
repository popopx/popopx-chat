// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import Combine

/// Membership credential stored in local wallet
struct MembershipCredential: Identifiable, Codable {
    let id: String
    let credentialX: String
    let signatureS: String
    let tier: String
    let period: String
    let expiresAt: Date
    let capability: String
    var status: CredentialStatus
    let source: CredentialSource
    let createdAt: Date
    var redeemedAt: Date?
    let blindFactorR: String?
    let metadata: [String: String]?

    enum CredentialStatus: String, Codable {
        case unused
        case active
        case expired
        case revoked
    }

    enum CredentialSource: String, Codable {
        case purchase
        case gift
        case redeemCode
    }

    var isExpired: Bool {
        return expiresAt < Date()
    }

    var tierDisplayName: String {
        switch tier {
        case "basic": return "Basic"
        case "premium": return "Premium"
        default: return tier.capitalized
        }
    }
}

/// Bot message protocol
struct BotMessage: Codable {
    let type: String
    let data: [String: AnyCodable]
}

/// Bot response
struct BotResponse: Codable {
    let type: String
    let data: [String: AnyCodable]
}

/// AnyCodable wrapper for mixed-type dictionaries
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}

/// Membership Wallet Manager
@MainActor
class MembershipWallet: ObservableObject {
    static let shared = MembershipWallet()

    @Published var credentials: [MembershipCredential] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?

    private let storageKey = "membership_credentials"
    private let botClient = MembershipBotClient.shared

    private init() {
        loadCredentials()
    }

    // MARK: - Storage

    func loadCredentials() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MembershipCredential].self, from: data) else {
            return
        }
        credentials = decoded
    }

    func saveCredentials() {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Credential Management

    func addCredential(_ credential: MembershipCredential) {
        credentials.append(credential)
        saveCredentials()
    }

    func removeCredential(id: String) {
        credentials.removeAll { $0.id == id }
        saveCredentials()
    }

    func updateCredentialStatus(id: String, status: MembershipCredential.CredentialStatus) {
        guard let index = credentials.firstIndex(where: { $0.id == id }) else { return }
        credentials[index].status = status
        saveCredentials()
    }

    // MARK: - Bot Communication

    /// Verify all credentials with Bot (batch check)
    func verifyAllCredentials() async {
        isLoading = true
        defer { isLoading = false }

        let credentialXs = credentials.map { $0.credentialX }
        guard !credentialXs.isEmpty else { return }

        do {
            let response = try await botClient.batchCheck(credentials: credentialXs)

            for result in response {
                guard let x = result["x"] as? String,
                      let statusStr = result["status"] as? String else { continue }

                let status: MembershipCredential.CredentialStatus
                switch statusStr {
                case "active": status = .active
                case "expired": status = .expired
                default: status = .unused
                }

                if let index = credentials.firstIndex(where: { $0.credentialX == x }) {
                    credentials[index].status = status
                }
            }

            saveCredentials()
            lastSyncDate = Date()
        } catch {
            print("Failed to verify credentials: \(error)")
        }
    }

    /// Redeem a credential (activate membership)
    func redeemCredential(_ credential: MembershipCredential) async throws -> [String: Any] {
        let response = try await botClient.redeem(
            x: credential.credentialX,
            s: credential.signatureS
        )

        if let success = response["success"] as? Bool, success {
            updateCredentialStatus(id: credential.id, status: .active)
        }

        return response
    }

    /// Check single credential status
    func checkCredentialStatus(_ credential: MembershipCredential) async throws -> [String: Any] {
        return try await botClient.checkStatus(x: credential.credentialX)
    }

    // MARK: - Purchase Flow

    /// Create a new credential after StoreKit purchase
    func createCredentialFromPurchase(
        tier: String,
        period: String,
        blindedX: String,
        blindFactorR: String,
        blindedSignature: String
    ) -> MembershipCredential {
        // Unblind the signature
        let signature = BlindSignature.unblind(
            blindedSignature: blindedSignature,
            blindingFactor: blindFactorR
        )

        let credential = MembershipCredential(
            id: UUID().uuidString,
            credentialX: BlindSignature.generateCredential(),
            signatureS: signature,
            tier: tier,
            period: period,
            expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
            capability: "Premium_Relay",
            status: .unused,
            source: .purchase,
            createdAt: Date(),
            redeemedAt: nil,
            blindFactorR: blindFactorR,
            metadata: nil
        )

        addCredential(credential)
        return credential
    }

    /// Import credential from gift or code redemption
    func importCredential(x: String, s: String, tier: String, expires: String) {
        let expiresDate = ISO8601DateFormatter().date(from: expires) ?? Date()

        let credential = MembershipCredential(
            id: UUID().uuidString,
            credentialX: x,
            signatureS: s,
            tier: tier,
            period: "yearly",
            expiresAt: expiresDate,
            capability: "Premium_Relay",
            status: .unused,
            source: .gift,
            createdAt: Date(),
            redeemedAt: nil,
            blindFactorR: nil,
            metadata: nil
        )

        addCredential(credential)
    }
}

/// Bot Client for POPOPX messaging
@MainActor
class MembershipBotClient {
    static let shared = MembershipBotClient()

    private let botContactId = "payment_bot_contact_id" // TODO: Configure from EntitlementStore

    private init() {}

    /// Send purchase request to Bot
    func sendPurchaseRequest(
        tier: String,
        period: String,
        blindedX: String,
        appleReceiptJWS: String
    ) async throws -> [String: Any] {
        let message: [String: Any] = [
            "type": "purchase_request",
            "data": [
                "tier": tier,
                "period": period,
                "blinded_x": blindedX,
                "apple_receipt_jws": appleReceiptJWS
            ]
        ]

        return try await sendToBot(message)
    }

    /// Redeem credential
    func redeem(x: String, s: String) async throws -> [String: Any] {
        let message: [String: Any] = [
            "type": "redeem",
            "data": [
                "x": x,
                "s": s
            ]
        ]

        return try await sendToBot(message)
    }

    /// Check credential status
    func checkStatus(x: String) async throws -> [String: Any] {
        let message: [String: Any] = [
            "type": "check_status",
            "data": ["x": x]
        ]

        return try await sendToBot(message)
    }

    /// Batch check credentials
    func batchCheck(credentials: [String]) async throws -> [[String: Any]] {
        let message: [String: Any] = [
            "type": "batch_check",
            "data": ["credentials": credentials]
        ]

        let response = try await sendToBot(message)
        return response["results"] as? [[String: Any]] ?? []
    }

    /// Redeem voucher code
    func redeemCode(code: String) async throws -> [String: Any] {
        let message: [String: Any] = [
            "type": "redeem_code",
            "data": ["code": code]
        ]

        return try await sendToBot(message)
    }

    // MARK: - Private

    private func sendToBot(_ message: [String: Any]) async throws -> [String: Any] {
        // TODO: Integrate with POPOPX API
        // For now, this is a placeholder
        // In production, use POPOPX chat_send_cmd to send message to botContactId

        print("[MembershipBotClient] Sending to bot: \(message)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Mock response
        return [
            "type": "mock_response",
            "data": ["status": "success"]
        ]
    }
}
