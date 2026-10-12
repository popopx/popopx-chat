//
//  ConnectDesktopView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 13/10/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import CodeScanner

struct ConnectDesktopView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @AppStorage(DEFAULT_CONFIRM_REMOTE_SESSIONS) private var confirmRemoteSessions = false
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @State private var sessionAddress: String = ""
    @State private var remoteCtrls: [RemoteCtrlInfo] = []
    @State private var alert: ConnectDesktopAlert?
    @State private var showConnectScreen = true
    @State private var showQRCodeScanner = true
    @State private var firstAppearance = true
    @State private var qrWorkItem: DispatchWorkItem?

    private enum ConnectDesktopAlert: Identifiable {
        case unlinkDesktop(rc: RemoteCtrlInfo)
        case disconnectDesktop(action: UserDisconnectAction)
        case badInvitationError
        case badVersionError(version: String?)
        case desktopDisconnectedError
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case let .unlinkDesktop(rc): "unlinkDesktop \(rc.remoteCtrlId)"
            case let .disconnectDesktop(action): "disconnectDecktop \(action)"
            case .badInvitationError: "badInvitationError"
            case let .badVersionError(v): "badVersionError \(v ?? "")"
            case .desktopDisconnectedError: "desktopDisconnectedError"
            case let .error(title, _): "error \(title)"
            }
        }
    }

    private enum UserDisconnectAction: String {
        case back
        case dismiss
    }

    var body: some View {
        Group {
            let discovery = m.remoteCtrlSession?.discovery
            if discovery == true || (discovery == nil && !showConnectScreen) {
                searchingDesktopView()
            } else if let session = m.remoteCtrlSession {
                switch session.sessionState {
                case .starting: connectingDesktopView(session, nil)
                case .searching: searchingDesktopView()
                case let .found(rc, compatible): foundDesktopView(session, rc, compatible)
                case let .connecting(rc_): connectingDesktopView(session, rc_)
                case let .pendingConfirmation(rc_, sessCode):
                    if confirmRemoteSessions || rc_ == nil {
                        verifySessionView(session, rc_, sessCode)
                    } else {
                        connectingDesktopView(session, rc_).onAppear {
                            verifyDesktopSessionCode(sessCode)
                        }
                    }
                case let .connected(rc, _): activeSessionView(session, rc)
                }
            // The hack below prevents camera freezing when exiting linked devices view.
            // Using showQRCodeScanner inside connectDesktopView or passing it as parameter still results in freezing.
            } else if showQRCodeScanner || firstAppearance {
                connectDesktopView()
            } else {
                connectDesktopView(showScanner: false)
            }
        }
        .onAppear {
            setDeviceName()
            updateRemoteCtrls()
            if m.remoteCtrlSession != nil {
                disconnectDesktop()
            }
            // The hack below prevents camera freezing when exiting linked devices view.
            // `firstAppearance` prevents camera flicker when the view first opens.
            // moving `showQRCodeScanner = false` to `onDisappear` (to avoid `firstAppearance`) does not prevent freeze.
            showQRCodeScanner = false
            let workItem = DispatchWorkItem { firstAppearance = false; showQRCodeScanner = true }
            qrWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }
        .onDisappear {
            qrWorkItem?.cancel()
            qrWorkItem = nil
            if m.remoteCtrlSession != nil {
                showConnectScreen = false
                disconnectDesktop()
            }
        }
        .onChange(of: m.activeRemoteCtrl) { _, newCtrl in
            UIApplication.shared.isIdleTimerDisabled = newCtrl
        }
        .alert(item: $alert) { a in
            switch a {
            case let .unlinkDesktop(rc):
                Alert(
                    title: Text(NSLocalizedString("Unlink desktop?", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Unlink", comment: ""))) {
                        unlinkDesktop(rc)
                    },
                    secondaryButton: .cancel()
                )
            case let .disconnectDesktop(action):
                Alert(
                    title: Text(NSLocalizedString("Disconnect desktop?", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Disconnect", comment: ""))) {
                        disconnectDesktop(action)
                    },
                    secondaryButton: .cancel()
                )
            case .badInvitationError:
                Alert(title: Text(NSLocalizedString("Bad desktop address", comment: "")))
            case let .badVersionError(v):
                Alert(
                    title: Text(NSLocalizedString("Incompatible version", comment: "")),
                    message: Text(String.localizedStringWithFormat(NSLocalizedString("Desktop app version %@ is not compatible with this app.", comment: ""), v ?? ""))
                )
            case .desktopDisconnectedError:
                Alert(title: Text(NSLocalizedString("Connection terminated", comment: "")))
            case let .error(title, error):
                mkAlert(title: title, message: error)
            }
        }
        .interactiveDismissDisabled(m.activeRemoteCtrl)
        .popopxBranded()
    }

    private func connectDesktopView(showScanner: Bool = true) -> some View {
        List {
            Section(header: Text(NSLocalizedString("This device name", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                devicesView()
            }
            if showScanner {
                scanDesctopAddressView()
            }
            if developerTools {
                desktopAddressView()
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Connect to desktop", comment: ""))
        .modifier(ThemedBackground(grouped: true))
    }

    private func connectingDesktopView(_ session: RemoteCtrlSession, _ rc: RemoteCtrlInfo?) -> some View {
        ZStack {
            List {
                Section(header: Text(NSLocalizedString("Connecting to desktop", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                    .textCase(.uppercase)) {
                    ctrlDeviceNameText(session, rc)
                    ctrlDeviceVersionText(session)
                }

                if let sessCode = session.sessionCode {
                    Section(header: Text(NSLocalizedString("Session code", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                        .textCase(.uppercase)) {
                        sessionCodeText(sessCode)
                    }
                }

                Section {
                    disconnectButton()
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .navigationTitle(NSLocalizedString("Connecting to desktop", comment: ""))

            ProgressView().scaleEffect(2)
        }
        .modifier(ThemedBackground(grouped: true))
    }

    private func searchingDesktopView() -> some View {
        List {
            Section(header: Text(NSLocalizedString("This device name", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                devicesView()
            }
            Section(header: Text(NSLocalizedString("Found desktop", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                Text(NSLocalizedString("Waiting for desktop...", comment: "")).italic()
                Button {
                    disconnectDesktop()
                } label: {
                    Label(NSLocalizedString("Scan QR code", comment: ""), systemImage: "qrcode")
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Connecting to desktop", comment: ""))
        .modifier(ThemedBackground(grouped: true))
    }

    @ViewBuilder private func foundDesktopView(_ session: RemoteCtrlSession, _ rc: RemoteCtrlInfo, _ compatible: Bool) -> some View {
        List {
            Section(header: Text(NSLocalizedString("This device name", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                devicesView()
            }
            Section(header: Text(NSLocalizedString("Found desktop", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                ctrlDeviceNameText(session, rc)
                ctrlDeviceVersionText(session)
                if !compatible {
                    Text(NSLocalizedString("Not compatible!", comment: "")).foregroundColor(QuantumColors.error)
                } else {
                    Button {
                        confirmKnownDesktop(rc)
                    } label: {
                        Label(NSLocalizedString("Connect", comment: ""), systemImage: "checkmark")
                    }
                }
            }
            if !compatible {
                Section {
                    disconnectButton(LocalizedStringKey(NSLocalizedString("Cancel", comment: "")))
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Found desktop", comment: ""))
        .modifier(ThemedBackground(grouped: true))
    }

    private func verifySessionView(_ session: RemoteCtrlSession, _ rc: RemoteCtrlInfo?, _ sessCode: String) -> some View {
        List {
            Section(header: Text(NSLocalizedString("Connected to desktop", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                ctrlDeviceNameText(session, rc)
                ctrlDeviceVersionText(session)
            }

            Section(header: Text(NSLocalizedString("Verify code with desktop", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                sessionCodeText(sessCode)
                Button {
                    verifyDesktopSessionCode(sessCode)
                } label: {
                    Label(NSLocalizedString("Confirm", comment: ""), systemImage: "checkmark")
                }
            }

            Section {
                disconnectButton()
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Verify connection", comment: ""))
        .modifier(ThemedBackground(grouped: true))
    }

    private func ctrlDeviceNameText(_ session: RemoteCtrlSession, _ rc: RemoteCtrlInfo?) -> Text {
        var t = Text(rc?.deviceViewName ?? session.ctrlAppInfo?.deviceName ?? "")
        if (rc == nil) {
            t = t + textSpace + Text(NSLocalizedString("connect_device_new", comment: "")).italic()
        }
        return t
    }

    private func ctrlDeviceVersionText(_ session: RemoteCtrlSession) -> Text {
        let v = session.ctrlAppInfo?.appVersionRange.maxVersion
        var t = Text(verbatim: "v\(v ?? "")")
        if v != session.appVersion {
            t = t + textSpace + Text(String(format: NSLocalizedString("connect_this_device_version", comment: ""), session.appVersion)).italic()
        }
        return t
    }

    private func activeSessionView(_ session: RemoteCtrlSession, _ rc: RemoteCtrlInfo) -> some View {
        List {
            Section(header: Text(NSLocalizedString("Connected desktop", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                Text(rc.deviceViewName)
                ctrlDeviceVersionText(session)
            }

            if let sessCode = session.sessionCode {
                Section(header: Text(NSLocalizedString("Session code", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                    .textCase(.uppercase)) {
                    sessionCodeText(sessCode)
                }
            }

            Section {
                disconnectButton()
            } footer: {
                // This is specific to iOS
                Text(NSLocalizedString("Keep the app open to use it from desktop", comment: ""))
                    .foregroundColor(theme.colors.secondary)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Connected to desktop", comment: ""))
        .modifier(ThemedBackground(grouped: true))
    }

    private func sessionCodeText(_ code: String) -> some View {
        Text(code.prefix(23))
    }

    private func devicesView() -> some View {
        Group {
            Text(m.currentUser?.displayName ?? "")
            if !remoteCtrls.isEmpty {
                NavigationLink {
                    linkedDesktopsView()
                } label: {
                    Text(NSLocalizedString("Linked desktops", comment: ""))
                }
            }
        }
    }

    private func scanDesctopAddressView() -> some View {
        Section(header: Text(NSLocalizedString("Scan QR code from desktop", comment: ""))
            .font(.caption.weight(.bold))
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
            .textCase(.uppercase)) {
            ScannerInView(showQRCodeScanner: $showQRCodeScanner,  processQRCode: processDesktopQRCode, scanMode: .oncePerCode)
        }
    }

    private func desktopAddressView() -> some View {
        Section(header: Text(NSLocalizedString("Desktop address", comment: ""))
            .font(.caption.weight(.bold))
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
            .textCase(.uppercase)) {
            if sessionAddress.isEmpty {
                Button {
                    sessionAddress = UIPasteboard.general.string ?? ""
                } label: {
                    Label(NSLocalizedString("Paste desktop address", comment: ""), systemImage: "doc.plaintext")
                }
                .disabled(!UIPasteboard.general.hasStrings)
            } else {
                HStack {
                    Text(sessionAddress).lineLimit(1)
                    Spacer()
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(theme.colors.secondary)
                        .onTapGesture { sessionAddress = "" }
                }
            }
            Button {
                connectDesktopAddress(sessionAddress)
            } label: {
                Label(NSLocalizedString("Connect to desktop", comment: ""), systemImage: "rectangle.connected.to.line.below")
            }
            .disabled(sessionAddress.isEmpty)
        }
    }

    private func linkedDesktopsView() -> some View {
        List {
            Section(header: Text(NSLocalizedString("Desktop devices", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                ForEach(remoteCtrls, id: \.remoteCtrlId) { rc in
                    remoteCtrlView(rc)
                }
                .onDelete { indexSet in
                    if let i = indexSet.first, i < remoteCtrls.count {
                        alert = .unlinkDesktop(rc: remoteCtrls[i])
                    }
                }
            }

            Section(header: Text(NSLocalizedString("Linked desktop options", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                .textCase(.uppercase)) {
                Toggle(NSLocalizedString("Verify connections", comment: ""), isOn: $confirmRemoteSessions)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Linked desktops", comment: ""))
        .modifier(ThemedBackground(grouped: true))
    }

    private func remoteCtrlView(_ rc: RemoteCtrlInfo) -> some View {
        Text(rc.deviceViewName)
    }


    private func setDeviceName() {
        guard let name = m.currentUser?.displayName else { return }
        do {
            try setLocalDeviceName(name)
        } catch let e {
            errorAlert(e)
        }
    }

    private func updateRemoteCtrls() {
        do {
            remoteCtrls = try listRemoteCtrls()
        } catch let e {
            errorAlert(e)
        }
    }

    private func processDesktopQRCode(_ resp: Result<ScanResult, ScanError>) {
        switch resp {
        case let .success(r): connectDesktopAddress(r.string)
        case let .failure(e): errorAlert(e)
        }
    }

    private func confirmKnownDesktop(_ rc: RemoteCtrlInfo) {
        connectDesktop_ {
            try await confirmRemoteCtrl(rc.remoteCtrlId)
        }
    }

    private func connectDesktopAddress(_ addr: String) {
        connectDesktop_ {
            try await connectRemoteCtrl(desktopAddress: addr)
        }
    }

    private func connectDesktop_(_ connect: @escaping () async throws -> (RemoteCtrlInfo?, CtrlAppInfo, String)) {
        Task {
            do {
                let (rc_, ctrlAppInfo, v) = try await connect()
                await MainActor.run {
                    sessionAddress = ""
                    m.remoteCtrlSession = RemoteCtrlSession(
                        ctrlAppInfo: ctrlAppInfo,
                        appVersion: v,
                        sessionState: .connecting(remoteCtrl_: rc_)
                    )
                }
            } catch let e {
                await MainActor.run {
                    switch e as? ChatError {
                    case .errorRemoteCtrl(.badInvitation): alert = .badInvitationError
                    case .error(.commandError): alert = .badInvitationError
                    case let .errorRemoteCtrl(.badVersion(v)): alert = .badVersionError(version: v)
                    case .errorAgent(.RCP(.version)): alert = .badVersionError(version: nil)
                    case .errorAgent(.RCP(.ctrlAuth)): alert = .desktopDisconnectedError
                    default: errorAlert(e)
                    }
                }
            }
        }
    }

    private func verifyDesktopSessionCode(_ sessCode: String) {
        Task {
            do {
                let rc = try await verifyRemoteCtrlSession(sessCode)
                await MainActor.run {
                    m.remoteCtrlSession = m.remoteCtrlSession?.updateState(.connected(remoteCtrl: rc, sessionCode: sessCode))
                }
                await MainActor.run {
                    updateRemoteCtrls()
                }
            } catch let error {
                await MainActor.run {
                    errorAlert(error)
                }
            }
        }
    }

    private func disconnectButton(_ label: LocalizedStringKey = LocalizedStringKey(NSLocalizedString("Disconnect", comment: ""))) -> some View {
        Button {
            disconnectDesktop(.dismiss)
        } label: {
            Label(label, systemImage: "multiply")
        }
    }

    private func disconnectDesktop(_ action: UserDisconnectAction? = nil) {
        Task {
            do {
                try await stopRemoteCtrl()
                await MainActor.run {
                    if case .connected = m.remoteCtrlSession?.sessionState {
                        switchToLocalSession()
                    } else {
                        m.remoteCtrlSession = nil
                    }
                    switch action {
                    case .back: dismiss()
                    case .dismiss: dismiss()
                    case .none: ()
                    }
                }
            } catch let e {
                await MainActor.run {
                    errorAlert(e)
                }
            }
        }
    }

    private func unlinkDesktop(_ rc: RemoteCtrlInfo) {
        Task {
            do {
                try await deleteRemoteCtrl(rc.remoteCtrlId)
                await MainActor.run {
                    remoteCtrls.removeAll(where: { $0.remoteCtrlId == rc.remoteCtrlId })
                }
            } catch let e {
                await MainActor.run {
                    errorAlert(e)
                }
            }
        }
    }

    private func errorAlert(_ error: Error) {
        let a = getErrorAlert(error, LocalizedStringKey(NSLocalizedString("Error", comment: "")))
        alert = .error(title: a.title, error: a.message)
    }
}

#Preview {
    ConnectDesktopView()
        .previewEnvironment()
}
