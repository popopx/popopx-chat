// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

public struct MeshPeerShareData: Identifiable, Hashable, Codable {
    public let peerIDHex: String
    public var nickname: String
    public let isConnected: Bool

    public var id: String { "mesh:\(peerIDHex)" }

    public init(peerIDHex: String, nickname: String, isConnected: Bool) {
        self.peerIDHex = peerIDHex
        self.nickname = nickname
        self.isConnected = isConnected
    }
}

public enum MeshSharePayload: Codable {
    case text(peerIDHex: String, text: String)
    case image(peerIDHex: String, filePath: String, caption: String)
    case file(peerIDHex: String, filePath: String, fileName: String, caption: String)
}

public enum MeshShareStore {
    private static let peersKey = "mesh_available_peers"
    private static let pendingPayloadKey = "mesh_pending_share_payload"

    public static func publishPeers(_ peers: [MeshPeerShareData]) {
        if let data = try? JSONEncoder().encode(peers) {
            groupDefaults.set(data, forKey: peersKey)
        }
    }

    public static func loadPeers() -> [MeshPeerShareData] {
        guard let data = groupDefaults.data(forKey: peersKey),
              let peers = try? JSONDecoder().decode([MeshPeerShareData].self, from: data) else {
            return []
        }
        return peers
    }

    public static func writePayload(_ payload: MeshSharePayload) {
        if let data = try? JSONEncoder().encode(payload) {
            groupDefaults.set(data, forKey: pendingPayloadKey)
        }
    }

    public static func consumePendingPayload() -> MeshSharePayload? {
        guard let data = groupDefaults.data(forKey: pendingPayloadKey),
              let payload = try? JSONDecoder().decode(MeshSharePayload.self, from: data) else {
            return nil
        }
        groupDefaults.removeObject(forKey: pendingPayloadKey)
        return payload
    }
}
