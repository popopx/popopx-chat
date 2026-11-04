// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// POPOPX Brand Colors and Typography
import SwiftUI
import UIKit

enum QuantumColors {
    // Brand colors - Fresh Blue-Green (Modern 2026 palette)
    static let primaryStart = Color(0xFF2AABEE) // Fresh Blue - brand primary
    static let primaryEnd = Color(0xFF5BC8FD)   // Light Blue - gradient end

    // Background and surface colors — dynamically adapt to light/dark mode per ui.rtf spec
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x00/255, green: 0x00/255, blue: 0x00/255, alpha: 1) // #000000 (Pure black - OLED friendly)
            : UIColor(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255, alpha: 1) // #F2F2F7 (iOS light background)
    })
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1) // #1C1C1E (iOS dark surface)
            : UIColor(red: 0xFF/255, green: 0xFF/255, blue: 0xFF/255, alpha: 1) // #FFFFFF (Pure white card)
    })
    static let surfaceElevated = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1) // #2C2C2E (iOS elevated surface)
            : UIColor(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255, alpha: 1) // #F2F2F7 (iOS light elevated)
    })

    static let accent = Color(0xFF00B4D8) // Ocean Blue - brand primary
    static let accentSecondary = Color(0xFF00C4A6) // Teal - ambient accent for glow/borders
    static let accentWarm = Color(0xFFFF6B6B) // Coral - countdown/instability accent

    // Encryption level colors
    static let encryptionStandard = Color(0xFF00B4D8) // Ocean Blue
    static let encryptionEnhanced = Color(0xFF00C4A6) // Teal
    static let quantumSafe = Color(0xFF2AABEE) // Fresh Blue
    static let encryptionQuantum = Color(0xFF2AABEE) // Fresh Blue (alias for quantumSafe)

    // Text colors — dynamically adapt to light/dark mode
    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // #FFFFFF (pure white)
            : UIColor(red: 0x00/255, green: 0x00/255, blue: 0x00/255, alpha: 1) // #000000 (pure black)
    })
    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x8E/255, green: 0x8E/255, blue: 0x93/255, alpha: 1) // #8E8E93 (iOS secondary label)
            : UIColor(red: 0x3C/255, green: 0x3C/255, blue: 0x43/255, alpha: 1) // #3C3C43 (iOS secondary label light)
    })
    static let textTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x63/255, green: 0x63/255, blue: 0x66/255, alpha: 1) // #636366 (iOS tertiary label)
            : UIColor(red: 0x3C/255, green: 0x3C/255, blue: 0x43/255, alpha: 0.6) // #3C3C43 60% opacity
    })
    static let textOnDark = Color.white
    static let textBody = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // #FFFFFF
            : UIColor(red: 0x00/255, green: 0x00/255, blue: 0x00/255, alpha: 1) // #000000
    })

    // Status colors — dynamic variants for WCAG AA contrast compliance
    static let success = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x10/255, green: 0xB9/255, blue: 0x81/255, alpha: 1) // #10B981 (5.4:1 on #000)
            : UIColor(red: 0x0A/255, green: 0x8F/255, blue: 0x60/255, alpha: 1) // #0A8F60 (5.1:1 on #F2F2F7)
    })
    static let warning = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF/255, green: 0xD6/255, blue: 0x0A/255, alpha: 1) // #FFD60A (bright amber for dark bg, 8.2:1)
            : UIColor(red: 0xB4/255, green: 0x53/255, blue: 0x09/255, alpha: 1) // #B45309 (dark amber for light bg, 5.0:1)
    })
    static let error = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF/255, green: 0x3B/255, blue: 0x30/255, alpha: 1) // #FF3B30 (4.6:1 on #000)
            : UIColor(red: 0xDC/255, green: 0x26/255, blue: 0x26/255, alpha: 1) // #DC2626 (4.7:1 on #FFF)
    })

    // Chat bubble colors — dynamically adapt to light/dark mode
    static let bubbleOther = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1) // #2C2C2E (other's message)
            : UIColor(red: 0xE9/255, green: 0xE9/255, blue: 0xE9/255, alpha: 1) // #E9E9E9 (other's message light)
    })
    static let bubbleOtherText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1) // #FFFFFF
            : UIColor(red: 0x00/255, green: 0x00/255, blue: 0x00/255, alpha: 1) // #000000
    })

    // Online/offline status colors
    static let online = Color(0xFF22C55E) // Green for online status
    static let offline = Color(0xFF8E8E93) // Gray for offline status

    // Separator color — dynamically adapt to light/dark mode
    static let separator = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x38/255, green: 0x38/255, blue: 0x3A/255, alpha: 1) // #38383A (iOS separator dark)
            : UIColor(red: 0xC6/255, green: 0xC6/255, blue: 0xC8/255, alpha: 1) // #C6C6C8 (iOS separator light)
    })

    // Animation / bubble colors
    static let bubbleGlow = Color(0xFF00C4A6) // Teal glow for bubble halos
    static let bubblePurple = Color(0xFF00B4D8) // Ocean Blue for bubble gradients
    static let bubblePurpleDeep = Color(0xFF008B8B) // Deep teal for balloon gradient core
    static let particleCyan = Color(0xFF00C4A6) // Teal particle color
    static let particleViolet = Color(0xFF00B4D8) // Ocean Blue particle color
    static let particleDeepPurple = Color(0xFF2AABEE) // Fresh Blue particle accent
    static let particleMidPurple = Color(0xFF5BC8FD) // Light Blue (medianet)
    static let hashGreen = Color(0xFF00C4A6) // Teal for hash/metadata text
    static let metadataRed = Color(0xFFFF6B6B) // Coral for metadata values
    static let networkCyan = Color(0xFF00B4D8) // Network accent cyan

    // Extended palette colors (generative art, effects, gradients)
    static let pureCyan = Color(0xFF00FFFF) // Pure cyan for effects
    static let hotPink = Color(0xFFFF6B9D) // Soft pink for effects
    static let pureMagenta = Color(0xFFFF00FF) // Pure magenta for effects
    static let turquoise = Color(0xFF00FFCC) // Turquoise for effects
    static let voidBlack = Color(0xFF000000) // Pure black background
    static let vividPurple = Color(0xFF00B4D8) // Ocean Blue variant (repurposed)
    static let darkPurpleDeep = Color(0xFF008B8B) // Deep teal variant (repurposed)
    static let deepVoid = Color(0xFF0A0A0A) // Deep void surface
    static let oceanBlue = Color(0xFF00B4D8) // Ocean blue accent
    static let warmOrange = Color(0xFFFF8E53) // Warm orange accent
    static let lavenderBright = Color(0xFF5BC8FD) // Light blue variant (repurposed)
    static let brightPurple = Color(0xFF2AABEE) // Fresh Blue variant (repurposed)
    static let tealAccent = Color(0xFF00C4A6) // Teal accent
    static let deepTeal = Color(0xFF008B8B) // Deep teal
    static let electricPurple = Color(0xFF00B4D8) // Ocean Blue variant (repurposed)
    static let darkPurpleMid = Color(0xFF1C1C1E) // Dark surface mid-tone (repurposed)
    static let darkPurpleDeep2 = Color(0xFF0A0A0A) // Dark surface deep variant (repurposed)
    static let darkSurface = Color(0xFF1C1C1E) // Dark surface
    static let darkSurfaceDeep = Color(0xFF0A0A0A) // Dark surface deep
    static let darkSurfaceDarker = Color(0xFF000000) // Dark surface darker
    static let darkSurfaceCard = Color(0xFF1C1C1E) // Dark surface for cards
    static let darkSurfaceBase = Color(0xFF0A0A0A) // Dark surface base
    static let mutedPurpleGray = Color(0xFF8E8E93) // Muted gray (repurposed)
    static let darkPurpleGray = Color(0xFF636366) // Dark gray (repurposed)
    static let silverGray = Color(0xFFB0B0C8) // Silver gray
    static let darkSilverGray = Color(0xFFA0A0B8) // Dark silver gray
    static let paleLilac = Color(0xFFE8E8F0) // Pale lilac
    static let lightSurface = Color(0xFFF2F2F7) // Light surface

    // Additional palette colors
    static let lavenderSilver = Color(0xFFC0C0D0) // Lavender silver for needle effects
    static let darkPurpleShadow = Color(0xFF1C1C1E) // Dark surface for shadow/backgrounds (repurposed)
    static let coralRed = Color(0xFFFF6B6B) // Coral red for icons/accents
    static let midnightPurple = Color(0xFF000000) // Pure black for backgrounds (repurposed)

    // Silver / needle ring colors
    static let silver = Color(0xFFC0C0C0) // Standard silver
    static let silverLight = Color(0xFFE8E8E8) // Light silver highlight
    static let silverLighter = Color(0xFFF0F0F0) // Lighter silver
    static let silverMedium = Color(0xFFD8D8D8) // Medium silver
    static let silverDark = Color(0xFFA8A8A8) // Dark silver
    static let thistle = Color(0xFFD8BFD8) // Thistle / lavender for X particles

    // Text colors (additional semantic)
    static let textDescription = Color(0xFF8E8E93) // iOS secondary label gray (repurposed)
    static let textMetadata = Color(0xFF636366) // iOS tertiary label gray (repurposed)

    // Button / UI surface colors
    static let buttonDarkPurple = Color(0xFF00B4D8) // Ocean Blue button background (repurposed)

    // Border opacity tokens
    static let borderSubtle: Double = 0.15
    static let borderNormal: Double = 0.30
    static let borderEmphasis: Double = 0.50
}

enum QuantumFonts {
    // Display - for launch/onboarding hero titles
    static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)
    // Title - for page titles
    static let title = Font.system(.largeTitle, design: .rounded).weight(.bold)
    // Header title - for section headers (existing)
    static let headerTitle = Font.system(.title, design: .rounded).weight(.bold)
    // Section title - for subsection headers
    static let sectionTitle = Font.system(.title2, design: .rounded).weight(.semibold)
    // Section header - for card titles (existing)
    static let sectionHeader = Font.system(.headline, design: .rounded)
    // Body - for main content text (existing)
    static let body = Font.system(.body, design: .rounded)
    // Body semibold - for button labels
    static let bodySemibold = Font.system(.body, design: .rounded).weight(.semibold)
    // Body large - for prominent body text
    static let bodyLarge = Font.system(.body, design: .rounded)
    // Callout - for secondary text
    static let callout = Font.system(.callout, design: .rounded)
    // Caption - for small text (existing)
    static let caption = Font.system(.caption, design: .rounded)
    // Mono - for encryption/technical labels only
    static let mono = Font.system(.caption, design: .monospaced)
    // Keep monospaced only for encryption/security labels
    static let encryptionLabel = Font.system(.caption2, design: .rounded).monospaced()

    // Animation / hash monospaced fonts
    static let monoBody = Font.system(.body, design: .monospaced)
    static let monoBodyMedium = Font.system(.body, design: .monospaced).weight(.medium)
    static let monoBodySemibold = Font.system(.body, design: .monospaced).weight(.semibold)
    static let monoCaption = Font.system(.caption, design: .monospaced)
    static let monoCaptionMedium = Font.system(.caption2, design: .monospaced).weight(.medium)
    static let monoSmall = Font.system(.caption2, design: .monospaced)
    static let monoHash = Font.system(.body, design: .monospaced).weight(.bold)
    static let monoHashLarge = Font.system(.title3, design: .monospaced).weight(.bold)
    static let monoTiny = Font.system(.caption2, design: .monospaced)

    // Animation title
    static let animationTitle = Font.system(.title2, design: .rounded).weight(.bold)

    // Icon sizes - use semantic text styles for Dynamic Type support
    static let iconExtraLarge = Font.system(.largeTitle)
    static let iconLarge = Font.system(.title)
    static let iconMedium = Font.system(.title2)
    static let iconRegular = Font.system(.body)
    static let iconSmall = Font.system(.caption2)
    static let iconTiny = Font.system(.caption2)

    // Bubble alias text
    static func bubbleAlias(diameter: CGFloat) -> Font {
        .system(.body, design: .rounded)
    }

    // Dynamic icon font scaled to container
    static func scaledIcon(_ diameter: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(.body).weight(weight)
    }
}

// MARK: - Spacing Tokens

enum QuantumSpacing {
    // Base 4pt grid
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 25
    static let xxxxl: CGFloat = 28

    // Semantic spacing
    static let cardCorner: CGFloat = 12
    static let cardCornerLarge: CGFloat = 16
    static let cardCornerXLarge: CGFloat = 24
    static let inputCorner: CGFloat = 14
    static let buttonCorner: CGFloat = 10
    static let buttonCornerLarge: CGFloat = 16

    // Onboarding
    static let onboardingHPad: CGFloat = 25
    static let onboardingVPad: CGFloat = 20
    static let onboardingSectionGap: CGFloat = 14
    static let onboardingCardGap: CGFloat = 10
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
