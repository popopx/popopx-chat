//
//  UserAddressView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 26.04.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import MessageUI
@preconcurrency import POPOPXSwitch

// MARK: - POPOPX Configuration

private enum PXUserAddressConfig {
    static let progressCircleSize: CGFloat = 58
    static let progressCircleOpacity: Double = 0.72
    static let progressScale: CGFloat = 2.2
    static let onboardingSpacing: CGFloat = 9
    static let shareIconTopInset: CGFloat = -8
    static let shareIconHorizontalPadding: CGFloat = 9
    static let createButtonShadowRadius: CGFloat = 9
    static let createButtonShadowOpacity: Double = 0.18
    static let darkThemeHeaderFont: Font = .headline.weight(.medium)
    static let sectionFooterBottomPadding: CGFloat = 5
    static let addressHeaderImageTopPadding: CGFloat = -22
    static let qrGlassCornerRadius: CGFloat = 14
    static let fullNameTopPadding: CGFloat = -3
    static let nameSaleYear: Int = 2026
    static let nameSaleMonth: Int = 12
    static let nameSaleDay: Int = 12
    static let nameSaleHour: Int = 18
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXUserAddressViewModel {
    let chatModel: ChatModel
    let onboarding: Bool
    let settings: AddressSettingsState
    let savedSettings: AddressSettingsState

    var hasAddress: Bool { chatModel.userAddress != nil }
    var isOnboardingWithAddress: Bool { onboarding && hasAddress }
    var isCreatingMode: Bool { !onboarding && !hasAddress }
    var hasUnsavedSettings: Bool { settings != savedSettings }
    var currentUserDomain: String? { chatModel.currentUser?.profile.contactDomain?.domain }
    var hasDomain: Bool { currentUserDomain != nil }
    var popopxNameDisplay: String {
        if let d = currentUserDomain { return "@\(d)" }
        return ""
    }
}

struct UserAddressView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject private var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State var shareViaProfile = false
    @State var autoCreate = false
    var onboarding: Bool = false
    @State private var showShortLink = true
    @State private var settings = AddressSettingsState()
    @State private var savedSettings = AddressSettingsState()
    @State private var showMailView = false
    @State private var mailViewResult: Result<MFMailComposeResult, Error>? = nil
    @State private var alert: UserAddressAlert?
    @State private var progressIndicator = false
    @State private var showShareViaChat = false

    private var pxVM: PXUserAddressViewModel {
        PXUserAddressViewModel(chatModel: chatModel, onboarding: onboarding, settings: settings, savedSettings: savedSettings)
    }

    private enum UserAddressAlert: Identifiable {
        case deleteAddress
        case shareOnCreate
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .deleteAddress: return "deleteAddress"
            case .shareOnCreate: return "shareOnCreate"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        ZStack {
            userAddressView()

            if progressIndicator {
                pxProgressOverlay
            }
        }
        .if(onboarding) { v in
            v.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "info.circle").opacity(0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if chatModel.userAddress == nil, autoCreate {
                createAddress()
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX progress overlay

    private var pxProgressOverlay: some View {
        ZStack {
            if chatModel.userAddress != nil {
                Circle()
                    .fill(theme.colors.background)
                    .opacity(PXUserAddressConfig.progressCircleOpacity)
                    .frame(width: PXUserAddressConfig.progressCircleSize, height: PXUserAddressConfig.progressCircleSize)
            }
            ProgressView().scaleEffect(PXUserAddressConfig.progressScale)
        }
    }

    private func userAddressView() -> some View {
        List {
            if let userAddress = chatModel.userAddress {
                if onboarding {
                    onboardingAddressView(userAddress)
                } else {
                    existingAddressView(userAddress)
                        .onAppear {
                            settings = AddressSettingsState(settings: userAddress.addressSettings)
                            savedSettings = AddressSettingsState(settings: userAddress.addressSettings)
                        }
                }
            } else if !onboarding {
                Section {
                    createAddressButton()
                } header: {
                    pxSectionHeaderText(
                        String(localized: "For social media", comment: "Section header for public address sharing options")
                    )
                }

                Section {
                    createOneTimeLinkButton()
                } header: {
                    pxSectionHeaderText(
                        String(localized: "Or to share privately", comment: "Section header for private one-time link creation")
                    )
                }

                Section {
                    learnMoreButton()
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .alert(item: $alert) { alert in
            switch alert {
            case .deleteAddress:
                return Alert(
                    title: Text(String(localized: "Delete address?", comment: "Alert title asking for confirmation to delete user's public address")),
                    message:
                        shareViaProfile
                    ? Text(String(localized: "All your contacts will remain connected. Profile update will be sent to your contacts.", comment: "Message explaining contacts stay connected but profile broadcast occurs"))
                    : Text(String(localized: "All your contacts will remain connected.", comment: "Reassurance that deleting address won't disconnect existing contacts")),
                    primaryButton: .destructive(Text(String(localized: "Delete", comment: "Destructive button text to confirm deletion"))) {
                        progressIndicator = true
                        Task {
                            do {
                                if let u = try await apiDeleteUserAddress() {
                                    DispatchQueue.main.async {
                                        chatModel.userAddress = nil
                                        chatModel.updateUser(u)
                                        if shareViaProfile {
                                            shareViaProfile = false
                                        }
                                    }
                                }
                                await MainActor.run { progressIndicator = false }
                            } catch let error {
                                logger.error("UserAddressView apiDeleteUserAddress: \(responseError(error))")
                                await MainActor.run { progressIndicator = false }
                            }
                        }
                    }, secondaryButton: .cancel()
                )
            case .shareOnCreate:
                return Alert(
                    title: Text(String(localized: "Share address with POPOPX contacts?", comment: "Alert title asking if user wants to broadcast new address")),
                    message: Text(String(localized: "Add address to your profile, so that your POPOPX contacts can share it with other people. Profile update will be sent to your POPOPX contacts.", comment: "Explanation of address broadcasting consequences")),
                    primaryButton: .default(Text(String(localized: "Share", comment: "Button to confirm sharing address"))) {
                        setProfileAddress($progressIndicator, true) { shareViaProfile = false }
                        shareViaProfile = true
                    }, secondaryButton: .cancel()
                )
            case let .error(title, error):
                return mkAlert(title: title, message: error)
            }
        }
    }

    // MARK: - POPOPX section header helper

    private func pxSectionHeaderText(_ text: String) -> some View {
        Text(text)
            .font(isInDarkTheme() ? PXUserAddressConfig.darkThemeHeaderFont : .body)
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
    }

    @ViewBuilder private func existingAddressView(_ userAddress: UserContactLink) -> some View {
        Section {
            PXLinkQRCode(link: userAddress.connLinkContact, short: $showShortLink)
                .id("popopx-contact-address-qrcode-\(userAddress.connLinkContact.popopxChatUri(short: showShortLink))")
            if userAddress.shouldBeUpgraded {
                upgradeAddressButton()
            }
            shareAddressButton(userAddress)
            shareViaChatButton(userAddress)
            // if MFMailComposeViewController.canSendMail() {
            //     shareViaEmailButton(userAddress)
            // }
            settingsRow("briefcase", color: theme.colors.secondary) {
                Toggle(String(localized: "Business address", comment: "Toggle to mark address as business contact point with auto-accept enabled"), isOn: $settings.businessAddress)
                    .onChange(of: settings.businessAddress) {_,  ba in
                        if ba {
                            settings.autoAccept = true
                            settings.autoAcceptIncognito = false
                        }
                        saveAddressSettings(settings, $savedSettings)
                    }
            }
            addressSettingsButton(userAddress)
        } header: {
            #if POPOPX_ASSETS
            VStack(alignment: .leading, spacing: 0) {
                Image(colorScheme == .light ? "popopx-address-small" : "popopx-address-small-light")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.top, PXUserAddressConfig.addressHeaderImageTopPadding)
                ToggleShortLinkHeader(text: Text(String(localized: "For social media", comment: "Section header for public address sharing options")), link: userAddress.connLinkContact, short: $showShortLink)
            }
            .padding(.bottom, 4)
            #else
            ToggleShortLinkHeader(text: Text(String(localized: "For social media", comment: "Section header for public address sharing options")), link: userAddress.connLinkContact, short: $showShortLink)
            #endif
        } footer: {
            if settings.businessAddress {
                Text(String(localized: "Add your team members to the conversations.", comment: "Footer suggesting business use case for adding colleagues"))
                    .foregroundColor(theme.colors.secondary)
            }
        }

        pxPopopxDomainSection

        Section {
            createOneTimeLinkButton()
        } header: {
            pxSectionHeaderText(
                String(localized: "Or to share privately", comment: "Section header for private one-time link creation")
            )
        }

        Section {
            learnMoreButton()
        }

        Section {
            deleteAddressButton()
        } footer: {
            Text(String(localized: "Your contacts will remain connected.", comment: "Reassurance that deleting address won't disconnect existing contacts"))
                .foregroundColor(theme.colors.secondary)
        }
    }

    // MARK: - POPOPX domain section

    @ViewBuilder
    private var pxPopopxDomainSection: some View {
        Section {
            NavigationLink {
                SetPopopxDomainView(
                    title: LocalizedStringKey(NSLocalizedString("address_your_popopx_name", comment: "")),
                    footer: LocalizedStringKey(NSLocalizedString("address_name_description", comment: "")),
                    prompt: "@yourname.testing",
                    popopxName: pxVM.popopxNameDisplay,
                    broadcastWarning: NSLocalizedString("Profile update will be sent to your POPOPX contacts.", comment: "alert title"),
                    save: { popopxDomain in
                        // TODO [TODO-FEATURE: medium] apiSetUserDomain not implemented
                        return false
                    }
                )
            } label: {
                if let d = pxVM.currentUserDomain {
                    Label("\(d)", systemImage: "at")
                } else {
                    Label(String(localized: "Get POPOPX name (BETA)", comment: "Button to register new POPOPX domain name - BETA indicates experimental feature"), systemImage: "at")
                }
            }
        } header: {
            if pxVM.hasDomain {
                Text(String(localized: "Your POPOPX name", comment: "Section header showing current POPOPX domain name"))
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    @ViewBuilder private func onboardingAddressView(_ userAddress: UserContactLink) -> some View {
        Section {
            HStack(spacing: PXUserAddressConfig.onboardingSpacing) {
                let link = userAddress.connLinkContact.popopxChatUri(short: showShortLink)
                linkTextView(link)
                Button { showShareSheet(items: [link]) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .padding(.top, PXUserAddressConfig.shareIconTopInset)
                        .padding(.horizontal, PXUserAddressConfig.shareIconHorizontalPadding)
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y_share_address", comment: "")))
            }
            .frame(maxWidth: .infinity)
        } header: {
            #if POPOPX_ASSETS
            VStack(alignment: .leading) {
                Image(colorScheme == .light ? "popopx-address" : "popopx-address-light")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                Text(String(localized: "Use this address in your social media profile, website, or email signature.", comment: "Instructions for where to use public address - shown during onboarding"))
                    .foregroundColor(theme.colors.onBackground)
                    .font(.body)
                    .textCase(nil)
            }
            .padding(.bottom, 4)
            #else
            Text(String(localized: "Use this address in your social media profile, website, or email signature.", comment: "Instructions for where to use public address - shown during onboarding"))
                .foregroundColor(theme.colors.onBackground)
                .font(.body)
                .textCase(nil)
                .padding(.bottom, 6)
            #endif
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 10))

        Section {
            PXLinkQRCode(link: userAddress.connLinkContact, short: $showShortLink)
                .id("popopx-contact-address-qrcode-\(userAddress.connLinkContact.popopxChatUri(short: showShortLink))")
                .padding()
                .glassBackground()
                .padding(.horizontal)
                        .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: {
            Text(String(localized: "Or use this QR - print or show online.", comment: "Suggestion to use QR code for sharing - can be printed physically or displayed digitally"))
                .foregroundColor(theme.colors.onBackground)
                .font(.body)
                .textCase(nil)
        }
    }

    private func createAddressButton() -> some View {
        Button {
            createAddress()
        } label: {
            Label(String(localized: "Create POPOPX address", comment: "Button to generate new public contact address"), systemImage: "qrcode")
        }
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXUserAddressConfig.createButtonShadowOpacity) : .clear, radius: PXUserAddressConfig.createButtonShadowRadius, x: 0, y: 4)
        .accessibilityLabel(Text(NSLocalizedString("a11y_create_address", comment: "")))
    }

    private func createAddress() {
        progressIndicator = true
        Task {
            do {
                let connLinkContact = try await apiCreateUserAddress()
                DispatchQueue.main.async {
                    if let connLinkContact {
                        chatModel.userAddress = UserContactLink(connLinkContact)
                        let hasRelevantContacts = chatModel.chats.contains { chat in
                            if case let .direct(contact) = chat.chatInfo {
                                return contact.active && !contact.isContactCard && !contact.contactConnIncognito
                            }
                            return false
                        }
                        if hasRelevantContacts {
                            alert = .shareOnCreate
                            progressIndicator = false
                        } else {
                            setProfileAddress($progressIndicator, true) { shareViaProfile = false }
                            shareViaProfile = true
                        }
                    } else {
                        progressIndicator = false
                    }
                }
            } catch let error {
                logger.error("UserAddressView apiCreateUserAddress: \(responseError(error))")
                await MainActor.run {
                    progressIndicator = false
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error creating address", comment: "")))
                }
            }
        }
    }

    private func upgradeAddressButton() -> some View {
        Button {
            upgradeAndShareAddressAlert(progressIndicator: $progressIndicator)
        } label: {
            settingsRow("arrow.up", color: theme.colors.primary) {
                Text(String(localized: "Upgrade address", comment: "Button to convert long address to short link with profile sharing"))
            }
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_upgrade_address", comment: "")))
    }

    private func createOneTimeLinkButton() -> some View {
        NavigationLink {
            PXNewChat(selection: .invite, hidePicker: true)
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            Label(String(localized: "Create 1-time link", comment: "Button to generate single-use invitation link"), systemImage: "link.badge.plus")
                .foregroundColor(theme.colors.primary)
        }
    }

    private func deleteAddressButton() -> some View {
        Button(role: .destructive) {
            alert = .deleteAddress
        } label: {
            Label(String(localized: "Delete address", comment: "Destructive button to permanently remove public address"), systemImage: "trash")
                .foregroundColor(theme.colors.error)
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_delete_address", comment: "")))
    }

    private func shareAddressButton(_ userAddress: UserContactLink) -> some View {
        return Button {
            if userAddress.shouldBeUpgraded {
                upgradeAndShareAddressAlert(progressIndicator: $progressIndicator, shareAddress: { userAddress.shareAddress(short: showShortLink) })
            } else {
                userAddress.shareAddress(short: showShortLink)
            }
        } label: {
            settingsRow("square.and.arrow.up", color: theme.colors.secondary) {
                Text(String(localized: "Share address", comment: "Button to share current address via system share sheet"))
            }
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_share_address", comment: "")))
    }

    private func shareViaChatButton(_ userAddress: UserContactLink) -> some View {
        Button {
            if userAddress.shouldBeUpgraded {
                showAlert(
                    NSLocalizedString("Upgrade address?", comment: "alert title"),
                    message: NSLocalizedString("The address will be short, and your profile will be shared via the address.", comment: "alert message"),
                    actions: {[
                        UIAlertAction(title: NSLocalizedString("Upgrade", comment: "alert button"), style: .default) { _ in
                            addShortLink(progressIndicator: $progressIndicator, onComplete: { showShareViaChat = true })
                        },
                        cancelAlertAction
                    ]}
                )
            } else {
                showShareViaChat = true
            }
        } label: {
            settingsRow("arrowshape.turn.up.forward", color: theme.colors.primary) {
                Text(String(localized: "Share via chat", comment: "Button to share address by forwarding to specific contacts")).foregroundColor(theme.colors.primary)
            }
        }
        .sheet(isPresented: $showShareViaChat) {
            shareAddressPicker()
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_share_via_chat", comment: "")))
    }

    private func shareViaEmailButton(_ userAddress: UserContactLink) -> some View {
        Button {
            showMailView = true
        } label: {
            settingsRow("envelope", color: theme.colors.secondary) {
                Text(String(localized: "Invite friends", comment: "Button to invite friends via email with address"))
            }
        }
        .sheet(isPresented: $showMailView) {
            SendAddressMailView(
                showMailView: $showMailView,
                mailViewResult: $mailViewResult,
                userAddress: userAddress
            )
            .edgesIgnoringSafeArea(.bottom)
        }
        .onChange(of: mailViewResult == nil) {_, _ in
            if let r = mailViewResult {
                switch r {
                case .success: ()
                case let .failure(error):
                    logger.error("UserAddressView share via email: \(responseError(error))")
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error sending email", comment: "")))
                }
                mailViewResult = nil
            }
        }
    }

    private func addressSettingsButton(_ userAddress: UserContactLink) -> some View {
        NavigationLink {
            UserAddressSettingsView(shareViaProfile: $shareViaProfile)
                .navigationTitle(String(localized: "Address settings", comment: "Navigation title for address configuration screen"))
                .navigationBarTitleDisplayMode(.large)
                .modifier(ThemedBackground(grouped: true))
        } label: {
            Text(String(localized: "Address settings", comment: "Label for navigation to address configuration options"))
        }
    }

    private func learnMoreButton() -> some View {
        NavigationLink {
            UserAddressLearnMore()
                .navigationTitle(String(localized: "Address or 1-time link?", comment: "Navigation title for comparison guide between address types"))
                .modifier(ThemedBackground(grouped: true))
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            settingsRow("info.circle", color: theme.colors.secondary) {
                Text(String(localized: "POPOPX address or 1-time link?", comment: "Button to learn difference between permanent address and temporary links"))
            }
        }
    }
}

// MARK: - POPOPX
extension UserAddressView {
    var pxComponentTag: String { "PX_USER_ADDRESS_VIEW" }
    var pxHasAddress: Bool { pxVM.hasAddress }
    var pxIsOnboarding: Bool { onboarding }
}

func upgradeAndShareAddressAlert(progressIndicator: Binding<Bool>, shareAddress: (() -> Void)? = nil) {
    showAlert(
        NSLocalizedString("Upgrade address?", comment: "alert message"),
        message: NSLocalizedString("The address will be short, and your profile will be shared via the address.", comment: "alert message"),
        actions: {
            var actions = [UIAlertAction(title: NSLocalizedString("Upgrade", comment: "alert button"), style: .default) { _ in
                addShortLink(progressIndicator: progressIndicator, shareOnCompletion: shareAddress != nil)
            }]
            if let shareAddress {
                actions.append(UIAlertAction(title: NSLocalizedString("Share old address", comment: "alert button"), style: .default) { _ in
                    shareAddress()
                })
            }
            actions.append(cancelAlertAction)
            return actions
        }
    )
}

@ViewBuilder
func shareAddressPicker(composeState: Binding<ComposeState>? = nil) -> some View {
    let v = ChatItemForwardingView(
        title: LocalizedStringKey(NSLocalizedString("address_share_address_title", comment: "")),
        isProhibited: { $0.prohibitedByPref(hasPopopxLink: true, isMediaOrFileAttachment: false, isVoice: false) },
        onSelectChat: { chat in shareMyAddress(chat, composeState: composeState) },
        includeLocal: false
    )
    if #available(iOS 16.0, *) {
        v.presentationDetents([.fraction(0.8)])
    } else {
        v
    }
}

func shareMyAddress(_ destChat: Chat, composeState: Binding<ComposeState>? = nil) {
    // TODO [TODO-FEATURE: medium] apiShareMyAddress not implemented
    // let sendAsGroup = if let gInfo = destChat.chatInfo.groupInfo { gInfo.useRelays && gInfo.membership.memberRole >= .owner } else { false }
    // Task {
    //     do {
    //         let mc = try await apiShareMyAddress(
    //             toChatType: destChat.chatInfo.chatType, toChatId: destChat.chatInfo.apiId,
    //             toScope: destChat.chatInfo.groupChatScope(), sendAsGroup: sendAsGroup
    //         )
    //         if case let .chat(_, chatLink, ownerSig) = mc {
    //         }
    //     } catch {
    //     }
    // }
}

private func addShortLink(progressIndicator: Binding<Bool>, shareOnCompletion: Bool = false, onComplete: (() -> Void)? = nil) {
    progressIndicator.wrappedValue = true
    Task {
        do {
            let userAddress = try await apiAddMyAddressShortLink()
            await MainActor.run {
                ChatModel.shared.userAddress = userAddress
                progressIndicator.wrappedValue = false
                if shareOnCompletion, let userAddress {
                    userAddress.shareAddress(short: true)
                }
                onComplete?()
            }
        } catch let error {
            logger.error("apiAddMyAddressShortLink: \(responseError(error))")
            showAlert(NSLocalizedString("error_adding_short_link", comment: "Error adding short link alert title"), message: responseError(error))
            await MainActor.run { progressIndicator.wrappedValue = false }
        }
    }
}


struct ToggleShortLinkHeader: View {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    let text: Text
    var link: CreatedConnLink
    @Binding var short: Bool

    var body: some View {
        if link.connShortLink == nil || !developerTools {
            text.foregroundColor(theme.colors.secondary)
        } else {
            HStack {
                text.foregroundColor(theme.colors.secondary)
                Spacer()
                Text(short ? String(localized: "Full link", comment: "Toggle option to show complete long address") : String(localized: "Short link", comment: "Toggle option to show abbreviated short address"))
                    .foregroundColor(theme.colors.primary)
                    .textCase(.none)
                    .contentShape(Rectangle())
                    .onTapGesture { short.toggle() }
            }
        }
    }
}

struct AddressSettingsState: Equatable {
    var businessAddress = false
    var autoAccept = false
    var autoAcceptIncognito = false
    var autoReply = ""

    init() {}

    init(settings: AddressSettings) {
        self.businessAddress = settings.businessAddress
        self.autoAccept = settings.autoAccept != nil
        self.autoAcceptIncognito = settings.autoAccept?.acceptIncognito == true
        self.autoReply = settings.autoReply?.text ?? ""
    }

    var addressSettings: AddressSettings {
        AddressSettings(
            businessAddress: self.businessAddress,
            autoAccept: self.autoAccept ? AutoAccept(acceptIncognito: self.autoAcceptIncognito) : nil,
            autoReply: self.autoReply.isEmpty ? nil : MsgContent.text(self.autoReply)
        )
    }
}

private func setProfileAddress(_ progressIndicator: Binding<Bool>, _ on: Bool, revert: @escaping () -> Void) {
    progressIndicator.wrappedValue = true
    Task {
        do {
            if let u = try await apiSetProfileAddress(on: on) {
                DispatchQueue.main.async {
                    ChatModel.shared.updateUser(u)
                }
            }
            await MainActor.run { progressIndicator.wrappedValue = false }
        } catch let error {
            logger.error("apiSetProfileAddress: \(responseError(error))")
            await MainActor.run {
                progressIndicator.wrappedValue = false
                revert()
                showErrorAlert(error, NSLocalizedString("Error saving profile", comment: "alert title"))
            }
        }
    }
}

// MARK: - POPOPX Address Settings Config

private enum PXAddressSettingsConfig {
    static let editorHeight: CGFloat = 92
    static let editorHorizontalPadding: CGFloat = -6
    static let editorTopPadding: CGFloat = -9
    static let darkThemeHeaderFont: Font = .headline.weight(.medium)
}

struct UserAddressSettingsView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var shareViaProfile: Bool
    @State private var settings = AddressSettingsState()
    @State private var savedSettings = AddressSettingsState()
    @State private var ignoreShareViaProfileChange = false
    @State private var progressIndicator = false

    var body: some View {
        ZStack {
            if let userAddress = ChatModel.shared.userAddress {
                userAddressSettingsView()
                    .onAppear {
                        settings = AddressSettingsState(settings: userAddress.addressSettings)
                        savedSettings = AddressSettingsState(settings: userAddress.addressSettings)
                    }
                    .onChange(of: settings.autoAccept) {_,  autoAccept in
                        if !autoAccept {
                            settings.businessAddress = false
                            settings.autoReply = ""
                        }
                    }
                    .onDisappear {
                        if savedSettings != settings {
                            showAlert(
                                title: NSLocalizedString("POPOPX address settings", comment: "alert title"),
                                message: NSLocalizedString("Settings were changed.", comment: "alert message"),
                                buttonTitle: NSLocalizedString("Save", comment: "alert button"),
                                buttonAction: { saveAddressSettings(settings, $savedSettings) },
                                cancelButton: true
                            )
                        }
                    }
            } else {
                Text(NSLocalizedString("error_opening_address_settings", comment: "Error opening address settings"))
            }
            if progressIndicator {
                ProgressView().scaleEffect(2)
            }
        }
    }

    private func userAddressSettingsView() -> some View {
        List {
            Section {
                shareWithContactsButton()
                autoAcceptToggle().disabled(settings.businessAddress)
                if settings.autoAccept && !ChatModel.shared.addressShortLinkDataSet && !settings.businessAddress {
                    acceptIncognitoToggle()
                }
            }

            Section {
                messageEditor(placeholder: NSLocalizedString("Enter welcome message… (optional)", comment: "placeholder"), text: $settings.autoReply)
            } header: {
                Text(String(localized: "Welcome message", comment: "Section header for automatic greeting message sent to new contacts"))
                    .font(isInDarkTheme() ? PXAddressSettingsConfig.darkThemeHeaderFont : .body)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            }

            Section {
                saveAddressSettingsButton()
                    .disabled(settings == savedSettings)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func shareWithContactsButton() -> some View {
        settingsRow("person", color: theme.colors.secondary) {
            Toggle(String(localized: "Share with POPOPX contacts", comment: "Toggle to broadcast address to existing contact list"), isOn: $shareViaProfile)
                .onChange(of: shareViaProfile) {_,  on in
                    if ignoreShareViaProfileChange {
                        ignoreShareViaProfileChange = false
                    } else {
                        if on {
                            showAlert(
                                NSLocalizedString("Share address with POPOPX contacts?", comment: "alert title"),
                                message: NSLocalizedString("Profile update will be sent to your POPOPX contacts.", comment: "alert message"),
                                actions: {[
                                    UIAlertAction(
                                        title: NSLocalizedString("Cancel", comment: "alert action"),
                                        style: .cancel,
                                        handler: { _ in
                                            ignoreShareViaProfileChange = true
                                            shareViaProfile = !on
                                        }
                                    ),
                                    UIAlertAction(
                                        title: NSLocalizedString("Share", comment: "alert action"),
                                        style: .default,
                                        handler: { _ in
                                            setProfileAddress($progressIndicator, on) {
                                                ignoreShareViaProfileChange = true
                                                shareViaProfile = !on
                                            }
                                        }
                                    )
                                ]}
                            )
                        } else {
                            showAlert(
                                NSLocalizedString("Stop sharing address?", comment: "alert title"),
                                message: NSLocalizedString("Profile update will be sent to your POPOPX contacts.", comment: "alert message"),
                                actions: {[
                                    UIAlertAction(
                                        title: NSLocalizedString("Cancel", comment: "alert action"),
                                        style: .cancel,
                                        handler: { _ in
                                            ignoreShareViaProfileChange = true
                                            shareViaProfile = !on
                                        }
                                    ),
                                    UIAlertAction(
                                        title: NSLocalizedString("Stop sharing", comment: "alert action"),
                                        style: .default,
                                        handler: { _ in
                                            setProfileAddress($progressIndicator, on) {
                                                ignoreShareViaProfileChange = true
                                                shareViaProfile = !on
                                            }
                                        }
                                    )
                                ]}
                            )
                        }
                    }
                }
        }
    }

    private func autoAcceptToggle() -> some View {
        settingsRow("checkmark", color: theme.colors.secondary) {
            Toggle(String(localized: "Auto-accept", comment: "Toggle to automatically accept incoming contact requests"), isOn: $settings.autoAccept)
                .onChange(of: settings.autoAccept) {_, _ in
                    saveAddressSettings(settings, $savedSettings)
                }
        }
    }

    private func acceptIncognitoToggle() -> some View {
        settingsRow(
            settings.autoAcceptIncognito ? "theatermasks.fill" : "theatermasks",
            color: settings.autoAcceptIncognito ? QuantumColors.accent : theme.colors.secondary
        ) {
            Toggle(String(localized: "Accept incognito", comment: "Toggle to accept anonymous/incognito contact requests"), isOn: $settings.autoAcceptIncognito)
        }
    }

    private func messageEditor(placeholder: String, text: Binding<String>) -> some View {
        ZStack {
            Group {
                if text.wrappedValue.isEmpty {
                    TextEditor(text: Binding.constant(placeholder))
                        .foregroundColor(theme.colors.secondary)
                        .disabled(true)
                }
                TextEditor(text: text)
            }
            .padding(.horizontal, PXAddressSettingsConfig.editorHorizontalPadding)
            .padding(.top, PXAddressSettingsConfig.editorTopPadding)
            .frame(height: PXAddressSettingsConfig.editorHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func saveAddressSettingsButton() -> some View {
        Button {
            hideKeyboard()
            saveAddressSettings(settings, $savedSettings)
        } label: {
            Text(String(localized: "Save", comment: "Button to save address configuration changes"))
        }
    }
}

private func saveAddressSettings(_ settings: AddressSettingsState, _ savedSettings: Binding<AddressSettingsState>) {
    Task {
        do {
            if let address = try await apiSetUserAddressSettings(settings.addressSettings) {
                await MainActor.run {
                    ChatModel.shared.userAddress = address
                    savedSettings.wrappedValue = settings
                }
            }
        } catch let error {
            logger.error("apiSetUserAddressSettings error: \(responseError(error))")
        }
    }
}

private let popopxNameSaleStart = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: PXUserAddressConfig.nameSaleYear, month: PXUserAddressConfig.nameSaleMonth, day: PXUserAddressConfig.nameSaleDay, hour: PXUserAddressConfig.nameSaleHour)) ?? Date.distantFuture

// MARK: - POPOPX Domain Config

private enum PXDomainConfig {
    static let pasteboardExpiration: TimeInterval = 125
    static let focusDelay: Double = 0.12
    static let focusAppearDelay: Double = 0.65
    static let maxDomainLength: Int = 253
    static let maxLabelLength: Int = 63
    static let saleTimerInterval: TimeInterval = 1.0
    static let countdownSpacing: CGFloat = 5
}

struct SetPopopxDomainView: View {
    let title: LocalizedStringKey
    let footer: LocalizedStringKey
    let prompt: String
    @State var popopxName: String
    let broadcastWarning: String?
    let save: (String?) async -> Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: AppTheme
    @State private var saving = false
    @State private var original = ""
    @State private var didSave = false
    @State private var editing = false
    @State private var timeToSaleStart = popopxNameSaleStart.timeIntervalSinceNow
    @State private var saleTimer: Timer? = nil
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var nameFocused: Bool

    init(title: LocalizedStringKey, footer: LocalizedStringKey, prompt: String, popopxName: String, broadcastWarning: String? = nil, save: @escaping (String?) async -> Bool) {
        self.title = title
        self.footer = footer
        self.prompt = prompt
        self._popopxName = State(initialValue: popopxName)
        self.broadcastWarning = broadcastWarning
        self.save = save
        self._original = State(initialValue: popopxName)
        self._editing = State(initialValue: popopxName.isEmpty)
    }

    private var changed: Bool {
        normalized(popopxName) != normalized(original)
    }

    private var isValid: Bool {
        guard let d = normalized(popopxName) else { return true }
        return isValidPopopxDomain(d)
    }

    var body: some View {
        List {
            Section {
                if editing {
                    pxEditingField
                } else {
                    pxDisplayField
                }
            } header: {
                Text(verbatim: "")
            } footer: {
                Text(footer).foregroundColor(theme.colors.secondary)
            }
            Section {
                if editing {
                    pxEditingActions
                } else {
                    Button(String(localized: "Remove name", comment: "Button to delete current POPOPX domain name")) {
                        popopxName = ""
                        editing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + PXDomainConfig.focusDelay) { nameFocused = true }
                    }
                }
            }
            pxSaleCountdownSection
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if editing {
                DispatchQueue.main.asyncAfter(deadline: .now() + PXDomainConfig.focusAppearDelay) { nameFocused = true }
            }
            if timeToSaleStart > 0 {
                saleTimer = Timer.scheduledTimer(withTimeInterval: PXDomainConfig.saleTimerInterval, repeats: true) { t in
                    timeToSaleStart = popopxNameSaleStart.timeIntervalSinceNow
                    if timeToSaleStart <= 0 { t.invalidate() }
                }
            }
        }
        .onDisappear {
            saleTimer?.invalidate()
            saleTimer = nil
            if !didSave, !saving, changed, isValid {
                let domain = normalized(popopxName)
                let saveName = save
                showAlert(
                    NSLocalizedString("Save POPOPX name?", comment: "alert title"),
                    message: broadcastWarning,
                    actions: {[
                        UIAlertAction(title: NSLocalizedString("Save", comment: "alert action"), style: .default) { _ in
                            Task { _ = await saveName(domain) }
                        },
                        UIAlertAction(title: NSLocalizedString("Don't save", comment: "alert action"), style: .cancel)
                    ]}
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                saleTimer?.invalidate()
                saleTimer = nil
            case .active:
                if saleTimer == nil, timeToSaleStart > 0 {
                    saleTimer = Timer.scheduledTimer(withTimeInterval: PXDomainConfig.saleTimerInterval, repeats: true) { t in
                        timeToSaleStart = popopxNameSaleStart.timeIntervalSinceNow
                        if timeToSaleStart <= 0 { t.invalidate() }
                    }
                }
            default:
                break
            }
        }
    }

    // MARK: - POPOPX extracted domain view builders

    private var pxEditingField: some View {
        ZStack(alignment: .trailing) {
            TextField(prompt, text: $popopxName)
                .focused($nameFocused)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .padding(.trailing, isValid ? 0 : 20)
            if !isValid {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(theme.colors.error)
            }
        }
    }

    private var pxDisplayField: some View {
        Button {
            UIPasteboard.general.setItems([["public.utf8-plain-text": popopxName]], options: [.expirationDate: Date().addingTimeInterval(PXDomainConfig.pasteboardExpiration), .localOnly: true])
        } label: {
            HStack {
                Text(popopxName)
                    .foregroundColor(theme.colors.onBackground)
                Spacer()
                Image(systemName: "doc.on.doc")
                    .foregroundColor(theme.colors.secondary)
            }
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_copy_name", comment: "")))
    }

    private var pxEditingActions: some View {
        Button {
            if let w = broadcastWarning, changed {
                showAlert(w, actions: {[
                    UIAlertAction(title: NSLocalizedString("Save", comment: "alert action"), style: .default) { _ in saveAndDismiss() },
                    UIAlertAction(title: NSLocalizedString("Cancel", comment: "alert action"), style: .cancel)
                ]})
            } else {
                saveAndDismiss()
            }
        } label: {
            Text(String(localized: "Save", comment: "Button to save POPOPX domain name changes"))
        }
        .disabled(saving || !isValid || !changed)
    }

    @ViewBuilder
    private var pxSaleCountdownSection: some View {
        Section {
            VStack(alignment: .leading, spacing: PXDomainConfig.countdownSpacing) {
                Text(verbatim: saleCountdown(timeToSaleStart))
                Text(timeToSaleStart > 0 ? String(localized: "until you can register a POPOPX domain", comment: "Text indicating time remaining until domain registration opens") : String(localized: "Update the app to register a POPOPX domain", comment: "Message prompting user to update app for domain registration feature"))
                    .foregroundColor(theme.colors.secondary)
                    .font(.caption)
            }
        } header: {
            Text(String(localized: "POPOPX name sale starts in", comment: "Section header for countdown timer to domain name sale"))
                .foregroundColor(theme.colors.secondary)
        } footer: {
            Text(String(localized: "Investors can reserve names before the sale starts.", comment: "Footer explaining early access for crowdfunding backers - simplex.domains link removed for rebranding"))
                .foregroundColor(theme.colors.secondary)
                .padding(.bottom)
        }
    }

    private func saveAndDismiss() {
        saving = true
        Task {
            let ok = await save(normalized(popopxName))
            await MainActor.run {
                saving = false
                if ok {
                    didSave = true
                    dismiss()
                }
            }
        }
    }

    private func normalized(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty
                ? nil
                : addPopopxTLD((t.hasPrefix("@") || t.hasPrefix("#") ? String(t.dropFirst()) : t).lowercased())
    }

    private func saleCountdown(_ remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining))
        let days = total / 86400
        let dayStr = String.localizedStringWithFormat(
            days == 1
                ? NSLocalizedString("%d day", comment: "time interval")
                : NSLocalizedString("%d days", comment: "time interval"),
            days
        )
        return dayStr + " " + String.localizedStringWithFormat(
            NSLocalizedString("%02d hrs %02d min %02d sec", comment: "countdown"),
            total / 3600 % 24, total / 60 % 60, total % 60
        )
    }

    private func addPopopxTLD(_ d: String) -> String {
        if d.contains(".") { d } else { "\(d).popopx" }
    }

    private func isValidPopopxDomain(_ s: String) -> Bool {
        if s.utf8.count > PXDomainConfig.maxDomainLength { return false }
        let labels = s.split(separator: ".", omittingEmptySubsequences: false)
        if labels.count < 2 { return false }
        for label in labels {
            if !isValidNameLabel(label) { return false }
        }
        return true
    }

    private func isValidNameLabel(_ label: Substring) -> Bool {
        if label.isEmpty || label.utf8.count > PXDomainConfig.maxLabelLength { return false }
        return label.range(of: "^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$", options: .regularExpression) != nil
    }
}

// MARK: - POPOPX
extension SetPopopxDomainView {
    var pxComponentTag: String { "PX_SET_POPOPX_DOMAIN_VIEW" }
}

struct UserAddressView_Previews: PreviewProvider {
    static var previews: some View {
        let chatModel = ChatModel()
        chatModel.userAddress = UserContactLink(CreatedConnLink(connFullLink: "https://popopxchat.com/contact#/?v=1&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.popopxchat.com%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23MCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%3D", connShortLink: nil))

        return Group {
            UserAddressView()
                .environmentObject(chatModel)
            UserAddressView()
                .environmentObject(ChatModel())
        }
    }
}
