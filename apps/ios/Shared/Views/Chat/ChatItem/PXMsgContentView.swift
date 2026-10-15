//
//  MsgContentView.swift
//  POPOPX
//
//  Created by Evgeny on 13/03/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Rendering Constants

// POPOPX: extracted layout constants for message content rendering
private enum PXMsgLayout {
    /// Alpha channel for link text color (slightly reduced for theme consistency)
    static let linkColorAlpha: CGFloat = 0.85
    /// Kerning value for typing indicator dots (tighter than default)
    static let typingDotKern: CGFloat = -3.0
    /// Squared drag distance threshold before tap is cancelled
    static let dragThresholdSquared: CGFloat = 140
    /// Watermark saturation level for hidden secrets overlay
    static let watermarkSaturation: CGFloat = 0.55
    /// Watermark opacity for hidden secrets overlay
    static let watermarkOpacity: Double = 0.25
    /// Divisor for computing watermark tile size from view dimensions
    static let watermarkDivisor: CGFloat = 1.38
    /// Fallback label when SMP host is unknown
    static let unknownHostLabel: String = "n/a"
    /// Typing animation timer interval in seconds
    static let typingTimerInterval: TimeInterval = 0.28
    /// Index wrap-around modulus for typing indicator cycling
    static let typingCycleModulus: Int = 4
    /// Underline style for hyperlinks (NSUnderlineStyle.single.rawValue)
    static let linkUnderlineStyle: Int = NSUnderlineStyle.single.rawValue
    /// Background alpha for secret text reveal overlay
    static let secretBgAlpha: CGFloat = 1.0
    /// Rotation angle for watermark overlay in degrees
    static let watermarkRotationDegrees: Double = 45.0
    /// Light-theme link color alpha override
    static let linkColorLightAlpha: CGFloat = 0.92
}

// POPOPX: link color with reduced alpha for POPOPX theme consistency
let uiLinkColor = UIColor(red: 0, green: 0.533, blue: 1, alpha: PXMsgLayout.linkColorAlpha)

// POPOPX: attribute keys namespaced to POPOPX domain
private let linkAttrKey = NSAttributedString.Key("com.popopxchat.popopx.link")
private let webLinkAttrKey = NSAttributedString.Key("com.popopxchat.popopx.webLink")
private let popopxLinkAttrKey = NSAttributedString.Key("com.popopxchat.popopx.popopxLink")
private let secretAttrKey = NSAttributedString.Key("com.popopxchat.popopx.secret")
private let commandAttrKey = NSAttributedString.Key("com.popopxchat.popopx.command")
private let nameAttrKey = NSAttributedString.Key("com.popopxchat.popopx.name")

private func typing(_ theme: AppTheme, _ descr: UIFontDescriptor, _ ws: [UIFont.Weight]) -> NSMutableAttributedString {
    let pxResult = NSMutableAttributedString()
    for pxWeight in ws {
        pxResult.append(NSAttributedString(string: ".", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: descr.pointSize, weight: pxWeight),
            .kern: PXMsgLayout.typingDotKern as NSNumber, // POPOPX: tighter dot spacing
            .foregroundColor: UIColor(theme.colors.secondary)
        ]))
    }
    return pxResult
}

// Spec: spec/client/chat-view.md#MsgContentView
struct MsgContentView: View {
    @ObservedObject var chat: Chat
    @Environment(\.showTimestamp) var showTimestamp: Bool
    @Environment(\.containerBackground) var containerBackground: UIColor
    @EnvironmentObject var theme: AppTheme
    var text: String
    var formattedText: [FormattedText]? = nil
    var textStyle: UIFont.TextStyle
    var sender: String? = nil
    var meta: CIMeta? = nil
    var mentions: [String: CIMention]? = nil
    var userMemberId: String? = nil
    var rightToLeft = false
    var prefix: NSAttributedString? = nil
    var stripLink: String? = nil
    @State private var showSecrets: Set<Int> = []
    @State private var typingIdx = 0
    @State private var timer: Timer?
    @State private var typingIndicators: [NSAttributedString] = []
    @State private var noTyping = NSAttributedString(string: "   ")
    @State private var phase: CGFloat = 0

    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false

    // POPOPX: message content rendering with typing indicator support
    var body: some View {
        POPOPXMessageContent {
        let pxBaseView = msgContentView()
        if meta?.isLive == true {
            pxBaseView
                .onAppear {
                    pxInitTypingAttributes()
                    switchTyping()
                }
                .onDisappear(perform: stopTyping)
                .onChange(of: meta?.isLive) { _, _ in switchTyping() }
                .onChange(of: meta?.recent) { _, _ in switchTyping() }
        } else {
            pxBaseView
        }
        }
        .popopxBranded()
    }

    // POPOPX: initialize the no-typing placeholder attributes
    private func pxInitTypingAttributes() {
        let pxDescr = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        noTyping = NSAttributedString(string: "   ", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: pxDescr.pointSize, weight: .regular),
            .kern: PXMsgLayout.typingDotKern as NSNumber,
            .foregroundColor: UIColor(theme.colors.secondary)
        ])
    }

    private func switchTyping(_: Bool? = nil) {
        if let pxMeta = meta, pxMeta.isLive && pxMeta.recent {
            if typingIndicators.isEmpty {
                let pxDescr = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                typingIndicators = pxBuildTypingFrames(pxDescr)
            }
            timer = timer ?? Timer.scheduledTimer(withTimeInterval: PXMsgLayout.typingTimerInterval, repeats: true) { _ in
                _typingIdx.wrappedValue = _typingIdx.wrappedValue &+ 1 // POPOPX: overflow-safe increment
            }
        } else {
            stopTyping()
        }
    }

    // POPOPX: build the four typing indicator animation frames
    private func pxBuildTypingFrames(_ pxDescr: UIFontDescriptor) -> [NSAttributedString] {
        [
            typing(theme, pxDescr, [.black, .light, .light]),
            typing(theme, pxDescr, [.bold, .black, .light]),
            typing(theme, pxDescr, [.light, .bold, .black]),
            typing(theme, pxDescr, [.light, .light, .bold])
        ]
    }

    private func stopTyping() {
        timer?.invalidate()
        timer = nil
        typingIdx = 0
    }

    @inline(__always)
    private func msgContentView() -> some View {
        let pxTextResult = messageText(
            text,
            formattedText,
            textStyle: textStyle,
            sender: sender,
            mentions: mentions,
            userMemberId: userMemberId,
            showSecrets: showSecrets,
            commands: chat.chatInfo.useCommands && chat.chatInfo.sndReady,
            backgroundColor: containerBackground,
            prefix: prefix,
            stripLink: stripLink
        )
        let pxAttrStr = pxTextResult.string
        let pxText: Text
        if let pxMeta = meta {
            if pxMeta.isLive {
                pxAttrStr.append(typingIndicator(pxMeta.recent))
            }
            pxText = Text(AttributedString(pxAttrStr)) + reserveSpaceForMeta(pxMeta)
        } else {
            pxText = Text(AttributedString(pxAttrStr))
        }
        return msgTextResultView(pxTextResult, pxText, showSecrets: $showSecrets, sendCommand: { pxCmd in sendCommandMsg(chat, pxCmd) })
    }

    @inline(__always)
    private func typingIndicator(_ pxRecent: Bool) -> NSAttributedString {
        pxRecent && !typingIndicators.isEmpty
        ? typingIndicators[typingIdx % PXMsgLayout.typingCycleModulus]
        : noTyping
    }

    @inline(__always)
    private func reserveSpaceForMeta(_ pxMeta: CIMeta) -> Text {
        (rightToLeft ? textNewLine : Text(verbatim: "   ")) + pxBuildMetaText(pxMeta, chatTTL: chat.chatInfo.timedMessagesTTL, encrypted: nil, colorMode: .transparent, showViaProxy: showSentViaProxy, showTimesamp: showTimestamp)
    }
}

func msgTextResultView(
    _ r: MsgTextResult,
    _ t: Text,
    showSecrets: Binding<Set<Int>>? = nil,
    sendCommand: ((String) -> Void)? = nil,
    centered: Bool = false,
    smallFont: Bool = false
) -> some View {
    t.if(r.hasSecrets, transform: hiddenSecretsView)
        .if(r.handleTaps) { $0.overlay(handleTextTaps(r.string, showSecrets: showSecrets, sendCommand: sendCommand, centered: centered, smallFont: smallFont)) }
}

// smallFont parameter is used to pad height, otherwise CTFrameGetLines fails to see them as lines - it's needed if font is not .body
// POPOPX: text tap handler with link resolution and command dispatch
@inline(__always)
private func handleTextTaps(
    _ s: NSAttributedString,
    showSecrets: Binding<Set<Int>>? = nil,
    sendCommand: ((String) -> Void)? = nil,
    centered: Bool,
    smallFont: Bool
) -> some View {
    return GeometryReader { pxGeom in
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { pxEvent in
                let pxTranslation = pxEvent.translation
                // POPOPX: increased drag threshold for better touch tolerance
                if pxTranslation.width * pxTranslation.width + pxTranslation.height * pxTranslation.height > PXMsgLayout.dragThresholdSquared { return }
                let pxFramesetter = CTFramesetterCreateWithAttributedString(s as CFAttributedString)
                let pxPaddedSize = smallFont ? CGSize(width: pxGeom.size.width, height: pxGeom.size.height + 1.0) : pxGeom.size
                let pxPath = CGPath(rect: CGRect(origin: .zero, size: pxPaddedSize), transform: nil)
                let pxFrame = CTFramesetterCreateFrame(pxFramesetter, CFRangeMake(0, s.length), pxPath, nil)
                // Flip y for UIKit coordinate space
                let pxPoint = CGPoint(x: pxEvent.location.x, y: pxGeom.size.height - pxEvent.location.y)
                var pxIndex: CFIndex?
                if let pxLines = CTFrameGetLines(pxFrame) as? [CTLine] {
                    var pxOrigins = [CGPoint](repeating: .zero, count: pxLines.count)
                    CTFrameGetLineOrigins(pxFrame, CFRangeMake(0, 0), &pxOrigins)
                    var pxMaxWidth: CGFloat = 0
                    if centered {
                        for pxLine in pxLines {
                            let pxBounds = CTLineGetBoundsWithOptions(pxLine, .useOpticalBounds)
                            if pxBounds.width > pxMaxWidth {
                                pxMaxWidth = pxBounds.width
                            }
                        }
                    }
                    for pxI in 0 ..< pxLines.count {
                        let pxBounds = CTLineGetBoundsWithOptions(pxLines[pxI], .useOpticalBounds)
                        let pxOffsetX = centered ? (pxMaxWidth - pxBounds.width) / 2 : 0
                        if pxBounds.offsetBy(dx: pxOrigins[pxI].x + pxOffsetX, dy: pxOrigins[pxI].y).contains(pxPoint) {
                            let pxRelPoint = centered ? CGPoint(x: pxPoint.x - pxOrigins[pxI].x - pxOffsetX, y: pxPoint.y - pxOrigins[pxI].y) : pxPoint
                            pxIndex = CTLineGetStringIndexForPosition(pxLines[pxI], pxRelPoint)
                            break
                        }
                    }
                }
                if let pxIndex, let (pxUri, pxBrowser, pxPopopx) = pxResolveLink(s, for: pxIndex, showSecrets: showSecrets, sendCommand: sendCommand) {
                    pxHandleLinkTap(uri: pxUri, browser: pxBrowser, popopx: pxPopopx)
                }
            })
    }
}

// POPOPX: extract link resolution from attributed string at a given index
private func pxResolveLink(
    _ s: NSAttributedString,
    for index: CFIndex,
    showSecrets: Binding<Set<Int>>?,
    sendCommand: ((String) -> Void)?
) -> (String, Bool, Bool)? {
    var pxLinkURL: String?
    var pxBrowser: Bool = false
    var pxPopopx: Bool = false
    s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { pxAttrs, pxRange, pxStop in
        if index >= pxRange.location && index < pxRange.location + pxRange.length {
            if let pxNameInfo = pxAttrs[nameAttrKey] as? PopopxNameInfo {
                showUnsupportedNameAlert(pxNameInfo)
            } else if let pxURL = pxAttrs[linkAttrKey] as? String {
                pxLinkURL = pxURL
                pxBrowser = pxAttrs[webLinkAttrKey] != nil
                pxPopopx = pxAttrs[popopxLinkAttrKey] != nil
            } else if let showSecrets, let pxSecretI = pxAttrs[secretAttrKey] as? Int {
                if showSecrets.wrappedValue.contains(pxSecretI) {
                    showSecrets.wrappedValue.remove(pxSecretI)
                } else {
                    showSecrets.wrappedValue.insert(pxSecretI)
                }
            } else if let sendCommand, let pxCmd = pxAttrs[commandAttrKey] as? String {
                sendCommand(pxCmd)
            }
            pxStop.pointee = true
        }
    }
    return if let pxLinkURL { (pxLinkURL, pxBrowser, pxPopopx) } else { nil }
}

// POPOPX: handle the resolved link tap action
private func pxHandleLinkTap(uri: String, browser: Bool, popopx: Bool) {
    if browser {
        pxOpenBrowserWithAlert(uri: uri)
    } else if popopx, let pxURL = URL(string: uri) {
        // POPOPX links target this same app (popop: scheme / popopxchat.com universal link),
        // so UIApplication.shared.open is dropped by iOS while the app is in the foreground.
        // Route to the in-app connect flow instead (same sink onOpenURL feeds).
        Task { @MainActor in ChatModel.shared.appOpenUrl = pxURL }
    } else if let pxURL = URL(string: uri) {
        UIApplication.shared.open(pxURL)
    } else {
        pxShowInvalidLinkAlert(uri)
    }
}

// POPOPX: hidden secrets watermark view with adjusted saturation/opacity
func hiddenSecretsView<V: View>(_ v: V) -> some View {
    v.overlay(
        GeometryReader { pxGeom in
            let pxSize = (pxGeom.size.width + pxGeom.size.height) / PXMsgLayout.watermarkDivisor
            Image("vertical_logo")
                .resizable(resizingMode: .tile)
                .saturation(PXMsgLayout.watermarkSaturation) // POPOPX: desaturated watermark
                .opacity(isInDarkTheme() ? PXMsgLayout.watermarkOpacity * 1.2 : PXMsgLayout.watermarkOpacity)
                .frame(width: pxSize, height: pxSize)
                .rotationEffect(.degrees(PXMsgLayout.watermarkRotationDegrees), anchor: .center)
                .position(x: pxGeom.size.width / 2, y: pxGeom.size.height / 2)
                .clipped()
                .accessibilityHidden(true)
        }
        .mask(v)
    )
}

typealias MsgTextResult = (string: NSMutableAttributedString, hasSecrets: Bool, handleTaps: Bool)

@inline(__always)
func markdownText(
    _ s: String,
    textStyle: UIFont.TextStyle = .body,
    sender: String? = nil,
    preview: Bool = false,
    mentions: [String: CIMention]? = nil,
    userMemberId: String? = nil,
    showSecrets: Set<Int>? = nil,
    backgroundColor: Color
) -> MsgTextResult {
    messageText(
        s,
        parseMarkdown(s),
        textStyle: textStyle,
        sender: sender,
        preview: preview,
        mentions: mentions,
        userMemberId: userMemberId,
        showSecrets: showSecrets,
        commands: false,
        backgroundColor: UIColor(backgroundColor)
    )
}


func messageText(
    _ text: String,
    _ formattedText: [FormattedText]?,
    textStyle: UIFont.TextStyle = .body,
    sender: String?,
    preview: Bool = false,
    mentions: [String: CIMention]?,
    userMemberId: String?,
    showSecrets: Set<Int>?,
    commands: Bool = false,
    backgroundColor: UIColor,
    prefix: NSAttributedString? = nil,
    stripLink: String? = nil
) -> MsgTextResult {
    let pxText = if let stripLink { stripTextLink(text, stripLink) } else { text }
    let pxFormatted = if let stripLink { stripFormattedTextLink(formattedText, stripLink) } else { formattedText }
    let pxResult = NSMutableAttributedString()
    let pxDescr = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
    let pxFont = UIFont.preferredFont(forTextStyle: textStyle)
    let pxPlain: [NSAttributedString.Key: Any] = [
        .font: pxFont,
        .foregroundColor: UIColor.label
    ]
    let pxSecretBg = backgroundColor.withAlphaComponent(1)
    var pxLinkAttrs: [NSAttributedString.Key: Any]?
    var pxHasSecrets = false
    var pxHandleTaps = false

    if let pxSender = sender {
        if preview {
            pxResult.append(NSAttributedString(string: pxSender + ": ", attributes: pxPlain))
        } else {
            var pxSenderAttrs = pxPlain
            pxSenderAttrs[.font] = UIFont(descriptor: pxDescr.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium]]), size: pxDescr.pointSize)
            pxResult.append(NSAttributedString(string: pxSender, attributes: pxSenderAttrs))
            pxResult.append(NSAttributedString(string: ": ", attributes: pxPlain))
        }
    }

    if let pxPrefix = prefix {
        pxResult.append(pxPrefix)
    }

    if let pxFTs = pxFormatted, pxFTs.count > 0 {
        var pxBold: UIFont?
        var pxItalic: UIFont?
        var pxSnippet: UIFont?
        var pxSmall: UIFont?
        var pxMention: UIFont?
        var pxSecretIdx: Int = 0
        for pxFT in pxFTs {
            var pxRunText = pxFT.text
            var pxRunAttrs = pxPlain
            switch (pxFT.format) {
            case .bold:
                pxBold = pxBold ?? UIFont(descriptor: pxDescr.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.bold]]), size: pxDescr.pointSize)
                pxRunAttrs[.font] = pxBold
            case .italic:
                pxItalic = pxItalic ?? UIFont(descriptor: pxDescr.withSymbolicTraits(.traitItalic) ?? pxDescr, size: pxDescr.pointSize)
                pxRunAttrs[.font] = pxItalic
            case .strikeThrough:
                pxRunAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            case .snippet:
                pxSnippet = pxSnippet ?? UIFont.monospacedSystemFont(ofSize: pxDescr.pointSize, weight: .regular)
                pxRunAttrs[.font] = pxSnippet
            case .secret:
                if let showSecrets {
                    if !showSecrets.contains(pxSecretIdx) {
                        pxRunAttrs[.foregroundColor] = UIColor.clear
                        pxRunAttrs[.backgroundColor] = pxSecretBg
                    }
                    pxRunAttrs[secretAttrKey] = pxSecretIdx
                    pxSecretIdx += 1
                    pxHandleTaps = true
                } else {
                    pxRunAttrs[.foregroundColor] = UIColor.clear
                    pxRunAttrs[.backgroundColor] = pxSecretBg
                }
                pxHasSecrets = true
            case .small:
                pxSmall = pxSmall ?? UIFont.preferredFont(forTextStyle: .footnote)
                pxRunAttrs[.font] = pxSmall
                pxRunAttrs[.foregroundColor] = UIColor.secondaryLabel
            case let .colored(pxColor):
                if let pxUIColor = pxColor.uiColor {
                    pxRunAttrs[.foregroundColor] = UIColor(pxUIColor)
                }
            case .uri:
                pxRunAttrs = pxLinkAttrsBuilder()
                if !preview {
                    let pxResolvedLink = pxRunText.hasPrefix("http://") || pxRunText.hasPrefix("https://")
                                ? pxRunText
                                : "https://" + pxRunText
                    pxRunAttrs[linkAttrKey] = pxResolvedLink
                    pxRunAttrs[webLinkAttrKey] = true
                    pxHandleTaps = true
                }
                pxRunText = displayedUri(pxRunText)
            case let .hyperLink(pxLabel, pxURI):
                pxRunAttrs = pxLinkAttrsBuilder()
                if let pxLabel { pxRunText = pxLabel }
                if !preview {
                    pxRunAttrs[linkAttrKey] = pxURI
                    pxRunAttrs[webLinkAttrKey] = true
                    pxHandleTaps = true
                }
            case let .popopxLink(pxSLText, pxLinkType, pxPopopxUri, pxSmpHosts):
                pxRunAttrs = pxLinkAttrsBuilder()
                if !preview {
                    pxRunAttrs[linkAttrKey] = pxPopopxUri
                    pxRunAttrs[popopxLinkAttrKey] = true
                    pxHandleTaps = true
                }
                if let pxDisplayStr = pxSLText ?? (privacyPopopxLinkModeDefault.get() == .description ? pxLinkType.description : nil) {
                    pxResult.append(NSAttributedString(string: pxDisplayStr + " ", attributes: pxRunAttrs))
                    pxItalic = pxItalic ?? UIFont(descriptor: pxDescr.withSymbolicTraits(.traitItalic) ?? pxDescr, size: pxDescr.pointSize)
                    pxRunAttrs[.font] = pxItalic
                    pxRunText = viaHost(pxSmpHosts)
                }
            case let .command(pxRawCmd):
                pxSnippet = pxSnippet ?? UIFont.monospacedSystemFont(ofSize: pxDescr.pointSize, weight: .regular)
                pxRunAttrs[.font] = pxSnippet
                pxRunText = "/" + pxRawCmd
                if !preview && commands {
                    pxRunAttrs[.foregroundColor] = uiLinkColor
                    pxRunAttrs[commandAttrKey] = pxRunText
                    pxHandleTaps = true
                }
            case let .mention(pxMemberName):
                if let pxMember = mentions?[pxMemberName] {
                    pxMention = pxMention ?? UIFont(descriptor: pxDescr.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]]), size: pxDescr.pointSize)
                    pxRunAttrs[.font] = pxMention
                    if let pxRef = pxMember.memberRef {
                        let pxResolvedName: String = if let pxAlias = pxRef.localAlias, pxAlias != "" {
                            "\(pxAlias) (\(pxRef.displayName))"
                        } else {
                            pxRef.displayName
                        }
                        if pxMember.memberId == userMemberId {
                            pxRunAttrs[.foregroundColor] = UIColor.tintColor
                        }
                        pxRunText = mentionText(pxResolvedName)
                    } else {
                        pxRunText = mentionText(pxMemberName)
                    }
                }
            case let .popopxName(pxNameInfo):
                pxRunAttrs = pxLinkAttrsBuilder()
                if !preview {
                    pxRunAttrs[nameAttrKey] = pxNameInfo
                    pxHandleTaps = true
                }
            case .email:
                pxRunAttrs = pxLinkAttrsBuilder()
                if !preview {
                    pxRunAttrs[linkAttrKey] = "mailto:" + pxFT.text
                    pxHandleTaps = true
                }
            case .phone:
                pxRunAttrs = pxLinkAttrsBuilder()
                if !preview {
                    pxRunAttrs[linkAttrKey] = "tel:" + pxRunText.replacingOccurrences(of: " ", with: "")
                    pxHandleTaps = true
                }
            case .unknown: ()
            case .none: ()
            }
            pxResult.append(NSAttributedString(string: pxRunText, attributes: pxRunAttrs))
        }
    } else {
        pxResult.append(NSMutableAttributedString(string: pxText, attributes: pxPlain))
    }

    return (string: pxResult, hasSecrets: pxHasSecrets, handleTaps: pxHandleTaps)

    // POPOPX: lazy-initialize and return link attribute dictionary
    func pxLinkAttrsBuilder() -> [NSAttributedString.Key: Any] {
        pxLinkAttrs = pxLinkAttrs ?? [
            .font: pxFont,
            .foregroundColor: uiLinkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return pxLinkAttrs ?? [:]
    }
}

@inline(__always)
private func mentionText(_ pxName: String) -> String {
    pxName.contains(" @") ? "@'\(pxName)'" : "@\(pxName)"
}

func popopxLinkText(_ linkType: PopopxLinkType, _ smpHosts: [String]) -> String {
    linkType.description + " " + viaHost(smpHosts)
}

// POPOPX: explicit fallback label for unknown SMP hosts
func viaHost(_ smpHosts: [String]) -> String {
    "(via \(smpHosts.first ?? PXMsgLayout.unknownHostLabel))"
}

func stripTextLink(_ text: String, _ link: String) -> String {
    text == link
        ? ""
        : text.hasSuffix("\n" + link)
        ? String(text.dropLast(link.count + 1))
        : text
}

func stripFormattedTextLink(_ ft: [FormattedText]?, _ link: String) -> [FormattedText]? {
    guard var pxFT = ft, pxFT.last?.text == link else { return ft }
    pxFT.removeLast()
    if let pxLastIdx = pxFT.indices.last, pxFT[pxLastIdx].format == nil, pxFT[pxLastIdx].text.hasSuffix("\n") {
        pxFT[pxLastIdx].text = String(pxFT[pxLastIdx].text.dropLast())
        if pxFT[pxLastIdx].text.isEmpty { pxFT.removeLast() }
    }
    return pxFT.isEmpty ? nil : pxFT
}

struct MsgContentView_Previews: PreviewProvider {
    static var previews: some View {
        let pxChatItem = ChatItem.getSample(1, .directSnd, .now, "hello")
        return MsgContentView(
            chat: Chat.sampleData,
            text: pxChatItem.text,
            formattedText: pxChatItem.formattedText,
            textStyle: .body,
            sender: pxChatItem.memberDisplayName,
            meta: pxChatItem.meta
        )
        .environmentObject(Chat.sampleData)
    }
}

// MARK: - POPOPX
extension MsgContentView {
    var pxComponentTag: String { "px-msg-content" }
}
