//
//  ChatBannerView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ChatBannerView: View {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_CHAT_ITEM_ROUNDNESS) private var roundness = defaultChatItemRoundness
    @ObservedObject var chat: Chat
    @State private var showSecrets: Set<Int> = []

    var body: some View {
        let v = VStack(spacing: 8) {
            ChatInfoImage(chat: chat, size: alertProfileImageSize)

            let badge = chat.chatInfo.nameBadge
            NameWithBadge(Text(chat.chatInfo.displayName).font(.title3), badge, .title3) { if let badge { showBadgeInfoAlert(chat.chatInfo.displayName, badge) } }
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 240)

            let fullName = chat.chatInfo.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if fullName != "" && fullName != chat.chatInfo.displayName && fullName != chat.chatInfo.displayName.trimmingCharacters(in: .whitespacesAndNewlines) {
                Text(chat.chatInfo.fullName)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)
            }

            if let shortDescr = chat.chatInfo.shortDescr {
                let r = markdownText(shortDescr, textStyle: .subheadline, showSecrets: showSecrets, backgroundColor: theme.colors.background)
                msgTextResultView(r, Text(AttributedString(r.string)), showSecrets: $showSecrets, centered: true, smallFont: true)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }

            if let chatContext {
                Text(chatContext)
                    .font(.callout)
                    .foregroundColor(theme.colors.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(theme.appColors.receivedMessage)
        .clipShape(RoundedRectangle(cornerRadius: msgRectMaxRadius * roundness))
        if let (label, connLink) = chatAddress() {
            v.contextMenu {
                Button {
                    let shareItems: [Any] = [connLink]
                    showShareSheet(items: shareItems)
                } label: {
                    Label(label, systemImage: "square.and.arrow.up")
                }
            }
            .padding(.horizontal)
        } else {
            v.padding(.horizontal)
        }

    }

    func chatAddress() -> (label: LocalizedStringKey, connLink: String)? {
        switch chat.chatInfo {
        case let .direct(contact):
            if !contact.nextConnectPrepared && !contact.nextAcceptContactRequest {
                let connLink: String? = if let pct = contact.preparedContact, case .con = pct.uiConnLinkType {
                    pct.connLinkToConnect.popopxChatUri()
                } else {
                    contact.profile.contactLink
                }
                if let connLink {
                    return (LocalizedStringKey(NSLocalizedString("banner_popopx_address", comment: "POPOPX address")), connLink)
                }
            }
        case let .group(groupInfo, _):
            if !groupInfo.nextConnectPrepared {
                if let pg = groupInfo.preparedGroup {
                    let connLink = pg.connLinkToConnect.popopxChatUri()
                    switch groupInfo.businessChat?.chatType {
                    case .none: return (LocalizedStringKey(NSLocalizedString("banner_group_link", comment: "Group link")), connLink)
                    case .business: return (LocalizedStringKey(NSLocalizedString("banner_business_address", comment: "Business address")), connLink)
                    default: ()
                    }
                }
            }
        default: ()
        }
        return nil
    }

    var chatContext: LocalizedStringKey? {
        switch chat.chatInfo {
        case let .direct(contact):
            if contact.nextConnectPrepared, let linkType = contact.preparedContact?.uiConnLinkType {
                switch linkType {
                case .inv:
                    LocalizedStringKey(NSLocalizedString("banner_tap_connect_to_chat", comment: "Tap Connect to chat"))
                case .con:
                    contact.isBot ? LocalizedStringKey(NSLocalizedString("banner_tap_connect_to_use_bot", comment: "Tap Connect to use bot")) : LocalizedStringKey(NSLocalizedString("banner_tap_connect_to_send_request", comment: "Tap Connect to send request"))
                }
            } else if contact.nextAcceptContactRequest {
                LocalizedStringKey(NSLocalizedString("banner_accept_contact_request", comment: "Accept contact request"))
            } else if case .bot = contact.profile.peerType {
                LocalizedStringKey(NSLocalizedString("banner_bot", comment: "Bot"))
            } else {
                LocalizedStringKey(NSLocalizedString("banner_your_contact", comment: "Your contact"))
            }
        case let .group(groupInfo, _):
            switch groupInfo.businessChat?.chatType {
            case .none:
                if groupInfo.nextConnectPrepared {
                    groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("banner_tap_join_channel", comment: "Tap Join channel")) : LocalizedStringKey(NSLocalizedString("banner_tap_join_group", comment: "Tap Join group"))
                } else {
                    switch (groupInfo.membership.memberStatus) {
                    case .memInvited: groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("banner_join_channel", comment: "Join channel")) : LocalizedStringKey(NSLocalizedString("banner_join_group", comment: "Join group"))
                    case .memCreator: groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("banner_your_channel", comment: "Your channel")) : LocalizedStringKey(NSLocalizedString("banner_your_group", comment: "Your group"))
                    default: groupInfo.useRelays ? LocalizedStringKey(NSLocalizedString("banner_channel", comment: "Channel")) : LocalizedStringKey(NSLocalizedString("banner_group", comment: "Group"))
                    }
                }
            case .business:
                if groupInfo.nextConnectPrepared {
                    LocalizedStringKey(NSLocalizedString("banner_tap_connect_to_chat", comment: "Tap Connect to chat"))
                } else {
                    LocalizedStringKey(NSLocalizedString("banner_business_connection", comment: "Business connection"))
                }
            case .customer:
                LocalizedStringKey(NSLocalizedString("banner_your_business_contact", comment: "Your business contact"))
            }
        default: nil
        }
    }
}
