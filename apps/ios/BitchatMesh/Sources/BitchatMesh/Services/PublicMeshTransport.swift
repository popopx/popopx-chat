// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitFoundation
import CoreBluetooth

/// Simplified public interface for POPOPX integration.
/// Exposes only the mesh transport capabilities needed by the POPOPX app,
/// avoiding the need to make the full internal Transport protocol public.
public protocol PublicMeshTransport: AnyObject {
    func startServices()
    func stopServices()
    func sendPublicMessage(_ content: String)
    func sendPrivateMessage(_ content: String, to peerIDHex: String)
    func currentPeerSnapshots() -> [PublicPeerSnapshot]
    func noisePublicKeyData(forPeerIDHex peerIDHex: String) -> Data?
    var myPeerIDHex: String { get }
    var myNickname: String { get }

    // Event callbacks
    var onMessageReceived: ((String, String, String) -> Void)? { get set } // (messageID, senderID, content)
    var onPeerConnected: ((String) -> Void)? { get set } // peerID
    var onPeerDisconnected: ((String) -> Void)? { get set } // peerID
    var onAvailabilityChanged: ((Bool) -> Void)? { get set }
}

/// Simplified peer snapshot for public API.
public struct PublicPeerSnapshot: Equatable, Identifiable {
    public var id: String { peerIDHex }
    public let peerIDHex: String
    public let nickname: String
    public let isConnected: Bool

    public init(peerIDHex: String, nickname: String, isConnected: Bool) {
        self.peerIDHex = peerIDHex
        self.nickname = nickname
        self.isConnected = isConnected
    }
}

/// Adapter that wraps the internal BLEService and exposes PublicMeshTransport.
final class PublicMeshTransportAdapter: PublicMeshTransport {
    private let transport: Transport
    private let eventForwarder: EventForwarder

    var onMessageReceived: ((String, String, String) -> Void)? {
        get { eventForwarder.onMessageReceived }
        set { eventForwarder.onMessageReceived = newValue }
    }
    var onPeerConnected: ((String) -> Void)? {
        get { eventForwarder.onPeerConnected }
        set { eventForwarder.onPeerConnected = newValue }
    }
    var onPeerDisconnected: ((String) -> Void)? {
        get { eventForwarder.onPeerDisconnected }
        set { eventForwarder.onPeerDisconnected = newValue }
    }
    var onAvailabilityChanged: ((Bool) -> Void)? {
        get { eventForwarder.onAvailabilityChanged }
        set { eventForwarder.onAvailabilityChanged = newValue }
    }

    init(transport: Transport) {
        self.transport = transport
        self.eventForwarder = EventForwarder()
        transport.eventDelegate = eventForwarder
        transport.peerEventsDelegate = eventForwarder
    }

    public func startServices() { transport.startServices() }
    public func stopServices() { transport.stopServices() }

    public func sendPublicMessage(_ content: String) {
        transport.sendMessage(content, mentions: [])
    }

    public func sendPrivateMessage(_ content: String, to peerIDHex: String) {
        let peerID = PeerID(str: peerIDHex)
        let nickname = transport.peerNickname(peerID: peerID) ?? peerIDHex
        transport.sendPrivateMessage(content, to: peerID, recipientNickname: nickname, messageID: UUID().uuidString)
    }

    public func currentPeerSnapshots() -> [PublicPeerSnapshot] {
        transport.currentPeerSnapshots().map {
            PublicPeerSnapshot(peerIDHex: $0.peerID.id, nickname: $0.nickname, isConnected: $0.isConnected)
        }
    }

    public func noisePublicKeyData(forPeerIDHex peerIDHex: String) -> Data? {
        let peerID = PeerID(str: peerIDHex)
        return transport.noiseSessionPublicKeyData(for: peerID)
    }

    public var myPeerIDHex: String { transport.myPeerID.id }
    public var myNickname: String { transport.myNickname }
}

/// Internal event forwarder that bridges Transport events to simple callbacks.
final class EventForwarder: TransportEventDelegate, TransportPeerEventsDelegate {
    var onMessageReceived: ((String, String, String) -> Void)?
    var onPeerConnected: ((String) -> Void)?
    var onPeerDisconnected: ((String) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    @MainActor func didReceiveTransportEvent(_ event: TransportEvent) {
        switch event {
        case .messageReceived(let message):
            onMessageReceived?(message.id, message.senderPeerID?.id ?? message.sender, message.content)
        case .publicMessageReceived(let peerID, _, let content, _, let messageID):
            onMessageReceived?(messageID ?? UUID().uuidString, peerID.id, content)
        case .peerConnected(let peerID):
            onPeerConnected?(peerID.id)
            onAvailabilityChanged?(true)
        case .peerDisconnected(let peerID):
            onPeerDisconnected?(peerID.id)
        case .bluetoothStateUpdated(let state):
            onAvailabilityChanged?(state == .poweredOn)
        default:
            break
        }
    }

    @MainActor func didUpdatePeerSnapshots(_ snapshots: [TransportPeerSnapshot]) {
        let hasConnected = snapshots.contains { $0.isConnected }
        onAvailabilityChanged?(hasConnected)
    }
}
