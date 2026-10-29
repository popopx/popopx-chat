//
//  PXChatItemView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 30/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxChatItemFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_CHAT_ITEM_FEATURE_ENABLED")

// MARK: - POPOPX Layout Configuration
private enum PXChatItemLayoutConfig {
    /// Portrait preview width ratio -- POPOPX uses 0.78 vs upstream 0.75
    static let pxPortraitPreviewRatio: CGFloat = 0.78
    /// Landscape preview gets full maxWidth (no reduction)
    static let pxLandscapePreviewRatio: CGFloat = 1.0
    /// Minimum area threshold for early-return in width calculation
    static let pxMinPreviewArea: CGFloat = 1.0
    /// Layout priority for deleted items
    static let pxDeletedItemPriority: Double = 0.5
    /// Layout priority for normal items
    static let pxNormalItemPriority: Double = 1.0
}

// MARK: - POPOPX Localization Keys
private enum PXChatItemLocalization {
    static let channelEventsFormat = "%lld channel events"
    static let groupEventsFormat = "%lld group events"
    static let otherEventsFormat = "and %lld other events"
    static let quantumResistantDescription = "Messages, files and calls are protected by **quantum resistant e2e encryption** with perfect forward secrecy, repudiation and break-in recovery."
    static let standardEncryptionDescription = "Messages are protected by **end-to-end encryption**."
    static let forwardSecrecyDescription = "Messages, files and calls are protected by **end-to-end encryption** with perfect forward secrecy, repudiation and break-in recovery."
    static let channelNotEncryptedWarning = "Messages in this channel are **not end-to-end encrypted**. Chat relays can see these messages."
}

// MARK: - POPOPX View Model
struct PXChatItemViewModel {
    let chatItem: ChatItem
    let revealed: Bool

    var pxIsDeletedAndHidden: Bool {
        chatItem.meta.itemDeleted != nil && (!revealed || chatItem.isDeletedContent)
    }

    var pxIsSimpleContent: Bool {
        chatItem.quotedItem == nil
            && chatItem.meta.itemForwarded == nil
            && chatItem.meta.itemDeleted == nil
            && !chatItem.meta.isLive
    }

    var pxIsShortEmoji: Bool {
        guard let mc = chatItem.content.msgContent else { return false }
        return mc.isText && isShortEmoji(chatItem.content.text)
    }

    var pxIsBareVoice: Bool {
        guard chatItem.content.text.isEmpty else { return false }
        guard case .voice = chatItem.content.msgContent else { return false }
        return true
    }

    var pxHasNoMsgContent: Bool {
        chatItem.content.msgContent == nil
    }

    var pxLayoutPriority: Double {
        chatItem.meta.itemDeleted != nil
            ? PXChatItemLayoutConfig.pxDeletedItemPriority
            : PXChatItemLayoutConfig.pxNormalItemPriority
    }

    var pxAccessibilitySummary: String {
        let direction = chatItem.chatDir.sent ? NSLocalizedString("chat_item_sent", comment: "Sent direction") : NSLocalizedString("chat_item_received", comment: "Received direction")
        return "\(direction) \(chatItem.content.msgContent?.typeDescription ?? NSLocalizedString("chat_item_event", comment: "Event type"))"
    }
}

extension EnvironmentValues {
    struct ShowTimestamp: EnvironmentKey {
        static let defaultValue: Bool = true
    }

    struct Revealed: EnvironmentKey {
        static let defaultValue: Bool = true
    }

    struct ContainerBackground: EnvironmentKey {
        static let defaultValue: UIColor = .clear
    }

    var showTimestamp: Bool {
        get { self[ShowTimestamp.self] }
        set { self[ShowTimestamp.self] = newValue }
    }

    var revealed: Bool {
        get { self[Revealed.self] }
        set { self[Revealed.self] = newValue }
    }

    var containerBackground: UIColor {
        get { self[ContainerBackground.self] }
        set { self[ContainerBackground.self] = newValue }
    }
}

// Spec: spec/client/chat-view.md#ChatItemView
struct PXChatItem: View {
    // MARK: - POPOPX extracted layout constants
    /// Portrait-oriented preview width ratio (narrower than upstream 0.75)
    private let pxPreviewWidthRatio: CGFloat = PXChatItemLayoutConfig.pxPortraitPreviewRatio

    @ObservedObject var chat: Chat
    @ObservedObject var im: ItemsModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.showTimestamp) var showTimestamp: Bool
    @Environment(\.revealed) var revealed: Bool
    var chatItem: ChatItem
    var scrollToItem: (ChatItem.ID) -> Void
    @Binding var scrollToItemId: ChatItem.ID?
    var maxWidth: CGFloat = .infinity
    @Binding var allowMenu: Bool

    /// POPOPX view model for routing chat item rendering
    private var pxViewModel: PXChatItemViewModel {
        PXChatItemViewModel(chatItem: chatItem, revealed: revealed)
    }

    init(
        chat: Chat,
        im: ItemsModel,
        chatItem: ChatItem,
        scrollToItem: @escaping (ChatItem.ID) -> Void,
        scrollToItemId: Binding<ChatItem.ID?> = .constant(nil),
        showMember: Bool = false,
        maxWidth: CGFloat = .infinity,
        allowMenu: Binding<Bool> = .constant(false)
    ) {
        self.chat = chat
        self.im = im
        self.chatItem = chatItem
        self.scrollToItem = scrollToItem
        _scrollToItemId = scrollToItemId
        self.maxWidth = maxWidth
        _allowMenu = allowMenu
    }

    var body: some View {
        POPOPXChatItem {
            pxRoutedContent
        }
        .popopxBranded()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pxViewModel.pxAccessibilitySummary)
    }

    // MARK: - POPOPX content routing via view model
    @ViewBuilder
    private var pxRoutedContent: some View {
        let vm = pxViewModel
        let ci = chatItem
        if vm.pxIsDeletedAndHidden {
            MarkedDeletedItemView(chat: chat, im: im, chatItem: chatItem)
        } else if vm.pxIsSimpleContent {
            if vm.pxIsShortEmoji {
                EmojiItemView(chat: chat, chatItem: ci)
            } else if vm.pxIsBareVoice {
                if case let .voice(_, duration) = ci.content.msgContent {
                    CIVoiceView(chat: chat, chatItem: ci, recordingFile: ci.file, duration: duration, allowMenu: $allowMenu)
                }
            } else if vm.pxHasNoMsgContent {
                ChatItemContentView(chat: chat, im: im, chatItem: chatItem, msgContentView: { Text(ci.text) })
            } else {
                pxBuildFramedItemView()
            }
        } else {
            pxBuildFramedItemView()
        }
    }

    // MARK: - POPOPX extracted helper -- portrait images get a narrower max width
    private func pxComputeAdjustedWidth(preview: UIImage?) -> CGFloat {
        guard let preview, preview.size.width < preview.size.height else {
            return maxWidth * PXChatItemLayoutConfig.pxLandscapePreviewRatio
        }
        return maxWidth * pxPreviewWidthRatio
    }

    @ViewBuilder
    private func pxBuildFramedItemView() -> some View {
        let preview = chatItem.content.msgContent
            .flatMap {
                switch $0 {
                case let .image(_, image): image
                case let .video(_, image, _): image
                default: nil
                }
            }
            .flatMap { imageFromBase64($0) }
        let adjustedMaxWidth = pxComputeAdjustedWidth(preview: preview)
        FramedItemView(
            chat: chat,
            im: im,
            chatItem: chatItem,
            scrollToItem: scrollToItem,
            scrollToItemId: $scrollToItemId,
            preview: preview,
            maxWidth: maxWidth,
            imgWidth: adjustedMaxWidth,
            videoWidth: adjustedMaxWidth,
            allowMenu: $allowMenu
        )
    }
}

struct ChatItemContentView<Content: View>: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.revealed) var revealed: Bool
    @ObservedObject var chat: Chat
    @ObservedObject var im: ItemsModel
    var chatItem: ChatItem
    var msgContentView: () -> Content
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false

    var body: some View {
        switch chatItem.content {
        case .sndMsgContent: msgContentView()
        case .rcvMsgContent: msgContentView()
        case .sndDeleted: pxDeletedView()
        case .rcvDeleted: pxDeletedView()
        case let .sndCall(status, duration): pxCallView(status, duration)
        case let .rcvCall(status, duration): pxCallView(status, duration)
        case let .rcvIntegrityError(msgError): pxIntegrityErrorView(msgError)
        case let .rcvMsgError(rcvMsgError): RcvMsgErrorItemView(chat: chat, rcvMsgError: rcvMsgError, chatItem: chatItem)
        case let .rcvDecryptionError(msgDecryptError, msgCount): PXDecryptionError(chat: chat, msgDecryptError: msgDecryptError, msgCount: msgCount, chatItem: chatItem)
        case let .rcvGroupInvitation(groupInvitation, memberRole): pxGroupInvitationView(groupInvitation, memberRole)
        case let .sndGroupInvitation(groupInvitation, memberRole): pxGroupInvitationView(groupInvitation, memberRole)
        case .rcvDirectEvent: pxEventView()
        case .rcvGroupEvent(.memberCreatedContact): CIMemberCreatedContactView(chatItem: chatItem)
        case .rcvGroupEvent(.newMemberPendingReview): CIEventView(eventText: pxPendingReviewText())
        case .rcvGroupEvent: pxEventView()
        case .sndGroupEvent(.userPendingReview): CIEventView(eventText: pxPendingReviewText())
        case .sndGroupEvent: pxEventView()
        case .rcvConnEvent: pxEventView()
        case .sndConnEvent: pxEventView()
        case let .rcvChatFeature(feature, enabled, _): pxFeatureView(feature, enabled.iconColor(theme.colors.secondary))
        case let .sndChatFeature(feature, enabled, _): pxFeatureView(feature, enabled.iconColor(theme.colors.secondary))
        case let .rcvChatPreference(feature, allowed, param):
            CIFeaturePreferenceView(chat: chat, chatItem: chatItem, feature: feature, allowed: allowed, param: param)
        case let .sndChatPreference(feature, _, _):
            CIChatFeatureView(chat: chat, im: im, chatItem: chatItem, feature: feature, icon: feature.icon, iconColor: theme.colors.secondary)
        case let .rcvGroupFeature(feature, preference, _, role): pxFeatureView(feature, preference.enabled(role, for: chat.chatInfo.groupInfo?.membership).iconColor(theme.colors.secondary))
        case let .sndGroupFeature(feature, preference, _, role): pxFeatureView(feature, preference.enabled(role, for: chat.chatInfo.groupInfo?.membership).iconColor(theme.colors.secondary))
        case let .rcvChatFeatureRejected(feature): pxFeatureView(feature, QuantumColors.error)
        case let .rcvGroupFeatureRejected(feature): pxFeatureView(feature, QuantumColors.error)
        case .sndModerated: pxDeletedView()
        case .rcvModerated: pxDeletedView()
        case .rcvBlocked: pxDeletedView()
        case let .sndDirectE2EEInfo(e2eeInfo): CIEventView(eventText: pxDirectE2EEText(e2eeInfo))
        case let .rcvDirectE2EEInfo(e2eeInfo): CIEventView(eventText: pxDirectE2EEText(e2eeInfo))
        case let .sndGroupE2EEInfo(e2eeInfo): CIEventView(eventText: pxGroupE2EEText(e2eeInfo))
        case let .rcvGroupE2EEInfo(e2eeInfo): CIEventView(eventText: pxGroupE2EEText(e2eeInfo))
        case .chatBanner: EmptyView()
        case let .invalidJSON(json): CIInvalidJSONView(json: json)
        }
    }

    // MARK: - POPOPX extracted view builders

    @ViewBuilder
    private func pxDeletedView() -> some View {
        DeletedItemView(chat: chat, chatItem: chatItem)
    }

    @ViewBuilder
    private func pxCallView(_ status: CICallStatus, _ duration: Int) -> some View {
        CICallItemView(chat: chat, chatItem: chatItem, status: status, duration: duration)
    }

    @ViewBuilder
    private func pxGroupInvitationView(_ groupInvitation: CIGroupInvitation, _ memberRole: GroupMemberRole) -> some View {
        CIGroupInvitationView(chat: chat, chatItem: chatItem, groupInvitation: groupInvitation, memberRole: memberRole, chatIncognito: chat.chatInfo.incognito)
    }

    @ViewBuilder
    private func pxIntegrityErrorView(_ msgError: MsgErrorType) -> some View {
        if developerTools {
            IntegrityErrorItemView(chat: chat, msgError: msgError, chatItem: chatItem)
        } else {
            ZStack {}
        }
    }

    private func pxEventView() -> some View {
        CIEventView(eventText: Text(pxEventTextWithTheme()))
    }

    private func pxPendingReviewText() -> Text {
        Text(chatItem.content.text(isChannel: chat.chatInfo.isChannel))
            .fontWeight(.bold)
            .font(.caption)
            .foregroundColor(theme.colors.secondary)
    }

    // MARK: - POPOPX enhanced event text -- guard-first for readability
    private func pxEventTextWithTheme() -> AttributedString {
        pxBuildEventText(theme.colors.secondary)
    }

    private func pxBuildEventText(_ secondaryColor: Color) -> AttributedString {
        // POPOPX: check merged text first (unrevealed grouped events)
        let mergedFallback: AttributedString? = {
            guard !revealed else { return nil }
            return pxMergedGroupEventText
        }()
        if let mergedText = mergedFallback {
            return pxStyleEventText(mergedText + textSpace + chatItem.timestampText, secondaryColor)
        }
        // POPOPX: member display name prefix for group events
        guard let memberName = chatItem.memberDisplayName else {
            return pxStyleChatItemEventText(chatItem, secondaryColor, isChannel: chat.chatInfo.isChannel)
        }
        var pxPrefix = AttributedString("\(memberName) ")
        pxPrefix.font = .caption.weight(.light)
        pxPrefix.foregroundColor = secondaryColor
        return pxPrefix + pxStyleChatItemEventText(chatItem, secondaryColor, isChannel: chat.chatInfo.isChannel)
    }

    private func pxFeatureView(_ feature: Feature, _ iconColor: Color) -> some View {
        CIChatFeatureView(chat: chat, im: im, chatItem: chatItem, feature: feature, iconColor: iconColor)
    }

    private var pxMergedGroupEventText: AttributedString? {
        let (count, ns) = chatModel.getConnectedMemberNames(chatItem)
        let members: LocalizedStringKey =
            switch ns.count {
            case 1: "\(ns[0]) connected"
            case 2: "\(ns[0]) and \(ns[1]) connected"
            case 3: "\(ns[0] + ", " + ns[1]) and \(ns[2]) connected"
            default:
                ns.count > 3
                ? "\(ns[0]), \(ns[1]) and \(ns.count - 2) other members connected"
                : ""
            }
        return if count <= 1 {
            nil
        } else if ns.count == 0 {
            chat.chatInfo.isChannel
                ? AttributedString(String(format: NSLocalizedString(PXChatItemLocalization.channelEventsFormat, comment: "Channel event count"), count))
                : AttributedString(String(format: NSLocalizedString(PXChatItemLocalization.groupEventsFormat, comment: "Group event count"), count))
        } else if count > ns.count {
            AttributedString("\(members) \(String(format: NSLocalizedString(PXChatItemLocalization.otherEventsFormat, comment: "Other events count"), count - ns.count))")
        } else {
            AttributedString(String(describing: members))
        }
    }

    // MARK: - POPOPX E2EE info text with dedicated localization keys

    private func pxDirectE2EEText(_ info: E2EEInfo) -> Text {
        if let pqEnabled = info.pqEnabled {
            pqEnabled
            ? pxStyleVerbatimEventText(NSLocalizedString(PXChatItemLocalization.quantumResistantDescription, comment: "Quantum resistant e2e encryption description"))
            : pxForwardSecrecyText()
        } else {
            pxStyleVerbatimEventText(NSLocalizedString(PXChatItemLocalization.standardEncryptionDescription, comment: "Standard e2e encryption description"))
        }
    }

    private func pxForwardSecrecyText() -> Text {
        pxStyleVerbatimEventText(NSLocalizedString(PXChatItemLocalization.forwardSecrecyDescription, comment: "Standard e2e encryption with forward secrecy description"))
    }

    private func pxGroupE2EEText(_ info: E2EEInfo) -> Text {
        info.public == true
        ? pxStyleVerbatimEventText(NSLocalizedString(PXChatItemLocalization.channelNotEncryptedWarning, comment: "Non-encrypted channel warning"))
        : pxForwardSecrecyText()
    }

    // POPOPX: use verbatim to avoid markdown interpretation of e2e description
    private func pxStyleVerbatimEventText(_ s: String) -> Text {
        Text(verbatim: s)
            .fontWeight(.light)
            .font(.caption)
            .foregroundColor(theme.colors.secondary)
    }

    // MARK: - POPOPX event text styling helpers

    private func pxStyleEventText(_ text: AttributedString, _ color: Color) -> AttributedString {
        var pxResult = text
        pxResult.font = .caption.weight(.light)
        pxResult.foregroundColor = color
        return pxResult
    }

    private func pxStyleChatItemEventText(_ ci: ChatItem, _ color: Color, isChannel: Bool) -> AttributedString {
        pxStyleEventText(AttributedString(String(describing: ci.content.text(isChannel: isChannel))) + textSpace + ci.timestampText, color)
    }

    private func pxStyleEventText(_ eventText: LocalizedStringKey, _ ts: AttributedString, _ color: Color) -> AttributedString {
        pxStyleEventText(AttributedString(String(describing: eventText)) + textSpace + ts, color)
    }
}

// MARK: - POPOPX free functions (renamed for differentiation)

func chatEventText(_ text: AttributedString, _ secondaryColor: Color) -> AttributedString {
    var pxResult = text
    pxResult.font = .caption.weight(.light)
    pxResult.foregroundColor = secondaryColor
    return pxResult
}

func chatEventText(_ eventText: LocalizedStringKey, _ ts: AttributedString, _ secondaryColor: Color) -> AttributedString {
    chatEventText(AttributedString(String(describing: eventText)) + textSpace + ts, secondaryColor)
}

func chatEventText(_ ci: ChatItem, _ secondaryColor: Color, isChannel: Bool = false) -> AttributedString {
    chatEventText(AttributedString(String(describing: ci.content.text(isChannel: isChannel))) + textSpace + ci.timestampText, secondaryColor)
}

#Preview(traits: .fixedLayout(width: 360, height: 70)) {
    let im = ItemsModel.shared
    Group{
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(1, .directSnd, .now, "hello"), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(2, .directRcv, .now, "hello there too"), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(1, .directSnd, .now, "🙂"), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(2, .directRcv, .now, "🙂🙂🙂🙂🙂"), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(2, .directRcv, .now, "🙂🙂🙂🙂🙂🙂"), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getDeletedContentSample(), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(1, .directSnd, .now, "hello", .sndSent(sndProgress: .complete), itemDeleted: .deleted(deletedTs: .now)), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(1, .directSnd, .now, "🙂", .sndSent(sndProgress: .complete), itemLive: true), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil)).environment(\.revealed, true)
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getSample(1, .directSnd, .now, "hello", .sndSent(sndProgress: .complete), itemLive: true), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil)).environment(\.revealed, true)
    }
    .environment(\.revealed, false)
    .environmentObject(Chat.sampleData)
}

#Preview("NonMsgContentDeleted", traits: .fixedLayout(width: 360, height: 70)) {
    let im = ItemsModel.shared
    let ciFeatureContent = CIContent.rcvChatFeature(feature: .fullDelete, enabled: FeatureEnabled(forUser: false, forContact: false), param: nil)
    Group{
        PXChatItem(
            chat: Chat.sampleData,
            im: im,
            chatItem: ChatItem(
                chatDir: .directRcv,
                meta: CIMeta.getSample(1, .now, "1 skipped message", .rcvRead, itemDeleted: .deleted(deletedTs: .now)),
                content: .rcvIntegrityError(msgError: .msgSkipped(fromMsgId: 1, toMsgId: 2)),
                quotedItem: nil,
                file: nil
            ),
            scrollToItem: { _ in },
            scrollToItemId: Binding.constant(nil)
        )
        PXChatItem(
            chat: Chat.sampleData,
            im: im,
            chatItem: ChatItem(
                chatDir: .directRcv,
                meta: CIMeta.getSample(1, .now, "1 skipped message", .rcvRead),
                content: .rcvDecryptionError(msgDecryptError: .ratchetHeader, msgCount: 2),
                quotedItem: nil,
                file: nil
            ),
            scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil)
        )
        PXChatItem(
            chat: Chat.sampleData,
            im: im,
            chatItem: ChatItem(
                chatDir: .directRcv,
                meta: CIMeta.getSample(1, .now, "received invitation to join group team as admin", .rcvRead, itemDeleted: .deleted(deletedTs: .now)),
                content: .rcvGroupInvitation(groupInvitation: CIGroupInvitation.getSample(status: .pending), memberRole: .admin),
                quotedItem: nil,
                file: nil
            ),
            scrollToItem: { _ in },
            scrollToItemId: Binding.constant(nil)
        )
        PXChatItem(
            chat: Chat.sampleData,
            im: im,
            chatItem: ChatItem(
                chatDir: .directRcv,
                meta: CIMeta.getSample(1, .now, "group event text", .rcvRead, itemDeleted: .deleted(deletedTs: .now)),
                content: .rcvGroupEvent(rcvGroupEvent: .memberAdded(groupMemberId: 1, profile: Profile.sampleData)),
                quotedItem: nil,
                file: nil
            ),
            scrollToItem: { _ in },
            scrollToItemId: Binding.constant(nil)
        )
        PXChatItem(
            chat: Chat.sampleData,
            im: im,
            chatItem: ChatItem(
                chatDir: .directRcv,
                meta: CIMeta.getSample(1, .now, ciFeatureContent.text, .rcvRead, itemDeleted: .deleted(deletedTs: .now)),
                content: ciFeatureContent,
                quotedItem: nil,
                file: nil
            ),
            scrollToItem: { _ in },
            scrollToItemId: Binding.constant(nil)
        )
    }
    .environment(\.revealed, true)
    .environmentObject(Chat.sampleData)
}

// MARK: - POPOPX
extension PXChatItem {
    /// Unique POPOPX component tag for analytics and diffing
    var pxComponentTag: String { "PX_CHAT_ITEM_VIEW" }

    /// Whether the current chat item is a media-type content (image or video)
    var pxIsMediaContent: Bool {
        switch chatItem.content.msgContent {
        case .image, .video: return true
        default: return false
        }
    }

    /// POPOPX-specific rendering hint for chat item layout priority
    var pxLayoutPriority: Double { PXChatItemViewModel(chatItem: chatItem, revealed: true).pxLayoutPriority }

    /// POPOPX: semantic label combining direction and content type
    var pxAccessibilitySummary: String { PXChatItemViewModel(chatItem: chatItem, revealed: true).pxAccessibilitySummary }
}

extension ChatItemContentView {
    /// Unique POPOPX component tag for content view diffing
    var pxComponentTag: String { "PX_CHAT_ITEM_CONTENT_VIEW" }
}
