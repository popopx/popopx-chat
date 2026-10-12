// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct GenerativeBubbleModifier: ViewModifier {
    @ObservedObject var themeManager = CyberThemeManager.shared
    let isIncoming: Bool

    func body(content: Content) -> some View {
        if themeManager.isCyberMode {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(neonBorderGradient, lineWidth: 1.2)
                )
                .overlay(
                    BreathingGlow(cornerRadius: 10)
                )
        } else {
            content
                .iridescentBubble(isUnread: false, isIncoming: isIncoming)
                .iridescentEdge(isUnread: false, cornerRadius: 10)
        }
    }

    private var neonBorderGradient: LinearGradient {
        LinearGradient(
            colors: isIncoming
                ? [Color(hex: "#00FFFF").opacity(0.7), Color(hex: "#8B5CF6").opacity(0.5)]
                : [Color(hex: "#8B5CF6").opacity(0.7), Color(hex: "#FF00FF").opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BreathingGlow: View {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/1.0, paused: powerMode.isLowPowerMode || reduceMotion || scenePhase != .active)) { timeline in // POPOPX: 1fps for battery, was 15fps
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 1.5) + 1) / 2
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: "#00FFFF").opacity(0.25 + pulse * 0.3), // POPOPX: 方案4 — increased opacity to compensate for blur removal
                            Color(hex: "#FF00FF").opacity(0.2 + pulse * 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .allowsHitTesting(false)
        }
        .popopxBranded()
    }
}

struct CyberBubbleStyle: ViewModifier {
    @ObservedObject var themeManager = CyberThemeManager.shared

    func body(content: Content) -> some View {
        if themeManager.isCyberMode {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "#1A1228").opacity(0.7)) // POPOPX: solid替代 ultraThinMaterial
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#8B5CF6").opacity(0.08),
                                        Color(hex: "#818CF8").opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#8B5CF6").opacity(0.4),
                                    Color(hex: "#818CF8").opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content
        }
    }
}

extension View {
    func generativeBubble(isIncoming: Bool) -> some View {
        modifier(GenerativeBubbleModifier(isIncoming: isIncoming))
    }

    func cyberBubbleStyle() -> some View {
        modifier(CyberBubbleStyle())
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
