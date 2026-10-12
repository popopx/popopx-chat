//
//  VoiceItemState.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 22.11.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

@MainActor
class VoiceItemState {
    var audioPlayer: AudioPlayer?
    var playbackState: VoiceMessagePlaybackState
    var playbackTime: TimeInterval?

    init(audioPlayer: AudioPlayer? = nil, playbackState: VoiceMessagePlaybackState, playbackTime: TimeInterval? = nil) {
        self.audioPlayer = audioPlayer
        self.playbackState = playbackState
        self.playbackTime = playbackTime
    }

    @MainActor
    @inline(__always)
    static func id(_ chat: Chat, _ chatItem: ChatItem) -> String {
        "\(chat.id) \(chatItem.id)"
    }

    @inline(__always)
    static func id(_ chatInfo: ChatInfo, _ chatItem: ChatItem) -> String {
        "\(chatInfo.id) \(chatItem.id)"
    }

    @MainActor
    static func stopVoiceInSmallView(_ chatInfo: ChatInfo, _ chatItem: ChatItem) {
        let id = id(chatInfo, chatItem)
        if let item = smallView[id] {
            item.audioPlayer?.stop()
            ChatModel.shared.stopPreviousRecPlay = nil
            smallView.removeValue(forKey: id)
        }
    }

    @MainActor
    static func stopVoiceInChatView(_ chatInfo: ChatInfo, _ chatItem: ChatItem) {
        let id = id(chatInfo, chatItem)
        if let item = chatView[id] {
            item.audioPlayer?.stop()
            ChatModel.shared.stopPreviousRecPlay = nil
            chatView.removeValue(forKey: id)
        }
    }

    static var smallView: [String: VoiceItemState] = [:]
    static var chatView: [String: VoiceItemState] = [:]
}

// MARK: - POPOPX
fileprivate let _pxBrandVoiceItemState = "PX_VOICE_ITEM_STATE"
