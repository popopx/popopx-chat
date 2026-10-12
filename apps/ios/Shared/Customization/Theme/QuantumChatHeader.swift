// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct QuantumChatHeader: View {
    let encryptionLevel: EncryptionLevel

    var body: some View {
        HStack(spacing: 8) {
            encryptionIcon
            Text(encryptionLevel.label)
                .font(QuantumFonts.encryptionLabel)
                .foregroundColor(encryptionLevel.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(encryptionLevel.color.opacity(0.3), lineWidth: 1)
                )
        )
        .popopxBranded()
    }

    @ViewBuilder
    private var encryptionIcon: some View {
        switch encryptionLevel {
        case .standard:
            Image(systemName: "lock.shield.fill")
                .font(.caption2)
                .foregroundColor(QuantumColors.encryptionStandard)
        case .enhanced:
            Image(systemName: "lock.shield.fill")
                .font(.caption2)
                .foregroundColor(QuantumColors.encryptionEnhanced)
                .quantumPulse(color: QuantumColors.encryptionEnhanced, duration: 2.0)
        case .quantumSafe:
            Image(systemName: "lock.shield.fill")
                .font(.caption2)
                .foregroundColor(QuantumColors.encryptionQuantum)
                .shieldGlow(color: QuantumColors.encryptionQuantum, intensity: 1.2)
        }
    }
}
