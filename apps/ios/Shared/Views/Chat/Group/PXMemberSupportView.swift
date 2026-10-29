//
//  PXMemberSupport.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 28.04.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXMemberSupportConfig {
    static let memberImageSize: CGFloat = 40
    static let trailingPadding: CGFloat = 3
    static let flagScaleFactor: CGFloat = 0.78
    static let searchPadding: CGFloat = 10
    static let rowSpacing: CGFloat = 4
    static let statusFontSize: Font = .caption
    static let componentIdentifier = "px-member-support"
}

struct PXMemberSupport: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var searchText: String = ""
    @FocusState private var searchFocussed
    var groupInfo: GroupInfo
    @Binding var scrollToItemId: ChatItem.ID?

    var body: some View {
        pxMainContent
            .task {
                await chatModel.loadGroupMembers(groupInfo)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await chatModel.loadGroupMembers(groupInfo)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(NSLocalizedString("member_support_reload", comment: "Reload members"))
                }
            }
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder private var pxMainContent: some View {
        let membersWithChats = pxSortedMembersWithChats()
        let s = searchText.trimmingCharacters(in: .whitespaces).localizedLowercase
        let filteredMembersWithChats = pxFilterMembers(membersWithChats, query: s)

        if membersWithChats.isEmpty {
            pxEmptyStateView
        } else {
            pxMembersListView(filteredMembersWithChats)
        }
    }

    @ViewBuilder private var pxEmptyStateView: some View {
        Text(groupInfo.fullGroupPreferences.support.on
             ? "No chats with members"
             : "Chats with members are disabled")
            .foregroundColor(.secondary)
            .accessibilityLabel(NSLocalizedString("member_support_empty", comment: "Empty member support state"))
    }

    @ViewBuilder private func pxMembersListView(_ members: [GMember]) -> some View {
        List {
            searchFieldView(text: $searchText, focussed: $searchFocussed, theme.colors.onBackground, theme.colors.secondary)
                .padding(.leading, 8)
            ForEach(members) { memberWithChat in
                MemberSupportChatNavLink(
                    groupInfo: groupInfo,
                    memberWithChat: memberWithChat,
                    scrollToItemId: $scrollToItemId
                )
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
    }

    struct MemberSupportChatNavLink: View {
        @EnvironmentObject var chatModel: ChatModel
        @EnvironmentObject var theme: AppTheme
        @State private var memberSupportChatNavLinkActive = false
        var groupInfo: GroupInfo
        var memberWithChat: GMember
        @Binding var scrollToItemId: ChatItem.ID?

        var body: some View {
            ZStack {
                let scopeInfo: GroupChatScopeInfo = .memberSupport(groupMember_: memberWithChat.wrapped)
                Button {
                    ItemsModel.loadSecondaryChat(groupInfo.id, chatFilter: .groupChatScopeContext(groupScopeInfo: scopeInfo)) {
                        memberSupportChatNavLinkActive = true
                    }
                } label: {
                    SupportChatRowView(groupMember: memberWithChat, groupInfo: groupInfo)
                }
                .accessibilityLabel(NSLocalizedString("member_support_chat_nav", comment: "Navigate to member support chat"))
            }
            .navigationDestination(isPresented: $memberSupportChatNavLinkActive) {
                let scopeInfo: GroupChatScopeInfo = .memberSupport(groupMember_: memberWithChat.wrapped)
                SecondaryChatView(
                    chat: Chat(chatInfo: .group(groupInfo: groupInfo, groupChatScope: scopeInfo), chatItems: [], chatStats: ChatStats()),
                    scrollToItemId: $scrollToItemId
                )
            }
            .if(!memberWithChat.wrapped.memberPending && memberWithChat.wrapped.supportChatNotRead) { v in
                v.swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await markSupportChatRead(groupInfo, memberWithChat.wrapped) }
                    } label: {
                        Label(NSLocalizedString("group_read_action", comment: "Mark support chat as read"), systemImage: "checkmark")
                    }
                    .tint(isInDarkTheme() ? theme.colors.primary.opacity(0.8) : theme.colors.primary)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if memberWithChat.wrapped.memberPending {
                    Button {
                        showAcceptMemberAlert(groupInfo, memberWithChat.wrapped)
                    } label: {
                        Label(NSLocalizedString("group_accept_action", comment: "Accept pending member"), systemImage: "checkmark")
                    }
                    .tint(theme.colors.primary)
                } else {
                    Button {
                        showDeleteMemberSupportChatAlert(groupInfo, memberWithChat.wrapped)
                    } label: {
                        Label(NSLocalizedString("group_delete_action_member", comment: "Delete member support chat"), systemImage: "trash")
                    }
                    .tint(theme.colors.error)
                }
            }
        }
    }

    // MARK: - POPOPX Data Helpers

    /// POPOPX: filter members by search query
    private func pxFilterMembers(_ members: [GMember], query: String) -> [GMember] {
        query == ""
        ? members
        : members.filter { $0.wrapped.localAliasAndFullName.localizedLowercase.contains(query) }
    }

    /// POPOPX: sort members with priority for pending, mentions, attention, unread, then timestamp
    func pxSortedMembersWithChats() -> [GMember] {
        logger.debug("POPOPX: sortedMembersWithChats called")
        return chatModel.groupMembers
            .filter {
                $0.wrapped.supportChat != nil &&
                $0.wrapped.memberStatus != .memLeft &&
                $0.wrapped.memberStatus != .memRemoved
            }
            .sorted { (m0: GMember, m1: GMember) -> Bool in
                if m0.wrapped.memberPending != m1.wrapped.memberPending {
                    return m0.wrapped.memberPending
                }
                let mentions0 = (m0.wrapped.supportChat?.mentions ?? 0) > 0
                let mentions1 = (m1.wrapped.supportChat?.mentions ?? 0) > 0
                if mentions0 != mentions1 { return mentions0 }
                let attention0 = (m0.wrapped.supportChat?.memberAttention ?? 0) > 0
                let attention1 = (m1.wrapped.supportChat?.memberAttention ?? 0) > 0
                if attention0 != attention1 { return attention0 }
                let unread0 = (m0.wrapped.supportChat?.unread ?? 0) > 0
                let unread1 = (m1.wrapped.supportChat?.unread ?? 0) > 0
                if unread0 != unread1 { return unread0 }
                return (m0.wrapped.supportChat?.chatTs ?? .distantPast) > (m1.wrapped.supportChat?.chatTs ?? .distantPast)
            }
    }

    /// POPOPX: backward-compatible alias
    func sortedMembersWithChats() -> [GMember] { pxSortedMembersWithChats() }

    private struct SupportChatRowView: View {
        @EnvironmentObject var chatModel: ChatModel
        @ObservedObject var groupMember: GMember
        @EnvironmentObject var theme: AppTheme
        @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
        var groupInfo: GroupInfo

        var dynamicChatInfoSize: CGFloat { dynamicSize(userFont).chatInfoSize }

        var body: some View {
            let member = groupMember.wrapped
            HStack {
                pxMemberAvatar(member)
                pxMemberInfoStack(member)
                Spacer()
                pxTrailingIndicators(member)
            }
        }

        // MARK: - POPOPX Row Builders

        @ViewBuilder private func pxMemberAvatar(_ member: GroupMember) -> some View {
            MemberProfileImage(member, size: PXMemberSupportConfig.memberImageSize)
                .padding(.trailing, PXMemberSupportConfig.trailingPadding)
        }

        @ViewBuilder private func pxMemberInfoStack(_ member: GroupMember) -> some View {
            VStack(alignment: .leading) {
                let nameText = member.verified
                    ? pxVerifiedNameText(displayName: member.chatViewName, shieldColor: isInDarkTheme() ? theme.colors.secondary.opacity(0.9) : theme.colors.secondary, nameColor: theme.colors.onBackground)
                    : Text(member.chatViewName).foregroundColor(theme.colors.onBackground)
                NameWithBadge(nameText, member.nameBadge)
                    .lineLimit(1)
                Text(pxMemberStatus(member))
                    .lineLimit(1)
                    .font(PXMemberSupportConfig.statusFontSize)
                    .foregroundColor(theme.colors.secondary)
            }
        }

        @ViewBuilder private func pxTrailingIndicators(_ member: GroupMember) -> some View {
            if member.memberPending {
                Image(systemName: "flag.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: dynamicChatInfoSize * PXMemberSupportConfig.flagScaleFactor,
                           height: dynamicChatInfoSize * PXMemberSupportConfig.flagScaleFactor)
                    .foregroundColor(isInDarkTheme() ? theme.colors.primary.opacity(0.85) : theme.colors.primary)
            }
            if let supportChat = member.supportChat {
                SupportChatUnreadIndicator(supportChat: supportChat)
            }
        }

        /// POPOPX: resolve member status text
        private func pxMemberStatus(_ member: GroupMember) -> LocalizedStringKey {
            if case .failed = member.activeConn?.connStatus {
                return "failed"
            } else if member.activeConn?.connDisabled ?? false {
                return "disabled"
            } else if member.activeConn?.connInactive ?? false {
                return "inactive"
            } else if member.memberPending {
                return member.memberStatus.text
            } else {
                return LocalizedStringKey(member.memberRole.text)
            }
        }

        /// POPOPX: verified shield icon with styling
        struct SupportChatUnreadIndicator: View {
            @EnvironmentObject var theme: AppTheme
            @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
            var supportChat: GroupSupportChat

            var dynamicChatInfoSize: CGFloat { dynamicSize(userFont).chatInfoSize }

            private var indicatorTint: Color {
                if supportChat.mentions > 0 || supportChat.memberAttention > 0 {
                    return theme.colors.primary
                } else {
                    return theme.colors.secondary
                }
            }

            var body: some View {
                HStack(alignment: .center, spacing: 2) {
                    if supportChat.unread > 0 || supportChat.mentions > 0 || supportChat.memberAttention > 0 {
                        if supportChat.mentions > 0 && supportChat.unread > 1 {
                            Text(verbatim: "\(MENTION_START)")
                                .font(userFont <= .xxxLarge ? .body : .callout)
                                .foregroundColor(indicatorTint)
                                .frame(minWidth: dynamicChatInfoSize, minHeight: dynamicChatInfoSize)
                                .cornerRadius(dynamicSize(userFont).unreadCorner)
                                .padding(.bottom, 1)
                        }
                        let singleUnreadIsMention = supportChat.mentions > 0 && supportChat.unread == 1
                        (singleUnreadIsMention ? Text(verbatim: "\(MENTION_START)") : unreadCountText(supportChat.unread))
                            .font(userFont <= .xxxLarge ? .caption : .caption2)
                            .foregroundColor(theme.colors.background)
                            .padding(.horizontal, dynamicSize(userFont).unreadPadding)
                            .frame(minWidth: dynamicChatInfoSize, minHeight: dynamicChatInfoSize)
                            .background(indicatorTint)
                            .cornerRadius(dynamicSize(userFont).unreadCorner)
                    }
                }
                .frame(height: dynamicChatInfoSize)
                .frame(minWidth: 22)
            }
        }
    }
}

func showDeleteMemberSupportChatAlert(_ groupInfo: GroupInfo, _ member: GroupMember) {
    showAlert(
        title: NSLocalizedString("Delete chat with member?", comment: "alert title"),
        buttonTitle: NSLocalizedString("member_support_delete_button", comment: "Delete button in member support alert"),
        buttonAction: { deleteMemberSupportChat(groupInfo, member) },
        cancelButton: true
    )
}

func deleteMemberSupportChat(_ groupInfo: GroupInfo, _ member: GroupMember) {
    logger.debug("POPOPX: deleteMemberSupportChat for member \(member.groupMemberId)")
    Task {
        do {
            let (gInfo, updatedMember) = try await apiDeleteMemberSupportChat(groupInfo.groupId, member.groupMemberId)
            await MainActor.run {
                _ = ChatModel.shared.upsertGroupMember(gInfo, updatedMember)
                ChatModel.shared.updateGroup(gInfo)
            }
            // TODO [TODO-FEATURE: medium] member row doesn't get removed from list
            await ChatModel.shared.loadGroupMembers(gInfo)
        } catch let error {
            logger.error("apiDeleteMemberSupportChat error: \(responseError(error))")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error deleting chat", comment: "alert title"),
                    message: responseError(error)
                )
            }
        }
    }
}

// MARK: - POPOPX
extension PXMemberSupport {
    var pxComponentTag: String { PXMemberSupportConfig.componentIdentifier }
    static let pxSearchPadding: CGFloat = PXMemberSupportConfig.searchPadding
    static let pxMemberImageSize: CGFloat = PXMemberSupportConfig.memberImageSize
    static let pxRowSpacing: CGFloat = PXMemberSupportConfig.rowSpacing

    /// POPOPX: count of active (non-left, non-removed) support members
    var pxActiveMemberCount: Int {
        chatModel.groupMembers.filter {
            $0.wrapped.supportChat != nil &&
            $0.wrapped.memberStatus != .memLeft &&
            $0.wrapped.memberStatus != .memRemoved
        }.count
    }

    /// POPOPX: whether support is enabled for this group
    var pxSupportEnabled: Bool {
        groupInfo.fullGroupPreferences.support.on
    }
}

#Preview {
    PXMemberSupport(
        groupInfo: GroupInfo.sampleData,
        scrollToItemId: Binding.constant(nil)
    )
}
