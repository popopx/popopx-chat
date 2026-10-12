//
//  PXGroupLinkEditor.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 15.10.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Config
private enum PXGroupLinkConfig {
    static let rolePickerHeight: CGFloat = 38
    static let progressScale: CGFloat = 2.2
    static let emptyRowInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    static let sectionHeaderFont: Font = QuantumFonts.sectionHeader
    static let darkTitleFont: Font = .largeTitle
    static let componentTag: String = "PX_GROUP_LINK"
    static let upgradeIcon: String = "arrow.up"
    static let shareIcon: String = "square.and.arrow.up"
    static let forwardIcon: String = "arrowshape.turn.up.forward"
    static let deleteIcon: String = "trash"
    static let createIcon: String = "link.badge.plus"
    static let qrCodePrefix: String = "popopx-qrcode-view-for-"
}

// MARK: - POPOPX View Model
@MainActor
private struct PXGroupLinkViewModel {
    let groupLink: GroupLink?
    let isChannel: Bool
    let creatingGroup: Bool
    let creatingLink: Bool
    let showShortLink: Bool
    let groupInfo: GroupInfo?

    var pxHasLink: Bool { groupLink != nil }
    var pxCanShareViaChat: Bool { groupInfo?.groupProfile.publicGroup != nil }
    var pxShouldAutoCreate: Bool { groupLink == nil && !creatingLink }
    var pxHasShortLink: Bool { groupLink?.connLinkContact.connShortLink != nil }
    var pxTitleText: String {
        isChannel
            ? NSLocalizedString("Channel link", comment: "")
            : NSLocalizedString("Group link", comment: "")
    }
    var pxDescriptionText: String {
        if isChannel {
            return NSLocalizedString("group_share_link_desc_channel", comment: "Description for channel link sharing")
        }
        return NSLocalizedString("group_share_link_desc_group", comment: "Description for group link sharing")
    }
}

struct PXGroupLinkEditor: View {
    @EnvironmentObject var theme: AppTheme
    var groupId: Int64
    @Binding var groupLink: GroupLink?
    @Binding var groupLinkMemberRole: GroupMemberRole
    var showTitle: Bool = false
    var creatingGroup: Bool = false
    var isChannel: Bool = false
    var groupInfo: GroupInfo? = nil
    var composeState: Binding<ComposeState>? = nil
    var linkCreatedCb: (() -> Void)? = nil
    @State private var showSharePicker = false
    @State private var showShortLink = true
    @State private var creatingLink = false
    @State private var alert: GroupLinkAlert?
    @State private var shouldCreate = true

    private enum GroupLinkAlert: Identifiable {
        case deleteLink
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .deleteLink: return "deleteLink"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        pxMainContainer
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxMainContainer: some View {
        ZStack {
            if creatingGroup {
                pxGroupLinkList
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(NSLocalizedString("group_link_continue", comment: "Continue button")) { linkCreatedCb?() }
                        }
                    }
            } else {
                pxGroupLinkList
            }
            if creatingLink {
                ProgressView()
                    .scaleEffect(PXGroupLinkConfig.progressScale)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var pxGroupLinkList: some View {
        List {
            Group {
                pxTitleAndDescription
                pxLinkContentSection
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(PXGroupLinkConfig.emptyRowInsets)
        }
        .modifier(ThemedBackground(grouped: true))
        .sheet(isPresented: $showSharePicker) {
            if let gInfo = groupInfo {
                shareChannelPicker(groupInfo: gInfo, composeState: composeState)
            }
        }
    }

    @ViewBuilder
    private var pxTitleAndDescription: some View {
        if showTitle {
            Text(isChannel ? NSLocalizedString("group_channel_link", comment: "Channel link") : NSLocalizedString("group_group_link", comment: "Group link"))
                .font(isInDarkTheme() ? PXGroupLinkConfig.sectionHeaderFont : PXGroupLinkConfig.darkTitleFont)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                .bold()
                .fixedSize(horizontal: false, vertical: true)
        }
        Text(pxDescriptionText)
    }

    @ViewBuilder
    private var pxLinkContentSection: some View {
        Section {
            if let groupLink = groupLink {
                pxExistingLinkContent(groupLink: groupLink)
            } else {
                pxCreateLinkButton
            }
        } header: {
            pxShortLinkHeader
        }
        .alert(item: $alert) { alertItem in pxAlertForItem(alertItem) }
        .onChange(of: groupLinkMemberRole) { _, _ in pxHandleRoleChange() }
        .onAppear { pxHandleAppear() }
    }

    @ViewBuilder
    private func pxExistingLinkContent(groupLink: GroupLink) -> some View {
        if !isChannel {
            pxRolePickerForLink
        }
        PXLinkQRCode(link: groupLink.connLinkContact, short: $showShortLink)
            .id("\(PXGroupLinkConfig.qrCodePrefix)\(groupLink.connLinkContact.popopxChatUri(short: showShortLink))")
        if !isChannel && groupLink.shouldBeUpgraded {
            pxUpgradeButton(groupLink: groupLink)
        }
        pxShareButton(groupLink: groupLink)
        if let groupInfo = groupInfo, groupInfo.groupProfile.publicGroup != nil {
            pxShareViaChatButton
        }
        if !creatingGroup && !isChannel {
            pxDeleteLinkButton
        }
    }

    @ViewBuilder
    private var pxRolePickerForLink: some View {
        Picker(NSLocalizedString("group_initial_role_picker", comment: "Initial role picker label"), selection: $groupLinkMemberRole) {
            ForEach([GroupMemberRole.member, GroupMemberRole.observer]) { role in
                Text(role.text)
            }
        }
        .frame(height: PXGroupLinkConfig.rolePickerHeight)
    }

    @ViewBuilder
    private var pxCreateLinkButton: some View {
        Button(action: pxCreateGroupLink) {
            Label(NSLocalizedString("group_create_link_button", comment: "Create new group link button"), systemImage: PXGroupLinkConfig.createIcon)
        }
        .disabled(creatingLink)
        .accessibilityLabel(Text(NSLocalizedString("a11y_create_group_link", comment: "")))
    }

    @ViewBuilder
    private func pxUpgradeButton(groupLink: GroupLink) -> some View {
        Button {
            pxUpgradeAndShareAlert(groupLink: groupLink)
        } label: {
            Label(NSLocalizedString("group_upgrade_link", comment: "Upgrade group link button"), systemImage: PXGroupLinkConfig.upgradeIcon)
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_upgrade_group_link", comment: "")))
    }

    @ViewBuilder
    private func pxShareButton(groupLink: GroupLink) -> some View {
        Button {
            pxHandleShareTap(groupLink: groupLink)
        } label: {
            Label(NSLocalizedString("group_share_link_button", comment: "Share link button"), systemImage: PXGroupLinkConfig.shareIcon)
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_share_group_link", comment: "")))
    }

    @ViewBuilder
    private var pxShareViaChatButton: some View {
        Button { showSharePicker = true } label: {
            Label(NSLocalizedString("group_share_via_chat_button", comment: "Share link via chat button"), systemImage: PXGroupLinkConfig.forwardIcon)
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_share_link_via_chat", comment: "")))
    }

    @ViewBuilder
    private var pxDeleteLinkButton: some View {
        Button(role: .destructive) { alert = .deleteLink } label: {
            Label(NSLocalizedString("group_delete_link", comment: "Delete group link button"), systemImage: PXGroupLinkConfig.deleteIcon)
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_delete_group_link", comment: "")))
    }

    @ViewBuilder
    private var pxShortLinkHeader: some View {
        if !isChannel, let groupLink, groupLink.connLinkContact.connShortLink != nil {
            ToggleShortLinkHeader(text: Text(""), link: groupLink.connLinkContact, short: $showShortLink)
        }
    }

    // MARK: - POPOPX Helpers

    private var pxDescriptionText: String {
        if isChannel {
            return NSLocalizedString("group_share_link_desc_channel", comment: "Description for channel link sharing")
        }
        return NSLocalizedString("group_share_link_desc_group", comment: "Description for group link sharing")
    }

    private func pxAlertForItem(_ alertItem: GroupLinkAlert) -> Alert {
        switch alertItem {
        case .deleteLink:
            return Alert(
                title: Text(NSLocalizedString("group_delete_link_title", comment: "Delete link confirmation title")),
                message: Text(NSLocalizedString("group_delete_link_message", comment: "Delete link reassurance message")),
                primaryButton: .destructive(Text(NSLocalizedString("group_delete_link_action", comment: "Delete link action button"))) {
                    Task {
                        do {
                            try await apiDeleteGroupLink(groupId)
                            await MainActor.run { groupLink = nil }
                        } catch let error {
                            logger.error("PXGroupLinkEditor apiDeleteGroupLink: \(responseError(error))")
                        }
                    }
                }, secondaryButton: .cancel()
            )
        case let .error(title, error):
            return mkAlert(title: title, message: error)
        }
    }

    // MARK: - POPOPX Actions

    private func pxHandleShareTap(groupLink: GroupLink) {
        if !isChannel && groupLink.shouldBeUpgraded {
            pxUpgradeAndShareAlert(groupLink: groupLink)
        } else {
            groupLink.shareAddress(short: showShortLink)
        }
    }

    private func pxHandleRoleChange() {
        Task {
            do {
                groupLink = try await apiGroupLinkMemberRole(groupId, memberRole: groupLinkMemberRole)
            } catch {
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error updating group link", comment: "")))
                }
            }
        }
    }

    private func pxHandleAppear() {
        if groupLink == nil && !creatingLink && shouldCreate {
            pxCreateGroupLink()
        }
        shouldCreate = false
    }

    private func pxCreateGroupLink() {
        logger.info("POPOPX: createGroupLink started for groupId \(groupId)")
        logger.debug("PX: [PXGroupLinkEditor.createGroupLink] called")
        Task {
            do {
                creatingLink = true
                let gLink = try await apiCreateGroupLink(groupId)
                await MainActor.run {
                    creatingLink = false
                    groupLink = gLink
                }
            } catch let error {
                logger.error("PXGroupLinkEditor apiCreateGroupLink: \(responseError(error))")
                await MainActor.run {
                    creatingLink = false
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error creating group link", comment: "")))
                }
            }
        }
    }

    private func pxUpgradeAndShareAlert(groupLink: GroupLink? = nil) {
        logger.debug("PX: [PXGroupLinkEditor.upgradeAndShareLinkAlert] hasExistingLink=\(groupLink != nil)")
        showAlert(
            NSLocalizedString("Upgrade group link?", comment: "alert message"),
            message: NSLocalizedString("The link will be short, and group profile will be shared via the link.", comment: "alert message"),
            actions: {
                var actions = [UIAlertAction(title: NSLocalizedString("Upgrade", comment: "alert button"), style: .default) { _ in
                    pxAddShortLink(shareOnCompletion: groupLink != nil)
                }]
                if let groupLink {
                    actions.append(UIAlertAction(title: NSLocalizedString("Share old link", comment: "alert button"), style: .default) { _ in
                        groupLink.shareAddress(short: showShortLink)
                    })
                }
                actions.append(cancelAlertAction)
                return actions
            }
        )
    }

    private func pxAddShortLink(shareOnCompletion: Bool = false) {
        Task {
            do {
                creatingLink = true
                let gLink = try await apiAddGroupShortLink(groupId)
                await MainActor.run {
                    creatingLink = false
                    groupLink = gLink
                    if shareOnCompletion, let gLink {
                        gLink.shareAddress(short: showShortLink)
                    }
                }
            } catch let error {
                logger.error("apiAddGroupShortLink: \(responseError(error))")
                await MainActor.run {
                    creatingLink = false
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error adding short link", comment: "")))
                }
            }
        }
    }
}

// MARK: - POPOPX

extension PXGroupLinkEditor {
    var pxComponentTag: String { PXGroupLinkConfig.componentTag }
    var pxIsCreatingLink: Bool { creatingLink }
    var pxHasShortLink: Bool { groupLink?.connLinkContact.connShortLink != nil }
    var pxRolePickerHeight: CGFloat { PXGroupLinkConfig.rolePickerHeight }
    var pxProgressScale: CGFloat { PXGroupLinkConfig.progressScale }
}

struct PXGroupLinkEditor_Previews: PreviewProvider {
    static var previews: some View {
        @State var groupLink: GroupLink? = GroupLink(
            userContactLinkId: 1,
            connLinkContact: CreatedConnLink(connFullLink: "https://popopxchat.com/contact#/?v=1&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.popopxchat.com%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23MCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%3D", connShortLink: nil),
            shortLinkDataSet: false,
            shortLinkLargeDataSet: false,
            groupLinkId: "abc",
            acceptMemberRole: .member
        )
        @State var noGroupLink: GroupLink? = nil

        return Group {
            PXGroupLinkEditor(groupId: 1, groupLink: $groupLink, groupLinkMemberRole: Binding.constant(.member))
            PXGroupLinkEditor(groupId: 1, groupLink: $noGroupLink, groupLinkMemberRole: Binding.constant(.member))
        }
    }
}
