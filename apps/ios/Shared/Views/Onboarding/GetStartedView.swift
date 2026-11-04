// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

struct GetStartedView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme

    @State private var isCompleting = false
    @State private var logoScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                QuantumColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)

                        // Animated Logo
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            QuantumColors.accent.opacity(0.3),
                                            QuantumColors.accentSecondary.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 120, height: 120)

                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity)
                        }

                        // Title
                        VStack(spacing: 12) {
                            Text("You're All Set!")
                                .font(QuantumFonts.title)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("Welcome to POPOPX")
                                .font(QuantumFonts.bodyLarge)
                                .foregroundColor(QuantumColors.textSecondary)
                        }

                        // Feature Summary
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What you get")
                                .font(QuantumFonts.sectionHeader)
                                .foregroundColor(QuantumColors.textPrimary)

                            featureRow(
                                icon: "message.fill",
                                title: "Secure Messaging",
                                description: "End-to-end encrypted by default"
                            )

                            featureRow(
                                icon: "person.2.fill",
                                title: "No Phone Number",
                                description: "Create profile without personal info"
                            )

                            featureRow(
                                icon: "lock.shield.fill",
                                title: "Privacy First",
                                description: "No metadata, no tracking"
                            )

                            featureRow(
                                icon: "bolt.fill",
                                title: "Fast & Reliable",
                                description: "Optimized for performance"
                            )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(QuantumColors.surface)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )

                        // Tips
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Tips")
                                .font(QuantumFonts.sectionHeader)
                                .foregroundColor(QuantumColors.textPrimary)

                            tipRow("Swipe right on chats to pin them")
                            tipRow("Long press messages for more options")
                            tipRow("Pull down to refresh your chat list")
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(QuantumColors.surfaceElevated)
                        )

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollBounceBehavior(.basedOnSize)

                // Start Button
                VStack {
                    Spacer()
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }

    // MARK: - Components

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(QuantumColors.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(QuantumFonts.bodySemibold)
                    .foregroundColor(QuantumColors.textPrimary)

                Text(description)
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }

            Spacer()
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(QuantumColors.accent)
                .padding(.top, 2)

            Text(text)
                .font(QuantumFonts.callout)
                .foregroundColor(QuantumColors.textSecondary)

            Spacer()
        }
    }

    private var startButton: some View {
        Button {
            completeOnboarding()
        } label: {
            HStack(spacing: 8) {
                if isCompleting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }

                Text(isCompleting ? "Starting..." : "Start Messaging")
                    .font(QuantumFonts.bodySemibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isCompleting)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        isCompleting = true

        // Request notification authorization and complete onboarding
        NtfManager.shared.requestAuthorization(
            onDeny: {
                DispatchQueue.main.async {
                    TransportManager.shared.requestBluetoothPermission {
                        DispatchQueue.main.async {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 10_000_000000)
                        if !Task.isCancelled && ChatModel.shared.onboardingStage != .onboardingComplete {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                }
            },
            onAuthorized: {
                DispatchQueue.main.async {
                    TransportManager.shared.requestBluetoothPermission {
                        DispatchQueue.main.async {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 10_000_000000)
                        if !Task.isCancelled && ChatModel.shared.onboardingStage != .onboardingComplete {
                            advanceOnboarding(to: .onboardingComplete)
                        }
                    }
                }
            }
        )
    }
}

#Preview {
    GetStartedView()
        .environmentObject(ChatModel())
        .environmentObject(AppTheme.shared)
}
