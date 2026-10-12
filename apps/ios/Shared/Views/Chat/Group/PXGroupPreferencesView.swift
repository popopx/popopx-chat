//
//  PXGroupPreferencesView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 16.11.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

private let featureRoles: [(role: GroupMemberRole?, text: LocalizedStringKey)] = [
    (nil, "all members"),
    (.admin, "admins"),
    (.owner, "owners")
]

// MARK: - POPOPX Configuration

private enum PXGroupPrefsConfig {
    static let pickerRowHeight: CGFloat = 40
    static let defaultTimedMessageTTL: Int = 86400
    static let featureIconSize: CGFloat = 24
    static let sectionFooterSpacing: CGFloat = 10
    static let toggleAnimDuration: Double = 0.3
    static let enabledColor: Color = QuantumColors.success
    static let disabledColor: Color = QuantumColors.accent
    static let darkThemeEnabledOpacity: Double = 0.9
    static let featureCount: Int = 10
    static let relayFeatureCount: Int = 5
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXGroupPrefsViewModel {
    let groupInfo: GroupInfo
    let preferences: FullGroupPreferences
    let currentPreferences: FullGroupPreferences
    let creatingGroup: Bool

    var isOwner: Bool { groupInfo.isOwner }
    var isChannel: Bool { groupInfo.isChannel }
    var useRelays: Bool { groupInfo.useRelays }
    var hasUnsavedChanges: Bool { currentPreferences != preferences }

    var saveButtonText: LocalizedStringKey {
        if creatingGroup { return LocalizedStringKey(NSLocalizedString("group_save", comment: "Save")) }
        return groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("group_save_notify_subscribers", comment: "Save and notify subscribers")) : LocalizedStringKey(NSLocalizedString("group_save_notify_members", comment: "Save and notify group members"))
    }

    func featureEnabled(_ feature: GroupFeature) -> GroupFeatureEnabled {
        switch feature {
        case .timedMessages: return preferences.timedMessages.enable
        case .fullDelete: return preferences.fullDelete.enable
        case .directMessages: return preferences.directMessages.enable
        case .reactions: return preferences.reactions.enable
        case .voice: return preferences.voice.enable
        case .files: return preferences.files.enable
        case .popopxLinks: return preferences.popopxLinks.enable
        case .reports: return preferences.reports.enable
        case .history: return preferences.history.enable
        case .support: return preferences.support.enable
        default: return .off
        }
    }

    func roleText(for role: GroupMemberRole?) -> LocalizedStringKey {
        featureRoles.first(where: { $0.role == role })?.text ?? "all members"
    }
}

struct GroupPreferencesView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var groupInfo: GroupInfo
    @Binding var preferences: FullGroupPreferences
    var currentPreferences: FullGroupPreferences
    let creatingGroup: Bool
    let savePreferences: () -> Void
    @State private var showSaveDialogue = false

    private var pxVM: PXGroupPrefsViewModel {
        PXGroupPrefsViewModel(
            groupInfo: groupInfo,
            preferences: preferences,
            currentPreferences: currentPreferences,
            creatingGroup: creatingGroup
        )
    }

    var body: some View {
        VStack {
            List {
                if !groupInfo.useRelays {
                    pxOwnerAdmissionSection
                    pxStandardFeatureSections
                } else {
                    pxRelayFeatureSections
                }
                if groupInfo.isOwner {
                    pxOwnerActionsSection
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        }
        .onChange(of: preferences.timedMessages.enable) {_,  enable in
            if enable == .on {
                if preferences.timedMessages.ttl == nil {
                    preferences.timedMessages.ttl = PXGroupPrefsConfig.defaultTimedMessageTTL
                }
            } else {
                preferences.timedMessages.ttl = currentPreferences.timedMessages.ttl
            }
        }
        .modifier(BackButton(disabled: Binding.constant(false)) {
            if currentPreferences == preferences {
                dismiss()
            } else {
                showSaveDialogue = true
            }
        })
        .confirmationDialog(NSLocalizedString("Save preferences?", comment: "confirmation dialog title"), isPresented: $showSaveDialogue) {
            Button(pxVM.saveButtonText) {
                savePreferences()
                dismiss()
            }
            Button(NSLocalizedString("Exit without saving", comment: "")) {
                preferences = currentPreferences
                dismiss()
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX extracted view builders

    @ViewBuilder
    private var pxOwnerAdmissionSection: some View {
        Section {
            MemberAdmissionButton(
                groupInfo: $groupInfo,
                admission: groupInfo.groupProfile.memberAdmission_,
                currentAdmission: groupInfo.groupProfile.memberAdmission_,
                creatingGroup: creatingGroup
            )
        }
    }

    @ViewBuilder
    private var pxStandardFeatureSections: some View {
        featureSection(.timedMessages, $preferences.timedMessages.enable)
        featureSection(.fullDelete, $preferences.fullDelete.enable)
        featureSection(.directMessages, $preferences.directMessages.enable, $preferences.directMessages.role)
        featureSection(.reactions, $preferences.reactions.enable)
        featureSection(.voice, $preferences.voice.enable, $preferences.voice.role)
        featureSection(.files, $preferences.files.enable, $preferences.files.role)
        featureSection(.popopxLinks, $preferences.popopxLinks.enable, $preferences.popopxLinks.role)
        featureSection(.reports, $preferences.reports.enable, disabled: true)
        featureSection(.history, $preferences.history.enable)
        featureSection(.support, $preferences.support.enable, disabled: true)
    }

    @ViewBuilder
    private var pxRelayFeatureSections: some View {
        featureSection(.timedMessages, $preferences.timedMessages.enable)
        featureSection(.fullDelete, $preferences.fullDelete.enable)
        featureSection(.reactions, $preferences.reactions.enable)
        featureSection(.history, $preferences.history.enable)
        let supportNotice = NSLocalizedString("Chats with admins in public channels have no E2E encryption - use only with trusted chat relays.", comment: "alert message")
        featureSection(.support, $preferences.support.enable, notice: supportNotice)
            .onChange(of: preferences.support.enable) {_,  enable in
                if enable == .on {
                    showAlert(
                        NSLocalizedString("Enable chats with admins?", comment: "alert title"),
                        message: supportNotice,
                        actions: {[
                            UIAlertAction(title: NSLocalizedString("Enable", comment: "alert button"), style: .destructive) { _ in },
                            UIAlertAction(title: NSLocalizedString("Cancel", comment: "alert button"), style: .cancel) { _ in
                                preferences.support.enable = .off
                            }
                        ]}
                    )
                }
            }
    }

    @ViewBuilder
    private var pxOwnerActionsSection: some View {
        Section {
            Button(NSLocalizedString("Reset", comment: "")) { preferences = currentPreferences }
            Button(pxVM.saveButtonText) { savePreferences() }
        }
        .disabled(currentPreferences == preferences)
    }

    private func featureSection(_ feature: GroupFeature, _ enableFeature: Binding<GroupFeatureEnabled>, _ enableForRole: Binding<GroupMemberRole?>? = nil, disabled: Bool = false, notice: String? = nil) -> some View {
        Section {
            let pxIsActive = enableFeature.wrappedValue == .on
            let pxColor: Color = pxIsActive
                ? (isInDarkTheme() ? PXGroupPrefsConfig.enabledColor.opacity(PXGroupPrefsConfig.darkThemeEnabledOpacity) : PXGroupPrefsConfig.enabledColor)
                : theme.colors.secondary
            let pxIcon = pxIsActive ? feature.iconFilled : feature.icon
            let pxTimedActive = feature == .timedMessages && pxIsActive
            if groupInfo.isOwner {
                let enable = Binding(
                    get: { enableFeature.wrappedValue == .on },
                    set: { on, _ in enableFeature.wrappedValue = on ? .on : .off }
                )
                settingsRow(pxIcon, color: pxColor) {
                    Toggle(feature.text(isChannel: groupInfo.isChannel), isOn: enable)
                }
                .disabled(disabled)
                if pxTimedActive {
                    PXDropdownTimePicker(
                        selection: $preferences.timedMessages.ttl,
                        label: LocalizedStringKey(NSLocalizedString("prefs_delete_after", comment: "Delete after")),
                        dropdownValues: TimedMessagesPreference.ttlValues,
                        customPickerConfirmButtonText: LocalizedStringKey(NSLocalizedString("prefs_select_button", comment: "Select")),
                        customPickerDescription: LocalizedStringKey(NSLocalizedString("prefs_delete_after", comment: "Delete after"))
                    )
                    .frame(height: PXGroupPrefsConfig.pickerRowHeight)
                }
                if pxIsActive, let enableForRole {
                    pxRolePicker(enableForRole)
                }
            } else {
                settingsRow(pxIcon, color: pxColor) {
                    infoRow(Text(feature.text(isChannel: groupInfo.isChannel)), enableFeature.wrappedValue.text)
                }
                if pxTimedActive {
                    infoRow("Delete after", timeText(preferences.timedMessages.ttl))
                }
                if pxIsActive, let enableForRole {
                    pxReadOnlyRoleRow(enableForRole)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: PXGroupPrefsConfig.sectionFooterSpacing) {
                Text(feature.enableDescription(enableFeature.wrappedValue, groupInfo.isOwner, isChannel: groupInfo.isChannel))
                if let notice { Text(notice) }
            }
            .foregroundColor(theme.colors.secondary)
        }
        .onChange(of: enableFeature.wrappedValue) {_,  enabled in
            if case .off = enabled {
                enableForRole?.wrappedValue = nil
            }
        }
    }

    // MARK: - POPOPX role picker helpers

    private func pxRolePicker(_ enableForRole: Binding<GroupMemberRole?>) -> some View {
        Picker(LocalizedStringKey(NSLocalizedString("group_enabled_for", comment: "Enabled for picker label")), selection: enableForRole) {
            ForEach(featureRoles, id: \.role) { fr in
                Text(fr.text)
            }
        }
        .frame(height: PXGroupPrefsConfig.pickerRowHeight)
    }

    private func pxReadOnlyRoleRow(_ enableForRole: Binding<GroupMemberRole?>) -> some View {
        HStack {
            Text(NSLocalizedString("group_enabled_for", comment: "Label for feature role restriction"))
                .foregroundColor(theme.colors.secondary)
            Spacer()
            Text(
                featureRoles.first(where: { fr in fr.role == enableForRole.wrappedValue })?.text
                ?? "all members"
            )
            .foregroundColor(theme.colors.secondary)
        }
    }
}

struct MemberAdmissionButton: View {
    @Binding var groupInfo: GroupInfo
    @State var admission: GroupMemberAdmission
    @State var currentAdmission: GroupMemberAdmission
    var creatingGroup: Bool = false

    var body: some View {
        NavigationLink {
            MemberAdmissionView(
                groupInfo: $groupInfo,
                admission: $admission,
                currentAdmission: currentAdmission,
                creatingGroup: creatingGroup,
                saveAdmission: saveAdmission
            )
            .navigationTitle(NSLocalizedString("member_admission_nav_title", comment: "Member admission navigation title"))
            .modifier(ThemedBackground(grouped: true))
            .navigationBarTitleDisplayMode(.large)
            .onDisappear {
                let saveText = NSLocalizedString(
                    creatingGroup ? "Save" : "Save and notify group members",
                    comment: "alert button"
                )

                if groupInfo.groupProfile.memberAdmission_ != admission {
                    showAlert(
                        title: NSLocalizedString("Save admission settings?", comment: "alert title"),
                        buttonTitle: saveText,
                        buttonAction: { saveAdmission() },
                        cancelButton: true
                    )
                }
            }
        } label: {
            if creatingGroup {
                Text(NSLocalizedString("group_set_member_admission", comment: "Button to configure member admission during group creation"))
            } else {
                Label(NSLocalizedString("group_member_admission", comment: "Member admission settings label"), systemImage: "switch.2")
            }
        }
    }

    private func saveAdmission() {
        logger.info("POPOPX: saveAdmission for group \(groupInfo.groupId)")
        logger.debug("PX: [saveAdmission] creatingGroup=\(creatingGroup)")
        Task {
            do {
                var gp = groupInfo.groupProfile
                gp.memberAdmission = admission
                let gInfo = try await apiUpdateGroup(groupInfo.groupId, gp)
                await MainActor.run {
                    groupInfo = gInfo
                    ChatModel.shared.updateGroup(gInfo)
                    currentAdmission = admission
                }
            } catch {
                logger.error("MemberAdmissionView apiUpdateGroup error: \(responseError(error))")
            }
        }
    }
}

// MARK: - POPOPX

extension GroupPreferencesView {
    var pxComponentTag: String { "PX_GROUP_PREFERENCES" }
    var pxIsCreating: Bool { creatingGroup }
    var pxIsOwner: Bool { groupInfo.isOwner }
}

extension MemberAdmissionButton {
    var pxComponentTag: String { "PX_MEMBER_ADMISSION_BUTTON" }
    var pxIsCreating: Bool { creatingGroup }
}

struct GroupPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        GroupPreferencesView(
            groupInfo: Binding.constant(GroupInfo.sampleData),
            preferences: Binding.constant(FullGroupPreferences.sampleData),
            currentPreferences: FullGroupPreferences.sampleData,
            creatingGroup: false,
            savePreferences: {}
        )
    }
}
