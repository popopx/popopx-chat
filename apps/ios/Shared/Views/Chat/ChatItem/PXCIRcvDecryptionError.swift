//
//  PXCIRcvDecryptionError.swift
//  POPOPX (iOS)
//
//  POPOPX decryption error display for chat items.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxDecryptErrorFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_DECRYPT_ERROR_FEATURE_ENABLED")

// MARK: - POPOPX Configuration
private enum PXCIRcvDecryptionErrorConfig {
    static let verticalPadding: CGFloat = 5
    static let horizontalPadding: CGFloat = 14
    static let fixButtonSpacing: CGFloat = 2
    static let metaTrailingSpace: String = "   "
    static let syncLogPrefix: String = "PX: [syncMemberConnection]"
    static let contactSyncLogPrefix: String = "PX: [syncContactConnection]"
    static let componentIdentifier: String = "px-decryption-error"
    static let a11yFixConnection: String = "px_decrypt_fix_connection"
    static let a11yErrorItem: String = "px_decrypt_error_item"
}

// MARK: - POPOPX View Model
@MainActor
private struct PXCIRcvDecryptionErrorViewModel {
    let chat: Chat
    let chatItem: ChatItem
    let msgDecryptError: MsgDecryptError
    let msgCount: UInt32

    var isGroupContext: Bool {
        if case .group = chat.chatInfo { return true }
        return false
    }

    var isDirectContext: Bool {
        if case .direct = chat.chatInfo { return true }
        return false
    }

    var errorMessageText: String {
        chatItem.content.text
    }

    func failureMessage(_ theme: AppTheme) -> Text {
        let why = NSLocalizedString("decrypt_error_reason", comment: "decryption error explanation - old database backup")
        var message: AttributedString
        switch msgDecryptError {
        case .ratchetHeader:
            message = AttributedString(String(format: NSLocalizedString("decrypt_messages_failed_fmt", comment: "number of messages that failed to decrypt"), msgCount) + "\n" + why)
        case .tooManySkipped:
            message = AttributedString(String(format: NSLocalizedString("decrypt_messages_skipped_fmt", comment: "number of messages that were skipped"), msgCount) + "\n" + why)
        case .ratchetEarlier:
            message = AttributedString(String(format: NSLocalizedString("decrypt_messages_failed_fmt", comment: "number of messages that failed to decrypt"), msgCount) + "\n" + why)
        case .other:
            message = AttributedString(String(format: NSLocalizedString("decrypt_messages_failed_fmt", comment: "number of messages that failed to decrypt"), msgCount) + "\n" + why)
        case .ratchetSync:
            message = AttributedString(NSLocalizedString("decrypt_renegotiation_failed", comment: "encryption re-negotiation failed message"))
        }
        return Text(message)
    }
}

let decryptErrorReason: LocalizedStringKey = LocalizedStringKey(NSLocalizedString("decrypt_error_reason", comment: "decryption error explanation - old database backup"))

// Spec: spec/client/chat-view.md#PXDecryptionError
struct PXDecryptionError: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    @Environment(\.showTimestamp) var showTimestamp: Bool
    var msgDecryptError: MsgDecryptError
    var msgCount: UInt32
    var chatItem: ChatItem
    @State private var alert: PXDecryptionErrorAlert?

    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false

    enum PXDecryptionErrorAlert: Identifiable {
        case syncAllowedAlert(_ syncConnection: () -> Void)
        case syncNotSupportedContactAlert
        case syncNotSupportedMemberAlert
        case decryptionErrorAlert
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .syncAllowedAlert: return "syncAllowedAlert"
            case .syncNotSupportedContactAlert: return "syncNotSupportedContactAlert"
            case .syncNotSupportedMemberAlert: return "syncNotSupportedMemberAlert"
            case .decryptionErrorAlert: return "decryptionErrorAlert"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        decryptionErrorBody
            .onAppear {
                // for direct chat ConnectionStats are populated on opening chat, see ChatView onAppear
                if case let .group(groupInfo, _) = chat.chatInfo,
                   case let .groupRcv(groupMember) = chatItem.chatDir {
                    do {
                        let (member, stats) = try apiGroupMemberInfoSync(groupInfo.apiId, groupMember.groupMemberId)
                        if let s = stats {
                            m.updateGroupMemberConnectionStats(groupInfo, member, s)
                        }
                    } catch let error {
                        logger.error("apiGroupMemberInfo error: \(responseError(error))")
                    }
                }
            }
            .alert(item: $alert) { alertItem in
                switch(alertItem) {
                case let .syncAllowedAlert(syncConnection): return syncAllowedAlert(syncConnection)
                case .syncNotSupportedContactAlert: return Alert(title: Text(NSLocalizedString("decrypt_fix_not_supported_contact", comment: "fix not supported by contact alert title")), message: alertMessage())
                case .syncNotSupportedMemberAlert: return Alert(title: Text(NSLocalizedString("decrypt_fix_not_supported_member", comment: "fix not supported by group member alert title")), message: alertMessage())
                case .decryptionErrorAlert: return Alert(title: Text(NSLocalizedString("decrypt_error_alert_title", comment: "decryption error alert title")), message: alertMessage())
                case let .error(title, error): return mkAlert(title: title, message: error)
                }
            }
        .popopxBranded()
    }

    // MARK: - POPOPX decomposed sub-views

    @ViewBuilder private var decryptionErrorBody: some View {
        Group {
            if case let .direct(contact) = chat.chatInfo,
               let contactStats = contact.activeConn?.connectionStats {
                directChatDecryptionView(contact: contact, stats: contactStats)
            } else if case let .group(groupInfo, _) = chat.chatInfo,
                      case let .groupRcv(groupMember) = chatItem.chatDir,
                      let mem = m.getGroupMember(groupMember.groupMemberId),
                      let memberStats = mem.wrapped.activeConn?.connectionStats {
                groupChatDecryptionView(groupInfo: groupInfo, groupMember: groupMember, stats: memberStats)
            } else {
                basicDecryptionErrorItem()
            }
        }
        .background { chatItemFrameColor(chatItem, theme).modifier(ChatTailPadding()).background(theme.colors.surface) }
    }

    @ViewBuilder
    private func directChatDecryptionView(contact: Contact, stats: ConnectionStats) -> some View {
        if stats.ratchetSyncAllowed {
            decryptionErrorItemFixButton(syncSupported: true) {
                alert = .syncAllowedAlert { syncContactConnection(contact) }
            }
        } else if !stats.ratchetSyncSupported {
            decryptionErrorItemFixButton(syncSupported: false) {
                alert = .syncNotSupportedContactAlert
            }
        } else {
            basicDecryptionErrorItem()
        }
    }

    @ViewBuilder
    private func groupChatDecryptionView(groupInfo: GroupInfo, groupMember: GroupMember, stats: ConnectionStats) -> some View {
        if stats.ratchetSyncAllowed {
            decryptionErrorItemFixButton(syncSupported: true) {
                alert = .syncAllowedAlert { syncMemberConnection(groupInfo, groupMember) }
            }
        } else if !stats.ratchetSyncSupported {
            decryptionErrorItemFixButton(syncSupported: false) {
                alert = .syncNotSupportedMemberAlert
            }
        } else {
            basicDecryptionErrorItem()
        }
    }

    private func basicDecryptionErrorItem() -> some View {
        decryptionErrorItem { alert = .decryptionErrorAlert }
    }

    // MARK: - POPOPX visual differentiation for decryption error UI

    private func decryptionErrorItemFixButton(syncSupported: Bool, _ onClick: @escaping (() -> Void)) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: PXCIRcvDecryptionErrorConfig.fixButtonSpacing) {
                HStack {
                    Text(chatItem.content.text)
                        .foregroundColor(theme.colors.error)
                        .italic()
                }
                Text({
                    var pxResult = pxStatusIconAttributed("exclamationmark.arrow.triangle.2.circlepath", syncSupported ? theme.colors.primary : theme.colors.secondary)
                    pxResult.font = .callout
                    pxResult += AttributedString(" ")
                    var pxLabel = AttributedString(NSLocalizedString("decrypt_fix_connection", comment: "fix connection button label in decryption error"))
                    pxLabel.foregroundColor = syncSupported ? theme.colors.primary : theme.colors.secondary
                    pxLabel.font = .callout
                    pxResult += pxLabel
                    pxResult += AttributedString(PXCIRcvDecryptionErrorConfig.metaTrailingSpace)
                    pxResult += pxBuildMetaText(chatItem.meta, chatTTL: nil, encrypted: nil, colorMode: .transparent, showViaProxy: showSentViaProxy, showTimesamp: showTimestamp)
                    return pxResult
                }())
            }
            .padding(.horizontal, PXCIRcvDecryptionErrorConfig.horizontalPadding)
            CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary)
                .padding(.horizontal, PXCIRcvDecryptionErrorConfig.horizontalPadding)
        }
        .simultaneousGesture(TapGesture().onEnded(onClick))
        .padding(.vertical, PXCIRcvDecryptionErrorConfig.verticalPadding)
        .textSelection(.disabled)
        .accessibilityLabel(Text(verbatim: PXCIRcvDecryptionErrorConfig.a11yFixConnection))
    }

    private func decryptionErrorItem(_ onClick: @escaping (() -> Void)) -> some View {
        return ZStack(alignment: .bottomTrailing) {
            HStack {
                Text(chatItem.content.text)
                    .foregroundColor(theme.colors.error)
                    .italic()
                Text({
                    var pxResult = AttributedString(PXCIRcvDecryptionErrorConfig.metaTrailingSpace)
                    pxResult += pxBuildMetaText(chatItem.meta, chatTTL: nil, encrypted: nil, colorMode: .transparent, showViaProxy: showSentViaProxy, showTimesamp: showTimestamp)
                    return pxResult
                }())
            }
            .padding(.horizontal, PXCIRcvDecryptionErrorConfig.horizontalPadding)
            CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary)
                .padding(.horizontal, PXCIRcvDecryptionErrorConfig.horizontalPadding)
        }
        .simultaneousGesture(TapGesture().onEnded(onClick))
        .padding(.vertical, PXCIRcvDecryptionErrorConfig.verticalPadding)
        .textSelection(.disabled)
        .accessibilityLabel(Text(verbatim: PXCIRcvDecryptionErrorConfig.a11yErrorItem))
    }

    // MARK: - POPOPX alert message builder

    private func alertMessage() -> Text {
        let vm = PXCIRcvDecryptionErrorViewModel(
            chat: chat, chatItem: chatItem,
            msgDecryptError: msgDecryptError, msgCount: msgCount
        )
        return vm.failureMessage(theme)
    }

    // MARK: - POPOPX enhanced logging for sync operations

    private func syncMemberConnection(_ groupInfo: GroupInfo, _ member: GroupMember) {
        logger.debug("\(PXCIRcvDecryptionErrorConfig.syncLogPrefix) called for group: \(groupInfo.apiId)")
        Task {
            do {
                let (mem, stats) = try apiSyncGroupMemberRatchet(groupInfo.apiId, member.groupMemberId, false)
                await MainActor.run {
                    m.updateGroupMemberConnectionStats(groupInfo, mem, stats)
                }
            } catch let error {
                logger.error("syncMemberConnection apiSyncGroupMemberRatchet error: \(responseError(error))")
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error synchronizing connection", comment: "")))
                }
            }
        }
    }

    private func syncContactConnection(_ contact: Contact) {
        logger.debug("\(PXCIRcvDecryptionErrorConfig.contactSyncLogPrefix) called for contact: \(contact.apiId)")
        Task {
            do {
                let stats = try apiSyncContactRatchet(contact.apiId, false)
                await MainActor.run {
                    m.updateContactConnectionStats(contact, stats)
                }
            } catch let error {
                logger.error("syncContactConnection apiSyncContactRatchet error: \(responseError(error))")
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error", comment: "")), message: LocalizedStringKey(NSLocalizedString("Error synchronizing connection", comment: "")))
                }
            }
        }
    }

    private func syncAllowedAlert(_ syncConnection: @escaping () -> Void) -> Alert {
        Alert(
            title: Text(NSLocalizedString("decrypt_fix_connection_question", comment: "fix connection alert title")),
            message: alertMessage(),
            primaryButton: .default(Text(NSLocalizedString("decrypt_fix_button", comment: "fix connection alert action button")), action: syncConnection),
            secondaryButton: .cancel()
        )
    }
}

//struct PXDecryptionError_Previews: PreviewProvider {
//    static var previews: some View {
//        PXDecryptionError(msgDecryptError: .ratchetHeader, msgCount: 1, chatItem: ChatItem.getIntegrityErrorSample())
//    }
//}

// MARK: - POPOPX
extension PXDecryptionError {
    var pxComponentTag: String { PXCIRcvDecryptionErrorConfig.componentIdentifier }
    var pxA11yFixId: String { PXCIRcvDecryptionErrorConfig.a11yFixConnection }
    var pxIsGroupDecryptionContext: Bool {
        if case .group = chat.chatInfo { return true }
        return false
    }
}
