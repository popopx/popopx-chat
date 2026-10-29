// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit
import OSLog
#if !POPOPXSwitch
import POPOPXSwitch
#endif

class CryptoEncrypt {
    static let shared = CryptoEncrypt()
    private let logger = Logger(subsystem: "im.popopx", category: "CryptoEncrypt")

    private let keychainService = "im.popopx.wallet"
    private let keychainAccount = "encryption.key"

    /// In-memory cache of the symmetric key to avoid repeated Keychain queries.
    private var cachedKey: SymmetricKey?
    private let cacheLock = NSLock()

    private init() {}

    /// Clear the in-memory key cache. Called when the app backgrounds or the key is rotated/deleted.
    func clearCache() {
        cacheLock.lock()
        cachedKey = nil
        cacheLock.unlock()
    }

    // Generate or retrieve symmetric key from Keychain, with in-memory caching
    private func getOrCreateKey() throws -> SymmetricKey {
        cacheLock.lock()
        if let cached = cachedKey {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Try to load existing key from Keychain
        if let keyData = loadKeyFromKeychain() {
            let key = SymmetricKey(data: keyData)
            cacheLock.lock()
            cachedKey = key
            cacheLock.unlock()
            return key
        }

        // Generate new key and try to save to Keychain
        let key = SymmetricKey(size: .bits256)
        var keyData = key.withUnsafeBytes { Data($0) }

        do {
            try saveKeyToKeychain(keyData)
        } catch {
            // Keychain unavailable (simulator entitlement -34018, etc.)
            // Zeroize keyData and fall back to deterministic key
            keyData.withUnsafeMutableBytes { ptr in
                if let base = ptr.baseAddress, ptr.count > 0 {
                    memset(base, 0, ptr.count)
                }
            }
            logger.warning("Keychain unavailable (\(error)), using fallback key")
            let fallback = simulatorFallbackKey()
            cacheLock.lock()
            cachedKey = fallback
            cacheLock.unlock()
            return fallback
        }

        cacheLock.lock()
        cachedKey = key
        cacheLock.unlock()

        return key
    }

    /// Deterministic key derivation fallback when Keychain is unavailable.
    /// WARNING: NOT secure — only for simulator/testing environments.
    private func simulatorFallbackKey() -> SymmetricKey {
        let seed = "im.popopx.fallback." + (Bundle.main.bundleIdentifier ?? "unknown")
        let hash = SHA256.hash(data: Data(seed.utf8))
        return SymmetricKey(data: hash)
    }

    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }

        return combined
    }

    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Keychain Operations

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: ACCESS_GROUP,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            return nil
        }

        return keyData
    }

    private func saveKeyToKeychain(_ keyData: Data) throws {
        // Delete existing key if present
        deleteKeyFromKeychain()

        // Clear in-memory cache so the next read picks up the new key
        clearCache()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: ACCESS_GROUP,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CryptoError.keychainError(status)
        }
    }

    private func deleteKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]

        SecItemDelete(query as CFDictionary)
    }

    func deleteKey() {
        deleteKeyFromKeychain()
        clearCache()
    }
}

enum CryptoError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return NSLocalizedString("needle_encrypt_failed", comment: "Encryption failed")
        case .decryptionFailed:
            return NSLocalizedString("needle_decrypt_failed", comment: "Decryption failed")
        case .keychainError(let status):
            return String(format: NSLocalizedString("needle_keychain_error", comment: "Keychain error"), status)
        }
    }
}
