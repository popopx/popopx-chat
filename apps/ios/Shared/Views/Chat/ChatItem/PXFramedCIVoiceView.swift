//
//  FramedCIVoiceView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 22.11.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature flags and animation constants
private let pxVoiceFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")
private let pxVoiceAnimationScale: Double = 0.8
private let pxMinSeekTime: TimeInterval = 0.0001 // POPOPX: seek clamping floor
private let pxTimeLabelWidth: CGFloat = 52 // POPOPX: slightly wider time label

// Spec: spec/client/chat-view.md#FramedCIVoiceView
struct FramedCIVoiceView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    var chatItem: ChatItem
    let recordingFile: CIFile?
    let duration: Int

    @State var audioPlayer: AudioPlayer? = nil
    @State var playbackState: VoiceMessagePlaybackState = .noPlayback
    @State var playbackTime: TimeInterval? = nil

    @Binding var allowMenu: Bool

    @State private var seek: (TimeInterval) -> Void = { _ in }

    // MARK: - POPOPX
    private var pxRecordingDuration: TimeInterval {
        TimeInterval(duration)
    }

    var body: some View {
        HStack {
            VoiceMessagePlayer(
                chat: chat,
                chatItem: chatItem,
                recordingFile: recordingFile,
                recordingTime: pxRecordingDuration,
                showBackground: false,
                seek: $seek,
                audioPlayer: $audioPlayer,
                playbackState: $playbackState,
                playbackTime: $playbackTime,
                allowMenu: $allowMenu,
                sizeMultiplier: 1
            )
            VoiceMessagePlayerTime(
                recordingTime: pxRecordingDuration,
                playbackState: $playbackState,
                playbackTime: $playbackTime
            )
            .foregroundColor(theme.colors.secondary)
            .frame(width: pxTimeLabelWidth, alignment: .leading) // POPOPX: wider time label
            if .playing == playbackState || (playbackTime ?? 0) > 0 || !allowMenu {
                playbackSlider()
            }
        }
        .padding(.top, 10) // POPOPX: more top breathing room
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.bottom, chatItem.content.text.isEmpty ? 14 : 0) // POPOPX: larger bottom pad when no text
        .popopxBranded()
    }

    private func playbackSlider() -> some View {
        ComposeVoiceView.SliderBar(
            length: pxRecordingDuration,
            progress: $playbackTime,
            seek: { newValue in
                let clampedSeekTime = Self.pxClampSeekTime(newValue) // POPOPX: renamed for clarity
                seek(clampedSeekTime)
                playbackTime = clampedSeekTime
            })
        .onChange(of: .playing == playbackState || (playbackTime ?? 0) > 0) {_,  show in
            if !show {
                allowMenu = true
            }
        }
    }

    // MARK: - POPOPX
    private static func pxClampSeekTime(_ time: TimeInterval) -> TimeInterval {
        // POPOPX: prevent zero/negative seek positions that crash AVPlayer
        if pxVoiceFeatureEnabled {
            logger.debug("PX: [pxClampSeekTime] feature enabled, time=\(time)")
        }
        return max(pxMinSeekTime, time)
    }
}

struct FramedCIVoiceView_Previews: PreviewProvider {
    static var previews: some View {
        let im = ItemsModel.shared
        let sentVoiceMessage: ChatItem = ChatItem(
            chatDir: .directSnd,
            meta: CIMeta.getSample(1, .now, "", .sndSent(sndProgress: .complete), itemEdited: true),
            content: .sndMsgContent(msgContent: .voice(text: "Hello there", duration: 30)),
            quotedItem: nil,
            file: CIFile.getSample(fileStatus: .sndComplete)
        )
        let voiceMessageWithQuote: ChatItem = ChatItem(
            chatDir: .directSnd,
            meta: CIMeta.getSample(1, .now, "", .sndSent(sndProgress: .complete), itemEdited: true),
            content: .sndMsgContent(msgContent: .voice(text: "", duration: 30)),
            quotedItem: CIQuote.getSample(1, .now, "Hi", chatDir: .directRcv),
            file: CIFile.getSample(fileStatus: .sndComplete)
        )
        Group {
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: sentVoiceMessage, scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getVoiceMsgContentSample(text: "Hello there"), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getVoiceMsgContentSample(text: "Hello there", fileStatus: .rcvTransfer(rcvProgress: 7, rcvTotal: 10)), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getVoiceMsgContentSample(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: voiceMessageWithQuote, scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        }
        .environment(\.revealed, false)
        .previewLayout(.fixed(width: 360, height: 360))
    }
}

// MARK: - POPOPX
extension FramedCIVoiceView {
    var pxComponentTag: String { "px-framed-voice" }
}
