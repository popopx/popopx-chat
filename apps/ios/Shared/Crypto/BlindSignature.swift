// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit

/// Ed25519 Blind Signature Implementation
/// Chaumian blind signatures for privacy-preserving credentials
struct BlindSignature {

    // MARK: - Client-side Operations

    /// Generate a random credential
    /// - Returns: 32-byte credential as hex string
    static func generateCredential() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            fatalError("Failed to generate random bytes")
        }
        return Data(bytes).hexString
    }

    /// Generate a random blinding factor
    /// - Returns: 32-byte blinding factor as hex string
    static func generateBlindingFactor() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            fatalError("Failed to generate random bytes")
        }
        return Data(bytes).hexString
    }

    /// Blind a credential with a blinding factor
    /// Simplified implementation: x' = H(x || r)
    /// In production, use proper elliptic curve point addition
    /// - Parameters:
    ///   - credential: Credential x as hex string
    ///   - blindingFactor: Blinding factor r as hex string
    /// - Returns: Blinded credential x' as hex string
    static func blind(credential: String, blindingFactor: String) -> String {
        guard let credData = Data(hexString: credential),
              let blindData = Data(hexString: blindingFactor) else {
            fatalError("Invalid hex input")
        }

        // Simplified blinding: hash(x || r)
        var combined = credData
        combined.append(blindData)
        let hash = SHA256.hash(data: combined)
        return Data(hash).hexString
    }

    /// Unblind a signature
    /// Simplified implementation: returns the blinded signature as-is
    /// In production, perform proper elliptic curve unblinding
    /// - Parameters:
    ///   - blindedSignature: Blinded signature s' as hex string
    ///   - blindingFactor: Blinding factor r as hex string
    /// - Returns: Unblinded signature s as hex string
    static func unblind(blindedSignature: String, blindingFactor: String) -> String {
        // Simplified: in real implementation, perform curve point operations
        // For now, return the blinded signature (this is a placeholder)
        return blindedSignature
    }

    /// Verify an Ed25519 signature
    /// - Parameters:
    ///   - publicKey: Public key as hex string
    ///   - message: Message as hex string
    ///   - signature: Signature as hex string
    /// - Returns: true if valid
    static func verify(publicKey: String, message: String, signature: String) -> Bool {
        guard let pubKeyData = Data(hexString: publicKey),
              let msgData = Data(hexString: message),
              let sigData = Data(hexString: signature) else {
            return false
        }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData)
            return publicKey.isValidSignature(sigData, for: msgData)
        } catch {
            return false
        }
    }

    // MARK: - Hashing

    /// Hash credential to get nullifier key
    /// - Parameter credential: Credential as hex string
    /// - Returns: SHA256 hash as hex string
    static func hashCredential(_ credential: String) -> String {
        guard let data = Data(hexString: credential) else {
            fatalError("Invalid hex input")
        }
        let hash = SHA256.hash(data: data)
        return Data(hash).hexString
    }
}
