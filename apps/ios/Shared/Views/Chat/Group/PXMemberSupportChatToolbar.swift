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
            let nameColor = isInDarkTheme() ? darkThemeAccentColor() : theme.colors.onBackground
            let nameFont = darkThemeHeaderFont()
            let nameText = groupMember.verified
                ? pxVerifiedNameText(displayName: groupMember.chatViewName, shieldColor: theme.colors.secondary, nameColor: nameColor, nameFont: nameFont)
                : Text(groupMember.chatViewName).font(nameFont).foregroundColor(nameColor)
            NameWithBadge(nameText, groupMember.nameBadge, .headline)
                .lineLimit(1)
        }
        .foregroundColor(theme.colors.onBackground)
        .frame(width: Self.pxToolbarWidth)
        .popopxBranded()
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
