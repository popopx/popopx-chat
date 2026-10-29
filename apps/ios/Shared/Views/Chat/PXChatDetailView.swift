//
//  ChatInfoView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 05/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
@preconcurrency import POPOPXSwitch

func infoRow(_ title: LocalizedStringKey, _ value: String) -> some View {
    HStack {
        Text(title)
        Spacer()
        Text(value)
            .foregroundStyle(.secondary)
    }
}

func infoRow(_ title: Text, _ value: String) -> some View {
    HStack {
        title
        Spacer()
        Text(value)
            .foregroundStyle(.secondary)
    }
}

func localizedInfoRow(_ title: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
    HStack {
        Text(title)
        Spacer()
        Text(value)
            .foregroundStyle(.secondary)
    }
}

@ViewBuilder func smpServers(_ title: LocalizedStringKey, _ servers: [String], _ secondaryColor: Color) -> some View {
    if servers.count > 0 {
        HStack {
            Text(title).frame(width: 120, alignment: .leading)
            Button(serverHost(servers[0])) {
                UIPasteboard.general.setItems([["public.utf8-plain-text": servers.joined(separator: ";")]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true])
            }
            .foregroundColor(secondaryColor)
            .lineLimit(1)
        }
    }
}

func serverHost(_ s: String) -> String {
    if let i = s.range(of: "@")?.lowerBound {
        return String(s[i...].dropFirst())
    } else {
        return s
    }
}

enum SendReceipts: Identifiable, Hashable {
    case yes
    case no
    case userDefault(Bool)

    var id: Self { self }

    var text: LocalizedStringKey {
        switch self {
        case .yes: return "yes"
        case .no: return "no"
        case let .userDefault(on): return on ? "default (yes)" : "default (no)"
        }
    }

    func bool() -> Bool? {
        switch self {
        case .yes: return true
        case .no: return false
        case .userDefault: return nil
        }
    }

    static func fromBool(_ enable: Bool?, userDefault def: Bool) -> SendReceipts {
        if let enable = enable {
            return enable ? .yes : .no
        }
        return .userDefault(def)
    }
}

// Spec: spec/client/chat-view.md#ChatInfoView
struct ChatInfoView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @ObservedObject var chat: Chat
    @State var contact: Contact
    @State var localAlias: String
    @State var featuresAllowed: ContactFeaturesAllowed
    @State var currentFeaturesAllowed: ContactFeaturesAllowed
    var onSearch: () -> Void
    @State private var connectionStats: ConnectionStats? = nil
    @State private var customUserProfile: Profile? = nil
    @State private var connectionCode: String? = nil
    @FocusState private var aliasTextFieldFocused: Bool
    @State private var alert: ChatInfoViewAlert? = nil
    @State private var actionSheet: SomeActionSheet? = nil
    @State private var sheet: SomeSheet<AnyView>? = nil
    @State private var showConnectContactViaAddressDialog = false
    @State private var sendReceipts = SendReceipts.userDefault(true)
    @State private var sendReceiptsUserDefault = true
    @State private var progressIndicator = false
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @State private var showSecrets: Set<Int> = []
    @State private var showBlockConfirmation = false
    @State private var showReportDialog = false

    enum ChatInfoViewAlert: Identifiable {
        case clearChatAlert
        case subStatusAlert(status: SubscriptionStatus)
        case switchAddressAlert
        case abortSwitchAddressAlert
        case syncConnectionForceAlert
        case queueInfo(info: String)
        case someAlert(alert: SomeAlert)
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .clearChatAlert: return "clearChatAlert"
            case let .subStatusAlert(status): return "subStatusAlert \(status)"
            case .switchAddressAlert: return "switchAddressAlert"
            case .abortSwitchAddressAlert: return "abortSwitchAddressAlert"
            case .syncConnectionForceAlert: return "syncConnectionForceAlert"
            case let .queueInfo(info): return "queueInfo \(info)"
            case let .someAlert(alert): return "chatInfoSomeAlert \(alert.id)"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    contactInfoHeader()
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            aliasTextFieldFocused = false
                        }

                    localAliasTextEdit()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.bottom, 18)

                    GeometryReader { g in
                        HStack(alignment: .center, spacing: 8) {
                            let buttonWidth = g.size.width / 4
                            searchButton(width: buttonWidth)
                            AudioCallButton(chat: chat, contact: contact, connectionStats: $connectionStats, width: buttonWidth) { alert = .someAlert(alert: $0) }
                            VideoButton(chat: chat, contact: contact, connectionStats: $connectionStats, width: buttonWidth) { alert = .someAlert(alert: $0) }
                            if let nextNtfMode = chat.chatInfo.nextNtfMode {
                                muteButton(width: buttonWidth, nextNtfMode: nextNtfMode)
                            }
                        }
                    }
                    .padding(.trailing)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: infoViewActionButtonHeight)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8))

                    if let customUserProfile = customUserProfile {
                        Section(header: Text(NSLocalizedString("Incognito", comment: ""))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            HStack {
                                Text(NSLocalizedString("Your random profile", comment: ""))
                                Spacer()
                                Text(customUserProfile.chatViewName)
                                    .foregroundStyle(QuantumColors.accent)
                            }
                        }
                    }

                    Section {
                        if let code = connectionCode { verifyCodeButton(code) }
                        contactPreferencesButton()
                        sendReceiptsOption()
                        if let connStats = connectionStats,
                           connStats.ratchetSyncAllowed {
                            synchronizeConnectionButton()
                        }
                        // } else if developerTools {
                        //     synchronizeConnectionButtonForce()
                        // }

                        NavigationLink {
                            PXChatWallpaperEditorSheet(chat: chat)
                        } label: {
                            Label(NSLocalizedString("Chat theme", comment: ""), systemImage: "photo")
                        }
                        //                    } else if developerTools {
                        //                        synchronizeConnectionButtonForce()
                        //                    }
                        .listRowBackground(Color.clear)
                        .scrollContentBackground(.hidden)
                    }
                    .disabled(!contact.ready || !contact.active)

                    Section {
                        ChatTTLOption(chat: chat, progressIndicator: $progressIndicator)
                    } footer: {
                        Text(NSLocalizedString("Delete chat messages from your device.", comment: ""))
                    }

                    if let conn = contact.activeConn {
                        Section {
                            infoRow(Text(String(NSLocalizedString("E2E encryption", comment: ""))), conn.connPQEnabled ? NSLocalizedString("Quantum resistant", comment: "") : NSLocalizedString("Standard", comment: ""))
                        }
                    }

                    if let contactLink = contact.contactLink {
                        Section {
                            PXContactLinkQRCode(uri: contactLink)
                            Button {
                                showShareSheet(items: [popopxChatLink(contactLink)])
                            } label: {
                                Label(NSLocalizedString("Share address", comment: ""), systemImage: "square.and.arrow.up")
                            }
                        } header: {
                            Text(NSLocalizedString("Address", comment: ""))
                                .font(isInDarkTheme() ? .subheadline.weight(.bold) : .caption)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        } footer: {
                            Text(String.localizedStringWithFormat(NSLocalizedString("You can share this address with your contacts to let them connect with **%@**.", comment: ""), contact.displayName))
                                .foregroundColor(theme.colors.secondary)
                        }
                    }

                    if contact.ready && contact.active {
                        Section(header: Text(NSLocalizedString("Servers", comment: ""))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            if let chatSubStatus = chatModel.chatSubStatus {
                                SubStatusRow(status: chatSubStatus)
                                    .onTapGesture {
                                        alert = .subStatusAlert(status: chatSubStatus)
                                    }
                            }
                            if let connStats = connectionStats {
                                Button(NSLocalizedString("Change receiving address", comment: "")) {
                                    alert = .switchAddressAlert
                                }
                                .disabled(
                                    connStats.rcvQueuesInfo.contains { $0.rcvSwitchStatus != nil }
                                    || connStats.ratchetSyncSendProhibited
                                )
                                if connStats.rcvQueuesInfo.contains(where: { $0.rcvSwitchStatus != nil }) {
                                    Button(NSLocalizedString("Abort changing address", comment: "")) {
                                        alert = .abortSwitchAddressAlert
                                    }
                                    .disabled(
                                        connStats.rcvQueuesInfo.contains { $0.rcvSwitchStatus != nil && !$0.canAbortSwitch }
                                        || connStats.ratchetSyncSendProhibited
                                    )
                                }
                                smpServers(LocalizedStringKey(NSLocalizedString("Receiving via", comment: "")), connStats.rcvQueuesInfo.map { $0.rcvServer }, theme.colors.secondary)
                                smpServers(LocalizedStringKey(NSLocalizedString("Sending via", comment: "")), connStats.sndQueuesInfo.map { $0.sndServer }, theme.colors.secondary)
                            }
                        }
                    }

                    Section {
                        clearChatButton()
                        reportContactButton()
                        blockContactButton()
                        deleteContactButton()
                    }

                    if developerTools {
                        Section(header: Text(NSLocalizedString("For console", comment: ""))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                            infoRow(LocalizedStringKey(NSLocalizedString("Local name", comment: "")), chat.chatInfo.localDisplayName)
                            infoRow(LocalizedStringKey(NSLocalizedString("Database ID", comment: "")), "\(chat.chatInfo.apiId)")
                            Button (NSLocalizedString("Debug delivery", comment: "")) {
                                Task {
                                    do {
                                        if let info = try await apiContactQueueInfo(chat.chatInfo.apiId) {
                                            await MainActor.run { alert = .queueInfo(info: queueInfoText(info)) }
                                        }
                                    } catch let e {
                                        logger.error("apiContactQueueInfo error: \(responseError(e))")
                                        let a = getErrorAlert(e, "Error")
                                        await MainActor.run { alert = .error(title: a.title, error: a.message) }
                                    }
                                }
                            }
                        }
                    }
                }
                .modifier(ThemedBackground(grouped: true, glass: true))
                .listRowBackground(Color.clear)
                .scrollContentBackground(.hidden)
                .toolbar(.hidden, for: .navigationBar)
                .disabled(progressIndicator)
                .opacity(progressIndicator ? 0.6 : 1)

                if progressIndicator {
                    ProgressView().scaleEffect(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if let currentUser = chatModel.currentUser {
                sendReceiptsUserDefault = currentUser.sendRcptsContacts
            }
            sendReceipts = SendReceipts.fromBool(contact.chatSettings.sendRcpts, userDefault: sendReceiptsUserDefault)

            Task {
                do {
                    let (stats, profile) = try await apiContactInfo(chat.chatInfo.apiId)
                    let (ct, code) = try await apiGetContactCode(chat.chatInfo.apiId)
                    await MainActor.run {
                        connectionStats = stats
                        customUserProfile = profile
                        connectionCode = code
                        if contact.activeConn?.connectionCode != ct.activeConn?.connectionCode {
                            chat.chatInfo = .direct(contact: ct)
                        }
                    }
                } catch let error {
                    logger.error("apiContactInfo or apiGetContactCode error: \(responseError(error))")
                }
            }
        }
        .alert(item: $alert) { alertItem in
            switch(alertItem) {
            case .clearChatAlert: return clearChatAlert()
            case let .subStatusAlert(status): return subStatusAlert(status)
            case .switchAddressAlert: return switchAddressAlert(switchContactAddress)
            case .abortSwitchAddressAlert: return abortSwitchAddressAlert(abortSwitchContactAddress)
            case .syncConnectionForceAlert:
                return syncConnectionForceAlert({
                    Task {
                        if let stats = await syncContactConnection(contact, force: true, showAlert: { alert = .someAlert(alert: $0) }) {
                            await MainActor.run {
                                connectionStats = stats
                            }
                            dismiss()
                        }
                    }
                })
            case let .queueInfo(info): return queueInfoAlert(info)
            case let .someAlert(a): return a.alert
            case let .error(title, error): return mkAlert(title: title, message: error)
            }
        }
        .actionSheet(item: $actionSheet) { $0.actionSheet }
        .sheet(item: $sheet) {
            $0.content
                .presentationDetents([.fraction($0.fraction)])
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if currentFeaturesAllowed != featuresAllowed {
                        showAlert(
                            title: NSLocalizedString("Save preferences?", comment: "alert title"),
                            buttonTitle: NSLocalizedString("Save and notify contact", comment: "alert button"),
                            buttonAction: { savePreferences(); dismiss() },
                            cancelButton: true
                        )
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(NSLocalizedString("Back", comment: ""))
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .popopxBranded()
    }

    private func contactInfoHeader() -> some View {
        VStack(spacing: 8) {
            let cInfo = chat.chatInfo
            ChatInfoImage(chat: chat, size: 192, color: Color(uiColor: .tertiarySystemFill))
                .padding(.vertical, 12)
            // show actual display name, alias can be edited in this view
            let displayName = contact.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = cInfo.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let badge = cInfo.nameBadge
            // the shield is smaller (.title2) than the name (.largeTitle), so on the shared baseline it
            // sits low; raise it by half the cap-height difference to center it with the capitals
            let shieldRaise = (UIFont.preferredFont(forTextStyle: .largeTitle).capHeight - UIFont.preferredFont(forTextStyle: .title2).capHeight) / 2
            let nameFont = isInDarkTheme() ? QuantumFonts.sectionHeader : .largeTitle
            let nameColor = isInDarkTheme() ? darkThemeAccentColor() : .primary
            let nameText: Text = contact.verified
                ? {
                    var pxShield = AttributedString("\(Image(systemName: "checkmark.shield")) ")
                    pxShield.foregroundColor = theme.colors.secondary
                    pxShield.font = .title2
                    pxShield.baselineOffset = shieldRaise
                    var pxName = AttributedString(displayName)
                    pxName.font = nameFont
                    pxName.foregroundColor = nameColor
                    return Text(pxShield + pxName)
                }()
                : Text(displayName).font(nameFont).foregroundColor(nameColor)
            NameWithBadge(nameText, badge, .largeTitle) { if let badge { showBadgeInfoAlert(displayName, badge) } }
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.bottom, 2)
            // Show domain verification indicator if domain claim exists
            if let domainClaim = contact.profile.contactDomain, let verified = contact.profile.contactDomainVerified {
                HStack(spacing: 4) {
                    Image(systemName: verified ? "checkmark.seal.fill" : "exclamationmark.seal")
                        .font(.caption)
                        .foregroundColor(verified ? QuantumColors.success : QuantumColors.warning)
                    Text(domainClaim.domain)
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(verified ? QuantumColors.success.opacity(0.1) : QuantumColors.warning.opacity(0.1))
                )
                .onTapGesture {
                    showDomainVerificationAlert(displayName, domainClaim, verified)
                }
                .padding(.bottom, 2)
            }
            if fullName != "" && fullName != displayName && fullName != cInfo.displayName.trimmingCharacters(in: .whitespacesAndNewlines)  {
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
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func localAliasTextEdit() -> some View {
        TextField(NSLocalizedString("Set contact name…", comment: ""), text: $localAlias)
            .disableAutocorrection(true)
            .focused($aliasTextFieldFocused)
            .submitLabel(.done)
            .onChange(of: aliasTextFieldFocused) {_,  focused in
                if !focused {
                    setContactAlias()
                }
            }
            .onSubmit {
                setContactAlias()
            }
            .multilineTextAlignment(.center)
            .foregroundColor(theme.colors.secondary)
    }

    private func setContactAlias() {
        Task {
            do {
                if let contact = try await apiSetContactAlias(contactId: chat.chatInfo.apiId, localAlias: localAlias) {
                    await MainActor.run {
                        chatModel.updateContact(contact)
                    }
                }
            } catch {
                logger.error("setContactAlias error: \(responseError(error))")
            }
        }
    }

    private func searchButton(width: CGFloat) -> some View {
        InfoViewButton(image: "magnifyingglass", title: "search", width: width) {
            dismiss()
            onSearch()
        }
        .disabled(!contact.ready || chat.chatItems.isEmpty)
    }

    private func muteButton(width: CGFloat, nextNtfMode: MsgFilter) -> some View {
        return InfoViewButton(
            image: nextNtfMode.iconFilled,
            title: "\(nextNtfMode.text(mentions: false))",
            width: width
        ) {
            toggleNotifications(chat, enableNtfs: nextNtfMode)
        }
        .disabled(!contact.ready || !contact.active)
    }

    private func verifyCodeButton(_ code: String) -> some View {
        NavigationLink {
            VerifyCodeView(
                displayName: contact.displayName,
                connectionCode: code,
                connectionVerified: contact.verified,
                verify: { code in
                    if let r = apiVerifyContact(chat.chatInfo.apiId, connectionCode: code) {
                        let (verified, existingCode) = r
                        contact.activeConn?.connectionCode = verified ? SecurityCode(securityCode: existingCode, verifiedAt: .now) : nil
                        connectionCode = existingCode
                        DispatchQueue.main.async {
                            chat.chatInfo = .direct(contact: contact)
                        }
                        return r
                    }
                    return nil
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(NSLocalizedString("Security code", comment: ""))
            .modifier(ThemedBackground(grouped: true))
        } label: {
            Label(
                contact.verified ? NSLocalizedString("View security code", comment: "") : NSLocalizedString("Verify security code", comment: ""),
                systemImage: contact.verified ? "checkmark.shield" : "shield"
            )
        }
    }

    private func contactPreferencesButton() -> some View {
        NavigationLink {
            ContactPreferencesView(
                contact: $contact,
                featuresAllowed: $featuresAllowed,
                currentFeaturesAllowed: $currentFeaturesAllowed,
                savePreferences: savePreferences
            )
            .navigationTitle(NSLocalizedString("Contact preferences", comment: ""))
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
        } label: {
            Label(NSLocalizedString("Contact preferences", comment: ""), systemImage: "switch.2")
        }
    }

    private func sendReceiptsOption() -> some View {
        PXWrappedPicker(selection: $sendReceipts) {
            ForEach([.yes, .no, .userDefault(sendReceiptsUserDefault)]) { (opt: SendReceipts) in
                Text(opt.text)
            }
        } label: {
            Label(NSLocalizedString("Send receipts", comment: ""), systemImage: "checkmark.message")
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

    private func synchronizeConnectionButton() -> some View {
        Button {
            Task {
                if let stats = await syncContactConnection(contact, force: false, showAlert: { alert = .someAlert(alert: $0) }) {
                    await MainActor.run {
                        connectionStats = stats
                    }
                    dismiss()
                }
            }
        } label: {
            Label(NSLocalizedString("Fix connection", comment: ""), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                .foregroundColor(QuantumColors.warning)
        }
    }

    private func reportContactButton() -> some View {
        Button(role: .destructive) {
            showReportDialog = true
        } label: {
            Label(NSLocalizedString("Report contact", comment: ""), systemImage: "exclamationmark.bubble")
                .foregroundColor(theme.colors.error)
        }
        .confirmationDialog(
            NSLocalizedString("Report this contact?", comment: "report contact confirmation title"),
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Report: Spam", comment: "report category"), role: .destructive) {
                reportAndBlock(reason: "spam")
            }
            Button(NSLocalizedString("Report: Harassment", comment: "report category"), role: .destructive) {
                reportAndBlock(reason: "harassment")
            }
            Button(NSLocalizedString("Report: Illegal content", comment: "report category"), role: .destructive) {
                reportAndBlock(reason: "illegal_content")
            }
            Button(NSLocalizedString("Block & Delete Chat", comment: "block contact confirmation action"), role: .destructive) {
                BlockedContactsManager.shared.block(contact.contactId)
                Task {
                    await deleteChat(chat)
                    await MainActor.run { dismiss() }
                }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("The contact will be blocked, chat deleted, and a report sent to our team.", comment: "report contact confirmation message"))
        }
    }

    @State private var reportFailed = false

    private func reportAndBlock(reason: String) {
        BlockedContactsManager.shared.block(contact.contactId)
        Task {
            do {
                _ = try await ServerAPI.shared.post("compliance/report", body: [
                    "contactId": contact.contactId,
                    "reason": reason
                ])
                await deleteChat(chat)
                await MainActor.run { dismiss() }
            } catch {
                logger.error("Failed to submit compliance report: \(error)")
                await MainActor.run { reportFailed = true }
            }
        }
    }

    private func blockContactButton() -> some View {
        Button(role: .destructive) {
            showBlockConfirmation = true
        } label: {
            Label(NSLocalizedString("Block contact", comment: ""), systemImage: "person.crop.circle.badge.xmark")
                .foregroundColor(theme.colors.error)
        }
        .confirmationDialog(
            NSLocalizedString("Block this contact?", comment: "block contact confirmation title"),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Block & Delete Chat", comment: "block contact confirmation action"), role: .destructive) {
                BlockedContactsManager.shared.block(contact.contactId)
                Task {
                    await deleteChat(chat)
                    await MainActor.run { dismiss() }
                }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Messages from this contact will be hidden. The conversation will be deleted.", comment: "block contact confirmation message"))
        }
    }

    private func deleteContactButton() -> some View {
        Button(role: .destructive) {
            deleteContactDialog(
                chat,
                contact,
                dismissToChatList: true,
                showAlert: { alert = .someAlert(alert: $0) },
                showActionSheet: { actionSheet = $0 },
                showSheetContent: { sheet = $0 }
            )
        } label: {
            Label(NSLocalizedString("Delete contact", comment: ""), systemImage: "person.badge.minus")
                .foregroundColor(theme.colors.error)
        }
    }

    private func clearChatButton() -> some View {
        Button() {
            alert = .clearChatAlert
        } label: {
            Label(NSLocalizedString("Clear conversation", comment: ""), systemImage: "gobackward")
                .foregroundColor(QuantumColors.warning)
        }
    }

    private func clearChatAlert() -> Alert {
        Alert(
            title: Text(NSLocalizedString("Clear conversation?", comment: "")),
            message: Text(NSLocalizedString("All messages will be deleted - this cannot be undone! The messages will be deleted ONLY for you.", comment: "")),
            primaryButton: .destructive(Text(NSLocalizedString("Clear", comment: ""))) {
                Task {
                    await clearChat(chat)
                    await MainActor.run { dismiss() }
                }
            },
            secondaryButton: .cancel()
        )
    }

    private func subStatusAlert(_ status: SubscriptionStatus) -> Alert {
        Alert(
            title: Text(NSLocalizedString("Network status", comment: "")),
            message: Text(status.statusExplanation)
        )
    }

    private func switchContactAddress() {
        Task {
            do {
                let stats = try apiSwitchContact(contactId: contact.apiId)
                await MainActor.run {
                    connectionStats = stats
                    chatModel.updateContactConnectionStats(contact, stats)
                    dismiss()
                }
            } catch let error {
                logger.error("switchContactAddress apiSwitchContact error: \(responseError(error))")
                let a = getErrorAlert(error, "Error changing address")
                await MainActor.run {
                    alert = .error(title: a.title, error: a.message)
                }
            }
        }
    }

    private func abortSwitchContactAddress() {
        Task {
            do {
                let stats = try apiAbortSwitchContact(contact.apiId)
                await MainActor.run {
                    connectionStats = stats
                    chatModel.updateContactConnectionStats(contact, stats)
                }
            } catch let error {
                logger.error("abortSwitchContactAddress apiAbortSwitchContact error: \(responseError(error))")
                let a = getErrorAlert(error, "Error aborting address change")
                await MainActor.run {
                    alert = .error(title: a.title, error: a.message)
                }
            }
        }
    }

    private func savePreferences() {
        Task {
            do {
                let prefs = contactFeaturesAllowedToPrefs(featuresAllowed)
                if let toContact = try await apiSetContactPrefs(contactId: contact.contactId, preferences: prefs) {
                    await MainActor.run {
                        contact = toContact
                        chatModel.updateContact(toContact)
                        currentFeaturesAllowed = featuresAllowed
                    }
                }
            } catch {
                logger.error("ContactPreferencesView apiSetContactPrefs error: \(responseError(error))")
            }
        }
    }
}

struct SubStatusRow: View {
    @EnvironmentObject var theme: AppTheme
    var status: SubscriptionStatus

    var body: some View {
        HStack {
            Text(NSLocalizedString("Network status", comment: ""))
            Image(systemName: "info.circle")
                .foregroundColor(theme.colors.primary)
                .font(.footnote)
            Spacer()
            Text(status.statusString)
                .foregroundColor(theme.colors.secondary)
            serverImage(status)
        }
    }

    private func serverImage(_ status: SubscriptionStatus) -> some View {
        return Image(systemName: status.imageName)
            .foregroundColor(status == .active ? QuantumColors.success : theme.colors.secondary)
            .font(.caption)
    }
}

struct ChatTTLOption: View {
    @ObservedObject var chat: Chat
    @Binding var progressIndicator: Bool
    @State private var currentChatItemTTL: ChatTTL = ChatTTL.userDefault(.seconds(0))
    @State private var chatItemTTL: ChatTTL = ChatTTL.chat(.seconds(0))

    var body: some View {
        PXWrappedPicker(LocalizedStringKey(NSLocalizedString("chat_delete_messages_after", comment: "Delete messages after picker label")), selection: $chatItemTTL) {
            ForEach(ChatItemTTL.values) { ttl in
                Text(ttl.deleteAfterText).tag(ChatTTL.chat(ttl))
            }
            let defaultTTL = ChatTTL.userDefault(ChatModel.shared.chatItemTTL)
            Text(defaultTTL.text).tag(defaultTTL)

            if case .chat(let ttl) = chatItemTTL, case .seconds = ttl {
                Text(ttl.deleteAfterText).tag(chatItemTTL)
            }
        }
        .disabled(progressIndicator)
        .onChange(of: chatItemTTL) {_,  ttl in
            if ttl == currentChatItemTTL { return }
            setChatTTL(
                ttl,
                hasPreviousTTL: !currentChatItemTTL.neverExpires,
                onCancel: { chatItemTTL = currentChatItemTTL }
            ) {
                progressIndicator = true
                Task {
                    let m = ChatModel.shared
                    do {
                        try await setChatTTL(chatType: chat.chatInfo.chatType, id: chat.chatInfo.apiId, ttl)
                        await loadChat(chat: chat, im: ItemsModel.shared, clearItems: true)
                        await MainActor.run {
                            progressIndicator = false
                            currentChatItemTTL = chatItemTTL
                            if ItemsModel.shared.reversedChatItems.isEmpty && m.chatId == chat.id,
                               let chat = m.getChat(chat.id) {
                                chat.chatItems = []
                                m.replaceChat(chat.id, chat)
                            }
                        }
                    }
                    catch let error {
                        logger.error("setChatTTL error \(responseError(error))")
                        await loadChat(chat: chat, im: ItemsModel.shared, clearItems: true)
                        await MainActor.run {
                            chatItemTTL = currentChatItemTTL
                            progressIndicator = false
                        }
                    }
                }
            }
        }
        .onAppear {
            let sm = ChatModel.shared
            let ttl = chat.chatInfo.ttl(sm.chatItemTTL)
            chatItemTTL = ttl
            currentChatItemTTL = ttl
        }
    }
}

func syncContactConnection(_ contact: Contact, force: Bool, showAlert: (SomeAlert) -> Void) async -> ConnectionStats? {
    do {
        let stats = try apiSyncContactRatchet(contact.apiId, force)
        await MainActor.run {
            ChatModel.shared.updateContactConnectionStats(contact, stats)
        }
        return stats
    } catch let error {
        logger.error("syncContactConnection apiSyncContactRatchet error: \(responseError(error))")
        let a = getErrorAlert(error, "Error synchronizing connection")
        await MainActor.run {
            showAlert(
                SomeAlert(
                    alert: mkAlert(title: a.title, message: a.message),
                    id: "syncContactConnection error"
                )
            )
        }
        return nil
    }
}

struct AudioCallButton: View {
    var chat: Chat
    var contact: Contact
    @Binding var connectionStats: ConnectionStats?
    var width: CGFloat
    var showAlert: (SomeAlert) -> Void

    var body: some View {
        CallButton(
            chat: chat,
            contact: contact,
            connectionStats: $connectionStats,
            image: "phone.fill",
            title: "call",
            mediaType: .audio,
            width: width,
            showAlert: showAlert
        )
    }
}

struct VideoButton: View {
    var chat: Chat
    var contact: Contact
    @Binding var connectionStats: ConnectionStats?
    var width: CGFloat
    var showAlert: (SomeAlert) -> Void

    var body: some View {
        CallButton(
            chat: chat,
            contact: contact,
            connectionStats: $connectionStats,
            image: "video.fill",
            title: "video",
            mediaType: .video,
            width: width,
            showAlert: showAlert
        )
    }
}

private struct CallButton: View {
    var chat: Chat
    var contact: Contact
    @Binding var connectionStats: ConnectionStats?
    var image: String
    var title: LocalizedStringKey
    var mediaType: CallMediaType
    var width: CGFloat
    var showAlert: (SomeAlert) -> Void

    var body: some View {
        let canCall = contact.ready && contact.active && chat.chatInfo.featureEnabled(.calls) && ChatModel.shared.activeCall == nil

        InfoViewButton(image: image, title: title, disabledLook: !canCall, width: width) {
            if canCall {
                if let connStats = connectionStats {
                    if connStats.ratchetSyncState == .ok {
                        if CallController.useCallKit() {
                            CallController.shared.startCall(contact, mediaType)
                        } else {
                            // When CallKit is not used, colorscheme will be changed and it will be visible if not hiding sheets first
                            dismissAllSheets(animated: true) {
                                CallController.shared.startCall(contact, mediaType)
                            }
                        }
                    } else if connStats.ratchetSyncAllowed {
                        showAlert(SomeAlert(
                            alert: Alert(
                                title: Text(NSLocalizedString("Fix connection?", comment: "")),
                                message: Text(NSLocalizedString("Connection requires encryption renegotiation.", comment: "")),
                                primaryButton: .default(Text(NSLocalizedString("Fix", comment: ""))) {
                                    Task {
                                        if let stats = await syncContactConnection(contact, force: false, showAlert: showAlert) {
                                            await MainActor.run {
                                                connectionStats = stats
                                            }
                                        }
                                    }
                                },
                                secondaryButton: .cancel()
                            ),
                            id: "can't call contact, fix connection"
                        ))
                    } else {
                        showAlert(SomeAlert(
                            alert: mkAlert(
                                title: LocalizedStringKey(NSLocalizedString("Can't call contact", comment: "")),
                                message: LocalizedStringKey(NSLocalizedString("Encryption renegotiation in progress.", comment: ""))
                            ),
                            id: "can't call contact, encryption renegotiation in progress"
                        ))
                    }
                }
            } else if contact.sendMsgToConnect {
                showAlert(SomeAlert(
                    alert: mkAlert(
                        title: LocalizedStringKey(NSLocalizedString("Can't call contact", comment: "")),
                        message: LocalizedStringKey(NSLocalizedString("Send message to enable calls.", comment: ""))
                    ),
                    id: "can't call contact, send message"
                ))
            } else if !contact.active {
                showAlert(SomeAlert(
                    alert: mkAlert(
                        title: LocalizedStringKey(NSLocalizedString("Can't call contact", comment: "")),
                        message: LocalizedStringKey(NSLocalizedString("Contact is deleted.", comment: ""))
                    ),
                    id: "can't call contact, contact deleted"
                ))
            } else if !contact.ready {
                showAlert(SomeAlert(
                    alert: mkAlert(
                        title: LocalizedStringKey(NSLocalizedString("Can't call contact", comment: "")),
                        message: LocalizedStringKey(NSLocalizedString("Connecting to contact, please wait or check later!", comment: ""))
                    ),
                    id: "can't call contact, contact not ready"
                ))
            } else if !chat.chatInfo.featureEnabled(.calls) {
                switch chat.chatInfo.showEnableCallsAlert {
                case .userEnable:
                    showAlert(SomeAlert(
                        alert: Alert(
                            title: Text(NSLocalizedString("Allow calls?", comment: "")),
                            message: Text(NSLocalizedString("You need to allow your contact to call to be able to call them.", comment: "")),
                            primaryButton: .default(Text(NSLocalizedString("Allow", comment: ""))) {
                                allowFeatureToContact(contact, .calls)
                            },
                            secondaryButton: .cancel()
                        ),
                        id: "allow calls"
                    ))
                case .askContact:
                    showAlert(SomeAlert(
                        alert: mkAlert(
                            title: LocalizedStringKey(NSLocalizedString("Calls prohibited!", comment: "")),
                            message: LocalizedStringKey(NSLocalizedString("Please ask your contact to enable calls.", comment: ""))
                        ),
                        id: "calls prohibited, ask contact"
                    ))
                case .other:
                    showAlert(SomeAlert(
                        alert: mkAlert(
                            title: LocalizedStringKey(NSLocalizedString("Calls prohibited!", comment: "")),
                            message: LocalizedStringKey(NSLocalizedString("Please check yours and your contact preferences.", comment: ""))
                        )
                        , id: "calls prohibited, other"
                    ))
                }
            } else {
                showAlert(SomeAlert(
                    alert: mkAlert(title: LocalizedStringKey(NSLocalizedString("Can't call contact", comment: ""))),
                    id: "can't call contact"
                ))
            }
        }
        .disabled(ChatModel.shared.activeCall != nil)
    }
}

let infoViewActionButtonHeight: CGFloat = 60

struct InfoViewButton: View {
    var image: String
    var title: LocalizedStringKey
    var disabledLook: Bool = false
    var width: CGFloat
    var action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: image)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .accentColor)
        .glassBackground()
        .shadow(color: darkThemeAccentColor().opacity(0.15), radius: 8, x: 0, y: 4)
        .cornerRadius(10.0)
        .frame(width: width)
        .frame(minHeight: infoViewActionButtonHeight)
        .disabled(disabledLook)
        .onTapGesture(perform: action)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}

struct PXChatWallpaperEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: AppTheme
    @State private var globalThemeUsed: Bool = false
    @State var chat: Chat
    @State private var themes: ThemeModeOverrides

    init(chat: Chat) {
        self.chat = chat
        self.themes = if case let ChatInfo.direct(contact) = chat.chatInfo, let uiThemes = contact.uiThemes {
            uiThemes
        } else if case let ChatInfo.group(groupInfo, _) = chat.chatInfo, let uiThemes = groupInfo.uiThemes {
            uiThemes
        } else {
            ThemeModeOverrides()
        }
    }

    var body: some View {
        let preferred = themes.preferredMode(!theme.colors.isLight)
        let initialTheme = preferred ?? ThemeManager.defaultActiveTheme(ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
        PXChatWallpaperEditor(
            initialTheme: initialTheme,
            themeModeOverride: initialTheme,
            applyToMode: themes.light == themes.dark ? nil : initialTheme.mode,
            globalThemeUsed: $globalThemeUsed,
            save: { applyToMode, newTheme in
                await save(applyToMode, newTheme, $chat)
            }
        )
        .navigationTitle(NSLocalizedString("Chat theme", comment: ""))
        .modifier(ThemedBackground(grouped: true))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            globalThemeUsed = preferred == nil
        }
        .onChange(of: theme.base.mode) {_, _ in
            globalThemeUsed = themesFromChat(chat).preferredMode(!theme.colors.isLight) == nil
        }
        .onChange(of: ChatModel.shared.chatId) {_, _ in
            dismiss()
        }
    }

    private func themesFromChat(_ chat: Chat) -> ThemeModeOverrides {
        if case let ChatInfo.direct(contact) = chat.chatInfo, let uiThemes = contact.uiThemes {
            uiThemes
        } else if case let ChatInfo.group(groupInfo, _) = chat.chatInfo, let uiThemes = groupInfo.uiThemes {
            uiThemes
        } else {
            ThemeModeOverrides()
        }
    }

    @State private var updateBackendTask: Task<Void, Never> = Task {}
    private func save(
        _ applyToMode: DefaultThemeMode?,
        _ newTheme: ThemeModeOverride?,
        _ chat: Binding<Chat>
    ) async {
        let unchangedThemes: ThemeModeOverrides = themesFromChat(chat.wrappedValue)
        var wallpaperFiles = Set([unchangedThemes.light?.wallpaper?.imageFile, unchangedThemes.dark?.wallpaper?.imageFile])
        var changedThemes: ThemeModeOverrides? = unchangedThemes
        let light: ThemeModeOverride? = if let newTheme {
            ThemeModeOverride(mode: DefaultThemeMode.light, colors: newTheme.colors, wallpaper: newTheme.wallpaper?.withFilledWallpaperPath())
        } else {
            nil
        }
        let dark: ThemeModeOverride? = if let newTheme {
            ThemeModeOverride(mode: DefaultThemeMode.dark, colors: newTheme.colors, wallpaper: newTheme.wallpaper?.withFilledWallpaperPath())
        } else {
            nil
        }

        if let applyToMode {
            switch applyToMode {
            case DefaultThemeMode.light:
                changedThemes?.light = light
            case DefaultThemeMode.dark:
                changedThemes?.dark = dark
            }
        } else {
            changedThemes?.light = light
            changedThemes?.dark = dark
        }
        if changedThemes?.light != nil || changedThemes?.dark != nil {
            let light = changedThemes?.light
            let dark = changedThemes?.dark
            let currentMode = CurrentColors.base.mode
            // same image file for both modes, copy image to make them as different files
            if var light, var dark, let lightWallpaper = light.wallpaper, let darkWallpaper = dark.wallpaper, let lightImageFile = lightWallpaper.imageFile, let darkImageFile = darkWallpaper.imageFile, lightWallpaper.imageFile == darkWallpaper.imageFile {
                let imageFile = if currentMode == DefaultThemeMode.light {
                    darkImageFile
                } else {
                    lightImageFile
                }
                let filePath = saveWallpaperFile(url: getWallpaperFilePath(imageFile))
                if currentMode == DefaultThemeMode.light {
                    dark.wallpaper?.imageFile = filePath
                    changedThemes = ThemeModeOverrides(light: changedThemes?.light, dark: dark)
                } else {
                    light.wallpaper?.imageFile = filePath
                    changedThemes = ThemeModeOverrides(light: light, dark: changedThemes?.dark)
                }
            }
        } else {
            changedThemes = nil
        }
        wallpaperFiles.remove(changedThemes?.light?.wallpaper?.imageFile)
        wallpaperFiles.remove(changedThemes?.dark?.wallpaper?.imageFile)
        wallpaperFiles.forEach(removeWallpaperFile)

        let changedThemesConstant = changedThemes
        updateBackendTask.cancel()
        updateBackendTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000000)
                if await apiSetChatUIThemes(chatId: chat.id, themes: changedThemesConstant) {
                    if case var ChatInfo.direct(contact) = chat.wrappedValue.chatInfo {
                        contact.uiThemes = changedThemesConstant
                        await MainActor.run {
                            ChatModel.shared.updateChatInfo(ChatInfo.direct(contact: contact))
                            chat.wrappedValue = Chat.init(chatInfo: ChatInfo.direct(contact: contact))
                            themes = themesFromChat(chat.wrappedValue)
                        }
                    } else if case var ChatInfo.group(groupInfo, _) = chat.wrappedValue.chatInfo {
                        groupInfo.uiThemes = changedThemesConstant

                        await MainActor.run {
                            ChatModel.shared.updateChatInfo(ChatInfo.group(groupInfo: groupInfo, groupChatScope: nil))
                            chat.wrappedValue = Chat.init(chatInfo: ChatInfo.group(groupInfo: groupInfo, groupChatScope: nil))
                            themes = themesFromChat(chat.wrappedValue)
                        }
                    }
                }
            } catch {
                // canceled task
            }
        }
    }
}

func switchAddressAlert(_ switchAddress: @escaping () -> Void) -> Alert {
    Alert(
        title: Text(NSLocalizedString("Change receiving address?", comment: "")),
        message: Text(NSLocalizedString("Receiving address will be changed to a different server. Address change will complete after sender comes online.", comment: "")),
        primaryButton: .default(Text(NSLocalizedString("Change", comment: "")), action: switchAddress),
        secondaryButton: .cancel()
    )
}

func abortSwitchAddressAlert(_ abortSwitchAddress: @escaping () -> Void) -> Alert {
    Alert(
        title: Text(NSLocalizedString("Abort changing address?", comment: "")),
        message: Text(NSLocalizedString("Address change will be aborted. Old receiving address will be used.", comment: "")),
        primaryButton: .destructive(Text(NSLocalizedString("Abort", comment: "")), action: abortSwitchAddress),
        secondaryButton: .cancel()
    )
}

func syncConnectionForceAlert(_ syncConnectionForce: @escaping () -> Void) -> Alert {
    Alert(
        title: Text(NSLocalizedString("Renegotiate encryption?", comment: "")),
        message: Text(NSLocalizedString("The encryption is working and the new encryption agreement is not required. It may result in connection errors!", comment: "")),
        primaryButton: .destructive(Text(NSLocalizedString("Renegotiate", comment: "")), action: syncConnectionForce),
        secondaryButton: .cancel()
    )
}

func queueInfoText(_ info: (RcvMsgInfo?, ServerQueueInfo)) -> String {
    let (rcvMsgInfo, qInfo) = info
    var msgInfo: String
    if let rcvMsgInfo { msgInfo = encodeJSON(rcvMsgInfo) } else { msgInfo = "none" }
    return String.localizedStringWithFormat(NSLocalizedString("server queue info: %@\n\nlast received msg: %@", comment: "queue info"), encodeJSON(qInfo), msgInfo)
}

func queueInfoAlert(_ info: String) -> Alert {
    Alert(
        title: Text(NSLocalizedString("Message queue info", comment: "")),
        message: Text(info),
        primaryButton: .default(Text(NSLocalizedString("Ok", comment: ""))),
        secondaryButton: .default(Text(NSLocalizedString("Copy", comment: ""))) { UIPasteboard.general.setItems([["public.utf8-plain-text": info]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true]) }
    )
}

func deleteContactDialog(
    _ chat: Chat,
    _ contact: Contact,
    dismissToChatList: Bool,
    showAlert: @escaping (SomeAlert) -> Void,
    showActionSheet: @escaping (SomeActionSheet) -> Void,
    showSheetContent: @escaping (SomeSheet<AnyView>) -> Void
) {
    if contact.sndReady && contact.active && !contact.chatDeleted {
        deleteContactOrConversationDialog(chat, contact, dismissToChatList, showAlert, showActionSheet, showSheetContent)
    } else if contact.sndReady && contact.active && contact.chatDeleted {
        deleteContactWithoutConversation(chat, contact, dismissToChatList, showAlert, showActionSheet)
    } else { // !(contact.sndReady && contact.active)
        deleteNotReadyContact(chat, contact, dismissToChatList, showAlert, showActionSheet)
    }
}

func setChatTTL(_ ttl: ChatTTL, hasPreviousTTL: Bool, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
    let title = if ttl.neverExpires {
        NSLocalizedString("Disable automatic message deletion?", comment: "alert title")
    } else if ttl.usingDefault || hasPreviousTTL {
        NSLocalizedString("Change automatic message deletion?", comment: "alert title")
    } else {
        NSLocalizedString("Enable automatic message deletion?", comment: "alert title")
    }

    let message = if ttl.neverExpires {
        NSLocalizedString("Messages in this chat will never be deleted.", comment: "alert message")
    } else {
        NSLocalizedString("This action cannot be undone - the messages sent and received in this chat earlier than selected will be deleted.", comment: "alert message")
    }

    showAlert(title, message: message) {
        [
            UIAlertAction(
                title: ttl.neverExpires ?  NSLocalizedString("Disable delete messages", comment: "alert button") : NSLocalizedString("Delete messages", comment: "alert button"),
                style: .destructive,
                handler: { _ in onConfirm() }
            ),
            UIAlertAction(title: NSLocalizedString("Cancel", comment: "alert button"), style: .cancel, handler: { _ in onCancel() })
        ]
    }
}

private func deleteContactOrConversationDialog(
    _ chat: Chat,
    _ contact: Contact,
    _ dismissToChatList: Bool,
    _ showAlert: @escaping (SomeAlert) -> Void,
    _ showActionSheet: @escaping (SomeActionSheet) -> Void,
    _ showSheetContent: @escaping (SomeSheet<AnyView>) -> Void
) {
    showActionSheet(SomeActionSheet(
        actionSheet: ActionSheet(
            title: Text(NSLocalizedString("Delete contact?", comment: "")),
            buttons: [
                .destructive(Text(NSLocalizedString("Only delete conversation", comment: ""))) {
                    deleteContactMaybeErrorAlert(chat, contact, chatDeleteMode: .messages, dismissToChatList, showAlert)
                },
                .destructive(Text(NSLocalizedString("Delete contact", comment: ""))) {
                    showSheetContent(SomeSheet(
                        content: { AnyView(
                            DeleteActiveContactDialog(
                                chat: chat,
                                contact: contact,
                                dismissToChatList: dismissToChatList,
                                showAlert: showAlert
                            )
                        ) },
                        id: "DeleteActiveContactDialog"
                    ))
                },
                .cancel()
            ]
        ),
        id: "deleteContactOrConversationDialog"
    ))
}

private func deleteContactMaybeErrorAlert(
    _ chat: Chat,
    _ contact: Contact,
    chatDeleteMode: ChatDeleteMode,
    _ dismissToChatList: Bool,
    _ showAlert: @escaping (SomeAlert) -> Void
) {
    Task {
        let alert_ = await deleteContactChat(chat, chatDeleteMode: chatDeleteMode)
        if let alert = alert_ {
            showAlert(SomeAlert(alert: alert, id: "deleteContactMaybeErrorAlert, error"))
        } else {
            if dismissToChatList {
                await MainActor.run {
                    ChatModel.shared.chatId = nil
                }
                DispatchQueue.main.async {
                    dismissAllSheets(animated: true) {
                        if case .messages = chatDeleteMode, showDeleteConversationNoticeDefault.get() {
                            AlertManager.shared.showAlert(deleteConversationNotice(contact))
                        } else if chatDeleteMode.isEntity, showDeleteContactNoticeDefault.get() {
                            AlertManager.shared.showAlert(deleteContactNotice(contact))
                        }
                    }
                }
            } else {
                if case .messages = chatDeleteMode, showDeleteConversationNoticeDefault.get() {
                    showAlert(SomeAlert(alert: deleteConversationNotice(contact), id: "deleteContactMaybeErrorAlert, deleteConversationNotice"))
                } else if chatDeleteMode.isEntity, showDeleteContactNoticeDefault.get() {
                    showAlert(SomeAlert(alert: deleteContactNotice(contact), id: "deleteContactMaybeErrorAlert, deleteContactNotice"))
                }
            }
        }
    }
}

private func deleteConversationNotice(_ contact: Contact) -> Alert {
    return Alert(
        title: Text(NSLocalizedString("Conversation deleted!", comment: "")),
        message: Text(String.localizedStringWithFormat(NSLocalizedString("You can send messages to %@ from Archived contacts.", comment: ""), contact.displayName)),
        primaryButton: .default(Text(NSLocalizedString("Don't show again", comment: ""))) {
            showDeleteConversationNoticeDefault.set(false)
        },
        secondaryButton: .default(Text(NSLocalizedString("Ok", comment: "")))
    )
}

private func deleteContactNotice(_ contact: Contact) -> Alert {
    return Alert(
        title: Text(NSLocalizedString("Contact deleted!", comment: "")),
        message: Text(String.localizedStringWithFormat(NSLocalizedString("You can still view conversation with %@ in the list of chats.", comment: ""), contact.displayName)),
        primaryButton: .default(Text(NSLocalizedString("Don't show again", comment: ""))) {
            showDeleteContactNoticeDefault.set(false)
        },
        secondaryButton: .default(Text(NSLocalizedString("Ok", comment: "")))
    )
}

enum ContactDeleteMode {
    case full
    case entity

    public func toChatDeleteMode(notify: Bool) -> ChatDeleteMode {
        switch self {
        case .full: .full(notify: notify)
        case .entity: .entity(notify: notify)
        }
    }
}

struct DeleteActiveContactDialog: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: AppTheme
    var chat: Chat
    var contact: Contact
    var dismissToChatList: Bool
    var showAlert: (SomeAlert) -> Void
    @State private var keepConversation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(NSLocalizedString("Keep conversation", comment: ""), isOn: $keepConversation)

                    Button(role: .destructive) {
                        dismiss()
                        deleteContactMaybeErrorAlert(chat, contact, chatDeleteMode: contactDeleteMode.toChatDeleteMode(notify: false), dismissToChatList, showAlert)
                    } label: {
                        Text(NSLocalizedString("Delete without notification", comment: ""))
                    }

                    Button(role: .destructive) {
                        dismiss()
                        deleteContactMaybeErrorAlert(chat, contact, chatDeleteMode: contactDeleteMode.toChatDeleteMode(notify: true), dismissToChatList, showAlert)
                    } label: {
                        Text(NSLocalizedString("Delete and notify contact", comment: ""))
                    }
                } footer: {
                    Text(NSLocalizedString("Contact will be deleted - this cannot be undone!", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        }
    }

    var contactDeleteMode: ContactDeleteMode {
        keepConversation ? .entity : .full
    }
}

private func deleteContactWithoutConversation(
    _ chat: Chat,
    _ contact: Contact,
    _ dismissToChatList: Bool,
    _ showAlert: @escaping (SomeAlert) -> Void,
    _ showActionSheet: @escaping (SomeActionSheet) -> Void
) {
    showActionSheet(SomeActionSheet(
        actionSheet: ActionSheet(
            title: Text(NSLocalizedString("Confirm contact deletion?", comment: "")),
            buttons: [
                .destructive(Text(NSLocalizedString("Delete and notify contact", comment: ""))) {
                    deleteContactMaybeErrorAlert(chat, contact, chatDeleteMode: .full(notify: true), dismissToChatList, showAlert)
                },
                .destructive(Text(NSLocalizedString("Delete without notification", comment: ""))) {
                    deleteContactMaybeErrorAlert(chat, contact, chatDeleteMode: .full(notify: false), dismissToChatList, showAlert)
                },
                .cancel()
            ]
        ),
        id: "deleteContactWithoutConversation"
    ))
}

private func deleteNotReadyContact(
    _ chat: Chat,
    _ contact: Contact,
    _ dismissToChatList: Bool,
    _ showAlert: @escaping (SomeAlert) -> Void,
    _ showActionSheet: @escaping (SomeActionSheet) -> Void
) {
    showActionSheet(SomeActionSheet(
        actionSheet: ActionSheet(
            title: Text(NSLocalizedString("Confirm contact deletion?", comment: "")),
            buttons: [
                .destructive(Text(NSLocalizedString("Confirm", comment: ""))) {
                    deleteContactMaybeErrorAlert(chat, contact, chatDeleteMode: .full(notify: false), dismissToChatList, showAlert)
                },
                .cancel()
            ]
        ),
        id: "deleteNotReadyContact"
    ))
}

struct ChatInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ChatInfoView(
            chat: Chat(chatInfo: ChatInfo.sampleData.direct, chatItems: []),
            contact: Contact.sampleData,
            localAlias: "",
            featuresAllowed: contactUserPrefsToFeaturesAllowed(Contact.sampleData.mergedPreferences),
            currentFeaturesAllowed: contactUserPrefsToFeaturesAllowed(Contact.sampleData.mergedPreferences),
             onSearch: {}
        )
    .previewEnvironment()
    }
}

@MainActor
func showDomainVerificationAlert(_ displayName: String, _ domainClaim: PopopxDomainClaim, _ verified: Bool) {
    let title = verified
        ? NSLocalizedString("Domain verified", comment: "")
        : NSLocalizedString("Domain not verified", comment: "")
    let message = verified
        ? String.localizedStringWithFormat(NSLocalizedString("%@ is verified for domain %@", comment: ""), displayName, domainClaim.domain)
        : String.localizedStringWithFormat(NSLocalizedString("%@ claims domain %@ but it is not verified", comment: ""), displayName, domainClaim.domain)
    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(title), message: LocalizedStringKey(message))
}
