//
//  PXChatItemForwardingView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 12.04.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXChatItemForwardingConfig {
    static let chatAvatarSize: CGFloat = 30
    static let incognitoMaskSize: CGFloat = 22
    static let avatarTrailingPadding: CGFloat = 2
    static let listItemMaxLines: Int = 1
    static let emptyStateOpacity: CGFloat = 0.85
    static let toolbarTitleDarkOpacity: Double = 0.85
    static let componentIdentifier: String = "PX_CHAT_ITEM_FORWARDING_VIEW"
    static let a11yCancel: String = "px_forward_cancel"
    static let a11yChatRow: String = "px_forward_chat_row"
    static let a11yIncognito: String = "px_forward_incognito"
    static let a11yEmptyState: String = "px_forward_empty"
    static let forwardProhibitedAlertId: String = "px_forward_prohibited"
}

// MARK: - POPOPX View Model
@MainActor
struct PXChatItemForwardingViewModel {
    let chats: [Chat]
    let includeLocal: Bool
    var filteredChats: [Chat] { filterChatsToForwardTo(chats: chats, includeLocal: includeLocal) }
    func isSearchEmpty(_ searchText: String) -> Bool {
        let s = searchText.trimmingCharacters(in: .whitespaces).localizedLowercase
        return s.isEmpty ? filteredChats.isEmpty : filteredChats.filter { foundChat($0, s) }.isEmpty
    }
    var hasForwardableChats: Bool { !filteredChats.isEmpty }
    func filteredForSearch(_ searchText: String) -> [Chat] {
        let s = searchText.trimmingCharacters(in: .whitespaces).localizedLowercase
        return s.isEmpty ? filteredChats : filteredChats.filter { foundChat($0, s) }
    }
}

struct ChatItemForwardingView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss

    var title: LocalizedStringKey = "Forward"
    var chatItems: [ChatItem] = []
    var fromChatInfo: ChatInfo? = nil
    var composeState: Binding<ComposeState>? = nil
    var isProhibited: ((Chat) -> Bool)? = nil
    var onSelectChat: ((Chat) -> Void)? = nil
    var includeLocal: Bool = true

    @State private var searchText: String = ""
    @State private var alert: SomeAlert?
    private var chatsToForwardTo: [Chat] { filterChatsToForwardTo(chats: ChatModel.shared.chats, includeLocal: includeLocal) }

    var body: some View {
        forwardingNavigationStack
            .modifier(ThemedBackground())
            .alert(item: $alert) { $0.alert }
            .popopxBranded()
    }

    // MARK: - POPOPX decomposed sub-views

    @ViewBuilder private var forwardingNavigationStack: some View {
        NavigationStack {
            forwardListView
                .toolbar { forwardingToolbar }
        }
    }

    @ToolbarContentBuilder private var forwardingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(NSLocalizedString("Cancel", comment: "")) {
                dismiss()
            }
            .accessibilityLabel(Text(verbatim: PXChatItemForwardingConfig.a11yCancel))
        }
        ToolbarItem(placement: .principal) {
            Text(title)
                .font(isInDarkTheme() ? QuantumFonts.sectionHeader : .headline)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                .bold()
        }
    }

    @ViewBuilder private var forwardListView: some View {
        VStack(alignment: .leading) {
            if !chatsToForwardTo.isEmpty {
                searchableChatList
            } else {
                emptyStateView
            }
        }
    }

    @ViewBuilder private var searchableChatList: some View {
        List {
            let vm = PXChatItemForwardingViewModel(chats: chatsToForwardTo, includeLocal: includeLocal)
            let chats = vm.filteredForSearch(searchText)
            ForEach(chats) { chat in
                forwardListChatView(chat)
                    .disabled(chatModel.deletedChats.contains(chat.chatInfo.id))
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .modifier(ThemedBackground(grouped: true))
    }

    private var emptyStateView: some View {
        ZStack {
            Text(NSLocalizedString("compose_no_filtered_chats", comment: "Empty state when no chats match filter"))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.6) : theme.colors.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(verbatim: PXChatItemForwardingConfig.a11yEmptyState))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(ThemedBackground())
    }

    @ViewBuilder private func forwardListChatView(_ chat: Chat) -> some View {
        let prohibited = isProhibited?(chat) ?? chatItems.map { ci in
            chat.prohibitedByPref(
                hasPopopxLink: hasPopopxLink(ci.content.msgContent?.text),
                isMediaOrFileAttachment: ci.content.msgContent?.isMediaOrFileAttachment ?? false,
                isVoice: ci.content.msgContent?.isVoice ?? false
            )
        }.contains(true)

        Button {
            handleForwardSelection(chat: chat, prohibited: prohibited)
        } label: {
            forwardChatRowContent(chat: chat, prohibited: prohibited)
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .accessibilityLabel(Text(verbatim: PXChatItemForwardingConfig.a11yChatRow))
    }

    // MARK: - POPOPX row content extraction

    @ViewBuilder private func forwardChatRowContent(chat: Chat, prohibited: Bool) -> some View {
        HStack {
            ChatInfoImage(chat: chat, size: PXChatItemForwardingConfig.chatAvatarSize)
                .padding(.trailing, PXChatItemForwardingConfig.avatarTrailingPadding)
            Text(chat.chatInfo.chatViewName)
                .foregroundColor(prohibited ? theme.colors.secondary : theme.colors.onBackground)
                .lineLimit(PXChatItemForwardingConfig.listItemMaxLines)
            if chat.chatInfo.incognito {
                Spacer()
                Image(systemName: "theatermasks")
                    .resizable()
                    .scaledToFit()
                    .frame(width: PXChatItemForwardingConfig.incognitoMaskSize, height: PXChatItemForwardingConfig.incognitoMaskSize)
                    .foregroundColor(theme.colors.secondary)
                    .accessibilityLabel(Text(verbatim: PXChatItemForwardingConfig.a11yIncognito))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - POPOPX forwarding action handler

    private func handleForwardSelection(chat: Chat, prohibited: Bool) {
        if prohibited {
            alert = SomeAlert(
                alert: mkAlert(
                    title: LocalizedStringKey(NSLocalizedString("cannot_forward_message_title", comment: "Cannot forward message alert title")),
                    message: LocalizedStringKey(NSLocalizedString("cannot_forward_message_message", comment: "Cannot forward message alert message"))
                ),
                id: PXChatItemForwardingConfig.forwardProhibitedAlertId
            )
        } else if let onSelectChat {
            dismiss()
            onSelectChat(chat)
        } else if let fromChatInfo, let composeState {
            dismiss()
            if chat.id == fromChatInfo.id {
                composeState.wrappedValue = ComposeState(
                    message: composeState.wrappedValue.message,
                    preview: composeState.wrappedValue.linkPreview != nil ? composeState.wrappedValue.preview : .noPreview,
                    contextItem: .forwardingItems(chatItems: chatItems, fromChatInfo: fromChatInfo)
                )
            } else {
                composeState.wrappedValue = ComposeState.init(forwardingItems: chatItems, fromChatInfo: fromChatInfo)
                ItemsModel.shared.loadOpenChat(chat.id)
            }
        }
    }
}

#Preview {
    ChatItemForwardingView(
        chatItems: [ChatItem.getSample(1, .directSnd, .now, "hello")],
        fromChatInfo: .direct(contact: Contact.sampleData),
        composeState: Binding.constant(ComposeState(message: "hello"))
    ).environmentObject(CurrentColors.toAppTheme())
}

// MARK: - POPOPX
extension ChatItemForwardingView {
    /// Unique POPOPX component tag for forwarding view diffing
    var pxComponentTag: String { PXChatItemForwardingConfig.componentIdentifier }

    /// Whether the forwarding list has any searchable chats available
    var pxHasForwardableChats: Bool {
        !chatsToForwardTo.isEmpty
    }

    /// POPOPX-specific alert identifier for forward prohibition
    var pxForwardProhibitedAlertId: String { PXChatItemForwardingConfig.forwardProhibitedAlertId }

    /// POPOPX accessibility identifier for the forwarding toolbar
    var pxA11yToolbarId: String { PXChatItemForwardingConfig.a11yCancel }
}
