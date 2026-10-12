// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import BitFoundation
import Foundation

struct BLEPeerEventDebouncer {
    private var lastEmitByPeer: [PeerID: Date] = [:]

    var count: Int {
        lastEmitByPeer.count
    }

    @discardableResult
    mutating func shouldEmit(peerID: PeerID, now: Date, minimumInterval: TimeInterval) -> Bool {
        if let lastEmit = lastEmitByPeer[peerID],
           now.timeIntervalSince(lastEmit) < minimumInterval {
            return false
        }

        lastEmitByPeer[peerID] = now
        return true
    }

    mutating func removeAll() {
        lastEmitByPeer.removeAll()
    }
}
