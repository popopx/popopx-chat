//
//  DesignTokens.swift
//  POPOPX (iOS)
//
//  Created to standardize UI design system across the app.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

/// Centralized design tokens for consistent spacing, sizing, and visual properties
enum DesignTokens {
    
    // MARK: - Corner Radius
    
    /// Small corner radius for buttons and compact elements (8pt)
    static let cornerRadiusSmall: CGFloat = 8
    
    /// Medium corner radius for cards and inputs (12pt)
    static let cornerRadiusMedium: CGFloat = 12
    
    /// Large corner radius for modals and sheets (16pt)
    static let cornerRadiusLarge: CGFloat = 16
    
    /// Extra large corner radius for prominent elements (24pt)
    static let cornerRadiusExtraLarge: CGFloat = 24
    
    /// Capsule/circle shape (use with .clipShape(Capsule()))
    static func cornerRadiusPill(height: CGFloat) -> CGFloat {
        return height / 2
    }
    
    // MARK: - Spacing (8pt grid system)
    
    /// Extra small spacing (4pt) - tight grouping
    static let spacingXS: CGFloat = 4
    
    /// Small spacing (8pt) - related elements
    static let spacingSM: CGFloat = 8
    
    /// Medium spacing (16pt) - default padding
    static let spacingMD: CGFloat = 16
    
    /// Large spacing (24pt) - section separation
    static let spacingLG: CGFloat = 24
    
    /// Extra large spacing (32pt) - major sections
    static let spacingXL: CGFloat = 32
    
    // MARK: - Touch Targets (WCAG 2.1 Compliance)
    
    /// Minimum touch target size per WCAG 2.1 Level AA (44x44pt)
    static let minTouchTarget: CGFloat = 44
    
    /// Comfortable touch target for primary actions (48x48pt)
    static let comfortableTouchTarget: CGFloat = 48
    
    /// Small icon button minimum size (32x32pt with padding to reach 44pt hit area)
    static let iconButtonSize: CGFloat = 32
    
    // MARK: - Typography Scale
    
    /// Display text for hero sections
    static let fontDisplay: Font = .system(.largeTitle)
    
    /// Large headlines
    static let fontHeadline: Font = .system(.title)
    
    /// Section titles
    static let fontTitle: Font = .system(.title2)
    
    /// Body text
    static let fontBody: Font = .system(.body)
    
    /// Captions and secondary text
    static let fontCaption: Font = .system(.caption)
    
    /// Small captions
    static let fontCaptionSmall: Font = .system(.caption2)
    
    // MARK: - Line Heights
    
    /// Tight line height for headings (1.2x)
    static func lineHeightTight(for fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.2
    }
    
    /// Normal line height for body text (1.5x)
    static func lineHeightNormal(for fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.5
    }
    
    /// Relaxed line height for long-form content (1.75x)
    static func lineHeightRelaxed(for fontSize: CGFloat) -> CGFloat {
        return fontSize * 1.75
    }
    
    // MARK: - Shadow Presets
    
    /// Subtle shadow for elevated surfaces
    static let shadowSubtle = ShadowPreset(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 2
    )
    
    /// Medium shadow for cards and modals
    static let shadowMedium = ShadowPreset(
        color: Color.black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 4
    )
    
    /// Strong shadow for floating elements
    static let shadowStrong = ShadowPreset(
        color: Color.black.opacity(0.16),
        radius: 24,
        x: 0,
        y: 8
    )
    
    // MARK: - Blur Intensity
    
    /// Light blur for subtle depth
    static let blurLight: CGFloat = 10
    
    /// Medium blur for glass effects
    static let blurMedium: CGFloat = 20
    
    /// Strong blur for prominent glass
    static let blurStrong: CGFloat = 40
}

/// Shadow preset for consistent elevation
struct ShadowPreset {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    func apply() -> some ViewModifier {
        return ShadowModifier(preset: self)
    }
}

/// View modifier for applying shadow presets
struct ShadowModifier: ViewModifier {
    let preset: ShadowPreset
    
    func body(content: Content) -> some View {
        content
            .shadow(color: preset.color, radius: preset.radius, x: preset.x, y: preset.y)
    }
}

extension View {
    /// Apply a shadow preset
    func shadow(_ preset: ShadowPreset) -> some View {
        self.modifier(ShadowModifier(preset: preset))
    }
    
    /// Ensure minimum touch target size per WCAG 2.1
    func minTouchTarget() -> some View {
        self.frame(minWidth: DesignTokens.minTouchTarget, minHeight: DesignTokens.minTouchTarget)
    }
}
