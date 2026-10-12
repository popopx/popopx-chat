//
//  PXProtocolServersView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 15/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

private let howToUrl: URL = URL(string: "https://popopxchat.com/docs/server.html") ?? URL(fileURLWithPath: NSTemporaryDirectory())

// MARK: - POPOPX Configuration
private enum PXProtocolServersConfig {
    static let testingOverlayOpacity: Double = 0.4
    static let scaleEffect: CGFloat = 2
    static let statusIconWidth: CGFloat = 16
    static let statusIconTrailingPadding: CGFloat = 4
    static let footerLineLimit: Int = 10
    static let buttonShadowRadius: CGFloat = 8
    static let buttonShadowY: CGFloat = 4
    static let buttonShadowOpacity: Double = 0.15
    static let componentIdentifier: String = "PX_YOUR_SERVERS_VIEW"
    static let linkComponentIdentifier: String = "PX_PROTOCOL_SERVER_VIEW_LINK"
    static let a11yChatRelaysSection: String = "px_proto_chat_relays"
    static let a11yMessageServersSection: String = "px_proto_message_servers"
    static let a11yFileServersSection: String = "px_proto_file_servers"
    static let a11yAddServer: String = "px_proto_add_server"
    static let a11yHowTo: String = "px_proto_how_to"
    static let a11yTestServers: String = "px_proto_test_servers"
    static let a11yInvalidServer: String = "px_proto_invalid_server"
}

// MARK: - POPOPX View Model
@MainActor
private struct PXProtocolServersViewModel {
    let userServers: [UserOperatorServers]
    let operatorIndex: Int

    var activeChatRelays: [UserChatRelay] {
        userServers[operatorIndex].chatRelays.filter { !$0.deleted }
    }

    var activeSMPServers: [UserServer] {
        userServers[operatorIndex].smpServers.filter { !$0.deleted }
    }

    var activeXFTPServers: [UserServer] {
        userServers[operatorIndex].xftpServers.filter { !$0.deleted }
    }

    var hasActiveChatRelays: Bool { !activeChatRelays.isEmpty }
    var hasActiveSMPServers: Bool { !activeSMPServers.isEmpty }
    var hasActiveXFTPServers: Bool { !activeXFTPServers.isEmpty }

    var hasAnyActiveServers: Bool {
        hasActiveSMPServers || hasActiveXFTPServers || hasActiveChatRelays
    }
}

struct YourServersView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject private var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.editMode) private var editMode
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    var operatorIndex: Int
    @State private var selectedServer: String? = nil
    @State private var showAddServer = false
    @State private var newServerNavLinkActive = false
    @State private var newChatRelayNavLinkActive = false
    @State private var showScanProtoServer = false
    @State private var testing = false
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showServerUpgrade = false

    var body: some View {
        yourServersView()
            .opacity(testing ? PXProtocolServersConfig.testingOverlayOpacity : 1)
            .overlay {
                if testing {
                    ProgressView()
                        .scaleEffect(PXProtocolServersConfig.scaleEffect)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .allowsHitTesting(!testing)
        .popopxBranded()
    }

    private func yourServersView() -> some View {
        let duplicateHosts = findDuplicateHosts(serverErrors)
        let duplicateRelayAddresses = findDuplicateRelayAddresses(serverErrors)
        return List {
            if !userServers[operatorIndex].chatRelays.filter({ !$0.deleted }).isEmpty {
                chatRelaysSection(duplicateRelayAddresses: duplicateRelayAddresses)
            }

            if !userServers[operatorIndex].smpServers.filter({ !$0.deleted }).isEmpty {
                smpServersSection(duplicateHosts: duplicateHosts)
            }

            if !userServers[operatorIndex].xftpServers.filter({ !$0.deleted }).isEmpty {
                xftpServersSection(duplicateHosts: duplicateHosts)
            }

            addServerSection

            testAndHelpSection
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .toolbar {
            if PXProtocolServersViewModel(userServers: userServers, operatorIndex: operatorIndex).hasAnyActiveServers {
                EditButton()
            }
        }
        .confirmationDialog(NSLocalizedString("settings_add_server_dialog", comment: "Add server dialog title"), isPresented: $showAddServer, titleVisibility: .hidden) {
            addServerDialogButtons
        }
        .sheet(isPresented: $showServerUpgrade) {
            NavigationStack {
                SubscriptionView()
                    .navigationTitle(NSLocalizedString("settings_premium_required_title", comment: "Premium required navigation title"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showScanProtoServer) {
            ScanProtocolServer(
                userServers: $userServers,
                serverErrors: $serverErrors,
                serverWarnings: $serverWarnings
            )
            .modifier(ThemedBackground(grouped: true))
        }
    }

    // MARK: - POPOPX decomposed sections

    @ViewBuilder
    private func chatRelaysSection(duplicateRelayAddresses: Set<String>) -> some View {
        Section {
            ForEach(bindingForChatRelays($userServers, operatorIndex)) { relay in
                if !relay.wrappedValue.deleted {
                    PXChatRelayLink(
                        userServers: $userServers,
                        serverErrors: $serverErrors,
                        serverWarnings: $serverWarnings,
                        relay: relay,
                        duplicateRelayAddresses: duplicateRelayAddresses,
                        backLabel: NSLocalizedString("settings_your_servers_label", comment: "Your servers back label"),
                        selectedServer: $selectedServer
                    )
                } else { EmptyView() }
            }
            .onDelete { indexSet in
                deleteChatRelay($userServers, operatorIndex, indexSet)
                validateServers_($userServers, $serverErrors, $serverWarnings)
            }
        } header: {
            Text(NSLocalizedString("settings_chat_relays_header", comment: "Chat relays section header"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            Text(NSLocalizedString("settings_chat_relays_forward_desc", comment: "Chat relays forward messages description"))
                .foregroundColor(theme.colors.secondary)
        }
    }

    @ViewBuilder
    private func smpServersSection(duplicateHosts: Set<String>) -> some View {
        Section {
            ForEach($userServers[operatorIndex].smpServers) { srv in
                if !srv.wrappedValue.deleted {
                    ProtocolServerViewLink(
                        userServers: $userServers,
                        serverErrors: $serverErrors,
                        serverWarnings: $serverWarnings,
                        duplicateHosts: duplicateHosts,
                        server: srv,
                        serverProtocol: .smp,
                        backLabel: NSLocalizedString("settings_your_servers_label", comment: "Your servers back label"),
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
            Text(NSLocalizedString("settings_message_servers", comment: "Message servers header"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            smpSectionFooter
        }
    }

    @ViewBuilder private var smpSectionFooter: some View {
        if let errStr = globalSMPServersError(serverErrors) {
            ServersErrorView(errStr: errStr)
        } else {
            Text(String(format: NSLocalizedString("settings_smp_servers_for_profile", comment: "SMP servers for profile description"), m.currentUser?.displayName ?? ""))
                .foregroundColor(theme.colors.secondary)
                .lineLimit(PXProtocolServersConfig.footerLineLimit)
        }
    }

    @ViewBuilder
    private func xftpServersSection(duplicateHosts: Set<String>) -> some View {
        Section {
            ForEach($userServers[operatorIndex].xftpServers) { srv in
                if !srv.wrappedValue.deleted {
                    ProtocolServerViewLink(
                        userServers: $userServers,
                        serverErrors: $serverErrors,
                        serverWarnings: $serverWarnings,
                        duplicateHosts: duplicateHosts,
                        server: srv,
                        serverProtocol: .xftp,
                        backLabel: NSLocalizedString("settings_your_servers_label", comment: "Your servers back label"),
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
            Text(NSLocalizedString("settings_media_file_servers", comment: "Media & file servers header"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
        } footer: {
            xftpSectionFooter
        }
    }

    @ViewBuilder private var xftpSectionFooter: some View {
        if let errStr = globalXFTPServersError(serverErrors) {
            ServersErrorView(errStr: errStr)
        } else {
            Text(String(format: NSLocalizedString("settings_xftp_servers_for_profile", comment: "XFTP servers for profile description"), m.currentUser?.displayName ?? ""))
                .foregroundColor(theme.colors.secondary)
                .lineLimit(PXProtocolServersConfig.footerLineLimit)
        }
    }

    @ViewBuilder private var addServerSection: some View {
        Section {
            ZStack {
                Button(NSLocalizedString("settings_add_server_button", comment: "Add server button")) {
                    if subscription.canAddSMPServer {
                        showAddServer = true
                    } else {
                        showServerUpgrade = true
                    }
                }
                .accessibilityLabel(Text(verbatim: PXProtocolServersConfig.a11yAddServer))
            }
            .navigationDestination(isPresented: $newServerNavLinkActive) {
                newServerDestinationView()
            }
            .navigationDestination(isPresented: $newChatRelayNavLinkActive) {
                PXNewChatRelay(userServers: $userServers, serverErrors: $serverErrors, serverWarnings: $serverWarnings)
                    .navigationTitle(NSLocalizedString("settings_new_chat_relay_title", comment: "New chat relay navigation title"))
                    .navigationBarTitleDisplayMode(.large)
                    .modifier(ThemedBackground(grouped: true))
            }
        } footer: {
            globalErrorsAndWarningsFooter
        }
    }

    @ViewBuilder private var globalErrorsAndWarningsFooter: some View {
        let errs = globalServersErrors(serverErrors)
        let warns = globalServersWarnings(serverWarnings)
        if !errs.isEmpty {
            ForEach(errs, id: \.self) { err in
                ServersErrorView(errStr: err)
            }
        } else if !warns.isEmpty {
            ForEach(warns, id: \.self) { warn in
                ServersWarningView(warnStr: warn)
            }
        }
    }

    @ViewBuilder private var testAndHelpSection: some View {
        Section {
            TestServersButton(
                smpServers: $userServers[operatorIndex].smpServers,
                xftpServers: $userServers[operatorIndex].xftpServers,
                chatRelays: $userServers[operatorIndex].chatRelays,
                testing: $testing
            )
            .accessibilityLabel(Text(verbatim: PXProtocolServersConfig.a11yTestServers))
            howToGuideButton
        }
    }

    @ViewBuilder private var addServerDialogButtons: some View {
        Button(NSLocalizedString("settings_enter_server_manually", comment: "Enter server manually button")) { newServerNavLinkActive = true }
        Button(NSLocalizedString("settings_scan_server_qr", comment: "Scan server QR code button")) { showScanProtoServer = true }
        Button(NSLocalizedString("settings_chat_relay_link", comment: "Chat relay button")) { newChatRelayNavLinkActive = true }
    }

    private func newServerDestinationView() -> some View {
        NewServerView(
            userServers: $userServers,
            serverErrors: $serverErrors,
            serverWarnings: $serverWarnings
        )
        .navigationTitle(NSLocalizedString("new_server_nav_title", comment: "New server navigation title"))
        .navigationBarTitleDisplayMode(.large)
        .modifier(ThemedBackground(grouped: true))
    }

    private var howToGuideButton: some View {
        Button {
            openExternalLink(howToUrl)
        } label: {
            HStack {
                Text(NSLocalizedString("settings_how_to_use_servers", comment: "How to use your servers button"))
                Image(systemName: "arrow.up.right.circle")
            }
        }
        .accessibilityLabel(Text(verbatim: PXProtocolServersConfig.a11yHowTo))
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXProtocolServersConfig.buttonShadowOpacity) : .clear, radius: PXProtocolServersConfig.buttonShadowRadius, x: 0, y: PXProtocolServersConfig.buttonShadowY)
    }
}

// MARK: - POPOPX
extension YourServersView {
    /// Unique POPOPX component tag for analytics and diffing
    var pxComponentTag: String { PXProtocolServersConfig.componentIdentifier }
    var pxA11yChatRelaysId: String { PXProtocolServersConfig.a11yChatRelaysSection }
    var pxA11yMessageServersId: String { PXProtocolServersConfig.a11yMessageServersSection }
}

struct ProtocolServerViewLink: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    var duplicateHosts: Set<String>
    @Binding var server: UserServer
    var serverProtocol: ServerProtocol
    var backLabel: String
    @Binding var selectedServer: String?

    var body: some View {
        let proto = serverProtocol.rawValue.uppercased()

        NavigationLink {
            PXProtocolServerEditor(
                userServers: $userServers,
                serverErrors: $serverErrors,
                serverWarnings: $serverWarnings,
                server: $server,
                serverToEdit: server,
                backLabel: backLabel
            )
            .navigationTitle(String(format: NSLocalizedString("protocol_server_title", comment: "Protocol server navigation title"), proto))
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
        } label: {
            protocolServerRowContent
        }
    }

    // MARK: - POPOPX decomposed row content

    @ViewBuilder private var protocolServerRowContent: some View {
        let address = parseServerAddress(server.server)
        HStack {
            Group {
                if let address = address {
                    if !address.valid || address.serverProtocol != serverProtocol {
                        invalidServerIndicator
                    } else if address.hostnames.contains(where: duplicateHosts.contains) {
                        Image(systemName: "exclamationmark.circle").foregroundColor(QuantumColors.error)
                    } else if !server.enabled {
                        Image(systemName: "slash.circle").foregroundColor(theme.colors.secondary)
                    } else {
                        showTestStatus(server: server)
                    }
                } else {
                    invalidServerIndicator
                }
            }
            .frame(width: PXProtocolServersConfig.statusIconWidth, alignment: .center)
            .padding(.trailing, PXProtocolServersConfig.statusIconTrailingPadding)

            let v = Text(address?.hostnames.first ?? server.server).lineLimit(1)
            if server.enabled {
                v
            } else {
                v.foregroundColor(theme.colors.secondary)
            }
        }
    }

    private var invalidServerIndicator: some View {
        Image(systemName: "exclamationmark.circle")
            .foregroundColor(QuantumColors.error)
            .accessibilityLabel(Text(verbatim: PXProtocolServersConfig.a11yInvalidServer))
    }
}

// MARK: - POPOPX
extension ProtocolServerViewLink {
    /// Unique POPOPX component tag for analytics and diffing
    var pxComponentTag: String { PXProtocolServersConfig.linkComponentIdentifier }
    var pxA11yInvalidId: String { PXProtocolServersConfig.a11yInvalidServer }
}

func deleteSMPServer(
    _ userServers: Binding<[UserOperatorServers]>,
    _ operatorServersIndex: Int,
    _ serverIndexSet: IndexSet
) {
    if let idx = serverIndexSet.first {
        let server = userServers[operatorServersIndex].wrappedValue.smpServers[idx]
        if server.serverId == nil {
            userServers[operatorServersIndex].wrappedValue.smpServers.remove(at: idx)
        } else {
            var updatedServer = server
            updatedServer.deleted = true
            userServers[operatorServersIndex].wrappedValue.smpServers[idx] = updatedServer
        }
    }
}

func deleteXFTPServer(
    _ userServers: Binding<[UserOperatorServers]>,
    _ operatorServersIndex: Int,
    _ serverIndexSet: IndexSet
) {
    if let idx = serverIndexSet.first {
        let server = userServers[operatorServersIndex].wrappedValue.xftpServers[idx]
        if server.serverId == nil {
            userServers[operatorServersIndex].wrappedValue.xftpServers.remove(at: idx)
        } else {
            var updatedServer = server
            updatedServer.deleted = true
            userServers[operatorServersIndex].wrappedValue.xftpServers[idx] = updatedServer
        }
    }
}

func deleteChatRelay(
    _ userServers: Binding<[UserOperatorServers]>,
    _ operatorServersIndex: Int,
    _ serverIndexSet: IndexSet
) {
    if let idx = serverIndexSet.first {
        let relay = userServers[operatorServersIndex].wrappedValue.chatRelays[idx]
        if relay.chatRelayId == nil {
            userServers[operatorServersIndex].wrappedValue.chatRelays.remove(at: idx)
        } else {
            var updatedRelay = relay
            updatedRelay.deleted = true
            userServers[operatorServersIndex].wrappedValue.chatRelays[idx] = updatedRelay
        }
    }
}

struct TestServersButton: View {
    @Binding var smpServers: [UserServer]
    @Binding var xftpServers: [UserServer]
    @Binding var chatRelays: [UserChatRelay]
    @Binding var testing: Bool

    var body: some View {
        Button(NSLocalizedString("settings_test_servers_button", comment: "Test servers button"), action: testServers)
            .disabled(testing || allServersDisabled)
    }

    private var allServersDisabled: Bool {
        smpServers.allSatisfy { !$0.enabled } &&
        xftpServers.allSatisfy { !$0.enabled } &&
        chatRelays.filter({ !$0.deleted }).allSatisfy { !$0.enabled }
    }

    private func testServers() {
        resetTestStatus()
        testing = true
        Task {
            let rfs = await runRelaysTest()
            let sfs = await runServersTest()
            await MainActor.run {
                testing = false
                var failures: [String] = []
                failures += rfs.map { (name, f) in "\(name): \(f.localizedDescription)" }
                failures += sfs.map { (srv, f) in "\(srv): \(f.localizedDescription)" }
                if !failures.isEmpty {
                    let msg = failures.joined(separator: "\n")
                    showAlert(
                        NSLocalizedString("Tests failed!", comment: "alert title"),
                        message: String.localizedStringWithFormat(NSLocalizedString("Some servers failed the test:\n%@", comment: "alert message"), msg)
                    )
                }
            }
        }
    }

    private func resetTestStatus() {
        for i in 0..<chatRelays.count {
            if chatRelays[i].enabled && !chatRelays[i].deleted {
                chatRelays[i].tested = nil
            }
        }

        for i in 0..<smpServers.count {
            if smpServers[i].enabled {
                smpServers[i].tested = nil
            }
        }

        for i in 0..<xftpServers.count {
            if xftpServers[i].enabled {
                xftpServers[i].tested = nil
            }
        }
    }

    private func runServersTest() async -> [String: ProtocolTestFailure] {
        var fs: [String: ProtocolTestFailure] = [:]
        for i in 0..<smpServers.count {
            if smpServers[i].enabled {
                if let f = await testServerConnection(server: $smpServers[i]) {
                    fs[serverHostname(smpServers[i].server)] = f
                }
            }
        }

        for i in 0..<xftpServers.count {
            if xftpServers[i].enabled {
                if let f = await testServerConnection(server: $xftpServers[i]) {
                    fs[serverHostname(xftpServers[i].server)] = f
                }
            }
        }
        return fs
    }

    private func runRelaysTest() async -> [String: RelayTestFailure] {
        var fs: [String: RelayTestFailure] = [:]
        for i in 0..<chatRelays.count {
            if chatRelays[i].enabled && !chatRelays[i].deleted {
                if let f = await testRelayConnection(relay: $chatRelays[i]) {
                    let name = !chatRelays[i].displayName.isEmpty ? chatRelays[i].displayName : chatRelays[i].domains.first ?? chatRelays[i].address
                    fs[name] = f
                }
            }
        }
        return fs
    }
}

func globalServersErrors(_ errors: [UserServersError]) -> [String] {
    errors.map { error in
        switch error {
        case let .noServers(`protocol`, user):
            if let user = user {
                return String(format: NSLocalizedString("protocol_server_no_servers_for", comment: "No servers for user"), `protocol`.rawValue, user.localDisplayName)
            }
            return String(format: NSLocalizedString("protocol_server_no_servers_configured", comment: "No servers configured"), `protocol`.rawValue)
        case let .storageMissing(`protocol`, user):
            if let user = user {
                return String(format: NSLocalizedString("protocol_server_storage_missing_for", comment: "Storage missing for protocol in user"), `protocol`.rawValue, user.localDisplayName)
            }
            return String(format: NSLocalizedString("protocol_server_storage_missing", comment: "Storage missing for protocol"), `protocol`.rawValue)
        case let .proxyMissing(`protocol`, user):
            if let user = user {
                return String(format: NSLocalizedString("protocol_server_proxy_missing_for", comment: "Proxy missing for protocol in user"), `protocol`.rawValue, user.localDisplayName)
            }
            return String(format: NSLocalizedString("protocol_server_proxy_missing", comment: "Proxy missing for protocol"), `protocol`.rawValue)
        case let .duplicateServer(_, duplicateServer, duplicateHost):
            return String(format: NSLocalizedString("protocol_server_duplicate", comment: "Duplicate server"), duplicateServer, duplicateHost)
        case let .duplicateChatRelayAddress(duplicateChatRelay, duplicateAddress):
            return String(format: NSLocalizedString("protocol_server_duplicate_relay", comment: "Duplicate chat relay"), duplicateChatRelay, duplicateAddress)
        case let .tooManyHosts(_, server):
            return String(format: NSLocalizedString("Server %@ has more than two host names.", comment: "servers error"), serverHostname(server))
        }
    }
}

func globalServersWarnings(_ warnings: [UserServersWarning]) -> [String] {
    warnings.map { warning in
        switch warning {
        case let .noChatRelays(user):
            if let user = user {
                return String(format: NSLocalizedString("protocol_server_no_relays_for", comment: "No chat relays for user"), user.localDisplayName)
            }
            return NSLocalizedString("protocol_server_no_relays_configured", comment: "No chat relays configured")
        case let .noNamesServers(user):
            if let user = user {
                return String(format: NSLocalizedString("protocol_server_no_name_servers_for", comment: "No name servers for user"), user.localDisplayName)
            }
            return NSLocalizedString("protocol_server_no_name_servers_configured", comment: "No name servers configured")
        }
    }
}

struct YourServersView_Previews: PreviewProvider {
    static var previews: some View {
        YourServersView(
            userServers: Binding.constant([UserOperatorServers.sampleDataNilOperator]),
            serverErrors: Binding.constant([]),
            serverWarnings: Binding.constant([]),
            operatorIndex: 1
        )
    }
}
