//
//  BadgesView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 11.09.2026.
//  Copyright © 2026 SimpleX Chat. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct BadgesView: View {
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject private var badgeModel = BadgeModel.shared
    var showsAsSheet: Bool = false

    private var shownBadge: BadgeState? {
        guard badgeModel.userId == chatModel.currentUser?.userId else { return nil }
        if let badgeState = badgeModel.badgeState, badgeState.shown { return badgeState }
        return nil
    }

    var body: some View {
        Group {
            if let badgeState = shownBadge {
                BadgesYourBadgeView(badgeState: badgeState, showsAsSheet: showsAsSheet)
                    .transition(.opacity)
            } else {
                BadgesSupportPopopxView(showsAsSheet: showsAsSheet)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: shownBadge != nil)
    }
}

var supportPopopxAlertAction: UIAlertAction {
    UIAlertAction(title: NSLocalizedString("Support POPOPX", comment: "alert button"), style: .default) { _ in
        Task { @MainActor in openBadgesView() }
    }
}

@MainActor
func openBadgesView() {
    showAppSheet {
        NavigationView {
            BadgesView(showsAsSheet: true)
                .modifier(ThemedBackground())
        }
    }
}

// false until the badge state is loaded for the current profile, so a supporter is never pitched to
@MainActor
func noShownBadge() -> Bool {
    BadgeModel.shared.badgeState?.shown != true && BadgeModel.shared.userId == ChatModel.shared.currentUser?.userId
}
