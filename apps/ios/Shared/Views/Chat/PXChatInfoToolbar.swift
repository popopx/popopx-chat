//
//  PXChatInfoToolbar.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 11/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration

private enum PXChatInfoToolbarConfig {
    static let incognitoIconSize: CGFloat = 26
    static let incognitoSpacerWidth: CGFloat = 18
    static let badgeFlagSize: CGFloat = 15
    static let toolbarFrameWidth: CGFloat = 225
    static let trailingPadding: CGFloat = 5
    static let fullNameTopPadding: CGFloat = -3
    static let subscriberTopPadding: CGFloat = -3
    static let subStatusLeadingPadding: CGFloat = 5
    static let displayNameFont: Font = .headline
    static let incognitoColor: Color = QuantumColors.accent
    static let darkThemeNameOpacity: Double = 0.88
    static let reportBadgeColors: [Color] = [.white, QuantumColors.error]
    static let supportBadgeRendering: SymbolRenderingMode = .palette
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXChatInfoToolbarViewModel {
    let chat: Chat

    var cInfo: ChatInfo { chat.chatInfo }
    var isIncognito: Bool { cInfo.incognito }
    var displayName: String { cInfo.displayName }
    var fullName: String { cInfo.fullName }
    var showsFullName: Bool { fullName != "" && displayName != fullName }
    var reportsCount: Int { chat.chatStats.reportsCount }
    var supportUnread: Int { chat.supportUnreadCount }
    var hasReportBadge: Bool { reportsCount > 0 }
    var hasSupportBadge: Bool { !hasReportBadge && supportUnread > 0 }
    var isContactVerified: Bool { cInfo.contact?.verified == true }

    var channelSubscriberCount: Int64? {
        if case let .group(groupInfo, _) = cInfo,
           groupInfo.useRelays,
           let count = groupInfo.groupSummary.publicMemberCount,
           count > 0 {
            count
        } else {
            nil
        }
    }

    var showsSubscriberCount: Bool { channelSubscriberCount != nil }
}

struct ChatInfoToolbar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var m: ChatModel
    @ObservedObject var chat: Chat
    var imageSize: CGFloat = 32

    private var pxVM: PXChatInfoToolbarViewModel {
        PXChatInfoToolbarViewModel(chat: chat)
    }

    var body: some View {
        HStack {
            if pxVM.isIncognito {
                pxIncognitoBadge
            }
            pxAvatarWithBadges
            pxNameSection
            if let contact = chat.chatInfo.contact,
               contact.ready && contact.active,
               let chatSubStatus = m.chatSubStatus,
               chatSubStatus != .active {
                SubStatusView(status: chatSubStatus)
                    .padding(.leading, PXChatInfoToolbarConfig.subStatusLeadingPadding)
            }
        }
        .foregroundColor(theme.colors.onBackground)
        .frame(width: PXChatInfoToolbarConfig.toolbarFrameWidth)
        .popopxBranded()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pxAccessibilityLabel)
    }

    // MARK: - POPOPX extracted view builders

    private var pxIncognitoBadge: some View {
        HStack(spacing: 0) {
            Image(systemName: "theatermasks")
                .foregroundColor(PXChatInfoToolbarConfig.incognitoColor)
                .frame(maxWidth: PXChatInfoToolbarConfig.incognitoIconSize, maxHeight: PXChatInfoToolbarConfig.incognitoIconSize, alignment: .center)
                .accessibilityLabel(Text(NSLocalizedString("a11y_incognito_mode_active", comment: "")))
            Spacer().frame(width: PXChatInfoToolbarConfig.incognitoSpacerWidth)
        }
    }

    private var pxAvatarWithBadges: some View {
        ZStack(alignment: .bottomTrailing) {
            ChatInfoImage(
                chat: chat,
                size: imageSize,
                color: Color(uiColor: .tertiaryLabel)
            )
            if pxVM.hasReportBadge {
                pxReportBadge
            } else if pxVM.hasSupportBadge {
                pxSupportBadge
            }
        }
        .padding(.trailing, PXChatInfoToolbarConfig.trailingPadding)
    }

    private var pxReportBadge: some View {
        Image(systemName: "flag.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white, QuantumColors.error)
            .frame(width: PXChatInfoToolbarConfig.badgeFlagSize, height: PXChatInfoToolbarConfig.badgeFlagSize)
            .symbolRenderingMode(PXChatInfoToolbarConfig.supportBadgeRendering)
            .accessibilityHidden(true)
    }

    private var pxSupportBadge: some View {
        Image(systemName: "flag.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white, theme.colors.primary)
            .frame(width: PXChatInfoToolbarConfig.badgeFlagSize, height: PXChatInfoToolbarConfig.badgeFlagSize)
            .symbolRenderingMode(PXChatInfoToolbarConfig.supportBadgeRendering)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var pxNameSection: some View {
        let nameColor = isInDarkTheme() ? darkThemeAccentColor() : theme.colors.onBackground
        let nameFont = darkThemeHeaderFont()
        if pxVM.isContactVerified {
            NameWithBadge(Text(pxVerifiedNameAttributedString(nameColor: nameColor, nameFont: nameFont)), pxVM.cInfo.nameBadge, .headline)
                .lineLimit(1)
                .if(pxVM.showsFullName) { v in
                    VStack(spacing: 0) {
                        v
                        Text(pxVM.fullName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.top, PXChatInfoToolbarConfig.fullNameTopPadding)
                    }
                }
                .if(pxVM.showsSubscriberCount) { v in
                    VStack(spacing: 0) {
                        v
                        if let count = pxVM.channelSubscriberCount {
                            Text(subscriberCountStr(count))
                                .foregroundColor(theme.colors.secondary)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.top, PXChatInfoToolbarConfig.subscriberTopPadding)
                        }
                    }
                }
        } else {
            NameWithBadge(Text(pxVM.displayName).foregroundColor(nameColor).font(nameFont), pxVM.cInfo.nameBadge, .headline)
                .lineLimit(1)
                .if(pxVM.showsFullName) { v in
                    VStack(spacing: 0) {
                        v
                        Text(pxVM.fullName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.top, PXChatInfoToolbarConfig.fullNameTopPadding)
                    }
                }
                .if(pxVM.showsSubscriberCount) { v in
                    VStack(spacing: 0) {
                        v
                        if let count = pxVM.channelSubscriberCount {
                            Text(subscriberCountStr(count))
                                .foregroundColor(theme.colors.secondary)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.top, PXChatInfoToolbarConfig.subscriberTopPadding)
                        }
                    }
                }
        }
    }

    private func pxVerifiedNameAttributedString(nameColor: Color, nameFont: Font) -> AttributedString {
        var pxName = AttributedString("\(Image(systemName: "checkmark.shield")) ")
        pxName.foregroundColor = theme.colors.secondary
        pxName.font = .caption
        var pxDisplayName = AttributedString(pxVM.displayName)
        pxDisplayName.foregroundColor = nameColor
        pxDisplayName.font = nameFont
        pxName += pxDisplayName
        return pxName
    }

    private var pxAccessibilityLabel: String {
        var parts = [pxVM.displayName]
        if pxVM.isIncognito { parts.append("incognito") }
        if pxVM.hasReportBadge { parts.append("\(pxVM.reportsCount) reports") }
        return parts.joined(separator: ", ")
    }

    struct SubStatusView: View {
        @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
        @EnvironmentObject var theme: AppTheme
        var status: SubscriptionStatus

        var body: some View {
            switch status {
            case .active: EmptyView()
            case .pending: ProgressView()
            case .removed: pxSubStatusError
            case .noSub: pxSubStatusError
            }
        }

        @ViewBuilder
        private var pxSubStatusError: some View {
            let dynamicChatInfoSize = dynamicSize(userFont).chatInfoSize
            Image(systemName: "exclamationmark.circle")
                .resizable()
                .scaledToFit()
                .foregroundColor(theme.colors.secondary)
                .frame(width: dynamicChatInfoSize, height: dynamicChatInfoSize)
                .accessibilityLabel(Text(NSLocalizedString("a11y_subscription_error", comment: "")))
        }
    }
}

public func subscriberCountStr(_ count: Int64) -> String {
    count == 1
        ? String.localizedStringWithFormat(NSLocalizedString("%d subscriber", comment: "channel subscriber count"), count)
        : String.localizedStringWithFormat(NSLocalizedString("%d subscribers", comment: "channel subscriber count"), count)
}

public func ownersContributorsCountStr(_ count: Int, withContributors: Bool) -> String {
    if withContributors {
        return String.localizedStringWithFormat(NSLocalizedString("%d owners & contributors", comment: "channel members count"), count)
    }
    return count == 1
        ? String.localizedStringWithFormat(NSLocalizedString("%d owner", comment: "channel owners count"), count)
        : String.localizedStringWithFormat(NSLocalizedString("%d owners", comment: "channel owners count"), count)
}

struct ChatInfoToolbar_Previews: PreviewProvider {
    static var previews: some View {
        ChatInfoToolbar(chat: Chat(chatInfo: ChatInfo.sampleData.direct, chatItems: []))
            .environmentObject(CurrentColors.toAppTheme())
    }
}

// MARK: - POPOPX
extension ChatInfoToolbar {
    var pxComponentTag: String { "PX_CHAT_INFO_TOOLBAR" }
    var pxIsIncognitoVisible: Bool { pxVM.isIncognito }
    var pxBadgeSummary: String {
        let reports = pxVM.reportsCount
        let unread = pxVM.supportUnread
        return reports > 0 ? "\(reports) reports" : "\(unread) unread"
    }
}
