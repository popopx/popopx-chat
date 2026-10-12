//
//  ChatViewActions.swift
//  POPOPX
//
//  Extracted from ChatView.swift
//  Action-related helper functions for ChatView (delete, archive, theme).
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

@MainActor
func publicGroupEditor(_ chat: Chat) -> Bool {
    if case let .group(groupInfo, _) = chat.chatInfo {
        groupInfo.useRelays && groupInfo.membership.memberRole >= .moderator
    } else {
        false
    }
}

@MainActor
func broadcastDeleteButtonText(_ chat: Chat) -> LocalizedStringKey {
    chat.chatInfo.featureEnabled(.fullDelete) ? LocalizedStringKey(NSLocalizedString("chat_delete_for_everyone", comment: "Delete for everyone")) : LocalizedStringKey(NSLocalizedString("chat_mark_deleted_for_everyone", comment: "Mark deleted for everyone"))
}

// Spec: spec/client/chat-view.md#deleteMessages
@MainActor
func deleteMessages(_ chat: Chat, _ deletingItems: [Int64], _ mode: CIDeleteMode = .cidmInternal, moderate: Bool, _ onSuccess: @escaping () async -> Void = {}) {
    let itemIds = deletingItems
    if itemIds.count > 0 {
        let chatInfo = chat.chatInfo
        Task {
            do {
                let deletedItems = if case .cidmBroadcast = mode,
                    moderate,
                    case .group = chat.chatInfo {
                    try await apiDeleteMemberChatItems(
                        groupId: chatInfo.apiId,
                        itemIds: itemIds
                    )
                } else {
                    try await apiDeleteChatItems(
                        type: chatInfo.chatType,
                        id: chatInfo.apiId,
                        scope: chatInfo.groupChatScope(),
                        itemIds: itemIds,
                        mode: mode
                    )
                }

                await MainActor.run {
                    for di in deletedItems {
                        if let toItem = di.toChatItem {
                            _ = ChatModel.shared.upsertChatItem(chatInfo, toItem.chatItem)
                        } else {
                            ChatModel.shared.removeChatItem(chatInfo, di.deletedChatItem.chatItem)
                        }
                        let deletedItem = di.deletedChatItem.chatItem
                        if deletedItem.isActiveReport {
                            ChatModel.shared.decreaseGroupReportsCounter(chatInfo.id)
                        }
                    }
                    if let updatedChatInfo = deletedItems.last?.deletedChatItem.chatInfo {
                        ChatModel.shared.updateChatInfo(updatedChatInfo)
                    }
                }
                await onSuccess()
            } catch {
                logger.error("ChatView.deleteMessages error: \(error.localizedDescription)")
                await MainActor.run {
                    showAlert(NSLocalizedString("Error deleting message", comment: "alert title"), message: responseError(error))
                }
            }
        }
    }
}

@MainActor
func archiveReports(_ chat: Chat, _ itemIds: [Int64], _ forAll: Bool, _ onSuccess: @escaping () async -> Void = {}) {
    if itemIds.count > 0 {
        let chatInfo = chat.chatInfo
        Task {
            do {
                let deleted = try await apiDeleteReceivedReports(
                    groupId: chatInfo.apiId,
                    itemIds: itemIds,
                    mode: forAll ? CIDeleteMode.cidmBroadcast : CIDeleteMode.cidmInternalMark
                )

                await MainActor.run {
                    for di in deleted {
                        if let toItem = di.toChatItem {
                            _ = ChatModel.shared.upsertChatItem(chatInfo, toItem.chatItem)
                        } else {
                            ChatModel.shared.removeChatItem(chatInfo, di.deletedChatItem.chatItem)
                        }
                        let deletedItem = di.deletedChatItem.chatItem
                        if deletedItem.isActiveReport {
                            ChatModel.shared.decreaseGroupReportsCounter(chatInfo.id)
                        }
                    }
                    if let updatedChatInfo = deleted.last?.deletedChatItem.chatInfo {
                        ChatModel.shared.updateChatInfo(updatedChatInfo)
                    }
                }
                await onSuccess()
            } catch {
                logger.error("ChatView.archiveReports error: \(error.localizedDescription)")
                showAlert(NSLocalizedString("Error archiving", comment: "alert title"), message: responseError(error))
            }
        }
    }
}

@MainActor
func buildTheme() -> AppTheme {
    if let cId = ChatModel.shared.chatId, let chat = ChatModel.shared.getChat(cId) {
        let perChatTheme = if case let .direct(contact) = chat.chatInfo {
            contact.uiThemes?.preferredMode(!AppTheme.shared.colors.isLight)
        } else if case let .group(groupInfo, _) = chat.chatInfo {
            groupInfo.uiThemes?.preferredMode(!AppTheme.shared.colors.isLight)
        } else {
            nil as ThemeModeOverride?
        }
        let overrides = if perChatTheme != nil {
            ThemeManager.currentColors(nil, perChatTheme, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
        } else {
            nil as ThemeManager.ActiveTheme?
        }
        let theme = overrides ?? CurrentColors
        return AppTheme(name: theme.name, base: theme.base, colors: theme.colors, appColors: theme.appColors, wallpaper: theme.wallpaper)
    } else {
        return AppTheme.shared
    }
}
