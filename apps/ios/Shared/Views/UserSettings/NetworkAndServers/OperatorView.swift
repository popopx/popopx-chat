//
//  OperatorView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 28.10.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import Ink

struct OperatorView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @EnvironmentObject var theme: AppTheme
    @Environment(\.editMode) private var editMode
    @Binding var currUserServers: [UserOperatorServers]
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    var operatorIndex: Int
    @State var useOperator: Bool
    @State private var useOperatorToggleReset: Bool = false
    @State private var showConditionsSheet: Bool = false
    @State private var selectedServer: String? = nil
    @State private var testing = false

    var body: some View {
        operatorView()
            .opacity(testing ? 0.4 : 1)
            .overlay {
                if testing {
                    ProgressView()
                        .scaleEffect(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .allowsHitTesting(!testing)
        .popopxBranded()
    }

    private func operatorView() -> some View {
        let duplicateHosts = findDuplicateHosts(serverErrors)
        let duplicateRelayAddresses = findDuplicateRelayAddresses(serverErrors)
        guard userServers.indices.contains(operatorIndex) else {
            return AnyView(
                VStack {
                    Text(NSLocalizedString("Server configuration has changed. Please go back and try again.", comment: ""))
                        .multilineTextAlignment(.center)
                        .padding()
                }
            )
        }
        return AnyView(VStack {
            List {
                Section {
                    infoViewLink()
                    useOperatorToggle()
                } header: {
                    Text(NSLocalizedString("Operator", comment: ""))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                } footer: {
                    if let errStr = globalServersError(serverErrors) {
                        ServersErrorView(errStr: errStr)
                    } else if let warnStr = globalServersWarning(serverWarnings) {
                        ServersWarningView(warnStr: warnStr)
                    } else {
                        switch (userServers[operatorIndex].operator_.conditionsAcceptance) {
                        case let .accepted(acceptedAt, _):
                            if let acceptedAt = acceptedAt {
                                Text(String.localizedStringWithFormat(NSLocalizedString("Conditions accepted on: %@.", comment: ""), conditionsTimestamp(acceptedAt)))
                                    .foregroundColor(theme.colors.secondary)
                            }
                        case let .required(deadline):
                            if userServers[operatorIndex].operator_.enabled, let deadline = deadline {
                                Text(String.localizedStringWithFormat(NSLocalizedString("Conditions will be accepted on: %@.", comment: ""), conditionsTimestamp(deadline)))
                                    .foregroundColor(theme.colors.secondary)
                            }
                        }
                    }
                }

                if userServers[operatorIndex].operator_.enabled {
                    if !userServers[operatorIndex].chatRelays.filter({ !$0.deleted }).isEmpty {
                        Section {
                            ForEach(bindingForChatRelays($userServers, operatorIndex)) { relay in
                                if !relay.wrappedValue.deleted {
                                    PXChatRelayLink(
                                        userServers: $userServers,
                                        serverErrors: $serverErrors,
                                        serverWarnings: $serverWarnings,
                                        relay: relay,
                                        duplicateRelayAddresses: duplicateRelayAddresses,
                                        backLabel: "\(userServers[operatorIndex].operator_.tradeName) servers",
                                        selectedServer: $selectedServer
                                    )
                                } else { EmptyView() }
                            }
                        } header: {
                            Text(NSLocalizedString("Chat relays", comment: "")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        } footer: {
                            Text(NSLocalizedString("Chat relays forward messages in channels you create.", comment: "")).foregroundColor(theme.colors.secondary)
                        }
                    }

                    if !userServers[operatorIndex].smpServers.filter({ !$0.deleted }).isEmpty {
                        Section {
                            Toggle(NSLocalizedString("To receive", comment: ""), isOn: $userServers[operatorIndex].operator_.smpRoles.storage)
                                .onChange(of: userServers[operatorIndex].operator_.smpRoles.storage) {_, _ in
                                    validateServers_($userServers, $serverErrors, $serverWarnings)
                                }
                            Toggle(NSLocalizedString("For private routing", comment: ""), isOn: $userServers[operatorIndex].operator_.smpRoles.proxy)
                                .onChange(of: userServers[operatorIndex].operator_.smpRoles.proxy) {_, _ in
                                    validateServers_($userServers, $serverErrors, $serverWarnings)
                                }
                        } header: {
                            Text(NSLocalizedString("Use for messages", comment: ""))
                                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        } footer: {
                            if let errStr = globalSMPServersError(serverErrors) {
                                ServersErrorView(errStr: errStr)
                            }
                        }
                    }

                    // Preset servers can't be deleted
                    if !userServers[operatorIndex].smpServers.filter({ $0.preset }).isEmpty {
                        Section {
                            ForEach($userServers[operatorIndex].smpServers) { srv in
                                if srv.wrappedValue.preset {
                                    ProtocolServerViewLink(
                                        userServers: $userServers,
                                        serverErrors: $serverErrors,
                                        serverWarnings: $serverWarnings,
                                        duplicateHosts: duplicateHosts,
                                        server: srv,
                                        serverProtocol: .smp,
                                        backLabel: "\(userServers[operatorIndex].operator_.tradeName) servers",
                                        selectedServer: $selectedServer
                                    )
                                } else {
                                    EmptyView()
                                }
                            }
                        } header: {
                            Text(NSLocalizedString("Message servers", comment: ""))
                                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        } footer: {
                            if let errStr = globalSMPServersError(serverErrors) {
                                ServersErrorView(errStr: errStr)
                            } else {
                                Text(String.localizedStringWithFormat(NSLocalizedString("The servers for new connections of your current chat profile **%@**.", comment: ""), ChatModel.shared.currentUser?.displayName ?? ""))
                                    .foregroundColor(theme.colors.secondary)
                                    .lineLimit(10)
                            }
                        }
                    }

                    if !userServers[operatorIndex].smpServers.filter({ !$0.preset && !$0.deleted }).isEmpty {
                        Section {
                            ForEach($userServers[operatorIndex].smpServers) { srv in
                                if !srv.wrappedValue.preset && !srv.wrappedValue.deleted {
                                    ProtocolServerViewLink(
                                        userServers: $userServers,
                                        serverErrors: $serverErrors,
                                        serverWarnings: $serverWarnings,
                                        duplicateHosts: duplicateHosts,
                                        server: srv,
                                        serverProtocol: .smp,
                                        backLabel: "\(userServers[operatorIndex].operator_.tradeName) servers",
                                        selectedServer: $selectedServer
                                    )
                                } else {
                                    EmptyView()
                                }
                            }
                            .onDelete { indexSet in
                                deleteSMPServer($userServers, operatorIndex, indexSet)
                                validateServers_($userServers, $serverErrors, $serverWarnings)
                            }
                        } header: {
                            Text(NSLocalizedString("Added message servers", comment: ""))
                                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        }
                    }

                    if !userServers[operatorIndex].xftpServers.filter({ !$0.deleted }).isEmpty {
                        Section {
                            Toggle(NSLocalizedString("To send", comment: ""), isOn: $userServers[operatorIndex].operator_.xftpRoles.storage)
                                .onChange(of: userServers[operatorIndex].operator_.xftpRoles.storage) {_, _ in
                                    validateServers_($userServers, $serverErrors, $serverWarnings)
                                }
                        } header: {
                            Text(NSLocalizedString("Use for files", comment: ""))
                                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        } footer: {
                            if let errStr = globalXFTPServersError(serverErrors) {
                                ServersErrorView(errStr: errStr)
                            }
                        }
                    }

                    // Preset servers can't be deleted
                    if !userServers[operatorIndex].xftpServers.filter({ $0.preset }).isEmpty {
                        Section {
                            ForEach($userServers[operatorIndex].xftpServers) { srv in
                                if srv.wrappedValue.preset {
                                    ProtocolServerViewLink(
                                        userServers: $userServers,
                                        serverErrors: $serverErrors,
                                        serverWarnings: $serverWarnings,
                                        duplicateHosts: duplicateHosts,
                                        server: srv,
                                        serverProtocol: .xftp,
                                        backLabel: "\(userServers[operatorIndex].operator_.tradeName) servers",
                                        selectedServer: $selectedServer
                                    )
                                } else {
                                    EmptyView()
                                }
                            }
                        } header: {
                            Text(NSLocalizedString("Media & file servers", comment: ""))
                                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        } footer: {
                            if let errStr = globalXFTPServersError(serverErrors) {
                                ServersErrorView(errStr: errStr)
                            } else {
                                Text(String.localizedStringWithFormat(NSLocalizedString("The servers for new files of your current chat profile **%@**.", comment: ""), ChatModel.shared.currentUser?.displayName ?? ""))
                                    .foregroundColor(theme.colors.secondary)
                                    .lineLimit(10)
                            }
                        }
                    }

                    if !userServers[operatorIndex].xftpServers.filter({ !$0.preset && !$0.deleted }).isEmpty {
                        Section {
                            ForEach($userServers[operatorIndex].xftpServers) { srv in
                                if !srv.wrappedValue.preset && !srv.wrappedValue.deleted {
                                    ProtocolServerViewLink(
                                        userServers: $userServers,
                                        serverErrors: $serverErrors,
                                        serverWarnings: $serverWarnings,
                                        duplicateHosts: duplicateHosts,
                                        server: srv,
                                        serverProtocol: .xftp,
                                        backLabel: "\(userServers[operatorIndex].operator_.tradeName) servers",
                                        selectedServer: $selectedServer
                                    )
                                } else {
                                    EmptyView()
                                }
                            }
                            .onDelete { indexSet in
                                deleteXFTPServer($userServers, operatorIndex, indexSet)
                                validateServers_($userServers, $serverErrors, $serverWarnings)
                            }
                        } header: {
                            Text(NSLocalizedString("Added media & file servers", comment: ""))
                                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        }
                    }

                    Section {
                        TestServersButton(
                            smpServers: $userServers[operatorIndex].smpServers,
                            xftpServers: $userServers[operatorIndex].xftpServers,
                            chatRelays: $userServers[operatorIndex].chatRelays,
                            testing: $testing
                        )
                    }
                }
            }
        }
        .toolbar {
            if (
                !userServers[operatorIndex].smpServers.filter({ !$0.preset && !$0.deleted }).isEmpty ||
                !userServers[operatorIndex].xftpServers.filter({ !$0.preset && !$0.deleted }).isEmpty
            ) {
                EditButton()
            }
        }
        .sheet(isPresented: $showConditionsSheet, onDismiss: onUseToggleSheetDismissed) {
            SingleOperatorUsageConditionsView(
                currUserServers: $currUserServers,
                userServers: $userServers,
                serverErrors: $serverErrors,
                serverWarnings: $serverWarnings,
                operatorIndex: operatorIndex
            )
            .modifier(ThemedBackground(grouped: true))
        }
        )
    }

    private func infoViewLink() -> some View {
        NavigationLink() {
            OperatorInfoView(serverOperator: userServers[operatorIndex].operator_)
                .navigationTitle(NSLocalizedString("Network operator", comment: ""))
                .modifier(ThemedBackground(grouped: true))
                .navigationBarTitleDisplayMode(.large)
        } label: {
            Image(userServers[operatorIndex].operator_.largeLogo(colorScheme))
                .resizable()
                .scaledToFit()
                .grayscale(userServers[operatorIndex].operator_.enabled ? 0.0 : 1.0)
                .frame(height: 40)
        }
    }

    private func useOperatorToggle() -> some View {
        Toggle(NSLocalizedString("Use servers", comment: ""), isOn: $useOperator)
            .onChange(of: useOperator) {_,  useOperatorToggle in
                if useOperatorToggleReset {
                    useOperatorToggleReset = false
                } else if useOperatorToggle {
                    switch userServers[operatorIndex].operator_.conditionsAcceptance {
                    case .accepted:
                        userServers[operatorIndex].operator_.enabled = true
                        validateServers_($userServers, $serverErrors, $serverWarnings)
                    case let .required(deadline):
                        if deadline == nil {
                            showConditionsSheet = true
                        } else {
                            userServers[operatorIndex].operator_.enabled = true
                            validateServers_($userServers, $serverErrors, $serverWarnings)
                        }
                    }
                } else {
                    userServers[operatorIndex].operator_.enabled = false
                    validateServers_($userServers, $serverErrors, $serverWarnings)
                }
            }
    }

    private func onUseToggleSheetDismissed() {
        if useOperator && !userServers[operatorIndex].operator_.conditionsAcceptance.usageAllowed {
            useOperatorToggleReset = true
            useOperator = false
        }
    }
}

func conditionsTimestamp(_ date: Date) -> String {
    let localDateFormatter = DateFormatter()
    localDateFormatter.dateStyle = .medium
    localDateFormatter.timeStyle = .none
    return localDateFormatter.string(from: date)
}

struct OperatorInfoView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var serverOperator: ServerOperator

    var body: some View {
        VStack {
            List {
                Section {
                    VStack(alignment: .leading) {
                        Image(serverOperator.largeLogo(colorScheme))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                        if let legalName = serverOperator.legalName {
                            Text(legalName)
                        }
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(serverOperator.info.description, id: \.self) { d in
                            Text(d)
                        }
                    }
                    ExternalLink(destination: serverOperator.info.website) {
                        Text(serverOperator.info.website.absoluteString)
                    }
                }
                if let selfhost = serverOperator.info.selfhost {
                    Section {
                        ExternalLink(destination: selfhost.link) {
                            Text(selfhost.text)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        }
    }
}

struct ConditionsTextView: View {
    @EnvironmentObject var theme: AppTheme
    @State private var conditionsData: (UsageConditions, String?, UsageConditions?)?
    @State private var failedToLoad: Bool = false
    @State private var conditionsHTML: String? = nil
    @State private var errorMessage: String? = nil
    @State private var reloadTrigger = 0

    let defaultConditionsLink = "https://popopxchat.com/conditions"

    var body: some View {
        viewBody()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: reloadTrigger) {
                do {
                    logger.debug("ConditionsTextView: Starting getUsageConditions()")
                    let conditions = try await getUsageConditions()
                    logger.debug("ConditionsTextView: getUsageConditions() succeeded")
                    let conditionsText = conditions.1
                    logger.debug("ConditionsTextView: conditionsText is nil? \(conditionsText == nil), length = \(conditionsText?.count ?? 0)")

                    let parentLink =  "https://popopxchat.com/conditions/\(conditions.0.conditionsCommit)"
                    let preparedText: String?

                    if let conditionsText {
                        logger.debug("ConditionsTextView: About to call prepareMarkdown")
                        let prepared = prepareMarkdown(conditionsText.trimmingCharacters(in: .whitespacesAndNewlines), parentLink)
                        logger.debug("ConditionsTextView: prepareMarkdown returned, length = \(prepared.count)")

                        logger.debug("ConditionsTextView: About to call MarkdownParser")
                        let html = MarkdownParser().html(from: prepared)
                        logger.debug("ConditionsTextView: MarkdownParser returned, HTML length = \(html.count)")

                        conditionsHTML = html
                        preparedText = prepared
                    } else {
                        logger.warning("ConditionsTextView: conditionsText is nil, will show fallback link")
                        preparedText = nil
                    }

                    logger.debug("ConditionsTextView: Setting conditionsData")
                    conditionsData = (conditions.0, preparedText, conditions.2)
                    logger.debug("ConditionsTextView: conditionsData set successfully")
                } catch let error {
                    let errorMsg = responseError(error)
                    logger.error("ConditionsTextView getUsageConditions error: \(errorMsg)")
                    errorMessage = errorMsg
                    failedToLoad = true
                }
            }
    }

    // TODO [TODO-FEATURE: medium] Diff rendering for conditions changes
    @ViewBuilder private func viewBody() -> some View {
        if let (_, _, _) = conditionsData {
            if let conditionsHTML {
                ConditionsWebView(html: conditionsHTML)
                    .padding(6)
                    .glassBackground(cornerRadius: 10)
            } else {
                let conditionsLink = "https://popopxchat.com/conditions"
                conditionsLinkView(conditionsLink, errorMessage: nil)
            }
        } else if failedToLoad {
            conditionsLinkView(defaultConditionsLink, errorMessage: errorMessage)
        } else {
            ProgressView()
                .scaleEffect(2)
        }
    }

    private func conditionsLinkView(_ conditionsLink: String, errorMessage: String?) -> some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(LinearGradient(
                    colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .padding(.top, 20)

            Text(NSLocalizedString("Unable to load conditions of use", comment: "Conditions load error title"))
                .font(.headline)
                .foregroundColor(QuantumColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("The conditions text is temporarily unavailable. You can review them via the link below, or try again.", comment: "Conditions load error message"))
                .font(.callout)
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if let url = URL(string: conditionsLink) {
                ExternalLink(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text(conditionsLink)
                    }
                    .font(.callout)
                    .foregroundColor(QuantumColors.accent)
                }
                .padding(.top, 4)
            }

            Button {
                retryLoadConditions()
            } label: {
                Text(NSLocalizedString("Try Again", comment: "Retry loading conditions"))
                    .fontWeight(.semibold)
            }
            .buttonStyle(QuantumButtonStyle(primary: true))
            .frame(maxWidth: 200)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func retryLoadConditions() {
        failedToLoad = false
        errorMessage = nil
        conditionsData = nil
        conditionsHTML = nil
        reloadTrigger += 1
    }

    private static let localLinkRegex = (try? NSRegularExpression(pattern: "\\[([^\\(]*)\\]\\(#.*?\\)")) ?? NSRegularExpression()
    private static let h1Regex = (try? NSRegularExpression(pattern: "^# ", options: .anchorsMatchLines)) ?? NSRegularExpression()

    private func prepareMarkdown(_ text: String, _ parentLink: String) -> String {
        var text = Self.localLinkRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "$1")
        text = Self.h1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "")
        return text
            .replacingOccurrences(of: "](/", with: "](\(parentLink)/")
            .replacingOccurrences(of: "](./", with: "](\(parentLink)/")
    }
}

struct SingleOperatorUsageConditionsView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var currUserServers: [UserOperatorServers]
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    var operatorIndex: Int

    var body: some View {
        viewBody()
    }

    @ViewBuilder private func viewBody() -> some View {
        if !userServers.indices.contains(operatorIndex) {
            VStack {
                Text(NSLocalizedString("Server configuration has changed. Please go back and try again.", comment: ""))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        } else {
            let operatorsWithConditionsAccepted = ChatModel.shared.conditions.serverOperators.filter { $0.conditionsAcceptance.conditionsAccepted }
            if case .accepted = userServers[operatorIndex].operator_.conditionsAcceptance {

                // In current UI implementation this branch doesn't get shown - as conditions can't be opened from inside operator once accepted
                VStack(alignment: .leading, spacing: 20) {
                    viewHeader()
                    ConditionsTextView()
                }
                .padding(.bottom)
                .padding(.bottom)
                .padding(.horizontal)
                .frame(maxHeight: .infinity)

            } else if !operatorsWithConditionsAccepted.isEmpty {

                NavigationStack {
                    VStack(alignment: .leading, spacing: 20) {
                        viewHeader()
                        Text(String.localizedStringWithFormat(NSLocalizedString("Conditions are already accepted for these operator(s): **%@**.", comment: ""), operatorsWithConditionsAccepted.map { $0.legalName_ }.joined(separator: ", ")))
                        Text(String.localizedStringWithFormat(NSLocalizedString("The same conditions will apply to operator **%@**.", comment: ""), userServers[operatorIndex].operator_.legalName_))
                        conditionsAppliedToOtherOperatorsText()
                        Spacer()

                        acceptConditionsButton()
                        usageConditionsNavLinkButton()
                    }
                    .padding(.bottom)
                    .padding(.bottom)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity)
                }

            } else {

                VStack(alignment: .leading, spacing: 20) {
                    viewHeader()
                    Text(String.localizedStringWithFormat(NSLocalizedString("To use the servers of **%@**, accept conditions of use.", comment: ""), userServers[operatorIndex].operator_.legalName_))
                    conditionsAppliedToOtherOperatorsText()
                    ConditionsTextView()
                    acceptConditionsButton()
                        .padding(.bottom)
                        .padding(.bottom)
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)

            }
        }
    }

    private func viewHeader() -> some View {
        HStack {
            Text(String.localizedStringWithFormat(NSLocalizedString("Use %@", comment: "operator trade name"), userServers[operatorIndex].operator_.tradeName)).font(.largeTitle).bold()
            Spacer()
            conditionsLinkButton()
        }
        .padding(.top)
        .padding(.top)
    }

    @ViewBuilder private func conditionsAppliedToOtherOperatorsText() -> some View {
        let otherOperatorsToApply = ChatModel.shared.conditions.serverOperators.filter {
            $0.enabled &&
            !$0.conditionsAcceptance.conditionsAccepted &&
            $0.operatorId != userServers[operatorIndex].operator_.operatorId
        }
        if !otherOperatorsToApply.isEmpty {
            Text(String.localizedStringWithFormat(NSLocalizedString("These conditions will also apply for: **%@**.", comment: ""), otherOperatorsToApply.map { $0.legalName_ }.joined(separator: ", ")))
        }
    }
    
    private func acceptConditionsButton() -> some View {
        let operatorIds = ChatModel.shared.conditions.serverOperators
            .filter {
                $0.operatorId == userServers[operatorIndex].operator_.operatorId || // Opened operator
                ($0.enabled && !$0.conditionsAcceptance.conditionsAccepted) // Other enabled operators with conditions not accepted
            }
            .map { $0.operatorId }
        logger.debug("acceptConditionsButton: operatorIds=\(operatorIds), conditionsId=\(ChatModel.shared.conditions.currentConditions.conditionsId)")
        return Button {
            Task {
                await acceptForOperators(operatorIds, operatorIndex)
            }
        } label: {
            Text(NSLocalizedString("Accept conditions", comment: ""))
        }
        .buttonStyle(QuantumButtonStyle(primary: true))
        .disabled(operatorIds.isEmpty)
    }

    func acceptForOperators(_ operatorIds: [Int64], _ operatorIndexToEnable: Int) async {
        logger.debug("acceptForOperators CALLED with operatorIds=\(operatorIds), operatorIndex=\(operatorIndexToEnable)")
        do {
            var resolvedOperatorIds = operatorIds
            logger.debug("acceptForOperators START: initial operatorIds=\(operatorIds), operatorIndex=\(operatorIndexToEnable)")
            logger.debug("acceptForOperators: current conditions - serverOperators.count=\(ChatModel.shared.conditions.serverOperators.count), conditionsId=\(ChatModel.shared.conditions.currentConditions.conditionsId)")

            if ChatModel.shared.conditions.serverOperators.isEmpty || ChatModel.shared.conditions.currentConditions.conditionsId == 0 {
                logger.debug("acceptForOperators: Conditions not loaded (operators empty or conditionsId=0), reloading from server...")

                var loadedConditions: ServerOperatorConditions? = nil

                for attempt in 1...5 {
                    do {
                        logger.debug("acceptForOperators: Attempt \(attempt)/5 to load conditions from server")
                        let conditions = try await apiGetServerOperators()
                        logger.debug("acceptForOperators: Load attempt \(attempt) succeeded - conditionsId=\(conditions.currentConditions.conditionsId), operators count=\(conditions.serverOperators.count)")

                        if conditions.currentConditions.conditionsId > 0 && !conditions.serverOperators.isEmpty {
                            loadedConditions = conditions
                            logger.debug("acceptForOperators: Got valid conditionsId=\(conditions.currentConditions.conditionsId) with \(conditions.serverOperators.count) operators, breaking retry loop")
                            break
                        } else {
                            logger.warning("acceptForOperators: Attempt \(attempt) returned invalid data - conditionsId=\(conditions.currentConditions.conditionsId), operators count=\(conditions.serverOperators.count)")
                            try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                        }
                    } catch let error {
                        logger.warning("acceptForOperators: Attempt \(attempt) failed: \(responseError(error))")
                        if attempt < 5 {
                            logger.debug("acceptForOperators: Waiting 1 second before retry...")
                            try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                        }
                    }
                }

                guard let conditions = loadedConditions else {
                    logger.error("acceptForOperators: FAILED to load conditions after 5 attempts")
                    logger.error("acceptForOperators: This likely means the Haskell core is not responding or database is corrupted")
                    throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_failed_load_protocol_info", comment: "Error when protocol info fails to load")))
                }

                logger.debug("acceptForOperators: Successfully loaded conditions with valid ID=\(conditions.currentConditions.conditionsId)")
                await MainActor.run {
                    ChatModel.shared.conditions = conditions
                }
            } else {
                logger.debug("acceptForOperators: Conditions already loaded with valid ID=\(ChatModel.shared.conditions.currentConditions.conditionsId), skipping reload")
            }

            let conditionsId = ChatModel.shared.conditions.currentConditions.conditionsId
            logger.debug("acceptForOperators: Final validation - conditionsId=\(conditionsId), resolvedOperatorIds count=\(resolvedOperatorIds.count)")

            if resolvedOperatorIds.isEmpty {
                logger.debug("acceptForOperators: operatorIds is empty, applying fallback logic")
                resolvedOperatorIds = ChatModel.shared.conditions.serverOperators
                    .filter { $0.enabled }
                    .map { $0.operatorId }
                logger.debug("acceptForOperators: fallback operatorIds=\(resolvedOperatorIds)")
            }

            guard conditionsId > 0 else {
                logger.error("acceptForOperators: BLOCKED - Invalid conditionsId=\(conditionsId). Cannot proceed without valid protocol ID.")
                throw ChatError.error(errorType: ChatErrorType.commandError(message: String(format: NSLocalizedString("error_invalid_conditions_id_detail", comment: "Error when conditions ID is invalid with detail"), conditionsId)))
            }

            guard !resolvedOperatorIds.isEmpty else {
                logger.error("acceptForOperators: BLOCKED - Empty operatorIds after fallback")
                throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_no_operators_for_conditions", comment: "Error when no operators specified for conditions")))
            }

            logger.debug("acceptForOperators: All validations passed, calling acceptConditions API - conditionsId=\(conditionsId), operatorIds=\(resolvedOperatorIds)")
            let r = try await acceptConditions(conditionsId: conditionsId, operatorIds: resolvedOperatorIds)
            logger.debug("acceptForOperators: acceptConditions API call succeeded, updating UI")
            await MainActor.run {
                ChatModel.shared.conditions = r
                updateOperatorsConditionsAcceptance($currUserServers, r.serverOperators)
                updateOperatorsConditionsAcceptance($userServers, r.serverOperators)
                if userServers.indices.contains(operatorIndexToEnable) {
                    userServers[operatorIndexToEnable].operator?.enabled = true
                }
                validateServers_($userServers, $serverErrors, $serverWarnings)
                dismiss()
            }
        } catch let error {
            let errorMsg = responseError(error)
            logger.error("acceptForOperators FAILED with error: \(errorMsg)")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error accepting conditions", comment: "alert title"),
                    message: errorMsg
                )
            }
        }
    }

    private func usageConditionsNavLinkButton() -> some View {
        NavigationLink(NSLocalizedString("View conditions", comment: "")) {
            ConditionsTextView()
                .padding()
                .navigationTitle(NSLocalizedString("Conditions of use", comment: ""))
                .navigationBarTitleDisplayMode(.large)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing, content: conditionsLinkButton) }
                .modifier(ThemedBackground(grouped: true))
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

@MainActor
func conditionsLinkButton() -> some View {
    let commit = ChatModel.shared.conditions.currentConditions.conditionsCommit
    let mdUrl = URL(string: "https://popopxchat.com/conditions") ?? conditionsURL
    return Menu {
        ExternalLink(destination: mdUrl) {
            Label(NSLocalizedString("Open conditions", comment: ""), systemImage: "doc")
        }
        if let commitUrl = URL(string: "https://popopxchat.com/conditions/\(commit)") {
            ExternalLink(destination: commitUrl) {
                Label(NSLocalizedString("Open changes", comment: ""), systemImage: "ellipsis")
            }
        }
    } label: {
        Image(systemName: "arrow.up.right.circle")
            .resizable()
            .scaledToFit()
            .frame(width: 20)
            .padding(2)
            .contentShape(Circle())
    }
}

#Preview {
    OperatorView(
        currUserServers: Binding.constant([UserOperatorServers.sampleData1, UserOperatorServers.sampleDataNilOperator]),
        userServers: Binding.constant([UserOperatorServers.sampleData1, UserOperatorServers.sampleDataNilOperator]),
        serverErrors: Binding.constant([]),
        serverWarnings: Binding.constant([]),
        operatorIndex: 0,
        useOperator: ServerOperator.sampleData1.enabled
    )
    .previewEnvironment()
}
