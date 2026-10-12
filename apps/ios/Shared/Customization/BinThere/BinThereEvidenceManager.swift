// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereEvidenceManager.swift
//  POPOPX (iOS)
//
//  Enterprise-grade evidence capture for BinThere burn-after-read security.
//  When a peeping violation is detected (multiple faces), silently captures
//  a frame from the camera buffer, encrypts with AES-GCM 256, and stores
//  in a file-protection-encrypted sandbox directory.
//
//  Features:
//  - Silent capture from CMSampleBuffer (no shutter sound)
//  - AES-GCM 256-bit encryption via CryptoKit
//  - Encrypted sandbox storage with .completeUnlessOpen file protection
//  - 5-second capture cooldown to prevent storage flooding
//  - Audit log for compliance tracking
//

import Foundation
import AVFoundation
import CryptoKit
import UIKit
import os

struct BinThereAuditEntry: Codable {
    let timestamp: Date
    let reason: String
    let evidenceFilename: String?
    let deviceModel: String
}

final class BinThereEvidenceManager {
    static let shared = BinThereEvidenceManager()

    private let logger = Logger(subsystem: "im.popopx", category: "BinThereEvidence")
    private let keychainKey = "binthere_evidence_aes256"
    private let captureCooldown: TimeInterval = 5.0
    private var lastCaptureTime: TimeInterval = 0
    private let evidenceDirectory: URL
    private let auditFileURL: URL
    private let symmetricKey: SymmetricKey

    private init() {
        self.symmetricKey = Self.loadOrCreateKey()
        let dir = Self.setupEvidenceDirectory()
        self.evidenceDirectory = dir
        self.auditFileURL = dir.appendingPathComponent("audit_log.enc")
        logger.info("BinThereEvidenceManager initialized")
    }

    // MARK: - Violation Handler

    func handleViolation(reason: String, sampleBuffer: CMSampleBuffer) {
        let now = CACurrentMediaTime()
        guard now - lastCaptureTime >= captureCooldown else {
            logger.debug("Capture cooldown active, skipping")
            return
        }
        lastCaptureTime = now

        let image = Self.convertSampleBufferToImage(sampleBuffer)
        var evidenceFilename: String?

        if let image, let encryptedData = encryptImage(image) {
            let filename = "EV_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).dat"
            let fileURL = evidenceDirectory.appendingPathComponent(filename)
            do {
                try encryptedData.write(to: fileURL, options: .completeFileProtection)
                evidenceFilename = filename
                logger.info("Evidence captured and encrypted: \(filename)")
            } catch {
                logger.error("Failed to write evidence: \(error)")
            }
        }

        appendAuditLog(reason: reason, evidenceFilename: evidenceFilename)
    }

    // MARK: - Silent Frame Capture

    private static func convertSampleBufferToImage(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
    }

    // MARK: - AES-GCM 256 Encryption

    private func encryptImage(_ image: UIImage) -> Data? {
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return nil }
        do {
            let sealed = try AES.GCM.seal(jpegData, using: symmetricKey)
            guard let combined = sealed.combined else {
                logger.error("AES-GCM seal produced nil combined data")
                return nil
            }
            return combined
        } catch {
            logger.error("AES-GCM encryption failed: \(error)")
            return nil
        }
    }

    // MARK: - Audit Log

    private func appendAuditLog(reason: String, evidenceFilename: String?) {
        let entry = BinThereAuditEntry(
            timestamp: Date(),
            reason: reason,
            evidenceFilename: evidenceFilename,
            deviceModel: Self.deviceModel()
        )

        var existingEntries: [BinThereAuditEntry] = []
        if let existingData = try? Data(contentsOf: auditFileURL),
           let sealedBox = try? AES.GCM.SealedBox(combined: existingData),
           let decrypted = try? AES.GCM.open(sealedBox, using: symmetricKey),
           let decoded = try? JSONDecoder().decode([BinThereAuditEntry].self, from: decrypted) {
            existingEntries = decoded
        }
        existingEntries.append(entry)

        do {
            let encoded = try JSONEncoder().encode(existingEntries)
            let sealed = try AES.GCM.seal(encoded, using: symmetricKey)
            guard let combined = sealed.combined else { return }
            try combined.write(to: auditFileURL, options: .completeFileProtection)
        } catch {
            logger.error("Audit log write failed: \(error)")
        }
    }

    // MARK: - Keychain Key Management

    private static func loadOrCreateKey() -> SymmetricKey {
        let account = "binthere_evidence_aes256"
        let service = "com.popopxchat.popopx"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data, keyData.count == 32 {
            return SymmetricKey(data: keyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(addQuery as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)

        return newKey
    }

    // MARK: - Directory Setup

    private static func setupEvidenceDirectory() -> URL {
        let fileManager = FileManager.default
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let evidenceDir = libraryURL.appendingPathComponent("SecureAudit", isDirectory: true)
            .appendingPathComponent("Evidence", isDirectory: true)

        if !fileManager.fileExists(atPath: evidenceDir.path) {
            do {
                try fileManager.createDirectory(at: evidenceDir, withIntermediateDirectories: true, attributes: [
                    .protectionKey: FileProtectionType.completeUnlessOpen
                ])
            } catch {
                let logger = Logger(subsystem: "im.popopx", category: "BinThereEvidence")
                logger.error("Failed to create evidence directory: \(error)")
            }

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableURL = evidenceDir
            try? mutableURL.setResourceValues(resourceValues)
        }

        return evidenceDir
    }

    // MARK: - Helpers

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { acc, element in
            guard let value = element.value as? Int8, value != 0 else { return acc }
            return acc + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    func auditEntryCount() -> Int {
        guard let data = try? Data(contentsOf: auditFileURL),
              let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(sealedBox, using: symmetricKey),
              let entries = try? JSONDecoder().decode([BinThereAuditEntry].self, from: decrypted) else {
            return 0
        }
        return entries.count
    }
}
