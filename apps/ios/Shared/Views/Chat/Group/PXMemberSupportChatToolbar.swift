//
//  MemberSupportChatToolbar.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 01.05.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct MemberSupportChatToolbar: View {
    // MARK: - POPOPX constants
    private static let pxToolbarWidth: CGFloat = 220
    private static let pxImagePadding: CGFloat = 4
    private static let pxShieldSymbol: String = "checkmark.shield"

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    var groupMember: GroupMember
    var imageSize: CGFloat = 32

    var body: some View {
        logger.debug("MemberSupportChatToolbar.body — member=\(groupMember.chatViewName), verified=\(groupMember.verified)")
        return HStack {
            MemberProfileImage(groupMember, size: imageSize)
                .padding(.trailing, Self.pxImagePadding)
            let t = Text(groupMember.chatViewName)
                .font(darkThemeHeaderFont())
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.onBackground)
            NameWithBadge((groupMember.verified ? memberVerifiedShield + t : t), groupMember.nameBadge, .headline)
                .lineLimit(1)
        }
        .foregroundColor(theme.colors.onBackground)
        .frame(width: Self.pxToolbarWidth)
        .popopxBranded()
    }

    private var memberVerifiedShield: Text {
        (Text(Image(systemName: Self.pxShieldSymbol)) + textSpace)
            .font(.caption)
            .foregroundColor(theme.colors.secondary)
            .baselineOffset(1)
            .kerning(-2)
    }
}

// MARK: - POPOPX
extension MemberSupportChatToolbar {
    var pxComponentTag: String { "px-member-support-toolbar" }
    var pxMemberDisplayName: String { groupMember.chatViewName }
    var pxIsVerifiedMember: Bool { groupMember.verified }
}

#Preview {
    MemberSupportChatToolbar(
        groupMember: GroupMember.sampleData
    )
    .environmentObject(CurrentColors.toAppTheme())
}
