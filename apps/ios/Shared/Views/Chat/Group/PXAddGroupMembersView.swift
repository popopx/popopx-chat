//
//  PXAddGroupMembers.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 22.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxGroupMembersAnimEnabled = UserDefaults.standard.bool(forKey: "PX_GROUP_MEMBERS_ANIM_ENABLED")

// MARK: - POPOPX Layout Config
private enum PXAddGroupMembersConfig {
    static let toolbarImageSize: CGFloat = 48
    static let contactCheckImageSize: CGFloat = 30
    static let pickerRowHeight: CGFloat = 36
    static let searchFieldHeight: CGFloat = 36
    static let contactProfilePadding: CGFloat = 2
    static let searchIconSize: CGFloat = 20
    static let searchIconTrailingPad: CGFloat = 10
    static let searchClearIconSize: CGFloat = 20
    static let searchLeadingPad: CGFloat = 2
    static let contactImageSize: CGFloat = 31
    static let contactImageTrailingPad: CGFloat = 4
    static let animDuration: Double = 0.32
    static let contactCornerRx: CGFloat = 6
    static let searchCornerRx: CGFloat = 10
    static let incognitoIcon: String = "theatermasks.circle.fill"
    static let checkedIcon: String = "checkmark.circle.fill"
    static let uncheckedIcon: String = "circle"
    static let inviteCheckIcon: String = "checkmark"
    static let searchIcon: String = "magnifyingglass"
    static let clearIcon: String = "xmark.circle.fill"
}

// MARK: - POPOPX View Model
@MainActor
private struct PXAddGroupMembersViewModel {
    let chat: Chat
    let groupInfo: GroupInfo
    let selectedCount: Int
    let creatingGroup: Bool

    var pxInviteLabel: String {
        groupInfo.businessChat == nil
            ? NSLocalizedString("Invite to group", comment: "")
            : NSLocalizedString("Invite to chat", comment: "")
    }

    var pxCanInvite: Bool { selectedCount >= 1 }

    var pxIsIncognitoConflict: Bool { !chat.chatInfo.incognito }

    var pxSelectedCountText: String { "\(selectedCount) selected" }
}

struct PXAddGroupMembers: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    var chat: Chat
    var groupInfo: GroupInfo

    var body: some View {
        PXAddGroupMembersCommon(chat: chat, groupInfo: groupInfo, addedMembersCb: { _ in dismiss() })
            .popopxBranded()
    }
}

struct PXAddGroupMembersCommon: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    var chat: Chat
    @State var groupInfo: GroupInfo
    var creatingGroup: Bool = false
    var showFooterCounter: Bool = true
    var addedMembersCb: ((Set<Int64>) -> Void)
    @State private var selectedContacts = Set<Int64>()
    @State private var selectedRole: GroupMemberRole = .member
    @State private var alert: AddGroupMembersAlert?
    @State private var searchText: String = ""
    @FocusState private var searchFocussed

    private enum AddGroupMembersAlert: Identifiable {
        case prohibitedToInviteIncognito
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .prohibitedToInviteIncognito: return "prohibitedToInviteIncognito"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        if creatingGroup {
            pxGroupMembersList
                .navigationBarBackButtonHidden()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("group_add_skip", comment: "Skip button")) { addedMembersCb(selectedContacts) }
                    }
                }
        } else {
            pxGroupMembersList
        }
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxGroupMembersList: some View {
        VStack {
            let membersToAdd = pxFilterMembersToAdd()
            List {
                pxToolbarHeader
                if membersToAdd.isEmpty {
                    pxEmptyStateView
                } else {
                    pxRoleAndInviteSection
                    pxContactListSection(members: membersToAdd)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .alert(item: $alert) { alertItem in pxAlertForItem(alertItem) }
        .onChange(of: selectedContacts) { _, _ in searchFocussed = false }
        .modifier(ThemedBackground(grouped: true))
    }

    @ViewBuilder
    private var pxToolbarHeader: some View {
        ChatInfoToolbar(chat: chat, imageSize: PXAddGroupMembersConfig.toolbarImageSize)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var pxEmptyStateView: some View {
        Text(NSLocalizedString("group_no_contacts_to_add", comment: "Empty state when no contacts available to add"))
            .foregroundColor(theme.colors.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var pxRoleAndInviteSection: some View {
        let count = selectedContacts.count
        Section {
            if creatingGroup {
                MemberAdmissionButton(
                    groupInfo: $groupInfo,
                    admission: groupInfo.groupProfile.memberAdmission_,
                    currentAdmission: groupInfo.groupProfile.memberAdmission_,
                    creatingGroup: true
                )
                GroupPreferencesButton(
                    groupInfo: $groupInfo,
                    preferences: groupInfo.fullGroupPreferences,
                    currentPreferences: groupInfo.fullGroupPreferences,
                    creatingGroup: true
                )
            }
            pxRolePicker
            pxInviteButton
                .disabled(count < 1)
        } footer: {
            pxFooterSection(count: count)
        }
    }

    @ViewBuilder
    private var pxRolePicker: some View {
        Picker(NSLocalizedString("group_new_member_role_picker", comment: "New member role picker label"), selection: $selectedRole) {
            ForEach(GroupMemberRole.supportedRoles.filter({ $0 <= groupInfo.membership.memberRole })) { role in
                Text(role.text)
            }
        }
        .frame(height: PXAddGroupMembersConfig.pickerRowHeight)
    }

    @ViewBuilder
    private var pxInviteButton: some View {
        let vm = PXAddGroupMembersViewModel(
            chat: chat,
            groupInfo: groupInfo,
            selectedCount: selectedContacts.count,
            creatingGroup: creatingGroup
        )
        Button {
            pxInviteMembers()
        } label: {
            HStack {
                Text(vm.pxInviteLabel)
                Image(systemName: PXAddGroupMembersConfig.inviteCheckIcon)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel(Text(vm.pxInviteLabel))
    }

    @ViewBuilder
    private func pxFooterSection(count: Int) -> some View {
        if showFooterCounter {
            if count >= 1 {
                HStack {
                    Button { selectedContacts.removeAll() } label: {
                        Text(NSLocalizedString("group_clear_selection", comment: "Clear selection button"))
                            .font(.caption)
                    }
                    .accessibilityLabel(Text(NSLocalizedString("a11y_clear_selection", comment: "")))
                    Spacer()
                    Text(String(format: NSLocalizedString("group_contacts_selected_fmt", comment: "Contact count footer"), count))
                        .foregroundColor(theme.colors.secondary)
                }
            } else {
                Text(NSLocalizedString("group_no_contacts_selected", comment: "No contacts selected footer"))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    @ViewBuilder
    private func pxContactListSection(members: [Contact]) -> some View {
        Section {
            pxSearchField
            let s = searchText.trimmingCharacters(in: .whitespaces).localizedLowercase
            let filtered = s == "" ? members : members.filter { $0.chatViewName.localizedLowercase.contains(s) }
            ForEach(filtered + [pxDummyContact]) { contact in
                if contact.contactId != pxDummyContact.contactId {
                    pxContactCheckRow(contact)
                }
            }
        }
    }

    @ViewBuilder
    private var pxSearchField: some View {
        pxSearchFieldView(
            text: $searchText,
            focussed: $searchFocussed,
            theme.colors.primary,
            theme.colors.secondary
        )
        .padding(.leading, PXAddGroupMembersConfig.searchLeadingPad)
    }

    // MARK: - POPOPX Contact Row

    @ViewBuilder
    private func pxContactCheckRow(_ contact: Contact) -> some View {
        let checked = selectedContacts.contains(contact.apiId)
        let prohibited = !chat.chatInfo.incognito && contact.contactConnIncognito
        let iconInfo = pxContactIconInfo(checked: checked, prohibited: prohibited)

        Button {
            pxHandleContactTap(contact: contact, prohibited: prohibited, checked: checked)
        } label: {
            HStack {
                ProfileImage(imageStr: contact.image, size: PXAddGroupMembersConfig.contactImageSize)
                    .padding(.trailing, PXAddGroupMembersConfig.contactProfilePadding + 2)
                NameWithBadge(
                    Text(ChatInfo.direct(contact: contact).chatViewName)
                        .foregroundColor(prohibited ? theme.colors.secondary : theme.colors.onBackground),
                    contact.active ? contact.profile.localBadge : nil
                )
                .lineLimit(1)
                Spacer()
                Image(systemName: iconInfo.name)
                    .foregroundColor(iconInfo.color)
            }
        }
        .accessibilityLabel(Text(contact.chatViewName))
    }

    // MARK: - POPOPX Helpers

    // Resolves keyboard losing focus bug in iOS16 and iOS17,
    // when there are no items inside `ForEach(members)` loop
    private let pxDummyContact: Contact = {
        var dummy = Contact.sampleData
        dummy.contactId = -1
        return dummy
    }()

    private func pxFilterMembersToAdd() -> [Contact] {
        filterMembersToAdd(chatModel.groupMembers)
    }

    private func pxContactIconInfo(checked: Bool, prohibited: Bool) -> (name: String, color: Color) {
        if prohibited {
            return (PXAddGroupMembersConfig.incognitoIcon, Color(uiColor: .tertiaryLabel).asAnotherColorFromSecondary(theme))
        }
        if checked {
            return (PXAddGroupMembersConfig.checkedIcon, theme.colors.primary)
        }
        return (PXAddGroupMembersConfig.uncheckedIcon, Color(uiColor: .tertiaryLabel).asAnotherColorFromSecondary(theme))
    }

    private func pxHandleContactTap(contact: Contact, prohibited: Bool, checked: Bool) {
        if prohibited {
            alert = .prohibitedToInviteIncognito
        } else {
            if checked {
                selectedContacts.remove(contact.apiId)
            } else {
                selectedContacts.insert(contact.apiId)
            }
        }
    }

    private func pxAlertForItem(_ alertItem: AddGroupMembersAlert) -> Alert {
        switch alertItem {
        case .prohibitedToInviteIncognito:
            return Alert(
                title: Text(NSLocalizedString("group_cant_invite_contact_title", comment: "Alert title when can't invite contact")),
                message: Text(NSLocalizedString("group_cant_invite_contact_msg", comment: "Alert message explaining incognito profile conflict"))
            )
        case let .error(title, error):
            return mkAlert(title: title, message: error)
        }
    }

    // MARK: - POPOPX Actions

    private func pxInviteMembers() {
        logger.info("POPOPX: inviteMembers started for group \(groupInfo.groupId), selecting \(selectedContacts.count) contacts")
        let pxRoleDescription = selectedRole.text
        logger.debug("PX: [inviteMembers] role=\(pxRoleDescription), count=\(selectedContacts.count)")
        Task {
            do {
                for contactId in selectedContacts {
                    let member = try await apiAddMember(groupInfo.groupId, contactId, selectedRole)
                    await MainActor.run { _ = chatModel.upsertGroupMember(groupInfo, member) }
                }
                logger.debug("PX: [inviteMembers] completed for \(selectedContacts.count) members")
                addedMembersCb(selectedContacts)
            } catch {
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error adding member(s)", comment: "")), message: LocalizedStringKey(responseError(error)))
                }
            }
        }
    }

    // MARK: - POPOPX Search Field

    @ViewBuilder
    private func pxSearchFieldView(text: Binding<String>, focussed: FocusState<Bool>.Binding, _ primaryColor: Color, _ secondaryColor: Color) -> some View {
        HStack {
            Image(systemName: PXAddGroupMembersConfig.searchIcon)
                .resizable()
                .scaledToFit()
                .frame(height: PXAddGroupMembersConfig.searchIconSize)
                .padding(.trailing, PXAddGroupMembersConfig.searchIconTrailingPad)
            TextField(NSLocalizedString("Search", comment: ""), text: text)
                .focused(focussed)
                .foregroundColor(primaryColor)
                .frame(maxWidth: .infinity)
                .autocorrectionDisabled(true)
            Image(systemName: PXAddGroupMembersConfig.clearIcon)
                .resizable()
                .scaledToFit()
                .opacity(text.wrappedValue == "" ? 0 : 1)
                .frame(height: PXAddGroupMembersConfig.searchClearIconSize)
                .onTapGesture {
                    text.wrappedValue = ""
                    focussed.wrappedValue = false
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y_clear_search", comment: "")))
        }
        .foregroundColor(secondaryColor)
        .frame(height: PXAddGroupMembersConfig.searchFieldHeight)
    }
}

func searchFieldView(text: Binding<String>, focussed: FocusState<Bool>.Binding, _ onBackgroundColor: Color, _ secondaryColor: Color) -> some View {
    HStack {
        Image(systemName: "magnifyingglass")
            .resizable()
            .scaledToFit()
            .frame(height: 20)
            .padding(.trailing, 10)
        TextField(NSLocalizedString("Search", comment: ""), text: text)
            .focused(focussed)
            .foregroundColor(onBackgroundColor)
            .frame(maxWidth: .infinity)
            .autocorrectionDisabled(true)
        Image(systemName: "xmark.circle.fill")
            .resizable()
            .scaledToFit()
            .opacity(text.wrappedValue == "" ? 0 : 1)
            .frame(height: 20)
            .onTapGesture {
                text.wrappedValue = ""
                focussed.wrappedValue = false
            }
    }
    .foregroundColor(secondaryColor)
    .frame(height: 36)
}

// MARK: - POPOPX

extension PXAddGroupMembersCommon {
    var pxComponentTag: String { "PX_ADD_GROUP_MEMBERS" }
    var pxSelectedCountDescription: String { "\(selectedContacts.count) selected" }
    var pxIsCreating: Bool { creatingGroup }
    static let pxContactCheckSize: CGFloat = PXAddGroupMembersConfig.contactCheckImageSize
    static let pxSearchHeight: CGFloat = PXAddGroupMembersConfig.searchFieldHeight
    static let pxInviteAnimDuration: Double = PXAddGroupMembersConfig.animDuration
    static let pxContactCornerRx: CGFloat = PXAddGroupMembersConfig.contactCornerRx
    static let pxSearchCornerRx: CGFloat = PXAddGroupMembersConfig.searchCornerRx
}

struct PXAddGroupMembers_Previews: PreviewProvider {
    static var previews: some View {
        PXAddGroupMembers(chat: Chat(chatInfo: ChatInfo.sampleData.group), groupInfo: GroupInfo.sampleData)
    }
}
