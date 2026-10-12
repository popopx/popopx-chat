// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/08-FEATURE-TOKEN.md
import SwiftUI
import POPOPXSwitch

struct TokenBalanceBadge: View {
    @EnvironmentObject var computeStore: ComputeStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.caption2)
            Text(formatBalance(computeStore.balance))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(QuantumColors.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(QuantumColors.accent.opacity(0.2), lineWidth: 0.5)
                )
        )
        .popopxBranded()
    }

    private func formatBalance(_ balance: Double) -> String {
        let balance = max(0, balance)
        let intBalance = Int(balance)
        if intBalance >= 1000 {
            return String(format: "%.1fk", balance / 1000.0)
        }
        return "\(intBalance)"
    }
}
