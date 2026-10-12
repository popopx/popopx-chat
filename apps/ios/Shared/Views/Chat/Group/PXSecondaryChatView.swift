//
//  SecondaryChatView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 29.04.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Config
private enum PXSecondaryChatConfig {
    static let emptyFadeDuration: Double = 0.25
    static let dismissOnVerify: Bool = true
    static let backButtonDisabled: Bool = false
    static let animationCurve: Animation = .easeInOut(duration: emptyFadeDuration)
}

// MARK: - POPOPX View Model
private struct PXSecondaryChatViewModel {
    let isSecondaryActive: Bool

    var pxTransitionOpacity: Double {
        isSecondaryActive ? 1.0 : 0.0
    }

    var pxAnimationBinding: Bool { isSecondaryActive }
}

struct SecondaryChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject var chat: Chat
    @Binding var scrollToItemId: ChatItem.ID?

    var body: some View {
        pxContainer
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxContainer: some View {
        Group {
            if let im = chatModel.secondaryIM {
                pxChatContent(im: im)
            }
        }
        .animation(PXSecondaryChatConfig.animationCurve, value: chatModel.secondaryIM != nil)
        .accessibilityElement(children: .contain)
        .popopxBranded()
    }

    @ViewBuilder
    private func pxChatContent(im: ItemsModel) -> some View {
        ChatView(
            chat: chat,
            im: im,
            mergedItems: BoxedValue(MergedItems.create(im, [])),
            floatingButtonModel: FloatingButtonModel(im: im),
            scrollToItemId: $scrollToItemId
        )
        .modifier(BackButton(disabled: Binding.constant(PXSecondaryChatConfig.backButtonDisabled)) {
            pxHandleBackAction()
        })
        .accessibilityLabel(Text(NSLocalizedString("a11y_secondary_chat_conversation", comment: "")))
    }

    // MARK: - POPOPX Actions

    private func pxHandleBackAction() {
        if PXSecondaryChatConfig.dismissOnVerify {
            chatModel.secondaryIM = nil
        }
        dismiss()
    }
}

// MARK: - POPOPX
extension SecondaryChatView {
    var pxComponentTag: String { "px-secondary-chat" }
    var pxIsSecondaryActive: Bool { chatModel.secondaryIM != nil }
    var pxFadeDuration: Double { PXSecondaryChatConfig.emptyFadeDuration }
    var pxAnimation: Animation { PXSecondaryChatConfig.animationCurve }
}

#Preview {
    SecondaryChatView(
        chat: Chat(
            chatInfo: .group(groupInfo: GroupInfo.sampleData, groupChatScope: .memberSupport(groupMember_: GroupMember.sampleData)),
            chatItems: [],
            chatStats: ChatStats()
        ),
        scrollToItemId: Binding.constant(nil)
    )
}
