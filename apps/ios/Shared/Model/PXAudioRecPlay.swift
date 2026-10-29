//
//  PXAudioRecPlay.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 19/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
@preconcurrency import AVFoundation
import SwiftUI
import os
import POPOPXSwitch

@MainActor
class AudioRecorder {
    var onTimer: ((TimeInterval) -> Void)?
    var onFinishRecording: (() -> Void)?

    var audioRecorder: AVAudioRecorder?
    var recordingTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var scenePhaseObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    init(onTimer: @escaping ((TimeInterval) -> Void), onFinishRecording: @escaping (() -> Void)) {
        self.onTimer = onTimer
        self.onFinishRecording = onFinishRecording
        scenePhaseObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTimer?.invalidate()
                self?.recordingTimer = nil
            }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.audioRecorder != nil, self.recordingTimer == nil else { return }
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    Task { @MainActor in
                        guard let self else { timer.invalidate(); return }
                        guard let time = self.audioRecorder?.currentTime else { return }
                        self.onTimer?(time)
                        if time >= MAX_VOICE_MESSAGE_LENGTH {
                            self.stop()
                            self.onFinishRecording?()
                        }
                    }
                }
            }
        }
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = scenePhaseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        recordingTimer?.invalidate()
        audioRecorder?.stop()
    }

    enum StartError {
        case permission
        case error(String)
    }

    func start(fileName: String) async -> StartError? {
        logger.debug("PX: AudioRecorder.start called, fileName=\(fileName)")
        let av = AVAudioSession.sharedInstance()
        if !(await checkPermission()) { return .permission }
        do {
            try av.setCategory(AVAudioSession.Category.playAndRecord, options: .defaultToSpeaker)
            try av.setActive(true)
            let settings: [String : Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16000,
                AVEncoderBitRateKey: 32000,
                AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_VariableConstrained,
                AVNumberOfChannelsKey: 1
            ]
            let url = getAppFilePath(fileName)
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record(forDuration: MAX_VOICE_MESSAGE_LENGTH)

            interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: av, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    guard let self, self.audioRecorder != nil else { return }
                    self.stop()
                    self.onFinishRecording?()
                }
            }

            await MainActor.run {
                AppDelegate.keepScreenOn(true)
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    Task { @MainActor in
                        guard let self else { timer.invalidate(); return }
                        guard let time = self.audioRecorder?.currentTime else { return }
                        self.onTimer?(time)
                        if time >= MAX_VOICE_MESSAGE_LENGTH {
                            self.stop()
                            self.onFinishRecording?()
                        }
                    }
                }
            }
            return nil
        } catch let error {
            await MainActor.run {
                AppDelegate.keepScreenOn(false)
            }
            try? av.setCategory(AVAudioSession.Category.soloAmbient)
            logger.error("AudioRecorder startAudioRecording error \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    func stop() {
        if let recorder = audioRecorder {
            recorder.stop()
        }
        audioRecorder = nil
        if let timer = recordingTimer {
            timer.invalidate()
        }
        recordingTimer = nil
        AppDelegate.keepScreenOn(false)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient)
    }

    private func checkPermission() async -> Bool {
        let permissionGranted: Bool
        if #available(iOS 17.0, *) {
            permissionGranted = await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        } else {
            let av = AVAudioSession.sharedInstance()
            switch av.recordPermission {
            case .granted: return true
            case .denied: return false
            case .undetermined:
                permissionGranted = await withCheckedContinuation { cont in
                    DispatchQueue.main.async {
                        av.requestRecordPermission { allowed in
                            cont.resume(returning: allowed)
                        }
                    }
                }
            @unknown default: return false
            }
        }
        return permissionGranted
    }
}

@MainActor
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    var onTimer: ((TimeInterval) -> Void)?
    var onFinishPlayback: (() -> Void)?

    var audioPlayer: AVAudioPlayer?
    var playbackTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var scenePhaseObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    init(onTimer: @escaping ((TimeInterval) -> Void), onFinishPlayback: @escaping (() -> Void)) {
        self.onTimer = onTimer
        self.onFinishPlayback = onFinishPlayback
        super.init()
        scenePhaseObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playbackTimer?.invalidate()
                self?.playbackTimer = nil
            }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.audioPlayer != nil, self.playbackTimer == nil else { return }
                self.playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    Task { @MainActor in
                        guard let self else { timer.invalidate(); return }
                        if self.audioPlayer?.isPlaying ?? false {
                            AppDelegate.keepScreenOn(true)
                            guard let time = self.audioPlayer?.currentTime else { return }
                            self.onTimer?(time)
                            AudioPlayer.changeAudioSession(true)
                        } else {
                            AudioPlayer.changeAudioSession(false)
                        }
                    }
                }
            }
        }
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = scenePhaseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        playbackTimer?.invalidate()
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
    }

    func start(fileSource: CryptoFile, at: TimeInterval?) {
        let url = getAppFilePath(fileSource.filePath)
        if let cfArgs = fileSource.cryptoArgs {
            if let data = try? readCryptoFile(path: url.path, cryptoArgs: cfArgs) {
                do {
                    audioPlayer = try AVAudioPlayer(data: data)
                } catch {
                    os_log(.error, "PXAudioRecPlay: failed to create audio player from data: %{public}@", error.localizedDescription)
                }
            }
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
            } catch {
                os_log(.error, "PXAudioRecPlay: failed to create audio player from URL: %{public}@", error.localizedDescription)
            }
        }
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        if let at = at {
            audioPlayer?.currentTime = at
        }
        audioPlayer?.play()

        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self else { return }
                self.pause()
            }
        }

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                if self.audioPlayer?.isPlaying ?? false {
                    AppDelegate.keepScreenOn(true)
                    guard let time = self.audioPlayer?.currentTime else { return }
                    self.onTimer?(time)
                    AudioPlayer.changeAudioSession(true)
                } else {
                    AudioPlayer.changeAudioSession(false)
                }
            }
        }
    }

    func pause() {
        audioPlayer?.pause()
        AppDelegate.keepScreenOn(false)
    }

    func play() {
        audioPlayer?.play()
    }

    func seek(_ to: TimeInterval) {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
            audioPlayer?.currentTime = to
            audioPlayer?.play()
        } else {
            audioPlayer?.currentTime = to
        }
        self.onTimer?(to)
    }

    func stop() {
        if let player = audioPlayer {
            player.stop()
            AppDelegate.keepScreenOn(false)
            AudioPlayer.changeAudioSession(false)
        }
        audioPlayer = nil
        if let timer = playbackTimer {
            timer.invalidate()
        }
        playbackTimer = nil
    }

    static func changeAudioSession(_ playback: Bool) {
        // When there is a audio recording, setting any other category will disable sound
        if AVAudioSession.sharedInstance().category == .playAndRecord {
            return
        }
        if playback {
            if AVAudioSession.sharedInstance().category != .playback {
                logger.log("AudioSession: playback")
                try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: [.duckOthers, .allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP])
            }
        } else {
            if AVAudioSession.sharedInstance().category != .soloAmbient {
                logger.log("AudioSession: soloAmbient")
                try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.soloAmbient)
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stop()
            self.onFinishPlayback?()
        }
    }
}

// MARK: - POPOPX
extension AudioRecorder {
    static let pxComponentTag: String = "PXAudioRecPlay"
    static let pxSampleRate: Double = 16000
    static let pxBitRate: Int = 32000
    static let pxTimerInterval: TimeInterval = 0.1
}
