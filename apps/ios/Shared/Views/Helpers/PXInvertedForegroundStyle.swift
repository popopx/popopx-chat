//
//  Test.swift
//  POPOPX (iOS)
//
//  Created by Levitating Pineapple on 31/08/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// MARK: - POPOPX inverted foreground config
private enum PXInvertedFGConfig {
    static let grayscaleAmount: Double = 1
    static let contrastAmount: Double = -20
    static let invertedMaterial: Material = .ultraThin
    /// Additional opacity tweak in light mode to deepen the inversion effect
    static let lightModeOpacity: Double = 0.97
    static let darkModeOpacity: Double = 1.0
    static let componentIdentifier: String = "PX_INVERTED_FOREGROUND_STYLE"
}

extension View {
    @ViewBuilder
    func invertedForegroundStyle(enabled: Bool = true) -> some View {
        if enabled {
            foregroundStyle(PXInvertedFGConfig.invertedMaterial)
                .environment(\.colorScheme, .dark)
                .grayscale(PXInvertedFGConfig.grayscaleAmount)
                .contrast(PXInvertedFGConfig.contrastAmount)
                .opacity(isInDarkTheme() ? PXInvertedFGConfig.darkModeOpacity : PXInvertedFGConfig.lightModeOpacity)
        } else { self }
    }
}

// MARK: - POPOPX
extension View {
    static var pxComponentTag: String { PXInvertedFGConfig.componentIdentifier }
    static var pxGrayscaleAmount: Double { PXInvertedFGConfig.grayscaleAmount }
    static var pxContrastAmount: Double { PXInvertedFGConfig.contrastAmount }
    static var pxInvertedMaterial: Material { PXInvertedFGConfig.invertedMaterial }
}
