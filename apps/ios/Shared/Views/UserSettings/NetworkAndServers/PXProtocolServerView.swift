//
//  SMPServerView.swift
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

struct PXProtocolServerEditor: View {
    // MARK: - POPOPX extracted constants
    private enum PXProtocolLayoutConfig {
        static let editorHeight: CGFloat = 144
        static let editorPadding: CGFloat = -6
        static let pickerFrameHeight: CGFloat = 36
        static let qrInset: CGFloat = 12
        static let progressScale: CGFloat = 2
        static let darkHeaderOpacity: Double = 0.92
    }

    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    @Binding var server: UserServer
    @State var serverToEdit: UserServer
    var backLabel: String
    @State private var showTestFailure = false
    @State private var testing = false
    @State private var testFailure: ProtocolTestFailure?

    var body: some View {
        ZStack {
            if server.preset {
                presetServer()
            } else {
                customServer()
            }
            if testing {
                ProgressView().scaleEffect(2)
            }
        }
        .modifier(BackButton(label: backLabel, disabled: Binding.constant(false)) {
            if let (serverToEditProtocol, serverToEditOperator) = serverProtocolAndOperator(serverToEdit, userServers),
               let (serverProtocol, serverOperator) = serverProtocolAndOperator(server, userServers) {
                if serverToEditProtocol != serverProtocol {
                    dismiss()
                    showAlert(
                        NSLocalizedString("settings_error_updating_server", comment: "Error updating server alert title"),
                        message: NSLocalizedString("settings_server_protocol_changed", comment: "Server protocol changed message")
                    )
                } else if serverToEditOperator != serverOperator {
                    dismiss()
                    showAlert(
                        NSLocalizedString("settings_error_updating_server", comment: "Error updating server alert title"),
                        message: NSLocalizedString("settings_server_operator_changed", comment: "Server operator changed message")
                    )
                } else {
                    server = serverToEdit
                    validateServers_($userServers, $serverErrors, $serverWarnings)
                    dismiss()
                }
            } else {
                dismiss()
                showAlert(
                    NSLocalizedString("settings_invalid_server_address", comment: "Invalid server address alert title"),
                    message: NSLocalizedString("settings_check_server_address_retry", comment: "Check server address and try again message")
                )
            }
        })
        .alert(isPresented: $showTestFailure) {
            Alert(
                title: Text(NSLocalizedString("settings_server_test_failed_title", comment: "Server test failed alert title")),
                message: Text(testFailure?.localizedDescription ?? "")
            )
        }
        .onChange(of: serverToEdit.server) {_, _ in
            serverToEdit.tested = serverToEdit.server == server.server ? server.tested : nil
        }
        .popopxBranded()
    }

    private func presetServer() -> some View {
        logger.debug("px: PXProtocolServerEditor.presetServer")
        return VStack {
            List {
                Section(header: Text(NSLocalizedString("settings_preset_server_address", comment: "Preset server address header")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                    Text(serverToEdit.server)
                        .textSelection(.enabled)
                }
                useServerSection(true)
                if let inherited = serverRolesInherited {
                    serverRolesSection(inherited: inherited)
                }
            }
        }
    }

    private func customServer() -> some View {
        logger.debug("px: PXProtocolServerEditor.customServer")
        return VStack {
            let serverAddress = parseServerAddress(serverToEdit.server)
            let valid = serverAddress?.valid == true
            List {
                Section {
                    TextEditor(text: $serverToEdit.server)
                        .multilineTextAlignment(.leading)
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .allowsTightening(true)
                        .lineLimit(10)
                        .frame(height: PXProtocolLayoutConfig.editorHeight)
                        .padding(PXProtocolLayoutConfig.editorPadding)
                } header: {
                    HStack {
                        Text(NSLocalizedString("settings_your_server_address", comment: "Your server address label"))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                        if !valid {
                            Spacer()
                            Image(systemName: "exclamationmark.circle").foregroundColor(theme.colors.error)
                        }
                    }
                }
                useServerSection(valid)
                if let inherited = serverRolesInherited {
                    serverRolesSection(inherited: inherited)
                }
                if valid {
                    Section(header: Text(NSLocalizedString("settings_add_to_another_device", comment: "Add to another device header")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                        PXMutableQRCode(uri: $serverToEdit.server, small: true)
                            .listRowInsets(EdgeInsets(top: PXProtocolLayoutConfig.qrInset, leading: PXProtocolLayoutConfig.qrInset, bottom: PXProtocolLayoutConfig.qrInset, trailing: PXProtocolLayoutConfig.qrInset))
                    }
                }
            }
        }
    }

    // inherited SMP roles for the per-server roles section, nil when the section should not be shown
    private var serverRolesInherited: ServerRoles? {
        guard let (serverProtocol, serverOperator) = serverProtocolAndOperator(serverToEdit, userServers),
              serverProtocol == .smp && serverToEdit.enabled, !serverToEdit.preset || serverToEdit.roles != ServerRolesOverride()
        else { return nil }
        return serverOperator?.smpRoles ?? ServerRoles.noOperatorDefault
    }

    private func serverRolesSection(inherited: ServerRoles) -> some View {
        Section {
            rolePicker(NSLocalizedString("settings_use_for_receive", comment: "To receive picker label"), $serverToEdit.roles.storage, defaultOn: inherited.storage)
            rolePicker(NSLocalizedString("settings_use_for_private_routing", comment: "For private routing picker label"), $serverToEdit.roles.proxy, defaultOn: inherited.proxy)
            rolePicker(NSLocalizedString("settings_use_for_name_resolution", comment: "To resolve names picker label"), $serverToEdit.roles.names, defaultOn: inherited.names)
        } header: {
            Text(NSLocalizedString("settings_use_for_messages", comment: "Use for messages header")).foregroundColor(theme.colors.secondary)
        }
    }

    private func rolePicker(_ title: String, _ selection: Binding<Bool?>, defaultOn: Bool) -> some View {
        Picker(title, selection: selection) {
            Text(String.localizedStringWithFormat(NSLocalizedString("settings_default_format", comment: "Default format string"), NSLocalizedString(defaultOn ? "settings_yes_option" : "settings_no_option", comment: "Yes/No option"))).tag(Bool?.none)
            Text(NSLocalizedString("settings_yes_option", comment: "Yes option")).tag(Bool?.some(true))
            Text(NSLocalizedString("settings_no_option", comment: "No option")).tag(Bool?.some(false))
        }
        .frame(height: PXProtocolLayoutConfig.pickerFrameHeight)
    }

    private func useServerSection(_ valid: Bool) -> some View {
        Section(header: Text(NSLocalizedString("settings_use_server_header", comment: "Use server header")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
            HStack {
                Button(NSLocalizedString("settings_test_server_button", comment: "Test server button")) {
                    testing = true
                    serverToEdit.tested = nil
                    Task {
                        if let f = await testServerConnection(server: $serverToEdit) {
                            showTestFailure = true
                            testFailure = f
                        }
                        await MainActor.run { testing = false }
                    }
                }
                .disabled(!valid || testing)
                Spacer()
                showTestStatus(server: serverToEdit)
            }
            Toggle(NSLocalizedString("settings_use_for_new_connections", comment: "Use for new connections toggle"), isOn: $serverToEdit.enabled)
        }
    }
}

struct BackButton: ViewModifier {
    var label: String = "Back"
    @Binding var disabled: Bool
    var action: () -> Void

    func body(content: Content) -> some View {
        content
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: action) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(verbatim: label)
                    }
                }
                .disabled(disabled)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }
}

@ViewBuilder func showTestStatus(server: UserServer) -> some View {
    switch server.tested {
    case .some(true):
        Image(systemName: "checkmark")
            .foregroundColor(QuantumColors.success)
    case .some(false):
        Image(systemName: "multiply")
            .foregroundColor(QuantumColors.error)
    case .none:
        Color.clear
    }
}

func testServerConnection(server: Binding<UserServer>) async -> ProtocolTestFailure? {
    do {
        let r = try await testProtoServer(server: server.wrappedValue.server)
        switch r {
        case .success:
            await MainActor.run { server.wrappedValue.tested = true }
            return nil
        case let .failure(f):
            await MainActor.run { server.wrappedValue.tested = false }
            return f
        }
    } catch let error {
        logger.error("testServerConnection \(responseError(error))")
        await MainActor.run {
            server.wrappedValue.tested = false
        }
        return nil
    }
}

struct PXProtocolServerEditor_Previews: PreviewProvider {
    static var previews: some View {
        PXProtocolServerEditor(
            userServers: Binding.constant([UserOperatorServers.sampleDataNilOperator]),
            serverErrors: Binding.constant([]),
            serverWarnings: Binding.constant([]),
            server: Binding.constant(UserServer.sampleData.custom),
            serverToEdit: UserServer.sampleData.custom,
            backLabel: "Your SMP servers"
        )
    }
}

// MARK: - POPOPX
extension PXProtocolServerEditor {
    var pxComponentTag: String { "PX_PROTOCOL_SERVER_VIEW" }
    var pxIsPresetMode: Bool { server.preset }
    var pxHasTestFailure: Bool { testFailure != nil }
}
