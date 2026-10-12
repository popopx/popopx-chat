//
//  PXThemeManager.swift
//  POPOPX (iOS)
//
//  Theme resolution, migration, persistence and application.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/theme.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI
import POPOPXSwitch

// MARK: - Legacy Theme Names

/// Themes that existed before the POPOPX redesign; all migrate to DARK.
private let pxLegacyThemeNames: Set<String> = ["POPOPX", "BLACK", "QUANTUM", "STEALTH", "EMBER"]

// Spec: spec/services/theme.md#ThemeManager
class ThemeManager {
    // Themes removed from the palette; preferences migrate to DARK
    private static let removedThemeNames: Set<String> = pxLegacyThemeNames

    // MARK: - Migration

    /// Migrates old theme preferences to DARK. Call at app launch before theme resolution.
    @MainActor
    static func migrateThemes() {
        pxMigrateSingleThemePref(currentThemeDefault)
        pxMigrateSingleThemePref(systemDarkThemeDefault)
        // Clean up stored overrides for removed themes
        pxPurgeRemovedThemeOverrides()
    }

    // MARK: - ActiveTheme

    // Spec: spec/services/theme.md#ActiveTheme
    struct ActiveTheme: Equatable {
        let name: String
        let base: DefaultTheme
        let colors: Colors
        let appColors: AppColors
        var wallpaper: AppWallpaper = AppWallpaper(background: nil, tint: nil, type: .empty)

        @MainActor
        func toAppTheme() -> AppTheme {
            AppTheme(name: name, base: base, colors: colors, appColors: appColors, wallpaper: wallpaper)
        }
    }

    // MARK: - Internal helpers

    /// Resolves the system-dark color palette and its default theme.
    private static func systemDarkThemeColors() -> (Colors, DefaultTheme) {
        (DarkColorPalette, DefaultTheme.DARK)
    }

    /// Returns the effective non-system theme name, performing legacy migration inline.
    private static func nonSystemThemeName() -> String {
        // Migrate any legacy names that were not caught at launch
        pxMigrateSingleThemePref(currentThemeDefault)
        pxMigrateSingleThemePref(systemDarkThemeDefault)

        let pxResolved = currentThemeDefault.get()
        return if pxResolved != DefaultTheme.SYSTEM_THEME_NAME {
            pxResolved
        } else {
            systemInDarkThemeCurrently ? systemDarkThemeDefault.get() : DefaultTheme.LIGHT.themeName
        }
    }

    // MARK: - Default active theme

    // Spec: spec/services/theme.md#defaultActiveTheme
    static func defaultActiveTheme(_ appSettingsTheme: [ThemeOverrides]) -> ThemeOverrides? {
        let pxEffectiveName = nonSystemThemeName()
        let pxThemeId = currentThemeIdsDefault.get()[pxEffectiveName]
        return appSettingsTheme.getTheme(pxThemeId)
    }

    static func defaultActiveTheme(_ perUserTheme: ThemeModeOverrides?, _ appSettingsTheme: [ThemeOverrides]) -> ThemeModeOverride {
        let pxModeTheme = !CurrentColors.colors.isLight ? perUserTheme?.dark : perUserTheme?.light
        if let pxModeTheme {
            return pxModeTheme
        }
        let pxDefault = defaultActiveTheme(appSettingsTheme)
        return ThemeModeOverride(mode: CurrentColors.base.mode, colors: pxDefault?.colors ?? ThemeColors(), wallpaper: pxDefault?.wallpaper ?? ThemeWallpaper.from(PresetWallpaper.school.toType(CurrentColors.base), nil, nil))
    }

    // MARK: - Current colors

    // Spec: spec/services/theme.md#currentColors
    static func currentColors(_ themeOverridesForType: WallpaperType?, _ perChatTheme: ThemeModeOverride?, _ perUserTheme: ThemeModeOverrides?, _ appSettingsTheme: [ThemeOverrides]) -> ActiveTheme {
        let pxThemeName = currentThemeDefault.get()
        let pxEffectiveName = nonSystemThemeName()
        let pxDefaultTheme = defaultActiveTheme(appSettingsTheme)

        let pxBaseTheme = pxResolveBaseActiveTheme(pxEffectiveName)

        let pxPerUser = pxBaseTheme.colors.isLight ? perUserTheme?.light : perUserTheme?.dark
        let pxMatchedTheme = appSettingsTheme.sameTheme(themeOverridesForType ?? perChatTheme?.type ?? pxPerUser?.type ?? pxDefaultTheme?.wallpaper?.toAppWallpaper().type, pxEffectiveName) ?? pxDefaultTheme

        if pxMatchedTheme == nil && pxPerUser == nil && perChatTheme == nil && themeOverridesForType == nil {
            return ActiveTheme(name: pxThemeName, base: pxBaseTheme.base, colors: pxBaseTheme.colors, appColors: pxBaseTheme.appColors, wallpaper: pxBaseTheme.wallpaper)
        }
        let pxPresetWallpaperColors: ThemeColors? = pxResolvePresetWallpaperColors(themeOverridesForType, perChatTheme, pxPerUser, pxMatchedTheme, pxBaseTheme.base)

        let pxThemeOrEmpty = pxMatchedTheme ?? ThemeOverrides(base: pxBaseTheme.base)
        let pxColors = pxThemeOrEmpty.toColors(pxThemeOrEmpty.base, perChatTheme?.colors, pxPerUser?.colors, pxPresetWallpaperColors)
        return ActiveTheme(
            name: pxThemeName,
            base: pxBaseTheme.base,
            colors: pxColors,
            appColors: pxThemeOrEmpty.toAppColors(pxThemeOrEmpty.base, perChatTheme?.colors, perChatTheme?.type, pxPerUser?.colors, pxPerUser?.type, pxPresetWallpaperColors),
            wallpaper: pxThemeOrEmpty.toAppWallpaper(themeOverridesForType, perChatTheme, pxPerUser, pxColors.background)
        )
    }

    // MARK: - Export

    // Spec: spec/services/theme.md#currentThemeOverridesForExport
    static func currentThemeOverridesForExport(_ themeOverridesForType: WallpaperType?, _ perChatTheme: ThemeModeOverride?, _ perUserTheme: ThemeModeOverrides?) -> ThemeOverrides {
        let pxCurrent = currentColors(themeOverridesForType, perChatTheme, perUserTheme, themeOverridesDefault.get())
        let pxWType = pxCurrent.wallpaper.type
        let pxWBg = pxCurrent.wallpaper.background
        let pxWTint = pxCurrent.wallpaper.tint
        let pxExportWallpaper: ThemeWallpaper? = if case WallpaperType.empty = pxWType {
            nil
        } else {
            ThemeWallpaper.from(pxWType, pxWBg?.toReadableHex(), pxWTint?.toReadableHex()).withFilledWallpaperBase64()
        }
        return ThemeOverrides(
            themeId: "",
            base: pxCurrent.base,
            colors: ThemeColors.from(pxCurrent.colors, pxCurrent.appColors),
            wallpaper: pxExportWallpaper
        )
    }

    // MARK: - Apply

    // Spec: spec/services/theme.md#applyTheme
    @MainActor
    static func applyTheme(_ theme: String) {
        currentThemeDefault.set(theme)
        CurrentColors = currentColors(nil, nil, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
        applyOLEDOverride()
        AppTheme.shared.updateFromCurrentColors()
        let pxAccent = UIColor(CurrentColors.colors.primary)
        if SceneDelegate.windowStatic?.tintColor != pxAccent {
            SceneDelegate.windowStatic?.tintColor = pxAccent
        }
//        applyNavigationBarColors(CurrentColors.toAppTheme())
    }

    // MARK: - Window style

    // Spec: spec/services/theme.md#adjustWindowStyle
    @MainActor
    static func adjustWindowStyle() {
        let pxStyle = pxResolveInterfaceStyle()
        if SceneDelegate.windowStatic?.overrideUserInterfaceStyle != pxStyle {
            SceneDelegate.windowStatic?.overrideUserInterfaceStyle = pxStyle
        }
    }

    @MainActor
    static func changeDarkTheme(_ theme: String) {
        systemDarkThemeDefault.set(theme)
        CurrentColors = currentColors(nil, nil, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
        applyOLEDOverride()
        AppTheme.shared.updateFromCurrentColors()
    }

    // MARK: - Save & apply color

    // Spec: spec/services/theme.md#saveAndApplyThemeColor
    @MainActor
    static func saveAndApplyThemeColor(_ baseTheme: DefaultTheme, _ name: ThemeColor, _ color: Color? = nil, _ pref: CodableDefault<[ThemeOverrides]>? = nil) {
        let pxBaseName = baseTheme.themeName
        let pxPref = pref ?? themeOverridesDefault
        let pxOverrides = pxPref.get()
        let pxThemeId = currentThemeIdsDefault.get()[pxBaseName]
        let pxPrev = pxOverrides.getTheme(pxThemeId) ?? ThemeOverrides(base: baseTheme)
        pxPref.set(pxOverrides.replace(pxPrev.withUpdatedColor(name, color?.toReadableHex())))
        var pxIds = currentThemeIdsDefault.get()
        pxIds[pxBaseName] = pxPrev.themeId
        currentThemeIdsDefault.set(pxIds)
        applyTheme(currentThemeDefault.get())
    }

    static func applyThemeColor(name: ThemeColor, color: Color? = nil, pref: Binding<ThemeModeOverride>) {
        pref.wrappedValue = pref.wrappedValue.withUpdatedColor(name, color?.toReadableHex())
    }

    // MARK: - Save & apply wallpaper

    // Spec: spec/services/theme.md#saveAndApplyWallpaper
    @MainActor
    static func saveAndApplyWallpaper(_ baseTheme: DefaultTheme, _ type: WallpaperType?, _ pref: CodableDefault<[ThemeOverrides]>?) {
        let pxBaseName = baseTheme.themeName
        let pxPref = pref ?? themeOverridesDefault
        let pxOverrides = pxPref.get()
        let pxTheme = pxOverrides.sameTheme(type, baseTheme.themeName)
        var pxPrev = pxTheme ?? ThemeOverrides(base: baseTheme)
        pxPrev.wallpaper = pxResolveWallpaperForSave(type, pxPrev.wallpaper)
        pxPref.set(pxOverrides.replace(pxPrev))
        var pxIds = currentThemeIdsDefault.get()
        pxIds[pxBaseName] = pxPrev.themeId
        currentThemeIdsDefault.set(pxIds)
        applyTheme(currentThemeDefault.get())
    }

    static func copyFromSameThemeOverrides(_ type: WallpaperType?, _ lowerLevelOverride: ThemeModeOverride?, _ pref: Binding<ThemeModeOverride>) -> Bool {
        let pxOverrides = themeOverridesDefault.get()
        let pxSameWp: ThemeWallpaper? = if let pxWp = lowerLevelOverride?.wallpaper, lowerLevelOverride?.type?.sameType(type) == true {
            pxWp
        } else {
            pxOverrides.sameTheme(type, CurrentColors.base.themeName)?.wallpaper
        }
        guard let pxSameWp else {
            if let type {
                var pxW: ThemeWallpaper = ThemeWallpaper.from(type, nil, nil)
                pxW.scale = nil
                pxW.scaleType = nil
                pxW.background = nil
                pxW.tint = nil
                pref.wrappedValue = ThemeModeOverride(mode: CurrentColors.base.mode, wallpaper: pxW)
            } else {
                // Empty wallpaper overrides any top-level ones
                pref.wrappedValue = ThemeModeOverride(mode: CurrentColors.base.mode, wallpaper: ThemeWallpaper())
            }
            return true
        }
        var pxType = pxSameWp.toAppWallpaper().type
        if case let WallpaperType.image(pxFile, pxScale, pxScaleType) = pxType, pxSameWp.imageFile == pxFile {
            // Same image file: copy it first so removal does not affect the main override
            if let pxCopiedFile = saveWallpaperFile(url: getWallpaperFilePath(pxFile)) {
                pxType = WallpaperType.image(pxCopiedFile, pxScale, pxScaleType)
            } else {
                logger.error("Error while copying wallpaper from global overrides to chat overrides")
                return false
            }
        }
        var pxPrev = pref.wrappedValue
        var pxW = ThemeWallpaper.from(pxType, nil, nil)
        pxW.scale = nil
        pxW.scaleType = nil
        pxW.background = nil
        pxW.tint = nil
        pxPrev.colors = ThemeColors()
        pxPrev.wallpaper = pxW
        pref.wrappedValue = pxPrev
        return true
    }

    static func applyWallpaper(_ type: WallpaperType?, _ pref: Binding<ThemeModeOverride>) {
        var pxPrev = pref.wrappedValue
        pxPrev.wallpaper = if let type {
            ThemeWallpaper.from(type, pxPrev.wallpaper?.background, pxPrev.wallpaper?.tint)
        } else {
            nil
        }
        pref.wrappedValue = pxPrev
    }

    // MARK: - Save & apply overrides

    // Spec: spec/services/theme.md#saveAndApplyThemeOverrides
    @MainActor
    static func saveAndApplyThemeOverrides(_ theme: ThemeOverrides, _ pref: CodableDefault<[ThemeOverrides]>? = nil) {
        let pxImportedWp = theme.wallpaper?.importFromString()
        let pxBaseName = theme.base.themeName
        let pxPref: CodableDefault<[ThemeOverrides]> = pref ?? themeOverridesDefault
        let pxOverrides = pxPref.get()
        var pxPrev = pxOverrides.getTheme(nil, pxImportedWp?.toAppWallpaper().type, theme.base) ?? ThemeOverrides(base: theme.base)
        if let pxImageFile = pxPrev.wallpaper?.imageFile {
            try? FileManager.default.removeItem(at: getWallpaperFilePath(pxImageFile))
        }
        pxPrev.base = theme.base
        pxPrev.colors = theme.colors
        pxPrev.wallpaper = pxImportedWp
        pxPref.set(pxOverrides.replace(pxPrev))
        currentThemeDefault.set(pxBaseName)
        var pxCurrentIds = currentThemeIdsDefault.get()
        pxCurrentIds[pxBaseName] = pxPrev.themeId
        currentThemeIdsDefault.set(pxCurrentIds)
        applyTheme(pxBaseName)
    }

    // MARK: - Reset

    // Spec: spec/services/theme.md#resetAllThemeColors
    @MainActor
    static func resetAllThemeColors(_ pref: CodableDefault<[ThemeOverrides]>? = nil) {
        let pxResolvedName = nonSystemThemeName()
        let pxPref: CodableDefault<[ThemeOverrides]> = pref ?? themeOverridesDefault
        let pxOverrides = pxPref.get()
        guard let pxThemeId = currentThemeIdsDefault.get()[pxResolvedName],
              var pxPrev = pxOverrides.getTheme(pxThemeId)
        else { return }
        pxPrev.colors = ThemeColors()
        pxPrev.wallpaper?.background = nil
        pxPrev.wallpaper?.tint = nil
        pxPref.set(pxOverrides.replace(pxPrev))
        applyTheme(currentThemeDefault.get())
    }

    static func resetAllThemeColors(_ pref: Binding<ThemeModeOverride>) {
        var pxPrev = pref.wrappedValue
        pxPrev.colors = ThemeColors()
        pxPrev.wallpaper?.background = nil
        pxPrev.wallpaper?.tint = nil
        pref.wrappedValue = pxPrev
    }

    // MARK: - Remove

    // Spec: spec/services/theme.md#removeTheme
    static func removeTheme(_ themeId: String?) {
        var pxThemes = themeOverridesDefault.get().map { $0 }
        pxThemes.removeAll(where: { $0.themeId == themeId })
        themeOverridesDefault.set(pxThemes)
    }
}

// MARK: - Private helpers

extension ThemeManager {
    /// Migrates a single StringDefault preference from legacy names to DARK.
    private static func pxMigrateSingleThemePref(_ pref: StringDefault) {
        let pxStored = pref.get()
        if removedThemeNames.contains(pxStored) {
            pref.set(DefaultTheme.DARK.themeName)
        }
    }

    /// Removes stored overrides whose base theme has been removed.
    private static func pxPurgeRemovedThemeOverrides() {
        var pxOverrides = themeOverridesDefault.get()
        let pxCountBefore = pxOverrides.count
        pxOverrides.removeAll { removedThemeNames.contains($0.base.themeName) }
        if pxOverrides.count != pxCountBefore {
            themeOverridesDefault.set(pxOverrides)
        }
    }

    /// Resolves the base ActiveTheme for a given effective theme name.
    private static func pxResolveBaseActiveTheme(_ pxEffectiveName: String) -> ActiveTheme {
        switch pxEffectiveName {
        case DefaultTheme.LIGHT.themeName:
            return ActiveTheme(name: DefaultTheme.LIGHT.themeName, base: DefaultTheme.LIGHT, colors: LightColorPalette.clone(), appColors: LightColorPaletteApp.clone(), wallpaper: AppWallpaper(background: nil, tint: nil, type: PresetWallpaper.school.toType(DefaultTheme.LIGHT)))
        default:
            return ActiveTheme(name: DefaultTheme.DARK.themeName, base: DefaultTheme.DARK, colors: DarkColorPalette.clone(), appColors: DarkColorPaletteApp.clone(), wallpaper: AppWallpaper(background: nil, tint: nil, type: PresetWallpaper.school.toType(DefaultTheme.DARK)))
        }
    }

    /// Resolves preset wallpaper colors from the override chain.
    private static func pxResolvePresetWallpaperColors(
        _ pxType: WallpaperType?,
        _ pxPerChat: ThemeModeOverride?,
        _ pxPerUser: ThemeModeOverride?,
        _ pxMatched: ThemeOverrides?,
        _ pxBase: DefaultTheme
    ) -> ThemeColors? {
        if let pxType, case let WallpaperType.preset(pxFilename, _) = pxType {
            return PresetWallpaper.from(pxFilename)?.colors[pxBase]
        } else if let pxChatWp = pxPerChat?.wallpaper, let pxPreset = pxChatWp.preset {
            return PresetWallpaper.from(pxPreset)?.colors[pxBase]
        } else if let pxUserWp = pxPerUser?.wallpaper, let pxPreset = pxUserWp.preset {
            return PresetWallpaper.from(pxPreset)?.colors[pxBase]
        } else if let pxMatchedWp = pxMatched?.wallpaper, let pxPreset = pxMatchedWp.preset {
            return PresetWallpaper.from(pxPreset)?.colors[pxBase]
        }
        return nil
    }

    /// Resolves the UIUserInterfaceStyle from the current theme preference.
    @MainActor
    private static func pxResolveInterfaceStyle() -> UIUserInterfaceStyle {
        switch currentThemeDefault.get() {
        case DefaultTheme.LIGHT.themeName: return UIUserInterfaceStyle.light
        case DefaultTheme.SYSTEM_THEME_NAME: return UIUserInterfaceStyle.unspecified
        default: return UIUserInterfaceStyle.dark
        }
    }

    /// Resolves the wallpaper value for save-and-apply.
    private static func pxResolveWallpaperForSave(_ pxType: WallpaperType?, _ pxCurrent: ThemeWallpaper?) -> ThemeWallpaper? {
        if let pxType {
            if case WallpaperType.empty = pxType {
                return nil as ThemeWallpaper?
            } else {
                return ThemeWallpaper.from(pxType, pxCurrent?.background, pxCurrent?.tint)
            }
        }
        return nil
    }
}

// MARK: - POPOPX

/// Namespace for POPOPX-specific theme manager constants.
extension ThemeManager {
    static let _pxBrand = "PX_THEME_MANAGER"
    static let pxRemovedThemeNames: Set<String> = ["POPOPX", "BLACK", "QUANTUM", "STEALTH", "EMBER"]
    static let pxDefaultHeapSizeMB: Int = 64
    /// Maximum number of theme overrides per base theme
    static let pxMaxOverridesPerBase: Int = 50
    /// Opacity threshold for wallpaper tint visibility
    static let pxWallpaperTintThreshold: Double = 0.15
}
