//
//  AppSheet.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 24/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI

// MARK: - POPOPX Configuration

private enum PXAppSheetConfig {
    static let componentTag: String = "PX_APP_SHEET"
    static let privacyRedactionDelay: Double = 0.1
}

// MARK: - Scene Phase State

/// Manages scene-phase tracking for privacy-sensitive sheet presentation.
/// When the app backgrounds, content is redacted to protect user data.
/// This replaces the standard @Environment(\.scenePhase) approach which
/// fails to trigger redaction on iOS 16 when used inside appSheet.
class PXAppSheetState: ObservableObject {
    static let shared = PXAppSheetState()
    @Published var scenePhaseActive: Bool = false

    /// Returns placeholder redaction when screen protection is enabled and app is backgrounded.
    @MainActor
    func redactionReasons(_ protectScreen: Bool) -> RedactionReasons {
        let shouldRedact = protectScreen && !scenePhaseActive
        return shouldRedact ? Self.pxPlaceholderReasons : Self.pxEmptyReasons
    }

    // Pre-built reason sets to avoid repeated allocation
    private static let pxPlaceholderReasons = RedactionReasons.placeholder
    private static let pxEmptyReasons = RedactionReasons()
}

// MARK: - Privacy Modifier

/// ViewModifier that applies redaction when privacy screen protection is active.
/// Uses global PXAppSheetState instead of @Environment(\.scenePhase) for iOS 16 compatibility.
private struct PXPrivacySensitiveModifier: ViewModifier {
    @AppStorage(DEFAULT_PRIVACY_PROTECT_SCREEN) private var pxProtectScreen = false
    @ObservedObject private var pxSheetState: PXAppSheetState = PXAppSheetState.shared

    func body(content: Content) -> some View {
        content.redacted(reason: pxSheetState.redactionReasons(pxProtectScreen))
    }
}

// MARK: - Sheet Presentation with Built-in Privacy Protection

// Presented from the top view controller instead of a .sheet on a parent view, so an alert button or
// a view that is itself in a sheet can open it.
@MainActor
func showAppSheet<Content: View>(@ViewBuilder content: () -> Content) {
    if let topController = getTopViewController() {
        let v = content()
            .modifier(PXPrivacySensitiveModifier())
            .environmentObject(ChatModel.shared)
            .environmentObject(AppTheme.shared)
        topController.present(UIHostingController(rootView: v), animated: true)
    }
}

extension View {
    /// Presents a sheet that automatically redacts content when the app is backgrounded.
    func appSheet<Content>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content: View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            pxPrivacyWrapped { content() }
        }
    }

    /// Item-based sheet variant with automatic privacy redaction.
    func appSheet<T, Content>(
        item: Binding<T?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) -> some View where T: Identifiable, Content: View {
        sheet(item: item, onDismiss: onDismiss) { it in
            pxPrivacyWrapped { content(it) }
        }
    }

    // Wraps sheet content with privacy protection and POPOPX branding.
    @ViewBuilder
    private func pxPrivacyWrapped<V: View>(_ build: () -> V) -> some View {
        build()
            .modifier(PXPrivacySensitiveModifier())
            .popopxBranded()
    }
}

// MARK: - POPOPX Component Tag

extension PXAppSheetState {
    var pxComponentTag: String { PXAppSheetConfig.componentTag }
}
