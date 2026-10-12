// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

enum QuantumWallpaper: String, CaseIterable, Identifiable {
    case quantumField = "Quantum Field"
    case encryptedSpace = "Encrypted Space"
    case shieldMatrix = "Shield Matrix"
    case dataStream = "Data Stream"
    case deepSpace = "Deep Space"
    case nebula = "Nebula"
    case darkMatter = "Dark Matter"

    var id: String { rawValue }

    var isDynamic: Bool {
        switch self {
        case .quantumField, .dataStream: return true
        default: return false
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .quantumField:
            return LinearGradient(
                colors: [
                    Color(0xFF0A0A14),
                    Color(0xFF131320),
                    Color(0xFF0D0D18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .encryptedSpace:
            return LinearGradient(
                colors: [
                    Color(0xFF08080F),
                    Color(0xFF101020),
                    Color(0xFF0D0D1A)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .shieldMatrix:
            return LinearGradient(
                colors: [
                    Color(0xFF0D0D11),
                    Color(0xFF161622),
                    Color(0xFF0D0D11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dataStream:
            return LinearGradient(
                colors: [
                    Color(0xFF0A0A12),
                    Color(0xFF0D0D16),
                    Color(0xFF0A0A12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .deepSpace:
            return LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.02, blue: 0.08),
                    Color(red: 0.07, green: 0.03, blue: 0.18),
                    Color(red: 0.04, green: 0.04, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nebula:
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.02, blue: 0.18),
                    Color(red: 0.04, green: 0.06, blue: 0.22),
                    Color(red: 0.02, green: 0.10, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .darkMatter:
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.07),
                    Color(red: 0.07, green: 0.04, blue: 0.12),
                    Color(red: 0.05, green: 0.03, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var accentColor: Color {
        switch self {
        case .quantumField: return QuantumColors.accent
        case .encryptedSpace: return QuantumColors.accentSecondary
        case .shieldMatrix: return QuantumColors.encryptionQuantum
        case .dataStream: return QuantumColors.encryptionStandard
        case .deepSpace: return QuantumColors.accent
        case .nebula: return QuantumColors.accentSecondary
        case .darkMatter: return QuantumColors.encryptionStandard
        }
    }
}

struct WallpaperBackground: View {
    let wallpaper: QuantumWallpaper
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            wallpaper.gradient
                .ignoresSafeArea()

            if wallpaper.isDynamic && !reduceMotion {
                switch wallpaper {
                case .quantumField:
                    QuantumFieldBackground(particleCount: 50, speed: 0.8)
                case .dataStream:
                    DataStreamEffect()
                default:
                    EmptyView()
                }
            } else if wallpaper == .shieldMatrix {
                ShieldMatrixPattern()
            } else if wallpaper == .encryptedSpace {
                StarFieldEffect()
            }
        }
        .ignoresSafeArea()
        .popopxBranded()
    }
}

struct DataStreamEffect: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var powerMode = PowerModeObserver.shared

    var body: some View {
        // POPOPX: Reduced from 15fps to 2fps for battery efficiency
        TimelineView(.animation(minimumInterval: 1.0/2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let lineCount = 20
                let spacing = size.width / CGFloat(lineCount)

                for i in 0..<lineCount {
                    let x = CGFloat(i) * spacing + spacing / 2
                    let speed = 100.0 + Double(i % 5) * 30.0
                    let offset = time.truncatingRemainder(dividingBy: 2.0) * speed
                    let alpha = 0.03 + 0.02 * sin(time + Double(i))

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: -10))
                    path.addLine(to: CGPoint(x: x, y: size.height + 10))

                    let color = i % 3 == 0
                        ? Color(0xFF8B5CF6).opacity(alpha)
                        : (i % 3 == 1 ? Color(0xFF818CF8).opacity(alpha) : Color(0xFF7C3AED).opacity(alpha * 0.7))

                    context.stroke(path, with: .color(color), lineWidth: 1.5)

                    let dotY = CGFloat(offset)
                    if dotY > 0 && dotY < size.height {
                        let dotRect = CGRect(x: x - 2, y: dotY - 2, width: 4, height: 4)
                        context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(alpha * 3)))
                    }
                }
            }
        }
        .opacity(0.6)
        .allowsHitTesting(false)
    }
}

struct ShieldMatrixPattern: View {
    var body: some View {
        Canvas { context, size in
            let hexSize: CGFloat = 30
            let hexHeight = hexSize * sqrt(3.0) / 2.0
            let cols = Int(size.width / (hexSize * 1.5)) + 2
            let rows = Int(size.height / hexHeight) + 2

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * hexSize * 1.5
                    let y = CGFloat(row) * hexHeight + (col % 2 == 0 ? 0 : hexHeight / 2)

                    var path = Path()
                    for i in 0..<6 {
                        let angle = Double(i) * .pi / 3.0 - .pi / 6.0
                        let px = x + hexSize * 0.5 * cos(angle)
                        let py = y + hexSize * 0.5 * sin(angle)
                        if i == 0 {
                            path.move(to: CGPoint(x: px, y: py))
                        } else {
                            path.addLine(to: CGPoint(x: px, y: py))
                        }
                    }
                    path.closeSubpath()

                    context.stroke(path, with: .color(Color(0xFF8B5CF6).opacity(0.06)), lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct StarFieldEffect: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var powerMode = PowerModeObserver.shared

    var body: some View {
        // POPOPX: Reduced from 12fps to 2fps for battery efficiency
        TimelineView(.animation(minimumInterval: 1.0/2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let starCount = 60

                for i in 0..<starCount {
                    let seed = Double(i) * 12.9898
                    let x = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1.0) * size.width
                    let y = abs(cos(seed) * 12345.6789).truncatingRemainder(dividingBy: 1.0) * size.height

                    let twinkle = 0.3 + 0.3 * sin(time * 2.0 + Double(i))
                    let radius = 0.5 + 0.5 * sin(time + Double(i) * 0.5)

                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    let color = i % 4 == 0
                        ? Color(0xFF8B5CF6).opacity(twinkle)
                        : (i % 4 == 1 ? Color(0xFF818CF8).opacity(twinkle * 0.8) : Color.white.opacity(twinkle * 0.6))

                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }

                let nebulaX = size.width * 0.7
                let nebulaY = size.height * 0.3
                let nebulaRect = CGRect(x: nebulaX - 80, y: nebulaY - 60, width: 160, height: 120)
                context.fill(
                    Path(ellipseIn: nebulaRect),
                    with: .radialGradient(
                        Gradient(colors: [Color(0xFF8B5CF6).opacity(0.08), .clear]),
                        center: CGPoint(x: nebulaX, y: nebulaY),
                        startRadius: 0,
                        endRadius: 80
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}
