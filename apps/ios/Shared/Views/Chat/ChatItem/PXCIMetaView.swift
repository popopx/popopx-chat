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
            chatItem.timestampText
                .foregroundColor(metaColor)
                .font(.caption)
                .lineLimit(1)
        } else {
            ZStack {
                pxBuildMetaText(
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
                )
                .lineLimit(1)
                .invertedForegroundStyle(enabled: pxInvertMaterial)
                if pxInvertMaterial {
                    pxBuildMetaText(
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
                    )
                    .lineLimit(1)
                }
            }
        }
        }
        .popopxBranded()
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

    func statusSpacer(_ pxSent: Bool) -> Text {
        switch self {
        case .normal, .transparent:
            Text(
                pxSent
                ? Image("checkmark.wide")
                : Image(systemName: "circlebadge.fill")
            ).foregroundColor(.clear)
        case .invertedMaterial: textSpace.kerning(PXCIMetaConfig.pxInvertedKerning)
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
) -> Text {
    var pxResult = Text("")
    var pxSpace: Text? = nil
    let pxAppendSpace = {
        if let pxSp = pxSpace {
            pxResult = pxResult + pxSp
            pxSpace = nil
        }
    }
    let pxResolved = pxColorMode.resolve(pxColor)
    if pxShowEdited, pxMeta.itemEdited {
        pxResult = pxResult + pxStatusIcon("pencil", pxResolved)
    }
    if pxMeta.disappearing {
        pxResult = pxResult + pxStatusIcon("timer", pxResolved).font(.system(size: PXCIMetaConfig.pxTimerIconFontSize))
        let pxTtl = pxMeta.itemTimed?.ttl
        if pxTtl != pxChatTTL {
            pxResult = pxResult + pxColored(Text(shortTimeText(pxTtl)), pxResolved)
        }
        pxSpace = textSpace
    }
    if pxShowViaProxy, pxMeta.sentViaProxy == true {
        pxAppendSpace()
        pxResult = pxResult + pxStatusIcon("arrow.forward", pxResolved?.opacity(PXCIMetaConfig.pxProxyIconOpacity)).font(.caption2)
    }
    if pxShowStatus {
        pxAppendSpace()
        if let (pxImage, pxStatusColor) = pxMeta.itemStatus.statusIcon(pxColor, pxPaleColor ?? pxColor, pxPrimaryColor) {
            let pxMetaColor = if pxOnlyOverrides && pxStatusColor == pxColor {
                Color.clear
            } else {
                pxColorMode.resolve(pxStatusColor)
            }
            pxResult = pxResult + pxColored(Text(pxImage), pxMetaColor)
        } else if !pxMeta.disappearing {
            pxResult = pxResult + pxColorMode.statusSpacer(pxMeta.itemStatus.sent)
        }
        pxSpace = textSpace
    }
    if let pxCrypto = pxEncrypted, pxShowFileEncryption {
        pxAppendSpace()
        pxResult = pxResult + pxStatusIcon(pxCrypto ? "lock" : "lock.open", pxResolved)
        pxSpace = textSpace
    }
    // TODO [BLOCKED: msgVerified field not exposed in upstream FFI]
    // if pxShowSignature, pxMeta.msgVerified?.verified == true && pxSignedFileVerified != false {
    //     pxAppendSpace()
    //     pxResult = pxResult + pxColored(Text(Image(systemName: "checkmark.seal")), pxResolved)
    //     pxSpace = textSpace
    // } else if pxMeta.msgVerified == .sigMissing {
    //     pxAppendSpace()
    //     pxResult = pxResult + pxColored(Text(Image(systemName: "xmark.seal")), pxColorMode.resolve(QuantumColors.error))
    //     pxSpace = textSpace
    // }
    if pxShowTimestamp {
        pxAppendSpace()
        pxResult = pxResult + pxColored(pxMeta.timestampText, pxResolved)
    }
    return pxResult.font(.caption)
}

@inline(__always)
private func pxStatusIcon(_ pxIcon: String, _ pxColor: Color?) -> Text {
    let pxText = Text(Image(systemName: pxIcon))
    if let pxColor {
        return pxText.foregroundColor(pxColor)
    }
    return pxText
}

// Applying `foregroundColor(nil)` breaks `.invertedForegroundStyle` modifier
@inline(__always)
private func pxColored(_ pxText: Text, _ pxColor: Color?) -> Text {
    if let pxColor {
        pxText.foregroundColor(pxColor)
    } else {
        pxText
    }
}

struct CIMetaView_Previews: PreviewProvider {
    static let metaColor = Color.secondary
    static var previews: some View {
        Group {
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndSent(sndProgress: .complete)), metaColor: metaColor)
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndSent(sndProgress: .partial)), metaColor: metaColor)
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndRcvd(msgRcptStatus: .ok, sndProgress: .complete)), metaColor: metaColor)
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndRcvd(msgRcptStatus: .ok, sndProgress: .partial)), metaColor: metaColor)
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndRcvd(msgRcptStatus: .badMsgHash, sndProgress: .complete)), metaColor: metaColor)
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getSample(2, .directSnd, .now, "https://popopxchat.com", .sndSent(sndProgress: .complete), itemEdited: true), metaColor: metaColor)
            CIMetaView(chat: Chat.sampleData, chatItem: ChatItem.getDeletedContentSample(), metaColor: metaColor)
        }
        .previewLayout(.fixed(width: 360, height: 100))
    }
}

// MARK: - POPOPX
extension CIMetaView {
    var pxComponentTag: String { "PX_CI_META" }
}
