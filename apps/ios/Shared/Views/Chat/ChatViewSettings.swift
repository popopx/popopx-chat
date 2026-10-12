//
//  ChatViewSettings.swift
//  POPOPX
//
//  Extracted from ChatView.swift
//  Settings-related view builders and helpers for ChatView.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ToggleNtfsButton: View {
    @ObservedObject var chat: Chat

    var body: some View {
        Group {
        if let nextMode = chat.chatInfo.nextNtfMode {
            Button {
                toggleNotifications(chat, enableNtfs: nextMode)
            } label: {
                Label(nextMode.text(mentions: chat.chatInfo.hasMentions), systemImage: nextMode.icon)
            }
        }
        }
        .popopxBranded()
    }
}

@MainActor
func toggleNotifications(_ chat: Chat, enableNtfs: MsgFilter) {
    var chatSettings = chat.chatInfo.chatSettings ?? ChatSettings.defaults
    chatSettings.enableNtfs = enableNtfs
    updateChatSettings(chat, chatSettings: chatSettings)
}

@MainActor
func toggleChatFavorite(_ chat: Chat, favorite: Bool) {
    var chatSettings = chat.chatInfo.chatSettings ?? ChatSettings.defaults
    chatSettings.favorite = favorite
    updateChatSettings(chat, chatSettings: chatSettings)
}

@MainActor
func updateChatSettings(_ chat: Chat, chatSettings: ChatSettings) {
    Task {
        do {
            try await apiSetChatSettings(type: chat.chatInfo.chatType, id: chat.chatInfo.apiId, chatSettings: chatSettings)
            await MainActor.run {
                let wasFavorite = chat.chatInfo.chatSettings?.favorite ?? false
                ChatTagsModel.shared.updateChatFavorite(favorite: chatSettings.favorite, wasFavorite: wasFavorite)
                let wasUnread = chat.unreadTag
                switch chat.chatInfo {
                case var .direct(contact):
                    contact.chatSettings = chatSettings
                    ChatModel.shared.updateContact(contact)
                case var .group(groupInfo, _):
                    groupInfo.chatSettings = chatSettings
                    ChatModel.shared.updateGroup(groupInfo)
                default: ()
                }
                ChatTagsModel.shared.updateChatTagRead(chat, wasUnread: wasUnread)
            }
        } catch let error {
            logger.error("apiSetChatSettings error \(responseError(error))")
        }
    }
}

// Spec: spec/client/chat-view.md#ContentFilter
enum ContentFilter: CaseIterable {
    case images
    case videos
    case voice
    case files
    case links

    static let alwaysShow: Set<MsgContentTag> = [.image, .link]

    var contentTag: MsgContentTag {
        switch self {
        case .images: .image
        case .videos: .video
        case .voice: .voice
        case .files: .file
        case .links: .link
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .images: "Images"
        case .videos: "Videos"
        case .voice: "Voice messages"
        case .files: "Files"
        case .links: "Links"
        }
    }

    var searchPlaceholder: LocalizedStringKey {
        switch self {
        case .images: "Search images"
        case .videos: "Search videos"
        case .voice: "Search voice messages"
        case .files: "Search files"
        case .links: "Search links"
        }
    }

    var icon: String {
        switch self {
        case .images: "photo"
        case .videos: "video"
        case .voice: "mic"
        case .files: "doc"
        case .links: "link"
        }
    }

    var iconFilled: String {
        switch self {
        case .images: "photo.fill"
        case .videos: "video.fill"
        case .voice: "mic.fill"
        case .files: "doc.fill"
        case .links: "link.circle.fill"
        }
    }
}
