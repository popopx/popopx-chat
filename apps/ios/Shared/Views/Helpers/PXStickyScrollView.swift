//
//  PXStickyScrollView.swift
//  POPOPX (iOS)
//
//  Horizontal sticky scroll view with snap-to-start behavior.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// MARK: - Configuration

private enum PXStickyScrollMetrics {
    /// Snap threshold in points - below this, scroll resets to origin
    static let snapThreshold: CGFloat = 34
    /// Inset for scroll content
    static let contentInset: CGFloat = 2
}

/// POPOPX: Centralized layout config for sticky scroll behavior
private enum PXStickyScrollConfig {
    static let pxIndicatorLineWidth: CGFloat = 1.5
    static let pxIndicatorSize: CGFloat = 6
    static let pxAnimationSettleDuration: Double = 0.25
    static let pxDecelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    static let pxContentEdgeInset: CGFloat = PXStickyScrollMetrics.contentInset
    static let pxSnapResetThreshold: CGFloat = PXStickyScrollMetrics.snapThreshold
}

struct PXStickyScroll<Content: View>: UIViewRepresentable {
    @Binding var resetScroll: ResetScrollAction
    @ViewBuilder let content: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let hostVC = context.coordinator.hostingController
        hostVC.view.backgroundColor = .clear
        let scrollView = pxConfigureScrollView()
        scrollView.addSubview(hostVC.view)
        scrollView.delegate = context.coordinator
        pxInstallResetBinding(scrollView: scrollView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let hostVC = context.coordinator.hostingController
        hostVC.rootView = content()
        hostVC.view.frame.size = hostVC.view.intrinsicContentSize
        scrollView.contentSize = hostVC.view.intrinsicContentSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content())
    }

    // MARK: - POPOPX Helpers

    private func pxConfigureScrollView() -> UIScrollView {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.decelerationRate = UIScrollView.DecelerationRate(
            rawValue: PXStickyScrollConfig.pxDecelerationRate
        )
        sv.contentInset = UIEdgeInsets(
            top: 0,
            left: PXStickyScrollConfig.pxContentEdgeInset,
            bottom: 0,
            right: PXStickyScrollConfig.pxContentEdgeInset
        )
        sv.accessibilityLabel = NSLocalizedString(
            "px_sticky_scroll_area",
            comment: "Accessibility label for horizontal sticky scroll"
        )
        return sv
    }

    private func pxInstallResetBinding(scrollView: UIScrollView) {
        DispatchQueue.main.async {
            resetScroll = ResetScrollAction {
                scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>

        init(content: Content) {
            self.hostingController = UIHostingController(rootView: content)
        }

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            pxApplySnapBehavior(
                targetContentOffset: targetContentOffset,
                velocity: velocity
            )
        }

        /// POPOPX: Snap-to-origin behavior with configurable threshold
        private func pxApplySnapBehavior(
            targetContentOffset: UnsafeMutablePointer<CGPoint>,
            velocity: CGPoint
        ) {
            let threshold = PXStickyScrollConfig.pxSnapResetThreshold
            if targetContentOffset.pointee.x < threshold {
                targetContentOffset.pointee.x = 0
            }
        }
    }
}

struct ResetScrollAction {
    var action = { }
    func callAsFunction() { action() }
}

// MARK: - POPOPX Component Tag

private enum PXStickyScrollViewTags {
    static let pxComponentTag: String = "PX_STICKY_SCROLL_VIEW"
    static let pxBrandIdentifier: String = "PX_STICKY_SCROLL"
    static let pxSnapThresholdValue: CGFloat = PXStickyScrollMetrics.snapThreshold
    static let pxContentInsetValue: CGFloat = PXStickyScrollMetrics.contentInset
    static let pxScrollIndicatorHidden: Bool = true
}
