//
//  MicrophoneBlowDetector.swift
//  POPOPX
//
//  Detects blow intensity via microphone for balloon inflation.
//  Copyright © 2026 POPOPX. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import os

private let blowLogger = Logger(subsystem: "im.popopx", category: "MicrophoneBlowDetector")

@MainActor
class MicrophoneBlowDetector: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    @Published var currentScale: CGFloat = 1.0
    var isHoldingButton: Bool = false

    init() {
        NotificationCenter.default.addObserver(
            forName: UIScene.willDeactivateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stopMonitoring() }
        }
    }

    func startMonitoring() {
        isHoldingButton = true
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]

            let url = URL(fileURLWithPath: "/dev/null")
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            // 120Hz polling for ProMotion displays
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateBlowMeter()
                }
            }
        } catch {
            blowLogger.debug("Microphone access failed: \(error)")
        }
    }

    private func updateBlowMeter() {
        guard let recorder = audioRecorder, isHoldingButton else { return }
        recorder.updateMeters()

        let averagePower = recorder.averagePower(forChannel: 0)

        // Threshold: -25dB triggers inflation
        if averagePower > -25.0 {
            let blowIntensity = CGFloat(averagePower + 25.0)
            withAnimation(.linear(duration: 1.0 / 120.0)) {
                if currentScale < 2.8 {
                    currentScale += blowIntensity * 0.003
                }
            }
        }
    }

    func stopMonitoring() {
        isHoldingButton = false
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        audioRecorder = nil

        // Spring back to idle
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            currentScale = 1.0
        }

        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
