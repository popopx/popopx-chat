//
//  LocalAuthView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 10/04/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
//  Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import Foundation

private func constantTimeEqual(_ a: String, _ b: String) -> Bool {
    guard let ad = a.data(using: .utf8), let bd = b.data(using: .utf8) else { return false }
    let maxLen = max(ad.count, bd.count)
    if maxLen == 0 { return true }
    var result: UInt8 = 0
    ad.withUnsafeBytes { aBytes in
        bd.withUnsafeBytes { bBytes in
            let aBase = aBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
            let bBase = bBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
            for i in 0..<maxLen {
                let aByte: UInt8 = (i < ad.count) ? (aBase?[i] ?? 0) : 0
                let bByte: UInt8 = (i < bd.count) ? (bBase?[i] ?? 0) : 0
                result |= aByte ^ bByte
            }
        }
    }
    result |= UInt8(ad.count ^ bd.count)
    return result == 0
}

struct LocalAuthView: View {
    @EnvironmentObject var m: ChatModel
    var authRequest: LocalAuthRequest
    @State private var password = ""
    @State private var allowToReact = true

    var body: some View {
        PasscodeView(passcode: $password, title: authRequest.title ?? PXLocalAuthConfig.defaultTitle, reason: authRequest.reason, submitLabel: PXLocalAuthConfig.submitLabel,
                     buttonsEnabled: $allowToReact) {
            pxHandleSubmit()
        } cancel: {
            pxHandleCancel()
        }
        .popopxBranded()
    }

    // MARK: - POPOPX Actions

    private func pxHandleSubmit() {
        if let lockoutMsg = checkPasscodeLockout() {
            m.laRequest = nil
            authRequest.completed(.failed(authError: lockoutMsg))
            return
        }
        if let sdPassword = kcSelfDestructPassword.get(), authRequest.selfDestruct && constantTimeEqual(password, sdPassword) {
            allowToReact = false
            deleteStorageAndRestart(sdPassword) { r in
                m.laRequest = nil
                authRequest.completed(r)
            }
            return
        }
        let r: LAResult
        if constantTimeEqual(password, authRequest.password) {
            recordPasscodeSuccess()
            if authRequest.selfDestruct && kcSelfDestructPassword.get() != nil && !m.chatInitialized {
                Task { @MainActor in await initChatAndMigrate() }
            }
            r = .success
        } else {
            recordPasscodeFailure()
            r = .failed(authError: NSLocalizedString("Incorrect passcode", comment: "PIN entry"))
        }
        m.laRequest = nil
        authRequest.completed(r)
    }

    private func pxHandleCancel() {
        m.laRequest = nil
        authRequest.completed(.failed(authError: NSLocalizedString("Authentication cancelled", comment: "PIN entry")))
    }

    private func deleteStorageAndRestart(_ password: String, completed: @escaping (LAResult) -> Void) {
        Task {
            do {
                /** Waiting until [initializeChat] finishes */
                while (m.ctrlInitInProgress) {
                    try await Task.sleep(nanoseconds: PXLocalAuthConfig.initPollNanoseconds)
                }
                if m.chatRunning == true {
                    try await stopChatAsync()
                }
                if m.chatInitialized {
                    /**
                     * The following sequence can bring a user here:
                     * the user opened the app, entered app passcode, went to background, returned back, entered self-destruct code.
                     * In this case database should be closed to prevent possible situation when OS can deny database removal command
                     * */
                    ffiQueue.sync { chatCloseStore() }
                }
                deleteAppDatabaseAndFiles()
                // Clear sensitive data on screen just in case app fails to hide its views while new database is created
                m.chatId = nil
                ItemsModel.shared.reversedChatItems = []
                ItemsModel.shared.chatState.clear()
                ChatModel.shared.secondaryIM?.reversedChatItems = []
                ChatModel.shared.secondaryIM?.chatState.clear()
                m.updateChats([])
                m.users = []
                _ = kcAppPassword.set(password)
                _ = kcSelfDestructPassword.remove()
                await NtfManager.shared.removeAllNotifications()
                let displayName = UserDefaults.standard.string(forKey: DEFAULT_LA_SELF_DESTRUCT_DISPLAY_NAME)
                UserDefaults.standard.removeObject(forKey: DEFAULT_LA_SELF_DESTRUCT)
                UserDefaults.standard.removeObject(forKey: DEFAULT_LA_SELF_DESTRUCT_DISPLAY_NAME)
                m.chatDbChanged = true
                m.chatInitialized = false
                resetChatCtrl()
                try await initializeChat(start: true)
                m.chatDbChanged = false
                AppChatState.shared.set(.active)
                if m.currentUser != nil || !m.chatInitialized { return }
                var profile: Profile? = nil
                if let displayName = displayName, displayName != "" {
                    profile = Profile(displayName: displayName, fullName: "")
                }
                m.currentUser = try apiCreateActiveUser(profile, pastTimestamp: true)
                advanceOnboarding(to: .onboardingComplete)
                try startChat()
                completed(.success)
            } catch {
                completed(.failed(authError: NSLocalizedString("Incorrect passcode", comment: "PIN entry")))
            }
        }
    }
}

struct LocalAuthView_Previews: PreviewProvider {
    static var previews: some View {
        LocalAuthView(authRequest: LocalAuthRequest.sample)
    .previewEnvironment()
    }
}

// MARK: - POPOPX Config & Tag

private enum PXLocalAuthConfig {
    static let defaultTitle: LocalizedStringKey = "Enter Passcode"
    static let submitLabel: LocalizedStringKey = "Submit"
    static let initPollNanoseconds: UInt64 = 50_000000
}

extension LocalAuthView {
    static let pxComponentTag: String = "PX_LOCAL_AUTH_VIEW"
}
