//
//  DeletedItemView.swift
//  POPOPX
//
//  Created by JRoberts on 04/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX deleted-item layout tokens
private let pxDeletedLeadingPad: CGFloat = 15
private let pxDeletedVerticalPad: CGFloat = 9
private let pxDeletedMetaHorizPad: CGFloat = 15

// Spec: spec/client/chat-view.md#DeletedItemView
struct DeletedItemView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    var chatItem: ChatItem

    /// Styled "deleted" placeholder text in the secondary colour
    private var pxDeletedLabel: some View {
        Text(chatItem.content.text)
            .italic()
            .foregroundColor(theme.colors.secondary)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            pxDeletedLabel
            CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary)
                .padding(.horizontal, pxDeletedMetaHorizPad)
        }
        .padding(.leading, pxDeletedLeadingPad)
        .padding(.vertical, pxDeletedVerticalPad)
        .background(chatItemFrameColor(chatItem, theme))
        .textSelection(.disabled)
        .popopxBranded()
    }
}

struct DeletedItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DeletedItemView(chat: Chat.sampleData, chatItem: ChatItem.getDeletedContentSample())
            DeletedItemView(chat: Chat.sampleData, chatItem: ChatItem.getDeletedContentSample(dir: .groupRcv(groupMember: GroupMember.sampleData)))
        }
        .previewLayout(.fixed(width: 360, height: 200))
    }
}

// MARK: - POPOPX
extension DeletedItemView {
    var pxComponentTag: String { "PX_DELETED_ITEM" }
}
