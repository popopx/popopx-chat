//
//  CIEventView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 20.07.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Event Banner Configuration
private enum PXCIEventConfig {
    /// Horizontal padding around event text
    static let horizontalPadding: CGFloat = 8
    /// Vertical padding around event text
    static let verticalPadding: CGFloat = 5
    /// Maximum number of lines before truncation
    static let lineLimit: Int = 4
    /// Base opacity for event text in light theme
    static let lightThemeOpacity: Double = 1.0
    /// Muted opacity for event text in dark theme
    static let darkThemeOpacity: Double = 0.92
    /// Accessibility identifier for event banner
    static let accessibilityId: String = "px_ci_event_banner"
    /// Component tag for dedup tracking
    static let componentTag: String = "PX_EVENT"
}

// Spec: spec/client/chat-view.md#CIEventView
struct CIEventView: View {
    var eventText: Text

    var body: some View {
        eventText
        .lineLimit(PXCIEventConfig.lineLimit)
        .textSelection(.disabled)
        .padding(.vertical, PXCIEventConfig.verticalPadding)
        .padding(.horizontal, PXCIEventConfig.horizontalPadding)
        .opacity(isInDarkTheme() ? PXCIEventConfig.darkThemeOpacity : PXCIEventConfig.lightThemeOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(PXCIEventConfig.accessibilityId)
        .popopxBranded()
    }
}

struct CIEventView_Previews: PreviewProvider {
    static var previews: some View {
        CIEventView(eventText: Text("event happened"))
    }
}

// MARK: - POPOPX
extension CIEventView {
    static let pxComponentTag: String = PXCIEventConfig.componentTag
}
