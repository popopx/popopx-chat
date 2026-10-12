// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/12-FEATURE-ENCRYPTED-DOCS.md
import Foundation
import CryptoKit
import Security
import os

struct EncryptedDocument: Identifiable, Codable {
    let id: String
    var title: String
    var encryptedContent: Data
    var ownerId: String
    var collaborators: [String]
    var expiresAt: Date?
    var createdAt: Date = Date()
}

@MainActor
class EncryptedDocManager: ObservableObject {
    static let shared = EncryptedDocManager()

    @Published var documents: [EncryptedDocument] = [] {
        didSet { saveDocuments() }
    }

    private static let keychainAccount = "encrypted-doc-manager-key"
    private static let keychainService = "com.popopxchat.popopx"

    private var persistenceURL: URL {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("EncryptedDocs", isDirectory: true)
                .appendingPathComponent("documents.json")
        }
        let docsDir = dir.appendingPathComponent("EncryptedDocs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: docsDir.path) {
            do {
                try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
            } catch {
                os_log(.error, "EncryptedDocManager: failed to create docs directory: %{public}@", error.localizedDescription)
            }
            do {
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: docsDir.path)
            } catch {
                os_log(.error, "EncryptedDocManager: failed to set file protection on docs directory: %{public}@", error.localizedDescription)
            }
        }
        return docsDir.appendingPathComponent("documents.json")
    }

    init() {
        loadDocuments()
    }

    private lazy var masterKey: SymmetricKey = {
        if let existing = loadKeyFromKeychain() { return existing }
        let newKey = SymmetricKey(size: .bits256)
        saveKeyToKeychain(newKey)
        return newKey
    }()

    private func derivedKey(for docId: String) -> SymmetricKey {
        let inputKey = masterKey.withUnsafeBytes { Data($0) }
        let info = Data(docId.utf8)
        let prk = HKDF<SHA256>.extract(inputKeyMaterial: SymmetricKey(data: inputKey), salt: Data())
        let derived = HKDF<SHA256>.expand(pseudoRandomKey: prk, info: info, outputByteCount: 32)
        return SymmetricKey(data: derived)
    }

    func createDocument(title: String, content: String) throws -> EncryptedDocument {
        let docId = UUID().uuidString
        let encrypted = try encrypt(content, docId: docId)
        let doc = EncryptedDocument(
            id: docId,
            title: title,
            encryptedContent: encrypted,
            ownerId: "self",
            collaborators: []
        )
        documents.append(doc)
        return doc
    }

    func readContent(_ doc: EncryptedDocument) throws -> String {
        try decrypt(doc.encryptedContent, docId: doc.id)
    }

    func shareDocument(_ docId: String, with userId: String) {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = documents.firstIndex(where: { $0.id == docId }) {
            guard documents[idx].ownerId == "self" else { return }
            guard trimmed != documents[idx].ownerId else { return }
            if !documents[idx].collaborators.contains(trimmed) {
                documents[idx].collaborators.append(trimmed)
            }
        }
    }

    func setExpiry(_ docId: String, expiresAt: Date) {
        if let idx = documents.firstIndex(where: { $0.id == docId }) {
            guard documents[idx].ownerId == "self" else { return }
            documents[idx].expiresAt = expiresAt
        }
    }

    func revokeAccess(_ docId: String) {
        if let idx = documents.firstIndex(where: { $0.id == docId }) {
            guard documents[idx].ownerId == "self" else { return }
            documents[idx].collaborators.removeAll()
        }
    }

    func deleteDocument(_ docId: String) {
        guard documents.first(where: { $0.id == docId })?.ownerId == "self" else { return }
        documents.removeAll { $0.id == docId }
    }

    func updateContent(_ docId: String, content: String) {
        if let idx = documents.firstIndex(where: { $0.id == docId }) {
            let doc = documents[idx]
            guard doc.ownerId == "self" || doc.collaborators.contains("self") else { return }
            do {
                let encrypted = try encrypt(content, docId: doc.id)
                documents[idx].encryptedContent = encrypted
            } catch {
                logger.error("EncryptedDocManager: encryption failed for doc \(doc.id): \(error)")
            }
        }
    }

    func isExpired(_ doc: EncryptedDocument) -> Bool {
        guard let expiry = doc.expiresAt else { return false }
        return expiry < Date()
    }

    func timeRemaining(for doc: EncryptedDocument) -> TimeInterval? {
        guard let expiry = doc.expiresAt else { return nil }
        let remaining = expiry.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }

    // MARK: - Persistence

    private func saveDocuments() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: persistenceURL, options: [.atomic, .completeFileProtection])
            var docURL = persistenceURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            do {
                try docURL.setResourceValues(resourceValues)
            } catch {
                os_log(.error, "EncryptedDocManager: failed to set resource values (isExcludedFromBackup): %{public}@", error.localizedDescription)
            }
        } catch {
            os_log(.error, "EncryptedDocManager: failed to save documents: %{public}@", error.localizedDescription)
        }
    }

    private func loadDocuments() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            documents = try JSONDecoder().decode([EncryptedDocument].self, from: data)
        } catch {
            os_log(.error, "EncryptedDocManager: failed to load documents: %{public}@", error.localizedDescription)
        }
    }

    // MARK: - AES-GCM Encryption

    private func encrypt(_ plaintext: String, docId: String) throws -> Data {
        guard let data = plaintext.data(using: .utf8) else {
            throw DocError.encodingFailed
        }
        let key = derivedKey(for: docId)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw DocError.encryptionFailed
        }
        return combined
    }

    private func decrypt(_ ciphertext: Data, docId: String) throws -> String {
        guard !ciphertext.isEmpty else {
            throw DocError.decryptionFailed
        }
        let key = derivedKey(for: docId)
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        let decrypted = try AES.GCM.open(box, using: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw DocError.decryptionFailed
        }
        return string
    }

    enum DocError: Error, LocalizedError {
        case encodingFailed
        case encryptionFailed
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return NSLocalizedString("encrypted_doc_encode_failed", comment: "Failed to encode document text")
            case .encryptionFailed: return NSLocalizedString("encrypted_doc_encrypt_failed", comment: "Failed to encrypt document")
            case .decryptionFailed: return NSLocalizedString("encrypted_doc_decrypt_failed", comment: "Failed to decrypt document — data may be corrupted")
            }
        }
    }

    // MARK: - Keychain

    private func saveKeyToKeychain(_ key: SymmetricKey) {
        let rawKey = key.withUnsafeBytes { Data($0) }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecValueData as String: rawKey
        ]
        #if os(iOS) && !targetEnvironment(simulator)
        if let teamID = Bundle.main.infoDictionary?["TeamIdentifier"] as? String, teamID != "$(AppIdentifierPrefix)" {
            query[kSecAttrAccessGroup as String] = "\(teamID).com.popopxchat.popopx"
        }
        #endif
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            os_log(.error, "EncryptedDocManager: failed to save key to Keychain: %d", Int(status))
        }
    }

    private func loadKeyFromKeychain() -> SymmetricKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        #if os(iOS) && !targetEnvironment(simulator)
        if let teamID = Bundle.main.infoDictionary?["TeamIdentifier"] as? String, teamID != "$(AppIdentifierPrefix)" {
            query[kSecAttrAccessGroup as String] = "\(teamID).com.popopxchat.popopx"
        }
        #endif
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let rawKey = result as? Data else { return nil }
        return SymmetricKey(data: rawKey)
    }
}
