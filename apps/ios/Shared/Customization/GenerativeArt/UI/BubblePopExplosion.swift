// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

struct PopParticle: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let velocity: CGVector
    let radius: Double
    let color: Color
    let isGlowing: Bool
    let dragK: Double
}

struct BubblePopExplosion: View {
    let startDate: Date
    let puncturePoint: CGPoint
    let bubbleSize: CGSize
    let particleCount: Int
    let onCompletion: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var particles: [PopParticle] = []
    @State private var showFlash = true
    @State private var hasCompleted = false
    @AppStorage("popopx_particle_density") private var particleDensity: Double = 1.0

    private var palette: [Color] {
        // Dual-mode particle colors based on current theme
        if isInDarkTheme() {
            // Dark Mode: Neon Extinguish - 50% #6E25C4 + 30% #00FFD2 + 20% #FF00A0
            return [
                Color(hex: "#6E25C4"), // Popop Purple (50% weight)
                Color(hex: "#6E25C4"),
                Color(hex: "#00FFD2"), // Aura Cyan (30% weight)
                Color(hex: "#FF00A0"), // Transient Pink (20% weight)
                Color.white
            ]
        } else {
            // Light Mode: Water Pearl Splash - 60% #A570EB + 20% #00C4A6 + 20% #FFFFFF
            return [
                Color(hex: "#A570EB"), // Bright purple water drop (60% weight)
                Color(hex: "#A570EB"),
                Color(hex: "#A570EB"),
                Color(hex: "#00C4A6"), // Thin mint green (20% weight)
                Color.white // High-gloss white pearl (20% weight)
            ]
        }
    }

    private let dragK: Double = 4.5
    private let totalFrames: Int = 48
    private let fps: Double = 60.0
    private var totalDuration: TimeInterval { Double(totalFrames) / fps }

    var body: some View {
        ZStack {
            if showFlash {
                PunctureFlash(point: puncturePoint)
            }

            if !reduceMotion {
                explosionCanvas
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            generateParticles()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showFlash = false
            }
        }
        .popopxBranded()
    }

    private var explosionCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / fps, paused: hasCompleted || powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                if elapsed < 0 { return }

                let frame = min(Int(elapsed * fps), totalFrames)
                if frame >= totalFrames {
                    if !hasCompleted {
                        DispatchQueue.main.async {
                            hasCompleted = true
                            onCompletion?()
                        }
                    }
                    return
                }

                let t = elapsed
                let opacity = max(0, 1.0 - pow(Double(frame) / Double(totalFrames), 2))
                let dragDecay = exp(-dragK * t)
                let gravTerm = (dragK * t + exp(-dragK * t) - 1.0) / dragK

                // Fallback gravity vector when MotionGravityService unavailable
                let gravity = CGVector(dx: 0, dy: 9.8)
                
                // Stage 3: Pixel sand dissolution starts at 70% of animation
                let sandPhaseStart = Double(totalFrames) * 0.7
                let isInSandPhase = Double(frame) > sandPhaseStart
                let sandProgress = isInSandPhase ? (Double(frame) - sandPhaseStart) / (Double(totalFrames) - sandPhaseStart) : 0.0

                for particle in particles {
                    let px = particle.origin.x + particle.velocity.dx * dragDecay / dragK
                    let py = particle.origin.y + particle.velocity.dy * dragDecay / dragK
                        + gravity.dy * gravTerm
                    
                    let lifeProgress = Double(frame) / Double(totalFrames)
                    
                    // Stage 3 enhancement: Add horizontal drift and faster radius shrink
                    let adjustedPx: Double
                    let adjustedPy: Double
                    let adjustedRadius: Double
                    
                    if isInSandPhase {
                        // Horizontal drift simulating sand falling
                        let driftAmount = sandProgress * 8.0 * (particle.isGlowing ? 1.5 : 1.0)
                        adjustedPx = px + driftAmount
                        
                        // Faster vertical fall in sand phase
                        adjustedPy = py + sandProgress * 20.0
                        
                        // Radius shrinks faster in sand phase
                        let baseScale = 1.0 - sandProgress * 0.7
                        adjustedRadius = particle.radius * baseScale * (1.0 - lifeProgress * 0.3)
                    } else {
                        adjustedPx = px
                        adjustedPy = py
                        let scale = 1.0 - lifeProgress * 0.5
                        adjustedRadius = particle.radius * scale
                    }

                    let rect = CGRect(
                        x: adjustedPx - adjustedRadius,
                        y: adjustedPy - adjustedRadius,
                        width: adjustedRadius * 2,
                        height: adjustedRadius * 2
                    )

                    // Sand phase: particles become more transparent and fragmented
                    let sandOpacityMultiplier = isInSandPhase ? (1.0 - sandProgress * 0.5) : 1.0
                    let finalOpacity = opacity * 0.85 * sandOpacityMultiplier
                    
                    let color = particle.color.opacity(finalOpacity)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )

                    if particle.isGlowing && opacity > 0.3 {
                        context.fill(
                            Path(ellipseIn: rect.insetBy(dx: -adjustedRadius * 0.6, dy: -adjustedRadius * 0.6)),
                            with: .color(color.opacity(opacity * 0.25 * sandOpacityMultiplier))
                        )
                    }
                }
            }
        }
    }

    private func generateParticles() {
        var newParticles: [PopParticle] = []
        let scaledCount = max(1, Int(Double(particleCount) * particleDensity))

        for i in 0..<scaledCount {
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 200...1200)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed

            let color = palette[i % palette.count]
            let radius = Double.random(in: 1.0...3.5)

            newParticles.append(PopParticle(
                origin: puncturePoint,
                velocity: CGVector(dx: vx, dy: vy),
                radius: radius,
                color: color,
                isGlowing: i % 6 == 0,
                dragK: dragK
            ))
        }
        particles = newParticles
    }
}

struct PunctureFlash: View {
    let point: CGPoint
    let config = currentFlashConfig()

    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.3

    var body: some View {
        Circle()
            .fill(config.coreColor)
            .frame(width: 24, height: 24)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(point)
            .onAppear {
                withAnimation(.easeOut(duration: config.duration)) {
                    opacity = 0
                    scale = 1.5
                }
            }
            .allowsHitTesting(false)
    }
}

@MainActor
class BubblePopCoordinator: ObservableObject {
    static let shared = BubblePopCoordinator()

    @Published var activeExplosions: [UUID: PopExplosionConfig] = [:]

    func triggerPop(
        chatItemId: UUID,
        at puncturePoint: CGPoint,
        isManual: Bool,
        bubbleSize: CGSize,
        onCompletion: (() -> Void)? = nil
    ) {
        let count = isManual ? 1500 : 1000

        Task { @MainActor in
            BubbleHapticsManager.shared.popExplosion()
        }

        let config = PopExplosionConfig(
            puncturePoint: puncturePoint,
            bubbleSize: bubbleSize,
            particleCount: count,
            startDate: Date(),
            onCompletion: onCompletion
        )

        activeExplosions[chatItemId] = config
    }

    func removeExplosion(_ id: UUID) {
        activeExplosions.removeValue(forKey: id)
    }
}

struct PopExplosionConfig {
    let puncturePoint: CGPoint
    let bubbleSize: CGSize
    let particleCount: Int
    let startDate: Date
    let onCompletion: (() -> Void)?
}

// MARK: - POPOPX
extension BubblePopExplosion {
    static let pxComponentTag: String = "PX_BUBBLE_POP"
    static let pxDefaultParticleCount: Int = 1500
}
