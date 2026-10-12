//
//  SuspendChat.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 26/06/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import UIKit
import POPOPXSwitch
import SwiftUI

private let suspendLock = NSRecursiveLock()

let bgSuspendTimeout: Int = 5 // seconds

let terminationTimeout: Int = 3 // seconds

let activationDelay: TimeInterval = 1.5

let nseSuspendTimeout: TimeInterval = 5

@MainActor
private func _suspendChat(timeout: Int) {
    let state = AppChatState.shared.value
    if state == .suspending || state == .suspended {
        logger.debug("_suspendChat: already \(state.rawValue), skipping")
        return
    }
    if !state.canSuspend {
        logger.error("_suspendChat called, current state: \(state.rawValue)")
    } else if ChatModel.ok {
        AppChatState.shared.set(.suspending)
        apiSuspendChat(timeoutMicroseconds: timeout * 1000000)
        let endTask: @Sendable () -> Void = { Task { @MainActor in chatSuspended() } }
        Task.detached {
            try? await Task.sleep(for: .seconds(Double(timeout) + 1))
            endTask()
        }
    } else {
        AppChatState.shared.set(.suspended)
    }
}

let seSubscriber = seMessageSubscriber {
    switch $0 {
    case let .state(state):
        Task { @MainActor in
            switch state {
            case .inactive:
                if AppChatState.shared.value.inactive { activateChat() }
            case .sendingMessage:
                if AppChatState.shared.value.canSuspend { suspendChat() }
            }
        }
    }
}

@MainActor
func suspendChat() {
    suspendLock.lock(); defer { suspendLock.unlock() }
    _suspendChat(timeout: appSuspendTimeout)
}

@MainActor
func suspendBgRefresh() {
    suspendLock.lock(); defer { suspendLock.unlock() }
    if case .bgRefresh = AppChatState.shared.value  {
        _suspendChat(timeout: bgSuspendTimeout)
    }
}

@MainActor
private func _terminateChatAction(chatOk: Bool) -> Bool {
    suspendLock.lock(); defer { suspendLock.unlock() }
    switch AppChatState.shared.value {
    case .suspending:
        _chatSuspended()
        if chatOk { apiSuspendChat(timeoutMicroseconds: 0) }
        return true
    case .suspended, .stopped:
        return true
    case .active, .activating, .bgRefresh:
        _suspendChat(timeout: terminationTimeout)
        return false
    @unknown default:
        _suspendChat(timeout: terminationTimeout)
        return false
    }
}

@MainActor
func terminateChat() async {
    logger.debug("terminateChat")
    let shouldCloseStore = _terminateChatAction(chatOk: ChatModel.ok)

    if shouldCloseStore {
        await withCheckedContinuation { cont in
            ffiQueue.async {
                chatCloseStore()
                cont.resume()
            }
        }
    }
}

@MainActor
func chatSuspended() {
    suspendLock.lock(); defer { suspendLock.unlock() }
    if case .suspending = AppChatState.shared.value {
        _chatSuspended()
    }
}

@MainActor
private func _chatSuspended() {
    logger.debug("_chatSuspended")
    AppChatState.shared.set(.suspended)
    if ChatModel.shared.chatRunning == true {
        ChatReceiver.shared.stop()
    }
}

@MainActor
func setAppState(_ appState: AppState) {
    suspendLock.lock(); defer { suspendLock.unlock() }
    AppChatState.shared.set(appState)
}

@MainActor
func activateChat(appState: AppState = .active) {
    suspendLock.lock(); defer { suspendLock.unlock() }
    let currentState = AppChatState.shared.value
    guard currentState != .active && currentState != .activating else {
        logger.error("activateChat: invalid transition from \(currentState.rawValue)")
        return
    }
    AppChatState.shared.set(appState)
    if ChatModel.ok { apiActivateChat() }
}

nonisolated(unsafe) var _initChatInProgressBacking = false
var _initChatInProgress: Bool {
    get { suspendLock.lock(); defer { suspendLock.unlock() }; return _initChatInProgressBacking }
    set { suspendLock.lock(); defer { suspendLock.unlock() }; _initChatInProgressBacking = newValue }
}

@MainActor
func initChatAndMigrate(refreshInvitations: Bool = true) async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        Task.detached {
            // Wait for Haskell runtime readiness without blocking a global queue thread
            // Use a sync closure to avoid Swift 6 concurrency warning about Semaphore.wait()
            {
                POPOPXApp._haskellReady.wait()
            }()
            await MainActor.run { cont.resume() }
        }
    }
    let m = ChatModel.shared
    logger.info("initChatAndMigrate: STARTING - chatInitialized=\(m.chatInitialized), _initChatInProgress=\(_initChatInProgress)")
    if m.chatInitialized || _initChatInProgress {
        logger.info("initChatAndMigrate: Early return - already initialized or in progress")
        return
    }
    _initChatInProgress = true
    logger.info("initChatAndMigrate: Starting initialization process...")
    m.v3DBMigration = v3DBMigrationDefault.get()
    defer { _initChatInProgress = false }
    if AppChatState.shared.value == .stopped && storeDBPassphraseGroupDefault.get() && kcDatabasePassword.get() != nil {
        await initialize(start: true, confirmStart: true)
    } else {
        await initialize(start: true)
    }

    func initialize(start: Bool, confirmStart: Bool = false) async {
        do {
            try await initializeChat(start: m.v3DBMigration.startChat && start, confirmStart: m.v3DBMigration.startChat && confirmStart, refreshInvitations: refreshInvitations)
        } catch let error {
            AlertManager.shared.showAlertMsg(
                title: start
                    ? LocalizedStringKey(NSLocalizedString("model_error_starting_chat_title", comment: "alert title"))
                    : LocalizedStringKey(NSLocalizedString("model_error_opening_chat_title", comment: "alert title")),
                message: LocalizedStringKey(String(format: NSLocalizedString("model_contact_developers_error_message", comment: "alert message"), responseError(error)))
            )
        }
    }
}

@MainActor
func startChatForCall() {
    if ChatModel.shared.chatRunning == true {
        ChatReceiver.shared.start()
    }
    if .active != AppChatState.shared.value {
        activateChat()
    }
}

@MainActor
func startChatAndActivate(_ completion: @escaping () -> Void) {
    if ChatModel.shared.chatRunning == true {
        ChatReceiver.shared.start()
    }
    if case .active = AppChatState.shared.value {
        completion()
    } else if nseStateGroupDefault.get().inactive {
        activate()
    } else {
        // setting app state to "activating" to notify NSE that it should suspend
        setAppState(.activating)
        waitNSESuspended(timeout: nseSuspendTimeout) { ok in
            if !ok {
                // if for some reason NSE failed to suspend,
                // e.g., it crashed previously without setting its state to "suspended",
                // set it to "suspended" state anyway, so that next time app
                // does not have to wait when activating.
                nseStateGroupDefault.set(.suspended)
            }
            if AppChatState.shared.value == .activating {
                activate()
            }
        }
    }

    func activate() {
        if ChatModel.shared.chatInitialized {
            activateChat()
        } else {
            logger.warning("SuspendChat.activate: chat not initialized, skipping activateChat")
        }
        completion()
    }
}

// appStateGroupDefault must not be used in the app directly, only via this singleton
@MainActor
class AppChatState {
    static let shared = AppChatState()
    private var value_ = appStateGroupDefault.get()

    var value: AppState {
        value_
    }

    func set(_ state: AppState) {
        appStateGroupDefault.set(state)
        sendAppState(state)
        value_ = state
    }
}
