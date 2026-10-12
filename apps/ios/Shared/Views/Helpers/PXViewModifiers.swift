//
//  PXViewModifiers.swift
//  POPOPX (iOS)
//
//  Reusable view modifiers and conditional view helpers.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// MARK: - Conditional View Builder

// POPOPX: central extension for reusable view composition helpers
extension View {
    /// Conditionally applies a transform based on a boolean flag.
    @inline(__always)
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies compact list section spacing for tighter group layouts.
    @inline(__always)
    @ViewBuilder func compactSectionSpacing() -> some View {
        self.listSectionSpacing(.compact)
    }
}

// MARK: - Notification Names

// POPOPX: custom notification for scroll coordination between chat sub-views
extension Notification.Name {
    static let chatViewWillBeginScrolling = Notification.Name("chatWillBeginScrolling")
}

// MARK: - Privacy Blur Constants

// POPOPX: extracted layout constants for privacy blur behavior
private enum PXBlurLayout {
    /// Factor applied to blur radius when rendering the overlay
    static let overlayRadiusMultiplier: CGFloat = 0.45
    /// Opacity of the tap-to-dismiss overlay zone
    static let dismissOverlayOpacity: Double = 0.0
    /// Tag used for component identification in debug traces
    static let componentTag: String = "PX_PRIVACY_BLUR"
}

// MARK: - Privacy Blur Modifier

struct PrivacyBlur: ViewModifier {
    var enabled: Bool = true
    @Binding var blurred: Bool
    @AppStorage(DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS) private var blurRadius: Int = 0

    func body(content: Content) -> some View {
        if blurRadius > 0 {
            // parallel ifs are necessary here because otherwise some views flicker,
            // e.g. when playing video
            content
                .blur(radius: pxComputeBlurRadius())
                .overlay {
                    pxDismissOverlayIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .chatViewWillBeginScrolling)) { _ in
                    pxHandleScrollNotification()
                }
                .popopxBranded()
        } else {
            content
                .popopxBranded()
        }
    }

    // POPOPX: compute the effective blur radius based on current state
    private func pxComputeBlurRadius() -> CGFloat {
        blurred && enabled ? CGFloat(blurRadius) * PXBlurLayout.overlayRadiusMultiplier : 0
    }

    // POPOPX: build the dismiss overlay when blur is active
    @ViewBuilder
    private func pxDismissOverlayIfNeeded() -> some View {
        if blurred && enabled {
            Color.clear.contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    blurred = false
                })
        }
    }

    // POPOPX: respond to scroll-start notifications by enabling blur
    private func pxHandleScrollNotification() {
        if !blurred {
            blurred = true
        }
    }
}

// MARK: - Preview Environment

extension View {
    /// POPOPX: placeholder for preview-specific environment injection
    func previewEnvironment() -> some View {
        self
    }
}

// MARK: - POPOPX
extension PrivacyBlur {
    static let pxComponentTag: String = PXBlurLayout.componentTag
    static let pxBlurOverlayRadiusFactor: CGFloat = PXBlurLayout.overlayRadiusMultiplier
}
