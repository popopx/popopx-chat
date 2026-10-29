//
//  PXGroupMemberDetail.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 25.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXGroupMemberDetailConfig {
    static let profileImageSize: CGFloat = 198
    static let headerBottomPadding: CGFloat = 22
    static let profileImageTopPadding: CGFloat = 14
    static let actionButtonSpacing: CGFloat = 10
    static let progressScale: CGFloat = 2.1
    static let progressShadowRadius: CGFloat = 4
    static let progressShadowOpacity: Double = 0.06
    static let infoRowSpacing: CGFloat = 6
    static let profileBorderWidth: CGFloat = 1.5
    static let connAnimDelay: Double = 0.35
    static let nameLineLimit: Int = 2
    static let fullNameLineLimit: Int = 3
    static let descrLineLimit: Int = 4
    static let serverHeaderIconSpacing: CGFloat = 6
}

// MARK: - POPOPX ViewModel
@MainActor
private struct PXGroupMemberDetailVM {
    let member: GroupMember
    let groupInfo: GroupInfo
    let connectionCode: String?
    let connectionStats: ConnectionStats?
    let openedFromSupportChat: Bool

    var showMemberSupportChat: Bool {
        !openedFromSupportChat
            && groupInfo.membership.memberRole >= .moderator
            && member.memberRole != .relay
            && ((groupInfo.fullGroupPreferences.support.on && member.memberRole < .moderator)
                || member.supportChat != nil)
    }

    var canVerifyCode: Bool {
        connectionCode != nil && member.memberRole != .relay
    }

    var canSyncConn: Bool {
        connectionStats?.ratchetSyncAllowed ?? false
    }

    var showActionButtonsRow: Bool {
        !groupInfo.useRelays
    }

    var isMemberActiveOrCurrent: Bool {
        member.memberActive || (groupInfo.useRelays && member.memberCurrent)
    }

    var showExtraActionsSection: Bool {
        isMemberActiveOrCurrent && (showMemberSupportChat || canVerifyCode || canSyncConn)
    }

    var channelMemberHeaderKey: String {
        if groupInfo.useRelays {
            switch member.memberRole {
            case .relay: return "group_member_relay"
            case .owner: return "group_member_owner"
            default: return "group_member_subscriber"
            }
        }
        return "group_member_label"
    }

    var relayFooterKey: String {
        groupInfo.isOwner ? "group_relay_footer_owner" : "group_relay_footer_member"
    }

    var groupOrChannelLabelKey: String {
        if groupInfo.useRelays { return "group_channel_label" }
        return groupInfo.businessChat == nil ? "group_group_label" : "group_chat_label"
    }
}

// MARK: - POPOPX Feature
private let pxGroupMemberFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")
private let pxConnAnimationEnabled = UserDefaults.standard.bool(forKey: "PX_CONN_ANIM_ENABLED")

struct PXGroupMemberDetail: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @State var groupInfo: GroupInfo
    @ObservedObject var chat: Chat
    @ObservedObject var groupMember: GMember
    @Binding var scrollToItemId: ChatItem.ID?
    var navigation: Bool = false
    var openedFromSupportChat: Bool = false
    var groupRelay: GroupRelay? = nil
    @State private var connectionStats: ConnectionStats? = nil
    @State private var connectionCode: String? = nil
    @State private var connectionLoaded: Bool = false
    @State private var knownContactChat: Chat? = nil
    @State private var knownContact: Contact? = nil
    @State private var knownContactConnectionStats: ConnectionStats? = nil
    @State private var newRole: GroupMemberRole = .member
    @State private var alert: PXGroupMemberDetailAlert?
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @State private var justOpened = true
    @State private var progressIndicator = false

    private var vm: PXGroupMemberDetailVM {
        PXGroupMemberDetailVM(
            member: groupMember.wrapped,
            groupInfo: groupInfo,
            connectionCode: connectionCode,
            connectionStats: connectionStats,
            openedFromSupportChat: openedFromSupportChat
        )
    }

    private var channelMemberSectionHeader: LocalizedStringKey {
        LocalizedStringKey(NSLocalizedString(vm.channelMemberHeaderKey, comment: "member section header"))
    }

    private var relaySectionFooter: LocalizedStringKey {
        LocalizedStringKey(NSLocalizedString(vm.relayFooterKey, comment: "relay section footer"))
    }

    enum PXGroupMemberDetailAlert: Identifiable {
        case blockMemberAlert(mem: GroupMember)
        case unblockMemberAlert(mem: GroupMember)
        case blockForAllAlert(mem: GroupMember)
        case unblockForAllAlert(mem: GroupMember)
        case changeMemberRoleAlert(mem: GroupMember, role: GroupMemberRole)
        case switchAddressAlert
        case abortSwitchAddressAlert
        case syncConnectionForceAlert
        case queueInfo(info: String)
        case someAlert(alert: SomeAlert)
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case let .blockMemberAlert(mem): return "blockMemberAlert \(mem.groupMemberId)"
            case let .unblockMemberAlert(mem): return "unblockMemberAlert \(mem.groupMemberId)"
            case let .blockForAllAlert(mem): return "blockForAllAlert \(mem.groupMemberId)"
            case let .unblockForAllAlert(mem): return "unblockForAllAlert \(mem.groupMemberId)"
            case let .changeMemberRoleAlert(mem, role): return "changeMemberRoleAlert \(mem.groupMemberId) \(role.rawValue)"
            case .switchAddressAlert: return "switchAddressAlert"
            case .abortSwitchAddressAlert: return "abortSwitchAddressAlert"
            case .syncConnectionForceAlert: return "syncConnectionForceAlert"
            case let .queueInfo(info): return "queueInfo \(info)"
            case let .someAlert(alert): return "someAlert \(alert.id)"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        Group {
        if navigation {
            NavigationStack { groupMemberInfoView() }
        } else {
            groupMemberInfoView()
        }
        }
        .popopxBranded()
    }

    private func knownDirectChat(_ contactId: Int64) -> (Chat, Contact)? {
        guard let pxChat = chatModel.getContactChat(contactId),
              let pxContact = pxChat.chatInfo.contact,
              pxContact.directOrUsed == true else {
            logger.debug("PX: [knownDirectChat] no direct chat for contactId=\(contactId)")
            return nil
        }
        logger.debug("PX: [knownDirectChat] found chat for contactId=\(contactId)")
        return (pxChat, pxContact)
    }

    private func groupMemberInfoView() -> some View {
        ZStack {
            let member = groupMember.wrapped
            List {
                groupMemberInfoHeader(member)
                                .listRowSeparator(.hidden)
                    .padding(.bottom, PXGroupMemberDetailConfig.headerBottomPadding)

                if vm.showActionButtonsRow {
                    infoActionButtons(member)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .frame(height: infoViewActionButtonHeight)
                                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                if connectionLoaded {
                    if vm.showExtraActionsSection {
                        Section {
                            if vm.showMemberSupportChat {
                                MemberInfoSupportChatNavLink(groupInfo: groupInfo, member: groupMember, scrollToItemId: $scrollToItemId)
                            }
                            if vm.canVerifyCode, let code = connectionCode {
                                verifyCodeButton(code)
                            }
                            if vm.canSyncConn {
                                synchronizeConnectionButton()
                            }
                        }
                    }

                    if let contactLink = member.contactLink {
                        Section {
                            PXContactLinkQRCode(uri: contactLink)
                            Button {
                                showShareSheet(items: [popopxChatLink(contactLink)])
                            } label: {
                                Label(NSLocalizedString("group_share_address", comment: "share member address button"), systemImage: "square.and.arrow.up")
                            }
                            if member.memberContactId != nil {
                                if knownContactChat == nil && !groupInfo.fullGroupPreferences.directMessages.on(for: groupInfo.membership) {
                                    connectViaAddressButton(contactLink)
                                }
                            } else {
                                connectViaAddressButton(contactLink)
                            }
                        } header: {
                            Text(NSLocalizedString("group_address_header", comment: "member address section header"))
                                .foregroundColor(theme.colors.secondary)
                        } footer: {
                            Text(String(format: NSLocalizedString("group_address_footer_fmt", comment: "member address section footer with display name"), member.displayName))
                                .foregroundColor(theme.colors.secondary)
                        }
                    }

                    Section {
                        let label: LocalizedStringKey = LocalizedStringKey(NSLocalizedString(vm.groupOrChannelLabelKey, comment: "group/channel label"))
                        infoRow(label, groupInfo.displayName)

                        if let roles = member.canChangeRoleTo(groupInfo: groupInfo) {
                            Picker(NSLocalizedString("group_change_role", comment: "change role picker label"), selection: $newRole) {
                                ForEach(roles) { role in
                                    Text(role.text)
                                }
                            }
                            .frame(height: 36)
                        } else {
                            infoRow(LocalizedStringKey(NSLocalizedString("group_role_label", comment: "member role info row label")), member.memberRole.text)
                        }
                        if let link = member.relayLink {
                            infoRow(LocalizedStringKey(NSLocalizedString("group_relay_link", comment: "relay link info row label")), String.localizedStringWithFormat(NSLocalizedString("via %@", comment: "relay hostname"), hostFromRelayLink(link)))
                        }
                        if let address = groupRelay?.userChatRelay.address {
                            infoRow(LocalizedStringKey(NSLocalizedString("group_relay_address", comment: "relay address info row label")), String.localizedStringWithFormat(NSLocalizedString("via %@", comment: "relay hostname"), hostFromRelayLink(address)))
                            Button {
                                showShareSheet(items: [popopxChatLink(address)])
                            } label: {
                                Label(NSLocalizedString("group_share_relay_address", comment: "share relay address button"), systemImage: "square.and.arrow.up")
                            }
                        }
                        if groupRelay?.relayStatus == .rejected {
                            infoRow(LocalizedStringKey(NSLocalizedString("group_status_label", comment: "status info row label")), NSLocalizedString("group_rejected_by_relay", comment: "rejected by relay operator status"))
                        }
                    } header: {
                        Text(channelMemberSectionHeader).foregroundColor(theme.colors.secondary)
                    } footer: {
                        if groupInfo.useRelays && member.memberRole == .relay {
                            Text(relaySectionFooter).foregroundColor(theme.colors.secondary)
                        }
                    }

                    if let connStats = connectionStats {
                        Section(header: Text(NSLocalizedString("group_servers_header", comment: "servers section header")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            if let subStatus = connStats.subStatus {
                                SubStatusRow(status: subStatus)
                                    .onTapGesture {
                                        showAlert(
                                            NSLocalizedString("Network status", comment: "alert title"),
                                            message: subStatus.statusExplanation
                                        )
                                    }
                            }
                            Button(NSLocalizedString("group_change_receiving_address", comment: "change receiving address button")) {
                                alert = .switchAddressAlert
                            }
                            .disabled(
                                connStats.rcvQueuesInfo.contains { $0.rcvSwitchStatus != nil }
                                || !member.sendMsgEnabled
                            )
                            if connStats.rcvQueuesInfo.contains(where: { $0.rcvSwitchStatus != nil }) {
                                Button(NSLocalizedString("group_abort_changing_address", comment: "abort changing address button")) {
                                    alert = .abortSwitchAddressAlert
                                }
                                .disabled(
                                    connStats.rcvQueuesInfo.contains { $0.rcvSwitchStatus != nil && !$0.canAbortSwitch }
                                    || !member.sendMsgEnabled
                                )
                            }
                            smpServers(LocalizedStringKey(NSLocalizedString("group_receiving_via", comment: "receiving via servers label")), connStats.rcvQueuesInfo.map { $0.rcvServer }, theme.colors.secondary)
                            smpServers(LocalizedStringKey(NSLocalizedString("group_sending_via", comment: "sending via servers label")), connStats.sndQueuesInfo.map { $0.sndServer }, theme.colors.secondary)
                        }
                    }

                    if let connFailedErr = member.activeConn?.connFailedErr {
                        Section {
                            Text(connFailedErr)
                                .foregroundColor(theme.colors.secondary)
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(theme.colors.error)
                                Text(NSLocalizedString("Connection failed", comment: "status when connection to member fails"))
                            }
                        }
                    }

                    if groupInfo.membership.memberRole >= .moderator {
                        adminDestructiveSection(member)
                    } else if !groupInfo.useRelays {
                        nonAdminBlockSection(member)
                    }

                    developerToolsSection(member)

                }

            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                justOpened = false
                newRole = member.memberRole
                do {
                    let (_, stats) = try await apiGroupMemberInfo(groupInfo.apiId, member.groupMemberId)
                    let getCode = (member.memberActive || (groupInfo.useRelays && member.memberCurrent)) && member.memberRole != .relay
                    let (mem, code) = getCode ? try await apiGetGroupMemberCode(groupInfo.apiId, member.groupMemberId) : (member, nil)
                    await MainActor.run {
                        _ = chatModel.upsertGroupMember(groupInfo, mem)
                        connectionStats = stats
                        connectionCode = code
                        connectionLoaded = true
                    }
                } catch let error {
                    await MainActor.run {
                        connectionLoaded = true
                    }
                    logger.error("apiGroupMemberInfo or apiGetGroupMemberCode error: \(responseError(error))")
                }
                if let contactId = member.memberContactId, let (contactChat, contact) = knownDirectChat(contactId) {
                    knownContactChat = contactChat
                    knownContact = contact
                    do {
                        let (stats, _) = try await apiContactInfo(contactChat.chatInfo.apiId)
                        await MainActor.run {
                            knownContactConnectionStats = stats
                        }
                    } catch let error {
                        logger.error("apiContactInfo error: \(responseError(error))")
                    }
                }
            }
            .onChange(of: newRole) {_,  newRole in
                if newRole != member.memberRole {
                    alert = .changeMemberRoleAlert(mem: member, role: newRole)
                }
            }
            .onChange(of: member.memberRole) {_,  role in
                newRole = role
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .alert(item: $alert) { alertItem in
                switch(alertItem) {
                case let .blockMemberAlert(mem): return blockMemberAlert(groupInfo, mem)
                case let .unblockMemberAlert(mem): return unblockMemberAlert(groupInfo, mem)
                case let .blockForAllAlert(mem): return blockForAllAlert(groupInfo, mem)
                case let .unblockForAllAlert(mem): return unblockForAllAlert(groupInfo, mem)
                case let .changeMemberRoleAlert(mem, _): return changeMemberRoleAlert(mem)
                case .switchAddressAlert: return switchAddressAlert(switchMemberAddress)
                case .abortSwitchAddressAlert: return abortSwitchAddressAlert(abortSwitchMemberAddress)
                case .syncConnectionForceAlert: return syncConnectionForceAlert({ syncMemberConnection(force: true) })
                case let .queueInfo(info): return queueInfoAlert(info)
                case let .someAlert(a): return a.alert
                case let .error(title, error): return mkAlert(title: title, message: error)
                }
            }

            if progressIndicator {
                ProgressView()
                    .scaleEffect(PXGroupMemberDetailConfig.progressScale)
                    .shadow(color: Color.black.opacity(PXGroupMemberDetailConfig.progressShadowOpacity), radius: PXGroupMemberDetailConfig.progressShadowRadius, x: 0, y: 1)
            }
        }
        .onChange(of: chat.chatInfo) {_,  c in
            if case let .group(gI, _) = chat.chatInfo {
                groupInfo = gI
            }
        }
        .modifier(ThemedBackground(grouped: true))
    }

    func infoActionButtons(_ member: GroupMember) -> some View {
        // GeometryReader is used here to divide available width into 4 equal button widths
        // This requires knowing the actual parent width at runtime
        GeometryReader { g in
            let buttonWidth = g.size.width / 4
            HStack(alignment: .center, spacing: PXGroupMemberDetailConfig.actionButtonSpacing) {
                if let chat = knownContactChat, let contact = knownContact {
                    knownDirectChatButton(chat, width: buttonWidth)
                    AudioCallButton(chat: chat, contact: contact, connectionStats: $knownContactConnectionStats, width: buttonWidth) { alert = .someAlert(alert: $0) }
                    VideoButton(chat: chat, contact: contact, connectionStats: $knownContactConnectionStats, width: buttonWidth) { alert = .someAlert(alert: $0) }
                } else if groupInfo.fullGroupPreferences.directMessages.on(for: groupInfo.membership) {
                    if let contactId = member.memberContactId {
                        newDirectChatButton(contactId, width: buttonWidth)
                    } else if member.versionRange.maxVersion >= CREATE_MEMBER_CONTACT_VERSION {
                        createMemberContactButton(member, width: buttonWidth)
                    }
                    InfoViewButton(image: "phone.fill", title: LocalizedStringKey(NSLocalizedString("group_btn_call", comment: "call button title")), disabledLook: true, width: buttonWidth) { showSendMessageToEnableCallsAlert()
                    }
                    InfoViewButton(image: "video.fill", title: LocalizedStringKey(NSLocalizedString("group_btn_video", comment: "video button title")), disabledLook: true, width: buttonWidth) { showSendMessageToEnableCallsAlert()
                    }
                } else { // no known contact chat && directMessages are off
                    InfoViewButton(image: "message.fill", title: LocalizedStringKey(NSLocalizedString("group_btn_message", comment: "message button title")), disabledLook: true, width: buttonWidth) { showDirectMessagesProhibitedAlert(LocalizedStringKey(NSLocalizedString("group_cant_message_member", comment: "can't message member alert title")))
                    }
                    InfoViewButton(image: "phone.fill", title: LocalizedStringKey(NSLocalizedString("group_btn_call", comment: "call button title")), disabledLook: true, width: buttonWidth) { showDirectMessagesProhibitedAlert(LocalizedStringKey(NSLocalizedString("group_cant_call_member", comment: "can't call member alert title")))
                    }
                    InfoViewButton(image: "video.fill", title: LocalizedStringKey(NSLocalizedString("group_btn_video", comment: "video button title")), disabledLook: true, width: buttonWidth) { showDirectMessagesProhibitedAlert(LocalizedStringKey(NSLocalizedString("group_cant_call_member", comment: "can't call member alert title")))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    func showSendMessageToEnableCallsAlert() {
        alert = .someAlert(alert: SomeAlert(
            alert: mkAlert(
                title: LocalizedStringKey(NSLocalizedString("group_cant_call_member", comment: "can't call member alert title")),
                message: LocalizedStringKey(NSLocalizedString("group_send_message_enable_calls", comment: "send message to enable calls alert message"))
            ),
            id: "can't call member, send message"
        ))
    }

    func showDirectMessagesProhibitedAlert(_ title: LocalizedStringKey) {
        let messageLabel: LocalizedStringKey = (
            groupInfo.businessChat == nil
            ? LocalizedStringKey(NSLocalizedString("group_direct_messages_prohibited", comment: "direct messages between members prohibited"))
            : LocalizedStringKey(NSLocalizedString("group_direct_messages_prohibited_chat", comment: "direct messages between members prohibited in this chat"))
        )
        alert = .someAlert(alert: SomeAlert(
            alert: mkAlert(
                title: title,
                message: messageLabel
            ),
            id: "can't message member, direct messages prohibited"
        ))
    }

    func connectViaAddressButton(_ contactLink: String) -> some View {
        Button {
            planAndConnect(
                contactLink,
                theme: theme,
                dismiss: true
            )
        } label: {
            Label(NSLocalizedString("group_connect_button", comment: "connect via address button"), systemImage: "link")
        }
    }

    func knownDirectChatButton(_ chat: Chat, width: CGFloat) -> some View {
        InfoViewButton(image: "message.fill", title: "message", width: width) {
            ItemsModel.shared.loadOpenChat(chat.id) {
                dismissAllSheets(animated: true)
            }
        }
        .accessibilityLabel(Text(NSLocalizedString("group_btn_message", comment: "message button")))
    }

    func newDirectChatButton(_ contactId: Int64, width: CGFloat) -> some View {
        InfoViewButton(image: "message.fill", title: "message", width: width) {
            Task {
                ItemsModel.shared.loadOpenChat("@\(contactId)") {
                    dismissAllSheets(animated: true)
                }
            }
        }
        .accessibilityLabel(Text(NSLocalizedString("group_btn_message", comment: "message button")))
    }

    func createMemberContactButton(_ member: GroupMember, width: CGFloat) -> some View {
        InfoViewButton(
            image: "message.fill",
            title: "message",
            disabledLook:
                !(
                    member.sendMsgEnabled ||
                    (member.activeConn?.connectionStats?.ratchetSyncAllowed ?? false)
                ),
            width: width
        ) {
            if member.sendMsgEnabled {
                progressIndicator = true
                Task {
                    do {
                        let memberContact = try await apiCreateMemberContact(groupInfo.apiId, groupMember.groupMemberId)
                        await MainActor.run {
                            progressIndicator = false
                            chatModel.addChat(Chat(chatInfo: .direct(contact: memberContact)))
                            ItemsModel.shared.loadOpenChat(memberContact.id) {
                                dismissAllSheets(animated: true)
                            }
                        }
                    } catch let error {
                        logger.error("createMemberContactButton apiCreateMemberContact error: \(responseError(error))")
                        await MainActor.run {
                            progressIndicator = false
                            AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error creating member contact", comment: "")))
                        }
                    }
                }
            } else if let connStats = connectionStats {
                if connStats.ratchetSyncAllowed {
                    alert = .someAlert(alert: SomeAlert(
                        alert: Alert(
                            title: Text(NSLocalizedString("group_fix_connection_question", comment: "fix connection alert title")),
                            message: Text(NSLocalizedString("group_encryption_renegotiation_needed", comment: "connection requires encryption renegotiation")),
                            primaryButton: .default(Text(NSLocalizedString("group_fix_button", comment: "fix connection button"))) {
                                syncMemberConnection(force: false)
                            },
                            secondaryButton: .cancel()
                        ),
                        id: "can't message member, fix connection"
                    ))
                } else if connStats.ratchetSyncInProgress {
                    alert = .someAlert(alert: SomeAlert(
                        alert: mkAlert(
                            title: LocalizedStringKey(NSLocalizedString("group_cant_message_member", comment: "can't message member alert title")),
                            message: LocalizedStringKey(NSLocalizedString("group_renegotiation_in_progress", comment: "encryption renegotiation in progress"))
                        ),
                        id: "can't message member, encryption renegotiation in progress"
                    ))
                } else {
                    alert = .someAlert(alert: SomeAlert(
                        alert: mkAlert(
                            title: LocalizedStringKey(NSLocalizedString("group_cant_message_member", comment: "can't message member alert title")),
                            message: LocalizedStringKey(NSLocalizedString("group_connection_not_ready", comment: "connection not ready"))
                        ),
                        id: "can't message member, connection not ready"
                    ))
                }
            }
        }
    }

    private func groupMemberInfoHeader(_ mem: GroupMember) -> some View {
        let darkTheme = isInDarkTheme()
        return VStack {
            MemberProfileImage(mem, size: PXGroupMemberDetailConfig.profileImageSize, color: theme.colors.secondary)
                .padding(.top, PXGroupMemberDetailConfig.profileImageTopPadding)
                .padding()
            // show alias if set, alias cannot be edited in this view
            let displayName = mem.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = mem.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let badge = mem.nameBadge
            let shieldColor = theme.colors.secondary
            let nameFont: Font = darkTheme ? QuantumFonts.sectionHeader : .largeTitle
            let nameColor: Color = darkTheme ? darkThemeAccentColor() : .primary
            let nameText = mem.verified
                ? pxVerifiedNameText(displayName: displayName, shieldColor: shieldColor, nameColor: nameColor, nameFont: nameFont)
                : Text(displayName).font(nameFont).foregroundColor(nameColor)
            NameWithBadge(nameText, badge, .largeTitle) { if let badge { showBadgeInfoAlert(displayName, badge) } }
                .multilineTextAlignment(.center)
                .lineLimit(PXGroupMemberDetailConfig.nameLineLimit)
                .padding(.bottom, 2)
            if fullName != "" && fullName != displayName && fullName != mem.memberProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines) {
                Text(mem.fullName)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .lineLimit(PXGroupMemberDetailConfig.fullNameLineLimit)
                    .padding(.bottom, 2)
            }
            if let descr = mem.memberProfile.shortDescr?.trimmingCharacters(in: .whitespacesAndNewlines), descr != "" {
                Text(descr)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(PXGroupMemberDetailConfig.descrLineLimit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    struct MemberInfoSupportChatNavLink: View {
        @EnvironmentObject var theme: AppTheme
        var groupInfo: GroupInfo
        var member: GMember
        @Binding var scrollToItemId: ChatItem.ID?

        var body: some View {
            let scopeInfo: GroupChatScopeInfo = .memberSupport(groupMember_: member.wrapped)
            NavigationLink {
                SecondaryChatView(
                    chat: Chat(chatInfo: .group(groupInfo: groupInfo, groupChatScope: scopeInfo), chatItems: [], chatStats: ChatStats()),
                    scrollToItemId: $scrollToItemId
                )
                .onAppear {
                    ItemsModel.loadSecondaryChat(groupInfo.id, chatFilter: .groupChatScopeContext(groupScopeInfo: scopeInfo))
                }
            } label: {
                Label(NSLocalizedString("group_chat_with_member", comment: "chat with member navigation link label"), systemImage: "flag")
            }
        }
    }

    private func verifyCodeButton(_ code: String) -> some View {
        let member = groupMember.wrapped
        return NavigationLink {
            VerifyCodeView(
                displayName: member.displayName,
                connectionCode: code,
                connectionVerified: member.verified,
                verify: { code in
                    var member = groupMember.wrapped
                    if let r = apiVerifyGroupMember(member.groupId, member.groupMemberId, connectionCode: code) {
                        let (verified, existingCode) = r
                        let connCode = verified ? SecurityCode(securityCode: existingCode, verifiedAt: .now) : nil
                        connectionCode = existingCode
                        if groupInfo.useRelays {
                            member.memberVerifiedCode = connCode
                        } else {
                            member.activeConn?.connectionCode = connCode
                        }
                        _ = chatModel.upsertGroupMember(groupInfo, member)
                        return r
                    }
                    return nil
                },
                verificationText: groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("group_verify_subscriber_code", comment: "verification text for subscriber")) : nil
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(NSLocalizedString("group_security_code_title", comment: "security code navigation title"))
            .modifier(ThemedBackground())
        } label: {
            Label(
                member.verified ? NSLocalizedString("group_view_security_code", comment: "view security code button") : NSLocalizedString("group_verify_security_code", comment: "verify security code button"),
                systemImage: member.verified ? "checkmark.shield" : "shield"
            )
        }
    }

    private func synchronizeConnectionButton() -> some View {
        Button {
            syncMemberConnection(force: false)
        } label: {
            Label(NSLocalizedString("group_fix_connection", comment: "fix connection button"), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                .foregroundColor(QuantumColors.warning)
        }
        .accessibilityLabel(Text(NSLocalizedString("group_fix_connection", comment: "fix connection button")))
    }

    private func synchronizeConnectionButtonForce() -> some View {
        Button {
            alert = .syncConnectionForceAlert
        } label: {
            Label(NSLocalizedString("group_renegotiate_encryption", comment: "renegotiate encryption button"), systemImage: "exclamationmark.triangle")
                .foregroundColor(theme.colors.error)
        }
    }

    @ViewBuilder private func adminDestructiveSection(_ mem: GroupMember) -> some View {
        let canBlockForAll = mem.canBlockForAll(groupInfo: groupInfo)
        let canRemove = mem.canBeRemoved(groupInfo: groupInfo)
        if canBlockForAll || canRemove {
            Section {
                if canBlockForAll {
                    if mem.blockedByAdmin {
                        unblockForAllButton(mem)
                    } else {
                        blockForAllButton(mem)
                    }
                }
                if canRemove {
                    if mem.memberStatus != .memRemoved && (mem.memberStatus != .memLeft || mem.memberRole == .relay) {
                        removeMemberButton(mem)
                    } else if mem.memberRole != .relay {
                        deleteMemberMessagesButton(mem)
                    }
                }
            }
        }
    }

    private func nonAdminBlockSection(_ mem: GroupMember) -> some View {
        Section {
            if mem.blockedByAdmin {
                Label(NSLocalizedString("group_blocked_by_admin", comment: "blocked by admin label"), systemImage: "hand.raised")
                    .foregroundColor(theme.colors.secondary)
            } else if mem.memberSettings.showMessages {
                blockMemberButton(mem)
            } else {
                unblockMemberButton(mem)
            }
        }
    }

    private func blockForAllButton(_ mem: GroupMember) -> some View {
        Button(role: .destructive) {
            alert = .blockForAllAlert(mem: mem)
        } label: {
            Label(NSLocalizedString("group_block_for_all", comment: "block member for all button"), systemImage: "hand.raised")
                .foregroundColor(theme.colors.error)
        }
    }

    private func unblockForAllButton(_ mem: GroupMember) -> some View {
        Button {
            alert = .unblockForAllAlert(mem: mem)
        } label: {
            Label(NSLocalizedString("group_unblock_for_all", comment: "unblock member for all button"), systemImage: "hand.raised.slash")
        }
    }

    private func blockMemberButton(_ mem: GroupMember) -> some View {
        Button(role: .destructive) {
            alert = .blockMemberAlert(mem: mem)
        } label: {
            Label(NSLocalizedString("group_block_member", comment: "block member button"), systemImage: "hand.raised")
                .foregroundColor(theme.colors.error)
        }
    }

    private func unblockMemberButton(_ mem: GroupMember) -> some View {
        Button {
            alert = .unblockMemberAlert(mem: mem)
        } label: {
            Label(NSLocalizedString("group_unblock_member", comment: "unblock member button"), systemImage: "hand.raised.slash")
        }
    }

    private func removeMemberButton(_ mem: GroupMember) -> some View {
        Button(role: .destructive) {
            showRemoveMemberAlert(groupInfo, mem, dismiss: dismiss)
        } label: {
            let text = mem.memberRole == .relay
                ? NSLocalizedString("group_remove_relay", comment: "remove relay button")
                : groupInfo.useRelays
                ? NSLocalizedString("group_remove_subscriber", comment: "remove subscriber button")
                : NSLocalizedString("group_remove_member", comment: "remove member button")
            Label(text, systemImage: "trash")
                .foregroundColor(theme.colors.error)
        }
    }

    private func deleteMemberMessagesButton(_ mem: GroupMember) -> some View {
        Button(role: .destructive) {
            showDeleteMemberMessagesAlert(mem)
        } label: {
            Label(NSLocalizedString("group_delete_member_messages", comment: "delete member messages button"), systemImage: "trash")
                .foregroundColor(theme.colors.error)
        }
    }

    func showDeleteMemberMessagesAlert(_ mem: GroupMember) {
        logger.debug("PX: [showDeleteMemberMessagesAlert] member=\(mem.groupMemberId)")
        let pxMemberName = mem.chatViewName
        showAlert(
            NSLocalizedString("Delete member messages?", comment: "alert title"),
            message: NSLocalizedString("Member messages will be deleted - this cannot be undone!", comment: "alert message"),
            actions: {[
                UIAlertAction(title: NSLocalizedString("Delete messages", comment: "alert action"), style: .destructive) { _ in
                    logger.debug("PX: [showDeleteMemberMessagesAlert] confirming delete for \(pxMemberName)")
                    removeMember(groupInfo, mem, withMessages: true, dismiss: dismiss)
                },
                cancelAlertAction
            ]}
        )
    }

    @ViewBuilder private func developerToolsSection(_ mem: GroupMember) -> some View {
        if developerTools {
            Section(header: Text(NSLocalizedString("group_for_console", comment: "section header for developer console information")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                infoRow(LocalizedStringKey(NSLocalizedString("group_local_name", comment: "local name info row")), mem.localDisplayName)
                infoRow(LocalizedStringKey(NSLocalizedString("group_database_id", comment: "database ID info row")), "\(mem.groupMemberId)")
                if let conn = mem.activeConn {
                    let connLevelDesc = conn.connLevel == 0 ? NSLocalizedString("direct", comment: "connection level description") : String.localizedStringWithFormat(NSLocalizedString("indirect (%d)", comment: "connection level description"), conn.connLevel)
                    infoRow(LocalizedStringKey(NSLocalizedString("group_connection_label", comment: "connection info row label")), connLevelDesc)
                }
                if !groupInfo.useRelays || mem.memberRole == .relay {
                    Button (NSLocalizedString("group_debug_delivery", comment: "debug delivery button")) {
                        Task {
                            do {
                                if let info = try await apiGroupMemberQueueInfo(groupInfo.apiId, mem.groupMemberId) {
                                    await MainActor.run { alert = .queueInfo(info: queueInfoText(info)) }
                                }
                            } catch let e {
                                logger.error("apiContactQueueInfo error: \(responseError(e))")
                                await MainActor.run {
                                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error", comment: "")))
                                }
                            }
                        }
                    }
                    .accessibilityLabel(Text(NSLocalizedString("group_debug_delivery", comment: "debug delivery button")))
                }
            }
        }
    }

    private func changeMemberRoleAlert(_ mem: GroupMember) -> Alert {
        Alert(
            title: Text(NSLocalizedString("Change role?", comment: "alert title for changing member role")),
            message: (
                mem.memberCurrent
                ? (
                    groupInfo.isChannel
                    ? Text(String(format: NSLocalizedString("Role will be changed to \"%@\". All subscribers will be notified.", comment: "alert message for role change"), newRole.text))
                    : groupInfo.businessChat == nil
                    ? Text(String(format: NSLocalizedString("Role will be changed to \"%@\". All group members will be notified.", comment: "alert message for role change in group"), newRole.text))
                    : Text(String(format: NSLocalizedString("Role will be changed to \"%@\". All chat members will be notified.", comment: "alert message for role change in chat"), newRole.text))
                )
                : Text(String(format: NSLocalizedString("Role will be changed to \"%@\". The member will receive a new invitation.", comment: "alert message for role change with new invitation"), newRole.text))
            ),
            primaryButton: .default(Text(NSLocalizedString("Change", comment: "button to confirm role change"))) {
                Task {
                    do {
                        let updatedMembers = try await apiMembersRole(groupInfo.groupId, [mem.groupMemberId], newRole)
                        await MainActor.run {
                            updatedMembers.forEach { updatedMember in
                                _ = chatModel.upsertGroupMember(groupInfo, updatedMember)
                            }
                        }

                    } catch let error {
                        newRole = mem.memberRole
                        logger.error("apiMembersRole error: \(responseError(error))")
                        await MainActor.run {
                            AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error changing role", comment: "")))
                        }
                    }
                }
            },
            secondaryButton: .cancel {
                newRole = mem.memberRole
            }
        )
    }

    private func switchMemberAddress() {
        logger.debug("POPOPX: switchMemberAddress")
        if pxGroupMemberFeatureEnabled {
            logger.debug("PX: [switchMemberAddress] feature enabled, switching address for member=\(groupMember.groupMemberId)")
        }
        Task {
            do {
                let stats = try apiSwitchGroupMember(groupInfo.apiId, groupMember.groupMemberId)
                connectionStats = stats
                await MainActor.run {
                    chatModel.updateGroupMemberConnectionStats(groupInfo, groupMember.wrapped, stats)
                    dismiss()
                }
            } catch let error {
                logger.error("switchMemberAddress apiSwitchGroupMember error: \(responseError(error))")
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error changing address", comment: "")))
                }
            }
        }
    }

    private func abortSwitchMemberAddress() {
        logger.debug("POPOPX: abortSwitchMemberAddress")
        if pxGroupMemberFeatureEnabled {
            logger.debug("PX: [abortSwitchMemberAddress] feature enabled, aborting for member=\(groupMember.groupMemberId)")
        }
        Task {
            do {
                let stats = try apiAbortSwitchGroupMember(groupInfo.apiId, groupMember.groupMemberId)
                connectionStats = stats
                await MainActor.run {
                    chatModel.updateGroupMemberConnectionStats(groupInfo, groupMember.wrapped, stats)
                }
            } catch let error {
                logger.error("abortSwitchMemberAddress apiAbortSwitchGroupMember error: \(responseError(error))")
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error aborting address change", comment: "")))
                }
            }
        }
    }

    private func syncMemberConnection(force: Bool) {
        logger.debug("POPOPX: syncMemberConnection force=\(force)")
        Task {
            do {
                let (mem, stats) = try apiSyncGroupMemberRatchet(groupInfo.apiId, groupMember.groupMemberId, force)
                connectionStats = stats
                await MainActor.run {
                    chatModel.updateGroupMemberConnectionStats(groupInfo, mem, stats)
                    dismiss()
                }
            } catch let error {
                logger.error("syncMemberConnection apiSyncGroupMemberRatchet error: \(responseError(error))")
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error synchronizing connection", comment: "")))
                }
            }
        }
    }
}

func MemberProfileImage(
    _ mem: GroupMember,
    size: CGFloat,
    color: Color = Color(uiColor: .tertiarySystemGroupedBackground),
    backgroundColor: Color? = nil
) -> some View {
    ProfileImage(
        imageStr: mem.image,
        size: size,
        color: color,
        backgroundColor: backgroundColor,
        blurred: mem.blocked
    )
}

func blockMemberAlert(_ gInfo: GroupInfo, _ mem: GroupMember) -> Alert {
    Alert(
        title: Text(NSLocalizedString("Block member?", comment: "alert title for blocking a member")),
        message: Text(String(format: NSLocalizedString("All new messages from %@ will be hidden!", comment: "alert message when blocking a member"), mem.chatViewName)),
        primaryButton: .destructive(Text(NSLocalizedString("Block", comment: "button to block member"))) {
            toggleShowMemberMessages(gInfo, mem, false)
        },
        secondaryButton: .cancel()
    )
}

func unblockMemberAlert(_ gInfo: GroupInfo, _ mem: GroupMember) -> Alert {
    Alert(
        title: Text(NSLocalizedString("group_unblock_member_question", comment: "unblock member alert title")),
        message: Text(String(format: NSLocalizedString("group_unblock_member_message_fmt", comment: "unblock member alert message with display name"), mem.chatViewName)),
        primaryButton: .default(Text(NSLocalizedString("group_unblock_action", comment: "unblock button"))) {
            toggleShowMemberMessages(gInfo, mem, true)
        },
        secondaryButton: .cancel()
    )
}

func toggleShowMemberMessages(_ gInfo: GroupInfo, _ member: GroupMember, _ showMessages: Bool) {
    var memberSettings = member.memberSettings
    memberSettings.showMessages = showMessages
    updateMemberSettings(gInfo, member, memberSettings)
}

func updateMemberSettings(_ gInfo: GroupInfo, _ member: GroupMember, _ memberSettings: GroupMemberSettings) {
    Task {
        do {
            try await apiSetMemberSettings(gInfo.groupId, member.groupMemberId, memberSettings)
            await MainActor.run {
                var mem = member
                mem.memberSettings = memberSettings
                _ = ChatModel.shared.upsertGroupMember(gInfo, mem)
            }
        } catch let error {
            logger.error("apiSetMemberSettings error \(responseError(error))")
        }
    }
}

func blockForAllAlert(_ gInfo: GroupInfo, _ mem: GroupMember) -> Alert {
    Alert(
        title: Text(gInfo.useRelays
            ? NSLocalizedString("group_block_subscriber_all", comment: "block subscriber for all alert title")
            : NSLocalizedString("group_block_member_all", comment: "block member for all alert title")),
        message: Text(String(format: NSLocalizedString("group_block_all_message_fmt", comment: "block for all alert message with display name"), mem.chatViewName)),
        primaryButton: .destructive(Text(NSLocalizedString("group_block_for_all_action", comment: "block for all button"))) {
            blockMemberForAll(gInfo, mem, true)
        },
        secondaryButton: .cancel()
    )
}

func unblockForAllAlert(_ gInfo: GroupInfo, _ mem: GroupMember) -> Alert {
    Alert(
        title: Text(gInfo.useRelays
            ? NSLocalizedString("group_unblock_subscriber_all", comment: "unblock subscriber for all alert title")
            : NSLocalizedString("group_unblock_member_all", comment: "unblock member for all alert title")),
        message: Text(String(format: NSLocalizedString("group_unblock_all_message_fmt", comment: "unblock for all alert message with display name"), mem.chatViewName)),
        primaryButton: .default(Text(NSLocalizedString("group_unblock_for_all_action", comment: "unblock for all button"))) {
            blockMemberForAll(gInfo, mem, false)
        },
        secondaryButton: .cancel()
    )
}

func blockMemberForAll(_ gInfo: GroupInfo, _ member: GroupMember, _ blocked: Bool) {
    Task {
        do {
            let updatedMembers = try await apiBlockMembersForAll(gInfo.groupId, [member.groupMemberId], blocked)
            await MainActor.run {
                updatedMembers.forEach { updatedMember in
                    _ = ChatModel.shared.upsertGroupMember(gInfo, updatedMember)
                }
            }
        } catch let error {
            logger.error("apiBlockMembersForAll error: \(responseError(error))")
        }
    }
}

// MARK: - POPOPX
extension PXGroupMemberDetail {
    var pxComponentTag: String { "px-group-member-info" }
    var pxMemberRoleTag: String { "px-member-role" }
    var pxConnectionStatsTag: String { "px-conn-stats" }
}

struct PXGroupMemberDetail_Previews: PreviewProvider {
    static var previews: some View {
        PXGroupMemberDetail(
            groupInfo: GroupInfo.sampleData,
            chat: Chat.sampleData,
            groupMember: GMember.sampleData,
            scrollToItemId: Binding.constant(nil)
        )
    }
}
