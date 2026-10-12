//
//  POPOPXApp.swift
//  Shared
//
//  Created by Evgeny Poberezkin on 17/01/2022.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import OSLog
import POPOPXSwitch
import WebKit

let logger = Logger()

@main
// Spec: spec/architecture.md#POPOPXApp
struct POPOPXApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var chatModel = ChatModel.shared
    @ObservedObject var alertManager = AlertManager.shared

    @Environment(\.scenePhase) var scenePhase
    @State private var enteredBackgroundAuthenticated: TimeInterval? = nil
    @State private var lastSceneUpdateDate: Date? = nil
    @State private var showNeonSplash = true

    nonisolated static let _haskellReady = DispatchSemaphore(value: 0)
    nonisolated static let _initLock = NSLock()
    nonisolated(unsafe) private static var _haskellInitializedBacking = false
    static var _haskellInitialized: Bool {
        get { _initLock.lock(); defer { _initLock.unlock() }; return _haskellInitializedBacking }
        set { _initLock.lock(); defer { _initLock.unlock() }; _haskellInitializedBacking = newValue }
    }

    static let isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init() {
        if Self.isPreview { return }
        
        // Critical path - must complete before first render
        DispatchQueue.global(qos: .userInitiated).async {
            haskell_init()
            Self._haskellInitialized = true
            Self._haskellReady.signal()
        }
        UserDefaults.standard.register(defaults: appDefaults)
        setGroupDefaults()
        registerGroupDefaults()
        setDbContainer()
        
        // BGTaskScheduler registration must be synchronous during init
        BGManager.shared.register()

        // Deferred - not needed for initial UI, can run asynchronously
        Task {
            // TODO [TODO-FEATURE: high] cleanupOrphanedMigrationTempFiles not implemented
            // cleanupOrphanedMigrationTempFiles()
            NtfManager.shared.registerCategories()
            await TransportManager.shared.initialize()
            NeedleProcessor.shared.initialize()
            DeadMansSwitch.shared.recordActivity()
            await WKWebsiteDataStore.default().removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date.distantPast
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            // contentAccessAuthenticationExtended has to be passed to ContentView on view initialization,
            // so that it's computed by the time view renders, and not on event after rendering
            ContentView(contentAccessAuthenticationExtended: !authenticationExpired())
                .environmentObject(chatModel)
                .environmentObject(AppTheme.shared)
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(ComputeStore.shared)
                .onOpenURL { url in
                    logger.debug("ContentView.onOpenURL: \(url, privacy: .sensitive)")
                    let allowedSchemes: Set<String> = ["popop", "popopx", "https", "binthere"]
                    guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else { return }
                    if AppChatState.shared.value == .active {
                        chatModel.appOpenUrl = url
                    } else {
                        chatModel.appOpenUrlLater = url
                    }
                }
                .onAppear() {
                    logger.debug("POPOPXApp.onAppear triggered")
                    #if DEBUG
                    logger.debug("POPOPXApp.onAppear: migrationState=\(String(describing: chatModel.migrationState)), onboardingStage=\(String(describing: chatModel.onboardingStage))")
                    logger.debug("POPOPXApp.onAppear: kcAppPassword=\(kcAppPassword.get() != nil ? "exists" : "nil"), kcSelfDestructPassword=\(kcSelfDestructPassword.get() != nil ? "exists" : "nil")")
                    #endif

                    // Migrate legacy onboarding stage raw values from upstream naming
                    if let raw = UserDefaults.standard.string(forKey: DEFAULT_ONBOARDING_STAGE) {
                        let migrated = OnboardingStage.migratePersistedValue(raw)
                        if migrated != raw {
                            UserDefaults.standard.set(migrated, forKey: DEFAULT_ONBOARDING_STAGE)
                            logger.debug("POPOPXApp.onAppear: migrated onboarding stage '\(raw)' -> '\(migrated)'")
                        }
                    }

                    // Sync LA preference: group default is authoritative, old standard key may be stale
                    let groupLA = appLocalAuthEnabledGroupDefault.get()
                    let standardLA = UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)
                    if groupLA != standardLA {
                        UserDefaults.standard.set(groupLA, forKey: DEFAULT_PERFORM_LA)
                        logger.debug("POPOPXApp.onAppear: synced DEFAULT_PERFORM_LA from group default: \(groupLA)")
                    }

                    // Set initial onboarding stage for routing after launch screen completes.
                    // The LaunchScreenView handles calling initChatAndMigrate via LaunchCoordinator.
                    let hasDB = hasDatabase()
                    let storedStage = UserDefaults.standard.string(forKey: DEFAULT_ONBOARDING_STAGE)
                    
                    if storedStage == nil && kcAppPassword.get() == nil {
                        logger.debug("POPOPXApp.onAppear: first launch detected")
                        chatModel.onboardingStage = .step1_WelcomeIdentity
                    } else if storedStage == nil {
                        logger.debug("POPOPXApp.onAppear: previous install detected, setting onboardingComplete")
                        chatModel.onboardingStage = .onboardingComplete
                    } else if !hasDB {
                        // UserDefaults persists but DB was deleted (simulator erase incomplete, app reinstall, etc.)
                        logger.debug("POPOPXApp.onAppear: onboarding stage exists but no database, resetting to onboarding")
                        chatModel.onboardingStage = .step1_WelcomeIdentity
                    } else {
                        logger.debug("POPOPXApp.onAppear: onboardingStage already set to \(String(describing: chatModel.onboardingStage))")
                    }
                }
                .task {
                    await ComputeStore.shared.loadProducts()
                    await ComputeStore.shared.loadStoreKitProducts()
                    if ComplianceManager.shared.consentRecords.first(where: { $0.id == "1" })?.granted == true {
                        await ServerAPI.shared.registerDevice()
                    }
                }
                .overlay {
                    if showNeonSplash {
                        NeonLaunchView(isVisible: $showNeonSplash)
                            .onAppear {
                                Task {
                                    try? await Task.sleep(for: .seconds(1.5))
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        showNeonSplash = false
                                    }
                                }
                            }
                    }
                }
// Spec: spec/architecture.md#scenePhaseHandling
                .onChange(of: scenePhase) { oldPhase, phase in
                    logger.debug("scenePhase was \(String(describing: oldPhase)), now \(String(describing: phase))")
                    PXAppSheetState.shared.scenePhaseActive = phase == .active
                    switch (phase) {
                    case .background:
                        // --- authentication
                        // see ContentView .onChange(of: scenePhase) for remaining authentication logic
                        if chatModel.contentViewAccessAuthenticated {
                            enteredBackgroundAuthenticated = Date().timeIntervalSinceReferenceDate
                        }
                        chatModel.contentViewAccessAuthenticated = false
                        // authentication ---

                        // Persist compose draft to survive app termination
                        if let draft = chatModel.draft, !draft.message.isEmpty,
                           let draftChatId = chatModel.draftChatId {
                            groupDefaults.set(draft.message, forKey: "px_compose_draft")
                            groupDefaults.set(draftChatId, forKey: "px_compose_draft_chat_id")
                        }

                        Task { await NeedleProcessor.shared.shutdown() }

                        // Clear CryptoEncrypt in-memory key cache on background
                        CryptoEncrypt.shared.clearCache()

                        TransportManager.shared.pausePeerUpdates()
                        if CallController.useCallKit() && chatModel.activeCall != nil {
                            CallController.shared.shouldSuspendChat = true
                        } else {
                            suspendChat()
                            BGManager.shared.schedule()
                        }
                        NtfManager.shared.setNtfBadgeCount(chatModel.totalUnreadCountForAllUsers())
                    case .active:
                        // Restore persisted compose draft
                        if let draftMessage = groupDefaults.string(forKey: "px_compose_draft"),
                           let draftChatId = groupDefaults.string(forKey: "px_compose_draft_chat_id") {
                            if chatModel.draft == nil || chatModel.draft?.message.isEmpty == true {
                                chatModel.draft = ComposeState(message: draftMessage)
                                chatModel.draftChatId = draftChatId
                            }
                            groupDefaults.removeObject(forKey: "px_compose_draft")
                            groupDefaults.removeObject(forKey: "px_compose_draft_chat_id")
                        }

                        CallController.shared.shouldSuspendChat = false
                        TransportManager.shared.resumePeerUpdates()
                        NtfManager.shared.refreshAuthorizationStatus()
                        let appState = AppChatState.shared.value

                        Task {
                            await SubscriptionManager.shared.refreshOnActivation()

                            // Check if database key rotation is needed
                            if chatModel.chatRunning == true && checkAndRotateDatabaseKeyIfNeeded() {
                                await MainActor.run {
                                    chatModel.showComputeStore = false
                                    chatModel.showKeyRotationNotice = true
                                }
                            }
                        }

                        if appState != .stopped {
                            startChatAndActivate {
                                if chatModel.chatRunning == true {
                                    let now = Date()
                                    let shouldUpdate = lastSceneUpdateDate == nil || now.timeIntervalSince(lastSceneUpdateDate!) >= 30

                                    if let ntfResponse = chatModel.notificationResponse {
                                        chatModel.notificationResponse = nil
                                        Task { @MainActor in
                                            NtfManager.shared.processNotificationResponse(ntfResponse)
                                        }
                                    }
                                    chatModel.meshBridge?.consumePendingSharePayload()
                                    checkClipboardForPopopxLink()
                                    if appState.inactive && shouldUpdate {
                                        lastSceneUpdateDate = now
                                        Task {
                                            await updateChats()
                                            if !chatModel.showCallView && !CallController.shared.hasActiveCalls() {
                                                await updateCallInvitations()
                                            }
                                            if let url = chatModel.appOpenUrlLater {
                                                await MainActor.run {
                                                    chatModel.appOpenUrlLater = nil
                                                    chatModel.appOpenUrl = url
                                                }
                                            }
                                        }
                                    } else if let url = chatModel.appOpenUrlLater {
                                        chatModel.appOpenUrlLater = nil
                                        chatModel.appOpenUrl = url
                                    }
                                }
                            }
                        }
                    default:
                        break
                    }
                }
        }
    }

    private func setDbContainer() {
// Uncomment and run once to open DB in app documents folder:
//         dbContainerGroupDefault.set(.documents)
//         v3DBMigrationDefault.set(.offer)
// to create database in app documents folder also uncomment:
//         let legacyDatabase = true
        let legacyDatabase = hasLegacyDatabase()
        if legacyDatabase, case .documents = dbContainerGroupDefault.get() {
            dbContainerGroupDefault.set(.documents)
            setMigrationState(.offer)
            logger.debug("POPOPXApp init: using legacy DB in documents folder")
        } else {
            dbContainerGroupDefault.set(.group)
            setMigrationState(.ready)
            logger.debug("POPOPXApp init: using DB in app group container")
            logger.debug("POPOPXApp init: legacy DB\(legacyDatabase ? "" : " not") present")
        }
    }

    private func setMigrationState(_ state: V3DBMigrationState) {
        if case .migrated = v3DBMigrationDefault.get() { return }
        v3DBMigrationDefault.set(state)
        AppStateModel.shared.v3DBMigration = state
    }

    private func authenticationExpired() -> Bool {
        if let enteredBackgroundAuthenticated = enteredBackgroundAuthenticated {
            let delay = Double(UserDefaults.standard.integer(forKey: DEFAULT_LA_LOCK_DELAY))
            return Date().timeIntervalSinceReferenceDate - enteredBackgroundAuthenticated >= delay
        } else {
            return true
        }
    }

    private func updateChats() async {
        do {
            let chats = try await apiGetChatsAsync()
            await MainActor.run { chatModel.updateChats(chats) }
            if let id = chatModel.chatId,
               let chat = chatModel.getChat(id),
               !NtfManager.shared.navigatingToChat {
                Task { await loadChat(chat: chat, im: ItemsModel.shared, clearItems: false) }
            }
            if let ncr = chatModel.ntfContactRequest {
                await MainActor.run { chatModel.ntfContactRequest = nil }
                if case let .contactRequest(contactRequest) = chatModel.getChat(ncr.chatId)?.chatInfo {
                    Task { await acceptContactRequest(incognito: false, contactRequestId: contactRequest.apiId) }
                }
            }
        } catch let error {
            logger.error("apiGetChats: cannot update chats \(responseError(error))")
        }
    }

    private func updateCallInvitations() async {
        do {
            try await refreshCallInvitations()
        } catch let error {
            logger.error("apiGetCallInvitations: cannot update call invitations \(responseError(error))")
        }
    }

    private func checkClipboardForPopopxLink() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.hasPrefix("popopx:/") else { return }
        // Ignore encrypted connection links generated by this app (user's own share links)
        if text.hasPrefix("popopx://enc#") { return }
        let hash = String(text.hashValue)
        let lastHash = UserDefaults.standard.string(forKey: "px_last_clipboard_link_hash")
        guard hash != lastHash else { return }
        UserDefaults.standard.set(hash, forKey: "px_last_clipboard_link_hash")
        chatModel.clipboardDetectedLink = text
    }
}
