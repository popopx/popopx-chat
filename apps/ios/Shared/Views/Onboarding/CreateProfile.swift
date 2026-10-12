//
//  CreateProfile.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 07/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

enum UserProfileAlert: Identifiable {
    case duplicateUserError
    case invalidDisplayNameError
    case createUserError(error: LocalizedStringKey)
    case invalidNameError(validName: String)

    var id: String {
        switch self {
        case .duplicateUserError: return "duplicateUserError"
        case .invalidDisplayNameError: return "invalidDisplayNameError"
        case .createUserError: return "createUserError"
        case let .invalidNameError(validName): return "invalidNameError \(validName)"
        }
    }
}

let MAX_BIO_LENGTH_BYTES = 160

@MainActor
struct CreateProfile: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: AppTheme
    @State private var displayName: String = ""
    @State private var profileBio: String = ""
    @FocusState private var focusDisplayName
    @State private var alert: UserProfileAlert?
    @State private var showChooseSource = false
    @State private var showImagePicker = false
    @State private var showTakePhoto = false
    @State private var chosenImage: UIImage? = nil
    @State private var profileImage: String? = nil
    @State private var creatingProfile = false

    var body: some View {
        List {
            Group {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .center) {
                        ZStack(alignment: .topTrailing) {
                            ProfileImage(imageStr: profileImage, size: 128)
                            if profileImage != nil {
                                Button {
                                    profileImage = nil
                                } label: {
                                    Image(systemName: "multiply")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 12)
                                }
                            }
                        }

                        editImageButton { showChooseSource = true }
                            .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 10) // Offsets transparent space built into 3D asset
                    Spacer(minLength: 0)
                    #if POPOPX_ASSETS
                    Image(colorScheme == .light ? "create-profile" : "create-profile-light")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                    // No trailing spacer — asset image has empty space on the right
                    #endif
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

            Section {
                ZStack(alignment: .leading) {
                    let name = displayName.trimmingCharacters(in: .whitespaces)
                    if name != mkValidName(name) {
                        Button {
                            alert = .invalidNameError(validName: mkValidName(name))
                        } label: {
                            Image(systemName: "exclamationmark.circle").foregroundColor(theme.colors.error)
                        }
                        .accessibilityLabel(Text(NSLocalizedString("Invalid name", comment: "")))
                    } else {
                        Image(systemName: "pencil").foregroundColor(theme.colors.secondary)
                            .accessibilityHidden(true)
                    }
                    TextField(NSLocalizedString("Enter your name…", comment: "Profile name placeholder"), text: $displayName)
                        .padding(.leading, 36)
                        .focused($focusDisplayName)
                }
                ZStack(alignment: .leading) {
                    Image(systemName: "pencil").foregroundColor(theme.colors.secondary)
                        .accessibilityHidden(true)
                    TextField(NSLocalizedString("Bio", comment: "Profile bio placeholder"), text: $profileBio)
                        .padding(.leading, 36)
                }
                Button(action: createProfile) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(theme.colors.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : theme.colors.primary.opacity(0.15))
                            )
                        Text(NSLocalizedString("Create profile", comment: "Create profile button"))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                .disabled(creatingProfile || !canCreateProfile(displayName) || !bioFitsLimit())
                if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(NSLocalizedString("Please enter your name", comment: "Hint to enter profile name"))
                        .font(.footnote)
                        .foregroundColor(theme.colors.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Your profile is stored on your device and only shared with your contacts.", comment: "Profile storage explanation"))
                }
                .foregroundColor(theme.colors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .compactSectionSpacing()
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .navigationTitle(NSLocalizedString("Create your profile", comment: "Create profile navigation title"))
        .modifier(ThemedBackground(grouped: true, glass: true))
        .alert(item: $alert) { a in userProfileAlert(a, $displayName) }
        .confirmationDialog(NSLocalizedString("Profile image", comment: "Profile image dialog title"), isPresented: $showChooseSource, titleVisibility: .visible) {
            Button(NSLocalizedString("Take picture", comment: "Take picture button")) {
                showTakePhoto = true
            }
            Button(NSLocalizedString("Choose from library", comment: "Choose from library button")) {
                showImagePicker = true
            }
        }
        .fullScreenCover(isPresented: $showTakePhoto) {
            ZStack {
                Color.black.ignoresSafeArea()
                CameraImagePicker(image: $chosenImage)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            LibraryImagePicker(image: $chosenImage) { _ in
                await MainActor.run {
                    showImagePicker = false
                }
            }
        }
        .onChange(of: chosenImage) {_,  image in
            Task {
                let resized: String? = if let image {
                    await resizeImageToStrSize(cropToSquare(image), maxDataSize: 12500)
                } else {
                    nil
                }
                await MainActor.run { profileImage = resized }
            }
        }
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusDisplayName = true
            }
        }
        .popopxBranded()
    }

    private func bioFitsLimit() -> Bool {
        chatJsonLength(profileBio) <= MAX_BIO_LENGTH_BYTES
    }

    private func createProfile() {
        hideKeyboard()
        if creatingProfile { return }
        creatingProfile = true
        if !ChatModel.shared.chatInitialized {
            logger.error("createProfile: chat not initialized")
            creatingProfile = false
            AlertManager.shared.showAlert(title: LocalizedStringKey(NSLocalizedString("Not Ready", comment: "")), message: LocalizedStringKey(NSLocalizedString("Please wait for the app to finish initializing.", comment: "")))
            return
        }
        let shortDescr: String? = if profileBio.isEmpty { nil } else { profileBio }
        let profile = Profile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            fullName: "",
            shortDescr: shortDescr,
            image: profileImage
        )
        let m = ChatModel.shared
        do {
            m.currentUser = try apiCreateActiveUser(profile)
            creatingProfile = false
            if m.users.isEmpty || m.users.allSatisfy({ $0.user.hidden }) {
                try startChat(onboarding: true)
                AppChatState.shared.set(.active)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    withAnimation {
                        advanceOnboarding(to: .step2_NetworkAndCommitments)
                    }
                }
            } else {
                m.users = try listUsers()
                try getUserChatData()
                AppChatState.shared.set(.active)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    advanceOnboarding(to: .onboardingComplete)
                    dismiss()
                }
            }
        } catch let error {
            creatingProfile = false
            showCreateProfileAlert(showAlert: { alert = $0 }, error)
        }
    }
}

@MainActor
struct CreateFirstProfile: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var displayName: String = ""
    @FocusState private var focusDisplayName
    @State private var creatingProfile = false
    @State private var showEncryptAnimation = false
    @State private var animationComplete = false
    @State private var profileCreated = false
    @State private var showMigrateSheet = false
    // New states for two-phase interaction
    @State private var showBubbleWrapStage = false
    @State private var textFieldFalling = false
    @State private var bubbleRising = false

    var body: some View {
        ZStack {
            OnboardingBubbleBackground()

            if showEncryptAnimation {
                encryptAnimationContent()
            } else if showBubbleWrapStage {
                bubbleWrapContent()
            } else {
                inputContent()
            }
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
    }

    private func inputContent() -> some View {
        ScrollView {
            VStack(alignment: .center, spacing: 10) {
                #if POPOPX_ASSETS
                Image(colorScheme == .light ? "your-profile" : "your-profile-light")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                #else
                ZStack {
                    let gp = PXOnboardingCard.gradientPoints(aspectRatio: 1.0, scale: colorScheme == .light ? 1.2 : 1.5)
                    LinearGradient(
                        stops: colorScheme == .light ? PXOnboardingCard.lightStops : PXOnboardingCard.darkStops,
                        startPoint: gp.start,
                        endPoint: gp.end
                    )
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .aspectRatio(1.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [QuantumColors.accent.opacity(0.5), QuantumColors.accentSecondary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: QuantumColors.accent.opacity(0.3), radius: 20, x: 0, y: 6)
                .shadow(color: QuantumColors.accentSecondary.opacity(0.2), radius: 28, x: 0, y: 0)
                .padding(.horizontal, 25)
                .frame(maxWidth: .infinity)
                #endif

                Text(NSLocalizedString("Your alias", comment: "Profile creation title"))
                    .font(.largeTitle)
                    .bold()
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
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(QuantumColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(NSLocalizedString("No account. No phone. No email. No ID.\nEnd-to-end encrypted.", comment: "Privacy features description"))
                    .font(.footnote)
                    .foregroundColor(Color(hex: "#887FA0"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 20)

                profileNameField()

                if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(NSLocalizedString("Please enter your name", comment: "Hint to enter profile name"))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "#C4BFD6"))
                        .padding(.top, 8)
                }

                Spacer(minLength: 20)

                createProfileButton()
                    .safeAreaPadding(.bottom, 20)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 25)
            .padding(.top, 8)
            .padding(.bottom, 25)
        }
        .onTapGesture { focusDisplayName = false }
        .onAppear {
            focusDisplayName = true
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if m.migrationState == nil {
                        m.migrationState = .pasteOrScanLink
                    }
                    showMigrateSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down")
                        Text(NSLocalizedString("Migrate", comment: "Migrate button"))
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .sheet(isPresented: $showMigrateSheet, onDismiss: { m.migrationState = nil }) {
            NavigationView {
                MigrateToDevice(migrationState: Binding(get: { m.appState.migrationState }, set: { m.appState.migrationState = $0 }))
                    .navigationTitle(NSLocalizedString("Migrate here", comment: ""))
                    .modifier(ThemedBackground(grouped: true))
            }
        }
    }

    private func encryptAnimationContent() -> some View {
        GravitationalCollapseWithEnclave(
            alias: displayName.trimmingCharacters(in: .whitespaces),
            onComplete: {
                animationComplete = true
            }
        )
    }

    private func bubbleWrapContent() -> some View {
        GeometryReader { geo in
            ZStack {
                // Ambient background glow during bubble stage
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

                // Falling text field (dramatic disappearance)
                if textFieldFalling {
                    profileNameField()
                        .offset(y: geo.size.height * 0.5)
                        .opacity(0.25)
                        .scaleEffect(0.85)
                        .blur(radius: 8)
                        .animation(.easeIn(duration: 0.6), value: textFieldFalling)
                }

                // Rising bubble with nickname - CENTERED and DRAMATIC
                EncryptedAliasBubble(
                    alias: displayName.trimmingCharacters(in: .whitespaces),
                    diameter: min(geo.size.width * 0.6, 260), // Even larger for impact
                    onTap: {
                        triggerGravitationalCollapse()
                    }
                )
                .scaleEffect(bubbleRising ? 1.0 : 0.15)
                .opacity(bubbleRising ? 1.0 : 0.0)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.38) // Slightly lower for better balance
                .animation(.spring(response: 1.0, dampingFraction: 0.45), value: bubbleRising)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        bubbleRising = true
                    }
                }

                // Bottom hint text - enhanced visibility with glow
                Text(NSLocalizedString("pop_to_encrypt_hint", comment: "Bubble wrap stage hint text"))
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
                    .position(x: geo.size.width / 2, y: geo.size.height - 110) // Fixed position at bottom
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: bubbleRising)
            }
        }
    }

    private func profileNameField() -> some View {
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#141021"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
            Text(NSLocalizedString("profile_name_placeholder", comment: "Profile name input placeholder"))
                .font(.system(size: 17))
                .foregroundColor(Color(hex: "#C4BFD6"))
                .padding(.horizontal, 16)
                .allowsHitTesting(false)
                .opacity(displayName.isEmpty ? 1.0 : 0.0)
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

    private func createProfileButton() -> some View {
        Button {
            startCreateProfileFlow()
        } label: {
            if creatingProfile {
                ProgressView()
                    .tint(.white)
            } else {
                Text(String(localized: "Create & Encrypt"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(QuantumButtonStyle(primary: true))
        .disabled(creatingProfile || !canCreateProfile(displayName))
        .frame(maxWidth: .infinity)
    }

    private func startCreateProfileFlow() {
        hideKeyboard()
        // Phase 1: Show bubble wrap stage (text field falls, bubble rises with nickname)
        withAnimation(.easeInOut(duration: 0.3)) {
            textFieldFalling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showBubbleWrapStage = true
        }
        // Profile creation happens after user taps the bubble
    }

    private func triggerGravitationalCollapse() {
        // Phase 2: User tapped bubble - now create profile and show collapse animation
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

    private func showAlert(_ alert: UserProfileAlert) {
        AlertManager.shared.showAlert(userProfileAlert(alert, $displayName))
    }

    private func createProfile() {
        guard !creatingProfile else {
            logger.debug("createProfile: already in progress, ignoring tap")
            return
        }
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
        let m = ChatModel.shared
        logger.debug("createProfileAfterInit: Attempting to create profile")
        logger.debug("createProfileAfterInit: userExists=\(m.currentUser != nil), chatInitialized=\(m.chatInitialized)")

        if let existingUser = m.currentUser {
            logger.debug("createProfileAfterInit: Active user already exists, skipping creation")
            proceedWithExistingUser(existingUser)
            return
        }

        do {
            if let activeUser = try apiGetActiveUser() {
                logger.debug("createProfileAfterInit: Found existing active user in DB")
                m.currentUser = activeUser
                proceedWithExistingUser(activeUser)
                return
            }
        } catch {
            logger.warning("createProfileAfterInit: apiGetActiveUser check failed: \(responseError(error))")
        }

        do {
            m.currentUser = try apiCreateActiveUser(profile)
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
        let m = ChatModel.shared
        m.currentUser = user
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
        logger.warning("createProfileAfterInit: Duplicate name detected, attempting to recover with existing user")
        let m = ChatModel.shared
        do {
            let users = try listUsers()
            guard let firstUser = users.first else {
                logger.error("recoverFromDuplicateNameError: no users found after listUsers()")
                creatingProfile = false
                AlertManager.shared.showAlert(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Failed to recover from duplicate name error. Please restart the app.", comment: "")))
                return
            }
            m.currentUser = firstUser.user
            _ = try apiSetActiveUser(firstUser.user.userId, viewPwd: nil)
            logger.debug("createProfileAfterInit: Recovered - switched to existing user")
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
}

@MainActor
func showCreateProfileAlert(
    showAlert: (UserProfileAlert) -> Void,
    _ error: Error
) {
    let m = ChatModel.shared
    switch error as? ChatError {
    case .errorStore(.duplicateName),
         .error(.userExists(_)):
        if m.currentUser == nil {
            AlertManager.shared.showAlert(duplicateUserAlert)
        } else {
            showAlert(.duplicateUserError)
        }
    case .error(.invalidDisplayName(_, _)):
        if m.currentUser == nil {
            AlertManager.shared.showAlert(invalidDisplayNameAlert)
        } else {
            showAlert(.invalidDisplayNameError)
        }
    default:
        let errStr = String(localized: "Error: \(responseError(error))")
        if m.currentUser == nil {
            AlertManager.shared.showAlert(Alert(
                title: Text(NSLocalizedString("Error creating profile!", comment: "Error creating profile alert title")),
                message: Text(errStr)
            ))
        } else {
            showAlert(.createUserError(error: LocalizedStringKey(errStr)))
        }
    }
    logger.error("Failed to create user or start chat: \(responseError(error))")
}

private func canCreateProfile(_ displayName: String) -> Bool {
    let name = displayName.trimmingCharacters(in: .whitespaces)
    return name != "" && mkValidName(name) == name
}

func userProfileAlert(_ alert: UserProfileAlert, _ displayName: Binding<String>) -> Alert {
    switch alert {
    case .duplicateUserError: return duplicateUserAlert
    case .invalidDisplayNameError: return invalidDisplayNameAlert
    case let .createUserError(err): return creatUserErrorAlert(err)
    case let .invalidNameError(name): return createInvalidNameAlert(name, displayName)
    }
}

private var duplicateUserAlert: Alert {
    Alert(
        title: Text(NSLocalizedString("Duplicate display name!", comment: "Duplicate name alert title")),
        message: Text(NSLocalizedString("You already have a chat profile with the same display name. Please choose another name.", comment: "Duplicate name alert message"))
    )
}

private var invalidDisplayNameAlert: Alert {
    Alert(
        title: Text(NSLocalizedString("Invalid display name!", comment: "Invalid name alert title")),
        message: Text(NSLocalizedString("This display name is invalid. Please choose another name.", comment: "Invalid name alert message"))
    )
}

private func creatUserErrorAlert(_ err: LocalizedStringKey) -> Alert {
    Alert(
        title: Text(NSLocalizedString("Error creating profile!", comment: "Error creating profile alert title")),
        message: Text(err)
    )
}

func createInvalidNameAlert(_ name: String, _ displayName: Binding<String>) -> Alert {
    name == ""
    ? Alert(title: Text(NSLocalizedString("Invalid name!", comment: "Invalid name alert title")))
    : Alert(
        title: Text(NSLocalizedString("Invalid name!", comment: "Invalid name alert title")),
        message: Text(String(format: NSLocalizedString("Correct name to %@?", comment: "Correct name suggestion"), name)),
        primaryButton: .default(
            Text(NSLocalizedString("Ok", comment: "Ok button")),
            action: { displayName.wrappedValue = name }
        ),
        secondaryButton: .cancel()
    )
}

func validDisplayName(_ name: String) -> Bool {
    mkValidName(name.trimmingCharacters(in: .whitespaces)) == name
}

func mkValidName(_ s: String) -> String {
    guard var c = s.cString(using: .utf8),
          let result = chat_valid_name(&c) else {
        return s
    }
    return fromCString(result)
}

@MainActor
func advanceOnboarding(to stage: OnboardingStage) {
    let m = ChatModel.shared
    m.onboardingStage = stage
    logger.debug("advanceOnboarding: stage=\(stage.rawValue), chatModel.onboardingStage=\(String(describing: m.onboardingStage))")
}

struct CreateProfile_Previews: PreviewProvider {
    static var previews: some View {
        CreateProfile()
    .previewEnvironment()
    }
}
