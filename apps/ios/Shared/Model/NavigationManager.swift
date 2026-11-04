//
//  NavigationManager.swift
//  POPOPX
//
//  Centralized navigation state management to prevent sheet conflicts
//

import SwiftUI
import Combine

// MARK: - Sheet Identifiers

enum PXSheet: String, Identifiable {
    case notices
    case chooseLAMode
    case setPasscode
    case userPicker
    case renewalReminder
    case trialSubscribe
    case migration
    case conditions
    case whyBuilt
    case terminal
    case computeStore
    case paywall

    var id: String { rawValue }
}

// MARK: - Navigation Manager

@MainActor
final class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    @Published private(set) var activeSheet: PXSheet?
    @Published private(set) var presentedSheets: Set<PXSheet> = []

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Sheet Presentation

    /// Request to show a sheet. Returns true if the sheet was shown, false if another sheet is already active.
    func show(_ sheet: PXSheet) -> Bool {
        if let existing = activeSheet, existing != sheet {
            return false
        }
        activeSheet = sheet
        presentedSheets.insert(sheet)
        return true
    }

    /// Force show a sheet, dismissing any existing sheet first.
    func forceShow(_ sheet: PXSheet) {
        if let existing = activeSheet, existing != sheet {
            dismiss(existing)
        }
        activeSheet = sheet
        presentedSheets.insert(sheet)
    }

    /// Dismiss a specific sheet.
    func dismiss(_ sheet: PXSheet) {
        presentedSheets.remove(sheet)
        if activeSheet == sheet {
            activeSheet = nil
        }
    }

    /// Dismiss all sheets.
    func dismissAll() {
        activeSheet = nil
        presentedSheets.removeAll()
    }

    /// Check if a specific sheet is currently presented.
    func isPresented(_ sheet: PXSheet) -> Bool {
        presentedSheets.contains(sheet)
    }

    /// Check if any sheet is currently presented.
    var hasActiveSheet: Bool {
        activeSheet != nil
    }

    // MARK: - Binding Helpers

    /// Create a Binding<Bool> for a sheet that syncs with the navigation manager.
    func binding(for sheet: PXSheet) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.presentedSheets.contains(sheet) ?? false },
            set: { [weak self] newValue in
                if newValue {
                    self?.forceShow(sheet)
                } else {
                    self?.dismiss(sheet)
                }
            }
        )
    }

    /// Create a Binding<T?> for an item-based sheet that syncs with the navigation manager.
    func itemBinding<T: Equatable>(for sheet: PXSheet, value: Binding<T?>) -> Binding<T?> {
        Binding(
            get: { value.wrappedValue },
            set: { [weak self] newValue in
                if newValue != nil {
                    self?.forceShow(sheet)
                } else {
                    self?.dismiss(sheet)
                }
                value.wrappedValue = newValue
            }
        )
    }
}

// MARK: - View Extension

extension View {
    /// Sheet modifier that integrates with NavigationManager to prevent conflicts.
    func managedSheet<Content: View>(
        _ sheet: PXSheet,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let manager = NavigationManager.shared
        return self.sheet(
            isPresented: manager.binding(for: sheet),
            onDismiss: {
                manager.dismiss(sheet)
                onDismiss?()
            },
            content: content
        )
    }

    /// Item-based sheet modifier that integrates with NavigationManager.
    func managedSheet<T: Identifiable & Equatable, Content: View>(
        _ sheet: PXSheet,
        item: Binding<T?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (T) -> Content
    ) -> some View {
        let manager = NavigationManager.shared
        return self.sheet(
            item: manager.itemBinding(for: sheet, value: item),
            onDismiss: {
                manager.dismiss(sheet)
                onDismiss?()
            },
            content: content
        )
    }
}
