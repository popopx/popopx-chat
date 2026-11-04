// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct NeonLaunchView: View {
    @Binding var isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.85
    @State private var hasAppeared = false

    var body: some View {
        if isVisible {
            ZStack {
                QuantumColors.background
                    .ignoresSafeArea()

                ambientDrift

                logoText
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack {
                    Spacer()
                    Text(NSLocalizedString("launch_private_messaging", comment: "Launch splash subtitle describing the app"))
                        .font(QuantumFonts.caption.weight(.light))
                        .minimumScaleFactor(0.5)
                        .foregroundColor(QuantumColors.accentSecondary.opacity(0.8))
                        .padding(.bottom, 20)
                }
                .safeAreaPadding(.bottom)
                .opacity(logoOpacity)
            }
            .onAppear {
                hasAppeared = true
                let animation: Animation = reduceMotion ? .easeOut(duration: 0.4) : .spring(response: 0.5, dampingFraction: 0.7)
                withAnimation(animation) {
                    logoOpacity = 1.0
                    logoScale = 1.0
                }
            }
        }
    }

    private var logoText: some View {
        Text("POPOPX")
            .font(QuantumFonts.display)
            .minimumScaleFactor(0.5)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        QuantumColors.accentSecondary,
                        QuantumColors.accentSecondary
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: QuantumColors.accentSecondary.opacity(0.6), radius: 20)
            .shadow(color: QuantumColors.accentSecondary.opacity(0.3), radius: 40)
    }

    private var ambientDrift: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? .infinity : 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let orbs: [(Color, Double, CGFloat, Double)] = [
                    (QuantumColors.accentSecondary, 0.15, 200, 18),
                    (QuantumColors.accentSecondary, 0.10, 160, 22),
                    (QuantumColors.accentWarm, 0.08, 140, 26),
                    (QuantumColors.accent, 0.06, 120, 20)
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
