//
//  PXVideoPlayerView.swift
//  POPOPX (iOS)
//
//  Created by Avently on 30.03.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation
import SwiftUI
import AVKit
import Combine

// MARK: - POPOPX Configuration
private enum PXVideoPlayerConfig {
    static let cacheLimit: Int32 = 15
    static let loopRestartTime: CMTime = CMTime.zero
    static let componentIdentifier = "PX_VIDEO_PLAYER_VIEW"
    static let videoGravity: AVLayerVideoGravity = .resizeAspectFill
}

struct VideoPlayerView: UIViewRepresentable {

    static let players: NSCache<NSString, AVPlayer> = {
        let cache = NSCache<NSString, AVPlayer>()
        cache.countLimit = Int(PXVideoPlayerConfig.cacheLimit)
        return cache
    }()
    private static var activePlayerKeys: [NSString] = []

    @MainActor
    static func getOrCreatePlayer(_ url: URL, _ gallery: Bool) -> AVPlayer {
        let key = pxPlayerCacheKey(url, gallery) as NSString
        if let cached = players.object(forKey: key) {
            return cached
        }
        let player = AVPlayer(url: url)
        players.setObject(player, forKey: key)
        activePlayerKeys.append(key)
        return player
    }

    @MainActor
    static func removeAllPlayers() {
        pxPauseAllActive()
        activePlayerKeys.removeAll()
        players.removeAllObjects()
    }

    static func removePlayer(forKey key: NSString) {
        players.object(forKey: key)?.pause()
        if let idx = activePlayerKeys.firstIndex(of: key as NSString) {
            activePlayerKeys.remove(at: idx)
        }
        players.removeObject(forKey: key)
    }

    /// POPOPX: pause every active player before clearing
    private static func pxPauseAllActive() {
        for key in activePlayerKeys {
            players.object(forKey: key)?.pause()
        }
    }

    typealias UIViewType = UIView
    let player: AVPlayer
    let url: URL
    let showControls: Bool

    func makeUIView(context: UIViewRepresentableContext<VideoPlayerView>) -> UIView {
        let controller = pxConfigureController()
        controller.player = player
        context.coordinator.controller = controller
        pxAttachLoopObserver(controller: controller, context: context)
        pxAttachStatusPublisher(context: context)
        return controller.view
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<VideoPlayerView>) {
    }

    func makeCoordinator() -> VideoPlayerView.Coordinator {
        Coordinator()
    }

    // MARK: - POPOPX Setup Helpers

    /// POPOPX: create and configure the AVPlayerViewController
    private func pxConfigureController() -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = showControls
        controller.videoGravity = PXVideoPlayerConfig.videoGravity
        controller.speeds = Self.pxEmptyPlaybackSpeeds
        return controller
    }

    /// POPOPX: attach end-of-item loop observer
    private func pxAttachLoopObserver(controller: AVPlayerViewController, context: UIViewRepresentableContext<VideoPlayerView>) {
        context.coordinator.timeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: PXVideoPlayerConfig.loopRestartTime)
            player?.play()
        }
    }

    /// POPOPX: attach timeControlStatus publisher for screen-on / audio session
    private func pxAttachStatusPublisher(context: UIViewRepresentableContext<VideoPlayerView>) {
        var played = false
        context.coordinator.publisher = player.publisher(for: \.timeControlStatus).sink { status in
            if played || status == .playing {
                AppDelegate.keepScreenOn(status == .playing)
                AudioPlayer.changeAudioSession(status == .playing)
            }
            played = status == .playing
        }
    }

    class Coordinator: NSObject {
        var controller: AVPlayerViewController?
        var timeObserver: Any? = nil
        var publisher: AnyCancellable? = nil

        deinit {
            if let timeObserver = timeObserver {
                NotificationCenter.default.removeObserver(timeObserver)
            }
            publisher?.cancel()
        }
    }
}

// MARK: - POPOPX
extension VideoPlayerView {
    static let pxComponentTag: String = PXVideoPlayerConfig.componentIdentifier
    static let pxLoopRestartTime: CMTime = PXVideoPlayerConfig.loopRestartTime
    static let pxEmptyPlaybackSpeeds: [AVPlaybackSpeed] = []
    static let pxCacheCapacity: Int32 = PXVideoPlayerConfig.cacheLimit

    static func pxPlayerCacheKey(_ url: URL, _ gallery: Bool) -> String {
        url.absoluteString + gallery.description
    }

    /// POPOPX: check whether a player exists for the given URL
    @MainActor
    static func pxHasCachedPlayer(for url: URL, gallery: Bool) -> Bool {
        let key = pxPlayerCacheKey(url, gallery) as NSString
        return players.object(forKey: key) != nil
    }
}
