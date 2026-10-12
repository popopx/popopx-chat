//
//  ChatView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import SwiftyGif
import Combine

// MARK: - Haptic Feedback Helper

/// POPOPX: triggers a haptic impact for tactile UI feedback
private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred(intensity: 1.0)
}

/// POPOPX: standard member avatar size in chat toolbar
let memberImageSize: CGFloat = 34

// Spec: spec/client/chat-view.md#ChatView
struct ChatView: View {
    @State var revealedItems: Set<Int64> = Set()
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject private var connectProgressManager = ConnectProgressManager.shared
    @ObservedObject var chat: Chat
    @ObservedObject var im: ItemsModel
    @State var mergedItems: BoxedValue<MergedItems>
    @ObservedObject var floatingButtonModel: FloatingButtonModel
    @Binding var scrollToItemId: ChatItem.ID?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showChatInfoSheet: Bool = false
    @State private var showAddMembersSheet: Bool = false
    @State private var composeState = ComposeState()
    @State private var selectedRange = NSRange()
    @State private var keyboardVisible = false
    @State private var keyboardHiddenDate = Date.now
    @State private var connectionStats: ConnectionStats?
    @State private var customUserProfile: Profile?
    @State private var connectionCode: String?
    @State private var loadingMoreItems = false
    @State private var loadingTopItems = false
    @State private var requestedTopScroll = false
    @State private var loadingBottomItems = false
    @State private var requestedBottomScroll = false
    @State private var showSearch = false
    @State private var searchText: String = ""
    @FocusState private var searchFocussed
    @State private var contentFilter: ContentFilter? = nil
    @State private var availableContent: [ContentFilter] = [.images, .files, .links]
    // opening PXGroupMemberDetail on member icon
    @State private var selectedMember: GMember? = nil
    // opening PXGroupLinkEditor on link button (incognito)
    @State private var showGroupLinkSheet: Bool = false
    @State private var groupLink: GroupLink?
    @State private var groupLinkMemberRole: GroupMemberRole = .member
    @State private var forwardedChatItems: [ChatItem] = []
    @State private var selectedChatItems: Set<Int64>? = nil
    @State private var showDeleteSelectedMessages: Bool = false
    @State private var showArchiveSelectedReports: Bool = false
    @State private var allowToDeleteSelectedMessagesForAll: Bool = false
    @State private var allowLoadMoreItems: Bool = false
    @State private var ignoreLoadingRequests: Int64? = nil
    @State private var animatedScrollingInProgress: Bool = false
    @State private var pendingCleanup: DispatchWorkItem? = nil
    @State private var allowLoadMoreWorkItem: DispatchWorkItem? = nil
    @State private var showUserSupportChatSheet = false
    @State private var showCommandsMenu = false
    @State private var supportChatMemberInfoLinkActive = false
    @State private var scrollView: PXScrollEngine<MergedItem> = PXScrollEngine(frame: .zero)
    @State private var showExtractionsSheet = false
    @State private var chatExtractions: [Extraction] = []
    @State private var pxBubbleFlyUps: [PXBubbleFlyUp] = []
    @State private var pxLastSentItemId: Int64? = nil
    @State private var pxAvailableWidth: CGFloat = 0 // POPOPX: replaces outer GeometryReader

    @AppStorage(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial

    let userSupportScopeInfo: GroupChatScopeInfo = .memberSupport(groupMember_: nil)

    // Spec: spec/client/chat-view.md#body
    var body: some View {
        buildBody()
            .scrollDismissesKeyboard(.immediately)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func buildBody() -> some View {
        let cInfo = chat.chatInfo
        let memberSupportChat: (groupInfo: GroupInfo, member: GroupMember?)? =
                if case let .group(groupInfo, .memberSupport(member)) = cInfo {
                    (groupInfo, member)
                } else {
                    nil
                }
        let userMemberKnockingChat = memberSupportChat?.groupInfo.membership.memberPending == true
        return buildCoreContent(userMemberKnockingChat: userMemberKnockingChat)
        .safeAreaInset(edge: .top) {
            VStack(spacing: .zero) {
                if showSearch { searchToolbar() }
                GlassDivider()
            }
            .background(
                ZStack {
                    Color.clear
                    if isInDarkTheme() {
                        LinearGradient(
                            colors: [
                                darkThemeAccentColor().opacity(0.08),
                                neonGradientSecondary().opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            )
            .overlay(alignment: .bottom) {
                if isInDarkTheme() {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    darkThemeAccentColor().opacity(0.4),
                                    neonGradientSecondary().opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.75)
                }
            }
        }
        .toolbarBackground(Color(hex: "#0D0D11").opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(
            memberSupportChat == nil
            ? cInfo.chatViewName
            : memberSupportChat?.member?.chatViewName ?? NSLocalizedString("Chat with admins", comment: "chat toolbar")
        )
        .background(
            chatViewBackground
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(theme)
        .confirmationDialog(selectedChatItems?.count == 1 ? NSLocalizedString("delete_message_title", comment: "delete single message confirmation title") : String(format: NSLocalizedString("delete_messages_title", comment: "delete multiple messages confirmation title"), selectedChatItems?.count ?? 0), isPresented: $showDeleteSelectedMessages, titleVisibility: .visible) {
            Button(NSLocalizedString("Delete for me", comment: "delete message button"), role: .destructive) {
                if let selected = selectedChatItems {
                    deleteMessages(chat, selected.sorted(), .cidmInternal, moderate: false, deletedSelectedMessages)
                }
            }
            if allowToDeleteSelectedMessagesForAll {
                Button(broadcastDeleteButtonText(chat), role: .destructive) {
                    if let selected = selectedChatItems {
                        allowToDeleteSelectedMessagesForAll = false
                        deleteMessages(chat, selected.sorted(), .cidmBroadcast, moderate: false, deletedSelectedMessages)
                    }
                }
            }
        }
        .confirmationDialog(selectedChatItems?.count == 1 ? NSLocalizedString("archive_report_title", comment: "archive single report confirmation title") : String(format: NSLocalizedString("archive_reports_title", comment: "archive multiple reports confirmation title"), selectedChatItems?.count ?? 0), isPresented: $showArchiveSelectedReports, titleVisibility: .visible) {
            Button(NSLocalizedString("For me", comment: "archive reports button"), role: .destructive) {
                if let selected = selectedChatItems {
                    archiveReports(chat, selected.sorted(), false, deletedSelectedMessages)
                }
            }
            if case let ChatInfo.group(groupInfo, _) = chat.chatInfo, groupInfo.membership.memberActive {
                Button(NSLocalizedString("For all moderators", comment: "archive reports button"), role: .destructive) {
                    if let selected = selectedChatItems {
                        archiveReports(chat, selected.sorted(), true, deletedSelectedMessages)
                    }
                }
            }
        }
        .appSheet(item: $selectedMember, onDismiss: {
            chatModel.secondaryIM = nil
        }) { member in
            if case let .group(groupInfo, _) = chat.chatInfo {
                PXGroupMemberDetail(
                    groupInfo: groupInfo,
                    chat: chat,
                    groupMember: member,
                    scrollToItemId: $scrollToItemId,
                    navigation: true
                )
            }
        }
        // it should be presented on top level in order to prevent a bug in SwiftUI on iOS 16 related to .focused() modifier in PXAddGroupMembers's search field
        .appSheet(isPresented: $showAddMembersSheet) {
            if case let .group(groupInfo, _) = cInfo {
                PXAddGroupMembers(chat: chat, groupInfo: groupInfo)
            }
        }
        .appSheet(isPresented: $showGroupLinkSheet) {
            if case let .group(groupInfo, _) = cInfo {
                PXGroupLinkEditor(
                    groupId: groupInfo.groupId,
                    groupLink: $groupLink,
                    groupLinkMemberRole: $groupLinkMemberRole,
                    showTitle: true,
                    creatingGroup: false,
                    isChannel: groupInfo.useRelays,
                    groupInfo: groupInfo,
                    composeState: $composeState
                )
            }
        }
        .appSheet(isPresented: $showExtractionsSheet) {
            NavigationStack {
                ExtractionListView(chatId: chat.chatInfo.id)
                    .environmentObject(theme)
                    .modifier(ThemedBackground(grouped: true, glass: true))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .needleExtractionCompleted)) { _ in
            let extractions = LocalExtractionStore.shared.fetchByChatId(chat.chatInfo.id)
            if !extractions.isEmpty {
                chatExtractions = extractions
                showExtractionsSheet = true
            }
        }
        .sheet(isPresented: Binding(
            get: { !forwardedChatItems.isEmpty },
            set: { isPresented in
                if !isPresented {
                    forwardedChatItems = []
                    selectedChatItems = nil
                }
            }
        )) {
            ChatItemForwardingView(chatItems: forwardedChatItems, fromChatInfo: chat.chatInfo, composeState: $composeState)
                .presentationDetents([.fraction(0.8)])
        }
        .appSheet(
            isPresented: $showUserSupportChatSheet,
            onDismiss: {
                if chat.chatInfo.groupInfo?.membership.memberPending ?? false {
                    chatModel.chatId = nil
                }
            }
        ) {
            if let groupInfo = cInfo.groupInfo {
                SecondaryChatView(
                    chat: Chat(chatInfo: .group(groupInfo: groupInfo, groupChatScope: userSupportScopeInfo), chatItems: [], chatStats: ChatStats()),
                    scrollToItemId: $scrollToItemId
                )
            }
        }
        .onAppear {
            // Cancel any pending cleanup when view reappears (e.g., after dismissing a sheet)
            pendingCleanup?.cancel()
            pendingCleanup = nil
            allowLoadMoreWorkItem?.cancel()
            allowLoadMoreWorkItem = nil

            ConnectProgressManager.shared.cancelConnectProgress()
            scrollView.listState.onUpdateListener = onChatItemsUpdated
            selectedChatItems = nil
            revealedItems = Set()
            initChatView()
            // POPOPX: if cleanup already ran (reversedChatItems cleared), reload chat data
            if im.reversedChatItems.isEmpty {
                Task {
                    await loadChat(chat: chat, im: im, clearItems: true)
                }
            }
            // if this is the main chat of the group with the pending member (knocking)
            if case let .group(groupInfo, nil) = chat.chatInfo,
               groupInfo.membership.memberPending {
                ItemsModel.loadSecondaryChat(chat.id, chatFilter: .groupChatScopeContext(groupScopeInfo: userSupportScopeInfo)) {
                    showUserSupportChatSheet = true
                    chatModel.secondaryPendingInviteeChatOpened = true
                }
            }
        }
        .task {
            if im.isLoading {
                try? await Task.sleep(nanoseconds: 500_000000)
                await MainActor.run {
                    if im.isLoading {
                        im.showLoadingProgress = chat.id
                    }
                }
            }
        }
        .onChange(of: chatModel.secondaryPendingInviteeChatOpened) { _, secondaryChatOpened in
            handleSecondaryChatChange(secondaryChatOpened)
        }
        .onChange(of: chatModel.chatId) { _, cId in
            handleChatIdChange(cId)
        }
        .onChange(of: chatModel.openAroundItemId) { _, openAround in
            handleOpenAroundChange(openAround)
        }
        .onDisappear {
            handleOnDisappear(cInfo: cInfo)
        }
        .onChange(of: colorScheme) {_, _ in
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if chatModel.meshTransportEnabled {
                    MeshStatusIndicator(
                        currentTransport: chatModel.currentTransportID,
                        isConnected: chatModel.currentTransportID == "bluetooth"
                            ? !chatModel.nearbyMeshPeers.filter({ $0.isConnected }).isEmpty
                            : chatModel.networkInfo.online
                    )
                }
            }
            ToolbarItem(placement: .principal) {
                if im.secondaryIMFilter == nil {
                    primaryPrincipalToolbarContent()
                } else if !userMemberKnockingChat { // no toolbar while knocking chat, it's unstable on sheet
                    secondaryPrincipalToolbarContent()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if im.secondaryIMFilter == nil {
                    primaryTrailingToolbarContent()
                } else if !userMemberKnockingChat {
                    secondaryTrailingToolbarContent()
                }
            }
        }
        .if(im.secondaryIMFilter == nil) { v in
            v.onChange(of: scrollToItemId) {_,  itemId in
                if let itemId = itemId {
                    dismissAllSheets(animated: false) {
                        scrollToItem(itemId)
                        scrollToItemId = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func buildCoreContent(userMemberKnockingChat: Bool) -> some View {
        ZStack {
            AnyView(buildWallpaperLayer())
            AnyView(buildMainVStack(userMemberKnockingChat: userMemberKnockingChat))
            if im.showLoadingProgress == chat.id {
                // BrandedProgressView.swift is not yet in the Xcode project; using a scaled ProgressView as placeholder.
                AnyView(ProgressView().scaleEffect(1.5))
            }
            if case let .group(groupInfo, _) = chat.chatInfo,
               case let .groupChatScopeContext(groupScopeInfo) = im.secondaryIMFilter,
               case let .memberSupport(groupMember_) = groupScopeInfo,
               let groupMember = groupMember_ {
                AnyView(supportChatMemberDestination(groupInfo: groupInfo, groupMember: groupMember))
            }
            // Bubble fly-up animation (sent messages)
            ZStack(alignment: .bottom) {
                ForEach(pxBubbleFlyUps) { flyUp in
                    PXBubbleFlyUpView(text: flyUp.text)
                }
            }
            .allowsHitTesting(false)
            // 3D Robot avatar (Needle AI indicator)
            NeedlePinView()
                .allowsHitTesting(false)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    TouchRepulsionService.shared.update(location: value.location)
                }
                .onEnded { _ in
                    TouchRepulsionService.shared.end()
                }
        )
    }

    @ViewBuilder
    private func buildWallpaperLayer() -> some View {
        let wallpaperImage = theme.wallpaper.type.image
        let wallpaperType = theme.wallpaper.type
        let backgroundColor = theme.wallpaper.background ?? wallpaperType.defaultBackgroundColor(theme.base, theme.colors.background)
        let tintColor = theme.wallpaper.tint ?? wallpaperType.defaultTintColor(theme.base)
        // RTF spec: Obsidian Void background (#000000 + 2% #6E25C4 purple glow for dark, #F7F5FA for light)
        ZStack {
            if isInDarkTheme() {
                Color(hex: "#000000")
                Color(hex: "#6E25C4").opacity(0.02)
            } else {
                Color(hex: "#F7F5FA")
            }
        }
        .ignoresSafeArea(.all)
        .if(wallpaperImage != nil && im.secondaryIMFilter == nil) { view in
            view.modifier(
                ChatViewBackground(image: wallpaperImage ?? Image(""), imageType: wallpaperType, background: backgroundColor, tint: tintColor)
            )
        }
    }

    @ViewBuilder
    private func buildMainVStack(userMemberKnockingChat: Bool) -> some View {
        VStack(spacing: 0) {
            AnyView(buildChatArea(userMemberKnockingChat: userMemberKnockingChat))
            if let connectInProgressText = connectProgressManager.showConnectProgress {
                AnyView(connectInProgressView(connectInProgressText))
            }
            if let connectingText {
                AnyView(
                    Text(connectingText)
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                        .padding(.top)
                )
            }
            if selectedChatItems == nil {
                AnyView(
                    ComposeView(
                        chat: chat,
                        im: im,
                        composeState: $composeState,
                        showCommandsMenu: $showCommandsMenu,
                        keyboardVisible: $keyboardVisible,
                        keyboardHiddenDate: $keyboardHiddenDate,
                        selectedRange: $selectedRange
                    )
                )
            } else {
                AnyView(
                    SelectedItemsBottomToolbar(
                        im: im,
                        selectedChatItems: $selectedChatItems,
                        chatInfo: chat.chatInfo,
                        deleteItems: { forAll in
                            allowToDeleteSelectedMessagesForAll = forAll
                            showDeleteSelectedMessages = true
                        },
                        archiveItems: {
                            showArchiveSelectedReports = true
                        },
                        moderateItems: {
                            if case let .group(groupInfo, _) = chat.chatInfo {
                                showModerateSelectedMessagesAlert(groupInfo)
                            }
                        },
                        forwardItems: forwardSelectedMessages
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func buildChatArea(userMemberKnockingChat: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if userMemberKnockingChat {
                AnyView(
                    ZStack(alignment: .top) {
                        chatItemsList()
                        userMemberKnockingTitleBar()
                    }
                )
            } else {
                AnyView(chatItemsList())
            }
            if let groupInfo = chat.chatInfo.groupInfo, !composeState.message.isEmpty {
                AnyView(GroupMentionsView(im: im, groupInfo: groupInfo, composeState: $composeState, selectedRange: $selectedRange, keyboardVisible: $keyboardVisible))
            }
            if !chat.chatInfo.menuCommands.isEmpty {
                AnyView(CommandsMenuView(chat: chat, composeState: $composeState, selectedRange: $selectedRange, showCommandsMenu: $showCommandsMenu))
            }
            AnyView(
                FloatingButtons(im: im, theme: theme, scrollView: scrollView, chat: chat, loadingMoreItems: $loadingMoreItems, loadingTopItems: $loadingTopItems, requestedTopScroll: $requestedTopScroll, loadingBottomItems: $loadingBottomItems, requestedBottomScroll: $requestedBottomScroll, animatedScrollingInProgress: $animatedScrollingInProgress, listState: scrollView.listState, model: floatingButtonModel, reloadItems: {
                    mergedItems.boxedValue = MergedItems.create(im, revealedItems)
                    scrollView.updateItems(mergedItems.boxedValue.items)
                })
            )
        }
    }

    @ViewBuilder private var chatViewBackground: some View {
        // POPOPX: Obsidian Void theme background (particle field removed for battery)
        ZStack {
            if isInDarkTheme() {
                Color(hex: "#000000")
                Color(hex: "#6E25C4").opacity(0.02)
            } else {
                Color(hex: "#F7F5FA")
            }
        }
    }

    @ViewBuilder
    private func connectInProgressView(_ s: String) -> some View {
        // POPOPX: connect progress bar with cancel button
        let pxBarMinHeight: CGFloat = 54
        let pxBarPadding: CGFloat = 12
        VStack(spacing: 0) {
            GlassDivider()

            HStack(spacing: 16) {
                // BrandedProgressView.swift is not yet in the Xcode project; using ProgressView as placeholder.
                ProgressView()
                    .scaleEffect(0.8)
                Text(s)

                Spacer()

                Button {
                    triggerHapticFeedback(.light)
                    ConnectProgressManager.shared.cancelConnectProgress()
                } label: {
                    Image(systemName: "multiply")
                }
                .tint(theme.colors.primary)
            }
            .padding(pxBarPadding)
            .frame(minHeight: pxBarMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ToolbarMaterial.material(toolbarMaterial))
        }
    }

    @inline(__always)
    @ViewBuilder private func primaryPrincipalToolbarContent() -> some View {
        let cInfo = chat.chatInfo
        if selectedChatItems != nil {
            SelectedItemsTopToolbar(selectedChatItems: $selectedChatItems)
        } else if case let .direct(contact) = cInfo {
            Button {
                Task {
                    showChatInfoSheet = true
                }
            } label: {
                ChatInfoToolbar(chat: chat)
            }
            .appSheet(isPresented: $showChatInfoSheet, onDismiss: { }) {
                ChatInfoView(
                    chat: chat,
                    contact: contact,
                    localAlias: chat.chatInfo.localAlias,
                    featuresAllowed: contactUserPrefsToFeaturesAllowed(contact.mergedPreferences),
                    currentFeaturesAllowed: contactUserPrefsToFeaturesAllowed(contact.mergedPreferences),
                    onSearch: { focusSearch() }
                )
            }
        } else if case let .group(groupInfo, _) = cInfo {
            Button {
                Task { await chatModel.loadGroupMembers(groupInfo) { showChatInfoSheet = true } }
            } label: {
                ChatInfoToolbar(chat: chat)
                    .tint(theme.colors.primary)
            }
            .appSheet(isPresented: $showChatInfoSheet, onDismiss: {
                chatModel.secondaryIM = nil
            }) {
                GroupChatInfoView(
                    chat: chat,
                    groupInfo: Binding(
                        get: { groupInfo },
                        set: { gInfo in
                            chat.chatInfo = .group(groupInfo: gInfo, groupChatScope: nil)
                            chat.created = Date.now
                        }
                    ),
                    scrollToItemId: $scrollToItemId,
                    composeState: $composeState,
                    onSearch: { focusSearch() },
                    localAlias: groupInfo.localAlias
                )
            }
        } else if case .local = cInfo {
            ChatInfoToolbar(chat: chat)
        }
    }

    @inline(__always)
    @ViewBuilder private func primaryTrailingToolbarContent() -> some View {
        let cInfo = chat.chatInfo
        if selectedChatItems != nil {
            Button {
                withAnimation {
                    selectedChatItems = nil
                }
            } label: {
                Text(LocalizedStringKey("Cancel"))
            }
        } else {
            switch cInfo {
            case let .direct(contact):
                HStack {
                    let callsPrefEnabled = contact.mergedPreferences.calls.enabled.forUser
                    let canStartCall = callsPrefEnabled && contact.ready && contact.active && chatModel.activeCall == nil
                    if let call = chatModel.activeCall, call.contact.id == cInfo.id {
                        endCallButton(call)
                    } else if canStartCall {
                        // Call button always in toolbar; tap opens Audio/Video submenu
                        Menu {
                            Button {
                                CallController.shared.startCall(contact, .audio)
                            } label: {
                                Label(NSLocalizedString("chat_audio_call", comment: "Label for audio call button"), systemImage: "phone")
                            }
                            Button {
                                CallController.shared.startCall(contact, .video)
                            } label: {
                                Label(NSLocalizedString("chat_video_call", comment: "Label for video call button"), systemImage: "video")
                            }
                        } label: {
                            Image(systemName: "phone")
                        }
                    } else if chatModel.activeCall == nil {
                        // Calls unavailable: show filter button in place of call button
                        contentFilterMenu(withLabel: false)
                    }
                    needleButton()
                    Menu {
                        searchButton()
                        ToggleNtfsButton(chat: chat)
                            .disabled(!contact.ready || !contact.active)
                        // Filter options in menu when call button is shown (or during any active call)
                        if !availableContent.isEmpty && (canStartCall || chatModel.activeCall != nil) {
                            GlassDivider()
                            ForEach(availableContent, id: \.self) { type in
                                Button {
                                    setContentFilter(type)
                                } label: {
                                    Label(type.label, systemImage: contentFilter == type ? type.iconFilled : type.icon)
                                }
                            }
                            if contentFilter != nil {
                                Button {
                                    closeSearch()
                                } label: {
                                    Label(NSLocalizedString("chat_all_messages", comment: "Label to show all messages (clear filter)"), systemImage: "bubble.left.and.text.bubble.right")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            case let .group(groupInfo, _):
                HStack {
                    contentFilterMenu(withLabel: false)
                    needleButton()
                    Menu {
                        if groupInfo.canAddMembers {
                            if chat.chatInfo.incognito || groupInfo.useRelays {
                                groupLinkButton()
                            } else {
                                addMembersButton()
                            }
                        }
                        searchButton()
                        ToggleNtfsButton(chat: chat)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            case .local:
                HStack {
                    if !availableContent.isEmpty {
                        Menu {
                            ForEach(availableContent, id: \.self) { type in
                                Button {
                                    setContentFilter(type)
                                } label: {
                                    Label(type.label, systemImage: contentFilter == type ? type.iconFilled : type.icon)
                                }
                            }
                            if contentFilter != nil {
                                Button {
                                    closeSearch()
                                } label: {
                                    Label(NSLocalizedString("chat_all_messages", comment: "Label to show all messages (clear filter)"), systemImage: "bubble.left.and.text.bubble.right")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                    needleButton()
                    searchButton()
                }
            default:
                EmptyView()
            }
        }
    }

    @inline(__always)
    @ViewBuilder private func secondaryPrincipalToolbarContent() -> some View {
        if selectedChatItems != nil {
            SelectedItemsTopToolbar(selectedChatItems: $selectedChatItems)
        } else {
            switch im.secondaryIMFilter {
            case let .groupChatScopeContext(groupScopeInfo):
                switch groupScopeInfo {
                case let .memberSupport(groupMember_):
                    if let groupMember = groupMember_ {
                        Button {
                            supportChatMemberInfoLinkActive = true
                        } label: {
                            MemberSupportChatToolbar(groupMember: groupMember)
                        }
                    } else {
                        textChatToolbar("Chat with admins")
                    }
                case .reports:
                    textChatToolbar("Member reports")
                }
            case let .msgContentTagContext(contentTag):
                switch contentTag {
                case .report:
                    textChatToolbar("Member reports")
                default:
                    EmptyView()
                }
            case .none:
                EmptyView()
            }
        }
    }

    @inline(__always)
    @ViewBuilder private func secondaryTrailingToolbarContent() -> some View {
        if selectedChatItems != nil {
            Button {
                withAnimation {
                    selectedChatItems = nil
                }
            } label: {
                Text(LocalizedStringKey("Cancel"))
            }
        } else {
            searchButton()
        }
    }

    @inline(__always)
    private func userMemberKnockingTitleBar() -> some View {
         VStack(spacing: 0) {
             Text(LocalizedStringKey("Chat with admins"))
                 .font(.headline)
                 .foregroundColor(theme.colors.onBackground)
                 .padding(.top, 8)
                 .padding(.bottom, 14)
                 .frame(maxWidth: .infinity)
                 .background(ToolbarMaterial.material(toolbarMaterial))
             GlassDivider()
         }
    }

    func textChatToolbar(_ text: LocalizedStringKey) -> some View {
        Text(text)
        .font(.headline)
        .lineLimit(1)
        .foregroundColor(theme.colors.onBackground)
        .frame(width: 220)
    }

    @ViewBuilder
    private func supportChatMemberDestination(groupInfo: GroupInfo, groupMember: GroupMember) -> some View {
        Color.clear
            .frame(width: 0, height: 0)
            .navigationDestination(isPresented: $supportChatMemberInfoLinkActive) {
                PXGroupMemberDetail(
                    groupInfo: groupInfo,
                    chat: chat,
                    groupMember: GMember(groupMember),
                    scrollToItemId: $scrollToItemId,
                    openedFromSupportChat: true
                )
                .toolbar(.visible, for: .navigationBar)
                .modifier(BackButton(disabled: Binding.constant(false)) {
                    supportChatMemberInfoLinkActive = false
                })
            }
    }

    private func handleSecondaryChatChange(_ secondaryChatOpened: Bool) {
        if secondaryChatOpened {
            ItemsModel.loadSecondaryChat(chat.id, chatFilter: .groupChatScopeContext(groupScopeInfo: userSupportScopeInfo)) {
                showUserSupportChatSheet = true
            }
        } else if im.secondaryIMFilter != nil {
            Task {
                try? await Task.sleep(nanoseconds: 650_000000)
                dismiss()
            }
        }
    }

    private func handleChatIdChange(_ cId: String?) {
        pendingCleanup?.cancel()
        pendingCleanup = nil
        ConnectProgressManager.shared.cancelConnectProgress()
        showChatInfoSheet = false
        selectedChatItems = nil
        revealedItems = Set()
        stopAudioPlayer()
        if let cId {
            if let c = chatModel.getChat(cId) {
                _ = c // chat reference is managed by parent via @ObservedObject
            }
            scrollView.listState.onUpdateListener = onChatItemsUpdated
            initChatView()
            closeSearch()
            mergedItems.boxedValue = MergedItems.create(im, revealedItems)
            scrollView.updateItems(mergedItems.boxedValue.items)

            if let openAround = chatModel.openAroundItemId, let index = mergedItems.boxedValue.indexInParentItems[openAround] {
                scrollView.scrollToItem(index)
            } else if let viewedIdx = mergedItems.boxedValue.items.firstIndex(where: { !$0.hasUnread() }) {
                if viewedIdx > 0 {
                    scrollView.scrollToItem(viewedIdx - 1)
                } else {
                    scrollView.scrollToBottom()
                }
            } else if let unreadIndex = mergedItems.boxedValue.items.lastIndex(where: { $0.hasUnread() }) {
                scrollView.scrollToItem(unreadIndex)
            } else {
                scrollView.scrollToBottom()
            }
            if chatModel.openAroundItemId != nil {
                chatModel.openAroundItemId = nil
            }
        } else {
            dismiss()
        }
    }

    private func handleOpenAroundChange(_ openAround: ChatItem.ID?) {
        if let openAround {
            closeSearch()
            mergedItems.boxedValue = MergedItems.create(im, revealedItems)
            scrollView.updateItems(mergedItems.boxedValue.items)
            chatModel.openAroundItemId = nil

            if let index = mergedItems.boxedValue.indexInParentItems[openAround] {
                scrollView.scrollToItem(index)
            }

            if !loadingBottomItems {
                allowLoadMoreItems = false
                let workItem = DispatchWorkItem { allowLoadMoreItems = true }
                allowLoadMoreWorkItem?.cancel()
                allowLoadMoreWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            }
        }
    }

    private func handleOnDisappear(cInfo: ChatInfo) {
        ConnectProgressManager.shared.cancelConnectProgress()
        VideoPlayerView.removeAllPlayers()
        stopAudioPlayer()
        if chatModel.chatId == cInfo.id {
            let closingChatId = chatModel.chatId
            // POPOPX: slightly shorter cleanup delay (0.35→0.32)
            let pxCleanupDelay: TimeInterval = 0.32
            let cleanup = DispatchWorkItem { [weak im] in
                if chatModel.chatId == nil || chatModel.chatId == closingChatId {
                    chatModel.chatAgentConnId = nil
                    chatModel.chatSubStatus = nil
                    im?.reversedChatItems = []
                    im?.chatState.clear()
                    chatModel.groupMembers = []
                    chatModel.groupMembersIndexes.removeAll()
                    chatModel.membersLoaded = false
                    ChannelRelaysModel.shared.reset()
                }
            }
            pendingCleanup = cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + pxCleanupDelay, execute: cleanup)
        }
    }

    // Spec: spec/client/chat-view.md#initChatView
    private func initChatView() {
        let cInfo = chat.chatInfo
        // This check prevents the call to apiContactInfo after the app is suspended, and the database is closed.
        if case .active = scenePhase {
            if case let .direct(contact) = cInfo {
                Task {
                    do {
                        let (stats, _) = try await apiContactInfo(chat.chatInfo.apiId)
                        await MainActor.run {
                            if let s = stats {
                                chatModel.updateContactConnectionStats(contact, s)
                                if let conn = contact.activeConn {
                                    chatModel.chatAgentConnId = conn.agentConnId
                                    chatModel.chatSubStatus = s.subStatus
                                }
                            }
                        }
                    } catch let error {
                        logger.error("apiContactInfo error: \(responseError(error))")
                    }
                }
            } else {
                Task {
                    await MainActor.run {
                        chatModel.chatAgentConnId = nil
                        chatModel.chatSubStatus = nil
                    }
                }
            }
            if case let .group(groupInfo, _) = cInfo, groupInfo.useRelays {
                Task { await chatModel.loadGroupMembers(groupInfo) }
                if groupInfo.membership.memberRole == .owner {
                    Task {
                        let relays = await apiGetGroupRelays(groupInfo.groupId)
                        await MainActor.run {
                            ChannelRelaysModel.shared.set(groupId: groupInfo.groupId, groupRelays: relays)
                        }
                    }
                } else if groupInfo.membership.memberCurrent {
                    Task {
                        if let gInfo = await apiGetUpdatedGroupLinkData(groupInfo.groupId) {
                            await MainActor.run {
                                chatModel.updateGroup(gInfo)
                            }
                        }
                    }
                }
            }
            updateAvailableContent()
        }
        if chatModel.draftChatId == draftChatId(cInfo.id, cInfo.groupChatScope()) && !composeState.forwarding,
           let draft = chatModel.draft {
            composeState = draft
        }
        if chat.chatStats.unreadChat {
            Task {
                await markChatUnread(chat, unreadChat: false)
            }
        }
        floatingButtonModel.updateOnListChange(scrollView.listState)
    }

    private func updateAvailableContent() {
        Task {
            let content: [ContentFilter]
            do {
                let contentTags = Set(try await apiGetChatContentTypes(chatId: chat.chatInfo.id)).union(ContentFilter.alwaysShow)
                content = ContentFilter.allCases.filter { contentTags.contains($0.contentTag) }
            } catch let error {
                logger.error("apiGetChatContentTypes error: \(responseError(error))")
                content = ContentFilter.allCases
            }
            await MainActor.run {
                availableContent = content
            }
        }
    }
    
    // Spec: spec/client/chat-view.md#scrollToItem
    private func scrollToItem(_ itemId: ChatItem.ID) {
        // POPOPX: retry limit and sleep interval extracted to named constants
        let pxMaxScrollRetries: Int = 50
        let pxRetrySleepNs: UInt64 = 20_000000
        Task {
            do {
                var index = mergedItems.boxedValue.indexInParentItems[itemId]
                if index == nil {
                    let pagination = ChatPagination.around(chatItemId: itemId, count: ChatPagination.PRELOAD_COUNT * 2)
                    let oldSize = im.reversedChatItems.count
                    let triedToLoad = await loadChatItems(chat, pagination)
                    if !triedToLoad {
                        return
                    }
                    var repeatsLeft = pxMaxScrollRetries
                    while oldSize == im.reversedChatItems.count && repeatsLeft > 0 {
                        try await Task.sleep(nanoseconds: pxRetrySleepNs)
                        repeatsLeft -= 1
                    }
                    index = mergedItems.boxedValue.indexInParentItems[itemId]
                }
                if let index {
                    closeKeyboardAndRun {
                        Task {
                            await MainActor.run { animatedScrollingInProgress = true }
                            await scrollView.scrollToItemAnimated(min(im.reversedChatItems.count - 1, index))
                            await MainActor.run { animatedScrollingInProgress = false }
                        }
                    }
                }
            } catch {
                logger.error("Error scrolling to item: \(error)")
            }
        }
    }

    // Spec: spec/client/chat-view.md#searchToolbar
    private func searchToolbar() -> some View {
        let placeholder: LocalizedStringKey = contentFilter?.searchPlaceholder ?? "Search"
        // POPOPX: slightly tighter inner spacing than upstream (4→3)
        let pxSearchInnerSpacing: CGFloat = 3
        let pxSearchFieldPadding: CGFloat = 7
        return HStack(spacing: 12) {
            HStack(spacing: pxSearchInnerSpacing) {
                Image(systemName: "magnifyingglass")
                if let contentFilter {
                    Image(systemName: contentFilter.icon)
                }
                TextField(placeholder, text: $searchText)
                    .focused($searchFocussed)
                    .foregroundColor(theme.colors.onBackground)
                    .frame(maxWidth: .infinity)

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").opacity(searchText == "" ? 0 : 1)
                }
            }
            .padding(EdgeInsets(top: pxSearchFieldPadding, leading: pxSearchFieldPadding, bottom: pxSearchFieldPadding, trailing: pxSearchFieldPadding))
            .foregroundColor(theme.colors.secondary)
            .background(Color(.tertiarySystemFill))
            .cornerRadius(10.0)

            Button ("Cancel") {
                closeSearch()
                searchTextChanged("")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func voiceWithoutFrame(_ ci: ChatItem) -> Bool {
        ci.content.msgContent?.isVoice == true && ci.content.text.count == 0 && ci.quotedItem == nil && ci.meta.itemForwarded == nil
    }

    // Spec: spec/client/chat-view.md#filtered
    private func filtered(_ reversedChatItems: Array<ChatItem>) -> Array<ChatItem> {
        reversedChatItems
            .enumerated()
            .filter { (index, chatItem) in
                if let mergeCategory = chatItem.mergeCategory, index > 0 {
                    mergeCategory != reversedChatItems[index - 1].mergeCategory
                } else {
                    true
                }
            }
            .map { $0.element }
    }

    // Spec: spec/client/chat-view.md#chatItemsList
    private func chatItemsList() -> some View {
        // POPOPX: replaced wrapper GeometryReader with background measurement — avoids invalidating entire list layout
        PXScrollRepresentable(scrollView: scrollView) { (index: Int, mergedItem: MergedItem) in
            let ci = switch mergedItem {
            case let .single(item, _, _): item.item
            case let .grouped(items, _, _, _, _, _, _, _): items.boxedValue.last?.item ?? ChatItem.deletedItemDummy()
            }
            return Group {
                if case .chatBanner = ci.content {
                    VStack {
                        ChatBannerView(chat: chat)
                            .padding(.bottom, 90)
                            .padding(.top, 8)

                        let listItem = mergedItem.newest()
                        if let prevItem = listItem.prevItem {
                            DateSeparator(date: prevItem.meta.itemTs).padding(8)
                        }
                    }
                } else {
                    chatItemWithMenuView(mergedItem, ci, index, pxAvailableWidth)
                }
            }
            // crashes on Cell size calculation without this line
            .environmentObject(ChatModel.shared)
            .environmentObject(theme) // crashes without this line when scrolling to the first unread in EndlessScrollVIew
            .id(ci.id) // Required to trigger `onAppear` on iOS15
        }
        .background(
            GeometryReader { pxGeo in
                Color.clear
                    .onAppear { pxAvailableWidth = pxGeo.size.width }
                    .onChange(of: pxGeo.size.width) { _, newWidth in
                        pxAvailableWidth = newWidth
                    }
            }
        )
            .onAppear {
                if !im.isLoading {
                    updateWithInitiallyLoadedItems()
                }
            }
            .onChange(of: im.isLoading) {_,  loading in
                if !loading {
                    updateWithInitiallyLoadedItems()
                }
            }
            .onChange(of: im.reversedChatItems) {_,  items in
                mergedItems.boxedValue = MergedItems.create(im, revealedItems)
                scrollView.updateItems(mergedItems.boxedValue.items)
                if im.itemAdded {
                    im.itemAdded = false
                    if scrollView.listState.firstVisibleItemIndex < 2 {
                        scrollView.scrollToBottomAnimated()
                    } else {
                        scrollView.scroll(by: 34)
                    }
                    // Trigger bubble fly-up for newly sent messages
                    if !reduceMotion, let first = items.first, first.chatDir.sent, first.id != pxLastSentItemId {
                        pxLastSentItemId = first.id
                        let flyUp = PXBubbleFlyUp(text: first.content.text)
                        pxBubbleFlyUps.append(flyUp)
                        Task {
                            // POPOPX: bubble display duration (1.2s → 1.15s)
                            try? await Task.sleep(nanoseconds: 1_150000000)
                            pxBubbleFlyUps.removeAll { $0.id == flyUp.id }
                        }
                    }
                }
            }
            .onChange(of: revealedItems) {_,  revealed in
                mergedItems.boxedValue = MergedItems.create(im, revealed)
                scrollView.updateItems(mergedItems.boxedValue.items)
            }
            .onChange(of: chat.id) {_, _ in
                allowLoadMoreItems = false
                let workItem = DispatchWorkItem { allowLoadMoreItems = true }
                allowLoadMoreWorkItem?.cancel()
                allowLoadMoreWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            }
            .padding(.vertical, -100)
            .onTapGesture { hideKeyboard() }
            .onChange(of: searchText) {_,  s in
                if showSearch {
                    searchTextChanged(s)
                }
            }
    }

    @ViewBuilder
    private func chatItemWithMenuView(_ mergedItem: MergedItem, _ ci: ChatItem, _ index: Int, _ width: CGFloat) -> some View {
        let cInfo = chat.chatInfo
        let voiceNoFrame = voiceWithoutFrame(ci)
        // POPOPX: slightly wider group chat ratio (0.84→0.85) and adjusted direct chat margins
        let pxGroupWidthFactor: CGFloat = 0.85
        let pxGroupMargin: CGFloat = 42
        let pxDirectMargin: CGFloat = 32
        let maxWidth = cInfo.chatType == .group
            ? voiceNoFrame
                ? (width - 28) - pxGroupMargin
                : (width - 28) * pxGroupWidthFactor - pxGroupMargin
            : voiceNoFrame
                ? (width - pxDirectMargin)
                : (width - pxDirectMargin) * pxGroupWidthFactor
        ChatItemWithMenu(
            im: im,
            chat: chat,
            index: index,
            isLastItem: index == mergedItems.boxedValue.items.count - 1,
            chatItem: ci,
            scrollToItem: scrollToItem,
            scrollToItemId: $scrollToItemId,
            merged: mergedItem,
            maxWidth: maxWidth,
            composeState: $composeState,
            selectedMember: $selectedMember,
            showChatInfoSheet: $showChatInfoSheet,
            revealedItems: $revealedItems,
            selectedChatItems: $selectedChatItems,
            forwardedChatItems: $forwardedChatItems,
            searchText: $searchText,
            contentFilter: $contentFilter,
            closeKeyboardAndRun: closeKeyboardAndRun
        )
    }


    private var connectingText: LocalizedStringKey? {
        switch (chat.chatInfo) {
        case let .direct(contact):
            if !contact.sndReady && contact.active && !contact.sendMsgToConnect && !contact.nextAcceptContactRequest {
                (contact.preparedContact?.uiConnLinkType == .con && !contact.isBot) || contact.contactGroupMemberId != nil
                ? "contact should accept…"
                : "connecting…"
            } else {
                nil
            }
        case let .group(groupInfo, _):
            if groupInfo.useRelays {
                nil
            } else {
                switch (groupInfo.membership.memberStatus) {
                case .memUnknown: groupInfo.preparedGroup?.connLinkStartedConnection == true ? "connecting…" : nil
                case .memAccepted: "connecting…"
                default: nil
                }
            }
        default: nil
        }
    }

    private func updateWithInitiallyLoadedItems() {
        if mergedItems.boxedValue.items.isEmpty {
            mergedItems.boxedValue = MergedItems.create(im, revealedItems)
        }
        let unreadIndex = mergedItems.boxedValue.items.lastIndex(where: { $0.hasUnread() })
        let unreadItemId: Int64? = if let unreadIndex { mergedItems.boxedValue.items[unreadIndex].newest().item.id } else { nil }
        // this helps to speed up initial process of setting scroll position and reduce time needed
        // to layout items on screen
        if let unreadIndex, let unreadItemId {
            scrollView.setScrollPosition(unreadIndex, unreadItemId)
        }
        scrollView.updateItems(mergedItems.boxedValue.items)
        if let unreadIndex {
            scrollView.scrollToItem(unreadIndex)
        }
        let workItem = DispatchWorkItem { allowLoadMoreItems = true }
        allowLoadMoreWorkItem?.cancel()
        allowLoadMoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    // Spec: spec/client/chat-view.md#searchTextChanged
    private func searchTextChanged(_ s: String) {
        Task {
            await loadChat(chat: chat, im: im, contentTag: contentFilter?.contentTag, search: s)
            mergedItems.boxedValue = MergedItems.create(im, revealedItems)
            await MainActor.run {
                scrollView.updateItems(mergedItems.boxedValue.items)
            }
            if !s.isEmpty {
                scrollView.scrollToBottom()
            } else if let index = scrollView.listState.items.lastIndex(where: { $0.hasUnread() }) {
                // scroll to the top unread item
                scrollView.scrollToItem(index)
            } else {
                scrollView.scrollToBottom()
            }
        }
    }


    // Spec: spec/client/chat-view.md#callButton
    private func callButton(_ contact: Contact, _ media: CallMediaType, imageName: String) -> some View {
        Button {
            CallController.shared.startCall(contact, media)
        } label: {
            Image(systemName: imageName)
        }
    }

    private func endCallButton(_ call: Call) -> some View {
        Button {
            if CallController.useCallKit(), let callUUID = call.callUUID {
                CallController.shared.endCall(callUUID: callUUID)
            } else {
                CallController.shared.endCall(call: call) {}
            }
        } label: {
            Image(systemName: "phone.down.fill").tint(QuantumColors.error)
        }
    }

    private func needleButton() -> some View {
        Button {
            chatExtractions = LocalExtractionStore.shared.fetchByChatId(chat.chatInfo.id)
            showExtractionsSheet = true
        } label: {
            Image(systemName: "sparkles")
        }
    }

    private func searchButton() -> some View {
        Button {
            focusSearch()
        } label: {
            Label(NSLocalizedString("chat_search", comment: "Label for search button"), systemImage: "magnifyingglass")
        }
    }

    private func contentFilterMenu(withLabel: Bool) -> some View {
        Menu {
            ForEach(availableContent, id: \.self) { type in
                Button {
                    setContentFilter(type)
                } label: {
                    Label(type.label, systemImage: contentFilter == type ? type.iconFilled : type.icon)
                }
            }
            if contentFilter != nil {
                Button {
                    closeSearch()
                } label: {
                    Label(NSLocalizedString("chat_all_messages", comment: "Label to show all messages (clear filter)"), systemImage: "bubble.left.and.text.bubble.right")
                }
            }
        } label: {
            let icon = contentFilter == nil ? "photo.on.rectangle" : "photo.on.rectangle.fill"
            if withLabel {
                Label(NSLocalizedString("chat_filter", comment: "Label for filter button"), systemImage: icon)
            } else {
                Image(systemName: icon)
            }
        }
    }

    private func focusSearch() {
        showSearch = true
        searchFocussed = true
        searchText = ""
    }

    private func setContentFilter(_ type: ContentFilter) {
        if (contentFilter == type) { return }
        contentFilter = type
        showSearch = true
        searchText = ""
        searchTextChanged("")
    }

    private func closeSearch() {
        showSearch = false
        searchText = ""
        searchFocussed = false
        contentFilter = nil
        updateAvailableContent()
    }

    private func closeKeyboardAndRun(_ action: @escaping () -> Void) {
        var delay: TimeInterval = 0
        if keyboardVisible || keyboardHiddenDate.timeIntervalSinceNow >= -1 || showSearch {
            delay = 0.5
            closeSearch()
            hideKeyboard()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }

    private func addMembersButton() -> some View {
        Button {
            if case let .group(gInfo, _) = chat.chatInfo {
                Task { await chatModel.loadGroupMembers(gInfo) { showAddMembersSheet = true } }
            }
        } label: {
            Label(NSLocalizedString("chat_invite_member", comment: "Label for invite member button"), systemImage: "person.crop.circle.badge.plus")
        }
    }

    private func groupLinkButton() -> some View {
        Button {
            if case let .group(gInfo, _) = chat.chatInfo {
                Task {
                    do {
                        if let gLink = try apiGetGroupLink(gInfo.groupId) {
                            groupLink = gLink
                            groupLinkMemberRole = gLink.acceptMemberRole
                        }
                    } catch let error {
                        logger.error("ChatView apiGetGroupLink: \(responseError(error))")
                    }
                    showGroupLinkSheet = true
                }
            }
        } label: {
            if case let .group(gInfo, _) = chat.chatInfo, gInfo.useRelays {
                Label(NSLocalizedString("group_channel_link_label", comment: "Label for channel link button"), systemImage: "link")
            } else {
                Label(NSLocalizedString("group_group_link_label", comment: "Label for group link button"), systemImage: "link.badge.plus")
            }
        }
    }

    private func showModerateSelectedMessagesAlert(_ groupInfo: GroupInfo) {
        guard let count = selectedChatItems?.count, count > 0 else { return }

        AlertManager.shared.showAlert(Alert(
            title: Text(count == 1
                ? NSLocalizedString("Delete member message?", comment: "alert title")
                : String.localizedStringWithFormat(NSLocalizedString("Delete %d messages of members?", comment: "alert title"), count)),
            message: Text(
                groupInfo.fullGroupPreferences.fullDelete.on
                ? (count == 1
                    ? NSLocalizedString("The message will be deleted for all members.", comment: "alert message")
                    : String.localizedStringWithFormat(NSLocalizedString("The messages will be deleted for all members.", comment: "alert message"), count))
                : (count == 1
                    ? NSLocalizedString("The message will be marked as moderated for all members.", comment: "alert message")
                    : String.localizedStringWithFormat(NSLocalizedString("The messages will be marked as moderated for all members.", comment: "alert message"), count))
            ),
            primaryButton: .destructive(Text(LocalizedStringKey("Delete"))) {
                if let selected = selectedChatItems {
                    deleteMessages(chat, selected.sorted(), .cidmBroadcast, moderate: true, deletedSelectedMessages)
                }
            },
            secondaryButton: .cancel()
        ))
    }

    // Spec: spec/client/chat-view.md#deletedSelectedMessages
    private func deletedSelectedMessages() async {
        await MainActor.run {
            withAnimation {
                selectedChatItems = nil
            }
        }
    }

    // Spec: spec/client/chat-view.md#forwardSelectedMessages
    private func forwardSelectedMessages() {
        Task {
            do {
                if let selectedChatItems {
                    let (validItems, confirmation) = try await apiPlanForwardChatItems(
                        type: chat.chatInfo.chatType,
                        id: chat.chatInfo.apiId,
                        scope: chat.chatInfo.groupChatScope(),
                        itemIds: Array(selectedChatItems)
                    )
                    if let confirmation {
                        if validItems.count > 0 {
                            showAlert(
                                String.localizedStringWithFormat(
                                    NSLocalizedString("Forward %d message(s)?", comment: "alert title"),
                                    validItems.count
                                ),
                                message: forwardConfirmationText(confirmation) + "\n" +
                                    NSLocalizedString("Forward messages without files?", comment: "alert message")
                            ) {
                                switch confirmation {
                                case let .filesNotAccepted(fileIds):
                                    [forwardAction(validItems), downloadAction(fileIds), cancelAlertAction]
                                default:
                                    [forwardAction(validItems), cancelAlertAction]
                                }
                            }
                        } else {
                            showAlert(
                                NSLocalizedString("Nothing to forward!", comment: "alert title"),
                                message: forwardConfirmationText(confirmation)
                            ) {
                                switch confirmation {
                                case let .filesNotAccepted(fileIds):
                                    [downloadAction(fileIds), cancelAlertAction]
                                default:
                                    [okAlertAction]
                                }
                            }
                        }
                    } else {
                        await openForwardingSheet(validItems)
                    }
                }
            } catch {
                logger.error("Plan forward chat items failed: \(error.localizedDescription)")
            }
        }

        func forwardConfirmationText(_ fc: ForwardConfirmation) -> String {
            switch fc {
            case let .filesNotAccepted(fileIds):
                String.localizedStringWithFormat(
                    NSLocalizedString("%d file(s) were not downloaded.", comment: "forward confirmation reason"),
                    fileIds.count
                )
            case let .filesInProgress(filesCount):
                String.localizedStringWithFormat(
                    NSLocalizedString("%d file(s) are still being downloaded.", comment: "forward confirmation reason"),
                    filesCount
                )
            case let .filesMissing(filesCount):
                String.localizedStringWithFormat(
                    NSLocalizedString("%d file(s) were deleted.", comment: "forward confirmation reason"),
                    filesCount
                )
            case let .filesFailed(filesCount):
                String.localizedStringWithFormat(
                    NSLocalizedString("%d file(s) failed to download.", comment: "forward confirmation reason"),
                    filesCount
                )
            }
        }

        func forwardAction(_ items: [Int64]) -> UIAlertAction {
            UIAlertAction(
                title: NSLocalizedString("Forward messages", comment: "alert action"),
                style: .default,
                handler: { _ in Task { await openForwardingSheet(items) } }
            )
        }

        func downloadAction(_ fileIds: [Int64]) -> UIAlertAction {
            UIAlertAction(
                title: NSLocalizedString("Download files", comment: "alert action"),
                style: .default,
                handler: { _ in
                    Task {
                        if let user = ChatModel.shared.currentUser {
                            await receiveFiles(user: user, fileIds: fileIds)
                        }
                    }
                }
            )
        }

        func openForwardingSheet(_ items: [Int64]) async {
            var items = Set(items)
            var fci = [ChatItem]()
            for reversedChatItem in im.reversedChatItems {
                if items.contains(reversedChatItem.id) {
                    items.remove(reversedChatItem.id)
                    fci.insert(reversedChatItem, at: 0)
                }
                if items.isEmpty { break }
            }
            await MainActor.run { forwardedChatItems = fci }
        }
    }

    // Spec: spec/client/chat-view.md#loadChatItems
    private func loadChatItems(_ chat: Chat, _ pagination: ChatPagination) async -> Bool {
        if loadingMoreItems { return false }
        await MainActor.run {
            loadingMoreItems = true
            if case .before = pagination {
                loadingTopItems = true
            } else if case .after = pagination {
                loadingBottomItems = true
            }
        }
        let triedToLoad = await loadChatItemsUnchecked(chat, pagination)
        await MainActor.run {
            loadingMoreItems = false
            if case .before = pagination {
                loadingTopItems = false
            } else if case .after = pagination {
                loadingBottomItems = false
            }
        }
        return triedToLoad
    }

    private func loadChatItemsUnchecked(_ chat: Chat, _ pagination: ChatPagination) async -> Bool {
        await apiLoadMessages(
            chat.chatInfo.id,
            im,
            pagination,
            contentFilter?.contentTag,
            searchText,
            nil,
            { visibleItemIndexesNonReversed(im, scrollView.listState, mergedItems.boxedValue) }
        )
        return true
    }

    func stopAudioPlayer() {
        VoiceItemState.chatView.values.forEach { $0.audioPlayer?.stop() }
        VoiceItemState.chatView = [:]
    }

    // Spec: spec/client/chat-view.md#onChatItemsUpdated
    func onChatItemsUpdated() {
        if !mergedItems.boxedValue.isActualState() {
            //logger.debug("Items are not actual, waiting for the next update: \(String(describing: mergedItems.boxedValue.splits))  \(im.chatState.splits), \(mergedItems.boxedValue.indexInParentItems.count) vs \(im.reversedChatItems.count)")
            return
        }
        floatingButtonModel.updateOnListChange(scrollView.listState)
        pxPreloadIfNeeded(
            im,
            $allowLoadMoreItems,
            $ignoreLoadingRequests,
            scrollView.listState,
            mergedItems,
            loadItems: { unchecked, pagination in
                if unchecked {
                    await loadChatItemsUnchecked(chat, pagination)
                } else {
                    await loadChatItems(chat, pagination)
                }
            },
            loadLastItems: {
                if !loadingMoreItems {
                    await pxLoadLastItems($loadingMoreItems, loadingBottomItems: $loadingBottomItems, chat, im)
                }
            }
        )
    }

}

