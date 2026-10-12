// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct LaunchScreenView: View {
    @ObservedObject var coordinator = LaunchCoordinator.shared
    let onLaunchComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var minimumTimeElapsed = false
    @State private var isTransitioning = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var initTimeoutReached = false

    var body: some View {
        ZStack {
            QuantumFieldBackground(particleCount: 30, speed: 0.6)

            VStack(spacing: 24) {
                Spacer()

                logoSection

                statusSection

                progressSection

                Spacer()

                if initTimeoutReached {
                    retrySection
                }
            }
            .padding(.horizontal, 40)
        }
        .opacity(isTransitioning ? 0 : 1)
        .scaleEffect(isTransitioning ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: isTransitioning)
        .task {
            await coordinator.runInitialization()
        }
        .onAppear {
            let animation: Animation = reduceMotion ? .default : .spring(response: 0.6, dampingFraction: 0.7)
            withAnimation(animation) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 800_000000)
            if !Task.isCancelled {
                minimumTimeElapsed = true
            }
            if !initTimeoutReached {
                try? await Task.sleep(for: .seconds(14.2))
                if !Task.isCancelled && !coordinator.isComplete {
                    initTimeoutReached = true
                }
            }
        }
        .onChange(of: coordinator.isComplete) { _, complete in
            if complete && minimumTimeElapsed && !isTransitioning {
                triggerTransition()
            }
        }
        .onChange(of: minimumTimeElapsed) { _, elapsed in
            if elapsed && coordinator.isComplete && !isTransitioning {
                triggerTransition()
            }
        }
        .popopxBranded()
    }

    private var logoSection: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 80, height: 80)
                .shadow(color: QuantumColors.accent.opacity(0.3), radius: 16, x: 0, y: 0)

            Image(systemName: "lock.shield.fill")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .quantumPulse(color: QuantumColors.accent, duration: 3.0)
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text("POPOPX")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(coordinator.phase.statusText)
                .font(.system(.subheadline).weight(.medium))
                .foregroundColor(QuantumColors.textPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: coordinator.phase)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: coordinator.phase.progress)
                .tint(QuantumColors.accent)
                .animation(.easeInOut(duration: 0.5), value: coordinator.phase.progress)

            HStack {
                ForEach(LaunchPhase.allCases, id: \.self) { phase in
                    Circle()
                        .fill(phase <= coordinator.phase ? QuantumColors.accent : QuantumColors.surface)
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: coordinator.phase)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var retrySection: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("Taking longer than expected. You can retry or wait.", comment: "init timeout message"))
                .font(.callout)
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                initTimeoutReached = false
                Task { await coordinator.retry() }
            } label: {
                Text(NSLocalizedString("Retry", comment: "Retry button"))
            }
            .buttonStyle(QuantumButtonStyle(primary: true))
        }
        .padding(.bottom, 40)
    }

    private func triggerTransition() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onLaunchComplete()
        }
    }
}
