//
//  SetAppPaswordView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 10/04/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxPasscodeFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_PASSCODE_FEATURE_ENABLED")

// MARK: - POPOPX layout constants
private let pxPasscodeConfirmSpacing: CGFloat = 4

struct SetAppPasscodeView: View {
    var passcodeKeychain: KeyChainItem = kcAppPassword
    var prohibitedPasscodeKeychain: KeyChainItem = kcSelfDestructPassword
    var title: LocalizedStringKey = "New Passcode"
    var reason: String?
    var submit: () -> Void
    var cancel: () -> Void
    @Environment(\.dismiss) var dismiss: DismissAction
    @State private var showKeychainError = false
    @State private var passcode = ""
    @State private var enteredPassword = ""
    @State private var confirming = false

    var body: some View {
        ZStack {
            if confirming {
                pxConfirmPasscodeView()
            } else {
                pxSetNewPasscodeView()
            }
        }
        .alert(isPresented: $showKeychainError) {
            mkAlert(title: LocalizedStringKey(NSLocalizedString("KeyChain error", comment: "keychain error alert title")), message: LocalizedStringKey(NSLocalizedString("Error saving passcode", comment: "keychain error message")))
        }
        .popopxBranded()
    }

    // MARK: - POPOPX extracted confirm view
    private func pxConfirmPasscodeView() -> some View {
        logger.debug("PX: [pxConfirmPasscodeView] showing confirm step")
        return setPasswordView(
            title: LocalizedStringKey(NSLocalizedString("confirm_passcode_title", comment: "Confirm passcode view title")),
            submitLabel: LocalizedStringKey(NSLocalizedString("passcode_confirm_submit", comment: "Confirm passcode submit button")),
            submitEnabled: { pwd in pwd == enteredPassword }
        ) {
            pxHandleConfirmSubmit()
        }
    }

    // MARK: - POPOPX extracted initial set view
    private func pxSetNewPasscodeView() -> some View {
        logger.debug("PX: [pxSetNewPasscodeView] showing initial set step")
        return setPasswordView(title: title,
                        submitLabel: LocalizedStringKey(NSLocalizedString("save_button", comment: "Save button")),
                        // Do not allow to set app passcode == selfDestruct passcode
                        submitEnabled: { pwd in pwd != prohibitedPasscodeKeychain.get() }) {
            enteredPassword = passcode
            passcode = ""
            confirming = true
        }
    }

    // MARK: - POPOPX extracted confirm handler
    private func pxHandleConfirmSubmit() {
        guard passcode == enteredPassword else { return }
        if passcodeKeychain.set(passcode) {
            logger.debug("PX: [pxHandleConfirmSubmit] passcode saved successfully")
            enteredPassword = ""
            passcode = ""
            dismiss()
            submit()
        } else {
            logger.debug("PX: [pxHandleConfirmSubmit] keychain error")
            showKeychainError = true
        }
    }

    private func setPasswordView(title: LocalizedStringKey, submitLabel: LocalizedStringKey, submitEnabled: (((String) -> Bool))? = nil, submit: @escaping () -> Void) -> some View {
        PasscodeView(passcode: $passcode, title: title, reason: reason, submitLabel: submitLabel, submitEnabled: submitEnabled, buttonsEnabled: Binding.constant(true), submit: submit) {
            dismiss()
            cancel()
        }
    }
}

struct SetAppPasscodeView_Previews: PreviewProvider {
    static var previews: some View {
        SetAppPasscodeView(submit: {}, cancel: {})
    }
}
