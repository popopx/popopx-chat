// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct QuantumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassBackground(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [QuantumColors.accent.opacity(0.2), QuantumColors.accentSecondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: QuantumColors.accent.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

struct QuantumButtonStyle: ButtonStyle {
    let isPrimary: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(primary: Bool = true) {
        self.isPrimary = primary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(QuantumFonts.body.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isEnabled
                                        ? [QuantumColors.accent, QuantumColors.accentSecondary]
                                        : [QuantumColors.accent.opacity(0.3), QuantumColors.accentSecondary.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: QuantumColors.accent.opacity(isEnabled ? 0.3 : 0),
                                radius: 10, x: 0, y: 4
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isEnabled
                                        ? [QuantumColors.accent, QuantumColors.accentSecondary]
                                        : [QuantumColors.accent.opacity(0.3), QuantumColors.accentSecondary.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                }
            )
            .foregroundColor(isPrimary ? .white : (isEnabled ? QuantumColors.accent : QuantumColors.accent.opacity(0.3)))
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? (reduceMotion ? 1.0 : 0.85) : (isEnabled ? 1.0 : 0.5))
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

struct QuantumGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [QuantumColors.accent.opacity(0.15), QuantumColors.accentSecondary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

struct QuantumGlowBorder: ViewModifier {
    var color: Color = QuantumColors.accent
    var cornerRadius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.4), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func quantumCard() -> some View {
        modifier(QuantumCardModifier())
    }

    func quantumGlassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(QuantumGlassCard(cornerRadius: cornerRadius))
    }

    func quantumGlowBorder(color: Color = QuantumColors.accent, cornerRadius: CGFloat = 12) -> some View {
        modifier(QuantumGlowBorder(color: color, cornerRadius: cornerRadius))
    }
}
