//
//  LocalAuthenticationUtils.swift
//  POPOPX (iOS)
//
//  Created by Efim Poberezkin on 26.05.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import LocalAuthentication
import POPOPXSwitch

enum LAResult {
    case success
    case failed(authError: String?)
    case unavailable(authError: String?)
}

private let lockoutAttemptsKey = "passcode_lockout_attempts"
private let lockoutUntilKey = "passcode_lockout_until"
private let consecutiveFailuresKey = "passcode_consecutive_failures"
private let authLock = NSLock()

private var passcodeAttempts: Int {
    get { groupDefaults.integer(forKey: lockoutAttemptsKey) }
    set { groupDefaults.set(newValue, forKey: lockoutAttemptsKey) }
}
private var passcodeLockoutUntil: Date? {
    get {
        let time = groupDefaults.double(forKey: lockoutUntilKey)
        return time > 0 ? Date(timeIntervalSince1970: time) : nil
    }
    set {
        groupDefaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lockoutUntilKey)
    }
}
private let maxPasscodeAttempts = 5
private let basePasscodeLockoutDuration: TimeInterval = 60 // Start with 1 minute
private let maxPasscodeLockoutDuration: TimeInterval = 3600 // Max 1 hour

func checkPasscodeLockout() -> String? {
    authLock.lock()
    defer { authLock.unlock() }
    if let lockoutUntil = passcodeLockoutUntil, Date() < lockoutUntil {
        let remaining = Int(lockoutUntil.timeIntervalSinceNow) + 1
        return String.localizedStringWithFormat(NSLocalizedString("Too many attempts. Try again in %d seconds.", comment: "passcode lockout message"), remaining)
    }
    if Date() >= (passcodeLockoutUntil ?? .distantPast) {
        passcodeAttempts = 0
        passcodeLockoutUntil = nil
    }
    return nil
}

func recordPasscodeFailure() {
    authLock.lock()
    defer { authLock.unlock() }
    passcodeAttempts += 1
    if passcodeAttempts >= maxPasscodeAttempts {
        // Exponential backoff: 1 min, 2 min, 4 min, 8 min, 16 min, ... up to 1 hour
        let consecutiveFailures = groupDefaults.integer(forKey: consecutiveFailuresKey) + 1
        groupDefaults.set(consecutiveFailures, forKey: consecutiveFailuresKey)
        
        let exponentialDuration = min(basePasscodeLockoutDuration * pow(2.0, Double(consecutiveFailures - 1)), maxPasscodeLockoutDuration)
        passcodeLockoutUntil = Date().addingTimeInterval(exponentialDuration)
        passcodeAttempts = 0
        
        logger.warning("Passcode lockout activated: \(consecutiveFailures) consecutive failures, locked for \(exponentialDuration) seconds")
    }
}

func recordPasscodeSuccess() {
    authLock.lock()
    defer { authLock.unlock() }
    passcodeAttempts = 0
    passcodeLockoutUntil = nil
    groupDefaults.set(0, forKey: consecutiveFailuresKey)
}

func authorize(_ text: String, _ authorized: Binding<Bool>) {
    authenticate(reason: text) { laResult in
        switch laResult {
        case .success: authorized.wrappedValue = true
        case .unavailable: authorized.wrappedValue = false
        case .failed: authorized.wrappedValue = false
        }
    }
}

struct LocalAuthRequest {
    var title: LocalizedStringKey? // if title is null, reason is shown
    var reason: String
    var password: String
    var selfDestruct: Bool
    var completed: (LAResult) -> Void

    static var sample = LocalAuthRequest(title: "Enter Passcode", reason: "Authenticate", password: "", selfDestruct: false, completed: { _ in })
}

func authenticate(title: LocalizedStringKey? = nil, reason: String, selfDestruct: Bool = false, completed: @escaping (LAResult) -> Void) {
    switch privacyLocalAuthModeDefault.get() {
    case .system: systemAuthenticate(reason, completed)
    case .passcode:
        if let password = kcAppPassword.get() {
            DispatchQueue.main.async {
                ChatModel.shared.laRequest = LocalAuthRequest(
                    title: title,
                    reason: reason,
                    password: password,
                    selfDestruct: selfDestruct && UserDefaults.standard.bool(forKey: DEFAULT_LA_SELF_DESTRUCT),
                    completed: completed
                )
            }
        } else {
            completed(.unavailable(authError: NSLocalizedString("No app password", comment: "Authentication unavailable")))
        }
    }
}

func systemAuthenticate(_ reason: String, _ completed: @escaping (LAResult) -> Void) {
    let laContext = LAContext()
    var authAvailabilityError: NSError?
    if laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authAvailabilityError) {
        laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    completed(LAResult.success)
                } else {
                    completed(LAResult.failed(authError: authError?.localizedDescription))
                }
            }
        }
    } else {
        completed(LAResult.unavailable(authError: authAvailabilityError?.localizedDescription))
    }
}

func laTurnedOnAlert() -> Alert {
    mkAlert(
        title: LocalizedStringKey(NSLocalizedString("la_lock_turned_on_title", comment: "POPOPX Lock turned on alert title")),
        message: LocalizedStringKey(NSLocalizedString("la_lock_turned_on_message", comment: "POPOPX Lock turned on alert message"))
    )
}

func laPasscodeNotSetAlert() -> Alert {
    mkAlert(
        title: LocalizedStringKey(NSLocalizedString("la_lock_not_enabled_title", comment: "POPOPX Lock not enabled alert title")),
        message: LocalizedStringKey(NSLocalizedString("la_lock_not_enabled_message", comment: "POPOPX Lock not enabled alert message"))
    )
}

func laFailedAlert() -> Alert {
    mkAlert(
        title: LocalizedStringKey(NSLocalizedString("la_auth_failed_title", comment: "Authentication failed alert title")),
        message: LocalizedStringKey(NSLocalizedString("la_auth_failed_message", comment: "Authentication failed alert message"))
    )
}

func laUnavailableInstructionAlert() -> Alert {
    mkAlert(
        title: LocalizedStringKey(NSLocalizedString("la_auth_unavailable_title", comment: "Authentication unavailable alert title")),
        message: LocalizedStringKey(NSLocalizedString("la_auth_unavailable_instruction_message", comment: "Authentication unavailable instruction message"))
    )
}

func laUnavailableTurningOffAlert() -> Alert {
    mkAlert(
        title: LocalizedStringKey(NSLocalizedString("la_auth_unavailable_title", comment: "Authentication unavailable alert title")),
        message: LocalizedStringKey(NSLocalizedString("la_auth_unavailable_turning_off_message", comment: "Authentication unavailable turning off message"))
    )
}

