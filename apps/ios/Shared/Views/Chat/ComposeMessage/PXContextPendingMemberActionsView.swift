//
//  ContextPendingMemberActionsView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 02.05.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxPendingMemberFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")

// MARK: - POPOPX extracted constants & view model

private enum PXPendingMemberActionsConfig {
    static let actionsMinHeight: CGFloat = 56
    static let buttonSpacing: CGFloat = 2
    static let hStackSpacing: CGFloat = 0
    static let rejectColor: Color = .red
    static let acceptColor: Color = .blue
    static let componentTag: String = "px-ctx-pending-member"
    static let rejectIconName: String = "xmark.circle"
    static let acceptIconName: String = "checkmark.circle"
}

private struct PXPendingMemberActionsViewModel {
    let groupInfo: GroupInfo
    let member: GroupMember

    var memberDisplayName: String { member.displayName }
    var memberId: Int64 { member.groupMemberId }
    var isMemberRole: Bool { member.memberRole == .member }
    var canAcceptAsObserver: Bool { true }
}

struct ContextPendingMemberActionsView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss
    var groupInfo: GroupInfo
    var member: GroupMember
    @UserDefault(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial

    private var vm: PXPendingMemberActionsViewModel {
        PXPendingMemberActionsViewModel(groupInfo: groupInfo, member: member)
    }

    var body: some View {
        HStack(spacing: PXPendingMemberActionsConfig.hStackSpacing) {
            pxRejectButton
            pxAcceptButton
        }
        .frame(minHeight: PXPendingMemberActionsConfig.actionsMinHeight)
        .frame(maxWidth: .infinity)
        .background(ToolbarMaterial.material(toolbarMaterial))
        .compositingGroup()
        .popopxBranded()
    }

    // MARK: - POPOPX subviews

    private var pxRejectButton: some View {
        ZStack {
            Text(NSLocalizedString("pending_reject_button", comment: "Reject pending member button"))
                .foregroundColor(theme.colors.error)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { pxShowRejectAlert() }
        .accessibilityLabel(NSLocalizedString("Reject pending member", comment: "Accessibility"))
    }

    private var pxAcceptButton: some View {
        ZStack {
            Text(NSLocalizedString("pending_accept_button", comment: "Accept pending member button"))
                .foregroundColor(theme.colors.primary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { pxShowAcceptAlert() }
        .accessibilityLabel(NSLocalizedString("Accept pending member", comment: "Accessibility"))
    }

    // MARK: - POPOPX actions

    private func pxShowRejectAlert() {
        showRejectMemberAlert(groupInfo, member, dismiss: dismiss)
    }

    private func pxShowAcceptAlert() {
        showAcceptMemberAlert(groupInfo, member, dismiss: dismiss)
    }
}

func showRejectMemberAlert(_ groupInfo: GroupInfo, _ member: GroupMember, dismiss: DismissAction? = nil) {
    logger.debug("PX: [showRejectMemberAlert] memberId=\(member.groupMemberId)")
    showAlert(
        title: NSLocalizedString("Reject member?", comment: "alert title"),
        buttonTitle: NSLocalizedString("pending_reject_button", comment: "Reject pending member button"),
        buttonAction: { removeMember(groupInfo, member, withMessages: false,  dismiss: dismiss) },
        cancelButton: true
    )
}

func showAcceptMemberAlert(_ groupInfo: GroupInfo, _ member: GroupMember, dismiss: DismissAction? = nil) {
    logger.debug("PX: [showAcceptMemberAlert] memberId=\(member.groupMemberId)")
    showAlert(
        NSLocalizedString("Accept member", comment: "alert title"),
        message: NSLocalizedString("Member will join the group, accept member?", comment: "alert message"),
        actions: {[
            UIAlertAction(
                title: NSLocalizedString("Accept as member", comment: "alert action"),
                style: .default,
                handler: { _ in
                    acceptMember(groupInfo, member, .member, dismiss: dismiss)
                }
            ),
            UIAlertAction(
                title: NSLocalizedString("Accept as observer", comment: "alert action"),
                style: .default,
                handler: { _ in
                    acceptMember(groupInfo, member, .observer, dismiss: dismiss)
                }
            ),
            cancelAlertAction
        ]}
    )
}

func acceptMember(_ groupInfo: GroupInfo, _ member: GroupMember, _ role: GroupMemberRole, dismiss: DismissAction? = nil) {
    logger.debug("PX: [acceptMember] memberId=\(member.groupMemberId), role=\(role.rawValue)")
    Task {
        do {
            let (gInfo, acceptedMember) = try await apiAcceptMember(groupInfo.groupId, member.groupMemberId, role)
            await MainActor.run {
                _ = ChatModel.shared.upsertGroupMember(gInfo, acceptedMember)
                ChatModel.shared.updateGroup(gInfo)
                dismiss?()
            }
        } catch let error {
            logger.error("apiAcceptMember error: \(responseError(error))")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error accepting member", comment: "alert title"),
                    message: responseError(error)
                )
            }
        }
    }
}

#Preview {
    ContextPendingMemberActionsView(
        groupInfo: GroupInfo.sampleData,
        member: GroupMember.sampleData
    )
}

// MARK: - POPOPX
extension ContextPendingMemberActionsView {
    var pxComponentTag: String { PXPendingMemberActionsConfig.componentTag }
    var pxMemberId: Int64 { member.groupMemberId }
    var pxMemberRole: GroupMemberRole { member.memberRole }
}
