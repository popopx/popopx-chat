// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereCrypto.swift
//  POPOPX (iOS)
//
//  AES-256-GCM encryption for burn-after-read messages.
//  Keys are ephemeral per-paste (not derived from a master key).
//

import CryptoKit
import Foundation

enum BinThereCrypto {

    static func generateCEK() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func encrypt(plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw BinThereError.encryptionFailed
        }
        return combined
    }

    static func decrypt(combined: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    static func exportKey(_ key: SymmetricKey) -> String {
        let raw = key.withUnsafeBytes { Data($0) }
        return raw.base64URLEncodedString()
    }

    static func importKey(_ b64url: String) -> SymmetricKey? {
        guard let data = Data(base64URLEncoded: b64url), data.count == 32 else {
            return nil
        }
        return SymmetricKey(data: data)
    }
}

enum BinThereError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyImportFailed
    case botTimeout
    case pasteGone
    case botNotConfigured
    case imageCompressionFailed
    case concurrentOperation

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return NSLocalizedString("binthere_encrypt_failed", comment: "Failed to encrypt message")
        case .decryptionFailed: return NSLocalizedString("binthere_decrypt_failed", comment: "Failed to decrypt — message may be corrupted")
        case .keyImportFailed: return NSLocalizedString("binthere_invalid_key", comment: "Invalid decryption key")
        case .botTimeout: return NSLocalizedString("binthere_bot_timeout", comment: "Bot did not respond in time")
        case .pasteGone: return NSLocalizedString("binthere_message_expired", comment: "This message has already been read or has expired")
        case .botNotConfigured: return NSLocalizedString("binthere_bot_not_configured", comment: "BinThere bot is not configured")
        case .imageCompressionFailed: return NSLocalizedString("binthere_compress_failed", comment: "Failed to compress image below size limit")
        case .concurrentOperation: return NSLocalizedString("binthere_operation_in_progress", comment: "Another store operation is already in progress")
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded: String) {
        var padded = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder > 0 {
            padded.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: padded)
    }
}
