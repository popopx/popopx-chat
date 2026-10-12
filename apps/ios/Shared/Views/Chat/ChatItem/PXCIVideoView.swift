//
//  PXVideoPlayer.swift
//  POPOPX
//
//  Created by Avently on 30/03/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import AVKit
import POPOPXSwitch
import Combine

// MARK: - POPOPX Layout Configuration
private enum PXCIVideoConfig {
    static let smallViewSizeMultiplier: CGFloat = 0.38
    static let playIconBaseSize: CGFloat = 12
    static let smallViewIconScale: CGFloat = 1.6
    static let playButtonFrameSize: CGFloat = 40
    static let playButtonBackgroundOpacity: Double = 0.38
    static let playButtonShadowOpacity: Double = 0.2
    static let playButtonShadowRadius: CGFloat = 3
    static let playButtonShadowY: CGFloat = 1
    static let playButtonLeadingPadding: CGFloat = 4
    static let progressBackgroundOpacity: Double = 0.32
    static let progressSmallScaleFactor: CGFloat = 0.9
    static let progressFrameSize: CGFloat = 40
    static let progressIndicatorSize: CGFloat = 12
    static let durationVerticalPadding: CGFloat = 5
    static let durationHorizontalPadding: CGFloat = 10
    static let portraitWidthRatio: CGFloat = 0.75
    static let fullScreenCloseIconSize: CGFloat = 15
    static let fullScreenCloseLeadingPadding: CGFloat = 15
    static let fullScreenCloseTopPadding: CGFloat = 13
    static let fullScreenDragThreshold: CGFloat = 80
    static let fullScreenDragVerticalMin: CGFloat = 60
    static let fullScreenDragHorizontalMultiplier: CGFloat = 2
    static let statusIconSize: CGFloat = 10
    static let statusIconPadding: CGFloat = 13
    static let statusIconSecondarySize: CGFloat = 14
    static let statusIconSecondaryPadding: CGFloat = 11
    static let progressCircleLineWidth: CGFloat = 2
    static let progressCircleFrameSize: CGFloat = 16
    static let fileIndicatorSize: CGFloat = 10
    static let fileIndicatorSecondarySize: CGFloat = 14
    static let fileIndicatorPadding: CGFloat = 13
    static let fileIndicatorSecondaryPadding: CGFloat = 11
    static let timeObserverInterval: Double = 0.01
    static let fileSizePrefix: String = "  "
    static let decryptionOverlayOpacity: Double = 0.3
}

// MARK: - POPOPX Feature
private let pxVideoFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_VIDEO_FEATURE_ENABLED")

// MARK: - POPOPX View Model
@MainActor
private struct PXCIVideoViewModel {
    let chatItem: ChatItem
    let smallView: Bool
    let videoPlaying: Bool

    var sizeMultiplier: CGFloat {
        smallView ? PXCIVideoConfig.smallViewSizeMultiplier : 1
    }

    var playIconSize: CGFloat {
        smallView
            ? PXCIVideoConfig.playIconBaseSize * sizeMultiplier * PXCIVideoConfig.smallViewIconScale
            : PXCIVideoConfig.playIconBaseSize
    }

    var playButtonFrame: CGFloat {
        PXCIVideoConfig.playButtonFrameSize * sizeMultiplier
    }

    var progressIndicatorSize: CGFloat {
        smallView
            ? PXCIVideoConfig.progressIndicatorSize * sizeMultiplier
            : PXCIVideoConfig.progressIndicatorSize
    }

    var progressFrameSize: CGFloat {
        smallView
            ? PXCIVideoConfig.progressFrameSize * sizeMultiplier * PXCIVideoConfig.progressSmallScaleFactor
            : PXCIVideoConfig.progressFrameSize
    }

    var canShowPlayIcon: Bool {
        let pxSent = chatItem.chatDir.sent
        let pxStatus = chatItem.file?.fileStatus
        let pxProtocol = chatItem.file?.fileProtocol
        return !pxSent || pxStatus == CIFileStatus.sndComplete || (pxStatus == .sndStored && pxProtocol == .local)
    }

    var displayFileSize: String {
        if let file = chatItem.file, !videoPlaying {
            return PXCIVideoConfig.fileSizePrefix + ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .binary)
        }
        return ""
    }
}

// Spec: spec/client/chat-view.md#PXVideoPlayer
struct PXVideoPlayer: View {
    @EnvironmentObject var m: ChatModel
    private let chatItem: ChatItem
    private let preview: UIImage?
    @State private var duration: Int
    @State private var progress: Int = 0
    @State private var videoPlaying: Bool = false
    private let maxWidth: CGFloat
    private var videoWidth: CGFloat?
    private let smallView: Bool
    @State private var player: AVPlayer?
    @State private var fullPlayer: AVPlayer?
    @State private var url: URL?
    @State private var urlDecrypted: URL?
    @State private var decryptionInProgress: Bool = false
    @Binding private var showFullScreenPlayer: Bool
    @State private var timeObserver: Any? = nil
    @State private var fullScreenTimeObserver: Any? = nil
    @State private var publisher: AnyCancellable? = nil
    @State private var blurred: Bool = UserDefaults.standard.integer(forKey: DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS) > 0

    init(chatItem: ChatItem, preview: UIImage?, duration: Int, maxWidth: CGFloat, videoWidth: CGFloat?, smallView: Bool = false, showFullscreenPlayer: Binding<Bool>) {
        self.chatItem = chatItem
        self.preview = preview
        self._duration = State(initialValue: duration)
        self.maxWidth = maxWidth
        self.videoWidth = videoWidth
        self.smallView = smallView
        self._showFullScreenPlayer = showFullscreenPlayer
    }

    // POPOPX: video player rendering pipeline
    var body: some View {
        ZStack(alignment: smallView ? .topLeading : .center) {
            pxMainVideoContent
            pxDownloadOverlay
        }
        .fullScreenCover(isPresented: $showFullScreenPlayer) {
            if let decrypted = urlDecrypted {
                fullScreenPlayer(decrypted)
            }
        }
        .onAppear { setupPlayer(chatItem.file) }
        .onChange(of: chatItem.file) { _, file in setupPlayer(file) }
        .onDisappear {
            showFullScreenPlayer = false
            player?.replaceCurrentItem(with: nil)
            fullPlayer = nil
            if let urlDecrypted {
                let key = VideoPlayerView.pxPlayerCacheKey(urlDecrypted, smallView) as NSString
                VideoPlayerView.removePlayer(forKey: key)
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX Extracted View Builders

    @ViewBuilder
    private var pxMainVideoContent: some View {
        let file = chatItem.file
        ZStack(alignment: .topLeading) {
            if let file, let preview {
                pxVideoLayer(file: file, preview: preview)
            }
            if !smallView {
                durationProgress()
            }
        }
    }

    @ViewBuilder
    private func pxVideoLayer(file: CIFile, preview: UIImage) -> some View {
        if let urlDecrypted {
            if smallView {
                smallVideoView(urlDecrypted, file, preview)
            } else if let player {
                videoView(player, urlDecrypted, file, preview, duration)
            }
        } else if file.loaded {
            if smallView {
                smallVideoViewEncrypted(file, preview)
            } else {
                videoViewEncrypted(file, preview, duration)
            }
        } else {
            pxUnloadedImageView(preview: preview, file: file)
        }
    }

    @ViewBuilder
    private func pxUnloadedImageView(preview: UIImage, file: CIFile) -> some View {
        Group {
            if smallView {
                smallViewImageView(preview, file)
            } else {
                imageView(preview)
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            pxHandleUnloadedFileTap(file)
        })
    }

    @ViewBuilder
    private var pxDownloadOverlay: some View {
        if let file = chatItem.file, !blurred, showDownloadButton(file.fileStatus) {
            if !smallView || !file.showStatusIconInSmallView {
                playPauseIcon("play.fill")
                    .simultaneousGesture(TapGesture().onEnded {
                        receiveFileIfValidSize(file: file, receiveFile: receiveFile)
                    })
            }
        }
    }

    // MARK: - POPOPX View Model Accessor

    private var pxVM: PXCIVideoViewModel {
        PXCIVideoViewModel(chatItem: chatItem, smallView: smallView, videoPlaying: videoPlaying)
    }

    // MARK: - POPOPX Tap Handling

    private func pxHandleUnloadedFileTap(_ file: CIFile) {
        switch file.fileStatus {
        case .rcvInvitation, .rcvAborted:
            receiveFileIfValidSize(file: file, receiveFile: receiveFile)
        case .rcvAccepted:
            pxHandleAcceptedFileTap(file)
        case .rcvTransfer: ()
        case .rcvComplete: ()
        case .rcvCancelled: logger.debug("PXVideoPlayer: transfer cancelled")
        default: ()
        }
    }

    private func pxHandleAcceptedFileTap(_ file: CIFile) {
        switch file.fileProtocol {
        case .xftp:
            AlertManager.shared.showAlertMsg(
                title: LocalizedStringKey(NSLocalizedString("waiting_for_video_title", comment: "Waiting for video alert title")),
                message: LocalizedStringKey(NSLocalizedString("waiting_for_video_xftp_message", comment: "Waiting for video xftp message"))
            )
        case .smp:
            AlertManager.shared.showAlertMsg(
                title: LocalizedStringKey(NSLocalizedString("waiting_for_video_title", comment: "Waiting for video alert title")),
                message: LocalizedStringKey(NSLocalizedString("waiting_for_video_smp_message", comment: "Waiting for video smp message"))
            )
        case .local: ()
        }
    }

    // POPOPX: initialize AVPlayer and manage decryption state
    private func setupPlayer(_ file: CIFile?) {
        logger.debug("PX: [setupPlayer] called with file: \(file?.fileName ?? "nil")")
        let newUrl = getLoadedVideo(file)
        guard newUrl != url else { return }
        url = nil
        urlDecrypted = nil
        player = nil
        fullPlayer = nil
        if let newUrl {
            let pxDecrypted = file?.fileSource?.cryptoArgs == nil ? newUrl : file?.fileSource?.decryptedGet()
            urlDecrypted = pxDecrypted
            if let pxDecrypted = pxDecrypted {
                player = VideoPlayerView.getOrCreatePlayer(pxDecrypted, false)
            }
            url = newUrl
        }
        logger.debug("PX: [setupPlayer] completed, urlDecrypted: \(urlDecrypted != nil)")
    }

    private func showDownloadButton(_ fileStatus: CIFileStatus?) -> Bool {
        switch fileStatus {
        case .rcvInvitation: true
        case .rcvAborted: true
        default: false
        }
    }

    // MARK: - POPOPX Video Views

    private func videoViewEncrypted(_ file: CIFile, _ defaultPreview: UIImage, _ duration: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .center) {
                let pxCanPlay = pxVM.canShowPlayIcon
                imageView(defaultPreview)
                    .simultaneousGesture(TapGesture().onEnded {
                        decrypt(file: file) { showFullScreenPlayer = urlDecrypted != nil }
                    })
                    .onChange(of: m.activeCallViewIsCollapsed) { _, _ in showFullScreenPlayer = false }
                pxEncryptedOverlay(pxCanPlay: pxCanPlay, file: file)
            }
        }
    }

    @ViewBuilder
    private func pxEncryptedOverlay(pxCanPlay: Bool, file: CIFile) -> some View {
        if !blurred {
            if !decryptionInProgress {
                playPauseIcon(pxCanPlay ? "play.fill" : "play.slash")
                    .simultaneousGesture(TapGesture().onEnded {
                        decrypt(file: file) {
                            if urlDecrypted != nil {
                                videoPlaying = true
                                player?.play()
                            }
                        }
                    })
                    .disabled(!pxCanPlay)
            } else {
                videoDecryptionProgress()
            }
        }
    }

    private func videoView(_ player: AVPlayer, _ url: URL, _ file: CIFile, _ preview: UIImage, _ duration: Int) -> some View {
        let pxWidth = preview.size.width <= preview.size.height ? maxWidth * PXCIVideoConfig.portraitWidthRatio : maxWidth
        return ZStack(alignment: .topTrailing) {
            ZStack(alignment: .center) {
                let pxCanPlay = pxVM.canShowPlayIcon
                VideoPlayerView(player: player, url: url, showControls: false)
                    .frame(width: pxWidth, height: pxWidth * heightRatio(preview.size))
                    .clipped()
                    .onChange(of: m.stopPreviousRecPlay) { _, playingUrl in
                        if playingUrl != url {
                            player.pause()
                            videoPlaying = false
                        }
                    }
                    .modifier(PrivacyBlur(enabled: !videoPlaying, blurred: $blurred))
                    .if(!blurred) { v in
                        v.simultaneousGesture(TapGesture().onEnded {
                            pxHandleVideoTap(player: player, pxCanPlay: pxCanPlay)
                        })
                    }
                    .onChange(of: m.activeCallViewIsCollapsed) { _, _ in showFullScreenPlayer = false }
                pxPlayingOverlay(pxCanPlay: pxCanPlay, player: player, url: url)
            }
            fileStatusIcon()
        }
        .onAppear { addObserver(player, url) }
        .onDisappear {
            removeObserver()
            player.pause()
            videoPlaying = false
        }
    }

    private func pxHandleVideoTap(player: AVPlayer, pxCanPlay: Bool) {
        switch player.timeControlStatus {
        case .playing:
            player.pause()
            videoPlaying = false
        case .paused:
            if pxCanPlay { showFullScreenPlayer = true }
        default: ()
        }
    }

    @ViewBuilder
    private func pxPlayingOverlay(pxCanPlay: Bool, player: AVPlayer, url: URL) -> some View {
        if !videoPlaying && !blurred {
            playPauseIcon(pxCanPlay ? "play.fill" : "play.slash")
                .simultaneousGesture(TapGesture().onEnded {
                    m.stopPreviousRecPlay = url
                    player.play()
                })
                .disabled(!pxCanPlay)
        }
    }

    private func smallVideoViewEncrypted(_ file: CIFile, _ preview: UIImage) -> some View {
        ZStack(alignment: .topLeading) {
            let pxCanPlay = pxVM.canShowPlayIcon
            smallViewImageView(preview, file)
                .onTapGesture {
                    decrypt(file: file) { showFullScreenPlayer = urlDecrypted != nil }
                }
                .onChange(of: m.activeCallViewIsCollapsed) { _, _ in showFullScreenPlayer = false }
            pxSmallEncryptedOverlay(pxCanPlay: pxCanPlay, file: file)
        }
    }

    @ViewBuilder
    private func pxSmallEncryptedOverlay(pxCanPlay: Bool, file: CIFile) -> some View {
        if file.showStatusIconInSmallView {
            // Show nothing
        } else if !decryptionInProgress {
            playPauseIcon(pxCanPlay ? "play.fill" : "play.slash")
        } else {
            videoDecryptionProgress()
        }
    }

    private func smallVideoView(_ url: URL, _ file: CIFile, _ preview: UIImage) -> some View {
        ZStack(alignment: .topLeading) {
            smallViewImageView(preview, file)
                .onTapGesture { showFullScreenPlayer = true }
                .onChange(of: m.activeCallViewIsCollapsed) { _, _ in showFullScreenPlayer = false }
            if !file.showStatusIconInSmallView {
                playPauseIcon("play.fill")
            }
        }
    }

    // MARK: - POPOPX Visual Components

    private func playPauseIcon(_ image: String, _ color: Color = .white) -> some View {
        Image(systemName: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(color)
            .frame(width: pxVM.playIconSize, height: pxVM.playIconSize)
            .padding(.leading, smallView ? 0 : PXCIVideoConfig.playButtonLeadingPadding)
            .frame(width: pxVM.playButtonFrame, height: pxVM.playButtonFrame)
            .background(Color.black.opacity(PXCIVideoConfig.playButtonBackgroundOpacity))
            .clipShape(Circle())
            .shadow(
                color: .black.opacity(isInDarkTheme() ? PXCIVideoConfig.playButtonShadowOpacity + 0.1 : PXCIVideoConfig.playButtonShadowOpacity),
                radius: PXCIVideoConfig.playButtonShadowRadius,
                x: 0,
                y: PXCIVideoConfig.playButtonShadowY
            )
    }

    private func videoDecryptionProgress(_ color: Color = .white) -> some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(color)
            .frame(width: pxVM.progressIndicatorSize, height: pxVM.progressIndicatorSize)
            .frame(width: pxVM.progressFrameSize, height: pxVM.progressFrameSize)
            .background(Color.black.opacity(PXCIVideoConfig.progressBackgroundOpacity))
            .clipShape(Circle())
    }

    private func durationProgress() -> some View {
        Text((durationText(videoPlaying ? progress : duration)) + pxVM.displayFileSize)
            .font(.caption)
            .invertedForegroundStyle()
            .padding(.vertical, PXCIVideoConfig.durationVerticalPadding)
            .padding(.horizontal, PXCIVideoConfig.durationHorizontalPadding)
    }

    private func imageView(_ img: UIImage) -> some View {
        let w = img.size.width <= img.size.height ? maxWidth * PXCIVideoConfig.portraitWidthRatio : maxWidth
        return ZStack(alignment: .topTrailing) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: w, height: w * heightRatio(img.size))
                .clipped()
                .modifier(PrivacyBlur(blurred: $blurred))
            if !blurred || !showDownloadButton(chatItem.file?.fileStatus) {
                fileStatusIcon()
            }
        }
    }

    private func smallViewImageView(_ img: UIImage, _ file: CIFile) -> some View {
        ZStack(alignment: .center) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: maxWidth, height: maxWidth)
            if file.showStatusIconInSmallView {
                fileStatusIcon()
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - POPOPX File Status Icons

    @ViewBuilder private func fileStatusIcon() -> some View {
        if let file = chatItem.file {
            switch file.fileStatus {
            case .sndStored:
                pxSndStoredIcon(file)
            case let .sndTransfer(sndProgress, sndTotal):
                pxSndTransferIcon(file, sndProgress, sndTotal)
            case .sndComplete:
                fileIcon("checkmark", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
            case .sndCancelled:
                fileIcon("xmark", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
            case let .sndError(sndFileError):
                fileIcon("xmark", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
                    .simultaneousGesture(TapGesture().onEnded { showFileErrorAlert(sndFileError) })
            case let .sndWarning(sndFileError):
                fileIcon("exclamationmark.triangle.fill", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
                    .simultaneousGesture(TapGesture().onEnded { showFileErrorAlert(sndFileError, temporary: true) })
            case .rcvInvitation:
                fileIcon(file.expired && fileSizeValid(file) ? "xmark" : "arrow.down", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
            case .rcvAccepted:
                fileIcon("ellipsis", PXCIVideoConfig.fileIndicatorSecondarySize, PXCIVideoConfig.fileIndicatorSecondaryPadding)
            case let .rcvTransfer(rcvProgress, rcvTotal):
                pxRcvTransferIcon(file, rcvProgress, rcvTotal)
            case .rcvAborted:
                fileIcon("exclamationmark.arrow.circlepath", PXCIVideoConfig.fileIndicatorSecondarySize, PXCIVideoConfig.fileIndicatorSecondaryPadding)
            case .rcvComplete:
                EmptyView()
            case .rcvCancelled:
                fileIcon("xmark", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
            case let .rcvError(rcvFileError):
                fileIcon("xmark", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
                    .simultaneousGesture(TapGesture().onEnded { showFileErrorAlert(rcvFileError, file) })
            case let .rcvWarning(rcvFileError):
                fileIcon("exclamationmark.triangle.fill", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
                    .simultaneousGesture(TapGesture().onEnded { showFileErrorAlert(rcvFileError, temporary: true) })
            case .invalid:
                fileIcon("questionmark", PXCIVideoConfig.fileIndicatorSize, PXCIVideoConfig.fileIndicatorPadding)
            }
        }
    }

    @ViewBuilder
    private func pxSndStoredIcon(_ file: CIFile) -> some View {
        switch file.fileProtocol {
        case .xftp: progressView()
        case .smp: EmptyView()
        case .local: EmptyView()
        }
    }

    @ViewBuilder
    private func pxSndTransferIcon(_ file: CIFile, _ sndProgress: Int64, _ sndTotal: Int64) -> some View {
        switch file.fileProtocol {
        case .xftp: progressCircle(sndProgress, sndTotal)
        case .smp: progressView()
        case .local: EmptyView()
        }
    }

    @ViewBuilder
    private func pxRcvTransferIcon(_ file: CIFile, _ rcvProgress: Int64, _ rcvTotal: Int64) -> some View {
        if file.fileProtocol == .xftp && rcvProgress < rcvTotal {
            progressCircle(rcvProgress, rcvTotal)
        } else {
            progressView()
        }
    }

    private func fileIcon(_ icon: String, _ size: CGFloat, _ padding: CGFloat) -> some View {
        Image(systemName: icon)
            .resizable()
            .invertedForegroundStyle()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .padding(smallView ? 0 : padding)
    }

    private func progressView() -> some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
            .frame(width: PXCIVideoConfig.progressCircleFrameSize, height: PXCIVideoConfig.progressCircleFrameSize)
            .padding(smallView ? 0 : PXCIVideoConfig.statusIconSecondaryPadding)
    }

    private func progressCircle(_ progress: Int64, _ total: Int64) -> some View {
        Circle()
            .trim(from: 0, to: Double(progress) / Double(total))
            .stroke(style: StrokeStyle(lineWidth: PXCIVideoConfig.progressCircleLineWidth))
            .invertedForegroundStyle()
            .rotationEffect(.degrees(-90))
            .frame(width: PXCIVideoConfig.progressCircleFrameSize, height: PXCIVideoConfig.progressCircleFrameSize)
            .padding([.trailing, .top], smallView ? 0 : PXCIVideoConfig.statusIconSecondaryPadding)
    }

    // MARK: - POPOPX File Operations

    private func receiveFileIfValidSize(file: CIFile, receiveFile: @escaping (User, Int64, Bool, Bool) async -> Void) {
        logger.debug("PX: [receiveFileIfValidSize] called, fileSize: \(file.fileSize)")
        if let prohibited = file.fileProhibited {
            showProhibitedFileAlert(file, prohibited)
        } else {
            Task {
                if let user = m.currentUser {
                    await receiveFile(user, file.fileId, false, false)
                }
            }
        }
    }

    // MARK: - POPOPX Full Screen Player

    private func fullScreenPlayer(_ url: URL) -> some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VideoPlayer(player: fullPlayer)
                .overlay(alignment: .topLeading, content: { pxFullScreenCloseButton })
                .gesture(pxFullScreenDismissGesture)
                .onAppear { pxSetupFullScreenPlayback(url) }
                .onDisappear { pxTearDownFullScreenPlayback() }
        }
    }

    private var pxFullScreenCloseButton: some View {
        Button(action: { showFullScreenPlayer = false }) {
            Image(systemName: "multiply")
                .resizable()
                .tint(.white)
                .frame(width: PXCIVideoConfig.fullScreenCloseIconSize, height: PXCIVideoConfig.fullScreenCloseIconSize)
                .padding(.leading, PXCIVideoConfig.fullScreenCloseLeadingPadding)
                .padding(.top, PXCIVideoConfig.fullScreenCloseTopPadding)
        }
        .accessibilityLabel(NSLocalizedString("Close full screen player", comment: ""))
    }

    private var pxFullScreenDismissGesture: some Gesture {
        DragGesture(minimumDistance: PXCIVideoConfig.fullScreenDragThreshold)
            .onChanged { gesture in
                let t = gesture.translation
                let w = abs(t.width)
                if t.height > PXCIVideoConfig.fullScreenDragVerticalMin && t.height > w * PXCIVideoConfig.fullScreenDragHorizontalMultiplier {
                    showFullScreenPlayer = false
                }
            }
    }

    private func pxSetupFullScreenPlayback(_ url: URL) {
        if fullPlayer == nil {
            fullPlayer = AVPlayer(url: url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if m.stopPreviousRecPlay != url { m.stopPreviousRecPlay = url }
            if let player = fullPlayer {
                player.play()
                var played = false
                publisher = player.publisher(for: \.timeControlStatus).sink { status in
                    if played || status == .playing {
                        AppDelegate.keepScreenOn(status == .playing)
                        AudioPlayer.changeAudioSession(status == .playing)
                    }
                    played = status == .playing
                }
                fullScreenTimeObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                    player.seek(to: CMTime.zero)
                    player.play()
                }
            }
        }
    }

    private func pxTearDownFullScreenPlayback() {
        if let fullScreenTimeObserver = fullScreenTimeObserver {
            NotificationCenter.default.removeObserver(fullScreenTimeObserver)
        }
        fullScreenTimeObserver = nil
        fullPlayer?.pause()
        fullPlayer?.seek(to: CMTime.zero)
        publisher?.cancel()
    }

    // POPOPX: decrypt video source and prepare playback
    private func decrypt(file: CIFile, completed: (() -> Void)? = nil) {
        guard !decryptionInProgress else { return }
        logger.debug("PX: [decrypt] starting for file: \(file.fileName)")
        decryptionInProgress = true
        Task {
            urlDecrypted = await file.fileSource?.decryptedGetOrCreate(&ChatModel.shared.filesToDelete)
            await MainActor.run {
                if let pxDecrypted = urlDecrypted {
                    if !smallView {
                        player = VideoPlayerView.getOrCreatePlayer(pxDecrypted, false)
                    }
                }
                decryptionInProgress = false
                logger.debug("PX: [decrypt] completed, decrypted: \(urlDecrypted != nil)")
                completed?()
            }
        }
    }

    private func addObserver(_ player: AVPlayer, _ url: URL) {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: PXCIVideoConfig.timeObserverInterval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { time in
            if let item = player.currentItem {
                let dur = CMTimeGetSeconds(item.duration)
                if !dur.isInfinite && !dur.isNaN {
                    duration = Int(dur)
                }
                progress = Int(CMTimeGetSeconds(player.currentTime()))
                if player.currentTime() != player.currentItem?.duration && player.currentTime() != .zero {
                    videoPlaying = player.timeControlStatus == .playing || player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                }
            }
        }
    }

    private func removeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
    }
}

// MARK: - POPOPX
extension PXVideoPlayer {
    var pxComponentTag: String { "px-video-item" }
    var pxVideoSizeMultiplier: CGFloat { PXCIVideoConfig.smallViewSizeMultiplier }
    var pxPlayButtonFrame: CGFloat { PXCIVideoConfig.playButtonFrameSize }
}
