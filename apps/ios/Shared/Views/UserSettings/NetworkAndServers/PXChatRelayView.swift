//
//  PXChatRelay.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 23.02.2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

@ViewBuilder func showRelayTestStatus(relay: UserChatRelay) -> some View {
    switch relay.tested {
    case .some(true): Image(systemName: "checkmark").foregroundColor(QuantumColors.success)
    case .some(false): Image(systemName: "multiply").foregroundColor(QuantumColors.error)
    case .none: Color.clear
    }
}

func validRelayName(_ name: String) -> Bool {
    name != "" && validDisplayName(name)
}

func showInvalidRelayNameAlert(_ name: Binding<String>) {
    let validName = mkValidName(name.wrappedValue)
    if validName == "" {
        showAlert(NSLocalizedString("Invalid name!", comment: "alert title"))
    } else {
        showAlert(
            NSLocalizedString("Invalid name!", comment: "alert title"),
            message: String.localizedStringWithFormat(NSLocalizedString("Correct name to %@?", comment: "alert message"), validName),
            actions: {[
                UIAlertAction(title: NSLocalizedString("Ok", comment: "alert action"), style: .default) { _ in
                    name.wrappedValue = validName
                },
                cancelAlertAction
            ]}
        )
    }
}

func validRelayAddress(_ address: String) -> Bool {
    if let parsedMd = parseMarkdown(address),
       parsedMd.count == 1,
       case .popopxLink(_, .relay, _, _) = parsedMd.first?.format {
        true
    } else {
        false
    }
}

func addChatRelay(
    _ relay: UserChatRelay,
    _ userServers: Binding<[UserOperatorServers]>,
    _ serverErrors: Binding<[UserServersError]>,
    _ serverWarnings: Binding<[UserServersWarning]>? = nil,
    _ dismiss: DismissAction
) {
    let nameEmpty = relay.displayName.trimmingCharacters(in: .whitespaces).isEmpty
    let addressEmpty = relay.address.trimmingCharacters(in: .whitespaces).isEmpty
    if nameEmpty && addressEmpty {
        dismiss()
    } else if !validRelayName(relay.displayName) {
        dismiss()
        showAlert(
            NSLocalizedString("Invalid relay name!", comment: "alert title"),
            message: NSLocalizedString("Check relay name and try again.", comment: "alert message")
        )
    } else if !validRelayAddress(relay.address) {
        dismiss()
        showAlert(
            NSLocalizedString("Invalid relay address!", comment: "alert title"),
            message: NSLocalizedString("Check relay address and try again.", comment: "alert message")
        )
    } else if let i = userServers.wrappedValue.firstIndex(where: { $0.operator == nil }) {
        userServers[i].wrappedValue.chatRelays.append(relay)
        validateServers_(userServers, serverErrors, serverWarnings)
        dismiss()
    } else { // Shouldn't happen
        dismiss()
        showAlert(NSLocalizedString("Error adding relay", comment: "alert title"))
    }
}

// MARK: - POPOPX extracted constants & view model

private enum PXChatRelayConfig {
    static let editorHeight: CGFloat = 144
    static let editorPadding: CGFloat = -6
    static let iconWidth: CGFloat = 16
    static let iconTrailingPadding: CGFloat = 4
    static let progressScale: CGFloat = 2
    static let deleteButtonCornerRadius: CGFloat = 12
    static let testButtonMinWidth: CGFloat = 120
    static let sectionHeaderOpacity: Double = 0.85
    static let progressOverlayOpacity: Double = 0.25
    static let sectionVerticalSpacing: CGFloat = 12
    static let addressLineLimit: Int = 10
    static let testAlertIconName: String = "exclamationmark.circle"
    static let deleteIconName: String = "trash"
    static let successIconName: String = "checkmark"
    static let failureIconName: String = "multiply"
    static let disabledIconName: String = "slash.circle"
    static let componentTag: String = "PX_CHAT_RELAY_VIEW"
    static let linkComponentTag: String = "PX_CHAT_RELAY_VIEW_LINK"
    static let newComponentTag: String = "PX_NEW_CHAT_RELAY_VIEW"
}

private struct PXChatRelayViewModel {
    let relay: UserChatRelay

    var isValidName: Bool { validRelayName(relay.displayName) }
    var isValidAddress: Bool { validRelayAddress(relay.address) }
    var isFullyValid: Bool { isValidName && isValidAddress }
    var isTested: Bool { relay.tested == true }
    var isTestedNegative: Bool { relay.tested == false }
    var isTestPending: Bool { relay.tested == nil }
    var isPreset: Bool { relay.preset }
    var displayAddress: String { relay.address }
    var displayNameOrFallback: String {
        !relay.displayName.isEmpty ? relay.displayName : (relay.domains.first ?? relay.address)
    }
}

struct PXChatRelay: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    @Binding var relay: UserChatRelay
    @State var relayToEdit: UserChatRelay
    var backLabel: String
    @State private var showTestFailure = false
    @State private var testing = false
    @State private var testFailure: RelayTestFailure?

    private var vm: PXChatRelayViewModel { PXChatRelayViewModel(relay: relayToEdit) }

    var body: some View {
        ZStack {
            relayModeContainer
            if testing {
                ProgressView()
                    .scaleEffect(PXChatRelayConfig.progressScale)
                    .opacity(PXChatRelayConfig.progressOverlayOpacity)
            }
        }
        .modifier(BackButton(label: backLabel, disabled: Binding.constant(false)) {
            pxHandleBackNavigation()
        })
        .alert(isPresented: $showTestFailure) {
            Alert(
                title: Text(NSLocalizedString("relay_test_failed_title", comment: "Alert title when relay test fails")),
                message: Text(verbatim: testFailure?.localizedDescription ?? "")
            )
        }
        .onChange(of: relayToEdit.address) {_, _ in
            pxSyncTestStateOnAddressChange()
        }
        .popopxBranded()
    }

    // MARK: - POPOPX ViewBuilder helpers

    @ViewBuilder
    private var relayModeContainer: some View {
        if relay.preset {
            presetRelay()
        } else {
            customRelay(validName: vm.isValidName, validAddress: vm.isValidAddress)
        }
    }

    private func relaySectionHeader(_ text: String) -> some View {
        Text(text)
            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            .opacity(PXChatRelayConfig.sectionHeaderOpacity)
    }

    private func relayNameHeader(validName: Bool) -> some View {
        HStack {
            Text(NSLocalizedString("your_relay_name", comment: "Label for relay name field"))
                .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            if !validName {
                Spacer()
                Image(systemName: PXChatRelayConfig.testAlertIconName)
                    .foregroundColor(theme.colors.error)
                    .onTapGesture { showInvalidRelayNameAlert($relayToEdit.displayName) }
                    .accessibilityLabel(NSLocalizedString("Invalid relay name warning", comment: "Accessibility"))
            }
        }
    }

    private func presetRelay() -> some View {
        logger.debug("px: PXChatRelay.presetRelay")
        return List {
            Section(header: relaySectionHeader(NSLocalizedString("preset_relay_address", comment: "Section header for preset relay address"))) {
                Text(relayToEdit.address)
                    .textSelection(.enabled)
            }
            Section(header: relaySectionHeader(NSLocalizedString("preset_relay_name", comment: "Section header for preset relay name"))) {
                Text(relayToEdit.displayName)
            }
            useRelaySection()
        }
    }

    private func customRelay(validName: Bool, validAddress: Bool) -> some View {
        logger.debug("px: PXChatRelay.customRelay")
        return List {
            Section {
                TextEditor(text: $relayToEdit.address)
                    .multilineTextAlignment(.leading)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .allowsTightening(true)
                    .lineLimit(PXChatRelayConfig.addressLineLimit)
                    .frame(height: PXChatRelayConfig.editorHeight)
                    .padding(PXChatRelayConfig.editorPadding)
            } header: {
                HStack {
                    Text(NSLocalizedString("your_relay_address", comment: "Label for relay address field"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                    if !validAddress {
                        Spacer()
                        Image(systemName: PXChatRelayConfig.testAlertIconName)
                            .foregroundColor(theme.colors.error)
                            .accessibilityLabel(NSLocalizedString("Invalid relay address warning", comment: "Accessibility"))
                    }
                }
            }
            Section {
                TextField(NSLocalizedString("enter_relay_name_placeholder", comment: "Placeholder for relay name input"), text: $relayToEdit.displayName)
                    .autocorrectionDisabled(true)
                    .disabled(vm.isTested)
            } header: {
                relayNameHeader(validName: validName)
            } footer: {
                if vm.isTestPending {
                    Text(NSLocalizedString("test_relay_footer", comment: "Footer hint to test relay"))
                }
            }
            useRelaySection(valid: validAddress)
            Section {
                Button(role: .destructive) {
                    relay.deleted = true
                    validateServers_($userServers, $serverErrors, $serverWarnings)
                    dismiss()
                } label: {
                    Label(NSLocalizedString("delete_relay", comment: "Button to delete relay"), systemImage: PXChatRelayConfig.deleteIconName)
                        .foregroundColor(theme.colors.error)
                }
                .accessibilityLabel(NSLocalizedString("Delete this relay", comment: "Accessibility"))
            }
        }
    }

    private func useRelaySection(valid: Bool = true) -> some View {
        Section(header: relaySectionHeader(NSLocalizedString("use_relay", comment: "Section header for using relay"))) {
            HStack {
                Button(NSLocalizedString("test_relay_button", comment: "Button to test relay connection")) {
                    pxExecuteRelayTest()
                }
                .disabled(!valid || testing)
                .accessibilityLabel(NSLocalizedString("Test relay connection", comment: "Accessibility"))
                Spacer()
                showRelayTestStatus(relay: relayToEdit)
            }
            Toggle(NSLocalizedString("use_for_new_channels", comment: "Toggle to enable relay for new channels"), isOn: $relayToEdit.enabled)
                .accessibilityLabel(NSLocalizedString("Use relay for new channels", comment: "Accessibility"))
        }
    }

    // MARK: - POPOPX actions

    private func pxHandleBackNavigation() {
        if vm.isFullyValid {
            relay = relayToEdit
            validateServers_($userServers, $serverErrors, $serverWarnings)
            dismiss()
        } else if !vm.isValidName {
            dismiss()
            showAlert(
                NSLocalizedString("Invalid relay name!", comment: "alert title"),
                message: NSLocalizedString("Check relay name and try again.", comment: "alert message")
            )
        } else {
            dismiss()
            showAlert(
                NSLocalizedString("Invalid relay address!", comment: "alert title"),
                message: NSLocalizedString("Check relay address and try again.", comment: "alert message")
            )
        }
    }

    private func pxSyncTestStateOnAddressChange() {
        if relayToEdit.address == relay.address {
            relayToEdit.tested = relay.tested
            relayToEdit.displayName = relay.displayName
        } else {
            relayToEdit.tested = nil
        }
    }

    private func pxExecuteRelayTest() {
        testing = true
        relayToEdit.tested = nil
        Task {
            if let f = await testRelayConnection(relay: $relayToEdit) {
                showTestFailure = true
                testFailure = f
            }
            await MainActor.run { testing = false }
        }
    }
}

struct PXChatRelayLink: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    @Binding var relay: UserChatRelay
    var duplicateRelayAddresses: Set<String>
    var backLabel: String
    @Binding var selectedServer: String?

    private var isDuplicate: Bool { duplicateRelayAddresses.contains(relay.address) }
    private var linkDisplayName: String {
        !relay.displayName.isEmpty ? relay.displayName : (relay.domains.first ?? relay.address)
    }

    var body: some View {
        NavigationLink {
            PXChatRelay(
                userServers: $userServers,
                serverErrors: $serverErrors,
                serverWarnings: $serverWarnings,
                relay: $relay,
                relayToEdit: relay,
                backLabel: backLabel
            )
            .navigationTitle(NSLocalizedString("chat_relay_nav_title", comment: "Chat relay navigation title"))
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
        } label: {
            HStack {
                Group {
                    pxLinkLeadingIcon
                }
                .frame(width: 16, alignment: .center)
                .padding(.trailing, 4)

                pxLinkDisplayNameText
            }
        }
        .navigationTitle(NSLocalizedString("chat_relay_nav_title", comment: "Navigation title for chat relay settings"))
    }

    // MARK: - POPOPX link subviews

    @ViewBuilder
    private var pxLinkLeadingIcon: some View {
        if isDuplicate {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(QuantumColors.error)
                .accessibilityLabel(NSLocalizedString("Duplicate relay address", comment: "Accessibility"))
        } else if !relay.enabled {
            Image(systemName: "slash.circle")
                .foregroundColor(theme.colors.secondary)
                .accessibilityLabel(NSLocalizedString("Relay disabled", comment: "Accessibility"))
        } else {
            showRelayTestStatus(relay: relay)
        }
    }

    private var pxLinkDisplayNameText: some View {
        Group {
            let v = Text(linkDisplayName).lineLimit(1)
            if relay.enabled {
                v
            } else {
                v.foregroundColor(theme.colors.secondary)
            }
        }
    }
}

struct PXNewChatRelay: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]
    @State private var relayToEdit = UserChatRelay(
        chatRelayId: nil, address: "", name: "", domains: [],
        preset: false, tested: nil, enabled: true, deleted: false
    )
    @State private var showTestFailure = false
    @State private var testing = false
    @State private var testFailure: RelayTestFailure?

    private var newVM: PXChatRelayViewModel { PXChatRelayViewModel(relay: relayToEdit) }

    var body: some View {
        ZStack {
        List {
            Section {
                TextEditor(text: $relayToEdit.address)
                    .multilineTextAlignment(.leading)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .allowsTightening(true)
                    .lineLimit(PXChatRelayConfig.addressLineLimit)
                    .frame(height: PXChatRelayConfig.editorHeight)
                    .padding(PXChatRelayConfig.editorPadding)
            } header: {
                HStack {
                    Text(NSLocalizedString("your_relay_address", comment: "Label for relay address field"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                    if !newVM.isValidAddress {
                        Spacer()
                        Image(systemName: PXChatRelayConfig.testAlertIconName)
                            .foregroundColor(QuantumColors.error)
                            .accessibilityLabel(NSLocalizedString("Invalid relay address warning", comment: "Accessibility"))
                    }
                }
            }
            Section {
                TextField(NSLocalizedString("enter_relay_name_placeholder", comment: "Placeholder for relay name input"), text: $relayToEdit.displayName)
                    .autocorrectionDisabled(true)
                    .disabled(newVM.isTested)
            } header: {
                HStack {
                    Text(NSLocalizedString("your_relay_name", comment: "Label for relay name field"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                    if !newVM.isValidName {
                        Spacer()
                        Image(systemName: PXChatRelayConfig.testAlertIconName)
                            .foregroundColor(QuantumColors.error)
                            .onTapGesture { showInvalidRelayNameAlert($relayToEdit.displayName) }
                            .accessibilityLabel(NSLocalizedString("Invalid relay name warning", comment: "Accessibility"))
                    }
                }
            } footer: {
                if newVM.isTestPending {
                    Text(NSLocalizedString("test_relay_footer", comment: "Footer hint to test relay"))
                }
            }
            Section(header: pxNewRelaySectionHeader) {
                HStack {
                    Button(NSLocalizedString("test_relay_button", comment: "Button to test relay connection")) {
                        pxExecuteNewRelayTest()
                    }
                    .disabled(!newVM.isValidAddress || testing)
                    .accessibilityLabel(NSLocalizedString("Test relay connection", comment: "Accessibility"))
                    Spacer()
                    showRelayTestStatus(relay: relayToEdit)
                }
                Toggle(NSLocalizedString("use_for_new_channels", comment: "Toggle to enable relay for new channels"), isOn: $relayToEdit.enabled)
                    .accessibilityLabel(NSLocalizedString("Use relay for new channels", comment: "Accessibility"))
            }
        }
        if testing {
            ProgressView().scaleEffect(PXChatRelayConfig.progressScale)
        }
        }
        .modifier(BackButton(disabled: Binding.constant(false)) {
            addChatRelay(relayToEdit, $userServers, $serverErrors, $serverWarnings, dismiss)
        })
        .alert(isPresented: $showTestFailure) {
            Alert(
                title: Text(NSLocalizedString("relay_test_failed_title", comment: "Alert title when relay test fails")),
                message: Text(verbatim: testFailure?.localizedDescription ?? "")
            )
        }
        .onChange(of: relayToEdit.address) {_, _ in
            relayToEdit.tested = nil
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .popopxBranded()
    }

    // MARK: - POPOPX new relay helpers

    private var pxNewRelaySectionHeader: some View {
        Text(NSLocalizedString("use_relay", comment: "Section header for using relay"))
            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            .opacity(PXChatRelayConfig.sectionHeaderOpacity)
    }

    private func pxExecuteNewRelayTest() {
        testing = true
        relayToEdit.tested = nil
        Task {
            if let f = await testRelayConnection(relay: $relayToEdit) {
                showTestFailure = true
                testFailure = f
            }
            await MainActor.run { testing = false }
        }
    }
}

func testRelayConnection(relay: Binding<UserChatRelay>) async -> RelayTestFailure? {
    do {
        let (relayProfile, testFailure) = try await testChatRelay(address: relay.wrappedValue.address)
        if let f = testFailure {
            await MainActor.run { relay.wrappedValue.tested = false }
            return f
        }
        await MainActor.run {
            relay.wrappedValue.tested = true
            if let relayProfile {
                relay.wrappedValue.displayName = relayProfile.displayName
            }
        }
        return nil
    } catch {
        logger.error("testRelayConnection \(responseError(error))")
        await MainActor.run { relay.wrappedValue.tested = false }
        return nil
    }
}

// MARK: - POPOPX

extension PXChatRelay {
    var pxComponentTag: String { PXChatRelayConfig.componentTag }
    var pxIsPresetMode: Bool { relay.preset }
    var pxHasTestFailure: Bool { testFailure != nil }
    fileprivate var pxValidationState: PXChatRelayViewModel { vm }
}

extension PXChatRelayLink {
    var pxComponentTag: String { PXChatRelayConfig.linkComponentTag }
    var pxIsDuplicate: Bool { isDuplicate }
    var pxRelayDisplayName: String { linkDisplayName }
}

extension PXNewChatRelay {
    var pxComponentTag: String { PXChatRelayConfig.newComponentTag }
    var pxHasTestFailure: Bool { testFailure != nil }
    fileprivate var pxValidationState: PXChatRelayViewModel { newVM }
}
