// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// POPOPX Brand Colors and Typography
import SwiftUI
import UIKit

enum QuantumColors {
    // Brand colors - Popop Purple + Aura Cyan
    static let primaryStart = Color(0xFF6E25C4) // Popop Purple - brand primary
    static let primaryEnd = Color(0xFF934CFA) // Bright purple gradient end

    // Background and surface colors — dynamically adapt to light/dark mode per ui.rtf spec
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x00/255, green: 0x00/255, blue: 0x00/255, alpha: 1) // #000000 (pure black canvas for OLED)
            : UIColor(red: 0xF7/255, green: 0xF5/255, blue: 0xFA/255, alpha: 1) // #F7F5FA (pale lilac-white)
    })
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x09/255, green: 0x07/255, blue: 0x10/255, alpha: 1) // #090710 (chat layer with 5% brand purple)
            : UIColor(red: 0xFF/255, green: 0xFF/255, blue: 0xFF/255, alpha: 1) // #FFFFFF (pure white card)
    })
    static let surfaceElevated = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x12/255, green: 0x0D/255, blue: 0x1D/255, alpha: 1) // #120D1D (bar background)
            : UIColor(red: 0xF1/255, green: 0xEC/255, blue: 0xF7/255, alpha: 1) // #F1ECF7 (light bar background)
    })

    static let accent = Color(0xFF6E25C4) // Popop Purple - brand primary
    static let accentSecondary = Color(0xFF00FFD2) // Aura Cyan - ambient accent for glow/borders
    static let accentWarm = Color(0xFFFF00A0) // Transient Pink - countdown/instability accent

    // Encryption level colors
    static let encryptionStandard = Color(0xFF818CF8) // Blue-periwinkle
    static let encryptionEnhanced = Color(0xFF10B981) // Green
    static let quantumSafe = Color(0xFF8B5CF6) // Vivid violet
    static let encryptionQuantum = Color(0xFF8B5CF6) // Vivid violet (alias for quantumSafe)

    // Text colors — dynamically adapt to light/dark mode
    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0xF1/255, green: 0xF5/255, blue: 0xF9/255, alpha: 1) // #F1F5F9
            : UIColor(red: 0x1E/255, green: 0x29/255, blue: 0x3B/255, alpha: 1) // #1E293B
    })
    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x94/255, green: 0xA3/255, blue: 0xB8/255, alpha: 1) // #94A3B8
            : UIColor(red: 0x47/255, green: 0x55/255, blue: 0x69/255, alpha: 1) // #475569
    })
    static let textTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x7B/255, green: 0x8F/255, blue: 0xA6/255, alpha: 1) // #7B8FA6 (brightened for 5:1 contrast)
            : UIColor(red: 0x64/255, green: 0x74/255, blue: 0x8B/255, alpha: 1) // #64748B
    })

    // Status colors
    static let success = Color(0xFF10B981) // Green
    static let warning = Color(0xFFF59E0B) // Amber
    static let error = Color(0xFFFF3B30) // Red
}

enum QuantumFonts {
    static let headerTitle = Font.system(.title, design: .rounded).weight(.bold)
    static let sectionHeader = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    // Keep monospaced only for encryption/security labels
    static let encryptionLabel = Font.system(.caption2, design: .rounded).monospaced()
}

enum EncryptionLevel {
    case standard, enhanced, quantumSafe

    var label: String {
        switch self {
        case .standard: return NSLocalizedString("E2EE", comment: "encryption level standard label")
        case .enhanced: return NSLocalizedString("Enhanced", comment: "encryption level enhanced label")
        case .quantumSafe: return NSLocalizedString("Quantum-Safe", comment: "encryption level quantum safe label")
        }
    }

    var color: Color {
        switch self {
        case .standard: return QuantumColors.encryptionStandard
        case .enhanced: return QuantumColors.encryptionEnhanced
        case .quantumSafe: return QuantumColors.encryptionQuantum
        }
    }
}
