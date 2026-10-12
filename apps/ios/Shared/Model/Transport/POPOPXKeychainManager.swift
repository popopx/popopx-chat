//
//  POPOPXKeychainManager.swift
//  POPOPX
//
//  Created to prevent BitchatMesh KeychainManager from interfering with POPOPX data.
//  This is a simplified wrapper that does NOT run install lifecycle reconciliation.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Security
import POPOPXSwitch

/// POPOPX-specific Keychain manager that avoids BitchatMesh's panic mode deletion.
/// BitchatMesh's KeychainManager runs reconcileInstallLifecycle() in init(), which
/// can detect a "reinstall" scenario and delete all keychain data including POPOPX's
/// database encryption key. This manager skips that logic entirely.
@MainActor
final class POPOPXKeychainManager {
    static let shared = POPOPXKeychainManager()

    private let service = "com.popopxchat.popopx"

    private init() {
        // Deliberately skip any install lifecycle reconciliation
        // POPOPX manages its own persistence via UserDefaults + KeyChain helpers
    }

    /// Save data without running any install lifecycle checks
    func save(data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            return SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess
        }
        return status == errSecSuccess
    }

    /// Retrieve data without running any install lifecycle checks
    func retrieve(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    /// Delete data
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
