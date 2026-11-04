// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct GlowAvatarView<Content: View>: View {
    let size: CGFloat
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            outerGlowRing

            content()
                .frame(width: size - 8, height: size - 8)
                .clipShape(Circle())

            innerRing
        }
        .frame(width: size, height: size)
    }

    private var outerGlowRing: some View {
        Group {
            if reduceMotion {
                staticRing
            } else {
                animatedRing
            }
        }
    }

    private var animatedRing: some View {
        // POPOPX: Reduced from 20fps to 3fps to 1fps for battery efficiency
        TimelineView(.animation(minimumInterval: 1.0 / 1.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(t * 45)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            QuantumColors.pureCyan,
                            QuantumColors.particleViolet,
                            QuantumColors.pureMagenta,
                            QuantumColors.encryptionStandard,
                            QuantumColors.pureCyan
                        ],
                        center: .center,
                        angle: angle
                    ),
                    lineWidth: 3
                )
                .shadow(color: QuantumColors.particleViolet.opacity(0.4), radius: 8)
                .shadow(color: QuantumColors.pureCyan.opacity(0.2), radius: 12)
        }
    }

    private var staticRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        QuantumColors.pureCyan,
                        QuantumColors.particleViolet,
                        QuantumColors.pureMagenta,
                        QuantumColors.pureCyan
                    ],
                    center: .center
                ),
                lineWidth: 3
            )
            .shadow(color: QuantumColors.particleViolet.opacity(0.3), radius: 6)
    }

    private var innerRing: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            .padding(4)
    }
}

struct ProfileGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

extension View {
    func profileGlassCard() -> some View {
        modifier(ProfileGlassCard())
    }
}

