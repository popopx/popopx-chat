//
//  ChatItemClipShape.swift
//  POPOPX (iOS)
//
//  Created by Levitating Pineapple on 04/07/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxBubbleGlossFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_BUBBLE_GLOSS_FEATURE_ENABLED")

/// POPOPX: Bubble appearance configuration
private enum PXBubbleConfig {
    static let pxGlossLightOpacity: Double = 0.13
    static let pxGlossDarkOpacity: Double = 0.08
    static let pxGlossStartPoint: UnitPoint = .top
    static let pxGlossEndPoint: UnitPoint = .center
    static let pxDefaultCornerRx: Double = 10
    static let pxShadowOpacity: Double = 0.05
    static let pxShadowRadius: CGFloat = 2.5
    static let pxShadowYOffset: CGFloat = 1
    static let pxCornerAdjustment: Double = 1.0
    static let pxIridescentCornerRadiusMultiplier: Double = 1.0
}

/// Modifier, which provides clipping mask for ``ChatItemWithMenu`` view 
/// and it's previews: (drag interaction, context menu, etc.)
/// Supports [Dynamic Type](https://developer.apple.com/documentation/uikit/uifont/scaling_fonts_automatically)
/// by retaining pill shape, even when ``ChatItem``'s height is less that twice its corner radius
struct ChatItemClipped: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_CHAT_ITEM_ROUNDNESS) private var roundness = defaultChatItemRoundness
    @AppStorage(DEFAULT_CHAT_ITEM_TAIL) private var tailEnabled = true
    private let chatItem: (content: CIContent, chatDir: CIDirection)?
    private let tailVisible: Bool
    private let pxIsUnread: Bool
    private let pxTTLProgress: Double?
    private let pxDeleteAt: Date?
    private let pxTTL: TimeInterval?
    private let pxIsIncoming: Bool

    init() {
        self.chatItem = nil
        self.tailVisible = false
        self.pxIsUnread = false
        self.pxTTLProgress = nil
        self.pxDeleteAt = nil
        self.pxTTL = nil
        self.pxIsIncoming = false
    }

    init(_ ci: ChatItem, tailVisible: Bool, isUnread: Bool = false, ttlProgress: Double? = nil) {
        self.chatItem = (ci.content, ci.chatDir)
        self.tailVisible = tailVisible
        self.pxIsUnread = isUnread
        self.pxTTLProgress = ttlProgress
        self.pxIsIncoming = !ci.chatDir.sent
        self.pxDeleteAt = ci.meta.itemTimed?.deleteAt
        self.pxTTL = ci.meta.itemTimed.map { TimeInterval($0.ttl) }
    }

    /// Remaining seconds until deletion, computed live
    private var pxRemainingSeconds: Int {
        guard let deleteAt = pxDeleteAt else { return 0 }
        return max(Int(deleteAt.timeIntervalSince(Date())), 0)
    }

    /// TTL progress: uses explicit value if provided, otherwise computes from stored dates
    private var pxOverlayTTLProgress: Double {
        if let explicit = pxTTLProgress { return explicit }
        guard let deleteAt = pxDeleteAt,
              let ttl = pxTTL, ttl > 0 else { return 0 }
        let remaining = deleteAt.timeIntervalSince(Date())
        let elapsed = ttl - remaining
        return min(max(elapsed / ttl, 0), 1.0)
    }
    
    private func pxComputeShapeStyle() -> ChatItemShape.Style {
        guard let ci = chatItem else {
            return .roundRect(radius: msgRectMaxRadius)
        }
        switch ci.content {
        case
                .sndMsgContent,
                .rcvMsgContent,
                .rcvDecryptionError,
                .rcvIntegrityError,
                .rcvMsgError,
                .invalidJSON:
            let tail = if let mc = ci.content.msgContent, mc.isImageOrVideo && mc.text.isEmpty {
                false
            } else {
                tailVisible
            }
            return tailEnabled
            ? .bubble(
                padding: ci.chatDir.sent ? .trailing : .leading,
                tailVisible: tail
            )
            : .roundRect(radius: msgRectMaxRadius)
        case .rcvGroupInvitation, .sndGroupInvitation:
            return .roundRect(radius: msgRectMaxRadius)
        default:
            return .roundRect(radius: PXBubbleConfig.pxDefaultCornerRx)
        }
    }

    private func shapeStyle() -> ChatItemShape.Style {
        pxComputeShapeStyle()
    }

    func body(content: Content) -> some View {
        let clipShape = ChatItemShape(
            roundness: roundness,
            style: pxComputeShapeStyle()
        )
        content
            .contentShape(.dragPreview, clipShape)
            .contentShape(.contextMenuPreview, clipShape)
            .clipShape(clipShape)
            .overlay(
                pxGlossOverlay(for: clipShape)
            )
            .iridescentBubble(
                isUnread: pxIsUnread,
                ttlProgress: pxTTLProgress,
                isIncoming: pxIsIncoming
            )
            .overlay(
                IridescentCountdownOverlay(
                    ttlProgress: pxOverlayTTLProgress,
                    remainingSeconds: pxRemainingSeconds
                )
            )
            .iridescentEdge(
                isUnread: pxIsUnread,
                cornerRadius: msgRectMaxRadius * roundness
            )
            .popopxBranded()
    }

    // MARK: - POPOPX Overlay Builders

    @ViewBuilder private func pxGlossOverlay(for clipShape: ChatItemShape) -> some View {
        let glossOpacity = pxComputeGlossOpacity()
        clipShape
            .fill(
                LinearGradient(
                    colors: [
                        theme.colors.background.opacity(glossOpacity),
                        Color.clear
                    ],
                    startPoint: PXBubbleConfig.pxGlossStartPoint,
                    endPoint: PXBubbleConfig.pxGlossEndPoint
                )
            )
            .allowsHitTesting(false)
    }

    private func pxComputeGlossOpacity() -> Double {
        if isInDarkTheme() {
            return PXBubbleConfig.pxGlossDarkOpacity
        }
        return PXBubbleConfig.pxGlossLightOpacity
    }
}

// MARK: - POPOPX
extension ChatItemClipped {
    var pxComponentTag: String { "PX_CHAT_ITEM_CLIPPED" }
    var pxClipCornerAdjustment: Double { PXBubbleConfig.pxCornerAdjustment }
}

private let pxBubbleGlossLightOpacity: Double = PXBubbleConfig.pxGlossLightOpacity
private let pxBubbleGlossDarkOpacity: Double = PXBubbleConfig.pxGlossDarkOpacity
private let pxGlossStartPoint: UnitPoint = PXBubbleConfig.pxGlossStartPoint
private let pxGlossEndPoint: UnitPoint = PXBubbleConfig.pxGlossEndPoint
private let pxDefaultShapeCornerRx: Double = PXBubbleConfig.pxDefaultCornerRx
private let pxShadowOpacity: Double = PXBubbleConfig.pxShadowOpacity
private let pxShadowRadius: CGFloat = PXBubbleConfig.pxShadowRadius

struct ChatTailPadding: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, -msgTailWidth)
    }
}

let msgRectMaxRadius: Double = 18
private let msgBubbleMaxRadius: Double = msgRectMaxRadius * 1.2
private let msgTailWidth: Double = 9
private let msgTailMinHeight: Double = msgTailWidth * 1.254 // ~56deg
private let msgTailMaxHeight: Double = msgTailWidth * 1.732 // 60deg

struct ChatItemShape: Shape {
    fileprivate enum Style {
        case bubble(padding: HorizontalEdge, tailVisible: Bool)
        case roundRect(radius: Double)
    }

    fileprivate let roundness: Double
    fileprivate let style: Style

    func path(in rect: CGRect) -> Path {
        switch style {
        case let .bubble(padding, tailVisible):
            return pxBuildBubblePath(in: rect, padding: padding, tailVisible: tailVisible)
        case let .roundRect(radius):
            return Path(roundedRect: rect, cornerRadius: radius * roundness)
        }
    }

    /// POPOPX: Extracted bubble path construction
    private func pxBuildBubblePath(in rect: CGRect, padding: HorizontalEdge, tailVisible: Bool) -> Path {
        let w = rect.width
        let h = rect.height
        let rxMax = min(msgBubbleMaxRadius, w / 2)
        let ryMax = min(msgBubbleMaxRadius, h / 2)
        let rx = roundness * rxMax
        let ry = roundness * ryMax
        let tailHeight = min(msgTailMinHeight + roundness * (msgTailMaxHeight - msgTailMinHeight), h / 2)
        var path = Path()
        // top side
        path.move(to: CGPoint(x: rx, y: 0))
        path.addLine(to: CGPoint(x: w - rx, y: 0))
        if roundness > 0 {
            path.addQuadCurve(to: CGPoint(x: w, y: ry), control: CGPoint(x: w, y: 0))
        }
        if rect.height > 2 * ry {
            path.addLine(to: CGPoint(x: w, y: h - ry))
        }
        if roundness > 0 {
            path.addQuadCurve(to: CGPoint(x: w - rx, y: h), control: CGPoint(x: w, y: h))
        }
        // bottom side
        if tailVisible {
            path.addLine(to: CGPoint(x: -msgTailWidth, y: h))
            if roundness > 0 {
                let d = tailHeight - msgTailWidth * msgTailWidth / tailHeight
                let tc = CGPoint(x: 0, y: h - tailHeight + d * sqrt(roundness))
                path.addQuadCurve(to: CGPoint(x: 0, y: h - tailHeight), control: tc)
            } else {
                path.addLine(to: CGPoint(x: 0, y: h - tailHeight))
            }
            if rect.height > ry + tailHeight {
                path.addLine(to: CGPoint(x: 0, y: ry))
            }
        } else {
            path.addLine(to: CGPoint(x: rx, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - ry), control: CGPoint(x: 0 , y: h))
            if rect.height > 2 * ry {
                path.addLine(to: CGPoint(x: 0, y: ry))
            }
        }
        if roundness > 0 {
            path.addQuadCurve(to: CGPoint(x: rx, y: 0), control: CGPoint(x: 0, y: 0))
        }
        path.closeSubpath()
        return pxApplyPaddingFlip(path, padding: padding)
    }

    private func pxApplyPaddingFlip(_ path: Path, padding: HorizontalEdge) -> Path {
        switch padding {
        case .leading: return path
        case .trailing:
            return path.scale(x: -1, y: 1, anchor: .center).path(in: CGRect(
                x: 0, y: 0,
                width: path.boundingRect.width,
                height: path.boundingRect.height
            ))
        }
    }

    var offset: Double? {
        switch style {
        case let .bubble(padding, isTailVisible):
            if isTailVisible {
                switch padding {
                case .leading: -msgTailWidth
                case .trailing: msgTailWidth
                }
            } else { 0 }
        case .roundRect: 0
        }
    }

    /// POPOPX: Computed tail height based on roundness and constraints
    fileprivate static func pxTailHeight(roundness: Double, maxHeight: Double) -> Double {
        let pxRawHeight = msgTailMinHeight + roundness * (msgTailMaxHeight - msgTailMinHeight)
        return min(pxRawHeight, maxHeight)
    }

}
