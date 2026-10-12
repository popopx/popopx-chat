// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct NeedlePinView: View {
    @ObservedObject private var threatState = NeedleThreatState.shared
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let x = proxy.size.width / 2
            let y = proxy.size.height / 2

            if reduceMotion {
                robotAvatar
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#00FFFF"), lineWidth: 2)
                            .opacity(0.6)
                            .frame(width: 42, height: 42)
                            .shadow(color: Color(hex: "#00FFFF").opacity(0.3), radius: 8)
                    )
                    .position(x: x, y: y)
            } else {
                // POPOPX: Reduced from 15fps to 1fps for battery efficiency
                TimelineView(.animation(minimumInterval: 1.0 / 1.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let breathePhase = 0.5 + 0.5 * sin(t * .pi)

                    robotAvatar
                        .overlay(
                            Circle()
                                .stroke(
                                    Color(hex: "#00FFFF"),
                                    lineWidth: 2 + breathePhase * 0.5
                                )
                                .opacity(0.4 + breathePhase * 0.4)
                                .frame(width: 42, height: 42)
                                .shadow(
                                    color: Color(hex: "#00FFFF").opacity(0.2 + breathePhase * 0.3),
                                    radius: 6 + breathePhase * 4
                                )
                        )
                        .overlay(threatAura(time: t))
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var robotAvatar: some View {
        ZStack {
            robotBody
            robotHead
        }
        .frame(width: 34, height: 40)
    }

    private var robotHead: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#E8E8F0"),
                            Color(hex: "#A0A0B8"),
                            Color(hex: "#606078")
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.7), Color.clear],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: 6
                    )
                )
                .frame(width: 20, height: 20)
                .offset(x: -2, y: -2)

            HStack(spacing: 4) {
                robotEye
                robotEye
            }
            .offset(y: -1)

            Circle()
                .fill(Color(hex: "#00FFFF").opacity(0.5))
                .frame(width: 3, height: 3)
                .offset(y: 4)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#C0C0D0"), Color(hex: "#808098")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 5)
                .offset(y: -14)

            Circle()
                .fill(Color(hex: "#00FFFF"))
                .frame(width: 4, height: 4)
                .shadow(color: Color(hex: "#00FFFF").opacity(0.8), radius: 3)
                .offset(y: -17)
        }
        .offset(y: -4)
    }

    private var robotEye: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#00FFFF"), Color(hex: "#008B8B")],
                    center: .center,
                    startRadius: 0,
                    endRadius: 3
                )
            )
            .frame(width: 5, height: 5)
            .shadow(color: Color(hex: "#00FFFF").opacity(0.6), radius: 2)
    }

    private var robotBody: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#B0B0C8"),
                        Color(hex: "#808098"),
                        Color(hex: "#606078")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 16, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "#00FFFF").opacity(0.25), lineWidth: 0.5)
            )
            .overlay(
                Circle()
                    .fill(Color(hex: "#00FFFF").opacity(0.4))
                    .frame(width: 4, height: 4)
                    .shadow(color: Color(hex: "#00FFFF").opacity(0.5), radius: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            .offset(y: 10)
    }

    private func threatAura(time t: TimeInterval) -> some View {
        Group {
            if threatState.isThreatActive {
                let cycle = t.truncatingRemainder(dividingBy: 0.3) / 0.3
                let intensity = sin(cycle * .pi) * 0.8
                Circle()
                    .stroke(Color(red: 1.0, green: 0.23, blue: 0.19), lineWidth: 2)
                    .opacity(intensity)
                    .frame(width: 42, height: 42)
                    .shadow(color: Color(red: 1.0, green: 0.23, blue: 0.19).opacity(intensity * 0.5), radius: 8)
            } else {
                Color.clear
            }
        }
    }
}

extension NeedlePinView {
    static let pxComponentTag: String = "PX_NEEDLE_PIN"
}
