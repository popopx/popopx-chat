// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Testing
@testable import BitchatMesh

struct ChatFavoriteTogglePolicyTests {
    @Test
    func addingWithoutExistingStatusUsesFallbackNicknameAndBridgeKey() {
        let plan = ChatFavoriteTogglePolicy.plan(
            currentStatus: nil,
            fallbackNickname: "alice",
            bridgedNostrKey: "npub-alice"
        )

        #expect(plan == ChatFavoriteTogglePlan(
            persistenceAction: .add(nickname: "alice", nostrKey: "npub-alice"),
            notification: .none
        ))
    }

    @Test
    func addingMutualFavoriteSendsPositiveNotification() {
        let plan = ChatFavoriteTogglePolicy.plan(
            currentStatus: ChatFavoriteStatusSnapshot(
                peerNickname: "alice",
                peerNostrPublicKey: "npub-current",
                isFavorite: false,
                theyFavoritedUs: true
            ),
            fallbackNickname: "fallback",
            bridgedNostrKey: "npub-bridge"
        )

        #expect(plan == ChatFavoriteTogglePlan(
            persistenceAction: .add(nickname: "alice", nostrKey: "npub-current"),
            notification: .send(isFavorite: true)
        ))
    }

    @Test
    func addingWithoutAnyNicknameUsesUnknown() {
        let plan = ChatFavoriteTogglePolicy.plan(
            currentStatus: nil,
            fallbackNickname: nil,
            bridgedNostrKey: nil
        )

        #expect(plan == ChatFavoriteTogglePlan(
            persistenceAction: .add(nickname: "Unknown", nostrKey: nil),
            notification: .none
        ))
    }

    @Test
    func removingFavoriteSendsNegativeNotification() {
        let plan = ChatFavoriteTogglePolicy.plan(
            currentStatus: ChatFavoriteStatusSnapshot(
                peerNickname: "alice",
                peerNostrPublicKey: "npub-current",
                isFavorite: true,
                theyFavoritedUs: false
            ),
            fallbackNickname: nil,
            bridgedNostrKey: nil
        )

        #expect(plan == ChatFavoriteTogglePlan(
            persistenceAction: .remove,
            notification: .send(isFavorite: false)
        ))
    }
}
