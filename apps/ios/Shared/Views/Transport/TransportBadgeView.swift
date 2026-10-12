// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct TransportBadgeView: View {
    let transportID: String?
    var isAvailable: Bool = true

    private var iconName: String {
        if !isAvailable { return "wifi.slash" }
        switch transportID {
        case "bluetooth": return "antenna.radiowaves.left.and.right"
        case "multipeer": return "wifi"
        case "internet": return "globe"
        default: return "wifi.slash"
        }
    }

    private var label: String {
        if !isAvailable { return "OFF" }
        switch transportID {
        case "bluetooth": return "BLE"
        case "multipeer": return "MESH"
        case "internet": return "NET"
        default: return "OFF"
        }
    }

    private var color: Color {
        if !isAvailable { return Color.secondary }
        switch transportID {
        case "bluetooth": return neonGradientSecondary()
        case "multipeer": return QuantumColors.accent
        case "internet": return darkThemeAccentColor()
        default: return Color.secondary
        }
    }

    private var accessibilityName: String {
        switch transportID {
        case "bluetooth": return NSLocalizedString("Bluetooth", comment: "Transport badge accessibility name")
        case "multipeer": return NSLocalizedString("Multipeer", comment: "Transport badge accessibility name")
        case "internet": return NSLocalizedString("Internet", comment: "Transport badge accessibility name")
        default: return NSLocalizedString("Unknown", comment: "Transport badge accessibility name")
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.caption2.weight(.bold))
            Text(label)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .opacity(isAvailable ? 1.0 : 0.6)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(color.opacity(isAvailable ? 0.12 : 0.06))
                .overlay(Capsule().strokeBorder(color.opacity(isAvailable ? 0.4 : 0.2), lineWidth: 0.5))
        )
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("%@ transport, %@", comment: "Transport badge accessibility label"), accessibilityName, isAvailable ? NSLocalizedString("available", comment: "Transport badge state") : NSLocalizedString("unavailable", comment: "Transport badge state")))
        .accessibilityAddTraits(.isStaticText)
        .popopxBranded()
    }
}

#Preview("All States") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            TransportBadgeView(transportID: "internet", isAvailable: true)
            TransportBadgeView(transportID: "bluetooth", isAvailable: true)
        }
        HStack(spacing: 12) {
            TransportBadgeView(transportID: "internet", isAvailable: false)
            TransportBadgeView(transportID: "bluetooth", isAvailable: false)
        }
        TransportBadgeView(transportID: nil, isAvailable: false)
    }
    .padding(20)
    .background(Color.black)
}
