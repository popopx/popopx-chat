//
//  PXContactRequestActions.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 02.05.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Config
private enum PXContactRequestConfig {
    static let actionButtonHeight: CGFloat = 62
    static let progressTimeoutNanos: UInt64 = 1_000_000_000
    static let dimmedOpacity: Double = 0.4
    static let rejectIcon: String = "multiply"
    static let acceptIcon: String = "checkmark"
    static let rejectAlertTitle = NSLocalizedString("Reject contact request", comment: "alert title")
    static let rejectAlertMessage = NSLocalizedString("The sender will NOT be notified", comment: "alert message")
    static let acceptAlertTitle = NSLocalizedString("Accept contact request", comment: "alert title")
    static let rejectButtonLabel = NSLocalizedString("reject_button", comment: "Reject button label")
    static let acceptButtonLabel = NSLocalizedString("accept_button", comment: "Accept button label")
}

// MARK: - POPOPX View Model
private struct PXContactRequestViewModel {
    let contactRequestId: Int64
    let hasShortLinkData: Bool
    let isInProgress: Bool
    let isTimedOut: Bool

    var pxAcceptLabel: String { PXContactRequestConfig.acceptButtonLabel }
    var pxRejectLabel: String { PXContactRequestConfig.rejectButtonLabel }
    var pxShouldDim: Bool { isTimedOut }
    var pxShouldShowSpinner: Bool { isTimedOut }
}

struct PXContactRequestActions: View {
    @EnvironmentObject var theme: AppTheme
    var contactRequestId: Int64
    @UserDefault(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    @State private var inProgress = false
    @State private var progressByTimeout = false

    var body: some View {
        pxActionsContainer
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxActionsContainer: some View {
        pxButtonRow
            .disabled(inProgress)
            .frame(maxWidth: .infinity)
            .background(ToolbarMaterial.material(toolbarMaterial))
            .opacity(pxCurrentOpacity)
            .overlay { pxProgressOverlay }
            .onChange(of: inProgress) { _, inPrgrs in pxHandleProgressChange(inPrgrs) }
    }

    @ViewBuilder
    private var pxButtonRow: some View {
        HStack(spacing: 0) {
            Button(role: .destructive, action: pxShowRejectAlert) {
                Label(PXContactRequestConfig.rejectButtonLabel, systemImage: PXContactRequestConfig.rejectIcon)
            }
            .frame(maxWidth: .infinity, minHeight: PXContactRequestConfig.actionButtonHeight)
            .accessibilityLabel(Text(NSLocalizedString("a11y_reject_contact_request", comment: "")))

            Button(action: pxHandleAcceptTap) {
                Label(PXContactRequestConfig.acceptButtonLabel, systemImage: PXContactRequestConfig.acceptIcon)
            }
            .frame(maxWidth: .infinity, minHeight: PXContactRequestConfig.actionButtonHeight)
            .accessibilityLabel(Text(NSLocalizedString("a11y_accept_contact_request", comment: "")))
        }
    }

    @ViewBuilder
    private var pxProgressOverlay: some View {
        if progressByTimeout {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - POPOPX Helpers

    private var pxCurrentOpacity: Double {
        progressByTimeout ? PXContactRequestConfig.dimmedOpacity : 1.0
    }

    // MARK: - POPOPX Actions

    private func pxHandleProgressChange(_ inPrgrs: Bool) {
        if inPrgrs {
            Task {
                try? await Task.sleep(nanoseconds: PXContactRequestConfig.progressTimeoutNanos)
                progressByTimeout = inProgress
            }
        } else {
            progressByTimeout = false
        }
    }

    private func pxHandleAcceptTap() {
        if ChatModel.shared.addressShortLinkDataSet {
            pxAcceptRequest()
        } else {
            pxShowAcceptAlert()
        }
    }

    private func pxShowRejectAlert() {
        logger.debug("PX: [ContextContactRequestActions.showRejectAlert] requestId=\(contactRequestId)")
        showAlert(
            PXContactRequestConfig.rejectAlertTitle,
            message: PXContactRequestConfig.rejectAlertMessage,
            actions: {[
                UIAlertAction(title: NSLocalizedString("Reject", comment: "alert action"), style: .destructive) { _ in
                    Task { await rejectContactRequest(contactRequestId, dismissToChatList: true) }
                },
                cancelAlertAction
            ]}
        )
    }

    private func pxShowAcceptAlert() {
        logger.debug("PX: [ContextContactRequestActions.showAcceptAlert] requestId=\(contactRequestId)")
        showAlert(
            PXContactRequestConfig.acceptAlertTitle,
            actions: {[
                UIAlertAction(title: NSLocalizedString("Accept", comment: "alert action"), style: .default) { _ in
                    pxAcceptRequest()
                },
                UIAlertAction(title: NSLocalizedString("Accept incognito", comment: "alert action"), style: .default) { _ in
                    pxAcceptRequest(incognito: true)
                },
                cancelAlertAction
            ]}
        )
    }

    private func pxAcceptRequest(incognito: Bool = false) {
        Task {
            await acceptContactRequest(incognito: incognito, contactRequestId: contactRequestId, inProgress: $inProgress)
        }
    }
}

#Preview {
    PXContactRequestActions(
        contactRequestId: 1
    )
}

// MARK: - POPOPX
extension PXContactRequestActions {
    var pxComponentTag: String { "px-ctx-contact-request" }
    var pxActionButtonHeight: CGFloat { PXContactRequestConfig.actionButtonHeight }
    var pxIsInProgress: Bool { inProgress }
    var pxIsTimedOut: Bool { progressByTimeout }
}
