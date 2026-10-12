//
//  UserProfile.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 31/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct UserProfile: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_PROFILE_IMAGE_CORNER_RADIUS) private var radius = defaultProfileImageCorner
    @State private var profile = Profile(displayName: "", fullName: "")
    @State private var currentProfileHash: Int?
    @State private var shortDescr = ""
    // Modals
    @State private var showChooseSource = false
    @State private var showImagePicker = false
    @State private var showTakePhoto = false
    @State private var chosenImage: UIImage? = nil
    @State private var alert: UserProfileAlert?
    @FocusState private var focusDisplayName

    var body: some View {
        List {
            EditProfileImage(profileImage: $profile.image, iconName: "person.crop.circle.fill", showChooseSource: $showChooseSource)
                .padding(.top)

            Section {
                HStack {
                    TextField(NSLocalizedString("profile_enter_name_placeholder", comment: "Enter your name placeholder"), text: $profile.displayName)
                        .focused($focusDisplayName)
                    if !validNewProfileName {
                        Button {
                            alert = .invalidNameError(validName: mkValidName(profile.displayName))
                        } label: {
                            Image(systemName: "exclamationmark.circle").foregroundColor(QuantumColors.error)
                        }
                    }
                }
                if let user = chatModel.currentUser, showFullName(user) {
                    TextField(NSLocalizedString("profile_full_name_optional", comment: "Full name optional placeholder"), text: $profile.fullName)
                }
                HStack {
                    TextField(NSLocalizedString("profile_bio_placeholder", comment: "Bio placeholder"), text: $shortDescr)
                    if !bioFitsLimit() {
                        Button {
                            showAlert(NSLocalizedString("profile_bio_too_large", comment: "Bio too large alert title"))
                        } label: {
                            Image(systemName: "exclamationmark.circle").foregroundColor(QuantumColors.error)
                        }
                    }
                }
            } footer: {
                Text(NSLocalizedString("profile_stored_notice", comment: "Profile storage notice"))
            }

            Section {
                Button(NSLocalizedString("profile_reset_button", comment: "Reset button")) {
                    getCurrentProfile()
                }
                .disabled(
                    currentProfileHash == profile.hashValue &&
                    (profile.shortDescr ?? "") == shortDescr.trimmingCharacters(in: .whitespaces)
                )
                Button(NSLocalizedString("profile_save_notify", comment: "Save and notify contacts button")) {
                    saveProfile()
                }
                .disabled(!canSaveProfile)
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        // Lifecycle
        .onAppear {
            getCurrentProfile()
        }
        .onDisappear {
            if canSaveProfile {
                showAlert(
                    title: NSLocalizedString("Save your profile?", comment: "alert title"),
                    message: NSLocalizedString("Your profile was changed. If you save it, the updated profile will be sent to all your contacts.", comment: "alert message"),
                    buttonTitle: NSLocalizedString("Save (and notify contacts)", comment: "alert button"),
                    buttonAction: saveProfile,
                    cancelButton: true
                )
            }
        }
        .onChange(of: chosenImage) {_,  image in
            Task {
                let resized: String? = if let image {
                    await resizeImageToStrSize(cropToSquare(image), maxDataSize: 12500)
                } else {
                    nil
                }
                await MainActor.run { profile.image = resized }
            }
        }
        // Modals
        .confirmationDialog(NSLocalizedString("profile_image_source_title", comment: "Profile image source dialog title"), isPresented: $showChooseSource, titleVisibility: .visible) {
            Button(NSLocalizedString("profile_take_picture", comment: "Take picture button")) {
                showTakePhoto = true
            }
            Button(NSLocalizedString("profile_choose_from_library", comment: "Choose from library button")) {
                showImagePicker = true
            }
            if UIPasteboard.general.hasImages {
                Button(NSLocalizedString("profile_paste_image", comment: "Paste image button")) {
                    chosenImage = UIPasteboard.general.image
                }
            }
        }
        .fullScreenCover(isPresented: $showTakePhoto) {
            ZStack {
                theme.colors.background.edgesIgnoringSafeArea(.all)
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
        .alert(item: $alert) { a in userProfileAlert(a, $profile.displayName) }
        .popopxBranded()
    }

    private func showFullName(_ user: User) -> Bool {
        user.profile.fullName != "" && user.profile.fullName != user.profile.displayName
    }

    private func bioFitsLimit() -> Bool {
        chatJsonLength(shortDescr) <= MAX_BIO_LENGTH_BYTES
    }

    private var canSaveProfile: Bool {
        (
            currentProfileHash != profile.hashValue ||
            (chatModel.currentUser?.profile.shortDescr ?? "") != shortDescr.trimmingCharacters(in: .whitespaces)
        ) &&
        profile.displayName.trimmingCharacters(in: .whitespaces) != "" &&
        validNewProfileName &&
        bioFitsLimit()
    }

    private var validNewProfileName: Bool {
        profile.displayName == chatModel.currentUser?.profile.displayName
            || validDisplayName(profile.displayName)
    }

    private func saveProfile() {
        focusDisplayName = false
        Task {
            do {
                profile.displayName = profile.displayName.trimmingCharacters(in: .whitespaces)
                profile.shortDescr = shortDescr.trimmingCharacters(in: .whitespaces)
                if let (newProfile, _) = try await apiUpdateProfile(profile: profile) {
                    await MainActor.run {
                        chatModel.updateCurrentUser(newProfile)
                        getCurrentProfile()
                    }
                } else {
                    alert = .duplicateUserError
                }
            } catch {
                logger.error("UserProfile apiUpdateProfile error: \(responseError(error))")
            }
        }
    }

    private func getCurrentProfile() {
        if let user = chatModel.currentUser {
            profile = fromLocalProfile(user.profile)
            currentProfileHash = profile.hashValue
            shortDescr = profile.shortDescr ?? ""
        }
    }
}

struct EditProfileImage: View {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_PROFILE_IMAGE_CORNER_RADIUS) private var radius = defaultProfileImageCorner
    @Binding var profileImage: String?
    var iconName: String
    @Binding var showChooseSource: Bool

    var body: some View {
        Group {
            if profileImage != nil {
                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .topTrailing) {
                        ProfileImage(imageStr: profileImage, size: 160)
                            .onTapGesture { showChooseSource = true }
                        overlayButton("multiply", edge: .top) { profileImage = nil }
                    }
                    overlayButton("camera", edge: .bottom) { showChooseSource = true }
                }
            } else {
                ZStack(alignment: .center) {
                    ProfileImage(imageStr: profileImage, iconName: iconName, size: 160)
                    editImageButton { showChooseSource = true }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .contentShape(Rectangle())
    }

    private func overlayButton(
        _ systemName: String,
        edge: Edge.Set,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 12)
            .foregroundColor(theme.colors.primary)
            .padding(6)
            .frame(width: 36, height: 36, alignment: .center)
            .background(radius >= 20 ? Color.clear : theme.colors.background.opacity(0.5))
            .clipShape(Circle())
            .contentShape(Circle())
            .padding([.trailing, edge], -12)
            .onTapGesture(perform: action)
    }
}

func editImageButton(action: @escaping () -> Void) -> some View {
    Button {
        action()
    } label: {
        Image(systemName: "camera")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48)
    }
}
