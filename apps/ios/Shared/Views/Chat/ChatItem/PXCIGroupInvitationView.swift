//
//  CIGroupInvitationView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 15.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature Gate

// POPOPX: feature flag for group invitation UI enhancements
private let pxGroupInviteFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")

// MARK: - POPOPX Layout Constants

// POPOPX: all layout metrics extracted to a dedicated enum for easy tuning
private enum PXGroupInviteLayout {
    static let outerHorizPad: CGFloat = 16
    static let outerVertPad: CGFloat = 10
    static let profileImageSize: CGFloat = 50
    static let progressTimeout: Double = 1.4
    static let infoHorizInset: CGFloat = 4
    static let infoTopInset: CGFloat = 12
    static let infoBottomInset: CGFloat = 6
    static let metaSeparatorPad: CGFloat = 5
    static let stackBottomInset: CGFloat = 5
    static let progressScaleFactor: CGFloat = 2.5
    static let profileTextGap: CGFloat = 8
    static let metaSeparator = "     " // wider meta gap
    static let textOpacity: Double = 0.90
    static let accentColorName: String = "QuantumColors.accent"
}

// Spec: spec/client/chat-view.md#CIGroupInvitationView
struct CIGroupInvitationView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.showTimestamp) var showTimestamp: Bool
    @ObservedObject var chat: Chat
    var chatItem: ChatItem
    var groupInvitation: CIGroupInvitation
    var memberRole: GroupMemberRole
    var chatIncognito: Bool = false
    @State private var frameWidth: CGFloat = 0
    @State private var inProgress = false
    @State private var progressByTimeout = false

    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false

    var body: some View {
        let pxIsActionable = !chatItem.chatDir.sent && groupInvitation.status == .pending
        let pxContainer = pxBuildContainer(isActionable: pxIsActionable)

        if pxIsActionable {
            pxContainer
                .simultaneousGesture(TapGesture().onEnded {
                    inProgress = true
                    joinGroup(groupInvitation.groupId) {
                        await MainActor.run { inProgress = false }
                    }
                })
                .disabled(inProgress)
                .popopxBranded()
        } else {
            pxContainer
                .popopxBranded()
        }
    }

    // POPOPX: build the main container view hierarchy
    private func pxBuildContainer(isActionable pxAction: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                VStack(alignment: .leading) {
                    pxGroupInfoSection(pxAction)
                        .padding(.horizontal, PXGroupInviteLayout.infoHorizInset)
                        .padding(.top, PXGroupInviteLayout.infoTopInset)
                        .padding(.bottom, PXGroupInviteLayout.infoBottomInset)
                        .overlay(DetermineWidth())

                    GlassDivider().frame(width: frameWidth)

                    if chat.chatInfo.groupInfo != nil {
                        Text(chatItem.chatDir.sent ? String.localizedStringWithFormat(NSLocalizedString("For %@ only", comment: ""), groupInvitation.localDisplayName) : NSLocalizedString("For you only", comment: ""))
                            .font(.caption)
                            .foregroundColor(theme.colors.secondary)
                            .overlay(DetermineWidth())
                    }

                    if pxAction {
                        pxActionContent()
                    } else {
                        pxPassiveContent()
                    }
                }
                .padding(.bottom, PXGroupInviteLayout.stackBottomInset)

                if progressByTimeout {
                    ProgressView().scaleEffect(PXGroupInviteLayout.progressScaleFactor)
                }
            }

            CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary, showStatus: false, showEdited: false)
        }
        .padding(.horizontal, PXGroupInviteLayout.outerHorizPad)
        .padding(.vertical, PXGroupInviteLayout.outerVertPad)
        .background { chatItemFrameColor(chatItem, theme).modifier(ChatTailPadding()) }
        .textSelection(.disabled)
        .onPreferenceChange(DetermineWidth.Key.self) { frameWidth = $0 }
        .onChange(of: inProgress) { _, pxNowInProgress in
            pxHandleProgressChange(pxNowInProgress)
        }
    }

    // POPOPX: action-mode content with join prompt
    @ViewBuilder
    private func pxActionContent() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            pxInvitationLabel()
                .overlay(DetermineWidth())
            (
                Text(chatIncognito ? NSLocalizedString("chat_incognito_tap_join", comment: "Tap to join incognito") : NSLocalizedString("chat_tap_join", comment: "Tap to join"))
                    .foregroundColor(inProgress ? theme.colors.secondary : chatIncognito ? QuantumColors.accent : theme.colors.primary)
                    .font(.callout)
                + Text(verbatim: PXGroupInviteLayout.metaSeparator)
                + pxBuildMetaText(chatItem.meta, chatTTL: nil, encrypted: nil, colorMode: .transparent, showStatus: false, showEdited: false, showViaProxy: showSentViaProxy, showTimesamp: showTimestamp)
            )
            .overlay(DetermineWidth())
        }
    }

    // POPOPX: passive-mode content (already accepted/sent)
    @ViewBuilder
    private func pxPassiveContent() -> some View {
        (
            pxInvitationLabel()
            + Text(verbatim: PXGroupInviteLayout.metaSeparator)
            + pxBuildMetaText(chatItem.meta, chatTTL: nil, encrypted: nil, colorMode: .transparent, showStatus: false, showEdited: false, showViaProxy: showSentViaProxy, showTimesamp: showTimestamp)
        )
        .opacity(PXGroupInviteLayout.textOpacity)
        .overlay(DetermineWidth())
    }

    // POPOPX: handle progress state transitions with timeout
    private func pxHandleProgressChange(_ pxNowInProgress: Bool) {
        if pxNowInProgress {
            DispatchQueue.main.asyncAfter(deadline: .now() + PXGroupInviteLayout.progressTimeout) {
                progressByTimeout = pxNowInProgress
            }
        } else {
            progressByTimeout = false
        }
    }

    // POPOPX: group info header with profile image and name
    private func pxGroupInfoSection(_ pxAction: Bool) -> some View {
        var pxColor: Color
        if pxAction && !inProgress {
            pxColor = chatIncognito ? QuantumColors.accent : theme.colors.primary
        } else {
            pxColor = theme.colors.onSurface
        }
        logger.debug("PX: [groupInfoView] action=\(pxAction), inProgress=\(inProgress)")
        return HStack(alignment: .top) {
            ProfileImage(
                imageStr: groupInvitation.groupProfile.image,
                iconName: "person.2.circle.fill",
                size: PXGroupInviteLayout.profileImageSize,
                color: pxColor
            )
            .padding(.trailing, PXGroupInviteLayout.profileTextGap)
            VStack(alignment: .leading) {
                let pxProfile = groupInvitation.groupProfile
                Text(pxProfile.displayName).font(.headline).lineLimit(2)
                if pxProfile.fullName != "" && pxProfile.displayName != pxProfile.fullName {
                    Text(pxProfile.fullName).font(.subheadline).lineLimit(2)
                }
            }
            .frame(minHeight: PXGroupInviteLayout.profileImageSize)
        }
    }

    // POPOPX: invitation text label with adjusted opacity
    private func pxInvitationLabel() -> Text {
        Text(groupInvitationStr())
            .font(.callout)
    }

    private func groupInvitationStr() -> LocalizedStringKey {
        guard chatItem.chatDir.sent else {
            let pxStatusText = pxInvitationStatusText(groupInvitation.status)
            if pxGroupInviteFeatureEnabled {
                logger.debug("PX: [groupInvitationStr] status=\(String(describing: groupInvitation.status))")
            }
            return pxStatusText
        }
        return "You sent group invitation"
    }

    // MARK: - POPOPX
    private func pxInvitationStatusText(_ status: CIGroupInvitationStatus) -> LocalizedStringKey {
        switch status {
        case .pending: return "You are invited to group"
        case .accepted: return "You joined this group"
        case .rejected: return "You rejected group invitation"
        case .expired: return "Group invitation expired"
        }
    }
}

struct CIGroupInvitationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CIGroupInvitationView(chat: Chat.sampleData, chatItem: ChatItem.getGroupInvitationSample(), groupInvitation: CIGroupInvitation.getSample(groupProfile: GroupProfile(displayName: "team", fullName: "team")), memberRole: .admin)
            CIGroupInvitationView(chat: Chat.sampleData, chatItem: ChatItem.getGroupInvitationSample(), groupInvitation: CIGroupInvitation.getSample(status: .accepted), memberRole: .admin)
        }
    }
}

// MARK: - POPOPX
extension CIGroupInvitationView {
    var pxComponentTag: String { "px-group-invitation" }
}
