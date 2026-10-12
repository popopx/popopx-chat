// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitchatMesh
import CoreBluetooth

/// Adapter that wraps bitchat's RichMeshTransport and conforms to POPOPX's MessageTransport.
class BitchatTransportAdapter: MessageTransport {
    let transportID = "bluetooth"

    private let meshTransport: RichMeshTransport
    private var _isStarted = false
    private let stateLock = DispatchQueue(label: "chat.popopx.BitchatTransportAdapter")

    var onMessageReceived: ((TransportMessage) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    private var isStarted: Bool {
        get { stateLock.sync { _isStarted } }
        set { stateLock.sync { _isStarted = newValue } }
    }

    var isAvailable: Bool {
        guard isStarted else { return false }
        let peers = meshTransport.currentPeerSnapshots()
        return peers.contains { $0.isConnected }
    }

    init(transport: RichMeshTransport) {
        self.meshTransport = transport
    }

    func start() throws {
        guard !isStarted else { return }
        isStarted = true

        // Wire up legacy event callbacks for basic text messaging
        meshTransport.onMessageReceived = { [weak self] messageID, senderID, content in
            let payload = Data(content.utf8)
            let transportMsg = TransportMessage(
                id: messageID,
                recipientID: nil,
                payload: payload,
                priority: .normal,
                transportHint: "bluetooth"
            )
            self?.onMessageReceived?(transportMsg)
        }

        meshTransport.onAvailabilityChanged = { [weak self] available in
            self?.onAvailabilityChanged?(available)
        }

        meshTransport.onPeerConnected = { [weak self] _ in
            self?.onAvailabilityChanged?(self?.isAvailable ?? false)
        }

        meshTransport.onPeerDisconnected = { [weak self] _ in
            self?.onAvailabilityChanged?(self?.isAvailable ?? false)
        }

        meshTransport.startServices()
        onAvailabilityChanged?(isAvailable)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        meshTransport.onMessageReceived = nil
        meshTransport.onAvailabilityChanged = nil
        meshTransport.onPeerConnected = nil
        meshTransport.onPeerDisconnected = nil
        meshTransport.onTransportEvent = nil

        meshTransport.stopServices()
        onAvailabilityChanged?(false)
    }

    func send(_ message: TransportMessage, completion: @escaping (Result<Void, TransportError>) -> Void) {
        guard isStarted else {
            completion(.failure(.transportStopped))
            return
        }

        guard let text = String(data: message.payload, encoding: .utf8) else {
            completion(.failure(.encodingFailed))
            return
        }

        let hasConnectedPeers = meshTransport.currentPeerSnapshots().contains { $0.isConnected }
        guard hasConnectedPeers else {
            completion(.failure(.notAvailable))
            return
        }

        if let recipientID = message.recipientID {
            meshTransport.sendPrivateMessage(text, to: recipientID)
        } else {
            meshTransport.sendPublicMessage(text)
        }

        // Verify transport still has connected peers after enqueueing.
        // The BLE send is fire-and-forget on RichMeshTransport (returns Void),
        // so we confirm connectivity is still intact as a proxy for acceptance.
        let stillConnected = meshTransport.currentPeerSnapshots().contains { $0.isConnected }
        if stillConnected {
            completion(.success(()))
        } else {
            completion(.failure(.notAvailable))
        }
    }

    func nearbyPeers() -> [PublicPeerSnapshot] {
        meshTransport.currentPeerSnapshots()
    }

    /// Access to the underlying rich transport for bridge integration.
    var richTransport: RichMeshTransport { meshTransport }
}
