// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct ShieldGlowEffect: ViewModifier {
    var color: Color = QuantumColors.accent
    var intensity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var pulsePhase: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation(minimumInterval: 1.0/30.0, paused: powerMode.isLowPowerMode || reduceMotion || scenePhase != .active)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let pulse = reduceMotion ? 0.5 : (0.5 + 0.5 * sin(time * 2.0 * intensity))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.3 * pulse), color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            )
    }
}

struct QuantumPulseAnimation: ViewModifier {
    var color: Color = QuantumColors.accent
    var duration: Double = 2.0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation(minimumInterval: 1.0/30.0, paused: powerMode.isLowPowerMode || reduceMotion || scenePhase != .active)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let progress = reduceMotion ? 0 : ((time.truncatingRemainder(dividingBy: duration)) / duration)
                    let scale = 1.0 + progress * 0.5
                    let opacity = 1.0 - progress

                    Circle()
                        .stroke(color.opacity(opacity * 0.4), lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .scaleEffect(scale)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            )
    }
}

extension View {
    func shieldGlow(color: Color = QuantumColors.accent, intensity: Double = 1.0) -> some View {
        modifier(ShieldGlowEffect(color: color, intensity: intensity))
    }

    func quantumPulse(color: Color = QuantumColors.accent, duration: Double = 2.0) -> some View {
        modifier(QuantumPulseAnimation(color: color, duration: duration))
    }
}
