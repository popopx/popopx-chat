//
//  ContextItemView.swift
//  POPOPX
//
//  Created by JRoberts on 13/03/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXContextConfig {
    static let pxFeatureKey = "PX_CONTEXT_ITEM_ENHANCED"
    static let pxContentPadding: CGFloat = 14
    static let pxMinFrameHeight: CGFloat = 56
    static let pxIconFrameSize: CGFloat = 17
    static let pxAnimationDuration: Double = 0.24
    static let pxEnhancedBackgroundOpacity: Double = 0.95
    static let pxSenderSpacing: CGFloat = 4
    static let pxComponentId = "px-ctx-item"
}

private let pxContextFeatureEnabled = UserDefaults.standard.bool(forKey: PXContextConfig.pxFeatureKey)

// MARK: - POPOPX View Model
private struct PXContextItemState {
    let itemCount: Int
    let hasSingleItem: Bool
    let showsSender: Bool

    init(items: [ChatItem], showSender: Bool) {
        self.itemCount = items.count
        self.hasSingleItem = items.count == 1
        self.showsSender = showSender
    }

    var isMultiForward: Bool { !hasSingleItem }
}

struct ContextItemView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    let contextItems: [ChatItem]
    let contextIcon: String
    let cancelContextItem: () -> Void
    var contextIconForeground: Color? = nil
    var showSender: Bool = true

    var body: some View {
        pxMainLayout
            .padding(PXContextConfig.pxContentPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PXContextConfig.pxMinFrameHeight)
            .background(pxContextBackground)
            .popopxBranded()
    }

    // MARK: - POPOPX Layout Builders

    @ViewBuilder private var pxMainLayout: some View {
        let state = PXContextItemState(items: contextItems, showSender: showSender)
        HStack {
            pxIconView
            pxContentForState(state)
            Spacer()
            pxCancelButton
        }
    }

    private var pxIconView: some View {
        Image(systemName: contextIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: PXContextConfig.pxIconFrameSize, height: PXContextConfig.pxIconFrameSize)
            .foregroundColor(contextIconForeground ?? theme.colors.secondary)
            .accessibilityLabel(Text(verbatim: NSLocalizedString("a11y_context_icon", comment: "")))
    }

    @ViewBuilder private func pxContentForState(_ state: PXContextItemState) -> some View {
        if state.hasSingleItem, let singleItem = contextItems.first {
            if state.showsSender, let sender = singleItem.memberDisplayName {
                VStack(alignment: .leading, spacing: PXContextConfig.pxSenderSpacing) {
                    Text(sender).font(.caption).foregroundColor(theme.colors.secondary)
                    msgContentView(lines: 2, contextItem: singleItem)
                }
            } else {
                msgContentView(lines: 3, contextItem: singleItem)
            }
        } else {
            pxMultiItemCountText(count: state.itemCount)
        }
    }

    private func pxMultiItemCountText(count: Int) -> some View {
        let pxAction = chat.chatInfo.chatType == .local
            ? String(format: NSLocalizedString("context_saving_messages_format", comment: ""), count)
            : String(format: NSLocalizedString("context_forwarding_messages_format", comment: ""), count)
        return Text(pxAction).italic()
    }

    private var pxCancelButton: some View {
        Button {
            withAnimation(.easeInOut(duration: PXContextConfig.pxAnimationDuration)) {
                cancelContextItem()
            }
        } label: {
            Image(systemName: "multiply")
        }
        .tint(theme.colors.primary)
        .accessibilityLabel(Text(verbatim: NSLocalizedString("a11y_cancel_context", comment: "")))
    }

    // MARK: - POPOPX Background

    private var pxContextBackground: Color {
        let pxBaseColor = contextItems.first
            .map { chatItemFrameColor($0, theme) }
            ?? theme.colors.surface
        if pxContextFeatureEnabled {
            return pxBaseColor.opacity(PXContextConfig.pxEnhancedBackgroundOpacity)
        }
        return pxBaseColor
    }

    private func msgContentView(lines: Int, contextItem: ChatItem) -> some View {
        let pxAlignment = isRightToLeft(contextItem.text) ? TextAlignment.trailing : TextAlignment.leading
        return contextMsgPreview(contextItem)
            .multilineTextAlignment(pxAlignment)
            .lineLimit(lines)
    }

    private func contextMsgPreview(_ contextItem: ChatItem) -> some View {
        let pxTextResult = messageText(contextItem.text, contextItem.formattedText, sender: nil, preview: true, mentions: contextItem.mentions, userMemberId: nil, showSecrets: nil, backgroundColor: UIColor(pxContextBackground), stripLink: contextItem.content.msgContent?.chatLinkStr)
        let pxAttachment = pxBuildAttachmentText(contextItem)
        let t = pxAttachment + Text(AttributedString(pxTextResult.string))
        return t.if(pxTextResult.hasSecrets, transform: hiddenSecretsView)
    }

    // MARK: - POPOPX Helper

    private func pxBuildAttachmentText(_ contextItem: ChatItem) -> Text {
        let isFileLoaded = if let fileSource = getLoadedFileSource(contextItem.file) {
            FileManager.default.fileExists(atPath: getAppFilePath(fileSource.filePath).path)
        } else { false }
        switch contextItem.content.msgContent {
        case .file: return isFileLoaded ? pxImageText("doc.fill") : Text("")
        case .image: return pxImageText("photo")
        case .voice: return isFileLoaded ? pxImageText("play.fill") : Text("")
        case let .chat(_, chatLink, _):
            let pxHasText = contextItem.text != chatLink.connLinkStr
            return pxImageText(chatLink.smallIconName) + Text(chatLink.displayName) + Text(verbatim: pxHasText ? " - " : "")
        default: return Text("")
        }
    }

    private func pxImageText(_ s: String) -> Text {
        Text(Image(systemName: s)).foregroundColor(theme.colors.onSurface) + textSpace
    }
}

struct ContextItemView_Previews: PreviewProvider {
    static var previews: some View {
        let contextItem: ChatItem = ChatItem.getSample(1, .directSnd, .now, "hello")
        return ContextItemView(chat: Chat.sampleData, contextItems: [contextItem], contextIcon: "pencil.circle", cancelContextItem: {}, contextIconForeground: QuantumColors.error)
    }
}

// MARK: - POPOPX
extension ContextItemView {
    var pxComponentTag: String { PXContextConfig.pxComponentId }
    var pxContextItemCount: Int { contextItems.count }
    var pxHasSender: Bool { showSender }
}
