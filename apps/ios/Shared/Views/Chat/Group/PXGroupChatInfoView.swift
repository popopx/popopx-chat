//
//  GroupChatInfoView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 14.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

let SMALL_GROUPS_RCPS_MEM_LIMIT: Int = 20

// Spec: spec/client/chat-view.md#GroupChatInfoView
struct GroupChatInfoView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @ObservedObject var chat: Chat
    @Binding var groupInfo: GroupInfo
    @Binding var scrollToItemId: ChatItem.ID?
    @Binding var composeState: ComposeState
    var onSearch: () -> Void
    @State var localAlias: String
    @State private var showSharePicker = false
    @FocusState private var aliasTextFieldFocused: Bool
    @State private var alert: GroupChatInfoViewAlert? = nil
    @State private var groupLink: GroupLink?
    @State private var groupLinkMemberRole: GroupMemberRole = .member
    @State private var groupLinkNavLinkActive: Bool = false
    @State private var addMembersNavLinkActive: Bool = false
    @State private var connectionStats: ConnectionStats?
    @State private var connectionCode: String?
    @State private var sendReceipts = SendReceipts.userDefault(true)
    @State private var sendReceiptsUserDefault = true
    @State private var progressIndicator = false
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @State private var searchText: String = ""
    @FocusState private var searchFocussed
    @State private var showSecrets: Set<Int> = []

    enum GroupChatInfoViewAlert: Identifiable {
        case deleteGroupAlert
        case clearChatAlert
        case leaveGroupAlert
        case cantInviteIncognitoAlert
        case largeGroupReceiptsDisabled
        case blockMemberAlert(mem: GroupMember)
        case unblockMemberAlert(mem: GroupMember)
        case blockForAllAlert(mem: GroupMember)
        case unblockForAllAlert(mem: GroupMember)
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .deleteGroupAlert: return "deleteGroupAlert"
            case .clearChatAlert: return "clearChatAlert"
            case .leaveGroupAlert: return "leaveGroupAlert"
            case .cantInviteIncognitoAlert: return "cantInviteIncognitoAlert"
            case .largeGroupReceiptsDisabled: return "largeGroupReceiptsDisabled"
            case let .blockMemberAlert(mem): return "blockMemberAlert \(mem.groupMemberId)"
            case let .unblockMemberAlert(mem): return "unblockMemberAlert \(mem.groupMemberId)"
            case let .blockForAllAlert(mem): return "blockForAllAlert \(mem.groupMemberId)"
            case let .unblockForAllAlert(mem): return "unblockForAllAlert \(mem.groupMemberId)"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            let members = chatModel.groupMembers
                .filter { m in let status = m.wrapped.memberStatus; return status != .memLeft && status != .memRemoved }
                .sorted { $0.wrapped.memberRole > $1.wrapped.memberRole }

            ZStack {
                List {
                    groupInfoHeader()
                        .listRowBackground(Color.clear)

                    localAliasTextEdit()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.bottom, 18)

                    infoActionButtons()
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .frame(height: infoViewActionButtonHeight)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                    if groupInfo.useRelays && groupInfo.membership.memberIncognito {
                        Section(header: Text(NSLocalizedString("group_incognito", comment: "incognito section header"))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            HStack {
                                Text(NSLocalizedString("group_your_random_profile", comment: "your random profile info label"))
                                Spacer()
                                Text(groupInfo.membership.chatViewName)
                                    .foregroundStyle(QuantumColors.accent)
                            }
                        }
                    }

                    let showUserSupportChat = groupInfo.membership.memberActive
                        && ((groupInfo.fullGroupPreferences.support.on && groupInfo.membership.memberRole < .moderator)
                            || groupInfo.membership.supportChat != nil)

                    if groupInfo.useRelays {
                        Section {
                            // TODO [relays] allow other owners to manage channel link (requires protocol changes to share link ownership)
                            if groupInfo.isOwner && groupLink != nil {
                                channelLinkButton()
                            } else if let link = groupInfo.groupProfile.publicGroup?.groupLink {
                                PXContactLinkQRCode(uri: link)
                                Button {
                                    showShareSheet(items: [popopxChatLink(link)])
                                } label: {
                                    Label(NSLocalizedString("group_share_link", comment: "share link button"), systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    showSharePicker = true
                                } label: {
                                    Label(NSLocalizedString("group_share_via_chat", comment: "share via chat button"), systemImage: "arrowshape.turn.up.forward")
                                }
                            }
                            if groupInfo.isOwner || members.contains(where: { $0.wrapped.memberRole >= .owner }) {
                                channelMembersButton()
                            }
                            if groupInfo.membership.memberRole >= .moderator {
                                memberSupportButton()
                            }
                            if showUserSupportChat {
                                UserSupportChatNavLink(chat: chat, groupInfo: groupInfo, scrollToItemId: $scrollToItemId)
                            }
                        } footer: {
                            if !groupInfo.isOwner && groupInfo.groupProfile.publicGroup?.groupLink != nil {
                                Text(NSLocalizedString("group_share_link_footer", comment: "channel link share footer explanation"))
                                    .foregroundColor(theme.colors.secondary)
                            }
                        }
                    } else {
                        Section {
                            if groupInfo.canAddMembers && groupInfo.businessChat == nil {
                                groupLinkButton()
                            }
                            if groupInfo.businessChat == nil && groupInfo.membership.memberRole >= .moderator {
                                memberSupportButton()
                            }
                            if groupInfo.canModerate {
                                GroupReportsChatNavLink(chat: chat, groupInfo: groupInfo, scrollToItemId: $scrollToItemId)
                            }
                            if showUserSupportChat {
                                UserSupportChatNavLink(chat: chat, groupInfo: groupInfo, scrollToItemId: $scrollToItemId)
                            }
                        } header: {
                            Text("")
                        }
                    }

                    if groupInfo.useRelays && groupInfo.isOwner && groupLink != nil {
                        Section {
                            channelPopopxNameButton()
                        } header: {
                            if groupInfo.groupProfile.publicGroup?.publicGroupAccess?.groupDomainClaim?.shortName != nil {
                                Text(NSLocalizedString("group_channel_popopx_name", comment: "channel POPOPX name section header")).foregroundColor(theme.colors.secondary)
                            }
                        }
                    }

                    Section {
                        if groupInfo.isOwner && groupInfo.businessChat == nil {
                            editGroupButton()
                        }
                        if groupInfo.groupProfile.description != nil || (groupInfo.isOwner && groupInfo.businessChat == nil) {
                            addOrEditWelcomeMessage()
                        }
                        GroupPreferencesButton(groupInfo: $groupInfo, preferences: groupInfo.fullGroupPreferences, currentPreferences: groupInfo.fullGroupPreferences)
                    } footer: {
                        let label: LocalizedStringKey = (
                            groupInfo.useRelays
                            ? LocalizedStringKey(NSLocalizedString("group_prefs_footer_channel", comment: "only channel owners can change preferences footer"))
                            : groupInfo.businessChat == nil
                            ? LocalizedStringKey(NSLocalizedString("group_prefs_footer_group", comment: "only group owners can change preferences footer"))
                            : LocalizedStringKey(NSLocalizedString("group_prefs_footer_chat", comment: "only chat owners can change preferences footer"))
                        )
                        Text(label)
                            .foregroundColor(theme.colors.secondary)
                    }

                    Section {
                        if !groupInfo.useRelays {
                            if members.filter({ $0.wrapped.memberCurrent }).count <= SMALL_GROUPS_RCPS_MEM_LIMIT {
                                sendReceiptsOption()
                            } else {
                                sendReceiptsOptionDisabled()
                            }
                        }
                        NavigationLink {
                            PXChatWallpaperEditorSheet(chat: chat)
                        } label: {
                            Label(NSLocalizedString("group_chat_theme", comment: "chat theme navigation link"), systemImage: "photo")
                        }
                        ChatTTLOption(chat: chat, progressIndicator: $progressIndicator)
                    } footer: {
                        Text(NSLocalizedString("group_delete_messages_footer", comment: "delete chat messages footer"))
                    }

                    if !groupInfo.nextConnectPrepared && !groupInfo.useRelays {
                        Section(header: Text(verbatim: String(format: NSLocalizedString("group_members_count_fmt", comment: "number of members in group"), members.count + 1))
                            .font(isInDarkTheme() ? .subheadline.weight(.bold) : .caption)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            if groupInfo.canAddMembers {
                                if (chat.chatInfo.incognito) {
                                    Label(NSLocalizedString("group_invite_members", comment: "invite members label (disabled for incognito)"), systemImage: "plus")
                                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                                        .onTapGesture { alert = .cantInviteIncognitoAlert }
                                } else {
                                    addMembersButton()
                                }
                            }
                            searchFieldView(text: $searchText, focussed: $searchFocussed, theme.colors.onBackground, theme.colors.secondary)
                                .padding(.leading, 8)
                            let s = searchText.trimmingCharacters(in: .whitespaces).localizedLowercase
                            let filteredMembers = s == ""
                            ? members
                            : members.filter { $0.wrapped.localAliasAndFullName.localizedLowercase.contains(s) }
                            MemberRowView(
                                chat: chat,
                                groupInfo: groupInfo,
                                groupMember: GMember(groupInfo.membership),
                                scrollToItemId: $scrollToItemId,
                                user: true,
                                alert: $alert
                            )
                            ForEach(filteredMembers) { member in
                                MemberRowView(chat: chat, groupInfo: groupInfo, groupMember: member, scrollToItemId: $scrollToItemId, alert: $alert)
                            }
                        }
                    }

                    Section {
                        if groupInfo.useRelays && (groupInfo.isOwner || members.contains(where: { $0.wrapped.memberRole == .relay })) {
                            channelRelaysButton()
                        }
                        clearChatButton()
                        if groupInfo.canDelete {
                            deleteGroupButton()
                        }
                        if groupInfo.membership.memberCurrentOrPending {
                            if !groupInfo.useRelays || !groupInfo.isOwner
                                || members.contains(where: { $0.wrapped.memberRole == .owner && $0.wrapped.groupMemberId != groupInfo.membership.groupMemberId }) {
                                leaveGroupButton()
                            }
                        }
                    }

                    if groupInfo.useRelays && groupInfo.isOwner {
                        Section(header: Text(NSLocalizedString("group_advanced_options", comment: "advanced options section header")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            channelWebAccessButton()
                        }
                    }

                    if developerTools {
                        Section(header: Text(NSLocalizedString("group_for_console", comment: "section header for developer console information"))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            infoRow(LocalizedStringKey(NSLocalizedString("group_local_name", comment: "local name info row")), chat.chatInfo.localDisplayName)
                            infoRow(LocalizedStringKey(NSLocalizedString("group_database_id", comment: "database ID info row")), "\(chat.chatInfo.apiId)")
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .scrollContentBackground(.hidden)
                .modifier(ThemedBackground(grouped: true, glass: true))
                .toolbar(.hidden, for: .navigationBar)
                .disabled(progressIndicator)
                .opacity(progressIndicator ? 0.6 : 1)

                if progressIndicator {
                    ProgressView().scaleEffect(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showSharePicker) {
            shareChannelPicker(groupInfo: groupInfo, composeState: $composeState)
        }
        .alert(item: $alert) { alertItem in
            switch(alertItem) {
            case .deleteGroupAlert: return deleteGroupAlert(titleLabel:
                groupInfo.useRelays
                ? LocalizedStringKey(NSLocalizedString("group_delete_channel_question", comment: "delete channel alert title"))
                : groupInfo.businessChat == nil
                ? LocalizedStringKey(NSLocalizedString("group_delete_group_question", comment: "delete group alert title"))
                : LocalizedStringKey(NSLocalizedString("group_delete_chat_question", comment: "delete chat alert title"))
            )
            case .clearChatAlert: return clearChatAlert()
            case .leaveGroupAlert: return leaveGroupAlert(
                titleLabel: groupInfo.useRelays
                    ? LocalizedStringKey(NSLocalizedString("group_leave_channel_question", comment: "leave channel alert title"))
                    : groupInfo.businessChat == nil
                    ? LocalizedStringKey(NSLocalizedString("group_leave_group_question", comment: "leave group alert title"))
                    : LocalizedStringKey(NSLocalizedString("group_leave_chat_question", comment: "leave chat alert title")),
                messageLabel: groupInfo.useRelays
                    ? LocalizedStringKey(NSLocalizedString("group_leave_channel_message", comment: "leave channel alert message"))
                    : groupInfo.businessChat == nil
                    ? LocalizedStringKey(NSLocalizedString("group_leave_group_message", comment: "leave group alert message"))
                    : LocalizedStringKey(NSLocalizedString("group_leave_chat_message", comment: "leave chat alert message"))
            )
            case .cantInviteIncognitoAlert: return cantInviteIncognitoAlert()
            case .largeGroupReceiptsDisabled: return largeGroupReceiptsDisabledAlert()
            case let .blockMemberAlert(mem): return blockMemberAlert(groupInfo, mem)
            case let .unblockMemberAlert(mem): return unblockMemberAlert(groupInfo, mem)
            case let .blockForAllAlert(mem): return blockForAllAlert(groupInfo, mem)
            case let .unblockForAllAlert(mem): return unblockForAllAlert(groupInfo, mem)
            case let .error(title, error): return mkAlert(title: title, message: error)
            }
        }
        .onAppear {
            if let currentUser = chatModel.currentUser {
                sendReceiptsUserDefault = currentUser.sendRcptsSmallGroups
            }
            sendReceipts = SendReceipts.fromBool(groupInfo.chatSettings.sendRcpts, userDefault: sendReceiptsUserDefault)
            if !groupInfo.useRelays || groupInfo.isOwner {
                do {
                    if let gLink = try apiGetGroupLink(groupInfo.groupId) {
                        groupLink = gLink
                        groupLinkMemberRole = gLink.acceptMemberRole
                    }
                } catch let error {
                    logger.error("GroupChatInfoView apiGetGroupLink: \(responseError(error))")
                }
            }
        }
        .popopxBranded()
    }

    private func groupInfoHeader() -> some View {
        VStack {
            let cInfo = chat.chatInfo
            // show actual display name, alias can be edited in this view
            let displayName = (cInfo.groupInfo?.groupProfile.displayName ?? cInfo.displayName).trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = cInfo.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            ChatInfoImage(chat: chat, size: 192, color: Color(uiColor: .tertiarySystemFill))
                .padding(.top, 12)
                .padding()
            Text(displayName)
                .font(isInDarkTheme() ? QuantumFonts.sectionHeader : .largeTitle)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.bottom, 2)
            if fullName != "" && fullName != displayName && fullName != cInfo.displayName.trimmingCharacters(in: .whitespacesAndNewlines) {
                Text(cInfo.fullName)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.bottom, 2)
            }
            if let descr = cInfo.shortDescr?.trimmingCharacters(in: .whitespacesAndNewlines), descr != "" {
                let r = markdownText(descr, textStyle: .subheadline, showSecrets: showSecrets, backgroundColor: theme.colors.background)
                msgTextResultView(r, Text(AttributedString(r.string)), showSecrets: $showSecrets, centered: true, smallFont: true)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // TODO [BLOCKED: requires apiSetPublicGroupAccess Haskell API for groupPopopxNameView]
            // groupPopopxNameView(groupInfo) { groupInfo = $0 }
            if let webPage = groupInfo.groupProfile.publicGroup?.publicGroupAccess?.groupWebPage,
               let url = URL(string: webPage) {
                Link(destination: url) {
                    Text(webPage)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            if groupInfo.useRelays,
               let count = groupInfo.groupSummary.publicMemberCount,
               count > 0 {
                Text(subscriberCountStr(count))
                    .font(.subheadline)
                    .foregroundColor(theme.colors.secondary)
                    .padding(.bottom, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func localAliasTextEdit() -> some View {
        TextField(NSLocalizedString("group_set_chat_name_placeholder", comment: "set chat name text field placeholder"), text: $localAlias)
            .disableAutocorrection(true)
            .focused($aliasTextFieldFocused)
            .submitLabel(.done)
            .onChange(of: aliasTextFieldFocused) {_,  focused in
                if !focused {
                    setGroupAlias()
                }
            }
            .onSubmit {
                setGroupAlias()
            }
            .multilineTextAlignment(.center)
            .foregroundColor(theme.colors.secondary)
    }

    private func setGroupAlias() {
        Task {
            do {
                if let gInfo = try await apiSetGroupAlias(groupId: chat.chatInfo.apiId, localAlias: localAlias) {
                    await MainActor.run {
                        chatModel.updateGroup(gInfo)
                    }
                }
            } catch {
                logger.error("setGroupAlias error: \(responseError(error))")
            }
        }
    }

    func infoActionButtons() -> some View {
        // GeometryReader is used here to divide available width into 4 equal button widths
        // This requires knowing the actual parent width at runtime
        GeometryReader { g in
            let buttonWidth = g.size.width / 4
            HStack(alignment: .center, spacing: 8) {
                searchButton(width: buttonWidth)
                if groupInfo.useRelays && groupInfo.isOwner {
                    channelLinkActionButton(width: buttonWidth)
                } else if !groupInfo.useRelays && groupInfo.canAddMembers {
                    addMembersActionButton(width: buttonWidth)
                }
                if let nextNtfMode = chat.chatInfo.nextNtfMode {
                    muteButton(width: buttonWidth, nextNtfMode: nextNtfMode)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.08) : .clear, radius: 6, x: 0, y: 2)
    }

    private func searchButton(width: CGFloat) -> some View {
        InfoViewButton(image: "magnifyingglass", title: "search", width: width) {
            dismiss()
            onSearch()
        }
        .disabled(!groupInfo.ready || chat.chatItems.isEmpty)
    }

    private func addMembersActionButton(width: CGFloat) -> some View {
        ZStack {
            if chat.chatInfo.incognito {
                InfoViewButton(image: "link.badge.plus", title: "invite", width: width) {
                    groupLinkNavLinkActive = true
                }
            } else {
                InfoViewButton(image: "person.fill.badge.plus", title: "invite", width: width) {
                    addMembersNavLinkActive = true
                }
            }
        }
        .disabled(!groupInfo.ready)
        .navigationDestination(isPresented: $groupLinkNavLinkActive) {
            groupLinkDestinationView()
        }
        .navigationDestination(isPresented: $addMembersNavLinkActive) {
            addMembersDestinationView()
        }
    }

    private func muteButton(width: CGFloat, nextNtfMode: MsgFilter) -> some View {
        return InfoViewButton(
            image: nextNtfMode.iconFilled,
            title: "\(nextNtfMode.text(mentions: true))",
            width: width
        ) {
            toggleNotifications(chat, enableNtfs: nextNtfMode)
        }
        .disabled(!groupInfo.ready)
    }

    private func channelLinkActionButton(width: CGFloat) -> some View {
        ZStack {
            InfoViewButton(image: "link", title: "link", width: width) {
                groupLinkNavLinkActive = true
            }
        }
        .disabled(!groupInfo.ready)
        .navigationDestination(isPresented: $groupLinkNavLinkActive) {
            groupLinkDestinationView()
        }
    }

    private func addMembersButton() -> some View {
        let label: LocalizedStringKey = switch groupInfo.businessChat?.chatType {
            case .customer: LocalizedStringKey(NSLocalizedString("group_add_team_members", comment: "add team members button"))
            case .business: LocalizedStringKey(NSLocalizedString("group_add_friends", comment: "add friends button"))
            case .none: LocalizedStringKey(NSLocalizedString("group_invite_members_action", comment: "invite members button"))
        }
        return NavigationLink {
            addMembersDestinationView()
        } label: {
            Label(label, systemImage: "plus")
        }
    }

    private func addMembersDestinationView() -> some View {
        PXAddGroupMembers(chat: chat, groupInfo: groupInfo)
            .onAppear {
                searchFocussed = false
                Task {
                    await chatModel.loadGroupMembers(groupInfo)
                }
            }
    }

    private struct MemberRowView: View {
        var chat: Chat
        var groupInfo: GroupInfo
        @ObservedObject var groupMember: GMember
        @Binding var scrollToItemId: ChatItem.ID?
        @EnvironmentObject var theme: AppTheme
        var user: Bool = false
        @Binding var alert: GroupChatInfoViewAlert?

        var body: some View {
            let member = groupMember.wrapped
            let v1 = HStack{
                MemberProfileImage(member, size: 38)
                    .padding(.trailing, 2)
                // TODO [BLOCKED: upstream doesn't provide per-member server connection status]
                VStack(alignment: .leading) {
                    let nameColor = member.memberIncognito ? QuantumColors.accent : theme.colors.onBackground
                    let nameText = member.verified
                        ? pxVerifiedNameText(displayName: member.chatViewName, shieldColor: theme.colors.secondary, nameColor: nameColor)
                        : Text(member.chatViewName).foregroundColor(nameColor)
                    NameWithBadge(nameText, member.nameBadge)
                        .lineLimit(1)
                    (user ? Text(verbatim: "you: \(member.memberStatus.shortText)") : Text(memberConnStatus(member)))
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                }
                Spacer()
                memberInfo(member)
            }

            let v = ZStack {
                if user {
                    v1
                } else {
                    NavigationLink {
                        memberInfoView()
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)
                    v1
                }
            }

            if user {
                v
            } else if groupInfo.membership.memberRole >= .moderator {
                let canBlockForAll = member.canBlockForAll(groupInfo: groupInfo)
                let canRemove = member.canBeRemoved(groupInfo: groupInfo)
                if canBlockForAll && canRemove {
                    removeSwipe(member, blockForAllSwipe(member, v))
                } else if canBlockForAll {
                    blockForAllSwipe(member, v)
                } else if canRemove {
                    removeSwipe(member, v)
                } else {
                    v
                }
            } else {
                if !member.blockedByAdmin {
                    blockSwipe(member, v)
                } else {
                    v
                }
            }
        }

        private func memberInfoView() -> some View {
            PXGroupMemberDetail(groupInfo: groupInfo, chat: chat, groupMember: groupMember, scrollToItemId: $scrollToItemId)
                .toolbar(.visible, for: .navigationBar)
        }

        private func memberConnStatus(_ member: GroupMember) -> LocalizedStringKey {
            if case .failed = member.activeConn?.connStatus {
                return "failed"
            } else if member.activeConn?.connDisabled ?? false {
                return "disabled"
            } else if member.activeConn?.connInactive ?? false {
                return "inactive"
            } else {
                return member.memberStatus.shortText
            }
        }

        @ViewBuilder private func memberInfo(_ member: GroupMember) -> some View {
            if member.blocked {
                Text(NSLocalizedString("group_member_blocked", comment: "member blocked status label"))
                    .foregroundColor(theme.colors.secondary)
            } else {
                let role = member.memberRole
                if [.owner, .admin, .moderator, .observer].contains(role) {
                    Text(member.memberRole.text)
                        .foregroundColor(theme.colors.secondary)
                }
            }
        }

        private func blockSwipe<V: View>(_ member: GroupMember, _ v: V) -> some View {
            v.swipeActions(edge: .leading) {
                if member.memberSettings.showMessages {
                    Button {
                        alert = .blockMemberAlert(mem: member)
                    } label: {
                        Label(NSLocalizedString("group_swipe_block_member", comment: "swipe action: block member"), systemImage: "hand.raised").foregroundColor(theme.colors.secondary)
                    }
                } else {
                    Button {
                        alert = .unblockMemberAlert(mem: member)
                    } label: {
                        Label(NSLocalizedString("group_swipe_unblock_member", comment: "swipe action: unblock member"), systemImage: "hand.raised.slash").foregroundColor(theme.colors.primary)
                    }
                }
            }
        }

        private func blockForAllSwipe<V: View>(_ member: GroupMember, _ v: V) -> some View {
            v.swipeActions(edge: .leading) {
                if member.blockedByAdmin {
                    Button {
                        alert = .unblockForAllAlert(mem: member)
                    } label: {
                        Label(NSLocalizedString("group_swipe_unblock_for_all", comment: "swipe action: unblock for all"), systemImage: "hand.raised.slash").foregroundColor(theme.colors.primary)
                    }
                } else {
                    Button {
                        alert = .blockForAllAlert(mem: member)
                    } label: {
                        Label(NSLocalizedString("group_swipe_block_for_all", comment: "swipe action: block for all"), systemImage: "hand.raised").foregroundColor(theme.colors.secondary)
                    }
                }
            }
        }

        private func removeSwipe<V: View>(_ member: GroupMember, _ v: V) -> some View {
            v.swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    showRemoveMemberAlert(groupInfo, member)
                } label: {
                    Label(NSLocalizedString("group_swipe_remove_member", comment: "swipe action: remove member"), systemImage: "trash")
                        .foregroundColor(theme.colors.error)
                }
            }
        }
    }

    private func groupLinkButton() -> some View {
        NavigationLink {
            groupLinkDestinationView()
        } label: {
            if groupLink == nil {
                Label(NSLocalizedString("group_create_link", comment: "create group link button"), systemImage: "link.badge.plus")
            } else {
                Label(NSLocalizedString("group_group_link_label", comment: "group link button"), systemImage: "link")
            }
        }
    }

    private func channelLinkButton() -> some View {
        NavigationLink {
            groupLinkDestinationView()
        } label: {
            Label(NSLocalizedString("group_channel_link_label", comment: "channel link button"), systemImage: "link")
        }
    }

    private func channelWebAccessButton() -> some View {
        let title: LocalizedStringKey = groupInfo.isChannel
            ? LocalizedStringKey(NSLocalizedString("group_channel_webpage", comment: "channel webpage button title"))
            : LocalizedStringKey(NSLocalizedString("group_group_webpage", comment: "group webpage button title"))
        return NavigationLink {
            // TODO [TODO-FEATURE: medium] ChannelWebAccessView not implemented yet
            Text(NSLocalizedString("group_web_access_coming_soon", comment: "web access settings placeholder"))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            Label(title, systemImage: "globe")
        }
    }

    // TODO [BLOCKED: requires apiSetPublicGroupAccess Haskell API for channelPopopxNameButton]
    // private func channelPopopxNameButton() -> some View {
    //     NavigationLink {
    //         let domain = if let d = groupInfo.groupProfile.publicGroup?.publicGroupAccess?.groupDomainClaim?.shortName { "#\(d)" } else { "" }
    //         SetPopopxDomainView(
    //             title: "POPOPX name",
    //             footer: "Let people join via name registered with this channel link.",
    //             prompt: "#channelname.testing",
    //             popopxName: domain,
    //             save: { domain in
    //                 do {
    //                     var access = groupInfo.groupProfile.publicGroup?.publicGroupAccess ?? PublicGroupAccess()
    //                     access.groupDomainClaim = domain.map { PopopxDomainClaim(domain: $0) }
    //                     let gInfo = try await apiSetPublicGroupAccess(groupInfo.groupId, access: access)
    //                     await MainActor.run {
    //                         chatModel.updateGroup(gInfo)
    //                         groupInfo = gInfo
    //                     }
    //                     return true
    //                 } catch {
    //                     return false
    //                 }
    //             }
    //         )
    //     } label: {
    //         // Label content
    //     }
    // }

    private func channelPopopxNameButton() -> some View {
        EmptyView()
    }

    private func groupLinkDestinationView() -> some View {
        PXGroupLinkEditor(
            groupId: groupInfo.groupId,
            groupLink: $groupLink,
            groupLinkMemberRole: $groupLinkMemberRole,
            showTitle: false,
            creatingGroup: false,
            isChannel: groupInfo.useRelays,
            groupInfo: groupInfo,
            composeState: $composeState
        )
        .navigationTitle(groupInfo.useRelays
            ? NSLocalizedString("group_channel_link", comment: "channel link navigation title")
            : NSLocalizedString("group_group_link", comment: "group link navigation title"))
        .modifier(ThemedBackground(grouped: true))
        .navigationBarTitleDisplayMode(.large)
    }

    private func channelMembersButton() -> some View {
        let label: LocalizedStringKey = groupInfo.isOwner
            ? LocalizedStringKey(NSLocalizedString("group_subscribers", comment: "subscribers button title"))
            : LocalizedStringKey(NSLocalizedString("group_owners_contributors", comment: "owners and contributors button title"))
        return NavigationLink {
            ChannelMembersView(chat: chat, groupInfo: groupInfo)
                .navigationTitle(label)
                .modifier(ThemedBackground(grouped: true))
                .navigationBarTitleDisplayMode(.large)
        } label: {
            Label(label, systemImage: "person.2")
        }
    }

    private func channelRelaysButton() -> some View {
        NavigationLink {
            ChannelRelaysView(chat: chat, groupInfo: groupInfo)
                .navigationTitle(NSLocalizedString("group_chat_relays", comment: "chat relays navigation title"))
                .modifier(ThemedBackground(grouped: true))
                .navigationBarTitleDisplayMode(.large)
        } label: {
            Label(NSLocalizedString("group_chat_relays", comment: "chat relays button"), systemImage: "externaldrive.connected.to.line.below")
        }
    }

    private func memberSupportButton() -> some View {
        NavigationLink {
            PXMemberSupport(groupInfo: groupInfo, scrollToItemId: $scrollToItemId)
                .navigationTitle(NSLocalizedString("group_chats_with_members", comment: "chats with members navigation title"))
                .modifier(ThemedBackground())
                .navigationBarTitleDisplayMode(.large)
        } label: {
            HStack {
                Label(
                    NSLocalizedString("group_chats_with_members", comment: "chats with members button label"),
                    systemImage: chat.supportUnreadCount > 0 ? "flag.fill" : "flag"
                )
                Spacer()
                if chat.supportUnreadCount > 0 {
                    UnreadBadge(count: chat.supportUnreadCount, color: theme.colors.primary)
                }
            }
        }
    }

    private func editGroupButton() -> some View {
        NavigationLink {
            GroupProfileView(
                groupInfo: $groupInfo,
                groupProfile: groupInfo.groupProfile
            )
        } label: {
            Label(groupInfo.useRelays
                ? NSLocalizedString("group_edit_channel_profile", comment: "edit channel profile button")
                : NSLocalizedString("group_edit_group_profile", comment: "edit group profile button"), systemImage: "pencil")
        }
    }

    private func addOrEditWelcomeMessage() -> some View {
        NavigationLink {
            GroupWelcomeView(
                groupInfo: $groupInfo,
                groupProfile: groupInfo.groupProfile,
                welcomeText: groupInfo.groupProfile.description ?? ""
            )
            .navigationTitle(NSLocalizedString("group_welcome_message_title", comment: "welcome message navigation title"))
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
        } label: {
            groupInfo.groupProfile.description == nil
                ? Label(NSLocalizedString("group_add_welcome_message", comment: "add welcome message button"), systemImage: "plus.message")
                : Label(NSLocalizedString("group_welcome_message_label", comment: "welcome message button label"), systemImage: "message")
        }
    }

    @ViewBuilder private func deleteGroupButton() -> some View {
        let label: LocalizedStringKey = groupInfo.useRelays
            ? LocalizedStringKey(NSLocalizedString("group_delete_channel", comment: "delete channel button"))
            : groupInfo.businessChat == nil
            ? LocalizedStringKey(NSLocalizedString("group_delete_group", comment: "delete group button"))
            : LocalizedStringKey(NSLocalizedString("group_delete_chat", comment: "delete chat button"))
        Button(role: .destructive) {
            alert = .deleteGroupAlert
        } label: {
            Label(label, systemImage: "trash")
                .foregroundColor(theme.colors.error)
        }
    }

    private func clearChatButton() -> some View {
        Button() {
            alert = .clearChatAlert
        } label: {
            Label(NSLocalizedString("group_clear_conversation", comment: "clear conversation button"), systemImage: "gobackward")
                .foregroundColor(QuantumColors.warning)
        }
    }

    private func leaveGroupButton() -> some View {
        let label: LocalizedStringKey = groupInfo.useRelays
            ? LocalizedStringKey(NSLocalizedString("group_leave_channel", comment: "leave channel button"))
            : groupInfo.businessChat == nil
            ? LocalizedStringKey(NSLocalizedString("group_leave_group", comment: "leave group button"))
            : LocalizedStringKey(NSLocalizedString("group_leave_chat", comment: "leave chat button"))
        return Button(role: .destructive) {
            alert = .leaveGroupAlert
        } label: {
            Label(label, systemImage: "rectangle.portrait.and.arrow.right")
                .foregroundColor(theme.colors.error)
        }
    }

    // TODO [TODO-FEATURE: low] Reuse this and clearChatAlert with ChatInfoView
    private func deleteGroupAlert(titleLabel: LocalizedStringKey) -> Alert {
        return Alert(
            title: Text(titleLabel),
            message: Text("\(chat.chatInfo.displayName)\n\n\(deleteGroupAlertMessage(groupInfo))"),
            primaryButton: .destructive(Text(NSLocalizedString("group_delete_action", comment: "delete confirmation button"))) {
                Task {
                    do {
                        try await apiDeleteChat(type: chat.chatInfo.chatType, id: chat.chatInfo.apiId)
                        await MainActor.run {
                            dismiss()
                            chatModel.chatId = nil
                            chatModel.removeChat(chat.chatInfo.id)
                        }
                    } catch let error {
                        logger.error("deleteGroupAlert apiDeleteChat error: \(error.localizedDescription)")
                    }
                }
            },
            secondaryButton: .cancel()
        )
    }

    private func clearChatAlert() -> Alert {
        Alert(
            title: Text(NSLocalizedString("group_clear_conversation_question", comment: "clear conversation alert title")),
            message: Text(verbatim: "\(chat.chatInfo.displayName)\n\n\(NSLocalizedString("group_clear_chat_message", comment: "clear chat alert warning message"))"),
            primaryButton: .destructive(Text(NSLocalizedString("group_clear_action", comment: "clear confirmation button"))) {
                Task {
                    await clearChat(chat)
                    await MainActor.run { dismiss() }
                }
            },
            secondaryButton: .cancel()
        )
    }

    private func leaveGroupAlert(titleLabel: LocalizedStringKey, messageLabel: LocalizedStringKey) -> Alert {
        return Alert(
            title: Text(titleLabel),
            message: Text(verbatim: "\(chat.chatInfo.displayName)\n\n\(messageLabel)"),
            primaryButton: .destructive(Text(NSLocalizedString("group_leave_action", comment: "leave confirmation button"))) {
                Task {
                    await leaveGroup(chat.chatInfo.apiId)
                    await MainActor.run { dismiss() }
                }
            },
            secondaryButton: .cancel()
        )
    }

    private func sendReceiptsOption() -> some View {
        PXWrappedPicker(selection: $sendReceipts) {
            ForEach([.yes, .no, .userDefault(sendReceiptsUserDefault)]) { (opt: SendReceipts) in
                Text(opt.text)
            }
        } label: {
            Label(NSLocalizedString("group_send_receipts", comment: "send receipts option label"), systemImage: "checkmark.message")
        }
        .onChange(of: sendReceipts) {_, _ in
            setSendReceipts()
        }
    }

    private func setSendReceipts() {
        var chatSettings = chat.chatInfo.chatSettings ?? ChatSettings.defaults
        chatSettings.sendRcpts = sendReceipts.bool()
        updateChatSettings(chat, chatSettings: chatSettings)
    }

    private func sendReceiptsOptionDisabled() -> some View {
        HStack {
            Label(NSLocalizedString("group_send_receipts", comment: "send receipts option label"), systemImage: "checkmark.message")
            Spacer()
            Text(NSLocalizedString("group_receipts_disabled", comment: "send receipts disabled status"))
                .foregroundStyle(.secondary)
        }
        .onTapGesture {
            alert = .largeGroupReceiptsDisabled
        }
    }
}

// MARK: - POPOPX
fileprivate let _pxBrandGroupChatInfoView = "PX_GROUP_CHAT_INFO_VIEW"