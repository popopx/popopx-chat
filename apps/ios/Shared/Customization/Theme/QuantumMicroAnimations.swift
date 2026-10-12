// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct MessageSendAnimation: ViewModifier {
    @Binding var isSending: Bool
    var color: Color = QuantumColors.accent
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if isSending && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0/15.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let progress = min(1.0, time.truncatingRemainder(dividingBy: 0.6) / 0.6)

                        Circle()
                            .fill(color.opacity(0.6 * (1.0 - progress)))
                            .frame(width: 8, height: 8)
                            .offset(x: 20 * progress, y: -30 * progress)
                            .blur(radius: 2)
                    }
                    .transition(.opacity)
                }
            }
        )
    }
}

struct QuantumPageTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    )
            )
    }
}

struct SuccessWaveEffect: ViewModifier {
    var color: Color = QuantumColors.success
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var animate = false

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if animate && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0/15.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let progress = min(1.0, time.truncatingRemainder(dividingBy: 0.8) / 0.8)

                        Circle()
                            .stroke(color.opacity(0.4 * (1.0 - progress)), lineWidth: 2)
                            .frame(width: 40 + 60 * progress, height: 40 + 60 * progress)
                    }
                    .transition(.opacity)
                }
            }
        )
    }

    func trigger() {
        animate = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            animate = false
        }
    }
}

extension View {
    func messageSendAnimation(isSending: Binding<Bool>, color: Color = QuantumColors.accent) -> some View {
        modifier(MessageSendAnimation(isSending: isSending, color: color))
    }

    func quantumPageTransition() -> some View {
        modifier(QuantumPageTransition())
    }
}
