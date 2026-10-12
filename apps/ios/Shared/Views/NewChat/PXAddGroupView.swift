//
//  AddGroupView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 13.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXAddGroupViewConfig {
    static let profileImageSize: CGFloat = 128
    static let imageRemoveButtonSize: CGFloat = 12
    static let imageHorizontalPadding: CGFloat = 10
    static let illustrationFrameHeight: CGFloat = 140
    static let maxImageDataSize: Int64 = 12500
    static let navigationDelay: Double = 0.5
    static let focusDelay: Double = 1.0
    static let iconSectionInset: CGFloat = 8
    static let footerSpacing: CGFloat = 4
}

// MARK: - POPOPX ViewModel
@MainActor
private struct PXAddGroupViewModel {
    let profile: GroupProfile
    let incognitoDefault: Bool

    var canCreate: Bool {
        let name = profile.displayName.trimmingCharacters(in: .whitespaces)
        return name != "" && validDisplayName(name)
    }

    var hasInvalidName: Bool {
        let name = profile.displayName.trimmingCharacters(in: .whitespaces)
        return name != mkValidName(name)
    }

    var trimmedDisplayName: String {
        profile.displayName.trimmingCharacters(in: .whitespaces)
    }

    var sharedProfileText: String {
        let name = ChatModel.shared.currentUser?.displayName ?? ""
        return incognitoDefault
            ? NSLocalizedString("A new random profile will be shared.", comment: "shared profile info")
            : String(format: NSLocalizedString("Your profile **%@** will be shared.", comment: "shared profile info"), name)
    }
}

struct AddGroupView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @AppStorage(GROUP_DEFAULT_INCOGNITO, store: groupDefaults) private var incognitoDefault = false
    @State private var chat: Chat?
    @State private var groupInfo: GroupInfo?
    @State private var profile = GroupProfile(displayName: "", fullName: "")
    @FocusState private var focusDisplayName
    @State private var showChooseSource = false
    @State private var showImagePicker = false
    @State private var showTakePhoto = false
    @State private var chosenImage: UIImage? = nil
    @State private var showInvalidNameAlert = false
    @State private var groupLink: GroupLink?
    @State private var groupLinkMemberRole: GroupMemberRole = .member

    private var pxVM: PXAddGroupViewModel {
        PXAddGroupViewModel(profile: profile, incognitoDefault: incognitoDefault)
    }

    var body: some View {
        Group {
        if let chat = chat, let groupInfo = groupInfo {
            if !groupInfo.membership.memberIncognito {
                PXAddGroupMembersCommon(
                    chat: chat,
                    groupInfo: groupInfo,
                    creatingGroup: true,
                    showFooterCounter: false
                ) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + PXAddGroupViewConfig.navigationDelay) {
                        dismissAllSheets(animated: true) {
                            ItemsModel.shared.loadOpenChat(groupInfo.id)
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            } else {
                PXGroupLinkEditor(
                    groupId: groupInfo.groupId,
                    groupLink: $groupLink,
                    groupLinkMemberRole: $groupLinkMemberRole,
                    showTitle: false,
                    creatingGroup: true
                ) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + PXAddGroupViewConfig.navigationDelay) {
                        dismissAllSheets(animated: true) {
                            ItemsModel.shared.loadOpenChat(groupInfo.id)
                        }
                    }
                }
                .navigationTitle(NSLocalizedString("group_link_nav_title", comment: "Group link navigation title"))
            }
        } else {
            createGroupView()
        }
        }
        .popopxBranded()
    }

    @ViewBuilder func createGroupView() -> some View {
        List {
            Group {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .center) {
                        ZStack(alignment: .topTrailing) {
                            ProfileImage(imageStr: profile.image, iconName: "person.2.circle.fill", size: PXAddGroupViewConfig.profileImageSize)
                            if profile.image != nil {
                                Button {
                                    profile.image = nil
                                } label: {
                                    Image(systemName: "multiply")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: PXAddGroupViewConfig.imageRemoveButtonSize)
                                }
                                .accessibilityLabel(Text(NSLocalizedString("Remove group image", comment: "remove image button")))
                            }
                        }

                        editImageButton { showChooseSource = true }
                            .buttonStyle(BorderlessButtonStyle()) // otherwise whole "list row" is clickable
                    }
                    .padding(.horizontal, PXAddGroupViewConfig.imageHorizontalPadding) // Offsets transparent space built into 3D asset
                    #if POPOPX_ASSETS
                    Spacer(minLength: 0)
                    Image(colorScheme == .light ? "create-group" : "create-group-light")
                        .resizable()
                        .scaledToFit()
                        .frame(height: PXAddGroupViewConfig.illustrationFrameHeight)
                    #endif
                    Spacer(minLength: 0)
                }
            }
            .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: PXAddGroupViewConfig.iconSectionInset, leading: 0, bottom: 0, trailing: 0))

            Section {
                groupNameTextField()
                Button(action: createGroup) {
                    settingsRow("checkmark", color: theme.colors.primary) { Text(NSLocalizedString("group_create_button", comment: "Create group button")) }
                }
                .disabled(!canCreateProfile())
                IncognitoToggle(incognitoEnabled: $incognitoDefault)
            } footer: {
                VStack(alignment: .leading, spacing: PXAddGroupViewConfig.footerSpacing) {
                    Text(pxVM.sharedProfileText)
                    Text(NSLocalizedString("group_decentralized_footer", comment: "Group decentralization description"))
                }
                .foregroundColor(theme.colors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    focusDisplayName = false
                }
            }
            .compactSectionSpacing()
        }
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + PXAddGroupViewConfig.focusDelay) {
                focusDisplayName = true
            }
        }
        .confirmationDialog(NSLocalizedString("Group image", comment: "confirmation dialog title"), isPresented: $showChooseSource, titleVisibility: .visible) {
            Button(NSLocalizedString("Take picture", comment: "")) {
                showTakePhoto = true
            }
            Button(NSLocalizedString("Choose from library", comment: "")) {
                showImagePicker = true
            }
        }
        .fullScreenCover(isPresented: $showTakePhoto) {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
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
        .alert(isPresented: $showInvalidNameAlert) {
            createInvalidNameAlert(mkValidName(profile.displayName), $profile.displayName)
        }
        .onChange(of: chosenImage) {_,  image in
            Task {
                let resized: String? = if let image {
                    await resizeImageToStrSize(cropToSquare(image), maxDataSize: PXAddGroupViewConfig.maxImageDataSize)
                } else {
                    nil
                }
                await MainActor.run { profile.image = resized }
            }
        }
        .modifier(ThemedBackground(grouped: true))
    }

    func groupNameTextField() -> some View {
        ZStack(alignment: .leading) {
            if pxVM.hasInvalidName {
                Button {
                    showInvalidNameAlert = true
                } label: {
                    Image(systemName: "exclamationmark.circle").foregroundColor(theme.colors.error)
                }
                .accessibilityLabel(Text(NSLocalizedString("Invalid group name warning", comment: "invalid name accessibility")))
            } else {
                Image(systemName: "pencil").foregroundColor(theme.colors.secondary)
            }
            TextField(NSLocalizedString("Enter group name…", comment: ""), text: $profile.displayName)
                .padding(.leading, 36)
                .focused($focusDisplayName)
                .submitLabel(.continue)
                .onSubmit {
                    if pxVM.canCreate { createGroup() }
                }
        }
    }

    func createGroup() {
        focusDisplayName = false
        profile.displayName = pxVM.trimmedDisplayName
        profile.groupPreferences = GroupPreferences(history: GroupPreference(enable: .on))
        let profileCopy = profile
        let incognito = incognitoDefault
        Task {
            do {
                let gInfo = try await apiNewGroup(incognito: incognito, groupProfile: profileCopy)
                let c = Chat(chatInfo: .group(groupInfo: gInfo, groupChatScope: nil), chatItems: [])
                m.addChat(c)
                withAnimation {
                    groupInfo = gInfo
                    chat = c
                }
            } catch {
                dismissAllSheets(animated: true) {
                    AlertManager.shared.showAlert(
                        Alert(
                            title: Text(NSLocalizedString("group_create_error_title", comment: "Error creating group alert title")),
                            message: Text(verbatim: responseError(error))
                        )
                    )
                }
            }
        }
    }

    func canCreateProfile() -> Bool {
        pxVM.canCreate
    }
}

// Using this method may freeze the app in some cases, so it should be avoided when possible, especially when combined with .focussed modifier.
// It also must only be called from background thread.
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct AddGroupView_Previews: PreviewProvider {
    static var previews: some View {
        AddGroupView()
    }
}

// MARK: - POPOPX
extension AddGroupView {
    var pxComponentTag: String { "px-add-group" }
    var pxGroupNameFieldTag: String { "px-group-name-field" }
    var pxCanCreateGroup: Bool { pxVM.canCreate }
}
