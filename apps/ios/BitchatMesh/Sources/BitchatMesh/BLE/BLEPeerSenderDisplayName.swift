// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import BitFoundation
import Foundation

enum BLEPeerSenderDisplayName {
    static func resolveKnownPeer(
        peerID: PeerID,
        localPeerID: PeerID,
        localNickname: String,
        peers: [PeerID: BLEPeerInfo],
        allowConnectedUnverified: Bool
    ) -> String? {
        if peerID == localPeerID {
            return localNickname
        }

        guard let info = peers[peerID] else { return nil }

        if info.isVerifiedNickname {
            return collisionResolvedName(
                displayName: info.nickname,
                collisionNickname: info.nickname,
                peerID: peerID,
                localNickname: localNickname,
                peers: peers
            )
        }

        if allowConnectedUnverified, info.isConnected {
            let displayName = info.nickname.isEmpty ? anonymousNickname(for: peerID) : info.nickname
            return collisionResolvedName(
                displayName: displayName,
                collisionNickname: info.nickname,
                peerID: peerID,
                localNickname: localNickname,
                peers: peers
            )
        }

        return nil
    }

    static func anonymousNickname(for peerID: PeerID) -> String {
        "anon" + String(peerID.id.prefix(4))
    }

    private static func collisionResolvedName(
        displayName: String,
        collisionNickname: String,
        peerID: PeerID,
        localNickname: String,
        peers: [PeerID: BLEPeerInfo]
    ) -> String {
        let hasCollision = peers.values.contains {
            $0.isConnected && $0.nickname == collisionNickname && $0.peerID != peerID
        } || localNickname == collisionNickname

        guard hasCollision else { return displayName }
        return displayName + "#" + String(peerID.id.prefix(4))
    }
}
