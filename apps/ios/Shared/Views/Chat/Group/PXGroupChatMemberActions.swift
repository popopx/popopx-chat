//
//  GroupChatMemberActions.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 15.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

@MainActor
func showRemoveMemberAlert(_ groupInfo: GroupInfo, _ mem: GroupMember, dismiss: DismissAction? = nil) {
    if mem.memberRole == .relay {
        let isLastActive = groupInfo.useRelays && mem.memberCurrent && {
            let activeRelays = ChatModel.shared.groupMembers.filter { $0.wrapped.memberRole == .relay && $0.wrapped.memberCurrent }
            return activeRelays.count <= 1
        }()
        showAlert(
            NSLocalizedString("Remove relay?", comment: "alert title"),
            message: isLastActive
                ? NSLocalizedString("This is the last active relay. Removing it will prevent message delivery to subscribers.", comment: "alert message")
                : NSLocalizedString("Relay will be removed from channel - this cannot be undone!", comment: "alert message"),
            actions: {[
                UIAlertAction(title: NSLocalizedString("Remove", comment: "alert action"), style: .destructive) { _ in
                    removeMember(groupInfo, mem, withMessages: false, dismiss: dismiss)
                },
                cancelAlertAction
            ]}
        )
    } else if groupInfo.useRelays {
        showAlert(
            NSLocalizedString("Remove subscriber?", comment: "alert title"),
            message: NSLocalizedString("Subscriber will be removed from channel - this cannot be undone!", comment: "alert message"),
            actions: {[
                UIAlertAction(title: NSLocalizedString("Remove", comment: "alert action"), style: .destructive) { _ in
                    removeMember(groupInfo, mem, withMessages: false, dismiss: dismiss)
                },
                UIAlertAction(title: NSLocalizedString("Remove and delete messages", comment: "alert action"), style: .destructive) { _ in
                    removeMember(groupInfo, mem, withMessages: true, dismiss: dismiss)
                },
                cancelAlertAction
            ]}
        )
    } else {
        showAlert(
            NSLocalizedString("Remove member?", comment: "alert title"),
            message: groupInfo.businessChat == nil
                ? NSLocalizedString("Member will be removed from group - this cannot be undone!", comment: "alert message")
                : NSLocalizedString("Member will be removed from chat - this cannot be undone!", comment: "alert message"),
            actions: {[
                UIAlertAction(title: NSLocalizedString("Remove", comment: "alert action"), style: .destructive) { _ in
                    removeMember(groupInfo, mem, withMessages: false, dismiss: dismiss)
                },
                UIAlertAction(title: NSLocalizedString("Remove and delete messages", comment: "alert action"), style: .destructive) { _ in
                    removeMember(groupInfo, mem, withMessages: true, dismiss: dismiss)
                },
                cancelAlertAction
            ]}
        )
    }
}

func removeMember(_ groupInfo: GroupInfo, _ mem: GroupMember, withMessages: Bool, dismiss: DismissAction?) {
    Task {
        do {
            let (updatedGroupInfo, updatedMembers) = try await apiRemoveMembers(groupInfo.groupId, [mem.groupMemberId], withMessages)
            await MainActor.run {
                ChatModel.shared.updateGroup(updatedGroupInfo)
                updatedMembers.forEach { updatedMember in
                    _ = ChatModel.shared.upsertGroupMember(updatedGroupInfo, updatedMember)
                    if withMessages {
                        ChatModel.shared.removeMemberItems(updatedMember, byMember: groupInfo.membership, groupInfo)
                    }
                }
                dismiss?()
            }
        } catch let error {
            logger.error("apiRemoveMembers error: \(responseError(error))")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error removing member", comment: "alert title"),
                    message: responseError(error)
                )
            }
        }
    }
}

func deleteGroupAlertMessage(_ groupInfo: GroupInfo) -> String {
    groupInfo.useRelays ? (
        groupInfo.membership.memberCurrent
            ? NSLocalizedString("group_channel_delete_all", comment: "Channel deletion warning for all subscribers")
            : NSLocalizedString("group_channel_delete_you", comment: "Channel deletion warning for current user")
    ) : groupInfo.businessChat == nil ? (
        groupInfo.membership.memberCurrent
            ? NSLocalizedString("group_group_delete_all", comment: "Group deletion warning for all members")
            : NSLocalizedString("group_group_delete_you", comment: "Group deletion warning for current user")
    ) : (
        groupInfo.membership.memberCurrent
            ? NSLocalizedString("group_chat_delete_all", comment: "Chat deletion warning for all members")
            : NSLocalizedString("group_chat_delete_you", comment: "Chat deletion warning for current user")
    )
}

func cantInviteIncognitoAlert() -> Alert {
    Alert(
        title: Text(NSLocalizedString("group_cant_invite_contacts_title", comment: "Alert title when incognito profile prevents inviting")),
        message: Text(NSLocalizedString("group_cant_invite_contacts_msg", comment: "Alert message explaining incognito restriction"))
    )
}

func largeGroupReceiptsDisabledAlert() -> Alert {
    Alert(
        title: Text(NSLocalizedString("group_receipts_disabled_title", comment: "Alert title for disabled receipts")),
        message: Text(String(format: NSLocalizedString("group_receipts_disabled_msg_fmt", comment: "Alert message with member count"), SMALL_GROUPS_RCPS_MEM_LIMIT))
    )
}

@ViewBuilder
func shareChannelPicker(groupInfo: GroupInfo, composeState: Binding<ComposeState>? = nil) -> some View {
    let v = ChatItemForwardingView(
        title: LocalizedStringKey(NSLocalizedString("share_channel_title", comment: "Share channel forwarding title")),
        isProhibited: { $0.prohibitedByPref(hasPopopxLink: true, isMediaOrFileAttachment: false, isVoice: false) },
        onSelectChat: { chat in Task { @MainActor in shareChatLink(chat, sourceGroupInfo: groupInfo, composeState: composeState) } },
        includeLocal: false
    )
    v.presentationDetents([.fraction(0.8)])
}

@MainActor
func shareChatLink(_ destChat: Chat, sourceGroupInfo: GroupInfo, composeState: Binding<ComposeState>? = nil) {
    let sendAsGroup = if let gInfo = destChat.chatInfo.groupInfo { gInfo.useRelays && gInfo.membership.memberRole >= .owner } else { false }
    Task {
        do {
            let mc = try await apiShareChatMsgContent(
                shareChatType: .group, shareChatId: Int64(sourceGroupInfo.groupId),
                toChatType: destChat.chatInfo.chatType, toChatId: destChat.chatInfo.apiId,
                toScope: destChat.chatInfo.groupChatScope(), sendAsGroup: sendAsGroup
            )
            if case let .chat(_, chatLink, ownerSig) = mc {
                await MainActor.run {
                    dismissAllSheets {
                        let cs = ComposeState(preview: .chatLinkPreview(chatLink: chatLink, ownerSig: ownerSig))
                        if let composeState {
                            composeState.wrappedValue = cs
                        } else {
                            ChatModel.shared.draft = cs
                            ChatModel.shared.draftChatId = destChat.id
                        }
                        if destChat.id != ChatModel.shared.chatId {
                            ItemsModel.shared.loadOpenChat(destChat.id)
                        }
                    }
                }
            } else {
                logger.error("shareChatLink: unexpected MsgContent: \(String(describing: mc))")
                await MainActor.run {
                    showAlert(NSLocalizedString("Error sharing channel", comment: "alert title"), message: String(describing: mc))
                }
            }
        } catch {
            logger.error("shareChatLink error: \(error.localizedDescription)")
            await MainActor.run {
                showAlert(NSLocalizedString("Error sharing channel", comment: "alert title"), message: error.localizedDescription)
            }
        }
    }
}

// MARK: - POPOPX
fileprivate let _pxBrandGroupChatMemberActions = "PX_GROUP_CHAT_MEMBER_ACTIONS"
