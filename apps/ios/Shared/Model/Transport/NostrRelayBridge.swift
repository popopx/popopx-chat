// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitchatMesh

@MainActor
class NostrRelayBridge {
    static let shared = NostrRelayBridge()

    private var isInboundSubscribed = false

    private init() {}

    var connectionState: Bool {
        BitchatSharedRuntime.shared.isNostrConnected
    }

    func connect() {
        BitchatSharedRuntime.shared.connectNostrRelays()
        if !isInboundSubscribed {
            BitchatSharedRuntime.shared.subscribeNostrInbound { [weak self] data, senderPubKey in
                self?.handleInbound(data: data, from: senderPubKey)
            }
            isInboundSubscribed = true
        }
    }

    func disconnect() {
        BitchatSharedRuntime.shared.disconnectNostrRelays()
    }

    func sendViaNostr(peerPubKeyHex: String, messageData: Data) -> Bool {
        BitchatSharedRuntime.shared.sendNostrEvent(data: messageData, recipientPubKeyHex: peerPubKeyHex)
    }

    var onMessageReceived: ((Data, String) -> Void)?

    private func handleInbound(data: Data, from senderPubKey: String) {
        onMessageReceived?(data, senderPubKey)
    }
}
