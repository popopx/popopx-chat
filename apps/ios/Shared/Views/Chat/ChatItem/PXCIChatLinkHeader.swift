// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxLinkHeaderFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_LINK_HEADER_ENABLED")

// MARK: - POPOPX Layout & Style Configuration
private enum PXCIChatLinkConfig {
    static let verticalPadding: CGFloat = 8
    static let horizontalPadding: CGFloat = 14
    static let iconSize: CGFloat = 46
    static let profileSpacing: CGFloat = 6
    static let shadowRadius: CGFloat = 2
    static let animationMultiplier: Double = 0.8
    static let topProfilePadding: CGFloat = 10
    static let bottomProfilePadding: CGFloat = 8
    static let descriptionLineLimit: Int = 2
    static let descriptionBottomPadding: CGFloat = 2
    static let infoLineBottomPadding: CGFloat = 2
    static let metaSpacing: String = "   "
    static let secondaryDarkOpacity: Double = 0.82
}

// MARK: - POPOPX View Model
struct PXCIChatLinkViewModel {
    let chatLink: MsgChatLink
    let ownerSig: LinkOwnerSig?
    let hasText: Bool
    let chatItem: ChatItem

    var pxIsSigned: Bool { ownerSig != nil }
    var pxShortDescription: String? { chatLink.shortDescription }
    var pxDisplayName: String { chatLink.displayName }
    var pxFullName: String { chatLink.fullName }
    var pxShowsFullName: Bool { pxFullName != "" && pxFullName != pxDisplayName }
    var pxInfoLineText: String { chatLink.infoLine(signed: pxIsSigned) }
    var pxHasExistingText: Bool { hasText }

    var pxOpenHintText: Text {
        Text(NSLocalizedString("compose_tap_to_open", comment: "Tap to open chat link hint"))
    }
}

struct CIChatLinkHeader: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.showTimestamp) var showTimestamp: Bool
    var chatItem: ChatItem
    var chatLink: MsgChatLink
    var ownerSig: LinkOwnerSig?
    var hasText: Bool

    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false

    private var pxViewModel: PXCIChatLinkViewModel {
        PXCIChatLinkViewModel(
            chatLink: chatLink,
            ownerSig: ownerSig,
            hasText: hasText,
            chatItem: chatItem
        )
    }

    var body: some View {
        VStack(alignment: .leading) {
            pxLinkProfileView()
                .padding(.horizontal, PXCIChatLinkConfig.horizontalPadding)
                .padding(.top, PXCIChatLinkConfig.topProfilePadding)
                .padding(.bottom, PXCIChatLinkConfig.bottomProfilePadding)
                .overlay(DetermineWidth())
            GlassDivider()
            pxInfoSection()
                .overlay(DetermineWidth())
        }
        .padding(.horizontal, PXCIChatLinkConfig.horizontalPadding)
        .padding(.vertical, PXCIChatLinkConfig.verticalPadding)
        .accessibilityElement(children: .combine)
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private func pxInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let descr = pxViewModel.pxShortDescription {
                Text(descr)
                    .font(.footnote)
                    .foregroundColor(
                        isInDarkTheme()
                            ? theme.colors.secondary.opacity(PXCIChatLinkConfig.secondaryDarkOpacity)
                            : theme.colors.secondary
                    )
                    .lineLimit(PXCIChatLinkConfig.descriptionLineLimit)
                    .padding(.bottom, PXCIChatLinkConfig.descriptionBottomPadding)
            }
            Text(pxViewModel.pxInfoLineText)
                .font(.footnote)
                .foregroundColor(theme.colors.secondary)
                .padding(.bottom, PXCIChatLinkConfig.infoLineBottomPadding)
            pxOpenHintComposite()
        }
    }

    @ViewBuilder
    private func pxOpenHintComposite() -> some View {
        let t = pxViewModel.pxOpenHintText
            .foregroundColor(theme.colors.primary)
            .font(.callout)
        if pxViewModel.pxHasExistingText {
            t
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                t
                let pxMetaText: AttributedString = {
                    var pxResult = AttributedString(PXCIChatLinkConfig.metaSpacing)
                    pxResult += pxBuildMetaText(
                        chatItem.meta,
                        chatTTL: nil,
                        encrypted: nil,
                        colorMode: .transparent,
                        showStatus: false,
                        showEdited: false,
                        showViaProxy: showSentViaProxy,
                        showTimesamp: showTimestamp
                    )
                    return pxResult
                }()
                Text(pxMetaText)
            }
        }
    }

    private func pxLinkProfileView() -> some View {
        HStack(alignment: .top) {
            ProfileImage(
                imageStr: chatLink.image,
                iconName: chatLink.iconName,
                size: PXCIChatLinkConfig.iconSize,
                color: Color(uiColor: .tertiaryLabel)
            )
            .padding(.trailing, PXCIChatLinkConfig.profileSpacing)
            VStack(alignment: .leading) {
                Text(pxViewModel.pxDisplayName)
                    .font(.headline)
                    .lineLimit(PXCIChatLinkConfig.descriptionLineLimit)
                if pxViewModel.pxShowsFullName {
                    Text(pxViewModel.pxFullName)
                        .font(.subheadline)
                        .lineLimit(PXCIChatLinkConfig.descriptionLineLimit)
                }
            }
            .frame(minHeight: PXCIChatLinkConfig.iconSize)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(chatLink.displayName), \(NSLocalizedString("chat_link_profile", comment: "Chat link profile accessibility"))")
        )
    }
}

// MARK: - POPOPX
extension CIChatLinkHeader {
    static let pxComponentTag: String = "PX_CI_CHAT_LINK_HEADER"
    static let pxVerticalPadding: CGFloat = PXCIChatLinkConfig.verticalPadding
    static let pxHorizontalPadding: CGFloat = PXCIChatLinkConfig.horizontalPadding
    static let pxIconSize: CGFloat = PXCIChatLinkConfig.iconSize
    static let pxProfileSpacing: CGFloat = PXCIChatLinkConfig.profileSpacing
    static let pxShadowRadius: CGFloat = PXCIChatLinkConfig.shadowRadius
    static let pxAnimationMultiplier: Double = PXCIChatLinkConfig.animationMultiplier
}

extension CIChatLinkHeader {
    static var pxComponentIdentity: String { pxComponentTag }
}
