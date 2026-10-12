//
//  PXZoomableScrollView.swift
//  POPOPX
//
//  Created by Evgeny on 13/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

// MARK: - POPOPX Zoom Configuration
private enum PxZoomConfig {
    static let imageMaxScale: CGFloat = 25.0
    static let pageMaxScale: CGFloat = 6.0
    static let minScale: CGFloat = 1
    static let canvasBackground: UIColor = UIColor(white: 0.02, alpha: 1.0)
    static let featureFlagKey: String = "PX_ZOOM_FEATURE_ENABLED"
}

// MARK: - POPOPX Scroll View for Images

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private let pxContent: Content

    init(@ViewBuilder content: () -> Content) {
        self.pxContent = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        logger.debug("PX: [ZoomableScrollView.makeUIView] called")
        return pxConfigureScrollView(
            context: context,
            maxScale: PxZoomConfig.imageMaxScale,
            background: PxZoomConfig.canvasBackground,
            useSafeAreaInsets: false,
            useAutoResizing: true
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: self.pxContent))
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.pxHostingController.rootView = self.pxContent
        assert(context.coordinator.pxHostingController.view?.superview === uiView)
    }

    // MARK: - POPOPX Shared Setup

    private func pxConfigureScrollView(
        context: Context,
        maxScale: CGFloat,
        background: UIColor,
        useSafeAreaInsets: Bool,
        useAutoResizing: Bool
    ) -> UIScrollView {
        let pxScroll = UIScrollView()
        pxScroll.delegate = context.coordinator
        pxScroll.maximumZoomScale = maxScale
        pxScroll.minimumZoomScale = PxZoomConfig.minScale
        pxScroll.bouncesZoom = true
        pxScroll.backgroundColor = background
        pxScroll.insetsLayoutMarginsFromSafeArea = useSafeAreaInsets

        guard let pxHost = context.coordinator.pxHostingController.view else { return pxScroll }

        if useAutoResizing {
            pxHost.translatesAutoresizingMaskIntoConstraints = true
            pxHost.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            pxHost.frame = pxScroll.bounds
            pxScroll.addSubview(pxHost)
        } else {
            pxHost.backgroundColor = .clear
            pxHost.translatesAutoresizingMaskIntoConstraints = false
            pxScroll.addSubview(pxHost)
            pxActivateConstraints(for: pxHost, in: pxScroll)
        }

        return pxScroll
    }

    private func pxActivateConstraints(for hostedView: UIView, in scrollView: UIScrollView) {
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    // MARK: - POPOPX Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var pxHostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.pxHostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            pxHostingController.view
        }
    }
}

// MARK: - POPOPX Page-level Zoom View

struct ZoomablePageView<Content: View>: UIViewRepresentable {
    private let pxContent: Content

    init(@ViewBuilder content: () -> Content) {
        self.pxContent = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        logger.debug("PX: [ZoomablePageView.makeUIView] called")
        let pxScroll = UIScrollView()
        pxScroll.delegate = context.coordinator
        pxScroll.maximumZoomScale = PxZoomConfig.pageMaxScale
        pxScroll.minimumZoomScale = PxZoomConfig.minScale
        pxScroll.bouncesZoom = true
        pxScroll.backgroundColor = .clear

        guard let pxHost = context.coordinator.pxHostingController.view else { return pxScroll }
        pxHost.backgroundColor = .clear
        pxHost.translatesAutoresizingMaskIntoConstraints = false
        pxScroll.addSubview(pxHost)
        pxBindContentEdges(pxHost, in: pxScroll)

        return pxScroll
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: self.pxContent))
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.pxHostingController.rootView = self.pxContent
    }

    /// POPOPX: pin hosted view to content & frame layout guides
    private func pxBindContentEdges(_ hostedView: UIView, in scrollView: UIScrollView) {
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    // MARK: - POPOPX Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var pxHostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.pxHostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            pxHostingController.view
        }
    }
}

// MARK: - POPOPX Branding Tag
fileprivate let _pxBrandZoomableScroll = "PX_ZOOMABLE_SCROLL"
