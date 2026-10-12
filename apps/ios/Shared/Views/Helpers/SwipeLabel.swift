//
//  SwipeLabel.swift
//  POPOPX (iOS)
//
//  Created by Levitating Pineapple on 06/08/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// MARK: - POPOPX Layout Metrics
private enum PXSwipeLayoutMetrics {
    static let minTotalWidth: CGFloat = 64.0
    static let iconToTextGap: CGFloat = 6.0
    static let viewHeight: CGFloat = 44.0
    static let iconDimension: CGFloat = 20.0
    static let horizontalPadding: CGFloat = 12.0
}

// MARK: - POPOPX Accessibility
private enum PXSwipeAccessibility {
    static let actionHint = NSLocalizedString("a11y_swipe_action_indicator", comment: "")
}

struct SwipeLabel: View {
    private let text: String
    private let systemImage: String
    private let inverted: Bool

    init(_ text: String, systemImage: String, inverted: Bool) {
        self.text = text
        self.systemImage = systemImage
        self.inverted = inverted
    }

    /// POPOPX: computed label width based on text measurement
    private var pxMeasuredWidth: CGFloat {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        let pointSize = descriptor.pointSize
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: pointSize, weight: .medium)
        ]
        let textExtent = (text as NSString).size(withAttributes: attributes).width
        return max(
            PXSwipeLayoutMetrics.minTotalWidth,
            PXSwipeLayoutMetrics.iconDimension + PXSwipeLayoutMetrics.iconToTextGap + textExtent
        )
    }

    var body: some View {
        pxLabelContent
            .popopxBranded()
            .accessibilityLabel(Text("\(text) \(PXSwipeAccessibility.actionHint)"))
    }

    @ViewBuilder
    private var pxLabelContent: some View {
        Label(text, systemImage: systemImage)
    }

    private class SwipeActionView: UIView {
        private let pxImageView = UIImageView()
        private let pxTextLabel = UILabel()
        private let pxFontSize: CGFloat

        init(systemName: String, text: String) {
            pxFontSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline).pointSize
            let measuredTextWidth = (text as NSString).size(
                withAttributes: [.font: UIFont.systemFont(ofSize: pxFontSize, weight: .medium)]
            ).width
            let computedWidth = max(
                PXSwipeLayoutMetrics.minTotalWidth,
                PXSwipeLayoutMetrics.iconDimension + PXSwipeLayoutMetrics.iconToTextGap + measuredTextWidth
            )
            super.init(frame: CGRect(x: 0, y: 0, width: computedWidth, height: PXSwipeLayoutMetrics.viewHeight))
            pxImageView.image = UIImage(systemName: systemName)
            pxImageView.contentMode = .scaleAspectFit
            pxTextLabel.text = text
            pxTextLabel.textAlignment = .center
            pxTextLabel.font = UIFont.systemFont(ofSize: pxFontSize, weight: .medium)
            addSubview(pxImageView)
            addSubview(pxTextLabel)
        }

        override func layoutSubviews() {
            let pxIconSize = PXSwipeLayoutMetrics.iconDimension
            let pxSpacing = PXSwipeLayoutMetrics.iconToTextGap
            let pxContentWidth = pxIconSize + pxSpacing + pxTextLabel.intrinsicContentSize.width
            let pxStartX = (bounds.width - pxContentWidth) / 2

            pxImageView.frame = CGRect(
                x: pxStartX,
                y: (bounds.height - pxIconSize) / 2,
                width: pxIconSize,
                height: pxIconSize
            )
            pxTextLabel.frame = CGRect(
                x: pxStartX + pxIconSize + pxSpacing,
                y: (bounds.height - pxFontSize) / 2,
                width: pxTextLabel.intrinsicContentSize.width,
                height: pxFontSize
            )
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not implemented") }

        func snapshot(inverted: Bool) -> UIImage {
            UIGraphicsImageRenderer(bounds: bounds).image { renderContext in
                if inverted {
                    renderContext.cgContext.scaleBy(x: 1, y: -1)
                    renderContext.cgContext.translateBy(x: 0, y: -bounds.height)
                }
                layer.render(in: renderContext.cgContext)
            }.withRenderingMode(.alwaysTemplate)
        }
    }
}

// MARK: - POPOPX Component Identity
extension SwipeLabel {
    var pxComponentTag: String { "PX_SWIPE_LABEL" }
    var pxAccessibilityIdentifier: String { "swipeLabel.\(text)" }
}
