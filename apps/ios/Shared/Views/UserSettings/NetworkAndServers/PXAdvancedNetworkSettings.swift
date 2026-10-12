//
//  PXNetworkConfig.swift
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

private let secondsLabel =  NSLocalizedString("sec", comment: "network option")

// MARK: - POPOPX Layout Constants
private let pxPickerFrameHeight: CGFloat = 38
private let pxTextEditorPadding: CGFloat = -7
private let pxQRCodeInset: CGFloat = 14

enum NetworkSettingsAlert: Identifiable {
    case update
    case error(err: String)

    var id: String {
        switch self {
        case .update: return "update"
        case let .error(err): return "error \(err)"
        }
    }
}

struct PXNetworkConfig: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false
    @State private var netCfg = NetCfg.defaults
    @State private var currentNetCfg = NetCfg.defaults
    @State private var cfgLoaded = false
    @State private var enableKeepAlive = true
    @State private var keepAliveOpts = KeepAliveOpts.defaults
    @State private var showSettingsAlert: NetworkSettingsAlert?
    @State private var onionHosts: OnionHosts = .no
    @State private var showSaveDialog = false
    @State private var netProxy = networkProxyDefault.get()
    @State private var currentNetProxy = networkProxyDefault.get()
    @State private var useNetProxy = false
    @State private var netProxyAuth = false

    private var portBinding: Binding<String> {
        Binding(
            get: { netProxy.port > 0 ? "\(netProxy.port)" : "" },
            set: { s in
                netProxy.port = if let port = Int(s), port > 0 {
                    port
                } else {
                    0
                }
            }
        )
    }

    @ViewBuilder
    private var proxyFieldsGroup: some View {
        TextField(LocalizedStringKey(NSLocalizedString("IP address", comment: "")), text: $netProxy.host)
        TextField(LocalizedStringKey(NSLocalizedString("Port", comment: "")), text: portBinding)
        Toggle(NSLocalizedString("net_proxy_requires_password", comment: "Proxy requires password toggle"), isOn: $netProxyAuth)
        if netProxyAuth {
            TextField(LocalizedStringKey(NSLocalizedString("Username", comment: "")), text: $netProxy.username)
            PassphraseField(
                key: $netProxy.password,
                placeholder: NSLocalizedString("net_password", comment: "Password field placeholder"),
                valid: NetworkProxy.validCredential(netProxy.password)
            )
        }
    }

    var body: some View {
        VStack {
            List {
                Section {
                    NavigationLink {
                        List {
                            Section {
                                SelectionListView(list: SMPProxyMode.values, selection: $netCfg.smpProxyMode) { mode in
                                    netCfg.smpProxyMode = mode
                                }
                            } footer: {
                                Text(proxyModeInfo(netCfg.smpProxyMode))
                                    .font(.callout)
                                    .foregroundColor(theme.colors.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .scrollContentBackground(.hidden)
                        .navigationTitle(NSLocalizedString("Private routing", comment: ""))
                        .modifier(ThemedBackground(grouped: true))
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text(NSLocalizedString("net_private_routing", comment: "Private routing settings row"))
                            Spacer()
                            Text(netCfg.smpProxyMode.label)
                        }
                    }

                    NavigationLink {
                        List {
                            Section {
                                SelectionListView(list: SMPProxyFallback.values, selection: $netCfg.smpProxyFallback) { mode in
                                    netCfg.smpProxyFallback = mode
                                }
                                .disabled(netCfg.smpProxyMode == .never)
                            } footer: {
                                Text(proxyFallbackInfo(netCfg.smpProxyFallback))
                                    .font(.callout)
                                    .foregroundColor(theme.colors.secondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .scrollContentBackground(.hidden)
                        .navigationTitle(NSLocalizedString("Allow downgrade", comment: ""))
                        .modifier(ThemedBackground(grouped: true))
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text(NSLocalizedString("net_allow_downgrade", comment: "Allow downgrade settings row"))
                            Spacer()
                            Text(netCfg.smpProxyFallback.label)
                        }
                    }

                    Toggle(NSLocalizedString("net_show_message_status", comment: "Show message status toggle"), isOn: $showSentViaProxy)
                } header: {
                    Text(NSLocalizedString("net_private_routing_header", comment: "Private message routing section header"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                } footer: {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("net_routing_ip_protection", comment: "Private routing IP address protection explanation"))
                        if showSentViaProxy {
                            Text(NSLocalizedString("net_routing_show_arrow", comment: "Show arrow on messages via private routing"))
                        }
                    }
                    .foregroundColor(theme.colors.secondary)
                }

                Section {
                    Toggle(NSLocalizedString("net_use_socks_proxy", comment: "Use SOCKS proxy toggle"), isOn: $useNetProxy)
                    Group {
                        proxyFieldsGroup
                    }
                    .if(!useNetProxy) { $0.foregroundColor(theme.colors.secondary) }
                    .disabled(!useNetProxy)
                } header: {
                    HStack {
                        Text(verbatim: NSLocalizedString("net_socks_proxy_header", comment: "SOCKS proxy section header"))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        if useNetProxy && !netProxy.valid {
                            Spacer()
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(QuantumColors.error)
                        }
                    }
                } footer: {
                    if netProxyAuth {
                        Text(verbatim: NSLocalizedString("net_credentials_unencrypted", comment: "Credentials may be sent unencrypted warning"))
                            .foregroundColor(theme.colors.secondary)
                    } else {
                        Text(verbatim: NSLocalizedString("net_no_credentials_proxy", comment: "Do not use credentials with proxy"))
                            .foregroundColor(theme.colors.secondary)
                    }
                }
                .onChange(of: useNetProxy) {_,  useNetProxy in
                    netCfg.socksProxy = useNetProxy && currentNetProxy.valid
                        ? currentNetProxy.toProxyString()
                        : nil
                    netProxy = currentNetProxy
                    netProxyAuth = netProxy.username != "" || netProxy.password != ""
                }
                .onChange(of: netProxyAuth) {_,  netProxyAuth in
                    if netProxyAuth {
                        netProxy.auth = currentNetProxy.auth
                        netProxy.username = currentNetProxy.username
                        netProxy.password = currentNetProxy.password
                    } else {
                        netProxy.auth = .username
                        netProxy.username = ""
                        netProxy.password = ""
                    }
                }
                .onChange(of: netProxy) {_,  netProxy in
                    netCfg.socksProxy = useNetProxy && netProxy.valid
                        ? netProxy.toProxyString()
                        : nil
                }

                Section {
                    Picker(NSLocalizedString("net_onion_hosts_picker", comment: "Use .onion hosts picker label"), selection: $onionHosts) {
                        ForEach(OnionHosts.values, id: \.self) { Text($0.text) }
                    }
                    .frame(height: pxPickerFrameHeight)
                } footer: {
                    Text(onionHostsInfo(onionHosts))
                        .foregroundColor(theme.colors.secondary)
                }
                .onChange(of: onionHosts) {_,  hosts in
                    if hosts != OnionHosts(netCfg: currentNetCfg) {
                        let (hostMode, requiredHostMode) = hosts.hostMode
                        netCfg.hostMode = hostMode
                        netCfg.requiredHostMode = requiredHostMode
                    }
                }

                if developerTools {
                    Section {
                        PXWrappedPicker(LocalizedStringKey(NSLocalizedString("network_transport_isolation", comment: "Transport isolation picker label")), selection: $netCfg.sessionMode) {
                            let modes = TransportSessionMode.values.contains(netCfg.sessionMode)
                                ? TransportSessionMode.values
                                : TransportSessionMode.values + [netCfg.sessionMode]
                            ForEach(modes, id: \.self) { Text($0.text) }
                        }
                    } footer: {
                        sessionModeInfo(netCfg.sessionMode)
                            .foregroundColor(theme.colors.secondary)
                    }
                }

                Section {
                    PXWrappedPicker(LocalizedStringKey(NSLocalizedString("net_use_web_port", comment: "Use web port picker label")), selection: $netCfg.smpWebPortServers) {
                        ForEach(SMPWebPortServers.allCases, id: \.self) { Text($0.text) }
                    }
                } header: {
                    Text(NSLocalizedString("net_tcp_port_header", comment: "TCP port for messaging section header"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                } footer: {
                    netCfg.smpWebPortServers == .preset
                    ? Text(NSLocalizedString("net_tcp_port_443_preset", comment: "Use TCP port 443 for preset servers"))
                    : Text(String(format: NSLocalizedString("net_tcp_port_format", comment: "Use TCP port when no port specified"), netCfg.smpWebPortServers == .all ? "443" : "5223"))
                }

                Section {
                    timeoutSettingPicker(LocalizedStringKey(NSLocalizedString("net_tcp_connect_timeout", comment: "TCP connection timeout picker")), selection: $netCfg.tcpConnectTimeout.interactiveTimeout, values: [10_000000, 15_000000, 20_000000, 30_000000], label: secondsLabel)
                    timeoutSettingPicker(LocalizedStringKey(NSLocalizedString("net_tcp_connect_bg_timeout", comment: "TCP connection background timeout picker")), selection: $netCfg.tcpConnectTimeout.backgroundTimeout, values: [30_000000, 45_000000, 60_000000, 90_000000], label: secondsLabel)
                    timeoutSettingPicker(LocalizedStringKey(NSLocalizedString("net_protocol_timeout", comment: "Protocol timeout picker")), selection: $netCfg.tcpTimeout.interactiveTimeout, values: [5_000000, 7_000000, 10_000000, 15_000000, 20_000000], label: secondsLabel)
                    timeoutSettingPicker(LocalizedStringKey(NSLocalizedString("net_protocol_bg_timeout", comment: "Protocol background timeout picker")), selection: $netCfg.tcpTimeout.backgroundTimeout, values: [15_000000, 20_000000, 30_000000, 45_000000, 60_000000], label: secondsLabel)
                    timeoutSettingPicker(LocalizedStringKey(NSLocalizedString("net_protocol_timeout_per_kb", comment: "Protocol timeout per KB picker")), selection: $netCfg.tcpTimeoutPerKb, values: [2_500, 5_000, 10_000, 15_000, 20_000, 30_000], label: secondsLabel)
                    // intSettingPicker("Receiving concurrency", selection: $netCfg.rcvConcurrency, values: [1, 2, 4, 8, 12, 16, 24], label: "")
                    timeoutSettingPicker(LocalizedStringKey(NSLocalizedString("net_ping_interval", comment: "PING interval picker")), selection: $netCfg.smpPingInterval, values: [120_000000, 300_000000, 600_000000, 1200_000000, 2400_000000, 3600_000000], label: secondsLabel)
                    intSettingPicker(LocalizedStringKey(NSLocalizedString("net_ping_count", comment: "PING count picker")), selection: $netCfg.smpPingCount, values: [1, 2, 3, 5, 8], label: "")
                    Toggle(NSLocalizedString("net_enable_keepalive", comment: "Enable TCP keep-alive toggle"), isOn: $enableKeepAlive)

                    if enableKeepAlive {
                        intSettingPicker(LocalizedStringKey(NSLocalizedString("net_keepidle", comment: "TCP_KEEPIDLE picker")), selection: $keepAliveOpts.keepIdle, values: [15, 30, 60, 120, 180], label: secondsLabel)
                        intSettingPicker(LocalizedStringKey(NSLocalizedString("net_keepintvl", comment: "TCP_KEEPINTVL picker")), selection: $keepAliveOpts.keepIntvl, values: [5, 10, 15, 30, 60], label: secondsLabel)
                        intSettingPicker(LocalizedStringKey(NSLocalizedString("net_keepcnt", comment: "TCP_KEEPCNT picker")), selection: $keepAliveOpts.keepCnt, values: [1, 2, 4, 6, 8], label: "")
                    } else {
                        Group {
                            Text(verbatim: "TCP_KEEPIDLE")
                            Text(verbatim: "TCP_KEEPINTVL")
                            Text(verbatim: "TCP_KEEPCNT")
                        }
                        .foregroundColor(theme.colors.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("net_tcp_connection", comment: "TCP connection section header"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                }

                Section {
                    Button(NSLocalizedString("net_reset_defaults", comment: "Reset to defaults button")) {
                        updateNetCfgView(NetCfg.defaults, NetworkProxy.def)
                    }
                    .disabled(netCfg == NetCfg.defaults)

                    Button(NSLocalizedString("net_set_proxy_timeouts", comment: "Set timeouts for proxy/VPN button")) {
                        updateNetCfgView(netCfg.withProxyTimeouts, netProxy)
                    }
                    .disabled(netCfg.hasProxyTimeouts)

                    Button(NSLocalizedString("net_save_reconnect", comment: "Save and reconnect button")) {
                        showSettingsAlert = .update
                    }
                    .disabled(netCfg == currentNetCfg || (useNetProxy && !netProxy.valid))
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
        }
        .onChange(of: keepAliveOpts) {_,  opts in
            netCfg.tcpKeepAlive = keepAliveOpts
        }
        .onChange(of: enableKeepAlive) {_,  on in
            netCfg.tcpKeepAlive = on ? (currentNetCfg.tcpKeepAlive ?? KeepAliveOpts.defaults) : nil
        }
        .onAppear {
            if cfgLoaded { return }
            cfgLoaded = true
            currentNetCfg = getNetCfg()
            currentNetProxy = networkProxyDefault.get()
            updateNetCfgView(currentNetCfg, currentNetProxy)
        }
        .alert(item: $showSettingsAlert) { a in
            switch a {
            case .update:
                return Alert(
                    title: Text(NSLocalizedString("net_update_settings_title", comment: "Update settings alert title")),
                    message: Text(NSLocalizedString("net_update_settings_message", comment: "Updating settings re-connects message")),
                    primaryButton: .default(Text(NSLocalizedString("net_ok", comment: "Ok button"))) {
                        _ = saveNetCfg()
                    },
                    secondaryButton: .cancel()
                )
            case let .error(err):
                return Alert(
                    title: Text(NSLocalizedString("net_update_error_title", comment: "Error updating settings alert title")),
                    message: Text(err)
                )
            }
        }
        .modifier(BackButton(disabled: Binding.constant(false)) {
            if netCfg == currentNetCfg {
                dismiss()
                cfgLoaded = false
            } else if !useNetProxy || netProxy.valid {
                showSaveDialog = true
            }
        })
        .confirmationDialog(NSLocalizedString("net_update_network_settings", comment: "Update network settings confirmation"), isPresented: $showSaveDialog, titleVisibility: .visible) {
            Button(NSLocalizedString("net_save_reconnect", comment: "Save and reconnect button")) {
                if saveNetCfg() {
                    dismiss()
                    cfgLoaded = false
                }
            }
            Button(NSLocalizedString("net_exit_without_saving", comment: "Exit without saving button")) { dismiss() }
        }
        .popopxBranded()
    }

    private func updateNetCfgView(_ cfg: NetCfg, _ proxy: NetworkProxy) {
        logger.debug("PX: [PXNetworkConfig.updateNetCfgView] called")
        netCfg = cfg
        netProxy = proxy
        onionHosts = OnionHosts(netCfg: netCfg)
        enableKeepAlive = netCfg.enableKeepAlive
        keepAliveOpts = netCfg.tcpKeepAlive ?? KeepAliveOpts.defaults
        useNetProxy = netCfg.socksProxy != nil
        netProxyAuth = switch netProxy.auth {
        case .username: netProxy.username != "" || netProxy.password != ""
        case .isolate: false
        }
    }

    private func saveNetCfg() -> Bool {
        logger.debug("PX: [PXNetworkConfig.saveNetCfg] called")
        do {
            try setNetworkConfig(netCfg)
            currentNetCfg = netCfg
            setNetCfg(netCfg, networkProxy: useNetProxy ? netProxy : nil)
            currentNetProxy = netProxy
            networkProxyDefault.set(netProxy)
            return true
        } catch let error {
            let err = responseError(error)
            showSettingsAlert = .error(err: err)
            logger.error("\(err)")
            return false
        }
    }

    private func intSettingPicker(_ title: LocalizedStringKey, selection: Binding<Int>, values: [Int], label: String) -> some View {
        Picker(title, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text("\(value) \(label)")
            }
        }
        .frame(height: pxPickerFrameHeight)
    }

    private func timeoutSettingPicker(_ title: LocalizedStringKey, selection: Binding<Int>, values: [Int], label: String) -> some View {
        PXWrappedPicker(title, selection: selection) {
            let v = selection.wrappedValue
            let vs = values.contains(v) ? values : values + [v]
            ForEach(vs, id: \.self) { value in
                Text("\(String(format: "%g", (Double(value) / 1000000))) \(secondsLabel)")
            }
        }
    }

    private func onionHostsInfo(_ hosts: OnionHosts) -> LocalizedStringKey {
        switch hosts {
        case .no: return LocalizedStringKey(NSLocalizedString("net_onion_not_used", comment: "Onion hosts will not be used"))
        case .prefer: return LocalizedStringKey(NSLocalizedString("net_onion_preferred", comment: "Onion hosts preferred with VPN note"))
        case .require: return LocalizedStringKey(NSLocalizedString("net_onion_required", comment: "Onion hosts required with VPN note"))
        }
    }

    private func sessionModeInfo(_ mode: TransportSessionMode) -> Text {
        let userMode = Text(NSLocalizedString("net_session_user_mode", comment: "Separate TCP connection per chat profile"))
        return switch mode {
        case .user: userMode
        case .session: userMode + textNewLine + Text(NSLocalizedString("net_session_new_socks", comment: "New SOCKS credentials on app start"))
        case .server: userMode + textNewLine + Text(NSLocalizedString("net_session_socks_per_server", comment: "New SOCKS credentials per server"))
        case .entity: Text(NSLocalizedString("net_session_entity_mode", comment: "Separate TCP connection per contact with battery warning"))
        }
    }

    private func proxyModeInfo(_ mode: SMPProxyMode) -> LocalizedStringKey {
        switch mode {
        case .always: return LocalizedStringKey(NSLocalizedString("net_proxy_always", comment: "Always use private routing"))
        case .unknown: return LocalizedStringKey(NSLocalizedString("net_proxy_unknown", comment: "Use private routing with unknown servers"))
        case .unprotected: return LocalizedStringKey(NSLocalizedString("net_proxy_unprotected", comment: "Use private routing when IP not protected"))
        case .never: return LocalizedStringKey(NSLocalizedString("net_proxy_never", comment: "Do NOT use private routing"))
        }
    }

    private func proxyFallbackInfo(_ proxyFallback: SMPProxyFallback) -> LocalizedStringKey {
        switch proxyFallback {
        case .allow: return LocalizedStringKey(NSLocalizedString("net_fallback_allow", comment: "Send directly when no private routing support"))
        case .allowProtected: return LocalizedStringKey(NSLocalizedString("net_fallback_allow_protected", comment: "Send directly when IP protected and no private routing"))
        case .prohibit: return LocalizedStringKey(NSLocalizedString("net_fallback_prohibit", comment: "Do NOT send directly"))
        }
    }
}

// MARK: - POPOPX
extension PXNetworkConfig {
    var pxComponentTag: String { "PX_ADVANCED_NETWORK_SETTINGS" }
}

struct PXNetworkConfig_Previews: PreviewProvider {
    static var previews: some View {
        PXNetworkConfig()
    }
}
