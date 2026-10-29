//
//  CIChatFeatureView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 21/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxFeatureIconAnimEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ICON_ANIM_ENABLED")

/// POPOPX: Layout and appearance configuration for feature views
private enum PXFeatureViewConfig {
    static let pxMergedHSpacing: CGFloat = 6
    static let pxMergedVPadding: CGFloat = 6
    static let pxFullHSpacing: CGFloat = 6
    static let pxFullVPadding: CGFloat = 8
    static let pxFullBottomAlignSpacing: CGFloat = 6
    static let pxShadowColor: Color = Color.black
    static let pxShadowOpacity: Double = 0.04
    static let pxShadowRadius: CGFloat = 1.5
    static let pxShadowYOffset: CGFloat = 0.5
    static let pxIconAnimDuration: Double = 0.2
    static let pxIconAnimScale: CGFloat = 0.92
}

// Spec: spec/client/chat-view.md#CIChatFeatureView
struct CIChatFeatureView: View {
    @EnvironmentObject var m: ChatModel
    @Environment(\.revealed) var revealed: Bool
    @ObservedObject var chat: Chat
    @ObservedObject var im: ItemsModel
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    var feature: Feature
    var icon: String? = nil
    var iconColor: Color

    var body: some View {
        pxFeatureContainer
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder private var pxFeatureContainer: some View {
        Group {
            if !revealed, let fs = pxMergedFeatureList() {
                pxMergedIconRow(fs)
            } else {
                pxFullFeatureDisplay
            }
        }
    }

    @ViewBuilder private func pxMergedIconRow(_ features: [FeatureInfo]) -> some View {
        HStack(spacing: PXFeatureViewConfig.pxMergedHSpacing) {
            ForEach(features, content: pxFeatureIconBuilder)
        }
        .padding(.horizontal, PXFeatureViewConfig.pxMergedHSpacing)
        .padding(.vertical, PXFeatureViewConfig.pxMergedVPadding)
        .accessibilityLabel(Text(NSLocalizedString("px_merged_features", comment: "Merged chat features indicator")))
    }

    private struct FeatureInfo: Identifiable {
        var icon: String
        var scale: CGFloat
        var color: Color
        var param: String?

        init(_ f: Feature, _ color: Color, _ param: Int?) {
            self.icon = f.iconFilled
            self.scale = f.iconScale
            self.color = color
            self.param = f.hasParam && param != nil ? timeText(param) : nil
        }

        var id: String {
            "\(icon) \(color) \(param ?? "")"
        }
    }

    private func pxMergedFeatureList() -> [FeatureInfo]? {
        var fs: [FeatureInfo] = []
        var icons: Set<String> = []
        if var i = m.getChatItemIndex(im, chatItem) {
            while i < im.reversedChatItems.count,
                  let f = pxFeatureInfoForItem(im.reversedChatItems[i]) {
                if !icons.contains(f.icon) {
                    fs.insert(f, at: 0)
                    icons.insert(f.icon)
                }
                i += 1
            }
        }
        return fs.count > 1 ? fs : nil
    }

    private func mergedFeatures() -> [FeatureInfo]? {
        pxMergedFeatureList()
    }

    private func pxFeatureInfoForItem(_ ci: ChatItem) -> FeatureInfo? {
        let pxSecondaryColor = theme.colors.secondary
        switch ci.content {
        case let .rcvChatFeature(feature, enabled, param):
            return FeatureInfo(feature, enabled.iconColor(pxSecondaryColor), param)
        case let .sndChatFeature(feature, enabled, param):
            return FeatureInfo(feature, enabled.iconColor(pxSecondaryColor), param)
        case let .rcvGroupFeature(feature, preference, param, role):
            return FeatureInfo(feature, preference.enabled(role, for: chat.chatInfo.groupInfo?.membership).iconColor(pxSecondaryColor), param)
        case let .sndGroupFeature(feature, preference, param, role):
            return FeatureInfo(feature, preference.enabled(role, for: chat.chatInfo.groupInfo?.membership).iconColor(pxSecondaryColor), param)
        default: return nil
        }
    }

    private func featureInfo(_ ci: ChatItem) -> FeatureInfo? {
        pxFeatureInfoForItem(ci)
    }

    @ViewBuilder private func pxFeatureIconBuilder(_ f: FeatureInfo) -> some View {
        let pxIcon = Image(systemName: f.icon)
            .foregroundColor(f.color)
            .scaleEffect(f.scale)
        if let param = f.param {
            HStack(spacing: 2) {
                pxIcon
                Text(chatEventText(AttributedString(param), theme.colors.secondary)).lineLimit(1)
            }
        } else {
            pxIcon
        }
    }

    @ViewBuilder private func featureIconView(_ f: FeatureInfo) -> some View {
        pxFeatureIconBuilder(f)
    }

    @ViewBuilder private var pxFullFeatureDisplay: some View {
        HStack(alignment: .bottom, spacing: PXFeatureViewConfig.pxFullBottomAlignSpacing) {
            pxFeatureIcon
            Text(chatEventText(chatItem, theme.colors.secondary))
        }
        .padding(.horizontal, PXFeatureViewConfig.pxFullVPadding)
        .padding(.vertical, PXFeatureViewConfig.pxFullHSpacing)
        .shadow(
            color: PXFeatureViewConfig.pxShadowColor.opacity(PXFeatureViewConfig.pxShadowOpacity),
            radius: PXFeatureViewConfig.pxShadowRadius,
            x: 0,
            y: PXFeatureViewConfig.pxShadowYOffset
        )
        .textSelection(.disabled)
        .accessibilityLabel(Text(NSLocalizedString("px_chat_feature_detail", comment: "Chat feature detail view")))
    }

    @ViewBuilder private var pxFeatureIcon: some View {
        Image(systemName: icon ?? feature.iconFilled)
            .foregroundColor(iconColor)
            .scaleEffect(feature.iconScale)
    }

    private var fullFeatureView: some View {
        pxFullFeatureDisplay
    }
}

struct CIChatFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        let enabled = FeatureEnabled(forUser: false, forContact: false)
        CIChatFeatureView(
            chat: Chat.sampleData,
            im: ItemsModel.shared,
            chatItem: ChatItem.getChatFeatureSample(.fullDelete, enabled), feature: ChatFeature.fullDelete, iconColor: enabled.iconColor(.secondary)
        ).environment(\.revealed, true)
    }
}

// MARK: - POPOPX
extension CIChatFeatureView {
    var pxComponentTag: String { "px-chat-feature" }
    var pxFeatureShadowOpacity: Double { PXFeatureViewConfig.pxShadowOpacity }
    var pxFeatureShadowRadius: CGFloat { PXFeatureViewConfig.pxShadowRadius }
    static let pxFeatureHSpacing: CGFloat = PXFeatureViewConfig.pxFullBottomAlignSpacing
    static let pxFeatureAnimDuration: Double = PXFeatureViewConfig.pxIconAnimDuration
}
