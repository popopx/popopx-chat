// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  KeyDerivation.swift
//  POPOPXSwitch
//
//  Created for security enhancement - PBKDF2 key derivation
//

import Foundation
import CommonCrypto

/// Key derivation parameters
public struct KeyDerivationParams {
    public static let saltLength = 32
    public static let keyLength = 32
    public static let iterations = 600_000
    public static let algorithm = CCPBKDFAlgorithm(kCCPBKDF2)
    public static let prf = CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256)
}

/// Derives an encryption key from a passphrase using PBKDF2
/// - Parameters:
///   - passphrase: The user's passphrase
///   - salt: Random salt (generated if nil)
///   - iterations: Number of PBKDF2 iterations (default: 100,000)
/// - Returns: Tuple of (derivedKey, salt) or nil on failure
public func deriveKey(from passphrase: String, salt: Data? = nil, iterations: Int = KeyDerivationParams.iterations) -> (key: String, salt: String)? {
    var passphraseData = passphrase.data(using: .utf8)
    guard passphraseData != nil else {
        logger.error("deriveKey: failed to convert passphrase to data")
        return nil
    }
    let pd = passphraseData!

    let saltData: Data
    if let salt = salt {
        saltData = salt
    } else if let generated = generateRandomSalt() {
        saltData = generated
    } else {
        logger.error("deriveKey: failed to generate random salt")
        return nil
    }
    var derivedKey = Data(count: KeyDerivationParams.keyLength)

    let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
        saltData.withUnsafeBytes { saltBytes in
            pd.withUnsafeBytes { passphraseBytes in
                CCKeyDerivationPBKDF(
                    KeyDerivationParams.algorithm,
                    passphrase,
                    pd.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    saltData.count,
                    KeyDerivationParams.prf,
                    UInt32(iterations),
                    derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    KeyDerivationParams.keyLength
                )
            }
        }
    }

    // Zeroize passphrase data immediately after use
    if var pd = passphraseData {
        pd.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) }
    }
    passphraseData = nil

    guard status == kCCSuccess else {
        logger.error("deriveKey: PBKDF2 failed with status \(status)")
        return nil
    }

    let result = (derivedKey.base64EncodedString(), saltData.base64EncodedString())
    derivedKey.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) }
    return result
}

/// Generates a random salt for key derivation
/// - Returns: Random salt data, or nil if secure random generation fails
public func generateRandomSalt() -> Data? {
    var salt = Data(count: KeyDerivationParams.saltLength)
    let status = salt.withUnsafeMutableBytes {
        guard let base = $0.baseAddress else { return errSecParam }
        return SecRandomCopyBytes(kSecRandomDefault, KeyDerivationParams.saltLength, base)
    }
    guard status == errSecSuccess else {
        logger.error("generateRandomSalt: SecRandomCopyBytes failed with status \(status)")
        return nil
    }
    return salt
}

/// Key rotation metadata
struct KeyRotationMetadata: Codable {
    var version: Int
    var lastRotatedAt: Date
    var rotationIntervalDays: Int

    static let defaultRotationInterval = 90 // days

    init(version: Int = 1, lastRotatedAt: Date = Date(), rotationIntervalDays: Int = defaultRotationInterval) {
        self.version = version
        self.lastRotatedAt = lastRotatedAt
        self.rotationIntervalDays = rotationIntervalDays
    }

    var needsRotation: Bool {
        let daysSinceRotation = Calendar.current.dateComponents([.day], from: lastRotatedAt, to: Date()).day ?? 0
        return daysSinceRotation >= rotationIntervalDays
    }
}

/// Manages key rotation state
class KeyRotationManager {
    static let shared = KeyRotationManager()

    private let metadataKey = "databaseKeyRotationMetadata"

    func getMetadata() -> KeyRotationMetadata {
        if let data = UserDefaults.standard.data(forKey: metadataKey) {
            do {
                let metadata = try JSONDecoder().decode(KeyRotationMetadata.self, from: data)
                return metadata
            } catch {
                logger.error("KeyRotationManager.getMetadata: failed to decode key rotation metadata: \(error)")
                return KeyRotationMetadata()
            }
        }
        return KeyRotationMetadata()
    }

    func updateMetadata(_ metadata: KeyRotationMetadata) {
        do {
            let data = try JSONEncoder().encode(metadata)
            UserDefaults.standard.set(data, forKey: metadataKey)
        } catch {
            logger.error("KeyRotationManager.updateMetadata: failed to encode metadata: \(error)")
        }
    }

    func incrementVersion() {
        var metadata = getMetadata()
        metadata.version += 1
        metadata.lastRotatedAt = Date()
        updateMetadata(metadata)
    }

    func shouldRotate() -> Bool {
        return getMetadata().needsRotation
    }
}
