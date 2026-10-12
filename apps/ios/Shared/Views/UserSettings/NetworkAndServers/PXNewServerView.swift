//
//  NewServerView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 13.11.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX UI Configuration
private enum PXNewServerConfig {
    static let textEditorHeight: CGFloat = 144
    static let textEditorPadding: CGFloat = -6
    static let qrCodeInset: CGFloat = 12
    static let errorIconName: String = "exclamationmark.circle"
    static let sectionHeaderDarkOpacity: Double = 0.9
}

// MARK: - POPOPX View Model (theme-aware styling)
struct PXNewServerViewModel {
    let theme: AppTheme

    var pxSectionFont: Font {
        isInDarkTheme() ? darkThemeHeaderFont() : .body
    }

    var pxSectionColor: Color {
        isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary
    }

    var pxErrorColor: Color {
        theme.colors.error
    }
}

struct NewServerView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    @State private var serverToEdit: UserServer = .empty
    @State private var showTestFailure = false
    @State private var testing = false
    @State private var testFailure: ProtocolTestFailure?

    private var pxVM: PXNewServerViewModel {
        PXNewServerViewModel(theme: theme)
    }

    private var pxServerAddressParsed: ServerAddress? {
        parseServerAddress(serverToEdit.server)
    }

    private var pxIsAddressValid: Bool {
        pxServerAddressParsed?.valid == true
    }

    private var pxServerEditorFrame: some ViewModifier {
        FrameModifier(height: PXNewServerConfig.textEditorHeight)
    }

    var body: some View {
        ZStack {
            pxCustomServerView()
            if testing {
                ProgressView().scaleEffect(2)
            }
        }
        .modifier(BackButton(disabled: Binding.constant(false)) {
            addServer(serverToEdit, $userServers, $serverErrors, $serverWarnings, dismiss)
        })
        .alert(isPresented: $showTestFailure) {
            Alert(
                title: Text(NSLocalizedString("Server test failed!", comment: "Alert title when server connection test fails")),
                message: Text(testFailure?.localizedDescription ?? "")
            )
        }
        .accessibilityElement(children: .contain)
        .popopxBranded()
    }

    // TODO [TODO-FEATURE: low] Refactor - similar functions in PXProtocolServerEditor
    @ViewBuilder
    private func pxCustomServerView() -> some View {
        VStack {
            let serverAddress = pxServerAddressParsed
            let valid = serverAddress?.valid == true
            List {
                pxServerAddressSection(isValid: valid)
                pxUseServerSection(isValid: valid)
                if valid {
                    pxQRCodeSection()
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
    }

    // MARK: - POPOPX Section Builders

    @ViewBuilder
    private func pxServerAddressSection(isValid valid: Bool) -> some View {
        Section {
            TextEditor(text: $serverToEdit.server)
                .multilineTextAlignment(.leading)
                .autocorrectionDisabled(true)
                .autocapitalization(.none)
                .allowsTightening(true)
                .lineLimit(10)
                .frame(height: PXNewServerConfig.textEditorHeight)
                .padding(PXNewServerConfig.textEditorPadding)
        } header: {
            pxSectionHeader(
                title: NSLocalizedString("Your server address", comment: "Section header for server address input field"),
                showError: !valid
            )
        }
    }

    @ViewBuilder
    private func pxUseServerSection(isValid valid: Bool) -> some View {
        Section(header: pxSectionHeaderView(NSLocalizedString("Use server", comment: "Section header for server usage options"))) {
            HStack {
                Button(NSLocalizedString("Test server", comment: "Button to test server connection")) {
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
                .accessibilityLabel(Text(NSLocalizedString("Test server", comment: "Button to test server connection")))
                Spacer()
                showTestStatus(server: serverToEdit)
            }
            Toggle(NSLocalizedString("Use for new connections", comment: "Toggle to enable server for new chat connections"), isOn: $serverToEdit.enabled)
        }
    }

    @ViewBuilder
    private func pxQRCodeSection() -> some View {
        Section(header: pxSectionHeaderView(NSLocalizedString("Add to another device", comment: "Section header for QR code to add server on other devices"))) {
            PXMutableQRCode(uri: $serverToEdit.server, small: true)
                .listRowInsets(pxQREdgeInsets)
        }
    }

    // MARK: - POPOPX Helpers

    private var pxQREdgeInsets: EdgeInsets {
        EdgeInsets(
            top: PXNewServerConfig.qrCodeInset,
            leading: PXNewServerConfig.qrCodeInset,
            bottom: PXNewServerConfig.qrCodeInset,
            trailing: PXNewServerConfig.qrCodeInset
        )
    }

    @ViewBuilder
    private func pxSectionHeader(title: String, showError: Bool) -> some View {
        HStack {
            Text(title)
                .font(pxVM.pxSectionFont)
                .foregroundColor(pxVM.pxSectionColor)
            if showError {
                Spacer()
                Image(systemName: PXNewServerConfig.errorIconName)
                    .foregroundColor(pxVM.pxErrorColor)
            }
        }
    }

    private func pxSectionHeaderView(_ title: String) -> some View {
        Text(title)
            .font(pxVM.pxSectionFont)
            .foregroundColor(pxVM.pxSectionColor)
    }
}

// MARK: - Frame helper modifier
private struct FrameModifier: ViewModifier {
    let height: CGFloat
    func body(content: Content) -> some View {
        content.frame(height: height)
    }
}

func serverProtocolAndOperator(_ server: UserServer, _ userServers: [UserOperatorServers]) -> (ServerProtocol, ServerOperator?)? {
    if let serverAddress = parseServerAddress(server.server) {
        let serverProtocol = serverAddress.serverProtocol
        let hostnames = serverAddress.hostnames
        let matchingOperator = userServers.compactMap { $0.operator }.first { op in
            op.serverDomains.contains { domain in
                hostnames.contains { hostname in
                    hostname.hasSuffix(domain)
                }
            }
        }
        return (serverProtocol, matchingOperator)
    } else {
        return nil
    }
}

func addServer(
    _ server: UserServer,
    _ userServers: Binding<[UserOperatorServers]>,
    _ serverErrors: Binding<[UserServersError]>,
    _ serverWarnings: Binding<[UserServersWarning]>? = nil,
    _ dismiss: DismissAction
) {
    if let (serverProtocol, matchingOperator) = serverProtocolAndOperator(server, userServers.wrappedValue) {
        if let i = userServers.wrappedValue.firstIndex(where: { $0.operator?.operatorId == matchingOperator?.operatorId }) {
            switch serverProtocol {
            case .smp: userServers[i].wrappedValue.smpServers.append(server)
            case .xftp: userServers[i].wrappedValue.xftpServers.append(server)
            }
            validateServers_(userServers, serverErrors, serverWarnings)
            dismiss()
            if let op = matchingOperator {
                showAlert(
                    NSLocalizedString("Operator server", comment: "alert title"),
                    message: String.localizedStringWithFormat(NSLocalizedString("Server added to operator %@.", comment: "alert message"), op.tradeName)
                )
            }
        } else { // Shouldn't happen
            dismiss()
            showAlert(NSLocalizedString("Error adding server", comment: "alert title"))
        }
    } else {
        dismiss()
        if server.server.trimmingCharacters(in: .whitespaces) != "" {
            showAlert(
                NSLocalizedString("Invalid server address!", comment: "alert title"),
                message: NSLocalizedString("Check server address and try again.", comment: "alert title")
            )
        }
    }
}

// MARK: - POPOPX
extension NewServerView {
    var pxComponentTag: String { "PX_NEW_SERVER_VIEW" }
}

extension NewServerView {
    static var pxComponentIdentity: String { "PX_NEW_SERVER_VIEW" }
}

#Preview {
    NewServerView(
        userServers: Binding.constant([UserOperatorServers.sampleDataNilOperator]),
        serverErrors: Binding.constant([]),
        serverWarnings: Binding.constant([])
    )
}
