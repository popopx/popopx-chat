//
//  BadgeUserPreview.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 30.07.2026.
//  Copyright © 2026 SimpleX Chat. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct BadgeUserPreview<Trailing: View>: View {
    @EnvironmentObject var chatModel: ChatModel
    let level: BadgeLevel
    let trailing: () -> Trailing

    init(level: BadgeLevel, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.level = level
        self.trailing = trailing
    }

    var body: some View {
        let user = chatModel.currentUser
        let displayName = user?.displayName ?? NSLocalizedString("My nickname", comment: "badges preview placeholder")
        let previewBadge = LocalBadge(
            // fabricated for the preview: the status is given here, and NameBadge renders from it alone
            badge: BadgeInfo(badgeType: level.badgeType, badgeExpiry: .distantFuture),
            status: .active
        )
        return VStack(spacing: 12) {
            ProfileImage(imageStr: user?.image, size: 128)
            HStack(alignment: .center, spacing: 6) {
                NameWithBadge(Text(displayName).font(.largeTitle), previewBadge, .largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                trailing()
            }
        }
    }
}
