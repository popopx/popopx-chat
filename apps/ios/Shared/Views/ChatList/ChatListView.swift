//
//  ChatListView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-list.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - Haptic Feedback Helper

private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

private func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type)
}

struct ChatListView: View {
    @AppStorage(GROUP_DEFAULT_ONE_HAND_UI, store: groupDefaults) private var oneHandUI = false
    @AppStorage(DEFAULT_ONE_HAND_UI_CARD_SHOWN) private var oneHandUICardShown = false
    @AppStorage(DEFAULT_ADDRESS_CREATION_CARD_SHOWN) private var addressCreationCardShown = false
    @AppStorage(DEFAULT_SUPPORTER_BANNER_SHOWN) private var supporterBannerShown = false
    @AppStorage(DEFAULT_SUPPORTER_BANNER_TAPPED) private var supporterBannerTapped = false
    @AppStorage(DEFAULT_GET_STAKE_BANNER_TAPPED) private var getStakeBannerTapped = false
    @AppStorage(DEFAULT_GET_STAKE_BANNER_DISMISSED) private var getStakeBannerDismissed = false
    @AppStorage(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    @State private var showNewChatSheet = false
    @State private var showProfilerWheel = false
    @State private var showGetStakeSheet = false
    @State private var searchMode = false
    @FocusState private var searchFocussed
    @State private var searchText = ""
    @State private var searchShowingPopopxLink = false
    @State private var searchChatFilteredByPopopxLink: String? = nil
    @State private var scrollToSearchBar = false
    @State private var userPickerShown: Bool = false
    @State private var tagsExpanded: Bool = false
    @State private var sheet: SomeSheet<AnyView>? = nil
    @ObservedObject private var chatTagsModel = ChatTagsModel.shared
    @ObservedObject private var badgeModel = BadgeModel.shared
    @State private var scrollToItemId: ChatItem.ID? = nil
    @State private var showBadgesSheet = false

    // iOS 15 is required it to show/hide toolbar while chat is hidden/visible
    @State private var viewOnScreen = true

    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject private var connectProgressManager = ConnectProgressManager.shared
    @EnvironmentObject var theme: AppTheme
    @Binding var activeUserPickerSheet: UserPickerSheet?
    var onSwitchToProfileTab: (() -> Void)? = nil
    var onSwitchToMesh: (() -> Void)? = nil
    var onSwitchToDiscover: (() -> Void)? = nil

    // Spec: spec/client/chat-list.md#body
    var body: some View {
        viewBody.scrollDismissesKeyboard(.immediately)
    }
    
    private var viewBody: some View {
        ZStack {
            NavigationLink(value: true) { EmptyView() }
            chatListView
            ChatPopOverlayView()
            if showProfilerWheel {
                RevolverWheelView(isPresented: $showProfilerWheel, onSwitchToProfileTab: onSwitchToProfileTab)
                    .zIndex(100)
                    .allowsHitTesting(showProfilerWheel)
            }
        }
        .navigationDestination(for: Bool.self) { show in
            if show { chatView() }
        }
        .modifier(
            Sheet(isPresented: $userPickerShown) {
                UserPicker(userPickerShown: $userPickerShown, activeSheet: $activeUserPickerSheet)
            }
        )
        .appSheet(
            item: $activeUserPickerSheet,
            onDismiss: { chatModel.laRequest = nil },
            content: { UserPickerSheetView(sheet: $0) }
        )
        .appSheet(isPresented: $showNewChatSheet) {
            NewChatSheet()
        }
        .appSheet(isPresented: $showBadgesSheet) {
            NavigationView {
                BadgesView(showsAsSheet: true)
                    .modifier(ThemedBackground())
            }
        }
        .onChange(of: activeUserPickerSheet) { _, newValue in
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    userPickerShown = false
                }
            }
        }
        .environmentObject(chatTagsModel)
    }
    
    private var chatListView: some View {
        let tm = ToolbarMaterial.material(toolbarMaterial)
        return withToolbar(tm) {
            chatList
                .background(Color.clear)
                .navigationBarTitleDisplayMode(.inline)
                // FIXED: Keep navigation bar visible during search for consistent back button access
                // Previously hid nav bar completely, violating iOS HIG navigation consistency
        }
        // REMOVED: .scaleEffect(x: 1, y: oneHandUI ? -1 : 1, anchor: .center)
        // Vertical flip created cognitive disorientation and violated iOS HIG
        // Now using proper safe area adjustments instead
        .onDisappear {
            activeUserPickerSheet = nil
        }
        .refreshable {
            AlertManager.shared.showAlert(Alert(
                title: Text(NSLocalizedString("Reconnect servers?", comment: "")),
                message: Text(NSLocalizedString("Reconnect all connected servers to force message delivery. It uses additional traffic.", comment: "")),
                primaryButton: .default(Text(NSLocalizedString("Ok", comment: ""))) {
                    Task {
                        do {
                            try await reconnectAllServers()
                        } catch let error {
                            AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "alert title")), message: LocalizedStringKey(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
                        }
                    }
                },
                secondaryButton: .cancel()
            ))
        }
        .safeAreaInset(edge: .top) {
            if oneHandUI {
                GlassDivider()
            }
        }
        .sheet(item: $sheet) { sheet in
            sheet.content.presentationDetents([.fraction(sheet.fraction)])
        }
    }
    
    static var hasHomeIndicator: Bool = {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.safeAreaInsets.bottom > 0
        } else { false }
    }()
    
    @ViewBuilder func withToolbar(_ material: Material, content: () -> some View) -> some View {
        content()
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbarBackground(material)
            .toolbar { topToolbar }
            .navigationTitle(NSLocalizedString("chats_nav_title", comment: "Chats navigation title"))
            .navigationBarTitleDisplayMode(.inline)
    }

    @ToolbarContentBuilder var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            PXProfilerAvatar(showProfilerWheel: $showProfilerWheel, onSwitchToProfileTab: onSwitchToProfileTab)
                .frame(width: 36, height: 36)
        }
        ToolbarItem(placement: .principal) {
            BrandTitleView()
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 10) {
                HeaderNeedlePinView()
                QuickActionButton(showNewChatSheet: $showNewChatSheet)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if chatModel.chatRunning == .some(false) {
                chatStoppedIcon()
                    .accessibilityLabel(NSLocalizedString("Service stopped", comment: "Accessibility label for stopped service indicator"))
            }
        }
    }
    
    @ViewBuilder var trailingToolbarItem: some View {
        switch chatModel.chatRunning {
        case .some(true): NewChatMenuButton(showNewChatSheet: $showNewChatSheet)
        case .some(false):
            chatStoppedIcon()
                .accessibilityLabel(NSLocalizedString("Service stopped", comment: "Accessibility label for stopped service indicator"))
        case .none: EmptyView()
        }
    }

    // the onboarding cards replace the whole chat list, and the support-ended banner lives in the
    // list - a lapsed supporter is not a newcomer, and must be told even with no conversations yet
    private var shouldShowOnboarding: Bool {
        !addressCreationCardShown && !chatModel.chats.isEmpty && !hasConversations && !supportEnded && !badgeIssueFailed
    }

    private var supportEnded: Bool {
        badgeModel.alert?.kind == .supportEnded && badgeModel.userId == chatModel.currentUser?.userId
    }

    private var badgeIssueFailed: Bool {
        badgeModel.alert?.kind == .issueFailed && badgeModel.userId == chatModel.currentUser?.userId
    }

    private func showBadgeAlertDismissAlert(_ title: String) {
        showAlert(title) {
            [
                UIAlertAction(title: NSLocalizedString("Remind me later", comment: "alert button"), style: .default) { _ in
                    Task { await ackBadgeAlert(snooze: true) }
                },
                UIAlertAction(title: NSLocalizedString("Dismiss", comment: "alert button"), style: .default) { _ in
                    Task { await ackBadgeAlert(snooze: false) }
                },
                cancelAlertAction
            ]
        }
    }

    private func showSupportPopopxDismissAlert() {
        showAlert(
            title: NSLocalizedString("Support POPOPX", comment: "alert title"),
            message: NSLocalizedString("You can support POPOPX later in Settings.", comment: "alert message"),
            buttonTitle: NSLocalizedString("Ok", comment: "alert button"),
            buttonAction: { withAnimation { supporterBannerShown = true } },
            cancelButton: false
        )
    }

    private func openGetStake() {
        getStakeBannerTapped = true
        showGetStakeSheet = true
    }

    private var hasConversations: Bool {
        chatModel.chats.contains { chat in
            switch chat.chatInfo {
            case .local: return false
            case let .direct(contact): return !contact.chatDeleted && !contact.isContactCard
            case .group: return true
            case .contactRequest: return false
            case .contactConnection: return false
            case .meshPeer: return true
            case .meshGroup: return true
            case .invalidJSON: return false
            }
        }
    }

    @ViewBuilder private var chatList: some View {
        chatListContent
    }

    private var chatListContent: some View {
        let cs = filteredChats()
        let meshChats = cs.filter { isMeshChat($0) }
        let regularChats = cs.filter { !isMeshChat($0) }
        return ZStack {
            CosmicAbyssBackground()
            ScrollViewReader { scrollProxy in
                ScrollView {
                    chatListStack(cs: cs, meshChats: meshChats, regularChats: regularChats)
                        .padding(.vertical, 8)
                }
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 62)
                }
                .refreshable {
                    AlertManager.shared.showAlert(Alert(
                        title: Text(NSLocalizedString("Reconnect servers?", comment: "")),
                        message: Text(NSLocalizedString("Reconnect all connected servers to force message delivery. It uses additional traffic.", comment: "")),
                        primaryButton: .default(Text(NSLocalizedString("Ok", comment: ""))) {
                            Task {
                                do {
                                    try await reconnectAllServers()
                                } catch let error {
                                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "alert title")), message: LocalizedStringKey(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    ))
                }
                .onChange(of: chatModel.chatId) {_,  currentChatId in
                    if let chatId = chatModel.chatToTop, currentChatId != chatId {
                        chatModel.chatToTop = nil
                        chatModel.popChat(chatId)
                    }
                    stopAudioPlayer()
                }
                .onChange(of: chatModel.currentUser?.userId) {_, _ in
                    stopAudioPlayer()
                }
                .onChange(of: scrollToSearchBar) {_,  scrollToSearchBar in
                    if scrollToSearchBar {
                        Task { self.scrollToSearchBar = false }
                        withAnimation { scrollProxy.scrollTo("searchBar") }
                    }
                }
            }
            if cs.isEmpty && !chatModel.chats.isEmpty {
                noChatsView()
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func chatListStack(cs: [Chat], meshChats: [Chat], regularChats: [Chat]) -> some View {
        LazyVStack(spacing: 6) {
            if !chatModel.chats.isEmpty {
                ChatListSearchBar(
                    searchMode: $searchMode,
                    searchFocussed: $searchFocussed,
                    searchText: $searchText,
                    searchShowingPopopxLink: $searchShowingPopopxLink,
                    searchChatFilteredByPopopxLink: $searchChatFilteredByPopopxLink,
                    tagsExpanded: $tagsExpanded,
                    parentSheet: $sheet
                )
                .frame(maxWidth: .infinity)
                .padding(.top, oneHandUI ? 12 : 0)
                .padding(.bottom, 4)
                .id("searchBar")
            }
            // one slot: a badge the user paid for ending outranks the pitch to get one
            if supportEnded, let alert = badgeModel.alert {
                SupportPopopxBanner(
                    title: "Your badge expired",
                    subtitle: "Your badge expired on \(alert.dateText).",
                    onTap: { showBadgesSheet = true },
                    onDismiss: { showBadgeAlertDismissAlert(NSLocalizedString("Your badge expired", comment: "alert title")) }
                )
                    .padding(.vertical, 3)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .zIndex(1)
                    .onAppear { chatModel.chatListBanner = .badgeExpired }
            } else if badgeIssueFailed {
                SupportPopopxBanner(
                    title: "Badge renewal failed",
                    subtitle: "Tap for details",
                    warning: true,
                    onTap: { showBadgesSheet = true },
                    onDismiss: { showBadgeAlertDismissAlert(NSLocalizedString("Badge renewal failed", comment: "alert title")) }
                )
                    .padding(.vertical, 3)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .zIndex(1)
                    .onAppear { chatModel.chatListBanner = .badgeIssueFailed }
            // noShownBadge is false until the badge state loads: the pitch must not lock the slot and then
            // be hidden by a supporter's badge arriving a moment later, leaving the slot empty for the session
            } else if chatModel.bannerSlotFree(for: .badgePitch) && !supporterBannerShown && noShownBadge() && chatModel.chats.count > 3 {
                SupportPopopxBanner(
                    showDismiss: supporterBannerTapped,
                    onTap: {
                        supporterBannerTapped = true
                        showBadgesSheet = true
                    },
                    onDismiss: showSupportPopopxDismissAlert
                )
                    .padding(.vertical, 3)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .zIndex(1)
                    .onAppear { chatModel.chatListBanner = .badgePitch }
            } else if chatModel.bannerSlotFree(for: .getStake) && isInUS && !getStakeBannerDismissed {
                GetStakeBanner(
                    showDismiss: getStakeBannerTapped && !chatModel.chats.isEmpty,
                    onTap: openGetStake,
                    onDismiss: { withAnimation { getStakeBannerDismissed = true } }
                )
                    .padding(.vertical, 3)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .zIndex(1)
                    .onAppear { chatModel.chatListBanner = .getStake }
            }
            if !meshChats.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#6E25C4").opacity(0.8))
                    Text(NSLocalizedString("chat_list_mesh_section", comment: "Mesh section header"))
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: "#6E25C4").opacity(0.9))
                        .textCase(.uppercase)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6E25C4").opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ForEach(meshChats, id: \.viewId) { chat in
                    ChatBubbleRow(chat: chat, parentSheet: $sheet)
                        .disabled(chatModel.chatRunning != true || chatModel.deletedChats.contains(chat.chatInfo.id))
                }
            }
            ForEach(regularChats, id: \.viewId) { chat in
                ChatBubbleRow(chat: chat, parentSheet: $sheet)
                    .disabled(chatModel.chatRunning != true || chatModel.deletedChats.contains(chat.chatInfo.id))
            }
        }
    }
    
    @ViewBuilder private func noChatsView() -> some View {
        VStack(spacing: 16) {
            if searchString().isEmpty {
                switch chatTagsModel.activeFilter {
                case .presetTag:
                    gradientIcon("tag.slash", size: 48)
                case let .userTag(tag):
                    gradientIcon("tag.slash", size: 48)
                    Text(verbatim: String(format: NSLocalizedString("no_chats_in_list", comment: "No chats in list"), tag.chatTagText))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Button {
                        chatTagsModel.activeFilter = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                            Text(NSLocalizedString("clear_filter", comment: "Button to clear active filter"))
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(12)
                    }
                case .unread:
                    gradientIcon("bubble.left.slash", size: 48)
                    Text(LocalizedStringKey("No unread chats"))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Button {
                        chatTagsModel.activeFilter = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal.decrease")
                            Text(NSLocalizedString("show_all_chats", comment: "Button to show all chats"))
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(12)
                    }
                case .none:
                    gradientIcon("bubble.left.and.bubble.right", size: 56, glow: true)
                    Text(LocalizedStringKey(NSLocalizedString("chat_list_no_chats_yet", comment: "")))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(NSLocalizedString("start_conversation_hint", comment: "Hint text when no chats exist"))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button {
                        showNewChatSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                            Text(NSLocalizedString("new_chat_button", comment: "Button to start new chat"))
                        }
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(QuantumButtonStyle())
                    .padding(.top, 12)
                }
            } else {
                gradientIcon("magnifyingglass", size: 48)
                Text(LocalizedStringKey("No chats found"))
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("try_different_search", comment: "Hint for empty search results"))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    QuantumGlass.iridescentBorderGradient(opacity: 0.12),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 20)
    }

    private func gradientIcon(_ name: String, size: CGFloat, glow: Bool = false) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#6E25C4").opacity(0.7), Color(hex: "#00FFD2").opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: glow ? Color(hex: "#6E25C4").opacity(0.3) : .clear, radius: 12)
    }

    
    // Spec: spec/client/chat-list.md#unreadBadge
    private func unreadBadge(size: CGFloat = 18) -> some View {
        Circle()
            .frame(width: size, height: size)
            .foregroundColor(theme.colors.primary)
    }
    
    @ViewBuilder private func chatView() -> some View {
        if let chatId = chatModel.chatId, let chat = chatModel.getChat(chatId) {
            let im = ItemsModel.shared
            ChatView(
                chat: chat,
                im: im,
                mergedItems: BoxedValue(MergedItems.create(im, [])),
                floatingButtonModel: FloatingButtonModel(im: im),
                scrollToItemId: $scrollToItemId
            )
        }
    }
    
    // Spec: spec/client/chat-list.md#stopAudioPlayer
    func stopAudioPlayer() {
        VoiceItemState.smallView.values.forEach { $0.audioPlayer?.stop() }
        VoiceItemState.smallView = [:]
    }
    
    // Spec: spec/client/chat-list.md#filteredChats
    private func filteredChats() -> [Chat] {
        if let linkChatId = searchChatFilteredByPopopxLink {
            return chatModel.chats.filter { $0.id == linkChatId }
        } else {
            let s = searchString()
            let simpleChats: [Chat] = s == ""
            ? chatModel.chats.filter { chat in
                !chat.chatInfo.chatDeleted && !chat.chatInfo.contactCard && filtered(chat)
            }
            : chatModel.chats.filter { chat in
                let cInfo = chat.chatInfo
                return switch cInfo {
                case let .direct(contact):
                    !contact.chatDeleted && !chat.chatInfo.contactCard && (
                        ( viewNameContains(cInfo, s) ||
                          contact.profile.displayName.localizedLowercase.contains(s) ||
                          contact.fullName.localizedLowercase.contains(s)
                        )
                    )
                case .group: viewNameContains(cInfo, s)
                case .local: viewNameContains(cInfo, s)
                case .contactRequest: viewNameContains(cInfo, s)
                case let .contactConnection(conn): conn.localAlias.localizedLowercase.contains(s)
                case .meshPeer: false
                case .meshGroup: false
                case .invalidJSON: false
                }
            }
            // Merge mesh conversations when mesh transport is enabled
            if chatModel.meshTransportEnabled {
                let meshFiltered: [Chat] = s == ""
                    ? chatModel.meshConversations
                    : chatModel.meshConversations.filter { chat in
                        chat.chatInfo.chatViewName.localizedLowercase.contains(s)
                    }
                return meshFiltered + simpleChats
            }
            return simpleChats
        }

        func filtered(_ chat: Chat) -> Bool {
            switch chatTagsModel.activeFilter {
            case let .presetTag(tag): presetTagMatchesChat(tag, chat.chatInfo, chat.chatStats)
            case let .userTag(tag): chat.chatInfo.chatTags?.contains(tag.chatTagId) == true
            case .unread: chat.unreadTag
            case .none: true
            }
        }

        func viewNameContains(_ cInfo: ChatInfo, _ s: String) -> Bool {
            cInfo.chatViewName.localizedLowercase.contains(s)
        }
    }
    
    // Spec: spec/client/chat-list.md#searchString
    func searchString() -> String {
        searchShowingPopopxLink ? "" : searchText.trimmingCharacters(in: .whitespaces).localizedLowercase
    }

    private func isMeshChat(_ chat: Chat) -> Bool {
        let chatId = chat.chatInfo.id
        return chatId.hasPrefix("mesh:") || chatId.hasPrefix("meshgroup:")
    }
}

struct SubsStatusIndicator: View {
    @State private var subs: SMPServerSubs = SMPServerSubs.newSMPServerSubs
    @State private var hasSess: Bool = false
    @State private var task: Task<Void, Never>?
    @State private var showServersSummary = false

    @AppStorage(DEFAULT_SHOW_SUBSCRIPTION_PERCENTAGE) private var showSubscriptionPercentage = false

    var body: some View {
        Button {
            showServersSummary = true
        } label: {
            HStack(spacing: 4) {
                Text(LocalizedStringKey("Chats")).foregroundStyle(Color.primary).fixedSize().font(.headline)
                SubscriptionStatusIndicatorView(subs: subs, hasSess: hasSess)
                if showSubscriptionPercentage {
                    SubscriptionStatusPercentageView(subs: subs, hasSess: hasSess)
                }
            }
        }
        .disabled(ChatModel.shared.chatRunning != true)
        .onAppear {
            startTask()
        }
        .onDisappear {
            stopTask()
        }
        .appSheet(isPresented: $showServersSummary) {
            ServersSummaryView()
        }
    }

    private func startTask() {
        task = Task {
            while !Task.isCancelled {
                if AppChatState.shared.value == .active, ChatModel.shared.chatRunning == true {
                    do {
                        let (subs, hasSess) = try await getAgentSubsTotal()
                        await MainActor.run {
                            self.subs = subs
                            self.hasSess = hasSess
                        }
                    } catch let error {
                        logger.error("getSubsTotal error: \(responseError(error))")
                    }
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000) // POPOPX: 5s interval to reduce battery drain (was 1s)
            }
        }
    }

    func stopTask() {
        task?.cancel()
        task = nil
    }
}

// Spec: spec/client/chat-list.md#ChatListSearchBar
struct ChatListSearchBar: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var chatTagsModel: ChatTagsModel
    @ObservedObject private var connectProgressManager = ConnectProgressManager.shared
    @Binding var searchMode: Bool
    @FocusState.Binding var searchFocussed: Bool
    @Binding var searchText: String
    @Binding var searchShowingPopopxLink: Bool
    @Binding var searchChatFilteredByPopopxLink: String?
    @Binding var tagsExpanded: Bool
    @Binding var parentSheet: SomeSheet<AnyView>?
    @State private var ignoreSearchTextChange = false

    var body: some View {
        VStack(spacing: 12) {
            if tagsExpanded || searchFocussed {
                ScrollView([.horizontal], showsIndicators: false) { TagsView(parentSheet: $parentSheet, searchText: $searchText) }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                    TextField(NSLocalizedString("Search or paste POPOPX link", comment: ""), text: $searchText)
                        .foregroundColor(searchShowingPopopxLink ? theme.colors.secondary : theme.colors.onBackground)
                        .disabled(searchShowingPopopxLink)
                        .focused($searchFocussed)
                        .frame(maxWidth: .infinity)
                    if connectProgressManager.showConnectProgress != nil {
                        // Compact connecting indicator with pulsing animation
                        Circle()
                            .fill(theme.colors.primary)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .strokeBorder(theme.colors.primary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            )
                    }
                    if !searchText.isEmpty {
                        Button {
                            triggerHapticFeedback(.light)
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                }
                .padding(12)
                .foregroundColor(theme.colors.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            QuantumGlass.iridescentBorderGradient(opacity: 0.15),
                            lineWidth: 0.5
                        )
                )
                .cornerRadius(12)
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.08) : .clear, radius: 8, x: 0, y: 2)

                if searchFocussed {
                    Text(LocalizedStringKey("Cancel"))
                        .foregroundColor(theme.colors.primary)
                        .onTapGesture {
                            searchText = ""
                            searchFocussed = false
                        }
                } else if m.chats.count > 0 {
                    HStack(spacing: 8) {
                        tagToggleButton()
                        toggleFilterButton()
                    }
                }
            }
        }
        .onChange(of: searchFocussed) {_,  sf in
            withAnimation { searchMode = sf }
            if !sf && searchText.isEmpty {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    tagsExpanded = false
                }
            }
        }
        .onChange(of: searchText) {_,  t in
            if ignoreSearchTextChange {
                ignoreSearchTextChange = false
            } else {
                switch strConnectTarget(t.trimmingCharacters(in: .whitespaces)) {
                case let .link(text, _, linkText):
                    searchFocussed = false
                    ignoreSearchTextChange = true
                    searchText = linkText
                    searchShowingPopopxLink = true
                    searchChatFilteredByPopopxLink = nil
                    connect(text)
                case let .name(nameInfo):
                    showUnsupportedNameAlert(nameInfo)
                case .none:
                    if t != "" {
                        searchFocussed = true
                    } else {
                        ConnectProgressManager.shared.cancelConnectProgress()
                    }
                    searchShowingPopopxLink = false
                    searchChatFilteredByPopopxLink = nil
                }
            }
        }
        .onChange(of: chatTagsModel.activeFilter) {_, _ in
            searchText = ""
        }
    }

    private func tagToggleButton() -> some View {
        return Button {
            triggerHapticFeedback(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tagsExpanded.toggle()
            }
        } label: {
            ZStack {
                Color.clear
                    .frame(width: 44, height: 44)
                Image(systemName: tagsExpanded ? "tag.fill" : "tag")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(tagsExpanded ? theme.colors.primary : theme.colors.secondary)
                    .frame(width: tagsExpanded ? 20 : 18, height: tagsExpanded ? 20 : 18)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(tagsExpanded ? NSLocalizedString("Hide tags", comment: "Accessibility label to hide tag filters") : NSLocalizedString("Show tags", comment: "Accessibility label to show tag filters"))
    }

    private func toggleFilterButton() -> some View {
        let showUnread = chatTagsModel.activeFilter == .unread
        return Button {
            triggerHapticFeedback(.light)
            if chatTagsModel.activeFilter == .unread {
                chatTagsModel.activeFilter = nil
            } else {
                chatTagsModel.activeFilter = .unread
            }
        } label: {
            ZStack {
                Color.clear
                    .frame(width: 44, height: 44)
                Image(systemName: showUnread ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(showUnread ? theme.colors.primary : theme.colors.secondary)
                    .frame(width: showUnread ? 22 : 18, height: showUnread ? 22 : 18)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(showUnread ? NSLocalizedString("Show all chats", comment: "Accessibility label for unread filter button when active") : NSLocalizedString("Show unread chats", comment: "Accessibility label for unread filter button"))
    }

    private func connect(_ link: String) {
        planAndConnect(
            link,
            theme: theme,
            dismiss: false,
            cleanup: {
                searchText = ""
                searchFocussed = false
            },
            filterKnownContact: { searchChatFilteredByPopopxLink = $0.id },
            filterKnownGroup: { searchChatFilteredByPopopxLink = $0.id }
        )
    }
}

struct TagsView: View {
    @EnvironmentObject var chatTagsModel: ChatTagsModel
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var parentSheet: SomeSheet<AnyView>?
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            tagsView()
        }
    }
    
    @ViewBuilder private func tagsView() -> some View {
        if chatTagsModel.presetTags.count > 1 {
            if chatTagsModel.presetTags.count + chatTagsModel.userTags.count <= 3 {
                expandedPresetTagsFiltersView()
            } else {
                collapsedTagsFilterView()
                ForEach(PresetTag.allCases, id: \.id) { (tag: PresetTag) in
                    if !tag.сollapse && (chatTagsModel.presetTags[tag] ?? 0) > 0 {
                        expandedTagFilterView(tag)
                    }
                }
            }
        }
        let selectedTag: ChatTag? = if case let .userTag(tag) = chatTagsModel.activeFilter {
            tag
        } else {
            nil
        }
        ForEach(chatTagsModel.userTags, id: \.id) { tag in
            let current = tag == selectedTag
            ZStack {
                HStack(spacing: 5) {
                    if let emoji = tag.chatTagEmoji {
                        Text(emoji).font(.subheadline)
                    } else {
                        Image(systemName: current ? "tag.fill" : "tag")
                            .font(.system(.footnote).weight(current ? .semibold : .regular))
                    }
                    Text(tag.chatTagText).fontWeight(current ? .semibold : .regular)
                    if (chatTagsModel.unreadTags[tag.chatTagId] ?? 0) > 0 {
                        Circle()
                            .fill(theme.colors.primary)
                            .frame(width: 6, height: 6)
                    }
                }
                .font(.subheadline)
                .foregroundColor(current ? .white : theme.colors.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
                .background(
                    Capsule()
                        .fill(
                            current
                            ? AnyShapeStyle(LinearGradient(
                                colors: [theme.colors.primaryVariant, theme.colors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                              ))
                            : AnyShapeStyle(Color.clear)
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            current ? AnyShapeStyle(theme.colors.primaryVariant.opacity(0.4)) :
                            AnyShapeStyle(LinearGradient(
                                colors: [
                                    Color.white.opacity(isInDarkTheme() ? 0.15 : 0.5),
                                    Color.white.opacity(isInDarkTheme() ? 0.05 : 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: current ? theme.colors.primaryVariant.opacity(0.3) : .clear, radius: 6, x: 0, y: 2)
                .scaleEffect(current ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: current)
                .contentShape(Capsule())
                .onTapGesture {
                    setActiveFilter(filter: .userTag(tag))
                }
                .onLongPressGesture {
                    let screenHeight = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }?.screen.bounds.height ?? 800
                    let reservedSpace: Double = 4 * 44 // 2 for padding, 1 for "Create list" and another for extra tag
                    let tagsSpace = Double(max(chatTagsModel.userTags.count, 3)) * 44
                    let fraction = min((reservedSpace + tagsSpace) / screenHeight, 0.62)

                    parentSheet = SomeSheet(
                        content: {
                            AnyView(
                                NavigationStack {
                                    PXTagFilterList(chat: nil)
                                        .modifier(ThemedBackground(grouped: true))
                                }
                            )
                        },
                        id: "tag list",
                        fraction: fraction
                    )
                }
            }
        }
        
        Button {
            triggerHapticFeedback(.light)
            parentSheet = SomeSheet(
                content: {
                    AnyView(
                        NavigationStack {
                            TagListEditor()
                        }
                    )
                },
                id: "tag create"
            )
        } label: {
            if chatTagsModel.userTags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(.footnote).weight(.semibold))
                    Text(LocalizedStringKey("Add list")).fontWeight(.medium)
                }
                .font(.system(size: 12))
                .foregroundColor(theme.colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7) // Keep asymmetric for button height
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [theme.colors.primary.opacity(0.5), theme.colors.primaryVariant.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: theme.colors.primary.opacity(0.15), radius: 4, x: 0, y: 1)
                .frame(minHeight: 44) // Ensure minimum touch target
                .contentShape(Capsule())
            } else {
                Image(systemName: "plus")
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundColor(theme.colors.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
                    .overlay(
                        Circle()
                            .strokeBorder(theme.colors.primary.opacity(0.3), lineWidth: 0.8)
                    )
                    .contentShape(Circle())
            }
        }
        .accessibilityLabel(NSLocalizedString("Create new chat list", comment: "Accessibility label for tag creation button"))
    }

    @ViewBuilder private func expandedTagFilterView(_ tag: PresetTag) -> some View {
        let selectedPresetTag: PresetTag? = if case let .presetTag(tag) = chatTagsModel.activeFilter {
            tag
        } else {
            nil
        }
        let active = tag == selectedPresetTag
        let (icon, menuIcon, text) = presetTagLabel(tag: tag, active: active)

        HStack(spacing: 5) {
            Image(systemName: menuIcon ?? icon)
                .font(.system(.footnote).weight(active ? .semibold : .regular))
            Text(text).fontWeight(active ? .semibold : .regular)
        }
        .font(.subheadline)
        .foregroundColor(active ? .white : theme.colors.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.08))
        )
        .background(
            Capsule()
                .fill(
                    active
                    ? AnyShapeStyle(LinearGradient(
                        colors: [theme.colors.primary, theme.colors.primaryVariant],
                        startPoint: .leading,
                        endPoint: .trailing
                      ))
                    : AnyShapeStyle(Color.clear)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    active ? AnyShapeStyle(theme.colors.primary.opacity(0.4)) :
                    AnyShapeStyle(LinearGradient(
                        colors: [
                            Color.white.opacity(isInDarkTheme() ? 0.15 : 0.5),
                            Color.white.opacity(isInDarkTheme() ? 0.05 : 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )),
                    lineWidth: 0.5
                )
        )
        .shadow(color: active ? theme.colors.primary.opacity(0.35) : .clear, radius: 6, x: 0, y: 2)
        .scaleEffect(active ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: active)
        .contentShape(Capsule())
        .onTapGesture {
            setActiveFilter(filter: .presetTag(tag))
        }
    }

    private func expandedPresetTagsFiltersView() -> some View {
        ForEach(PresetTag.allCases, id: \.id) { tag in
            if (chatTagsModel.presetTags[tag] ?? 0) > 0 {
                expandedTagFilterView(tag)
            }
        }
    }
    
    @ViewBuilder private func collapsedTagsFilterView() -> some View {
        let selectedPresetTag: PresetTag? = if case let .presetTag(tag) = chatTagsModel.activeFilter {
            tag
        } else {
            nil
        }
        let hasSelection = selectedPresetTag != nil && (selectedPresetTag?.сollapse ?? false)
        Menu {
            if chatTagsModel.activeFilter != nil || !searchText.isEmpty {
                Button {
                    chatTagsModel.activeFilter = nil
                    searchText = ""
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text(LocalizedStringKey("All"))
                    }
                }
            }
            ForEach(PresetTag.allCases, id: \.id) { tag in
                if (chatTagsModel.presetTags[tag] ?? 0) > 0 && tag.сollapse {
                    Button {
                        setActiveFilter(filter: .presetTag(tag))
                    } label: {
                        let (icon, _, text) = presetTagLabel(tag: tag, active: tag == selectedPresetTag)
                        HStack {
                            Image(systemName: icon)
                            Text(text)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let tag = selectedPresetTag, tag.сollapse {
                    let (icon, menuIcon, _) = presetTagLabel(tag: tag, active: true)
                    Image(systemName: menuIcon ?? icon)
                        .font(.system(.footnote).weight(.semibold))
                } else {
                    Image(systemName: "list.bullet")
                        .font(.system(.footnote).weight(.medium))
                }
            }
            .foregroundColor(hasSelection ? .white : theme.colors.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
            .background(
                Capsule()
                    .fill(hasSelection
                        ? AnyShapeStyle(LinearGradient(
                            colors: [theme.colors.primary, theme.colors.primaryVariant],
                            startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.clear)
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        hasSelection ? AnyShapeStyle(theme.colors.primary.opacity(0.4)) :
                        AnyShapeStyle(LinearGradient(
                            colors: [
                                Color.white.opacity(isInDarkTheme() ? 0.15 : 0.5),
                                Color.white.opacity(isInDarkTheme() ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: hasSelection ? theme.colors.primary.opacity(0.35) : .clear, radius: 6, x: 0, y: 2)
        }
        .frame(minHeight: 32)
    }
    
    private func presetTagLabel(tag: PresetTag, active: Bool) -> (item: String, menu: String?, label: LocalizedStringKey) {
        switch tag {
        case .groupReports: (item: active ? "flag.fill" : "flag", menu: nil, label: "Reports")
        case .favorites: (item: active ? "star.fill" : "star", menu: nil, label: "Favorites")
        case .contacts: (item: active ? "person.fill" : "person", menu: nil, label: "Contacts")
        case .groups: (item: active ? "person.2.fill" : "person.2", menu: nil, label: "Groups")
        case .channels: (item: active ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right", menu: "antenna.radiowaves.left.and.right", label: "Channels")
        case .business: (item: active ? "briefcase.fill" : "briefcase", menu: nil, label: "Businesses")
        case .notes: (item: active ? "folder.fill" : "folder", menu: nil, label: "Notes")
        }
    }

    // Spec: spec/client/chat-list.md#setActiveFilter
    private func setActiveFilter(filter: ActiveFilter) {
        if filter != chatTagsModel.activeFilter {
            chatTagsModel.activeFilter = filter
        } else {
            chatTagsModel.activeFilter = nil
        }
    }
}

func chatStoppedIcon() -> some View {
    Button {
        AlertManager.shared.showAlertMsg(
            title: LocalizedStringKey("Chat is stopped"),
            message: LocalizedStringKey(NSLocalizedString("chat_list_start_chat_hint", comment: ""))
        )
    } label: {
        Image(systemName: "exclamationmark.octagon.fill").foregroundColor(QuantumColors.error)
    }
}

// Spec: spec/client/chat-list.md#presetTagMatchesChat
func presetTagMatchesChat(_ tag: PresetTag, _ chatInfo: ChatInfo, _ chatStats: ChatStats) -> Bool {
    switch tag {
    case .groupReports:
        chatStats.reportsCount > 0
    case .favorites:
        chatInfo.chatSettings?.favorite == true
    case .contacts:
        switch chatInfo {
        case let .direct(contact): !contact.isContactCard && !contact.chatDeleted
        case .contactRequest: true
        case .contactConnection: true
        case let .group(groupInfo, _): groupInfo.businessChat?.chatType == .customer
        default: false
        }
    case .groups:
        switch chatInfo {
        case let .group(groupInfo, _): groupInfo.businessChat == nil && !groupInfo.isChannel
        default: false
        }
    case .channels:
        switch chatInfo {
        case let .group(groupInfo, _): groupInfo.isChannel
        default: false
        }
    case .business:
        chatInfo.groupInfo?.businessChat?.chatType == .business
    case .notes:
        switch chatInfo {
        case .local: true
        default: false
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    @State static var userPickerSheet: UserPickerSheet? = .none

    static var previews: some View {
        let chatModel = ChatModel()
        chatModel.updateChats([
            ChatData(
                chatInfo: ChatInfo.sampleData.direct,
                chatItems: [ChatItem.getSample(1, .directSnd, .now, "hello")]
            ),
            ChatData(
                chatInfo: ChatInfo.sampleData.group,
                chatItems: [ChatItem.getSample(1, .directSnd, .now, "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")]
            ),
            ChatData(
                chatInfo: ChatInfo.sampleData.contactRequest,
                chatItems: []
            )

        ])
        return Group {
            ChatListView(activeUserPickerSheet: $userPickerSheet)
                .environmentObject(chatModel)
                .environmentObject(AppTheme.shared)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(ComputeStore.shared)
            ChatListView(activeUserPickerSheet: $userPickerSheet)
                .environmentObject(ChatModel())
                .environmentObject(AppTheme.shared)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(ComputeStore.shared)
        }
    }
}
