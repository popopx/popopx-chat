//
//  GroupChatInfoNavLinks.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 15.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct UserSupportChatNavLink: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var groupInfo: GroupInfo
    @EnvironmentObject var chatModel: ChatModel
    @Binding var scrollToItemId: ChatItem.ID?

    var body: some View {
        let scopeInfo: GroupChatScopeInfo = .memberSupport(groupMember_: nil)
        NavigationLink {
            SecondaryChatView(
                chat: Chat(chatInfo: .group(groupInfo: groupInfo, groupChatScope: scopeInfo), chatItems: [], chatStats: ChatStats()),
                scrollToItemId: $scrollToItemId
            )
            .onAppear {
                ItemsModel.loadSecondaryChat(groupInfo.id, chatFilter: .groupChatScopeContext(groupScopeInfo: scopeInfo))
            }
        } label: {
            HStack {
                Label(NSLocalizedString("group_chat_with_admins", comment: "Navigation link to admin support chat"), systemImage: chat.supportUnreadCount > 0 ? "flag.fill" : "flag")
                Spacer()
                if chat.supportUnreadCount > 0 {
                    UnreadBadge(count: chat.supportUnreadCount, color: theme.colors.primary)
                }
            }
        }
    }
}

struct GroupReportsChatNavLink: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var groupInfo: GroupInfo
    @EnvironmentObject var chatModel: ChatModel
    @Binding var scrollToItemId: ChatItem.ID?

    var body: some View {
        NavigationLink {
            SecondaryChatView(
                chat: Chat(chatInfo: .group(groupInfo: groupInfo, groupChatScope: .reports), chatItems: [], chatStats: ChatStats()),
                scrollToItemId: $scrollToItemId
            )
            .onAppear {
                ItemsModel.loadSecondaryChat(chat.id, chatFilter: .msgContentTagContext(contentTag: .report))
            }
        } label: {
            HStack {
                Label {
                    Text(NSLocalizedString("group_member_reports", comment: "Navigation link to member reports"))
                } icon: {
                    Image(systemName: chat.chatStats.reportsCount > 0 ? "flag.fill" : "flag").foregroundColor(theme.colors.error)
                }
                Spacer()
                if chat.chatStats.reportsCount > 0 {
                    UnreadBadge(count: chat.chatStats.reportsCount, color: QuantumColors.error)
                }
            }
        }
    }
}

struct GroupPreferencesButton: View {
    @Binding var groupInfo: GroupInfo
    @State var preferences: FullGroupPreferences
    @State var currentPreferences: FullGroupPreferences
    var creatingGroup: Bool = false

    private var label: LocalizedStringKey {
        groupInfo.useRelays ? "Channel preferences"
        : groupInfo.businessChat == nil ? "Group preferences"
        : "Chat preferences"
    }

    var body: some View {
        NavigationLink {
            GroupPreferencesView(
                groupInfo: $groupInfo,
                preferences: $preferences,
                currentPreferences: currentPreferences,
                creatingGroup: creatingGroup,
                savePreferences: savePreferences
            )
            .navigationTitle(label)
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
            .onDisappear {
                let saveText = NSLocalizedString(
                    creatingGroup ? "Save"
                    : groupInfo.useRelays ? "Save and notify subscribers"
                    : "Save and notify group members",
                    comment: "alert button"
                )

                if groupInfo.fullGroupPreferences != preferences {
                    showAlert(
                        title: NSLocalizedString("Save preferences?", comment: "alert title"),
                        buttonTitle: saveText,
                        buttonAction: { savePreferences() },
                        cancelButton: true
                    )
                }
            }
        } label: {
            if creatingGroup {
                Text(NSLocalizedString("group_set_group_preferences", comment: "Button to configure group preferences during creation"))
            } else {
                Label(label, systemImage: "switch.2")
            }
        }
    }

    private func savePreferences() {
        Task {
            do {
                var gp = groupInfo.groupProfile
                gp.groupPreferences = toGroupPreferences(preferences)
                let gInfo = try await apiUpdateGroup(groupInfo.groupId, gp)
                await MainActor.run {
                    groupInfo = gInfo
                    ChatModel.shared.updateGroup(gInfo)
                    currentPreferences = preferences
                }
            } catch {
                logger.error("GroupPreferencesView apiUpdateGroup error: \(responseError(error))")
            }
        }
    }
}

struct GroupChatInfoView_Previews: PreviewProvider {
    static var previews: some View {
        GroupChatInfoView(
            chat: Chat(chatInfo: ChatInfo.sampleData.group, chatItems: []),
            groupInfo: Binding.constant(GroupInfo.sampleData),
            scrollToItemId: Binding.constant(nil),
            composeState: Binding.constant(ComposeState()),
            onSearch: {},
            localAlias: ""
        )
    }
}

// MARK: - POPOPX
fileprivate let _pxBrandGroupChatInfoNavLinks = "PX_GROUP_CHAT_INFO_NAV_LINKS"
