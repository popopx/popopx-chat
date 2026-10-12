//
//  AppDelegate.swift
//  POPOPX
//
//  Created by Evgeny on 30/03/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/notifications.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import Foundation
import UIKit
import POPOPXSwitch
import SwiftUI
import os
import BitchatMesh

private let appDelegateLogger = Logger(subsystem: "com.popopxchat.popopx", category: "AppDelegate")

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    private var protectedDataWillBecomeUnavailableObserver: NSObjectProtocol?
    private var protectedDataDidBecomeAvailableObserver: NSObjectProtocol?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        appDelegateLogger.info("didFinishLaunchingWithOptions called")
        PrivacyScreen.shared.install()
        logger.debug("AppDelegate: didFinishLaunchingWithOptions")
        application.registerForRemoteNotifications()
        DispatchQueue.global(qos: .utility).async { [weak self] in self?.removePasscodesIfReinstalled() }
        prepareForLaunch()
        ThemeManager.migrateThemes() // Migrate old themes (POPOPX/QUANTUM/etc) to DARK
        deleteOldChatArchive()
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            logger.debug("AppDelegate: memory warning received, releasing caches")
            URLCache.shared.removeAllCachedResponses()
            ImageUtils.clearCache()
        }

        // Protected data availability observers
        protectedDataWillBecomeUnavailableObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil, queue: .main
        ) { _ in
            logger.debug("POPOPXApp: protected data will become unavailable")
        }
        protectedDataDidBecomeAvailableObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil, queue: .main
        ) { _ in
            logger.debug("POPOPXApp: protected data did become available")
        }

        return true
    }

    deinit {
        if let observer = protectedDataWillBecomeUnavailableObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = protectedDataDidBecomeAvailableObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02hhx", $0) }.joined()
        logger.debug("AppDelegate: didRegisterForRemoteNotificationsWithDeviceToken \(token, privacy: .private)")
        let m = ChatModel.shared
        let deviceToken = DeviceToken(pushProvider: PushProvider(env: pushEnvironment), token: token)
        m.deviceToken = deviceToken
        // savedToken is set in startChat, when it is started before this method is called
        if m.savedToken != nil {
            registerToken(token: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("AppDelegate: didFailToRegisterForRemoteNotificationsWithError \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.debug("AppDelegate: didReceiveRemoteNotification")
        let m = ChatModel.shared
        if let ntfData = userInfo["notificationData"] as? [AnyHashable : Any],
           m.notificationMode != .off {
            if let verification = ntfData["verification"] as? String,
               let nonce = ntfData["nonce"] as? String {
                if let token = m.deviceToken {
                    logger.debug("AppDelegate: didReceiveRemoteNotification: verification, confirming \(verification, privacy: .sensitive)")
                    // Ensure completionHandler is called within 25s even if the Task hangs
                    var completionCalled = false
                    let completionLock = NSLock()
                    let callCompletion: (UIBackgroundFetchResult) -> Void = { result in
                        completionLock.lock()
                        defer { completionLock.unlock() }
                        guard !completionCalled else { return }
                        completionCalled = true
                        completionHandler(result)
                    }
                    Task {
                        do {
                            if case .active = m.tokenStatus {} else { m.tokenStatus = .confirmed }
                            try await apiVerifyToken(token: token, nonce: nonce, code: verification)
                            m.tokenStatus = .active
                        } catch {
                            if let cr = error as? ChatError, case .errorAgent(.NTF(.AUTH)) = cr {
                                m.tokenStatus = .expired
                            }
                            logger.error("AppDelegate: didReceiveRemoteNotification: apiVerifyToken or apiIntervalNofication error: \(responseError(error))")
                        }
                        callCompletion(.newData)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                        callCompletion(.noData)
                    }
                } else {
                    completionHandler(.noData)
                }
            } else if let checkMessages = ntfData["checkMessages"] as? Bool, checkMessages {
                logger.debug("AppDelegate: didReceiveRemoteNotification: checkMessages")
                if m.ntfEnablePeriodic && allowBackgroundRefresh() && BGManager.shared.lastRanLongAgo {
                    receiveMessages(completionHandler)
                } else {
                    completionHandler(.noData)
                }
            } else {
                completionHandler(.noData)
            }
        } else {
            completionHandler(.noData)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        ChatModel.shared.filesToDelete.forEach {
            removeFile($0)
        }
        ChatModel.shared.filesToDelete = []
        if ChatModel.shared.chatInitialized {
            ffiQueue.async { chatCloseStore() }
        }
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SceneDelegate.self
        }
        return configuration
    }

    private func receiveMessages(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let complete = BGManager.shared.completionHandler {
            logger.debug("AppDelegate: completed BGManager.receiveMessages")
            completionHandler(.newData)
        }

        BGManager.shared.receiveMessages(complete)
    }

    private nonisolated func removePasscodesIfReinstalled() {
        // Prevent duplicate execution if didFinishLaunchingWithOptions is called multiple times
        let cleanupKey = "AppDelegate.cleanupPerformed"
        if UserDefaults.standard.bool(forKey: cleanupKey) {
            logger.debug("removePasscodesIfReinstalled: already performed in this session, skipping")
            return
        }
        UserDefaults.standard.set(true, forKey: cleanupKey)

        // Check for the database existence, because app and self destruct passcodes
        // will be saved and restored by iOS when a user deletes and re-installs the app.
        // In this case the database and settings will be deleted, but the passcodes won't be.
        // Deleting passcodes ensures that the user will not get stuck on "Opening app..." screen.
        let hasDB = hasDatabase()
        let hasAppPasswords = kcAppPassword.get() != nil || kcSelfDestructPassword.get() != nil
        let hasDBPassword = kcDatabasePassword.get() != nil
        // FIX: Include kcDatabasePassword in hasStoredPasswords check.
        // POPOPX creates DB with kcDatabasePassword during onboarding, but may not set kcAppPassword.
        // Without this fix, app deletes DB on every launch because hasStoredPasswords is false.
        let hasStoredPasswords = hasAppPasswords || hasDBPassword
        let performLA = UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)

        appDelegateLogger.info("removePasscodesIfReinstalled: hasStoredPasswords=\(String(hasStoredPasswords), privacy: .private), hasDB=\(String(hasDB), privacy: .private), hasDBPassword=\(String(hasDBPassword), privacy: .private), performLA=\(String(performLA), privacy: .private)")
        logger.debug("removePasscodesIfReinstalled: hasStoredPasswords=\(String(hasStoredPasswords), privacy: .private), hasDB=\(String(hasDB), privacy: .private), hasDBPassword=\(String(hasDBPassword), privacy: .private), performLA=\(String(performLA), privacy: .private)")

        if !performLA {
            if hasStoredPasswords && !hasDB {
                // Reinstall scenario: keychain has passwords but DB is gone
                appDelegateLogger.info("removePasscodesIfReinstalled: removing orphaned passwords (DB missing)")
                logger.debug("removePasscodesIfReinstalled: removing orphaned passwords (DB missing)")
                _ = kcAppPassword.remove()
                _ = kcSelfDestructPassword.remove()
                _ = kcDatabasePassword.remove()
                _ = kcDatabaseSalt.remove()
            }
            if hasDB && !hasStoredPasswords {
                // Keychain lost scenario: DB exists but no passwords in keychain
                appDelegateLogger.info("removePasscodesIfReinstalled: database exists but no passwords, removing database for fresh install")
                logger.debug("removePasscodesIfReinstalled: database exists but no passwords, removing database for fresh install")
                deleteAppDatabaseAndFiles()
            }
        } else {
            appDelegateLogger.info("removePasscodesIfReinstalled: skipping cleanup (performLA is true)")
            logger.debug("removePasscodesIfReinstalled: skipping cleanup (performLA is true)")
        }
    }

    private func prepareForLaunch() {
        do {
            try FileManager.default.createDirectory(at: getWallpaperDirectory(), withIntermediateDirectories: true)
        } catch {
            logger.error("AppDelegate: failed to create wallpaper directory: \(error.localizedDescription)")
        }
        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: getWallpaperDirectory().path)
        } catch {
            logger.error("AppDelegate: failed to set file protection on wallpaper directory: \(error.localizedDescription)")
        }
        excludeAppDataFromBackup()
    }

    nonisolated static func keepScreenOn(_ on: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = on
        }
    }
}

@MainActor
class SceneDelegate: NSObject, ObservableObject, UIWindowSceneDelegate {
    var window: UIWindow?
    static var windowStatic: UIWindow?
    var windowScene: UIWindowScene?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        UITableView.appearance().backgroundColor = .clear
        UIView.appearance().semanticContentAttribute = .unspecified
        guard let windowScene = scene as? UIWindowScene else { return }
        self.windowScene = windowScene
        window = windowScene.windows.first { $0.isKeyWindow }
        SceneDelegate.windowStatic = windowScene.windows.first { $0.isKeyWindow }
        migrateAccentColorAndTheme()
        ThemeManager.applyTheme(currentThemeDefault.get())
        ThemeManager.adjustWindowStyle()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        logger.debug("SceneDelegate: sceneDidDisconnect - \(scene)")
        window = nil
        SceneDelegate.windowStatic = nil
    }

    private func migrateAccentColorAndTheme() {
        let defs = UserDefaults.standard
        /// For checking migration
//        themeOverridesDefault.set([])
//        currentThemeDefault.set(DefaultTheme.SYSTEM_THEME_NAME)
//        defs.set(0.5, forKey: DEFAULT_ACCENT_COLOR_RED)
//        defs.set(0.3, forKey: DEFAULT_ACCENT_COLOR_GREEN)
//        defs.set(0.8, forKey: DEFAULT_ACCENT_COLOR_BLUE)

        let userInterfaceStyle = getUserInterfaceStyleDefault()
        if defs.double(forKey: DEFAULT_ACCENT_COLOR_GREEN) == 0 && userInterfaceStyle == .unspecified {
            // No migration needed or already migrated
            return
        }

        let defaultAccentColor = Color(cgColor: CGColor(red: 0.000, green: 0.533, blue: 1.000, alpha: 1))
        let accentColor = Color(cgColor: getUIAccentColorDefault())
        if accentColor != defaultAccentColor {
            let colors = ThemeColors(primary: accentColor.toReadableHex())
            var overrides = themeOverridesDefault.get()
            var themeIds = currentThemeIdsDefault.get()
            switch userInterfaceStyle {
            case .light:
                let light = ThemeOverrides(base: DefaultTheme.LIGHT, colors: colors, wallpaper: ThemeWallpaper(preset: PresetWallpaper.school.filename))
                overrides.append(light)
                themeOverridesDefault.set(overrides)
                themeIds[DefaultTheme.LIGHT.themeName] = light.themeId
                currentThemeIdsDefault.set(themeIds)
                ThemeManager.applyTheme(DefaultTheme.LIGHT.themeName)
            case .dark:
                let dark = ThemeOverrides(base: DefaultTheme.DARK, colors: colors, wallpaper: ThemeWallpaper(preset: PresetWallpaper.school.filename))
                overrides.append(dark)
                themeOverridesDefault.set(overrides)
                themeIds[DefaultTheme.DARK.themeName] = dark.themeId
                currentThemeIdsDefault.set(themeIds)
                ThemeManager.applyTheme(DefaultTheme.DARK.themeName)
            case .unspecified:
                let light = ThemeOverrides(base: DefaultTheme.LIGHT, colors: colors, wallpaper: ThemeWallpaper(preset: PresetWallpaper.school.filename))
                let dark = ThemeOverrides(base: DefaultTheme.DARK, colors: colors, wallpaper: ThemeWallpaper(preset: PresetWallpaper.school.filename))
                overrides.append(light)
                overrides.append(dark)
                themeOverridesDefault.set(overrides)
                themeIds[DefaultTheme.LIGHT.themeName] = light.themeId
                themeIds[DefaultTheme.DARK.themeName] = dark.themeId
                currentThemeIdsDefault.set(themeIds)
                ThemeManager.applyTheme(DefaultTheme.SYSTEM_THEME_NAME)
            @unknown default: ()
            }
        } else if userInterfaceStyle != .unspecified {
            let themeName = switch userInterfaceStyle {
            case .light: DefaultTheme.LIGHT.themeName
            case .dark: DefaultTheme.DARK.themeName
            default: DefaultTheme.SYSTEM_THEME_NAME
            }
            ThemeManager.applyTheme(themeName)
        }
        defs.removeObject(forKey: DEFAULT_ACCENT_COLOR_RED)
        defs.removeObject(forKey: DEFAULT_ACCENT_COLOR_GREEN)
        defs.removeObject(forKey: DEFAULT_ACCENT_COLOR_BLUE)
        defs.removeObject(forKey: DEFAULT_USER_INTERFACE_STYLE)
    }
}
