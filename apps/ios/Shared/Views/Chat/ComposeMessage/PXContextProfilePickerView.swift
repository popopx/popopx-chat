//
//  ContextProfilePickerView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 13.06.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxProfileFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")

/// POPOPX: Layout and appearance configuration
private enum PXProfilePickerConfig {
    static let pxUserRowHeight: CGFloat = 62
    static let pxMaxVisibleRows: CGFloat = 5.0
    static let pxChevronOpacity: Double = 0.65
    static let pxProfileImageDimension: CGFloat = 38
    static let pxRowLeadingInset: CGFloat = 12
    static let pxSectionTopPadding: CGFloat = 8
    static let pxSectionBottomPadding: CGFloat = -4
    static let pxChevronFontSize: CGFloat = 12
    static let pxDividerLeadingExtra: CGFloat = 48
    static let pxInfoIconSize: CGFloat = 16
    static let pxExpandAnimationDuration: Double = 0.2
}

let USER_ROW_SIZE: CGFloat = PXProfilePickerConfig.pxUserRowHeight
let MAX_VISIBLE_USER_ROWS: CGFloat = PXProfilePickerConfig.pxMaxVisibleRows

/// POPOPX: View model extracting computed state from the view
@MainActor
private struct PXProfilePickerViewModel {
    let chat: Chat
    let selectedUser: User
    let incognitoDefault: Bool
    let listExpanded: Bool

    var pxShouldShowExpanded: Bool {
        !listExpanded || chat.chatInfo.profileChangeProhibited
    }

    var pxIsCurrentSelected: Bool {
        selectedUser.activeUser || !selectedUser.hidden
    }

    var pxProfileChangeBlocked: Bool {
        chat.chatInfo.profileChangeProhibited
    }
}

struct ContextProfilePickerView: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State var selectedUser: User
    @State private var users: [User] = []
    @State private var listExpanded = false
    @State private var expandedListReady = false
    @State private var showIncognitoSheet = false

    @AppStorage(GROUP_DEFAULT_INCOGNITO, store: groupDefaults) private var incognitoDefault = false

    private let pxChevronOpacity: Double = PXProfilePickerConfig.pxChevronOpacity
    private let pxProfileImageSize: CGFloat = PXProfilePickerConfig.pxProfileImageDimension
    private let pxRowLeadingPadding: CGFloat = PXProfilePickerConfig.pxRowLeadingInset
    private let pxSectionHeaderTopPadding: CGFloat = PXProfilePickerConfig.pxSectionTopPadding
    private let pxSectionHeaderBottomPadding: CGFloat = PXProfilePickerConfig.pxSectionBottomPadding

    var body: some View {
        pxMainContainer
            .onAppear {
                users = chatModel.users
                    .map { $0.user }
                    .filter { u in u.activeUser || !u.hidden }
            }
            .sheet(isPresented: $showIncognitoSheet) {
                IncognitoHelp()
            }
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder private var pxMainContainer: some View {
        Group {
            if pxViewModel.pxShouldShowExpanded {
                pxCurrentSelectionView
            } else {
                pxExpandedProfileList
            }
        }
    }

    private var pxViewModel: PXProfilePickerViewModel {
        PXProfilePickerViewModel(
            chat: chat,
            selectedUser: selectedUser,
            incognitoDefault: incognitoDefault,
            listExpanded: listExpanded
        )
    }

    private func viewBody() -> some View {
        pxMainContainer
    }

    @ViewBuilder private var pxCurrentSelectionView: some View {
        VStack(spacing: 0) {
            pxSectionHeader
            pxActiveProfileDisplay
        }
    }

    private func currentSelection() -> some View {
        pxCurrentSelectionView
    }

    @ViewBuilder private var pxSectionHeader: some View {
        HStack {
            Text(NSLocalizedString("compose_your_profile", comment: "Label for user's profile selection"))
                .font(.callout)
                .foregroundColor(theme.colors.secondary)
            Spacer()
        }
        .padding(.top, pxSectionHeaderTopPadding)
        .padding(.bottom, pxSectionHeaderBottomPadding)
        .padding(.leading, pxRowLeadingPadding)
        .padding(.trailing)
        .accessibilityLabel(Text(NSLocalizedString("compose_your_profile", comment: "")))
    }

    @ViewBuilder private var pxActiveProfileDisplay: some View {
        if chat.chatInfo.profileChangeProhibited {
            if chat.chatInfo.incognito {
                pxIncognitoButton
            } else {
                profilerPickerUserOption(selectedUser)
            }
        } else if incognitoDefault {
            pxIncognitoButton
        } else {
            profilerPickerUserOption(selectedUser)
        }
    }

    private func profilePicker() -> some View {
        pxExpandedProfileList
    }

    @ViewBuilder private var pxExpandedProfileList: some View {
        ScrollViewReader { proxy in
            Group {
                if expandedListReady {
                    let scroll = ScrollView {
                        LazyVStack(spacing: 0) {
                            let otherUsers = users
                                .filter { u in u.userId != selectedUser.userId }
                                .sorted(using: KeyPathComparator<User>(\.activeOrder))
                            ForEach(otherUsers) { p in
                                profilerPickerUserOption(p)
                                    .contentShape(Rectangle())
                                pxGlassDivider
                            }

                            if incognitoDefault {
                                profilerPickerUserOption(selectedUser)
                                    .contentShape(Rectangle())
                                pxGlassDivider

                                pxIncognitoButton
                                    .contentShape(Rectangle())
                                    .id("BOTTOM_ANCHOR")
                            } else {
                                pxIncognitoButton
                                    .contentShape(Rectangle())
                                pxGlassDivider

                                profilerPickerUserOption(selectedUser)
                                    .contentShape(Rectangle())
                                    .id("BOTTOM_ANCHOR")
                            }
                        }
                    }
                        .frame(maxHeight: USER_ROW_SIZE * min(MAX_VISIBLE_USER_ROWS, CGFloat(users.count + 1)))
                        .onAppear {
                            DispatchQueue.main.async {
                                withAnimation(nil) {
                                    proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
                                }
                            }
                        }
                        .onDisappear {
                            expandedListReady = false
                        }

                    scroll.scrollDismissesKeyboard(.never)
                } else {
                    // Keep showing current selection to avoid flickering of scroll to bottom
                    pxCurrentSelectionView
                        .onAppear {
                            // Delay rendering of expanded profile list
                            DispatchQueue.main.async {
                                expandedListReady = true
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder private var pxGlassDivider: some View {
        GlassDivider()
            .padding(.leading)
            .padding(.leading, PXProfilePickerConfig.pxDividerLeadingExtra)
    }

    private func pxChevronImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundColor(theme.colors.secondary)
            .opacity(pxChevronOpacity)
            .accessibilityLabel(Text(
                systemName == "chevron.down"
                ? NSLocalizedString("px_collapse_profiles", comment: "")
                : NSLocalizedString("px_expand_profiles", comment: "")
            ))
    }

    @ViewBuilder private func pxProfileRowContent(
        user: User,
        isSelected: Bool,
        leadingView: () -> some View,
        trailingChevron: Bool
    ) -> some View {
        HStack {
            leadingView()
            Spacer()
            if trailingChevron {
                if listExpanded {
                    pxChevronImage(systemName: "chevron.down")
                } else if !chat.chatInfo.profileChangeProhibited {
                    pxChevronImage(systemName: "chevron.up")
                }
            }
        }
        .padding(.leading, pxRowLeadingPadding)
        .padding(.trailing)
        .frame(height: USER_ROW_SIZE)
    }
    
    private func profilerPickerUserOption(_ user: User) -> some View {
        Button {
            pxHandleProfileSelection(user)
        } label: {
            pxProfileRowContent(
                user: user,
                isSelected: selectedUser == user && !incognitoDefault,
                leadingView: {
                    pxProfileLeadingContent(user: user)
                },
                trailingChevron: selectedUser == user && !incognitoDefault
            )
        }
        .accessibilityLabel(Text(user.chatViewName))
    }

    @ViewBuilder private func pxProfileLeadingContent(user: User) -> some View {
        ProfileImage(imageStr: user.image, size: pxProfileImageSize)
        NameWithBadge(
            Text(user.chatViewName)
                .fontWeight(selectedUser == user && !incognitoDefault ? .medium : .regular)
                .foregroundColor(theme.colors.onBackground),
            user.profile.localBadge
        )
        .lineLimit(1)
    }

    private func pxHandleProfileSelection(_ user: User) {
        if !chat.chatInfo.profileChangeProhibited {
            if selectedUser == user {
                if !incognitoDefault {
                    listExpanded.toggle()
                } else {
                    incognitoDefault = false
                    listExpanded = false
                }
            } else if selectedUser != user {
                changeProfile(user)
            }
        } else {
            showCantChangeProfileAlert()
        }
    }

    private func changeProfile(_ newUser: User) {
        logger.debug("PX: [changeProfile] switching to userId=\(newUser.userId)")
        Task {
            do {
                if let contact = chat.chatInfo.contact {
                    let pxContactId = contact.contactId
                    let updatedContact = try await apiChangePreparedContactUser(contactId: pxContactId, newUserId: newUser.userId)
                    await MainActor.run {
                        selectedUser = newUser
                        incognitoDefault = false
                        listExpanded = false
                        chatModel.updateContact(updatedContact)
                    }
                } else if let groupInfo = chat.chatInfo.groupInfo {
                    let pxGroupId = groupInfo.groupId
                    let updatedGroupInfo = try await apiChangePreparedGroupUser(groupId: pxGroupId, newUserId: newUser.userId)
                    await MainActor.run {
                        selectedUser = newUser
                        incognitoDefault = false
                        listExpanded = false
                        chatModel.updateGroup(updatedGroupInfo)
                    }
                }
                do {
                    try await changeActiveUserAsync_(newUser.userId, viewPwd: nil, keepingChatId: chat.id)
                } catch {
                    await MainActor.run {
                        showAlert(
                            NSLocalizedString("Error switching profile", comment: "alert title"),
                            message: String.localizedStringWithFormat(NSLocalizedString("Your chat was moved to %@ but an unexpected error occurred while redirecting you to the profile.", comment: "alert message"), newUser.chatViewName)
                        )
                    }
                }
            } catch let error {
                await MainActor.run {
                    if let currentUser = chatModel.currentUser {
                        selectedUser = currentUser
                    }
                    showAlert(
                        NSLocalizedString("Error changing chat profile", comment: "alert title"),
                        message: responseError(error)
                    )
                }
            }
        }
    }

    private func incognitoOption() -> some View {
        pxIncognitoButton
    }

    @ViewBuilder private var pxIncognitoButton: some View {
        Button {
            pxHandleIncognitoToggle()
        } label: {
            pxProfileRowContent(
                user: selectedUser,
                isSelected: incognitoDefault,
                leadingView: { pxIncognitoLeadingContent },
                trailingChevron: incognitoDefault
            )
        }
        .accessibilityLabel(Text(NSLocalizedString("compose_incognito", comment: "")))
    }

    @ViewBuilder private var pxIncognitoLeadingContent: some View {
        pxIncognitoProfileImage
        Text(NSLocalizedString("compose_incognito", comment: "Label for incognito profile option"))
            .fontWeight(incognitoDefault ? .medium : .regular)
            .foregroundColor(theme.colors.onBackground)
        Image(systemName: "info.circle")
            .font(.subheadline)
            .foregroundColor(theme.colors.primary)
            .onTapGesture {
                showIncognitoSheet = true
            }
            .accessibilityLabel(Text(NSLocalizedString("px_incognito_info", comment: "")))
    }

    private func pxHandleIncognitoToggle() {
        if !chat.chatInfo.profileChangeProhibited {
            if incognitoDefault {
                listExpanded.toggle()
            } else {
                incognitoDefault = true
                listExpanded = false
            }
        } else {
            showCantChangeProfileAlert()
        }
    }

    private func incognitoProfileImage() -> some View {
        pxIncognitoProfileImage
    }

    @ViewBuilder private var pxIncognitoProfileImage: some View {
        Image(systemName: "theatermasks.fill")
            .resizable()
            .scaledToFit()
            .frame(width: pxProfileImageSize)
            .foregroundColor(QuantumColors.accent)
    }

    private func showCantChangeProfileAlert() {
        logger.debug("PX: [showCantChangeProfileAlert] profile change prohibited")
        showAlert(
            NSLocalizedString("Can't change profile", comment: "alert title"),
            message: NSLocalizedString("To use another profile after connection attempt, delete the chat and use the link again.", comment: "alert message")
        )
    }
}

#Preview {
    ContextProfilePickerView(
        chat: Chat.sampleData,
        selectedUser: User.sampleData
    )
}

// MARK: - POPOPX
extension ContextProfilePickerView {
    var pxComponentTag: String { "px-ctx-profile-picker" }
    var pxIsExpanded: Bool { listExpanded }
    var pxUserCount: Int { users.count }
    static let pxMaxVisibleRows: CGFloat = PXProfilePickerConfig.pxMaxVisibleRows
    static let pxRowHeight: CGFloat = PXProfilePickerConfig.pxUserRowHeight
    static let pxChevronAnimDuration: Double = PXProfilePickerConfig.pxExpandAnimationDuration
}
