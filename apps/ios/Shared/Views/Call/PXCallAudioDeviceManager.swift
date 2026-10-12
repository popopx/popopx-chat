//
//  PXCallAudioDeviceManager.swift
//  POPOPX (iOS)
//
//  Manages audio routing and device selection during active calls.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI
import POPOPXSwitch
import AVKit
import WebRTC

// MARK: - Routing constants

/// Timing thresholds for audio route polling and bluetooth drift detection.
private enum PXAudioRouting {
    /// Interval for polling audio route changes after bluetooth disconnect
    static let devicePollInterval: TimeInterval = 2.0
    /// Threshold for detecting bluetooth audio drift
    static let bluetoothDriftThreshold: TimeInterval = 6.0
    /// Number of consecutive polls before giving up on bluetooth recovery
    static let maxPollAttempts: Int = 5
    /// Delay before first route check after session activation
    static let initialRouteCheckDelay: TimeInterval = 0.5
}

// MARK: - Audio device manager

/// Observes AVAudioSession route changes and keeps published device lists in sync.
@MainActor
class CallAudioDeviceManager: ObservableObject {
    static let shared = CallAudioDeviceManager()
    let audioSession: AVAudioSession
    let nc = NotificationCenter.default

    var call: Call?
    var timer: Timer? = nil

    // Actually, only one output
    @Published var outputs: [AVAudioSessionPortDescription]
    @Published var currentDevice: AVAudioSessionPortDescription? = nil
    // All devices that can record audio (the ones that can play audio are not included)
    @Published var availableInputs: [AVAudioSessionPortDescription] = []

    init(_ audioSession: AVAudioSession? = nil) {
        self.audioSession = audioSession ?? RTCAudioSession.sharedInstance().session
        self.outputs = self.audioSession.currentRoute.outputs
        self.availableInputs = self.audioSession.availableInputs ?? []
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Device refresh

    /// Re-reads the current audio route and available inputs from the session.
    func reloadDevices() {
        outputs = audioSession.currentRoute.outputs
        currentDevice = audioSession.currentRoute.outputs.first
        availableInputs = audioSession.availableInputs ?? []
        Task { @MainActor in
            call?.speakerEnabled = currentDevice?.portType == .builtInSpeaker
        }

        // Workaround:
        // If a bluetooth device was connected and we chose speaker, then the
        // bluetooth device disconnects, iOS will not post a notification.
        // Schedule a manual poll to catch the route change.
        pxScheduleBluetoothPollIfNeeded()
    }

    // MARK: - Notification callback

    /// Handles AVAudioSession route-change notifications.
    @objc func audioCallback(notification: Notification) {
        reloadDevices()

        logger.debug("Changes in devices, current audio devices: \(String(describing: self.availableInputs.map({ $0.portType.rawValue }))), output: \(String(describing: self.currentDevice?.portType.rawValue))")
    }

    // MARK: - Lifecycle

    /// Begins observing audio route changes.
    func start() {
        nc.addObserver(self, selector: #selector(audioCallback), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    /// Stops observing and invalidates any pending poll timer.
    func stop() {
        nc.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        timer?.invalidate()
    }

    // MARK: - Private helpers

    /// Schedules a one-shot timer to re-read devices if a non-built-in input is present.
    private func pxScheduleBluetoothPollIfNeeded() {
        timer?.invalidate()
        let pxHasExternalInput = availableInputs.contains(where: { $0.portType != .builtInReceiver && $0.portType != .builtInSpeaker })
        if pxHasExternalInput {
            timer = Timer.scheduledTimer(withTimeInterval: PXAudioRouting.devicePollInterval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.reloadDevices()
                }
            }
        }
    }

    /// Returns a human-readable summary of the current audio route for debugging.
    func pxRouteDescription() -> String {
        let pxOutputName = currentDevice?.portType.rawValue ?? "none"
        let pxInputNames = availableInputs.map { $0.portType.rawValue }
        return "output=\(pxOutputName) inputs=\(pxInputNames.joined(separator: ","))"
    }
}

// MARK: - POPOPX

/// Namespace for POPOPX-specific audio device manager constants and helpers.
extension CallAudioDeviceManager {
    static let pxComponentTag: String = "PX_CALL_AUDIO_DEVICE_MANAGER"
    static let pxTimerInterval: TimeInterval = PXAudioRouting.devicePollInterval
    static let pxMaxBluetoothDriftSeconds: TimeInterval = PXAudioRouting.bluetoothDriftThreshold
    static var pxHasBluetoothDevice: Bool {
        shared.availableInputs.contains { $0.portType != .builtInReceiver && $0.portType != .builtInSpeaker }
    }
    static var pxActivePortDescription: String {
        shared.currentDevice?.portType.rawValue ?? "none"
    }
    /// Maximum number of bluetooth poll attempts before giving up
    static let pxMaxPollRetries: Int = PXAudioRouting.maxPollAttempts
    /// Whether the speaker is currently the active output
    static var pxIsSpeakerActive: Bool {
        shared.currentDevice?.portType == .builtInSpeaker
    }
    /// Returns the number of available input devices
    static var pxInputDeviceCount: Int {
        shared.availableInputs.count
    }
}
