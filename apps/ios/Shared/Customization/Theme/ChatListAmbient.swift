// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import CoreMotion

struct AmbientOrbBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared // POPOPX: 方案2
    @Environment(\.scenePhase) private var scenePhase // POPOPX: 方案2

    private let orbs: [AmbientOrb] = [
        AmbientOrb(color: Color(hex: "#00FFFF"), opacity: 0.20, size: 280, period: 20, startOffset: 0),
        AmbientOrb(color: Color(hex: "#00FFFF"), opacity: 0.12, size: 220, period: 25, startOffset: 7),
        AmbientOrb(color: Color(hex: "#FF00FF"), opacity: 0.10, size: 200, period: 30, startOffset: 14),
        AmbientOrb(color: Color(hex: "#A020F0"), opacity: 0.08, size: 180, period: 22, startOffset: 3)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "#0D0D11").ignoresSafeArea()

                if reduceMotion {
                    staticOrbs(in: geo.size)
                } else {
                    animatedOrbs(in: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func animatedOrbs(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in // POPOPX: 方案2 — switched from .periodic (no paused:) to .animation with guards
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                for orb in orbs {
                    let phase = t * (2 * .pi / orb.period) + orb.startOffset
                    let x = canvasSize.width * (0.3 + 0.4 * sin(phase))
                    let y = canvasSize.height * (0.3 + 0.4 * cos(phase * 0.7))

                    let rect = CGRect(
                        x: x - orb.size / 2,
                        y: y - orb.size / 2,
                        width: orb.size,
                        height: orb.size
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(orb.color.opacity(orb.opacity))
                    )
                }
            }
            .blur(radius: 40)
        }
    }

    private func staticOrbs(in size: CGSize) -> some View {
        ZStack {
            ForEach(Array(orbs.enumerated()), id: \.offset) { index, orb in
                Circle()
                    .fill(orb.color.opacity(orb.opacity))
                    .frame(width: orb.size, height: orb.size)
                    .position(
                        x: size.width * (0.25 + Double(index) * 0.2),
                        y: size.height * (0.3 + Double(index % 2) * 0.4)
                    )
            }
        }
        .blur(radius: 40)
    }
}

struct CosmicAbyssBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    private let particles: [ParticleSpec] = {
        var rng = SeededGenerator(seed: 0xC0591CAB55)
        return (0..<25).map { _ in
            ParticleSpec(
                startX: Double.random(in: 0...1, using: &rng),
                startY: Double.random(in: 0...1, using: &rng),
                speedX: Double.random(in: -0.002...0.002, using: &rng),
                speedY: Double.random(in: -0.001...0.001, using: &rng),
                size: CGFloat.random(in: 3.0...8.0, using: &rng),
                opacity: Double.random(in: 0.25...0.45, using: &rng)
            )
        }
    }()

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(hex: "#000000").ignoresSafeArea()
                RadialGradient(
                    colors: [Color(hex: "#A855F7").opacity(0.03), Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color(hex: "#A855F7").opacity(0.015), Color.clear],
                    center: UnitPoint(x: 0.3, y: 0.7),
                    startRadius: 100,
                    endRadius: 600
                )
                .ignoresSafeArea()

                // POPOPX: Always use static star field to save battery
                staticStarField
            } else {
                Color(hex: "#F7F5FA").ignoresSafeArea()
            }
        }
    }

    private var animatedStarField: some View {
        // POPOPX: Reduced from 12fps to 2fps for battery efficiency
        TimelineView(.animation(minimumInterval: 1.0 / 2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for (i, p) in particles.enumerated() {
                    let rawX = p.startX + p.speedX * t
                    let rawY = p.startY + p.speedY * t
                    let px = rawX - floor(rawX)
                    let py = rawY - floor(rawY)
                    let x = px * size.width
                    let y = py * size.height
                    let twinkle = 0.7 + 0.3 * sin(t * (0.5 + Double(i) * 0.1) + Double(i))
                    let finalOpacity = p.opacity * twinkle
                    let rect = CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#A855F7").opacity(finalOpacity)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var staticStarField: some View {
        Canvas { context, size in
            for (_, p) in particles.enumerated() {
                let x = p.startX * size.width
                let y = p.startY * size.height
                let rect = CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size)
                context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#A855F7").opacity(p.opacity)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct ParticleSpec {
    let startX: Double
    let startY: Double
    let speedX: Double
    let speedY: Double
    let size: CGFloat
    let opacity: Double
}

struct AmbientOrb {
    let color: Color
    let opacity: Double
    let size: CGFloat
    let period: Double
    let startOffset: Double
}

struct NeonChatCard: ViewModifier {
    let isUnread: Bool
    let isDarkTheme: Bool
    @EnvironmentObject private var motionService: MotionGravityService

    func body(content: Content) -> some View {
        let gravityOffset = CGSize(
            width: motionService.gravityVector.dx * 0.05,
            height: motionService.gravityVector.dy * 0.05
        )
        return content
            .offset(
                x: motionService.parallaxOffset.width + gravityOffset.width,
                y: motionService.parallaxOffset.height + gravityOffset.height
            )
            .modifier(GlassCardBase(isDarkTheme: isDarkTheme))
            .modifier(GlassCardOverlays(isUnread: isUnread, isDarkTheme: isDarkTheme, parallaxOffset: motionService.parallaxOffset))
    }
}

private struct GlassCardBase: ViewModifier {
    let isDarkTheme: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#6E25C4").opacity(isDarkTheme ? 0.10 : 0.05))
            )
    }
}

private struct GlassCardOverlays: ViewModifier {
    let isUnread: Bool
    let isDarkTheme: Bool
    let parallaxOffset: CGSize
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay(cardBorder)
            .overlay(glassSheen)
            .overlay(specularHighlight)
            .overlay(unreadIndicator, alignment: .leading)
            .shadow(
                color: isUnread && isDarkTheme ? Color(hex: "#00FFD2").opacity(0.12) : .clear,
                radius: 8, x: 0, y: 2
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                isUnread && isDarkTheme
                    ? Color(hex: "#00FFD2").opacity(0.5)
                    : isDarkTheme
                        ? Color(hex: "#00FFD2").opacity(0.15)
                        : Color.white.opacity(0.2),
                lineWidth: 0.5
            )
    }

    private var glassSheen: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear, .white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .mask(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var specularHighlight: some View {
        // POPOPX: Static highlight to save battery (removed TimelineView animation)
        let motionX = 0.5 + (parallaxOffset.width / 24.0) * 0.6
        let motionY = 0.5 + (parallaxOffset.height / 24.0) * 0.6
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.09), .clear],
                    center: UnitPoint(x: motionX, y: motionY),
                    startRadius: 10,
                    endRadius: 140
                )
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var unreadIndicator: some View {
        if isUnread && isDarkTheme {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#00FFD2"), Color(hex: "#6E25C4")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 32)
                .offset(x: -1)
                .shadow(color: Color(hex: "#00FFD2").opacity(0.5), radius: 4)
        }
    }
}

extension View {
    func neonChatCard(isUnread: Bool, isDarkTheme: Bool = true) -> some View {
        modifier(NeonChatCard(isUnread: isUnread, isDarkTheme: isDarkTheme))
    }
}

// MARK: - POPOPX
extension AmbientOrbBackground {
    static let pxComponentTag: String = "PX_AMBIENT_ORB_BG"
}
