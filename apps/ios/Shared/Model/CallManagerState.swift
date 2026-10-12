//
//  CallState.swift
//  POPOPX
//
//  Extracted from ChatModel.swift - Call-related state
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Combine
import SwiftUI
@preconcurrency import POPOPXSwitch

/// Manages WebRTC calls, invitations, and call UI state
@MainActor
final class CallManagerState: ObservableObject {
    // Call invitations
    @Published var callInvitations: Dictionary<ChatId, RcvCallInvitation> = [:]

    // Active call
    @Published var activeCall: Call?
    let callCommand: WebRTCCommandProcessor = WebRTCCommandProcessor()

    // Call UI
    @Published var showCallView = false
    @Published var activeCallViewIsCollapsed = false

    static let shared = CallManagerState()

    // MARK: - Reset

    func reset() {
        callInvitations = [:]
        activeCall = nil
        showCallView = false
        activeCallViewIsCollapsed = false
    }
}
