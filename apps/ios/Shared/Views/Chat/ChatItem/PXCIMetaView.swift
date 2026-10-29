//
//  CIMetaView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 11/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX: Meta view rendering configuration
private enum PXCIMetaConfig {
    /// Opacity for the sent-via-proxy indicator icon
    static let pxProxyIconOpacity: Double = 0.60
    /// Kerning value for inverted material status spacer
    static let pxInvertedKerning: CGFloat = 11
    /// Font size for the disappearing message timer icon
    static let pxTimerIconFontSize: CGFloat = 10
}

// Spec: spec/client/chat-view.md#CIMetaView
struct CIMetaView: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    @Environment(\.showTimestamp) var showTimestamp: Bool
    var chatItem: ChatItem
    var metaColor: Color
    /// Tertiary label colour used for low-emphasis status icons
    var pxPaleMetaColor = Color(uiColor: .tertiaryLabel)
    var showStatus = true
    var showEdited = true
    var pxInvertMaterial = false

    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false
    @AppStorage(DEFAULT_PRIVACY_SHOW_SIGNATURE) private var showSignature = true
    @AppStorage(DEFAULT_PRIVACY_SHOW_FILE_ENCRYPTION) private var showFileEncryption = true

    /// Resolved colour mode based on the invertedMaterial flag
    private var pxResolvedColorMode: MetaColorMode {
        pxInvertMaterial ? .invertedMaterial : .normal
    }

    var body: some View {
        Group {
        if chatItem.isDeletedContent {
            // Deleted items only show a timestamp in the meta row
            Text(pxDeletedTimestampText())
                .lineLimit(1)
        } else {
            ZStack {
                Text(pxBuildMetaText(
                    chatItem.meta,
                    chatTTL: chat.chatInfo.timedMessagesTTL,
                    encrypted: chatItem.encryptedFile,
                    color: metaColor,
                    paleColor: pxPaleMetaColor,
                    colorMode: pxResolvedColorMode,
                    showStatus: showStatus,
                    showEdited: showEdited,
                    showViaProxy: showSentViaProxy,
                    showTimesamp: showTimestamp,
                    signedFileVerified: chatItem.file?.loaded,
                    showSignature: showSignature,
                    showFileEncryption: showFileEncryption
                ))
                .lineLimit(1)
                .invertedForegroundStyle(enabled: pxInvertMaterial)
                if pxInvertMaterial {
                    Text(pxBuildMetaText(
                        chatItem.meta,
                        chatTTL: chat.chatInfo.timedMessagesTTL,
                        encrypted: chatItem.encryptedFile,
                        colorMode: .normal,
                        onlyOverrides: true,
                        showStatus: showStatus,
                        showEdited: showEdited,
                        showViaProxy: showSentViaProxy,
                        showTimesamp: showTimestamp,
                        signedFileVerified: chatItem.file?.loaded,
                        showSignature: showSignature,
                        showFileEncryption: showFileEncryption
                    ))
                    .lineLimit(1)
                }
            }
        }
        }
        .popopxBranded()
    }

    private func pxDeletedTimestampText() -> AttributedString {
        var pxTs = chatItem.timestampText
        pxTs.foregroundColor = metaColor
        pxTs.font = .caption
        return pxTs
    }
}

enum MetaColorMode {
    // Renders provided colours
    case normal
    // Fully transparent meta - used for reserving space
    case transparent
    // Renders white on dark backgrounds and black on light ones
    case invertedMaterial

    func resolve(_ c: Color?) -> Color? {
        switch self {
        case .normal: c
        case .transparent: .clear
        case .invertedMaterial: nil
        }
    }

    func statusSpacer(_ pxSent: Bool) -> AttributedString {
        switch self {
        case .normal, .transparent:
            return pxStatusIconAttributed(pxSent ? "checkmark.wide" : "circlebadge.fill", systemImage: !pxSent, .clear)
        case .invertedMaterial:
            let pxNsSpace = NSAttributedString(string: " ", attributes: [.kern: PXCIMetaConfig.pxInvertedKerning])
            return AttributedString(pxNsSpace)
        }
    }
}

// MARK: - POPOPX: builds the composite meta text for a chat item
func pxBuildMetaText(
    _ pxMeta: CIMeta,
    chatTTL pxChatTTL: Int?,
    encrypted pxEncrypted: Bool?,
    color pxColor: Color = .clear, // we use this function to reserve space without rendering meta
    paleColor pxPaleColor: Color? = nil,
    primaryColor pxPrimaryColor: Color = .accentColor,
    colorMode pxColorMode: MetaColorMode = .normal,
    onlyOverrides pxOnlyOverrides: Bool = false, // only render colors that differ from base
    showStatus pxShowStatus: Bool = true,
    showEdited pxShowEdited: Bool = true,
    showViaProxy pxShowViaProxy: Bool,
    showTimesamp pxShowTimestamp: Bool,
    signedFileVerified pxSignedFileVerified: Bool? = nil,
    showSignature pxShowSignature: Bool = true,
    showFileEncryption pxShowFileEncryption: Bool = true
) -> AttributedString {
    var pxResult = AttributedString()
    var pxSpace: AttributedString? = nil
    let pxAppendSpace = {
        if let pxSp = pxSpace {
            pxResult += pxSp
            pxSpace = nil
        }
    }
    let pxResolved = pxColorMode.resolve(pxColor)
    if pxShowEdited, pxMeta.itemEdited {
        pxResult += pxStatusIconAttributed("pencil", pxResolved)
    }
    if pxMeta.disappearing {
        pxResult += pxStatusIconAttributed("timer", pxResolved)
        let pxTtl = pxMeta.itemTimed?.ttl
        if pxTtl != pxChatTTL {
            pxResult += pxColoredAttributed(AttributedString(shortTimeTextString(pxTtl)), pxResolved)
        }
        pxSpace = AttributedString(" ")
    }
    if pxShowViaProxy, pxMeta.sentViaProxy == true {
        pxAppendSpace()
        pxResult += pxStatusIconAttributed("arrow.forward", pxResolved?.opacity(PXCIMetaConfig.pxProxyIconOpacity))
    }
    if pxShowStatus {
        pxAppendSpace()
        if let (pxImageName, pxIsSystem, pxStatusColor) = pxMeta.itemStatus.statusIcon(pxColor, pxPaleColor ?? pxColor, pxPrimaryColor) {
            let pxMetaColor = if pxOnlyOverrides && pxStatusColor == pxColor {
                Color.clear
            } else {
                pxColorMode.resolve(pxStatusColor)
            }
            pxResult += pxColoredAttributed(pxStatusIconAttributed(pxImageName, systemImage: pxIsSystem, pxMetaColor), pxMetaColor)
        } else if !pxMeta.disappearing {
            pxResult += pxColorMode.statusSpacer(pxMeta.itemStatus.sent)
        }
        pxSpace = AttributedString(" ")
    }
    if let pxCrypto = pxEncrypted, pxShowFileEncryption {
        pxAppendSpace()
        pxResult += pxStatusIconAttributed(pxCrypto ? "lock" : "lock.open", pxResolved)
        pxSpace = AttributedString(" ")
    }
    // TODO [BLOCKED: msgVerified field not exposed in upstream FFI]
    // if pxShowSignature, pxMeta.msgVerified?.verified == true && pxSignedFileVerified != false {
    //     pxAppendSpace()
    //     pxResult += pxColoredAttributed(pxStatusIconAttributed("checkmark.seal", pxResolved), pxResolved)
    //     pxSpace = AttributedString(" ")
    // } else if pxMeta.msgVerified == .sigMissing {
    //     pxAppendSpace()
    //     pxResult += pxColoredAttributed(pxStatusIconAttributed("xmark.seal", pxColorMode.resolve(QuantumColors.error)), pxColorMode.resolve(QuantumColors.error))
    //     pxSpace = AttributedString(" ")
    // }
    if pxShowTimestamp {
        pxAppendSpace()
        pxResult += pxColoredAttributed(pxMeta.timestampText, pxResolved)
    }
    pxResult.font = .caption
    return pxResult
}

/// Creates an AttributedString containing an inline SF Symbol or asset catalog image
func pxStatusIconAttributed(_ pxIcon: String, systemImage: Bool = true, _ pxColor: Color?) -> AttributedString {
    let pxConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    var pxImage: UIImage
    if systemImage {
        pxImage = UIImage(systemName: pxIcon, withConfiguration: pxConfig) ?? UIImage(systemName: pxIcon)!
    } else {
        pxImage = UIImage(named: pxIcon) ?? UIImage(systemName: pxIcon)!
    }
    if let pxColor {
        let pxUiColor = UIColor(pxColor)
        pxImage = pxImage.withTintColor(pxUiColor, renderingMode: .alwaysOriginal)
    }
    let pxAttachment = NSTextAttachment()
    pxAttachment.image = pxImage
    let pxImageHeight = pxImage.size.height
    pxAttachment.bounds = CGRect(x: 0, y: (UIFont.preferredFont(forTextStyle: .caption2).capHeight - pxImageHeight) / 2, width: pxImage.size.width, height: pxImageHeight)
    let pxNsAttr = NSAttributedString(attachment: pxAttachment)
    return AttributedString(pxNsAttr)
}

/// Applies foregroundColor to an AttributedString if color is non-nil
@inline(__always)
private func pxColoredAttributed(_ pxText: AttributedString, _ pxColor: Color?) -> AttributedString {
    if let pxColor {
        var pxResult = pxText
        pxResult.foregroundColor = pxColor
        return pxResult
    }
    return pxText
}

#Preview(traits: .fixedLayout(width: 360, height: 100)) {
    let metaColor = Color.secondary
    Group {
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndSent(sndProgress: .complete)), metaColor: metaColor)
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndSent(sndProgress: .partial)), metaColor: metaColor)
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndRcvd(msgRcptStatus: .ok, sndProgress: .complete)), metaColor: metaColor)
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndRcvd(msgRcptStatus: .ok, sndProgress: .partial)), metaColor: metaColor)
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndRcvd(msgRcptStatus: .badMsgHash, sndProgress: .complete)), metaColor: metaColor)
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndSent(sndProgress: .complete), itemEdited: true), metaColor: metaColor)
        CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getDeletedContentSample(), metaColor: metaColor)
    }
}

// MARK: - POPOPX
extension CIMetaView {
    var pxComponentTag: String { "PX_CI_META" }
}
