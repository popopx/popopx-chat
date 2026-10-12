// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitchatMesh

actor MeshToPOPOPXGateway {
    static let shared = MeshToPOPOPXGateway()

    private var forwardedMessageIDs: [String] = []
    private var forwardedMessageIDSet: Set<String> = []
    private let maxTrackedIDs = 500
    private var lastForwardTime: Date = .distantPast
    private let minForwardInterval: TimeInterval = 0.1
    private let maxForwardsPerSecond = 10
    private var forwardCount: Int = 0
    private var lastResetTime: Date = .distantPast

    private init() {}

    func handleMeshMessage(_ message: TransportMessage) {
        // Validate first, before consuming rate-limit tokens
        let recipientID = message.recipientID
        guard recipientID != nil else { return }
        
        guard shouldForward(message) else { return }

        Task { @MainActor in
            let handler = UnifiedConnectionHandler.shared
            guard let recipientID,
                  let peer = handler.knownPeers[recipientID],
                  peer.smpAddress != nil else { return }

            guard ChatModel.shared.networkInfo.online else { return }

            do {
                try await forwardToPOPOPX(message)
                await trackMessageID(message.id)
            } catch {
                // Forward failed — do not track, so the message can be retried
            }
        }
    }

    private func shouldForward(_ message: TransportMessage) -> Bool {
        if forwardedMessageIDSet.contains(message.id) { return false }

        let now = Date()
        if now.timeIntervalSince(lastResetTime) > 1.0 {
            forwardCount = 0
            lastResetTime = now
        }
        guard forwardCount < maxForwardsPerSecond else { return false }

        if now.timeIntervalSince(lastForwardTime) < minForwardInterval { return false }

        // Only consume rate-limit token after all checks pass
        forwardCount += 1
        lastForwardTime = now
        return true
    }

    private func trackMessageID(_ id: String) {
        forwardedMessageIDs.append(id)
        forwardedMessageIDSet.insert(id)
        if forwardedMessageIDs.count > maxTrackedIDs {
            let removeCount = forwardedMessageIDs.count / 2
            for oldID in forwardedMessageIDs.prefix(removeCount) {
                forwardedMessageIDSet.remove(oldID)
            }
            forwardedMessageIDs.removeFirst(removeCount)
        }
    }

    private func forwardToPOPOPX(_ message: TransportMessage) async throws {
        // Loop guard: if the recipient's best transport is the same transport
        // this message arrived on, forwarding via POPOPX would route it back
        // to the same mesh relay — skip to prevent a forwarding loop.
        if let recipientID = message.recipientID,
           let incomingTransport = message.transportHint {
            let bestTransport = await UnifiedConnectionHandler.shared.bestTransport(for: recipientID)
            if bestTransport == incomingTransport {
                return
            }
        }

        guard let text = String(data: message.payload, encoding: .utf8) else { return }
        try await TransportManager.shared.sendMessage(text, recipientID: message.recipientID)
    }
}
