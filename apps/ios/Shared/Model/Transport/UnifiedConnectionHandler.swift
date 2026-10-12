// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import Combine
import CryptoKit
import BitchatMesh

@MainActor
final class UnifiedConnectionHandler: ObservableObject {
    static let shared = UnifiedConnectionHandler()

    @Published var knownPeers: [String: UnifiedPeerInfo] = [:]
    @Published var connectionStatus: [String: ConnectionStatus] = [:]

    enum ConnectionStatus: String {
        case online = "Online"
        case nearby = "Nearby"
        case bothActive = "Both Active"
        case connecting = "Connecting..."
        case offline = "Offline"
    }

    private let identityManager = UnifiedIdentityManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var peerLastSeen: [String: Date] = [:]
    private var peerAdditionCount: Int = 0
    private let pruneStaleInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let pruneStaleFrequency = 10

    private init() {}

    func initialize() async {
        await identityManager.initialize()
        await BitchatSharedRuntime.shared.initializeEphemeralIDs()
    }

    func generateMyQR() async -> String? {
        await identityManager.generateUnifiedQR()
    }

    func handleScannedQR(_ qrString: String) async -> UnifiedPeerInfo? {
        guard let payload = await identityManager.parseUnifiedQR(qrString) else {
            return nil
        }

        guard isValidPublicKeyHex(payload.identity) else {
            return nil
        }

        let peerInfo = UnifiedPeerInfo(
            identityPubKeyHex: payload.identity,
            smpAddress: payload.smp,
            blePeerID: payload.ble,
            multipeerPeerID: payload.multipeer,
            nostrPubKey: payload.nostr,
            displayName: payload.name
        )

        knownPeers[payload.identity] = peerInfo
        peerLastSeen[payload.identity] = Date()
        peerAdditionCount += 1
        if peerAdditionCount % pruneStaleFrequency == 0 {
            pruneStalePeers()
        }
        await registerPeerInRouter(peerInfo)
        await BitchatSharedRuntime.shared.registerPeerForEphemeralDiscovery(publicKeyHex: payload.identity)
        updateConnectionStatus(for: payload.identity)

        return peerInfo
    }

    func registerPeerTransport(identityPubKey: String, transport: String, endpoint: String) {
        guard isValidPublicKeyHex(identityPubKey) else { return }
        guard !endpoint.isEmpty else { return }
        guard var peer = knownPeers[identityPubKey] else { return }

        switch transport {
        case "smp":
            guard endpoint.count <= 2048 else { return }
            peer.smpAddress = endpoint
        case "ble":
            guard endpoint.count <= 128, Data(hexString: endpoint) != nil else { return }
            peer.blePeerID = endpoint
        case "multipeer":
            guard endpoint.count <= 128 else { return }
            peer.multipeerPeerID = endpoint
        case "nostr":
            guard isValidPublicKeyHex(endpoint) else { return }
            peer.nostrPubKey = endpoint
        default:
            return
        }

        knownPeers[identityPubKey] = peer
        peerLastSeen[identityPubKey] = Date()
        updateConnectionStatus(for: identityPubKey)
        Task { await registerPeerInRouter(peer) }
    }

    func peerAppeared(blePeerID: String, noisePubKeyHex: String?) {
        guard let noisePubKeyHex else { return }
        if var peer = knownPeers[noisePubKeyHex] {
            peer.blePeerID = blePeerID
            knownPeers[noisePubKeyHex] = peer
            peerLastSeen[noisePubKeyHex] = Date()
            updateConnectionStatus(for: noisePubKeyHex)
            Task {
                await registerPeerInRouter(peer)
                await BitchatSharedRuntime.shared.registerPeerForEphemeralDiscovery(publicKeyHex: noisePubKeyHex)
            }
        } else if let noiseKeyData = Data(hexString: noisePubKeyHex) {
            let nostrPubKey = BitchatSharedRuntime.shared.getNostrPubKey(forNoisePubKey: noiseKeyData)
            let peer = UnifiedPeerInfo(
                identityPubKeyHex: noisePubKeyHex,
                blePeerID: blePeerID,
                nostrPubKey: nostrPubKey
            )
            knownPeers[noisePubKeyHex] = peer
            peerLastSeen[noisePubKeyHex] = Date()
            updateConnectionStatus(for: noisePubKeyHex)
            peerAdditionCount += 1
            if peerAdditionCount % pruneStaleFrequency == 0 {
                pruneStalePeers()
            }
            Task { await registerPeerInRouter(peer) }
        }
    }

    func peerDisappeared(blePeerID: String) {
        for (key, var peer) in knownPeers {
            if peer.blePeerID == blePeerID {
                peer.blePeerID = nil
                knownPeers[key] = peer
                updateConnectionStatus(for: key)
                let peerForTask = peer
                Task { await registerPeerInRouter(peerForTask) }
            }
        }
    }

    func bestTransport(for peerIdentity: String) -> String {
        guard let peer = knownPeers[peerIdentity] else { return "internet" }

        if peer.smpAddress != nil {
            return "smp"
        }
        if peer.blePeerID != nil {
            return "ble"
        }
        if peer.multipeerPeerID != nil {
            return "multipeer"
        }
        if peer.nostrPubKey != nil {
            return "nostr"
        }
        return "internet"
    }

    func statusText(for peerIdentity: String) -> String {
        guard let status = connectionStatus[peerIdentity] else { return "Unknown" }
        return status.rawValue
    }

    private func registerPeerInRouter(_ peer: UnifiedPeerInfo) async {
        await ChatModel.shared.transportRouter.registerPeer(
            identity: peer.identityPubKeyHex,
            transports: peer.availableTransports
        )
    }

    private func updateConnectionStatus(for peerIdentity: String) {
        guard let peer = knownPeers[peerIdentity] else {
            connectionStatus[peerIdentity] = .offline
            return
        }

        let hasOnline = peer.smpAddress != nil
        let hasNearby = peer.blePeerID != nil || peer.multipeerPeerID != nil

        if hasOnline && hasNearby {
            connectionStatus[peerIdentity] = .bothActive
        } else if hasOnline {
            connectionStatus[peerIdentity] = .online
        } else if hasNearby {
            connectionStatus[peerIdentity] = .nearby
        } else {
            connectionStatus[peerIdentity] = .offline
        }
    }

    func removePeer(_ identityPubKey: String) {
        knownPeers.removeValue(forKey: identityPubKey)
        connectionStatus.removeValue(forKey: identityPubKey)
        peerLastSeen.removeValue(forKey: identityPubKey)
        Task {
            await ChatModel.shared.transportRouter.unregisterPeer(identity: identityPubKey)
            await BitchatSharedRuntime.shared.unregisterPeerForEphemeralDiscovery(publicKeyHex: identityPubKey)
        }
    }

    func pruneStalePeers() {
        let cutoff = Date().addingTimeInterval(-pruneStaleInterval)
        let staleKeys = peerLastSeen.filter { $0.value < cutoff }.map { $0.key }
        for key in staleKeys {
            knownPeers.removeValue(forKey: key)
            connectionStatus.removeValue(forKey: key)
            peerLastSeen.removeValue(forKey: key)
        }
    }

    /// Remove a peer by chat ID, handling different ID formats (e.g., "mesh:xxxx").
    /// Extracts the actual identity key from prefixed chat IDs.
    func removePeerByChatID(_ chatID: String) {
        if chatID.hasPrefix("mesh:") {
            let blePeerID = String(chatID.dropFirst(5))
            for (key, peer) in knownPeers where peer.blePeerID == blePeerID {
                removePeer(key)
                return
            }
        }
        removePeer(chatID)
    }

    private func isValidPublicKeyHex(_ hex: String) -> Bool {
        guard hex.count == 64,
              let data = Data(hexString: hex),
              data.count == 32 else {
            return false
        }
        return (try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)) != nil
    }
}
