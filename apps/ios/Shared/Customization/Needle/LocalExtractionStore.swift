// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import SQLite3
import os

class LocalExtractionStore {
    static let shared = LocalExtractionStore()

    private let logger = Logger(subsystem: "im.popopx", category: "NeedleStore")
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "im.popopx.needle.store", qos: .userInitiated)

    private init() {
        queue.sync {
            openDatabase()
            createTable()
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func openDatabase() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Cannot find Application Support directory")
            return
        }

        let dbDir = appSupport.appendingPathComponent("Needle", isDirectory: true)
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create Needle database directory: \(error)")
        }
        do {
            try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: dbDir.path)
        } catch {
            logger.error("Failed to set file protection on Needle database directory: \(error)")
        }

        let dbPath = dbDir.appendingPathComponent("extractions.db").path
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            logger.error("Failed to open database at \(dbPath)")
            sqlite3_close(db)
            db = nil
        }

        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)

        var flags: Int32 = 1
        sqlite3_file_control(db, nil, SQLITE_FCNTL_PERSIST_WAL, &flags)
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS extractions (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                data_json TEXT NOT NULL,
                source_text TEXT NOT NULL,
                chat_id TEXT,
                created_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_extractions_type ON extractions(type);
            CREATE INDEX IF NOT EXISTS idx_extractions_created ON extractions(created_at);
        """
        execSQL(sql)
    }

    func save(_ extractions: [Extraction]) {
        queue.sync {
            guard let db else { return }
            sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
            for extraction in extractions {
                guard let jsonData = try? JSONSerialization.data(withJSONObject: extraction.data) else {
                    logger.warning("Failed to serialize extraction \(extraction.id) data, skipping")
                    continue
                }
                let storedValue: String
                do {
                    let encrypted = try CryptoEncrypt.shared.encrypt(jsonData)
                    storedValue = encrypted.base64EncodedString()
                } catch {
                    logger.warning("Failed to encrypt extraction \(extraction.id): \(error), storing unencrypted")
                    storedValue = jsonData.base64EncodedString()
                }

                let sql = "INSERT OR REPLACE INTO extractions (id, type, data_json, source_text, chat_id, created_at) VALUES (?, ?, ?, ?, ?, ?)"
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    logger.warning("Failed to prepare insert: \(String(cString: sqlite3_errmsg(db)))")
                    continue
                }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_text(stmt, 1, extraction.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 2, extraction.type.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 3, storedValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 4, extraction.sourceText, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if let chatId = extraction.chatId {
                    sqlite3_bind_text(stmt, 5, chatId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                sqlite3_bind_double(stmt, 6, extraction.createdAt.timeIntervalSince1970)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    logger.warning("Failed to insert extraction: \(String(cString: sqlite3_errmsg(db)))")
                }
            }
            let commitResult = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
            if commitResult != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                logger.error("COMMIT failed (result=\(commitResult)): \(msg), attempting ROLLBACK")
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }
    }

    func fetchAll(limit: Int = 100) -> [Extraction] {
        var results: [Extraction] = []
        queue.sync {
            guard let db else { return }
            let sql = "SELECT id, type, data_json, source_text, chat_id, created_at FROM extractions ORDER BY created_at DESC LIMIT ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int(stmt, 1, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let extraction = rowToExtraction(stmt) {
                    results.append(extraction)
                }
            }
        }
        return results
    }

    func fetchByType(_ type: ExtractionType, limit: Int = 50) -> [Extraction] {
        var results: [Extraction] = []
        queue.sync {
            guard let db else { return }
            let sql = "SELECT id, type, data_json, source_text, chat_id, created_at FROM extractions WHERE type = ? ORDER BY created_at DESC LIMIT ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, type.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(stmt, 2, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let extraction = rowToExtraction(stmt) {
                    results.append(extraction)
                }
            }
        }
        return results
    }

    func fetchByChatId(_ chatId: String, limit: Int = 50) -> [Extraction] {
        var results: [Extraction] = []
        queue.sync {
            guard let db else { return }
            let sql = "SELECT id, type, data_json, source_text, chat_id, created_at FROM extractions WHERE chat_id = ? ORDER BY created_at DESC LIMIT ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, chatId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(stmt, 2, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let extraction = rowToExtraction(stmt) {
                    results.append(extraction)
                }
            }
        }
        return results
    }

    func delete(id: UUID) {
        queue.sync {
            guard let db else { return }
            let sql = "DELETE FROM extractions WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(stmt) != SQLITE_DONE {
                logger.warning("Failed to delete: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }

    func deleteAll() {
        queue.sync {
            guard let db else { return }
            let sql = "DELETE FROM extractions"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) != SQLITE_DONE {
                logger.warning("Failed to delete all: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }

    func totalCount() -> Int {
        var count = 0
        queue.sync {
            guard let db else { return }
            let sql = "SELECT COUNT(*) FROM extractions"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        return count
    }

    private func rowToExtraction(_ stmt: OpaquePointer?) -> Extraction? {
        guard let stmt else { return nil }

        guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
              let id = UUID(uuidString: idStr),
              let typeStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
              let type = ExtractionType(rawValue: typeStr),
              let dataJson = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
              let sourceText = sqlite3_column_text(stmt, 3).map({ String(cString: $0) }) else {
            return nil
        }

        let chatId = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))

        let data: [String: String]
        if let raw = Data(base64Encoded: dataJson) {
            do {
                let decryptedData = try CryptoEncrypt.shared.decrypt(raw)
                if let dict = try? JSONSerialization.jsonObject(with: decryptedData) as? [String: String] {
                    data = dict
                } else if let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: String] {
                    data = dict
                } else {
                    logger.warning("Extraction \(id) has corrupted data, returning empty dictionary")
                    data = [:]
                }
            } catch {
                if let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: String] {
                    data = dict
                } else {
                    logger.warning("Extraction \(id) failed to decrypt and parse: \(error)")
                    data = [:]
                }
            }
        } else {
            logger.warning("Extraction \(id) has corrupted data, returning empty dictionary")
            data = [:]
        }

        return Extraction(id: id, type: type, data: data, sourceText: sourceText, chatId: chatId, createdAt: createdAt)
    }

    private func execSQL(_ sql: String) {
        guard let db else { return }
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            logger.warning("SQL error: \(msg)")
            sqlite3_free(errMsg)
        }
    }
}
