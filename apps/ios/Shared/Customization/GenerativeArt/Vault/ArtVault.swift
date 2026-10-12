// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import UIKit
import os
import Photos

/// Encrypted vault for storing generated art pieces.
/// Reuses CryptoEncrypt for AES-256-GCM encryption with Keychain-backed key.
@MainActor
final class ArtVault: ObservableObject {
    static let shared = ArtVault()

    private let logger = Logger(subsystem: "im.popopx", category: "ArtVault")
    private let maxPieces = 50

    @Published private(set) var pieces: [ArtPiece] = []
    @Published private(set) var isEnabled: Bool = true

    private let storageDir: URL
    private let metadataFile: URL

    private init() {
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Unable to locate Application Support directory — vault disabled")
            self.storageDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ArtVaultDisabled")
            self.metadataFile = storageDir.appendingPathComponent("metadata.json")
            self.isEnabled = false
            return
        }
        self.storageDir = supportDir.appendingPathComponent("GenerativeArt", isDirectory: true)
        self.metadataFile = storageDir.appendingPathComponent("metadata.json")

        do {
            try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create vault storage directory: \(error)")
        }
        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: storageDir.path)
        } catch {
            logger.error("Failed to set file protection on vault directory: \(error)")
        }
        loadMetadata()
    }

    // MARK: - Save

    func save(image: UIImage, metadata: ArtPiece) throws {
        guard let pngData = image.pngData() else {
            throw ArtVaultError.imageEncodingFailed
        }

        // Encrypt PNG data
        let encryptedData = try CryptoEncrypt.shared.encrypt(pngData)

        // Write encrypted file
        let filePath = storageDir.appendingPathComponent("\(metadata.id.uuidString).popopxart")
        try encryptedData.write(to: filePath, options: [.atomic, .completeFileProtection])
        var fileURL = filePath
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? fileURL.setResourceValues(resourceValues)

        // Update metadata
        var updatedMetadata = metadata
        updatedMetadata.filename = filePath.lastPathComponent
        pieces.insert(updatedMetadata, at: 0)

        // Enforce limit (LRU eviction)
        if pieces.count > maxPieces {
            let removed = pieces.removeLast()
            let removedPath = storageDir.appendingPathComponent(removed.filename)
            try? FileManager.default.removeItem(at: removedPath)
        }

        saveMetadata()
        logger.info("Saved art piece \(metadata.id.uuidString.prefix(8))...")
    }

    // MARK: - Load

    func load(_ piece: ArtPiece) async throws -> UIImage {
        let filePath = storageDir.appendingPathComponent(piece.filename)
        return try await Task.detached(priority: .userInitiated) {
            let encryptedData = try Data(contentsOf: filePath)
            let pngData = try CryptoEncrypt.shared.decrypt(encryptedData)
            guard let image = UIImage(data: pngData) else {
                throw ArtVaultError.decryptionFailed
            }
            return image
        }.value
    }

    // MARK: - Delete

    func delete(_ piece: ArtPiece) throws {
        let filePath = storageDir.appendingPathComponent(piece.filename)
        try FileManager.default.removeItem(at: filePath)
        pieces.removeAll { $0.id == piece.id }
        saveMetadata()
    }

    // MARK: - Export

    func exportToPhotos(_ piece: ArtPiece) async throws {
        let image = try await load(piece)
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized:
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized {
                    DispatchQueue.main.async {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: - Private

    private func loadMetadata() {
        guard FileManager.default.fileExists(atPath: metadataFile.path) else { return }
        do {
            let data = try Data(contentsOf: metadataFile)
            pieces = try JSONDecoder().decode([ArtPiece].self, from: data)
        } catch {
            logger.error("Failed to load metadata: \(error)")
            pieces = []
        }
    }

    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(pieces)
            try data.write(to: metadataFile, options: [.atomic, .completeFileProtection])
            var metaURL = metadataFile
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? metaURL.setResourceValues(resourceValues)
        } catch {
            logger.error("Failed to save metadata: \(error)")
        }
    }
}

// MARK: - ArtPiece Model

struct ArtPiece: Identifiable, Codable, Equatable {
    let id: UUID
    let seed: String
    let generatorType: String
    let sourceText: String
    let emotionProfile: EmotionProfile
    let createdAt: Date
    var filename: String

    static func == (lhs: ArtPiece, rhs: ArtPiece) -> Bool {
        lhs.id == rhs.id
    }
}

enum ArtVaultError: LocalizedError {
    case imageEncodingFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return NSLocalizedString("art_vault_encode_failed", comment: "Failed to encode image as PNG")
        case .decryptionFailed:
            return NSLocalizedString("art_vault_decrypt_failed", comment: "Failed to decrypt art piece")
        }
    }
}
