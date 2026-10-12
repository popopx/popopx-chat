//
//  ChatInfoImage.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 05/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout & Style Configuration
private enum PXChatInfoImageConfig {
    static let previewSize: CGFloat = 63
    static let defaultPreviewRed: Double = 0.9
    static let defaultPreviewGreen: Double = 0.9
    static let defaultPreviewBlue: Double = 0.9
    static let defaultPreviewColor: Color = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let defaultFallbackColor = Color(uiColor: .tertiarySystemGroupedBackground)
    static let darkThemeOverlayOpacity: Double = 0.12
    static let lightThemeOverlayOpacity: Double = 0.0
    static let accessibilityPrefix: String = "chat_info_image"
}

// MARK: - POPOPX View Model
@MainActor
struct PXChatInfoImageViewModel {
    let chat: Chat
    let size: CGFloat
    let color: Color

    var pxImageString: String? { chat.chatInfo.image }
    var pxIconName: String { chatIconName(chat.chatInfo) }
    var pxIsLocalChat: Bool {
        if case .local = chat.chatInfo { return true }
        return false
    }

    var pxResolvedColor: Color {
        pxIsLocalChat ? Color(uiColor: .tertiaryLabel) : color
    }

    var pxAccessibilityLabel: String {
        "\(PXChatInfoImageConfig.accessibilityPrefix)_\(pxIconName)"
    }
}

struct ChatInfoImage: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    var size: CGFloat
    var color = PXChatInfoImageConfig.defaultFallbackColor

    private var pxVM: PXChatInfoImageViewModel {
        PXChatInfoImageViewModel(chat: chat, size: size, color: color)
    }

    var body: some View {
        let iconColor = pxIsLocalChatThemed
            ? theme.appColors.primaryVariant2
            : pxVM.pxResolvedColor
        return pxProfileImageView(iconColor: iconColor)
    }

    // MARK: - POPOPX Helpers

    private var pxIsLocalChatThemed: Bool {
        if case .local = chat.chatInfo { return true }
        return false
    }

    @ViewBuilder
    private func pxProfileImageView(iconColor: Color) -> some View {
        ProfileImage(
            imageStr: pxVM.pxImageString,
            iconName: pxVM.pxIconName,
            size: size,
            color: iconColor
        )
        .overlay(
            Circle()
                .stroke(
                    isInDarkTheme()
                        ? Color.white.opacity(PXChatInfoImageConfig.darkThemeOverlayOpacity)
                        : Color.clear.opacity(PXChatInfoImageConfig.lightThemeOverlayOpacity),
                    lineWidth: 0.5
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(pxVM.pxAccessibilityLabel))
        .popopxBranded()
    }
}

struct ChatInfoImage_Previews: PreviewProvider {
    static var previews: some View {
        ChatInfoImage(
            chat: Chat(chatInfo: ChatInfo.sampleData.direct, chatItems: []),
            size: PXChatInfoImageConfig.previewSize,
            color: PXChatInfoImageConfig.defaultPreviewColor
        )
        .previewLayout(.fixed(width: PXChatInfoImageConfig.previewSize, height: PXChatInfoImageConfig.previewSize))
    }
}

// MARK: - POPOPX
extension ChatInfoImage {
    static let pxComponentTag: String = "PX_CHAT_INFO_IMAGE"
    static let pxPreviewSize: CGFloat = PXChatInfoImageConfig.previewSize
    static let pxDefaultPreviewColor = Color(
        red: PXChatInfoImageConfig.defaultPreviewRed,
        green: PXChatInfoImageConfig.defaultPreviewGreen,
        blue: PXChatInfoImageConfig.defaultPreviewBlue
    )
}

extension ChatInfoImage {
    static var pxComponentIdentity: String { pxComponentTag }
}
