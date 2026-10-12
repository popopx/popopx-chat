//
//  SoundPlayer.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 24/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import AVFoundation
import UIKit

// MARK: - POPOPX Configuration
private enum PXSoundPlayerConfig {
    static let componentTag: String = "PX_SOUND_PLAYER"
    static let vibrateSoundId: SystemSoundID = kSystemSoundID_Vibrate
    static let ringtoneName: String = "ringtone2"
    static let ringtoneExtension: String = "m4a"
    static let soundsDirectory: String = "sounds"
    static let callSoundExtension: String = "mp3"
    static let maxLoopDurationSecs: Double = 300
    static let nanoMultiplier: Double = 1_000_000_000
    static let connectingCallSound: String = "connecting_call"
    static let inCallSound: String = "in_call"
    static let inCallDelayMs: Double = 1000

    static func loadAudioResource(name: String, ext: String, directory: String) -> AVAudioPlayer? {
        guard let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: directory) else {
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            if player.prepareToPlay() { return player }
            return nil
        } catch {
            logger.debug("loadAudioResource: AVAudioPlayer error \(error.localizedDescription)")
            return nil
        }
    }

    static func performVibration(long: Bool) {
        if long {
            AudioServicesPlayAlertSound(vibrateSoundId)
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

@MainActor
class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?
    private var ringtoneTask: Task<Void, Never>?

    func startRingtone() {
        stopRingtone()
        logger.debug("startRingtone")
        guard let player = PXSoundPlayerConfig.loadAudioResource(
            name: PXSoundPlayerConfig.ringtoneName,
            ext: PXSoundPlayerConfig.ringtoneExtension,
            directory: PXSoundPlayerConfig.soundsDirectory
        ) else {
            logger.debug("startRingtone: file not found")
            return
        }
        audioPlayer = player

        ringtoneTask = Task { [weak self] in
            while let player = self?.audioPlayer, !Task.isCancelled {
                player.play()
                AudioServicesPlayAlertSound(PXSoundPlayerConfig.vibrateSoundId)
                do {
                    let durationSecs = min(max(player.duration, 0), PXSoundPlayerConfig.maxLoopDurationSecs)
                    try await Task.sleep(nanoseconds: UInt64(durationSecs * PXSoundPlayerConfig.nanoMultiplier))
                } catch {
                    break
                }
            }
        }
    }

    func stopRingtone() {
        ringtoneTask?.cancel()
        ringtoneTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

@MainActor
class CallSoundsPlayer {
    static let shared = CallSoundsPlayer()
    private var audioPlayer: AVAudioPlayer?
    private var playerTask: Task = Task {}

    private func start(_ soundName: String, delayMs: Double) {
        audioPlayer?.stop()
        playerTask.cancel()
        logger.debug("start \(soundName)")
        guard let player = PXSoundPlayerConfig.loadAudioResource(
            name: soundName,
            ext: PXSoundPlayerConfig.callSoundExtension,
            directory: PXSoundPlayerConfig.soundsDirectory
        ) else {
            logger.debug("start: file not found")
            return
        }
        audioPlayer = player

        playerTask = Task { [weak self] in
            while let player = self?.audioPlayer {
                player.play()
                do {
                    let durationSecs = min(max(player.duration, 0), PXSoundPlayerConfig.maxLoopDurationSecs)
                    let totalNanos = (durationSecs + delayMs / 1000.0) * PXSoundPlayerConfig.nanoMultiplier
                    try await Task.sleep(nanoseconds: UInt64(totalNanos))
                } catch {
                    break
                }
            }
        }
    }

    func startConnectingCallSound() {
        start(PXSoundPlayerConfig.connectingCallSound, delayMs: 0)
    }

    func startInCallSound() {
        // Taken from https://github.com/TelegramOrg/Telegram-Android
        // https://github.com/TelegramOrg/Telegram-Android/blob/master/LICENSE
        start(PXSoundPlayerConfig.inCallSound, delayMs: PXSoundPlayerConfig.inCallDelayMs)
    }

    func stop() {
        playerTask.cancel()
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func vibrate(long: Bool) {
        // iOS just don't want to vibrate more than once after a short period of time, and all 'styles' feel the same
        PXSoundPlayerConfig.performVibration(long: long)
    }
}

// MARK: - POPOPX
extension CallSoundsPlayer {
    static let pxComponentTag: String = PXSoundPlayerConfig.componentTag
    static let pxVibrateSoundId: SystemSoundID = PXSoundPlayerConfig.vibrateSoundId
    static let pxRingtoneName: String = PXSoundPlayerConfig.ringtoneName
    static let pxRingtoneExtension: String = PXSoundPlayerConfig.ringtoneExtension
    static let pxSoundsDirectory: String = PXSoundPlayerConfig.soundsDirectory
}
