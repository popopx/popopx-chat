//
//  PXComposeVoiceView.swift
//  POPOPX (iOS)
//
//  POPOPX voice message recording and playback composer.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

enum VoiceMessagePlaybackState {
    case noPlayback
    case playing
    case paused
}

func voiceMessageTime(_ time: TimeInterval) -> String {
    durationText(Int(time))
}

func voiceMessageTime_(_ time: TimeInterval?) -> String {
    durationText(Int(time ?? 0))
}

// POPOPX voice composer layout metrics
private enum PXVoiceComposerMetrics {
    static let previewHeight: CGFloat = 57
    static let controlSpacing: CGFloat = 10
    static let iconSize: CGFloat = 22
    static let iconLeadingPad: CGFloat = 14
    static let trailingPad: CGFloat = 14
    static let topPad: CGFloat = 6
    static let sliderTrackHeight: CGFloat = 6
    static let progressBarHeight: CGFloat = 6
    static let minRowHeight: CGFloat = 56
    static let verticalPad: CGFloat = 2
    static let progressAnimDuration: Double = 0.08
}

struct ComposeVoiceView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    var recordingFileName: String
    @Binding var recordingTime: TimeInterval?
    @Binding var recordingState: VoiceMessageRecordingState
    let cancelVoiceMessage: ((String) -> Void)
    let cancelEnabled: Bool

    @Binding var stopPlayback: Bool // value is not taken into account, only the fact it switches
    @State private var audioPlayer: AudioPlayer?
    @State private var playbackState: VoiceMessagePlaybackState = .noPlayback
    @State private var playbackTime: TimeInterval?
    @State private var startingPlayback: Bool = false

    var body: some View {
        ZStack {
            if recordingState != .finished {
                recordingMode()
            } else {
                playbackMode()
            }
        }
        .padding(.vertical, PXVoiceComposerMetrics.verticalPad)
        .frame(height: PXVoiceComposerMetrics.previewHeight)
        .background(theme.appColors.sentMessage)
        .frame(minHeight: PXVoiceComposerMetrics.minRowHeight)
        .frame(maxWidth: .infinity)
        .popopxBranded()
    }

    private func recordingMode() -> some View {
        ZStack {
            HStack(alignment: .center, spacing: PXVoiceComposerMetrics.controlSpacing) {
                pxPlayPauseImage("play.fill", theme.colors.onSurface)
                Text(voiceMessageTime_(recordingTime))
                Spacer()
                if cancelEnabled {
                    pxCancelButton()
                }
            }
            .padding(.trailing, PXVoiceComposerMetrics.trailingPad)
            .padding(.top, PXVoiceComposerMetrics.topPad)

            PXProgressBar(length: MAX_VOICE_MESSAGE_LENGTH, progress: $recordingTime)
        }
    }

    private func playbackMode() -> some View {
        ZStack {
            HStack(alignment: .center, spacing: PXVoiceComposerMetrics.controlSpacing) {
                pxPlaybackControls
                Spacer()
                if cancelEnabled {
                    pxCancelButton()
                }
            }
            .padding(.trailing, PXVoiceComposerMetrics.trailingPad)
            .padding(.top, PXVoiceComposerMetrics.topPad)

            if let recordingLength = recordingTime {
                SliderBar(length: recordingLength, progress: $playbackTime, seek: { audioPlayer?.seek($0) })
            }
        }
        .onChange(of: stopPlayback) {_, _ in
            audioPlayer?.stop()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
        .onChange(of: chatModel.stopPreviousRecPlay) {_, _ in
            if !startingPlayback {
                audioPlayer?.stop()
                playbackState = .noPlayback
                playbackTime = TimeInterval(0)
            } else {
                startingPlayback = false
            }
        }
    }

    @ViewBuilder private var pxPlaybackControls: some View {
        switch playbackState {
        case .noPlayback:
            Button {
                startPlayback()
            } label: {
                pxPlayPauseImage("play.fill", theme.colors.primary)
            }
            Text(voiceMessageTime_(recordingTime))
        case .playing:
            Button {
                audioPlayer?.pause()
                playbackState = .paused
            } label: {
                pxPlayPauseImage("pause.fill", theme.colors.primary)
            }
            Text(voiceMessageTime_(playbackTime))
        case .paused:
            Button {
                audioPlayer?.play()
                playbackState = .playing
            } label: {
                pxPlayPauseImage("play.fill", theme.colors.primary)
            }
            Text(voiceMessageTime_(playbackTime))
        }
    }

    /// Renders a play/pause SF Symbol at the standard voice-composer icon size
    private func pxPlayPauseImage(_ image: String, _ color: Color) -> some View {
        Image(systemName: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: PXVoiceComposerMetrics.iconSize, height: PXVoiceComposerMetrics.iconSize)
            .foregroundColor(color)
            .padding(.leading, PXVoiceComposerMetrics.iconLeadingPad)
    }

    private func pxCancelButton() -> some View {
        Button {
            audioPlayer?.stop()
            cancelVoiceMessage(recordingFileName)
        } label: {
            Image(systemName: "multiply")
        }
        .tint(theme.colors.primary)
    }

    struct SliderBar: View {
        @EnvironmentObject var theme: AppTheme
        var length: TimeInterval
        @Binding var progress: TimeInterval?
        var seek: (TimeInterval) -> Void

        var body: some View {
            Slider(value: Binding(get: { progress ?? TimeInterval(0) }, set: { seek($0) }), in: 0 ... length)
                .frame(maxWidth: .infinity)
                .frame(height: PXVoiceComposerMetrics.sliderTrackHeight)
                .tint(theme.colors.primary)
        }
    }

    /// Thin progress bar showing recording elapsed time
    private struct PXProgressBar: View {
        @EnvironmentObject var theme: AppTheme
        var length: TimeInterval
        @Binding var progress: TimeInterval?

        var body: some View {
            GeometryReader { geo in
                ZStack {
                    Rectangle()
                        .fill(theme.colors.primary)
                        .frame(
                            width: min(CGFloat((progress ?? TimeInterval(0)) / length) * geo.size.width, geo.size.width),
                            height: PXVoiceComposerMetrics.progressBarHeight
                        )
                        .animation(.linear(duration: PXVoiceComposerMetrics.progressAnimDuration), value: progress)
                }
                .frame(height: PXVoiceComposerMetrics.progressBarHeight)
            }
        }
    }

    private func startPlayback() {
        startingPlayback = true
        chatModel.stopPreviousRecPlay = getAppFilePath(recordingFileName)
        audioPlayer = AudioPlayer(
            onTimer: { playbackTime = $0 },
            onFinishPlayback: {
                playbackState = .noPlayback
                playbackTime = recordingTime // animate progress bar to the end
            }
        )
        audioPlayer?.start(fileSource: CryptoFile.plain(recordingFileName), at: playbackTime)
        playbackState = .playing
    }
}

struct ComposeVoiceView_Previews: PreviewProvider {
    static var previews: some View {
        ComposeVoiceView(
            recordingFileName: "voice.m4a",
            recordingTime: Binding.constant(TimeInterval(20)),
            recordingState: Binding.constant(VoiceMessageRecordingState.recording),
            cancelVoiceMessage: { _ in },
            cancelEnabled: true,
            stopPlayback: Binding.constant(false)
        )
        .environmentObject(ChatModel())
    }
}

// MARK: - POPOPX
extension ComposeVoiceView {
    var pxComponentTag: String { "px-compose-voice" }
}
