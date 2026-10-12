//
//  YourNetwork.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 22/04/2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

private enum YourNetworkSheet: Identifiable {
    case configureOperators
    case configureNotifications

    var id: String {
        switch self {
        case .configureOperators: return "configureOperators"
        case .configureNotifications: return "configureNotifications"
        }
    }
}

struct YourNetworkView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var serverOperators: [ServerOperator] = []
    @State private var selectedOperatorIds = Set<Int64>()
    @AppStorage("onboarding_notification_mode") private var notificationModeRaw: String = NotificationsMode.instant.rawValue
    @State private var sheetItem: YourNetworkSheet? = nil
    @State private var justOpened = true
    @State private var operatorsLoading = false
    @State private var operatorsLoadFailed = false
    @State private var reloadTask: Task<Void, Never>?
    
    // New state for button flow
    @State private var isProcessing = false
    @State private var showWaitingIndicator = false
    @State private var particleExpansionActive = false
    @State private var shouldAdvanceToNextStage = false

    private var notificationMode: NotificationsMode {
        get { NotificationsMode(rawValue: notificationModeRaw) ?? .instant }
        set { notificationModeRaw = newValue.rawValue }
    }

    var body: some View {
        ZStack {
            OnboardingBubbleBackground()

            GeometryReader { g in
                VStack(alignment: .center, spacing: 10) {
                    Spacer(minLength: 0)

                    Text(NSLocalizedString("Your network", comment: "Your network title"))
                        .font(.system(.title, design: .default).weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 15)
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#6E25C4").opacity(0.4), radius: 12, x: 0, y: 2)

                    Text(NSLocalizedString("Network routers cannot know\nwho talks to whom", comment: "Network privacy subtitle"))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#C4BFD6"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 16) {
                        configureRoutersButton()
                        configureNotificationsButton()
                    }
                    .padding(.top, 15)
                    .padding(.bottom, 15)

                    Spacer(minLength: 0)

                    if operatorsLoadFailed && serverOperators.isEmpty {
                        VStack(spacing: 12) {
                            Text(NSLocalizedString("Unable to load server operators. Please check your connection and try again.", comment: "operators load error"))
                                .font(.system(size: 13, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(hex: "#C4BFD6"))
                            Button {
                                reloadOperators()
                            } label: {
                                Text(NSLocalizedString("Retry", comment: "retry button"))
                            }
                            .buttonStyle(QuantumButtonStyle(primary: true))
                        }
                    } else {
                        centralVisualContent(g: g)
                            .safeAreaPadding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(maxHeight: .infinity)
            }
            
            // Waiting indicator overlay
            if showWaitingIndicator {
                WaitingIndicator()
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Particle expansion overlay
            if particleExpansionActive {
                ParticleExpansionOverlay()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            if justOpened {
                serverOperators = ChatModel.shared.conditions.serverOperators
                selectedOperatorIds = Set(serverOperators.filter { $0.enabled }.map { $0.operatorId })
                justOpened = false

                if serverOperators.isEmpty {
                    reloadOperators()
                }
            }
        }
        .onDisappear {
            reloadTask?.cancel()
            reloadTask = nil
        }
        .onChange(of: notificationModeRaw) { _, newValue in
            ChatModel.shared.notificationMode = NotificationsMode(rawValue: newValue) ?? .instant
        }
        .sheet(item: $sheetItem) { item in
            switch item {
            case .configureOperators:
                ChooseServerOperators(serverOperators: serverOperators, selectedOperatorIds: $selectedOperatorIds)
                    .modifier(ThemedBackground())
            case .configureNotifications:
                SetNotificationsMode(notificationMode: Binding(
                    get: { NotificationsMode(rawValue: notificationModeRaw) ?? .instant },
                    set: { notificationModeRaw = $0.rawValue }
                ))
                    .modifier(ThemedBackground())
            }
        }
        .navigationDestination(isPresented: $shouldAdvanceToNextStage) {
            OnboardingConditionsView(initialOperatorIds: Set(ChatModel.shared.conditions.serverOperators.filter { $0.enabled }.map { $0.operatorId }))
                .navigationBarBackButtonHidden(true)
                .modifier(ThemedBackground(glass: true))
                .onAppear { reloadConditionsIfNeeded() }
        }
        .frame(maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .popopxBranded()
    }

    private var isConfigComplete: Bool {
        !selectedOperatorIds.isEmpty
    }

    // MARK: - Central Visual Content (Needle Ring + X Logo)

    private func centralVisualContent(g: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Needle ring with inner glow circle and X logo particles centered independently
            ZStack(alignment: .center) {
                LiquidSilverNeedleRing(diameter: min(300, g.size.width * 0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Inner glow circle - centered
                InnerGlowCircle(diameter: min(140, g.size.width * 0.35))
                    .frame(width: min(140, g.size.width * 0.35), height: min(140, g.size.width * 0.35))
                
                // X logo particles - centered on top
                XLogoParticles(size: min(140, g.size.width * 0.35))
                    .frame(width: min(140, g.size.width * 0.35), height: min(140, g.size.width * 0.35))
            }
            .scaleEffect(isConfigComplete ? 1.0 : 0.85)
            .opacity(isConfigComplete ? 1.0 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isConfigComplete)

            Spacer(minLength: 50)

            // ENTER THE BUBBLE button
            enterBubbleButton()

            Spacer(minLength: 20)
        }
    }

    // MARK: - ENTER THE BUBBLE Button

    private func enterBubbleButton() -> some View {
        Button {
            handleEnterBubbleTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18, weight: .semibold))
                Text(NSLocalizedString("ENTER THE BUBBLE", comment: "Enter bubble network button"))
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .tracking(1.5)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#6E25C4").opacity(0.6),
                                        Color(hex: "#8B5CF6").opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: "#6E25C4").opacity(0.8),
                                Color(hex: "#00FFD2").opacity(0.5),
                                Color(hex: "#6E25C4").opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color(hex: "#6E25C4").opacity(0.5), radius: 12, x: 0, y: 4)
            .shadow(color: Color(hex: "#00FFD2").opacity(0.3), radius: 8, x: 0, y: 2)
        }
        .disabled(!isConfigComplete || isProcessing)
        .opacity(isConfigComplete ? 1.0 : 0.5)
        .scaleEffect(isProcessing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }

    // MARK: - Button Handler

    private func handleEnterBubbleTap() {
        guard !isProcessing, isConfigComplete else { return }
        
        isProcessing = true
        
        // Step 1: Show waiting indicator immediately
        withAnimation(.easeOut(duration: 0.3)) {
            showWaitingIndicator = true
        }
        
        // Step 2: Execute all functionality in background
        Task { @MainActor in
            // Apply notification mode
            _ = await applyNotificationMode()
            
            // Simulate brief processing time for visual feedback
            try? await Task.sleep(nanoseconds: 800_000000) // 0.8s
            
            // Step 3: Hide waiting indicator, trigger particle expansion
            withAnimation(.easeIn(duration: 0.3)) {
                showWaitingIndicator = false
            }
            
            // Small delay before particle expansion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.4)) {
                    particleExpansionActive = true
                }
                
                // Step 4: After particle expansion, advance to next stage
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    shouldAdvanceToNextStage = true
                    
                    // Reset processing state after navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessing = false
                        particleExpansionActive = false
                    }
                }
            }
        }
    }

    private func configureRoutersButton() -> some View {
        Button {
            sheetItem = .configureOperators
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .foregroundColor(Color(hex: "#00FFD2"))
                Text(NSLocalizedString("Setup routers", comment: "Setup routers button"))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                ForEach(serverOperators.reversed()) { op in
                    Image(op.logo(colorScheme))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .grayscale(selectedOperatorIds.contains(op.operatorId) ? 0.0 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#141021"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#6E25C4").opacity(0.4), Color(hex: "#00FFD2").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    private func configureNotificationsButton() -> some View {
        Button {
            sheetItem = .configureNotifications
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color(hex: "#00FFD2"))
                Text(NSLocalizedString("Setup notifications", comment: "Setup notifications button"))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: notificationMode.icon)
                    .foregroundColor(Color(hex: "#C4BFD6"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#141021"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#6E25C4").opacity(0.4), Color(hex: "#00FFD2").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    private func reloadOperators() {
        operatorsLoading = true
        operatorsLoadFailed = false
        reloadTask?.cancel()
        reloadTask = Task {
            do {
                let conditions = try await apiGetServerOperators()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    ChatModel.shared.conditions = conditions
                    serverOperators = conditions.serverOperators
                    selectedOperatorIds = Set(serverOperators.filter { $0.enabled }.map { $0.operatorId })
                    operatorsLoading = false
                    if serverOperators.isEmpty { operatorsLoadFailed = true }
                }
            } catch {
                logger.error("Failed to reload server operators: \(responseError(error))")
                await MainActor.run {
                    operatorsLoading = false
                    operatorsLoadFailed = true
                }
            }
        }
    }

    private func applyNotificationMode() async -> Bool {
        let m = ChatModel.shared
        m.notificationMode = notificationMode

        if let token = m.deviceToken {
            switch notificationMode {
            case .off:
                m.tokenStatus = .new
                return true
            default:
                do {
                    let status = try await apiRegisterToken(token: token, notificationMode: notificationMode)
                    m.tokenStatus = status
                    return true
                } catch let error {
                    logger.error("applyNotificationMode: token registration failed, will retry later: \(responseError(error))")
                    m.tokenStatus = .new
                    return true
                }
            }
        } else {
            logger.warning("applyNotificationMode: device token not yet available, saving preference for later registration")
            return true
        }
    }
    
    private func reloadConditionsIfNeeded() {
        guard ChatModel.shared.conditions.serverOperators.isEmpty else { return }
        Task {
            do {
                let conditions = try await apiGetServerOperators()
                await MainActor.run {
                    ChatModel.shared.conditions = conditions
                }
            } catch {
                logger.error("Failed to reload server operators: \(responseError(error))")
            }
        }
    }
}

// MARK: - Particle Expansion Overlay (全屏粒子向外柔和扩散)

struct ParticleExpansionOverlay: View {
    @State private var particles: [ExpansionParticle] = []
    @State private var expanded = false
    
    struct ExpansionParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var targetX: CGFloat
        var targetY: CGFloat
        var size: CGFloat
        var color: Color
        var opacity: Double
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                withAnimation(.easeOut(duration: 1.0)) {
                    expanded = true
                    for i in particles.indices {
                        particles[i].x = particles[i].targetX
                        particles[i].y = particles[i].targetY
                        particles[i].opacity = 0
                    }
                }
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        let colors: [Color] = [
            Color(hex: "#6E25C4"),
            Color(hex: "#8B5CF6"),
            Color(hex: "#A020F0"),
            Color(hex: "#00FFD2").opacity(0.7),
            Color.white.opacity(0.5)
        ]
        
        particles = (0..<60).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 200...500)
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            return ExpansionParticle(
                x: centerX,
                y: centerY,
                targetX: centerX + cos(angle) * distance,
                targetY: centerY + sin(angle) * distance,
                size: CGFloat.random(in: 2...6),
                color: colors.randomElement()!,
                opacity: 1.0
            )
        }
    }
}
