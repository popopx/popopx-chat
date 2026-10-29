//
//  PXServersSummaryView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 25.06.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import Combine

// MARK: - POPOPX Server Summary Customization
private let pxServerSummaryVersion = "2.0-px"

struct ServersSummaryView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var serversSummary: PresentedServersSummary? = nil
    @State private var selectedUserCategory: PresentedUserCategory = .allUsers
    @State private var selectedServerType: PresentedServerType = .smp
    @State private var alert: SomeAlert?

    @AppStorage(DEFAULT_SHOW_SUBSCRIPTION_PERCENTAGE) private var showSubscriptionPercentage = false

    enum PresentedUserCategory {
        case currentUser
        case allUsers
    }

    enum PresentedServerType {
        case smp
        case xftp
    }

    var body: some View {
        NavigationStack {
            viewBody()
                .navigationTitle(NSLocalizedString("Servers info", comment: ""))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(NSLocalizedString("Servers info", comment: ""))
                            .font(.headline.weight(.bold))
                            .shadow(color: isInDarkTheme() ? theme.colors.primary.opacity(PXServersSummaryConfig.navTitleShadowOpacity) : .clear, radius: PXServersSummaryConfig.navTitleShadowRadius, x: 0, y: 1)
                    }
                }
                .modifier(ThemedBackground(grouped: true))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        pxShareButton
                    }
                }
        }
        .onAppear {
            if m.users.filter({ u in u.user.activeUser || !u.user.hidden }).count == 1 {
                selectedUserCategory = .currentUser
            }
            getServersSummary()
        }
        .onReceive(Timer.publish(every: PXServersSummaryConfig.refreshInterval, on: .main, in: .common).autoconnect()) { _ in
            if AppChatState.shared.value == .active {
                getServersSummary()
            }
        }
        .alert(item: $alert) { $0.alert }
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    private var pxShareButton: some View {
        Button {
            if let serversSummary = serversSummary {
                showShareSheet(items: [encodePrettyPrinted(serversSummary)])
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(serversSummary == nil)
        .accessibilityLabel(Text(NSLocalizedString("Share server info", comment: "Accessibility label for share button")))
    }

    public func encodePrettyPrinted<T: Encodable>(_ value: T) -> String {
        let encoder = jsonEncoder
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    @ViewBuilder private func viewBody() -> some View {
        if let summ = serversSummary {
            pxServerList(summ)
        } else {
            Text(NSLocalizedString("No info, try to reload", comment: ""))
                .foregroundColor(theme.colors.secondary)
                .background(theme.colors.background)
        }
    }

    @ViewBuilder
    private func pxServerList(_ summ: PresentedServersSummary) -> some View {
        List {
            pxPickerGroup
            pxServerContent(summ)
            Section {
                reconnectAllButton()
                resetStatsButton()
            }
        }
    }

    @ViewBuilder
    private var pxPickerGroup: some View {
        Group {
            if m.users.filter({ u in u.user.activeUser || !u.user.hidden }).count > 1 {
                Picker(NSLocalizedString("servers_user_selection_picker", comment: "User selection picker label"), selection: $selectedUserCategory) {
                    Text(NSLocalizedString("All profiles", comment: "")).tag(PresentedUserCategory.allUsers)
                    Text(NSLocalizedString("Current profile", comment: "")).tag(PresentedUserCategory.currentUser)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(NSLocalizedString("User selection", comment: "Accessibility label for user picker")))
            }

            Picker(NSLocalizedString("servers_server_type_picker", comment: "Server type picker label"), selection: $selectedServerType) {
                Text(NSLocalizedString("Messages", comment: "")).tag(PresentedServerType.smp)
                Text(NSLocalizedString("Files", comment: "")).tag(PresentedServerType.xftp)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text(NSLocalizedString("Server type selection", comment: "Accessibility label for server type picker")))
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .listRowSeparator(.hidden)
        .listRowInsets(PXServersSummaryConfig.zeroRowInsets)
    }

    @ViewBuilder
    private func pxServerContent(_ summ: PresentedServersSummary) -> some View {
        switch (selectedUserCategory, selectedServerType) {
        case (.allUsers, .smp):
            let smpSumm = summ.allUsersSMP
            let (totals, curr, prev, prox) = (smpSumm.smpTotals, smpSumm.currentlyUsedSMPServers, smpSumm.previouslyUsedSMPServers, smpSumm.onlyProxiedSMPServers)
            pxSMPContent(totals: totals, curr: curr, prev: prev, prox: prox, statsStartedAt: summ.statsStartedAt)
        case (.currentUser, .smp):
            let smpSumm = summ.currentUserSMP
            let (totals, curr, prev, prox) = (smpSumm.smpTotals, smpSumm.currentlyUsedSMPServers, smpSumm.previouslyUsedSMPServers, smpSumm.onlyProxiedSMPServers)
            pxSMPContent(totals: totals, curr: curr, prev: prev, prox: prox, statsStartedAt: summ.statsStartedAt)
        case (.allUsers, .xftp):
            let xftpSumm = summ.allUsersXFTP
            let (totals, curr, prev) = (xftpSumm.xftpTotals, xftpSumm.currentlyUsedXFTPServers, xftpSumm.previouslyUsedXFTPServers)
            pxXFTPContent(totals: totals, curr: curr, prev: prev, statsStartedAt: summ.statsStartedAt)
        case (.currentUser, .xftp):
            let xftpSumm = summ.currentUserXFTP
            let (totals, curr, prev) = (xftpSumm.xftpTotals, xftpSumm.currentlyUsedXFTPServers, xftpSumm.previouslyUsedXFTPServers)
            pxXFTPContent(totals: totals, curr: curr, prev: prev, statsStartedAt: summ.statsStartedAt)
        }
    }

    @ViewBuilder
    private func pxSMPContent(totals: SMPTotals, curr: [SMPServerSummary], prev: [SMPServerSummary], prox: [SMPServerSummary], statsStartedAt: Date) -> some View {
        SMPStatsView(stats: totals.stats, statsStartedAt: statsStartedAt)
        smpSubsSection(totals)
        if curr.count > 0 {
            smpServersListView(curr, statsStartedAt, LocalizedStringKey(NSLocalizedString("Connected servers", comment: "")))
        }
        if prev.count > 0 {
            smpServersListView(prev, statsStartedAt, LocalizedStringKey(NSLocalizedString("Previously connected servers", comment: "")))
        }
        if prox.count > 0 {
            smpServersListView(prox, statsStartedAt, LocalizedStringKey(NSLocalizedString("Proxied servers", comment: "")), LocalizedStringKey(NSLocalizedString("You are not connected to these servers. Private routing is used to deliver messages to them.", comment: "")))
        }
        ServerSessionsView(sess: totals.sessions)
    }

    @ViewBuilder
    private func pxXFTPContent(totals: XFTPTotals, curr: [XFTPServerSummary], prev: [XFTPServerSummary], statsStartedAt: Date) -> some View {
        XFTPStatsView(stats: totals.stats, statsStartedAt: statsStartedAt)
        if curr.count > 0 {
            xftpServersListView(curr, statsStartedAt, LocalizedStringKey(NSLocalizedString("Connected servers", comment: "")))
        }
        if prev.count > 0 {
            xftpServersListView(prev, statsStartedAt, LocalizedStringKey(NSLocalizedString("Previously connected servers", comment: "")))
        }
        ServerSessionsView(sess: totals.sessions)
    }

    // MARK: - POPOPX Actions

    private func getServersSummary() {
        do {
            serversSummary = try getAgentServersSummary()
        } catch let error {
            logger.error("getAgentServersSummary error: \(responseError(error))")
        }
    }

    private func smpSubsSection(_ totals: SMPTotals) -> some View {
        Section {
            infoRow(LocalizedStringKey(NSLocalizedString("Active connections", comment: "")), numOrDash(totals.subs.ssActive))
            infoRow(LocalizedStringKey(NSLocalizedString("Total", comment: "")), numOrDash(totals.subs.total))
            Toggle(NSLocalizedString("Show percentage", comment: ""), isOn: $showSubscriptionPercentage)
        } header: {
            HStack {
                Text(NSLocalizedString("Message reception", comment: ""))
                SubscriptionStatusIndicatorView(subs: totals.subs, hasSess: totals.sessions.hasSess)
                if showSubscriptionPercentage {
                    SubscriptionStatusPercentageView(subs: totals.subs, hasSess: totals.sessions.hasSess)
                }
            }
        }
    }

    private func reconnectAllButton() -> some View {
        Button {
            alert = SomeAlert(
                alert: Alert(
                    title: Text(NSLocalizedString("Reconnect all servers?", comment: "")),
                    message: Text(NSLocalizedString("Reconnect all connected servers to force message delivery. It uses additional traffic.", comment: "")),
                    primaryButton: .default(Text(NSLocalizedString("Ok", comment: ""))) {
                        Task {
                            do {
                                try await reconnectAllServers()
                            } catch let error {
                                alert = SomeAlert(
                                    alert: mkAlert(
                                        title: LocalizedStringKey(NSLocalizedString("Error reconnecting servers", comment: "")),
                                        message: "\(responseError(error))"
                                    ),
                                    id: "error reconnecting servers"
                                )
                            }
                        }
                    },
                    secondaryButton: .cancel()
                ),
                id: "reconnect servers question"
            )
        } label: {
            Text(NSLocalizedString("Reconnect all servers", comment: ""))
        }
        .accessibilityLabel(Text(NSLocalizedString("Reconnect all servers", comment: "Accessibility label")))
    }

    private func smpServersListView(
        _ servers: [SMPServerSummary],
        _ statsStartedAt: Date,
        _ header: LocalizedStringKey? = nil,
        _ footer: LocalizedStringKey? = nil
    ) -> some View {
        let sortedServers = servers.sorted {
            $0.hasSubs == $1.hasSubs
            ? serverAddress($0.smpServer) < serverAddress($1.smpServer)
            : $0.hasSubs && !$1.hasSubs
        }
        return Section {
            ForEach(sortedServers) { server in
                smpServerView(server, statsStartedAt)
            }
        } header: {
            if let header = header {
                Text(header)
            }
        } footer: {
            if let footer = footer {
                Text(footer)
            }
        }
    }

    private func smpServerView(_ srvSumm: SMPServerSummary, _ statsStartedAt: Date) -> some View {
        NavigationLink {
            SMPServerSummaryView(
                summary: srvSumm,
                statsStartedAt: statsStartedAt
            )
            .navigationTitle(NSLocalizedString("SMP server", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .modifier(ThemedBackground(grouped: true))
        } label: {
            HStack {
                Text(serverAddress(srvSumm.smpServer))
                    .lineLimit(1)
                if let subs = srvSumm.subs {
                    Spacer()
                    if showSubscriptionPercentage {
                        SubscriptionStatusPercentageView(subs: subs, hasSess: srvSumm.sessionsOrNew.hasSess)
                    }
                    SubscriptionStatusIndicatorView(subs: subs, hasSess: srvSumm.sessionsOrNew.hasSess)
                } else if let sess = srvSumm.sessions {
                    Spacer()
                    Image(systemName: "arrow.up.circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(sessIconColor(sess), Color.clear)
                }
            }
        }
    }

    private func serverAddress(_ server: String) -> String {
        parseServerAddress(server)?.hostnames.first ?? server
    }

    private func sessIconColor(_ sess: ServerSessions) -> Color {
        let online = m.networkInfo.online
        return (
            online && sess.ssConnected > 0
            ? sessionActiveColor
            : theme.colors.secondary
        )
    }

    private var sessionActiveColor: Color {
        let onionHosts = networkUseOnionHostsGroupDefault.get()
        return onionHosts == .require ? QuantumColors.accent : theme.colors.primary
    }

    private func xftpServersListView(
        _ servers: [XFTPServerSummary],
        _ statsStartedAt: Date,
        _ header: LocalizedStringKey? = nil,
        _ footer: LocalizedStringKey? = nil
    ) -> some View {
        let sortedServers = servers.sorted { serverAddress($0.xftpServer) < serverAddress($1.xftpServer) }
        return Section {
            ForEach(sortedServers) { server in
                xftpServerView(server, statsStartedAt)
            }
        } header: {
            if let header = header {
                Text(header)
            }
        } footer: {
            if let footer = footer {
                Text(footer)
            }
        }
    }

    private func xftpServerView(_ srvSumm: XFTPServerSummary, _ statsStartedAt: Date) -> some View {
        NavigationLink {
            XFTPServerSummaryView(
                summary: srvSumm,
                statsStartedAt: statsStartedAt
            )
            .navigationTitle(NSLocalizedString("XFTP server", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .modifier(ThemedBackground(grouped: true))
        } label: {
            HStack {
                Text(serverAddress(srvSumm.xftpServer))
                    .lineLimit(1)
                if let inProgressIcon = inProgressIcon(srvSumm) {
                    Spacer()
                    Image(systemName: inProgressIcon)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(sessionActiveColor, Color.clear)
                }
            }
        }
    }

    private func inProgressIcon(_ srvSumm: XFTPServerSummary) -> String? {
        switch (srvSumm.rcvInProgress, srvSumm.sndInProgress, srvSumm.delInProgress) {
        case (false, false, false): nil
        case (true, false, false): "arrow.down.circle"
        case (false, true, false): "arrow.up.circle"
        case (false, false, true): "trash.circle"
        default: "arrow.up.arrow.down.circle"
        }
    }

    private func resetStatsButton() -> some View {
        Button {
            alert = SomeAlert(
                alert: Alert(
                    title: Text(NSLocalizedString("Reset all statistics?", comment: "")),
                    message: Text(NSLocalizedString("Servers statistics will be reset - this cannot be undone!", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Reset", comment: ""))) {
                        Task {
                            do {
                                try await resetAgentServersStats()
                                getServersSummary()
                            } catch let error {
                                alert = SomeAlert(
                                    alert: mkAlert(
                                        title: LocalizedStringKey(NSLocalizedString("Error resetting statistics", comment: "")),
                                        message: "\(responseError(error))"
                                    ),
                                    id: "error resetting statistics"
                                )
                            }
                        }
                    },
                    secondaryButton: .cancel()
                ),
                id: "reset statistics question"
            )
        } label: {
            Text(NSLocalizedString("Reset all statistics", comment: ""))
        }
        .accessibilityLabel(Text(NSLocalizedString("Reset statistics", comment: "Accessibility label")))
    }
}

struct SubscriptionStatusIndicatorView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    var subs: SMPServerSubs
    var hasSess: Bool

    var body: some View {
        let (color, variableValue, _) = subscriptionStatusInfo(
            online: m.networkInfo.online,
            usesProxy: networkUseOnionHostsGroupDefault.get() != .no || kcSocksProxy.get() != nil,
            subs: subs,
            hasSess: hasSess,
            primaryColor: theme.colors.primary
        )
        Image(systemName: "dot.radiowaves.up.forward", variableValue: variableValue)
            .foregroundColor(color)
    }
}

struct SubscriptionStatusPercentageView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    var subs: SMPServerSubs
    var hasSess: Bool

    var body: some View {
        let statusPercent = subscriptionStatusPercent(online: m.networkInfo.online, subs: subs, hasSess: hasSess)
        let percentText: String = subs.total > 0 || hasSess ? "\(Int(floor(statusPercent * 100)))%" : "%"
        Text(percentText)
            .foregroundColor(theme.colors.secondary)
            .font(.caption)
    }
}

func subscriptionStatusInfo(online: Bool, usesProxy: Bool, subs: SMPServerSubs, hasSess: Bool, primaryColor: Color) -> (Color, Double, Double) {
    func roundedToQuarter(_ n: Double) -> Double {
        n >= 1 ? 1
        : n <= 0 ? 0
        : (n * 4).rounded() / 4
    }

    let activeColor: Color = usesProxy ? QuantumColors.accent : primaryColor
    let noConnColorAndPercent: (Color, Double, Double) = (primaryColor.opacity(0.4), 1, 1)
    let activeSubsRounded = roundedToQuarter(subs.shareOfActive)

    return !online
    ? noConnColorAndPercent
    : subs.total == 0 && !hasSess
    ? (activeColor, 0, 0.33) // On freshly installed app (without chats) and on app start
    : subs.ssActive == 0
    ? (
        hasSess ? (activeColor, activeSubsRounded, subs.shareOfActive) : noConnColorAndPercent
    )
    : ( // ssActive > 0
        hasSess
        ? (activeColor, activeSubsRounded, subs.shareOfActive)
        : (QuantumColors.warning, activeSubsRounded, subs.shareOfActive) // This would mean implementation error
      )
}

func subscriptionStatusPercent(online: Bool, subs: SMPServerSubs, hasSess: Bool) -> Double {
    online && (hasSess || (subs.total > 0 && subs.ssActive > 0))
    ? subs.shareOfActive
    : 0
}

struct SMPServerSummaryView: View {
    var summary: SMPServerSummary
    var statsStartedAt: Date
    @State private var alert: SomeAlert?

    @AppStorage(DEFAULT_SHOW_SUBSCRIPTION_PERCENTAGE) private var showSubscriptionPercentage = false

    var body: some View {
        List {
            Section(LocalizedStringKey(NSLocalizedString("Server address", comment: ""))) {
                Text(summary.smpServer)
                    .textSelection(.enabled)
            }

            if let stats = summary.stats {
                SMPStatsView(stats: stats, statsStartedAt: statsStartedAt)
            }

            if let subs = summary.subs {
                smpSubsSection(subs)
            }

            if let sess = summary.sessions {
                ServerSessionsView(sess: sess)
            }
        }
        .alert(item: $alert) { $0.alert }
    }

    private func smpSubsSection(_ subs: SMPServerSubs) -> some View {
        Section {
            infoRow(LocalizedStringKey(NSLocalizedString("Active connections", comment: "")), numOrDash(subs.ssActive))
            infoRow(LocalizedStringKey(NSLocalizedString("Pending", comment: "")), numOrDash(subs.ssPending))
            infoRow(LocalizedStringKey(NSLocalizedString("Total", comment: "")), numOrDash(subs.total))
            reconnectButton()
        } header: {
            HStack {
                Text(NSLocalizedString("Message reception", comment: ""))
                SubscriptionStatusIndicatorView(subs: subs, hasSess: summary.sessionsOrNew.hasSess)
                if showSubscriptionPercentage {
                    SubscriptionStatusPercentageView(subs: subs, hasSess: summary.sessionsOrNew.hasSess)
                }
            }
        }
    }

    private func reconnectButton() -> some View {
        Button {
            alert = SomeAlert(
                alert: Alert(
                    title: Text(NSLocalizedString("Reconnect server?", comment: "")),
                    message: Text(NSLocalizedString("Reconnect server to force message delivery. It uses additional traffic.", comment: "")),
                    primaryButton: .default(Text(NSLocalizedString("Ok", comment: ""))) {
                        Task {
                            do {
                                try await reconnectServer(smpServer: summary.smpServer)
                            } catch let error {
                                alert = SomeAlert(
                                    alert: mkAlert(
                                        title: LocalizedStringKey(NSLocalizedString("Error reconnecting server", comment: "")),
                                        message: "\(responseError(error))"
                                    ),
                                    id: "error reconnecting server"
                                )
                            }
                        }
                    },
                    secondaryButton: .cancel()
                ),
                id: "reconnect server question"
            )
        } label: {
            Text(NSLocalizedString("Reconnect", comment: ""))
        }
    }
}

struct ServerSessionsView: View {
    var sess: ServerSessions

    var body: some View {
        Section(LocalizedStringKey(NSLocalizedString("Transport sessions", comment: ""))) {
            infoRow(LocalizedStringKey(NSLocalizedString("Connected", comment: "")), numOrDash(sess.ssConnected))
            infoRow(LocalizedStringKey(NSLocalizedString("Errors", comment: "")), numOrDash(sess.ssErrors))
            infoRow(LocalizedStringKey(NSLocalizedString("Connecting", comment: "")), numOrDash(sess.ssConnecting))
        }
    }
}

struct SMPStatsView: View {
    var stats: AgentSMPServerStatsData
    var statsStartedAt: Date

    var body: some View {
        Section {
            infoRow(LocalizedStringKey(NSLocalizedString("Messages sent", comment: "")), numOrDash(stats._sentDirect + stats._sentViaProxy))
            infoRow(LocalizedStringKey(NSLocalizedString("Messages received", comment: "")), numOrDash(stats._recvMsgs))
            NavigationLink {
                DetailedSMPStatsView(stats: stats, statsStartedAt: statsStartedAt)
                    .navigationTitle(NSLocalizedString("Detailed statistics", comment: ""))
                    .navigationBarTitleDisplayMode(.large)
                    .modifier(ThemedBackground(grouped: true))
            } label: {
                Text(NSLocalizedString("Details", comment: ""))
            }
        } header: {
            Text(NSLocalizedString("Statistics", comment: ""))
        } footer: {
            Text("\(String.localizedStringWithFormat(NSLocalizedString("Starting from %@.", comment: ""), localTimestamp(statsStartedAt)))\n\(NSLocalizedString("All data is kept private on your device.", comment: ""))")
        }
    }
}

private func numOrDash(_ n: Int) -> String {
    n == 0 ? "-" : "\(n)"
}

struct DetailedSMPStatsView: View {
    var stats: AgentSMPServerStatsData
    var statsStartedAt: Date

    var body: some View {
        List {
            Section(LocalizedStringKey(NSLocalizedString("Sent messages", comment: ""))) {
                infoRow(LocalizedStringKey(NSLocalizedString("Sent total", comment: "")), numOrDash(stats._sentDirect + stats._sentViaProxy))
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Sent directly", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._sentDirect, stats._sentDirectAttempts)
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Sent via proxy", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._sentViaProxy, stats._sentViaProxyAttempts)
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Proxied", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._sentProxied, stats._sentProxiedAttempts)
                Text(NSLocalizedString("Send errors", comment: ""))
                infoRow(LocalizedStringKey(NSLocalizedString("auth", comment: "server error type")), numOrDash(stats._sentAuthErrs)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("quota", comment: "server error type")), numOrDash(stats._sentQuotaErrs)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("expired", comment: "")), numOrDash(stats._sentExpiredErrs)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("other", comment: "")), numOrDash(stats._sentOtherErrs)).padding(.leading, 24)
            }
            Section(LocalizedStringKey(NSLocalizedString("Received messages", comment: ""))) {
                infoRow(LocalizedStringKey(NSLocalizedString("Received total", comment: "")), numOrDash(stats._recvMsgs))
                Text(NSLocalizedString("Receive errors", comment: ""))
                infoRow(LocalizedStringKey(NSLocalizedString("duplicates", comment: "")), numOrDash(stats._recvDuplicates)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("decryption errors", comment: "")), numOrDash(stats._recvCryptoErrs)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("other errors", comment: "")), numOrDash(stats._recvErrs)).padding(.leading, 24)
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Acknowledged", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._ackMsgs, stats._ackAttempts)
                Text(NSLocalizedString("Acknowledgement errors", comment: ""))
                infoRow(LocalizedStringKey(NSLocalizedString("no_msg errors", comment: "server error type")), numOrDash(stats._ackNoMsgErrs)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("other errors", comment: "")), numOrDash(stats._ackOtherErrs)).padding(.leading, 24)
            }
            Section(LocalizedStringKey(NSLocalizedString("Connections", comment: ""))) {
                infoRow(LocalizedStringKey(NSLocalizedString("Created", comment: "")), numOrDash(stats._connCreated))
                infoRow(LocalizedStringKey(NSLocalizedString("Secured", comment: "")), numOrDash(stats._connSecured))
                infoRow(LocalizedStringKey(NSLocalizedString("Completed", comment: "")), numOrDash(stats._connCompleted))
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Deleted", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._connDeleted, stats._connDelAttempts)
                infoRow(LocalizedStringKey(NSLocalizedString("Deletion errors", comment: "")), numOrDash(stats._connDelErrs))
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Subscribed", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._connSubscribed, stats._connSubAttempts)
                infoRow(LocalizedStringKey(NSLocalizedString("Subscriptions ignored", comment: "")), numOrDash(stats._connSubIgnored))
                infoRow(LocalizedStringKey(NSLocalizedString("Subscription errors", comment: "")), numOrDash(stats._connSubErrs))
            }
            Section {
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Enabled", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._ntfKey, stats._ntfKeyAttempts)
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Disabled", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._ntfKeyDeleted, stats._ntfKeyDeleteAttempts)
            } header: {
                Text(NSLocalizedString("Connection notifications", comment: ""))
            } footer: {
                Text(String.localizedStringWithFormat(NSLocalizedString("Starting from %@.", comment: ""), localTimestamp(statsStartedAt)))
            }
        }
    }
}

private func infoRowTwoValues(_ title: LocalizedStringKey, _ title2: LocalizedStringKey, _ value: Int, _ value2: Int) -> some View {
    HStack {
        HStack(spacing: 0) {
            Text(title)
            Text(verbatim: " / ")
            Text(title2)
        }
        .font(.caption2)
        Spacer()
        Group {
            if value == 0 && value2 == 0 {
                Text(verbatim: "-")
            } else {
                Text(verbatim: "\(numOrDash(value)) / \(numOrDash(value2))").font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
    }
}

struct XFTPServerSummaryView: View {
    var summary: XFTPServerSummary
    var statsStartedAt: Date

    var body: some View {
        List {
            Section(LocalizedStringKey(NSLocalizedString("Server address", comment: ""))) {
                Text(summary.xftpServer)
                    .textSelection(.enabled)
            }

            if let stats = summary.stats {
                XFTPStatsView(stats: stats, statsStartedAt: statsStartedAt)
            }

            if let sess = summary.sessions {
                ServerSessionsView(sess: sess)
            }
        }
    }
}

struct XFTPStatsView: View {
    var stats: AgentXFTPServerStatsData
    var statsStartedAt: Date
    @State private var expanded = false

    var body: some View {
        Section {
            infoRow(LocalizedStringKey(NSLocalizedString("Uploaded", comment: "")), prettySize(stats._uploadsSize))
            infoRow(LocalizedStringKey(NSLocalizedString("Downloaded", comment: "")), prettySize(stats._downloadsSize))
            NavigationLink {
                DetailedXFTPStatsView(stats: stats, statsStartedAt: statsStartedAt)
                    .navigationTitle(NSLocalizedString("Detailed statistics", comment: ""))
                    .navigationBarTitleDisplayMode(.large)
                    .modifier(ThemedBackground(grouped: true))
            } label: {
                Text(NSLocalizedString("Details", comment: ""))
            }
        } header: {
            Text(NSLocalizedString("Statistics", comment: ""))
        } footer: {
            Text("\(String.localizedStringWithFormat(NSLocalizedString("Starting from %@.", comment: ""), localTimestamp(statsStartedAt)))\n\(NSLocalizedString("All data is kept private on your device.", comment: ""))")
        }
    }
}

private func prettySize(_ sizeInKB: Int64) -> String {
    let kb: Int64 = 1024
    return sizeInKB == 0 ? "-" : ByteCountFormatter.string(fromByteCount: sizeInKB * kb, countStyle: .binary)
}

struct DetailedXFTPStatsView: View {
    var stats: AgentXFTPServerStatsData
    var statsStartedAt: Date

    var body: some View {
        List {
            Section(LocalizedStringKey(NSLocalizedString("Uploaded files", comment: ""))) {
                infoRow(LocalizedStringKey(NSLocalizedString("Size", comment: "")), prettySize(stats._uploadsSize))
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Chunks uploaded", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._uploads, stats._uploadAttempts)
                infoRow(LocalizedStringKey(NSLocalizedString("Upload errors", comment: "")), numOrDash(stats._uploadErrs))
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Chunks deleted", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._deletions, stats._deleteAttempts)
                infoRow(LocalizedStringKey(NSLocalizedString("Deletion errors", comment: "")), numOrDash(stats._deleteErrs))
            }
            Section {
                infoRow(LocalizedStringKey(NSLocalizedString("Size", comment: "")), prettySize(stats._downloadsSize))
                infoRowTwoValues(LocalizedStringKey(NSLocalizedString("Chunks downloaded", comment: "")), LocalizedStringKey(NSLocalizedString("attempts", comment: "")), stats._downloads, stats._downloadAttempts)
                Text(NSLocalizedString("Download errors", comment: ""))
                infoRow(LocalizedStringKey(NSLocalizedString("auth", comment: "server error type")), numOrDash(stats._downloadAuthErrs)).padding(.leading, 24)
                infoRow(LocalizedStringKey(NSLocalizedString("other", comment: "")), numOrDash(stats._downloadErrs)).padding(.leading, 24)
            } header: {
                Text(NSLocalizedString("Downloaded files", comment: ""))
            } footer: {
                Text(String.localizedStringWithFormat(NSLocalizedString("Starting from %@.", comment: ""), localTimestamp(statsStartedAt)))
            }
        }
    }
}

// MARK: - POPOPX Config & Tag

private enum PXServersSummaryConfig {
    static let refreshInterval: Double = 1.0
    static let navTitleShadowOpacity: Double = 0.3
    static let navTitleShadowRadius: CGFloat = 4
    static let zeroRowInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

extension ServersSummaryView {
    static let pxComponentTag: String = "PX_SERVERS_SUMMARY_VIEW"
    var pxServerCount: Int { 0 }

    func pxServerStatusText(_ connected: Bool) -> String {
        connected
            ? NSLocalizedString("Connected via POPOPX", comment: "POPOPX server status")
            : NSLocalizedString("Disconnected", comment: "POPOPX server status")
    }
}

#Preview {
    ServersSummaryView()
        .previewEnvironment()
}
