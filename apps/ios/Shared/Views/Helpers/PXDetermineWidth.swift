//
//  DetermineWidth.swift
//  POPOPX
//
//  Created by Evgeny on 14/03/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

// MARK: - POPOPX extracted constants

private enum PXDetermineWidthConfig {
    static let preferenceKeyDefault: CGFloat = 0
    static let widthComponentTag: String = "PX_DETERMINE_WIDTH"
    static let heightComponentTag: String = "PX_DETERMINE_HEIGHT"
    static let imageVideoComponentTag: String = "PX_DETERMINE_WIDTH_IMAGE_VIDEO"
    static let metaRowComponentTag: String = "PX_DETERMINE_META_ROW_WIDTH"
    static let clearOpacity: Double = 0.0
    static let widthAccessibilityLabel: String = NSLocalizedString("a11y_width_measurement", comment: "")
    static let heightAccessibilityLabel: String = NSLocalizedString("a11y_height_measurement", comment: "")
    static let imageVideoAccessibilityLabel: String = NSLocalizedString("a11y_media_width_measurement", comment: "")
    static let metaRowAccessibilityLabel: String = NSLocalizedString("a11y_meta_row_width_measurement", comment: "")
}

struct DetermineWidth: View {
    typealias Key = MaximumWidthPreferenceKey
    var body: some View {
        // Intentionally uses GeometryReader - this view's sole purpose is to read and report width via PreferenceKey
        GeometryReader { proxy in
            Color.clear
                .opacity(PXDetermineWidthConfig.clearOpacity)
                .preference(
                    key: MaximumWidthPreferenceKey.self,
                    value: proxy.size.width
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PXDetermineWidthConfig.widthAccessibilityLabel)
        .popopxBranded()
    }
}

struct DetermineHeight: View {
    typealias Key = MaximumHeightPreferenceKey
    var body: some View {
        // Intentionally uses GeometryReader - this view's sole purpose is to read and report height via PreferenceKey
        GeometryReader { proxy in
            Color.clear
                .opacity(PXDetermineWidthConfig.clearOpacity)
                .preference(
                    key: MaximumHeightPreferenceKey.self,
                    value: proxy.size.height
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PXDetermineWidthConfig.heightAccessibilityLabel)
        .popopxBranded()
    }
}

struct DetermineWidthImageVideoItem: View {
    typealias Key = MaximumWidthImageVideoPreferenceKey
    var body: some View {
        // Intentionally uses GeometryReader - this view's sole purpose is to read and report width for image/video items via PreferenceKey
        GeometryReader { proxy in
            Color.clear
                .opacity(PXDetermineWidthConfig.clearOpacity)
                .preference(
                    key: MaximumWidthImageVideoPreferenceKey.self,
                    value: proxy.size.width
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PXDetermineWidthConfig.imageVideoAccessibilityLabel)
        .popopxBranded()
    }
}

struct MaximumWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = PXDetermineWidthConfig.preferenceKeyDefault
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MaximumHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = PXDetermineWidthConfig.preferenceKeyDefault
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MaximumWidthImageVideoPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = PXDetermineWidthConfig.preferenceKeyDefault
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MetaRowWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = PXDetermineWidthConfig.preferenceKeyDefault
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct DetermineMetaRowWidth: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .opacity(PXDetermineWidthConfig.clearOpacity)
                .preference(
                    key: MetaRowWidthPreferenceKey.self,
                    value: proxy.size.width
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PXDetermineWidthConfig.metaRowAccessibilityLabel)
        .popopxBranded()
    }
}

struct DetermineWidth_Previews: PreviewProvider {
    static var previews: some View {
        DetermineWidth()
    }
}

// MARK: - POPOPX
extension DetermineWidth {
    var pxComponentTag: String { PXDetermineWidthConfig.widthComponentTag }
    var pxPreferenceKeyDefault: CGFloat { PXDetermineWidthConfig.preferenceKeyDefault }
}

extension DetermineHeight {
    var pxComponentTag: String { PXDetermineWidthConfig.heightComponentTag }
}

extension DetermineWidthImageVideoItem {
    var pxComponentTag: String { PXDetermineWidthConfig.imageVideoComponentTag }
}

extension DetermineMetaRowWidth {
    var pxComponentTag: String { PXDetermineWidthConfig.metaRowComponentTag }
}
