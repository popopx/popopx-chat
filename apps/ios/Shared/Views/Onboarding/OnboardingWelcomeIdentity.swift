//
//  OnboardingWelcomeIdentity.swift
//  POPOPX (iOS)
//
//  Created by POPOPX.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct OnboardingWelcomeIdentityView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var popController = BubblePopController()
    @State private var showBubble = false
    @State private var showProfileForm = false
    @State private var displayName: String = ""
    @FocusState private var focusDisplayName
    @State private var creatingProfile = false
    @State private var profileCreated = false
    @State private var showEncryptAnimation = false
    @State private var animationComplete = false
    @State private var showBubbleWrapStage = false
    @State private var bubbleRising = false
    @State private var showWhySheet = false
    @State private var showMigrateSheet = false

    var body: some View {
        ZStack {
            Color.clear

            if showEncryptAnimation {
                encryptAnimationContent
            } else if showBubbleWrapStage {
                bubbleWrapContent
            } else {
                welcomeContent
            }

            PurpleFlashOverlay(isActive: popController.flashActive)
        }
        .frame(maxHeight: .infinity)
        .onChange(of: animationComplete) { _, animDone in
            if animDone && profileCreated {
                advanceToNextStep()
            }
        }
        .onChange(of: profileCreated) { _, profDone in
            if profDone && animationComplete {
                advanceToNextStep()
            }
        }
        .onDisappear {
            popController.reset()
        }
        .sheet(isPresented: $showMigrateSheet, onDismiss: { m.migrationState = nil }) {
            NavigationStack {
                VStack(alignment: .leading) {
                    MigrateToDevice(migrationState: Binding(get: { m.appState.migrationState }, set: { m.appState.migrationState = $0 }))
                }
                .navigationTitle(NSLocalizedString("Migrate here", comment: ""))
                .modifier(ThemedBackground(grouped: true))
            }
        }
        .sheet(isPresented: $showWhySheet) {
            whyPopopxSheetContent
        }
        .toolbar(.hidden, for: .navigationBar)
        .popopxBranded()
    }

    // MARK: - Welcome Content (Phase 1: logo + bubble, Phase 2: profile form)

    private var welcomeContent: some View {
        GeometryReader { geometry in
            let screenWidth = max(0, geometry.size.width)
            let screenHeight = max(0, geometry.size.height)
            let logoWidth = max(1, (screenWidth - 50) * 0.50)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image(colorScheme == .light ? "logo" : "logo-light")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: logoWidth)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .top)

                Text(NSLocalizedString("Be free\nin your network", comment: "Onboarding title"))
                    .font(QuantumFonts.display)
                    .multilineTextAlignment(.center)
                    .tracking(1.5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: QuantumColors.accent.opacity(0.3), radius: 20)
                    .frame(maxWidth: .infinity)

                Text(NSLocalizedString("Private and secure messaging.", comment: "Onboarding subtitle"))
                    .font(QuantumFonts.body.weight(.medium))
                    .tracking(0.5)
                    .foregroundColor(QuantumColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 16)

                bubbleSection(screenWidth: screenWidth, screenHeight: screenHeight)

                if showProfileForm {
                    profileFormSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 25)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .frame(minHeight: max(1, screenHeight))
            .frame(maxWidth: max(1, screenWidth))
        }
        .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Bubble Section

    @ViewBuilder
    private func bubbleSection(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let safeWidth = max(1, screenWidth)
        let safeHeight = max(1, screenHeight * 0.40)
        
        ZStack {
            if popController.isPopping {
                BubblePopCanvas(particles: popController.particles, startTime: popController.startTime)
                    .frame(width: safeWidth, height: safeHeight)
                    .accessibilityHidden(true)
            } else if !showProfileForm {
                BubbleComponent(diameter: max(1, min(260, screenWidth * 0.65)))
                    .scaleEffect(showBubble ? 1.0 : 0.8)
                    .opacity(showBubble ? 1.0 : 0.0)
                    .animation(reduceMotion ? .easeIn(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.7), value: showBubble)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showBubble = true
                        }
                    }
                    .onTapGesture {
                        triggerBubblePop(containerSize: CGSize(width: screenWidth, height: screenHeight))
                    }
                    .accessibilityElement()
                    .accessibilityLabel(Text(NSLocalizedString("Welcome bubble", comment: "Accessibility label for welcome bubble")))
                    .accessibilityHint(Text(NSLocalizedString("Double-tap to pop the bubble and continue", comment: "Accessibility hint for bubble tap")))
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: showProfileForm ? 0 : max(1, screenHeight * 0.40))
        .animation(.easeInOut(duration: 0.4), value: showProfileForm)

        if !popController.isPopping && showBubble && !showProfileForm {
            Text(NSLocalizedString("tap_bubble_hint", comment: "Hint text below bubble animation"))
                .font(QuantumFonts.mono)
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(QuantumColors.accentSecondary.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
                .accessibilityHidden(true)
        }

        if !showProfileForm && !popController.isPopping && showBubble {
            Button {
                triggerBubblePopForNavigation(containerSize: CGSize(width: screenWidth, height: screenHeight))
            } label: {
                Text(NSLocalizedString("Get started", comment: "Get started button"))
            }
            .buttonStyle(OnboardingButtonStyle(isDisabled: false))
            .padding(.vertical, 10)
            .accessibilityLabel(Text(NSLocalizedString("Get started with POPOPX", comment: "Accessibility label for get started button")))
        }
    }

    // MARK: - Profile Form Section

    private var profileFormSection: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(NSLocalizedString("Your alias", comment: "Profile creation title"))
                .font(QuantumFonts.sectionTitle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(NSLocalizedString("On your device, not on servers.", comment: "Profile storage explanation"))
                .font(QuantumFonts.callout.weight(.medium))
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            profileNameField

            if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(NSLocalizedString("Please enter your name", comment: "Hint to enter profile name"))
                    .font(QuantumFonts.mono)
                    .foregroundColor(QuantumColors.textSecondary)
                    .padding(.top, 4)
            }

            privacyPills

            whyPopopxSection

            createProfileButton
                .padding(.top, 6)

            migrateLink
                .padding(.top, 4)
        }
    }

    // MARK: - Privacy Pills

    private var privacyPills: some View {
        HStack(spacing: 12) {
            privacyPill(icon: "lock.fill", label: NSLocalizedString("E2E Encrypted", comment: "Privacy pill"))
            privacyPill(icon: "eye.slash.fill", label: NSLocalizedString("No Tracking", comment: "Privacy pill"))
            privacyPill(icon: "shield.fill", label: NSLocalizedString("No Identifiers", comment: "Privacy pill"))
        }
    }

    private func privacyPill(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(QuantumFonts.iconTiny)
                .foregroundColor(QuantumColors.accentSecondary)
            Text(label)
                .font(QuantumFonts.caption.weight(.medium))
                .foregroundColor(QuantumColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(QuantumColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [QuantumColors.accent.opacity(0.25), QuantumColors.accentSecondary.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Why POPOPX Section

    private var whyPopopxSection: some View {
        Button {
            showWhySheet = true
        } label: {
            HStack(spacing: 6) {
                Text(NSLocalizedString("Why we built this", comment: "Why built link"))
                    .font(QuantumFonts.callout.weight(.medium))
                    .foregroundColor(QuantumColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(QuantumFonts.iconTiny.weight(.semibold))
                    .foregroundColor(QuantumColors.textSecondary)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Why POPOPX Sheet Content

    private var whyPopopxSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("You were born without an account", comment: "WhyPOPOPX title"))
                        .font(QuantumFonts.sectionTitle)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    Text(NSLocalizedString("Nobody tracked your conversations. No one drew a map of where you'd been. Privacy was never a feature - it was the way of life.", comment: "WhyPOPOPX paragraph 1"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Then we moved online, and every platform asked for a piece of you - your name, your number, your friends. We accepted that the price of talking to others is letting someone know who we talk to. Every generation, people and tech, had it this way - telephone, email, messengers, social media. It seemed the only way possible.", comment: "WhyPOPOPX paragraph 2"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("There is another way. A network with no phone numbers. No usernames. No accounts. No user identities of any kind. A network that connects people and carries encrypted messages without knowing who is connected.", comment: "WhyPOPOPX paragraph 3"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Not a better lock on someone else's door. Not a nicer landlord that respects your privacy, but still keeps the record of all visitors. You are not a guest. You are home. No king can enter it - you are sovereign.", comment: "WhyPOPOPX paragraph 4"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Your conversations belong to you, as it had always been before the Internet. The network is not a place you visit. It is a place you create and own. And nobody can take it from you, whether you make it private or public.", comment: "WhyPOPOPX paragraph 5"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("The oldest human freedom - to speak to another person without being watched - built on infrastructure that cannot betray it.", comment: "WhyPOPOPX paragraph 6"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Because we destroyed the power to know who you are. So that your power can never be taken.", comment: "WhyPOPOPX paragraph 7"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Be free in your network.", comment: "WhyPOPOPX closing"))
                        .font(QuantumFonts.body.weight(.semibold))
                        .foregroundColor(QuantumColors.accentSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
            }
            .background(QuantumColors.background)
            .navigationTitle(NSLocalizedString("Why we built this", comment: "Why built sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "Done button")) {
                        showWhySheet = false
                    }
                    .foregroundColor(QuantumColors.accentSecondary)
                }
            }
            .toolbarBackground(QuantumColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Migrate Link

    private var migrateLink: some View {
        Button {
            if m.migrationState == nil {
                m.migrationState = .pasteOrScanLink
            }
            showMigrateSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tray.and.arrow.down")
                    .font(QuantumFonts.iconSmall)
                Text(NSLocalizedString("Migrate from another device", comment: "Migrate link"))
                    .font(QuantumFonts.caption.weight(.medium))
            }
            .foregroundColor(QuantumColors.textTertiary)
        }
    }

    // MARK: - Profile Name Field

    private var profileNameField: some View {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let validName = mkValidName(name)
        return ZStack(alignment: .trailing) {
            TextField(NSLocalizedString("enter_profile_name_placeholder", comment: "Profile name input placeholder"), text: $displayName)
                .focused($focusDisplayName)
                .padding(.horizontal, 16)
                .padding(.trailing, name != validName ? 36 : 16)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .tint(QuantumColors.accentSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(QuantumColors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [QuantumColors.accent.opacity(0.5), QuantumColors.accentSecondary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: QuantumColors.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel(Text(NSLocalizedString("Profile name", comment: "Accessibility label for profile name input")))
                .accessibilityHint(Text(NSLocalizedString("Enter your display name. This will be shown to your contacts.", comment: "Accessibility hint for profile name input")))
            if name != validName {
                Button {
                    showAlert(.invalidNameError(validName: validName))
                } label: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(theme.colors.error)
                        .padding(.horizontal, 10)
                        .accessibilityLabel(Text(NSLocalizedString("Invalid name", comment: "accessibility label for invalid name error")))
                        .accessibilityHint(Text(NSLocalizedString("Double-tap to see why the name is invalid", comment: "accessibility hint for invalid name button")))
                }
            }
        }
    }

    // MARK: - Create Profile Button

    private var createProfileButton: some View {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let canCreate = name != "" && mkValidName(name) == name
        return Button {
            startCreateProfileFlow()
        } label: {
            if creatingProfile {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel(Text(NSLocalizedString("Creating profile", comment: "Accessibility label for progress indicator")))
            } else {
                Text(NSLocalizedString("onboarding_create_encrypt", comment: "Create profile and encrypt button"))
                    .font(QuantumFonts.body.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(QuantumButtonStyle(primary: true))
        .disabled(creatingProfile || !canCreate)
        .frame(maxWidth: .infinity, minHeight: 52)
        .accessibilityLabel(Text(NSLocalizedString("Create and encrypt profile", comment: "Accessibility label for create profile button")))
        .accessibilityHint(Text(NSLocalizedString("Double-tap to create your profile and encrypt your identity", comment: "Accessibility hint for create profile button")))
    }

    // MARK: - Encrypt Animation Content

    private var encryptAnimationContent: some View {
        GravitationalCollapseWithEnclave(
            alias: displayName.trimmingCharacters(in: .whitespaces),
            onComplete: {
                animationComplete = true
            }
        )
    }

    // MARK: - Bubble Wrap Content

    private var bubbleWrapContent: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [
                        QuantumColors.accent.opacity(0.15),
                        QuantumColors.accent.opacity(0.08),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: max(geo.size.width, geo.size.height) * 0.6
                )
                .ignoresSafeArea()

                EncryptedAliasBubble(
                    alias: displayName.trimmingCharacters(in: .whitespaces),
                    diameter: min(geo.size.width * 0.6, 260),
                    onTap: {
                        triggerGravitationalCollapse()
                    }
                )
                .scaleEffect(bubbleRising ? 1.0 : 0.15)
                .opacity(bubbleRising ? 1.0 : 0.0)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.38)
                .animation(.spring(response: 1.0, dampingFraction: 0.45), value: bubbleRising)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        bubbleRising = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        triggerGravitationalCollapse()
                    }
                }

                Text(NSLocalizedString("onboarding_encrypting_alias", comment: "Encrypting alias status text"))
                    .font(QuantumFonts.callout.weight(.semibold))
                    .foregroundColor(QuantumColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(QuantumColors.surfaceElevated.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                QuantumColors.accentSecondary.opacity(0.5),
                                                QuantumColors.accent.opacity(0.4)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: QuantumColors.accentSecondary.opacity(0.3), radius: 10, x: 0, y: 0)
                    )
                    .opacity(bubbleRising ? 1.0 : 0.0)
                    .position(x: geo.size.width / 2, y: geo.size.height - 110)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: bubbleRising)
            }
        }
    }

    // MARK: - Actions

    private func triggerBubblePop(containerSize: CGSize) {
        let bubbleCenterY = containerSize.height * 0.28
        popController.triggerPop(
            containerSize: containerSize,
            bubbleCenterY: bubbleCenterY,
            onComplete: {
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showProfileForm = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusDisplayName = true
                    }
                }
            }
        )
    }

    private func triggerBubblePopForNavigation(containerSize: CGSize) {
        triggerBubblePop(containerSize: containerSize)
    }

    private func startCreateProfileFlow() {
        hideKeyboard()
        withAnimation(.easeInOut(duration: 0.3)) {
            showBubbleWrapStage = true
        }
    }

    private func triggerGravitationalCollapse() {
        createProfile()
        withAnimation(.easeInOut(duration: 0.3)) {
            showBubbleWrapStage = false
            showEncryptAnimation = true
        }
    }

    private func advanceToNextStep() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            advanceOnboarding(to: .step2_CreateProfile)
        }
    }

    // MARK: - Profile Creation

    private func createProfile() {
        guard !creatingProfile else { return }
        creatingProfile = true

        if ChatModel.shared.chatInitialized {
            createProfileAfterInit()
            return
        }

        Task { @MainActor in
            let deadline = DispatchTime.now().uptimeNanoseconds + 30_000_000_000
            do {
                while !ChatModel.shared.chatInitialized && !ChatModel.shared.ctrlInitInProgress && DispatchTime.now().uptimeNanoseconds < deadline {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                while ChatModel.shared.ctrlInitInProgress && DispatchTime.now().uptimeNanoseconds < deadline {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            } catch {
                creatingProfile = false
                return
            }
            guard ChatModel.shared.chatInitialized else {
                logger.error("createProfile: initialization did not complete, cannot create profile")
                creatingProfile = false
                AlertManager.shared.showAlert(title: LocalizedStringKey(NSLocalizedString("Initialization failed", comment: "")), message: LocalizedStringKey(NSLocalizedString("The app could not initialize. Please restart.", comment: "")))
                return
            }
            createProfileAfterInit()
        }
    }

    private func createProfileAfterInit() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let profile = Profile(displayName: name, fullName: "")
        let chatModel = ChatModel.shared
        logger.debug("createProfileAfterInit: Attempting to create profile")

        if let existingUser = chatModel.currentUser {
            proceedWithExistingUser(existingUser)
            return
        }

        do {
            if let activeUser = try apiGetActiveUser() {
                chatModel.currentUser = activeUser
                proceedWithExistingUser(activeUser)
                return
            }
        } catch {
            logger.warning("createProfileAfterInit: apiGetActiveUser check failed: \(responseError(error))")
        }

        do {
            chatModel.currentUser = try apiCreateActiveUser(profile)
            logger.debug("createProfileAfterInit: Profile created successfully")
            try startChat(onboarding: true)
            AppChatState.shared.set(.active)
            creatingProfile = false
            profileCreated = true
        } catch let error {
            logger.error("createProfileAfterInit: Failed to create profile: \(responseError(error))")
            creatingProfile = false
            showEncryptAnimation = false
            let chatError = error as? ChatError
            if case .errorStore(.duplicateName) = chatError {} else if case .error(.userExists(_)) = chatError {} else {
                showCreateProfileAlert(showAlert: showAlert, error)
                return
            }
            recoverFromDuplicateNameError()
        }
    }

    private func proceedWithExistingUser(_ user: User) {
        let chatModel = ChatModel.shared
        chatModel.currentUser = user
        do {
            try startChat(onboarding: true)
            AppChatState.shared.set(.active)
            creatingProfile = false
            profileCreated = true
        } catch {
            logger.error("proceedWithExistingUser: startChat failed: \(responseError(error))")
            creatingProfile = false
            showCreateProfileAlert(showAlert: showAlert, error)
        }
    }

    private func recoverFromDuplicateNameError() {
        logger.warning("createProfileAfterInit: Duplicate name detected, attempting to recover")
        let chatModel = ChatModel.shared
        do {
            let users = try listUsers()
            guard let firstUser = users.first else {
                logger.error("recoverFromDuplicateNameError: no users found")
                creatingProfile = false
                AlertManager.shared.showAlert(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Failed to recover from duplicate name error. Please restart the app.", comment: "")))
                return
            }
            chatModel.currentUser = firstUser.user
            _ = try apiSetActiveUser(firstUser.user.userId, viewPwd: nil)
            try startChat(onboarding: true)
            AppChatState.shared.set(.active)
            creatingProfile = false
            profileCreated = true
        } catch {
            logger.error("createProfileAfterInit: Recovery failed: \(responseError(error))")
            creatingProfile = false
            showAlert(.duplicateUserError)
        }
    }

    private func showAlert(_ alert: UserProfileAlert) {
        AlertManager.shared.showAlert(userProfileAlert(alert, $displayName))
    }
}
