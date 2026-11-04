//
//  BubbleAnimationComponents.swift
//  POPOPX (iOS)
//
//  Reusable bubble animation components for onboarding pages
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - Background

struct OnboardingBubbleBackground: View {
    var body: some View {
        ZStack {
            QuantumColors.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [QuantumColors.accent.opacity(0.08), QuantumColors.accentSecondary.opacity(0.04), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Sand Particle

struct SandParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
}

// MARK: - 3D Bubble Component (realistic sphere with specular highlights)

struct BubbleComponent: View {
    var diameter: CGFloat = 240
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [QuantumColors.accentSecondary.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: diameter * 0.3,
                        endRadius: diameter * 0.7
                    )
                )
                .frame(width: diameter * 1.3, height: diameter * 1.3)
                .blur(radius: 5)

            // Main 3D sphere body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            QuantumColors.accent.opacity(0.08),
                            QuantumColors.surface.opacity(0.6)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 5,
                        endRadius: diameter * 0.5
                    )
                )
                .overlay(
                    Circle()
                        .fill(QuantumColors.surfaceElevated.opacity(0.5))
                        .opacity(0.5)
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    // Specular highlight (top-left bright spot)
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 2,
                                endRadius: diameter * 0.25
                            )
                        )
                        .frame(width: diameter * 0.5, height: diameter * 0.35)
                        .offset(x: -diameter * 0.1, y: -diameter * 0.15)
                        .blur(radius: 2)
                )
                .overlay(
                    // Bottom reflection arc
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    QuantumColors.accent.opacity(0.0),
                                    QuantumColors.accentSecondary.opacity(0.5),
                                    QuantumColors.accent.opacity(0.3),
                                    QuantumColors.accentSecondary.opacity(0.0)
                                ],
                                center: .center,
                                startAngle: .degrees(180),
                                endAngle: .degrees(360)
                            ),
                            lineWidth: 3
                        )
                        .frame(width: diameter, height: diameter)
                )
                .overlay(
                    // Gradient border ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 2
                        )
                )
                .compositingGroup()
                .shadow(color: QuantumColors.accentSecondary.opacity(0.35), radius: 20, x: 0, y: 0)

            // Metadata text inside bubble (flashing red server data)
            VStack(spacing: 8) {
                metadataRow(label: NSLocalizedString("bubble_meta_ip", comment: "Bubble metadata label"), value: "192.168.1.1")
                metadataRow(label: NSLocalizedString("bubble_meta_location", comment: "Bubble metadata label"), value: "NY")
                metadataRow(label: NSLocalizedString("bubble_meta_userid", comment: "Bubble metadata label"), value: "9482...")
            }
            .font(QuantumFonts.monoCaption)
            .foregroundColor(QuantumColors.metadataRed)
            .opacity(0.5)
        }
        .offset(y: floatOffset)
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 4.0)
                        .repeatForever(autoreverses: true)
                ) {
                    floatOffset = -10
                }
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).fontWeight(.semibold)
            Text(value)
        }
    }
}

// MARK: - Compact 3D Bubble (smaller, for steps 3 & 4)

struct CompactBubble3D: View {
    var diameter: CGFloat = 180
    var symbol: String = "server.rack"
    var symbolColor: Color = QuantumColors.accentSecondary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), QuantumColors.accent.opacity(0.08), QuantumColors.surface.opacity(0.6)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 5,
                        endRadius: diameter * 0.5
                    )
                )
                .overlay(Circle().fill(.ultraThinMaterial).opacity(0.5))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Ellipse()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)], center: UnitPoint(x: 0.3, y: 0.25), startRadius: 2, endRadius: diameter * 0.25))
                        .frame(width: diameter * 0.5, height: diameter * 0.35)
                        .offset(x: -diameter * 0.1, y: -diameter * 0.15)
                        .blur(radius: 4)
                )
                .overlay(
                    Circle().stroke(LinearGradient(colors: [QuantumColors.accent, QuantumColors.accentSecondary], startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 2)
                )
                .shadow(color: QuantumColors.accentSecondary.opacity(0.4), radius: 20, x: 0, y: 0)
                .shadow(color: QuantumColors.accent.opacity(0.3), radius: 30, x: 0, y: 0)

            Image(systemName: symbol)
                .font(QuantumFonts.scaledIcon(diameter))
                .foregroundStyle(
                    LinearGradient(colors: [QuantumColors.accent, symbolColor], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: symbolColor.opacity(0.5), radius: 8, x: 0, y: 0)
        }
        .scaleEffect(pulseScale)
        .offset(y: floatOffset)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { floatOffset = -8 }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulseScale = 1.03 }
            }
        }
    }
}

// MARK: - Finger Tap Animation (interactive — tap or drag to pop)

struct FingerTapAnimation: View {
    var onPop: () -> Void
    var rotationDegrees: Double = -30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fingerOffset: CGFloat = 0
    @State private var tapScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Circle()
                .stroke(QuantumColors.accentSecondary.opacity(0.4), lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(tapScale)
                .opacity(1.0 - (tapScale - 1.0) * 0.5)

            Image(systemName: "hand.point.up.left.fill")
                .font(QuantumFonts.iconMedium)
                .foregroundColor(QuantumColors.accentSecondary)
                .shadow(color: QuantumColors.accentSecondary.opacity(0.6), radius: 8, x: 0, y: 0)
                .rotationEffect(.degrees(rotationDegrees))
                .offset(y: fingerOffset + dragOffset.height)
        }
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                tapScale = 0.7
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    tapScale = 1.0
                }
            }
            onPop()
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        dragOffset = .zero
                    }
                    if value.translation.height < -20 {
                        onPop()
                    }
                }
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                ) {
                    fingerOffset = -20
                }
                withAnimation(
                    .easeOut(duration: 1.0)
                        .repeatForever(autoreverses: false)
                ) {
                    tapScale = 1.8
                }
            }
        }
    }
}

// MARK: - Bubble Pop Particle Canvas

struct BubblePopCanvas: View {
    let particles: [SandParticle]
    let startTime: Date
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startTime)
                
                for particle in particles {
                    let gravity = 0.3
                    let friction = 0.98
                    let fadeRate = 0.015
                    let shrinkRate = 0.02
                    
                    let vy = particle.vy + gravity * elapsed
                    let vx = particle.vx * pow(friction, elapsed * 30)
                    
                    let x = particle.x + vx * elapsed * 30
                    let y = particle.y + vy * elapsed * 30
                    
                    let opacity = max(0, particle.opacity - fadeRate * elapsed * 30)
                    let particleSize = max(0.5, particle.size - shrinkRate * elapsed * 30)
                    
                    let rect = CGRect(
                        x: x - particleSize / 2,
                        y: y - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )
                    context.fill(Path(rect), with: .color(particle.color.opacity(opacity)))
                }
            }
        }
    }
}

// MARK: - Purple Flash Overlay

struct PurpleFlashOverlay: View {
    let isActive: Bool
    @State private var flashOpacity: Double = 0

    var body: some View {
        if isActive {
            QuantumColors.accent
                .opacity(flashOpacity)
                .blendMode(.screen)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.1)) {
                        flashOpacity = 0.75
                    }
                    withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                        flashOpacity = 0
                    }
                }
        }
    }
}

// MARK: - Pop Style

enum PopStyle {
    case standard
    case network
    case commitments
}

// MARK: - Bubble Pop Controller

@MainActor
class BubblePopController: ObservableObject {
    @Published private(set) var snapshot = PopSnapshot()
    @Published var startTime: Date = Date()

    struct PopSnapshot {
        var isPopping = false
        var particles: [SandParticle] = []
        var flashActive = false
    }

    var isPopping: Bool { snapshot.isPopping }
    var particles: [SandParticle] { snapshot.particles }
    var flashActive: Bool { snapshot.flashActive }

    func triggerPop(containerSize: CGSize, bubbleCenterY: CGFloat, style: PopStyle = .standard, onComplete: @escaping @Sendable () -> Void) {
        guard !isPopping else { return }
        snapshot = PopSnapshot(isPopping: true, particles: [], flashActive: true)
        BubbleHapticsManager.shared.popExplosion()

        let centerX = containerSize.width / 2
        let centerY = bubbleCenterY
        let particleCount = 500

        let colors: [Color]
        let speedRange: ClosedRange<Double>
        let vyBias: Double

        switch style {
        case .standard:
            colors = [QuantumColors.accentSecondary, QuantumColors.accent]
            speedRange = 2...8
            vyBias = -3
        case .network:
            colors = [QuantumColors.accentSecondary, QuantumColors.particleViolet, QuantumColors.networkCyan]
            speedRange = 3...10
            vyBias = -4
        case .commitments:
            colors = [QuantumColors.accentSecondary, QuantumColors.particleDeepPurple, .white]
            speedRange = 2...7
            vyBias = -2
        }

        let newParticles = (0..<particleCount).map { i in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 0...100)
            let speed = Double.random(in: speedRange)
            return SandParticle(
                x: centerX + cos(angle) * distance,
                y: centerY + sin(angle) * distance,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed + vyBias,
                size: CGFloat.random(in: 1...4),
                opacity: 1.0,
                color: colors[i % colors.count]
            )
        }

        snapshot.particles = newParticles
        startTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.snapshot.flashActive = false
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500000000)
            onComplete()
        }
    }

    func reset() {
        snapshot = PopSnapshot()
    }
}

// MARK: - Gravitational Collapse with Secure Enclave (full spec-compliant animation)

struct GravitationalCollapseWithEnclave: View {
    let alias: String
    let onComplete: () -> Void
    @State private var collapsedHash: String = ""
    @State private var meteorOffsets: [CGFloat] = []
    @State private var meteorHorizontalDrift: [CGFloat] = []
    @State private var showSecureEnclave = false
    @State private var showRipple = false
    @State private var collapseWorkItems: [DispatchWorkItem] = []
    @State private var bubbleBurstScale: CGFloat = 1.5
    @State private var bubbleBurstOpacity: Double = 1.0
    @State private var screenHeight: CGFloat = 0 // Store screen height for animation

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Hash characters spiraling down across FULL SCREEN like meteor rain
                if !collapsedHash.isEmpty {
                    ForEach(Array(collapsedHash.enumerated()), id: \.offset) { index, char in
                        Text(String(char))
                            .font(QuantumFonts.monoHashLarge) // Even larger for full-screen visibility
                            .foregroundColor(QuantumColors.hashGreen) // Pure green per spec
                            .position(
                                x: geo.size.width / 2 + (index < meteorHorizontalDrift.count ? meteorHorizontalDrift[index] : 0),
                                y: geo.size.height * 0.35 + (index < meteorOffsets.count ? meteorOffsets[index] : 0) // Start from bubble position
                            )
                            .rotationEffect(
                                .degrees(index < meteorOffsets.count ? Double(meteorOffsets[index] / 2) : 0) // More dramatic rotation
                            )
                            .opacity(index < meteorOffsets.count ? Double(max(0, 1.0 - abs(meteorOffsets[index]) / (geo.size.height * 1.2))) : 1.0)
                    }
                }

                // Title text at top
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    Text(String(localized: "Encrypting your identity.\nZero knowledge. Zero trace."))
                        .font(QuantumFonts.animationTitle)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .tracking(0.5)
                        .shadow(color: QuantumColors.accent.opacity(0.4), radius: 12, x: 0, y: 2)
                    
                    Spacer()
                }

                // Bubble burst flash effect at center
                if !collapsedHash.isEmpty {
                    Circle()
                        .fill(QuantumColors.accent.opacity(0.4))
                        .frame(width: 250, height: 250)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.35)
                        .scaleEffect(bubbleBurstScale)
                        .opacity(bubbleBurstOpacity)
                        .blur(radius: 6)
                }

                // Secure Enclave icon at absolute bottom
                if showSecureEnclave {
                    Image(systemName: "lock.shield.fill")
                        .font(QuantumFonts.iconExtraLarge) // Even larger icon
                        .foregroundStyle(
                            LinearGradient(
                                colors: [QuantumColors.hashGreen, QuantumColors.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: QuantumColors.hashGreen.opacity(0.9), radius: 28, x: 0, y: 0)
                        .position(x: geo.size.width / 2, y: geo.size.height - 80) // Bottom position
                        .transition(.scale.combined(with: .opacity))

                    if showRipple {
                        Circle()
                            .stroke(QuantumColors.accent.opacity(0.5), lineWidth: 5)
                            .frame(width: 140, height: 140)
                            .position(x: geo.size.width / 2, y: geo.size.height - 80)
                            .scaleEffect(3.5)
                            .opacity(0)
                            .animation(.easeOut(duration: 1.6), value: showRipple)

                        Circle()
                            .stroke(QuantumColors.accent.opacity(0.4), lineWidth: 4)
                            .frame(width: 180, height: 180)
                            .position(x: geo.size.width / 2, y: geo.size.height - 80)
                            .scaleEffect(2.8)
                            .opacity(0)
                            .animation(.easeOut(duration: 1.4).delay(0.15), value: showRipple)

                        Circle()
                            .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 3)
                            .frame(width: 220, height: 220)
                            .position(x: geo.size.width / 2, y: geo.size.height - 80)
                            .scaleEffect(2.2)
                            .opacity(0)
                            .animation(.easeOut(duration: 1.2).delay(0.3), value: showRipple)
                    }
                }
            }
            .onAppear {
                // Capture screen height from GeometryReader context
                // UIScreen.main is deprecated in iOS 27.0; use geometry size instead
                screenHeight = geo.size.height
                startCollapse()
            }
        }
        .onDisappear {
            collapseWorkItems.forEach { $0.cancel() }
        }
    }

    private func startCollapse() {
        // Double micro-tap haptic for gravitational collapse trigger
        BubbleHapticsManager.shared.popDoubleMicroTap()

        // Initial bubble burst flash - more dramatic
        withAnimation(.easeOut(duration: 0.25)) {
            bubbleBurstScale = 4.0
            bubbleBurstOpacity = 0
        }

        // Generate longer hex string (32 chars) resembling SHA-256 style
        let fullHash = String(format: "%016llx%016llx", 
                              UInt64(bitPattern: Int64(alias.hashValue)),
                              UInt64(bitPattern: Int64(alias.utf8.reduce(0) { $0 &+ UInt8($1).hashValue })))
        collapsedHash = String(fullHash.prefix(32))
        meteorOffsets = Array(repeating: 0, count: collapsedHash.count)
        meteorHorizontalDrift = Array(repeating: 0, count: collapsedHash.count)

        let outerWorkItem = DispatchWorkItem { [self] in
            withAnimation(.easeInOut(duration: 0.6)) {
                showSecureEnclave = true
            }

            // Meteor rain covering FULL SCREEN - characters spiral from bubble position to bottom
            let fallDistance = screenHeight * 0.75 // 75% of screen height
            for i in 0..<collapsedHash.count {
                let delay = Double(i) * 0.015 // Very fast cascade for dramatic effect
                let screenWidth: CGFloat = 390 // iPhone width reference
                // Wide horizontal spread: characters scatter across full width
                let drift = CGFloat.random(in: -screenWidth * 0.45...screenWidth * 0.45)
                withAnimation(
                    .easeIn(duration: 2.2) // Slower fall for maximum visibility across screen
                        .delay(delay)
                ) {
                    meteorHorizontalDrift[i] = drift
                    meteorOffsets[i] = fallDistance
                }
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500000000)
                showRipple = true
                try? await Task.sleep(nanoseconds: 1_800000000)
                onComplete()
            }
        }
        collapseWorkItems.append(outerWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: outerWorkItem)
    }
}

// MARK: - Gravitational Collapse (for step2 encryption animation - legacy)

struct GravitationalCollapseView: View {
    let alias: String
    @State private var collapsedHash: String = ""
    @State private var meteorOffsets: [CGFloat] = []
    @State private var showSecureEnclave = false
    @State private var showRipple = false
    @State private var collapseWorkItems: [DispatchWorkItem] = []
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if !collapsedHash.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(collapsedHash.enumerated()), id: \.offset) { index, char in
                        Text(String(char))
                            .font(QuantumFonts.monoHash)
                            .foregroundColor(QuantumColors.hashGreen) // Pure green per spec
                            .offset(y: index < meteorOffsets.count ? meteorOffsets[index] : 0)
                            .opacity(index < meteorOffsets.count ? Double(max(0, 1.0 - abs(meteorOffsets[index]) / 200.0)) : 1.0)
                    }
                }
                .shadow(color: QuantumColors.hashGreen.opacity(0.5), radius: 10, x: 0, y: 0)
            }

            if showSecureEnclave {
                Image(systemName: "lock.shield.fill")
                    .font(QuantumFonts.iconLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [QuantumColors.accentSecondary, QuantumColors.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: QuantumColors.accent.opacity(0.5), radius: 12, x: 0, y: 0)
                    .transition(.scale.combined(with: .opacity))

                if showRipple {
                    Circle()
                        .stroke(QuantumColors.accent.opacity(0.4), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(2.0)
                        .opacity(0)
                        .animation(.easeOut(duration: 1.0), value: showRipple)
                }
            }
        }
        .onAppear {
            startCollapse()
        }
        .onDisappear {
            collapseWorkItems.forEach { $0.cancel() }
        }
    }

    private func startCollapse() {
        // Double micro-tap haptic for gravitational collapse trigger
        BubbleHapticsManager.shared.popDoubleMicroTap()

        // Generate longer hex string (32 chars) resembling SHA-256 style
        let fullHash = String(format: "%016llx%016llx", 
                              UInt64(bitPattern: Int64(alias.hashValue)),
                              UInt64(bitPattern: Int64(alias.utf8.reduce(0) { $0 &+ UInt8($1).hashValue })))
        collapsedHash = String(fullHash.prefix(32))
        meteorOffsets = Array(repeating: 0, count: collapsedHash.count)

        let outerWorkItem = DispatchWorkItem { [self] in
            withAnimation(.easeInOut(duration: 0.5)) {
                showSecureEnclave = true
            }

            // Meteor rain with rotation and spiral effect
            for i in 0..<collapsedHash.count {
                let delay = Double(i) * 0.03 // Faster cascade
                withAnimation(
                    .easeIn(duration: 1.2)
                        .delay(delay)
                ) {
                    // Each character spirals downward with horizontal drift
                    meteorOffsets[i] = 220 // Fall further to reach bottom icon
                }
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500000000)
                showRipple = true
                try? await Task.sleep(nanoseconds: 1_000000000)
                onComplete()
            }
        }
        collapseWorkItems.append(outerWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: outerWorkItem)
    }
}

// MARK: - Encrypted Alias Bubble (pure brand-purple transparent, for step2 interactive flow)

struct EncryptedAliasBubble: View {
    let alias: String
    var diameter: CGFloat = 180
    var onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer ambient glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            QuantumColors.accent.opacity(0.25),
                            QuantumColors.accent.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: diameter * 0.3,
                        endRadius: diameter * 0.9
                    )
                )
                .frame(width: diameter * 1.6, height: diameter * 1.6)
                .blur(radius: 6)

            // Pure brand-purple transparent sphere with dynamic gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            QuantumColors.accent.opacity(0.35),
                            QuantumColors.accent.opacity(0.2),
                            QuantumColors.accent.opacity(0.08)
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35), // Offset for 3D effect
                        startRadius: diameter * 0.05,
                        endRadius: diameter * 0.5
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    // Specular highlight (top-left bright spot)
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.0)],
                                center: UnitPoint(x: 0.35, y: 0.3),
                                startRadius: diameter * 0.05,
                                endRadius: diameter * 0.3
                            )
                        )
                        .frame(width: diameter * 0.45, height: diameter * 0.35)
                        .offset(x: -diameter * 0.12, y: -diameter * 0.18)
                        .blur(radius: 3)
                )
                .overlay(
                    // Gradient border ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 2
                        )
                )
                .compositingGroup()
                .shadow(color: QuantumColors.accent.opacity(0.5), radius: 25, x: 0, y: 0)

            // Nickname centered in bubble
            Text(alias)
                .font(QuantumFonts.bubbleAlias(diameter: diameter))
                .foregroundColor(.white)
                .shadow(color: QuantumColors.accent.opacity(0.8), radius: 10, x: 0, y: 2)
        }
        .offset(y: floatOffset)
        .contentShape(Circle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    floatOffset = -12
                }
            }
        }
    }
}

// MARK: - Alias Bubble (wraps the entered name in a bubble - legacy gradient style)

struct AliasBubbleView: View {
    let alias: String
    var diameter: CGFloat = 160
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), QuantumColors.accent.opacity(0.08), QuantumColors.surface.opacity(0.6)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 5,
                        endRadius: diameter * 0.5
                    )
                )
                .overlay(Circle().fill(.ultraThinMaterial).opacity(0.5))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Ellipse()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)], center: UnitPoint(x: 0.3, y: 0.25), startRadius: 2, endRadius: diameter * 0.25))
                        .frame(width: diameter * 0.5, height: diameter * 0.35)
                        .offset(x: -diameter * 0.1, y: -diameter * 0.15)
                        .blur(radius: 4)
                )
                .overlay(
                    Circle().stroke(LinearGradient(colors: [QuantumColors.accent, QuantumColors.accentSecondary], startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 1.5)
                )
                .shadow(color: QuantumColors.accentSecondary.opacity(0.3), radius: 15, x: 0, y: 0)

            Text(alias)
                .font(.system(.title2, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(pulseScale)
        .offset(y: floatOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { floatOffset = -8 }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulseScale = 1.03 }
        }
    }
}

// MARK: - Bubble Rise Animation (for step2 button trigger)

struct BubbleRiseView: View {
    let alias: String
    let onComplete: () -> Void
    @State private var riseOffset: CGFloat = 0
    @State private var showHash = false
    @State private var hashOpacity: Double = 0

    var body: some View {
        ZStack {
            AliasBubbleView(alias: alias)
                .offset(y: riseOffset)
                .opacity(showHash ? 0 : 1)

            if showHash {
                Text(String(format: "%016llx", UInt64(bitPattern: Int64(alias.hashValue))).prefix(16))
                    .font(QuantumFonts.monoBody.weight(.bold))
                    .foregroundColor(QuantumColors.accentSecondary)
                    .shadow(color: QuantumColors.accentSecondary.opacity(0.5), radius: 8)
                    .opacity(hashOpacity)
            }
        }
        .onAppear {
            BubbleHapticsManager.shared.popManual()
            withAnimation(.easeOut(duration: 1.2)) {
                riseOffset = -300
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeIn(duration: 0.5)) { showHash = true }
                withAnimation(.easeIn(duration: 0.5)) { hashOpacity = 1.0 }
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_000000000)
                onComplete()
            }
        }
    }
}

// MARK: - Liquid Silver Needle Ring (环绕屏幕边缘的液态银针)

struct LiquidSilverNeedleRing: View {
    var diameter: CGFloat = 280
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: Double = 0
    @State private var liquidFlow: Double = 0

    // Ensure diameter is always positive and finite
    private var safeDiameter: CGFloat {
        guard diameter.isFinite, diameter > 0 else { return 280 }
        return diameter
    }

    var body: some View {
        ZStack {
            // Outer ambient silver glow
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            QuantumColors.silver.opacity(0.6),
                            Color.white.opacity(0.2),
                            QuantumColors.silverLight.opacity(0.7),
                            Color.white.opacity(0.1)
                        ],
                        center: .center,
                        startAngle: .degrees(liquidFlow * 360),
                        endAngle: .degrees(liquidFlow * 360 + 360)
                    ),
                    lineWidth: 3
                )
                .frame(width: safeDiameter, height: safeDiameter)
                .blur(radius: 8)

            // Main needle ring - liquid silver effect
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            QuantumColors.silverLighter,
                            QuantumColors.silver,
                            Color.white,
                            QuantumColors.silverMedium,
                            QuantumColors.silverDark
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: safeDiameter, height: safeDiameter)
                .shadow(color: Color.white.opacity(0.6), radius: 10, x: 0, y: 0)
                .shadow(color: QuantumColors.silver.opacity(0.4), radius: 15, x: 0, y: 0)

            // Specular highlights for liquid metal effect
            ForEach(0..<4) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.9), Color.clear],
                            center: .center,
                            startRadius: 1,
                            endRadius: 8
                        )
                    )
                    .frame(width: 16, height: 16)
                    .position(
                        x: safeDiameter / 2 + cos((shimmerPhase + Double(i) * 0.25) * 2 * .pi) * (safeDiameter / 2 - 8),
                        y: safeDiameter / 2 + sin((shimmerPhase + Double(i) * 0.25) * 2 * .pi) * (safeDiameter / 2 - 8)
                    )
                    .blur(radius: 2)
            }

            // Subtle inner edge reflection
            Circle()
                .stroke(
                    Color.white.opacity(0.3),
                    lineWidth: 0.5
                )
                .frame(width: safeDiameter - 4, height: safeDiameter - 4)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    liquidFlow = 1.0
                }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    shimmerPhase = 1.0
                }
            }
        }
    }
}

// MARK: - Inner Glow Circle (内部发光圆圈)

struct InnerGlowCircle: View {
    var diameter: CGFloat = 140
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var alphaPulse: Double = 0

    var body: some View {
        ZStack {
            // Enhanced ambient purple glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            QuantumColors.accent.opacity(0.5 + alphaPulse * 0.3),
                            QuantumColors.particleViolet.opacity(0.3),
                            QuantumColors.particleDeepPurple.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: diameter * 0.15,
                        endRadius: diameter * 0.9
                    )
                )
                .frame(width: diameter * 1.8, height: diameter * 1.8)
                .blur(radius: 25)

            // Secondary glow ring for depth
            Circle()
                .stroke(
                    QuantumColors.accent.opacity(0.4 + alphaPulse * 0.2),
                    lineWidth: 2
                )
                .frame(width: diameter * 1.5, height: diameter * 1.5)
                .blur(radius: 10)

            // Bright core at center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            QuantumColors.thistle.opacity(0.9),
                            QuantumColors.particleDeepPurple.opacity(0.7),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: 16
                    )
                )
                .frame(width: 32, height: 32)
                .shadow(color: QuantumColors.accent.opacity(0.9), radius: 12)
                .shadow(color: Color.white.opacity(0.5), radius: 8)

            // Outer pulsing ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            QuantumColors.accentSecondary.opacity(0.6 + alphaPulse * 0.3),
                            QuantumColors.accent.opacity(0.4),
                            QuantumColors.accentSecondary.opacity(0.6 + alphaPulse * 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: diameter * 1.2, height: diameter * 1.2)
                .scaleEffect(1.0 + alphaPulse * 0.08)
                .opacity(0.7 + alphaPulse * 0.3)
        }
        .scaleEffect(1.0 + alphaPulse * 0.08)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    alphaPulse = 1.0
                }
            } else {
                alphaPulse = 0.5
            }
        }
    }
}

// MARK: - X Logo Particles (X徽标粒子)

struct XLogoParticles: View {
    var size: CGFloat = 140
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var alphaPulse: Double = 0
    @State private var particleDrift: Double = 0
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Particle field background
            ForEach(0..<80) { i in
                Circle()
                    .fill(particleColor(for: i))
                    .frame(width: particleSize(for: i) * 1.3, height: particleSize(for: i) * 1.3)
                    .position(
                        x: size / 2 + particleFieldX(for: i) + particleDriftOffset(for: i, axis: .x),
                        y: size / 2 + particleFieldY(for: i) + particleDriftOffset(for: i, axis: .y)
                    )
                    .opacity(0.6 + alphaPulse * 0.4)
            }

            // Main X shape formed by dense particles
            Group {
                // Left diagonal stroke
                ForEach(0..<35) { i in
                    Circle()
                        .fill(QuantumColors.thistle.opacity(0.9 + alphaPulse * 0.1))
                        .frame(width: 4, height: 4)
                        .position(
                            x: size / 2 - size * 0.22 + CGFloat(i) * (size * 0.44 / 34),
                            y: size / 2 - size * 0.22 + CGFloat(i) * (size * 0.44 / 34)
                        )
                        .shadow(color: QuantumColors.accent.opacity(0.8), radius: 6)
                }

                // Right diagonal stroke
                ForEach(0..<35) { i in
                    Circle()
                        .fill(QuantumColors.thistle.opacity(0.9 + alphaPulse * 0.1))
                        .frame(width: 4, height: 4)
                        .position(
                            x: size / 2 + size * 0.22 - CGFloat(i) * (size * 0.44 / 34),
                            y: size / 2 - size * 0.22 + CGFloat(i) * (size * 0.44 / 34)
                        )
                        .shadow(color: QuantumColors.accent.opacity(0.8), radius: 6)
                }
            }
            .rotationEffect(.degrees(rotationAngle))
        }
        .frame(width: size, height: size)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    alphaPulse = 1.0
                }
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    particleDrift = 1.0
                }
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotationAngle = 15
                }
            } else {
                alphaPulse = 0.5
            }
        }
    }

    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [
            QuantumColors.accent,
            QuantumColors.particleViolet,
            QuantumColors.particleDeepPurple,
            QuantumColors.particleMidPurple,
            QuantumColors.thistle,
            Color.white.opacity(0.7)
        ]
        return colors[index % colors.count]
    }

    private func particleSize(for index: Int) -> CGFloat {
        let sizes: [CGFloat] = [1.5, 2, 2.5, 3, 1.8, 2.2] // Larger base sizes
        return sizes[index % sizes.count]
    }

    private func particleFieldX(for index: Int) -> CGFloat {
        // Return offset from center (can be negative) - positioning will add size/2
        let angle = Double(index) * 0.5
        let radius = 20 + CGFloat(index % 5) * 6
        return cos(angle) * radius
    }

    private func particleFieldY(for index: Int) -> CGFloat {
        // Return offset from center (can be negative) - positioning will add size/2
        let angle = Double(index) * 0.5
        let radius = 20 + CGFloat(index % 5) * 6
        return sin(angle) * radius
    }

    private func particleDriftOffset(for index: Int, axis: Axis) -> CGFloat {
        let offset = sin(particleDrift * 2 * .pi + Double(index) * 0.3) * 4 // Larger drift
        return axis == .x ? offset : offset * 0.7
    }

    enum Axis { case x, y }
}

// MARK: - Waiting Indicator (等待中动画)

struct WaitingIndicator: View {
    @State private var rotation: Double = 0
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Rotating ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                QuantumColors.accent.opacity(0.2),
                                QuantumColors.accentSecondary,
                                QuantumColors.accent.opacity(0.2)
                            ],
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 50, height: 50)

                // Pulsing center dot
                Circle()
                    .fill(QuantumColors.accentSecondary)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOpacity)
            }

            Text(NSLocalizedString("Processing...", comment: "Waiting indicator text"))
                .font(QuantumFonts.monoBodyMedium)
                .foregroundColor(QuantumColors.textMetadata)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.4
            }
        }
    }
}

// MARK: - X Balloon 3D (带X徽标的动态气球)

struct XBalloon3D: View {
    var diameter: CGFloat = 160
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floatOffset: CGFloat = 0
    @State private var scalePulse: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var xAlphaPulse: Double = 0

    var body: some View {
        ZStack {
            // Main balloon sphere with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            QuantumColors.particleViolet.opacity(0.8),
                            QuantumColors.accent,
                            QuantumColors.bubblePurpleDeep
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: diameter * 0.1,
                        endRadius: diameter * 0.5
                    )
                )
                .frame(width: diameter, height: diameter)
                .shadow(color: QuantumColors.accent.opacity(0.6), radius: 20, x: 0, y: 10)
                .scaleEffect(scalePulse)

            // Inner glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [QuantumColors.accentSecondary.opacity(0.6), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: diameter * 0.85, height: diameter * 0.85)
                .blur(radius: 3)

            // X logo particles overlay - constrained to balloon bounds for proper centering
            Group {
                // Simplified X shape with fewer particles for performance
                ForEach(0..<20) { i in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 3, height: 3)
                        .position(
                            x: diameter / 2 - diameter * 0.15 + CGFloat(i) * (diameter * 0.3 / 19),
                            y: diameter / 2 - diameter * 0.15 + CGFloat(i) * (diameter * 0.3 / 19)
                        )
                        .shadow(color: QuantumColors.accent.opacity(0.8), radius: 3)
                }

                ForEach(0..<20) { i in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 3, height: 3)
                        .position(
                            x: diameter / 2 + diameter * 0.15 - CGFloat(i) * (diameter * 0.3 / 19),
                            y: diameter / 2 - diameter * 0.15 + CGFloat(i) * (diameter * 0.3 / 19)
                        )
                        .shadow(color: QuantumColors.accent.opacity(0.8), radius: 3)
                }
            }
            .frame(width: diameter, height: diameter) // Constrain to balloon bounds so particles center correctly
            .rotationEffect(.degrees(rotationAngle))
            .opacity(0.7 + xAlphaPulse * 0.3)

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.7), Color.clear],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 5,
                        endRadius: 20
                    )
                )
                .frame(width: diameter * 0.25, height: diameter * 0.15)
                .offset(x: -diameter * 0.15, y: -diameter * 0.2)
                .blur(radius: 2)
        }
        .offset(y: floatOffset)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    floatOffset = -8
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scalePulse = 1.05
                }
                withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                    rotationAngle = 10
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    xAlphaPulse = 1.0
                }
            }
        }
    }
}

