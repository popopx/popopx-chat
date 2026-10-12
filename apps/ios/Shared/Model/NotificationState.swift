//
//  NotificationState.swift
//  POPOPX
//
//  Extracted from ChatModel.swift - Notification-related state
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Combine
import SwiftUI
import UserNotifications
@preconcurrency import POPOPXSwitch

/// Manages push notifications, tokens, and notification-related state
@MainActor
final class NotificationState: ObservableObject {
    // Notification response
    @Published var notificationResponse: UNNotificationResponse?

    // Device tokens
    @Published var deviceToken: DeviceToken?
    @Published var savedToken: DeviceToken?
    @Published var tokenRegistered = false
    @Published var reRegisterTknStatus: NtfTknStatus? = nil
    @Published var tokenStatus: NtfTknStatus?

    // Notification settings
    @Published var notificationMode = NotificationsMode.off
    @Published var notificationServer: String?
    @Published var notificationPreview: NotificationPreviewMode = ntfPreviewModeGroupDefault.get()

    // Pending notification actions
    @Published var ntfContactRequest: NTFContactRequest?
    @Published var ntfCallInvitationAction: (ChatId, NtfCallAction)?

    static let shared = NotificationState()

    var ntfEnableLocal: Bool { true }

    var ntfEnablePeriodic: Bool {
        notificationMode != .off
    }

    // MARK: - Reset

    func reset() {
        notificationResponse = nil
        deviceToken = nil
        savedToken = nil
        tokenRegistered = false
        reRegisterTknStatus = nil
        tokenStatus = nil
        notificationMode = .off
        notificationServer = nil
        notificationPreview = ntfPreviewModeGroupDefault.get()
        ntfContactRequest = nil
        ntfCallInvitationAction = nil
    }
}
