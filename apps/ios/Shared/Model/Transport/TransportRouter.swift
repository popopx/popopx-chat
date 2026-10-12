// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import OSLog

private let routerLogger = Logger(subsystem: "im.popopx", category: "TransportRouter")

actor TransportRouter {
    private var transports: [String: MessageTransport] = [:]
    private var preferredTransportID: String = "internet"
    private var messageQueue: [(message: TransportMessage, retries: Int)] = []
    private let maxQueueSize = 500
    private let maxRetries = 3

    private var peerTransports: [String: [String]] = [:]
    private var recentMessageIDs: [String] = []
    private let recentMessageLimit = 200

    var onQueueFlushed: (() -> Void)?

    var currentTransportID: String {
        get async {
            if let transport = transports[preferredTransportID], transport.isAvailable {
                return preferredTransportID
            }
            return transports.first(where: { $0.value.isAvailable })?.key ?? "none"
        }
    }

    var availableTransports: [String] {
        get async {
            transports.filter { $0.value.isAvailable }.map { $0.key }
        }
    }

    func registerTransport(_ id: String, transport: MessageTransport) {
        transports[id] = transport
        transport.onAvailabilityChanged = { [weak self] available in
            Task { [weak self] in
                await self?.handleAvailabilityChanged(transportID: id, available: available)
            }
        }
    }

    func setPreferredTransport(_ id: String) {
        guard transports[id] != nil else { return }
        preferredTransportID = id
    }

    func registerPeer(identity: String, transports: [String]) {
        peerTransports[identity] = transports
    }

    func unregisterPeer(identity: String) {
        peerTransports.removeValue(forKey: identity)
    }

    func updatePeerTransport(identity: String, add transport: String) {
        var existing = peerTransports[identity] ?? []
        if !existing.contains(transport) {
            existing.append(transport)
        }
        peerTransports[identity] = existing
    }

    func removePeerTransport(identity: String, transport: String) {
        guard var existing = peerTransports[identity] else { return }
        existing.removeAll { $0 == transport }
        if existing.isEmpty {
            peerTransports.removeValue(forKey: identity)
        } else {
            peerTransports[identity] = existing
        }
    }

    func transportsForPeer(identity: String) -> [String] {
        peerTransports[identity] ?? []
    }

    func send(_ message: TransportMessage) async throws {
        if recentMessageIDs.contains(message.id) { return }

        if let recipientID = message.recipientID,
           let peerTransportIDs = peerTransports[recipientID],
           !peerTransportIDs.isEmpty {
            let targetID = message.transportHint ?? bestAvailable(from: peerTransportIDs) ?? preferredTransportID
            if let transport = transports[targetID], transport.isAvailable {
                try await sendVia(transport: transport, message: message)
                trackMessageID(message.id)
                return
            }
            if let fallbackID = bestAvailable(from: peerTransportIDs),
               let fallback = transports[fallbackID] {
                try await sendVia(transport: fallback, message: message)
                trackMessageID(message.id)
                return
            }
        }

        let targetID = message.transportHint ?? preferredTransportID

        if let transport = transports[targetID], transport.isAvailable {
            try await sendVia(transport: transport, message: message)
            trackMessageID(message.id)
            return
        }

        if let fallback = transports.first(where: { $0.value.isAvailable }) {
            try await sendVia(transport: fallback.value, message: message)
            trackMessageID(message.id)
            return
        }

        enqueue(message)
    }

    func flushQueue() async {
        guard !messageQueue.isEmpty else { return }
        let pending = messageQueue
        messageQueue.removeAll()

        for item in pending {
            recentMessageIDs.removeAll { $0 == item.message.id }
            do {
                try await send(item.message)
            } catch {
                if item.retries + 1 < maxRetries {
                    // Exponential backoff before re-enqueueing
                    let delay = UInt64(pow(2.0, Double(item.retries))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    messageQueue.append((item.message, item.retries + 1))
                }
                if messageQueue.count >= maxQueueSize {
                    messageQueue.removeFirst()
                }
            }
        }
        onQueueFlushed?()
    }

    var queuedMessageCount: Int {
        messageQueue.count
    }

    private func sendVia(transport: MessageTransport, message: TransportMessage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            transport.send(message) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func bestAvailable(from peerTransportIDs: [String]) -> String? {
        let priority = ["smp", "ble", "multipeer", "nostr", "internet"]
        // Peer transport IDs use "ble" (from UnifiedPeerInfo) but the router
        // registers the Bluetooth adapter as "bluetooth". Normalize for lookup.
        let transportIDMap = ["ble": "bluetooth"]
        for id in priority {
            if peerTransportIDs.contains(id) {
                let routerID = transportIDMap[id] ?? id
                if let t = transports[routerID], t.isAvailable {
                    return id
                }
            }
        }
        for id in peerTransportIDs {
            let routerID = transportIDMap[id] ?? id
            if let t = transports[routerID], t.isAvailable {
                return id
            }
        }
        return nil
    }

    private func trackMessageID(_ id: String) {
        recentMessageIDs.append(id)
        if recentMessageIDs.count > recentMessageLimit {
            recentMessageIDs.removeFirst()
        }
    }

    private func handleAvailabilityChanged(transportID: String, available: Bool) {
        if available && transportID == preferredTransportID {
            Task { await flushQueue() }
        }
    }

    private func enqueue(_ message: TransportMessage) {
        messageQueue.append((message, 0))
        if messageQueue.count > maxQueueSize {
            let dropped = messageQueue.removeFirst()
            let limit = maxQueueSize
            routerLogger.warning("TransportRouter: queue overflow (\(limit) max), dropped message \(dropped.message.id, privacy: .public)")
        }
    }
}
