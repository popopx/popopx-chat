//
//  API.swift
//  POPOPX NSE
//
//  Created by Evgeny on 26/04/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import Foundation
import os

// MARK: - Corrupt DB Backup Helpers

private func backupPathForCorruptDB(_ path: String, timestamp: TimeInterval) -> String {
    return path + ".corrupt.\(Int(timestamp))"
}

private func backupCorruptFile(_ path: String, to backupPath: String, fm: FileManager) {
    if fm.fileExists(atPath: path) {
        do {
            try fm.moveItem(atPath: path, toPath: backupPath)
        } catch {
            os_log(.error, "chatMigrateInit: failed to backup corrupt db file %{public}@: %{public}@", path, String(describing: error))
        }
    }
}

private func cleanupCorruptDBBackups(_ dbPath: String, timestamp: TimeInterval) {
    let fm = FileManager.default
    for suffix in [CHAT_DB, AGENT_DB, CHAT_DB_BAK, AGENT_DB_BAK] {
        let backupPath = backupPathForCorruptDB(dbPath + suffix, timestamp: timestamp)
        if fm.fileExists(atPath: backupPath) {
            try? fm.removeItem(atPath: backupPath)
        }
    }
}

private var chatController: chat_ctrl?

private var migrationResult: (Bool, DBMigrationResult)?

private extension NSLock {
    func sync<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}

private let chatControllerLock = NSLock()
private var isInitializing = false
private let initSemaphore = DispatchSemaphore(value: 0)

/// Must be called while chatControllerLock is held.
private func finishInitializing() {
    isInitializing = false
    initSemaphore.signal()
}

public func hasChatCtrl() -> Bool {
    chatControllerLock.sync { chatController != nil }
}

public func getChatCtrl() -> chat_ctrl? {
    chatControllerLock.sync { chatController }
}

private func zeroize(_ buffer: inout [CChar]) {
    guard !buffer.isEmpty else { return }
    _ = buffer.withUnsafeMutableBytes {
        memset_s($0.baseAddress, $0.count, 0, $0.count)
    }
}

/// Heap-allocated byte buffer with guaranteed zeroization on deinit.
/// Use for sensitive data (passphrases, keys) to minimize memory exposure.
final class SecureData {
    private var ptr: UnsafeMutablePointer<UInt8>
    private let length: Int

    init?(data: Data) {
        guard !data.isEmpty else { return nil }
        length = data.count
        ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        data.copyBytes(to: ptr, count: length)
    }

    convenience init?(string: String) {
        guard let data = string.data(using: .utf8) else { return nil }
        self.init(data: data)
    }

    deinit {
        memset_s(ptr, length, 0, length)
        ptr.deinitialize(count: length)
        ptr.deallocate()
    }

    var count: Int { length }

    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeRawBufferPointer(start: ptr, count: length))
    }

    func withUnsafeMutableBytes<T>(_ body: (UnsafeMutableRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeMutableRawBufferPointer(start: ptr, count: length))
    }
}

/// Executes a closure with a temporary C string copy of a sensitive string,
/// then zeroizes the C string buffer immediately after the closure returns.
private func withSecureCString<T>(_ string: String, _ body: (inout [CChar]) throws -> T) rethrows -> T {
    var cString = string.cString(using: .utf8) ?? []
    defer { zeroize(&cString) }
    return try body(&cString)
}

public func chatMigrateInit(_ useKey: String? = nil, confirmMigrations: MigrationConfirmation? = nil, backgroundMode: Bool = false) -> (Bool, DBMigrationResult) {
    if let res = chatControllerLock.sync({ migrationResult }) { return res }
    if chatControllerLock.sync({ isInitializing }) {
        let result = initSemaphore.wait(timeout: .now() + 10)
        if let res = chatControllerLock.sync({ migrationResult }) { return res }
        if result == .success {
            if let res = chatControllerLock.sync({ migrationResult }) { return res }
        }
    }
    let claimed: Bool = chatControllerLock.sync {
        if migrationResult != nil { return false }
        if isInitializing { return false }
        isInitializing = true
        return true
    }
    if !claimed {
        if let res = chatControllerLock.sync({ migrationResult }) { return res }
        return (false, .errorNotADatabase(dbFile: getAppDatabasePath().path))
    }
    let dbPath = getAppDatabasePath().path
    let fm = FileManager.default
    let chatDbPath = dbPath + CHAT_DB
    let agentDbPath = dbPath + AGENT_DB

    let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_NAME)
    logger.info("chatMigrateInit: appGroup=\(APP_GROUP_NAME, privacy: .private), groupURL=\(groupURL?.path ?? "NIL", privacy: .private), dbContainer=\(dbContainerGroupDefault.get().rawValue, privacy: .private)")
    logger.info("chatMigrateInit: dbPath=.../\(URL(fileURLWithPath: dbPath).lastPathComponent)")

    // Ensure the database directory exists (critical for fresh installs)
    let dbDirectory = (dbPath as NSString).deletingLastPathComponent
    if !fm.fileExists(atPath: dbDirectory) {
        logger.info("chatMigrateInit: database directory does not exist, creating: \(dbDirectory, privacy: .private)")
        do {
            try fm.createDirectory(atPath: dbDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("chatMigrateInit: failed to create database directory: \(error)")
            chatControllerLock.sync { finishInitializing() }
            return (false, .errorNotADatabase(dbFile: dbPath))
        }
    }

    let hasDB = hasDatabase()

    // CRITICAL FIX: On fresh install (!hasDB), ensure NO database files exist before FFI call.
    // SQLCipher fails with ErrorCorrupt if it tries to initialize a file that already exists
    // but is empty/corrupt from a previous crashed initialization.
    let corruptDBTimestamp = Date().timeIntervalSince1970
    if !hasDB {
        logger.info("chatMigrateInit: fresh install detected, cleaning up any leftover files")
        for path in [chatDbPath, agentDbPath, dbPath + CHAT_DB_BAK, dbPath + AGENT_DB_BAK,
                     chatDbPath + "-wal", chatDbPath + "-shm",
                     agentDbPath + "-wal", agentDbPath + "-shm"] {
            if fm.fileExists(atPath: path) {
                let attrs = try? fm.attributesOfItem(atPath: path)
                let size = attrs?[.size] as? Int64 ?? -1
                logger.warning("chatMigrateInit: removing leftover file \(path) (size=\(size))")
                let backupPath = backupPathForCorruptDB(path, timestamp: corruptDBTimestamp)
                backupCorruptFile(path, to: backupPath, fm: fm)
                try? fm.removeItem(atPath: path)
            }
        }
    } else if fm.fileExists(atPath: chatDbPath) || fm.fileExists(atPath: agentDbPath) {
        logger.warning("chatMigrateInit: partial database detected (chat=\(fm.fileExists(atPath: chatDbPath)), agent=\(fm.fileExists(atPath: agentDbPath))), deleting before retry")
        for path in [chatDbPath, agentDbPath, dbPath + CHAT_DB_BAK, dbPath + AGENT_DB_BAK,
                     chatDbPath + "-wal", chatDbPath + "-shm",
                     agentDbPath + "-wal", agentDbPath + "-shm"] {
            if fm.fileExists(atPath: path) {
                let backupPath = backupPathForCorruptDB(path, timestamp: corruptDBTimestamp)
                backupCorruptFile(path, to: backupPath, fm: fm)
                // Also delete the original to ensure clean state for FFI
                try? fm.removeItem(atPath: path)
                logger.info("chatMigrateInit: removed partial file \(path)")
            }
        }
    }

    let chatDbExists = fm.fileExists(atPath: chatDbPath)
    let agentDbExists = fm.fileExists(atPath: agentDbPath)
    var chatDbSize: Int64 = 0
    if chatDbExists {
        do {
            chatDbSize = try fm.attributesOfItem(atPath: chatDbPath)[.size] as? Int64 ?? 0
        } catch {
            logger.error("chatMigrateInit: failed to get chat.db size: \(error)")
        }
    }
    var agentDbSize: Int64 = 0
    if agentDbExists {
        do {
            agentDbSize = try fm.attributesOfItem(atPath: agentDbPath)[.size] as? Int64 ?? 0
        } catch {
            logger.error("chatMigrateInit: failed to get agent.db size: \(error)")
        }
    }

    logger.info("chatMigrateInit: dbPath=.../\(URL(fileURLWithPath: dbPath).lastPathComponent)")
    logger.info("chatMigrateInit: hasDatabase=\(hasDB)")
    logger.info("chatMigrateInit: chat.db exists=\(chatDbExists), size=\(chatDbSize)")
    logger.info("chatMigrateInit: agent.db exists=\(agentDbExists), size=\(agentDbSize)")

    // Validate database integrity: detect zero-sized or corrupt databases from interrupted migrations
    if chatDbExists && chatDbSize == 0 {
        logger.error("chatMigrateInit: chat.db is zero-sized (previous migration interrupted), backing up")
        backupCorruptFile(chatDbPath, to: backupPathForCorruptDB(chatDbPath, timestamp: corruptDBTimestamp), fm: fm)
        backupCorruptFile(dbPath + CHAT_DB_BAK, to: backupPathForCorruptDB(dbPath + CHAT_DB_BAK, timestamp: corruptDBTimestamp), fm: fm)
        // Also clean up WAL and SHM files
        try? fm.removeItem(atPath: chatDbPath + "-wal")
        try? fm.removeItem(atPath: chatDbPath + "-shm")
        if agentDbExists && agentDbSize > 0 && agentDbSize < 4096 {
            logger.warning("chatMigrateInit: agent.db is also suspiciously small (\(agentDbSize) bytes), backing up")
            backupCorruptFile(agentDbPath, to: backupPathForCorruptDB(agentDbPath, timestamp: corruptDBTimestamp), fm: fm)
            backupCorruptFile(dbPath + AGENT_DB_BAK, to: backupPathForCorruptDB(dbPath + AGENT_DB_BAK, timestamp: corruptDBTimestamp), fm: fm)
            try? fm.removeItem(atPath: agentDbPath + "-wal")
            try? fm.removeItem(atPath: agentDbPath + "-shm")
        }
    } else if agentDbExists && agentDbSize == 0 {
        logger.error("chatMigrateInit: agent.db is zero-sized (previous migration interrupted), backing up")
        backupCorruptFile(agentDbPath, to: backupPathForCorruptDB(agentDbPath, timestamp: corruptDBTimestamp), fm: fm)
        backupCorruptFile(dbPath + AGENT_DB_BAK, to: backupPathForCorruptDB(dbPath + AGENT_DB_BAK, timestamp: corruptDBTimestamp), fm: fm)
        try? fm.removeItem(atPath: agentDbPath + "-wal")
        try? fm.removeItem(atPath: agentDbPath + "-shm")
        if chatDbExists && chatDbSize > 0 && chatDbSize < 4096 {
            logger.warning("chatMigrateInit: chat.db is also suspiciously small (\(chatDbSize) bytes), backing up")
            backupCorruptFile(chatDbPath, to: backupPathForCorruptDB(chatDbPath, timestamp: corruptDBTimestamp), fm: fm)
            backupCorruptFile(dbPath + CHAT_DB_BAK, to: backupPathForCorruptDB(dbPath + CHAT_DB_BAK, timestamp: corruptDBTimestamp), fm: fm)
            try? fm.removeItem(atPath: chatDbPath + "-wal")
            try? fm.removeItem(atPath: chatDbPath + "-shm")
        }
    } else if chatDbExists && chatDbSize > 0 && chatDbSize < 4096 {
        logger.error("chatMigrateInit: chat.db is suspiciously small (\(chatDbSize) bytes), possible corruption from interrupted migration, backing up")
        backupCorruptFile(chatDbPath, to: backupPathForCorruptDB(chatDbPath, timestamp: corruptDBTimestamp), fm: fm)
        backupCorruptFile(dbPath + CHAT_DB_BAK, to: backupPathForCorruptDB(dbPath + CHAT_DB_BAK, timestamp: corruptDBTimestamp), fm: fm)
        try? fm.removeItem(atPath: chatDbPath + "-wal")
        try? fm.removeItem(atPath: chatDbPath + "-shm")
        if agentDbExists && agentDbSize < 4096 {
            backupCorruptFile(agentDbPath, to: backupPathForCorruptDB(agentDbPath, timestamp: corruptDBTimestamp), fm: fm)
            backupCorruptFile(dbPath + AGENT_DB_BAK, to: backupPathForCorruptDB(dbPath + AGENT_DB_BAK, timestamp: corruptDBTimestamp), fm: fm)
            try? fm.removeItem(atPath: agentDbPath + "-wal")
            try? fm.removeItem(atPath: agentDbPath + "-shm")
        }
    }

    var dbKey = ""
    let useKeychain = storeDBPassphraseGroupDefault.get()
    logger.debug("chatMigrateInit uses keychain: \(useKeychain)")

    if let key = useKey {
        dbKey = key
    } else if useKeychain {
        if !hasDatabase() {
            logger.info("chatMigrateInit: fresh install - generating random DB key")
            guard let randomKey = randomDatabasePassword() else {
                logger.error("chatMigrateInit: failed to generate random DB password")
                chatControllerLock.sync { finishInitializing() }
                return (false, .errorNotADatabase(dbFile: dbPath))
            }
            dbKey = randomKey
            initialRandomDBPassphraseGroupDefault.set(true)
            // FIX: Write key to Keychain immediately after generation, before FFI call
            // This ensures the key is persisted even if FFI fails with ErrorCorrupt
            logger.info("chatMigrateInit: writing key to Keychain before FFI call")
            _ = kcDatabasePassword.remove()
            _ = kcDatabaseSalt.remove()
            guard kcDatabasePassword.set(dbKey) else {
                logger.error("chatMigrateInit: CRITICAL - failed to write key to Keychain before FFI call")
                chatControllerLock.sync { finishInitializing() }
                return (false, .errorKeychain)
            }
            logger.info("chatMigrateInit: key successfully written to Keychain")
        } else if let storedKey = kcDatabasePassword.getWithRetry() {
            if let salt = kcDatabaseSalt.get() {
                logger.debug("chatMigrateInit: deriving key from stored passphrase")
                if let derived = deriveKey(from: storedKey, salt: Data(base64Encoded: salt)) {
                    dbKey = derived.key
                } else {
                    logger.error("chatMigrateInit: PBKDF2 derivation failed, cannot open encrypted database")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorNotADatabase(dbFile: dbPath))
                }
            } else {
                dbKey = storedKey
            }
        } else {
            logger.error("chatMigrateInit: database exists but encryption key not found in Keychain")
            let wasRandomPassphrase = initialRandomDBPassphraseGroupDefault.get()
            if wasRandomPassphrase {
                logger.warning("chatMigrateInit: DB was encrypted with auto-generated random key that is no longer in Keychain (likely lost due to app crash between DB creation and keychain write). Cleaning up orphaned DB and starting fresh.")
                try? fm.removeItem(atPath: chatDbPath)
                try? fm.removeItem(atPath: agentDbPath)
                try? fm.removeItem(atPath: dbPath + CHAT_DB_BAK)
                try? fm.removeItem(atPath: dbPath + AGENT_DB_BAK)
                // Reset onboarding stage since DB is being recreated fresh
                // This prevents app from being stuck on "Opening app..." when onboardingStage is .onboardingComplete but DB has no user
                UserDefaults.standard.set("step1_WelcomeIdentity", forKey: "onboardingStage")
                logger.info("chatMigrateInit: reset onboarding to step1 due to orphaned DB cleanup")
                guard let randomKey = randomDatabasePassword() else {
                    logger.error("chatMigrateInit: failed to generate random DB password for fresh start")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorNotADatabase(dbFile: dbPath))
                }
                dbKey = randomKey
                initialRandomDBPassphraseGroupDefault.set(true)
            } else {
                logger.error("chatMigrateInit: user passphrase lost - keychain inaccessible after abnormal exit")
                chatControllerLock.sync { finishInitializing() }
                return (false, .errorKeychain)
            }
        }
    }

    let confirm = confirmMigrations ?? defaultMigrationConfirmation()
    logger.info("chatMigrateInit: preparing FFI call - dbPath=.../\(URL(fileURLWithPath: dbPath).lastPathComponent), confirm=\(confirm.rawValue), keyLength=\(dbKey.count), dbExists=\(hasDB)")
    logger.debug("chatMigrateInit DB path: .../\(URL(fileURLWithPath: dbPath).lastPathComponent), confirm: \(confirm.rawValue)")
    guard var cPath = dbPath.cString(using: .utf8),
          var cConfirm = confirm.rawValue.cString(using: .utf8) else {
        logger.error("chatMigrateInit: string encoding failed")
        chatControllerLock.sync { finishInitializing() }
        return (false, .errorNotADatabase(dbFile: dbPath))
    }
    var newController: chat_ctrl? = nil
    // Use SecureData for key bytes to avoid CString conversion
    guard let keyData = SecureData(string: dbKey) else {
        logger.error("chatMigrateInit: failed to create SecureData for key")
        zeroize(&cPath); zeroize(&cConfirm)
        chatControllerLock.sync { finishInitializing() }
        return (false, .errorNotADatabase(dbFile: dbPath))
    }
    logger.info("chatMigrateInit: calling FFI chat_migrate_init_key_bytes with keyLength=\(keyData.count)")
    let cjson: UnsafeMutablePointer<CChar>? = keyData.withUnsafeBytes { keyPtr in
        let keyLen = Int32(keyPtr.count)
        return keyPtr.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: Int(keyLen)) { keyBytes in
            chat_migrate_init_key_bytes(&cPath, UnsafeMutablePointer(mutating: keyBytes), keyLen, 1, &cConfirm, backgroundMode ? 1 : 0, &newController)
        }
    }
    zeroize(&cPath); zeroize(&cConfirm)
    guard let cjson else {
        logger.error("chatMigrateInit: chat_migrate_init_key_bytes returned null, dbPath=\(dbPath, privacy: .private), keyEmpty=\(dbKey.isEmpty, privacy: .private), background=\(backgroundMode, privacy: .private)")
        chatControllerLock.sync { finishInitializing() }
        return (false, .errorNotADatabase(dbFile: dbPath))
    }
    let dbRes = dbMigrationResult(dataFromCString(cjson))
    let encrypted = dbKey != ""
    logger.info("chatMigrateInit: FFI result - dbRes=\(String(describing: dbRes)), controllerSet=\(newController != nil)")

    // Recovery: if FFI reports errorNotADatabase but DB files exist with valid sizes,
    // the database is likely corrupted from abrupt termination (WAL not checkpointed).
    // For auto-generated random passphrases, clean up and retry with a fresh key.
    if case .errorNotADatabase = dbRes, hasDB, useKeychain {
        let wasRandomPassphrase = initialRandomDBPassphraseGroupDefault.get()
        if wasRandomPassphrase {
            logger.warning("chatMigrateInit: DB appears corrupted (errorNotADatabase) despite valid file sizes. Likely WAL corruption from abrupt termination. Backing up corrupt files and retrying with fresh key.")
            for path in [chatDbPath, agentDbPath, dbPath + CHAT_DB_BAK, dbPath + AGENT_DB_BAK,
                         chatDbPath + "-wal", chatDbPath + "-shm",
                         agentDbPath + "-wal", agentDbPath + "-shm"] {
                let bp = backupPathForCorruptDB(path, timestamp: corruptDBTimestamp)
                backupCorruptFile(path, to: bp, fm: fm)
            }
            if let freshKey = randomDatabasePassword() {
                dbKey = freshKey
                initialRandomDBPassphraseGroupDefault.set(true)
                guard var cPath2 = dbPath.cString(using: .utf8),
                      var cConfirm2 = confirm.rawValue.cString(using: .utf8) else {
                    logger.error("chatMigrateInit: retry string encoding failed")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorNotADatabase(dbFile: dbPath))
                }
                guard let retryKeyData = SecureData(string: dbKey) else {
                    logger.error("chatMigrateInit: retry failed to create SecureData for key")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorNotADatabase(dbFile: dbPath))
                }
                let cjson2: UnsafeMutablePointer<CChar>? = retryKeyData.withUnsafeBytes { keyPtr in
                    let keyLen = Int32(keyPtr.count)
                    return keyPtr.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: Int(keyLen)) { keyBytes in
                        chat_migrate_init_key_bytes(&cPath2, UnsafeMutablePointer(mutating: keyBytes), keyLen, 1, &cConfirm2, backgroundMode ? 1 : 0, &newController)
                    }
                }
                zeroize(&cPath2); zeroize(&cConfirm2)
                guard let cjson2 else {
                    logger.error("chatMigrateInit: retry FFI call also returned null")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorNotADatabase(dbFile: dbPath))
                }
                let dbRes2 = dbMigrationResult(dataFromCString(cjson2))
                logger.info("chatMigrateInit: retry FFI result - dbRes=\(String(describing: dbRes2))")
                if dbRes2 == .ok {
                    let chatCreated = fm.fileExists(atPath: chatDbPath)
                    let agentCreated = fm.fileExists(atPath: agentDbPath)
                    if !chatCreated || !agentCreated {
                        logger.error("chatMigrateInit: retry FFI ok but files missing")
                        chatControllerLock.sync { finishInitializing() }
                        return (false, .errorSQL(dbFile: "chat.db or agent.db", migrationSQLError: "Database files not created by FFI on retry"))
                    }
                    excludeFromBackup(URL(fileURLWithPath: chatDbPath))
                    excludeFromBackup(URL(fileURLWithPath: agentDbPath))
                    // Remove corrupt DB backups now that retry succeeded
                    cleanupCorruptDBBackups(dbPath, timestamp: corruptDBTimestamp)
                    _ = kcDatabasePassword.remove()
                    _ = kcDatabaseSalt.remove()
                    let keychainWriteFailed = useKeychain && !kcDatabasePassword.set(dbKey)
                    dbKey = ""
                    if keychainWriteFailed {
                        if let ctrl = newController { _ = chat_close_store(ctrl) }
                        try? fm.removeItem(atPath: chatDbPath)
                        try? fm.removeItem(atPath: agentDbPath)
                        chatControllerLock.sync { finishInitializing() }
                        return (false, .errorKeychain)
                    }
                    let result = (true, dbRes2)
                    chatControllerLock.sync {
                        chatController = newController
                        migrationResult = result
                        finishInitializing()
                    }
                    return result
                }
            }
        }
    }

    // Recovery: if FFI reports errorSQL on a fresh install (!hasDB) but partial DB files
    // exist from a previous crashed run, clean them up and retry. The FFI can fail with
    // ErrorCorrupt when trying to CREATE TABLE over a partial/zero-length DB file.
    if case .errorSQL = dbRes, !hasDB, useKeychain {
        let partialFilesExist = fm.fileExists(atPath: chatDbPath) || fm.fileExists(atPath: agentDbPath)
        if partialFilesExist {
            logger.warning("chatMigrateInit: errorSQL on fresh install with partial DB files (chat=\(fm.fileExists(atPath: chatDbPath)), agent=\(fm.fileExists(atPath: agentDbPath))). Cleaning up and retrying.")
            for path in [chatDbPath, agentDbPath,
                         chatDbPath + "-wal", chatDbPath + "-shm",
                         agentDbPath + "-wal", agentDbPath + "-shm"] {
                if fm.fileExists(atPath: path) {
                    let bp = backupPathForCorruptDB(path, timestamp: corruptDBTimestamp)
                    backupCorruptFile(path, to: bp, fm: fm)
                    // CRITICAL: Also delete original to ensure FFI sees clean state
                    try? fm.removeItem(atPath: path)
                }
            }
            if let freshKey = randomDatabasePassword() {
                dbKey = freshKey
                initialRandomDBPassphraseGroupDefault.set(true)
                // FIX: Write key to Keychain immediately, before retry FFI call
                logger.info("chatMigrateInit: writing fresh key to Keychain before retry")
                _ = kcDatabasePassword.remove()
                _ = kcDatabaseSalt.remove()
                guard kcDatabasePassword.set(dbKey) else {
                    logger.error("chatMigrateInit: CRITICAL - failed to write fresh key to Keychain before retry")
                    // Clean up corrupt files even if keychain write failed
                    try? fm.removeItem(atPath: chatDbPath)
                    try? fm.removeItem(atPath: agentDbPath)
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorKeychain)
                }
                logger.info("chatMigrateInit: fresh key successfully written to Keychain")
                guard var cPath2 = dbPath.cString(using: .utf8),
                      var cConfirm2 = confirm.rawValue.cString(using: .utf8) else {
                    logger.error("chatMigrateInit: retry string encoding failed")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorSQL(dbFile: dbPath, migrationSQLError: "Retry string encoding failed"))
                }
                guard let retryKeyData2 = SecureData(string: dbKey) else {
                    logger.error("chatMigrateInit: errorSQL retry failed to create SecureData for key")
                    chatControllerLock.sync { finishInitializing() }
                    return (false, .errorSQL(dbFile: dbPath, migrationSQLError: "Retry SecureData creation failed"))
                }
                let cjson2: UnsafeMutablePointer<CChar>? = retryKeyData2.withUnsafeBytes { keyPtr in
                    let keyLen = Int32(keyPtr.count)
                    return keyPtr.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: Int(keyLen)) { keyBytes in
                        chat_migrate_init_key_bytes(&cPath2, UnsafeMutablePointer(mutating: keyBytes), keyLen, 1, &cConfirm2, backgroundMode ? 1 : 0, &newController)
                    }
                }
                zeroize(&cPath2); zeroize(&cConfirm2)
                if let cjson2 {
                    let dbRes2 = dbMigrationResult(dataFromCString(cjson2))
                    logger.info("chatMigrateInit: retry FFI result - dbRes=\(String(describing: dbRes2))")
                    if dbRes2 == .ok {
                        let chatCreated = fm.fileExists(atPath: chatDbPath)
                        let agentCreated = fm.fileExists(atPath: agentDbPath)
                        if !chatCreated || !agentCreated {
                            logger.error("chatMigrateInit: retry FFI ok but files missing")
                            chatControllerLock.sync { finishInitializing() }
                            return (false, .errorSQL(dbFile: dbPath, migrationSQLError: "Database files not created by FFI on retry"))
                        }
                        excludeFromBackup(URL(fileURLWithPath: chatDbPath))
                        excludeFromBackup(URL(fileURLWithPath: agentDbPath))
                        cleanupCorruptDBBackups(dbPath, timestamp: corruptDBTimestamp)
                        dbKey = ""
                        let result = (true, dbRes2)
                        chatControllerLock.sync {
                            chatController = newController
                            migrationResult = result
                            finishInitializing()
                        }
                        return result
                    } else {
                        // FIX: If retry failed, clean up corrupt database files
                        // Key is already in Keychain, so next launch can retry with same key
                        logger.warning("chatMigrateInit: retry FFI failed with dbRes=\(String(describing: dbRes2)). Cleaning up corrupt files for next attempt.")
                        for path in [chatDbPath, agentDbPath,
                                     chatDbPath + "-wal", chatDbPath + "-shm",
                                     agentDbPath + "-wal", agentDbPath + "-shm"] {
                            if fm.fileExists(atPath: path) {
                                try? fm.removeItem(atPath: path)
                                logger.info("chatMigrateInit: removed corrupt file \(path)")
                            }
                        }
                    }
                } else {
                    logger.error("chatMigrateInit: retry FFI call returned null")
                }
            }
        }
    }

    // Verify both database files were created on success
    if dbRes == .ok {
        let chatCreated = fm.fileExists(atPath: chatDbPath)
        let agentCreated = fm.fileExists(atPath: agentDbPath)
        logger.info("chatMigrateInit: post-init verification - chat.db exists=\(chatCreated), agent.db exists=\(agentCreated)")
        if !chatCreated || !agentCreated {
            logger.error("chatMigrateInit: FFI returned ok but database files missing! chat=\(chatCreated), agent=\(agentCreated)")
            // Fail fast to prevent data corruption from operating with missing databases
            chatControllerLock.sync { finishInitializing() }
            return (false, .errorSQL(dbFile: "chat.db or agent.db", migrationSQLError: "Database files not created by FFI"))
        }
        excludeFromBackup(URL(fileURLWithPath: chatDbPath))
        excludeFromBackup(URL(fileURLWithPath: agentDbPath))
        // Remove corrupt DB backups now that new DB opened successfully
        cleanupCorruptDBBackups(dbPath, timestamp: corruptDBTimestamp)
    }

    // FIX 1: Key was already written to Keychain before FFI call (see line ~243).
    // This block now only verifies the key is still in Keychain and logs the status.
    // On subsequent launches, dbKey is a derived key — writing it back would overwrite
    // the original passphrase, causing decryption failure on the next launch.
    var keychainWriteFailed = false
    if dbRes == .ok && useKeychain && encrypted && !hasDB {
        // Key was already written before FFI call, just verify it's still there
        if kcDatabasePassword.get() == nil {
            logger.error("chatMigrateInit: CRITICAL - key missing from Keychain after successful FFI call!")
            keychainWriteFailed = true
        } else {
            logger.info("chatMigrateInit: DB key verified in Keychain after successful FFI call")
        }
    }
    dbKey = ""

    if keychainWriteFailed {
        logger.error("chatMigrateInit: CRITICAL - database created but keychain write failed, cleaning up orphaned databases")
        if let ctrl = newController {
            _ = chat_close_store(ctrl)
        }
        do { try fm.removeItem(atPath: chatDbPath) } catch { logger.error("chatMigrateInit: failed to remove orphaned chat.db: \(error)") }
        do { try fm.removeItem(atPath: agentDbPath) } catch { logger.error("chatMigrateInit: failed to remove orphaned agent.db: \(error)") }
        chatControllerLock.sync { finishInitializing() }
        return (false, .errorKeychain)
    } else if dbRes == .ok && useKeychain && encrypted && !hasDB {
        logger.info("chatMigrateInit: DB key successfully written to Keychain on first launch")
    }
    
    let result = (encrypted, dbRes)
    chatControllerLock.sync {
        chatController = newController
        migrationResult = result
        finishInitializing()
    }
    return result
}

public func chatInitTemporaryDatabase(url: URL, key: String? = nil, confirmation: MigrationConfirmation = .error) -> (DBMigrationResult, chat_ctrl?) {
    let dbPath = url.path
    guard let dbKey = key ?? randomDatabasePassword() else {
        logger.error("chatInitTemporaryDatabase: failed to generate random DB password")
        return (.errorNotADatabase(dbFile: dbPath), nil)
    }
    logger.debug("chatInitTemporaryDatabase path: \(dbPath)")
    var temporaryController: chat_ctrl? = nil
    guard var cPath = dbPath.cString(using: .utf8),
          var cConfirm = confirmation.rawValue.cString(using: .utf8) else {
        return (.errorNotADatabase(dbFile: dbPath), nil)
    }
    var cKey = dbKey.cString(using: .utf8)!
    let cjson = chat_migrate_init_key(&cPath, &cKey, 1, &cConfirm, 0, &temporaryController)
    zeroize(&cPath); zeroize(&cConfirm)
    guard let cjson else {
        return (.errorNotADatabase(dbFile: dbPath), nil)
    }
    return (dbMigrationResult(dataFromCString(cjson)), temporaryController)
}

public func chatInitControllerRemovingDatabases() {
    let dbPath = getAppDatabasePath().path
    let fm = FileManager.default
    // Remove previous databases, otherwise, can be .errorNotADatabase with nil controller
    do { try fm.removeItem(atPath: dbPath + CHAT_DB) } catch { logger.error("Failed to remove chat DB: \(error)") }
    do { try fm.removeItem(atPath: dbPath + AGENT_DB) } catch { logger.error("Failed to remove agent DB: \(error)") }

    guard let dbKey = randomDatabasePassword() else {
        logger.error("chatInitControllerRemovingDatabases: failed to generate random DB password")
        return
    }
    logger.debug("chatInitControllerRemovingDatabases path: \(dbPath)")
    guard var cPath = dbPath.cString(using: .utf8),
          var cConfirm = MigrationConfirmation.error.rawValue.cString(using: .utf8) else {
        logger.error("chatInitControllerRemovingDatabases: string encoding failed")
        return
    }
    var newController: chat_ctrl? = nil
    var cKey = dbKey.cString(using: .utf8)!
    let cjson = chat_migrate_init_key(&cPath, &cKey, 1, &cConfirm, 0, &newController)
    if let cjson {
        free(cjson)
    }
    zeroize(&cPath); zeroize(&cConfirm)
    chatControllerLock.sync { chatController = newController }

    // We need only controller, not databases
    do { try fm.removeItem(atPath: dbPath + CHAT_DB) } catch { logger.error("Failed to remove chat DB: \(error)") }
    do { try fm.removeItem(atPath: dbPath + AGENT_DB) } catch { logger.error("Failed to remove agent DB: \(error)") }
}

/// Checks if database key rotation is needed and triggers it
/// Key rotation requires stopping the chat and re-encrypting with a new key
/// - Returns: true if rotation was initiated
public func checkAndRotateDatabaseKeyIfNeeded() -> Bool {
    guard KeyRotationManager.shared.shouldRotate() else {
        return false
    }

    logger.debug("checkAndRotateDatabaseKeyIfNeeded: rotation needed, notifying user")

    // Store a flag that rotation is needed
    UserDefaults.standard.set(true, forKey: "databaseKeyRotationNeeded")

    // The actual rotation will be handled by the UI when user changes passphrase
    // See DatabaseEncryptionView.encryptDatabaseAsync()
    return true
}

/// Performs the actual key rotation after database is re-encrypted with new key
/// - Parameters:
///   - newPassphrase: The new passphrase
///   - salt: The salt used for key derivation
public func completeKeyRotation(newPassphrase: String, salt: String) {
    // Save the old passphrase in case we need to roll back
    let oldPassphrase = kcDatabasePassword.get()
    let oldSalt = kcDatabaseSalt.get()

    // Update Keychain with new passphrase and salt
    guard kcDatabasePassword.set(newPassphrase) else {
        logger.error("completeKeyRotation: failed to save new passphrase to Keychain")
        return
    }

    guard kcDatabaseSalt.set(salt) else {
        logger.error("completeKeyRotation: failed to save salt to Keychain, rolling back passphrase")
        // Roll back the passphrase to maintain consistency
        if let oldPassphrase {
            _ = kcDatabasePassword.set(oldPassphrase)
        }
        if let oldSalt {
            _ = kcDatabaseSalt.set(oldSalt)
        }
        return
    }

    // Update rotation metadata
    KeyRotationManager.shared.incrementVersion()

    // Clear rotation needed flag
    UserDefaults.standard.set(false, forKey: "databaseKeyRotationNeeded")

    logger.debug("completeKeyRotation: successfully rotated key to version \(KeyRotationManager.shared.getMetadata().version)")
}


public func chatCloseStore() {
    guard let ctrl = getChatCtrl() else {
        logger.error("chatCloseStore: chatCtrl is nil")
        chatControllerLock.sync { chatController = nil }
        return
    }
    defer { chatControllerLock.sync { chatController = nil } }
    guard let result = chat_close_store(ctrl) else {
        logger.error("chatCloseStore: returned null")
        return
    }
    let err = fromCString(result)
    if err != "" {
        logger.error("chatCloseStore error: \(err)")
    }
}

public func chatReopenStore() {
    guard let ctrl = getChatCtrl() else {
        logger.error("chatReopenStore: chatCtrl is nil")
        return
    }
    guard let result = chat_reopen_store(ctrl) else {
        logger.error("chatReopenStore: returned null")
        return
    }
    let err = fromCString(result)
    if err != "" {
        logger.error("chatReopenStore error: \(err)")
    }
}

public func resetChatCtrl() {
    chatControllerLock.sync {
        chatController = nil
        migrationResult = nil
    }
}

// Spec: spec/api.md#sendPopopxCmd
@inline(__always)
public func sendPopopxCmd<R: ChatAPIResult>(_ cmd: ChatCmdProtocol, _ ctrl: chat_ctrl? = nil, retryNum: Int32 = 0) -> APIResult<R> {
    var safeRetryNum = retryNum
    if retryNum < 0 || retryNum > 10 {
        logger.error("sendPopopxCmd: invalid retryNum=\(retryNum), clamping to 0")
        safeRetryNum = 0
    }
    if let d = sendPopopxCmdStr(cmd.cmdString, ctrl, retryNum: safeRetryNum) {
        return decodeAPIResult(d)
    } else {
        return APIResult.error(.invalidJSON(json: nil), seq: 0)
    }
}

@inline(__always)
public func sendPopopxCmdStr(_ cmd: String, _ ctrl: chat_ctrl? = nil, retryNum: Int32) -> Data? {
    guard let controller = ctrl ?? getChatCtrl() else { return nil }
    guard var c = cmd.cString(using: .utf8) else { return nil }
    return if let cjson = chat_send_cmd_retry(controller, &c, retryNum) {
        dataFromCString(cjson)
    } else {
        nil
    }
}

// in microseconds
public let MESSAGE_TIMEOUT: Int32 = 15_000_000

@inline(__always)
public func recvPopopxMsg<R: ChatAPIResult>(_ ctrl: chat_ctrl? = nil, messageTimeout: Int32 = MESSAGE_TIMEOUT) -> APIResult<R>? {
    guard let controller = ctrl ?? getChatCtrl() else { return Optional<APIResult<R>>.none }
    if let cjson = chat_recv_msg_wait(controller, messageTimeout),
       let d = dataFromCString(cjson) {
        return decodeAPIResult(d)
    } else {
        return nil
    }
}

public func parseMarkdown(_ s: String) -> [FormattedText]? {
    guard var c = s.cString(using: .utf8) else { return nil }
    if let cjson = chat_parse_markdown(&c) {
        if let d = dataFromCString(cjson) {
            do {
                let r = try jsonDecoder.decode(ParsedMarkdown.self, from: d)
                return r.formattedText
            } catch {
                logger.error("parseMarkdown jsonDecoder.decode error: \(error.localizedDescription)")
            }
        }
    }
    return nil
}

public func chatJsonLength(_ s: String) -> Int {
    guard var c = s.cString(using: .utf8) else { return 0 }
    return Int(chat_json_length(&c))
}

// the code in core's canonical form (prefix and 20 characters, no separators), or nil when core rejects it.
// The check character is verified by core via FFI, not re-implemented here, so the two cannot disagree.
public func parseBadgeCode(_ s: String) -> String? {
    var c = s.cString(using: .utf8)!
    let canonical = fromCString(chat_parse_badge_code(&c)!)
    return canonical.isEmpty ? nil : canonical
}

struct ParsedMarkdown: Decodable {
    var formattedText: [FormattedText]?
}

public func parseServerAddress(_ s: String) -> ServerAddress? {
    guard var c = s.cString(using: .utf8) else { return nil }
    if let cjson = chat_parse_server(&c) {
         if let d = dataFromCString(cjson) {
            do {
                let r = try jsonDecoder.decode(ParsedServerAddress.self, from: d)
                return r.serverAddress
            } catch {
                logger.error("parseServerAddress jsonDecoder.decode error: \(error.localizedDescription)")
            }
        }
    }
    return nil
}

struct ParsedServerAddress: Decodable {
    var serverAddress: ServerAddress?
    var parseError: String
}

public func parseSanitizeUri(_ s: String, safe: Bool) -> ParsedUri? {
    guard var c = s.cString(using: .utf8) else { return nil }
    if let cjson = chat_parse_uri(&c, safe ? 1 : 0) {
         if let d = dataFromCString(cjson) {
            do {
                return try jsonDecoder.decode(ParsedUri.self, from: d)
            } catch {
                logger.error("parseSanitizeUri jsonDecoder.decode error: \(error.localizedDescription)")
            }
        }
    }
    return nil
}

public struct ParsedUri: Decodable {
    public var uriInfo: UriInfo?
    public var parseError: String
}

public struct UriInfo: Decodable {
    public var scheme: String
    public var sanitized: String?
}

@inline(__always)
public func fromCString(_ c: UnsafeMutablePointer<CChar>) -> String {
    let s = String.init(cString: c)
    free(c)
    return s
}

// Assumes FFI responses are null-terminated C strings without embedded nulls.
// The Haskell FFI currently only returns JSON text which satisfies this constraint.
@inline(__always)
public func dataFromCString(_ c: UnsafeMutablePointer<CChar>) -> Data? {
    let len = strlen(c)
    if len > 0 {
        return Data(bytesNoCopy: c, count: len, deallocator: .free)
    } else {
        free(c)
        return nil
    }
}

@inline(__always)
public func dataToString(_ d: Data?) -> String {
    if let d {
        String(data: d, encoding: .utf8) ?? "invalid string"
    } else {
        "no data"
    }
}

public func decodeUser_(_ jDict: NSDictionary) -> UserRef? {
    if let user_ = jDict["user_"] {
        do {
            return try decodeObject(user_ as Any)
        } catch {
            logger.error("decodeUser_: failed to decode user: \(error)")
            return nil
        }
    } else {
        return nil
    }
}

public func errorJson(_ jDict: NSDictionary) -> Data? {
    if let chatError = jDict["chatError"] {
        serializeJSON(chatError)
    } else {
        serializeJSON(jDict)
    }
}

public func parseChatData(_ jChat: Any, _ jNavInfo: Any? = nil) throws -> (ChatData, NavigationInfo) {
    guard let jChatDict = jChat as? NSDictionary else {
        throw RuntimeError("parseChatData: jChat is not a dictionary")
    }
    guard let chatInfoAny = jChatDict["chatInfo"] else {
        throw RuntimeError("parseChatData: missing chatInfo")
    }
    let chatInfo: ChatInfo
    do {
        chatInfo = try decodeObject(chatInfoAny)
    } catch {
        logger.error("parseChatData: failed to decode chatInfo: \(error)")
        throw RuntimeError("parseChatData: missing chatInfo")
    }
    guard let chatStatsAny = jChatDict["chatStats"] else {
        throw RuntimeError("parseChatData: missing chatStats")
    }
    let chatStats: ChatStats
    do {
        chatStats = try decodeObject(chatStatsAny)
    } catch {
        logger.error("parseChatData: failed to decode chatStats: \(error)")
        throw RuntimeError("parseChatData: missing chatStats")
    }
    let navInfo: NavigationInfo = if let jNavInfo = jNavInfo as? NSDictionary, let jNav = jNavInfo["navInfo"] {
        try decodeObject(jNav)
    } else {
        NavigationInfo()
    }
    let jChatItems = jChatDict["chatItems"] as? NSArray ?? []
    let chatItems = jChatItems.map { jCI in
        do {
            return try decodeObject(jCI) as ChatItem
        } catch {
            logger.error("parseChatData: failed to decode chatItem: \(error)")
            return ChatItem.invalidJSON(
                chatDir: decodeProperty(jCI, "chatDir"),
                meta: decodeProperty(jCI, "meta"),
                json: serializeJSON(jCI, options: .prettyPrinted)
            )
        }
    }
    return (ChatData(chatInfo: chatInfo, chatItems: chatItems, chatStats: chatStats), navInfo)
}

public func decodeObject<T: Decodable>(_ obj: Any) throws -> T {
    do {
        return try jsonDecoder.decode(T.self, from: JSONSerialization.data(withJSONObject: obj))
    } catch {
        logger.debug("decodeObject<\(T.self)> failed: \(error)")
        throw error
    }
}

@inline(__always)
public func decodeRaw<T: RawRepresentable>(_ value: Any) -> T? where T.RawValue == String {
    (value as? String).flatMap { T(rawValue: $0) }
}

@inline(__always)
func decodeProperty<T: Decodable>(_ obj: Any, _ prop: NSString) -> T? {
    if let jProp = (obj as? NSDictionary)?[prop] {
        do {
            return try decodeObject(jProp)
        } catch {
            logger.error("decodeProperty: failed to decode \(prop): \(error)")
            return nil
        }
    }
    return nil
}

@inline(__always)
func getOWSF(_ obj: NSDictionary, _ prop: NSString) -> (type: String, object: NSDictionary)? {
    guard let j = obj[prop] as? NSDictionary else {
        print("getOWSF: no '\(prop)' key in obj, keys=\(obj.allKeys)")
        return nil
    }
    print("getOWSF: found '\(prop)', j keys=\(j.allKeys)")
    // Check for _owsf tag (boolean true indicates single-field encoding)
    if let owsfValue = j["_owsf"] as? Bool, owsfValue {
        // _owsf is true, find the actual data key (not _owsf)
        let dataKeys = j.allKeys.filter { ($0 as? String) != "_owsf" }
        if let dataKey = dataKeys.first as? String, let dataObj = j[dataKey] as? NSDictionary {
            print("getOWSF: _owsf=true, data key='\(dataKey)'")
            return (dataKey, dataObj)
        }
    }
    // Fallback: check for _owsf as string tag
    if let owsfValue = j["_owsf"] as? String {
        print("getOWSF: found _owsf='\(owsfValue)'")
        return (owsfValue, j)
    }
    // Fallback: single key without _owsf tag
    if j.count == 1, let firstKey = j.allKeys.first as? String {
        print("getOWSF: fallback single key='\(firstKey)'")
        return (firstKey, j)
    }
    print("getOWSF: no match, returning nil")
    return nil
}

@inline(__always)
public func serializeJSON(_ obj: Any, options: JSONSerialization.WritingOptions = []) -> Data? {
    do {
        let d = try JSONSerialization.data(withJSONObject: obj, options: options)
        return dataPrefix(d)
    } catch {
        logger.error("serializeJSON: failed to serialize: \(error)")
        return nil
    }
}

let MAX_JSON_VIEW_LENGTH = 2048

@inline(__always)
public func dataPrefix(_ d: Data) -> Data {
    d.count > MAX_JSON_VIEW_LENGTH
    ? Data(d.prefix(MAX_JSON_VIEW_LENGTH))
    : d
}

public func responseError(_ err: Error) -> String {
    if let e = err as? ChatError {
        chatErrorString(e)
    } else {
        String(describing: err)
    }
}

public func chatErrorString(_ err: ChatError) -> String {
    switch err {
    case let .invalidJSON(json): dataToString(json)
    case let .unexpectedResult(type): "unexpected result: \(type)"
    default: String(describing: err)
    }
}

public enum DBMigrationResult: Equatable {
    case ok
    case invalidConfirmation
    case errorNotADatabase(dbFile: String)
    case errorMigration(dbFile: String, migrationError: MigrationError)
    case errorSQL(dbFile: String, migrationSQLError: String)
    case errorKeychain
    case errorKeyGeneration
    case unknown(json: String)
}

extension DBMigrationResult: Decodable {
    private enum CodingKeys: String, CodingKey {
        case _owsf, ok, invalidConfirmation, errorNotADatabase,
             errorMigration, errorSQL, errorKeychain, errorKeyGeneration
    }

    private enum DBMDataKeys: String, CodingKey {
        case dbFile, migrationError, migrationSQLError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check for _owsf tag (swift JSON format)
        if container.contains(._owsf) {
            let allKeys = Set(container.allKeys.map { $0.stringValue })
            let constructorKey = allKeys.first { $0 != "_owsf" }

            guard let key = constructorKey else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "No constructor key found alongside _owsf tag")
                )
            }

            switch key {
            case "ok":
                self = .ok
            case "invalidConfirmation":
                self = .invalidConfirmation
            case "errorNotADatabase":
                let nested = try container.nestedContainer(keyedBy: DBMDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let dbFile = try nested.decode(String.self, forKey: .dbFile)
                self = .errorNotADatabase(dbFile: dbFile)
            case "errorMigration":
                let nested = try container.nestedContainer(keyedBy: DBMDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let dbFile = try nested.decode(String.self, forKey: .dbFile)
                let migrationError = try nested.decode(MigrationError.self, forKey: .migrationError)
                self = .errorMigration(dbFile: dbFile, migrationError: migrationError)
            case "errorSQL":
                let nested = try container.nestedContainer(keyedBy: DBMDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let dbFile = try nested.decode(String.self, forKey: .dbFile)
                let migrationSQLError = try nested.decode(String.self, forKey: .migrationSQLError)
                self = .errorSQL(dbFile: dbFile, migrationSQLError: migrationSQLError)
            case "errorKeychain":
                self = .errorKeychain
            case "errorKeyGeneration":
                self = .errorKeyGeneration
            default:
                self = .unknown(json: key)
            }
        } else {
            // Fallback: standard decoding without _owsf tag
            if container.contains(.ok) {
                self = .ok
            } else if container.contains(.invalidConfirmation) {
                self = .invalidConfirmation
            } else if container.contains(.errorNotADatabase) {
                let nested = try container.nestedContainer(keyedBy: DBMDataKeys.self, forKey: .errorNotADatabase)
                let dbFile = try nested.decode(String.self, forKey: .dbFile)
                self = .errorNotADatabase(dbFile: dbFile)
            } else if container.contains(.errorMigration) {
                let nested = try container.nestedContainer(keyedBy: DBMDataKeys.self, forKey: .errorMigration)
                let dbFile = try nested.decode(String.self, forKey: .dbFile)
                let migrationError = try nested.decode(MigrationError.self, forKey: .migrationError)
                self = .errorMigration(dbFile: dbFile, migrationError: migrationError)
            } else if container.contains(.errorSQL) {
                let nested = try container.nestedContainer(keyedBy: DBMDataKeys.self, forKey: .errorSQL)
                let dbFile = try nested.decode(String.self, forKey: .dbFile)
                let migrationSQLError = try nested.decode(String.self, forKey: .migrationSQLError)
                self = .errorSQL(dbFile: dbFile, migrationSQLError: migrationSQLError)
            } else if container.contains(.errorKeychain) {
                self = .errorKeychain
            } else if container.contains(.errorKeyGeneration) {
                self = .errorKeyGeneration
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "Unknown DBMigrationResult format")
                )
            }
        }
    }
}

public enum MigrationConfirmation: String {
    case yesUp
    case yesUpDown
    case error
}

public func defaultMigrationConfirmation() -> MigrationConfirmation {
    confirmDBUpgradesGroupDefault.get() ? .error : .yesUp
}

public enum MigrationError: Equatable {
    case upgrade(upMigrations: [UpMigration])
    case downgrade(downMigrations: [String])
    case migrationError(mtrError: MTRError)
}

extension MigrationError: Decodable {
    private enum CodingKeys: String, CodingKey {
        case _owsf, upgrade, downgrade, migrationError
    }

    private enum MEDataKeys: String, CodingKey {
        case upMigrations, downMigrations, mtrError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(._owsf) {
            let allKeys = Set(container.allKeys.map { $0.stringValue })
            let constructorKey = allKeys.first { $0 != "_owsf" }

            guard let key = constructorKey else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "No constructor key found alongside _owsf tag")
                )
            }

            switch key {
            case "upgrade":
                let nested = try container.nestedContainer(keyedBy: MEDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let upMigrations = try nested.decode([UpMigration].self, forKey: .upMigrations)
                self = .upgrade(upMigrations: upMigrations)
            case "downgrade":
                let nested = try container.nestedContainer(keyedBy: MEDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let downMigrations = try nested.decode([String].self, forKey: .downMigrations)
                self = .downgrade(downMigrations: downMigrations)
            case "migrationError":
                let nested = try container.nestedContainer(keyedBy: MEDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let mtrError = try nested.decode(MTRError.self, forKey: .mtrError)
                self = .migrationError(mtrError: mtrError)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "Unknown MigrationError constructor: \(key)")
                )
            }
        } else {
            if container.contains(.upgrade) {
                let nested = try container.nestedContainer(keyedBy: MEDataKeys.self, forKey: .upgrade)
                let upMigrations = try nested.decode([UpMigration].self, forKey: .upMigrations)
                self = .upgrade(upMigrations: upMigrations)
            } else if container.contains(.downgrade) {
                let nested = try container.nestedContainer(keyedBy: MEDataKeys.self, forKey: .downgrade)
                let downMigrations = try nested.decode([String].self, forKey: .downMigrations)
                self = .downgrade(downMigrations: downMigrations)
            } else if container.contains(.migrationError) {
                let nested = try container.nestedContainer(keyedBy: MEDataKeys.self, forKey: .migrationError)
                let mtrError = try nested.decode(MTRError.self, forKey: .mtrError)
                self = .migrationError(mtrError: mtrError)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "Unknown MigrationError format")
                )
            }
        }
    }
}

public struct UpMigration: Decodable, Equatable {
    public var upName: String
//    public var withDown: Bool
}

public func downMigrationWarnings(_ downMigrations: [String]) -> [String] {
    let warnings: [(String, String)] = [
        ("20260222_chat_relays", NSLocalizedString("If you joined or created channels, they will stop working permanently.", comment: "down migration warning"))
    ]
    return warnings.compactMap { (key, message) in
        downMigrations.contains(key) ? message : nil
    }
}

public enum MTRError: Equatable {
    case noDown(dbMigrations: [String])
    case different(appMigration: String, dbMigration: String)
}

extension MTRError: Decodable {
    private enum CodingKeys: String, CodingKey {
        case _owsf, noDown, different
    }

    private enum MTRErrorDataKeys: String, CodingKey {
        case dbMigrations, appMigration, dbMigration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(._owsf) {
            let allKeys = Set(container.allKeys.map { $0.stringValue })
            let constructorKey = allKeys.first { $0 != "_owsf" }

            guard let key = constructorKey else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "No constructor key found alongside _owsf tag")
                )
            }

            switch key {
            case "noDown":
                let nested = try container.nestedContainer(keyedBy: MTRErrorDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let dbMigrations = try nested.decode([String].self, forKey: .dbMigrations)
                self = .noDown(dbMigrations: dbMigrations)
            case "different":
                let nested = try container.nestedContainer(keyedBy: MTRErrorDataKeys.self, forKey: CodingKeys(stringValue: key)!)
                let appMigration = try nested.decode(String.self, forKey: .appMigration)
                let dbMigration = try nested.decode(String.self, forKey: .dbMigration)
                self = .different(appMigration: appMigration, dbMigration: dbMigration)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "Unknown MTRError constructor: \(key)")
                )
            }
        } else {
            if container.contains(.noDown) {
                let nested = try container.nestedContainer(keyedBy: MTRErrorDataKeys.self, forKey: .noDown)
                let dbMigrations = try nested.decode([String].self, forKey: .dbMigrations)
                self = .noDown(dbMigrations: dbMigrations)
            } else if container.contains(.different) {
                let nested = try container.nestedContainer(keyedBy: MTRErrorDataKeys.self, forKey: .different)
                let appMigration = try nested.decode(String.self, forKey: .appMigration)
                let dbMigration = try nested.decode(String.self, forKey: .dbMigration)
                self = .different(appMigration: appMigration, dbMigration: dbMigration)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                         debugDescription: "Unknown MTRError format")
                )
            }
        }
    }
}

func dbMigrationResult(_ d: Data?) -> DBMigrationResult {
    if let d {
        do {
            return try jsonDecoder.decode(DBMigrationResult.self, from: d)
        } catch let error {
            logger.error("chatResponse jsonDecoder.decode error: \(error.localizedDescription)")
            return .unknown(json: dataToString(d))
        }
    } else {
        return .unknown(json: "no data")
    }
}
