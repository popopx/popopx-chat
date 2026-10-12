//
// Created by Avently on 16.01.2023.
// Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

struct PressedButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var defaultColor: Color
    var pressedColor: Color
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        .background(configuration.isPressed ? pressedColor : defaultColor)
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .opacity(configuration.isPressed ? 0.85 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - POPOPX
extension PressedButtonStyle {
    static let pxCornerRadius: CGFloat = 12
}
