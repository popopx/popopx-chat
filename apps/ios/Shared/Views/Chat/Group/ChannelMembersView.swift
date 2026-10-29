//
//  ChannelMembersView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 20.02.2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ChannelMembersView: View {
    @ObservedObject var chat: Chat
    var groupInfo: GroupInfo
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        Group {
            let members = chatModel.groupMembers
            .filter { m in
                let s = m.wrapped.memberStatus
                return s != .memLeft && s != .memRemoved && m.wrapped.memberRole != .relay
            }
        if groupInfo.isOwner {
            let subscriberCount = groupInfo.groupSummary.publicMemberCount ?? Int64(members.count + 1)
            List {
                Section(header: Text(subscriberCountStr(subscriberCount))
                    .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                    memberRow(GMember(groupInfo.membership), user: true, showRole: true)
                    ForEach(members) { member in
                        memberRow(member, user: false, showRole: member.wrapped.memberRole >= .owner)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        } else {
            let owners = members.filter { $0.wrapped.memberRole >= .owner }
            List {
                Section(header: Text(NSLocalizedString("group_owners_section", comment: "Section header for channel/group owners"))
                    .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                    ForEach(owners) { member in
                        memberRow(member, user: false, showRole: false)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        }
        }
        .popopxBranded()
    }

    @ViewBuilder private func memberRow(_ gMember: GMember, user: Bool, showRole: Bool) -> some View {
        let member = gMember.wrapped
        let nameColor = member.memberIncognito ? QuantumColors.accent : theme.colors.onBackground
        let displayName = member.verified
            ? pxVerifiedNameText(displayName: member.chatViewName, shieldColor: theme.colors.secondary, nameColor: nameColor)
            : Text(member.chatViewName).foregroundColor(nameColor)
        let row = HStack {
            MemberProfileImage(member, size: 38)
                .padding(.trailing, 2)
            VStack(alignment: .leading) {
                NameWithBadge(displayName, member.nameBadge)
                    .lineLimit(1)
                if user {
                    Text(NSLocalizedString("group_you_label", comment: "Label indicating current user"))
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                }
            }
            Spacer()
            if showRole {
                Text(member.memberRole.text)
                    .foregroundColor(theme.colors.secondary)
            }
        }
        if user {
            row
        } else {
            NavigationLink {
                PXGroupMemberDetail(
                    groupInfo: groupInfo,
                    chat: chat,
                    groupMember: gMember,
                    scrollToItemId: Binding.constant(nil)
                )
                .toolbar(.visible, for: .navigationBar)
            } label: {
                row
            }
        }
    }
}

#Preview {
    ChannelMembersView(
        chat: Chat.sampleData,
        groupInfo: GroupInfo.sampleData
    )
}
