// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit
import BitFoundation
import BitLogger

/// Manages ephemeral BLE broadcast IDs derived via ECDH for privacy-preserving peer discovery.
///
/// Instead of broadcasting static peer identifiers (which enable long-term tracking),
/// this manager derives time-rotating ephemeral IDs using ECDH shared secrets between
/// peer pairs. Only peers who have exchanged public keys (via QR code) can compute
/// matching ephemeral IDs and recognize each other.
///
/// Rotation strategy:
/// - Time-based: IDs rotate every `rotationInterval` (default: 1 hour)
/// - Session-based: IDs rotate per BLE connection session
/// - Third-party observers see only random-looking bytes that change periodically
actor EphemeralIDManager {
    static let shared = EphemeralIDManager()

    // MARK: - Configuration

    /// Ephemeral ID rotation interval (seconds). Default: 1 hour.
    private let rotationInterval: TimeInterval = 3600

    /// Ephemeral ID length in bytes (8 bytes = 16 hex chars, matches PeerID short format)
    private let ephemeralIDLength = 8

    /// Info string for HKDF key derivation
    private let hkdfInfo = Data("bitchat-ephemeral-id".utf8)

    // MARK: - State

    /// Local identity key for ECDH (separate from Noise static key for isolation)
    private var ephemeralIdentityKey: Curve25519.KeyAgreement.PrivateKey?

    /// Cached ephemeral IDs: peerPublicKeyHex -> (ephemeralID, expiresAt)
    private var ephemeralCache: [String: (id: Data, expiresAt: Date)] = [:]

    /// Nonces for each peer pair (ensures unique derivation per pair)
    private var peerNonces: [String: Data] = [:]

    /// Known peer public keys (from QR code exchanges)
    private var knownPeerPublicKeys: Set<String> = []

    /// Current broadcast ephemeral ID (our own, for discovery by others)
    private var currentBroadcastEphemeralID: Data?
    private var broadcastIDExpiresAt: Date?

    private let keychainService = "chat.popop.ephemeral-identity"
    private let keychainAccount = "ephemeral-keypair"

    private init() {}

    // MARK: - Initialization

    /// Initialize the ephemeral ID manager with a dedicated identity key.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func initialize() async {
        guard ephemeralIdentityKey == nil else { return }

        if let existing = loadKeyFromKeychain() {
            ephemeralIdentityKey = existing
        } else {
            let newKey = Curve25519.KeyAgreement.PrivateKey()
            ephemeralIdentityKey = newKey
            saveKeyToKeychain(newKey)
        }

        // Generate initial broadcast ephemeral ID
        await rotateBroadcastID()
    }

    // MARK: - Peer Registration

    /// Register a peer's public key for ephemeral ID computation.
    /// Called when a peer is added via QR code exchange.
    func registerPeer(publicKeyHex: String) async {
        knownPeerPublicKeys.insert(publicKeyHex)

        // Derive nonce deterministically from both public keys so both peers
        // compute the same nonce (and thus the same ephemeral ID).
        if peerNonces[publicKeyHex] == nil {
            peerNonces[publicKeyHex] = deriveDeterministicNonce(peerPublicKeyHex: publicKeyHex)
        }
    }

    /// Unregister a peer's public key.
    func unregisterPeer(publicKeyHex: String) async {
        knownPeerPublicKeys.remove(publicKeyHex)
        peerNonces.removeValue(forKey: publicKeyHex)
        ephemeralCache.removeValue(forKey: publicKeyHex)
    }

    // MARK: - Ephemeral ID Computation

    /// Compute the ephemeral ID for a specific peer (for recognizing them in broadcasts).
    /// Both peers compute the same ephemeral ID using their private key + peer's public key.
    func computeEphemeralID(forPeer publicKeyHex: String) async -> Data? {
        guard let identityKey = ephemeralIdentityKey,
              let peerPublicKeyData = Data(hexString: publicKeyHex),
              peerPublicKeyData.count == 32 else {
            return nil
        }

        // Check cache first
        let now = Date()
        if let cached = ephemeralCache[publicKeyHex], cached.expiresAt > now {
            return cached.id
        }

        // Derive peer's public key
        guard let peerPublicKey = try? Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: peerPublicKeyData
        ) else {
            return nil
        }

        // Perform ECDH to get shared secret
        guard let sharedSecret = try? identityKey.sharedSecretFromKeyAgreement(
            with: peerPublicKey
        ) else {
            return nil
        }

        // Get or generate nonce for this peer pair
        let nonce = peerNonces[publicKeyHex] ?? generateNonce()
        peerNonces[publicKeyHex] = nonce

        // Compute time window for rotation
        let timeWindow = Int(now.timeIntervalSince1970 / rotationInterval)

        // Derive ephemeral ID using HKDF
        let ephemeralID = deriveEphemeralID(
            sharedSecret: sharedSecret,
            nonce: nonce,
            timeWindow: timeWindow
        )

        // Cache the result
        let expiresAt = Date(timeIntervalSince1970: Double(timeWindow + 1) * rotationInterval)
        ephemeralCache[publicKeyHex] = (id: ephemeralID, expiresAt: expiresAt)

        return ephemeralID
    }

    /// Compute our own broadcast ephemeral ID (for advertising).
    /// This is derived from our identity key + a broadcast-specific nonce.
    func computeBroadcastEphemeralID() async -> Data? {
        let now = Date()

        // Return cached if still valid
        if let cached = currentBroadcastEphemeralID,
           let expiresAt = broadcastIDExpiresAt,
           expiresAt > now {
            return cached
        }

        // Rotate if expired
        return await rotateBroadcastID()
    }

    /// Check if a discovered ephemeral ID matches any known peer.
    /// Returns the peer's public key hex if matched, nil otherwise.
    func matchEphemeralID(_ discoveredID: Data) async -> String? {
        guard discoveredID.count == ephemeralIDLength else { return nil }

        // Check all known peers
        for peerPublicKeyHex in knownPeerPublicKeys {
            if let peerEphemeralID = await computeEphemeralID(forPeer: peerPublicKeyHex),
               peerEphemeralID == discoveredID {
                return peerPublicKeyHex
            }
        }

        return nil
    }

    // MARK: - Rotation

    /// Rotate the broadcast ephemeral ID (called periodically or on session change).
    ///
    /// ## Why not use ECDH for broadcast ID?
    ///
    /// Unlike peer-specific ephemeral IDs (which use ECDH with the peer's public key),
    /// the broadcast ID is derived directly from our identity key without ECDH. This is
    /// because:
    ///
    /// 1. **No peer-specific secret**: Broadcast IDs identify ourselves in the mesh.
    ///    There's no shared secret with a specific peer to use for ECDH.
    ///
    /// 2. **Private key derivation**: The broadcast ID is derived from our private identity
    ///    key using HKDF. Only we can compute it — third parties cannot predict or forge
    ///    our broadcast ID even if they observe previous values.
    ///
    /// 3. **Security through HKDF**: The broadcast ID is cryptographically secure because
    ///    it's derived using HKDF-SHA256 with:
    ///    - Input key material: Our identity private key (secret)
    ///    - Salt: A random nonce (unique per rotation)
    ///    - Info: Time window (prevents replay attacks)
    ///
    /// 4. **Rotation provides privacy**: The broadcast ID changes every hour (or on force
    ///    rotation), preventing long-term tracking. Third-party observers see only
    ///    random-looking bytes that change periodically.
    ///
    /// Note: On iOS, the broadcast ID is not included in BLE advertising packets due to
    /// the 31-byte overflow area limitation (only service UUIDs fit). Instead, peer
    /// recognition uses the ECDH-based peer-specific ephemeral IDs exchanged after
    /// connection. The broadcast ID serves as our own rotating self-identifier.
    ///
    /// In contrast, peer-specific ephemeral IDs use ECDH because both peers need to
    /// independently compute the same ID using their private key + the other's public key.
    @discardableResult
    private func rotateBroadcastID() async -> Data? {
        guard let identityKey = ephemeralIdentityKey else { return nil }

        let now = Date()
        let timeWindow = Int(now.timeIntervalSince1970 / rotationInterval)

        // Use a special "broadcast" nonce for our own ID
        let broadcastNonce = peerNonces["broadcast"] ?? generateNonce()
        peerNonces["broadcast"] = broadcastNonce

        // Derive broadcast ephemeral ID directly from identity key (no ECDH needed)
        // This creates a deterministic but rotating ID that peers can verify
        let inputKeyMaterial = identityKey.rawRepresentation
        let symmetricKey = SymmetricKey(data: inputKeyMaterial)

        let prk = HKDF<SHA256>.extract(
            inputKeyMaterial: symmetricKey,
            salt: broadcastNonce
        )

        let timeWindowData = withUnsafeBytes(of: timeWindow.bigEndian) { Data($0) }
        let expandedKey = HKDF<SHA256>.expand(
            pseudoRandomKey: prk,
            info: hkdfInfo + timeWindowData,
            outputByteCount: ephemeralIDLength
        )

        let ephemeralID = expandedKey.withUnsafeBytes { Data($0) }

        currentBroadcastEphemeralID = ephemeralID
        broadcastIDExpiresAt = Date(timeIntervalSince1970: Double(timeWindow + 1) * rotationInterval)

        SecureLogger.info(
            "🔄 Rotated broadcast ephemeral ID: \(ephemeralID.hexEncodedString()), expires at \(broadcastIDExpiresAt ?? now)",
            category: .session
        )

        return ephemeralID
    }

    /// Force rotation for a specific peer (session-based rotation).
    /// Clears the cached ephemeral ID so it is recomputed with the current time window.
    /// The deterministic nonce is preserved to maintain symmetry with the remote peer.
    func forceRotate(forPeer publicKeyHex: String) async {
        ephemeralCache.removeValue(forKey: publicKeyHex)

        SecureLogger.info(
            "🔄 Force rotated ephemeral ID for peer: \(publicKeyHex.prefix(16))...",
            category: .session
        )
    }

    /// Force rotation of broadcast ID (session-based rotation).
    func forceRotateBroadcastID() async {
        // Generate new broadcast nonce
        peerNonces["broadcast"] = generateNonce()

        // Clear current broadcast ID
        currentBroadcastEphemeralID = nil
        broadcastIDExpiresAt = nil

        // Rotate immediately
        _ = await rotateBroadcastID()
    }

    // MARK: - Key Derivation

    /// Derive ephemeral ID from shared secret, nonce, and time window using HKDF.
    private func deriveEphemeralID(
        sharedSecret: SharedSecret,
        nonce: Data,
        timeWindow: Int
    ) -> Data {
        // Combine shared secret with nonce and time window
        let timeWindowData = withUnsafeBytes(of: timeWindow.bigEndian) { Data($0) }
        let inputKeyMaterial = sharedSecret.withUnsafeBytes { Data($0) }

        // Create SymmetricKey from input key material
        let symmetricKey = SymmetricKey(data: inputKeyMaterial)

        // HKDF extract + expand
        let prk = HKDF<SHA256>.extract(
            inputKeyMaterial: symmetricKey,
            salt: nonce
        )

        let expandedKey = HKDF<SHA256>.expand(
            pseudoRandomKey: prk,
            info: hkdfInfo + timeWindowData,
            outputByteCount: ephemeralIDLength
        )

        // Convert SymmetricKey to Data
        return expandedKey.withUnsafeBytes { Data($0) }
    }

    /// Generate a cryptographically secure random nonce.
    private func generateNonce() -> Data {
        var nonce = Data(count: 16)
        nonce.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, baseAddress)
        }
        return nonce
    }

    /// Derive a deterministic nonce from both public keys so that both peers
    /// compute the same nonce. Keys are sorted lexicographically to ensure
    /// the result is identical regardless of which side is "us" vs "peer".
    private func deriveDeterministicNonce(peerPublicKeyHex: String) -> Data {
        guard let identityKey = ephemeralIdentityKey,
              let peerKeyData = Data(hexString: peerPublicKeyHex) else {
            return generateNonce()
        }
        let ourKeyData = identityKey.publicKey.rawRepresentation

        // Sort keys so both peers produce the same input
        let combined: Data
        if ourKeyData.lexicographicallyPrecedes(peerKeyData) {
            combined = ourKeyData + peerKeyData
        } else {
            combined = peerKeyData + ourKeyData
        }

        let hash = SHA256.hash(data: Data("bitchat-ephemeral-nonce".utf8) + combined)
        return Data(hash).prefix(16)
    }

    // MARK: - Keychain

    private func loadKeyFromKeychain() -> Curve25519.KeyAgreement.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    private func saveKeyToKeychain(_ key: Curve25519.KeyAgreement.PrivateKey) {
        let data = key.rawRepresentation

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            SecureLogger.warning("Keychain delete failed: \(deleteStatus)", category: .session)
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            SecureLogger.error("Keychain save failed: \(addStatus)", category: .session)
        }
    }

    // MARK: - Public Accessors

    /// Get the current broadcast ephemeral ID (for BLE advertising).
    func currentBroadcastID() async -> Data? {
        return await computeBroadcastEphemeralID()
    }

    /// Get all known peer public keys.
    func getKnownPeers() async -> Set<String> {
        return knownPeerPublicKeys
    }

    /// Check if the manager is initialized.
    func isInitialized() async -> Bool {
        return ephemeralIdentityKey != nil
    }
}
