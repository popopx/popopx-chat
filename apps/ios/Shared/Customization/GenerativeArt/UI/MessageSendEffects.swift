// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct SendRippleEffect: View {
    @Binding var isTriggered: Bool

    @State private var ripples: [RippleData] = []

    struct RippleData: Identifiable {
        let id = UUID()
        let color: Color
        let startTime: Date
    }

    private let colors: [Color] = [
        Color(hex: "#00FFFF"),
        Color(hex: "#8B5CF6"),
        Color(hex: "#FF00FF")
    ]

    var body: some View {
        Canvas { context, size in
            let now = Date()
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            for ripple in ripples {
                let age = now.timeIntervalSince(ripple.startTime)
                if age > 0.8 { continue }

                let progress = age / 0.8
                let radius = progress * 60
                let opacity = (1.0 - progress) * 0.4

                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(ripple.color.opacity(opacity)),
                    lineWidth: 2.0 * (1.0 - progress)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isTriggered) { _, triggered in
            if triggered {
                triggerRipples()
                isTriggered = false
            }
        }
    }

    private func triggerRipples() {
        let now = Date()
        ripples = colors.enumerated().map { index, color in
            RippleData(
                color: color,
                startTime: now.addingTimeInterval(Double(index) * 0.1)
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ripples.removeAll()
        }
    }
}

struct ReceiveGlowEffect: ViewModifier {
    let isActive: Bool
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        receiveGlow
                    }
                }
            )
    }

    private var receiveGlow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: powerMode.isLowPowerMode || scenePhase != .active || !isActive)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let pulse = sin(elapsed * 4) * 0.5 + 0.5

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    Color(hex: "#8B5CF6").opacity(0.3 * pulse),
                    lineWidth: 1.5
                )
                .blur(radius: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func receiveGlow(isActive: Bool) -> some View {
        modifier(ReceiveGlowEffect(isActive: isActive))
    }
}

// MARK: - Balloon Fly-Up Animation

struct PXBubbleFlyUp: Identifiable {
    let id = UUID()
    let text: String
}

struct PXBalloon3D: View {
    let text: String
    @State private var textSize: CGSize = .zero

    private var balloonDiameter: CGFloat {
        let contentSize = max(textSize.width, textSize.height)
        return max(contentSize + 40, 80) // min 80pt, padding 40pt
    }

    var body: some View {
        ZStack {
            // Main balloon body with 3D gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#A855F7"), Color(hex: "#6E25C4"), Color(hex: "#4A1A8A")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: balloonDiameter * 0.7
                    )
                )
                .frame(width: balloonDiameter, height: balloonDiameter)

            // White highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: balloonDiameter * 0.35
                    )
                )
                .frame(width: balloonDiameter * 0.5, height: balloonDiameter * 0.35)
                .offset(x: -balloonDiameter * 0.15, y: -balloonDiameter * 0.2)

            // Texture curves
            Path { p in
                p.move(to: CGPoint(x: balloonDiameter * 0.2, y: balloonDiameter * 0.45))
                p.addQuadCurve(
                    to: CGPoint(x: balloonDiameter * 0.8, y: balloonDiameter * 0.55),
                    control: CGPoint(x: balloonDiameter * 0.5, y: balloonDiameter * 0.7)
                )
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

            Path { p in
                p.move(to: CGPoint(x: balloonDiameter * 0.3, y: balloonDiameter * 0.3))
                p.addQuadCurve(
                    to: CGPoint(x: balloonDiameter * 0.7, y: balloonDiameter * 0.75),
                    control: CGPoint(x: balloonDiameter * 0.6, y: balloonDiameter * 0.45)
                )
            }
            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)

            // Tie knot
            Circle()
                .fill(Color(hex: "#6E25C4"))
                .frame(width: balloonDiameter * 0.15, height: balloonDiameter * 0.15)
                .offset(y: balloonDiameter * 0.575)

            // Text - measured to size the balloon
            Text(text)
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            textSize = geo.size
                        }
                        .onChange(of: geo.size) { _, newSize in
                            textSize = newSize
                        }
                    }
                )
        }
    }
}

struct PXBubbleFlyUpView: View {
    let text: String
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PXBalloon3D(text: text)
            .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 12)
            .scaleEffect(animate ? 1.1 : 0.5)
            .opacity(animate ? 0.3 : 1.0)
            .offset(y: animate ? -80 : 120)
            .onAppear {
                if reduceMotion { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    animate = true
                }
            }
    }
}

// MARK: - POPOPX
extension SendRippleEffect {
    static let pxComponentTag: String = "PX_SEND_RIPPLE"
}
