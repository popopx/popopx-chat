//
//  PrivacySettings.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 29/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - Haptic Feedback Helper

private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

struct PrivacySettings: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @AppStorage(GROUP_DEFAULT_PRIVACY_ACCEPT_IMAGES, store: groupDefaults) private var autoAcceptImages = true
    @AppStorage(GROUP_DEFAULT_PRIVACY_LINK_PREVIEWS, store: groupDefaults) private var useLinkPreviews = true
    @AppStorage(GROUP_DEFAULT_PRIVACY_SANITIZE_LINKS, store: groupDefaults) private var privacySanitizeLinks = false
    @AppStorage(DEFAULT_PRIVACY_SHOW_CHAT_PREVIEWS) private var showChatPreviews = true
    @AppStorage(DEFAULT_PRIVACY_VERIFY_POPOPX_NAMES) private var verifyPopopxNames = false
    @AppStorage(DEFAULT_PRIVACY_SAVE_LAST_DRAFT) private var saveLastDraft = true
    @AppStorage(DEFAULT_PRIVACY_SHOW_SIGNATURE) private var showSignature = true
    @AppStorage(DEFAULT_PRIVACY_SHOW_FILE_ENCRYPTION) private var showFileEncryption = true
    @AppStorage(GROUP_DEFAULT_PRIVACY_ENCRYPT_LOCAL_FILES, store: groupDefaults) private var encryptLocalFiles = true
    @AppStorage(GROUP_DEFAULT_PRIVACY_ASK_TO_APPROVE_RELAYS, store: groupDefaults) private var askToApproveRelays = true
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @AppStorage(DEFAULT_PRIVACY_PROTECT_SCREEN) private var protectScreen = false
    @AppStorage(DEFAULT_BINTHERE_SECURITY) private var binThereSecurity = true
    @AppStorage(DEFAULT_PERFORM_LA) private var prefPerformLA = false
    @State private var currentLAMode = privacyLocalAuthModeDefault.get()
    @AppStorage(DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS) private var privacyMediaBlurRadius: Int = 0
    @State private var contactReceipts = false
    @State private var contactReceiptsReset = false
    @State private var contactReceiptsOverrides = 0
    @State private var contactReceiptsDialogue = false
    @State private var groupReceipts = false
    @State private var groupReceiptsReset = false
    @State private var groupReceiptsOverrides = 0
    @State private var groupReceiptsDialogue = false
    @State private var autoAcceptMemberContacts = false
    @State private var autoAcceptMemberContactsReset = false
    @State private var autoAcceptGroupInvitations = false
    @State private var autoAcceptGroupInvitationsReset = false
    @State private var alert: PrivacySettingsViewAlert?

    enum PrivacySettingsViewAlert: Identifiable {
        case error(title: LocalizedStringKey, error: LocalizedStringKey = "")

        var id: String {
            switch self {
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        VStack {
            List {
                deviceSection()
                chatsSection()
                filesSection()
                contactRequestsSection()
                deliveryReceiptsSection()
                notificationsSection()
                receiptsSection()
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onChange(of: contactReceipts) {_, _ in
            triggerHapticFeedback(.light)
            if contactReceiptsReset {
                contactReceiptsReset = false
            } else {
                setOrAskSendReceiptsContacts(contactReceipts)
            }
        }
        .onChange(of: groupReceipts) {_, _ in
            triggerHapticFeedback(.light)
            if groupReceiptsReset {
                groupReceiptsReset = false
            } else {
                setOrAskSendReceiptsGroups(groupReceipts)
            }
        }
        .onChange(of: autoAcceptMemberContacts) {_, _ in
            triggerHapticFeedback(.light)
            if autoAcceptMemberContactsReset {
                autoAcceptMemberContactsReset = false
            } else {
                setAutoAcceptMemberContacts(autoAcceptMemberContacts)
            }
        }
        .onChange(of: autoAcceptGroupInvitations) {_, _ in
            triggerHapticFeedback(.light)
            if autoAcceptGroupInvitationsReset {
                autoAcceptGroupInvitationsReset = false
            } else {
                setAutoAcceptGroupInvitations(autoAcceptGroupInvitations)
            }
        }
        .onAppear {
            if let u = m.currentUser {
                if autoAcceptMemberContacts != u.autoAcceptMemberContacts {
                    autoAcceptMemberContactsReset = true
                    autoAcceptMemberContacts = u.autoAcceptMemberContacts
                }
                if autoAcceptGroupInvitations != u.autoAcceptGroupInvitations {
                    autoAcceptGroupInvitationsReset = true
                    autoAcceptGroupInvitations = u.autoAcceptGroupInvitations
                }
            }
        }
        .popopxBranded()
    }

    private func setEncryptLocalFiles(_ enable: Bool) {
        do {
            try apiSetEncryptLocalFiles(enable)
        } catch let error {
            let err = responseError(error)
            logger.error("apiSetEncryptLocalFiles \(err)")
            alert = .error(title: LocalizedStringKey(NSLocalizedString("privacy_error_title", comment: "")), error: LocalizedStringKey(err))
        }
    }

    private func setOrAskSendReceiptsContacts(_ enable: Bool) {
        contactReceiptsOverrides = m.chats.reduce(0) { count, chat in
            let sendRcpts = chat.chatInfo.contact?.chatSettings.sendRcpts
            return count + (sendRcpts == nil || sendRcpts == enable ? 0 : 1)
        }
        if contactReceiptsOverrides == 0 {
            setSendReceiptsContacts(enable, clearOverrides: false)
        } else {
            contactReceiptsDialogue = true
        }
    }

    private var contactReceiptsDialogTitle: LocalizedStringKey {
        contactReceipts
        ? LocalizedStringKey(NSLocalizedString("privacy_receipts_disabled_contacts", comment: ""))
        : LocalizedStringKey(NSLocalizedString("privacy_receipts_enabled_contacts", comment: ""))
    }

    private func setSendReceiptsContacts(_ enable: Bool, clearOverrides: Bool) {
        Task {
            do {
                if let currentUser = m.currentUser {
                    let userMsgReceiptSettings = UserMsgReceiptSettings(enable: enable, clearOverrides: clearOverrides)
                    try await apiSetUserContactReceipts(currentUser.userId, userMsgReceiptSettings: userMsgReceiptSettings)
                    privacyDeliveryReceiptsSet.set(true)
                    await MainActor.run {
                        var updatedUser = currentUser
                        updatedUser.sendRcptsContacts = enable
                        m.updateUser(updatedUser)
                        if clearOverrides {
                            m.chats.forEach { chat in
                                if var contact = chat.chatInfo.contact {
                                    let sendRcpts = contact.chatSettings.sendRcpts
                                    if sendRcpts != nil && sendRcpts != enable {
                                        contact.chatSettings.sendRcpts = nil
                                        m.updateContact(contact)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("privacy_error_setting_receipts", comment: "")), error: LocalizedStringKey("Error: ^[responseError(error)]"))
            }
        }
    }

    private func setOrAskSendReceiptsGroups(_ enable: Bool) {
        groupReceiptsOverrides = m.chats.reduce(0) { count, chat in
            let sendRcpts = chat.chatInfo.groupInfo?.chatSettings.sendRcpts
            return count + (sendRcpts == nil || sendRcpts == enable ? 0 : 1)
        }
        if groupReceiptsOverrides == 0 {
            setSendReceiptsGroups(enable, clearOverrides: false)
        } else {
            groupReceiptsDialogue = true
        }
    }

    private var groupReceiptsDialogTitle: LocalizedStringKey {
        groupReceipts
        ? LocalizedStringKey(NSLocalizedString("privacy_receipts_disabled_groups", comment: ""))
        : LocalizedStringKey(NSLocalizedString("privacy_receipts_enabled_groups", comment: ""))
    }

    private func setSendReceiptsGroups(_ enable: Bool, clearOverrides: Bool) {
        Task {
            do {
                if let currentUser = m.currentUser {
                    let userMsgReceiptSettings = UserMsgReceiptSettings(enable: enable, clearOverrides: clearOverrides)
                    try await apiSetUserGroupReceipts(currentUser.userId, userMsgReceiptSettings: userMsgReceiptSettings)
                    privacyDeliveryReceiptsSet.set(true)
                    await MainActor.run {
                        var updatedUser = currentUser
                        updatedUser.sendRcptsSmallGroups = enable
                        m.updateUser(updatedUser)
                        if clearOverrides {
                            m.chats.forEach { chat in
                                if var groupInfo = chat.chatInfo.groupInfo {
                                    let sendRcpts = groupInfo.chatSettings.sendRcpts
                                    if sendRcpts != nil && sendRcpts != enable {
                                        groupInfo.chatSettings.sendRcpts = nil
                                        m.updateGroup(groupInfo)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("privacy_error_setting_receipts", comment: "")), error: LocalizedStringKey("Error: ^[responseError(error)]"))
            }
        }
    }

    private func setAutoAcceptMemberContacts(_ enable: Bool) {
        Task {
            do {
                if let currentUser = m.currentUser {
                    try await apiSetUserAutoAcceptMemberContacts(currentUser.userId, enable: enable)
                    await MainActor.run {
                        var updatedUser = currentUser
                        updatedUser.autoAcceptMemberContacts = enable
                        m.updateUser(updatedUser)
                    }
                }
            } catch {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("privacy_error_setting_auto_accept", comment: "")), error: LocalizedStringKey("Error: ^[responseError(error)]"))
            }
        }
    }

    private func setAutoAcceptGroupInvitations(_ enable: Bool) {
        Task {
            do {
                if let currentUser = m.currentUser {
                    try await apiSetUserAutoAcceptGroupInvitations(currentUser.userId, enable: enable)
                    await MainActor.run {
                        var updatedUser = currentUser
                        updatedUser.autoAcceptGroupInvitations = enable
                        m.updateUser(updatedUser)
                    }
                }
            } catch {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("privacy_error_setting_auto_accept", comment: "")), error: LocalizedStringKey("Error: ^[responseError(error)]"))
            }
        }
    }

    private func popopxLockRow(_ value: LocalizedStringKey) -> some View {
        HStack {
            Text(String(localized: "POPOPX Lock", comment: "App lock feature name"))
            Spacer()
            Text(value)
        }
    }

    private func blurRadiusText(_ radius: Int) -> String {
        switch radius {
        case 0: return NSLocalizedString("Off", comment: "blur media")
        case 12: return NSLocalizedString("Soft", comment: "blur media")
        case 24: return NSLocalizedString("Medium", comment: "blur media")
        case 48: return NSLocalizedString("Strong", comment: "blur media")
        default: return "\(radius)"
        }
    }

    private func updateLinkPreviews(_ enabled: Bool) {
        groupDefaults.set(enabled, forKey: GROUP_DEFAULT_PRIVACY_LINK_PREVIEWS)
        privacyLinkPreviewsShowAlertGroupDefault.set(false)
    }

    private func updateMessageDraft(_ enabled: Bool) {
        if !enabled {
            m.draft = nil
            m.draftChatId = nil
        }
    }

    @ViewBuilder
    private func deviceSection() -> some View {
        Section(header: Text(String(localized: "Device", comment: "Privacy settings section header for device-level security options")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
            NavigationLink {
                PopopxLockView(prefPerformLA: $prefPerformLA, currentLAMode: $currentLAMode)
                    .navigationTitle(String(localized: "POPOPX Lock", comment: "App lock feature name"))
                    .modifier(ThemedBackground(grouped: true))
            } label: {
                if prefPerformLA {
                    settingsRow("lock.fill", color: QuantumColors.success) {
                        popopxLockRow(currentLAMode.text)
                    }
                } else {
                    settingsRow("lock", color: theme.colors.secondary) {
                        popopxLockRow(LocalizedStringKey("Off"))
                    }
                }
            }
            settingsRow("eye.slash", color: theme.colors.secondary) {
                Toggle(String(localized: "Protect app screen", comment: "Toggle to enable screen protection - prevents screenshots and screen recording"), isOn: $protectScreen)
            }
            settingsRow("shield.checkered", color: QuantumColors.accent) {
                Toggle(String(localized: "binthere_security_enhanced", comment: "Toggle to enable BinThere burn-after-read enhanced security (gaze tracking, anti-photography, evidence capture)"), isOn: $binThereSecurity)
            }
        }
    }

    @ViewBuilder
    private func chatsSection() -> some View {
        Section {
            settingsRow("network", color: theme.colors.secondary) {
                Toggle(String(localized: "Send link previews", comment: "Toggle to enable/disable URL link preview generation in chat messages"), isOn: $useLinkPreviews)
                    .onChange(of: useLinkPreviews) {_, linkPreviews in
                        updateLinkPreviews(linkPreviews)
                    }
            }
            settingsRow("link", color: theme.colors.secondary) {
                Toggle(String(localized: "Remove link tracking", comment: "Toggle to strip tracking parameters from URLs for privacy"), isOn: $privacySanitizeLinks)
            }
            settingsRow("message", color: theme.colors.secondary) {
                Toggle(String(localized: "Show last messages", comment: "Toggle to display message previews in chat list"), isOn: $showChatPreviews)
            }
            settingsRow("rectangle.and.pencil.and.ellipsis", color: theme.colors.secondary) {
                Toggle(String(localized: "Message draft", comment: "Toggle to save unsent message drafts when switching chats"), isOn: $saveLastDraft)
            }
            .onChange(of: saveLastDraft) {_, saveDraft in
                updateMessageDraft(saveDraft)
            }
        } header: {
            Text(String(localized: "Chats", comment: "Privacy settings section header for chat-related options"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        }
    }

    @ViewBuilder
    private func filesSection() -> some View {
        Section {
            settingsRow("lock.doc", color: theme.colors.secondary) {
                Toggle(String(localized: "Encrypt local files", comment: "Toggle to enable encryption of downloaded files stored on device"), isOn: $encryptLocalFiles)
                    .onChange(of: encryptLocalFiles) { _, newValue in
                        triggerHapticFeedback(.light)
                        setEncryptLocalFiles(newValue)
                    }
            }
            settingsRow("photo", color: theme.colors.secondary) {
                Toggle(String(localized: "Auto-accept images", comment: "Toggle to automatically accept incoming image files without confirmation"), isOn: $autoAcceptImages)
                    .onChange(of: autoAcceptImages) { _, newValue in
                        triggerHapticFeedback(.light)
                        privacyAcceptImagesGroupDefault.set(newValue)
                    }
            }
            settingsRow("circle.filled.pattern.diagonalline.rectangle", color: theme.colors.secondary) {
                Picker(LocalizedStringKey(NSLocalizedString("privacy_blur_media", comment: "")), selection: $privacyMediaBlurRadius) {
                    let values = [0, 12, 24, 48] + ([0, 12, 24, 48].contains(privacyMediaBlurRadius) ? [] : [privacyMediaBlurRadius])
                    ForEach(values, id: \.self) { radius in
                        Text(blurRadiusText(radius)).tag(radius)
                    }
                }
            }
        } header: {
            Text(String(localized: "Files", comment: "Privacy settings section header for file and media handling options"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            if askToApproveRelays {
                Text(String(localized: "The app will ask to confirm downloads from unknown file servers (except .onion).", comment: "Footer explaining file server approval behavior - .onion refers to Tor hidden services"))
                    .foregroundColor(theme.colors.secondary)
            } else {
                Text(String(localized: "Without Tor or VPN, your IP address will be visible to file servers.", comment: "Warning about IP exposure when not using privacy networks"))
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    @ViewBuilder
    private func contactRequestsSection() -> some View {
        Section {
            settingsRow("person", color: theme.colors.secondary) {
                Toggle(String(localized: "Contact requests in groups", comment: "Toggle to automatically accept contact requests from group members"), isOn: $autoAcceptMemberContacts)
            }
            settingsRow("person.2", color: theme.colors.secondary) {
                Toggle(String(localized: "Group invitations", comment: "Toggle to automatically accept group invitations"), isOn: $autoAcceptGroupInvitations)
            }
        } header: {
            Text(String(localized: "Auto-accept", comment: "Section header for auto-accept settings"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            Text(String(localized: "These settings are for your current profile **\(m.currentUser?.displayName ?? "")**.", comment: "Footer indicating which user profile the settings apply to"))
                .foregroundColor(theme.colors.secondary)
        }
    }

    @ViewBuilder
    private func deliveryReceiptsSection() -> some View {
        Section {
            // TODO [TODO-FEATURE: medium] morePrivacyView not available
            // NavigationLink(destination: morePrivacyView) {
            //     settingsRow("ellipsis", color: theme.colors.secondary) { Text(String(localized: "More privacy", comment: "Navigation link to additional privacy settings")) }
            // }
            settingsRow("person.2", color: theme.colors.secondary) {
                Toggle(String(localized: "Small groups (max 20)", comment: "Toggle to send delivery receipts only to small groups with 20 or fewer members"), isOn: $groupReceipts)
            }
        } header: {
            Text(String(localized: "Send delivery receipts to", comment: "Section header for configuring who receives message delivery confirmations"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            VStack(alignment: .leading) {
                Text(String(localized: "These settings are for your current profile **\(m.currentUser?.displayName ?? "")**.", comment: "Footer indicating which user profile the settings apply to - markdown bold syntax preserved"))
                Text(String(localized: "They can be overridden in contact and group settings.", comment: "Note that individual chat settings take precedence over these global defaults"))
            }
        }
        settingsRow("number", color: theme.colors.secondary) {
            Toggle(String(localized: "Verify POPOPX names", comment: "Toggle to enable verification of POPOPX protocol identifiers for security"), isOn: $verifyPopopxNames)
        }
    }

    @ViewBuilder
    private func notificationsSection() -> some View {
        Section {
            NavigationLink {
                List {
                    Section {
                        SelectionListView(list: NotificationPreviewMode.values, selection: $m.notificationPreview) { previewMode in
                            ntfPreviewModeGroupDefault.set(previewMode)
                            m.notificationPreview = previewMode
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "You can set lock screen notification preview via settings.", comment: "Instructions that users can configure notification previews in system Settings app"))
                                .foregroundColor(theme.colors.secondary)
                            Button(String(localized: "Open Settings", comment: "Button to launch iOS Settings app")) {
                                DispatchQueue.main.async {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                    }
                                }
                            }
                            .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .scrollContentBackground(.hidden)
                .navigationTitle(String(localized: "Show preview", comment: "Navigation title for notification preview mode selection screen"))
                .modifier(ThemedBackground(grouped: true))
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                HStack {
                    Text(String(localized: "Show preview", comment: "Label for notification preview setting"))
                    Spacer()
                    Text(m.notificationPreview.label)
                }
            }
        } header: {
            Text(String(localized: "Notifications", comment: "Section header for notification-related privacy settings"))
                .foregroundColor(theme.colors.secondary)
        }
    }

    @ViewBuilder
    private func receiptsSection() -> some View {
        Section {
            settingsRow("person", color: theme.colors.secondary) {
                Toggle(String(localized: "Contacts", comment: "Toggle to send delivery receipts to individual contacts"), isOn: $contactReceipts)
            }
            settingsRow("person.2", color: theme.colors.secondary) {
                Toggle(String(localized: "Small groups (max 20)", comment: "Toggle to send delivery receipts to small groups with 20 or fewer members"), isOn: $groupReceipts)
            }
        } header: {
            Text(String(localized: "Send delivery receipts to", comment: "Section header for configuring who receives message delivery confirmations"))
                .foregroundColor(theme.colors.secondary)
        } footer: {
            VStack(alignment: .leading) {
                Text(String(localized: "These settings are for your current profile **\(m.currentUser?.displayName ?? "")**.", comment: "Footer indicating which user profile the settings apply to - markdown bold syntax preserved"))
                Text(String(localized: "They can be overridden in contact and group settings.", comment: "Note that individual chat settings take precedence over these global defaults"))
            }
            .foregroundColor(theme.colors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog(contactReceiptsDialogTitle, isPresented: $contactReceiptsDialogue, titleVisibility: .visible) {
            Button(contactReceipts ? String(localized: "Enable (keep overrides)", comment: "Button to enable feature while preserving per-contact custom settings") : String(localized: "Disable (keep overrides)", comment: "Button to disable feature while preserving per-contact custom settings")) {
                setSendReceiptsContacts(contactReceipts, clearOverrides: false)
            }
            Button(contactReceipts ? String(localized: "Enable for all", comment: "Button to enable feature for all contacts, removing custom settings") : String(localized: "Disable for all", comment: "Button to disable feature for all contacts, removing custom settings"), role: .destructive) {
                setSendReceiptsContacts(contactReceipts, clearOverrides: true)
            }
            Button(String(localized: "Cancel", comment: "Standard cancel button text"), role: .cancel) {
                contactReceiptsReset = true
                contactReceipts.toggle()
            }
        }
        .confirmationDialog(groupReceiptsDialogTitle, isPresented: $groupReceiptsDialogue, titleVisibility: .visible) {
            Button(groupReceipts ? String(localized: "Enable (keep overrides)", comment: "Button to enable feature while preserving per-group custom settings") : String(localized: "Disable (keep overrides)", comment: "Button to disable feature while preserving per-group custom settings")) {
                setSendReceiptsGroups(groupReceipts, clearOverrides: false)
            }
            Button(groupReceipts ? String(localized: "Enable for all", comment: "Button to enable feature for all groups, removing custom settings") : String(localized: "Disable for all", comment: "Button to disable feature for all groups, removing custom settings"), role: .destructive) {
                setSendReceiptsGroups(groupReceipts, clearOverrides: true)
            }
            Button(String(localized: "Cancel", comment: "Standard cancel button text"), role: .cancel) {
                groupReceiptsReset = true
                groupReceipts.toggle()
            }
        }
    }
}

enum LAMode: String, Identifiable, CaseIterable {
    case system
    case passcode

    public var id: Self { self }

    var text: LocalizedStringKey {
        switch self {
        case .system: return LocalizedStringKey(NSLocalizedString("privacy_lock_system", comment: ""))
        case .passcode: return LocalizedStringKey(NSLocalizedString("privacy_lock_passcode", comment: ""))
        }
    }
}

struct PopopxLockView: View {
    @Binding var prefPerformLA: Bool
    @Binding var currentLAMode: LAMode
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_LA_NOTICE_SHOWN) private var prefLANoticeShown = false
    @State private var laMode: LAMode = privacyLocalAuthModeDefault.get()
    @AppStorage(DEFAULT_LA_LOCK_DELAY) private var laLockDelay = 30
    @State private var performLA: Bool = UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)
    @State private var selfDestruct: Bool = UserDefaults.standard.bool(forKey: DEFAULT_LA_SELF_DESTRUCT)
    @State private var currentSelfDestruct: Bool = UserDefaults.standard.bool(forKey: DEFAULT_LA_SELF_DESTRUCT)
    @AppStorage(DEFAULT_LA_SELF_DESTRUCT_DISPLAY_NAME) private var selfDestructDisplayName = ""
    @AppStorage(GROUP_DEFAULT_ALLOW_SHARE_EXTENSION, store: groupDefaults) private var allowShareExtension = false
    @State private var performLAToggleReset = false
    @State private var performLAModeReset = false
    @State private var performLASelfDestructReset = false
    @State private var showPasswordAction: PasswordAction? = nil
    @State private var showChangePassword = false
    @State var laAlert: LASettingViewAlert? = nil

    enum LASettingViewAlert: Identifiable {
        case laTurnedOnAlert
        case laFailedAlert
        case laUnavailableInstructionAlert
        case laUnavailableTurningOffAlert
        case laPasscodeSetAlert
        case laPasscodeChangedAlert
        case laSelfDestructPasscodeSetAlert
        case laSelfDestructPasscodeChangedAlert
        case laPasscodeNotChangedAlert

        var id: Self { self }
    }

    enum PasswordAction: Identifiable {
        case enableAuth
        case toggleMode
        case changePasscode
        case enableSelfDestruct
        case changeSelfDestructPasscode
        case selfDestructInfo

        var id: Self { self }
    }

    let laDelays: [Int] = [10, 30, 60, 180, 600, 0]

    func laDelayText(_ t: Int) -> LocalizedStringKey {
        let m = t / 60
        let s = t % 60
        return t == 0
            ? LocalizedStringKey(NSLocalizedString("privacy_timeout_immediately", comment: ""))
            : m == 0 || s != 0
            ? LocalizedStringKey("^[\(s)] seconds](inflect: true)")
            : LocalizedStringKey("^[\(m)] minutes](inflect: true)")
    }

    var body: some View {
        VStack {
            List {
                Section("") {
                    Toggle(String(localized: "Enable lock", comment: "Toggle to enable app lock security feature"), isOn: $performLA)
                    Picker(String(localized: "Lock mode", comment: "Picker label for selecting authentication method"), selection: $laMode) {
                        ForEach(LAMode.allCases) { mode in
                            Text(mode.text)
                        }
                    }
                    .frame(height: 36)
                    if performLA {
                        Picker(String(localized: "Lock after", comment: "Picker label for selecting auto-lock timeout duration"), selection: $laLockDelay) {
                            let delays = laDelays.contains(laLockDelay) ? laDelays : [laLockDelay] + laDelays
                            ForEach(delays, id: \.self) { t in
                                Text(laDelayText(t))
                            }
                        }
                        .frame(height: 36)
                        if showChangePassword && laMode == .passcode {
                            Button(String(localized: "Change passcode", comment: "Button to modify the current app passcode")) {
                                changeLAPassword()
                            }
                            .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                        }
                    }
                }

                if performLA {
                    Section(String(localized: "Share to POPOPX", comment: "Section header for iOS share extension permissions")) {
                        Toggle(String(localized: "Allow sharing", comment: "Toggle to permit other apps to share content to POPOPX"), isOn: $allowShareExtension)
                    }
                }

                if performLA && laMode == .passcode {
                    Section(header: Text(String(localized: "Self-destruct passcode", comment: "Section header for emergency data wipe passcode settings")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                        Toggle(isOn: $selfDestruct) {
                            HStack(spacing: 6) {
                                Text(String(localized: "Enable self-destruct", comment: "Toggle to activate emergency data deletion feature"))
                                Image(systemName: "info.circle")
                                    .foregroundColor(theme.colors.primary)
                                    .font(.subheadline)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel(NSLocalizedString("self_destruct_passcode_info", comment: "Self-destruct passcode info accessibility label"))
                            }
                            .onTapGesture {
                                showPasswordAction = .selfDestructInfo
                            }
                        }
                        if selfDestruct {
                            TextField(String(localized: "New display name", comment: "Placeholder text for entering profile name after self-destruct"), text: $selfDestructDisplayName)
                            Button(String(localized: "Change self-destruct passcode", comment: "Button to modify the emergency wipe passcode")) {
                                changeSelfDestructPassword()
                            }
                            .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                        }
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .onChange(of: performLA) {_,  performLAToggle in
            triggerHapticFeedback(.light)
            appLocalAuthEnabledGroupDefault.set(performLAToggle)
            prefLANoticeShown = true
            if performLAToggleReset {
                performLAToggleReset = false
            } else if performLAToggle {
                switch currentLAMode {
                case .system:
                    enableLA()
                case .passcode:
                    resetLA()
                    showPasswordAction = .enableAuth
                }
            } else {
                disableLA()
            }
        }
        .onChange(of: laMode) {_, _ in
            if performLAModeReset {
                performLAModeReset = false
            } else if prefPerformLA {
                toggleLAMode()
            } else {
                updateLAMode()
            }
        }
        .onChange(of: selfDestruct) {_, _ in
            triggerHapticFeedback(.light)
            if performLASelfDestructReset {
                performLASelfDestructReset = false
            } else if prefPerformLA {
                toggleSelfDestruct()
            }
        }
        .alert(item: $laAlert) { alertItem in
            switch alertItem {
            case .laTurnedOnAlert: return laTurnedOnAlert()
            case .laFailedAlert: return laFailedAlert()
            case .laUnavailableInstructionAlert: return laUnavailableInstructionAlert()
            case .laUnavailableTurningOffAlert: return laUnavailableTurningOffAlert()
            case .laPasscodeSetAlert: return passcodeAlert(LocalizedStringKey(NSLocalizedString("privacy_passcode_set", comment: "alert title")))
            case .laPasscodeChangedAlert: return passcodeAlert(LocalizedStringKey(NSLocalizedString("privacy_passcode_changed", comment: "alert title")))
            case .laSelfDestructPasscodeSetAlert: return selfDestructPasscodeAlert(LocalizedStringKey(NSLocalizedString("privacy_self_destruct_enabled", comment: "alert title")))
            case .laSelfDestructPasscodeChangedAlert: return selfDestructPasscodeAlert(LocalizedStringKey(NSLocalizedString("privacy_self_destruct_changed", comment: "alert title")))
            case .laPasscodeNotChangedAlert: return mkAlert(title: LocalizedStringKey(NSLocalizedString("privacy_passcode_not_changed", comment: "alert title")))
            }
        }
        .sheet(item: $showPasswordAction) { a in
            switch a {
            case .enableAuth:
                SetAppPasscodeView {
                    m.contentViewAccessAuthenticated = true
                    laLockDelay = 30
                    prefPerformLA = true
                    showChangePassword = true
                    showLAAlert(.laPasscodeSetAlert)
                } cancel: {
                    resetLAEnabled(false)
                }
            case .toggleMode:
                SetAppPasscodeView {
                    laLockDelay = 30
                    updateLAMode()
                    showChangePassword = true
                    showLAAlert(.laPasscodeSetAlert)
                } cancel: {
                    revertLAMode()
                }
            case .changePasscode:
                SetAppPasscodeView {
                    showLAAlert(.laPasscodeChangedAlert)
                } cancel: {
                    showLAAlert(.laPasscodeNotChangedAlert)
                }
            case .enableSelfDestruct:
                SetAppPasscodeView(
                    passcodeKeychain: kcSelfDestructPassword,
                    prohibitedPasscodeKeychain: kcAppPassword,
                    title: LocalizedStringKey(NSLocalizedString("privacy_set_passcode", comment: "set passcode view title")),
                    reason: NSLocalizedString("Enable self-destruct passcode", comment: "set passcode view")
                ) {
                    updateSelfDestruct()
                    showLAAlert(.laSelfDestructPasscodeSetAlert)
                } cancel: {
                    revertSelfDestruct()
                }
            case .changeSelfDestructPasscode:
                SetAppPasscodeView(
                    passcodeKeychain: kcSelfDestructPassword,
                    prohibitedPasscodeKeychain: kcAppPassword,
                    reason: NSLocalizedString("Change self-destruct passcode", comment: "set passcode view")
                ) {
                    showLAAlert(.laSelfDestructPasscodeChangedAlert)
                } cancel: {
                    showLAAlert(.laPasscodeNotChangedAlert)
                }
            case .selfDestructInfo:
                selfDestructInfoView()
            }
        }
        .onAppear {
            showChangePassword = prefPerformLA && currentLAMode == .passcode
        }
        .onDisappear() {
            m.laRequest = nil
        }
    }

    private func selfDestructInfoView() -> some View {
        VStack(alignment: .leading) {
            Text(String(localized: "Self-destruct", comment: "Title for emergency data deletion feature explanation screen"))
                .font(.largeTitle)
                .bold()
                .padding(.vertical)
            ScrollView {
                VStack(alignment: .leading) {
                    Group {
                        Text(String(localized: "If you enter your self-destruct passcode while opening the app:", comment: "Introduction explaining when self-destruct sequence triggers"))
                        VStack(spacing: 8) {
                            textListItem("1.", String(localized: "All app data is deleted."))
                            textListItem("2.", String(localized: "App passcode is replaced with self-destruct passcode."))
                            textListItem("3.", String(localized: "An empty chat profile with the provided name is created, and the app opens as usual."))
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func  showLAAlert(_ a: LASettingViewAlert) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            laAlert = a
        }
    }

    private func toggleLAMode() {
        authenticate(reason: NSLocalizedString("Change lock mode", comment: "authentication reason")) { laResult in
            switch laResult {
            case .failed:
                revertLAMode()
                laAlert = .laFailedAlert
            case .success:
                switch laMode {
                case .system:
                    updateLAMode()
                    authenticate(reason: NSLocalizedString("Enable POPOPX Lock", comment: "authentication reason")) { laResult in
                        switch laResult {
                        case .success:
                            _ = kcAppPassword.remove()
                            resetSelfDestruct()
                            laAlert = .laTurnedOnAlert
                        case .failed, .unavailable:
                            currentLAMode = .passcode
                            privacyLocalAuthModeDefault.set(.passcode)
                            revertLAMode()
                            laAlert = .laFailedAlert
                        }
                    }
                case .passcode:
                    showPasswordAction = .toggleMode
                }
            case .unavailable:
                disableUnavailableLA()
            }
        }
    }

    private func toggleSelfDestruct() {
        authenticate(reason: NSLocalizedString("Change self-destruct mode", comment: "authentication reason")) { laResult in
            switch laResult {
            case .failed:
                revertSelfDestruct()
                laAlert = .laFailedAlert
            case .success:
                if selfDestruct {
                    showPasswordAction = .enableSelfDestruct
                } else {
                    resetSelfDestruct()
                }
            case .unavailable:
                disableUnavailableLA()
            }
        }
    }

    private func changeLAPassword() {
        authenticate(title: LocalizedStringKey(NSLocalizedString("privacy_current_passcode", comment: "authentication title")), reason: NSLocalizedString("Change passcode", comment: "authentication reason")) { laResult in
            switch laResult {
            case .failed: laAlert = .laFailedAlert
            case .success: showPasswordAction = .changePasscode
            case .unavailable: disableUnavailableLA()
            }
        }
    }

    private func changeSelfDestructPassword() {
        authenticate(reason: NSLocalizedString("Change self-destruct passcode", comment: "authentication reason")) { laResult in
            switch laResult {
            case .failed: laAlert = .laFailedAlert
            case .success: showPasswordAction = .changeSelfDestructPasscode
            case .unavailable: disableUnavailableLA()
            }
        }
    }

    private func enableLA() {
        resetLA()
        authenticate(reason: NSLocalizedString("Enable POPOPX Lock", comment: "authentication reason")) { laResult in
            switch laResult {
            case .success:
                m.contentViewAccessAuthenticated = true
                prefPerformLA = true
                laAlert = .laTurnedOnAlert
            case .failed:
                resetLAEnabled(false)
                laAlert = .laFailedAlert
            case .unavailable:
                disableUnavailableLA()
            }
        }
    }

    private func disableUnavailableLA() {
        resetLAEnabled(false)
        laMode = .system
        updateLAMode()
        laAlert = .laUnavailableInstructionAlert
    }

    private func disableLA() {
        authenticate(reason: NSLocalizedString("Disable POPOPX Lock", comment: "authentication reason")) { laResult in
            switch (laResult) {
            case .success:
                prefPerformLA = false
                resetLA()
            case .failed:
                resetLAEnabled(true)
                laAlert = .laFailedAlert
            case .unavailable:
                prefPerformLA = false
                laAlert = .laUnavailableTurningOffAlert
            }
        }
    }

    private func resetLA() {
        _ = kcAppPassword.remove()
        laLockDelay = 30
        showChangePassword = false
        resetSelfDestruct()
    }

    private func resetLAEnabled(_ onOff: Bool) {
        prefPerformLA = onOff
        performLAToggleReset = true
        withAnimation { performLA = onOff }
    }

    private func revertLAMode() {
        performLAModeReset = true
        withAnimation { laMode = currentLAMode }
    }

    private func updateLAMode() {
        currentLAMode = laMode
        privacyLocalAuthModeDefault.set(laMode)
    }

    private func resetSelfDestruct() {
        _ = kcSelfDestructPassword.remove()
        selfDestruct = false
        updateSelfDestruct()
    }

    private func revertSelfDestruct() {
        performLASelfDestructReset = true
        withAnimation { selfDestruct = currentSelfDestruct }
    }

    private func updateSelfDestruct() {
        UserDefaults.standard.set(selfDestruct, forKey: DEFAULT_LA_SELF_DESTRUCT)
        currentSelfDestruct = selfDestruct
    }

    private func passcodeAlert(_ title: LocalizedStringKey) -> Alert {
        mkAlert(title: title, message: LocalizedStringKey(NSLocalizedString("privacy_remember_passcode_warning", comment: "passcode alert message")))
    }

    private func selfDestructPasscodeAlert(_ title: LocalizedStringKey) -> Alert {
        mkAlert(title: title, message: LocalizedStringKey(NSLocalizedString("privacy_self_destruct_data_warning", comment: "self-destruct passcode alert message")))
    }
}

struct PrivacySettings_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettings()
    }
}
