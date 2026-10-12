// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct NeonLaunchView: View {
    @Binding var isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoOpacity: Double = 0.6
    @State private var hasAppeared = false

    var body: some View {
        if isVisible {
            ZStack {
                Color(hex: "#0D0D11")
                    .ignoresSafeArea()

                ambientDrift

                logoText
                    .opacity(logoOpacity)

                VStack {
                    Spacer()
                    Text(NSLocalizedString("launch_private_messaging", comment: "Launch splash subtitle describing the app"))
                        .font(.system(size: 12, weight: .light, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .foregroundColor(Color(hex: "#00FFFF").opacity(0.8))
                        .padding(.bottom, 60)
                }
            }
            .onAppear {
                hasAppeared = true
                if reduceMotion {
                    logoOpacity = 1.0
                } else {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        logoOpacity = 1.0
                    }
                }
            }
        }
    }

    private var logoText: some View {
        Text("POPOPX")
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "#00FFFF"),
                        Color(hex: "#00FFFF")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: Color(hex: "#00FFFF").opacity(0.6), radius: 20)
            .shadow(color: Color(hex: "#00FFFF").opacity(0.4), radius: 40)
            .shadow(color: Color(hex: "#00FFFF").opacity(0.2), radius: 60)
    }

    private var ambientDrift: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? .infinity : 2.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let orbs: [(Color, Double, CGFloat, Double)] = [
                    (Color(hex: "#00FFFF"), 0.15, 200, 18),
                    (Color(hex: "#00FFFF"), 0.10, 160, 22),
                    (Color(hex: "#FF00FF"), 0.08, 140, 26),
                    (Color(hex: "#A020F0"), 0.06, 120, 20)
                ]

                for (i, orb) in orbs.enumerated() {
                    let phase = reduceMotion ? Double(i) * 1.5 : t * (2 * .pi / orb.3) + Double(i) * 1.5
                    let x = size.width * (0.3 + 0.4 * sin(phase))
                    let y = size.height * (0.3 + 0.4 * cos(phase * 0.7))

                    let rect = CGRect(
                        x: x - orb.2 / 2,
                        y: y - orb.2 / 2,
                        width: orb.2,
                        height: orb.2
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(orb.0.opacity(orb.1))
                    )
                }
            }
            .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}

// MARK: - POPOPX
extension NeonLaunchView {
    static let pxComponentTag: String = "PX_NEON_LAUNCH"
    static let pxDisplayDuration: TimeInterval = 1.5
}
