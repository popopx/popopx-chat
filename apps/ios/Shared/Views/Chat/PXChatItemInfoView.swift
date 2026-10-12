//
//  ChatItemInfoView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 09.05.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXInfoLayout {
    static let geometryInset: CGFloat = 34
    static let maxWidthFraction: CGFloat = 0.82
    static let bubbleHPad: CGFloat = 14
    static let bubbleVPad: CGFloat = 8
    static let forwardedAvatar: CGFloat = 50
    static let sectionGap: CGFloat = 18
    static let clipboardTTL: TimeInterval = 90
    static let deliveryMemberGap: CGFloat = 14
    static let memberAvatar: CGFloat = 32
    static let proxyIconOpacity: Double = 0.65
    static let versionStackGap: CGFloat = 4
    static let sectionHeaderBottomPad: CGFloat = 4
    static let glassDividerTopPad: CGFloat = 34
}

// Spec: spec/client/chat-view.md#ChatItemInfoView
struct ChatItemInfoView: View {
    @EnvironmentObject var chatModel: ChatModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: AppTheme
    var ci: ChatItem
    var userMemberId: String?
    @Binding var chatItemInfo: ChatItemInfo?
    @State private var selection: CIInfoTab = .history
    @State private var alert: CIInfoViewAlert? = nil
    @State private var messageStatusLimited: Bool = true
    @State private var fileStatusLimited: Bool = true
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false

    enum CIInfoTab {
        case history
        case quote
        case forwarded
        case delivery
    }

    enum CIInfoViewAlert: Identifiable {
        case alert(title: String, text: String)

        var id: String {
            switch self {
            case let .alert(title, text): return "alert \(title) \(text)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            pxTabbedContent
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showShareSheet(items: [pxFormattedShareText]) } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(NSLocalizedString("Share message info", comment: "Accessibility label for share button in message info view"))
                    }
                }
                .alert(item: $alert) { a in
                    switch(a) {
                    case let .alert(title, text): return Alert(title: Text(title), message: Text(text))
                    }
                }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX Computed Properties

    private var pxResolvedTitle: String {
        ci.localNote
        ? NSLocalizedString("Saved message", comment: "message info title")
        : ci.chatDir.sent
        ? NSLocalizedString("Sent message", comment: "message info title")
        : NSLocalizedString("Received message", comment: "message info title")
    }

    private var pxTabCount: Int {
        var count = 1
        if chatItemInfo?.memberDeliveryStatuses != nil { count += 1 }
        if ci.quotedItem != nil { count += 1 }
        if chatItemInfo?.forwardedFromChatItem != nil { count += 1 }
        return count
    }

    private var pxIsLocalChat: Bool {
        switch ci.chatDir {
        case .localSnd: true
        case .localRcv: true
        default: false
        }
    }

    private var pxSectionHeaderColor: Color {
        isInDarkTheme() ? darkThemeAccentColor() : .primary
    }

    private var pxFormattedShareText: String {
        pxBuildShareText()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder private var pxTabbedContent: some View {
        if pxTabCount > 1 {
            TabView(selection: $selection) {
                if let mdss = chatItemInfo?.memberDeliveryStatuses {
                    pxDeliveryTabContent(mdss)
                        .tabItem {
                            Label(NSLocalizedString("delivery_tab", comment: "Tab label for message delivery status"), systemImage: "checkmark.message")
                        }
                        .tag(CIInfoTab.delivery)
                }
                pxHistoryTabContent
                    .tabItem {
                        Label(NSLocalizedString("history_tab", comment: "Tab label for message history"), systemImage: "clock")
                    }
                    .tag(CIInfoTab.history)
                    .modifier(ThemedBackground())
                if let qi = ci.quotedItem {
                    pxQuoteTabContent(qi)
                        .tabItem {
                            Label(NSLocalizedString("in_reply_to_tab", comment: "Tab label for replied-to message"), systemImage: "arrowshape.turn.up.left")
                        }
                        .tag(CIInfoTab.quote)
                        .modifier(ThemedBackground())
                }
                if let forwardedFromItem = chatItemInfo?.forwardedFromChatItem {
                    pxForwardedTabContent(forwardedFromItem)
                        .tabItem {
                            Label(pxIsLocalChat ? NSLocalizedString("saved_message", comment: "Tab label for saved message") : NSLocalizedString("forwarded_message", comment: "Tab label for forwarded message"), systemImage: "arrowshape.turn.up.forward")
                        }
                        .tag(CIInfoTab.forwarded)
                        .modifier(ThemedBackground())
                }
            }
            .onAppear {
                if chatItemInfo?.memberDeliveryStatuses != nil {
                    selection = .delivery
                }
            }
        } else {
            pxHistoryTabContent
            .modifier(ThemedBackground())
        }
    }

    @ViewBuilder private var pxHistoryTabContent: some View {
        GeometryReader { g in
            let pxAvailableWidth = (g.size.width - PXInfoLayout.geometryInset) * PXInfoLayout.maxWidthFraction
            ScrollView {
                VStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
                    pxDetailsSection
                    GlassDivider().padding(.vertical)
                    pxHistorySection(pxAvailableWidth)
                }
                .padding()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - POPOPX Details Section

    private var pxDetailsSection: some View {
        let meta = ci.meta
        return VStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
            Text(pxResolvedTitle)
                .font(QuantumFonts.sectionHeader)
                .bold()
                .foregroundColor(pxSectionHeaderColor)
                .padding(.bottom)

            pxTimestampRows(meta)
            pxDeletionTimestampRows(meta)
            pxDisappearingRow(meta)
            if developerTools {
                pxDeveloperDetailsRows(meta)
            }
        }
    }

    @ViewBuilder private func pxTimestampRows(_ meta: CIMeta) -> some View {
        if ci.localNote {
            pxInfoRow("Created at", localTimestamp(meta.itemTs))
        } else {
            pxInfoRow("Sent at", localTimestamp(meta.itemTs))
        }
        if !ci.chatDir.sent {
            pxInfoRow("Received at", localTimestamp(meta.createdAt))
        }
    }

    @ViewBuilder private func pxDeletionTimestampRows(_ meta: CIMeta) -> some View {
        switch (meta.itemDeleted) {
        case let .deleted(deletedTs):
            if let deletedTs = deletedTs {
                pxInfoRow("Deleted at", localTimestamp(deletedTs))
            }
        case let .moderated(deletedTs, _):
            if let deletedTs = deletedTs {
                pxInfoRow("Moderated at", localTimestamp(deletedTs))
            }
        default: EmptyView()
        }
    }

    @ViewBuilder private func pxDisappearingRow(_ meta: CIMeta) -> some View {
        if let deleteAt = meta.itemTimed?.deleteAt {
            pxInfoRow("Disappears at", localTimestamp(deleteAt))
        }
    }

    // TODO [BLOCKED: msgVerified field not exposed in upstream FFI]
    //     let signedText: LocalizedStringKey = ci.chatDir.sent ? "Signed" : "Signed & verified"
    //     HStack {
    //         Label {
    //             Text(signedText)
    //         } icon: {
    //             Text(Image(systemName: "checkmark.seal")).foregroundColor(.secondary)
    //         }
    //         Spacer()
    //     }
    // } else if meta.msgVerified == .sigMissing {
    //     HStack {
    //         Label {
    //             Text("Signature missing")
    //         } icon: {
    //             Text(Image(systemName: "xmark.seal")).foregroundColor(QuantumColors.error)
    //         }
    //         Spacer()
    //     }
    // }

    private func pxDeveloperDetailsRows(_ meta: CIMeta) -> some View {
        VStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
            Divider().padding(.vertical)
            pxInfoRow("Database ID", "\(meta.itemId)")
            pxInfoRow("Record updated at", localTimestamp(meta.updatedAt))
            pxLimitedInfoRow("Message status", ci.meta.itemStatus.id, limited: $messageStatusLimited)
            if let file = ci.file {
                pxLimitedInfoRow("File status", file.fileStatus.id, limited: $fileStatusLimited)
            }
        }
    }

    private func pxLimitedInfoRow(_ label: String, _ value: String, limited: Binding<Bool>) -> some View {
        let row = pxInfoRow(LocalizedStringKey(label), value)
        return Group {
            if limited.wrappedValue {
                row.lineLimit(1)
            } else {
                row
            }
        }
        .onTapGesture {
            withAnimation {
                limited.wrappedValue.toggle()
            }
        }
    }

    // TODO [BLOCKED: fileXftpServers field not exposed in upstream FFI]
    // if ci.file != nil, let servers = chatItemInfo?.fileXftpServers, !servers.isEmpty {
    //     pxInfoRow("File servers", servers.map(serverHostname).joined(separator: "\n"))
    // }

    private func pxInfoRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - POPOPX History Section

    @ViewBuilder private func pxHistorySection(_ maxWidth: CGFloat) -> some View {
        if let chatItemInfo = chatItemInfo,
           !chatItemInfo.itemVersions.isEmpty {
            Text(NSLocalizedString("history_section", comment: "Section header for message history"))
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(pxSectionHeaderColor)
                .padding(.bottom, PXInfoLayout.sectionHeaderBottomPad)
            LazyVStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
                ForEach(Array(chatItemInfo.itemVersions.enumerated()), id: \.element.chatItemVersionId) { idx, itemVersion in
                    pxVersionBubble(itemVersion, maxWidth, isCurrent: idx == 0 && ci.meta.itemDeleted == nil)
                }
            }
        } else {
            Text(NSLocalizedString("no_history", comment: "Text when no message history exists"))
                .foregroundColor(theme.colors.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func pxVersionBubble(_ itemVersion: ChatItemVersion, _ maxBubbleWidth: CGFloat, isCurrent: Bool) -> some View {
        let pxBgColor = chatItemFrameColor(ci, theme)
        return VStack(alignment: .leading, spacing: PXInfoLayout.versionStackGap) {
            pxTextBubble(itemVersion.msgContent.text, itemVersion.formattedText, nil, backgroundColor: pxBgColor)
                .padding(.vertical, PXInfoLayout.bubbleVPad)
                .padding(.horizontal, PXInfoLayout.bubbleHPad)
                .background(pxBgColor)
                .modifier(ChatItemClipped())
                .contextMenu {
                    pxVersionContextMenu(itemVersion)
                }
            pxVersionTimestampLabel(itemVersion, isCurrent: isCurrent)
                .padding(.horizontal, PXInfoLayout.bubbleHPad)
        }
        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
    }

    @ViewBuilder private func pxVersionContextMenu(_ itemVersion: ChatItemVersion) -> some View {
        if itemVersion.msgContent.text != "" {
            Button {
                showShareSheet(items: [itemVersion.msgContent.text])
            } label: {
                Label(NSLocalizedString("share_action", comment: "Context menu action to share message"), systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.setItems([["public.utf8-plain-text": itemVersion.msgContent.text]], options: [.expirationDate: Date().addingTimeInterval(PXInfoLayout.clipboardTTL), .localOnly: true])
            } label: {
                Label(NSLocalizedString("copy_action", comment: "Context menu action to copy text"), systemImage: "doc.on.doc")
            }
        }
    }

    private func pxVersionTimestampLabel(_ itemVersion: ChatItemVersion, isCurrent: Bool) -> some View {
        let ts = localTimestamp(itemVersion.itemVersionTs)
        return (isCurrent ? Text("\(ts) \(NSLocalizedString("current_version", comment: "Label for current message version"))") : Text(ts))
            .foregroundStyle(.secondary)
            .font(.caption)
    }

    @ViewBuilder private func pxTextBubble(_ text: String, _ formattedText: [FormattedText]?, _ sender: String? = nil, backgroundColor: Color) -> some View {
        if text != "" {
            TextBubble(text: text, formattedText: formattedText, sender: sender, mentions: ci.mentions, userMemberId: userMemberId, backgroundColor: backgroundColor)
        } else {
            Text(NSLocalizedString("no_text_content", comment: "Placeholder when message has no text"))
                .italic()
                .foregroundColor(theme.colors.secondary)
        }
    }

    private struct TextBubble: View {
        @EnvironmentObject var theme: AppTheme
        var text: String
        var formattedText: [FormattedText]?
        var sender: String? = nil
        var mentions: [String: CIMention]?
        var userMemberId: String?
        var backgroundColor: Color
        @State private var showSecrets: Set<Int> = []

        var body: some View {
            let r = messageText(text, formattedText, sender: sender, mentions: mentions, userMemberId: userMemberId, showSecrets: showSecrets, backgroundColor: UIColor(backgroundColor))
            return msgTextResultView(r, Text(AttributedString(r.string)), showSecrets: $showSecrets)
        }
    }

    // MARK: - POPOPX Quote Tab

    @ViewBuilder private func pxQuoteTabContent(_ qi: CIQuote) -> some View {
        GeometryReader { g in
            let pxAvailableWidth = (g.size.width - PXInfoLayout.geometryInset) * PXInfoLayout.maxWidthFraction
            ScrollView {
                VStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
                    pxDetailsSection
                    GlassDivider().padding(.vertical)
                    Text(NSLocalizedString("in_reply_to_section", comment: "Section header for replied-to message"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(pxSectionHeaderColor)
                        .padding(.bottom, PXInfoLayout.sectionHeaderBottomPad)
                    pxQuotedBubble(qi, pxAvailableWidth)
                }
                .padding()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func pxQuotedBubble(_ qi: CIQuote, _ maxBubbleWidth: CGFloat) -> some View {
        let pxQuoteBg = quotedMsgFrameColor(qi, theme)
        return VStack(alignment: .leading, spacing: PXInfoLayout.versionStackGap) {
            pxTextBubble(qi.text, qi.formattedText, qi.getSender(nil), backgroundColor: pxQuoteBg)
                .padding(.vertical, PXInfoLayout.bubbleVPad)
                .padding(.horizontal, PXInfoLayout.bubbleHPad)
                .background(quotedMsgFrameColor(qi, theme))
                .modifier(ChatItemClipped())
                .contextMenu {
                    pxQuoteContextMenu(qi)
                }
            Text(localTimestamp(qi.sentAt))
                .foregroundStyle(.secondary)
                .font(.caption)
                .padding(.horizontal, PXInfoLayout.bubbleHPad)
        }
        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
    }

    @ViewBuilder private func pxQuoteContextMenu(_ qi: CIQuote) -> some View {
        if qi.text != "" {
            Button {
                showShareSheet(items: [qi.text])
            } label: {
                Label(NSLocalizedString("compose_share", comment: "Share quoted text button"), systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.setItems([["public.utf8-plain-text": qi.text]], options: [.expirationDate: Date().addingTimeInterval(PXInfoLayout.clipboardTTL), .localOnly: true])
            } label: {
                Label(NSLocalizedString("compose_copy", comment: "Copy quoted text button"), systemImage: "doc.on.doc")
            }
        }
    }

    func quotedMsgFrameColor(_ qi: CIQuote, _ theme: AppTheme) -> Color {
        (qi.chatDir?.sent ?? false)
        ? theme.appColors.sentMessage
        : theme.appColors.receivedMessage
    }

    // MARK: - POPOPX Forwarded Tab

    @ViewBuilder private func pxForwardedTabContent(_ forwardedFromItem: AChatItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
                pxDetailsSection
                GlassDivider().padding(.vertical)
                Text(pxIsLocalChat ? NSLocalizedString("chat_item_saved_from", comment: "Saved from header") : NSLocalizedString("chat_item_forwarded_from", comment: "Forwarded from header"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(pxSectionHeaderColor)
                    .padding(.bottom, PXInfoLayout.sectionHeaderBottomPad)
                pxForwardedSenderSection(forwardedFromItem)
            }
            .padding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func pxForwardedSenderSection(_ forwardedFromItem: AChatItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task {
                    await MainActor.run {
                        ItemsModel.shared.loadOpenChat(forwardedFromItem.chatInfo.id) {
                            dismiss()
                        }
                    }
                }
            } label: {
                pxForwardedSenderLabel(forwardedFromItem)
            }
            .accessibilityLabel(NSLocalizedString("Open chat of forwarded message", comment: "Accessibility label for forwarded message sender button"))

            if !pxIsLocalChat {
                GlassDivider().padding(.top, PXInfoLayout.glassDividerTopPad)
                Text(NSLocalizedString("recipients_cant_see_sender", comment: "Privacy notice that recipients can't see sender"))
                    .font(.caption)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    private func pxForwardedSenderLabel(_ forwardedFromItem: AChatItem) -> some View {
        HStack {
            ChatInfoImage(chat: Chat(chatInfo: forwardedFromItem.chatInfo), size: PXInfoLayout.forwardedAvatar)
                .padding(.trailing, 6)

            if forwardedFromItem.chatItem.chatDir.sent {
                pxSentForwardedLabel(forwardedFromItem)
            } else if case let .groupRcv(groupMember) = forwardedFromItem.chatItem.chatDir {
                pxGroupReceivedForwardedLabel(forwardedFromItem, groupMember)
            } else {
                NameWithBadge(
                    Text(forwardedFromItem.chatInfo.chatViewName).foregroundColor(theme.colors.onBackground),
                    forwardedFromItem.chatInfo.nameBadge
                )
                .lineLimit(1)
            }
        }
    }

    private func pxSentForwardedLabel(_ forwardedFromItem: AChatItem) -> some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("you_sent_label", comment: "Label indicating message was sent by you"))
                .italic()
                .foregroundColor(theme.colors.onBackground)
            NameWithBadge(
                Text(forwardedFromItem.chatInfo.chatViewName).foregroundColor(theme.colors.secondary),
                forwardedFromItem.chatInfo.nameBadge
            )
            .lineLimit(1)
        }
    }

    private func pxGroupReceivedForwardedLabel(_ forwardedFromItem: AChatItem, _ groupMember: GroupMember) -> some View {
        VStack(alignment: .leading) {
            NameWithBadge(
                Text(groupMember.chatViewName).foregroundColor(theme.colors.onBackground),
                groupMember.nameBadge
            )
            .lineLimit(1)
            NameWithBadge(
                Text(forwardedFromItem.chatInfo.chatViewName).foregroundColor(theme.colors.secondary),
                forwardedFromItem.chatInfo.nameBadge
            )
            .lineLimit(1)
        }
    }

    // MARK: - POPOPX Delivery Tab

    @ViewBuilder private func pxDeliveryTabContent(_ memberDeliveryStatuses: [MemberDeliveryStatus]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PXInfoLayout.sectionGap) {
                pxDetailsSection
                GlassDivider().padding(.vertical)
                Text(NSLocalizedString("delivery_section", comment: "Section header for delivery status"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(pxSectionHeaderColor)
                    .padding(.bottom, PXInfoLayout.sectionHeaderBottomPad)
                pxMemberStatusesList(memberDeliveryStatuses)
            }
            .padding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func pxMemberStatusesList(_ memberDeliveryStatuses: [MemberDeliveryStatus]) -> some View {
        LazyVStack(alignment: .leading, spacing: PXInfoLayout.deliveryMemberGap) {
            let pxStatuses = pxResolvedMemberStatuses(memberDeliveryStatuses)
            if !pxStatuses.isEmpty {
                ForEach(pxStatuses, id: \.0.groupMemberId) { pxMemberStatus in
                    pxSingleMemberStatusView(pxMemberStatus.0, pxMemberStatus.1, pxMemberStatus.2)
                }
            } else {
                Text(NSLocalizedString("no_delivery_info", comment: "Text when no delivery information available"))
                    .foregroundColor(theme.colors.secondary)
                    .accessibilityLabel(NSLocalizedString("No delivery information available", comment: "Accessibility label for empty delivery info"))
            }
        }
    }

    private func pxResolvedMemberStatuses(_ memberDeliveryStatuses: [MemberDeliveryStatus]) -> [(GroupMember, GroupSndStatus, Bool?)] {
        memberDeliveryStatuses.compactMap({ mds in
            if let mem = chatModel.getGroupMember(mds.groupMemberId) {
                return (mem.wrapped, mds.memberDeliveryStatus, mds.sentViaProxy)
            } else {
                return nil
            }
        })
    }

    private func pxSingleMemberStatusView(_ member: GroupMember, _ status: GroupSndStatus, _ sentViaProxy: Bool?) -> some View {
        HStack{
            MemberProfileImage(member, size: PXInfoLayout.memberAvatar)
                .padding(.trailing, 4)
            NameWithBadge(Text(member.chatViewName), member.nameBadge)
                .lineLimit(1)
            Spacer()
            if sentViaProxy == true {
                Image(systemName: "arrow.forward")
                    .foregroundColor(theme.colors.secondary)
                    .opacity(PXInfoLayout.proxyIconOpacity)
                    .accessibilityHidden(true)
            }
            let pxStatusGroup = Group {
                let (image, statusColor) = status.statusIcon(theme.colors.secondary, theme.colors.primary)
                image.foregroundColor(statusColor)
                    .accessibilityHidden(true)
            }

            if let (title, text) = status.statusInfo {
                pxStatusGroup.onTapGesture {
                    alert = .alert(title: title, text: text)
                }
            } else {
                pxStatusGroup
            }
        }
    }

    // MARK: - POPOPX Share Text Builder

    private func pxBuildShareText() -> String {
        let meta = ci.meta
        var pxLines: [String] = [String.localizedStringWithFormat(NSLocalizedString("# %@", comment: "copied message info title, # <title>"), pxResolvedTitle), ""]
        pxLines.append(pxTimestampShareLine(meta))
        pxLines.append(contentsOf: pxDeletionShareLines(meta))
        pxLines.append(contentsOf: pxDisappearingShareLine(meta))
        // TODO [BLOCKED: msgVerified field not exposed in upstream FFI]
        //     pxLines += [ci.chatDir.sent
        //         ? NSLocalizedString("Signed", comment: "copied message info")
        //         : NSLocalizedString("Signed & verified", comment: "copied message info")]
        // } else if meta.msgVerified == .sigMissing {
        //     pxLines += [NSLocalizedString("Signature missing", comment: "copied message info")]
        // }
        pxLines.append(contentsOf: pxDeveloperShareLines(meta))
        // TODO [BLOCKED: fileXftpServers field not exposed in upstream FFI]
        // if ci.file != nil, let servers = chatItemInfo?.fileXftpServers, !servers.isEmpty {
        //     pxLines += [String.localizedStringWithFormat(NSLocalizedString("File servers: %@", comment: "copied message info"), servers.map(serverHostname).joined(separator: ", "))]
        // }
        pxLines.append(contentsOf: pxQuoteShareLines())
        pxLines.append(contentsOf: pxHistoryShareLines())
        return pxLines.joined(separator: "\n")
    }

    private func pxTimestampShareLine(_ meta: CIMeta) -> String {
        String.localizedStringWithFormat(
            ci.localNote
                ? NSLocalizedString("Created at: %@", comment: "copied message info")
                : NSLocalizedString("Sent at: %@", comment: "copied message info"),
            localTimestamp(meta.itemTs))
    }

    private func pxDeletionShareLines(_ meta: CIMeta) -> [String] {
        var lines: [String] = []
        if !ci.chatDir.sent {
            lines.append(String.localizedStringWithFormat(NSLocalizedString("Received at: %@", comment: "copied message info"), localTimestamp(meta.createdAt)))
        }
        switch (ci.meta.itemDeleted) {
        case let .deleted(deletedTs):
            if let deletedTs = deletedTs {
                lines.append(String.localizedStringWithFormat(NSLocalizedString("Deleted at: %@", comment: "copied message info"), localTimestamp(deletedTs)))
            }
        case let .moderated(deletedTs, _):
            if let deletedTs = deletedTs {
                lines.append(String.localizedStringWithFormat(NSLocalizedString("Moderated at: %@", comment: "copied message info"), localTimestamp(deletedTs)))
            }
        default: ()
        }
        return lines
    }

    private func pxDisappearingShareLine(_ meta: CIMeta) -> [String] {
        if let deleteAt = meta.itemTimed?.deleteAt {
            return [String.localizedStringWithFormat(NSLocalizedString("Disappears at: %@", comment: "copied message info"), localTimestamp(deleteAt))]
        }
        return []
    }

    private func pxDeveloperShareLines(_ meta: CIMeta) -> [String] {
        guard developerTools else { return [] }
        var lines = [
            String.localizedStringWithFormat(NSLocalizedString("Database ID: %d", comment: "copied message info"), meta.itemId),
            String.localizedStringWithFormat(NSLocalizedString("Record updated at: %@", comment: "copied message info"), localTimestamp(meta.updatedAt)),
            String.localizedStringWithFormat(NSLocalizedString("Message status: %@", comment: "copied message info"), meta.itemStatus.id)
        ]
        if let file = ci.file {
            lines.append(String.localizedStringWithFormat(NSLocalizedString("File status: %@", comment: "copied message info"), file.fileStatus.id))
        }
        return lines
    }

    private func pxQuoteShareLines() -> [String] {
        guard let qi = ci.quotedItem else { return [] }
        var lines = ["", NSLocalizedString("## In reply to", comment: "copied message info"), ""]
        if let sender = qi.getSender(nil) {
            lines.append(String.localizedStringWithFormat(
                NSLocalizedString("%@ at %@:", comment: "copied message info, <sender> at <time>"),
                sender, localTimestamp(qi.sentAt)))
        } else {
            lines.append(String.localizedStringWithFormat(
                NSLocalizedString("%@:", comment: "copied message info"),
                localTimestamp(qi.sentAt)))
        }
        lines.append(qi.text != "" ? qi.text : NSLocalizedString("no text", comment: "copied message info in history"))
        return lines
    }

    private func pxHistoryShareLines() -> [String] {
        guard let chatItemInfo = chatItemInfo,
              !chatItemInfo.itemVersions.isEmpty else { return [] }
        var lines = ["", NSLocalizedString("## History", comment: "copied message info")]
        for (index, itemVersion) in chatItemInfo.itemVersions.enumerated() {
            let t = itemVersion.msgContent.text
            lines.append(contentsOf: [
                "",
                String.localizedStringWithFormat(
                    index == 0 && ci.meta.itemDeleted == nil
                    ? NSLocalizedString("%@ (current):", comment: "copied message info")
                    : NSLocalizedString("%@:", comment: "copied message info"),
                    localTimestamp(itemVersion.itemVersionTs)
                ),
                t != "" ? t : NSLocalizedString("no text", comment: "copied message info in history")
            ])
        }
        return lines
    }
}

private let _timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .medium
    return f
}()

func localTimestamp(_ date: Date) -> String {
    return _timestampFormatter.string(from: date)
}

struct ChatItemInfoView_Previews: PreviewProvider {
    static var previews: some View {
        ChatItemInfoView(ci: ChatItem.getSample(1, .directSnd, .now, "hello"), userMemberId: Chat.sampleData.chatInfo.groupInfo?.membership.memberId, chatItemInfo: Binding.constant(nil))
    }
}

// MARK: - POPOPX Component Identity
extension ChatItemInfoView {
    /// Unique POPOPX component tag for item info view diffing
    var pxComponentTag: String { "PX_CHAT_ITEM_INFO_VIEW" }

    /// Whether the current item has any quote or forwarded context
    var pxHasReplyContext: Bool {
        ci.quotedItem != nil || chatItemInfo?.forwardedFromChatItem != nil
    }

    /// POPOPX-specific tab count including delivery information
    var pxTotalTabCount: Int { pxTabCount }

    /// Resolved title exposed for external consumers
    var pxResolvedTitleExternal: String { pxResolvedTitle }

    /// Whether the chat direction is local
    var pxIsLocalExternal: Bool { pxIsLocalChat }
}
