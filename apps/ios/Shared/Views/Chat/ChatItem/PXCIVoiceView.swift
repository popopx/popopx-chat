//
//  CIVoiceView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 22.11.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/chat-view.md#CIVoiceView
struct CIVoiceView: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    let recordingFile: CIFile?
    let duration: Int
    @State var audioPlayer: AudioPlayer? = nil
    @State var playbackState: VoiceMessagePlaybackState = .noPlayback
    @State var playbackTime: TimeInterval? = nil

    @Binding var allowMenu: Bool
    var smallViewSize: CGFloat?
    @State private var seek: (TimeInterval) -> Void = { _ in }

    var body: some View {
        POPOPXMediaView {
            if smallViewSize != nil {
                HStack(spacing: 10) {
                    player()
                    playerTime()
                        .allowsHitTesting(false)
                    if .playing == playbackState || (playbackTime ?? 0) > 0 || !allowMenu {
                        playbackSlider()
                    }
                }
            } else if chatItem.chatDir.sent {
                VStack (alignment: .trailing, spacing: 6) {
                    HStack {
                        if .playing == playbackState || (playbackTime ?? 0) > 0 || !allowMenu {
                            playbackSlider()
                        }
                        playerTime()
                        player()
                    }
                    .frame(alignment: .trailing)
                    metaView().padding(.trailing, 10)
                }
            } else {
                VStack (alignment: .leading, spacing: 6) {
                    HStack {
                        player()
                        playerTime()
                        if .playing == playbackState || (playbackTime ?? 0) > 0 || !allowMenu {
                            playbackSlider()
                        }
                    }
                    .frame(alignment: .leading)
                    metaView().padding(.leading, -6)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .popopxBranded()
    }

    private func player() -> some View {
        let sizeMultiplier: CGFloat = if let sz = smallViewSize {
            voiceMessageSizeBasedOnSquareSize(sz) / 56
        } else {
            1
        }
        return VoiceMessagePlayer(
            chat: chat,
            chatItem: chatItem,
            recordingFile: recordingFile,
            recordingTime: TimeInterval(duration),
            showBackground: true,
            seek: $seek,
            audioPlayer: $audioPlayer,
            playbackState: $playbackState,
            playbackTime: $playbackTime,
            allowMenu: $allowMenu,
            sizeMultiplier: sizeMultiplier
        )
    }

    private func playerTime() -> some View {
        VoiceMessagePlayerTime(
            recordingTime: TimeInterval(duration),
            playbackState: $playbackState,
            playbackTime: $playbackTime
        )
        .foregroundColor(theme.colors.secondary)
    }
    
    private func playbackSlider() -> some View {
            ComposeVoiceView.SliderBar(
                length: TimeInterval(duration),
                progress: $playbackTime,
                seek: {
                    let time = max(0.0001, $0)
                    seek(time)
                    playbackTime = time
                })
            .onChange(of: .playing == playbackState || (playbackTime ?? 0) > 0) {_,  show in
                if !show {
                    allowMenu = true
                }
            }
            .tint(theme.colors.primary)
    }

    private func metaView() -> some View {
        CIMetaView(chat: chat, chatItem: chatItem, metaColor: theme.colors.secondary)
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 360)) {
    let im = ItemsModel.shared
    let sentVoiceMessage: ChatItem = ChatItem(
        chatDir: .directSnd,
        meta: CIMeta.getSample(1, .now, "", .sndSent(sndProgress: .complete), itemEdited: true),
        content: .sndMsgContent(msgContent: .voice(text: "", duration: 30)),
        quotedItem: nil,
        file: CIFile.getSample(fileStatus: .sndComplete)
    )
    let voiceMessageWtFile = ChatItem(
        chatDir: .directRcv,
        meta: CIMeta.getSample(1, .now, "", .rcvRead),
        content: .rcvMsgContent(msgContent: .voice(text: "", duration: 30)),
        quotedItem: nil,
        file: nil
    )
    Group {
        CIVoiceView(
            chat: Chat.sampleData,
            chatItem: ChatItem.getVoiceMsgContentSample(),
            recordingFile: CIFile.getSample(fileName: "voice.m4a", fileSize: 65536, fileStatus: .rcvComplete),
            duration: 30,
            allowMenu: Binding.constant(true)
        )
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: sentVoiceMessage, scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil), allowMenu: .constant(true))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getVoiceMsgContentSample(), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil), allowMenu: .constant(true))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getVoiceMsgContentSample(fileStatus: .rcvTransfer(rcvProgress: 7, rcvTotal: 10)), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil), allowMenu: .constant(true))
        PXChatItem(chat: Chat.sampleData, im: im, chatItem: voiceMessageWtFile, scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil), allowMenu: .constant(true))
    }
}
