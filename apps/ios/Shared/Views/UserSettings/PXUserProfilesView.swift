//
//  PXUserProfilesView.swift
//  POPOPX (iOS)
//
//  Created by Avently on 17.01.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
//  Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct PXUserProfiles: View {
    @EnvironmentObject private var m: ChatModel
    @EnvironmentObject private var theme: AppTheme
    @Environment(\.editMode) private var editMode
    @AppStorage(DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE) private var showHiddenProfilesNotice = true
    @AppStorage(DEFAULT_SHOW_MUTE_PROFILE_ALERT) private var showMuteProfileAlert = true
    @State private var showDeleteConfirmation = false
    @State private var userToDelete: User?
    @State private var alert: UserProfilesAlert?
    @State private var authorized = !UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)
    @State private var searchTextOrPassword = ""
    @State private var selectedUser: User?
    @State private var profileHidden = false
    @State private var profileAction: UserProfileAction?
    @State private var actionPassword = ""

    var trimmedSearchTextOrPassword: String { searchTextOrPassword.trimmingCharacters(in: .whitespaces)}

    private enum UserProfilesAlert: Identifiable {
        case deleteUser(user: User, delSMPQueues: Bool)
        case hiddenProfilesNotice
        case muteProfileAlert
        case activateUserError(error: String)
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case let .deleteUser(user, delSMPQueues): return "deleteUser \(user.userId) \(delSMPQueues)"
            case .hiddenProfilesNotice: return "hiddenProfilesNotice"
            case .muteProfileAlert: return "muteProfileAlert"
            case let .activateUserError(err): return "activateUserError \(err)"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    private enum UserProfileAction: Identifiable {
        case deleteUser(user: User, delSMPQueues: Bool)
        case unhideUser(user: User)

        var id: String {
            switch self {
            case let .deleteUser(user, delSMPQueues): return "deleteUser \(user.userId) \(delSMPQueues)"
            case let .unhideUser(user): return "unhideUser \(user.userId)"
            }
        }
    }

    var body: some View {
        List {
            pxHiddenProfilesBanner
            pxUserListSection
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .toolbar {
            EditButton()
        }
        .navigationTitle(NSLocalizedString("profile_your_profiles", comment: "Your chat profiles navigation title"))
        .modifier(ThemedBackground(grouped: true))
        .searchable(text: $searchTextOrPassword, placement: .navigationBarDrawer(displayMode: .always))
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .onAppear {
            if showHiddenProfilesNotice && m.users.count > 1 {
                alert = .hiddenProfilesNotice
            }
        }
        .confirmationDialog(LocalizedStringKey(NSLocalizedString("profile_delete_confirm", comment: "Delete chat profile confirmation title")), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            deleteModeButton(LocalizedStringKey(NSLocalizedString("profile_delete_with_connections", comment: "Delete profile and server connections")), true)
            deleteModeButton(LocalizedStringKey(NSLocalizedString("profile_delete_local_only", comment: "Delete local profile data only")), false)
        }
        .appSheet(item: $selectedUser) { user in
            HiddenProfileView(user: user, profileHidden: $profileHidden)
        }
        .onChange(of: profileHidden) {_, _ in
            Task {
                try? await Task.sleep(for: .seconds(PXUserProfilesConfig.hiddenProfileAutoDismissDelay))
                guard profileHidden else { return }
                withAnimation { profileHidden = false }
            }
        }
        .appSheet(item: $profileAction) { action in
            profileActionView(action)
        }
        .alert(item: $alert) { alert in
            pxAlertContent(alert)
        }
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxHiddenProfilesBanner: some View {
        if profileHidden {
            Button {
                withAnimation { profileHidden = false }
            } label: {
                Label(NSLocalizedString("profile_enter_password_hint", comment: "Enter password to show hidden profiles"), systemImage: "lock.open")
            }
            .accessibilityLabel(Text(NSLocalizedString("Show hidden profiles", comment: "Accessibility label")))
        }
    }

    @ViewBuilder
    private var pxUserListSection: some View {
        Section {
            let users = filteredUsers()
            let v = ForEach(users) { u in
                userView(u)
            }
            v.onDelete { indexSet in
                if let i = indexSet.first {
                    withAuth {
                        confirmDeleteUser(users[i].user)
                    }
                }
            }

            if trimmedSearchTextOrPassword == "" {
                NavigationLink {
                    CreateProfile()
                } label: {
                    Label(NSLocalizedString("profile_add_profile", comment: "Add profile button"), systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: PXUserProfilesConfig.buttonHeight)
                        .padding(.leading, 16).padding(.vertical, 8).padding(.trailing, 32)
                        .contentShape(Rectangle())
                        .padding(.leading, -16).padding(.vertical, -8).padding(.trailing, -32)
                }
                .accessibilityLabel(Text(NSLocalizedString("Add new profile", comment: "Accessibility label")))
            }
        } footer: {
            Text(NSLocalizedString("profile_tap_to_activate", comment: "Tap to activate profile footer hint"))
                .foregroundColor(theme.colors.secondary)
                .font(.body)
                .padding(.top, PXUserProfilesConfig.footerTopPadding)
        }
    }

    private func pxAlertContent(_ alert: UserProfilesAlert) -> Alert {
        switch alert {
        case let .deleteUser(user, delSMPQueues):
            return Alert(
                title: Text(NSLocalizedString("profile_delete_user_title", comment: "Delete user profile alert title")),
                message: Text(NSLocalizedString("profile_delete_user_message", comment: "Delete user profile warning message")),
                primaryButton: .destructive(Text(NSLocalizedString("profile_delete", comment: "Delete button title"))) {
                    Task { await removeUser(user, delSMPQueues, viewPwd: userViewPassword(user)) }
                },
                secondaryButton: .cancel()
            )
        case .hiddenProfilesNotice:
            return Alert(
                title: Text(NSLocalizedString("profile_make_private_title", comment: "Make profile private alert title")),
                message: Text(NSLocalizedString("profile_make_private_message", comment: "Make profile private explanation message")),
                primaryButton: .default(Text(NSLocalizedString("profile_dont_show_again", comment: "Don't show again button"))) {
                    showHiddenProfilesNotice = false
                },
                secondaryButton: .default(Text(NSLocalizedString("profile_ok", comment: "Ok button")))
            )
        case .muteProfileAlert:
            return Alert(
                title: Text(NSLocalizedString("profile_muted_title", comment: "Muted when inactive alert title")),
                message: Text(NSLocalizedString("profile_muted_message", comment: "Muted profile still receives calls message")),
                primaryButton: .default(Text(NSLocalizedString("profile_dont_show_again", comment: "Don't show again button"))) {
                    showMuteProfileAlert = false
                },
                secondaryButton: .default(Text(NSLocalizedString("profile_ok", comment: "Ok button")))
            )
        case let .activateUserError(error: err):
            return Alert(
                title: Text(NSLocalizedString("profile_switch_error", comment: "Error switching profile alert title")),
                message: Text(err)
            )
        case let .error(title, error):
            return mkAlert(title: title, message: error)
        }
    }

    // MARK: - POPOPX Actions & Helpers

    private func filteredUsers() -> [UserInfo] {
        let s = trimmedSearchTextOrPassword
        let lower = s.localizedLowercase
        return m.users.filter { u in
            if (u.user.activeUser || !u.user.hidden) && (s == "" || u.user.chatViewName.localizedLowercase.contains(lower)) {
                return true
            }
            return correctPassword(u.user, s)
        }
    }

    private var visibleUsersCount: Int {
        m.users.filter({ u in !u.user.hidden }).count
    }

    private func withAuth(_ action: @escaping () -> Void) {
        if authorized {
            action()
        } else {
            authenticate(
                reason: NSLocalizedString("Change chat profiles", comment: "authentication reason")
            ) { laResult in
                switch laResult {
                case .success, .unavailable:
                    authorized = true
                    PXAppSheetState.shared.scenePhaseActive = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + PXUserProfilesConfig.authDelaySeconds, execute: action)
                case .failed: authorized = false
                }
            }
        }
    }

    private func correctPassword(_ user: User, _ pwd: String) -> Bool {
        if let ph = user.viewPwdHash {
            return pwd != "" && chatPasswordHash(pwd, ph.salt) == ph.hash
        }
        return false
    }

    private func userViewPassword(_ user: User) -> String? {
        !user.hidden ? nil : trimmedSearchTextOrPassword
    }

    private func profileActionView(_ action: UserProfileAction) -> some View {
        let passwordValid = actionPassword == actionPassword.trimmingCharacters(in: .whitespaces)
        let passwordField = PassphraseField(key: $actionPassword, placeholder: NSLocalizedString("profile_password_placeholder", comment: "Profile password field placeholder"), valid: passwordValid)
        let actionEnabled: (User) -> Bool = { user in actionPassword != "" && passwordValid && correctPassword(user, actionPassword) }
        return List {
            switch action {
            case let .deleteUser(user, delSMPQueues):
                actionHeader(LocalizedStringKey(NSLocalizedString("profile_delete_header", comment: "Delete profile action header")), user)
                Section {
                    passwordField
                    settingsRow("trash", color: theme.colors.secondary) {
                        Button(NSLocalizedString("profile_delete_chat_profile", comment: "Delete chat profile action button"), role: .destructive) {
                            withAuth {
                                profileAction = nil
                                Task { await removeUser(user, delSMPQueues, viewPwd: actionPassword) }
                            }
                        }
                        .disabled(!actionEnabled(user))
                    }
                } footer: {
                    if actionEnabled(user) {
                        Text(NSLocalizedString("profile_delete_user_message", comment: "Delete user profile warning message"))
                            .foregroundColor(theme.colors.secondary)
                            .font(.callout)
                    }
                }
            case let .unhideUser(user):
                actionHeader(LocalizedStringKey(NSLocalizedString("profile_unhide_header", comment: "Unhide profile action header")), user)
                Section {
                    passwordField
                    settingsRow("lock.open", color: theme.colors.secondary) {
                        Button(NSLocalizedString("profile_unhide_chat_profile", comment: "Unhide chat profile action button")) {
                            withAuth{
                                profileAction = nil
                                setUserPrivacy(user) { try await apiUnhideUser(user.userId, viewPwd: actionPassword) }
                            }
                        }
                        .disabled(!actionEnabled(user))
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground())
    }

    @ViewBuilder func actionHeader(_ title: LocalizedStringKey, _ user: User) -> some View {
        Text(title)
            .font(.system(size: PXUserProfilesConfig.actionHeaderFontSize, weight: .semibold))
            .bold()
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            Section() {
            ProfilePreview(profileOf: user).padding(.leading, -8)
        }
    }

    private func deleteModeButton(_ title: LocalizedStringKey, _ delSMPQueues: Bool) -> some View {
        Button(title, role: .destructive) {
            withAuth {
                if let user = userToDelete {
                    if passwordEntryRequired(user) {
                        profileAction = .deleteUser(user: user, delSMPQueues: delSMPQueues)
                    } else {
                        alert = .deleteUser(user: user, delSMPQueues: delSMPQueues)
                    }
                }
            }
        }
    }

    private func passwordEntryRequired(_ user: User) -> Bool {
        user.hidden && user.activeUser && !correctPassword(user, trimmedSearchTextOrPassword)
    }

    private func removeUser(_ user: User, _ delSMPQueues: Bool, viewPwd: String?) async {
        do {
            if user.activeUser {
                ChatModel.shared.removeWallpaperFilesFromAllChats(user)
                if let newActive = m.users.first(where: { u in !u.user.activeUser && !u.user.hidden }) {
                    try await changeActiveUserAsync_(newActive.user.userId, viewPwd: nil)
                    try await deleteUser()
                } else {
                    // Deleting the last visible user while having hidden one(s)
                    try await deleteUser()
                    try await changeActiveUserAsync_(nil, viewPwd: nil)
                    try? await stopChatAsync()
                    await MainActor.run {
                        onboardingStageDefault.set(.step1_WelcomeIdentity)
                        m.onboardingStage = .step1_WelcomeIdentity
                        dismissAllSheets()
                    }
                }
            } else {
                try await deleteUser()
            }
        } catch let error {
            logger.error("Error deleting user profile: \(error)")
            await MainActor.run {
                AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error deleting user profile", comment: "")))
            }
        }

        func deleteUser() async throws {
            try await apiDeleteUser(user.userId, delSMPQueues, viewPwd: viewPwd)
            removeWallpaperFilesFromTheme(user.uiThemes)
            await MainActor.run { withAnimation { m.removeUser(user) } }
        }
    }

    @ViewBuilder private func userView(_ userInfo: UserInfo) -> some View {
        let user = userInfo.user
        let v = Button {
            Task {
                do {
                    try await changeActiveUserAsync_(user.userId, viewPwd: userViewPassword(user))
                    dismissAllSheets()
                } catch {
                    await MainActor.run { alert = .activateUserError(error: responseError(error)) }
                }
            }
        } label: {
            HStack {
                ProfileImage(imageStr: user.image, size: PXUserProfilesConfig.profileImageSize)
                    .padding(.trailing, PXUserProfilesConfig.profileImageTrailingPadding)
                Text(user.chatViewName)
                Spacer()
                pxUserStatusIcons(user, userInfo)
            }
        }
        .foregroundColor(theme.colors.onBackground)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            pxLeadingSwipeActions(user)
        }
        v
        .if(user.activeUser, transform: { view in
            view.overlay(
                RoundedRectangle(cornerRadius: PXUserProfilesConfig.activeUserCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: PXUserProfilesConfig.activeUserGradientStart).opacity(PXUserProfilesConfig.activeUserGradientStartOpacity), Color(hex: PXUserProfilesConfig.activeUserGradientEnd).opacity(PXUserProfilesConfig.activeUserGradientEndOpacity)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: PXUserProfilesConfig.activeUserBorderWidth
                    )
            )
        })
    }

    @ViewBuilder
    private func pxUserStatusIcons(_ user: User, _ userInfo: UserInfo) -> some View {
        if user.activeUser {
            Image(systemName: "checkmark").foregroundColor(theme.colors.onBackground)
        } else {
            if userInfo.unreadCount > 0 {
                userUnreadBadge(userInfo, theme: theme)
            }
            if user.hidden {
                Image(systemName: "lock").foregroundColor(theme.colors.secondary)
            } else if userInfo.unreadCount == 0 {
                if !user.showNtfs {
                    Image(systemName: "speaker.slash").foregroundColor(theme.colors.secondary)
                } else {
                    Image(systemName: "checkmark").foregroundColor(.clear)
                }
            }
        }
    }

    @ViewBuilder
    private func pxLeadingSwipeActions(_ user: User) -> some View {
        if user.hidden {
            Button(NSLocalizedString("profile_unhide", comment: "Unhide profile swipe action")) {
                withAuth {
                    if passwordEntryRequired(user) {
                        profileAction = .unhideUser(user: user)
                    } else {
                        setUserPrivacy(user) { try await apiUnhideUser(user.userId, viewPwd: trimmedSearchTextOrPassword) }
                    }
                }
            }
            .tint(QuantumColors.success)
        } else {
            if visibleUsersCount > 1 {
                Button(NSLocalizedString("profile_hide", comment: "Hide profile swipe action")) {
                    withAuth {
                        selectedUser = user
                    }
                }
                .tint(theme.colors.secondary)
            }
            Group {
                if user.showNtfs {
                    Button(NSLocalizedString("profile_mute", comment: "Mute profile swipe action")) {
                        withAuth {
                            setUserPrivacy(user, successAlert: showMuteProfileAlert ? .muteProfileAlert : nil) {
                                try await apiMuteUser(user.userId)
                            }
                        }
                    }
                } else {
                    Button(NSLocalizedString("profile_unmute", comment: "Unmute profile swipe action")) {
                        withAuth {
                            setUserPrivacy(user) { try await apiUnmuteUser(user.userId) }
                        }
                    }
                }
            }
            .tint(theme.colors.primary)
        }
    }

    private func confirmDeleteUser(_ user: User) {
        showDeleteConfirmation = true
        userToDelete = user
    }

    private func setUserPrivacy(_ user: User, successAlert: UserProfilesAlert? = nil, _ api: @escaping () async throws -> User) {
        Task {
            do {
                let u = try await api()
                await MainActor.run {
                    withAnimation { m.updateUser(u) }
                    if successAlert != nil {
                        alert = successAlert
                    }
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error updating user privacy", comment: "")))
                }
            }
        }
    }
}

public func chatPasswordHash(_ pwd: String, _ salt: String) -> String {
    guard var cPwd = pwd.cString(using: .utf8),
          var cSalt = salt.cString(using: .utf8),
          let cHash = chat_password_hash(&cPwd, &cSalt) else { return "" }
    return fromCString(cHash)
}

public func correctPassword(_ user: User, _ pwd: String) -> Bool {
    if let ph = user.viewPwdHash {
        return pwd != "" && chatPasswordHash(pwd, ph.salt) == ph.hash
    }
    return false
}

// MARK: - POPOPX Config & Tag

private enum PXUserProfilesConfig {
    static let buttonHeight: CGFloat = 38
    static let profileImageSize: CGFloat = 38
    static let profileImageTrailingPadding: CGFloat = 12
    static let footerTopPadding: CGFloat = 8
    static let actionHeaderFontSize: CGFloat = 28
    static let hiddenProfileAutoDismissDelay: Int = 10
    static let authDelaySeconds: Double = 0.5
    static let activeUserCornerRadius: CGFloat = 10
    static let activeUserBorderWidth: CGFloat = 1.5
    static let activeUserGradientStart: String = "#6E25C4"
    static let activeUserGradientStartOpacity: Double = 0.6
    static let activeUserGradientEnd: String = "#00FFD2"
    static let activeUserGradientEndOpacity: Double = 0.4
}

extension PXUserProfiles {
    static let pxComponentTag: String = "PX_USER_PROFILES_VIEW"
}

struct PXUserProfiles_Previews: PreviewProvider {
    static var previews: some View {
        PXUserProfiles()
    }
}
