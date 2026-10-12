// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import UIKit

struct NeonGlassTabBarConfig {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Adapt to current theme mode per ui.rtf spec
        let isInDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        
        if isInDarkMode {
            // Dark Mode: Pure black OLED with ultraThinMaterial per main.rtf spec
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.92)
        } else {
            // Light Mode: Clean white with thickMaterial
            appearance.backgroundEffect = UIBlurEffect(style: .systemThickMaterial)
            appearance.backgroundColor = UIColor(red: 247/255, green: 245/255, blue: 250/255, alpha: 0.92)
        }

        appearance.shadowColor = .clear

        let itemAppearance = UITabBarItemAppearance()

        itemAppearance.normal.iconColor = UIColor(white: 0.6, alpha: 1.0)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.6, alpha: 1.0)
        ]

        itemAppearance.selected.iconColor = UIColor(red: 110/255, green: 37/255, blue: 196/255, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 110/255, green: 37/255, blue: 196/255, alpha: 1.0)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isHidden = true
    }
}

struct NeonTabIndicator: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#6E25C4"),
                            Color(hex: "#FF00A0")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 20, height: 3)
                .shadow(color: Color(hex: "#6E25C4").opacity(0.6), radius: 4)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

struct NeonTabIcon: View {
    let systemName: String
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isActive {
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(hex: "#6E25C4"))
                    .blur(radius: 6)
                    .opacity(0.5)
            }

            Image(systemName: systemName)
                .font(.system(size: 22, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? Color(hex: "#6E25C4") : Color(white: 0.75))
        }
        .scaleEffect(!reduceMotion && isActive ? 1.08 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - POPOPX
extension NeonGlassTabBarConfig {
    static let pxComponentTag: String = "PX_NEON_GLASS_TAB_BAR"
}
