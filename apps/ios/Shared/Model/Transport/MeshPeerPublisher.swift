// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch
import BitchatMesh

enum MeshPeerPublisher {
    static func publish(_ peers: [PublicPeerSnapshot]) {
        let sharePeers = peers.map {
            MeshPeerShareData(peerIDHex: $0.id, nickname: $0.nickname, isConnected: $0.isConnected)
        }
        MeshShareStore.publishPeers(sharePeers)
    }
}
