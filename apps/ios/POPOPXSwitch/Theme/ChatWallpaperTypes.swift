//
//  ChatWallpaper.swift
//  POPOPX (iOS)
//
//  Created by Avently on 06.06.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI

// Spec: spec/services/theme.md#PresetWallpaper
public enum PresetWallpaper: CaseIterable {
    case cats
    case flowers
    case hearts
    case kids
    case school
    case travel

    var res: UIImage {
        UIImage(named: "wallpaper_\(filename)") ?? UIImage()
    }

    public var filename: String {
        switch self {
        case .cats: "cats"
        case .flowers: "flowers"
        case .hearts: "hearts"
        case .kids: "kids"
        case .school: "school"
        case .travel: "travel"
        }
    }

    public var scale: Float {
        switch self {
        case .cats: 0.63
        case .flowers: 0.53
        case .hearts: 0.59
        case .kids: 0.53
        case .school: 0.53
        case .travel: 0.68
        }
    }

    public var background: [DefaultTheme: Color] {
        switch self {
        case .cats: wallpaperBackgrounds(light: "#ffF8F6EA")
        case .flowers: wallpaperBackgrounds(light: "#ffE2FFE4")
        case .hearts: wallpaperBackgrounds(light: "#ffFDECEC")
        case .kids: wallpaperBackgrounds(light: "#ffdbfdfb")
        case .school: wallpaperBackgrounds(light: "#ffE7F5FF")
        case .travel: wallpaperBackgrounds(light: "#fff9eeff")
        }
    }

    public var tint: [DefaultTheme: Color] {
        switch self {
        case .cats: [
            DefaultTheme.LIGHT: "#ffefdca6".colorFromReadableHex(),
            DefaultTheme.DARK: "#ff4b3b0e".colorFromReadableHex()
        ]
        case .flowers: [
            DefaultTheme.LIGHT: "#ff9CEA59".colorFromReadableHex(),
            DefaultTheme.DARK: "#ff31560D".colorFromReadableHex()
        ]
        case .hearts: [
            DefaultTheme.LIGHT: "#fffde0e0".colorFromReadableHex(),
            DefaultTheme.DARK: "#ff3c0f0f".colorFromReadableHex()
        ]
        case .kids: [
            DefaultTheme.LIGHT: "#ffadeffc".colorFromReadableHex(),
            DefaultTheme.DARK: "#ff16404B".colorFromReadableHex()
        ]
        case .school: [
            DefaultTheme.LIGHT: "#ffCEEBFF".colorFromReadableHex(),
            DefaultTheme.DARK: "#ff0F293B".colorFromReadableHex()
        ]
        case .travel: [
            DefaultTheme.LIGHT: "#ffeedbfe".colorFromReadableHex(),
            DefaultTheme.DARK: "#ff311E48".colorFromReadableHex()
        ]
        }
    }

    public var colors: [DefaultTheme: ThemeColors] {
        switch self {
        case .cats: [
            DefaultTheme.LIGHT: ThemeColors.from(
                sentMessage: "#fffffaed",
                sentQuote: "#fffaf0d6",
                receivedMessage: "#ffF8F7F4",
                receivedQuote: "#ffefede9"
            ),
            DefaultTheme.DARK: ThemeColors.from(
                sentMessage: "#ff2f2919",
                sentQuote: "#ff473a1d",
                receivedMessage: "#ff272624",
                receivedQuote: "#ff373633"
            )
        ]
        case .flowers: [
            DefaultTheme.LIGHT: ThemeColors.from(
                sentMessage: "#fff1ffe5",
                sentQuote: "#ffdcf9c4",
                receivedMessage: "#ffF4F8F2",
                receivedQuote: "#ffe7ece7"
            ),
            DefaultTheme.DARK: ThemeColors.from(
                sentMessage: "#ff163521",
                sentQuote: "#ff1B5330",
                receivedMessage: "#ff242523",
                receivedQuote: "#ff353733"
            )
        ]
        case .hearts: [
            DefaultTheme.LIGHT: ThemeColors.from(
                sentMessage: "#fffff4f4",
                sentQuote: "#ffffdfdf",
                receivedMessage: "#fff8f6f6",
                receivedQuote: "#ffefebeb"
            ),
            DefaultTheme.DARK: ThemeColors.from(
                sentMessage: "#ff301515",
                sentQuote: "#ff4C1818",
                receivedMessage: "#ff242121",
                receivedQuote: "#ff3b3535"
            )
        ]
        case .kids: [
            DefaultTheme.LIGHT: ThemeColors.from(
                sentMessage: "#ffeafeff",
                sentQuote: "#ffcbf4f7",
                receivedMessage: "#fff3fafa",
                receivedQuote: "#ffe4efef"
            ),
            DefaultTheme.DARK: ThemeColors.from(
                sentMessage: "#ff16302F",
                sentQuote: "#ff1a4a49",
                receivedMessage: "#ff252626",
                receivedQuote: "#ff373A39"
            )
        ]
        case .school: [
            DefaultTheme.LIGHT: ThemeColors.from(
                sentMessage: "#ffeef9ff",
                sentQuote: "#ffD6EDFA",
                receivedMessage: "#ffF3F5F9",
                receivedQuote: "#ffe4e8ee"
            ),
            DefaultTheme.DARK: ThemeColors.from(
                sentMessage: "#ff172833",
                sentQuote: "#ff1C3E4F",
                receivedMessage: "#ff26282c",
                receivedQuote: "#ff393c40"
            )
        ]
        case .travel: [
            DefaultTheme.LIGHT: ThemeColors.from(
                sentMessage: "#fffcf6ff",
                sentQuote: "#fff2e0fc",
                receivedMessage: "#ffF6F4F7",
                receivedQuote: "#ffede9ee"
            ),
            DefaultTheme.DARK: ThemeColors.from(
                sentMessage: "#ff33263B",
                sentQuote: "#ff53385E",
                receivedMessage: "#ff272528",
                receivedQuote: "#ff3B373E"
            )
        ]
        }
    }

    public static func from(_ filename: String) -> PresetWallpaper? {
        switch filename {
        case PresetWallpaper.cats.filename: PresetWallpaper.cats
        case PresetWallpaper.flowers.filename: PresetWallpaper.flowers
        case PresetWallpaper.hearts.filename: PresetWallpaper.hearts
        case PresetWallpaper.kids.filename: PresetWallpaper.kids
        case PresetWallpaper.school.filename: PresetWallpaper.school
        case PresetWallpaper.travel.filename: PresetWallpaper.travel
        default: nil
        }
    }
}

func wallpaperBackgrounds(light: String) -> [DefaultTheme : Color] {
    [
        DefaultTheme.LIGHT: light.colorFromReadableHex(),
        DefaultTheme.DARK: "#ff0F172A".colorFromReadableHex() // Rich navy for dark mode
    ]
}

public enum WallpaperScaleType: String, Codable, CaseIterable {
    case fill
    case fit
    case `repeat`

    public var text: String {
        switch self {
        case .fill: "Fill"
        case .fit: "Fit"
        case .repeat: "Repeat"
        }
    }

    public func computeScaleFactor(_ srcSize: CGSize, _ dstSize: CGSize) -> (CGFloat, CGFloat) {
        switch self {
        case .fill:
            let widthScale = dstSize.width / srcSize.width
            let heightScale = dstSize.height / srcSize.height
            return (max(widthScale, heightScale), max(widthScale, heightScale))
        case .fit: fallthrough
        case .repeat:
            let widthScale = dstSize.width / srcSize.width
            let heightScale = dstSize.height / srcSize.height
            return (min(widthScale, heightScale), min(widthScale, heightScale))
        }
    }
}

// Spec: spec/services/theme.md#WallpaperType
public enum WallpaperType: Equatable {
    public var image: SwiftUI.Image? {
        if let uiImage {
            return SwiftUI.Image(uiImage: uiImage)
        }
        return nil
    }

    public var uiImage: UIImage? {
        let filename: String
        switch self {
        case let .preset(f, _): filename = f
        case let .image(f, _, _): filename = f
        default: return nil
        }
        if filename == "" { return nil }
        if let image = WallpaperType.cachedImage(forKey: filename) {
            return image
        } else {
            let res: UIImage?
            if case let .preset(filename, _) = self {
                res = (PresetWallpaper.from(filename) ?? PresetWallpaper.cats).res
            } else {
                // In case of unintentional image deletion don't crash the app
                res = UIImage(contentsOfFile: getWallpaperFilePath(filename).path)
            }
            if let res {
                WallpaperType.setCachedImage(res, forKey: filename)
            }
            return res
        }
    }

    public func sameType(_ other: WallpaperType?) -> Bool {
        if case let .preset(filename, _) = self, case let .preset(otherFilename, _) = other { filename == otherFilename }
        else if case .image = self, case .image = other { true }
        else if case .empty = self, case .empty = other { true }
        else { false }
    }

    public var isPreset: Bool { switch self { case .preset: true; default: false } }

    public var isImage: Bool { switch self { case .image: true; default: false } }

    public var isEmpty: Bool { switch self { case .empty: true; default: false } }

    public var scale: Float { 
        switch self {
        case let .preset(_, scale): scale ?? 1
        case let .image(_, scale, _): scale ?? 1
        case .empty: 1
        }
    }

    public func samePreset(other: PresetWallpaper?) -> Bool { if case let .preset(filename, _) = self, filename == other?.filename { true } else { false } }

    case preset(_ filename: String, _ scale: Float?)

    case image(_ filename: String, _ scale: Float?, _ scaleType: WallpaperScaleType?)

    case empty

    public func defaultBackgroundColor(_ theme: DefaultTheme, _ themeBackground: Color) -> Color {
        if case let .preset(filename, _) = self {
            let wallpaper = PresetWallpaper.from(filename) ?? PresetWallpaper.cats
            return wallpaper.background[theme] ?? wallpaper.background[.LIGHT] ?? themeBackground
        } else {
            return themeBackground
        }
    }

    public func defaultTintColor(_ theme: DefaultTheme) -> Color {
        if case let .preset(filename, _) = self {
            let wallpaper = PresetWallpaper.from(filename) ?? PresetWallpaper.cats
            return wallpaper.tint[theme] ?? wallpaper.tint[.LIGHT] ?? Color.clear
        } else if case let .image(_, _, scaleType) = self, scaleType == WallpaperScaleType.repeat {
            return Color.clear
        } else {
            return Color.clear
        }
    }

    private static let _cachedImagesLock = DispatchQueue(label: "chat.popopx.wallpaper.cachedImages")
    private static var _cachedImages: [String: UIImage] = [:]
    private static var _cachedImagesAccessOrder: [String] = [] // LRU tracking: least recently used at front
    private static let maxCachedImages = 10

    public static func cachedImage(forKey key: String) -> UIImage? {
        _cachedImagesLock.sync {
            guard let image = _cachedImages[key] else { return nil }
            // Move to end (most recently used)
            _cachedImagesAccessOrder.removeAll { $0 == key }
            _cachedImagesAccessOrder.append(key)
            return image
        }
    }

    public static func setCachedImage(_ image: UIImage, forKey key: String) {
        _cachedImagesLock.sync {
            // Update access order if key already exists
            _cachedImagesAccessOrder.removeAll { $0 == key }
            _cachedImages[key] = image
            _cachedImagesAccessOrder.append(key)
            // Evict least recently used entries if over capacity
            while _cachedImages.count > maxCachedImages, !_cachedImagesAccessOrder.isEmpty {
                let oldestKey = _cachedImagesAccessOrder.removeFirst()
                _cachedImages.removeValue(forKey: oldestKey)
            }
        }
    }

    public static func removeCachedImage(forKey key: String) {
        _cachedImagesLock.sync {
            _cachedImages.removeValue(forKey: key)
            _cachedImagesAccessOrder.removeAll { $0 == key }
        }
    }

    public static func from(_ wallpaper: ThemeWallpaper?) -> WallpaperType? {
        if wallpaper == nil {
            return nil
        } else if let preset = wallpaper?.preset {
            return WallpaperType.preset(preset, wallpaper?.scale)
        } else if let imageFile = wallpaper?.imageFile {
            return WallpaperType.image(imageFile, wallpaper?.scale, wallpaper?.scaleType)
        } else {
            return WallpaperType.empty
        }
    }
}
