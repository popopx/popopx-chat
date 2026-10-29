//
//  EmojiItemView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 04/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX emoji layout tokens
private enum PXEmojiItemConfig {
    /// Top padding for the emoji glyph
    static let topPadding: CGFloat = 11
    /// Horizontal padding around the emoji glyph
    static let horizontalPadding: CGFloat = 9
    /// Bottom padding for the metadata row
    static let metaBottomPadding: CGFloat = 9
    /// Horizontal padding for the metadata row
    static let metaHorizontalPadding: CGFloat = 15
    /// Threshold for switching between large and medium emoji font sizes
    static let largeThreshold: Int = 3
    /// VStack spacing between emoji and meta
    static let stackSpacing: CGFloat = 3
    /// Opacity dimming in light mode for meta text
    static let lightModeMetaOpacity: Double = 0.92
}

// Spec: spec/client/chat-view.md#EmojiItemView
struct EmojiItemView: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem

    var body: some View {
        VStack(spacing: PXEmojiItemConfig.stackSpacing) {
            // Render the emoji glyph with POPOPX-tuned padding
            emojiText(chatItem.content.text)
                .padding(.horizontal, PXEmojiItemConfig.horizontalPadding)
                .padding(.top, PXEmojiItemConfig.topPadding)
            CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary)
                .padding(.horizontal, PXEmojiItemConfig.metaHorizontalPadding)
                .padding(.bottom, PXEmojiItemConfig.metaBottomPadding)
                .opacity(isInDarkTheme() ? 1.0 : PXEmojiItemConfig.lightModeMetaOpacity)
        }
        .accessibilityElement(children: .combine)
        .popopxBranded()
    }
}

/// Returns a Text view sized for the emoji: large font for 1-3 chars, medium otherwise.
func emojiText(_ text: String) -> Text {
    let s = text.trimmingCharacters(in: .whitespaces)
    return Text(s).font(s.count < PXEmojiItemConfig.largeThreshold + 1 ? largeEmojiFont : mediumEmojiFont)
}

#Preview(traits: .fixedLayout(width: 360, height: 70)) {
    Group{
        EmojiItemView(chat: Chat.sampleData, chatItem: ChatItem.getSample(1, .directSnd, .now, "🙂", .sndSent(sndProgress: .complete)))
        EmojiItemView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directRcv, .now, "👍"))
    }
}

// MARK: - POPOPX
extension EmojiItemView {
    static let pxComponentTag: String = "PX_EMOJI_ITEM"
}
