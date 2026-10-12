//
//  CICallItemView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 20/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration

private enum PXCallItemConfig {
    static let componentTag: String = "PX_CALL_ITEM"
    /// Vertical spacing between icon and meta
    static let iconMetaSpacing: CGFloat = 4
    /// Bottom padding below meta row
    static let metaBottomPadding: CGFloat = 8
    /// Horizontal padding around meta row
    static let metaHorizontalPadding: CGFloat = 12
    /// Opacity for secondary icons in dark theme
    static let darkThemeIconOpacity: Double = 0.85
    /// Opacity for secondary icons in light theme
    static let lightThemeIconOpacity: Double = 1.0
}

// MARK: - POPOPX ViewModel

private struct PXCallItemViewModel {
    let status: CICallStatus
    let sent: Bool
    let duration: Int

    var missedCallSymbol: String {
        sent ? "phone.arrow.up.right" : "phone.arrow.down.left"
    }

    var statusAccessibilityLabel: String {
        switch status {
        case .pending: return sent
            ? NSLocalizedString("Outgoing pending call", comment: "call accessibility")
            : NSLocalizedString("Incoming pending call", comment: "call accessibility")
        case .missed: return sent
            ? NSLocalizedString("Outgoing missed call", comment: "call accessibility")
            : NSLocalizedString("Incoming missed call", comment: "call accessibility")
        case .rejected: return NSLocalizedString("Rejected call", comment: "call accessibility")
        case .accepted, .negotiated: return NSLocalizedString("Call connecting", comment: "call accessibility")
        case .progress: return NSLocalizedString("Call in progress", comment: "call accessibility")
        case .ended: return NSLocalizedString("Ended call", comment: "call accessibility")
        case .error: return NSLocalizedString("Call error", comment: "call accessibility")
        }
    }
}

struct CICallItemView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    var chatItem: ChatItem
    var status: CICallStatus
    var duration: Int

    var body: some View {
        let sent = chatItem.chatDir.sent
        let vm = PXCallItemViewModel(status: status, sent: sent, duration: duration)
        VStack(spacing: PXCallItemConfig.iconMetaSpacing) {
            statusIconView(vm)
            callMetaView
        }
        .popopxBranded()
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func statusIconView(_ vm: PXCallItemViewModel) -> some View {
        switch status {
        case .pending:
            if vm.sent {
                Image(systemName: "phone.arrow.up.right")
                    .foregroundColor(theme.colors.secondary)
                    .accessibilityLabel(vm.statusAccessibilityLabel)
            } else {
                acceptCallButton()
            }
        case .missed:
            missedCallIconView(vm)
                .foregroundColor(theme.colors.onSurface)
                .accessibilityLabel(vm.statusAccessibilityLabel)
        case .rejected:
            Image(systemName: "phone.down")
                .foregroundColor(theme.colors.error)
                .accessibilityLabel(vm.statusAccessibilityLabel)
        case .accepted:
            connectingCallIconView()
        case .negotiated:
            connectingCallIconView()
        case .progress:
            Image(systemName: "phone.and.waveform.fill")
                .foregroundColor(QuantumColors.success)
                .accessibilityLabel(vm.statusAccessibilityLabel)
        case .ended:
            endedCallIconView(vm)
        case .error:
            missedCallIconView(vm)
                .foregroundColor(QuantumColors.warning)
                .accessibilityLabel(vm.statusAccessibilityLabel)
        }
    }

    private var callMetaView: some View {
        CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary, showStatus: false, showEdited: false)
            .padding(.bottom, PXCallItemConfig.metaBottomPadding)
            .padding(.horizontal, PXCallItemConfig.metaHorizontalPadding)
    }

    private func missedCallIconView(_ vm: PXCallItemViewModel) -> some View {
        Image(systemName: vm.missedCallSymbol)
    }

    private func connectingCallIconView() -> some View {
        Image(systemName: "phone.connection")
            .foregroundColor(QuantumColors.success)
            .accessibilityLabel(NSLocalizedString("Call connecting", comment: "call accessibility"))
    }

    private func endedCallIconView(_ vm: PXCallItemViewModel) -> some View {
        HStack {
            Image(systemName: "phone.down")
            Text(durationText(vm.duration))
                .foregroundColor(theme.colors.secondary)
        }
        .accessibilityLabel(vm.statusAccessibilityLabel)
    }

    @ViewBuilder
    private func acceptCallButton() -> some View {
        if case let .direct(contact) = chat.chatInfo {
            Label(NSLocalizedString("compose_answer_call", comment: "Answer incoming call button"), systemImage: "phone.arrow.down.left")
                .foregroundColor(theme.colors.primary)
                .accessibilityLabel(Text(NSLocalizedString("compose_answer_call", comment: "Answer incoming call button")))
                .simultaneousGesture(TapGesture().onEnded {
                    if let invitation = m.callInvitations[contact.id] {
                        CallController.shared.answerCall(invitation: invitation)
                        logger.debug("acceptCallButton call answered")
                    } else {
                        AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Call already ended!", comment: "call already ended alert title")))
                    }
                })
        } else {
            Image(systemName: "phone.arrow.down.left")
                .foregroundColor(theme.colors.secondary)
        }
    }
}

//struct CICallItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        CICallItemView()
//    }
//}

// MARK: - POPOPX
extension CICallItemView {
    static let pxComponentTag: String = PXCallItemConfig.componentTag
}
