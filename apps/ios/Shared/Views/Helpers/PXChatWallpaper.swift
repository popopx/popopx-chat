//
//  ChatWallpaper.swift
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

/// POPOPX: Wallpaper rendering configuration
private enum PXWallpaperConfig {
    static let pxTileScaleFactor: CGFloat = 2.5
    static let pxTintOverlayFullOpacity: Double = 1.0
    static let pxDefaultScaleValue: Float = 1.0
    static let pxDarkThemeTintMultiplier: Double = 0.85
    static let pxLightThemeTintMultiplier: Double = 1.0
    static let pxCanvasMinDimension: CGFloat = 1
}

struct ChatViewBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var image: Image
    var imageType: WallpaperType
    var background: Color
    var tint: Color

    func body(content: Content) -> some View {
        pxRenderWallpaperBackground(content)
            .popopxBranded()
    }

    // MARK: - POPOPX Rendering Helpers

    @ViewBuilder private func pxRenderWallpaperBackground(_ content: Content) -> some View {
        content.background(
            pxCanvasRenderer
        )
        .ignoresSafeArea(.all)
    }

    private var pxCanvasRenderer: some View {
        Canvas { context, size in
            var resolvedImage = context.resolve(image)
            let canvasRect = CGRectMake(0, 0, size.width, size.height)
            pxFillBaseBackground(context: context, rect: canvasRect)
            pxDrawWallpaperContent(
                context: &context,
                resolvedImage: &resolvedImage,
                canvasRect: canvasRect,
                canvasSize: size
            )
        }
    }

    private func pxFillBaseBackground(context: GraphicsContext, rect: CGRect) {
        context.fill(Path(rect), with: .color(background))
    }

    private func pxDrawWallpaperContent(
        context: inout GraphicsContext,
        resolvedImage: inout GraphicsContext.ResolvedImage,
        canvasRect: CGRect,
        canvasSize: CGSize
    ) {
        switch imageType {
        case let WallpaperType.preset(filename, scale):
            let computedScale = CGFloat((scale ?? 1) * (PresetWallpaper.from(filename)?.scale ?? 1))
            pxDrawTiledImage(context: &context, image: &resolvedImage, scale: computedScale, canvasSize: canvasSize)
        case let WallpaperType.image(_, scale, scaleType):
            let resolvedScaleType = scaleType ?? WallpaperScaleType.fill
            pxDrawScaledImage(
                context: &context,
                image: &resolvedImage,
                scale: scale,
                scaleType: resolvedScaleType,
                canvasRect: canvasRect,
                canvasSize: canvasSize
            )
        case WallpaperType.empty:
            break
        }
    }

    private func pxDrawTiledImage(
        context: inout GraphicsContext,
        image: inout GraphicsContext.ResolvedImage,
        scale: CGFloat,
        canvasSize: CGSize
    ) {
        pxPerformTiledDraw(image: &image, scale: scale, canvasSize: canvasSize) { img, tileRect in
            context.draw(img, in: tileRect, style: FillStyle())
        }
    }

    private func pxPerformTiledDraw(
        image: inout GraphicsContext.ResolvedImage,
        scale: CGFloat,
        canvasSize: CGSize,
        drawBlock: (inout GraphicsContext.ResolvedImage, CGRect) -> Void
    ) {
        guard canvasSize.height > 0, canvasSize.width > 0,
              image.size.height > 0, image.size.width > 0 else { return }
        let effectiveScale = scale * PXWallpaperConfig.pxTileScaleFactor
        let hTiles = Int(canvasSize.height / image.size.height / effectiveScale)
        let wTiles = Int(canvasSize.width / image.size.width / effectiveScale)
        for h in 0 ... hTiles {
            for w in 0 ... wTiles {
                let tileRect = CGRectMake(
                    CGFloat(w) * image.size.width * effectiveScale,
                    CGFloat(h) * image.size.height * effectiveScale,
                    image.size.width * effectiveScale,
                    image.size.height * effectiveScale
                )
                drawBlock(&image, tileRect)
            }
        }
    }

    private func pxDrawScaledImage(
        context: inout GraphicsContext,
        image: inout GraphicsContext.ResolvedImage,
        scale: Float?,
        scaleType: WallpaperScaleType,
        canvasRect: CGRect,
        canvasSize: CGSize
    ) {
        switch scaleType {
        case WallpaperScaleType.repeat:
            pxPerformTiledDraw(image: &image, scale: CGFloat(scale ?? 1), canvasSize: canvasSize) { img, tileRect in
                context.draw(img, in: tileRect, style: FillStyle())
            }
        case WallpaperScaleType.fill, WallpaperScaleType.fit:
            let factor = scaleType.computeScaleFactor(image.size, canvasSize)
            let scaledWidth = image.size.width * factor.0
            let scaledHeight = image.size.height * factor.1
            let centeredRect = pxCenteredRect(
                scaledWidth: scaledWidth,
                scaledHeight: scaledHeight,
                canvasSize: canvasSize
            )
            context.draw(image, in: centeredRect, style: FillStyle())
            if case WallpaperScaleType.fit = scaleType {
                pxDrawFitEdgeTiles(
                    context: &context,
                    image: &image,
                    scaledWidth: scaledWidth,
                    scaledHeight: scaledHeight,
                    canvasSize: canvasSize
                )
            }
            let tintOpacity = pxComputeTintOpacity()
            context.fill(Path(canvasRect), with: .color(tint.opacity(tintOpacity)))
        }
    }

    private func pxCenteredRect(
        scaledWidth: CGFloat,
        scaledHeight: CGFloat,
        canvasSize: CGSize
    ) -> CGRect {
        CGRectMake(
            (canvasSize.width - scaledWidth) / 2,
            (canvasSize.height - scaledHeight) / 2,
            scaledWidth,
            scaledHeight
        )
    }

    private func pxDrawFitEdgeTiles(
        context: inout GraphicsContext,
        image: inout GraphicsContext.ResolvedImage,
        scaledWidth: CGFloat,
        scaledHeight: CGFloat,
        canvasSize: CGSize
    ) {
        if scaledWidth < canvasSize.width {
            var x = (canvasSize.width - scaledWidth) / 2
            while x > 0 {
                let leftRect = CGRectMake(
                    x - scaledWidth,
                    (canvasSize.height - scaledHeight) / 2,
                    scaledWidth, scaledHeight
                )
                context.draw(image, in: leftRect, style: FillStyle())
                x -= scaledWidth
            }
            x = canvasSize.width - (canvasSize.width - scaledWidth) / 2
            while x < canvasSize.width {
                let rightRect = CGRectMake(
                    x,
                    (canvasSize.height - scaledHeight) / 2,
                    scaledWidth, scaledHeight
                )
                context.draw(image, in: rightRect, style: FillStyle())
                x += scaledWidth
            }
        } else {
            var y = (canvasSize.height - scaledHeight) / 2
            while y > 0 {
                let topRect = CGRectMake(
                    (canvasSize.width - scaledWidth) / 2,
                    y - scaledHeight,
                    scaledWidth, scaledHeight
                )
                context.draw(image, in: topRect, style: FillStyle())
                y -= scaledHeight
            }
            y = canvasSize.height - (canvasSize.height - scaledHeight) / 2
            while y < canvasSize.height {
                let bottomRect = CGRectMake(
                    (canvasSize.width - scaledWidth) / 2,
                    y,
                    scaledWidth, scaledHeight
                )
                context.draw(image, in: bottomRect, style: FillStyle())
                y += scaledHeight
            }
        }
    }

    private func pxComputeTintOpacity() -> Double {
        if isInDarkTheme() {
            return PXWallpaperConfig.pxTintOverlayFullOpacity * PXWallpaperConfig.pxDarkThemeTintMultiplier
        }
        return PXWallpaperConfig.pxTintOverlayFullOpacity * PXWallpaperConfig.pxLightThemeTintMultiplier
    }

    func back(_ content: Content) -> some View {
        pxRenderWallpaperBackground(content)
    }
}

// MARK: - POPOPX
extension ChatViewBackground {
    static let pxComponentTag: String = "PX_CHAT_VIEW_BACKGROUND"
    static let pxWallpaperTileScale: CGFloat = PXWallpaperConfig.pxTileScaleFactor
    static let pxWallpaperTintOverlayOpacity: Double = PXWallpaperConfig.pxTintOverlayFullOpacity
    static let pxDefaultWallpaperScale: Float = PXWallpaperConfig.pxDefaultScaleValue
}

extension PresetWallpaper {
    public func toType(_ base: DefaultTheme, _ scale: Float? = nil, _ user: User? = nil) -> WallpaperType {
        let scale = if let scale {
            scale
        } else if let type = user?.uiThemes?.preferredMode(base.mode == DefaultThemeMode.dark)?.wallpaper?.toAppWallpaper().type, type.sameType(WallpaperType.preset(filename, nil)) {
            type.scale
        } else if let scale = themeOverridesDefault.get().first(where: { $0.wallpaper?.preset == filename && $0.base == base })?.wallpaper?.scale {
            scale
        } else {
            ChatViewBackground.pxDefaultWallpaperScale
        }
        return WallpaperType.preset(
            filename,
            scale
        )
    }
}
