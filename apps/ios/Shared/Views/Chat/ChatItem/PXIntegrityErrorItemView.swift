//
//  PXIntegrityErrorItemView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 28/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/chat-view.md#IntegrityErrorItemView
struct IntegrityErrorItemView: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var msgError: MsgErrorType
    var chatItem: ChatItem

    var body: some View {
        CIMsgError(chat: chat, chatItem: chatItem) {
            switch msgError {
            case .msgSkipped:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("skipped_messages_title", comment: "Integrity error alert title")),
                    message: LocalizedStringKey(NSLocalizedString("skipped_messages_message", comment: "Skipped messages alert message"))
                )
            case .msgBadHash:
                AlertManager.shared.showAlert(Alert(
                    title: Text(NSLocalizedString("bad_message_hash", comment: "Alert title for bad hash")),
                    message: Text(NSLocalizedString("hash_mismatch_description", comment: "Description of hash mismatch")) + textNewLine +
                        Text(decryptErrorReason) + textNewLine +
                        Text(NSLocalizedString("report_to_developers", comment: "Request to report to developers"))
                ))
            case .msgBadId: msgBadIdAlert()
            case .msgDuplicate: msgBadIdAlert()
            }
        }
        .popopxBranded()
    }

    private func msgBadIdAlert() {
        AlertManager.shared.showAlert(Alert(
            title: Text(NSLocalizedString("bad_message_id", comment: "Alert title for bad message ID")),
            message: Text(NSLocalizedString("message_id_incorrect", comment: "Description of incorrect message ID")) + textNewLine +
                Text(NSLocalizedString("report_to_developers", comment: "Request to report to developers"))
        ))
    }
}

struct CIMsgError: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(chatItem.content.text)
                .foregroundColor(theme.colors.error)
                .italic()
            CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary)
                .padding(.horizontal, 12)
        }
        .padding(.leading, 12)
        .padding(.vertical, 6)
        .background { chatItemFrameColor(chatItem, theme).modifier(ChatTailPadding()) }
        .textSelection(.disabled)
        .simultaneousGesture(TapGesture().onEnded(onTap))
        .popopxBranded()
    }
}

struct RcvMsgErrorItemView: View {
    @ObservedObject var chat: Chat
    var rcvMsgError: RcvMsgError
    var chatItem: ChatItem

    var body: some View {
        CIMsgError(chat: chat, chatItem: chatItem) {
            let message: LocalizedStringKey = switch rcvMsgError {
                case let .dropped(attempts): LocalizedStringKey(String(format: NSLocalizedString("message_receive_error", comment: "Message receive error with attempt count"), attempts))
                case let .parseError(parseError): LocalizedStringKey("\(parseError)")
                }
            AlertManager.shared.showAlertMsg(
                title: LocalizedStringKey(NSLocalizedString("message_error_title", comment: "Message error alert title")),
                message: message
            )
        }
    }
}

struct IntegrityErrorItemView_Previews: PreviewProvider {
    static var previews: some View {
        IntegrityErrorItemView(chat: Chat.sampleData, msgError: .msgBadHash, chatItem: ChatItem.getIntegrityErrorSample())
    }
}

// MARK: - POPOPX
extension IntegrityErrorItemView {
    private func pxSecurityIcon() -> String {
        "shield.lefthalf.filled"
    }
}
