//
//  ChatUtils.swift
//  POPOPXSwitch
//
//  Created by Levitating Pineapple on 15/07/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation

public protocol ChatLike {
    var chatInfo: ChatInfo { get }
}

extension ChatLike {
    public func groupFeatureEnabled(_ feature: GroupFeature) -> Bool {
        if case let .group(groupInfo, _) = self.chatInfo {
            let p = groupInfo.fullGroupPreferences
            return switch feature {
            case .timedMessages: p.timedMessages.on
            case .directMessages: p.directMessages.on(for: groupInfo.membership)
            case .fullDelete: p.fullDelete.on
            case .reactions: p.reactions.on
            case .voice: p.voice.on(for: groupInfo.membership)
            case .files: p.files.on(for: groupInfo.membership)
            case .popopxLinks: p.popopxLinks.on(for: groupInfo.membership)
            case .history: p.history.on
            case .support: p.support.on
            case .reports: p.reports.on
            case .signMessages: p.signMessages.on
            }
        } else {
            return true
        }
    }

    public func prohibitedByPref(
        hasPopopxLink: Bool,
        isMediaOrFileAttachment: Bool,
        isVoice: Bool
    ) -> Bool {
        // preference checks should match checks in compose view
        let popopxLinkProhibited = hasPopopxLink && !groupFeatureEnabled(.popopxLinks)
        let fileProhibited = isMediaOrFileAttachment && !groupFeatureEnabled(.files)
        let voiceProhibited = isVoice && !chatInfo.featureEnabled(.voice)
        return switch chatInfo {
        case .direct: voiceProhibited
        case .group: popopxLinkProhibited || fileProhibited || voiceProhibited
        case .local: false
        case .contactRequest: false
        case .contactConnection: false
        case .meshPeer: false
        case .meshGroup: false
        case .invalidJSON: false
        }
    }
}

public func filterChatsToForwardTo<C: ChatLike>(chats: [C], includeLocal: Bool = true) -> [C] {
    var filteredChats = chats.filter { c in
        c.chatInfo.chatType != .local && canForwardToChat(c.chatInfo)
    }
    if includeLocal, let privateNotes = chats.first(where: { $0.chatInfo.chatType == .local }) {
        filteredChats.insert(privateNotes, at: 0)
    }
    return filteredChats
}

public func foundChat(_ chat: ChatLike, _ searchStr: String) -> Bool {
    let cInfo = chat.chatInfo
    return switch cInfo {
    case let .direct(contact):
        viewNameContains(cInfo, searchStr) ||
        contact.profile.displayName.localizedLowercase.contains(searchStr) ||
        contact.fullName.localizedLowercase.contains(searchStr)
    default:
        viewNameContains(cInfo, searchStr)
    }

    func viewNameContains(_ cInfo: ChatInfo, _ s: String) -> Bool {
        cInfo.chatViewName.localizedLowercase.contains(s)
    }
}

private func canForwardToChat(_ cInfo: ChatInfo) -> Bool {
    switch cInfo {
    case let .direct(contact): cInfo.sendMsgEnabled && !contact.sendMsgToConnect
    case .group: cInfo.sendMsgEnabled
    case .local: cInfo.sendMsgEnabled
    case .contactRequest: false
    case .contactConnection: false
    case .meshPeer: true
    case .meshGroup: false
    case .invalidJSON: false
    }
}

public func chatIconName(_ cInfo: ChatInfo) -> String {
    switch cInfo {
    case let .direct(contact): contact.chatIconName
    case let .group(groupInfo, _): groupInfo.chatIconName
    case .local: "folder.circle.fill"
    case .contactRequest: "person.crop.circle.fill"
    default:  "circle.fill"
    }
}

public func hasPopopxLink(_ text: String?) -> Bool {
    if let text, let parsedMsg = parseMarkdown(text) {
        parsedMsgHasPopopxLink(parsedMsg)
    } else {
        false
    }
}

public func parsedMsgHasPopopxLink(_ parsedMsg: [FormattedText]) -> Bool {
    parsedMsg.contains(where: { ft in ft.format?.isPopopxLink ?? false })
}
