//
//  ScrollViewCells.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 27.01.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// MARK: - POPOPX Layout Configuration
private enum PXScrollViewCellsConfig {
    static let maxEditorHeightRatio: CGFloat = 12
    static let maxEditorHeightCap: CGFloat = 360
    static let placeholderLeadingTrailing: CGFloat = 7
    static let placeholderTop: CGFloat = 8
    static let placeholderAlpha: CGFloat = 0.6
    static let placeholderFontSize: CGFloat = 14
    static let reuseLogTag: String = "PX_HOSTING_CELL_REUSE"
    static let constraintPriority: UILayoutPriority = .required
    static let clearBackground: Bool = true
}

protocol ReusableView {
    func prepareForReuse()
}

/// `UIHostingConfiguration` back-port for iOS14 and iOS15
/// Implemented as a `UIView` that wraps and manages a generic `UIHostingController`
final class HostingCell<Hosted: View>: UIView, ReusableView {
    private let hostingController = UIHostingController<Hosted?>(rootView: nil)

    /// Updates content of the cell
    /// For reference: https://noahgilmore.com/blog/swiftui-self-sizing-cells/
    func set(content: Hosted, parent: UIViewController) {
        hostingController.view.backgroundColor = .clear
        hostingController.rootView = content
        if let hostingView = hostingController.view {
            hostingView.invalidateIntrinsicContentSize()
            if hostingController.parent != parent { parent.addChild(hostingController) }
            if !subviews.contains(hostingController.view) {
                pxAttachHostingView(hostingView)
            }
            if hostingController.parent != parent { hostingController.didMove(toParent: parent) }
        } else {
            logger.error("HostingCell: hosting view not loaded for \(self.hostingController)")
        }
    }

    func prepareForReuse() {
        logger.debug("PX: HostingCell.prepareForReuse")
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        hostingController.rootView = nil
    }

    // MARK: - POPOPX Layout Helpers

    private func pxAttachHostingView(_ hostingView: UIView) {
        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(pxHostingConstraints(for: hostingView))
    }

    private func pxHostingConstraints(for hostingView: UIView) -> [NSLayoutConstraint] {
        [
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
    }
}

// MARK: - POPOPX
extension HostingCell {
    var pxComponentTag: String { "PX_HOSTING_CELL" }
    var pxIsLoaded: Bool { hostingController.view != nil }
    var pxReuseIdentifier: String { PXScrollViewCellsConfig.reuseLogTag }
}
