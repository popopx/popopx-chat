// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitLogger

/// Shared runtime holder for host app integration.
/// BitchatBridgeView and the host app's transport layer both access this
/// to share the same AppRuntime instance.
@MainActor
public final class BitchatSharedRuntime {
    public static let shared = BitchatSharedRuntime()

    private var _runtime: AppRuntime?
    private var nostrInboundHandler: ((Data, String) -> Void)?

    public var meshTransport: RichMeshTransport? { _runtime?.meshTransport }
    public var isRunning: Bool { _runtime != nil }

    public var isNostrConnected: Bool { NostrRelayManager.shared.isConnected }
    public var isGatewayEnabled: Bool { GatewayService.shared.isEnabled }
    public var isBridgeEnabled: Bool { BridgeService.shared.isEnabled }

    private init() {}

    func register(_ runtime: AppRuntime) {
        _runtime = runtime
        wireGatewayAndBridge()
    }

    public func ensureStarted() {
        if let existing = _runtime {
            existing.start()
            wireGatewayAndBridge()
        } else {
            let rt = AppRuntime()
            _runtime = rt
            rt.start()
            wireGatewayAndBridge()
        }
    }

    /// Returns the shared AppRuntime, creating it if needed.
    /// All callers that need an AppRuntime should use this instead of creating their own.
    func runtime() -> AppRuntime {
        if let existing = _runtime {
            return existing
        }
        let rt = AppRuntime()
        _runtime = rt
        return rt
    }

    // MARK: - Nostr Relay Access

    public func connectNostrRelays() {
        NostrRelayManager.shared.connect()
    }

    public func disconnectNostrRelays() {
        NostrRelayManager.shared.disconnect()
    }

    public func sendNostrEvent(data: Data, recipientPubKeyHex: String) -> Bool {
        guard recipientPubKeyHex.count == 64,
              let recipientData = Data(hexString: recipientPubKeyHex),
              recipientData.count == 32 else { return false }
        guard let runtime = _runtime else { return false }
        let identity: NostrIdentity
        do {
            guard let id = try runtime.idBridge.getCurrentNostrIdentity() else {
                SecureLogger.error("sendNostrEvent: getCurrentNostrIdentity returned nil", category: .session)
                return false
            }
            identity = id
        } catch {
            SecureLogger.error("sendNostrEvent: failed to get current Nostr identity: \(error)", category: .session)
            return false
        }
        let content = data.base64EncodedString()
        let event: NostrEvent
        do {
            event = try NostrProtocol.createPrivateMessage(
                content: content,
                recipientPubkey: recipientPubKeyHex,
                senderIdentity: identity
            )
        } catch {
            SecureLogger.error("sendNostrEvent: failed to create Nostr private message: \(error)", category: .session)
            return false
        }
        NostrRelayManager.shared.sendEvent(event)
        return true
    }

    public func subscribeNostrInbound(handler: @escaping (Data, String) -> Void) {
        nostrInboundHandler = handler
        let identity: NostrIdentity
        do {
            guard let runtime = _runtime else { return }
            guard let id = try runtime.idBridge.getCurrentNostrIdentity() else {
                SecureLogger.error("subscribeNostrInbound: getCurrentNostrIdentity returned nil", category: .session)
                return
            }
            identity = id
        } catch {
            SecureLogger.error("subscribeNostrInbound: failed to get current Nostr identity: \(error)", category: .session)
            return
        }
        let pubkeyHex = identity.publicKey.hexEncodedString()
        let filter = NostrFilter.giftWrapsFor(pubkey: pubkeyHex)
        NostrRelayManager.shared.subscribe(
            filter: filter,
            id: "popopx-inbound",
            relayUrls: nil,
            handler: { [weak self] event in
                guard let data = Data(base64Encoded: event.content) else { return }
                self?.nostrInboundHandler?(data, event.pubkey)
            },
            onEOSE: nil
        )
    }

    // MARK: - Gateway / Bridge Control

    public func enableGateway(_ enabled: Bool) {
        GatewayService.shared.setEnabled(enabled)
    }

    public func enableBridge(_ enabled: Bool) {
        BridgeService.shared.setEnabled(enabled)
    }

    // MARK: - Identity Bridge

    public func getNostrPubKey(forNoisePubKey: Data) -> String? {
        _runtime?.idBridge.getNostrPublicKey(for: forNoisePubKey)
    }

    /// Derive the primary Nostr identity deterministically from the unified master seed
    /// (Curve25519 key material). Returns the Nostr public key hex on success.
    public func deriveNostrIdentity(fromMasterSeed seed: Data) -> String? {
        guard let runtime = _runtime else {
            SecureLogger.warning("deriveNostrIdentity: runtime not available", category: .session)
            return nil
        }
        do {
            let identity = try runtime.idBridge.derivePrimaryFromMasterSeed(seed)
            return identity.publicKeyHex
        } catch {
            SecureLogger.error("deriveNostrIdentity failed: \(error)", category: .session)
            return nil
        }
    }

    public func associateNoiseKey(_ noisePublicKey: Data, withNostrPubKey hex: String) {
        _runtime?.idBridge.associateNoiseKey(noisePublicKey, withNostrPubKey: hex)
    }

    // MARK: - Ephemeral ID Management

    public func initializeEphemeralIDs() async {
        await EphemeralIDManager.shared.initialize()
    }

    public func registerPeerForEphemeralDiscovery(publicKeyHex: String) async {
        await EphemeralIDManager.shared.registerPeer(publicKeyHex: publicKeyHex)
    }

    public func unregisterPeerForEphemeralDiscovery(publicKeyHex: String) async {
        await EphemeralIDManager.shared.unregisterPeer(publicKeyHex: publicKeyHex)
    }

    public func computeEphemeralID(forPeer publicKeyHex: String) async -> Data? {
        await EphemeralIDManager.shared.computeEphemeralID(forPeer: publicKeyHex)
    }

    public func currentBroadcastEphemeralID() async -> Data? {
        await EphemeralIDManager.shared.currentBroadcastID()
    }

    public func matchEphemeralID(_ id: Data) async -> String? {
        await EphemeralIDManager.shared.matchEphemeralID(id)
    }

    // MARK: - Internal Wiring

    private func wireGatewayAndBridge() {
        let gateway = GatewayService.shared
        gateway.publishToRelays = { event, _ in
            NostrRelayManager.shared.sendEvent(event)
        }
        gateway.relaysConnected = {
            NostrRelayManager.shared.isConnected
        }
        gateway.broadcastToMesh = { [weak self] data in
            guard let text = String(data: data, encoding: .utf8) else { return }
            self?._runtime?.meshTransport.sendPublicMessage(text)
        }

        let bridge = BridgeService.shared
        bridge.publishToRelays = { event, _ in
            NostrRelayManager.shared.sendEvent(event)
        }
        bridge.relaysConnected = {
            NostrRelayManager.shared.isConnected
        }
        bridge.broadcastToMesh = { [weak self] data in
            guard let text = String(data: data, encoding: .utf8) else { return }
            self?._runtime?.meshTransport.sendPublicMessage(text)
        }
        bridge.deriveIdentity = { [weak self] cell in
            guard let runtime = self?._runtime else {
                throw NostrError.invalidEvent
            }
            return try runtime.idBridge.deriveIdentity(forBridgeRendezvous: cell)
        }
    }
}
