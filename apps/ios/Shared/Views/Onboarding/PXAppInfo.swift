//
//  POPOPXInfo.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 07/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct AppInfoView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var showWhyBuilt = false
    @State private var createProfileNavLinkActive = false
    @StateObject private var popController = BubblePopController()
    @State private var showBubble = false
    var onboarding: Bool

    var body: some View {
        ZStack {
            Color(hex: "#06040A")
                .ignoresSafeArea()
            RadialGradient(
                colors: [QuantumColors.accent.opacity(0.08), QuantumColors.accentSecondary.opacity(0.04), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 320
            )
            .ignoresSafeArea()

            GeometryReader { g in
                ZStack {
                    VStack(alignment: .center, spacing: 10) {
                        Image(colorScheme == .light ? "logo" : "logo-light")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: max(0, (g.size.width - 50)) * 0.55)
                            .padding(.leading, 4)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .top)

                        if onboarding {
                            Text(NSLocalizedString("Be free\nin your network", comment: "Onboarding title"))
                                .font(.largeTitle)
                                .bold()
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text(NSLocalizedString("Private and secure messaging.", comment: "Onboarding subtitle"))
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(QuantumColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(NSLocalizedString("The first network where you own\nyour contacts and groups.", comment: "Onboarding description"))
                                .font(.footnote)
                                .foregroundColor(Color(hex: "#887FA0"))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 20)

                            ZStack {
                                if popController.isPopping {
                                    BubblePopCanvas(particles: popController.particles)
                                        .frame(width: g.size.width, height: g.size.height * 0.5)
                                } else {
                                    BubbleComponent(diameter: min(260, g.size.width * 0.65))
                                        .scaleEffect(showBubble ? 1.0 : 0.8)
                                        .opacity(showBubble ? 1.0 : 0.0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showBubble)
                                        .onAppear {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                showBubble = true
                                            }
                                        }
                                        .onTapGesture {
                                            triggerBubblePop(in: g)
                                        }
                                }
                            }
                            .frame(height: g.size.height * 0.4)

                            Spacer(minLength: 10)

                            if !popController.isPopping && showBubble {
                                Text(NSLocalizedString("tap_bubble_hint", comment: "Hint text below bubble animation"))
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color(hex: "#C4BFD6"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "#00FFD2").opacity(0.2), lineWidth: 1)
                                    )
                                    .transition(.opacity.combined(with: .scale))
                            }

                            Spacer(minLength: 10)

                            createFirstProfileButton()
                                .padding(.vertical, 10)

                            Button {
                                showWhyBuilt = true
                            } label: {
                                Label(NSLocalizedString("Why POPOPX is built.", comment: "Why built link"), systemImage: "info.circle")
                                    .font(.headline)
                                    .foregroundColor(QuantumColors.textSecondary)
                            }
                        } else {
                            nonOnboardingContent(g: g)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                    .frame(minHeight: g.size.height)

                    PurpleFlashOverlay(isActive: popController.flashActive)
                }
                .sheet(isPresented: Binding(
                    get: { m.migrationState != nil && !createProfileNavLinkActive },
                    set: { isPresented in
                        if !isPresented {
                            m.migrationState = nil
                            MigrationToDeviceState.save(nil)
                        }
                    }
                )) {
                    NavigationStack {
                        VStack(alignment: .leading) {
                            MigrateToDevice(migrationState: Binding(get: { m.appState.migrationState }, set: { m.appState.migrationState = $0 }))
                        }
                        .navigationTitle(NSLocalizedString("Migrate here", comment: ""))
                        .modifier(ThemedBackground(grouped: true))
                    }
                }
                .sheet(isPresented: $showWhyBuilt) {
                    WhyPOPOPX(
                        onboarding: onboarding,
                        createProfileNavLinkActive: $createProfileNavLinkActive
                    )
                }
                .navigationDestination(isPresented: $createProfileNavLinkActive) {
                    CreateFirstProfile()
                        .modifier(ThemedBackground())
                }
            }
        }
        .onAppear() {
            setLastVersionDefault()
        }
        .onDisappear {
            popController.reset()
        }
        .frame(maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .popopxBranded()
    }

    private func nonOnboardingContent(g: GeometryProxy) -> some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [QuantumColors.surface, QuantumColors.surfaceElevated]
                        : [Color.white, QuantumColors.textPrimary.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: QuantumColors.accent.opacity(0.6), radius: 20, x: 0, y: 0)
                    .shadow(color: QuantumColors.accentSecondary.opacity(0.4), radius: 32, x: 0, y: 0)
            }
            .aspectRatio(1.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [QuantumColors.accent.opacity(0.5), QuantumColors.accentSecondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: QuantumColors.accent.opacity(0.3), radius: 20, x: 0, y: 6)
            .shadow(color: QuantumColors.accentSecondary.opacity(0.2), radius: 28, x: 0, y: 0)
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity)

            Text(NSLocalizedString("Quantum-secure\nmessaging", comment: "App tagline title"))
                .font(.system(.title).weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: QuantumColors.accent.opacity(0.5), radius: 12, x: 0, y: 2)

            Text(NSLocalizedString("Private and secure messaging.", comment: "App subtitle"))
                .font(.system(.title3).weight(.semibold))
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(NSLocalizedString("The first network where you own\nyour contacts and groups.", comment: "App description"))
                .font(.system(.footnote).weight(.regular))
                .foregroundColor(Color(hex: "#887FA0"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func triggerBubblePop(in g: GeometryProxy) {
        let bubbleCenterY = g.size.height * 0.28
        popController.triggerPop(
            containerSize: g.size,
            bubbleCenterY: bubbleCenterY,
            onComplete: {
                Task { @MainActor in
                    createProfileNavLinkActive = true
                }
            }
        )
    }

    private func triggerBubblePopForNavigation() {
        guard !popController.isPopping else { return }
        let bubbleCenterY: CGFloat
        let containerW: CGFloat
        let containerH: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            containerW = window.bounds.width
            containerH = window.bounds.height
            bubbleCenterY = window.bounds.height * 0.28
        } else {
            containerW = 390
            containerH = 844
            bubbleCenterY = 400 * 0.28
        }
        popController.triggerPop(
            containerSize: CGSize(width: containerW, height: containerH),
            bubbleCenterY: bubbleCenterY * 0.5,
            style: .standard,
            onComplete: {
                Task { @MainActor in
                    createProfileNavLinkActive = true
                }
            }
        )
    }

    private func createFirstProfileButton() -> some View {
        Button {
            triggerBubblePopForNavigation()
        } label: {
            Text(NSLocalizedString("Get started", comment: "Get started button"))
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
    }
}

let textSpace = Text(verbatim: " ")

let textNewLine = Text(verbatim: "\n")

struct AppInfoView_Previews: PreviewProvider {
    static var previews: some View {
        AppInfoView(onboarding: true)
    .previewEnvironment()
    }
}
