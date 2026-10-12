// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import CoreHaptics
import SwiftUI

@MainActor
class BubbleHapticsManager {
    static let shared = BubbleHapticsManager()

    private var engine: CHHapticEngine?
    private var isEngineReady = false

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.prepareEngine()
                }
            }
            engine?.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.isEngineReady = false
                }
            }
            prepareEngine()
        } catch {
            engine = nil
        }
    }

    private func prepareEngine() {
        do {
            try engine?.start()
            isEngineReady = true
        } catch {
            isEngineReady = false
        }
    }

    func popAuto() {
        guard isEngineReady, let engine else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func popManual() {
        guard isEngineReady, let engine else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            return
        }
        do {
            let puncture = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            )

            let burst = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.03
            )

            let pattern = try CHHapticPattern(events: [puncture, burst], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    func popDoubleMicroTap() {
        // Two consecutive micro-vibrations (100ms apart) for gravitational collapse trigger
        guard isEngineReady, let engine else {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred()
            }
            return
        }
        do {
            let firstTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )

            let secondTap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.1 // 100ms delay
            )

            let pattern = try CHHapticPattern(events: [firstTap, secondTap], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred()
            }
        }
    }

    func popExplosion() {
        guard isEngineReady, let engine else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
            }
            return
        }
        do {
            // T=0s: Rigid impact - simulates bubble surface tension release
            let punch = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
                ],
                relativeTime: 0
            )

            // T=0.01-0.3s: Soft decay events - simulates rainbow particles sliding down
            var decayEvents: [CHHapticEvent] = []
            let stepCount = 10 // Increased from 6 for smoother decay
            let duration: Double = 0.3 // Extended to 0.3s per spec
            
            for i in 0..<stepCount {
                let t = 0.01 + Double(i) * (duration / Double(stepCount - 1))
                let progress = Double(i) / Double(stepCount - 1)
                // Quadratic decay: intensity drops faster initially, then slower
                let intensity = Float(0.3 * pow(1.0 - progress, 2))
                let sharpness = Float(0.2 * (1.0 - progress))
                
                decayEvents.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.02, intensity)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0.02, sharpness))
                    ],
                    relativeTime: t
                ))
            }

            let pattern = try CHHapticPattern(events: [punch] + decayEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    func popLargeFile() {
        guard isEngineReady, let engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        do {
            let rumble = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            )

            let snap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.15
            )

            let pattern = try CHHapticPattern(events: [rumble, snap], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func swipeTrail(intensity: Float) {
        guard isEngineReady, let engine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.1, min(intensity, 1.0))),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - POPOPX
extension BubbleHapticsManager {
    static let pxComponentTag: String = "PX_BUBBLE_HAPTICS"
}
