// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import BitchatMesh

struct MeshStatusIndicator: View {
    let currentTransport: String
    let isConnected: Bool

    private var iconName: String {
        if !isConnected { return "wifi.slash" }
        switch currentTransport {
        case "bluetooth": return "antenna.radiowaves.left.and.right"
        case "internet": return "wifi"
        default: return "wifi.slash"
        }
    }

    private var label: String {
        if !isConnected { return "DISCONNECTED" }
        switch currentTransport {
        case "bluetooth": return "MESH"
        case "internet": return "ONLINE"
        default: return "OFFLINE"
        }
    }

    private var glowColor: Color {
        if !isConnected { return .gray }
        switch currentTransport {
        case "bluetooth": return neonGradientSecondary()
        case "internet": return darkThemeAccentColor()
        default: return .gray
        }
    }

    private var accessibilityName: String {
        switch currentTransport {
        case "bluetooth": return NSLocalizedString("Bluetooth mesh", comment: "Mesh status indicator accessibility name")
        case "internet": return NSLocalizedString("Internet", comment: "Mesh status indicator accessibility name")
        default: return NSLocalizedString("Disconnected", comment: "Mesh status indicator accessibility name")
        }
    }

    var body: some View {
        let showGlow = true

        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(glowColor)
                .shadow(color: glowColor.opacity(isConnected && showGlow ? 0.8 : 0), radius: 3)

            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(glowColor)
                .shadow(color: glowColor.opacity(isConnected && showGlow ? 0.6 : 0), radius: 2)
        }
        .opacity(isConnected ? 1.0 : 0.6)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(glowColor.opacity(0.4), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("%@, %@", comment: "Mesh status indicator accessibility label"), accessibilityName, isConnected ? NSLocalizedString("connected", comment: "Mesh status connected") : NSLocalizedString("disconnected", comment: "Mesh status disconnected")))
        .accessibilityAddTraits(.isStaticText)
        .popopxBranded()
    }
}
