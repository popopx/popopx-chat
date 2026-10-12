//
//  PXNetworkAndServers.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 02/08/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

private enum NetworkAlert: Identifiable {
    case error(err: String)

    var id: String {
        switch self {
        case let .error(err): return "error \(err)"
        }
    }
}

private enum NetworkAndServersSheet: Identifiable {
    case showConditions

    var id: String {
        switch self {
        case .showConditions: return "showConditions"
        }
    }
}

// MARK: - POPOPX Configuration
private enum PXNetworkAndServersConfig {
    static let operatorLogoSize: CGFloat = 24
    static let indicatorMaxSize: CGFloat = 24
    static let conditionsHorizontalPadding: CGFloat = 25
    static let conditionsReviewSpacing: CGFloat = 8
    static let conditionsBottomPadding: CGFloat = 16
    static let conditionsDeadlineHorizontalPadding: CGFloat = 32
    static let acceptButtonShadowRadius: CGFloat = 8
    static let acceptButtonShadowY: CGFloat = 4
    static let acceptButtonShadowOpacity: Double = 0.15
    static let refreshConfigLogPrefix: String = "PX: refreshing server config"
    static let componentIdentifier: String = "PX_NETWORK_AND_SERVERS"
    static let a11yPresetServersSection: String = "px_net_preset_section"
    static let a11yYourServersRow: String = "px_net_your_servers"
    static let a11yAdvancedSettings: String = "px_net_advanced"
    static let a11ySaveButton: String = "px_net_save"
    static let a11yIceServersRow: String = "px_net_ice_servers"
    static let a11yRefreshConfig: String = "px_net_refresh_config"
    static let a11yConnectionStatus: String = "px_net_connection"
    static let a11yConditionsReview: String = "px_net_conditions_review"
    static let a11yConditionsAccepted: String = "px_net_conditions_accepted"
}

// MARK: - POPOPX View Model
@MainActor
private struct PXNetworkAndServersViewModel {
    let chatModel: ChatModel
    let saveableSettings: SaveableSettings

    var conditionsAction: UsageConditionsAction? {
        chatModel.conditions.conditionsAction
    }

    var anyOperatorEnabled: Bool {
        saveableSettings.servers.userServers.contains(where: { $0.operator?.enabled ?? false })
    }

    var canSave: Bool {
        serversCanBeSaved(
            saveableSettings.servers.currUserServers,
            saveableSettings.servers.userServers,
            saveableSettings.servers.serverErrors
        )
    }

    var hasUnsavedOperatorChanges: Bool {
        saveableSettings.servers.userServers != saveableSettings.servers.currUserServers
    }

    var globalError: String? {
        globalServersError(saveableSettings.servers.serverErrors)
    }

    var globalWarning: String? {
        globalServersWarning(saveableSettings.servers.serverWarnings)
    }

    var hasServerErrors: Bool {
        !saveableSettings.servers.serverErrors.isEmpty
    }

    func operatorHasUnsavedChanges(at index: Int) -> Bool {
        saveableSettings.servers.userServers[index] != saveableSettings.servers.currUserServers[index]
    }

    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NetworkAndServers: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var m: ChatModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var ss: SaveableSettings
    @State private var sheetItem: NetworkAndServersSheet? = nil
    @State private var justOpened = true
    @State private var showSaveDialog = false
    @State private var refreshingConfig = false
    @State private var lastFetchTime: Date? = nil
    @State private var showConfigError = false
    @State private var configErrorMessage = ""

    var body: some View {
        networkListContainer
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
            .task { await initialServerLoad() }
            .modifier(BackButton(disabled: Binding.constant(false)) {
                handleBackButton()
            })
            .confirmationDialog(LocalizedStringKey(NSLocalizedString("net_save_servers_confirm", comment: "Save servers confirmation dialog")), isPresented: $showSaveDialog, titleVisibility: .visible) {
                saveConfirmationButtons
            }
            .sheet(item: $sheetItem) { item in
                switch item {
                case .showConditions:
                    UsageConditionsView(
                        currUserServers: $ss.servers.currUserServers,
                        userServers: $ss.servers.userServers
                    )
                    .modifier(ThemedBackground(grouped: true))
                }
            }
            .onAppear {
                lastFetchTime = RemoteConfigCache.lastFetchTime()
            }
            .alert(NSLocalizedString("net_error", comment: "Error alert title"), isPresented: $showConfigError) {
                Button(NSLocalizedString("net_ok", comment: "OK button")) {}
            } message: {
                Text(verbatim: configErrorMessage)
            }
            .popopxBranded()
    }

    // MARK: - POPOPX decomposed sub-views

    @ViewBuilder private var networkListContainer: some View {
        VStack {
            List {
                presetServersSection
                messagesAndFilesSection
                saveServersSection
                callsSection
                connectionStatusSection
            }
        }
    }

    @ViewBuilder private var presetServersSection: some View {
        let conditionsAction = m.conditions.conditionsAction
        let anyOperatorEnabled = ss.servers.userServers.contains(where: { $0.operator?.enabled ?? false })
        Section {
            ForEach(ss.servers.userServers.enumerated().map { $0 }, id: \.element.id) { idx, userOperatorServers in
                if let serverOperator = userOperatorServers.operator {
                    serverOperatorView(idx, serverOperator)
                } else {
                    EmptyView()
                }
            }

            if let conditionsAction = conditionsAction, anyOperatorEnabled {
                conditionsButton(conditionsAction)
            }
        } header: {
            Text(NSLocalizedString("net_preset_servers", comment: "Preset servers section header"))
                .font(pxSectionHeaderFont())
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            presetServersFooter(conditionsAction: conditionsAction, anyOperatorEnabled: anyOperatorEnabled)
        }
    }

    @ViewBuilder
    private func presetServersFooter(conditionsAction: UsageConditionsAction?, anyOperatorEnabled: Bool) -> some View {
        switch conditionsAction {
        case let .review(_, deadline, _):
            if let deadline = deadline, anyOperatorEnabled {
                Text(String(format: NSLocalizedString("net_conditions_deadline", comment: "Conditions acceptance deadline"), conditionsTimestamp(deadline)))
                    .foregroundColor(theme.colors.secondary)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var messagesAndFilesSection: some View {
        Section {
            yourServersNavigationLink
            advancedSettingsNavigationLink
        } header: {
            Text(NSLocalizedString("net_messages_files", comment: "Messages and files section header"))
                .font(pxSectionHeaderFont())
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        }
    }

    @ViewBuilder private var yourServersNavigationLink: some View {
        if let idx = ss.servers.userServers.firstIndex(where: { $0.operator == nil }) {
            NavigationLink {
                YourServersView(
                    userServers: $ss.servers.userServers,
                    serverErrors: $ss.servers.serverErrors,
                    serverWarnings: $ss.servers.serverWarnings,
                    operatorIndex: idx
                )
                .navigationTitle(NSLocalizedString("net_your_servers_title", comment: "Your servers navigation title"))
                .modifier(ThemedBackground(grouped: true))
            } label: {
                HStack {
                    Text(NSLocalizedString("net_your_servers", comment: "Your servers settings row"))

                    if ss.servers.userServers[idx] != ss.servers.currUserServers[idx] {
                        Spacer()
                        unsavedChangesIndicator()
                    }
                }
            }
            .accessibilityLabel(Text(verbatim: PXNetworkAndServersConfig.a11yYourServersRow))
        }
    }

    private var advancedSettingsNavigationLink: some View {
        NavigationLink {
            PXNetworkConfig()
                .navigationTitle(NSLocalizedString("net_advanced_settings_title", comment: "Advanced network settings navigation title"))
                .modifier(ThemedBackground(grouped: true))
        } label: {
            Text(NSLocalizedString("net_advanced_settings", comment: "Advanced network settings row"))
        }
        .accessibilityLabel(Text(verbatim: PXNetworkAndServersConfig.a11yAdvancedSettings))
    }

    @ViewBuilder private var saveServersSection: some View {
        Section {
            Button(NSLocalizedString("net_save_servers", comment: "Save servers button"), action: { saveServers($ss.servers.currUserServers, $ss.servers.userServers) })
                .disabled(!serversCanBeSaved(ss.servers.currUserServers, ss.servers.userServers, ss.servers.serverErrors))
                .accessibilityLabel(Text(verbatim: PXNetworkAndServersConfig.a11ySaveButton))
        } footer: {
            serversErrorAndWarningFooter
        }
    }

    @ViewBuilder private var serversErrorAndWarningFooter: some View {
        if let errStr = globalServersError(ss.servers.serverErrors) {
            ServersErrorView(errStr: errStr)
        } else if !ss.servers.serverErrors.isEmpty {
            ServersErrorView(errStr: NSLocalizedString("Errors in servers configuration.", comment: "servers error"))
        }
        if let warnStr = globalServersWarning(ss.servers.serverWarnings) {
            ServersWarningView(warnStr: warnStr)
        }
    }

    @ViewBuilder private var callsSection: some View {
        Section(header: Text(NSLocalizedString("net_calls_section", comment: "Calls section header")).font(pxSectionHeaderFont()).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
            NavigationLink {
                RTCServers()
                    .navigationTitle(NSLocalizedString("net_ice_servers_title", comment: "Your ICE servers navigation title"))
                    .modifier(ThemedBackground(grouped: true))
            } label: {
                Text(NSLocalizedString("net_webrtc_ice_servers", comment: "WebRTC ICE servers row"))
            }
            .accessibilityLabel(Text(verbatim: PXNetworkAndServersConfig.a11yIceServersRow))

            Button {
                refreshServerConfig()
            } label: {
                refreshConfigRowContent
            }
            .disabled(refreshingConfig)
            .accessibilityLabel(Text(verbatim: PXNetworkAndServersConfig.a11yRefreshConfig))
        }
    }

    @ViewBuilder private var refreshConfigRowContent: some View {
        HStack {
            Text(NSLocalizedString("net_refresh_config", comment: "Refresh server config button"))
            Spacer()
            if refreshingConfig {
                ProgressView()
            } else if let lastFetchTime = lastFetchTime {
                Text(formatFetchTime(lastFetchTime))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.7) : theme.colors.secondary)
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder private var connectionStatusSection: some View {
        Section(header: Text(NSLocalizedString("net_connection_section", comment: "Network connection section header")).font(pxSectionHeaderFont()).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
            HStack {
                Text(m.networkInfo.networkType.text)
                Spacer()
                Image(systemName: "circle.fill").foregroundColor(m.networkInfo.online ? QuantumColors.success : QuantumColors.error)
                    .accessibilityLabel(m.networkInfo.online ? NSLocalizedString("net_online", comment: "Online accessibility label") : NSLocalizedString("net_offline", comment: "Offline accessibility label"))
            }
            .accessibilityLabel(Text(verbatim: PXNetworkAndServersConfig.a11yConnectionStatus))
        }
    }

    @ViewBuilder private var saveConfirmationButtons: some View {
        Button(NSLocalizedString("net_save", comment: "Save button")) {
            saveServers($ss.servers.currUserServers, $ss.servers.userServers)
            dismiss()
        }
        Button(NSLocalizedString("net_exit_without_saving", comment: "Exit without saving button")) { dismiss() }
    }

    // MARK: - POPOPX server operator row

    private func serverOperatorView(_ operatorIndex: Int, _ serverOperator: ServerOperator) -> some View {
        NavigationLink() {
            OperatorView(
                currUserServers: $ss.servers.currUserServers,
                userServers: $ss.servers.userServers,
                serverErrors: $ss.servers.serverErrors,
                serverWarnings: $ss.servers.serverWarnings,
                operatorIndex: operatorIndex,
                useOperator: serverOperator.enabled
            )
            .navigationTitle(String(format: NSLocalizedString("%@ servers", comment: ""), serverOperator.tradeName))
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
        } label: {
            serverOperatorRowContent(operatorIndex: operatorIndex, serverOperator: serverOperator)
        }
    }

    @ViewBuilder
    private func serverOperatorRowContent(operatorIndex: Int, serverOperator: ServerOperator) -> some View {
        HStack {
            Image(serverOperator.logo(colorScheme))
                .resizable()
                .scaledToFit()
                .grayscale(serverOperator.enabled ? 0.0 : 1.0)
                .frame(width: PXNetworkAndServersConfig.operatorLogoSize, height: PXNetworkAndServersConfig.operatorLogoSize)
            Text(serverOperator.tradeName)
                .foregroundColor(serverOperator.enabled ? theme.colors.onBackground : theme.colors.secondary)

            if ss.servers.userServers[operatorIndex] != ss.servers.currUserServers[operatorIndex] {
                Spacer()
                unsavedChangesIndicator()
            }
        }
    }

    private func unsavedChangesIndicator() -> some View {
        Image(systemName: "pencil")
            .foregroundColor(theme.colors.secondary)
            .symbolRenderingMode(.monochrome)
            .frame(maxWidth: PXNetworkAndServersConfig.indicatorMaxSize, maxHeight: PXNetworkAndServersConfig.indicatorMaxSize, alignment: .center)
    }

    @ViewBuilder
    private func conditionsButton(_ conditionsAction: UsageConditionsAction) -> some View {
        let a11yId: String = {
            switch conditionsAction {
            case .review: return PXNetworkAndServersConfig.a11yConditionsReview
            case .accepted: return PXNetworkAndServersConfig.a11yConditionsAccepted
            }
        }()
        Button {
            sheetItem = .showConditions
        } label: {
            switch conditionsAction {
            case .review:
                Text(NSLocalizedString("net_review_conditions", comment: "Review conditions button"))
            case .accepted:
                Text(NSLocalizedString("net_accepted_conditions", comment: "Accepted conditions button"))
            }
        }
        .accessibilityLabel(Text(verbatim: a11yId))
    }

    // MARK: - POPOPX logic helpers

    private func handleBackButton() {
        if serversCanBeSaved(ss.servers.currUserServers, ss.servers.userServers, ss.servers.serverErrors) {
            showSaveDialog = true
        } else {
            dismiss()
        }
    }

    private func initialServerLoad() async {
        // this condition is needed to prevent re-setting the servers when exiting single server view
        if justOpened {
            do {
                ss.servers.currUserServers = try await getUserServers()
                ss.servers.userServers = ss.servers.currUserServers
                ss.servers.serverErrors = []
                ss.servers.serverWarnings = []
                validateServers_($ss.servers.userServers, $ss.servers.serverErrors, $ss.servers.serverWarnings)
            } catch let error {
                await MainActor.run {
                    showAlert(
                        NSLocalizedString("Error loading servers", comment: "alert title"),
                        message: responseError(error)
                    )
                }
            }
            if RemoteConfigCache.load() == nil {
                Task {
                    _ = try? await ConfigBotClient.shared.requestConfig()
                    await MainActor.run {
                        lastFetchTime = RemoteConfigCache.lastFetchTime()
                    }
                }
            }
            justOpened = false
        }
    }

    private func refreshServerConfig() {
        logger.info("PX: refreshing server config")
        refreshingConfig = true
        Task {
            do {
                _ = try await ConfigBotClient.shared.requestConfig()
                await MainActor.run {
                    lastFetchTime = RemoteConfigCache.lastFetchTime()
                    refreshingConfig = false
                }
            } catch {
                await MainActor.run {
                    configErrorMessage = responseError(error)
                    showConfigError = true
                    refreshingConfig = false
                }
            }
        }
    }

    private func formatFetchTime(_ date: Date) -> String {
        let vm = PXNetworkAndServersViewModel(chatModel: m, saveableSettings: ss)
        return vm.formatRelativeTime(date)
    }
}

// MARK: - UsageConditionsView

struct UsageConditionsView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var currUserServers: [UserOperatorServers]
    @Binding var userServers: [UserOperatorServers]

    var body: some View {
        conditionsContent
            .padding(.horizontal, PXNetworkAndServersConfig.conditionsHorizontalPadding)
            .frame(maxHeight: .infinity)
    }

    // MARK: - POPOPX decomposed sub-views

    @ViewBuilder private var conditionsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch ChatModel.shared.conditions.conditionsAction {

            case .none:
                regularConditionsHeader()
                    .padding(.top)
                    .padding(.top)
                ConditionsTextView()
                    .padding(.bottom)
                    .padding(.bottom)

            case let .review(operators, deadline, _):
                reviewConditionsContent(operators: operators, deadline: deadline)

            case let .accepted(operators):
                acceptedConditionsContent(operators: operators)
            }
        }
    }

    @ViewBuilder
    private func reviewConditionsContent(operators: [ServerOperator], deadline: Date?) -> some View {
        HStack {
            Text(NSLocalizedString("net_updated_conditions", comment: "Updated conditions title")).font(.largeTitle).bold()
        }
        .padding(.top)
        .padding(.top)

        Text(String(format: NSLocalizedString("net_conditions_for_operators", comment: "Conditions will be accepted for operators"), operators.map { $0.legalName_ }.joined(separator: ", ")))
        ConditionsTextView()
        VStack(spacing: PXNetworkAndServersConfig.conditionsReviewSpacing) {
            acceptConditionsButton(operators.map { $0.operatorId })
            if let deadline = deadline {
                Text(String(format: NSLocalizedString("net_conditions_auto_accept", comment: "Conditions auto-acceptance deadline"), conditionsTimestamp(deadline)))
                    .foregroundColor(theme.colors.secondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, PXNetworkAndServersConfig.conditionsDeadlineHorizontalPadding)
                conditionsDiffButton(.footnote)
            } else {
                conditionsDiffButton()
                    .padding(.top)
            }
        }
        .padding(.bottom)
        .padding(.bottom)
    }

    @ViewBuilder
    private func acceptedConditionsContent(operators: [ServerOperator]) -> some View {
        regularConditionsHeader()
            .padding(.top)
            .padding(.top)
        Text(String(format: NSLocalizedString("net_conditions_accepted_for", comment: "Conditions accepted for operators"), operators.map { $0.legalName_ }.joined(separator: ", ")))
        ConditionsTextView()
            .padding(.bottom)
            .padding(.bottom)
    }

    private func acceptConditionsButton(_ operatorIds: [Int64]) -> some View {
        Button {
            acceptForOperators(operatorIds)
        } label: {
            Text(NSLocalizedString("net_accept_conditions", comment: "Accept conditions button"))
        }
        .buttonStyle(OnboardingButtonStyle())
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXNetworkAndServersConfig.acceptButtonShadowOpacity) : .clear, radius: PXNetworkAndServersConfig.acceptButtonShadowRadius, x: 0, y: PXNetworkAndServersConfig.acceptButtonShadowY)
    }

    func acceptForOperators(_ operatorIds: [Int64]) {
        Task {
            do {
                let conditionsId = ChatModel.shared.conditions.currentConditions.conditionsId
                let r = try await acceptConditions(conditionsId: conditionsId, operatorIds: operatorIds)
                await MainActor.run {
                    ChatModel.shared.conditions = r
                    updateOperatorsConditionsAcceptance($currUserServers, r.serverOperators)
                    updateOperatorsConditionsAcceptance($userServers, r.serverOperators)
                    dismiss()
                }
            } catch let error {
                await MainActor.run {
                    showAlert(
                        NSLocalizedString("Error accepting conditions", comment: "alert title"),
                        message: responseError(error)
                    )
                }
            }
        }
    }

    @ViewBuilder private func conditionsDiffButton(_ font: Font? = nil) -> some View {
        let commit = ChatModel.shared.conditions.currentConditions.conditionsCommit
        if let commitUrl = URL(string: "https://popopxchat.com/conditions/\(commit)") {
            ExternalLink(destination: commitUrl) {
                HStack {
                    Text(NSLocalizedString("net_open_changes", comment: "Open changes link"))
                    Image(systemName: "arrow.up.right.circle")
                }
                .font(font)
            }
        }
    }
}

@MainActor
private func regularConditionsHeader() -> some View {
    HStack {
        Text(NSLocalizedString("net_conditions_of_use", comment: "Conditions of use title")).font(.largeTitle).bold()
        Spacer()
        conditionsLinkButton()
    }
}


func validateServers_(
    _ userServers: Binding<[UserOperatorServers]>,
    _ serverErrors: Binding<[UserServersError]>,
    _ serverWarnings: Binding<[UserServersWarning]>? = nil
) {
    let userServersToValidate = userServers.wrappedValue
    Task {
        do {
            let (errs, warns) = try await validateServers(userServers: userServersToValidate)
            await MainActor.run {
                serverErrors.wrappedValue = errs
                serverWarnings?.wrappedValue = warns
            }
        } catch let error {
            logger.error("validateServers error: \(responseError(error))")
        }
    }
}

func serversCanBeSaved(
    _ currUserServers: [UserOperatorServers],
    _ userServers: [UserOperatorServers],
    _ serverErrors: [UserServersError]
) -> Bool {
    return userServers != currUserServers && serverErrors.isEmpty
}

struct ServersErrorView: View {
    @EnvironmentObject var theme: AppTheme
    var errStr: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(QuantumColors.error)
            Text(errStr)
                .foregroundColor(theme.colors.secondary)
        }
    }
}

struct ServersWarningView: View {
    @EnvironmentObject var theme: AppTheme
    var warnStr: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(QuantumColors.warning)
            Text(warnStr)
                .foregroundColor(theme.colors.secondary)
        }
    }
}

func globalServersError(_ serverErrors: [UserServersError]) -> String? {
    for err in serverErrors {
        if let errStr = err.globalError {
            return errStr
        }
    }
    return nil
}

func globalServersWarning(_ serverWarnings: [UserServersWarning]) -> String? {
    for warn in serverWarnings {
        switch warn {
        case let .noChatRelays(user):
            let text = NSLocalizedString("No chat relays enabled.", comment: "servers warning")
            if let user = user {
                return String.localizedStringWithFormat(
                    NSLocalizedString("For chat profile %@:", comment: "servers warning"),
                    user.localDisplayName
                ) + " " + text
            } else { return text }
        case let .noNamesServers(user):
            let text = NSLocalizedString("No name servers enabled.", comment: "servers warning")
            if let user = user {
                return String.localizedStringWithFormat(
                    NSLocalizedString("For chat profile %@:", comment: "servers warning"),
                    user.localDisplayName
                ) + " " + text
            } else { return text }
        }
    }
    return nil
}

func bindingForChatRelays(_ userServers: Binding<[UserOperatorServers]>, _ opIndex: Int) -> Binding<[UserChatRelay]> {
    Binding(
        get: { userServers[opIndex].wrappedValue.chatRelays },
        set: { userServers[opIndex].wrappedValue.chatRelays = $0 }
    )
}

func globalSMPServersError(_ serverErrors: [UserServersError]) -> String? {
    for err in serverErrors {
        if let errStr = err.globalSMPError {
            return errStr
        }
    }
    return nil
}

func globalXFTPServersError(_ serverErrors: [UserServersError]) -> String? {
    for err in serverErrors {
        if let errStr = err.globalXFTPError {
            return errStr
        }
    }
    return nil
}

func findDuplicateHosts(_ serverErrors: [UserServersError]) -> Set<String> {
    let duplicateHostsList = serverErrors.compactMap { err in
        if case let .duplicateServer(_, _, duplicateHost) = err {
            return duplicateHost
        } else {
            return nil
        }
    }
    return Set(duplicateHostsList)
}

func findDuplicateRelayAddresses(_ serverErrors: [UserServersError]) -> Set<String> {
    Set(serverErrors.compactMap { err in
        if case let .duplicateChatRelayAddress(_, duplicateAddress) = err { return duplicateAddress }
        else { return nil }
    })
}


func saveServers(_ currUserServers: Binding<[UserOperatorServers]>, _ userServers: Binding<[UserOperatorServers]>) {
    let userServersToSave = userServers.wrappedValue
    Task {
        do {
            try await setUserServers(userServers: userServersToSave)
            // Get updated servers to learn new server ids (otherwise it messes up delete of newly added and saved servers)
            do {
                let updatedServers = try await getUserServers()
                let updatedOperators = try getServerOperatorsSync()
                await MainActor.run {
                    ChatModel.shared.conditions = updatedOperators
                    currUserServers.wrappedValue = updatedServers
                    userServers.wrappedValue = updatedServers
                }
            } catch let error {
                logger.error("saveServers getUserServers error: \(responseError(error))")
                await MainActor.run {
                    currUserServers.wrappedValue = userServersToSave
                }
            }
        } catch let error {
            logger.error("saveServers setUserServers error: \(responseError(error))")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error saving servers", comment: "alert title"),
                    message: responseError(error)
                )
            }
        }
    }
}

func updateOperatorsConditionsAcceptance(_ usvs: Binding<[UserOperatorServers]>, _ updatedOperators: [ServerOperator]) {
    for i in 0..<usvs.wrappedValue.count {
        if let updatedOperator = updatedOperators.first(where: { $0.operatorId == usvs.wrappedValue[i].operator?.operatorId }) {
            usvs.wrappedValue[i].operator?.conditionsAcceptance = updatedOperator.conditionsAcceptance
        }
    }
}

struct NetworkServersView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkAndServers()
    }
}

// MARK: - POPOPX
extension NetworkAndServers {
    var pxComponentTag: String { PXNetworkAndServersConfig.componentIdentifier }
    var pxA11yPresetId: String { PXNetworkAndServersConfig.a11yPresetServersSection }
    var pxA11yRefreshId: String { PXNetworkAndServersConfig.a11yRefreshConfig }

    func pxSectionHeaderFont() -> Font {
        isInDarkTheme() ? darkThemeHeaderFont() : .body
    }
}
