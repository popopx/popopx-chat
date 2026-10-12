// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/11-FEATURE-DID.md
import Foundation
import CryptoKit
import Security
import os

struct PrivacyCard: Identifiable, Codable {
    let id: UUID
    var did: String
    var displayName: String
    var avatar: String?
    var credentials: [VerifiableCredential]
}

struct VerifiableCredential: Identifiable, Codable {
    let id: String
    var type: String
    var issuer: String
    var issuanceDate: String
    var status: String
}

@MainActor
class DIDManager: ObservableObject {
    static let shared = DIDManager()

    private static let keychainService = "com.popopxchat.popopx"
    private static let keychainAccount = "did-manager-current"

    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.popopxchat.popopx") ?? .standard
    private static let cardsKey = "didManagerCards"
    private static let credentialsKey = "didManagerCredentials"

    @Published var currentDID: String?
    @Published var cards: [PrivacyCard] = [] {
        didSet { saveCards() }
    }
    @Published var credentials: [VerifiableCredential] = [] {
        didSet { saveCredentials() }
    }

    var currentCard: PrivacyCard {
        cards.first ?? PrivacyCard(id: UUID(), did: "did:popopx:not_initialized", displayName: "Not Initialized", avatar: nil, credentials: [])
    }

    init() {
        loadPersistedState()
        currentDID = Self.loadDIDFromKeychain()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let defaults = Self.appGroupDefaults
        if let encryptedData = defaults.data(forKey: Self.cardsKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encryptedData)
                cards = try JSONDecoder().decode([PrivacyCard].self, from: data)
            } catch {
                os_log(.error, "DIDManager: failed to decode cards: %{public}@", error.localizedDescription)
            }
        }
        if let encryptedData = defaults.data(forKey: Self.credentialsKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encryptedData)
                credentials = try JSONDecoder().decode([VerifiableCredential].self, from: data)
            } catch {
                os_log(.error, "DIDManager: failed to decode credentials: %{public}@", error.localizedDescription)
            }
        }
    }

    private func saveCards() {
        do {
            let jsonData = try JSONEncoder().encode(cards)
            let encryptedData = try CryptoEncrypt.shared.encrypt(jsonData)
            Self.appGroupDefaults.set(encryptedData, forKey: Self.cardsKey)
        } catch {
            os_log(.error, "DIDManager: failed to encode cards: %{public}@", error.localizedDescription)
        }
    }

    private func saveCredentials() {
        do {
            let jsonData = try JSONEncoder().encode(credentials)
            let encryptedData = try CryptoEncrypt.shared.encrypt(jsonData)
            Self.appGroupDefaults.set(encryptedData, forKey: Self.credentialsKey)
        } catch {
            os_log(.error, "DIDManager: failed to encode credentials: %{public}@", error.localizedDescription)
        }
    }

    func generateDID() {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { return }
        let encoded = bytes.map { String(format: "%02x", $0) }.joined()
        let did = "did:popopx:\(encoded)"
        currentDID = did
        Self.saveDIDToKeychain(did)

        if cards.isEmpty {
            cards.append(PrivacyCard(id: UUID(), did: did, displayName: "My Privacy Card", avatar: nil, credentials: []))
        }
    }

    private static func saveDIDToKeychain(_ did: String) {
        guard let data = did.data(using: .utf8) else { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        ]
        #if os(iOS) && !targetEnvironment(simulator)
        if let teamID = Bundle.main.infoDictionary?["TeamIdentifier"] as? String, teamID != "$(AppIdentifierPrefix)" {
            query[kSecAttrAccessGroup as String] = "\(teamID).com.popopxchat.popopx"
        }
        #endif
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            os_log(.error, "DIDManager: failed to save DID to Keychain: %d", Int(status))
        }
    }

    private static func loadDIDFromKeychain() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        #if os(iOS) && !targetEnvironment(simulator)
        if let teamID = Bundle.main.infoDictionary?["TeamIdentifier"] as? String, teamID != "$(AppIdentifierPrefix)" {
            query[kSecAttrAccessGroup as String] = "\(teamID).com.popopxchat.popopx"
        }
        #endif
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let did = String(data: data, encoding: .utf8) else { return nil }
        return did
    }

    func createCard(name: String) -> PrivacyCard {
        let card = PrivacyCard(
            id: UUID(),
            did: currentDID ?? "did:popopx:unregistered",
            displayName: name,
            avatar: nil,
            credentials: credentials
        )
        cards.append(card)
        return card
    }

    func issueCredential(type: String, issuer: String) -> VerifiableCredential {
        let credential = VerifiableCredential(
            id: UUID().uuidString,
            type: type,
            issuer: issuer,
            issuanceDate: ISO8601DateFormatter().string(from: Date()),
            status: "active"
        )
        credentials.append(credential)

        if let firstIndex = cards.indices.first {
            cards[firstIndex].credentials.append(credential)
        }

        return credential
    }

    func deleteCard(_ cardId: UUID) {
        cards.removeAll { $0.id == cardId }
    }

    func revokeCredential(_ credentialId: String) {
        if let idx = credentials.firstIndex(where: { $0.id == credentialId }) {
            credentials[idx].status = "revoked"
        }
        for cardIndex in cards.indices {
            if let credIdx = cards[cardIndex].credentials.firstIndex(where: { $0.id == credentialId }) {
                cards[cardIndex].credentials[credIdx].status = "revoked"
            }
        }
    }
}
