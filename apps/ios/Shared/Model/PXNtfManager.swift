//
//  PXNtfManager.swift
//  POPOPX
//
//  Notification registration, presentation logic and badge management.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/notifications.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
@preconcurrency import UserNotifications
import UIKit
import POPOPXSwitch

// MARK: - Notification Action Identifiers

let ntfActionAcceptContact = "NTF_ACT_ACCEPT_CONTACT"
let ntfActionAcceptCall = "NTF_ACT_ACCEPT_CALL"
let ntfActionRejectCall = "NTF_ACT_REJECT_CALL"

private let ntfTimeInterval: TimeInterval = 1

// MARK: - POPOPX Notification Constants
private enum PXNtfConfig {
    /// Time window for deduplicating notifications from the same chat
    static let recentWindowSeconds: TimeInterval = 30
    /// Maximum badge count to display
    static let maxBadgeValue: Int = 999
    /// Prefix for POPOPX notification identifiers
    static let identifierPrefix: String = "px_ntf"
    /// Connection event category description
    static let connectionEventDescription: String = "POPOPX encrypted message or connection event"
    /// Log prefix for POPOPX-specific tracing
    static let logPrefix: String = "PX"
}

// MARK: - POPOPX Notification Builder Helpers
private enum PXNtfBuilder {
    static func pxMakeGroupInvitationContent(_ groupInfo: GroupInfo) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Group invitation", comment: "")
        content.body = String.localizedStringWithFormat(
            NSLocalizedString("You are invited to group %@", comment: ""),
            groupInfo.displayName
        )
        content.sound = .default
        return content
    }

    static func pxUniqueIdentifier(counter: Int, targetId: String?) -> String {
        if let targetId = targetId {
            return "\(appNotificationId)-\(targetId)-\(counter)"
        } else {
            return "\(appNotificationId)-\(counter)"
        }
    }
}

enum NtfCallAction {
    case accept
    case reject
}

// Spec: spec/services/notifications.md#NtfManager
@MainActor
class NtfManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NtfManager()

    public var navigatingToChat = false
    private var granted = false
    private var prevNtfTime: Dictionary<ChatId, Date> = [:]
    private var ntfCounter: Int = 0

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Handle notification when app is in background
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: () -> Void) {
        logger.debug("NtfManager.userNotificationCenter: didReceive")
        if appStateGroupDefault.get() == .active {
            pxProcessResponse(response)
        } else {
            logger.debug("NtfManager.userNotificationCenter: remember response in model")
            ChatModel.shared.notificationResponse = response
        }
        handler()
    }

    // Spec: spec/services/notifications.md#processNotificationResponse
    func processNotificationResponse(_ ntfResponse: UNNotificationResponse) {
        pxProcessResponse(ntfResponse)
    }

    /// POPOPX: Internal response processing with extracted routing
    private func pxProcessResponse(_ ntfResponse: UNNotificationResponse) {
        let chatModel = ChatModel.shared
        let userInfo = ntfResponse.notification.request.content
        let actionId = ntfResponse.actionIdentifier
        logger.debug("NtfManager.processNotificationResponse: didReceive: action \(actionId), categoryIdentifier \(userInfo.categoryIdentifier)")
        if let userId = userInfo.userInfo["userId"] as? Int64,
           userId != chatModel.currentUser?.userId {
            logger.debug("NtfManager.processNotificationResponse changeActiveUser")
            changeActiveUser(userId, viewPwd: nil)
        }
        if userInfo.categoryIdentifier == ntfCategoryContactRequest && actionId == ntfActionAcceptContact,
           let chatId = userInfo.userInfo["chatId"] as? String {
            pxHandleContactRequestAction(chatId: chatId, chatModel: chatModel)
        } else if let (chatId, ntfAction) = pxCallAction(from: userInfo, actionId: actionId) {
            pxHandleCallAction(chatId: chatId, action: ntfAction, chatModel: chatModel)
        } else {
            pxHandleNavigationAction(userInfo: userInfo)
        }
    }

    // MARK: - POPOPX Response Routing Helpers

    private func pxHandleContactRequestAction(chatId: String, chatModel: ChatModel) {
        if case let .contactRequest(contactRequest) = chatModel.getChat(chatId)?.chatInfo {
            Task { await acceptContactRequest(incognito: false, contactRequestId: contactRequest.apiId) }
        } else {
            chatModel.ntfContactRequest = NTFContactRequest(chatId: chatId)
        }
    }

    private func pxHandleCallAction(chatId: ChatId, action: NtfCallAction, chatModel: ChatModel) {
        if let invitation = chatModel.callInvitations.removeValue(forKey: chatId) {
            CallController.shared.callAction(invitation: invitation, action: action)
        } else {
            chatModel.ntfCallInvitationAction = (chatId, action)
        }
    }

    private func pxHandleNavigationAction(userInfo: UNNotificationContent) {
        if let chatId = userInfo.targetContentIdentifier {
            if ChatModel.shared.getChat(chatId) != nil {
                self.navigatingToChat = true
                ItemsModel.shared.loadOpenChat(chatId) {
                    self.navigatingToChat = false
                }
            }
        }
    }

    /// POPOPX: Extracted call action parsing with guard-let pattern
    private func pxCallAction(from content: UNNotificationContent, actionId action: String) -> (ChatId, NtfCallAction)? {
        guard content.categoryIdentifier == ntfCategoryCallInvitation,
              let chatId = content.userInfo["chatId"] as? String else { return nil }
        if action == ntfActionAcceptCall {
            return (chatId, .accept)
        } else if action == ntfActionRejectCall {
            return (chatId, .reject)
        }
        return nil
    }

    // Handle notification when the app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: (UNNotificationPresentationOptions) -> Void) {
        logger.debug("NtfManager.userNotificationCenter: willPresent")
        handler(pxPresentationOptions(notification.request.content))
    }

    /// POPOPX: Presentation options with extracted logic
    private func pxPresentationOptions(_ content: UNNotificationContent) -> UNNotificationPresentationOptions {
        let model = ChatModel.shared
        if UIApplication.shared.applicationState == .active {
            switch content.categoryIdentifier {
            case ntfCategoryMessageReceived:
                return pxMessagePresentationOptions(content: content, model: model)
            case ntfCategoryCheckMessage: return []
            case ntfCategoryCallInvitation: return []
            default: return [.sound, .banner, .list]
            }
        } else {
            return content.categoryIdentifier == ntfCategoryCheckMessage ? [] : [.sound, .banner, .list]
        }
    }

    /// POPOPX: Extracted message-specific presentation logic
    private func pxMessagePresentationOptions(content: UNNotificationContent, model: ChatModel) -> UNNotificationPresentationOptions {
        let recent = pxRecentInTheSameChat(content)
        let userId = content.userInfo["userId"] as? Int64
        if let userId = userId, let user = model.getUser(userId), !user.showNotifications {
            return []
        } else if model.chatId == nil {
            if model.currentUser?.userId == userId {
                return recent ? [] : [.sound, .list]
            } else {
                return recent ? [.banner] : [.sound, .banner, .list]
            }
        } else if model.chatId == content.targetContentIdentifier {
            return recent ? [] : [.sound, .list]
        } else {
            return recent ? [.banner, .list] : [.sound, .banner, .list]
        }
    }

    /// POPOPX: Recent notification deduplication with named constant
    private func pxRecentInTheSameChat(_ content: UNNotificationContent) -> Bool {
        let now = Date.now
        if let chatId = content.targetContentIdentifier {
            var isRecent: Bool = false
            if let t = prevNtfTime[chatId] { isRecent = t.distance(to: now) < PXNtfConfig.recentWindowSeconds }
            prevNtfTime[chatId] = now
            return isRecent
        }
        return false
    }

    // Keep backward-compatible alias
    private func recentInTheSameChat(_ content: UNNotificationContent) -> Bool {
        pxRecentInTheSameChat(content)
    }

    // Spec: spec/services/notifications.md#registerCategories
    func registerCategories() {
        logger.debug("\(PXNtfConfig.logPrefix): NtfManager.registerCategories called")
        logger.debug("NtfManager.registerCategories")
        UNUserNotificationCenter.current().setNotificationCategories(pxNotificationCategories())
    }

    /// POPOPX: Extracted category registration builder
    private func pxNotificationCategories() -> Set<UNNotificationCategory> {
        [
            UNNotificationCategory(
                identifier: ntfCategoryContactRequest,
                actions: [
                    UNNotificationAction(
                        identifier: ntfActionAcceptContact,
                        title: NSLocalizedString("Accept", comment: "accept contact request via notification"),
                        options: .foreground
                    )
                ],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: NSLocalizedString("New contact request", comment: "notification")
            ),
            UNNotificationCategory(
                identifier: ntfCategoryContactConnected,
                actions: [],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: NSLocalizedString("Contact is connected", comment: "notification")
            ),
            UNNotificationCategory(
                identifier: ntfCategoryMessageReceived,
                actions: [],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: NSLocalizedString("New message", comment: "notification")
            ),
            UNNotificationCategory(
                identifier: ntfCategoryCallInvitation,
                actions: [
                    UNNotificationAction(
                        identifier: ntfActionAcceptCall,
                        title: NSLocalizedString("Accept", comment: "accept incoming call via notification"),
                        options: .foreground
                    ),
                    UNNotificationAction(
                        identifier: ntfActionRejectCall,
                        title: NSLocalizedString("Reject", comment: "reject incoming call via notification")
                    )
                ],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: NSLocalizedString("Incoming call", comment: "notification")
            ),
            UNNotificationCategory(
                identifier: ntfCategoryConnectionEvent,
                actions: [],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: NSLocalizedString(PXNtfConfig.connectionEventDescription, comment: "notification")
            ),
            UNNotificationCategory(
                identifier: ntfCategoryManyEvents,
                actions: [],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: NSLocalizedString("New events", comment: "notification")
            )
        ]
    }

    // Spec: spec/services/notifications.md#requestAuthorization
    func requestAuthorization(onDeny denied: (()-> Void)? = nil, onAuthorized authorized: (()-> Void)? = nil, whenDone: (() -> Void)? = nil) {
        logger.debug("NtfManager.requestAuthorization")
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            logger.debug("NtfManager.requestAuthorization: current status=\(settings.authorizationStatus.rawValue)")
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                    logger.debug("NtfManager.requestAuthorization: denied")
                    denied?()
                    whenDone?()
                case .authorized:
                    logger.debug("NtfManager.requestAuthorization: already authorized")
                    self.granted = true
                    authorized?()
                    whenDone?()
                case .provisional:
                    logger.debug("NtfManager.requestAuthorization: provisional")
                    self.granted = true
                    authorized?()
                    whenDone?()
                default:
                    logger.debug("NtfManager.requestAuthorization: requesting from system (status=notDetermined)")
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { grantedValue, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                logger.error("NtfManager.requestAuthorization error \(error.localizedDescription)")
                            } else {
                                logger.debug("NtfManager.requestAuthorization: system dialog result granted=\(grantedValue)")
                                self.granted = grantedValue
                            }
                            authorized?()
                            whenDone?()
                        }
                    }
                }
            }
        }
    }

    /// Re-query notification authorization status from the system.
    /// Call this when the app returns to foreground (scenePhase .active)
    /// to pick up changes made in iOS Settings.
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let isNowGranted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                if self.granted != isNowGranted {
                    logger.debug("NtfManager.refreshAuthorizationStatus: granted changed \(self.granted) -> \(isNowGranted)")
                    self.granted = isNowGranted
                }
            }
        }
    }

    // Spec: spec/services/notifications.md#notifyContactRequest
    func notifyContactRequest(_ user: any UserLike, _ contactRequest: UserContactRequest) {
        logger.debug("NtfManager.notifyContactRequest")
        pxAddNotification(pxMakeContactRequest(user, contactRequest))
    }

    func notifyContactConnected(_ user: any UserLike, _ contact: Contact) {
        logger.debug("NtfManager.notifyContactConnected")
        pxAddNotification(pxMakeContactConnected(user, contact))
    }

    // Spec: spec/services/notifications.md#notifyMessageReceived
    func notifyMessageReceived(_ user: any UserLike, _ cInfo: ChatInfo, _ cItem: ChatItem) {
        logger.debug("NtfManager.notifyMessageReceived")
        if cInfo.ntfsEnabled(chatItem: cItem) {
            pxAddNotification(pxMakeMessageReceived(user, cInfo, cItem))
        }
    }

    // Spec: spec/services/notifications.md#notifyCallInvitation
    func notifyCallInvitation(_ invitation: RcvCallInvitation) {
        logger.debug("NtfManager.notifyCallInvitation")
        pxAddNotification(pxMakeCallInvitation(invitation))
    }

    func notifyGroupInvitation(_ user: any UserLike, _ groupInfo: GroupInfo) {
        logger.debug("NtfManager.notifyGroupInvitation")
        pxAddNotification(PXNtfBuilder.pxMakeGroupInvitationContent(groupInfo))
    }

    // MARK: - POPOPX Notification Content Builders

    private func pxMakeContactRequest(_ user: any UserLike, _ contactRequest: UserContactRequest) -> UNMutableNotificationContent {
        createContactRequestNtf(user, contactRequest, 0)
    }

    private func pxMakeContactConnected(_ user: any UserLike, _ contact: Contact) -> UNMutableNotificationContent {
        createContactConnectedNtf(user, contact, 0)
    }

    private func pxMakeMessageReceived(_ user: any UserLike, _ cInfo: ChatInfo, _ cItem: ChatItem) -> UNMutableNotificationContent {
        createMessageReceivedNtf(user, cInfo, cItem, 0)
    }

    private func pxMakeCallInvitation(_ invitation: RcvCallInvitation) -> UNMutableNotificationContent {
        createCallInvitationNtf(invitation, 0)
    }

    // Spec: spec/services/notifications.md#setNtfBadgeCount
    func setNtfBadgeCount(_ count: Int) {
        let clampedCount = min(count, PXNtfConfig.maxBadgeValue)
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(clampedCount)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = clampedCount
        }
        ntfBadgeCountGroupDefault.set(clampedCount)
    }

    // Spec: spec/services/notifications.md#changeNtfBadgeCount
    func changeNtfBadgeCount(by count: Int = 1) {
        setNtfBadgeCount(max(0, ntfBadgeCountGroupDefault.get() + count))
    }

    /// POPOPX: Notification dispatch with unique counter-based identifiers
    private func pxAddNotification(_ content: UNMutableNotificationContent) {
        guard granted else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: ntfTimeInterval, repeats: false)
        ntfCounter += 1
        let identifier = PXNtfBuilder.pxUniqueIdentifier(counter: ntfCounter, targetId: content.targetContentIdentifier)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { logger.error("addNotification error: \(error.localizedDescription)") }
        }
    }

    func removeAllNotifications() async {
        let nc = UNUserNotificationCenter.current()
        let settings = await nc.notificationSettings()
        if settings.authorizationStatus == .authorized {
            nc.removeAllPendingNotificationRequests()
            nc.removeAllDeliveredNotifications()
        }
    }
}

// MARK: - POPOPX
extension NtfManager {
    static let pxComponentTag: String = "PXNtfManager"
    static let pxRecentNotificationWindow: TimeInterval = PXNtfConfig.recentWindowSeconds
    static let pxMaxBadgeCount: Int = PXNtfConfig.maxBadgeValue
}

extension NtfManager {
    static var pxComponentIdentity: String { pxComponentTag }
}
