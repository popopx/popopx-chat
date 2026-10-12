//
//  PXNotifications.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 26/06/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Constants
private enum PXNotificationsConfig {
    static let footerTopPadding: CGFloat = 1
    static let checkmarkSize: CGFloat = 16
    static let loadingScale: CGFloat = 2
    static let previewButtonSpacing: CGFloat = 8
    static let testStatusOpacity: Double = 0.85
    static let sectionHeaderDarkWeight: Font.Weight = .semibold
}

@MainActor
private struct PXNotificationsViewModel {
    let chatModel: ChatModel

    var currentMode: NotificationsMode { chatModel.notificationMode }
    var currentPreview: NotificationPreviewMode { chatModel.notificationState.notificationPreview }
    var deviceToken: DeviceToken? { chatModel.deviceToken }
    var notificationServer: String? { chatModel.notificationServer }
    var modeLabel: LocalizedStringKey { chatModel.notificationMode.label }
    var previewLabel: LocalizedStringKey { chatModel.notificationPreview.label }

    func refreshTokenState() -> (DeviceToken?, NtfTknStatus?, NotificationsMode, String?) {
        apiGetNtfToken()
    }
}

struct PXNotifications: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var notificationMode: NotificationsMode = ChatModel.shared.notificationMode
    @State private var ntfAlert: NotificationAlert?
    @State private var legacyDatabase = dbContainerGroupDefault.get() == .documents
    @State private var testing = false
    @State private var testedSuccess: Bool? = nil

    private var vm: PXNotificationsViewModel {
        PXNotificationsViewModel(chatModel: m)
    }

    var body: some View {
        ZStack {
            pxMainList
            if testing {
                ProgressView()
                    .scaleEffect(PXNotificationsConfig.loadingScale)
                    .accessibilityLabel(Text(NSLocalizedString("Testing notification delivery", comment: "Loading indicator during notification test")))
            }
        }
        .alert(item: $ntfAlert) { alert in
            if let token = m.deviceToken {
                return pxBuildAlert(alert, token)
            } else {
                return Alert(title: Text(NSLocalizedString("settings_no_device_token", comment: "Alert title when device token missing")))
            }
        }
        .popopxBranded()
    }

    // MARK: - View Builders

    @ViewBuilder
    private var pxMainList: some View {
        List {
            Section {
                pxNotificationModeSection
                pxPreviewModeSection
                pxServerInfoSection
            } header: {
                pxSectionHeader
            } footer: {
                pxFooter
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .disabled(legacyDatabase)
        .onAppear {
            (m.savedToken, m.tokenStatus, m.notificationMode, m.notificationServer) = vm.refreshTokenState()
        }
    }

    @ViewBuilder
    private var pxNotificationModeSection: some View {
        NavigationLink {
            pxNotificationModeDetail
        } label: {
            HStack {
                Text(NSLocalizedString("settings_send_notifications", comment: "Notification mode navigation label"))
                Spacer()
                Text(vm.modeLabel)
                    .accessibilityLabel(Text(NSLocalizedString("Current notification mode", comment: "Accessibility label for current mode")))
            }
        }
    }

    @ViewBuilder
    private var pxNotificationModeDetail: some View {
        List {
            Section {
                SelectionListView(list: NotificationsMode.values, selection: $notificationMode) { mode in
                    ntfAlert = .setMode(mode: mode)
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text(ntfModeDescription(notificationMode))
                        .foregroundColor(theme.colors.secondary)
                }
                .font(.callout)
                .padding(.top, PXNotificationsConfig.footerTopPadding)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("send_notifications_nav_title", comment: "Send notifications navigation title"))
        .modifier(ThemedBackground(grouped: true))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var pxPreviewModeSection: some View {
        NavigationLink {
            pxPreviewModeDetail
        } label: {
            HStack {
                Text(NSLocalizedString("settings_show_preview", comment: "Notification preview mode navigation label"))
                Spacer()
                Text(vm.previewLabel)
                    .accessibilityLabel(Text(NSLocalizedString("Current preview mode", comment: "Accessibility label for current preview mode")))
            }
        }
    }

    @ViewBuilder
    private var pxPreviewModeDetail: some View {
        List {
            Section {
                SelectionListView(
                    list: NotificationPreviewMode.values,
                    selection: Binding(
                        get: { m.notificationState.notificationPreview },
                        set: { m.notificationState.notificationPreview = $0 }
                    )
                ) { previewMode in
                    ntfPreviewModeGroupDefault.set(previewMode)
                    m.notificationPreview = previewMode
                }
            } footer: {
                pxPreviewFooterContent
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("show_preview_nav_title", comment: "Show preview navigation title"))
        .modifier(ThemedBackground(grouped: true))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var pxPreviewFooterContent: some View {
        VStack(alignment: .leading, spacing: PXNotificationsConfig.previewButtonSpacing) {
            Text(NSLocalizedString("settings_lock_screen_preview", comment: "Lock screen preview instructions"))
                .foregroundColor(theme.colors.secondary)
            Button(NSLocalizedString("settings_open_settings_button", comment: "Open iOS Settings app button")) {
                DispatchQueue.main.async {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
            .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
            .foregroundColor(isInDarkTheme() ? .white : .primary)
            .accessibilityLabel(Text(NSLocalizedString("Open system settings", comment: "Accessibility label for opening system settings")))
        }
    }

    @ViewBuilder
    private var pxServerInfoSection: some View {
        if let server = m.notificationServer {
            smpServers("Push server", [server], theme.colors.secondary)
            pxTestTokenRow(server)
        }
    }

    @ViewBuilder
    private var pxSectionHeader: some View {
        Text(NSLocalizedString("settings_push_notifications", comment: "Push notifications section header"))
            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
    }

    @ViewBuilder
    private var pxFooter: some View {
        if legacyDatabase {
            Text(NSLocalizedString("settings_restart_migrate_notice", comment: "Restart and migrate database notice"))
                .foregroundColor(theme.colors.secondary)
                .font(.callout)
                .padding(.top, PXNotificationsConfig.footerTopPadding)
        }
    }

    // MARK: - Alert Construction

    private func pxBuildAlert(_ alert: NotificationAlert, _ token: DeviceToken) -> Alert {
        switch alert {
        case let .setMode(mode):
            return Alert(
                title: Text(pxModeAlertTitle(mode)),
                message: Text(ntfModeDescription(mode)),
                primaryButton: .default(Text(mode == .off ? NSLocalizedString("notifications_turn_off", comment: "Turn off") : NSLocalizedString("notifications_enable", comment: "Enable"))) {
                    pxApplyNotificationsMode(token, mode)
                },
                secondaryButton: .cancel() {
                    notificationMode = m.notificationMode
                }
            )
        case let .testFailure(testFailure):
            return Alert(
                title: Text(NSLocalizedString("settings_server_test_failed", comment: "Alert title for server test failure")),
                message: Text(testFailure.localizedDescription)
            )
        case let .error(title, error):
            return Alert(title: Text(title), message: Text(error))
        }
    }

    private func pxModeAlertTitle(_ mode: NotificationsMode) -> LocalizedStringKey {
        switch mode {
        case .off: return "Use only local notifications?"
        case .periodic: return "Enable periodic notifications?"
        case .instant: return "Enable instant notifications?"
        }
    }

    // MARK: - Notification Mode Logic

    private func pxApplyNotificationsMode(_ token: DeviceToken, _ mode: NotificationsMode) {
        Task {
            switch mode {
            case .off:
                do {
                    try await apiDeleteToken(token: token)
                    await MainActor.run {
                        m.tokenStatus = .new
                        notificationMode = .off
                        m.notificationMode = .off
                        m.notificationServer = nil
                        testedSuccess = nil
                    }
                } catch let error {
                    await MainActor.run {
                        let err = responseError(error)
                        logger.error("apiDeleteToken error: \(err)")
                        notificationMode = m.notificationMode
                        ntfAlert = .error(title: LocalizedStringKey(NSLocalizedString("ntf_error_deleting_token", comment: "Error deleting token alert title")), error: err)
                    }
                }
            default:
                do {
                    let _ = try await apiRegisterToken(token: token, notificationMode: mode)
                    let (_, tknStatus, ntfMode, ntfServer) = apiGetNtfToken()
                    await MainActor.run {
                        m.tokenStatus = tknStatus
                        notificationMode = ntfMode
                        m.notificationMode = ntfMode
                        m.notificationServer = ntfServer
                        testedSuccess = nil
                    }
                } catch let error {
                    await MainActor.run {
                        let err = responseError(error)
                        logger.error("apiRegisterToken error: \(err)")
                        notificationMode = m.notificationMode
                        ntfAlert = .error(title: LocalizedStringKey(NSLocalizedString("ntf_error_enabling", comment: "Error enabling notifications alert title")), error: err)
                    }
                }
            }
        }
    }

    // MARK: - Test Token UI

    @ViewBuilder
    private func pxTestTokenRow(_ server: String) -> some View {
        HStack {
            Button(NSLocalizedString("settings_test_notifications", comment: "Test notification delivery button")) {
                testing = true
                Task {
                    await pxRunServerTest(server)
                    await MainActor.run { testing = false }
                }
            }
            .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
            .foregroundColor(isInDarkTheme() ? .white : .primary)
            .disabled(testing)
            .accessibilityLabel(Text(NSLocalizedString("Test notification delivery", comment: "Accessibility label for test button")))
            if !testing {
                Spacer()
                pxTestStatusIndicator
            }
        }
    }

    @ViewBuilder
    private var pxTestStatusIndicator: some View {
        if testedSuccess == true {
            Image(systemName: "checkmark")
                .foregroundColor(QuantumColors.success)
                .opacity(PXNotificationsConfig.testStatusOpacity)
                .accessibilityLabel(Text(NSLocalizedString("Test passed", comment: "Accessibility label for successful test")))
        } else if testedSuccess == false {
            Image(systemName: "multiply")
                .foregroundColor(QuantumColors.error)
                .opacity(PXNotificationsConfig.testStatusOpacity)
                .accessibilityLabel(Text(NSLocalizedString("Test failed", comment: "Accessibility label for failed test")))
        }
    }

    // MARK: - Server Test Logic

    private func pxRunServerTest(_ server: String) async {
        do {
            let r = try await testProtoServer(server: server)
            switch r {
            case .success:
                if let token = m.deviceToken {
                    await pxCheckTokenStatus(token)
                } else {
                    await MainActor.run {
                        showAlert(
                            NSLocalizedString("No token!", comment: "alert title")
                        )
                    }
                }
            case let .failure(f):
                await MainActor.run {
                    ntfAlert = .testFailure(testFailure: f)
                    testedSuccess = false
                }
            }
        } catch let error {
            await MainActor.run {
                let err = responseError(error)
                logger.error("testServerConnection \(err)")
                ntfAlert = .error(title: LocalizedStringKey(NSLocalizedString("ntf_error_testing_server", comment: "Error testing server connection alert title")), error: err)
            }
        }
    }

    private func pxCheckTokenStatus(_ token: DeviceToken) async {
        do {
            let status = try await apiCheckToken(token: token)
            await MainActor.run {
                m.tokenStatus = status
                testedSuccess = status.workingToken
                if status.workingToken {
                    showAlert(
                        NSLocalizedString("Notifications status", comment: "alert title"),
                        message: tokenStatusInfo(status, register: false)
                    )
                } else {
                    showAlert(
                        title: NSLocalizedString("Notifications error", comment: "alert title"),
                        message: tokenStatusInfo(status, register: true),
                        buttonTitle: NSLocalizedString("ntf_register_button", comment: "Register notification button"),
                        buttonAction: {
                            reRegisterToken(token: token)
                            testedSuccess = nil
                        },
                        cancelButton: true
                    )
                }
            }
        } catch let error {
            await MainActor.run {
                let err = responseError(error)
                logger.error("apiCheckToken \(err)")
                ntfAlert = .error(title: LocalizedStringKey(NSLocalizedString("ntf_error_checking_token", comment: "Error checking token status alert title")), error: err)
            }
        }
    }
}

func ntfModeDescription(_ mode: NotificationsMode) -> LocalizedStringKey {
    switch mode {
    case .off: return LocalizedStringKey(NSLocalizedString("ntf_mode_desc_off", comment: "Notification mode off description"))
    case .periodic: return LocalizedStringKey(NSLocalizedString("ntf_mode_desc_periodic", comment: "Notification mode periodic description"))
    case .instant: return LocalizedStringKey(NSLocalizedString("ntf_mode_desc_instant", comment: "Notification mode instant description"))
    }
}

func ntfModeShortDescription(_ mode: NotificationsMode) -> LocalizedStringKey {
    switch mode {
    case .off: return LocalizedStringKey(NSLocalizedString("ntf_mode_short_off", comment: "Short notification mode off description"))
    case .periodic: return LocalizedStringKey(NSLocalizedString("ntf_mode_short_periodic", comment: "Short notification mode periodic description"))
    case .instant: return LocalizedStringKey(NSLocalizedString("ntf_mode_short_instant", comment: "Short notification mode instant description"))
    }
}

// MARK: - POPOPX
extension PXNotifications {
    var pxComponentTag: String { "PX_NOTIFICATIONS_VIEW" }
}

struct SelectionListView<Item: SelectableItem>: View {
    @EnvironmentObject var theme: AppTheme
    var list: [Item]
    @Binding var selection: Item
    var onSelection: ((Item) -> Void)?
    @State private var tapped: Item? = nil

    var body: some View {
        ForEach(list) { item in
            Button {
                if selection == item { return }
                if let f = onSelection {
                    f(item)
                } else {
                    selection = item
                }
            } label: {
                pxSelectionRow(item)
            }
            .accessibilityLabel(Text(item.label))
        }
        .environment(\.editMode, .constant(.active))
    }

    @ViewBuilder
    private func pxSelectionRow(_ item: Item) -> some View {
        HStack {
            Text(item.label).foregroundColor(theme.colors.onBackground)
            Spacer()
            if selection == item {
                Image(systemName: "checkmark")
                    .resizable().scaledToFit().frame(width: PXNotificationsConfig.checkmarkSize)
                    .foregroundColor(theme.colors.primary)
            }
        }
    }
}

enum NotificationAlert: Identifiable {
    case setMode(mode: NotificationsMode)
    case testFailure(testFailure: ProtocolTestFailure)
    case error(title: LocalizedStringKey, error: String)

    var id: String {
        switch self {
        case let .setMode(mode): return "enable \(mode.rawValue)"
        case let .testFailure(testFailure): return "testFailure \(testFailure.testStep) \(testFailure.testError)"
        case let .error(title, error): return "error \(title): \(error)"
        }
    }
}

struct PXNotifications_Previews: PreviewProvider {
    static var previews: some View {
        PXNotifications()
    }
}
