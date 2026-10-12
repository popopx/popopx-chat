//
//  PXAddChannelView.swift
//  POPOPX (iOS)
//
//  Channel creation flow: profile, relay progress, and link steps.
//  Created by spaced4ndy on 23.02.2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - Layout & timing metrics

/// All magic numbers for the channel-creator view are centralised here.
private enum PXChannelCreatorMetrics {
    static let profileImageSize: CGFloat = 130
    static let progressShadowOpacity: Double = 0.12
    static let progressShadowRadius: CGFloat = 5
    static let progressShadowY: CGFloat = 4
    static let maxImageDataSize: Int64 = 12500
    static let listRowTopInset: CGFloat = 12
    static let listRowBottomInset: CGFloat = 4
    static let textFieldLeadingPad: CGFloat = 40
    static let progressRingLineWidth: CGFloat = 3.0
    static let statusDotSize: CGFloat = 10
    static let relayRowSpacing: CGFloat = 6
    static let headerVerticalGap: CGFloat = 14
}

// MARK: - Feature flags

/// POPOPX feature toggles read from UserDefaults.
private let pxChannelFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_CHANNEL_FEATURE_ENABLED")
private let pxRelayCreationAnimEnabled = UserDefaults.standard.bool(forKey: "PX_RELAY_CREATION_ANIM_ENABLED")

// MARK: - Main view

struct PXChannelCreator: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var subscription: SubscriptionManager
    @ObservedObject private var channelRelaysModel = ChannelRelaysModel.shared
    @StateObject private var ss = SaveableSettings()
    @State private var profile = GroupProfile(displayName: "", fullName: "")
    @FocusState private var focusDisplayName: Bool
    @State private var showChooseSource = false
    @State private var showImagePicker = false
    @State private var showTakePhoto = false
    @State private var chosenImage: UIImage? = nil
    @State private var hasRelays = true
    @State private var groupInfo: GroupInfo? = nil
    @State private var groupLink: GroupLink? = nil
    @State private var groupRelays: [GroupRelay] = []
    @State private var creationInProgress = false
    @State private var showLinkStep = false
    @State private var relayListExpanded = false

    var body: some View {
        Group {
            if showLinkStep, let pxGInfo = groupInfo {
                pxLinkStepView(pxGInfo)
            } else if let pxGInfo = groupInfo {
                pxProgressStepView(pxGInfo)
            } else {
                pxProfileStepView()
            }
        }
        .popopxBranded()
    }

    // MARK: - Step 1: Profile

    /// Renders the initial profile-entry form with image picker and relay configuration.
    private func pxProfileStepView() -> some View {
        List {
            Group {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .center) {
                        ZStack(alignment: .topTrailing) {
                            ProfileImage(imageStr: profile.image, iconName: "antenna.radiowaves.left.and.right.circle.fill", size: 128)
                            if profile.image != nil {
                                Button {
                                    profile.image = nil
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
                    #if POPOPX_ASSETS
                    Spacer(minLength: 0)
                    Image(colorScheme == .light ? "create-channel" : "create-channel-light")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                    #endif
                    Spacer(minLength: 0)
                }
            }
            .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: PXChannelCreatorMetrics.listRowTopInset, leading: 0, bottom: 0, trailing: 0))

            Section {
                pxChannelNameField()
                if subscription.purchasedTier == .premium {
                    NavigationLink {
                        NetworkAndServers()
                            .navigationTitle(NSLocalizedString("network_servers_nav_title", comment: "Network & servers navigation title"))
                            .modifier(ThemedBackground(grouped: true))
                            .environmentObject(ss)
                    } label: {
                        let pxRelayColor: Color = hasRelays ? .accentColor : QuantumColors.warning
                        settingsRow("externaldrive.connected.to.line.below", color: pxRelayColor) {
                            Text(NSLocalizedString("channel_configure_relays", comment: "Configure relays button")).foregroundColor(pxRelayColor)
                        }
                    }
                }
                let pxCanCreate = pxValidateProfile() && hasRelays && !creationInProgress
                Button(action: pxCreateChannel) {
                    settingsRow("checkmark", color: pxCanCreate ? theme.colors.primary : theme.colors.secondary) { Text(NSLocalizedString("channel_create_button", comment: "Create public channel button")) }
                }
                .disabled(!pxCanCreate)
            } footer: {
                pxFooterContent()
            }
            .compactSectionSpacing()
        }
        .onAppear {
            Task { hasRelays = await pxCheckRelaysAvailable() }
            DispatchQueue.main.asyncAfter(deadline: .now() + PXChannelCreator.pxFocusDelay) {
                focusDisplayName = true
            }
        }
        .confirmationDialog(NSLocalizedString("Channel image", comment: "confirmation dialog title"), isPresented: $showChooseSource, titleVisibility: .visible) {
            Button(NSLocalizedString("Take picture", comment: "")) { showTakePhoto = true }
            Button(NSLocalizedString("Choose from library", comment: "")) { showImagePicker = true }
        }
        .fullScreenCover(isPresented: $showTakePhoto) {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                CameraImagePicker(image: $chosenImage)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            LibraryImagePicker(image: $chosenImage) { _ in
                await MainActor.run { showImagePicker = false }
            }
        }
        .onChange(of: chosenImage) {_,  pxImage in
            Task {
                let pxResized: String? = if let pxImage {
                    await resizeImageToStrSize(cropToSquare(pxImage), maxDataSize: PXChannelCreatorMetrics.maxImageDataSize)
                } else {
                    nil
                }
                await MainActor.run { profile.image = pxResized }
            }
        }
        .modifier(ThemedBackground(grouped: true))
    }

    // MARK: - Profile sub-views

    /// Text field for the channel display name with validation icon.
    private func pxChannelNameField() -> some View {
        ZStack(alignment: .leading) {
            let pxTrimmedName = profile.displayName.trimmingCharacters(in: .whitespaces)
            if pxTrimmedName != mkValidName(pxTrimmedName) {
                Button {
                    pxShowInvalidNameAlert()
                } label: {
                    Image(systemName: "exclamationmark.circle").foregroundColor(theme.colors.error)
                }
            } else {
                Image(systemName: "pencil").foregroundColor(theme.colors.secondary)
            }
            TextField(NSLocalizedString("Enter channel name…", comment: ""), text: $profile.displayName)
                .padding(.leading, PXChannelCreatorMetrics.textFieldLeadingPad)
                .focused($focusDisplayName)
                .submitLabel(.continue)
                .onSubmit {
                    if pxValidateProfile() && hasRelays { pxCreateChannel() }
                }
        }
    }

    /// Section footer: relay warning or profile-sharing notice.
    private func pxFooterContent() -> some View {
        Group {
            if !hasRelays {
                ServersWarningView(warnStr: NSLocalizedString("Enable at least one chat relay in Network & Servers.", comment: "channel creation warning"))
            } else {
                let pxDisplayName = ChatModel.shared.currentUser?.displayName ?? ""
                Text(String(format: NSLocalizedString("Your profile **%@** will be shared with channel relays and subscribers.\nRelays can access channel messages.", comment: "channel creation footer"), pxDisplayName))
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    /// Validates that the profile display name is non-empty and well-formed.
    private func pxValidateProfile() -> Bool {
        let pxTrimmed = profile.displayName.trimmingCharacters(in: .whitespaces)
        return pxTrimmed != "" && validDisplayName(pxTrimmed)
    }

    // MARK: - Channel creation

    /// Initiates channel creation with randomly selected relays.
    private func pxCreateChannel() {
        focusDisplayName = false
        profile.displayName = profile.displayName.trimmingCharacters(in: .whitespaces)
        profile.groupPreferences = GroupPreferences(
            history: GroupPreference(enable: .on),
            support: GroupPreference(enable: .off)
        )
        creationInProgress = true
        Task {
            do {
                let pxSelectedRelays = try await pxChooseRandomRelays()
                let pxRelayIds = pxSelectedRelays.compactMap { $0.chatRelayId }
                guard !pxRelayIds.isEmpty else {
                    await MainActor.run {
                        creationInProgress = false
                        hasRelays = false
                    }
                    return
                }
                guard let pxResult = try await apiNewPublicGroup(
                    incognito: false, relayIds: pxRelayIds, groupProfile: profile
                ) else {
                    await MainActor.run { creationInProgress = false }
                    return
                }
                switch pxResult {
                case let .created(pxGInfo, pxGLink, pxGRelays):
                    await MainActor.run {
                        m.updateGroup(pxGInfo)
                        m.creatingChannelId = pxGInfo.id
                        groupInfo = pxGInfo
                        groupLink = pxGLink
                        groupRelays = pxGRelays.sorted { relayDisplayName($0) < relayDisplayName($1) }
                        channelRelaysModel.set(groupId: pxGInfo.groupId, groupRelays: pxGRelays)
                        creationInProgress = false
                    }
                case let .creationFailed(pxRelayResults):
                    await MainActor.run {
                        creationInProgress = false
                        showAlert(
                            NSLocalizedString("Error creating channel", comment: "alert title"),
                            message: NSLocalizedString("Relay results:", comment: "alert message") + "\n" +
                                pxRelayResults.map { "\(chatRelayDisplayName($0.relay)): \($0.relayError.map { connErrorText($0) } ?? NSLocalizedString("ok", comment: "relay status"))" }.joined(separator: "\n")
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    creationInProgress = false
                    showAlert(
                        NSLocalizedString("Error creating channel", comment: "alert title"),
                        message: responseError(error)
                    )
                }
            }
        }
    }

    private let maxRelays = 3

    /// Selects relays using round-robin across operator groups, preferring custom relays first.
    private func pxChooseRandomRelays() async throws -> [UserChatRelay] {
        let pxServers = try await getUserServers()
        // Operator relays are grouped per operator; custom relays (nil operator)
        // are treated independently to maximize trust distribution.
        var pxOpGroups: [[UserChatRelay]] = []
        var pxCustomRelays: [UserChatRelay] = []
        for pxOp in pxServers {
            guard pxOp.operator?.enabled ?? true else { continue }
            let pxRelays = pxOp.chatRelays.filter { $0.enabled && !$0.deleted && $0.chatRelayId != nil }
            guard !pxRelays.isEmpty else { continue }
            if pxOp.operator != nil {
                pxOpGroups.append(pxRelays.shuffled())
            } else {
                pxCustomRelays = pxRelays.shuffled()
            }
        }
        var pxSelected: [UserChatRelay] = []
        // Prefer at least one custom relay when available for trust distribution
        if let pxRelay = pxCustomRelays.first {
            pxSelected.append(pxRelay)
            pxCustomRelays.removeFirst()
            if pxSelected.count >= maxRelays { return pxSelected }
        }
        // Round-robin across shuffled groups
        var pxGroups = pxOpGroups + pxCustomRelays.map { [$0] }
        pxGroups.shuffle()
        let pxMaxDepth = pxGroups.map(\.count).max() ?? 0
        for pxDepth in 0..<pxMaxDepth {
            for pxGroup in pxGroups {
                if pxDepth < pxGroup.count {
                    pxSelected.append(pxGroup[pxDepth])
                    if pxSelected.count >= maxRelays { return pxSelected }
                }
            }
        }
        return pxSelected
    }

    /// Checks whether any enabled relay servers are available.
    private func pxCheckRelaysAvailable() async -> Bool {
        guard let pxServers = try? await getUserServers() else {
            return false
        }
        return pxServers.contains { pxOp in
            (pxOp.operator?.enabled ?? true) &&
            pxOp.chatRelays.contains { $0.enabled && !$0.deleted && $0.chatRelayId != nil }
        }
    }

    // MARK: - Step 2: Progress

    /// Shows relay connection progress with expandable detail list.
    private func pxProgressStepView(_ pxGInfo: GroupInfo) -> some View {
        let pxFailCount = groupRelays.filter { pxRelayConnFailed($0) != nil }.count
        let pxActiveCount = groupRelays.filter { $0.relayStatus == .active && pxRelayConnFailed($0) == nil }.count
        let pxTotalCount = groupRelays.count
        return List {
            Group {
                let pxProgressImageSize: CGFloat = PXChannelCreatorMetrics.profileImageSize
                ProfileImage(imageStr: pxGInfo.groupProfile.image, iconName: "antenna.radiowaves.left.and.right.circle.fill", size: pxProgressImageSize)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .shadow(color: Color.black.opacity(PXChannelCreatorMetrics.progressShadowOpacity), radius: PXChannelCreatorMetrics.progressShadowRadius, x: 0, y: PXChannelCreatorMetrics.progressShadowY)

                Text(pxGInfo.groupProfile.displayName)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: PXChannelCreatorMetrics.listRowTopInset, leading: 0, bottom: PXChannelCreatorMetrics.listRowBottomInset, trailing: 0))

            Section {
                Button {
                    let pxDur = PXChannelCreator.pxRelayToggleAnimDuration
                    withAnimation(.easeInOut(duration: pxDur)) { relayListExpanded.toggle() }
                } label: {
                    HStack(spacing: PXChannelCreatorMetrics.relayRowSpacing) {
                        if pxActiveCount + pxFailCount < pxTotalCount {
                            RelayProgressIndicator(active: pxActiveCount, total: pxTotalCount)
                        }
                        if pxFailCount > 0 {
                            Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays active, %d failed", comment: "channel creation progress with errors"), pxActiveCount, pxTotalCount, pxFailCount))
                        } else {
                            Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays active", comment: "channel creation progress"), pxActiveCount, pxTotalCount))
                        }
                        Spacer()
                        Image(systemName: relayListExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(theme.colors.secondary)
                    }
                }
                .foregroundColor(theme.colors.onBackground)

                if relayListExpanded {
                    ForEach(groupRelays) { pxRelay in
                        let pxErr = pxRelayConnFailed(pxRelay)
                        if let pxErr {
                            Button {
                                showAlert(
                                    NSLocalizedString("Relay connection failed", comment: "alert title"),
                                    message: pxErr
                                )
                            } label: {
                                pxRelayRowView(pxRelay, connFailed: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            pxRelayRowView(pxRelay, connFailed: false)
                        }
                    }
                }
            }
            .compactSectionSpacing()

            Section {
                Button(NSLocalizedString("cancel_delete_channel_button", comment: "Cancel and delete channel button"), role: .destructive) {
                    pxShowCancelAlert(pxGInfo)
                }
                Button(NSLocalizedString("continue_button", comment: "Continue button")) {
                    pxHandleContinueButton(pxActiveCount, pxFailCount, pxTotalCount)
                }
                .disabled(pxActiveCount == 0)
            }
        }
        .navigationTitle(NSLocalizedString("creating_channel_nav_title", comment: "Creating channel navigation title"))
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            if !showLinkStep && m.creatingChannelId == pxGInfo.id {
                pxShowCancelAlert(pxGInfo)
            }
        }
        .onChange(of: channelRelaysModel.groupRelays) {_,  pxRelays in
            guard channelRelaysModel.groupId == pxGInfo.groupId else { return }
            groupRelays = pxRelays.sorted { relayDisplayName($0) < relayDisplayName($1) }
            if pxRelays.allSatisfy({ $0.relayStatus == .active && pxRelayConnFailed($0) == nil }) {
                showLinkStep = true
                channelRelaysModel.reset()
            }
        }
    }

    /// Returns the connection failure message for a relay, or nil if connected.
    private func pxRelayConnFailed(_ pxRelay: GroupRelay) -> String? {
        m.groupMembers.first(where: { $0.wrapped.groupMemberId == pxRelay.groupMemberId })?
            .wrapped.activeConn?.connFailedErr
    }

    /// Renders a single relay row with name and status indicator.
    private func pxRelayRowView(_ pxRelay: GroupRelay, connFailed pxFailed: Bool) -> some View {
        HStack {
            Text(relayDisplayName(pxRelay))
            Spacer()
            relayStatusIndicator(pxRelay.relayStatus, connFailed: pxFailed)
        }
    }

    /// Handles the Continue button logic during relay progress.
    private func pxHandleContinueButton(_ pxActive: Int, _ pxFail: Int, _ pxTotal: Int) {
        if pxActive >= pxTotal {
            showLinkStep = true
        } else if pxActive > 0 {
            let pxActions: [UIAlertAction] = if pxActive + pxFail < pxTotal {
                [
                    UIAlertAction(title: NSLocalizedString("Continue", comment: "alert action"), style: .default) { _ in showLinkStep = true },
                    UIAlertAction(title: NSLocalizedString("Wait", comment: "alert action"), style: .cancel) { _ in }
                ]
            } else {
                [
                    UIAlertAction(title: NSLocalizedString("Continue", comment: "alert action"), style: .default) { _ in showLinkStep = true },
                    cancelAlertAction
                ]
            }
            showAlert(
                NSLocalizedString("Not all relays connected", comment: "alert title"),
                message: String.localizedStringWithFormat(NSLocalizedString("Channel will start working with %d of %d relays. Continue?", comment: "alert message"), pxActive, pxTotal),
                actions: { pxActions }
            )
        }
    }

    // MARK: - Step 3: Link

    /// Final step: configure the channel's public link.
    private func pxLinkStepView(_ pxGInfo: GroupInfo) -> some View {
        PXGroupLinkEditor(
            groupId: pxGInfo.groupId,
            groupLink: $groupLink,
            groupLinkMemberRole: Binding.constant(.observer), // TODO [relays] starting role should be communicated in protocol from owner to relays
            showTitle: false,
            creatingGroup: true,
            isChannel: true,
            groupInfo: pxGInfo
        ) {
            m.creatingChannelId = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + PXChannelCreator.pxNavigationDelay) {
                dismissAllSheets(animated: true) {
                    ItemsModel.shared.loadOpenChat(pxGInfo.id)
                }
            }
        }
        .navigationTitle(NSLocalizedString("channel_link_nav_title", comment: "Channel link navigation title"))
    }

    // MARK: - Cancellation

    /// Deletes the in-progress channel and cleans up state.
    private func pxCancelCreation(_ pxGInfo: GroupInfo) {
        m.creatingChannelId = nil
        channelRelaysModel.reset()
        dismissAllSheets(animated: true)
        Task {
            do {
                try await apiDeleteChat(type: .group, id: pxGInfo.apiId)
                await MainActor.run { m.removeChat(pxGInfo.id) }
            } catch {
                logger.error("cancelChannelCreation error: \(responseError(error))")
            }
        }
    }

    /// Presents a confirmation alert before cancelling channel creation.
    private func pxShowCancelAlert(_ pxGInfo: GroupInfo) {
        let pxActiveCount = groupRelays.filter { $0.relayStatus == .active && pxRelayConnFailed($0) == nil }.count
        let pxTotalCount = groupRelays.count
        showAlert(
            NSLocalizedString("Cancel creating channel?", comment: "alert title"),
            message: String.localizedStringWithFormat(
                NSLocalizedString("Your new channel %@ is connected to %d of %d relays.\nIf you cancel, the channel will be deleted - you can create it again.", comment: "alert message"),
                pxGInfo.groupProfile.displayName, pxActiveCount, pxTotalCount
            ),
            actions: {[
                UIAlertAction(title: NSLocalizedString("Wait", comment: "alert action"), style: .cancel) { _ in },
                UIAlertAction(title: NSLocalizedString("Cancel", comment: "alert action"), style: .destructive) { _ in
                    pxCancelCreation(pxGInfo)
                }
            ]}
        )
    }

    // MARK: - Validation alert

    /// Shows an alert with an invalid-name warning and optional correction.
    private func pxShowInvalidNameAlert() {
        let pxValidName = mkValidName(profile.displayName)
        if pxValidName == "" {
            showAlert(NSLocalizedString("Invalid name!", comment: "alert title"))
        } else {
            showAlert(
                NSLocalizedString("Invalid name!", comment: "alert title"),
                message: String.localizedStringWithFormat(NSLocalizedString("Correct name to %@?", comment: "alert message"), pxValidName),
                actions: {[
                    UIAlertAction(title: NSLocalizedString("Ok", comment: "alert action"), style: .default) { _ in
                        profile.displayName = pxValidName
                    },
                    cancelAlertAction
                ]}
            )
        }
    }

}

// MARK: - Free functions

/// Resolve a human-readable display name for a group relay.
func relayDisplayName(_ relay: GroupRelay) -> String {
    if !relay.userChatRelay.displayName.isEmpty { return relay.userChatRelay.displayName }
    if let pxDomain = relay.userChatRelay.domains.first { return pxDomain }
    if let pxLink = relay.relayLink { return hostFromRelayLink(pxLink) }
    return String(format: NSLocalizedString("relay %@", comment: "fallback relay name"), relay.groupRelayId)
}

/// Resolve display name for a user-owned chat relay.
func chatRelayDisplayName(_ relay: UserChatRelay) -> String {
    if !relay.displayName.isEmpty { return relay.displayName }
    return relay.address
}

/// Renders a colored status dot + label for a relay's current connection state.
func relayStatusIndicator(_ status: RelayStatus, connFailed: Bool = false, memberStatus: GroupMemberStatus? = nil) -> some View {
    let pxIsRemoved = memberStatus.map { [.memLeft, .memRemoved, .memGroupDeleted].contains($0) } ?? false
    let pxIsRejected = status == .rejected
    let pxIndicatorColor: Color = connFailed || pxIsRemoved || pxIsRejected ? QuantumColors.error : (status == .active ? QuantumColors.success : QuantumColors.warning)
    let pxStatusText: LocalizedStringKey =
        connFailed ? "failed"
        : pxIsRejected ? "rejected"
        : memberStatus == .memLeft ? "removed by operator"
        : pxIsRemoved ? "removed"
        : status.text
    return HStack(spacing: PXChannelCreatorMetrics.relayRowSpacing) {
        Circle()
            .fill(pxIndicatorColor)
            .frame(width: PXChannelCreatorMetrics.statusDotSize, height: PXChannelCreatorMetrics.statusDotSize)
        Text(pxStatusText)
            .font(.caption)
            .foregroundStyle(.secondary)
        if connFailed {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.accentColor)
                .font(.caption)
        }
    }
}

/// Circular progress ring showing active vs total relay connections.
struct RelayProgressIndicator: View {
    var active: Int
    var total: Int

    var body: some View {
        if active == 0 {
            ProgressView()
                .frame(width: PXChannelCreatorMetrics.statusDotSize * 2.2, height: PXChannelCreatorMetrics.statusDotSize * 2.2)
        } else {
            ZStack {
                Circle()
                    .stroke(Color(uiColor: .tertiaryLabel), style: StrokeStyle(lineWidth: PXChannelCreatorMetrics.progressRingLineWidth))
                Circle()
                    .trim(from: 0, to: Double(active) / Double(max(total, 1)))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: PXChannelCreatorMetrics.progressRingLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: PXChannelCreatorMetrics.statusDotSize * 2.2, height: PXChannelCreatorMetrics.statusDotSize * 2.2)
        }
    }
}

#Preview {
    PXChannelCreator()
}

// MARK: - POPOPX

/// Namespace for POPOPX-specific channel creator constants.
extension PXChannelCreator {
    static let pxComponentTag: String = "PXPXChannelCreator"
    static var pxNavigationDelay: Double = 0.58
    static var pxFocusDelay: Double = 1.2
    static let pxMaxRelays: Int = 3
    static let pxProfileImageSize: CGFloat = 130
    static let pxHeaderPaddingH: CGFloat = 14
    static let pxSectionSpacingV: CGFloat = 8
    static var pxRelayToggleAnimDuration: Double = 0.3
    static let pxProgressImageShadowRadius: CGFloat = 4
    static let pxSectionFooterPadding: CGFloat = 12
}
