//
//  MarkedDeletedItemView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 30.11.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/chat-view.md#MarkedDeletedItemView
struct MarkedDeletedItemView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.revealed) var revealed: Bool
    @ObservedObject var chat: Chat
    @ObservedObject var im: ItemsModel
    var chatItem: ChatItem

    var body: some View {
        Text(pxBuildMarkedDeletedText())
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background { chatItemFrameColor(chatItem, theme).modifier(ChatTailPadding()) }
        .textSelection(.disabled)
        .fixedSize(horizontal: false, vertical: true)
        .popopxBranded()
    }

    private func pxBuildMarkedDeletedText() -> AttributedString {
        var pxResult = AttributedString(String(describing: mergedMarkedDeletedText))
        pxResult += textSpace
        pxResult += chatItem.timestampText
        pxResult.font = .caption.italic()
        pxResult.foregroundColor = theme.colors.secondary
        return pxResult
    }

    var mergedMarkedDeletedText: LocalizedStringKey {
        if !revealed,
           let ciCategory = chatItem.mergeCategory,
           var i = m.getChatItemIndex(im, chatItem) {
            var moderated = 0
            var blocked = 0
            var blockedByAdmin = 0
            var deleted = 0
            var moderatedBy: Set<String> = []
            while i < im.reversedChatItems.count,
                  let ci = .some(im.reversedChatItems[i]),
                  ci.mergeCategory == ciCategory,
                  let itemDeleted = ci.meta.itemDeleted {
                switch itemDeleted {
                case let .moderated(_, byGroupMember):
                    moderated += 1
                    moderatedBy.insert(byGroupMember.displayName)
                case .blocked: blocked += 1
                case .blockedByAdmin: blockedByAdmin += 1
                case .deleted: deleted += 1
                }
                i += 1
            }
            let pxTotal = moderated + blocked + blockedByAdmin + deleted
            return pxMergedDeletedLabel(total: pxTotal, moderated: moderated, blocked: blocked, blockedByAdmin: blockedByAdmin, moderatedBy: moderatedBy)
        } else {
            return markedDeletedText
        }
    }

    // MARK: - POPOPX
    private func pxMergedDeletedLabel(total: Int, moderated: Int, blocked: Int, blockedByAdmin: Int, moderatedBy: Set<String>) -> LocalizedStringKey {
        guard total > 1 else { return markedDeletedText }
        if total == moderated {
            return LocalizedStringKey(String(format: NSLocalizedString("marked_deleted_moderated_by_list", comment: "Moderated messages with list of moderators"), total, moderatedBy.joined(separator: ", ")))
        } else if total == blockedByAdmin {
            return LocalizedStringKey(String(format: NSLocalizedString("marked_deleted_blocked_by_admin", comment: "Messages blocked by admin"), total))
        } else if total == blocked + blockedByAdmin {
            return LocalizedStringKey(String(format: NSLocalizedString("marked_deleted_blocked", comment: "Messages blocked"), total))
        } else {
            return LocalizedStringKey(String(format: NSLocalizedString("marked_deleted_marked_deleted", comment: "Messages marked deleted"), total))
        }
    }

    // same texts are in markedDeletedText in PXChatPreview, but it returns String;
    // can be refactored into a single function if functions calling these are changed to return same type
    var markedDeletedText: LocalizedStringKey {
        if chatItem.meta.itemDeleted != nil, chatItem.isReport {
            return LocalizedStringKey(NSLocalizedString("archived_report", comment: "archived report deleted status"))
        } else {
            switch chatItem.meta.itemDeleted {
            case let .moderated(_, byGroupMember): return LocalizedStringKey(String(format: NSLocalizedString("marked_deleted_moderated_by", comment: "Moderated by user"), byGroupMember.displayName))
            case .blocked: return LocalizedStringKey(NSLocalizedString("marked_deleted_blocked_single", comment: "Message blocked"))
            case .blockedByAdmin: return LocalizedStringKey(NSLocalizedString("marked_deleted_blocked_by_admin_single", comment: "Message blocked by admin"))
            case .deleted, nil: return LocalizedStringKey(NSLocalizedString("marked_deleted_deleted", comment: "Message marked deleted"))
            }
        }
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 200)) {
    Group {
        MarkedDeletedItemView(
            chat: Chat.sampleData,
            im: ItemsModel.shared,
            chatItem: ChatItem.getSample(1, .directSnd, .now, "hello", .sndSent(sndProgress: .complete), itemDeleted: .deleted(deletedTs: .now))
        ).environment(\.revealed, true)
    }
}

// MARK: - POPOPX
extension MarkedDeletedItemView {
    var pxComponentTag: String { "px-marked-deleted" }
}
