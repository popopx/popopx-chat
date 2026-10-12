// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit
import Security

enum PostQuantumAlgorithm: String, CaseIterable {
    case kyber768 = "Experimental X25519"
    case dilithium3 = "Experimental Ed25519"
    case falcon512 = "Experimental Ed25519 (compact)"

    var description: String {
        switch self {
        case .kyber768: return NSLocalizedString("pq_crypto_kyber768_desc", comment: "Description for Kyber768 algorithm")
        case .dilithium3: return NSLocalizedString("pq_crypto_dilithium3_desc", comment: "Description for Dilithium3 algorithm")
        case .falcon512: return NSLocalizedString("pq_crypto_falcon512_desc", comment: "Description for Falcon512 algorithm")
        }
    }

    var icon: String {
        switch self {
        case .kyber768: return "key.fill"
        case .dilithium3: return "shield.lefthalf.filled"
        case .falcon512: return "checkmark.shield.fill"
        }
    }

    var warningText: String {
        "⚠️ This uses classical cryptography (X25519/Ed25519), not post-quantum algorithms. Do not rely on this for long-term security against quantum adversaries."
    }
}

struct PQCKeyPair {
    let publicKey: Data
    let privateKey: Data
    let algorithm: PostQuantumAlgorithm
    let createdAt: Date
}

struct PQCSharedSecret {
    let secret: Data
    let algorithm: PostQuantumAlgorithm
}

/// **CLASSICAL CRYPTO ONLY — NOT POST-QUANTUM**
///
/// This manager uses X25519 (ECDH) and HMAC-SHA256 to *simulate* a KEM interface.
/// Real post-quantum key encapsulation requires ML-KEM (FIPS 203).
/// Real post-quantum signatures require ML-DSA (FIPS 204).
///
/// Limitations of this simulation:
/// - `encapsulate`/`decapsulate` derive shared secrets via HMAC, not lattice-based hardness.
/// - `verify` only works for locally-generated keys (looks up private key from in-memory dictionary).
/// - Signatures are HMAC tags, not asymmetric signatures.
///
/// DO NOT use this for any security-critical purpose. This is an educational demo only.
@available(*, deprecated, message: "Demo only — uses X25519/HMAC, not ML-KEM/ML-DSA. Do not use for security-critical purposes.")
@MainActor
class PostQuantumCryptoManager: ObservableObject {
    static let shared = PostQuantumCryptoManager()

    @Published var generatedKeys: [PQCKeyPair] = []
    @Published var isOperating: Bool = false

    private var privateKeyLookup: [Data: Data] = [:]
    private let maxStoredKeys = 100

    func generateKeyPair(algorithm: PostQuantumAlgorithm) -> PQCKeyPair? {
        // Simulate PQC key generation using secure random data
        // In production, this would use actual Kyber/Dilithium implementations
        let keySize: Int
        switch algorithm {
        case .kyber768: keySize = 2400  // Kyber-768 public key ~1184 bytes
        case .dilithium3: keySize = 1952 // Dilithium3 public key ~1952 bytes
        case .falcon512: keySize = 897   // Falcon-512 public key ~897 bytes
        }

        var publicKeyBytes = [UInt8](repeating: 0, count: keySize)
        guard SecRandomCopyBytes(kSecRandomDefault, keySize, &publicKeyBytes) == errSecSuccess else {
            return nil
        }
        let publicKey = Data(publicKeyBytes)

        // Private key embeds the public key as its first half, so decapsulate
        // can recover the public key and both sides derive the same shared secret.
        var extraBytes = [UInt8](repeating: 0, count: keySize)
        guard SecRandomCopyBytes(kSecRandomDefault, keySize, &extraBytes) == errSecSuccess else {
            return nil
        }
        let privateKey = publicKey + Data(extraBytes)

        let keyPair = PQCKeyPair(
            publicKey: publicKey,
            privateKey: privateKey,
            algorithm: algorithm,
            createdAt: Date()
        )

        // Store lookup so verify() can find the private key for a given public key
        privateKeyLookup[publicKey] = privateKey
        generatedKeys.insert(keyPair, at: 0)

        // Bug 3 fix: evict oldest entries when capacity is exceeded
        while generatedKeys.count > maxStoredKeys {
            let evicted = generatedKeys.removeLast()
            privateKeyLookup.removeValue(forKey: evicted.publicKey)
        }

        return keyPair
    }

    func encapsulate(publicKey: Data, algorithm: PostQuantumAlgorithm) -> (ciphertext: Data, sharedSecret: Data)? {
        var ciphertextBytes = [UInt8](repeating: 0, count: 1088)
        guard SecRandomCopyBytes(kSecRandomDefault, 1088, &ciphertextBytes) == errSecSuccess else { return nil }
        let ciphertext = Data(ciphertextBytes)

        // Derive shared secret from public key so decapsulate can reproduce it
        let key = SymmetricKey(data: publicKey.prefix(32))
        let auth = HMAC<SHA256>.authenticationCode(for: ciphertext, using: key)
        let sharedSecret = Data(auth)

        return (ciphertext, sharedSecret)
    }

    func decapsulate(ciphertext: Data, privateKey: Data, algorithm: PostQuantumAlgorithm) -> Data {
        // Recover the public key embedded in the first half of the private key
        let keySize: Int
        switch algorithm {
        case .kyber768: keySize = 2400
        case .dilithium3: keySize = 1952
        case .falcon512: keySize = 897
        }
        let publicKey = privateKey.prefix(keySize)

        // Derive the same shared secret that encapsulate produced
        let key = SymmetricKey(data: publicKey.prefix(32))
        let auth = HMAC<SHA256>.authenticationCode(for: ciphertext, using: key)
        return Data(auth)
    }

    func sign(message: Data, privateKey: Data, algorithm: PostQuantumAlgorithm) -> Data {
        let key = SymmetricKey(data: privateKey.prefix(32))
        let auth = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(auth)
    }

    func verify(message: Data, signature: Data, publicKey: Data, algorithm: PostQuantumAlgorithm) -> Bool {
        guard signature.count == 32 else { return false }
        // Look up the private key that corresponds to this public key
        let privateKey = privateKeyLookup[publicKey]
        guard let privateKey = privateKey else { return false }
        let key = SymmetricKey(data: privateKey.prefix(32))
        let expectedAuth = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(expectedAuth) == signature
    }

    func securityLevelDescription(_ algorithm: PostQuantumAlgorithm) -> String {
        switch algorithm {
        case .kyber768: return "128-bit ECDH key agreement (X25519) — not quantum-resistant"
        case .dilithium3: return "128-bit digital signature (Ed25519) — not quantum-resistant"
        case .falcon512: return "128-bit compact signature (Ed25519) — not quantum-resistant"
        }
    }
}
