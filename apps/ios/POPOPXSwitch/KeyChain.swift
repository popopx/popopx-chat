//
//  KeyChain.swift
//  POPOPXSwitch
//
//  Created by Evgeny on 04/09/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Security
import CryptoKit
import LocalAuthentication

private let ACCESS_POLICY: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
#if KEYCHAIN_ACCESS_GROUP
public let ACCESS_GROUP: String = KEYCHAIN_ACCESS_GROUP
#else
// Match entitlements: $(AppIdentifierPrefix)com.popopxchat.popopx
// On real devices, AppIdentifierPrefix = TeamID + "."
public let ACCESS_GROUP: String = {
    #if os(iOS) && !targetEnvironment(simulator)
    // Read from Info.plist if available, otherwise use hardcoded fallback
    if let teamID = Bundle.main.object(forInfoDictionaryKey: "TeamIdentifier") as? String,
       !teamID.isEmpty && teamID != "$(AppIdentifierPrefix)" {
        let accessGroup = "\(teamID).com.popopxchat.popopx"
        logger.info("KeyChain ACCESS_GROUP: computed from TeamIdentifier=\(teamID), result=\(accessGroup, privacy: .private)")
        return accessGroup
    }
    // Fallback: try to extract from bundle identifier
    let bundleID = Bundle.main.bundleIdentifier ?? "com.popopxchat.popopx"
    logger.warning("KeyChain ACCESS_GROUP: TeamIdentifier not found in Info.plist, using fallback=\(bundleID).com.popopxchat.popopx")
    // Bundle ID format: com.popopxchat.popopx (no team prefix in bundle ID itself)
    // For simulator or when team ID unavailable, use service name without prefix
    #endif
    return "com.popopxchat.popopx"
}()
#endif
private let SERVICE_NAME: String = "com.popopxchat.popopx"
private let DATABASE_PASSWORD_ITEM: String = "databasePassword"
private let DATABASE_SALT_ITEM: String = "databaseSalt"
private let APP_PASSWORD_ITEM: String = "appPassword"
private let SELF_DESTRUCT_PASSWORD_ITEM: String = "selfDestructPassword"
private let SOCKS_PROXY_ITEM: String = "networkSocksProxy"

public enum KeyChainError: Error {
    case notAvailableInSimulator
    case keychainOperationFailed(OSStatus)
}

#if targetEnvironment(simulator) && DEBUG
// NOTE: Keychain unavailable in simulator - use mock credentials only
#endif

public let kcDatabasePassword = KeyChainItem(forKey: DATABASE_PASSWORD_ITEM)
public let kcDatabaseSalt = KeyChainItem(forKey: DATABASE_SALT_ITEM)

public let kcAppPassword = KeyChainItem(forKey: APP_PASSWORD_ITEM)

public let kcSelfDestructPassword = KeyChainItem(forKey: SELF_DESTRUCT_PASSWORD_ITEM)

public let kcTrialStart = KeyChainItem(forKey: "monTrialStartKeychain")

public let kcSocksProxy = KeyChainItem(forKey: SOCKS_PROXY_ITEM)

public struct KeyChainItem {
    var forKey: String

    public func get() -> String? {
        getItemString(forKey: forKey)
    }

    public func getWithRetry() -> String? {
        if let result = getItemString(forKey: forKey) {
            return result
        }
        // Single retry with short delay to avoid blocking the calling thread
        let maxRetries = 1
        for attempt in 1...maxRetries {
            logger.warning("KeyChain getWithRetry: key [REDACTED] not found, retry \(attempt)/\(maxRetries)")
            usleep(100_000) // 0.1s — brief delay for keychain eventual consistency
            if let result = getItemString(forKey: forKey) {
                return result
            }
        }
        logger.error("KeyChain getWithRetry: key [REDACTED] unavailable after \(maxRetries + 1) attempts")
        return nil
    }

    public func set(_ value: String) -> Bool {
        do {
            try setItemString(value, forKey: forKey)
            return true
        } catch {
            logger.error("KeyChain set failed: \(error)")
            return false
        }
    }

    public func remove() -> Bool {
        deleteItem(forKey: forKey)
    }
}

func randomDatabasePassword() -> String? {
    var keyData = Data(count: 32)
    let status = keyData.withUnsafeMutableBytes {
        guard let base = $0.baseAddress else { return errSecParam }
        return SecRandomCopyBytes(kSecRandomDefault, 32, base)
    }
    if status == errSecSuccess {
        return keyData.base64EncodedString()
    } else {
        logger.error("randomDatabasePassword: error \(status)")
        return nil
    }
}

#if targetEnvironment(simulator) && DEBUG
// Simulator keychain: file-based persistence in app group container.
// UserDefaults(suiteName:) does not reliably persist across simulator re-launches,
// so we store each key as a separate .dat file in the shared app group directory.
private func _simKeychainFileURL(forKey key: String) -> URL? {
    guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.popopxchat.popopx") else {
        logger.error("KeyChain simulator: app group container unavailable")
        return nil
    }
    let dir = appGroupURL.appendingPathComponent("sim_keychain", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("\(key).dat")
}
#endif

private func getItemData(forKey key: String) throws -> Data {
    #if targetEnvironment(simulator) && DEBUG
    guard let fileURL = _simKeychainFileURL(forKey: key) else {
        return Data()
    }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        logger.debug("KeyChain simulator GET: key=\(key), result=NOT_FOUND")
        return Data()
    }
    guard let data = try? Data(contentsOf: fileURL) else {
        logger.debug("KeyChain simulator GET: key=\(key), result=READ_FAILED")
        return Data()
    }
    logger.debug("KeyChain simulator GET: key=\(key), dataLength=\(data.count)")
    return data
    #else
    var query = baseItemQuery(forKey: key)
    query[kSecMatchLimit] = kSecMatchLimitOne
    query[kSecReturnData] = true as AnyObject?

    #if os(iOS) && !targetEnvironment(simulator)
    logger.info("KeyChain GET: key=\(key), accessGroup=\(ACCESS_GROUP, privacy: .private)")
    #endif

    var dataRef: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
    if status == errSecSuccess {
        guard let dataRef = dataRef else {
            logger.error("KeyChain GET: success but dataRef is nil, key=\(key)")
            return Data()
        }
        let data = (dataRef as! CFData) as Data
        logger.info("KeyChain GET: success, key=\(key), dataLength=\(data.count)")
        return data
    }
    if status != errSecItemNotFound {
        logger.error("KeyChain GET: FAILED, key=\(key), status=\(status)")
    } else {
        logger.debug("KeyChain GET: item not found, key=\(key)")
    }
    return Data()
    #endif
}

private func getItemString(forKey key: String) -> String? {
    do {
        let data = try getItemData(forKey: key)
        guard !data.isEmpty else { return nil }
        return NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String
    } catch {
        logger.error("KeyChain getItemString failed: \(error)")
        return nil
    }
}

private func setItemData(_ data: Data, forKey key: String) throws {
    #if targetEnvironment(simulator) && DEBUG
    guard let fileURL = _simKeychainFileURL(forKey: key) else {
        throw KeyChainError.notAvailableInSimulator
    }
    try data.write(to: fileURL, options: .atomic)
    logger.debug("KeyChain simulator SET: key=\(key), dataLength=\(data.count), success=true")
    #else
    var query = baseItemQuery(forKey: key)
    query[kSecAttrAccessible] = ACCESS_POLICY
    query[kSecValueData] = data as CFData
    #if os(iOS) && !targetEnvironment(simulator)
    logger.info("KeyChain SET: key=\(key), accessGroup=\(ACCESS_GROUP, privacy: .private), policy=\(ACCESS_POLICY), dataLength=\(data.count)")
    #endif
    var status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecDuplicateItem {
        logger.debug("KeyChain SET: duplicate item found, deleting and re-adding")
        SecItemDelete(query as CFDictionary)
        status = SecItemAdd(query as CFDictionary, nil)
    }
    if status == errSecSuccess {
        logger.info("KeyChain SET: success, key=\(key)")
        return
    }
    logger.error("KeyChain SET: FAILED, key=\(key), status=\(status)")
    if status != errSecSuccess {
        #if targetEnvironment(simulator)
        throw KeyChainError.notAvailableInSimulator
        #else
        throw KeyChainError.keychainOperationFailed(status)
        #endif
    }
    #endif
}

private func setItemString(_ s: String, forKey key: String) throws {
    if let data = s.data(using: .utf8) {
        try setItemData(data, forKey: key)
    } else {
        throw KeyChainError.notAvailableInSimulator
    }
}

private func deleteItem(forKey key: String) -> Bool {
    #if targetEnvironment(simulator) && DEBUG
    guard let fileURL = _simKeychainFileURL(forKey: key) else {
        return false
    }
    try? FileManager.default.removeItem(at: fileURL)
    return true
    #else
    let query = baseItemQuery(forKey: key)
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
        logger.error("deleteItem: error deleting data for key [REDACTED], error: \(status)")
        return false
    }
    return true
    #endif
}

private func baseItemQuery(forKey key: String) -> [NSString : AnyObject] {
    var query = [NSString : AnyObject]()
    query[kSecClass] = kSecClassGenericPassword
    query[kSecAttrService] = SERVICE_NAME as AnyObject?
    query[kSecAttrAccount] = key as AnyObject?
    // Match upstream simplex-chat: explicitly set access group on real devices
    #if os(iOS) && !targetEnvironment(simulator)
    query[kSecAttrAccessGroup] = ACCESS_GROUP as AnyObject?
    #endif
    return query
}

// MARK: - Biometric-Protected Keychain Items

/// Store data protected by biometric authentication (Face ID / Touch ID).
/// The item is invalidated when the user enrolls a new biometric identity.
/// Requires `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` access level.
public func setBiometricProtected(_ data: Data, forKey key: String) throws {
    #if targetEnvironment(simulator) && DEBUG
    guard let fileURL = _simKeychainFileURL(forKey: "bio_\(key)") else {
        throw KeyChainError.notAvailableInSimulator
    }
    try data.write(to: fileURL, options: .atomic)
    #else
    var error: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
    ) else {
        logger.error("setBiometricProtected: SecAccessControlCreateWithFlags failed")
        throw KeyChainError.keychainOperationFailed(errSecParam)
    }

    var query = baseItemQuery(forKey: key)
    query[kSecValueData] = data as AnyObject
    query[kSecAttrAccessControl] = access

    var status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecDuplicateItem {
        SecItemDelete(query as CFDictionary)
        status = SecItemAdd(query as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
        logger.error("setBiometricProtected: SecItemAdd failed with status \(status)")
        throw KeyChainError.keychainOperationFailed(status)
    }
    #endif
}

/// Retrieve biometric-protected data. Prompts for biometric authentication.
public func getBiometricProtected(forKey key: String, prompt: String) -> Data? {
    #if targetEnvironment(simulator) && DEBUG
    guard let fileURL = _simKeychainFileURL(forKey: "bio_\(key)") else {
        return nil
    }
    return try? Data(contentsOf: fileURL)
    #else
    var query = baseItemQuery(forKey: key)
    query[kSecMatchLimit] = kSecMatchLimitOne
    query[kSecReturnData] = true as AnyObject?
    query[kSecAttrAccessControl] = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        nil
    ) as AnyObject
    let context = LAContext()
    context.localizedReason = prompt
    query[kSecUseAuthenticationContext] = context

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess else {
        if status != errSecUserCanceled {
            logger.error("getBiometricProtected: SecItemCopyMatching failed with status \(status)")
        }
        return nil
    }
    return result as? Data
    #endif
}
