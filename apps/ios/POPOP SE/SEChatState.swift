//
//  SEChatState.swift
//  POPOPX SE
//
//  Created by User on 18/07/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// SEStateGroupDefault must not be used in the share extension directly, only via this singleton
class SEChatState {
    static let shared = SEChatState()
    private let lock = NSLock()
    private var value_ = seStateGroupDefault.get()

    var value: SEState {
        lock.lock()
        defer { lock.unlock() }
        return value_
    }

    func set(_ state: SEState) {
        seStateGroupDefault.set(state)
        sendSEState(state)
        lock.lock()
        value_ = state
        lock.unlock()
    }
}

/// Waits for other processes to set their state to suspended
/// Will wait for maximum of two seconds, since they might not be running
func waitForOtherProcessesToSuspend() async {
    let startTime = CFAbsoluteTimeGetCurrent()
    while CFAbsoluteTimeGetCurrent() - startTime < 2 {
        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        if appStateGroupDefault.get() == .suspended &&
           nseStateGroupDefault.get() == .suspended {
            break
        }
    }
}
