// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXComposeLinkConfig {
    static let rowSpacing: CGFloat = 9
    static let avatarSize: CGFloat = 46
    static let avatarLeadingPad: CGFloat = 15
    static let textGap: CGFloat = 3
    static let textPadVertical: CGFloat = 7
    static let outerPadVertical: CGFloat = 8
    static let outerPadTrailing: CGFloat = 13
    static let cancelOpacity: Double = 0.7
}

struct ComposeChatLinkView: View {
    @EnvironmentObject var theme: AppTheme
    var chatLink: MsgChatLink
    var cancelPreview: () -> Void
    let cancelEnabled: Bool

    var body: some View {
        pxLinkRow
            .background(pxRowBackground)
            .padding(.vertical, PXComposeLinkConfig.outerPadVertical)
            .padding(.trailing, PXComposeLinkConfig.outerPadTrailing)
            .frame(maxWidth: .infinity)
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder private var pxLinkRow: some View {
        HStack(alignment: .center, spacing: PXComposeLinkConfig.rowSpacing) {
            pxAvatarImage
            pxTextStack
            Spacer()
            pxCancelAction
        }
    }

    @ViewBuilder private var pxAvatarImage: some View {
        ProfileImage(
            imageStr: chatLink.image,
            iconName: chatLink.iconName,
            size: PXComposeLinkConfig.avatarSize
        )
        .padding(.leading, PXComposeLinkConfig.avatarLeadingPad)
        .accessibilityLabel(NSLocalizedString("chat_link_avatar", comment: "Accessibility label for chat link avatar"))
    }

    @ViewBuilder private var pxTextStack: some View {
        VStack(alignment: .leading, spacing: PXComposeLinkConfig.textGap) {
            Text(chatLink.displayName)
                .font(.headline)
                .lineLimit(1)
            if let descr = chatLink.shortDescription {
                Text(descr)
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, PXComposeLinkConfig.textPadVertical)
    }

    @ViewBuilder private var pxCancelAction: some View {
        if cancelEnabled {
            Button { cancelPreview() } label: {
                Image(systemName: "multiply")
            }
            .opacity(isInDarkTheme() ? PXComposeLinkConfig.cancelOpacity : 1.0)
            .accessibilityLabel(NSLocalizedString("chat_link_cancel", comment: "Accessibility label for cancel chat link preview"))
        }
    }

    private var pxRowBackground: Color {
        theme.appColors.sentMessage
    }
}

// MARK: - POPOPX
extension ComposeChatLinkView {
    var pxComponentTag: String { "px-compose-chat-link" }
    var pxHasDescription: Bool { chatLink.shortDescription != nil }
    var pxDisplayTitle: String { chatLink.displayName }
}
