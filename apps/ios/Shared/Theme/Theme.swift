//
//  Theme.swift
//  POPOPX (iOS)
//
//  Created by Avently on 14.06.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI
import POPOPXSwitch

// Spec: spec/services/theme.md#CurrentColors
// currentUser is nil at module load time; updated via ThemeManager.applyTheme once chat starts
private let _currentColorsLock = NSLock()
private enum _CurrentColorsStorage {
    static var backing: ThemeManager.ActiveTheme = ThemeManager.currentColors(nil, nil, nil, themeOverridesDefault.get())
}

var CurrentColors: ThemeManager.ActiveTheme {
    get { _currentColorsLock.lock(); defer { _currentColorsLock.unlock() }; return _CurrentColorsStorage.backing }
    set { _currentColorsLock.lock(); defer { _currentColorsLock.unlock() }; _CurrentColorsStorage.backing = newValue }
}

var MenuTextColor: Color {
    if isInDarkTheme() {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { AppTheme.shared.colors.onBackground.opacity(0.8) }
        }
        return Color(white: 0.87)
    } else {
        return Color.black
    }
}
var NoteFolderIconColor: Color {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { AppTheme.shared.appColors.primaryVariant2 }
    }
    return Color(0xFF934CFA)
}

func isInDarkTheme() -> Bool { !CurrentColors.colors.isLight }

func isOLEDMode() -> Bool {
    UserDefaults.standard.object(forKey: "PX_OLED_TRUE_BLACK") as? Bool ?? false
}

func setOLEDMode(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: "PX_OLED_TRUE_BLACK")
}

@MainActor
func applyOLEDOverride() {
    guard isOLEDMode(), !CurrentColors.colors.isLight else { return }
    CurrentColors.colors.background = Color(0xFF000000)
    CurrentColors.colors.surface = Color(0xFF0A0A0A)
}

// Returns the brand accent color for dark mode UI elements
func darkThemeAccentColor() -> Color {
    Color(0xFF6E25C4) // Popop Purple - brand primary for dark mode
}

// Returns the header font style for dark mode
func darkThemeHeaderFont() -> Font {
    Font.system(.headline, design: .default)
}

// Returns the secondary brand color for gradients
func neonGradientSecondary() -> Color {
    Color(0xFF934CFA) // Bright purple - secondary accent for gradients
}

// Flash effect configuration based on current theme
struct FlashEffectConfig {
    let coreColor: Color
    let outerColor: Color
    let blendMode: BlendMode
    let maxOpacity: Double
    let duration: TimeInterval
    let frameCount: Int
}

func currentFlashConfig() -> FlashEffectConfig {
    if isInDarkTheme() {
        return FlashEffectConfig(
            coreColor: Color(0xFF9D5BFF), // High-brightness glowing purple
            outerColor: Color(0xFF00FFD2), // Aura cyan halo
            blendMode: .screen,
            maxOpacity: 0.75,
            duration: 0.1, // 12 frames at 120Hz
            frameCount: 12
        )
    } else {
        return FlashEffectConfig(
            coreColor: Color.white, // Crystal transparent white
            outerColor: Color(0xFF6E25C4).opacity(0.15), // Logo purple shadow
            blendMode: .overlay,
            maxOpacity: 0.35,
            duration: 0.15, // 18 frames at 120Hz
            frameCount: 18
        )
    }
}

// Spec: spec/services/theme.md#AppTheme
@MainActor
class AppTheme: ObservableObject, Equatable {
    static let shared = AppTheme(name: CurrentColors.name, base: CurrentColors.base, colors: CurrentColors.colors, appColors: CurrentColors.appColors, wallpaper: CurrentColors.wallpaper)

    var name: String
    var base: DefaultTheme
    @ObservedObject var colors: Colors
    @ObservedObject var appColors: AppColors
    @ObservedObject var wallpaper: AppWallpaper

    init(name: String, base: DefaultTheme, colors: Colors, appColors: AppColors, wallpaper: AppWallpaper) {
        self.name = name
        self.base = base
        self.colors = colors
        self.appColors = appColors
        self.wallpaper = wallpaper
    }

    nonisolated static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    func updateFromCurrentColors() {
        objectWillChange.send()
        name = CurrentColors.name
        base = CurrentColors.base
        colors.updateColorsFrom(CurrentColors.colors)
        appColors.updateColorsFrom(CurrentColors.appColors)
        wallpaper.updateWallpaperFrom(CurrentColors.wallpaper)
    }
}

struct ThemedBackground: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    var grouped: Bool = false
    var glass: Bool = false

    func body(content: Content) -> some View {
        if glass {
            content
                .background(glassBaseBackground)
                .background(
                    LinearGradient(
                        colors: [
                            theme.colors.background.opacity(0.85),
                            theme.colors.background.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            content
                .background(
                    isInDarkTheme()
                    ? LinearGradient(
                        colors: [
                            theme.colors.background,
                            theme.colors.background.lighter(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [theme.colors.background], startPoint: .top, endPoint: .bottom)
                )
                .background(
                    grouped
                    ? theme.colors.background.asGroupedBackground(theme.base.mode)
                    : Color.clear
                )
        }
    }

    private var glassBaseBackground: some View {
        ZStack {
            theme.colors.background

            // Subtle color orbs for depth - more subtle than before
            Circle()
                .fill(theme.colors.primary.opacity(isInDarkTheme() ? 0.06 : 0.03))
                .frame(width: 300, height: 300)
                .offset(x: -120, y: -200)
                .blur(radius: 60)

            Circle()
                .fill(theme.colors.secondary.opacity(isInDarkTheme() ? 0.04 : 0.02))
                .frame(width: 250, height: 250)
                .offset(x: 140, y: 100)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
    }
}

// Spec: spec/services/theme.md#systemInDarkThemeCurrently
var systemInDarkThemeCurrently: Bool {
    return UITraitCollection.current.userInterfaceStyle == .dark
}

@MainActor
func reactOnDarkThemeChanges(_ inDarkNow: Bool) {
    if currentThemeDefault.get() == DefaultTheme.SYSTEM_THEME_NAME && CurrentColors.colors.isLight == inDarkNow {
        // Change active colors from light to dark and back based on system theme
        ThemeManager.applyTheme(DefaultTheme.SYSTEM_THEME_NAME)
    }
}

extension ThemeWallpaper {
    public func importFromString() -> ThemeWallpaper {
        if preset == nil, let image {
            // Need to save image from string and to save its path
            if let parsed = imageFromBase64(image),
               let filename = saveWallpaperFile(image: parsed) {
                var copy = self
                copy.image = nil
                copy.imageFile = filename
                return copy
            } else {
                return ThemeWallpaper()
            }
        } else {
            return self
        }
    }

    func withFilledWallpaperBase64() -> ThemeWallpaper {
        let aw = toAppWallpaper()
        let type = aw.type
        let preset: String? = if case let WallpaperType.preset(filename, _) = type { filename } else { nil }
        let scale: Float? = if case let WallpaperType.preset(_, scale) = type { scale } else { if case let WallpaperType.image(_, scale, _) = type { scale } else { 1.0 } }
        let scaleType: WallpaperScaleType? = if case let WallpaperType.image(_, _, scaleType) = type { scaleType } else { nil }
        let image: String? = if case WallpaperType.image = type, let image = type.uiImage { resizeImageToStrSizeSync(image, maxDataSize: 5_000_000) } else { nil }
        return ThemeWallpaper (
            preset: preset,
            scale: scale,
            scaleType: scaleType,
            background: aw.background?.toReadableHex(),
            tint: aw.tint?.toReadableHex(),
            image: image,
            imageFile: nil
        )
    }
}

extension ThemeModeOverride {
    func removeSameColors(_ base: DefaultTheme, colorsToCompare tc: ThemeColors) -> ThemeModeOverride {
        let wallpaperType = WallpaperType.from(wallpaper) ?? WallpaperType.empty
        let w: ThemeWallpaper
        switch wallpaperType {
        case let WallpaperType.preset(filename, scale):
            let p = PresetWallpaper.from(filename)
            w = ThemeWallpaper(
                preset: filename,
                scale: scale ?? wallpaper?.scale,
                scaleType: nil,
                background: p?.background[base]?.toReadableHex(),
                tint: p?.tint[base]?.toReadableHex(),
                image: nil,
                imageFile: nil
            )
        case WallpaperType.image:
            w = ThemeWallpaper(
                preset: nil,
                scale: nil,
                scaleType: WallpaperScaleType.fill,
                background: Color.clear.toReadableHex(),
                tint: Color.clear.toReadableHex(),
                image: nil,
                imageFile: nil
            )
        default:
            w = ThemeWallpaper()
        }
        let wallpaper: ThemeWallpaper? = if let wallpaper {
            ThemeWallpaper(
                preset: wallpaper.preset,
                scale: wallpaper.scale != w.scale ? wallpaper.scale : nil,
                scaleType: wallpaper.scaleType != w.scaleType ? wallpaper.scaleType : nil,
                background: wallpaper.background != w.background ? wallpaper.background : nil,
                tint: wallpaper.tint != w.tint ? wallpaper.tint : nil,
                image: wallpaper.image,
                imageFile: wallpaper.imageFile
            )
        } else {
            nil
        }
        return ThemeModeOverride(
            mode: self.mode,
            colors: ThemeColors(
                primary: colors.primary != tc.primary ? colors.primary : nil,
                primaryVariant: colors.primaryVariant != tc.primaryVariant ? colors.primaryVariant : nil,
                secondary: colors.secondary != tc.secondary ? colors.secondary : nil,
                secondaryVariant: colors.secondaryVariant != tc.secondaryVariant ? colors.secondaryVariant : nil,
                background: colors.background != tc.background ? colors.background : nil,
                surface: colors.surface != tc.surface ? colors.surface : nil,
                title: colors.title != tc.title ? colors.title : nil,
                primaryVariant2: colors.primaryVariant2 != tc.primaryVariant2 ? colors.primaryVariant2 : nil,
                sentMessage: colors.sentMessage != tc.sentMessage ? colors.sentMessage : nil,
                sentQuote: colors.sentQuote != tc.sentQuote ? colors.sentQuote : nil,
                receivedMessage: colors.receivedMessage != tc.receivedMessage ? colors.receivedMessage : nil,
                receivedQuote: colors.receivedQuote != tc.receivedQuote ? colors.receivedQuote : nil
            ),
            wallpaper: wallpaper
        )
    }
}
