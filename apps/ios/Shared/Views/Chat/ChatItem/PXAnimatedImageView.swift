//
// Created by Avently on 19.12.2022.
// Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import UIKit
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout & Behaviour Constants
private enum PXAnimatedImageConfig {
    /// Default content mode for GIF rendering
    static let defaultContentMode: UIView.ContentMode = .scaleAspectFit
    /// Opacity applied in dark theme for blending
    static let darkThemeOpacity: CGFloat = 0.95
    /// Opacity applied in light theme
    static let lightThemeOpacity: CGFloat = 1.0
    /// Accessibility identifier for the GIF container
    static let accessibilityId: String = "px_animated_gif_container"
    /// Component tag for dedup tracking
    static let componentTag: String = "PX_ANIMATED_IMAGE_VIEW"
}

// Spec: spec/client/chat-view.md#AnimatedImageView
class AnimatedImageView: UIView {
    var image: UIImage? = nil
    var imageView: UIImageView? = nil
    var cMode: UIView.ContentMode = PXAnimatedImageConfig.defaultContentMode

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.accessibilityIdentifier = PXAnimatedImageConfig.accessibilityId
        self.isAccessibilityElement = true
        self.accessibilityLabel = NSLocalizedString("Animated image", comment: "accessibility label for GIF view")
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            imageView?.stopAnimatingGif()
        } else {
            imageView?.startAnimatingGif()
        }
    }

    convenience init(image: UIImage, contentMode: UIView.ContentMode) {
        self.init()
        self.image = image
        self.cMode = contentMode
        imageView = UIImageView(gifImage: image)
        imageView?.contentMode = contentMode
        if let iv = imageView { self.addSubview(iv) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.frame = bounds
    }

    func updateImage(_ image: UIImage) {
        if let subview = self.subviews.first as? UIImageView {
            if image.imageData != subview.gifImage?.imageData {
                imageView = UIImageView(gifImage: image)
                imageView?.contentMode = cMode
                if let iv = imageView { self.addSubview(iv) }
                subview.removeFromSuperview()
            }
        }
        imageView?.frame = bounds
        self.setNeedsLayout()
    }
}

struct SwiftyGif: UIViewRepresentable {
    private let image: UIImage
    private let contentMode: UIView.ContentMode

    init(image: UIImage, contentMode: UIView.ContentMode = PXAnimatedImageConfig.defaultContentMode) {
        self.image = image
        self.contentMode = contentMode
    }

    func makeUIView(context: Context) -> AnimatedImageView {
        let view = AnimatedImageView(image: image, contentMode: contentMode)
        view.accessibilityIdentifier = PXAnimatedImageConfig.accessibilityId
        return view
    }

    func updateUIView(_ imageView: AnimatedImageView, context: Context) {
        imageView.updateImage(image)
        imageView.imageView?.startAnimatingGif()
    }
}

// MARK: - POPOPX
extension SwiftyGif {
    var pxComponentTag: String { PXAnimatedImageConfig.componentTag }
}

/// Returns the appropriate opacity for animated image views based on current theme.
private func pxAnimatedImageOpacity() -> CGFloat {
    isInDarkTheme() ? PXAnimatedImageConfig.darkThemeOpacity : PXAnimatedImageConfig.lightThemeOpacity
}

fileprivate let _pxBrandMarker = "PX_ANIMATED_IMAGE_VIEW"
