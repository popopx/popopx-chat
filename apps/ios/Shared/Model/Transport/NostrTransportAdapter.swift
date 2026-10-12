// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CryptoKit

class NostrTransportAdapter: MessageTransport {
    let transportID = "nostr"
    private let bridge: NostrRelayBridge
    private var isStarted = false
    private var _isAvailable = false

    var onMessageReceived: ((TransportMessage) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    var isAvailable: Bool {
        _isAvailable
    }

    init(bridge: NostrRelayBridge? = nil) {
        self.bridge = bridge ?? MainActor.assumeIsolated { NostrRelayBridge.shared }
    }

    func start() throws {
        Task { @MainActor in
            isStarted = true
            bridge.connect()
            _isAvailable = bridge.connectionState
            bridge.onMessageReceived = { data, senderPubKey in
                // Use a stable hash of sender+payload for dedup instead of UUID,
                // so replayed events from Nostr relays are correctly deduplicated.
                let hashInput = Data("\(senderPubKey):".utf8) + data
                let digest = SHA256.hash(data: hashInput)
                let stableID = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
                let message = TransportMessage(
                    id: stableID,
                    senderID: senderPubKey,
                    payload: data,
                    transportHint: "nostr"
                )
                self.onMessageReceived?(message)
            }
        }
    }

    func stop() {
        Task { @MainActor in
            isStarted = false
            bridge.disconnect()
            bridge.onMessageReceived = nil
            _isAvailable = false
        }
    }

    func send(_ message: TransportMessage, completion: @escaping (Result<Void, TransportError>) -> Void) {
        Task { @MainActor in
            guard let recipientID = message.recipientID else {
                completion(.failure(.peerNotFound))
                return
            }
            let success = bridge.sendViaNostr(peerPubKeyHex: recipientID, messageData: message.payload)
            completion(success ? .success(()) : .failure(.sendFailed("Nostr send failed")))
        }
    }
}
