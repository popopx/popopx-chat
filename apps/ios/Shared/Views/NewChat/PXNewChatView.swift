//
//  PXNewChatView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 28.11.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch
import CodeScanner
import AVFoundation

struct SomeAlert: Identifiable {
    var alert: Alert
    var id: String
}

struct SomeActionSheet: Identifiable {
    var actionSheet: ActionSheet
    var id: String
}

struct SomeSheet<Content: View>: Identifiable {
    @ViewBuilder var content: Content
    var id: String
    var fraction = 0.4
}

private enum NewChatViewAlert: Identifiable {
    case newChatSomeAlert(alert: SomeAlert)
    var id: String {
        switch self {
        case let .newChatSomeAlert(alert): return "newChatSomeAlert \(alert.id)"
        }
    }
}

enum NewChatOption: Identifiable {
    case invite
    case connect

    var id: Self { self }
}

// MARK: - POPOPX Configuration

private enum PXNewChatConfig {
    static let componentTag: String = "PXNewChatView"
    /// Duration for selection change animation
    static let selectionAnimationDuration: Double = 0.3333
    /// Minimum swipe distance for tab switching
    static let swipeMinimumDistance: CGFloat = 20.0
    /// Delay before creating invitation (seconds)
    static let createInvitationDelay: Double = 0.25
    /// Delay in nanoseconds for invitation creation task
    static let createInvitationDelayNanoseconds: UInt64 = 250_000000
    /// Opacity for dark theme accent gradient overlay
    static let darkThemeGradientPrimaryOpacity: Double = 0.04
    /// Opacity for secondary neon gradient in dark theme
    static let darkThemeGradientSecondaryOpacity: Double = 0.02
    /// Opacity for dark theme top border line
    static let darkThemeBorderPrimaryOpacity: Double = 0.4
    /// Opacity for secondary neon border in dark theme
    static let darkThemeBorderSecondaryOpacity: Double = 0.2
    /// Height of the dark theme accent border line
    static let darkThemeBorderHeight: CGFloat = 0.75
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXNewChatViewModel {
    let animationDuration: Double
    let swipeMinimumDistance: CGFloat
    let isOnboarding: Bool
}

@MainActor
func showKeepInvitationAlert() {
    if let showingInvitation = ChatModel.shared.showingInvitation,
       !showingInvitation.connChatUsed {
        showAlert(
            NSLocalizedString("Keep unused invitation?", comment: "alert title"),
            message: NSLocalizedString("You can view invitation link again in connection details.", comment: "alert message"),
            actions: {[
                UIAlertAction(
                    title: NSLocalizedString("Keep", comment: "alert action"),
                    style: .default
                ),
                UIAlertAction(
                    title: NSLocalizedString("Delete", comment: "alert action"),
                    style: .destructive,
                    handler: { _ in
                        Task {
                            await deleteChat(Chat(
                                chatInfo: .contactConnection(contactConnection: showingInvitation.pcc),
                                chatItems: []
                            ))
                        }
                    }
                )
            ]}
        )
    }
    ChatModel.shared.showingInvitation = nil
}

// Spec: spec/client/navigation.md#NewChatView
struct PXNewChat: View {
    @State var selection: NewChatOption
    @State var showQRCodeScanner = false
    var onboarding: Bool = false
    var hidePicker: Bool = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var invitationUsed: Bool = false
    @State private var connLinkInvitation: CreatedConnLink = CreatedConnLink(connFullLink: "", connShortLink: nil)
    @State private var showShortLink = true
    @State private var creatingConnReq = false
    @State var choosingProfile = false
    @State private var pastedLink: String = ""
    @State private var alert: NewChatViewAlert?
    @State private var contactConnection: PendingContactConnection? = nil

    var body: some View {
        let vm = PXNewChatViewModel(animationDuration: PXNewChatConfig.selectionAnimationDuration, swipeMinimumDistance: PXNewChatConfig.swipeMinimumDistance, isOnboarding: onboarding)
        VStack(alignment: .leading) {
            if !onboarding && !hidePicker {
                Picker(NSLocalizedString("chat_new_chat", comment: "picker label"), selection: $selection) {
                    Label(NSLocalizedString("chat_one_time_link", comment: "picker option"), systemImage: "link")
                        .tag(NewChatOption.invite)
                    Label(NSLocalizedString("chat_connect_via_link", comment: "picker option"), systemImage: "qrcode")
                        .tag(NewChatOption.connect)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: $selection.wrappedValue) {_,  opt in
                    if opt == NewChatOption.connect {
                        showQRCodeScanner = true
                    }
                }
            }

            VStack {
                // it seems there's a bug in iOS 15 if several views in switch (or if-else) statement have different transitions
                // https://developer.apple.com/forums/thread/714977?answerId=731615022#731615022
                if case .invite = selection {
                    prepareAndInviteView()
                        .transition(.move(edge: .leading))
                        .onAppear {
                            createInvitation()
                        }
                }
                if case .connect = selection {
                    ConnectView(showQRCodeScanner: $showQRCodeScanner, pastedLink: $pastedLink, alert: $alert, onboarding: onboarding)
                        .transition(.move(edge: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pxInviteBackground)
            .overlay(alignment: .top) {
                if isInDarkTheme() {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                darkThemeAccentColor().opacity(PXNewChatConfig.darkThemeBorderPrimaryOpacity),
                                neonGradientSecondary().opacity(PXNewChatConfig.darkThemeBorderSecondaryOpacity)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: PXNewChatConfig.darkThemeBorderHeight)
                }
            }
            .animation(.easeInOut(duration: vm.animationDuration), value: selection)
            .gesture(DragGesture(minimumDistance: vm.swipeMinimumDistance, coordinateSpace: .local)
                .onChanged { value in
                    switch(value.translation.width, value.translation.height) {
                    case (...0, -30...30): // left swipe
                        if selection == .invite {
                            selection = .connect
                        }
                    case (0..., -30...30): // right swipe
                        if selection == .connect {
                            selection = .invite
                        }
                    default: ()
                    }
                },
                including: onboarding ? .subviews : .all
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !onboarding {
                    InfoSheetButton {
                        AddContactLearnMore(showTitle: true)
                    }
                    .accessibilityLabel(Text(NSLocalizedString("Learn more about connecting", comment: "info button accessibility")))
                } else {
                    Button(NSLocalizedString("chat_done", comment: "button")) {
                        dismiss()
                    }
                    .accessibilityLabel(Text(NSLocalizedString("chat_done", comment: "button")))
                }
            }
        }
        .if(onboarding) { $0.navigationBarTitleDisplayMode(.inline) }
        .modifier(ThemedBackground(grouped: true))
        .onChange(of: invitationUsed) {_,  used in
            if used && !(m.showingInvitation?.connChatUsed ?? true) {
                m.markShowingInvitationUsed()
            }
        }
        .onDisappear {
            if !choosingProfile {
                showKeepInvitationAlert()
                contactConnection = nil
            }
        }
        .alert(item: $alert) { a in
            switch(a) {
            case let .newChatSomeAlert(a):
                return a.alert
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX Sub-views

    private var pxInviteBackground: some View {
        ZStack {
            Color.clear.overlay(.ultraThinMaterial)
            if isInDarkTheme() {
                LinearGradient(
                    colors: [
                        darkThemeAccentColor().opacity(PXNewChatConfig.darkThemeGradientPrimaryOpacity),
                        neonGradientSecondary().opacity(PXNewChatConfig.darkThemeGradientSecondaryOpacity),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func prepareAndInviteView() -> some View {
        ZStack { // ZStack is needed for views to not make transitions between each other
            if connLinkInvitation.connFullLink != "" {
                InviteView(
                    invitationUsed: $invitationUsed,
                    contactConnection: $contactConnection,
                    connLinkInvitation: $connLinkInvitation,
                    showShortLink: $showShortLink,
                    choosingProfile: $choosingProfile,
                    onboarding: onboarding
                )
            } else if creatingConnReq {
                creatingLinkProgressView()
            } else {
                retryButton()
            }
        }
    }

    private func createInvitation() {
        if connLinkInvitation.connFullLink == "" && contactConnection == nil && !creatingConnReq {
            creatingConnReq = true
            Task {
                _ = try? await Task.sleep(nanoseconds: UInt64(PXNewChatConfig.createInvitationDelayNanoseconds))
                let (r, apiAlert) = await apiAddContact(incognito: incognitoGroupDefault.get())
                if let (connLink, pcc) = r {
                    await MainActor.run {
                        m.updateContactConnection(pcc)
                        m.showingInvitation = ShowingInvitation(pcc: pcc, connChatUsed: false)
                        connLinkInvitation = connLink
                        contactConnection = pcc
                    }
                } else {
                    await MainActor.run {
                        creatingConnReq = false
                        if let apiAlert = apiAlert {
                            alert = .newChatSomeAlert(alert: SomeAlert(alert: apiAlert, id: "createInvitation error"))
                        }
                    }
                }
            }
        }
    }

    // Rectangle here and in retryButton are needed for gesture to work
    private func creatingLinkProgressView() -> some View {
        ProgressView(NSLocalizedString("chat_creating_link", comment: "progress view"))
            .progressViewStyle(.circular)
    }

    private func retryButton() -> some View {
        Button(action: createInvitation) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text(NSLocalizedString("chat_retry", comment: "button"))
            }
        }
    }
}

private func incognitoProfileImage() -> some View {
    Image(systemName: "theatermasks.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 30)
        .foregroundColor(QuantumColors.accent)
}

private struct InviteView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var invitationUsed: Bool
    @Binding var contactConnection: PendingContactConnection?
    @Binding var connLinkInvitation: CreatedConnLink
    @Binding var showShortLink: Bool
    @Binding var choosingProfile: Bool
    var onboarding: Bool = false

    @AppStorage(GROUP_DEFAULT_INCOGNITO, store: groupDefaults) private var incognitoDefault = false

    var body: some View {
        List {
            Section(header: sectionHeader) {
                shareLinkView()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 10))

            qrCodeView()
            if !onboarding, let selectedProfile = chatModel.currentUser {
                Section {
                    NavigationLink {
                        ActiveProfilePicker(
                            contactConnection: $contactConnection,
                            connLinkInvitation: $connLinkInvitation,
                            incognitoEnabled: $incognitoDefault,
                            choosingProfile: $choosingProfile,
                            selectedProfile: selectedProfile
                        )
                    } label: {
                        HStack {
                            if incognitoDefault {
                                incognitoProfileImage()
                                Text(NSLocalizedString("chat_incognito", comment: "profile option"))
                            } else {
                                ProfileImage(imageStr: chatModel.currentUser?.image, size: 30)
                                Text(chatModel.currentUser?.chatViewName ?? "")
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("chat_share_profile", comment: "section header")).foregroundColor(theme.colors.secondary)
                } footer: {
                    if incognitoDefault {
                        Text(NSLocalizedString("chat_new_random_profile_shared", comment: "section footer"))
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onChange(of: incognitoDefault) {_,  incognito in
            setInvitationUsed()
        }
        .onChange(of: chatModel.currentUser) {_,  u in
            setInvitationUsed()
        }
    }

    private var sectionHeader: some View {
        #if POPOPX_ASSETS
        VStack(alignment: .leading, spacing: 0) {
            Image(colorScheme == .light
                ? (onboarding ? "one-time-link" : "one-time-link-small")
                : (onboarding ? "one-time-link-light" : "one-time-link-small-light"))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            sectionHeaderText
        }
        .padding(.bottom, 6)
        #else
        sectionHeaderText
            .if(onboarding) { $0.padding(.bottom, 6) }
        #endif
    }

    @ViewBuilder private var sectionHeaderText: some View {
        if onboarding {
            Text(NSLocalizedString("chat_send_link_via_messenger", comment: "onboarding section header"))
                .font(.body).foregroundColor(theme.colors.onBackground).textCase(nil)
        } else {
            Text(NSLocalizedString("chat_share_invite_link", comment: "section header")).foregroundColor(theme.colors.secondary)
        }
    }

    private func shareLinkView() -> some View {
        HStack(spacing: 8) {
            let link = connLinkInvitation.popopxChatUri(short: showShortLink)
            linkTextView(link)
            Button {
                showShareSheet(items: [link])
                setInvitationUsed()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .padding(.top, -7)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func qrCodeView() -> some View {
        Section {
            PXLinkQRCode(link: connLinkInvitation, short: $showShortLink, onShare: setInvitationUsed)
                .id("popopx-qrcode-view-for-\(connLinkInvitation.popopxChatUri(short: showShortLink))")
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: {
            if onboarding {
                Text(NSLocalizedString("chat_show_qr_in_person", comment: "onboarding QR section header")).font(.body).foregroundColor(theme.colors.onBackground).textCase(nil)
            } else {
                ToggleShortLinkHeader(text: Text(NSLocalizedString("chat_or_show_code", comment: "QR section header")), link: connLinkInvitation, short: $showShortLink)
            }
        }
    }

    private func setInvitationUsed() {
        if !invitationUsed {
            invitationUsed = true
        }
    }
}

private enum ProfileSwitchStatus {
    case switchingUser
    case switchingIncognito
    case idle
}

private struct ActiveProfilePicker: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var contactConnection: PendingContactConnection?
    @Binding var connLinkInvitation: CreatedConnLink
    @Binding var incognitoEnabled: Bool
    @Binding var choosingProfile: Bool
    @State private var alert: SomeAlert?
    @State private var profileSwitchStatus: ProfileSwitchStatus = .idle
    @State private var switchingProfileByTimeout = false
    @State private var lastSwitchingProfileByTimeoutCall: Double?
    @State private var profiles: [User] = []
    @State private var searchTextOrPassword = ""
    @State private var showIncognitoSheet = false
    @State private var incognitoFirst: Bool = false
    @State var selectedProfile: User
    var trimmedSearchTextOrPassword: String { searchTextOrPassword.trimmingCharacters(in: .whitespaces)}

    var body: some View {
        viewBody()
            .navigationTitle(NSLocalizedString("chat_select_chat_profile", comment: "navigation title"))
            .searchable(text: $searchTextOrPassword, placement: .navigationBarDrawer(displayMode: .always))
            .autocorrectionDisabled(true)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                profiles = chatModel.users
                    .map { $0.user }
            }
            .onChange(of: incognitoEnabled) {_,  incognito in
                if profileSwitchStatus != .switchingIncognito {
                    return
                }

                Task {
                    do {
                        if let contactConn = contactConnection,
                           let conn = try await apiSetConnectionIncognito(connId: contactConn.pccConnId, incognito: incognito) {
                            await MainActor.run {
                                contactConnection = conn
                                chatModel.updateContactConnection(conn)
                                profileSwitchStatus = .idle
                                dismiss()
                            }
                        }
                    } catch {
                        profileSwitchStatus = .idle
                        incognitoEnabled = !incognito
                        logger.error("apiSetConnectionIncognito error: \(responseError(error))")
                        let err = getErrorAlert(error, LocalizedStringKey(NSLocalizedString("chat_error_changing_incognito", comment: "alert title")))

                        alert = SomeAlert(
                            alert: Alert(
                                title: Text(err.title),
                                message: Text(err.message ?? LocalizedStringKey(String(format: NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
                            ),
                            id: "setConnectionIncognitoError"
                        )
                    }
                }
            }
            .onChange(of: profileSwitchStatus) {_,  sp in
                if sp != .idle {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        switchingProfileByTimeout = profileSwitchStatus != .idle
                    }
                } else {
                    switchingProfileByTimeout = false
                }
            }
            .onChange(of: selectedProfile) {_,  profile in
                if (profileSwitchStatus != .switchingUser) {
                    return
                }
                Task {
                    do {
                        if let contactConn = contactConnection,
                           let conn = try await apiChangeConnectionUser(connId: contactConn.pccConnId, userId: profile.userId) {
                            await MainActor.run {
                                contactConnection = conn
                                connLinkInvitation = conn.connLinkInv ?? CreatedConnLink(connFullLink: "", connShortLink: nil)
                                incognitoEnabled = false
                                chatModel.updateContactConnection(conn)
                            }
                            do {
                                try await changeActiveUserAsync_(profile.userId, viewPwd: profile.hidden ? trimmedSearchTextOrPassword : nil)
                                await MainActor.run {
                                    profileSwitchStatus = .idle
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    profileSwitchStatus = .idle
                                    alert = SomeAlert(
                                        alert: Alert(
                                            title: Text(NSLocalizedString("chat_error_switching_profile", comment: "alert title")),
                                            message: Text(String(format: NSLocalizedString("Your connection was moved to %@ but an error happened when switching profile.", comment: "switching profile error"), profile.chatViewName))
                                        ),
                                        id: "switchingProfileError"
                                    )
                                }
                            }
                        }
                    } catch {
                        await MainActor.run {
                            profileSwitchStatus = .idle
                            if let currentUser = chatModel.currentUser {
                                selectedProfile = currentUser
                            }
                            let err = getErrorAlert(error, LocalizedStringKey(NSLocalizedString("chat_error_changing_profile", comment: "alert title")))
                            alert = SomeAlert(
                                alert: Alert(
                                    title: Text(err.title),
                                    message: Text(err.message ?? LocalizedStringKey(String(format: NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
                                ),
                                id: "changeConnectionUserError"
                            )
                        }
                    }
                }
            }
            .alert(item: $alert) { a in
                a.alert
            }
            .onAppear {
                incognitoFirst = incognitoEnabled
                choosingProfile = true
            }
            .onDisappear {
                choosingProfile = false
            }
            .sheet(isPresented: $showIncognitoSheet) {
                IncognitoHelp()
            }
    }


    @ViewBuilder private func viewBody() -> some View {
        profilePicker()
            .allowsHitTesting(!switchingProfileByTimeout)
            .modifier(ThemedBackground(grouped: true))
            .overlay {
                if switchingProfileByTimeout {
                    ProgressView()
                        .scaleEffect(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
    }

    private func filteredProfiles() -> [User] {
        let s = trimmedSearchTextOrPassword
        let lower = s.localizedLowercase

        return profiles.filter { u in
            if (u.activeUser || !u.hidden) && (s == "" || u.chatViewName.localizedLowercase.contains(lower)) {
                return true
            }
            return correctPassword(u, s)
        }
    }

    private func profilerPickerUserOption(_ user: User) -> some View {
        Button {
            if selectedProfile == user && incognitoEnabled {
                incognitoEnabled = false
                profileSwitchStatus = .switchingIncognito
            } else if selectedProfile != user {
                selectedProfile = user
                profileSwitchStatus = .switchingUser
            }
        } label: {
            HStack {
                ProfileImage(imageStr: user.image, size: 30)
                    .padding(.trailing, 2)
                NameWithBadge(
                    Text(user.chatViewName).foregroundColor(theme.colors.onBackground),
                    user.profile.localBadge
                )
                .lineLimit(1)
                Spacer()
                if selectedProfile == user, !incognitoEnabled {
                    Image(systemName: "checkmark")
                        .resizable().scaledToFit().frame(width: 16)
                        .foregroundColor(theme.colors.primary)
                }
            }
        }
    }

    @ViewBuilder private func profilePicker() -> some View {
        let incognitoOption = Button {
            if !incognitoEnabled {
                incognitoEnabled = true
                profileSwitchStatus = .switchingIncognito
            }
        } label : {
            HStack {
                incognitoProfileImage()
                Text(NSLocalizedString("chat_incognito", comment: "profile option"))
                    .foregroundColor(theme.colors.onBackground)
                Image(systemName: "info.circle")
                    .foregroundColor(theme.colors.primary)
                    .font(.footnote)
                    .onTapGesture {
                        showIncognitoSheet = true
                    }
                Spacer()
                if incognitoEnabled {
                    Image(systemName: "checkmark")
                        .resizable().scaledToFit().frame(width: 16)
                        .foregroundColor(theme.colors.primary)
                }
            }
        }

        List {
            let filteredProfiles = filteredProfiles()
            let activeProfile = filteredProfiles.first { u in u.activeUser }

            if let selectedProfile = activeProfile {
                let otherProfiles = filteredProfiles
                    .filter { u in u.userId != activeProfile?.userId }
                    .sorted(using: KeyPathComparator<User>(\.activeOrder, order: .reverse))

                if incognitoFirst {
                    incognitoOption
                    profilerPickerUserOption(selectedProfile)
                } else {
                    profilerPickerUserOption(selectedProfile)
                    incognitoOption
                }

                ForEach(otherProfiles) { p in
                    profilerPickerUserOption(p)
                }
            } else {
                incognitoOption
                ForEach(filteredProfiles) { p in
                    profilerPickerUserOption(p)
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .opacity(switchingProfileByTimeout ? 0.4 : 1)
    }
}

private struct ConnectView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var connectProgressManager = ConnectProgressManager.shared
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var showQRCodeScanner: Bool
    @Binding var pastedLink: String
    @Binding var alert: NewChatViewAlert?
    var onboarding: Bool = false
    @State var scannerPaused: Bool = false
    @State private var pasteboardHasStrings = UIPasteboard.general.hasStrings

    var body: some View {
        List {
            Section(header: connectSectionHeader) {
                pasteLinkView()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

            Section(header: Text(NSLocalizedString("chat_or_scan_qr", comment: "section header")).foregroundColor(theme.colors.secondary)) {
                if connectProgressManager.isInProgress && !showQRCodeScanner {
                    PxBalloonProgressView(text: connectProgressManager.connectInProgressText)
                        .frame(height: 200)
                } else {
                    ScannerInView(showQRCodeScanner: $showQRCodeScanner, scannerPaused: $scannerPaused, processQRCode: processQRCode)
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onDisappear {
            connectProgressManager.cancelConnectProgress()
        }
    }

    @ViewBuilder private func pasteLinkView() -> some View {
        if pastedLink == "" {
            ZStack(alignment: .trailing) {
                Button {
                    if let str = UIPasteboard.general.string {
                        switch strConnectTarget(str.trimmingCharacters(in: .whitespaces)) {
                        case let .link(text, _, _):
                            pastedLink = text
                            connect(pastedLink)
                        case let .name(nameInfo):
                            showUnsupportedNameAlert(nameInfo)
                        case .none:
                            alert = .newChatSomeAlert(alert: SomeAlert(
                                alert: mkAlert(title: LocalizedStringKey(NSLocalizedString("chat_invalid_link", comment: "alert title")), message: LocalizedStringKey(NSLocalizedString("chat_not_popopx_link", comment: "alert message"))),
                                id: "pasteLinkView: code is not a POPOPX link"
                            ))
                        }
                    }
                } label: {
                    Text(NSLocalizedString("chat_tap_to_paste_link", comment: "button label")).foregroundColor(theme.colors.primary)
                }
                .disabled(!pasteboardHasStrings)
                .frame(maxWidth: .infinity, alignment: .center)
                if connectProgressManager.showConnectProgress != nil {
                    ProgressView()
                }
            }
        } else {
            HStack {
                linkTextView(pastedLink)
                if connectProgressManager.showConnectProgress != nil {
                    ProgressView()
                }
            }
        }
    }

    private func processQRCode(_ resp: Result<ScanResult, ScanError>) {
        switch resp {
        case let .success(r):
            let link = r.string
            if strIsPopopxLink(r.string) {
                connect(link)
            } else {
                alert = .newChatSomeAlert(alert: SomeAlert(
                    alert: mkAlert(title: LocalizedStringKey(NSLocalizedString("chat_invalid_qr_code", comment: "alert title")), message: LocalizedStringKey(NSLocalizedString("chat_not_popopx_qr", comment: "alert message"))),
                    id: "processQRCode: code is not a POPOPX link"
                ))
            }
        case let .failure(e):
            logger.error("processQRCode QR code error: \(e.localizedDescription)")
            alert = .newChatSomeAlert(alert: SomeAlert(
                alert: mkAlert(title: LocalizedStringKey(NSLocalizedString("invalid_qr_code_title", comment: "Invalid QR code alert title")), message: LocalizedStringKey(String(format: NSLocalizedString("Error scanning code: %@", comment: "QR code scan error"), e.localizedDescription))),
                id: "processQRCode: failure"
            ))
        }
    }

    private var connectSectionHeader: some View {
        #if POPOPX_ASSETS
        VStack(alignment: .leading, spacing: 0) {
            Image(colorScheme == .light
                ? (onboarding ? "connect-via-link" : "connect-via-link-small")
                : (onboarding ? "connect-via-link-light" : "connect-via-link-small-light"))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            Text(NSLocalizedString("chat_paste_link_received", comment: "section header")).foregroundColor(theme.colors.secondary)
        }
        .padding(.bottom, 4)
        #else
        Text(NSLocalizedString("chat_paste_link_received", comment: "section header")).foregroundColor(theme.colors.secondary)
        #endif
    }

    private func connect(_ link: String) {
        showQRCodeScanner = false
        planAndConnect(
            link,
            theme: theme,
            dismiss: true,
            cleanup: {
                pastedLink = ""
            }
        )
    }
}

struct ScannerInView: View {
    @Binding var showQRCodeScanner: Bool
    var scannerPaused: Binding<Bool>? = nil
    let processQRCode: (_ resp: Result<ScanResult, ScanError>) -> Void
    @State private var cameraAuthorizationStatus: AVAuthorizationStatus?
    var scanMode: ScanMode = .continuous
    var placeholderBackground = Color(uiColor: .secondarySystemGroupedBackground)

    var body: some View {
        Group {
            if showQRCodeScanner, case .authorized = cameraAuthorizationStatus {
                CodeScannerView(codeTypes: [.qr], scanMode: scanMode, isPaused: scannerPaused?.wrappedValue ?? false, completion: processQRCode)
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .padding(.horizontal)
            } else {
                Button {
                    switch cameraAuthorizationStatus {
                    case .notDetermined: askCameraAuthorization { showQRCodeScanner = true }
                    case .restricted: ()
                    case .denied: UIApplication.shared.open(appSettingsURL)
                    case .authorized: showQRCodeScanner = true
                    default: askCameraAuthorization { showQRCodeScanner = true }
                    }
                } label: {
                    ZStack {
                        Rectangle()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(Color.clear)
                        switch cameraAuthorizationStatus {
                        case .authorized, nil: EmptyView()
                        case .restricted: Text(NSLocalizedString("chat_camera_not_available", comment: "camera status"))
                        case .denied:  Label(NSLocalizedString("chat_enable_camera_access", comment: "camera action"), systemImage: "camera")
                        default: Label(NSLocalizedString("chat_tap_to_scan", comment: "camera action"), systemImage: "qrcode")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(placeholderBackground)
                )
                .padding(.horizontal)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .disabled(cameraAuthorizationStatus == .restricted)
            }
        }
        .task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            cameraAuthorizationStatus = status
            if showQRCodeScanner {
                switch status {
                case .notDetermined: await askCameraAuthorizationAsync()
                case .restricted: showQRCodeScanner = false
                case .denied: showQRCodeScanner = false
                case .authorized: ()
                @unknown default: await askCameraAuthorizationAsync()
                }
            }
        }
    }

    func askCameraAuthorizationAsync() async {
        await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func askCameraAuthorization(_ cb: (() -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if allowed { cb?() }
        }
    }
}


func linkTextView(_ link: String) -> some View {
    Text(link)
        .lineLimit(1)
        .font(.caption)
        .truncationMode(.middle)
}

struct InfoSheetButton<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var showInfoSheet = false

    var body: some View {
        Button {
            showInfoSheet = true
        } label: {
            Image(systemName: "info.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .sheet(isPresented: $showInfoSheet) {
            content
        }
    }
}

// Haskell FFI now recognizes popopx:/ directly (no normalization needed)
private func normalizeForParsing(_ str: String) -> String {
    return str
}

func strIsPopopxLink(_ str: String) -> Bool {
    if str.hasPrefix("popopx://enc#") { return true }
    let normalized = normalizeForParsing(str)
    if let parsedMd = parseMarkdown(normalized),
       parsedMd.count == 1,
       case .popopxLink = parsedMd[0].format {
        return true
    } else {
        return false
    }
}

enum ConnectTarget {
    case link(text: String, linkType: PopopxLinkType, linkText: String)
    case name(PopopxNameInfo)
}

func strConnectTarget(_ str: String) -> ConnectTarget? {
    // Handle encrypted links directly without markdown parsing
    if str.hasPrefix("popopx://enc#") {
        let fragment = String(str.dropFirst("popopx://enc#".count))
        guard fragment.count >= 10, fragment.allSatisfy({ $0.isHexDigit || $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" || $0 == "-" || $0 == "_" }) else {
            return nil
        }
        return .link(text: str, linkType: .invitation, linkText: str)
    }
    let normalized = normalizeForParsing(str)
    let parsedMd = parseMarkdown(normalized)
    let links = parsedMd?.filter { $0.format?.isPopopxLink ?? false } ?? []
    return if links.count == 1, case let .popopxLink(_, linkType, _, smpHosts) = links[0].format {
        .link(text: links[0].text, linkType: linkType, linkText: popopxLinkText(linkType, smpHosts))
    } else if links.isEmpty,
              case let .popopxName(nameInfo) = parsedMd?.first(where: { if case .popopxName = $0.format { true } else { false } })?.format {
        .name(nameInfo)
    } else {
        nil
    }
}

func showUnsupportedNameAlert(_ nameInfo: PopopxNameInfo) {
    let upgrade = " " + NSLocalizedString("Please upgrade the app.", comment: "alert message")
    if nameInfo.nameType == .contact {
        showAlert(
            NSLocalizedString("Unsupported contact name", comment: "alert title"),
            message: NSLocalizedString("Connecting via contact name requires a newer app version.", comment: "alert message") + upgrade
        )
    } else {
        showAlert(
            NSLocalizedString("Unsupported channel name", comment: "alert title"),
            message: NSLocalizedString("Connecting via channel name requires a newer app version.", comment: "alert message") + upgrade
        )
    }
}

struct IncognitoToggle: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var incognitoEnabled: Bool
    @State private var showIncognitoSheet = false

    var body: some View {
        ZStack(alignment: .leading) {
            Image(systemName: incognitoEnabled ? "theatermasks.fill" : "theatermasks")
                .frame(maxWidth: 24, maxHeight: 24, alignment: .center)
                .foregroundColor(incognitoEnabled ? QuantumColors.accent : theme.colors.secondary)
                .font(.footnote)
            Toggle(isOn: $incognitoEnabled) {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("chat_incognito", comment: "profile option"))
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.colors.primary)
                        .font(.footnote)
                }
                .onTapGesture {
                    showIncognitoSheet = true
                }
            }
            .padding(.leading, 36)
        }
        .sheet(isPresented: $showIncognitoSheet) {
            IncognitoHelp()
        }
    }
}

@MainActor
func sharedProfileInfo(_ incognito: Bool) -> Text {
    let name = ChatModel.shared.currentUser?.displayName ?? ""
    return Text(
        incognito
        ? NSLocalizedString("A new random profile will be shared.", comment: "shared profile info")
        : String(format: NSLocalizedString("Your profile **%@** will be shared.", comment: "shared profile info"), name)
    )
}

private func showInvitationLinkConnectingAlert(cleanup: (() -> Void)?) {
    showAlert(
        NSLocalizedString("Already connecting!", comment: "new chat sheet title"),
        message: NSLocalizedString("You are already connecting via this one-time link!", comment: "new chat sheet message"),
        actions: {[
            okCleanupAlertAction(cleanup: cleanup)
        ]}
    )
}

private func showGroupLinkConnectingAlert(groupInfo: GroupInfo?, cleanup: (() -> Void)?) {
    if let groupInfo = groupInfo {
        if groupInfo.businessChat == nil {
            showAlert(
                NSLocalizedString("Group already exists!", comment: "new chat sheet title"),
                message:
                    String.localizedStringWithFormat(
                        NSLocalizedString("You are already joining the group %@.", comment: "new chat sheet message"),
                        groupInfo.displayName
                    ),
                actions: {[
                    okCleanupAlertAction(cleanup: cleanup)
                ]}
            )
        } else {
            showAlert(
                NSLocalizedString("Chat already exists!", comment: "new chat sheet title"),
                message:
                    String.localizedStringWithFormat(
                        NSLocalizedString("You are already connecting to %@.", comment: "new chat sheet message"),
                        groupInfo.displayName
                    ),
                actions: {[
                    okCleanupAlertAction(cleanup: cleanup)
                ]}
            )
        }
    } else {
        showAlert(
            NSLocalizedString("Already joining the group!", comment: "new chat sheet title"),
            message: NSLocalizedString("You are already joining the group via this link.", comment: "new chat sheet message"),
            actions: {[
                okCleanupAlertAction(cleanup: cleanup)
            ]}
        )
    }
}

private func okCleanupAlertAction(cleanup: (() -> Void)?) -> UIAlertAction {
    UIAlertAction(
        title: NSLocalizedString("Ok", comment: "new chat action"),
        style: .default,
        handler: { _ in
            cleanup?()
        }
    )
}

private func showAskCurrentOrIncognitoProfileSheet(
    title: String,
    actionStyle: UIAlertAction.Style = .default,
    connectionLink: CreatedConnLink,
    connectionPlan: ConnectionPlan?,
    ownerVerification: OwnerVerification? = nil,
    dismiss: Bool,
    cleanup: (() -> Void)?
) {
    showSheet(
        title,
        message: ownerVerificationMessage(ownerVerification),
        actions: {[
            UIAlertAction(
                title: NSLocalizedString("Use current profile", comment: "new chat action"),
                style: actionStyle,
                handler: { _ in
                    connectViaLink(connectionLink, connectionPlan: connectionPlan, dismiss: dismiss, incognito: false, cleanup: cleanup)
                }
            ),
            UIAlertAction(
                title: NSLocalizedString("Use new incognito profile", comment: "new chat action"),
                style: actionStyle,
                handler: { _ in
                    connectViaLink(connectionLink, connectionPlan: connectionPlan, dismiss: dismiss, incognito: true, cleanup: cleanup)
                }
            ),
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: "new chat action"),
                style: .default,
                handler: { _ in
                    cleanup?()
                }
            )
        ]}
    )
}

private func showAskCurrentOrIncognitoProfileConnectContactViaAddressSheet(
    contact: Contact,
    dismiss: Bool,
    cleanup: (() -> Void)?
) {
    showSheet(
        String.localizedStringWithFormat(
            NSLocalizedString("Connect with %@", comment: "new chat action"),
            contact.chatViewName
        ),
        actions: {[
            UIAlertAction(
                title: NSLocalizedString("Use current profile", comment: "new chat action"),
                style: .default,
                handler: { _ in
                    connectContactViaAddress_(contact, dismiss: dismiss, incognito: false, cleanup: cleanup)
                }
            ),
            UIAlertAction(
                title: NSLocalizedString("Use new incognito profile", comment: "new chat action"),
                style: .default,
                handler: { _ in
                    connectContactViaAddress_(contact, dismiss: dismiss, incognito: true, cleanup: cleanup)
                }
            ),
            UIAlertAction(
                title: NSLocalizedString("Cancel", comment: "new chat action"),
                style: .default,
                handler: { _ in
                    cleanup?()
                }
            )
        ]}
    )
}

private func showOwnGroupLinkConfirmConnectSheet(
    groupInfo: GroupInfo,
    connectionLink: CreatedConnLink,
    connectionPlan: ConnectionPlan?,
    dismiss: Bool,
    cleanup: (() -> Void)?
) {
    if groupInfo.useRelays {
        showSheet(
            String.localizedStringWithFormat(
                NSLocalizedString("This is your link for channel %@!", comment: "new chat action"),
                groupInfo.displayName
            ),
            actions: {[
                UIAlertAction(
                    title: NSLocalizedString("Open channel", comment: "new chat action"),
                    style: .default,
                    handler: { _ in
                        Task { @MainActor in
                            openKnownGroup(groupInfo, dismiss: dismiss, cleanup: cleanup)
                        }
                    }
                ),
                UIAlertAction(
                    title: NSLocalizedString("Cancel", comment: "new chat action"),
                    style: .default,
                    handler: { _ in
                        cleanup?()
                    }
                )
            ]}
        )
    } else {
        showSheet(
            String.localizedStringWithFormat(
                NSLocalizedString("Join your group?\nThis is your link for group %@!", comment: "new chat action"),
                groupInfo.displayName
            ),
            actions: {[
                UIAlertAction(
                    title: NSLocalizedString("Open group", comment: "new chat action"),
                    style: .default,
                    handler: { _ in
                        Task { @MainActor in
                            openKnownGroup(groupInfo, dismiss: dismiss, cleanup: cleanup)
                        }
                    }
                ),
                UIAlertAction(
                    title: NSLocalizedString("Use current profile", comment: "new chat action"),
                    style: .destructive,
                    handler: { _ in
                        connectViaLink(connectionLink, connectionPlan: connectionPlan, dismiss: dismiss, incognito: false, cleanup: cleanup)
                    }
                ),
                UIAlertAction(
                    title: NSLocalizedString("Use new incognito profile", comment: "new chat action"),
                    style: .destructive,
                    handler: { _ in
                        connectViaLink(connectionLink, connectionPlan: connectionPlan, dismiss: dismiss, incognito: true, cleanup: cleanup)
                    }
                ),
                UIAlertAction(
                    title: NSLocalizedString("Cancel", comment: "new chat action"),
                    style: .default,
                    handler: { _ in
                        cleanup?()
                    }
                )
            ]}
        )
    }
}

private func showPrepareContactAlert(
    connectionLink: CreatedConnLink,
    contactShortLinkData: ContactShortLinkData,
    ownerVerification: OwnerVerification? = nil,
    theme: AppTheme,
    dismiss: Bool,
    cleanup: (() -> Void)?
) {
    showOpenChatAlert(
        profileName: contactShortLinkData.profile.displayName,
        profileFullName: contactShortLinkData.profile.fullName,
        profileImage:
            ProfileImage(
                imageStr: contactShortLinkData.profile.image,
                iconName: contactShortLinkData.business
                            ? "briefcase.circle.fill"
                            : contactShortLinkData.profile.peerType == .bot
                            ? "cube.fill"
                            : "person.crop.circle.fill",
                size: alertProfileImageSize
            ),
        profileBadge: contactShortLinkData.localBadge,
        theme: theme,
        information: ownerVerificationMessage(ownerVerification),
        cancelTitle: NSLocalizedString("Cancel", comment: "new chat action"),
        confirmTitle: NSLocalizedString("Open new chat", comment: "new chat action"),
        onCancel: { cleanup?() },
        onConfirm: {
            Task {
                do {
                    let chat = try await apiPrepareContact(connLink: connectionLink, contactShortLinkData: contactShortLinkData)
                    await MainActor.run {
                        ChatModel.shared.addChat(Chat(chat))
                        openKnownChat(chat.id, dismiss: dismiss, cleanup: cleanup)
                    }
                } catch let error {
                    logger.error("showPrepareContactAlert apiPrepareContact error: \(error.localizedDescription)")
                    showAlert(NSLocalizedString("Error opening chat", comment: ""), message: responseError(error))
                    await MainActor.run {
                        cleanup?()
                    }
                }
            }
        }
    )
}

private func showPrepareGroupAlert(
    connectionLink: CreatedConnLink,
    groupShortLinkInfo: GroupShortLinkInfo?,
    groupShortLinkData: GroupShortLinkData,
    ownerVerification: OwnerVerification? = nil,
    theme: AppTheme,
    dismiss: Bool,
    cleanup: (() -> Void)?
) {
    let isChannel = !(groupShortLinkInfo?.direct ?? true)
    let subscriberCount = groupShortLinkData.publicGroupData.map { String(format: NSLocalizedString("%d subscribers", comment: "channel subtitle"), $0.publicMemberCount) }
    showOpenChatAlert(
        profileName: groupShortLinkData.groupProfile.displayName,
        profileFullName: groupShortLinkData.groupProfile.fullName,
        profileImage:
            ProfileImage(
                imageStr: groupShortLinkData.groupProfile.image,
                iconName: isChannel
                            ? "antenna.radiowaves.left.and.right.circle.fill"
                            : "person.2.circle.fill",
                size: alertProfileImageSize
            ),
        theme: theme,
        subtitle: isChannel ? subscriberCount : nil,
        information: ownerVerificationMessage(ownerVerification),
        cancelTitle: NSLocalizedString("Cancel", comment: "new chat action"),
        confirmTitle: isChannel
            ? NSLocalizedString("Open channel", comment: "new chat action")
            : NSLocalizedString("Open group", comment: "new chat action"),
        onCancel: { cleanup?() },
        onConfirm: {
            Task {
                do {
                    let chat = try await apiPrepareGroup(connLink: connectionLink, directLink: groupShortLinkInfo?.direct ?? true, groupShortLinkData: groupShortLinkData)
                    await MainActor.run {
                        if let relays = groupShortLinkInfo?.groupRelays, !relays.isEmpty,
                           case let .group(gInfo, _) = chat.chatInfo {
                            ChatModel.shared.channelRelayHostnames[gInfo.groupId] = relays
                        }
                        ChatModel.shared.addChat(Chat(chat))
                        openKnownChat(chat.id, dismiss: dismiss, cleanup: cleanup)
                    }
                } catch let error {
                    logger.error("showPrepareGroupAlert apiPrepareGroup error: \(error.localizedDescription)")
                    showAlert(NSLocalizedString(isChannel ? "Error opening channel" : "Error opening group", comment: "alert title"), message: responseError(error))
                    await MainActor.run {
                        cleanup?()
                    }
                }
            }
        }
    )
}

@MainActor
private func showOpenKnownContactAlert(
    _ contact: Contact,
    theme: AppTheme,
    dismiss: Bool
) {
    showOpenChatAlert(
        profileName: contact.profile.displayName,
        profileFullName: contact.profile.fullName,
        profileImage:
            ProfileImage(
                imageStr: contact.profile.image,
                iconName: contact.chatIconName,
                size: alertProfileImageSize
            ),
        profileBadge: contact.active ? contact.profile.localBadge : nil,
        theme: theme,
        cancelTitle: NSLocalizedString("Cancel", comment: "new chat action"),
        confirmTitle:
            contact.nextConnectPrepared
            ? NSLocalizedString("Open new chat", comment: "new chat action")
            : NSLocalizedString("Open chat", comment: "new chat action"),
        onConfirm: {
            openKnownContact(contact, dismiss: dismiss, cleanup: nil)
        }
    )
}

private func memberRoleInformation(_ role: GroupMemberRole, isChannel: Bool) -> String {
    switch role {
    case .observer: isChannel
        ? NSLocalizedString("You are a subscriber", comment: "new chat alert")
        : NSLocalizedString("You are an observer", comment: "new chat alert")
    case .moderator: NSLocalizedString("You are a moderator", comment: "new chat alert")
    case .admin: NSLocalizedString("You are an admin", comment: "new chat alert")
    case .owner: NSLocalizedString("You are an owner", comment: "new chat alert")
    default: isChannel
        ? NSLocalizedString("You are a contributor", comment: "new chat alert")
        : NSLocalizedString("You are a member", comment: "new chat alert")
    }
}

@MainActor
private func showOpenKnownGroupAlert(
    _ groupInfo: GroupInfo,
    theme: AppTheme,
    dismiss: Bool
) {
    let subscriberCount = groupInfo.groupSummary.publicMemberCount.map { String(format: NSLocalizedString("%d subscribers", comment: "channel subtitle"), $0) }
    showOpenChatAlert(
        profileName: groupInfo.groupProfile.displayName,
        profileFullName: groupInfo.groupProfile.fullName,
        profileImage:
            ProfileImage(
                imageStr: groupInfo.groupProfile.image,
                iconName: groupInfo.chatIconName,
                size: alertProfileImageSize
            ),
        theme: theme,
        subtitle: groupInfo.useRelays ? subscriberCount : nil,
        information: groupInfo.nextConnectPrepared || groupInfo.businessChat != nil
            ? nil
            : memberRoleInformation(groupInfo.membership.memberRole, isChannel: groupInfo.useRelays),
        cancelTitle: NSLocalizedString("Cancel", comment: "new chat action"),
        confirmTitle:
            groupInfo.useRelays
            ? NSLocalizedString("Open channel", comment: "new chat action")
            : groupInfo.businessChat == nil
            ? NSLocalizedString("Open group", comment: "new chat action")
            : ( groupInfo.nextConnectPrepared
                ? NSLocalizedString("Open new chat", comment: "new chat action")
                : NSLocalizedString("Open chat", comment: "new chat action")
              ),
        onConfirm: {
            openKnownGroup(groupInfo, dismiss: dismiss, cleanup: nil)
        }
    )
}

// Spec: spec/client/navigation.md#planAndConnect
@MainActor
private final class AlertBox {
    let alert: Alert
    init(alert: Alert) { self.alert = alert }
}

@MainActor
func planAndConnect(
    _ shortOrFullLink: String,
    linkOwnerSig: LinkOwnerSig? = nil,
    theme: AppTheme,
    dismiss: Bool,
    cleanup: (() -> Void)? = nil,
    filterKnownContact: ((Contact) -> Void)? = nil,
    filterKnownGroup: ((GroupInfo) -> Void)? = nil
) {
    let shortOrFullLink = normalizeForParsing(shortOrFullLink)
    switch strConnectTarget(shortOrFullLink) {
    case let .name(nameInfo):
        showUnsupportedNameAlert(nameInfo)
        cleanup?()
        return
    case let .link(_, linkType, _):
        if linkType == .relay {
            showAlert(
                NSLocalizedString("Relay address", comment: "alert title"),
                message: NSLocalizedString("This is a chat relay address, it cannot be used to connect.", comment: "alert message")
            )
            cleanup?()
            return
        }
    case .none: break
    }
    ConnectProgressManager.shared.cancelConnectProgress()
    let inProgress = BoxedValue(true)
    connectTask(inProgress)
    ConnectProgressManager.shared.startConnectProgress(NSLocalizedString("Loading profile…", comment: "in progress text")) {
        inProgress.boxedValue = false
        cleanup?()
    }

    func connectTask(_ inProgress: BoxedValue<Bool>) {
        Task {
            let (result, alert) = await apiConnectPlan(connLink: shortOrFullLink, linkOwnerSig: linkOwnerSig, inProgress: inProgress)
            let alertBox = alert.map { AlertBox(alert: $0) }
            await MainActor.run {
                ConnectProgressManager.shared.stopConnectProgress()
            }
            if !inProgress.boxedValue { return }
            if let (connectionLink, connectionPlan) = result {
                switch connectionPlan {
                case let .invitationLink(ilp):
                    switch ilp {
                    case let .ok(contactSLinkData_, ownerVerification):
                        if let contactSLinkData = contactSLinkData_ {
                            logger.debug("planAndConnect, .invitationLink, .ok, short link data present")
                            await MainActor.run {
                                showPrepareContactAlert(
                                    connectionLink: connectionLink,
                                    contactShortLinkData: contactSLinkData,
                                    ownerVerification: ownerVerification,
                                    theme: theme,
                                    dismiss: dismiss,
                                    cleanup: cleanup
                                )
                            }
                        } else {
                            logger.debug("planAndConnect, .invitationLink, .ok, no short link data")
                            await MainActor.run {
                                logger.debug("planAndConnect: about to call showAskCurrentOrIncognitoProfileSheet")
                                showAskCurrentOrIncognitoProfileSheet(
                                    title: NSLocalizedString("Connect via one-time link", comment: "new chat sheet title"),
                                    connectionLink: connectionLink,
                                    connectionPlan: connectionPlan,
                                    ownerVerification: ownerVerification,
                                    dismiss: dismiss,
                                    cleanup: cleanup
                                )
                            }
                        }
                    case .ownLink:
                        logger.debug("planAndConnect, .invitationLink, .ownLink")
                        await MainActor.run {
                            showAskCurrentOrIncognitoProfileSheet(
                                title: NSLocalizedString("Connect to yourself?\nThis is your own one-time link!", comment: "new chat sheet title"),
                                actionStyle: .destructive,
                                connectionLink: connectionLink,
                                connectionPlan: connectionPlan,
                                dismiss: dismiss,
                                cleanup: cleanup
                            )
                        }
                    case let .connecting(contact_):
                        logger.debug("planAndConnect, .invitationLink, .connecting")
                        await MainActor.run {
                            if let contact = contact_ {
                                if let f = filterKnownContact {
                                    f(contact)
                                } else {
                                    showOpenKnownContactAlert(contact, theme: theme, dismiss: dismiss)
                                }
                            } else {
                                showInvitationLinkConnectingAlert(cleanup: cleanup)
                            }
                        }
                    case let .known(contact):
                        logger.debug("planAndConnect, .invitationLink, .known")
                        await MainActor.run {
                            if let f = filterKnownContact {
                                f(contact)
                            } else {
                                showOpenKnownContactAlert(contact, theme: theme, dismiss: dismiss)
                            }
                        }
                    }
                case let .contactAddress(cap):
                    switch cap {
                    case let .ok(contactSLinkData_, ownerVerification):
                        if let contactSLinkData = contactSLinkData_ {
                            logger.debug("planAndConnect, .contactAddress, .ok, short link data present")
                            await MainActor.run {
                                showPrepareContactAlert(
                                    connectionLink: connectionLink,
                                    contactShortLinkData: contactSLinkData,
                                    ownerVerification: ownerVerification,
                                    theme: theme,
                                    dismiss: dismiss,
                                    cleanup: cleanup
                                )
                            }
                        } else {
                            logger.debug("planAndConnect, .contactAddress, .ok, no short link data")
                            await MainActor.run {
                                showAskCurrentOrIncognitoProfileSheet(
                                    title: NSLocalizedString("Connect via contact address", comment: "new chat sheet title"),
                                    connectionLink: connectionLink,
                                    connectionPlan: connectionPlan,
                                    ownerVerification: ownerVerification,
                                    dismiss: dismiss,
                                    cleanup: cleanup
                                )
                            }
                        }
                    case .ownLink:
                        logger.debug("planAndConnect, .contactAddress, .ownLink")
                        await MainActor.run {
                            showAskCurrentOrIncognitoProfileSheet(
                                title: NSLocalizedString("Connect to yourself?\nThis is your own POPOPX address!", comment: "new chat sheet title"),
                                actionStyle: .destructive,
                                connectionLink: connectionLink,
                                connectionPlan: connectionPlan,
                                dismiss: dismiss,
                                cleanup: cleanup
                            )
                        }
                    case .connectingConfirmReconnect:
                        logger.debug("planAndConnect, .contactAddress, .connectingConfirmReconnect")
                        await MainActor.run {
                            showAskCurrentOrIncognitoProfileSheet(
                                title: NSLocalizedString("You have already requested connection!\nRepeat connection request?", comment: "new chat sheet title"),
                                actionStyle: .destructive,
                                connectionLink: connectionLink,
                                connectionPlan: connectionPlan,
                                dismiss: dismiss,
                                cleanup: cleanup
                            )
                        }
                    case let .connectingProhibit(contact):
                        logger.debug("planAndConnect, .contactAddress, .connectingProhibit")
                        await MainActor.run {
                            if let f = filterKnownContact {
                                f(contact)
                            } else {
                                showOpenKnownContactAlert(contact, theme: theme, dismiss: dismiss)
                            }
                        }
                    case let .known(contact):
                        logger.debug("planAndConnect, .contactAddress, .known")
                        await MainActor.run {
                            if let f = filterKnownContact {
                                f(contact)
                            } else {
                                showOpenKnownContactAlert(contact, theme: theme, dismiss: dismiss)
                            }
                        }
                    case let .contactViaAddress(contact):
                        logger.debug("planAndConnect, .contactAddress, .contactViaAddress")
                        await MainActor.run {
                            showAskCurrentOrIncognitoProfileConnectContactViaAddressSheet(
                                contact: contact,
                                dismiss: dismiss,
                                cleanup: cleanup
                            )
                        }
                    }
                case let .groupLink(glp):
                    switch glp {
                    case let .ok(groupShortLinkInfo_, groupSLinkData_, ownerVerification):
                        if let groupSLinkData = groupSLinkData_ {
                            logger.debug("planAndConnect, .groupLink, .ok, short link data present")
                            await MainActor.run {
                                showPrepareGroupAlert(
                                    connectionLink: connectionLink,
                                    groupShortLinkInfo: groupShortLinkInfo_,
                                    groupShortLinkData: groupSLinkData,
                                    ownerVerification: ownerVerification,
                                    theme: theme,
                                    dismiss: dismiss,
                                    cleanup: cleanup
                                )
                            }
                        } else {
                            logger.debug("planAndConnect, .groupLink, .ok, no short link data")
                            await MainActor.run {
                                showAskCurrentOrIncognitoProfileSheet(
                                    title: NSLocalizedString("Join group", comment: "new chat sheet title"),
                                    connectionLink: connectionLink,
                                    connectionPlan: connectionPlan,
                                    ownerVerification: ownerVerification,
                                    dismiss: dismiss,
                                    cleanup: cleanup
                                )
                            }
                        }
                    case let .ownLink(groupInfo):
                        logger.debug("planAndConnect, .groupLink, .ownLink")
                        await MainActor.run {
                            if let f = filterKnownGroup {
                                f(groupInfo)
                            }
                            showOwnGroupLinkConfirmConnectSheet(
                                groupInfo: groupInfo,
                                connectionLink: connectionLink,
                                connectionPlan: connectionPlan,
                                dismiss: dismiss,
                                cleanup: cleanup
                            )
                        }
                    case .connectingConfirmReconnect:
                        logger.debug("planAndConnect, .groupLink, .connectingConfirmReconnect")
                        await MainActor.run {
                            showAskCurrentOrIncognitoProfileSheet(
                                title: NSLocalizedString("You are already joining the group!\nRepeat join request?", comment: "new chat sheet title"),
                                actionStyle: .destructive,
                                connectionLink: connectionLink,
                                connectionPlan: connectionPlan,
                                dismiss: dismiss,
                                cleanup: cleanup
                            )
                        }
                    case let .connectingProhibit(groupInfo_):
                        logger.debug("planAndConnect, .groupLink, .connectingProhibit")
                        await MainActor.run {
                            showGroupLinkConnectingAlert(groupInfo: groupInfo_, cleanup: cleanup)
                        }
                    case let .known(groupInfo):
                        logger.debug("planAndConnect, .groupLink, .known")
                        await MainActor.run {
                            if let f = filterKnownGroup {
                                f(groupInfo)
                            } else {
                                showOpenKnownGroupAlert(groupInfo, theme: theme, dismiss: dismiss)
                            }
                        }
                    case let .noRelays(groupSLinkData_):
                        logger.debug("planAndConnect, .groupLink, .noRelays")
                        await MainActor.run {
                            if let groupSLinkData = groupSLinkData_ {
                                showOpenChatAlert(
                                    profileName: groupSLinkData.groupProfile.displayName,
                                    profileFullName: groupSLinkData.groupProfile.fullName,
                                    profileImage:
                                        ProfileImage(
                                            imageStr: groupSLinkData.groupProfile.image,
                                            iconName: "antenna.radiowaves.left.and.right.circle.fill",
                                            size: alertProfileImageSize
                                        ),
                                    theme: theme,
                                    subtitle: NSLocalizedString("Channel has no active relays. Please try to join later.", comment: "alert subtitle"),
                                    cancelTitle: NSLocalizedString("OK", comment: "alert button"),
                                    confirmTitle: nil,
                                    onCancel: { cleanup?() }
                                )
                            } else {
                                showAlert(
                                    NSLocalizedString("Channel temporarily unavailable", comment: "alert title"),
                                    message: NSLocalizedString("Channel has no active relays. Please try to join later.", comment: "alert message")
                                )
                                cleanup?()
                            }
                        }
                    case let .updateRequired(groupSLinkData_):
                        logger.debug("planAndConnect, .groupLink, .updateRequired")
                        await MainActor.run {
                            if let groupSLinkData = groupSLinkData_ {
                                showOpenChatAlert(
                                    profileName: groupSLinkData.groupProfile.displayName,
                                    profileFullName: groupSLinkData.groupProfile.fullName,
                                    profileImage:
                                        ProfileImage(
                                            imageStr: groupSLinkData.groupProfile.image,
                                            iconName: "person.2.circle.fill",
                                            size: alertProfileImageSize
                                        ),
                                    theme: theme,
                                    subtitle: NSLocalizedString("This group requires a newer version of the app. Please update the app to join.", comment: "alert subtitle"),
                                    cancelTitle: NSLocalizedString("OK", comment: "alert button"),
                                    confirmTitle: nil,
                                    onCancel: { cleanup?() }
                                )
                            } else {
                                showAlert(
                                    NSLocalizedString("App update required", comment: "alert title"),
                                    message: NSLocalizedString("This group requires a newer version of the app. Please update the app to join.", comment: "alert message")
                                )
                                cleanup?()
                            }
                        }
                    }
                case let .error(chatError):
                    logger.debug("planAndConnect, .error \(chatErrorString(chatError))")
                    showAskCurrentOrIncognitoProfileSheet(
                        title: NSLocalizedString("Connect via link", comment: "new chat sheet title"),
                        connectionLink: connectionLink,
                        connectionPlan: nil,
                        dismiss: dismiss,
                        cleanup: cleanup
                    )
                }
            } else {
                DispatchQueue.main.async {
                    if let alertBox {
                        dismissAllSheets(animated: true) {
                            AlertManager.shared.showAlert(alertBox.alert)
                            cleanup?()
                        }
                    } else {
                        cleanup?()
                    }
                }
            }
        }
    }
}

private func connectContactViaAddress_(_ contact: Contact, dismiss: Bool, incognito: Bool, cleanup: (() -> Void)? = nil) {
    Task {
        if dismiss {
            DispatchQueue.main.async {
                dismissAllSheets(animated: true)
            }
        }
        let ok = await connectContactViaAddress(contact.contactId, incognito)
        if ok {
            await MainActor.run { AlertManager.shared.showAlert(connReqSentAlert(.contact)) }
        }
        cleanup?()
    }
}

private func connectViaLink(
    _ connectionLink: CreatedConnLink,
    connectionPlan: ConnectionPlan?,
    dismiss: Bool,
    incognito: Bool,
    cleanup: (() -> Void)?
) {
    Task {
        logger.debug("connectViaLink: starting, showing progress")
        // Show progress indicator during connection
        await MainActor.run {
            ConnectProgressManager.shared.startConnectProgress(
                NSLocalizedString("Connecting…", comment: "connection in progress")
            )
        }

        let result = await apiConnect(incognito: incognito, connLink: connectionLink)
        logger.debug("connectViaLink: apiConnect returned, result=\(result != nil ? "success" : "nil")")

        // Stop progress indicator
        await MainActor.run {
            ConnectProgressManager.shared.stopConnectProgress()
        }

        if let (connReqType, pcc) = result {
            await MainActor.run {
                ChatModel.shared.updateContactConnection(pcc)
            }
            let crt: ConnReqType
            crt = if let plan = connectionPlan {
                planToConnReqType(plan) ?? connReqType
            } else {
                connReqType
            }
            DispatchQueue.main.async {
                logger.debug("connectViaLink: showing alert via UIKit and will dismiss sheets on OK")
                // Use UIKit-based showAlert to present on top of any sheet
                showAlert(
                    title: NSLocalizedString("chat_connection_request_sent", comment: "alert title"),
                    message: crt.connReqSentTextString,
                    buttonTitle: NSLocalizedString("OK", comment: "alert button"),
                    buttonAction: {
                        logger.debug("connectViaLink: OK tapped, dismissing all sheets")
                        dismissAllSheets(animated: true) {
                            logger.debug("connectViaLink: all sheets dismissed, switching to chats tab")
                            ChatModel.shared.switchToChatsTab = true
                            cleanup?()
                        }
                    },
                    cancelButton: false
                )
            }
        } else {
            logger.debug("connectViaLink: apiConnect returned nil, dismissing sheets")
            DispatchQueue.main.async {
                dismissAllSheets(animated: true) {
                    ChatModel.shared.switchToChatsTab = true
                    cleanup?()
                }
            }
        }
    }
}

@MainActor
func openKnownContact(_ contact: Contact, dismiss: Bool, cleanup: (() -> Void)?) {
    if let c = ChatModel.shared.getContactChat(contact.contactId) {
        openKnownChat(c.id, dismiss: dismiss, cleanup: cleanup)
    }
}

@MainActor
func openKnownGroup(_ groupInfo: GroupInfo, dismiss: Bool, cleanup: (() -> Void)?) {
    if let g = ChatModel.shared.getGroupChat(groupInfo.groupId) {
        openKnownChat(g.id, dismiss: dismiss, cleanup: cleanup)
    }
}

@MainActor
func openKnownChat(_ chatId: ChatId, dismiss: Bool, cleanup: (() -> Void)?) {
    if dismiss {
        dismissAllSheets(animated: true) {
            ItemsModel.shared.loadOpenChat(chatId) {
                cleanup?()
            }
        }
    } else {
        ItemsModel.shared.loadOpenChat(chatId) {
            cleanup?()
        }
    }
}

func contactAlreadyConnectingAlert(_ contact: Contact) -> Alert {
    Alert(
        title: Text(NSLocalizedString("chat_contact_already_exists", comment: "alert title")),
        message: Text(String(format: NSLocalizedString("You are already connecting to %@.", comment: "alert message"), contact.displayName))
    )
}

func groupAlreadyExistsAlert(_ groupInfo: GroupInfo) -> Alert {
    groupInfo.businessChat == nil
    ? Alert(
        title: Text(NSLocalizedString("chat_group_already_exists", comment: "alert title")),
        message: Text(String(format: NSLocalizedString("You are already in group %@.", comment: "alert message"), groupInfo.displayName))
    )
    : Alert(
        title: Text(NSLocalizedString("chat_chat_already_exists", comment: "alert title")),
        message: Text(String(format: NSLocalizedString("You are already connected with %@.", comment: "alert message"), groupInfo.displayName))
    )
}

enum ConnReqType: Equatable {
    case invitation
    case contact
    case groupLink

    var connReqSentText: LocalizedStringKey {
        switch self {
        case .invitation: return LocalizedStringKey(NSLocalizedString("chat_conn_req_sent_invitation", comment: "connection request sent message"))
        case .contact: return LocalizedStringKey(NSLocalizedString("chat_conn_req_sent_contact", comment: "connection request sent message"))
        case .groupLink: return LocalizedStringKey(NSLocalizedString("chat_conn_req_sent_group", comment: "connection request sent message"))
        }
    }

    var connReqSentTextString: String {
        switch self {
        case .invitation: return NSLocalizedString("chat_conn_req_sent_invitation", comment: "connection request sent message")
        case .contact: return NSLocalizedString("chat_conn_req_sent_contact", comment: "connection request sent message")
        case .groupLink: return NSLocalizedString("chat_conn_req_sent_group", comment: "connection request sent message")
        }
    }
}

private func planToConnReqType(_ connectionPlan: ConnectionPlan) -> ConnReqType? {
    switch connectionPlan {
    case .invitationLink: .invitation
    case .contactAddress: .contact
    case .groupLink: .groupLink
    case .error: nil
    }
}

private func ownerVerificationMessage(_ ov: OwnerVerification?) -> String? {
    switch ov {
    case .verified: NSLocalizedString("Link signature verified.", comment: "owner verification")
    case let .failed(reason): String.localizedStringWithFormat(NSLocalizedString("⚠️ Signature verification failed: %@.", comment: "owner verification"), reason)
    case .none: nil
    }
}

func connReqSentAlert(_ type: ConnReqType) -> Alert {
    return Alert(
        title: Text(NSLocalizedString("chat_connection_request_sent", comment: "alert title")),
        message: Text(type.connReqSentText)
    )
}

struct PXNewChat_Previews: PreviewProvider {
    static var previews: some View {
        @State var parentAlert: SomeAlert?
        @State var contactConnection: PendingContactConnection? = nil

        PXNewChat(
            selection: .invite
        )
    }
}

// MARK: - POPOPX
extension PXNewChat {
    static let pxComponentTag: String = PXNewChatConfig.componentTag
    static let pxSelectionAnimationDuration: Double = PXNewChatConfig.selectionAnimationDuration
    static let pxSwipeMinimumDistance: CGFloat = PXNewChatConfig.swipeMinimumDistance
    static var pxCreateInvitationDelay: Double = PXNewChatConfig.createInvitationDelay
}
