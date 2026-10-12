//
//  PXAppSettings.swift
//  POPOPX (iOS)
//
//  Import and export of application settings from/to serialized form.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch
import SwiftUI

// MARK: - POPOPX Settings Layout

// POPOPX: category indices and metadata for settings screen sections
private enum PXSettingsLayout {
    static let totalCategoryCount = 6
    static let networkIdx = 0
    static let privacyIdx = 1
    static let notificationsIdx = 2
    static let appearanceIdx = 3
    static let experimentalIdx = 4
    static let databaseIdx = 5
    static let componentTag: String = "PX_APP_SETTINGS"
    static let brandMarker: String = "PX_APP_SETTINGS"
    static let schemaVersion: String = "1.0.0"
}

// POPOPX: diagnostic logging flags read from UserDefaults
private enum PXSettingsDiagnostics {
    static let importLogEnabled = UserDefaults.standard.bool(forKey: "PX_IMPORT_LOG_ENABLED")
    static let currentLogEnabled = UserDefaults.standard.bool(forKey: "PX_CURRENT_LOG_ENABLED")
}

extension AppSettings {

    @MainActor
    public func importIntoApp() {
        pxLogImportStart()
        let pxDefaults = UserDefaults.standard
        // Network configuration: migrate from Android/desktop if needed
        pxApplyNetworkConfig(defaults: pxDefaults)
        // Privacy and notification settings
        pxApplyPrivacyAndNotificationSettings(defaults: pxDefaults)
        // WebRTC, session, and developer settings
        pxApplyWebRTCAndDevSettings(defaults: pxDefaults)
        // UI appearance and layout settings
        pxApplyUIAppearanceSettings(defaults: pxDefaults)
        pxLogImportCompletion()
    }

    // MARK: - POPOPX: import helpers

    // POPOPX: extract network config migration into dedicated method
    private func pxApplyNetworkConfig(defaults pxDefaults: UserDefaults) {
        if var val = networkConfig {
            // migrating from Android/desktop BUT shouldn't be here ever because it should be changed in migration stage
            if case .onionViaSocks = val.hostMode {
                val.hostMode = .publicHost
                val.requiredHostMode = true
            }
            if val.socksProxy != nil {
                val.socksProxy = networkProxy?.toProxyString()
                setNetCfg(val, networkProxy: networkProxy)
            } else {
                val.socksProxy = nil
                setNetCfg(val, networkProxy: nil)
            }
        }
        if let pxProxyVal = networkProxy { networkProxyDefault.set(pxProxyVal) }
    }

    // POPOPX: batch apply all privacy-related group defaults
    private func pxApplyPrivacyAndNotificationSettings(defaults pxDefaults: UserDefaults) {
        if let pxEncryptVal = privacyEncryptLocalFiles { privacyEncryptLocalFilesGroupDefault.set(pxEncryptVal) }
        if let pxApproveVal = privacyAskToApproveRelays { privacyAskToApproveRelaysGroupDefault.set(pxApproveVal) }
        if let pxAcceptImgVal = privacyAcceptImages {
            privacyAcceptImagesGroupDefault.set(pxAcceptImgVal)
            pxDefaults.setValue(pxAcceptImgVal, forKey: DEFAULT_PRIVACY_ACCEPT_IMAGES)
        }
        if let pxPreviewsVal = privacyLinkPreviews {
            privacyLinkPreviewsGroupDefault.set(pxPreviewsVal)
            pxDefaults.setValue(pxPreviewsVal, forKey: DEFAULT_PRIVACY_LINK_PREVIEWS)
        }
        if let pxSanitizeVal = privacySanitizeLinks { privacySanitizeLinksGroupDefault.set(pxSanitizeVal) }
        if let pxShowChatPrev = privacyShowChatPreviews { pxDefaults.setValue(pxShowChatPrev, forKey: DEFAULT_PRIVACY_SHOW_CHAT_PREVIEWS) }
        if let pxSaveDraft = privacySaveLastDraft { pxDefaults.setValue(pxSaveDraft, forKey: DEFAULT_PRIVACY_SAVE_LAST_DRAFT) }
        if let pxProtectScr = privacyProtectScreen { pxDefaults.setValue(pxProtectScr, forKey: DEFAULT_PRIVACY_PROTECT_SCREEN) }
        if let pxBlurRad = privacyMediaBlurRadius { pxDefaults.setValue(pxBlurRad, forKey: DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS) }
        if let pxNtfMode = notificationMode {
            Task { @MainActor in ChatModel.shared.notificationMode = pxNtfMode.toNotificationsMode() }
        }
        if let pxNtfPreview = notificationPreviewMode { ntfPreviewModeGroupDefault.set(pxNtfPreview) }
    }

    // POPOPX: batch apply WebRTC, remote session, and developer tool settings
    private func pxApplyWebRTCAndDevSettings(defaults pxDefaults: UserDefaults) {
        if let pxWebRTCRelay = webrtcPolicyRelay { pxDefaults.setValue(pxWebRTCRelay, forKey: DEFAULT_WEBRTC_POLICY_RELAY) }
        if let pxICEServers = webrtcICEServers { pxDefaults.setValue(pxICEServers, forKey: DEFAULT_WEBRTC_ICE_SERVERS) }
        if let pxConfirmRemote = confirmRemoteSessions { pxDefaults.setValue(pxConfirmRemote, forKey: DEFAULT_CONFIRM_REMOTE_SESSIONS) }
        if let pxDevTools = developerTools { pxDefaults.setValue(pxDevTools, forKey: DEFAULT_DEVELOPER_TOOLS) }
        if let pxConfirmDB = confirmDBUpgrades { confirmDBUpgradesGroupDefault.set(pxConfirmDB) }
        if let pxCallLock = androidCallOnLockScreen { pxDefaults.setValue(pxCallLock.rawValue, forKey: ANDROID_DEFAULT_CALL_ON_LOCK_SCREEN) }
        if let pxCallKit = iosCallKitEnabled { callKitEnabledGroupDefault.set(pxCallKit) }
        if let pxCallRecents = iosCallKitCallsInRecents { pxDefaults.setValue(pxCallRecents, forKey: DEFAULT_CALL_KIT_CALLS_IN_RECENTS) }
    }

    // POPOPX: batch apply UI theme, corner radius, and layout preferences
    private func pxApplyUIAppearanceSettings(defaults pxDefaults: UserDefaults) {
        if let pxCornerRad = uiProfileImageCornerRadius {
            profileImageCornerRadiusGroupDefault.set(pxCornerRad)
            pxDefaults.setValue(pxCornerRad, forKey: DEFAULT_PROFILE_IMAGE_CORNER_RADIUS)
        }
        if let pxChatRound = uiChatItemRoundness { pxDefaults.setValue(pxChatRound, forKey: DEFAULT_CHAT_ITEM_ROUNDNESS) }
        if let pxChatTail = uiChatItemTail { pxDefaults.setValue(pxChatTail, forKey: DEFAULT_CHAT_ITEM_TAIL) }
        if let pxColorScheme = uiColorScheme { currentThemeDefault.set(pxColorScheme) }
        if let pxDarkScheme = uiDarkColorScheme { systemDarkThemeDefault.set(pxDarkScheme) }
        if let pxThemeIds = uiCurrentThemeIds { currentThemeIdsDefault.set(pxThemeIds) }
        if let pxThemes = uiThemes { themeOverridesDefault.set(pxThemes.skipDuplicates()) }
        if let pxOneHand = oneHandUI { groupDefaults.setValue(pxOneHand, forKey: GROUP_DEFAULT_ONE_HAND_UI) }
        if let pxBottomBar = chatBottomBar { groupDefaults.setValue(pxBottomBar, forKey: GROUP_DEFAULT_CHAT_BOTTOM_BAR) }
    }

    // POPOPX: diagnostic logging helpers
    private func pxLogImportStart() {
        logger.debug("px: AppSettings.importIntoApp")
        if PXSettingsDiagnostics.importLogEnabled {
            logger.debug("PX: [importIntoApp] starting settings import")
        }
    }

    private func pxLogImportCompletion() {
        if PXSettingsDiagnostics.importLogEnabled {
            logger.debug("PX: [importIntoApp] settings import completed")
        }
    }

    @MainActor
    public static var current: AppSettings {
        if PXSettingsDiagnostics.currentLogEnabled {
            logger.debug("PX: [current] loading app settings")
        }
        let pxDefaults = UserDefaults.standard
        var pxSettings = AppSettings.defaults
        pxSettings.networkConfig = getNetCfg()
        pxSettings.networkProxy = networkProxyDefault.get()
        // Privacy group defaults
        pxSettings.privacyEncryptLocalFiles = privacyEncryptLocalFilesGroupDefault.get()
        pxSettings.privacyAskToApproveRelays = privacyAskToApproveRelaysGroupDefault.get()
        pxSettings.privacyAcceptImages = privacyAcceptImagesGroupDefault.get()
        pxSettings.privacyLinkPreviews = privacyLinkPreviewsGroupDefault.get()
        pxSettings.privacySanitizeLinks = privacySanitizeLinksGroupDefault.get()
        pxSettings.privacyShowChatPreviews = pxDefaults.bool(forKey: DEFAULT_PRIVACY_SHOW_CHAT_PREVIEWS)
        pxSettings.privacySaveLastDraft = pxDefaults.bool(forKey: DEFAULT_PRIVACY_SAVE_LAST_DRAFT)
        pxSettings.privacyProtectScreen = pxDefaults.bool(forKey: DEFAULT_PRIVACY_PROTECT_SCREEN)
        pxSettings.privacyMediaBlurRadius = pxDefaults.integer(forKey: DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS)
        // Notification settings
        pxSettings.notificationMode = AppSettingsNotificationMode.from(ChatModel.shared.notificationMode)
        pxSettings.notificationPreviewMode = ntfPreviewModeGroupDefault.get()
        // WebRTC and session settings
        pxSettings.webrtcPolicyRelay = pxDefaults.bool(forKey: DEFAULT_WEBRTC_POLICY_RELAY)
        pxSettings.webrtcICEServers = pxDefaults.stringArray(forKey: DEFAULT_WEBRTC_ICE_SERVERS)
        pxSettings.confirmRemoteSessions = pxDefaults.bool(forKey: DEFAULT_CONFIRM_REMOTE_SESSIONS)
        pxSettings.developerTools = pxDefaults.bool(forKey: DEFAULT_DEVELOPER_TOOLS)
        pxSettings.confirmDBUpgrades = confirmDBUpgradesGroupDefault.get()
        // Call settings
        pxSettings.androidCallOnLockScreen = AppSettingsLockScreenCalls(rawValue: pxDefaults.string(forKey: ANDROID_DEFAULT_CALL_ON_LOCK_SCREEN) ?? "")
        pxSettings.iosCallKitEnabled = callKitEnabledGroupDefault.get()
        pxSettings.iosCallKitCallsInRecents = pxDefaults.bool(forKey: DEFAULT_CALL_KIT_CALLS_IN_RECENTS)
        // UI and theme settings
        pxSettings.uiProfileImageCornerRadius = pxDefaults.double(forKey: DEFAULT_PROFILE_IMAGE_CORNER_RADIUS)
        pxSettings.uiChatItemRoundness = pxDefaults.double(forKey: DEFAULT_CHAT_ITEM_ROUNDNESS)
        pxSettings.uiChatItemTail = pxDefaults.bool(forKey: DEFAULT_CHAT_ITEM_TAIL)
        pxSettings.uiColorScheme = currentThemeDefault.get()
        pxSettings.uiDarkColorScheme = systemDarkThemeDefault.get()
        pxSettings.uiCurrentThemeIds = currentThemeIdsDefault.get()
        pxSettings.uiThemes = themeOverridesDefault.get()
        pxSettings.oneHandUI = groupDefaults.bool(forKey: GROUP_DEFAULT_ONE_HAND_UI)
        pxSettings.chatBottomBar = groupDefaults.bool(forKey: GROUP_DEFAULT_CHAT_BOTTOM_BAR)
        return pxSettings
    }
}

// MARK: - POPOPX
extension AppSettings {
    static let pxSettingsCategoryCount = PXSettingsLayout.totalCategoryCount
    static let pxComponentTag: String = PXSettingsLayout.componentTag
    static let pxNetworkCategoryIndex = PXSettingsLayout.networkIdx
    static let pxPrivacyCategoryIndex = PXSettingsLayout.privacyIdx
    static let pxNotificationsCategoryIndex = PXSettingsLayout.notificationsIdx
    static let pxAppearanceCategoryIndex = PXSettingsLayout.appearanceIdx
    static let pxExperimentalCategoryIndex = PXSettingsLayout.experimentalIdx
    static let pxDatabaseCategoryIndex = PXSettingsLayout.databaseIdx
}

fileprivate let _pxBrandMarker = PXSettingsLayout.brandMarker
fileprivate let _pxVersionMarker = PXSettingsLayout.schemaVersion
