// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct QuantumFieldBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    var particleCount: Int = 40
    var speed: Double = 1.0

    var body: some View {
        // POPOPX: Reduced from 20fps to 1fps for battery efficiency
        TimelineView(.animation(minimumInterval: 1.0 / 1.0, paused: powerMode.isLowPowerMode || reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate * speed
                drawParticles(context: &context, size: size, time: time)
                drawFlowLines(context: &context, size: size, time: time)
            }
            .opacity(colorScheme == .dark ? 0.6 : 0.3)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .popopxBranded()
    }

    private func drawParticles(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let count = particleCount
        for i in 0..<count {
            let seed = Double(i) * 12.9898
            let x = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1.0)
            let y = (cos(seed) * 12345.6789).truncatingRemainder(dividingBy: 1.0)

            let baseX = abs(x) * size.width
            let baseY = abs(y) * size.height

            let flowX = sin(time * 0.3 + Double(i) * 0.5) * 30
            let flowY = cos(time * 0.2 + Double(i) * 0.3) * 20

            let px = baseX + flowX
            let py = baseY + flowY

            let alpha = 0.15 + 0.15 * sin(time * 0.5 + Double(i))
            let radius = 1.5 + 1.0 * sin(time * 0.3 + Double(i) * 0.7)

            let color: Color = i % 3 == 0
                ? Color(0xFF8B5CF6).opacity(alpha)
                : (i % 3 == 1 ? Color(0xFF7C3AED).opacity(alpha) : Color(0xFF818CF8).opacity(alpha * 0.8))

            let rect = CGRect(x: px - radius, y: py - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func drawFlowLines(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let lineCount = 6
        for i in 0..<lineCount {
            var path = Path()
            let startY = size.height * (0.15 + Double(i) * 0.14)
            let amplitude = 20.0 + Double(i) * 5.0
            let frequency = 0.003 + Double(i) * 0.0005
            let phase = time * 0.4 + Double(i) * 1.2

            path.move(to: CGPoint(x: 0, y: startY))
            for x in stride(from: 0.0, through: size.width, by: 4.0) {
                let y = startY + sin(x * frequency + phase) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }

            let alpha = 0.06 + 0.04 * sin(time * 0.3 + Double(i))
            let color: Color = i % 2 == 0
                ? Color(0xFF8B5CF6).opacity(alpha)
                : Color(0xFF818CF8).opacity(alpha)

            context.stroke(path, with: .color(color), lineWidth: 1.0)
        }
    }
}
