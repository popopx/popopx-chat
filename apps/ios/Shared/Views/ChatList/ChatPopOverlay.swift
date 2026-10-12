//
//  ChatPopOverlay.swift
//  POPOPX
//
//  Global overlay for "Swipe to Pop" — purple flash + 1500 rainbow particles
//  Copyright © 2026 POPOPX. All rights reserved.
//

import SwiftUI

@MainActor
class ChatPopCoordinator: ObservableObject {
    static let shared = ChatPopCoordinator()

    @Published private(set) var snapshot = PopSnapshot()

    struct PopSnapshot {
        var isPopping = false
        var particles: [SandParticle] = []
        var flashOpacity: Double = 0
    }

    var isPopping: Bool { snapshot.isPopping }
    var particles: [SandParticle] { snapshot.particles }
    var flashOpacity: Double { snapshot.flashOpacity }

    private var particleTimer: Timer?
    private var flashTimer: Timer?

    private init() {}

    func triggerPop(chatId: String) {
        guard !isPopping else { return }
        snapshot = PopSnapshot(isPopping: true, particles: [], flashOpacity: 0)

        let particleCount = 500

        let screenSize: CGSize = {
            if let ws = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return ws.windows.first?.bounds.size ?? CGSize(width: 390, height: 844)
            }
            return CGSize(width: 390, height: 844)
        }()
        let centerX = screenSize.width / 2
        let centerY = screenSize.height * 0.45

        let rainbowColors: [Color] = [
            Color(hex: "#FF3B30"),
            Color(hex: "#FF9500"),
            Color(hex: "#FFCC00"),
            Color(hex: "#34C759"),
            Color(hex: "#00FFD2"),
            Color(hex: "#007AFF"),
            Color(hex: "#AF52DE"),
            Color(hex: "#FF2D55"),
            Color(hex: "#6E25C4"),
            Color(hex: "#00FFD2"),
        ]

        snapshot.particles = (0..<particleCount).map { i in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 0...80)
            let speed = Double.random(in: 1...6)
            return SandParticle(
                x: centerX + CGFloat(cos(angle) * distance),
                y: centerY + CGFloat(sin(angle) * distance * 0.5),
                vx: CGFloat(cos(angle) * speed) * 0.6,
                vy: CGFloat(sin(angle) * speed * 0.3) - 1.5,
                size: CGFloat.random(in: 1.5...4.5),
                opacity: 1.0,
                color: rainbowColors[i % rainbowColors.count]
            )
        }

        withAnimation(.easeOut(duration: 0.04)) {
            snapshot.flashOpacity = 0.6
        }
        withAnimation(.easeOut(duration: 0.08).delay(0.04)) {
            snapshot.flashOpacity = 0
        }

        startParticlePhysics()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.reset()
        }
    }

    private func startParticlePhysics() {
        let timerInterval = 1.0 / 30.0
        particleTimer?.invalidate()
        particleTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                var allFinished = true
                for i in self.snapshot.particles.indices {
                    self.snapshot.particles[i].vy += 0.35
                    self.snapshot.particles[i].vx *= 0.985
                    self.snapshot.particles[i].x += self.snapshot.particles[i].vx
                    self.snapshot.particles[i].y += self.snapshot.particles[i].vy
                    self.snapshot.particles[i].opacity = max(0, self.snapshot.particles[i].opacity - 0.012)
                    self.snapshot.particles[i].size = max(0.5, self.snapshot.particles[i].size - 0.015)
                    if self.snapshot.particles[i].opacity > 0 { allFinished = false }
                }
                if allFinished {
                    timer.invalidate()
                }
                self.objectWillChange.send()
            }
        }
    }

    func reset() {
        particleTimer?.invalidate()
        particleTimer = nil
        snapshot = PopSnapshot()
    }
}

struct ChatPopOverlayView: View {
    @ObservedObject var coordinator = ChatPopCoordinator.shared

    var body: some View {
        ZStack {
            if coordinator.flashOpacity > 0 {
                Color(hex: "#6E25C4")
                    .opacity(coordinator.flashOpacity)
                    .blendMode(.screen)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if coordinator.isPopping && !coordinator.particles.isEmpty {
                BubblePopCanvas(particles: coordinator.particles)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }
}
