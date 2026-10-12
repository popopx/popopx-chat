// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitchatMesh
import os

/// Manages the POPOPX global broadcast square (24H 阅后即焚广场).
///
/// Publishes ephemeral kind-20002 events with throwaway identities and
/// subscribes to the global feed, filtering through Needle for spam.
@MainActor
final class GlobalBroadcastManager: ObservableObject {
    static let shared = GlobalBroadcastManager()

    private let logger = Logger(subsystem: "im.popopx", category: "GlobalSquare")

    @Published private(set) var feedItems: [BroadcastItem] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var lastError: String?

    /// Hard cap on in-memory feed size to bound RAM under heavy relay load.
    private let maxFeedSize = 200

    /// Default relays for the global square — public, high-bandwidth, NIP-40
    /// honoring where possible.
    private let defaultRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.primal.net",
        "wss://offchain.pub"
    ]

    private var subscriptionId: String?
    private let needleProcessor = NeedleProcessor.shared

    private init() {}

    // MARK: - Publishing

    /// Publish a new drift-hole to the global square.
    ///
    /// Each call mints a fresh throwaway identity so no two publishes are
    /// linkable. The event is PoW-mined (12 bits default) before signing to
    /// raise the spam cost for attackers.
    func publish(content: String) async throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BroadcastError.emptyContent
        }
        guard content.count <= 500 else {
            throw BroadcastError.contentTooLong
        }

        // 1. Throwaway identity — never reused, never persisted.
        let tempIdentity = try NostrIdentity.generate()

        // 2. 24-hour TTL from now.
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)

        // 3. Create + mine + sign. Mining runs off-main inside NostrPoW.
        let event = try await NostrProtocol.createMinedGlobalBroadcastEvent(
            content: content,
            senderIdentity: tempIdentity,
            expiresAt: expiresAt,
            powTargetBits: 12
        )

        // 4. Fan-out to the default relay set. Fire-and-forget per relay; we
        //    don't block on ACKs because the user experience is "launched".
        NostrRelayManager.shared.sendEvent(event, to: defaultRelays)

        logger.info("Published global broadcast event \(event.id.prefix(8))...")
    }

    // MARK: - Subscription

    /// Open a global subscription to kind-20002 events. Idempotent.
    func startSubscription() {
        guard !isSubscribed else { return }

        // Flip the activation gate so default relays connect even without
        // favorites or location permission.
        NostrRelayManager.shared.isGlobalSquareActive = true

        let filter = NostrFilter.globalBroadcast(limit: 100)
        let subId = UUID().uuidString
        subscriptionId = subId

        NostrRelayManager.shared.subscribe(
            filter: filter,
            id: subId
        ) { [weak self] event in
            Task { [weak self] in
                await self?.handleIncomingEvent(event)
            }
        } onEOSE: { [weak self] in
            self?.logger.info("Global square EOSE received")
        }

        isSubscribed = true
        logger.info("Started global square subscription")
    }

    /// Close the subscription and clear the feed.
    func stopSubscription() {
        if let subId = subscriptionId {
            NostrRelayManager.shared.unsubscribe(id: subId)
            subscriptionId = nil
        }
        NostrRelayManager.shared.isGlobalSquareActive = false
        isSubscribed = false
        feedItems.removeAll()
        logger.info("Stopped global square subscription")
    }

    // MARK: - Inbound handling

    private func handleIncomingEvent(_ event: NostrEvent) async {
        // Signature verification is handled by NostrRelayManager pipeline
        // (Schnorr verification runs off-main before dispatching events).

        // 1. Kind check — defensive, the filter should already scope this.
        guard event.kind == NostrProtocol.EventKind.globalBroadcast.rawValue else {
            return
        }

        // 2. Expiration check (NIP-40). Drop expired events silently.
        let now = Int(Date().timeIntervalSince1970)
        if let expTag = event.tags.first(where: { $0.first == "expiration" }),
           expTag.count >= 2,
           let expTime = Int(expTag[1]),
           expTime < now {
            return
        }

        // 3. Needle local filter — blocks spam and low-value content before
        //    it ever touches the UI.
        let isInteresting = await needleProcessor.shouldShow(content: event.content)
        guard isInteresting else {
            return
        }

        // 4. Build the feed item.
        let expiresAt: Int = {
            if let expTag = event.tags.first(where: { $0.first == "expiration" }),
               expTag.count >= 2,
               let expTime = Int(expTag[1]) {
                return expTime
            }
            // Fallback: 24H from created_at if tag is missing.
            return event.created_at + 24 * 60 * 60
        }()

        let item = BroadcastItem(
            id: event.id,
            content: event.content,
            pubkey: event.pubkey,
            createdAt: Int64(event.created_at),
            expiresAt: Int64(expiresAt)
        )

        // 5. Dedup — drop if we've already seen this event ID.
        guard !feedItems.contains(where: { $0.id == item.id }) else {
            return
        }

        // 6. Prepend and trim.
        feedItems.insert(item, at: 0)
        if feedItems.count > maxFeedSize {
            feedItems.removeLast(feedItems.count - maxFeedSize)
        }
    }

}

enum BroadcastError: LocalizedError {
    case emptyContent
    case contentTooLong

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return NSLocalizedString("nostr_broadcast_empty", comment: "Content cannot be empty")
        case .contentTooLong:
            return NSLocalizedString("nostr_broadcast_too_long", comment: "Content exceeds 500 character limit")
        }
    }
}
