// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/05-FEATURE-QUANTUM-THEME.md
import SwiftUI

enum QuantumGradients {
    static let primary = LinearGradient(
        colors: [QuantumColors.primaryStart, QuantumColors.primaryEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = LinearGradient(
        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let warmAccent = LinearGradient(
        colors: [QuantumColors.accentWarm, QuantumColors.accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.04, green: 0.02, blue: 0.08, alpha: 1)
                    : UIColor(red: 0.98, green: 0.97, blue: 1.0, alpha: 1)
            }),
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.06, green: 0.02, blue: 0.14, alpha: 1)
                    : UIColor(red: 0.96, green: 0.95, blue: 1.0, alpha: 1)
            }),
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.04, green: 0.02, blue: 0.12, alpha: 1)
                    : UIColor(red: 0.97, green: 0.96, blue: 1.0, alpha: 1)
            }),
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1)
                    : UIColor(red: 0.95, green: 0.94, blue: 0.99, alpha: 1)
            })
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surface = LinearGradient(
        colors: [QuantumColors.surface, QuantumColors.surfaceElevated],
        startPoint: .top,
        endPoint: .bottom
    )

    static let encryptionShield = RadialGradient(
        colors: [QuantumColors.accent.opacity(0.3), QuantumColors.accentSecondary.opacity(0.1), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 60
    )

    static let quantumAura = AngularGradient(
        colors: [
            QuantumColors.accent.opacity(0.0),
            QuantumColors.accent.opacity(0.4),
            QuantumColors.accentSecondary.opacity(0.4),
            QuantumColors.accent.opacity(0.0)
        ],
        center: .center
    )

    static let cardBorder = LinearGradient(
        colors: [QuantumColors.accent.opacity(0.35), QuantumColors.accentSecondary.opacity(0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let neonGlow = RadialGradient(
        colors: [QuantumColors.accent.opacity(0.15), QuantumColors.accentSecondary.opacity(0.08), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 120
    )
}
