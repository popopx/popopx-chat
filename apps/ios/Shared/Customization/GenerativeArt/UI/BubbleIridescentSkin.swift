// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

private let pxTransientBubblesEnabled = UserDefaults.standard.object(forKey: "PX_TRANSIENT_BUBBLES_ENABLED") as? Bool ?? true

struct SeededGenerator: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}

struct IridescentBubbleModifier: ViewModifier {
    let isUnread: Bool
    let ttlProgress: Double?
    let isIncoming: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if pxTransientBubblesEnabled {
                    iridescentOverlay
                }
            }
        )
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private var iridescentOverlay: some View {
        let baseOpacity = isUnread ? 0.15 : 0.08
        let opacity = ttlProgress.map { baseOpacity * (1.0 - $0 * 0.6) } ?? baseOpacity

        return Group {
            if reduceMotion {
                staticIridescentGradient(opacity: opacity)
            } else {
                animatedIridescentShimmer(opacity: opacity)
            }
        }
        .blendMode(.screen)
        .mask(drainMask)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var drainMask: some View {
        if isUnread {
            LinearGradient(
                colors: [.white, .white],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [.white, .white.opacity(0.3), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func animatedIridescentShimmer(opacity: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 1.0, paused: powerMode.isLowPowerMode || !isVisible || scenePhase != .active)) { timeline in // POPOPX: 1fps for battery, was 12fps
            let t = timeline.date.timeIntervalSinceReferenceDate
            let flowDirection: Double = ttlProgress.map { $0 > 0.5 ? 1.0 : 0.0 } ?? 0.0

            Canvas { context, size in
                let bandCount = 3
                let colors: [Color] = [
                    Color(hex: "#00FFCC"),
                    Color(hex: "#A020F0"),
                    Color(hex: "#FF007A")
                ]

                for i in 0..<bandCount {
                    let phase = t * (0.4 + Double(i) * 0.25) + Double(i) * 2.094
                    let amplitude = size.height * 0.15
                    let yBase = size.height * (0.25 + Double(i) * 0.25)
                    let flowOffset = flowDirection * t * 20

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: yBase + sin(phase) * amplitude + flowOffset))

                    let stepCount = 24
                    for step in 1...stepCount {
                        let x = size.width * CGFloat(step) / CGFloat(stepCount)
                        let localPhase = phase + Double(step) * 0.35
                        let y = yBase + sin(localPhase) * amplitude + flowOffset
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    context.stroke(
                        path,
                        with: .color(colors[i].opacity(opacity * (0.7 + Double(i) * 0.15))),
                        lineWidth: 3.0 - Double(i) * 0.4
                    )
                }
            }
        }
    }

    private func staticIridescentGradient(opacity: Double) -> some View {
        LinearGradient(
            colors: [
                Color(hex: "#00FFCC").opacity(opacity * 0.6),
                Color(hex: "#A020F0").opacity(opacity * 0.8),
                Color(hex: "#FF007A").opacity(opacity * 0.5)
            ],
            startPoint: isIncoming ? .topLeading : .topTrailing,
            endPoint: isIncoming ? .bottomTrailing : .bottomLeading
        )
    }
}

struct IridescentEdgeStroke: View {
    let isUnread: Bool
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @State private var isVisible = false

    var body: some View {
        Group {
            if pxTransientBubblesEnabled && isUnread {
                if reduceMotion {
                    staticEdgeStroke
                } else {
                    animatedEdgeStroke
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private var animatedEdgeStroke: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 1.0, paused: powerMode.isLowPowerMode || !isVisible || scenePhase != .active)) { timeline in // POPOPX: 1fps for battery, was 10fps
            let t = timeline.date.timeIntervalSinceReferenceDate
            let rotation = Angle.degrees(t * 30)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(hex: "#00FFCC").opacity(0.4),
                            Color(hex: "#A020F0").opacity(0.3),
                            Color(hex: "#FF007A").opacity(0.35),
                            Color(hex: "#A020F0").opacity(0.25),
                            Color(hex: "#00FFCC").opacity(0.4)
                        ],
                        center: .center,
                        angle: rotation
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 0.5)
        }
    }

    private var staticEdgeStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color(hex: "#00FFCC").opacity(0.3),
                        Color(hex: "#A020F0").opacity(0.2),
                        Color(hex: "#FF007A").opacity(0.25),
                        Color(hex: "#00FFCC").opacity(0.3)
                    ],
                    center: .center
                ),
                lineWidth: 1.2
            )
    }
}

struct IridescentCountdownOverlay: View {
    let ttlProgress: Double
    let remainingSeconds: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if pxTransientBubblesEnabled && ttlProgress > 0.1 {
            ZStack {
                RadialGradient(
                    colors: [
                        Color.black.opacity(ttlProgress * 0.15),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 120
                )

                if !reduceMotion && ttlProgress > 0.3 {
                    Canvas { context, size in
                        let crackSeed = UInt64(remainingSeconds)
                        var rng = SeededGenerator(seed: crackSeed)

                        let crackCount: Int
                        let crackOpacity: Double
                        let maxBranches: Int

                        switch ttlProgress {
                        case 0.3..<0.6:
                            crackCount = 3
                            crackOpacity = 0.15
                            maxBranches = 1
                        case 0.6..<0.8:
                            crackCount = 6
                            crackOpacity = 0.3
                            maxBranches = 2
                        default:
                            crackCount = 12
                            crackOpacity = 0.45
                            maxBranches = 3
                        }

                        for _ in 0..<crackCount {
                            let edge = Int.random(in: 0..<4, using: &rng)
                            let startT = Double.random(in: 0...1, using: &rng)
                            var x: Double, y: Double
                            switch edge {
                            case 0: x = startT * size.width; y = 0
                            case 1: x = size.width; y = startT * size.height
                            case 2: x = startT * size.width; y = size.height
                            default: x = 0; y = startT * size.height
                            }

                            var path = Path()
                            path.move(to: CGPoint(x: x, y: y))

                            let segments = 2 + Int.random(in: 0...maxBranches, using: &rng)
                            for _ in 0..<segments {
                                let dx = Double.random(in: -20...20, using: &rng)
                                let dy = Double.random(in: -20...20, using: &rng)
                                x += dx
                                y += dy
                                path.addLine(to: CGPoint(x: x, y: y))
                            }

                            context.stroke(path, with: .color(.white.opacity(crackOpacity)), lineWidth: 0.5)
                        }
                    }
                }

                Text(formatCountdown(remainingSeconds))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.25 + ttlProgress * 0.2))
                    .shadow(color: Color(red: 0, green: 1, blue: 0.8).opacity(0.4), radius: 4)
                    .blur(radius: 0.5)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

extension View {
    func iridescentBubble(isUnread: Bool, ttlProgress: Double? = nil, isIncoming: Bool = false) -> some View {
        modifier(IridescentBubbleModifier(isUnread: isUnread, ttlProgress: ttlProgress, isIncoming: isIncoming))
    }

    func iridescentEdge(isUnread: Bool, cornerRadius: CGFloat = 10) -> some View {
        overlay(IridescentEdgeStroke(isUnread: isUnread, cornerRadius: cornerRadius))
    }
}

// MARK: - POPOPX
extension IridescentBubbleModifier {
    static let pxComponentTag: String = "PX_IRIDESCENT_BUBBLE"
    static let pxShimmerFPS: Double = 24.0
    static let pxEdgeFPS: Double = 20.0
    static let pxMaxBandOpacity: Double = 0.15
    static let pxMinBandOpacity: Double = 0.08
}
