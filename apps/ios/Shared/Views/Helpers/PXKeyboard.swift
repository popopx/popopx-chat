//
//  Keyboard.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 10/07/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI

// MARK: - POPOPX Keyboard Layout Config
private enum PXKeyboardConfig {
    static let brandMarker: String = "PX_KEYBOARD"
    static let componentTag: String = "PX_KEYBOARD_COMPONENT"
    static let defaultAnimationDuration: Double = 0.2
    static let keyboardDismissDelay: TimeInterval = 0.15
}

// MARK: - POPOPX Keyboard Metrics
struct PXKeyboardMetrics {
    static let estimatedHeight: CGFloat = 336
    static let safeAreaBottomInset: CGFloat = 34
    static let animationCurve: Animation = .easeOut(duration: PXKeyboardConfig.defaultAnimationDuration)

    /// POPOPX-specific: compute effective keyboard height accounting for safe area
    static func pxEffectiveHeight(rawHeight: CGFloat, hasSafeArea: Bool) -> CGFloat {
        let inset = hasSafeArea ? safeAreaBottomInset : 0
        return max(rawHeight - inset, 0)
    }
}

// MARK: - POPOPX Keyboard Dismiss Helper
extension View {
    /// POPOPX branded keyboard dismiss on tap gesture
    func pxDismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            DispatchQueue.main.asyncAfter(deadline: .now() + PXKeyboardConfig.keyboardDismissDelay) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

// MARK: - POPOPX Keyboard State Observer
final class PXKeyboardStateObserver: ObservableObject {
    static let shared = PXKeyboardStateObserver()

    @Published var isVisible: Bool = false
    @Published var keyboardHeight: CGFloat = 0

    private var notificationTokens: [NSObjectProtocol] = []

    init() {
        pxObserveKeyboard()
    }

    private func pxObserveKeyboard() {
        let willShow = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            self.isVisible = true
            self.keyboardHeight = frame.height
        }

        let willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.isVisible = false
            self.keyboardHeight = 0
        }

        notificationTokens = [willShow, willHide]
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
