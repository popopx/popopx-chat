//
//  ContentView.swift
//  Shared
//
//  Created by Evgeny Poberezkin on 17/01/2022.
//
// Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import Intents
import POPOPXSwitch

private enum NoticesSheet: Identifiable {
    case whatsNew(updatedConditions: Bool)

    var id: String {
        switch self {
        case .whatsNew: return "whatsNew"
        }
    }
}

// Spec: spec/client/navigation.md#ContentView
struct ContentView: View {
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject var appState = AppStateModel.shared
    @ObservedObject var alertManager = AlertManager.shared
    @ObservedObject var callController = CallController.shared
    // Spec: spec/client/navigation.md#PXAppSheetState
    @ObservedObject var appSheetState = PXAppSheetState.shared
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var subscription: SubscriptionManager

    // Spec: spec/client/navigation.md#contentAccessAuthenticationExtended
    var contentAccessAuthenticationExtended: Bool

    @Environment(\.scenePhase) var scenePhase
    @State private var automaticAuthenticationAttempted = false
    @State private var canConnectViewCall = false
    @State private var lastSuccessfulUnlock: TimeInterval? = nil

    @AppStorage(DEFAULT_SHOW_LA_NOTICE) private var prefShowLANotice = false
    @AppStorage(DEFAULT_LA_NOTICE_SHOWN) private var prefLANoticeShown = false
    @AppStorage(DEFAULT_PERFORM_LA) private var prefPerformLA = false
    @AppStorage(DEFAULT_PRIVACY_PROTECT_SCREEN) private var protectScreen = false
    @AppStorage(DEFAULT_NOTIFICATION_ALERT_SHOWN) private var notificationAlertShown = false
    @State private var noticesShown = false
    @State private var noticesSheetItem: NoticesSheet? = nil
    @State private var showChooseLAMode = false
    @State private var showSetPasscode = false
    @State private var waitingForOrPassedAuth = true
    @State private var chatListUserPickerSheet: UserPickerSheet? = nil
    @State private var showRenewalReminder = false
    @State private var renewalReminderShown = false
    @State private var trialBannerDismissed = false
    @State private var showTrialSubscribe = false
    @State private var initTimeoutReached = false
    @State private var launchComplete = false

    private let callTopPadding: CGFloat = 40

    private var accessAuthenticated: Bool {
        chatModel.contentViewAccessAuthenticated || contentAccessAuthenticationExtended
    }

    var body: some View {
        allViews()
        .popopxBranded()
    }

    func allViews() -> some View {
        ZStack {
            let showCallArea = chatModel.activeCall != nil && chatModel.activeCall?.callState != .waitCapabilities && chatModel.activeCall?.callState != .invitationAccepted
            // contentView() has to be in a single branch, so that enabling authentication doesn't trigger re-rendering and close settings.
            // i.e. with separate branches like this settings are closed: `if prefPerformLA { ... contentView() ... } else { contentView() }
            if !prefPerformLA || accessAuthenticated {
                contentView()
                    .padding(.top, showCallArea ? callTopPadding : 0)
            } else {
                lockButton()
                    .padding(.top, showCallArea ? callTopPadding : 0)
            }

            if showCallArea, let call = chatModel.activeCall {
                VStack {
                    activeCallInteractiveArea(call)
                    Spacer()
                }
            }

            if chatModel.showCallView, let call = chatModel.activeCall {
                callView(call)
            }

            if chatListUserPickerSheet == nil, let la = chatModel.laRequest {
                LocalAuthView(authRequest: la)
                    .onDisappear {
                        // this flag is separate from accessAuthenticated to show initializationView while we wait for authentication
                        waitingForOrPassedAuth = accessAuthenticated
                    }
            } else if showSetPasscode {
                SetAppPasscodeView {
                    chatModel.contentViewAccessAuthenticated = true
                    prefPerformLA = true
                    showSetPasscode = false
                    privacyLocalAuthModeDefault.set(.passcode)
                    alertManager.showAlert(laTurnedOnAlert())
                } cancel: {
                    prefPerformLA = false
                    showSetPasscode = false
                    alertManager.showAlert(laPasscodeNotSetAlert())
                }
            } else if chatModel.chatDbStatus == nil && appState.onboardingStage == nil && AppChatState.shared.value != .stopped && waitingForOrPassedAuth {
                initializationView()
            }
        }
        .overlay {
            if alertManager.presentAlert {
                if let legacyAlert = alertManager.legacyAlert {
                    // Legacy Alert - use standard iOS alert
                    Color.clear
                        .alert(isPresented: $alertManager.presentAlert) { legacyAlert }
                } else {
                    // New GlassAlertView - cyberpunk styled
                    GlassAlertView(
                        title: alertManager.alertTitle,
                        message: alertManager.alertMessage,
                        primaryButton: alertManager.alertPrimaryButton,
                        secondaryButton: alertManager.alertSecondaryButton.map { (text: $0.0, action: $0.1) },
                        destructiveButton: alertManager.alertDestructiveButton,
                        onDismiss: { alertManager.presentAlert = false }
                    )
                    .zIndex(1000)
                }
            }
        }
        .onChange(of: alertManager.presentAlert) { _, isPresented in
            if !isPresented { alertManager.legacyAlert = nil }
        }
        .confirmationDialog(NSLocalizedString("POPOPX Lock mode", comment: "lock mode chooser title"), isPresented: $showChooseLAMode, titleVisibility: .visible) {
            Button(NSLocalizedString("System authentication", comment: "lock mode option")) { initialEnableLA() }
            Button(NSLocalizedString("Passcode entry", comment: "lock mode option")) { showSetPasscode = true }
        }
        .onChange(of: scenePhase) { oldPhase, phase in
            logger.debug("scenePhase was \(String(describing: oldPhase)), now \(String(describing: phase))")
            switch (phase) {
            case .background:
                // also see .onChange(of: scenePhase) in POPOPXApp: on entering background
                // it remembers enteredBackgroundAuthenticated and sets chatModel.contentViewAccessAuthenticated to false
                automaticAuthenticationAttempted = false
                canConnectViewCall = false
            case .active:
                canConnectViewCall = !prefPerformLA || contentAccessAuthenticationExtended || unlockedRecently()
                
                // condition `!chatModel.contentViewAccessAuthenticated` is required for when authentication is enabled in settings or on initial notice
                if prefPerformLA && !chatModel.contentViewAccessAuthenticated {
                    if AppChatState.shared.value != .stopped {
                        if contentAccessAuthenticationExtended {
                            chatModel.contentViewAccessAuthenticated = true
                        } else {
                            if !automaticAuthenticationAttempted {
                                automaticAuthenticationAttempted = true
                                // authenticate if call kit call is not in progress
                                if !(CallController.useCallKit() && chatModel.showCallView && chatModel.activeCall != nil) {
                                    authenticateContentViewAccess()
                                }
                            }
                        }
                    } else {
                        // when app is stopped automatic authentication is not attempted
                        chatModel.contentViewAccessAuthenticated = contentAccessAuthenticationExtended
                    }
                }
            default:
                break
            }
        }
        .onAppear {
            reactOnDarkThemeChanges(systemInDarkThemeCurrently)
        }
        .onChange(of: colorScheme) {_,  scheme in
            // It's needed to update UI colors when iOS wants to make screenshot after going to background,
            // so when a user changes his global theme from dark to light or back, the app will adapt to it
            reactOnDarkThemeChanges(scheme == .dark)
        }
        .onChange(of: theme.name) {_, _ in
            ThemeManager.adjustWindowStyle()
        }
    }

    // Spec: spec/client/navigation.md#contentView
    @ViewBuilder private func contentView() -> some View {
        if !launchComplete {
            LaunchScreenView(onLaunchComplete: {
                launchComplete = true
            })
        } else if let status = chatModel.chatDbStatus, status != .ok {
            // Check if database files actually exist - if they do, proceed to onboarding
            // This handles cases where FFI returns error but DB was created successfully
            Group {
                if hasValidDatabaseFiles() {
                    proceedToOnboardingOrMain()
                } else {
                    DatabaseErrorView(status: status)
                }
            }
        } else if !chatModel.v3DBMigration.startChat {
            MigrateToAppGroupView()
        } else if let step = appState.onboardingStage {
            if case .onboardingComplete = step,
               chatModel.currentUser != nil {
                mainView()
            } else if case .onboardingComplete = step,
               chatModel.currentUser == nil {
                initializationView()
            } else {
                OnboardingView(onboarding: step)
            }
        } else {
            initializationView()
        }
    }
    
    /// Check if database files exist and have non-zero size
    private func hasValidDatabaseFiles() -> Bool {
        let dbPath = getAppDatabasePath().path
        let fm = FileManager.default
        let chatDb = dbPath + "_chat.db"
        let agentDb = dbPath + "_agent.db"
        
        // Check if both database files exist and have content
        guard fm.fileExists(atPath: chatDb),
              fm.fileExists(atPath: agentDb) else {
            return false
        }
        
        // Check file sizes are non-zero
        do {
            let chatAttrs = try fm.attributesOfItem(atPath: chatDb)
            let agentAttrs = try fm.attributesOfItem(atPath: agentDb)
            
            if let chatSize = chatAttrs[FileAttributeKey.size] as? Int64,
               let agentSize = agentAttrs[FileAttributeKey.size] as? Int64 {
                return chatSize > 0 && agentSize > 0
            }
        } catch {
            logger.error("ContentView: failed to check database file attributes: \(error.localizedDescription)")
        }
        
        return false
    }
    
    /// Proceed to onboarding or main view based on current state
    @ViewBuilder private func proceedToOnboardingOrMain() -> some View {
        if !chatModel.v3DBMigration.startChat {
            MigrateToAppGroupView()
        } else if let step = appState.onboardingStage {
            if case .onboardingComplete = step,
               chatModel.currentUser != nil {
                mainView()
            } else if case .onboardingComplete = step,
               chatModel.currentUser == nil {
                initializationView()
            } else {
                OnboardingView(onboarding: step)
            }
        } else {
            initializationView()
        }
    }

    // Spec: spec/client/navigation.md#callView
    @ViewBuilder private func callView(_ call: Call) -> some View {
        if CallController.useCallKit() {
            PXActiveCall(call: call, canConnectCall: Binding.constant(true))
                .onDisappear {
                    if prefPerformLA && !accessAuthenticated { authenticateContentViewAccess() }
                }
        } else {
            PXActiveCall(call: call, canConnectCall: $canConnectViewCall)
            if prefPerformLA && !accessAuthenticated {
                Rectangle()
                    .fill(colorScheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                lockButton()
            }
        }
    }

    // Spec: spec/client/navigation.md#callBanner
    private func activeCallInteractiveArea(_ call: Call) -> some View {
        HStack {
            Text(call.contact.displayName).font(.body).foregroundColor(.white)
            Spacer()
            CallDuration(call: call)
        }
        .padding(.horizontal)
        .frame(height: callTopPadding)
        .background(theme.colors.primary)
        .onTapGesture {
            chatModel.activeCallViewIsCollapsed = false
        }
    }

    struct CallDuration: View {
        let call: Call
        @State var text: String = ""

        var body: some View {
            Text(text).frame(minWidth: text.count <= 5 ? 52 : 77, alignment: .leading).offset(x: 4).font(.body).foregroundColor(.white)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                    if let connectedAt = call.connectedAt {
                        text = durationText(Int(Date.now.timeIntervalSince1970 - connectedAt.timeIntervalSince1970))
                    }
                }
            }
        }
    }

    // Spec: spec/client/navigation.md#lockButton
    private func lockButton() -> some View {
        Button(action: authenticateContentViewAccess) { Label(NSLocalizedString("unlock_button", comment: "Unlock button label"), systemImage: "lock") }
    }

    private func initializationView() -> some View {
        ZStack {
            QuantumFieldBackground()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: QuantumColors.accent.opacity(0.5), radius: 12, x: 0, y: 0)
                        .quantumPulse(color: QuantumColors.accent, duration: 2.0)

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(QuantumColors.accent)
                }

                Text(NSLocalizedString("Opening app…", comment: "initialization progress message"))
                    .font(.system(.body).weight(.semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.textPrimary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .shadow(color: QuantumColors.accent.opacity(0.4), radius: 8, x: 0, y: 1)
                    .padding()

                if initTimeoutReached {
                    Text(NSLocalizedString("Taking longer than expected. You can retry or wait.", comment: "init timeout message"))
                        .font(.callout)
                        .foregroundColor(QuantumColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        initTimeoutReached = false
                        retryInitialization()
                    } label: {
                        Text(NSLocalizedString("Retry", comment: "Retry button"))
                    }
                    .buttonStyle(QuantumButtonStyle(primary: true))
                    .padding(.horizontal, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if !initTimeoutReached {
                try? await Task.sleep(nanoseconds: 15_000_000000)
                if !Task.isCancelled && chatModel.chatDbStatus == nil && appState.onboardingStage == nil {
                    initTimeoutReached = true
                }
            }
        }
    }

    private func retryInitialization() {
        logger.debug("ContentView: retrying initialization")
        Task { @MainActor in
            await initChatAndMigrate()
        }
    }

    private func mainView() -> some View {
        ZStack(alignment: .top) {
            if subscription.showTrialReminder && !trialBannerDismissed {
                TrialReminderBanner {
                    presentSheet(&showTrialSubscribe)
                }
                .environmentObject(theme)
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation { trialBannerDismissed = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                            .padding(.trailing, 8)
                            .padding(.top, 4)
                    }
                    .accessibilityLabel(Text(NSLocalizedString("Close", comment: "close button")))
                }
                .zIndex(1)
            }
            RootTabView(activeUserPickerSheet: $chatListUserPickerSheet)
                .redacted(reason: appSheetState.redactionReasons(protectScreen))
            .onAppear {
                // Connect only after the notifications prompt is resolved: the system prompt suspends
                // the app (scene .inactive), which kills an in-flight connect and makes
                // getTopViewController() nil. Deferring keeps the URL until the app is active again.
                let openingViaLink = pendingConnectUrl != nil
                requestNtfAuthorization(showDeniedAlert: !openingViaLink) {
                    connectViaUrl()
                }
                if !openingViaLink {
                    // Local Authentication notice is to be shown on next start after onboarding is complete
                    if (!prefLANoticeShown && prefShowLANotice && chatModel.chats.count > 2) {
                        prefLANoticeShown = true
                        alertManager.showAlert(laNoticeAlert())
                    } else if !chatModel.showCallView && CallController.shared.activeCallInvitation == nil {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            guard !noticesShown, scenePhase == .active else { return }
                            let showWhatsNew = shouldShowWhatsNew()
                            let showUpdatedConditions = chatModel.conditions.conditionsAction?.showNotice ?? false
                            noticesShown = showWhatsNew || showUpdatedConditions
                            if showWhatsNew || showUpdatedConditions {
                                noticesSheetItem = .whatsNew(updatedConditions: showUpdatedConditions)
                            }
                        }
                    }
                    showReRegisterTokenAlert()
                }
                prefShowLANotice = true
            }
            .onChange(of: chatModel.appOpenUrl) {_, _ in connectViaUrl() }
            .onChange(of: chatModel.reRegisterTknStatus) {_, _ in showReRegisterTokenAlert() }
            .sheet(item: $noticesSheetItem) { item in
                switch item {
                case let .whatsNew(updatedConditions):
                    WhatsNewView(updatedConditions: updatedConditions)
                        .modifier(ThemedBackground())
                        .if(updatedConditions) { v in
                            v.task { await setConditionsNotified_() }
                        }
                }
            }
            if chatModel.setDeliveryReceipts {
                SetDeliveryReceiptsView()
            }
            IncomingCallView()
            if let link = chatModel.clipboardDetectedLink {
                ClipboardLinkBanner(link: link) {
                    chatModel.clipboardDetectedLink = nil
                } onConnect: {
                    chatModel.clipboardDetectedLink = nil
                    planAndConnect(link, theme: theme, dismiss: false)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: chatModel.clipboardDetectedLink)
        .onContinueUserActivity("INStartCallIntent", perform: processUserActivity)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            if let url = userActivity.webpageURL {
                #if DEBUG
                logger.debug("onContinueUserActivity.NSUserActivityTypeBrowsingWeb: \(url)")
                #endif
                chatModel.appOpenUrl = url
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { subscription.isLocked || chatModel.showPaywall },
            set: { chatModel.showPaywall = $0 }
        )) {
            PaywallView()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showRenewalReminder) {
            SubscriptionRenewalView()
                .environmentObject(theme)
        }
        .onChange(of: subscription.needsRenewalReminder) {_,  needsReminder in
            if needsReminder && !renewalReminderShown && !subscription.isLocked {
                presentSheet(&showRenewalReminder)
                renewalReminderShown = true
            }
        }
        .onChange(of: subscription.trialDaysLeft) {_,  days in
            if days <= 1 && !subscription.isLocked && !renewalReminderShown {
                if subscription.trialActive {
                    presentSheet(&showTrialSubscribe)
                } else {
                    presentSheet(&showRenewalReminder)
                }
                renewalReminderShown = true
            }
        }
        .sheet(isPresented: Binding(
            get: { chatModel.showComputeStore },
            set: { chatModel.showComputeStore = $0 }
        )) {
            NavigationStack { ComputeStoreView().environmentObject(theme) }
        }
        .sheet(isPresented: Binding(
            get: { chatModel.showKeyRotationNotice },
            set: { chatModel.showKeyRotationNotice = $0 }
        )) {
            NavigationStack {
                KeyRotationNoticeView()
                    .environmentObject(theme)
            }
        }
        .sheet(isPresented: $showTrialSubscribe) {
            NavigationStack { SubscriptionView().environmentObject(theme) }
        }
    }

    // MARK: - Sheet mutual exclusion
    // Only one of these sheets can be presented at a time; SwiftUI silently drops
    // all but the last .sheet(isPresented:) when multiple are true simultaneously.
    private func presentSheet(_ flag: inout Bool) {
        showRenewalReminder = false
        showTrialSubscribe = false
        chatModel.showComputeStore = false
        chatModel.showKeyRotationNotice = false
        flag = true
    }

    private func setConditionsNotified_() async {
        do {
            let conditionsId = ChatModel.shared.conditions.currentConditions.conditionsId
            try await setConditionsNotified(conditionsId: conditionsId)
        } catch let error {
            logger.error("setConditionsNotified error: \(responseError(error))")
        }
    }

    private func processUserActivity(_ activity: NSUserActivity) {
        let intent = activity.interaction?.intent
        if let intent = intent as? INStartCallIntent {
            callToRecentContact(intent.contacts, intent.callCapability == .videoCall ? .video : .audio)
        }
    }

    private func callToRecentContact(_ contacts: [INPerson]?, _ mediaType: CallMediaType) {
        logger.debug("callToRecentContact")
        if let contactId = contacts?.first?.personHandle?.value,
           let chat = chatModel.getChat(contactId),
           case let .direct(contact) = chat.chatInfo {
            let activeCall = chatModel.activeCall
            // This line works when a user clicks on a video button in CallKit UI while in call.
            // The app tries to make another call to the same contact and overwite activeCall instance making its state broken
            if let activeCall, contactId == activeCall.contact.id, mediaType == .video, !activeCall.hasVideo {
                Task {
                    await chatModel.callCommand.processCommand(.media(source: .camera, enable: true))
                }
            } else if activeCall == nil {
                logger.debug("callToRecentContact: start call")
                CallController.shared.startCall(contact, mediaType)
            }
        }
    }

    // Spec: spec/client/navigation.md#unlockedRecently
    private func unlockedRecently() -> Bool {
        if let lastSuccessfulUnlock = lastSuccessfulUnlock {
            return ProcessInfo.processInfo.systemUptime - lastSuccessfulUnlock < 2
        } else {
            return false
        }
    }

    private func authenticateContentViewAccess() {
        dismissAllSheets(animated: false) {
            chatModel.chatId = nil

            authenticate(reason: NSLocalizedString("Unlock app", comment: "authentication reason"), selfDestruct: true) { laResult in
                switch (laResult) {
                case .success:
                    guard scenePhase == .active else { return }
                    chatModel.contentViewAccessAuthenticated = true
                    canConnectViewCall = true
                    lastSuccessfulUnlock = ProcessInfo.processInfo.systemUptime
                case .failed:
                    chatModel.contentViewAccessAuthenticated = false
                    if privacyLocalAuthModeDefault.get() == .passcode {
                        AlertManager.shared.showAlert(laFailedAlert())
                    }
                case .unavailable:
                    prefPerformLA = false
                    canConnectViewCall = true
                    AlertManager.shared.showAlert(laUnavailableTurningOffAlert())
                }
            }
        }
    }

    func requestNtfAuthorization(showDeniedAlert: Bool = true, whenDone: (() -> Void)? = nil) {
        NtfManager.shared.requestAuthorization(
            onDeny: {
                if showDeniedAlert, !notificationAlertShown {
                    notificationAlertShown = true
                    alertManager.showAlert(notificationAlert())
                }
                whenDone?()
            },
            onAuthorized: { notificationAlertShown = false
                whenDone?()
            }
        )
    }

    func laNoticeAlert() -> Alert {
        Alert(
            title: Text(NSLocalizedString("POPOPX Lock", comment: "lock notice alert title")),
            message: Text(NSLocalizedString("To protect your information, turn on POPOPX Lock.\nYou will be prompted to complete authentication before this feature is enabled.", comment: "lock notice alert message")),
            primaryButton: .default(Text(NSLocalizedString("Turn on", comment: "button to enable lock"))) { showChooseLAMode = true },
            secondaryButton: .cancel()
         )
    }

    private func initialEnableLA () {
        privacyLocalAuthModeDefault.set(.system)
        authenticate(reason: NSLocalizedString("Enable POPOPX Lock", comment: "authentication reason")) { laResult in
            switch laResult {
            case .success:
                chatModel.contentViewAccessAuthenticated = true
                prefPerformLA = true
                alertManager.showAlert(laTurnedOnAlert())
            case .failed:
                prefPerformLA = false
                alertManager.showAlert(laFailedAlert())
            case .unavailable:
                prefPerformLA = false
                alertManager.showAlert(laUnavailableInstructionAlert())
            }
        }
    }

    func notificationAlert() -> Alert {
        Alert(
            title: Text(NSLocalizedString("Notifications are disabled!", comment: "notification disabled alert title")),
            message: Text(NSLocalizedString("The app can notify you when you receive messages or contact requests - please open settings to enable.", comment: "notification disabled alert message")),
            primaryButton: .default(Text(NSLocalizedString("Open Settings", comment: "button to open system settings"))) {
                DispatchQueue.main.async {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            },
            secondaryButton: .cancel()
        )
    }

    // Spec: spec/client/navigation.md#connectViaUrl
    // a URL opened via link that is ready to be connected now (appOpenUrl immediately, or
    // appOpenUrlLater once the app is active — see .onChange(of: scenePhase) in POPOPXApp)
    private var pendingConnectUrl: URL? {
        let m = ChatModel.shared
        if let url = m.appOpenUrl { return url }
        if let url = m.appOpenUrlLater, AppChatState.shared.value == .active, scenePhase == .active { return url }
        return nil
    }

    func connectViaUrl() {
        let m = ChatModel.shared
        guard let url = pendingConnectUrl else { return }
        // Defer URL processing if local auth is required but not yet complete
        if prefPerformLA && !accessAuthenticated {
            m.appOpenUrl = nil
            m.appOpenUrlLater = url
            return
        }
        if m.appOpenUrl != nil { m.appOpenUrl = nil } else { m.appOpenUrlLater = nil }
        connectViaUrl_(url)
    }

    func connectViaUrl_(_ url: URL) {
        let allowedSchemes: Set<String> = ["https", "popop", "popopx", "binthere"]
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else {
            AlertManager.shared.showAlert(Alert(title: Text(NSLocalizedString("Error: URL is invalid", comment: "invalid URL error alert"))))
            return
        }
        dismissAllSheets() {
            var path = url.path
            if path == "/r" {
                showAlert(
                    NSLocalizedString("Relay address", comment: "alert title"),
                    message: NSLocalizedString("This is a chat relay address, it cannot be used to connect.", comment: "alert message")
                )
            } else if url.scheme?.lowercased() == "popopx" && url.host?.lowercased() == "enc" {
                // popopx://enc#<encrypted_data> format
                planAndConnect(
                    url.absoluteString,
                    theme: theme,
                    dismiss: false
                )
            } else if (path == "/contact" || path == "/invitation" || path == "/a" || path == "/c" || path == "/g" || path == "/i") {
                path.removeFirst()
                let link = url.absoluteString.replacingOccurrences(of: "///\(path)", with: "/\(path)")
                planAndConnect(
                    link,
                    theme: theme,
                    dismiss: false
                )
            } else {
                AlertManager.shared.showAlert(Alert(title: Text(NSLocalizedString("Error: URL is invalid", comment: "invalid URL error alert"))))
            }
        }
    }

    func showReRegisterTokenAlert() {
        dismissAllSheets() {
            let m = ChatModel.shared
            if let errorTknStatus = m.reRegisterTknStatus, let token = chatModel.deviceToken {
                chatModel.reRegisterTknStatus = nil
                AlertManager.shared.showAlert(Alert(
                    title: Text(NSLocalizedString("Notifications error", comment: "notification registration error alert title")),
                    message: Text(tokenStatusInfo(errorTknStatus, register: true)),
                    primaryButton: .default(Text(NSLocalizedString("Register", comment: "button to register for notifications"))) { reRegisterToken(token: token) },
                    secondaryButton: .cancel()
                ))
            }
        }
    }
}

@MainActor
final class AlertManager: ObservableObject {
    static let shared = AlertManager()
    @Published var presentAlert = false
    @Published var alertTitle: LocalizedStringKey = ""
    @Published var alertMessage: LocalizedStringKey? = nil
    @Published var alertPrimaryButton: (text: LocalizedStringKey, action: () -> Void)? = nil
    @Published var alertSecondaryButton: (LocalizedStringKey, () -> Void)? = nil
    @Published var alertDestructiveButton: (text: LocalizedStringKey, action: () -> Void)? = nil
    @Published var legacyAlert: Alert?

    func showAlert(_ alert: Alert) {
        legacyAlert = alert
        presentAlert = true
    }

    func showAlertMsg(title: LocalizedStringKey, message: LocalizedStringKey? = nil) {
        alertTitle = title
        alertMessage = message
        alertPrimaryButton = nil
        alertSecondaryButton = nil
        alertDestructiveButton = nil
        legacyAlert = nil
        presentAlert = true
    }

    func showAlert(title: LocalizedStringKey, message: LocalizedStringKey? = nil, primary: (LocalizedStringKey, () -> Void)? = nil, secondary: (LocalizedStringKey, () -> Void)? = nil, destructive: (LocalizedStringKey, () -> Void)? = nil) {
        alertTitle = title
        alertMessage = message
        alertPrimaryButton = primary.map { (text: $0.0, action: $0.1) }
        alertSecondaryButton = secondary
        alertDestructiveButton = destructive.map { (text: $0.0, action: $0.1) }
        legacyAlert = nil
        presentAlert = true
    }
}

func mkAlert(title: LocalizedStringKey, message: LocalizedStringKey? = nil) -> Alert {
    if let message = message {
        return Alert(title: Text(title), message: Text(message))
    } else {
        return Alert(title: Text(title))
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(text: "Hello!")
//    }
//}
