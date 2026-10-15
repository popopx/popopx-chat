//
//  VoiceMessagePlayer.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 22.11.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

struct VoiceMessagePlayerTime: View {
    var recordingTime: TimeInterval
    @Binding var playbackState: VoiceMessagePlaybackState
    @Binding var playbackTime: TimeInterval?

    var body: some View {
        ZStack(alignment: .leading) {
            Text(String("66:66")).foregroundColor(.clear)
            switch playbackState {
            case .noPlayback:
                Text(voiceMessageTime(recordingTime))
            case .playing:
                Text(voiceMessageTime_(playbackTime))
            case .paused:
                Text(voiceMessageTime_(playbackTime))
            }
        }
    }
}

@MainActor
struct VoiceMessagePlayer: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    var recordingFile: CIFile?
    var recordingTime: TimeInterval
    var showBackground: Bool

    @Binding var seek: (TimeInterval) -> Void
    @Binding var audioPlayer: AudioPlayer?
    @Binding var playbackState: VoiceMessagePlaybackState
    @Binding var playbackTime: TimeInterval?

    @Binding var allowMenu: Bool
    var sizeMultiplier: CGFloat

    var body: some View {
        ZStack {
            if let recordingFile = recordingFile {
                switch recordingFile.fileStatus {
                case .sndStored:
                    if recordingFile.fileProtocol == .local {
                        playbackButton()
                    } else {
                        loadingIcon()
                    }
                case .sndTransfer: loadingIcon()
                case .sndComplete: playbackButton()
                case .sndCancelled: playbackButton()
                case let .sndError(sndFileError):
                    fileStatusIcon("multiply", 14)
                        .simultaneousGesture(TapGesture().onEnded {
                            showFileErrorAlert(sndFileError)
                        })
                case let .sndWarning(sndFileError):
                    fileStatusIcon("exclamationmark.triangle.fill", 16)
                        .simultaneousGesture(TapGesture().onEnded {
                            showFileErrorAlert(sndFileError, temporary: true)
                        })
                case .rcvInvitation: downloadButton(recordingFile, recordingFile.expired ? "multiply" : "play.fill")
                case .rcvAccepted: loadingIcon()
                case .rcvTransfer: loadingIcon()
                case .rcvAborted: downloadButton(recordingFile, "exclamationmark.arrow.circlepath")
                case .rcvComplete: playbackButton()
                case .rcvCancelled: playPauseIcon("play.fill", Color(uiColor: .tertiaryLabel))
                case let .rcvError(rcvFileError):
                    fileStatusIcon("multiply", 14)
                        .simultaneousGesture(TapGesture().onEnded {
                            showFileErrorAlert(rcvFileError, recordingFile)
                        })
                case let .rcvWarning(rcvFileError):
                    fileStatusIcon("exclamationmark.triangle.fill", 16)
                        .simultaneousGesture(TapGesture().onEnded {
                            showFileErrorAlert(rcvFileError, temporary: true)
                        })
                case .invalid: playPauseIcon("play.fill", Color(uiColor: .tertiaryLabel))
                }
            } else {
                playPauseIcon("play.fill", Color(uiColor: .tertiaryLabel))
            }
        }
        .onAppear {
            if audioPlayer == nil {
                let small = sizeMultiplier != 1
                audioPlayer = small ? VoiceItemState.smallView[VoiceItemState.id(chat, chatItem)]?.audioPlayer : VoiceItemState.chatView[VoiceItemState.id(chat, chatItem)]?.audioPlayer
                playbackState = (small ? VoiceItemState.smallView[VoiceItemState.id(chat, chatItem)]?.playbackState : VoiceItemState.chatView[VoiceItemState.id(chat, chatItem)]?.playbackState) ?? .noPlayback
                playbackTime = small ? VoiceItemState.smallView[VoiceItemState.id(chat, chatItem)]?.playbackTime : VoiceItemState.chatView[VoiceItemState.id(chat, chatItem)]?.playbackTime
            }
            seek = { to in audioPlayer?.seek(to) }
            let audioPath: URL? = if let recordingSource = getLoadedFileSource(recordingFile) {
                getAppFilePath(recordingSource.filePath)
            } else {
                nil
            }
            let chatId = chatModel.chatId
            let userId = chatModel.currentUser?.userId
            audioPlayer?.onTimer = {
                playbackTime = $0
                notifyStateChange()
                if (audioPath != nil && chatModel.stopPreviousRecPlay != audioPath) || chatModel.chatId != chatId || chatModel.currentUser?.userId != userId {
                    stopPlayback()
                }
            }
            audioPlayer?.onFinishPlayback = {
                playbackState = .noPlayback
                playbackTime = TimeInterval(0)
                notifyStateChange()
            }
            if let audioPath, chatModel.stopPreviousRecPlay != audioPath {
                stopPlayback()
            }
        }
        .onChange(of: chatModel.stopPreviousRecPlay) {_,  it in
            if let recordingFileName = getLoadedFileSource(recordingFile)?.filePath,
               chatModel.stopPreviousRecPlay != getAppFilePath(recordingFileName) {
                stopPlayback()
            }
        }
        .onChange(of: playbackState) {_,  state in
            allowMenu = state == .paused || state == .noPlayback
            if state == .noPlayback, let recordingFileName = getLoadedFileSource(recordingFile)?.filePath,
               chatModel.stopPreviousRecPlay == getAppFilePath(recordingFileName) {
                chatModel.stopPreviousRecPlay = nil
            }
        }
        .onChange(of: chatModel.chatId) {_, _ in
            stopPlayback()
        }
        .onDisappear {
            if sizeMultiplier == 1 && chatModel.chatId == nil {
                stopPlayback()
            }
        }
    }

    private func playbackButton() -> some View {
        let icon = switch playbackState {
        case .noPlayback: "play.fill"
        case .playing: "pause.fill"
        case .paused: "play.fill"
        }
        return playPauseIcon(icon, theme.colors.primary)
            .simultaneousGesture(TapGesture().onEnded { _ in
                switch playbackState {
                case .noPlayback:
                    if let recordingSource = getLoadedFileSource(recordingFile) {
                        startPlayback(recordingSource)
                    }
                case .playing:
                    audioPlayer?.pause()
                    playbackState = .paused
                    notifyStateChange()
                case .paused:
                    audioPlayer?.play()
                    playbackState = .playing
                    notifyStateChange()
                }
            })
    }

    private func playPauseIcon(_ image: String, _ color: Color) -> some View {
        ZStack {
            Image(systemName: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20 * sizeMultiplier, height: 20 * sizeMultiplier)
                .foregroundColor(color)
                .padding(.leading, image == "play.fill" ? 4 : 0)
                .frame(width: 56 * sizeMultiplier, height: 56 * sizeMultiplier)
                .background(showBackground ? chatItemFrameColor(chatItem, theme) : .clear)
                .clipShape(Circle())
            if recordingTime > 0 {
                ProgressCircle(length: recordingTime, progress: $playbackTime)
                    .frame(width: 53 * sizeMultiplier, height: 53 * sizeMultiplier)
            }
        }
    }

    private func downloadButton(_ recordingFile: CIFile, _ icon: String) -> some View {
        playPauseIcon(icon, theme.colors.primary)
            .simultaneousGesture(TapGesture().onEnded {
                chatModel.openWhenReceived(recordingFile) { file in
                    if let recordingSource = getLoadedFileSource(file) {
                        startPlayback(recordingSource)
                    }
                }
                Task {
                    if let user = chatModel.currentUser {
                        await receiveFile(user: user, fileId: recordingFile.fileId)
                    }
                }
            })
    }

    func notifyStateChange() {
        if sizeMultiplier != 1 {
            VoiceItemState.smallView[VoiceItemState.id(chat, chatItem)] = VoiceItemState(audioPlayer: audioPlayer, playbackState: playbackState, playbackTime: playbackTime)
        } else {
            VoiceItemState.chatView[VoiceItemState.id(chat, chatItem)] = VoiceItemState(audioPlayer: audioPlayer, playbackState: playbackState, playbackTime: playbackTime)
        }
    }

    private struct ProgressCircle: View {
        @EnvironmentObject var theme: AppTheme
        @Environment(\.accessibilityReduceMotion) var reduceMotion
        var length: TimeInterval
        @Binding var progress: TimeInterval?

        var body: some View {
            Circle()
                .trim(from: 0, to: ((progress ?? TimeInterval(0)) / length))
                .stroke(
                    theme.colors.primary,
                    style: StrokeStyle(lineWidth: 3)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear, value: progress)
        }
    }

    private func fileStatusIcon(_ image: String, _ size: CGFloat) -> some View {
        Image(systemName: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * sizeMultiplier, height: size * sizeMultiplier)
            .foregroundColor(Color(uiColor: .tertiaryLabel))
            .frame(width: 56 * sizeMultiplier, height: 56 * sizeMultiplier)
            .background(showBackground ? chatItemFrameColor(chatItem, theme) : .clear)
            .clipShape(Circle())
    }

    private func loadingIcon() -> some View {
        ProgressView()
            .frame(width: 30 * sizeMultiplier, height: 30 * sizeMultiplier)
            .frame(width: 56 * sizeMultiplier, height: 56 * sizeMultiplier)
            .background(showBackground ? chatItemFrameColor(chatItem, theme) : .clear)
            .clipShape(Circle())
    }

    private func startPlayback(_ recordingSource: CryptoFile) {
        let audioPath = getAppFilePath(recordingSource.filePath)
        let chatId = chatModel.chatId
        let userId = chatModel.currentUser?.userId
        chatModel.stopPreviousRecPlay = audioPath
        audioPlayer = AudioPlayer(
            onTimer: { [weak chatModel] in
                playbackTime = $0
                notifyStateChange()
                guard let chatModel else { return }
                if chatModel.stopPreviousRecPlay != audioPath || chatModel.chatId != chatId || chatModel.currentUser?.userId != userId {
                    stopPlayback()
                }
            },
            onFinishPlayback: {
                playbackState = .noPlayback
                playbackTime = TimeInterval(0)
                notifyStateChange()
            }
        )
        audioPlayer?.start(fileSource: recordingSource, at: playbackTime)
        playbackState = .playing
        notifyStateChange()
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        playbackState = .noPlayback
        playbackTime = TimeInterval(0)
        notifyStateChange()
    }
}

@inline(__always)
func voiceMessageSizeBasedOnSquareSize(_ squareSize: CGFloat) -> CGFloat {
    let squareToCircleRatio = 0.935
    return squareSize + squareSize * (1 - squareToCircleRatio)
}

// MARK: - POPOPX
fileprivate let _pxBrandVoiceMessagePlayer = "PX_VOICE_MESSAGE_PLAYER"
