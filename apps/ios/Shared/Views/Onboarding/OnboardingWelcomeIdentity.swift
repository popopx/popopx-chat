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
        GeometryReader { g in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image(colorScheme == .light ? "logo" : "logo-light")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: max(0, (g.size.width - 50)) * 0.50)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .top)

                    Text(NSLocalizedString("Be free\nin your network", comment: "Onboarding title"))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .tracking(1.5)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(hex: "#6E25C4").opacity(0.3), radius: 20)
                        .frame(maxWidth: .infinity)

                    Text(NSLocalizedString("Private and secure messaging.", comment: "Onboarding subtitle"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(QuantumColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 16)

                    bubbleSection(g: g)

                    if showProfileForm {
                        profileFormSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 25)
                .padding(.top, 28)
                .padding(.bottom, 20)
                .frame(minHeight: g.size.height)
                .frame(maxWidth: g.size.width)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Bubble Section

    @ViewBuilder
    private func bubbleSection(g: GeometryProxy) -> some View {
        ZStack {
            if popController.isPopping {
                BubblePopCanvas(particles: popController.particles)
                    .frame(width: g.size.width, height: g.size.height * 0.40)
            } else if !showProfileForm {
                BubbleComponent(diameter: min(260, g.size.width * 0.65))
                    .scaleEffect(showBubble ? 1.0 : 0.8)
                    .opacity(showBubble ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showBubble)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showBubble = true
                        }
                    }
                    .onTapGesture {
                        triggerBubblePop(in: g)
                    }
            }
        }
        .frame(height: showProfileForm ? 0 : g.size.height * 0.40)
        .animation(.easeInOut(duration: 0.4), value: showProfileForm)

        if !popController.isPopping && showBubble && !showProfileForm {
            Text(NSLocalizedString("tap_bubble_hint", comment: "Hint text below bubble animation"))
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color(hex: "#C4BFD6"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#00FFD2").opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
        }

        if !showProfileForm && !popController.isPopping && showBubble {
            Button {
                triggerBubblePopForNavigation(in: g)
            } label: {
                Text(NSLocalizedString("Get started", comment: "Get started button"))
            }
            .buttonStyle(OnboardingButtonStyle(isDisabled: false))
            .padding(.vertical, 10)
        }
    }

    // MARK: - Profile Form Section

    private var profileFormSection: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(NSLocalizedString("Your alias", comment: "Profile creation title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
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
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            profileNameField

            if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(NSLocalizedString("Please enter your name", comment: "Hint to enter profile name"))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(hex: "#C4BFD6"))
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
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#00FFD2"))
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#C4BFD6"))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#141021"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#6E25C4").opacity(0.25), Color(hex: "#00FFD2").opacity(0.15)],
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#C4BFD6"))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#C4BFD6"))
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    Text(NSLocalizedString("Nobody tracked your conversations. No one drew a map of where you'd been. Privacy was never a feature - it was the way of life.", comment: "WhyPOPOPX paragraph 1"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Then we moved online, and every platform asked for a piece of you - your name, your number, your friends. We accepted that the price of talking to others is letting someone know who we talk to. Every generation, people and tech, had it this way - telephone, email, messengers, social media. It seemed the only way possible.", comment: "WhyPOPOPX paragraph 2"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("There is another way. A network with no phone numbers. No usernames. No accounts. No user identities of any kind. A network that connects people and carries encrypted messages without knowing who is connected.", comment: "WhyPOPOPX paragraph 3"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Not a better lock on someone else's door. Not a nicer landlord that respects your privacy, but still keeps the record of all visitors. You are not a guest. You are home. No king can enter it - you are sovereign.", comment: "WhyPOPOPX paragraph 4"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Your conversations belong to you, as it had always been before the Internet. The network is not a place you visit. It is a place you create and own. And nobody can take it from you, whether you make it private or public.", comment: "WhyPOPOPX paragraph 5"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("The oldest human freedom - to speak to another person without being watched - built on infrastructure that cannot betray it.", comment: "WhyPOPOPX paragraph 6"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Because we destroyed the power to know who you are. So that your power can never be taken.", comment: "WhyPOPOPX paragraph 7"))
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(hex: "#E8E4F0"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("Be free in your network.", comment: "WhyPOPOPX closing"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#00FFD2"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(24)
            }
            .background(Color(hex: "#0A0814"))
            .navigationTitle(NSLocalizedString("Why we built this", comment: "Why built sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "Done button")) {
                        showWhySheet = false
                    }
                    .foregroundColor(Color(hex: "#00FFD2"))
                }
            }
            .toolbarBackground(Color(hex: "#0A0814"), for: .navigationBar)
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
                    .font(.system(size: 12))
                Text(NSLocalizedString("Migrate from another device", comment: "Migrate link"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(Color(hex: "#6E6585"))
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
                .tint(Color(hex: "#00FFD2"))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#141021"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "#6E25C4").opacity(0.5), Color(hex: "#00FFD2").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color(hex: "#6E25C4").opacity(0.2), radius: 8, x: 0, y: 4)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if name != validName {
                Button {
                    showAlert(.invalidNameError(validName: validName))
                } label: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(theme.colors.error)
                        .padding(.horizontal, 10)
                        .accessibilityLabel(Text(NSLocalizedString("Invalid name", comment: "accessibility label for invalid name error")))
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
            } else {
                Text(NSLocalizedString("onboarding_create_encrypt", comment: "Create profile and encrypt button"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(QuantumButtonStyle(primary: true))
        .disabled(creatingProfile || !canCreate)
        .frame(maxWidth: .infinity, minHeight: 52)
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
                        Color(hex: "#6E25C4").opacity(0.15),
                        Color(hex: "#6E25C4").opacity(0.08),
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
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#C4BFD6"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#141021").opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#00FFD2").opacity(0.5),
                                                Color(hex: "#6E25C4").opacity(0.4)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color(hex: "#00FFD2").opacity(0.3), radius: 10, x: 0, y: 0)
                    )
                    .opacity(bubbleRising ? 1.0 : 0.0)
                    .position(x: geo.size.width / 2, y: geo.size.height - 110)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: bubbleRising)
            }
        }
    }

    // MARK: - Actions

    private func triggerBubblePop(in g: GeometryProxy) {
        let bubbleCenterY = g.size.height * 0.28
        popController.triggerPop(
            containerSize: g.size,
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

    private func triggerBubblePopForNavigation(in g: GeometryProxy) {
        triggerBubblePop(in: g)
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
            advanceOnboarding(to: .step2_NetworkAndCommitments)
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
