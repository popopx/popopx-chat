//
//  ThemeModeEditor.swift
//  POPOPX (iOS)
//
//  Created by Avently on 20.06.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxThemeTransitionEnabled = UserDefaults.standard.bool(forKey: "PX_THEME_TRANSITION_ENABLED")

struct PXWallpaperEditor: View {
    @EnvironmentObject var theme: AppTheme
    var initialTheme: ThemeModeOverride
    @State var themeModeOverride: ThemeModeOverride
    @State var applyToMode: DefaultThemeMode?
    @State var showMore: Bool = false
    @State var showFileImporter: Bool = false
    @Binding var globalThemeUsed: Bool
    var save: (DefaultThemeMode?, ThemeModeOverride?) async -> Void

    @State private var showImageImporter: Bool = false

    var body: some View {
        List {
            let wallpaperType = theme.wallpaper.type

            WallpaperPresetSelector(
                selectedWallpaper: wallpaperType,
                currentColors: { type in
                    // If applying for :
                    // - all themes: no overrides needed
                    // - specific user: only user overrides for currently selected theme are needed, because they will NOT be copied when other wallpaper is selected
                    let perUserOverride: ThemeModeOverrides? = wallpaperType.sameType(type) ? ChatModel.shared.currentUser?.uiThemes : nil
                    return ThemeManager.currentColors(type, nil, perUserOverride, themeOverridesDefault.get())
                },
                onChooseType: onChooseType
            )
            .padding(.bottom, PXThemeEditorConfig.wallpaperBottomPadding)
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .modifier(WallpaperImporter(showImageImporter: $showImageImporter, onChooseImage: { image in
                if let filename = saveWallpaperFile(image: image) {
                    _ = onTypeCopyFromSameTheme(WallpaperType.image(filename, PXThemeEditorConfig.wallpaperImageScale, PXThemeEditorConfig.wallpaperFillMode))
                }
            }))

            WallpaperSetupView(
                wallpaperType: themeModeOverride.type,
                base: theme.base,
                initialWallpaper: theme.wallpaper,
                editColor: { name in editColor(name, theme) },
                onTypeChange: onTypeChange
            )

            Section {
                if !globalThemeUsed {
                    PXResetToGlobalThemeButton(app: true, primaryColor: theme.colors.primary) {
                        themeModeOverride = ThemeManager.defaultActiveTheme(ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                        globalThemeUsed = true
                        Task {
                            await save(applyToMode, nil)
                            await MainActor.run {
                                // Change accent color globally
                                ThemeManager.applyTheme(currentThemeDefault.get())
                            }
                        }
                    }
                }

                PXSetDefaultThemeButton(primaryColor: theme.colors.primary) {
                    globalThemeUsed = false
                    let lightBase = DefaultTheme.LIGHT
                    let darkBase = DefaultTheme.DARK
                    let mode = themeModeOverride.mode
                    Task {
                        // Saving for both modes in one place by changing mode once per save
                        if applyToMode == nil {
                            let oppositeMode = mode == DefaultThemeMode.light ? DefaultThemeMode.dark : DefaultThemeMode.light
                            await save(oppositeMode, ThemeModeOverride.withFilledAppDefaults(oppositeMode, oppositeMode == DefaultThemeMode.light ? lightBase : darkBase))
                        }
                        await MainActor.run {
                            themeModeOverride = ThemeModeOverride.withFilledAppDefaults(mode, mode == DefaultThemeMode.light ? lightBase : darkBase)
                        }
                        await save(themeModeOverride.mode, themeModeOverride)
                        await MainActor.run {
                            // Change accent color globally
                            ThemeManager.applyTheme(currentThemeDefault.get())
                        }
                    }
                }.onChange(of: initialTheme.mode) {_,  mode in
                    themeModeOverride = initialTheme
                    if applyToMode != nil {
                        applyToMode = mode
                    }
                }
                .onChange(of: theme) {_, _ in
                    // Applies updated global theme if current one tracks global theme
                    if globalThemeUsed {
                        themeModeOverride = ThemeManager.defaultActiveTheme(ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                        globalThemeUsed = true
                    }
                }
            }

            if showMore {
                let values: [(DefaultThemeMode?, LocalizedStringKey)] = [
                        (nil, LocalizedStringKey(NSLocalizedString("theme_all_modes", comment: "Theme mode option"))),
                        (DefaultThemeMode.light, LocalizedStringKey(NSLocalizedString("theme_light_mode", comment: "Theme mode option"))),
                        (DefaultThemeMode.dark, LocalizedStringKey(NSLocalizedString("theme_dark_mode", comment: "Theme mode option")))
                ]
                Picker(NSLocalizedString("theme_apply_to_label", comment: "Theme apply to picker label"), selection: $applyToMode) {
                    ForEach(values, id: \.0) { (_, text) in
                        Text(text)
                    }
                }
                .frame(height: PXThemeEditorConfig.modePickerHeight)
                .onChange(of: applyToMode) {_,  mode in
                    if let mode, mode != theme.base.mode {
                        let lightBase = DefaultTheme.LIGHT
                        let darkBase = DefaultTheme.DARK
                        ThemeManager.applyTheme(mode == DefaultThemeMode.light ? lightBase.themeName : darkBase.themeName)
                    }
                }

                CustomizeThemeColorsSection(editColor: { name in editColor(name, theme) })

                ImportExportThemeSection(showFileImporter: $showFileImporter, perChat: nil, perUser: ChatModel.shared.currentUser?.uiThemes)
            } else {
                PXAdvancedSettingsButton(primaryColor: theme.colors.primary) { showMore = true }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(
            ThemeImporter(isPresented: $showFileImporter) { imported in
                let importedFromString = imported.wallpaper?.importFromString()
                let importedType = importedFromString?.toAppWallpaper().type
                let currentTheme = ThemeManager.currentColors(nil, nil, nil, themeOverridesDefault.get())
                let type: WallpaperType? = if importedType?.sameType(currentTheme.wallpaper.type) == true { nil } else { importedType }
                let colors = ThemeManager.currentThemeOverridesForExport(type, nil, nil).colors
                let res = ThemeModeOverride(mode: imported.base.mode, colors: imported.colors, wallpaper: importedFromString).removeSameColors(imported.base, colorsToCompare: colors)
                Task {
                    await MainActor.run {
                        themeModeOverride = res
                    }
                    await save(applyToMode, res)
                }
            }
        )
        .popopxBranded()
    }

    private func onTypeCopyFromSameTheme(_ type: WallpaperType?) -> Bool {
        _ = ThemeManager.copyFromSameThemeOverrides(type, nil, $themeModeOverride)
        Task {
            await save(applyToMode, themeModeOverride)
        }
        globalThemeUsed = false
        return true
    }

    private func preApplyGlobalIfNeeded(_ type: WallpaperType?) {
        if globalThemeUsed {
            _ = onTypeCopyFromSameTheme(type)
        }
    }

    private func onTypeChange(_ type: WallpaperType?) {
        logger.debug("PX: [PXWallpaperEditor.onTypeChange] type=\(String(describing: type))")
        if globalThemeUsed {
            preApplyGlobalIfNeeded(type)
            // Saves copied static image instead of original from global theme
            ThemeManager.applyWallpaper(themeModeOverride.type, $themeModeOverride)
        } else {
            ThemeManager.applyWallpaper(type, $themeModeOverride)
        }
        Task {
            await save(applyToMode, themeModeOverride)
        }
    }

    private func currentColors(_ type: WallpaperType?) -> ThemeManager.ActiveTheme {
        // If applying for :
        // - all themes: no overrides needed
        // - specific user: only user overrides for currently selected theme are needed, because they will NOT be copied when other wallpaper is selected
        let perUserOverride: ThemeModeOverrides? = theme.wallpaper.type.sameType(type) ? ChatModel.shared.currentUser?.uiThemes : nil
        return ThemeManager.currentColors(type, nil, perUserOverride, themeOverridesDefault.get())
    }

    private func onChooseType(_ type: WallpaperType?) {
        if let type, case WallpaperType.image = type {
            if theme.wallpaper.type.isImage || currentColors(type).wallpaper.type.image == nil {
                showImageImporter = true
            } else {
                _ = onTypeCopyFromSameTheme(currentColors(type).wallpaper.type)
            }
        } else if themeModeOverride.type != type || theme.wallpaper.type != type {
            _ = onTypeCopyFromSameTheme(type)
        } else {
            onTypeChange(type)
        }
    }

    private func editColor(_ name: ThemeColor, _ currentTheme: AppTheme) -> Binding<Color> {
        let pref = SendableBindingWrapper($themeModeOverride)
        return editColorBinding(
            name: name,
            wallpaperType: theme.wallpaper.type,
            wallpaperImage: theme.wallpaper.type.image,
            theme: currentTheme,
            onColorChange: { color in
                Task { @MainActor in
                    preApplyGlobalIfNeeded(pref.wrappedValue.type)
                    ThemeManager.applyThemeColor(name: name, color: color, pref: pref.binding)
                    await save(applyToMode, pref.wrappedValue)
                }
            })
    }
}

struct PXChatWallpaperEditor: View {
    @EnvironmentObject var theme: AppTheme
    @State private var currentTheme: ThemeManager.ActiveTheme
    var initialTheme: ThemeModeOverride
    @State var themeModeOverride: ThemeModeOverride
    @State var applyToMode: DefaultThemeMode?
    @State var showMore: Bool = false
    @State var showFileImporter: Bool = false
    @Binding var globalThemeUsed: Bool
    var save: (DefaultThemeMode?, ThemeModeOverride?) async -> Void

    @State private var showImageImporter: Bool = false

    init(initialTheme: ThemeModeOverride, themeModeOverride: ThemeModeOverride, applyToMode: DefaultThemeMode? = nil, globalThemeUsed: Binding<Bool>, save: @escaping (DefaultThemeMode?, ThemeModeOverride?) async -> Void) {
        let cur = ThemeManager.currentColors(nil, globalThemeUsed.wrappedValue ? nil : themeModeOverride, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
        self.currentTheme = cur
        self.initialTheme = initialTheme
        self.themeModeOverride = themeModeOverride
        self.applyToMode = applyToMode
        self._globalThemeUsed = globalThemeUsed
        self.save = save
    }

    var body: some View {
        List {
            WallpaperPresetSelector(
                selectedWallpaper: currentTheme.wallpaper.type,
                activeBackgroundColor: currentTheme.wallpaper.background,
                activeTintColor: currentTheme.wallpaper.tint,
                currentColors: currentColors,
                onChooseType: onChooseType
            )
            .padding(.bottom, PXThemeEditorConfig.wallpaperBottomPadding)
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .modifier(WallpaperImporter(showImageImporter: $showImageImporter, onChooseImage: { image in
                if let filename = saveWallpaperFile(image: image) {
                    _ = onTypeCopyFromSameTheme(WallpaperType.image(filename, PXThemeEditorConfig.wallpaperImageScale, PXThemeEditorConfig.wallpaperFillMode))
                }
            }))

            WallpaperSetupView(
                wallpaperType: themeModeOverride.type,
                base: currentTheme.base,
                initialWallpaper: currentTheme.wallpaper,
                editColor: editColor,
                onTypeChange: onTypeChange
            )

            Section {
                if !globalThemeUsed {
                    PXResetToGlobalThemeButton(app: ChatModel.shared.currentUser?.uiThemes?.preferredMode(isInDarkTheme()) == nil, primaryColor: theme.colors.primary) {
                        themeModeOverride = ThemeManager.defaultActiveTheme(ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                        globalThemeUsed = true
                        Task {
                            await save(applyToMode, nil)
                        }
                    }
                }

                PXSetDefaultThemeButton(primaryColor: theme.colors.primary) {
                    globalThemeUsed = false
                    let lightBase = DefaultTheme.LIGHT
                    let darkBase = DefaultTheme.DARK
                    let mode = themeModeOverride.mode
                    Task {
                        // Saving for both modes in one place by changing mode once per save
                        if applyToMode == nil {
                            let oppositeMode = mode == DefaultThemeMode.light ? DefaultThemeMode.dark : DefaultThemeMode.light
                            await save(oppositeMode, ThemeModeOverride.withFilledAppDefaults(oppositeMode, oppositeMode == DefaultThemeMode.light ? lightBase : darkBase))
                        }
                        await MainActor.run {
                            themeModeOverride = ThemeModeOverride.withFilledAppDefaults(mode, mode == DefaultThemeMode.light ? lightBase : darkBase)
                        }
                        await save(themeModeOverride.mode, themeModeOverride)
                    }
                }
                .onChange(of: initialTheme) {_,  initial in
                    if initial.mode != themeModeOverride.mode {
                        themeModeOverride = initial
                        currentTheme = ThemeManager.currentColors(nil, globalThemeUsed ? nil : themeModeOverride, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                        if applyToMode != nil {
                            applyToMode = initial.mode
                        }
                    }
                }
                .onChange(of: currentTheme) {_, _ in
                    // Applies updated global theme if current one tracks global theme
                    if globalThemeUsed {
                        themeModeOverride = ThemeManager.defaultActiveTheme(ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                        globalThemeUsed = true
                    }
                }
                .onChange(of: themeModeOverride) {_,  override in
                    currentTheme = ThemeManager.currentColors(nil, globalThemeUsed ? nil : override, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                }
            }

            if showMore {
                let values: [(DefaultThemeMode?, LocalizedStringKey)] = [
                    (nil, LocalizedStringKey(NSLocalizedString("theme_all_modes", comment: "Theme editor apply to all modes"))),
                    (DefaultThemeMode.light, LocalizedStringKey(NSLocalizedString("theme_light_mode", comment: "Theme editor light mode"))),
                    (DefaultThemeMode.dark, LocalizedStringKey(NSLocalizedString("theme_dark_mode", comment: "Theme editor dark mode")))
                ]
                Picker(NSLocalizedString("theme_apply_to", comment: "Theme editor apply to picker label"), selection: $applyToMode) {
                    ForEach(values, id: \.0) { (_, text) in
                        Text(text)
                    }
                }
                .frame(height: PXThemeEditorConfig.modePickerHeight)
                .onChange(of: applyToMode) {_,  mode in
                    if let mode, mode != currentTheme.base.mode {
                        let lightBase = DefaultTheme.LIGHT
                        let darkBase = DefaultTheme.DARK
                        ThemeManager.applyTheme(mode == DefaultThemeMode.light ? lightBase.themeName : darkBase.themeName)
                    }
                }

                CustomizeThemeColorsSection(editColor: editColor)

                ImportExportThemeSection(showFileImporter: $showFileImporter, perChat: themeModeOverride, perUser: ChatModel.shared.currentUser?.uiThemes)
            } else {
                PXAdvancedSettingsButton(primaryColor: theme.colors.primary) { showMore = true }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(
            ThemeImporter(isPresented: $showFileImporter) { imported in
                let importedFromString = imported.wallpaper?.importFromString()
                let importedType = importedFromString?.toAppWallpaper().type
                let currentTheme = ThemeManager.currentColors(nil, nil, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                let type: WallpaperType? = if importedType?.sameType(currentTheme.wallpaper.type) == true { nil } else { importedType }
                let colors = ThemeManager.currentThemeOverridesForExport(type, nil, ChatModel.shared.currentUser?.uiThemes).colors
                let res = ThemeModeOverride(mode: imported.base.mode, colors: imported.colors, wallpaper: importedFromString).removeSameColors(imported.base, colorsToCompare: colors)
                Task {
                    await MainActor.run {
                        themeModeOverride = res
                    }
                    await save(applyToMode, res)
                }
            }
        )
        .popopxBranded()
    }

    private func onTypeCopyFromSameTheme(_ type: WallpaperType?) -> Bool {
        let success = ThemeManager.copyFromSameThemeOverrides(type, ChatModel.shared.currentUser?.uiThemes?.preferredMode(!currentTheme.colors.isLight), $themeModeOverride)
        if success {
            Task {
                await save(applyToMode, themeModeOverride)
            }
            globalThemeUsed = false
        }
        return success
    }

    private func preApplyGlobalIfNeeded(_ type: WallpaperType?) {
        if globalThemeUsed {
            _ = onTypeCopyFromSameTheme(type)
        }
    }

    private func onTypeChange(_ type: WallpaperType?) {
        logger.debug("PX: [PXChatWallpaperEditor.onTypeChange] type=\(String(describing: type))")
        if globalThemeUsed {
            preApplyGlobalIfNeeded(type)
            // Saves copied static image instead of original from global theme
            ThemeManager.applyWallpaper(themeModeOverride.type, $themeModeOverride)
        } else {
            ThemeManager.applyWallpaper(type, $themeModeOverride)
        }
        Task {
            await save(applyToMode, themeModeOverride)
        }
        logger.debug("PX: [PXChatWallpaperEditor.onTypeChange] saved, globalUsed=\(globalThemeUsed)")
    }

    private func currentColors(_ type: WallpaperType?) -> ThemeManager.ActiveTheme {
        let perChatOverride: ThemeModeOverride? = type?.sameType(themeModeOverride.type) == true ? themeModeOverride : nil
        return ThemeManager.currentColors(type, perChatOverride, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
    }

    private func onChooseType(_ type: WallpaperType?) {
        logger.debug("PX: [PXChatWallpaperEditor.onChooseType] type=\(String(describing: type))")
        if let type, case WallpaperType.image = type {
            let pxIsImageOverride = themeModeOverride.type?.isImage == true && !globalThemeUsed
            if pxIsImageOverride || currentColors(type).wallpaper.type.image == nil {
                showImageImporter = true
            } else if !onTypeCopyFromSameTheme(currentColors(type).wallpaper.type) {
                showImageImporter = true
            }
        } else if globalThemeUsed || themeModeOverride.type != type || themeModeOverride.type != type {
            _ = onTypeCopyFromSameTheme(type)
        } else {
            onTypeChange(type)
        }
    }

    private func editColor(_ name: ThemeColor) -> Binding<Color> {
        let pref = SendableBindingWrapper($themeModeOverride)
        return editColorBinding(
            name: name,
            wallpaperType: themeModeOverride.type,
            wallpaperImage: themeModeOverride.type?.image,
            theme: currentTheme.toAppTheme(),
            onColorChange: { color in
                Task { @MainActor in
                    preApplyGlobalIfNeeded(pref.wrappedValue.type)
                    ThemeManager.applyThemeColor(name: name, color: color, pref: pref.binding)
                    currentTheme = ThemeManager.currentColors(nil, globalThemeUsed ? nil : pref.wrappedValue, ChatModel.shared.currentUser?.uiThemes, themeOverridesDefault.get())
                    await save(applyToMode, pref.wrappedValue)
                }
            })
    }
}

private struct PXResetToGlobalThemeButton: View {
    let app: Bool
    let primaryColor: Color
    let onClick: () -> Void

    var body: some View {
        Button {
            onClick()
        } label: {
            Text(app ? NSLocalizedString("theme_reset_to_app", comment: "Reset to app theme") : NSLocalizedString("theme_reset_to_user", comment: "Reset to user theme"))
                .foregroundColor(primaryColor)
                .opacity(isInDarkTheme() ? PXThemeEditorConfig.darkThemeButtonOpacity : PXThemeEditorConfig.lightThemeButtonOpacity)
        }
        .accessibilityLabel(Text(app ? NSLocalizedString("theme_reset_to_app", comment: "Reset to app theme") : NSLocalizedString("theme_reset_to_user", comment: "Reset to user theme")))
    }
}

private struct PXSetDefaultThemeButton: View {
    let primaryColor: Color
    let onClick: () -> Void

    var body: some View {
        Button {
            onClick()
        } label: {
            Text(NSLocalizedString("Set default theme", comment: "button to set the default theme"))
                .foregroundColor(primaryColor)
                .opacity(isInDarkTheme() ? PXThemeEditorConfig.darkThemeButtonOpacity : PXThemeEditorConfig.lightThemeButtonOpacity)
        }
        .accessibilityLabel(Text(NSLocalizedString("Set default theme", comment: "button to set the default theme")))
    }
}

private struct PXAdvancedSettingsButton: View {
    let primaryColor: Color
    let onClick: () -> Void

    var body: some View {
        Button {
            onClick()
        } label: {
            HStack {
                Image(systemName: "chevron.down")
                    .accessibilityHidden(true)
                Text(NSLocalizedString("Advanced settings", comment: "button to show advanced settings"))
            }
            .foregroundColor(primaryColor)
            .opacity(isInDarkTheme() ? PXThemeEditorConfig.darkThemeButtonOpacity : PXThemeEditorConfig.lightThemeButtonOpacity)
        }
        .accessibilityLabel(Text(NSLocalizedString("Advanced settings", comment: "button to show advanced settings")))
    }
}

// MARK: - POPOPX Configuration

private enum PXThemeEditorConfig {
    static let componentTag: String = "PX_THEME_MODE_EDITOR"
    /// Bottom padding after wallpaper preset selector
    static let wallpaperBottomPadding: CGFloat = 12
    /// Frame height for theme mode picker
    static let modePickerHeight: CGFloat = 38
    /// Sheet detent fraction for theme editor
    static let sheetDetentFraction: CGFloat = 0.4
    /// Spacing between advanced settings items
    static let advancedSectionSpacing: CGFloat = 6
    /// Duration for theme transition animation
    static let transitionDuration: Double = 0.35
    /// Corner radius for wallpaper picker
    static let wallpaperPickerCornerRadius: CGFloat = 12
    /// Wallpaper image scale factor
    static let wallpaperImageScale: Float = 1
    /// Wallpaper fill mode
    static let wallpaperFillMode: WallpaperScaleType = .fill
    /// Opacity for dark theme accent in button labels
    static let darkThemeButtonOpacity: Double = 0.9
    /// Opacity for light theme accent in button labels
    static let lightThemeButtonOpacity: Double = 1.0
}

// MARK: - POPOPX ViewModel

private struct PXThemeEditorViewModel {
    let isDark: Bool

    var buttonOpacity: Double {
        isDark ? PXThemeEditorConfig.darkThemeButtonOpacity : PXThemeEditorConfig.lightThemeButtonOpacity
    }
}
