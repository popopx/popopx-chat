// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitFoundation
import Combine
import CoreBluetooth

/// Extended public interface that exposes the full TransportEvent stream
/// and rich send capabilities (voice, files, groups, board) for deep POPOPX integration.
public protocol RichMeshTransport: PublicMeshTransport {
    /// Full event stream — all 11 TransportEvent cases forwarded.
    var onTransportEvent: ((RichTransportEvent) -> Void)? { get set }

    // Rich send capabilities
    func sendVoiceFrame(_ data: Data, to peerIDHex: String)
    func sendVoiceFrameBroadcast(_ data: Data)
    func sendFilePrivate(_ packetData: Data, to peerIDHex: String, transferId: String)
    func sendGroupInvite(_ payload: Data, to peerIDHex: String)
    func broadcastGroupMessage(_ envelope: Data)
    func sendBoardPayload(_ payload: Data)
    func sendMeshPing(to peerIDHex: String, completion: @escaping (Double?, Int?) -> Void)

    // Identity
    var myNoisePublicKeyHex: String { get }

    // Mesh diagnostics
    func currentMeshTopologyJSON() -> String?

    // Board
    func boardPosts(geohash: String) -> [PublicBoardPost]
    func postToBoard(content: String, geohash: String, isUrgent: Bool) -> Bool
    var onBoardPostArrival: ((PublicBoardPost) -> Void)? { get set }

    // Groups
    func createMeshGroup(named: String) -> PublicGroupInfo?
    func inviteToMeshGroup(groupIDHex: String, peerIDHex: String)
    func sendMeshGroupText(groupIDHex: String, content: String)
    func myMeshGroups() -> [PublicGroupInfo]
}

/// A serializable representation of TransportEvent for crossing the package boundary.
/// Mirrors TransportEvent but uses only public/primitive types.
public enum RichTransportEvent: @unchecked Sendable {
    case messageReceived(messageID: String, senderPeerIDHex: String, senderNickname: String, content: String, timestamp: Date, isPrivate: Bool)
    case publicMessageReceived(peerIDHex: String, nickname: String, content: String, timestamp: Date, messageID: String?)
    case noisePayloadReceived(peerIDHex: String, payloadTypeRaw: UInt8, payload: Data, timestamp: Date)
    case groupMessageReceived(payload: Data, timestamp: Date)
    case publicVoiceFrameReceived(peerIDHex: String, nickname: String, payload: Data, timestamp: Date)
    case peerConnected(peerIDHex: String)
    case peerDisconnected(peerIDHex: String)
    case peerListUpdated(peerIDHexes: [String])
    case peerSnapshotsUpdated(snapshots: [PublicPeerSnapshot])
    case messageDeliveryStatusUpdated(messageID: String, statusRaw: String)
    case bluetoothStateUpdated(stateRaw: Int)
    case groupMessageDecrypted(groupIDHex: String, groupName: String, messageID: String, senderNickname: String, content: String, timestamp: Date)
    case groupListUpdated(groups: [PublicGroupInfo])
}

/// Public board post type for crossing the package boundary.
public struct PublicBoardPost: Sendable, Identifiable, Equatable {
    public let postIDHex: String
    public let geohash: String
    public let content: String
    public let authorNickname: String
    public let createdAt: Date
    public let expiresAt: Date
    public let isUrgent: Bool
    public var id: String { postIDHex }
}

/// Public group info for crossing the package boundary.
public struct PublicGroupInfo: Sendable, Identifiable, Equatable {
    public let groupIDHex: String
    public let name: String
    public let epoch: UInt32
    public let memberCount: Int
    public let memberNicknames: [String]
    public var id: String { groupIDHex }
}

/// Adapter that wraps the internal Transport and exposes RichMeshTransport.
@MainActor
final class RichMeshTransportAdapter: @preconcurrency RichMeshTransport {
    private let transport: Transport
    private let eventForwarder: RichEventForwarder
    private let groupStore: GroupStore

    // MARK: - PublicMeshTransport callbacks (legacy path)

    var onMessageReceived: ((String, String, String) -> Void)? {
        get { eventForwarder.legacyOnMessageReceived }
        set { eventForwarder.legacyOnMessageReceived = newValue }
    }
    var onPeerConnected: ((String) -> Void)? {
        get { eventForwarder.legacyOnPeerConnected }
        set { eventForwarder.legacyOnPeerConnected = newValue }
    }
    var onPeerDisconnected: ((String) -> Void)? {
        get { eventForwarder.legacyOnPeerDisconnected }
        set { eventForwarder.legacyOnPeerDisconnected = newValue }
    }
    var onAvailabilityChanged: ((Bool) -> Void)? {
        get { eventForwarder.onAvailabilityChanged }
        set { eventForwarder.onAvailabilityChanged = newValue }
    }

    // MARK: - RichMeshTransport

    var onTransportEvent: ((RichTransportEvent) -> Void)? {
        get { eventForwarder.onTransportEvent }
        set { eventForwarder.onTransportEvent = newValue }
    }

    init(transport: Transport, groupStore: GroupStore) {
        self.transport = transport
        self.eventForwarder = RichEventForwarder()
        self.groupStore = groupStore
        transport.eventDelegate = eventForwarder
        transport.peerEventsDelegate = eventForwarder

        boardArrivalsCancellable = BoardStore.shared.postArrivals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] post in
                self?.boardPostArrivalCallback?(Self.toPublicPost(post))
            }

        eventForwarder.groupDecryptor = { [weak self] payload, timestamp in
            self?.tryDecryptGroupMessage(payload: payload, timestamp: timestamp)
        }
    }

    private func tryDecryptGroupMessage(payload: Data, timestamp: Date) {
        guard let envelope = GroupMessageEnvelope.decode(payload) else { return }
        let groupIDHex = envelope.groupID.hexEncodedString()
        guard let group = groupStore.group(withID: envelope.groupID),
              let key = groupStore.key(forGroupID: envelope.groupID) else { return }
        guard let plaintext = try? GroupCrypto.openMessage(envelope, key: key) else { return }
        eventForwarder.onTransportEvent?(.groupMessageDecrypted(
            groupIDHex: groupIDHex,
            groupName: group.name,
            messageID: plaintext.messageID,
            senderNickname: plaintext.senderNickname,
            content: plaintext.content,
            timestamp: Date(timeIntervalSince1970: Double(plaintext.timestampMs) / 1000)
        ))
    }

    // MARK: - Lifecycle

    public func startServices() { transport.startServices() }
    public func stopServices() { transport.stopServices() }

    // MARK: - Text messaging

    public func sendPublicMessage(_ content: String) {
        transport.sendMessage(content, mentions: [])
    }

    public func sendPrivateMessage(_ content: String, to peerIDHex: String) {
        let peerID = PeerID(str: peerIDHex)
        let nickname = transport.peerNickname(peerID: peerID) ?? peerIDHex
        transport.sendPrivateMessage(content, to: peerID, recipientNickname: nickname, messageID: UUID().uuidString)
    }

    // MARK: - Rich send

    public func sendVoiceFrame(_ data: Data, to peerIDHex: String) {
        let peerID = PeerID(str: peerIDHex)
        transport.sendVoiceFrame(data, to: peerID)
    }

    public func sendVoiceFrameBroadcast(_ data: Data) {
        transport.sendVoiceFrameBroadcast(data)
    }

    public func sendFilePrivate(_ packetData: Data, to peerIDHex: String, transferId: String) {
        guard let packet = BitchatFilePacket.decode(packetData) else { return }
        let peerID = PeerID(str: peerIDHex)
        transport.sendFilePrivate(packet, to: peerID, transferId: transferId, allowLegacyFallback: true)
    }

    public func sendGroupInvite(_ payload: Data, to peerIDHex: String) {
        let peerID = PeerID(str: peerIDHex)
        transport.sendGroupInvite(payload, to: peerID)
    }

    public func broadcastGroupMessage(_ envelope: Data) {
        transport.broadcastGroupMessage(envelope)
    }

    public func sendBoardPayload(_ payload: Data) {
        transport.sendBoardPayload(payload)
    }

    public func sendMeshPing(to peerIDHex: String, completion: @escaping (Double?, Int?) -> Void) {
        let peerID = PeerID(str: peerIDHex)
        transport.sendMeshPing(to: peerID) { result in
            completion(result.map { Double($0.rttMs) }, result?.hops)
        }
    }

    // MARK: - Peer snapshots

    public func currentPeerSnapshots() -> [PublicPeerSnapshot] {
        transport.currentPeerSnapshots().map {
            PublicPeerSnapshot(peerIDHex: $0.peerID.id, nickname: $0.nickname, isConnected: $0.isConnected)
        }
    }

    public func noisePublicKeyData(forPeerIDHex peerIDHex: String) -> Data? {
        let peerID = PeerID(str: peerIDHex)
        return transport.noiseSessionPublicKeyData(for: peerID)
    }

    // MARK: - Identity

    public var myPeerIDHex: String { transport.myPeerID.id }
    public var myNickname: String { transport.myNickname }

    public var myNoisePublicKeyHex: String {
        transport.noiseStaticPublicKeyData().hexEncodedString()
    }

    // MARK: - Diagnostics

    public func currentMeshTopologyJSON() -> String? {
        guard let topo = transport.currentMeshTopology() else { return nil }
        let nodes = topo.nodes.map { $0.id }
        let edges = topo.edges.map { ["a": $0.a.id, "b": $0.b.id] }
        let dict: [String: Any] = [
            "localPeerID": topo.localPeerID.id,
            "nodes": nodes,
            "edges": edges
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Board

    public var onBoardPostArrival: ((PublicBoardPost) -> Void)? {
        get { boardPostArrivalCallback }
        set { boardPostArrivalCallback = newValue }
    }
    private var boardPostArrivalCallback: ((PublicBoardPost) -> Void)?
    private var boardArrivalsCancellable: AnyCancellable?

    public func boardPosts(geohash: String) -> [PublicBoardPost] {
        BoardStore.shared.posts(forGeohash: geohash).map { Self.toPublicPost($0) }
    }

    public func postToBoard(content: String, geohash: String, isUrgent: Bool) -> Bool {
        let trimmed = String(content.prefix(BoardWireConstants.contentMaxBytes))
        guard !trimmed.isEmpty else { return false }

        let signingKey = transport.noiseSigningPublicKeyData()
        guard signingKey.count == BoardWireConstants.signingKeyLength else { return false }

        var nickname = transport.myNickname
        while nickname.utf8.count > BoardWireConstants.nicknameMaxBytes {
            nickname.removeLast()
        }

        let createdAt = UInt64(Date().timeIntervalSince1970 * 1000)
        let lifetimeMs = min(UInt64(7 * 24 * 60 * 60 * 1000), BoardWireConstants.maxLifetimeMs)
        let expiresAt = createdAt + lifetimeMs
        let flags: UInt8 = isUrgent ? BoardPostPacket.urgentFlag : 0

        var postID = Data(count: BoardWireConstants.postIDLength)
        let status = postID.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, base)
        }
        guard status == errSecSuccess else { return false }

        let signingBytes = BoardPostPacket.signingBytes(
            postID: postID,
            geohash: geohash,
            content: trimmed,
            authorSigningKey: signingKey,
            authorNickname: nickname,
            createdAt: createdAt,
            expiresAt: expiresAt,
            flags: flags
        )
        guard let signature = transport.noiseSignData(signingBytes) else { return false }

        let post = BoardPostPacket(
            postID: postID,
            geohash: geohash,
            content: trimmed,
            authorSigningKey: signingKey,
            authorNickname: nickname,
            createdAt: createdAt,
            expiresAt: expiresAt,
            flags: flags,
            signature: signature
        )
        transport.sendBoardPayload(BoardWire.post(post).encode())
        return true
    }

    private static func toPublicPost(_ post: BoardPostPacket) -> PublicBoardPost {
        PublicBoardPost(
            postIDHex: post.postID.hexEncodedString(),
            geohash: post.geohash,
            content: post.content,
            authorNickname: post.authorNickname,
            createdAt: Date(timeIntervalSince1970: Double(post.createdAt) / 1000),
            expiresAt: Date(timeIntervalSince1970: Double(post.expiresAt) / 1000),
            isUrgent: post.isUrgent
        )
    }

    // MARK: - Groups

    public func createMeshGroup(named name: String) -> PublicGroupInfo? {
        let creator = GroupMember(
            fingerprint: transport.noiseIdentityFingerprint(),
            signingKey: transport.noiseSigningPublicKeyData(),
            nickname: transport.myNickname
        )
        guard let group = groupStore.createGroup(named: name, creator: creator) else { return nil }
        let info = Self.toPublicGroup(group)
        eventForwarder.onTransportEvent?(.groupListUpdated(groups: myMeshGroups()))
        return info
    }

    public func inviteToMeshGroup(groupIDHex: String, peerIDHex: String) {
        guard let groupID = Data(hexString: groupIDHex),
              let group = groupStore.group(withID: groupID) else { return }
        let peerID = PeerID(str: peerIDHex)
        let statePayload = GroupStatePayload(
            groupID: group.groupID,
            name: group.name,
            key: groupStore.key(forGroupID: groupID) ?? Data(),
            epoch: group.epoch,
            members: group.members,
            creatorFingerprint: group.creatorFingerprint,
            signature: Data()
        )
        if let encoded = statePayload.encode() {
            transport.sendGroupInvite(encoded, to: peerID)
        }
    }

    public func sendMeshGroupText(groupIDHex: String, content: String) {
        guard let groupID = Data(hexString: groupIDHex),
              let group = groupStore.group(withID: groupID),
              let key = groupStore.key(forGroupID: groupID) else { return }

        let messageID = UUID().uuidString
        let timestampMs = UInt64(Date().timeIntervalSince1970 * 1000)
        let signingKey = transport.noiseSigningPublicKeyData()

        guard let envelope = try? GroupCrypto.sealMessage(
            content: content,
            messageID: messageID,
            senderNickname: transport.myNickname,
            senderSigningKey: signingKey,
            timestampMs: timestampMs,
            groupID: groupID,
            epoch: group.epoch,
            key: key,
            sign: { [transport] data in transport.noiseSignData(data) }
        ) else { return }

        transport.broadcastGroupMessage(envelope)
    }

    public func myMeshGroups() -> [PublicGroupInfo] {
        groupStore.groups.map { Self.toPublicGroup($0) }
    }

    private static func toPublicGroup(_ group: BitchatGroup) -> PublicGroupInfo {
        PublicGroupInfo(
            groupIDHex: group.groupID.hexEncodedString(),
            name: group.name,
            epoch: group.epoch,
            memberCount: group.members.count,
            memberNicknames: group.members.map { $0.nickname }
        )
    }
}

/// Event forwarder that bridges ALL TransportEvent cases to both legacy callbacks and the rich event stream.
final class RichEventForwarder: TransportEventDelegate, TransportPeerEventsDelegate {
    // Legacy callbacks (backward compat with PublicMeshTransport consumers)
    var legacyOnMessageReceived: ((String, String, String) -> Void)?
    var legacyOnPeerConnected: ((String) -> Void)?
    var legacyOnPeerDisconnected: ((String) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    // Rich event stream
    var onTransportEvent: ((RichTransportEvent) -> Void)?

    // Group decryption hook — set by the adapter
    var groupDecryptor: ((Data, Date) -> Void)?

    @MainActor func didReceiveTransportEvent(_ event: TransportEvent) {
        // Forward to rich event stream
        let rich: RichTransportEvent
        switch event {
        case .messageReceived(let msg):
            rich = .messageReceived(
                messageID: msg.id,
                senderPeerIDHex: msg.senderPeerID?.id ?? msg.sender,
                senderNickname: msg.sender,
                content: msg.content,
                timestamp: msg.timestamp,
                isPrivate: msg.isPrivate
            )
            legacyOnMessageReceived?(msg.id, msg.senderPeerID?.id ?? msg.sender, msg.content)

        case .publicMessageReceived(let peerID, let nickname, let content, let ts, let msgID):
            rich = .publicMessageReceived(peerIDHex: peerID.id, nickname: nickname, content: content, timestamp: ts, messageID: msgID)
            legacyOnMessageReceived?(msgID ?? UUID().uuidString, peerID.id, content)

        case .noisePayloadReceived(let peerID, let type, let payload, let ts):
            rich = .noisePayloadReceived(peerIDHex: peerID.id, payloadTypeRaw: type.rawValue, payload: payload, timestamp: ts)

        case .groupMessageReceived(let payload, let ts):
            rich = .groupMessageReceived(payload: payload, timestamp: ts)
            groupDecryptor?(payload, ts)

        case .publicVoiceFrameReceived(let peerID, let nickname, let payload, let ts):
            rich = .publicVoiceFrameReceived(peerIDHex: peerID.id, nickname: nickname, payload: payload, timestamp: ts)

        case .peerConnected(let peerID):
            rich = .peerConnected(peerIDHex: peerID.id)
            legacyOnPeerConnected?(peerID.id)
            onAvailabilityChanged?(true)

        case .peerDisconnected(let peerID):
            rich = .peerDisconnected(peerIDHex: peerID.id)
            legacyOnPeerDisconnected?(peerID.id)

        case .peerListUpdated(let peers):
            rich = .peerListUpdated(peerIDHexes: peers.map { $0.id })

        case .peerSnapshotsUpdated(let snapshots):
            let publicSnapshots = snapshots.map {
                PublicPeerSnapshot(peerIDHex: $0.peerID.id, nickname: $0.nickname, isConnected: $0.isConnected)
            }
            rich = .peerSnapshotsUpdated(snapshots: publicSnapshots)

        case .messageDeliveryStatusUpdated(let msgID, let status):
            rich = .messageDeliveryStatusUpdated(messageID: msgID, statusRaw: "\(status)")

        case .bluetoothStateUpdated(let state):
            rich = .bluetoothStateUpdated(stateRaw: state.rawValue)
            onAvailabilityChanged?(state == .poweredOn)
        }
        onTransportEvent?(rich)
    }

    @MainActor func didUpdatePeerSnapshots(_ snapshots: [TransportPeerSnapshot]) {
        let hasConnected = snapshots.contains { $0.isConnected }
        onAvailabilityChanged?(hasConnected)
        let publicSnapshots = snapshots.map {
            PublicPeerSnapshot(peerIDHex: $0.peerID.id, nickname: $0.nickname, isConnected: $0.isConnected)
        }
        onTransportEvent?(.peerSnapshotsUpdated(snapshots: publicSnapshots))
    }
}
