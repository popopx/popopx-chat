//
//  NewChatMenuButton.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 28.11.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Config
private enum PXNewChatConfig {
    static let iconSize: CGFloat = 24
    static let indent: CGFloat = 36
    static let overlayOpacity: Double = 0.4
    static let progressPadding: CGFloat = 32
    static let progressCornerRadius: CGFloat = 16
    static let searchBarCornerRadius: CGFloat = 10
    static let progressScale: CGFloat = 1.5
    static let progressSpacing: CGFloat = 16
    static let overlayAnimationDuration: Double = 0.2
    static let searchIconSize: CGFloat = 16
    static let searchPadding: CGFloat = 7
    static let searchCornerRadius: CGFloat = 10
    static let filterIconSize: CGFloat = 22
    static let filterSmallIconSize: CGFloat = 16
}

// MARK: - POPOPX View Model
private struct PXNewChatMenuViewModel {
    let isConnectInProgress: Bool
    let overlayOpacity: Double = PXNewChatConfig.overlayOpacity
    let animationDuration: Double = PXNewChatConfig.overlayAnimationDuration
}

struct NewChatMenuButton: View {
    // do not use chatModel here because it prevents showing PXAddGroupMembers after group creation and QR code after link creation on iOS 16
//    @EnvironmentObject var chatModel: ChatModel
    @Binding var showNewChatSheet: Bool
    @State private var alert: SomeAlert? = nil

    var body: some View {
        pxButtonContainer
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxButtonContainer: some View {
        Button {
            pxHandleNewChatAction()
        } label: {
            pxPlusIcon
        }
        .alert(item: $alert) { a in
            return a.alert
        }
        .popopxBranded()
    }

    @ViewBuilder
    private var pxPlusIcon: some View {
        Image(systemName: "plus")
            .resizable()
            .scaledToFit()
            .frame(width: PXNewChatConfig.iconSize, height: PXNewChatConfig.iconSize)
            .accessibilityLabel(Text(NSLocalizedString("a11y_create_new_chat", comment: "")))
    }

    // MARK: - POPOPX Actions

    private func pxHandleNewChatAction() {
        ConnectProgressManager.shared.cancelConnectProgress()
        showNewChatSheet = true
    }
}

private var indent: CGFloat = PXNewChatConfig.indent

struct NewChatSheet: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject private var connectProgressManager = ConnectProgressManager.shared
    @State private var alert: SomeAlert?
    @State private var newDoc: EncryptedDocument?

    var body: some View {
        let showArchive = chatModel.chats.contains { $0.chatInfo.contact?.chatDeleted == true }
        pxSheetContainer(showArchive: showArchive)
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private func pxSheetContainer(showArchive: Bool) -> some View {
        NavigationStack {
            viewBody(showArchive)
                .navigationTitle(NSLocalizedString("new_chat_nav_title", comment: "New chat navigation title"))
                .navigationBarTitleDisplayMode(.large)
                .modifier(ThemedBackground(grouped: true, glass: true))
                .listRowBackground(Color.clear)
                .scrollContentBackground(.hidden)
                .alert(item: $alert) { a in
                    return a.alert
                }
                .sheet(item: $newDoc) { doc in
                    NavigationStack {
                        EncryptedDocView(document: doc)
                            .environmentObject(EncryptedDocManager.shared)
                    }
                }
                .overlay {
                    pxProgressOverlay
                }
                .animation(.easeInOut(duration: PXNewChatConfig.overlayAnimationDuration), value: connectProgressManager.isInProgress)
        }
        .onDisappear {
            ConnectProgressManager.shared.cancelConnectProgress()
        }
    }

    @ViewBuilder
    private var pxProgressOverlay: some View {
        if connectProgressManager.isInProgress {
            ZStack {
                Color.black.opacity(PXNewChatConfig.overlayOpacity)
                VStack(spacing: PXNewChatConfig.progressSpacing) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(PXNewChatConfig.progressScale)
                        .tint(.white)
                    Text(connectProgressManager.connectInProgressText)
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(PXNewChatConfig.progressPadding)
                .background(.ultraThinMaterial)
                .cornerRadius(PXNewChatConfig.progressCornerRadius)
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }

    private func viewBody(_ showArchive: Bool) -> some View {
        List {
            Section {
                NavigationLink {
                    PXNewChat(selection: .invite, hidePicker: true)
                        .modifier(ThemedBackground(grouped: true))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label(NSLocalizedString("create_1time_link_label", comment: "Create 1-time link label"), systemImage: "link.badge.plus")
                }
                NavigationLink {
                    PXNewChat(selection: .connect, showQRCodeScanner: true, hidePicker: true)
                        .modifier(ThemedBackground(grouped: true))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label(NSLocalizedString("scan_paste_link_label", comment: "Scan / Paste link label"), systemImage: "qrcode")
                }
                NavigationLink {
                    AddGroupView()
                        .navigationTitle(NSLocalizedString("create_group_nav_title", comment: "Create group navigation title"))
                        .modifier(ThemedBackground(grouped: true))
                        .navigationBarTitleDisplayMode(.large)
                } label: {
                    Label(NSLocalizedString("create_group_label", comment: "Create group label"), systemImage: "person.2.circle.fill")
                }
                NavigationLink {
                    PXChannelCreator()
                        .navigationTitle(NSLocalizedString("create_channel_nav_title", comment: "Create public channel navigation title"))
                        .modifier(ThemedBackground(grouped: true))
                        .navigationBarTitleDisplayMode(.large)
                } label: {
                    Label(NSLocalizedString("create_channel_label", comment: "Create public channel label"), systemImage: "antenna.radiowaves.left.and.right")
                }
                Button {
                    pxCreateEncryptedDocument()
                } label: {
                    Label(NSLocalizedString("encrypted_docs_label", comment: "Encrypted Docs label"), systemImage: "doc.text.fill")
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y_create_encrypted_document", comment: "")))
                NavigationLink {
                    ExtractionListView()
                        .modifier(ThemedBackground(grouped: true, glass: true))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label(NSLocalizedString("needle_extractions_label", comment: "Needle Extractions label"), systemImage: "sparkles")
                }
            }
            
            if (showArchive) {
                Section {
                    NavigationLink {
                        DeletedChats()
                    } label: {
                        newChatActionButton("archivebox", color: theme.colors.secondary) { Text(NSLocalizedString("newchat_archived_contacts", comment: "Archived contacts button")) }
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    // MARK: - POPOPX Actions

    private func pxCreateEncryptedDocument() {
        do {
            let doc = try EncryptedDocManager.shared.createDocument(title: NSLocalizedString("New Document", comment: "default document title"), content: "")
            newDoc = doc
        } catch {
            logger.error("EncryptedDocManager: failed to create document: \(error)")
        }
    }

    func newChatActionButton<Content : View>(_ icon: String, color: Color/* = .secondary*/, content: @escaping () -> Content) -> some View {
        ZStack(alignment: .leading) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: PXNewChatConfig.iconSize, maxHeight: PXNewChatConfig.iconSize, alignment: .center)
                .symbolRenderingMode(.monochrome)
                .foregroundColor(color)
            content().foregroundColor(theme.colors.onBackground).padding(.leading, indent)
        }
    }
}

@MainActor
func chatOrderRank(_ chat: Chat) -> Int {
    switch chat.chatInfo {
    case .contactRequest: 4
    case let .direct(contact):
        contact.isContactCard ? 5
        : contact.nextAcceptContactRequest ? 4
        : contact.nextConnectPrepared ? 3
        : contact.active ? 2
        : contact.chatDeleted ? 1
        : 0
    default: 0
    }
}

struct ContactsList: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var chatModel: ChatModel
    var chatPredicate: (Chat, Bool) -> Bool // (chat, search) -> show
    @Binding var searchMode: Bool
    @Binding var searchText: String
    var header: String? = nil
    @FocusState.Binding var searchFocussed: Bool
    @Binding var searchShowingPopopxLink: Bool
    @Binding var searchChatFilteredByPopopxLink: String?
    var showDeletedChatIcon: Bool
    @AppStorage(DEFAULT_SHOW_UNREAD_AND_FAVORITES) private var showUnreadAndFavorites = false
    
    var body: some View {
        let contactChats = chatModel.chats.filter { chat in chatPredicate(chat, !searchText.isEmpty) }
        let filteredContactChats = filteredContactChats(
            showUnreadAndFavorites: showUnreadAndFavorites,
            searchShowingPopopxLink: searchShowingPopopxLink,
            searchChatFilteredByPopopxLink: searchChatFilteredByPopopxLink,
            searchText: searchText,
            contactChats: contactChats
        )
        
        if !filteredContactChats.isEmpty {
            Section(header: Group {
                if let header = header {
                    Text(header)
                        .textCase(.uppercase)
                        .foregroundColor(theme.colors.secondary)
                    }
                }
            ) {
                ForEach(filteredContactChats, id: \.viewId) { chat in
                    ContactListNavLink(chat: chat, showDeletedChatIcon: showDeletedChatIcon)
                        .disabled(chatModel.chatRunning != true)
                }
            }
        }
        
        if filteredContactChats.isEmpty && !contactChats.isEmpty {
            pxNoResultSection(text: NSLocalizedString("No filtered contacts", comment: "contacts list empty state"))
        } else if contactChats.isEmpty {
            pxNoResultSection(text: NSLocalizedString("No contacts", comment: "contacts list empty state"))
        }
    }
    
    private func pxNoResultSection(text: String) -> some View {
        Section {
            Text(text)
                .foregroundColor(theme.colors.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
    }

    private func chatComparator(chat1: Chat, chat2: Chat) -> Bool {
        let r1 = chatOrderRank(chat1)
        let r2 = chatOrderRank(chat2)
        return r1 > r2 ? true : r1 < r2 ? false : chat1.chatInfo.chatTs > chat2.chatInfo.chatTs
    }
        
    private func filterChat(chat: Chat, searchText: String, showUnreadAndFavorites: Bool) -> Bool {
        var meetsPredicate = true
        let s = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cInfo = chat.chatInfo

        if !searchText.isEmpty {
            if (!cInfo.chatViewName.lowercased().contains(searchText.lowercased())) {
                if case let .direct(contact) = cInfo {
                    meetsPredicate = contact.profile.displayName.lowercased().contains(s) || contact.fullName.lowercased().contains(s)
                } else {
                    meetsPredicate = false
                }
            }
        }

        if showUnreadAndFavorites {
            meetsPredicate = meetsPredicate && (cInfo.chatSettings?.favorite ?? false)
        }

        return meetsPredicate
    }
    
    func filteredContactChats(
        showUnreadAndFavorites: Bool,
        searchShowingPopopxLink: Bool,
        searchChatFilteredByPopopxLink: String?,
        searchText: String,
        contactChats: [Chat]
    ) -> [Chat] {
        let linkChatId = searchChatFilteredByPopopxLink
        let s = searchShowingPopopxLink ? "" : searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filteredChats: [Chat]

        if let linkChatId = linkChatId {
            filteredChats = contactChats.filter { $0.id == linkChatId }
        } else {
            filteredChats = contactChats.filter { chat in
                filterChat(chat: chat, searchText: s, showUnreadAndFavorites: showUnreadAndFavorites)
            }
        }

        return filteredChats.sorted(by: chatComparator)
    }
}

struct ContactsListSearchBar: View {
    @EnvironmentObject var m: ChatModel
    @ObservedObject private var connectProgressManager = ConnectProgressManager.shared
    @EnvironmentObject var theme: AppTheme
    @Binding var searchMode: Bool
    @FocusState.Binding var searchFocussed: Bool
    @Binding var searchText: String
    @Binding var searchShowingPopopxLink: Bool
    @Binding var searchChatFilteredByPopopxLink: String?
    @Binding var connectNameCandidate: String?
    @State private var ignoreSearchTextChange = false
    @State private var linkProcessing = false
    @AppStorage(DEFAULT_SHOW_UNREAD_AND_FAVORITES) private var showUnreadAndFavorites = false

    var body: some View {
        HStack(spacing: 12) {
            pxSearchField
            pxTrailingControl
        }
        .padding(.top, 24)
        .onChange(of: searchFocussed) {_,  sf in
            withAnimation { searchMode = sf }
        }
        .onChange(of: searchText) {_,  t in
            pxHandleSearchTextChange(t)
        }
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxSearchField: some View {
        HStack(spacing: 4) {
            Spacer()
                .frame(width: 8)
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: PXNewChatConfig.searchIconSize, height: PXNewChatConfig.searchIconSize)
            TextField(NSLocalizedString("Search or paste POPOPX link", comment: ""), text: $searchText)
                .foregroundColor(searchShowingPopopxLink ? theme.colors.secondary : theme.colors.onBackground)
                .disabled(searchShowingPopopxLink)
                .focused($searchFocussed)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(NSLocalizedString("a11y_search_contacts_paste_link", comment: "")))
            if linkProcessing || connectProgressManager.showConnectProgress != nil {
                ProgressView()
                    .scaleEffect(0.8)
            }
            if !searchText.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: PXNewChatConfig.searchIconSize, height: PXNewChatConfig.searchIconSize)
                    .onTapGesture {
                        searchText = ""
                    }
                    .accessibilityLabel(Text(NSLocalizedString("a11y_clear_search", comment: "")))
            }
        }
        .padding(EdgeInsets(top: PXNewChatConfig.searchPadding, leading: PXNewChatConfig.searchPadding, bottom: PXNewChatConfig.searchPadding, trailing: PXNewChatConfig.searchPadding))
        .foregroundColor(theme.colors.secondary)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(PXNewChatConfig.searchCornerRadius)
    }

    @ViewBuilder
    private var pxTrailingControl: some View {
        if searchFocussed {
            Text(NSLocalizedString("search_cancel_button", comment: "Cancel search button"))
                .foregroundColor(theme.colors.primary)
                .onTapGesture {
                    searchText = ""
                    searchFocussed = false
                }
        } else if m.chats.count > 0 {
            pxToggleFilterButton
        }
    }

    @ViewBuilder
    private var pxToggleFilterButton: some View {
        ZStack {
            Color.clear
                .frame(width: PXNewChatConfig.filterIconSize, height: PXNewChatConfig.filterIconSize)
            Image(systemName: showUnreadAndFavorites ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                .resizable()
                .scaledToFit()
                .foregroundColor(showUnreadAndFavorites ? theme.colors.primary : theme.colors.secondary)
                .frame(width: showUnreadAndFavorites ? PXNewChatConfig.filterIconSize : PXNewChatConfig.filterSmallIconSize, height: showUnreadAndFavorites ? PXNewChatConfig.filterIconSize : PXNewChatConfig.filterSmallIconSize)
                .onTapGesture {
                    showUnreadAndFavorites = !showUnreadAndFavorites
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y_toggle_unread_favorites_filter", comment: "")))
        }
    }

    // MARK: - POPOPX Actions

    private func pxHandleSearchTextChange(_ t: String) {
        if ignoreSearchTextChange {
            ignoreSearchTextChange = false
        } else {
            let s = t.trimmingCharacters(in: .whitespaces)
            switch strConnectTarget(s) {
            case let .link(text, _, linkText):
                searchFocussed = false
                ignoreSearchTextChange = true
                searchText = linkText
                searchShowingPopopxLink = true
                searchChatFilteredByPopopxLink = nil
                connectNameCandidate = nil
                linkProcessing = true
                pxConnect(text)
            default:
                // A name is resolved only when its "Connect to …" row is tapped, not on every keystroke.
                // The popopx-name filter is chat-list only: this contacts/deleted view is a scoped
                // subset, so a resolved chat id (channel, business, unlisted or active-only contact)
                // may not be present in it.
                // TODO [TODO-FEATURE: medium] nameSearchCandidate not implemented
                // let candidate = nameSearchCandidate(s)
                // connectNameCandidate = candidate
                let candidate: String? = nil
                if candidate == nil {
                    if t != "" {
                        searchFocussed = true
                    } else {
                        connectProgressManager.cancelConnectProgress()
                        linkProcessing = false
                    }
                    searchShowingPopopxLink = false
                    searchChatFilteredByPopopxLink = nil
                }
            }
        }
    }

    private func pxConnect(_ link: String) {
        planAndConnect(
            link,
            theme: theme,
            dismiss: false,
            cleanup: {
                searchText = ""
                searchFocussed = false
                linkProcessing = false
            },
            filterKnownContact: { searchChatFilteredByPopopxLink = $0.id }
        )
    }
}


struct DeletedChats: View {
    @State private var searchMode = false
    @FocusState var searchFocussed: Bool
    @State private var searchText = ""
    @State private var searchShowingPopopxLink = false
    @State private var searchChatFilteredByPopopxLink: String? = nil
    // deleted contacts are not connected to by name, so this candidate only stops per-keystroke resolution
    @State private var connectNameCandidate: String? = nil

    var body: some View {
        List {
            ContactsListSearchBar(
                searchMode: $searchMode,
                searchFocussed: $searchFocussed,
                searchText: $searchText,
                searchShowingPopopxLink: $searchShowingPopopxLink,
                searchChatFilteredByPopopxLink: $searchChatFilteredByPopopxLink,
                connectNameCandidate: $connectNameCandidate
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .frame(maxWidth: .infinity)
            
            ContactsList(
                chatPredicate: { chat, _ in chat.chatInfo.contact?.chatDeleted == true },
                searchMode: $searchMode,
                searchText: $searchText,
                searchFocussed: $searchFocussed,
                searchShowingPopopxLink: $searchShowingPopopxLink,
                searchChatFilteredByPopopxLink: $searchChatFilteredByPopopxLink,
                showDeletedChatIcon: false
            )
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("archived_contacts_nav_title", comment: "Archived contacts navigation title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(searchMode ? .hidden : .visible, for: .navigationBar)
        .modifier(ThemedBackground(grouped: true))

    }
}

#Preview {
    NewChatMenuButton(showNewChatSheet: Binding.constant(false))
}

// MARK: - POPOPX
extension NewChatMenuButton {
    static let pxComponentTag: String = "PXNewChatMenuButton"
    static let pxIconSize: CGFloat = PXNewChatConfig.iconSize
}

extension NewChatSheet {
    static let pxOverlayOpacity: Double = PXNewChatConfig.overlayOpacity
    static let pxProgressPadding: CGFloat = PXNewChatConfig.progressPadding
    static let pxProgressCornerRadius: CGFloat = PXNewChatConfig.progressCornerRadius
    static let pxSearchBarCornerRadius: CGFloat = PXNewChatConfig.searchBarCornerRadius
}
