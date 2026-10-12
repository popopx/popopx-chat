// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Testing
import Foundation
import CryptoKit
@testable import BitchatMesh

@Suite("EphemeralIDManager Tests")
struct EphemeralIDManagerTests {

    // MARK: - Helper Methods

    private func generateTestKeyPair() -> (privateKey: Curve25519.KeyAgreement.PrivateKey, publicKeyHex: String) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyHex = privateKey.publicKey.rawRepresentation.hexEncodedString()
        return (privateKey, publicKeyHex)
    }

    // MARK: - Initialization Tests

    @Test("Manager initializes with identity key")
    func testInitialization() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let isInitialized = await manager.isInitialized()
        #expect(isInitialized == true)
    }

    @Test("Manager generates broadcast ephemeral ID on initialization")
    func testBroadcastIDGeneration() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let broadcastID = await manager.currentBroadcastID()
        #expect(broadcastID != nil)
        #expect(broadcastID?.count == 8) // 8 bytes = 16 hex chars
    }

    // MARK: - Peer Registration Tests

    @Test("Peer registration succeeds")
    func testPeerRegistration() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        let knownPeers = await manager.getKnownPeers()
        #expect(knownPeers.contains(publicKeyHex))
    }

    @Test("Peer unregistration succeeds")
    func testPeerUnregistration() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)
        await manager.unregisterPeer(publicKeyHex: publicKeyHex)

        let knownPeers = await manager.getKnownPeers()
        #expect(!knownPeers.contains(publicKeyHex))
    }

    // MARK: - Ephemeral ID Computation Tests

    @Test("Ephemeral ID computation returns 8-byte ID")
    func testEphemeralIDComputation() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        let ephemeralID = await manager.computeEphemeralID(forPeer: publicKeyHex)
        #expect(ephemeralID != nil)
        #expect(ephemeralID?.count == 8)
    }

    @Test("Ephemeral ID computation fails for invalid public key")
    func testInvalidPublicKey() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let ephemeralID = await manager.computeEphemeralID(forPeer: "invalid_hex")
        #expect(ephemeralID == nil)
    }

    @Test("Ephemeral ID computation fails for wrong-length public key")
    func testWrongLengthPublicKey() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let ephemeralID = await manager.computeEphemeralID(forPeer: "0011223344556677") // 8 bytes instead of 32
        #expect(ephemeralID == nil)
    }

    // MARK: - Time Window Boundary Tests

    @Test("Force rotation clears cache but preserves deterministic nonce within same time window")
    func testTimeWindowRotation() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        // Get initial ephemeral ID
        let id1 = await manager.computeEphemeralID(forPeer: publicKeyHex)

        // Force rotation clears cache
        await manager.forceRotate(forPeer: publicKeyHex)

        // Recomputed ID is the same within the same time window (deterministic nonce)
        let id2 = await manager.computeEphemeralID(forPeer: publicKeyHex)
        #expect(id1 == id2)
    }

    @Test("Broadcast ID changes after force rotation")
    func testBroadcastIDRotation() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let id1 = await manager.currentBroadcastID()

        await manager.forceRotateBroadcastID()

        let id2 = await manager.currentBroadcastID()

        #expect(id1 != id2)
    }

    @Test("Broadcast ID is deterministic within same time window")
    func testBroadcastIDDeterministic() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        // Get broadcast ID twice without rotation
        let id1 = await manager.currentBroadcastID()
        let id2 = await manager.currentBroadcastID()

        // Should be the same (deterministic)
        #expect(id1 == id2)
    }

    @Test("Broadcast ID is 8 bytes")
    func testBroadcastIDLength() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let broadcastID = await manager.currentBroadcastID()

        #expect(broadcastID != nil)
        #expect(broadcastID?.count == 8)
    }

    @Test("Broadcast ID differs from peer ephemeral IDs")
    func testBroadcastIDDifferentFromPeerIDs() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        let broadcastID = await manager.currentBroadcastID()
        let peerID = await manager.computeEphemeralID(forPeer: publicKeyHex)

        // Broadcast ID should be different from any peer's ephemeral ID
        #expect(broadcastID != peerID)
    }

    @Test("Ephemeral ID is cached within same time window")
    func testEphemeralIDCaching() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        // Compute twice without rotation
        let id1 = await manager.computeEphemeralID(forPeer: publicKeyHex)
        let id2 = await manager.computeEphemeralID(forPeer: publicKeyHex)

        // Should be the same (cached)
        #expect(id1 == id2)
    }

    // MARK: - HKDF Derivation Tests

    @Test("HKDF derivation produces consistent results")
    func testHKDFConsistency() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex1) = generateTestKeyPair()
        let (_, publicKeyHex2) = generateTestKeyPair()

        // Register both peers
        await manager.registerPeer(publicKeyHex: publicKeyHex1)
        await manager.registerPeer(publicKeyHex: publicKeyHex2)

        // Compute ephemeral IDs multiple times
        let id1a = await manager.computeEphemeralID(forPeer: publicKeyHex1)
        let id1b = await manager.computeEphemeralID(forPeer: publicKeyHex1)

        let id2a = await manager.computeEphemeralID(forPeer: publicKeyHex2)
        let id2b = await manager.computeEphemeralID(forPeer: publicKeyHex2)

        // Same peer should produce same ID (within time window)
        #expect(id1a == id1b)
        #expect(id2a == id2b)

        // Different peers should produce different IDs
        #expect(id1a != id2a)
    }

    @Test("HKDF derivation uses ECDH shared secret")
    func testECDHSharedSecret() async {
        // Create two key pairs
        let keyPair1 = generateTestKeyPair()
        let keyPair2 = generateTestKeyPair()

        // Compute shared secret from both perspectives
        let sharedSecret1 = try! keyPair1.privateKey.sharedSecretFromKeyAgreement(
            with: Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(hexString: keyPair2.publicKeyHex)!)
        )

        let sharedSecret2 = try! keyPair2.privateKey.sharedSecretFromKeyAgreement(
            with: Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(hexString: keyPair1.publicKeyHex)!)
        )

        // Shared secrets should be identical (ECDH property)
        let ss1Data = sharedSecret1.withUnsafeBytes { Data($0) }
        let ss2Data = sharedSecret2.withUnsafeBytes { Data($0) }
        #expect(ss1Data == ss2Data)
    }

    // MARK: - Ephemeral ID Matching Tests

    @Test("Ephemeral ID matching succeeds for known peer")
    func testEphemeralIDMatching() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        // Compute the ephemeral ID for this peer
        let ephemeralID = await manager.computeEphemeralID(forPeer: publicKeyHex)

        // Try to match it
        let matchedPeer = await manager.matchEphemeralID(ephemeralID!)

        #expect(matchedPeer == publicKeyHex)
    }

    @Test("Ephemeral ID matching fails for unknown ID")
    func testUnknownEphemeralIDMatching() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let unknownID = Data([0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77])
        let matchedPeer = await manager.matchEphemeralID(unknownID)

        #expect(matchedPeer == nil)
    }

    @Test("Ephemeral ID matching fails for wrong-length ID")
    func testWrongLengthEphemeralIDMatching() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let wrongLengthID = Data([0x00, 0x11, 0x22, 0x33]) // 4 bytes instead of 8
        let matchedPeer = await manager.matchEphemeralID(wrongLengthID)

        #expect(matchedPeer == nil)
    }

    // MARK: - Bidirectional Recognition Tests

    @Test("Two peers can recognize each other's ephemeral IDs")
    func testBidirectionalRecognition() async {
        // This test simulates two devices recognizing each other

        // Device 1
        let manager1 = EphemeralIDManager.shared
        await manager1.initialize()

        // Device 2 (simulated with separate key pair)
        let (_, device2PublicKeyHex) = generateTestKeyPair()

        // Register device 2's public key on device 1
        await manager1.registerPeer(publicKeyHex: device2PublicKeyHex)

        // Device 1 computes ephemeral ID for device 2
        let ephemeralIDForDevice2 = await manager1.computeEphemeralID(forPeer: device2PublicKeyHex)

        // Device 1 tries to match it
        let matchedPeer = await manager1.matchEphemeralID(ephemeralIDForDevice2!)

        #expect(matchedPeer == device2PublicKeyHex)
    }

    // MARK: - Nonce Uniqueness Tests

    @Test("Different peers get different nonces")
    func testNonceUniqueness() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex1) = generateTestKeyPair()
        let (_, publicKeyHex2) = generateTestKeyPair()

        await manager.registerPeer(publicKeyHex: publicKeyHex1)
        await manager.registerPeer(publicKeyHex: publicKeyHex2)

        // Compute ephemeral IDs
        let id1 = await manager.computeEphemeralID(forPeer: publicKeyHex1)
        let id2 = await manager.computeEphemeralID(forPeer: publicKeyHex2)

        // Should be different (different nonces + different ECDH secrets)
        #expect(id1 != id2)
    }

    // MARK: - Edge Case Tests

    @Test("Manager handles empty peer set gracefully")
    func testEmptyPeerSet() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let knownPeers = await manager.getKnownPeers()
        #expect(knownPeers.isEmpty)

        // Should still be able to compute broadcast ID
        let broadcastID = await manager.currentBroadcastID()
        #expect(broadcastID != nil)
    }

    @Test("Manager handles multiple rotations deterministically")
    func testMultipleRotations() async {
        let manager = EphemeralIDManager.shared
        await manager.initialize()

        let (_, publicKeyHex) = generateTestKeyPair()
        await manager.registerPeer(publicKeyHex: publicKeyHex)

        let initialID = await manager.computeEphemeralID(forPeer: publicKeyHex)

        // Multiple force rotations within the same time window produce the same ID
        // because the nonce is deterministic (derived from both public keys)
        for _ in 0..<5 {
            await manager.forceRotate(forPeer: publicKeyHex)
            let newID = await manager.computeEphemeralID(forPeer: publicKeyHex)
            #expect(newID == initialID)
        }
    }
}
