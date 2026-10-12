//
//  PXFullScreenMediaView.swift
//  POPOPX (iOS)
//
//  POPOPX full-screen media viewer for images and video in chat.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import SwiftyGif
import AVKit

// MARK: - POPOPX Media Configuration
private enum PXMediaConfig {
    static let featureEnabled: Bool = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")
    static let scrollAnimDuration: Double = 0.2 * 0.8
    static let dragMinimumDistance: CGFloat = 80
    static let dismissVerticalThreshold: CGFloat = 60
    static let scrollHorizontalThreshold: CGFloat = 60
    static let horizontalToVerticalRatio: CGFloat = 2
}

// Spec: spec/client/chat-view.md#FullScreenMediaView
struct FullScreenMediaView: View {
    @EnvironmentObject var m: ChatModel
    @State var chatItem: ChatItem
    var scrollToItem: ((ChatItem.ID) -> Void)?
    @State var image: UIImage?
    @State var player: AVPlayer? = nil
    @State var url: URL? = nil
    @Binding var showView: Bool
    @State private var showNext = false
    @State private var nextImage: UIImage?
    @State private var nextPlayer: AVPlayer?
    @State private var nextURL: URL?
    @State private var scrolling = false
    @State private var offset: CGFloat = 0
    @State private var nextOffset: CGFloat = 0

    var body: some View {
        pxMediaContainer
            .popopxBranded()
    }

    // MARK: - POPOPX Container

    private var pxMediaContainer: some View {
        GeometryReader(content: pxMediaScrollContent)
    }

    // MARK: - POPOPX Scroll Content

    func pxMediaScrollContent(_ g: GeometryProxy) -> some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            if showNext, let nextImage = nextImage {
                pxCurrentMediaLayer
                imageView(nextImage).offset(x: offset + nextOffset)
            } else if showNext, let nextPlayer = nextPlayer, let nextURL = nextURL {
                pxCurrentMediaLayer
                videoView(nextPlayer, nextURL).offset(x: offset + nextOffset)
            } else {
                ZoomableScrollView {
                    pxCurrentMediaLayer
                }
            }
        }
        .onAppear {
            pxStartPlayback()
        }
        .onDisappear {
            player?.pause()
            nextPlayer?.pause()
        }
        .gesture(
            DragGesture(minimumDistance: PXMediaConfig.dragMinimumDistance)
            .onChanged { gesture in
                pxHandleDrag(gesture: gesture, g: g)
            }
            .onEnded { _ in scrolling = false }
        )
    }

    @ViewBuilder private var pxCurrentMediaLayer: some View {
        if let image = image {
            imageView(image).offset(x: offset)
        } else if let player = player, let url = url {
            videoView(player, url).offset(x: offset)
        }
    }

    // MARK: - POPOPX Drag Handler

    private func pxHandleDrag(gesture: DragGesture.Value, g: GeometryProxy) {
        let t = gesture.translation
        let w = abs(t.width)
        logger.debug("PX: [handleMediaDragGesture] translation h=\(t.height) w=\(w)")
        if t.height > PXMediaConfig.dismissVerticalThreshold && t.height > w * PXMediaConfig.horizontalToVerticalRatio {
            showView = false
            scrollToItem?(chatItem.id)
        } else if w > PXMediaConfig.scrollHorizontalThreshold && w > abs(t.height) * PXMediaConfig.horizontalToVerticalRatio && !scrolling {
            let previous = t.width > 0
            scrolling = true
            if let item = m.nextChatItemData(chatItem.id, previous: previous, map: chatItemImage) {
                var img: UIImage?
                var url: URL?
                (chatItem, img, url) = item
                nextImage = img
                nextPlayer?.pause()
                if let url = url {
                    nextPlayer = VideoPlayerView.getOrCreatePlayer(url, true)
                } else {
                    nextPlayer = nil
                }
                nextURL = url
                let pxContainerWidth = g.size.width
                var toOffset: CGFloat
                (toOffset, nextOffset) = previous ? (pxContainerWidth, -pxContainerWidth) : (-pxContainerWidth, pxContainerWidth)
                showNext = true
                withAnimation(.easeIn(duration: PXMediaConfig.scrollAnimDuration)) {
                    offset = toOffset
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + PXMediaConfig.scrollAnimDuration) {
                    image = img
                    player?.pause()
                    self.url = url
                    if let url = url {
                        player = VideoPlayerView.getOrCreatePlayer(url, true)
                        pxStartPlayback()
                    } else {
                        player = nil
                    }
                    showNext = false
                    offset = 0
                }
            }
        }
    }

    // MARK: - POPOPX Media Views

    private func imageView(_ img: UIImage) -> some View {
        ZStack {
            Color.black
            if img.imageData == nil {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                SwiftyGif(image: img)
                        .scaledToFit()
            }
        }
        .onTapGesture { showView = false } // this is used in full screen view, onTapGesture works
        .accessibilityLabel(NSLocalizedString("Full screen media image", comment: "Accessibility label for full screen image view"))
    }

    private func videoView( _ player: AVPlayer, _ url: URL) -> some View {
        VideoPlayerView(player: player, url: url, showControls: true)
            .accessibilityLabel(NSLocalizedString("Full screen media video", comment: "Accessibility label for full screen video view"))
    }

    private func chatItemImage(_ ci: ChatItem) -> (ChatItem, UIImage?, URL?)? {
        if case .image = ci.content.msgContent,
           let img = getLoadedImage(ci.file) {
            return (ci, img, nil)
        }
        // Currently, video support in gallery is not enabled
         /*else if case .video = ci.content.msgContent,
           let url = getLoadedVideo(ci.file) {
            return (ci, nil, url)
        }*/
        return nil
    }

    private func pxStartPlayback() {
        guard let pxPlayer = player else { return }
        logger.debug("PX: [startPlayerAndNotify] starting playback, url=\(url?.absoluteString ?? "nil")")
        m.stopPreviousRecPlay = url
        pxPlayer.play()
    }
}

// MARK: - POPOPX Component Identity
extension FullScreenMediaView {
    var pxComponentTag: String { "px-fullscreen-media" }

    /// Whether media is currently playing
    var pxIsPlaying: Bool { player?.timeControlStatus == .playing }

    /// Whether there is a next media item queued for transition
    var pxHasQueuedNext: Bool { showNext }
}
