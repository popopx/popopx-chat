//
//  ChatListNavLink.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 01/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXChatListNavLinkConfig {
    static let progressTimeoutDelay: Double = 1.0
    static let sheetMaxFraction: CGFloat = 0.62
    static let tagSheetReservedRows: Int = 4
    static let tagSheetMinRows: Int = 3
    static let tagSheetRowHeight: CGFloat = 44
    static let hapticLightIntensity: UIImpactFeedbackGenerator.FeedbackStyle = .light
    static let hapticMediumIntensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    static let hapticHeavyIntensity: UIImpactFeedbackGenerator.FeedbackStyle = .heavy
}

// MARK: - POPOPX ViewModel
@MainActor
private struct PXChatListNavLinkVM {
    let chat: Chat

    var isGroupChat: Bool {
        if case .group = chat.chatInfo { return true }
        return false
    }

    var isDirectChat: Bool {
        if case .direct = chat.chatInfo { return true }
        return false
    }

    var isNoteFolder: Bool {
        if case .local = chat.chatInfo { return true }
        return false
    }

    var isContactRequest: Bool {
        if case .contactRequest = chat.chatInfo { return true }
        return false
    }

    var isContactConnection: Bool {
        if case .contactConnection = chat.chatInfo { return true }
        return false
    }

    var isMeshPeer: Bool {
        if case .meshPeer = chat.chatInfo { return true }
        return false
    }

    var isMeshGroup: Bool {
        if case .meshGroup = chat.chatInfo { return true }
        return false
    }

    var isInvalidJSON: Bool {
        if case .invalidJSON = chat.chatInfo { return true }
        return false
    }

    var hasUnreadMessages: Bool {
        chat.chatStats.unreadCount > 0 || chat.chatStats.unreadChat
    }

    var isFavorite: Bool {
        chat.chatInfo.chatSettings?.favorite == true
    }

    var hasChatItems: Bool {
        !chat.chatItems.isEmpty
    }

    var hasReports: Bool {
        chat.chatStats.reportsCount > 0
    }

    var isIncognito: Bool {
        chat.chatInfo.incognito
    }

    func tagSheetFraction(screenHeight: CGFloat, tagCount: Int) -> CGFloat {
        let reservedSpace = CGFloat(PXChatListNavLinkConfig.tagSheetReservedRows) * PXChatListNavLinkConfig.tagSheetRowHeight
        let tagsSpace = CGFloat(max(tagCount, PXChatListNavLinkConfig.tagSheetMinRows)) * PXChatListNavLinkConfig.tagSheetRowHeight
        return min((reservedSpace + tagsSpace) / screenHeight, PXChatListNavLinkConfig.sheetMaxFraction)
    }
}

// MARK: - Haptic Feedback Helper

private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

typealias DynamicSizes = (
    rowHeight: CGFloat,
    profileImageSize: CGFloat,
    mediaSize: CGFloat,
    incognitoSize: CGFloat,
    chatInfoSize: CGFloat,
    unreadCorner: CGFloat,
    unreadPadding: CGFloat
)

private let dynamicSizes: [DynamicTypeSize: DynamicSizes] = [
    .xSmall: (68, 55, 33, 22, 18, 9, 3),
    .small: (72, 57, 34, 22, 18, 9, 3),
    .medium: (76, 60, 36, 22, 18, 10, 4),
    .large: (80, 63, 38, 24, 20, 10, 4),
    .xLarge: (88, 67, 41, 24, 20, 10, 4),
    .xxLarge: (100, 71, 44, 27, 22, 11, 4),
    .xxxLarge: (110, 75, 48, 30, 24, 12, 5),
    .accessibility1: (110, 75, 48, 30, 24, 12, 5),
    .accessibility2: (114, 75, 48, 30, 24, 12, 5),
    .accessibility3: (124, 75, 48, 30, 24, 12, 5),
    .accessibility4: (134, 75, 48, 30, 24, 12, 5),
    .accessibility5: (144, 75, 48, 30, 24, 12, 5)
]

private let defaultDynamicSizes: DynamicSizes = dynamicSizes[.large] ?? (80, 63, 38, 24, 20, 10, 4)

func dynamicSize(_ font: DynamicTypeSize) -> DynamicSizes {
    dynamicSizes[font] ?? defaultDynamicSizes
}

// Spec: spec/client/chat-list.md#ChatListNavLink
struct ChatListNavLink: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var chatTagsModel: ChatTagsModel
    @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
    @AppStorage(GROUP_DEFAULT_ONE_HAND_UI, store: groupDefaults) private var oneHandUI = false
    @ObservedObject var chat: Chat
    @Binding var parentSheet: SomeSheet<AnyView>?
    @State private var showContactRequestDialog = false
    @State private var showJoinGroupDialog = false
    @State private var showContactConnectionInfo = false
    @State private var showInvalidJSON = false
    @State private var alert: SomeAlert? = nil
    @State private var actionSheet: SomeActionSheet? = nil
    @State private var sheet: SomeSheet<AnyView>? = nil
    @State private var showConnectContactViaAddressDialog = false
    @State private var inProgress = false
    @State private var progressByTimeout = false

    private var pxVM: PXChatListNavLinkVM {
        PXChatListNavLinkVM(chat: chat)
    }

    var dynamicRowHeight: CGFloat { dynamicSize(userFont).rowHeight }

    var body: some View {
        Group {
            switch chat.chatInfo {
            case let .direct(contact):
                contactNavLink(contact)
            case let .group(groupInfo, _):
                groupNavLink(groupInfo)
            case let .local(noteFolder):
                noteFolderNavLink(noteFolder)
            case let .contactRequest(cReq):
                contactRequestNavLink(cReq)
            case let .contactConnection(cConn):
                contactConnectionNavLink(cConn)
            case let .meshPeer(peer):
                meshPeerNavLink(peer)
            case let .meshGroup(groupIDHex, name, memberCount):
                meshGroupNavLink(groupIDHex: groupIDHex, name: name, memberCount: memberCount)
            case let .invalidJSON(json):
                invalidJSONPreview(json)
            }
        }
        .modifier(SwipeToPopModifier(chat: chat))
        .onChange(of: inProgress) {_,  inProgress in
            if inProgress {
                DispatchQueue.main.asyncAfter(deadline: .now() + PXChatListNavLinkConfig.progressTimeoutDelay) {
                    progressByTimeout = inProgress
                }
            } else {
                progressByTimeout = false
            }
        }
        .actionSheet(item: $actionSheet) { $0.actionSheet }
        .popopxBranded()
    }
    
    // Spec: spec/client/chat-list.md#contactNavLink
    private func contactNavLink(_ contact: Contact) -> some View {
        Group {
            if contact.isContactCard {
                PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false))
                    .frameCompat(height: dynamicRowHeight)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            deleteContactDialog(
                                chat,
                                contact,
                                dismissToChatList: false,
                                showAlert: { alert = $0 },
                                showActionSheet: { actionSheet = $0 },
                                showSheetContent: { sheet = $0 }
                            )
                        } label: {
                            deleteLabel
                        }
                        .tint(theme.colors.error)
                    }
                    .onTapGesture { showConnectContactViaAddressDialog = true }
                    .confirmationDialog(LocalizedStringKey(String(format: NSLocalizedString("chat_connect_with", comment: "Connect with %@"), contact.chatViewName)), isPresented: $showConnectContactViaAddressDialog, titleVisibility: .visible) {
                        Button(NSLocalizedString("chat_use_current_profile", comment: "Use current profile")) { connectContactViaAddress_(contact, false) }
                        Button(NSLocalizedString("chat_use_incognito_profile", comment: "Use new incognito profile")) { connectContactViaAddress_(contact, true) }
                    }
            } else {
                NavLinkPlain(
                    chatId: chat.chatInfo.id,
                    selection: $chatModel.chatId,
                    label: { PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false)) }
                )
                .frameCompat(height: dynamicRowHeight)
                .if(!contact.nextAcceptContactRequest) { v in
                    v.swipeActions(edge: .leading, allowsFullSwipe: true) {
                        markReadButton()
                        toggleFavoriteButton()
                        toggleNtfsButton(chat: chat)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if contact.nextAcceptContactRequest {
                        if let contactRequestId = contact.contactRequestId {
                            Button {
                                Task { await acceptContactRequest(incognito: false, contactRequestId: contactRequestId) }
                            } label: { SwipeLabel(NSLocalizedString("Accept", comment: "swipe action"), systemImage: "checkmark", inverted: oneHandUI) }
                                .tint(theme.colors.primary)
                            if !ChatModel.shared.addressShortLinkDataSet {
                                Button {
                                    Task { await acceptContactRequest(incognito: true, contactRequestId: contactRequestId) }
                                } label: {
                                    SwipeLabel(NSLocalizedString("Accept incognito", comment: "swipe action"), systemImage: "theatermasks.fill", inverted: oneHandUI)
                                }
                                .tint(QuantumColors.accent)
                            }
                            Button {
                                AlertManager.shared.showAlert(rejectContactRequestAlert(contactRequestId))
                            } label: {
                                SwipeLabel(NSLocalizedString("Reject", comment: "swipe action"), systemImage: "multiply", inverted: oneHandUI)
                            }
                            .tint(theme.colors.error)
                        } else if let groupDirectInv = contact.groupDirectInv, !groupDirectInv.memberRemoved {
                            Button {
                                acceptMemberContactRequest(contact)
                            } label: {
                                Label(NSLocalizedString("chat_accept", comment: "Accept"), systemImage: "checkmark")
                            }
                            .tint(theme.colors.primary)
                            Button {
                                showRejectMemberContactRequestAlert(contact)
                            } label: {
                                Label(NSLocalizedString("chat_reject", comment: "Reject"), systemImage: "multiply")
                            }
                            .tint(theme.colors.error)
                        } else {
                            Button {
                                deleteContactDialog(
                                    chat,
                                    contact,
                                    dismissToChatList: false,
                                    showAlert: { alert = $0 },
                                    showActionSheet: { actionSheet = $0 },
                                    showSheetContent: { sheet = $0 }
                                )
                            } label: {
                                deleteLabel
                            }
                            .tint(theme.colors.error)
                        }
                    } else {
                        tagChatButton(chat)
                        if !chat.chatItems.isEmpty {
                            clearChatButton()
                        }
                        Button {
                            deleteContactDialog(
                                chat,
                                contact,
                                dismissToChatList: false,
                                showAlert: { alert = $0 },
                                showActionSheet: { actionSheet = $0 },
                                showSheetContent: { sheet = $0 }
                            )
                        } label: {
                            deleteLabel
                        }
                        .tint(theme.colors.error)
                    }
                }
            }
        }
        .alert(item: $alert) { $0.alert }
        .sheet(item: $sheet) {
            $0.content
                .presentationDetents([.fraction($0.fraction)])
        }
    }

    // Spec: spec/client/chat-list.md#groupNavLink
    @ViewBuilder private func groupNavLink(_ groupInfo: GroupInfo) -> some View {
        switch (groupInfo.membership.memberStatus) {
        case .memInvited:
            PXChatPreview(chat: chat, progressByTimeout: $progressByTimeout)
                .frameCompat(height: dynamicRowHeight)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    joinGroupButton()
                    if groupInfo.canDelete {
                        deleteGroupChatButton(groupInfo)
                    }
                }
                .onTapGesture { showJoinGroupDialog = true }
                .confirmationDialog(LocalizedStringKey(NSLocalizedString("chat_group_invitation", comment: "Group invitation")), isPresented: $showJoinGroupDialog, titleVisibility: .visible) {
                    Button(chat.chatInfo.incognito ? NSLocalizedString("chat_join_incognito", comment: "Join incognito") : NSLocalizedString("chat_join_group", comment: "Join group")) {
                        inProgress = true
                        joinGroup(groupInfo.groupId) {
                            await MainActor.run { inProgress = false }
                        }
                    }
                    Button(NSLocalizedString("chat_delete_invitation", comment: "Delete invitation"), role: .destructive) { Task { await deleteChat(chat) } }
                }
                .disabled(inProgress)
        case .memAccepted:
            PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false))
                .frameCompat(height: dynamicRowHeight)
                .onTapGesture {
                    AlertManager.shared.showAlert(groupInvitationAcceptedAlert())
                }
                .swipeActions(edge: .trailing) {
                    tagChatButton(chat)
                    if groupInfo.membership.memberCurrentOrPending && !(groupInfo.useRelays && groupInfo.isOwner) {
                        leaveGroupChatButton(groupInfo)
                    }
                    if groupInfo.canDelete {
                        deleteGroupChatButton(groupInfo)
                    }
                }
        default:
            NavLinkPlain(
                chatId: chat.chatInfo.id,
                selection: $chatModel.chatId,
                label: { PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false)) },
                disabled: !groupInfo.ready
            )
            .frameCompat(height: dynamicRowHeight)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                markReadButton()
                toggleFavoriteButton()
                toggleNtfsButton(chat: chat)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                tagChatButton(chat)
                let showReportsButton = chat.chatStats.reportsCount > 0 && groupInfo.membership.memberRole >= .moderator
                let showClearButton = !chat.chatItems.isEmpty
                let showDeleteGroup = groupInfo.canDelete
                let showLeaveGroup = groupInfo.membership.memberCurrentOrPending && !(groupInfo.useRelays && groupInfo.isOwner)
                let totalNumberOfButtons = 1 + (showReportsButton ? 1 : 0) + (showClearButton ? 1 : 0) + (showDeleteGroup ? 1 : 0) + (showLeaveGroup ? 1 : 0)

                if showClearButton && totalNumberOfButtons <= 3 {
                    clearChatButton()
                }

                if showReportsButton && totalNumberOfButtons <= 3 {
                    archiveAllReportsButton()
                }

                if showLeaveGroup {
                    leaveGroupChatButton(groupInfo)
                }

                if showDeleteGroup && totalNumberOfButtons <= 3 {
                    deleteGroupChatButton(groupInfo)
                } else if totalNumberOfButtons > 3 {
                    if showDeleteGroup && !groupInfo.membership.memberActive {
                        deleteGroupChatButton(groupInfo)
                        moreOptionsButton(false, chat, groupInfo)
                    } else {
                        moreOptionsButton(true, chat, groupInfo)
                    }
                }
            }
        }
    }

    // Spec: spec/client/chat-list.md#noteFolderNavLink
    private func noteFolderNavLink(_ noteFolder: NoteFolder) -> some View {
        NavLinkPlain(
            chatId: chat.chatInfo.id,
            selection: $chatModel.chatId,
            label: { PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false)) },
            disabled: !noteFolder.ready
        )
        .frameCompat(height: dynamicRowHeight)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            markReadButton()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !chat.chatItems.isEmpty {
                clearNoteFolderButton()
            }
        }
    }

    private func joinGroupButton() -> some View {
        Button {
            inProgress = true
            joinGroup(chat.chatInfo.apiId) {
                await MainActor.run { inProgress = false }
            }
        } label: {
            SwipeLabel(NSLocalizedString("Join", comment: "swipe action"), systemImage: chat.chatInfo.incognito ? "theatermasks" : "ipad.and.arrow.forward", inverted: oneHandUI)
        }
        .tint(chat.chatInfo.incognito ? QuantumColors.accent : theme.colors.primary)
        .accessibilityLabel(Text(NSLocalizedString("Join", comment: "swipe action")))
    }

    // Spec: spec/client/chat-list.md#markReadButton
    @ViewBuilder private func markReadButton() -> some View {
        if pxVM.hasUnreadMessages {
            Button {
                Task { await markChatRead(ItemsModel.shared, chat) }
            } label: {
                SwipeLabel(NSLocalizedString("Read", comment: "swipe action"), systemImage: "checkmark", inverted: oneHandUI)
            }
            .tint(theme.colors.primary)
        } else {
            Button {
                Task { await markChatUnread(chat) }
            } label: {
                SwipeLabel(NSLocalizedString("Unread", comment: "swipe action"), systemImage: "circlebadge.fill", inverted: oneHandUI)
            }
            .tint(theme.colors.primary)
        }

    }

    // Spec: spec/client/chat-list.md#toggleFavoriteButton
    @ViewBuilder private func toggleFavoriteButton() -> some View {
        if pxVM.isFavorite {
            Button {
                triggerHapticFeedback(PXChatListNavLinkConfig.hapticLightIntensity)
                toggleChatFavorite(chat, favorite: false)
            } label: {
                SwipeLabel(NSLocalizedString("Unfav.", comment: "swipe action"), systemImage: "star.slash.fill", inverted: oneHandUI)
            }
            .tint(QuantumColors.success)
        } else {
            Button {
                triggerHapticFeedback(PXChatListNavLinkConfig.hapticLightIntensity)
                toggleChatFavorite(chat, favorite: true)
            } label: {
                SwipeLabel(NSLocalizedString("Favorite", comment: "swipe action"), systemImage: "star.fill", inverted: oneHandUI)
            }
            .tint(QuantumColors.success)
        }
    }

    // Spec: spec/client/chat-list.md#toggleNtfsButton
    @ViewBuilder private func toggleNtfsButton(chat: Chat) -> some View {
        if let nextMode = chat.chatInfo.nextNtfMode {
            Button {
                toggleNotifications(chat, enableNtfs: nextMode)
            } label: {
                SwipeLabel(nextMode.text(mentions: chat.chatInfo.hasMentions), systemImage: nextMode.iconFilled, inverted: oneHandUI)
            }
        } else {
            EmptyView()
        }
    }

    private func archiveAllReportsButton() -> some View {
        Button {
            AlertManager.shared.showAlert(archiveAllReportsAlert())
        } label: {
            SwipeLabel(NSLocalizedString("Archive reports", comment: "swipe action"), systemImage: "archivebox", inverted: oneHandUI)
        }
    }

    // Spec: spec/client/chat-list.md#clearChatButton
    private func clearChatButton() -> some View {
        Button {
            triggerHapticFeedback(PXChatListNavLinkConfig.hapticHeavyIntensity)
            AlertManager.shared.showAlert(clearChatAlert())
        } label: {
            SwipeLabel(NSLocalizedString("Clear", comment: "swipe action"), systemImage: "gobackward", inverted: oneHandUI)
        }
        .tint(QuantumColors.warning)
    }

    private func tagChatButton(_ chat: Chat) -> some View {
        Button {
            triggerHapticFeedback(PXChatListNavLinkConfig.hapticLightIntensity)
            setTagChatSheet(chat)
        } label: {
            SwipeLabel(NSLocalizedString("List", comment: "swipe action"), systemImage: "tag.fill", inverted: oneHandUI)
        }
        .tint(QuantumColors.success)
    }
    
    private func setTagChatSheet(_ chat: Chat) {
        let screenHeight = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.bounds.height) ?? 800
        let fraction = PXChatListNavLinkVM(chat: chat).tagSheetFraction(screenHeight: screenHeight, tagCount: chatTagsModel.userTags.count)
        
        parentSheet = SomeSheet(
            content: {
                AnyView(
                    NavigationStack {
                        if chatTagsModel.userTags.isEmpty {
                            TagListEditor(chat: chat)
                        } else {
                            PXTagFilterList(chat: chat)
                        }
                    }
                )
            },
            id: "lists sheet",
            fraction: fraction
        )
    }
    
    private func moreOptionsButton(_ canShowGroupDelete: Bool, _ chat: Chat, _ groupInfo: GroupInfo?) -> some View {
        Button {
            var buttons: [Alert.Button] = []
            buttons.append(.default(Text(LocalizedStringKey(NSLocalizedString("chat_clear", comment: "Clear")))) {
                AlertManager.shared.showAlert(clearChatAlert())
            })

            if let groupInfo, chat.chatStats.reportsCount > 0 && groupInfo.membership.memberRole >= .moderator && groupInfo.ready {
                buttons.append(.default(Text(LocalizedStringKey(NSLocalizedString("chat_archive_reports", comment: "Archive reports")))) {
                    AlertManager.shared.showAlert(archiveAllReportsAlert())
                })
            }

            if canShowGroupDelete, let gi = groupInfo, gi.canDelete {
                buttons.append(.destructive(Text(LocalizedStringKey(NSLocalizedString("chat_delete", comment: "Delete")))) {
                    AlertManager.shared.showAlert(deleteGroupAlert(gi))
                })
            }
            
            buttons.append(.cancel())
                               
            actionSheet = SomeActionSheet(
                actionSheet: ActionSheet(
                    title: canShowGroupDelete ? Text(LocalizedStringKey(NSLocalizedString("chat_clear_or_delete_group", comment: "Clear or delete group?"))) : Text(LocalizedStringKey(NSLocalizedString("chat_clear_group", comment: "Clear group?"))),
                    buttons: buttons
                ),
                id: "other options"
            )
        } label: {
            SwipeLabel(NSLocalizedString("More", comment: "swipe action"), systemImage: "ellipsis", inverted: oneHandUI)
        }
    }
    
    private func clearNoteFolderButton() -> some View {
        Button {
            AlertManager.shared.showAlert(clearNoteFolderAlert())
        } label: {
            SwipeLabel(NSLocalizedString("Clear", comment: "swipe action"), systemImage: "gobackward", inverted: oneHandUI)
        }
        .tint(QuantumColors.warning)
    }

    private func leaveGroupChatButton(_ groupInfo: GroupInfo) -> some View {
        Button {
            AlertManager.shared.showAlert(leaveGroupAlert(groupInfo))
        } label: {
            SwipeLabel(NSLocalizedString("Leave", comment: "swipe action"), systemImage: "rectangle.portrait.and.arrow.right.fill", inverted: oneHandUI)
        }
        .tint(QuantumColors.warning)
    }

    private func deleteGroupChatButton(_ groupInfo: GroupInfo) -> some View {
        Button {
            AlertManager.shared.showAlert(deleteGroupAlert(groupInfo))
        } label: {
            deleteLabel
        }
        .tint(theme.colors.error)
    }

    // Spec: spec/client/chat-list.md#contactRequestNavLink
    private func contactRequestNavLink(_ contactRequest: UserContactRequest) -> some View {
        ContactRequestView(contactRequest: contactRequest, chat: chat)
        .frameCompat(height: dynamicRowHeight)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                triggerHapticFeedback(PXChatListNavLinkConfig.hapticMediumIntensity)
                Task { await acceptContactRequest(incognito: false, contactRequestId: contactRequest.apiId) }
            } label: { SwipeLabel(NSLocalizedString("Accept", comment: "swipe action"), systemImage: "checkmark", inverted: oneHandUI) }
                .tint(theme.colors.primary)
            if !ChatModel.shared.addressShortLinkDataSet {
                Button {
                    triggerHapticFeedback(PXChatListNavLinkConfig.hapticMediumIntensity)
                    Task { await acceptContactRequest(incognito: true, contactRequestId: contactRequest.apiId) }
                } label: {
                    SwipeLabel(NSLocalizedString("Accept incognito", comment: "swipe action"), systemImage: "theatermasks.fill", inverted: oneHandUI)
                }
                .tint(QuantumColors.accent)
            }
            Button {
                triggerHapticFeedback(PXChatListNavLinkConfig.hapticHeavyIntensity)
                AlertManager.shared.showAlert(rejectContactRequestAlert(contactRequest.apiId))
            } label: {
                SwipeLabel(NSLocalizedString("Reject", comment: "swipe action"), systemImage: "multiply", inverted: oneHandUI)
            }
            .tint(theme.colors.error)
        }
        .contentShape(Rectangle())
        .onTapGesture { showContactRequestDialog = true }
        .confirmationDialog(LocalizedStringKey(NSLocalizedString("chat_accept_connection_request", comment: "Accept connection request?")), isPresented: $showContactRequestDialog, titleVisibility: .visible) {
            Button(NSLocalizedString("chat_accept", comment: "Accept")) { Task { await acceptContactRequest(incognito: false, contactRequestId: contactRequest.apiId) } }
            if !ChatModel.shared.addressShortLinkDataSet {
                Button(NSLocalizedString("chat_accept_incognito", comment: "Accept incognito")) { Task { await acceptContactRequest(incognito: true, contactRequestId: contactRequest.apiId) } }
            }
            Button(NSLocalizedString("chat_reject_sender_not_notified", comment: "Reject (sender NOT notified)"), role: .destructive) { Task { await rejectContactRequest(contactRequest.apiId) } }
        }
    }

    // Spec: spec/client/chat-list.md#contactConnectionNavLink
    private func contactConnectionNavLink(_ contactConnection: PendingContactConnection) -> some View {
        ContactConnectionView(chat: chat)
        .frameCompat(height: dynamicRowHeight)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                AlertManager.shared.showAlert(deleteContactConnectionAlert(contactConnection) { a in
                    AlertManager.shared.showAlertMsg(title: a.title, message: a.message)
                })
            } label: {
                deleteLabel
            }
            .tint(theme.colors.error)

            Button {
                showContactConnectionInfo = true
            } label: {
                SwipeLabel(NSLocalizedString("Name", comment: "swipe action"), systemImage: "pencil", inverted: oneHandUI)
            }
            .tint(theme.colors.primary)
        }
        .appSheet(isPresented: $showContactConnectionInfo) {
            if case let .contactConnection(contactConnection) = chat.chatInfo {
                ContactConnectionInfo(contactConnection: contactConnection)
                    .modifier(ThemedBackground(grouped: true))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showContactConnectionInfo = true
        }
    }

    private func meshPeerNavLink(_ peer: MeshPeerContact) -> some View {
        PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false))
            .frameCompat(height: dynamicRowHeight)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    triggerHapticFeedback(PXChatListNavLinkConfig.hapticMediumIntensity)
                    Task { await deleteChat(chat) }
                } label: {
                    deleteLabel
                }
                .tint(theme.colors.error)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                triggerHapticFeedback(PXChatListNavLinkConfig.hapticLightIntensity)
                chatModel.chatId = peer.id
                chatModel.meshBridge?.loadMeshConversation(peerID: peer.peerIDHex)
            }
    }

    private func meshGroupNavLink(groupIDHex: String, name: String, memberCount: Int) -> some View {
        PXChatPreview(chat: chat, progressByTimeout: Binding.constant(false))
            .frameCompat(height: dynamicRowHeight)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    triggerHapticFeedback(PXChatListNavLinkConfig.hapticMediumIntensity)
                    Task { await deleteChat(chat) }
                } label: {
                    deleteLabel
                }
                .tint(theme.colors.error)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                triggerHapticFeedback(PXChatListNavLinkConfig.hapticLightIntensity)
                chatModel.chatId = "meshgroup:\(groupIDHex)"
                chatModel.meshBridge?.loadMeshGroupConversation(groupIDHex: groupIDHex)
            }
    }

    private var deleteLabel: some View {
        SwipeLabel(NSLocalizedString("Delete", comment: "swipe action"), systemImage: "trash.fill", inverted: oneHandUI)
    }

    private func deleteGroupAlert(_ groupInfo: GroupInfo) -> Alert {
        let label: LocalizedStringKey = groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("chat_delete_channel_confirm", comment: "Delete channel?")) : groupInfo.businessChat == nil ? LocalizedStringKey(NSLocalizedString("chat_delete_group_confirm", comment: "Delete group?")) : LocalizedStringKey(NSLocalizedString("chat_delete_chat_confirm", comment: "Delete chat?"))
        return Alert(
            title: Text(label),
            message: Text(deleteGroupAlertMessage(groupInfo)),
            primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_delete", comment: "Delete")))) {
                Task { await deleteChat(chat) }
            },
            secondaryButton: .cancel()
        )
    }

    private func archiveAllReportsAlert() -> Alert {
        Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("chat_archive_all_reports", comment: "Archive all reports?"))),
            message: Text(LocalizedStringKey(NSLocalizedString("chat_archive_all_reports_msg", comment: "All reports will be archived for you."))),
            primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_archive", comment: "Archive")))) {
                Task { await archiveAllReportsForMe(chat.chatInfo.apiId) }
            },
            secondaryButton: .cancel()
        )
    }

    private func archiveAllReportsForMe(_ apiId: Int64) async {
        do {
            if case let .groupChatItemsDeleted(user, groupInfo, chatItemIDs, _, member) = try await apiArchiveReceivedReports(groupId: apiId) {
                await groupChatItemsDeleted(user, groupInfo, chatItemIDs, member)
            }
        } catch {
            logger.error("archiveAllReportsForMe error: \(responseError(error))")
        }
    }

    private func clearChatAlert() -> Alert {
        Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("chat_clear_conversation", comment: "Clear conversation?"))),
            message: Text(LocalizedStringKey(NSLocalizedString("chat_clear_conversation_msg", comment: "All messages will be deleted..."))),
            primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_clear", comment: "Clear")))) {
                Task { await clearChat(chat) }
            },
            secondaryButton: .cancel()
        )
    }

    private func clearNoteFolderAlert() -> Alert {
        Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("chat_clear_private_notes", comment: "Clear private notes?"))),
            message: Text(LocalizedStringKey(NSLocalizedString("chat_clear_private_notes_msg", comment: "All messages will be deleted..."))),
            primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_clear", comment: "Clear")))) {
                Task { await clearChat(chat) }
            },
            secondaryButton: .cancel()
        )
    }

    private func leaveGroupAlert(_ groupInfo: GroupInfo) -> Alert {
        let titleLabel: LocalizedStringKey = groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("chat_leave_channel", comment: "Leave channel?")) : groupInfo.businessChat == nil ? LocalizedStringKey(NSLocalizedString("chat_leave_group", comment: "Leave group?")) : LocalizedStringKey(NSLocalizedString("chat_leave_chat", comment: "Leave chat?"))
        let messageLabel: LocalizedStringKey = (
            groupInfo.useRelays
            ? LocalizedStringKey(NSLocalizedString("chat_leave_channel_msg", comment: "You will stop receiving messages from this channel..."))
            : groupInfo.businessChat == nil
            ? LocalizedStringKey(NSLocalizedString("chat_leave_group_msg", comment: "You will stop receiving messages from this group..."))
            : LocalizedStringKey(NSLocalizedString("chat_leave_chat_msg", comment: "You will stop receiving messages from this chat..."))
        )
        return Alert(
            title: Text(titleLabel),
            message: Text(messageLabel),
            primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_leave", comment: "Leave")))) {
                Task { await leaveGroup(groupInfo.groupId) }
            },
            secondaryButton: .cancel()
        )
    }

    private func groupInvitationAcceptedAlert() -> Alert {
        Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("chat_joining_group", comment: "Joining group"))),
            message: Text(LocalizedStringKey(NSLocalizedString("chat_joined_group_msg", comment: "You joined this group. Connecting to inviting group member.")))
        )
    }

    private func invalidJSONPreview(_ json: Data?) -> some View {
        Text(NSLocalizedString("chat_invalid_data", comment: "invalid chat data"))
            .foregroundColor(theme.colors.error)
            .padding(4)
            .frameCompat(height: dynamicRowHeight)
            .onTapGesture { showInvalidJSON = true }
            .appSheet(isPresented: $showInvalidJSON) {
                invalidJSONView(dataToString(json))
            }
    }

    private func connectContactViaAddress_(_ contact: Contact, _ incognito: Bool) {
        Task {
            let ok = await connectContactViaAddress(contact.contactId, incognito)
            if ok {
                ItemsModel.shared.loadOpenChat(contact.id) {
                    AlertManager.shared.showAlert(connReqSentAlert(.contact))
                }
            }
        }
    }
}

extension View {
    @inline(__always)
    @ViewBuilder fileprivate func frameCompat(height: CGFloat) -> some View {
        self.frame(height: height)
    }
}

func rejectContactRequestAlert(_ contactRequestId: Int64) -> Alert {
    Alert(
        title: Text(LocalizedStringKey(NSLocalizedString("chat_reject_contact_request", comment: "Reject contact request"))),
        message: Text(LocalizedStringKey(NSLocalizedString("chat_sender_not_notified", comment: "The sender will NOT be notified"))),
        primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_reject", comment: "Reject")))) {
            Task { await rejectContactRequest(contactRequestId) }
        },
        secondaryButton: .cancel()
    )
}

func deleteContactConnectionAlert(_ contactConnection: PendingContactConnection, showError: @escaping (ErrorAlert) -> Void, success: @escaping () -> Void = {}) -> Alert {
    Alert(
        title: Text(LocalizedStringKey(NSLocalizedString("chat_delete_pending_connection", comment: "Delete pending connection?"))),
        message:
            contactConnection.initiated
            ? Text(LocalizedStringKey(NSLocalizedString("chat_delete_connection_initiated_msg", comment: "The contact you shared this link with will NOT be able to connect!")))
            : Text(LocalizedStringKey(NSLocalizedString("chat_delete_connection_not_initiated_msg", comment: "The connection you accepted will be cancelled!"))),
        primaryButton: .destructive(Text(LocalizedStringKey(NSLocalizedString("chat_delete", comment: "Delete")))) {
            Task {
                do {
                    try await apiDeleteChat(type: .contactConnection, id: contactConnection.apiId)
                    await MainActor.run {
                        ChatModel.shared.removeChat(contactConnection.id)
                        success()
                    }
                } catch let error {
                    await MainActor.run {
                        showError(getErrorAlert(error, LocalizedStringKey(NSLocalizedString("chat_error_deleting_connection", comment: "Error deleting connection"))))
                    }
                }
            }
        },
        secondaryButton: .cancel()
    )
}

@MainActor
func connectContactViaAddress(_ contactId: Int64, _ incognito: Bool) async -> Bool {
    let (contact, alert) = await apiConnectContactViaAddress(incognito: incognito, contactId: contactId)
    if let alert = alert {
        AlertManager.shared.showAlert(alert)
        return false
    } else if let contact = contact {
        ChatModel.shared.updateContact(contact)
        return true
    }
    return false
}

func joinGroup(_ groupId: Int64, _ onComplete: @escaping () async -> Void) {
    Task {
        logger.debug("joinGroup")
        do {
            if let r = try await apiJoinGroup(groupId) {
                switch r {
                case let .joined(groupInfo):
                    await MainActor.run { ChatModel.shared.updateGroup(groupInfo) }
                case .invitationRemoved:
                    await MainActor.run { AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("chat_invitation_expired", comment: "alert title")), message: LocalizedStringKey(NSLocalizedString("chat_invitation_no_longer_valid", comment: "alert message"))) }
                    await deleteGroup()
                case .groupNotFound:
                    await MainActor.run { AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("chat_no_group", comment: "alert title")), message: LocalizedStringKey(NSLocalizedString("chat_group_no_longer_exists", comment: "alert message"))) }
                    await deleteGroup()
                }
            }
            await onComplete()
        } catch let error {
            await onComplete()
            let a = getErrorAlert(error, LocalizedStringKey(NSLocalizedString("chat_error_joining_group", comment: "alert title")))
            await MainActor.run { AlertManager.shared.showAlertMsg(title: a.title, message: a.message) }
        }

        func deleteGroup() async {
            do {
                // TODO [BLOCKED: requires upstream API to return invitation chat item in delete group response]
                try await apiDeleteChat(type: .group, id: groupId)
                await MainActor.run { ChatModel.shared.removeChat("#\(groupId)") }
            } catch {
                logger.error("apiDeleteChat error: \(responseError(error))")
            }
        }
    }
}

func getErrorAlert(_ error: Error, _ title: LocalizedStringKey) -> ErrorAlert {
    if let r = error as? ChatError,
       let alert = getNetworkErrorAlert(r) {
        let message = alert.message.map { LocalizedStringKey($0) }
        return ErrorAlert(title: LocalizedStringKey(alert.title), message: message)
    } else {
        return ErrorAlert(title: title, message: LocalizedStringKey(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 82)) {
    struct PreviewWrapper: View {
        @State var chatId: String? = "@1"
        var body: some View {
            Group {
                ChatListNavLink(chat: Chat(
                    chatInfo: ChatInfo.sampleData.direct,
                    chatItems: [ChatItem.getSample(1, .directSnd, .now, "hello")]
                ), parentSheet: .constant(nil))
                ChatListNavLink(chat: Chat(
                    chatInfo: ChatInfo.sampleData.direct,
                    chatItems: [ChatItem.getSample(1, .directSnd, .now, "hello")]
                ), parentSheet: .constant(nil))
                ChatListNavLink(chat: Chat(
                    chatInfo: ChatInfo.sampleData.contactRequest,
                    chatItems: []
                ), parentSheet: .constant(nil))
            }
        }
    }
    return PreviewWrapper()
}

// MARK: - POPOPX
extension ChatListNavLink {
    var pxComponentTag: String { "px-chat-list-nav-link" }
    var pxSwipeActionTag: String { "px-swipe-action" }
    var pxHasUnread: Bool { pxVM.hasUnreadMessages }
}
