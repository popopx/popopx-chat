// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import BitFoundation
import Foundation
import CryptoKit

/// Bridge between Noise and Nostr identities
final class NostrIdentityBridge {
    private let keychainService = "chat.bitchat.nostr"
    private let currentIdentityKey = "nostr-current-identity"
    private let deviceSeedKey = "nostr-device-seed"
    private let masterSeedKey = "nostr-master-seed"
    // In-memory cache to avoid transient keychain access issues
    private var deviceSeedCache: Data?
    // Cache derived identities to avoid repeated crypto during view rendering
    private var derivedIdentityCache: [String: NostrIdentity] = [:]
    private var cacheAccessOrder: [String] = []
    private let maxCacheSize = 64
    private let cacheLock = NSLock()
    private let deviceSeedLock = NSLock()

    private let keychain: KeychainManagerProtocol

    init(keychain: KeychainManagerProtocol = KeychainManager.makeDefault()) {
        self.keychain = keychain
    }
    
    /// Get or create the current Nostr identity
    func getCurrentNostrIdentity() throws -> NostrIdentity? {
        // Check if we already have a Nostr identity
        if let existingData = keychain.load(key: currentIdentityKey, service: keychainService),
           let identity = try? JSONDecoder().decode(NostrIdentity.self, from: existingData) {
            // Codable excludes privateKey, so a decoded identity always has an empty key.
            // Attempt to re-derive from the stored master seed to restore the full identity.
            if identity.privateKey.isEmpty {
                if let masterSeed = keychain.load(key: masterSeedKey, service: keychainService) {
                    let restored = try derivePrimaryFromMasterSeed(masterSeed)
                    return restored
                }
                // No master seed available — cannot produce a functional identity
                struct MissingPrivateKeyError: Error, LocalizedError {
                    var errorDescription: String? { "Nostr identity is missing private key and no master seed is available for re-derivation" }
                }
                throw MissingPrivateKeyError()
            }
            return identity
        }
        
        // Generate new Nostr identity
        let nostrIdentity = try NostrIdentity.generate()
        
        // Store it
        let data = try JSONEncoder().encode(nostrIdentity)
        keychain.save(key: currentIdentityKey, data: data, service: keychainService, accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
        
        return nostrIdentity
    }
    
    /// Get Nostr public key associated with a Noise public key
    func getNostrPublicKey(for noisePublicKey: Data) -> String? {
        let key = "nostr-noise-\(noisePublicKey.base64EncodedString())"
        guard let data = keychain.load(key: key, service: keychainService),
              let pubkey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return pubkey
    }

    /// Associate a Noise public key with a Nostr public key
    func associateNoiseKey(_ noisePublicKey: Data, withNostrPubKey nostrPubKeyHex: String) {
        let key = "nostr-noise-\(noisePublicKey.base64EncodedString())"
        guard let data = nostrPubKeyHex.data(using: .utf8) else { return }
        keychain.save(key: key, data: data, service: keychainService, accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
    }
    
    /// Clear all Nostr identity associations and current identity
    func clearAllAssociations() {
        // Must go through the injected keychain, not raw SecItem calls:
        // under test that keychain is in-memory, and a direct delete here
        // would wipe the developer's real Nostr identity on every test run.
        keychain.deleteAll(service: keychainService)

        cacheLock.lock()
        deviceSeedCache = nil
        derivedIdentityCache.removeAll()
        cacheAccessOrder.removeAll()
        cacheLock.unlock()
    }

    // MARK: - Unified Identity Derivation

    /// Derive the primary Nostr identity deterministically from the unified master seed
    /// (the Curve25519 identity key material). Also derives the per-geohash device seed
    /// from the same root, so all Nostr keys trace back to a single identity.
    ///
    /// Domain separation:
    /// - Primary identity: HMAC-SHA256(masterSeed, "popop-nostr-primary-v1")
    /// - Device seed:      HMAC-SHA256(masterSeed, "popop-nostr-device-seed-v1")
    func derivePrimaryFromMasterSeed(_ masterSeed: Data) throws -> NostrIdentity {
        let primaryKey = HMAC<SHA256>.authenticationCode(
            for: Data("popop-nostr-primary-v1".utf8),
            using: SymmetricKey(data: masterSeed)
        )
        let identity = try NostrIdentity(privateKeyData: Data(primaryKey))

        let data = try JSONEncoder().encode(identity)
        keychain.save(key: currentIdentityKey, data: data, service: keychainService, accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)

        // Store the master seed so getCurrentNostrIdentity can re-derive after Codable round-trip
        keychain.save(key: masterSeedKey, data: masterSeed, service: keychainService, accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)

        let derivedDeviceSeed = HMAC<SHA256>.authenticationCode(
            for: Data("popop-nostr-device-seed-v1".utf8),
            using: SymmetricKey(data: masterSeed)
        )
        keychain.save(
            key: deviceSeedKey,
            data: Data(derivedDeviceSeed),
            service: keychainService,
            accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        )
        cacheLock.lock()
        deviceSeedCache = Data(derivedDeviceSeed)
        derivedIdentityCache.removeAll()
        cacheAccessOrder.removeAll()
        cacheLock.unlock()

        return identity
    }

    // MARK: - Per-Geohash Identities (Location Channels)

    /// Returns a stable device seed used to derive unlinkable per-geohash identities.
    /// Stored only on device keychain.
    private func getOrCreateDeviceSeed() throws -> Data {
        deviceSeedLock.lock()
        defer { deviceSeedLock.unlock() }

        // Check in-memory cache first (now safe under deviceSeedLock)
        if let cached = deviceSeedCache {
            return cached
        }

        // Check keychain
        if let existing = keychain.load(key: deviceSeedKey, service: keychainService) {
            // Migrate to WhenPasscodeSetThisDeviceOnly for enhanced security
            keychain.save(key: deviceSeedKey, data: existing, service: keychainService, accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
            deviceSeedCache = existing
            return existing
        }

        // Generate new seed
        var seed = Data(count: 32)
        let randomStatus = seed.withUnsafeMutableBytes { ptr -> OSStatus in
            guard let baseAddress = ptr.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, 32, baseAddress)
        }
        guard randomStatus == errSecSuccess else {
            struct SecureRandomError: Error, LocalizedError {
                let status: OSStatus
                var errorDescription: String? { "SecRandomCopyBytes failed for device seed: status \(status)" }
            }
            throw SecureRandomError(status: randomStatus)
        }
        // Use WhenPasscodeSetThisDeviceOnly - available only when passcode is set, deleted on app uninstall
        keychain.save(key: deviceSeedKey, data: seed, service: keychainService, accessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
        deviceSeedCache = seed
        return seed
    }

    /// Derive a deterministic, unlinkable Nostr identity for a mesh-bridge
    /// rendezvous cell. Distinct HMAC label keeps it unlinkable from the
    /// geohash-chat identity for the same cell string.
    func deriveIdentity(forBridgeRendezvous cell: String) throws -> NostrIdentity {
        try deriveIdentity(forGeohash: "bridge|" + cell)
    }

    /// Derive a deterministic, unlinkable Nostr identity for a given geohash.
    /// Uses HMAC-SHA256(deviceSeed, geohash) as private key material, with fallback rehashing
    /// if the candidate is not a valid secp256k1 private key.
    func deriveIdentity(forGeohash geohash: String) throws -> NostrIdentity {
        // Check cache first to avoid repeated crypto + keychain I/O during view rendering
        cacheLock.lock()
        if let cached = derivedIdentityCache[geohash] {
            cacheAccessOrder.removeAll(where: { $0 == geohash })
            cacheAccessOrder.append(geohash)
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let seed = try getOrCreateDeviceSeed()
        guard let msg = geohash.data(using: .utf8) else {
            throw NSError(domain: "NostrIdentity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid geohash string"])
        }

        func candidateKey(iteration: UInt32) -> Data {
            var input = Data(msg)
            var iterBE = iteration.bigEndian
            withUnsafeBytes(of: &iterBE) { bytes in
                input.append(contentsOf: bytes)
            }
            let code = HMAC<SHA256>.authenticationCode(for: input, using: SymmetricKey(data: seed))
            return Data(code)
        }

        // Try a few iterations to ensure a valid key can be formed
        for i in 0..<10 {
            let keyData = candidateKey(iteration: UInt32(i))
            if let identity = try? NostrIdentity(privateKeyData: keyData) {
                cacheLock.lock()
                insertIntoCache(key: geohash, identity: identity)
                cacheLock.unlock()
                return identity
            }
        }
        // As a final fallback, hash the seed+msg and try again
        let fallback = (seed + msg).sha256Hash()
        let identity = try NostrIdentity(privateKeyData: fallback)

        // Cache the result
        cacheLock.lock()
        insertIntoCache(key: geohash, identity: identity)
        cacheLock.unlock()

        return identity
    }

    /// Insert into cache with LRU eviction. Must be called with cacheLock held.
    private func insertIntoCache(key: String, identity: NostrIdentity) {
        derivedIdentityCache[key] = identity
        cacheAccessOrder.removeAll(where: { $0 == key })
        cacheAccessOrder.append(key)
        while cacheAccessOrder.count > maxCacheSize, let oldest = cacheAccessOrder.first {
            cacheAccessOrder.removeFirst()
            derivedIdentityCache.removeValue(forKey: oldest)
        }
    }
}
