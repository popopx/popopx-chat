//
//  GroupProfileView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 29/07/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

enum GroupProfileAlert: Identifiable {
    case saveError(err: String)
    case invalidName(validName: String)

    var id: String {
        switch self {
        case let .saveError(err): return "saveError \(err)"
        case let .invalidName(validName): return "invalidName \(validName)"
        }
    }
}

// MARK: - POPOPX Configuration

private enum PXGroupProfileConfig {
    static let componentTag: String = "px-group-profile"
    /// Maximum image data size in bytes for profile image resize
    static let maxImageDataSize: Int64 = 12500
    /// Delay before auto-focusing display name field (seconds)
    static let keyboardFocusDelay: TimeInterval = 1
    /// Opacity for invalid name warning icon in dark theme
    static let darkThemeWarningOpacity: Double = 0.9
    /// Opacity for invalid name warning icon in light theme
    static let lightThemeWarningOpacity: Double = 1.0
}

// MARK: - POPOPX ViewModel

private struct PXGroupProfileViewModel {
    let profile: GroupProfile
    let originalProfile: GroupProfile
    let shortDescr: String
    let isChannel: Bool

    var profileChanged: Bool {
        currentProfileHash != originalProfile.hashValue ||
        (profile.shortDescr ?? "") != shortDescr.trimmingCharacters(in: .whitespaces)
    }

    var currentProfileHash: Int {
        profile.hashValue
    }

    var canUpdateProfile: Bool {
        profileChanged &&
        !profile.displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        validNewProfileName &&
        shortDescrFitsLimit
    }

    var validNewProfileName: Bool {
        profile.displayName == originalProfile.displayName ||
        validDisplayName(profile.displayName.trimmingCharacters(in: .whitespaces))
    }

    var shortDescrFitsLimit: Bool {
        chatJsonLength(shortDescr) <= MAX_BIO_LENGTH_BYTES
    }

    var storageFooterText: String {
        isChannel
            ? NSLocalizedString("group_channel_profile_stored", comment: "channel profile storage description")
            : NSLocalizedString("group_profile_stored", comment: "group profile storage description")
    }

    var displayNamePlaceholder: String {
        isChannel
            ? NSLocalizedString("group_channel_display_name", comment: "channel display name placeholder")
            : NSLocalizedString("group_display_name", comment: "group display name placeholder")
    }

    var fullNamePlaceholder: String {
        isChannel
            ? NSLocalizedString("group_channel_full_name", comment: "channel full name placeholder")
            : NSLocalizedString("group_full_name", comment: "group full name placeholder")
    }

    var saveButtonText: String {
        isChannel
            ? NSLocalizedString("group_save_channel_profile", comment: "save channel profile button")
            : NSLocalizedString("group_save_group_profile", comment: "save group profile button")
    }

    var navTitle: String {
        isChannel
            ? NSLocalizedString("channel_profile_nav_title", comment: "Channel profile navigation title")
            : NSLocalizedString("group_profile_nav_title", comment: "Group profile navigation title")
    }

    var imageDialogTitle: String {
        isChannel
            ? NSLocalizedString("group_channel_image", comment: "channel image dialog title")
            : NSLocalizedString("group_group_image", comment: "group image dialog title")
    }

    var imageErrorTitle: String {
        isChannel
            ? NSLocalizedString("error_saving_channel_profile", comment: "Error saving channel profile")
            : NSLocalizedString("error_saving_group_profile", comment: "Error saving group profile")
    }
}

struct GroupProfileView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @Binding var groupInfo: GroupInfo
    @State var groupProfile: GroupProfile
    @State private var shortDescr: String = ""
    @State private var currentProfileHash: Int?
    @State private var showChooseSource = false
    @State private var showImagePicker = false
    @State private var showTakePhoto = false
    @State private var chosenImage: UIImage? = nil
    @State private var alert: GroupProfileAlert?
    @FocusState private var focusDisplayName

    var body: some View {
        let vm = PXGroupProfileViewModel(
            profile: groupProfile,
            originalProfile: groupInfo.groupProfile,
            shortDescr: shortDescr,
            isChannel: groupInfo.useRelays
        )
        List {
            profileImageSection
            profileFieldsSection(vm)
            actionButtonsSection(vm)
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .confirmationDialog(vm.imageDialogTitle, isPresented: $showChooseSource, titleVisibility: .visible) {
            imageSourceDialogButtons
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
        .onChange(of: chosenImage) {_,  image in
            Task {
                let resized: String? = if let image {
                    await resizeImageToStrSize(cropToSquare(image), maxDataSize: PXGroupProfileConfig.maxImageDataSize)
                } else {
                    nil
                }
                await MainActor.run { groupProfile.image = resized }
            }
        }
        .onAppear {
            currentProfileHash = groupProfile.hashValue
            shortDescr = groupInfo.groupProfile.shortDescr ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + PXGroupProfileConfig.keyboardFocusDelay) {
                withAnimation { focusDisplayName = true }
            }
        }
        .onDisappear {
            if vm.canUpdateProfile {
                showAlert(
                    title: groupInfo.useRelays
                        ? NSLocalizedString("Save channel profile?", comment: "alert title")
                        : NSLocalizedString("Save group profile?", comment: "alert title"),
                    message: groupInfo.useRelays
                        ? NSLocalizedString("Channel profile was changed. If you save it, the updated profile will be sent to channel subscribers.", comment: "alert message")
                        : NSLocalizedString("Group profile was changed. If you save it, the updated profile will be sent to group members.", comment: "alert message"),
                    buttonTitle: groupInfo.useRelays
                        ? NSLocalizedString("Save (and notify subscribers)", comment: "alert button")
                        : NSLocalizedString("Save (and notify members)", comment: "alert button"),
                    buttonAction: saveProfile,
                    cancelButton: true
                )
            }
        }
        .alert(item: $alert) { a in
            switch a {
            case let .saveError(err):
                return Alert(
                    title: Text(vm.imageErrorTitle),
                    message: Text(err)
                )
            case let .invalidName(name):
                return createInvalidNameAlert(name, $groupProfile.displayName)
            }
        }
        .navigationTitle(vm.navTitle)
        .modifier(ThemedBackground(grouped: true))
        .navigationBarTitleDisplayMode(focusDisplayName ? .inline : .large)
        .popopxBranded()
    }

    // MARK: - Sub-views

    private var profileImageSection: some View {
        EditProfileImage(profileImage: $groupProfile.image, iconName: groupInfo.chatIconName, showChooseSource: $showChooseSource)
            .if(!focusDisplayName) { $0.padding(.top) }
            .accessibilityLabel(Text(NSLocalizedString("group_profile_image", comment: "Profile image accessibility")))
    }

    private func profileFieldsSection(_ vm: PXGroupProfileViewModel) -> some View {
        Section {
            displayNameRow(vm)
            fullNameRow
            shortDescrRow(vm)
        } footer: {
            Text(vm.storageFooterText)
        }
    }

    private func displayNameRow(_ vm: PXGroupProfileViewModel) -> some View {
        HStack {
            TextField(vm.displayNamePlaceholder, text: $groupProfile.displayName)
                .focused($focusDisplayName)
                .accessibilityLabel(Text(vm.displayNamePlaceholder))
            if !vm.validNewProfileName {
                Button {
                    alert = .invalidName(validName: mkValidName(groupProfile.displayName))
                } label: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(theme.colors.error)
                        .opacity(isInDarkTheme() ? PXGroupProfileConfig.darkThemeWarningOpacity : PXGroupProfileConfig.lightThemeWarningOpacity)
                }
                .accessibilityLabel(Text(NSLocalizedString("Invalid name warning", comment: "invalid name accessibility")))
            }
        }
    }

    private var fullNameRow: some View {
        Group {
            let fullName = groupInfo.groupProfile.fullName
            if fullName != "" && fullName != groupProfile.displayName {
                TextField(groupInfo.useRelays
                    ? NSLocalizedString("group_channel_full_name", comment: "channel full name placeholder")
                    : NSLocalizedString("group_full_name", comment: "group full name placeholder"), text: $groupProfile.fullName)
                    .accessibilityLabel(Text(NSLocalizedString("group_full_name", comment: "group full name placeholder")))
            }
        }
    }

    private func shortDescrRow(_ vm: PXGroupProfileViewModel) -> some View {
        HStack {
            TextField(NSLocalizedString("group_short_description_placeholder", comment: "Short description placeholder"), text: $shortDescr)
                .accessibilityLabel(Text(NSLocalizedString("group_short_description_placeholder", comment: "Short description placeholder")))
            if !vm.shortDescrFitsLimit {
                Button {
                    showAlert(NSLocalizedString("Description too large", comment: "alert title"))
                } label: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(theme.colors.error)
                        .opacity(isInDarkTheme() ? PXGroupProfileConfig.darkThemeWarningOpacity : PXGroupProfileConfig.lightThemeWarningOpacity)
                }
                .accessibilityLabel(Text(NSLocalizedString("Description too large warning", comment: "description too large accessibility")))
            }
        }
    }

    private func actionButtonsSection(_ vm: PXGroupProfileViewModel) -> some View {
        Section {
            Button(NSLocalizedString("group_reset_button", comment: "Reset profile changes button")) {
                groupProfile = groupInfo.groupProfile
                shortDescr = groupInfo.groupProfile.shortDescr ?? ""
                currentProfileHash = groupProfile.hashValue
            }
            .disabled(
                currentProfileHash == groupProfile.hashValue &&
                (groupInfo.groupProfile.shortDescr ?? "") == shortDescr.trimmingCharacters(in: .whitespaces)
            )
            .accessibilityLabel(Text(NSLocalizedString("group_reset_button", comment: "Reset profile changes button")))
            Button(vm.saveButtonText, action: saveProfile)
                .disabled(!vm.canUpdateProfile)
                .accessibilityLabel(Text(vm.saveButtonText))
        }
    }

    private var imageSourceDialogButtons: some View {
        Group {
            Button(NSLocalizedString("group_take_picture", comment: "Take photo with camera")) {
                showTakePhoto = true
            }
            .accessibilityLabel(Text(NSLocalizedString("group_take_picture", comment: "Take photo with camera")))
            Button(NSLocalizedString("group_choose_from_library", comment: "Select photo from library")) {
                showImagePicker = true
            }
            .accessibilityLabel(Text(NSLocalizedString("group_choose_from_library", comment: "Select photo from library")))
            if UIPasteboard.general.hasImages {
                Button(NSLocalizedString("group_paste_image", comment: "Paste image from clipboard")) {
                    chosenImage = UIPasteboard.general.image
                }
                .accessibilityLabel(Text(NSLocalizedString("group_paste_image", comment: "Paste image from clipboard")))
            }
        }
    }

    // MARK: - Actions

    func saveProfile() {
        logger.debug("POPOPX: GroupProfileView saveProfile")
        Task {
            do {
                groupProfile.displayName = groupProfile.displayName.trimmingCharacters(in: .whitespaces)
                groupProfile.fullName = groupProfile.fullName.trimmingCharacters(in: .whitespaces)
                groupProfile.shortDescr = shortDescr.trimmingCharacters(in: .whitespaces)
                let gInfo = try await apiUpdateGroup(groupInfo.groupId, groupProfile)
                await MainActor.run {
                    currentProfileHash = groupProfile.hashValue
                    groupInfo = gInfo
                    chatModel.updateGroup(gInfo)
                    dismiss()
                }
            } catch let error {
                let err = responseError(error)
                alert = .saveError(err: err)
                logger.error("GroupProfile apiUpdateGroup error: \(err)")
            }
        }
    }
}

// MARK: - POPOPX
extension GroupProfileView {
    static let pxComponentTag: String = PXGroupProfileConfig.componentTag
}

struct GroupProfileView_Previews: PreviewProvider {
    static var previews: some View {
        GroupProfileView(
            groupInfo: Binding.constant(GroupInfo.sampleData),
            groupProfile: GroupProfile.sampleData
        )
    }
}
