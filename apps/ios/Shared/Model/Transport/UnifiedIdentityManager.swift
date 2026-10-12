// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit
import BitchatMesh
import os

struct UnifiedPeerInfo: Codable, Equatable {
    let identityPubKeyHex: String
    var smpAddress: String?
    var blePeerID: String?
    var multipeerPeerID: String?
    var nostrPubKey: String?
    var displayName: String?

    var availableTransports: [String] {
        var result: [String] = []
        if smpAddress != nil { result.append("smp") }
        if blePeerID != nil { result.append("ble") }
        if multipeerPeerID != nil { result.append("multipeer") }
        if nostrPubKey != nil { result.append("nostr") }
        return result
    }
}

struct UnifiedQRPayload: Codable {
    let identity: String
    var smp: String?
    var ble: String?
    var multipeer: String?
    var nostr: String?
    var name: String?
    let version: Int

    init(identity: String, smp: String? = nil, ble: String? = nil, multipeer: String? = nil, nostr: String? = nil, name: String? = nil) {
        self.identity = identity
        self.smp = smp
        self.ble = ble
        self.multipeer = multipeer
        self.nostr = nostr
        self.name = name
        self.version = 1
    }
}

actor UnifiedIdentityManager {
    static let shared = UnifiedIdentityManager()

    private let keychainService = "chat.popop.unified-identity"
    private let keychainAccount = "master-keypair"
    #if os(iOS) && !targetEnvironment(simulator)
    private let accessGroup: String = {
        if let teamID = Bundle.main.infoDictionary?["TeamIdentifier"] as? String, teamID != "$(AppIdentifierPrefix)" {
            return "\(teamID).com.popopxchat.popopx"
        }
        return "com.popopxchat.popopx"
    }()
    #endif

    private var identityPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var identityPublicKeyHex: String?

    private(set) var localPeerInfo: UnifiedPeerInfo?

    private init() {}

    func initialize() async {
        if let existing = loadKeyFromKeychain() {
            identityPrivateKey = existing
            identityPublicKeyHex = existing.publicKey.rawRepresentation.hexString
        } else {
            let newKey = Curve25519.KeyAgreement.PrivateKey()
            identityPrivateKey = newKey
            identityPublicKeyHex = newKey.publicKey.rawRepresentation.hexString
            saveKeyToKeychain(newKey)
        }

        localPeerInfo = UnifiedPeerInfo(
            identityPubKeyHex: identityPublicKeyHex ?? "",
            smpAddress: nil,
            blePeerID: nil,
            multipeerPeerID: nil,
            nostrPubKey: nil,
            displayName: nil
        )

        if let masterSeed = identityPrivateKey?.rawRepresentation {
            let nostrPubKey = await MainActor.run {
                BitchatSharedRuntime.shared.deriveNostrIdentity(fromMasterSeed: masterSeed)
            }
            if let nostrPubKey {
                localPeerInfo?.nostrPubKey = nostrPubKey
                if let pubKeyData = identityPrivateKey?.publicKey.rawRepresentation {
                    await MainActor.run {
                        BitchatSharedRuntime.shared.associateNoiseKey(pubKeyData, withNostrPubKey: nostrPubKey)
                    }
                }
            }
        }
    }

    var publicKeyHex: String {
        get async {
            if identityPublicKeyHex == nil {
                await initialize()
            }
            return identityPublicKeyHex ?? ""
        }
    }

    func blePeerID() -> String {
        guard let pubKeyData = identityPrivateKey?.publicKey.rawRepresentation else { return "" }
        let hash = SHA256.hash(data: pubKeyData)
        return Data(hash.prefix(8)).hexString
    }

    func updateTransportEndpoint(_ transport: String, endpoint: String) async {
        guard var info = localPeerInfo else { return }
        switch transport {
        case "smp":
            info.smpAddress = endpoint
        case "ble":
            info.blePeerID = endpoint
        case "multipeer":
            info.multipeerPeerID = endpoint
        case "nostr":
            info.nostrPubKey = endpoint
        default:
            break
        }
        localPeerInfo = info
    }

    func updateDisplayName(_ name: String) async {
        guard var info = localPeerInfo else { return }
        info.displayName = name
        localPeerInfo = info
    }

    func generateUnifiedQR() async -> String? {
        if localPeerInfo == nil {
            await initialize()
        }
        guard let info = localPeerInfo else { return nil }

        let payload = UnifiedQRPayload(
            identity: info.identityPubKeyHex,
            smp: info.smpAddress,
            ble: info.blePeerID,
            multipeer: info.multipeerPeerID,
            nostr: info.nostrPubKey,
            name: info.displayName
        )

        guard let data = try? JSONEncoder().encode(payload) else { return nil }

        return "popop://connect?\(data.base64EncodedString())"
    }

    func parseUnifiedQR(_ qrString: String) -> UnifiedQRPayload? {
        guard qrString.hasPrefix("popop://connect?") else { return nil }
        let encoded = String(qrString.dropFirst("popop://connect?".count))
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(UnifiedQRPayload.self, from: data)
    }

    func deriveSharedSecret(peerPublicKeyHex: String) -> Data? {
        guard let privateKey = identityPrivateKey,
              let peerKeyData = Data(hexString: peerPublicKeyHex) else { return nil }

        do {
            let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKeyData)
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
            return sharedSecret.withUnsafeBytes { Data($0) }
        } catch {
            return nil
        }
    }

    private func loadKeyFromKeychain() -> Curve25519.KeyAgreement.PrivateKey? {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        func attempt(withAccessGroup: Bool) -> OSStatus {
            var q = base
            #if os(iOS) && !targetEnvironment(simulator)
            if withAccessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
            #endif
            return SecItemCopyMatching(q as CFDictionary, &result)
        }

        #if os(iOS) && !targetEnvironment(simulator)
        var status = attempt(withAccessGroup: true)
        if status == -34018 { status = attempt(withAccessGroup: false) }
        #else
        let status = attempt(withAccessGroup: false)
        #endif

        guard status == errSecSuccess, let data = result as? Data else { return nil }

        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private func saveKeyToKeychain(_ key: Curve25519.KeyAgreement.PrivateKey) {
        let data = key.rawRepresentation

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]

        // Delete existing item first
        var deleteQuery = base
        deleteQuery.removeValue(forKey: kSecValueData as String)
        #if os(iOS) && !targetEnvironment(simulator)
        deleteQuery[kSecAttrAccessGroup as String] = accessGroup
        #endif
        SecItemDelete(deleteQuery as CFDictionary)

        // Add with access group, fallback on -34018
        func attempt(addAccessGroup: Bool) -> OSStatus {
            var query = base
            #if os(iOS) && !targetEnvironment(simulator)
            if addAccessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
            #endif
            return SecItemAdd(query as CFDictionary, nil)
        }

        #if os(iOS) && !targetEnvironment(simulator)
        var status = attempt(addAccessGroup: true)
        if status == -34018 { status = attempt(addAccessGroup: false) }
        #else
        let status = attempt(addAccessGroup: false)
        #endif

        if status != errSecSuccess {
            os_log(.error, "UnifiedIdentityManager: failed to save key to Keychain: %d", Int(status))
        }
    }
}
