// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  PxBalloonProgressView.swift
//  POPOPX (iOS)
//

import SwiftUI

struct PxBalloonProgressView: View {
    let text: String
    @State private var pulse = false
    @State private var floatY = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                balloonShape
                    .scaleEffect(pulse ? 1.08 : 0.92)
                    .offset(y: floatY ? -6 : 6)
            }
            .frame(width: 80, height: 100)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatY = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                pulse = false
                floatY = false
            }
        }
    }

    private var balloonShape: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [QuantumColors.vividPurple, QuantumColors.accent, QuantumColors.darkPurpleDeep],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: 28
                    )
                )
                .frame(width: 70, height: 70)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 35, height: 24)
                .offset(x: -10, y: -14)

            Circle()
                .fill(QuantumColors.accent)
                .frame(width: 10, height: 10)
                .offset(y: 40)

            Path { p in
                p.move(to: CGPoint(x: 35, y: 45))
                p.addQuadCurve(to: CGPoint(x: 35, y: 70), control: CGPoint(x: 42, y: 55))
            }
            .stroke(QuantumColors.accent.opacity(0.6), lineWidth: 1.5)
        }
        .shadow(color: QuantumColors.accent.opacity(0.4), radius: 16)
        .shadow(color: QuantumColors.accentSecondary.opacity(0.2), radius: 24)
    }
}
