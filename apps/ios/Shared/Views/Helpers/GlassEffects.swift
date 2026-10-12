//
//  GlassEffects.swift
//  Shared
//
//  Apple Liquid Glass design system — WWDC 2025 design principles.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

/// Glass morphism color constants for consistent borders, overlays, and text
enum QuantumGlass {
    // MARK: - Border Highlights
    
    /// Primary border highlight for glass surfaces (light mode)
    static let borderHighlight = Color.white.opacity(0.5)
    
    /// Secondary border highlight for glass surfaces (light mode)
    static let borderSubtle = Color.white.opacity(0.2)
    
    /// Tertiary border highlight for subtle edges
    static let borderFaint = Color.white.opacity(0.15)
    
    /// Prominent border highlight for buttons and primary actions
    static let borderProminent = Color.white.opacity(0.6)
    
    /// Extra prominent border for alert dialogs
    static let borderAlert = Color.white.opacity(0.7)
    
    /// Secondary border for alert dialog gradients
    static let borderAlertSecondary = Color.white.opacity(0.3)

    // MARK: - Iridescent Border (Dark Mode)

    static func iridescentBorderGradient(opacity: Double = 0.25) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#00FFCC").opacity(opacity),
                Color(hex: "#A020F0").opacity(opacity * 0.8),
                Color(hex: "#FF007A").opacity(opacity * 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Backdrop Overlays
    
    /// Semi-transparent backdrop for modal overlays and dismiss areas
    static let backdropOverlay = Color.black.opacity(0.5)
    
    // MARK: - Text Colors (Dark Mode)
    
    /// Message text color for alerts and dialogs in dark mode
    static let messageTextDark = Color.white.opacity(0.75)
    
    /// Subtitle text color for sheets in dark mode
    static let subtitleTextDark = Color.white.opacity(0.75)
}

// MARK: - Glass Primitives

struct GlassBackground: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    var cornerRadius: CGFloat = 12
    var tint: Color? = nil
    var opacity: Double = 0.12 // Increased from 0.08 for better contrast

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill((tint ?? theme.colors.primary).opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC").opacity(0.2), Color(hex: "#A020F0").opacity(0.15), Color(hex: "#FF007A").opacity(0.1)]
                            : [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5 // Thinner border
                    )
            )
            .shadow(
                color: Color.black.opacity(isInDarkTheme() ? 0.3 : 0.06), // Single shadow, reduced
                radius: 8, x: 0, y: 2
            )
            // Removed second shadow for cleaner look
    }
}

struct GlassSurface: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    var cornerRadius: CGFloat = 12
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill((tint ?? theme.colors.primary).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC").opacity(0.25), Color(hex: "#A020F0").opacity(0.18), Color(hex: "#FF007A").opacity(0.12)]
                            : [
                                QuantumGlass.borderHighlight,
                                QuantumGlass.borderSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5 // Thinner border
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: Color.black.opacity(isInDarkTheme() ? 0.35 : 0.08), // Single shadow instead of 3
                radius: 12, x: 0, y: 4
            )
            // Removed 2 additional shadows for cleaner, privacy-focused design
    }
}

struct GlassInnerHighlight: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC").opacity(0.3), Color.clear]
                            : [Color.white.opacity(0.5), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tint: Color? = nil
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        let t = tint ?? theme.colors.primary
        let isDark = isInDarkTheme()
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isDark ? t.opacity(configuration.isPressed ? 0.2 : 0.12) : t.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isDark
                            ? [darkThemeAccentColor().opacity(0.35), neonGradientSecondary().opacity(0.2)]
                            : [t.opacity(0.5), t.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isDark ? 0.75 : 1.0
                    )
            )
            // REDUCED: Single shadow for better performance and cleaner look (was dual shadows)
            .shadow(
                color: t.opacity(configuration.isPressed ? 0.12 : 0.18),
                radius: configuration.isPressed ? 6 : 10,
                x: 0, y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var gradient: LinearGradient? = nil
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        let g = gradient ?? LinearGradient(
            colors: [theme.colors.primary, theme.colors.primaryVariant],
            startPoint: .leading, endPoint: .trailing
        )
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(g)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isInDarkTheme()
                        ? AnyShapeStyle(QuantumGlass.iridescentBorderGradient(opacity: 0.3))
                        : AnyShapeStyle(Color.white.opacity(0.25)),
                        lineWidth: 0.5
                    )
            )
            // REDUCED: Single shadow for cleaner visual hierarchy (was dual shadows)
            .shadow(
                color: theme.colors.primary.opacity(configuration.isPressed ? 0.3 : 0.4),
                radius: configuration.isPressed ? 6 : 14,
                x: 0, y: configuration.isPressed ? 2 : 7
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glass Alert / Popup

struct GlassAlertView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    var primaryButton: (text: LocalizedStringKey, action: () -> Void)? = nil
    var secondaryButton: (text: LocalizedStringKey, action: () -> Void)? = nil
    var destructiveButton: (text: LocalizedStringKey, action: () -> Void)? = nil
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    @State private var dismissWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.body.weight(.bold))
                        .foregroundColor(isInDarkTheme() ? .white : .primary)
                        .multilineTextAlignment(.center)

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(isInDarkTheme() ? QuantumGlass.messageTextDark : .secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                GlassDivider()
                    .padding(.horizontal, 0)

                VStack(spacing: 0) {
                    if let destructiveButton {
                        glassAlertButton(text: destructiveButton.text, role: .destructive, action: destructiveButton.action)
                    }
                    if let primaryButton {
                        glassAlertButton(text: primaryButton.text, role: .primary, action: primaryButton.action)
                    }
                    if let secondaryButton {
                        glassAlertButton(text: secondaryButton.text, role: .cancel, action: secondaryButton.action)
                    }
                    if primaryButton == nil && secondaryButton == nil && destructiveButton == nil {
                        glassAlertButton(text: LocalizedStringKey(NSLocalizedString("OK", comment: "alert button")), role: .cancel, action: dismiss)
                    }
                }
            }
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isInDarkTheme() ? Color(red: 13/255, green: 13/255, blue: 17/255).opacity(0.95) : Color(.systemBackground).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC").opacity(0.35), Color(hex: "#A020F0").opacity(0.25), Color(hex: "#FF007A").opacity(0.15)]
                            : [QuantumGlass.borderAlert, QuantumGlass.borderAlertSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // REDUCED: Single combined shadow for better performance (was dual shadows)
            .shadow(
                color: Color.black.opacity(isInDarkTheme() ? 0.5 : 0.12),
                radius: 24, x: 0, y: 10
            )
            .scaleEffect(appear ? 1.0 : 0.8)
            .opacity(appear ? 1.0 : 0.0)
        }
        .onAppear {
            let animation: Animation = reduceMotion ? .default : .spring(response: 0.4, dampingFraction: 0.75)
            withAnimation(animation) {
                appear = true
            }
        }
        .onDisappear {
            dismissWorkItem?.cancel()
            dismissWorkItem = nil
        }
        .popopxBranded()
    }

    private func dismiss() {
        let animation: Animation = reduceMotion ? .default : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) {
            appear = false
        }
        let workItem = DispatchWorkItem { onDismiss() }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private enum ButtonRole { case primary, cancel, destructive }

    private func glassAlertButton(text: LocalizedStringKey, role: ButtonRole, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            Text(text)
                .font(.system(.subheadline).weight(role == .primary ? .semibold : .regular))
                .foregroundColor(
                    role == .destructive
                    ? (isInDarkTheme() ? neonGradientSecondary() : QuantumColors.error)
                    : (role == .primary
                        ? (isInDarkTheme() ? darkThemeAccentColor() : Color.accentColor)
                        : (isInDarkTheme() ? .white : .primary))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(GlassAlertButtonStyle(isFirst: false, isLast: false))
    }
}

struct GlassAlertButtonStyle: ButtonStyle {
    var isFirst: Bool = false
    var isLast: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                ? (isInDarkTheme() ? darkThemeAccentColor().opacity(0.1) : Color.primary.opacity(0.06))
                : Color.clear
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Glass Confirmation Dialog

struct GlassConfirmationDialog: View {
    let title: LocalizedStringKey
    var titleVisibility: Visibility = .visible
    let buttons: [(text: LocalizedStringKey, role: ButtonRole, action: () -> Void)]
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    @State private var dismissWorkItem: DispatchWorkItem?

    enum ButtonRole { case normal, destructive, cancel }

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                if titleVisibility == .visible {
                    Text(title)
                        .font(.body.weight(.bold))
                        .foregroundColor(isInDarkTheme() ? .white : .primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    GlassDivider()
                }

                VStack(spacing: 0) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        let button = buttons[index]
                        Button {
                            button.action()
                            dismiss()
                        } label: {
                            Text(button.text)
                                .font(.system(.subheadline).weight(button.role == .cancel ? .semibold : .regular))
                                .foregroundColor(
                                    button.role == .destructive
                                    ? (isInDarkTheme() ? neonGradientSecondary() : QuantumColors.error)
                                    : (button.role == .cancel
                                        ? (isInDarkTheme() ? darkThemeAccentColor() : Color.accentColor)
                                        : (isInDarkTheme() ? .white : .primary))
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        if index < buttons.count - 1 {
                            GlassDivider().padding(.horizontal, 0)
                        }
                    }
                }
            }
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isInDarkTheme() ? Color(red: 13/255, green: 13/255, blue: 17/255).opacity(0.95) : Color(.systemBackground).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC").opacity(0.35), Color(hex: "#A020F0").opacity(0.25), Color(hex: "#FF007A").opacity(0.15)]
                            : [QuantumGlass.borderAlert, QuantumGlass.borderAlertSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // REDUCED: Single shadow for performance (was dual shadows)
            .shadow(color: Color.black.opacity(isInDarkTheme() ? 0.5 : 0.12), radius: 24, x: 0, y: 10)
            .scaleEffect(appear ? 1.0 : 0.8)
            .opacity(appear ? 1.0 : 0.0)
        }
        .onAppear {
            let animation: Animation = reduceMotion ? .default : .spring(response: 0.4, dampingFraction: 0.75)
            withAnimation(animation) {
                appear = true
            }
        }
        .onDisappear {
            dismissWorkItem?.cancel()
            dismissWorkItem = nil
        }
    }

    private func dismiss() {
        let animation: Animation = reduceMotion ? .default : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) {
            appear = false
        }
        let workItem = DispatchWorkItem { onDismiss() }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
}

// MARK: - Glass Action Sheet

struct GlassActionSheet: View {
    let title: LocalizedStringKey?
    let message: LocalizedStringKey?
    let buttons: [(text: LocalizedStringKey, role: ButtonRole, action: () -> Void)]
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    @State private var dismissWorkItem: DispatchWorkItem?

    enum ButtonRole { case normal, destructive, cancel }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appear ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 8) {
                if let title {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.body.weight(.bold))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                            .multilineTextAlignment(.center)
                        if let message {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(isInDarkTheme() ? QuantumGlass.messageTextDark : .secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    GlassDivider()
                }

                VStack(spacing: 0) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        let button = buttons[index]
                        Button {
                            button.action()
                            dismiss()
                        } label: {
                            Text(button.text)
                                .font(.system(.subheadline).weight(button.role == .cancel ? .semibold : .regular))
                                .foregroundColor(
                                    button.role == .destructive
                                    ? (isInDarkTheme() ? neonGradientSecondary() : QuantumColors.error)
                                    : (button.role == .cancel
                                        ? (isInDarkTheme() ? darkThemeAccentColor() : Color.accentColor)
                                        : (isInDarkTheme() ? .white : .primary))
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        if index < buttons.count - 1 && button.role != .cancel {
                            GlassDivider().padding(.horizontal, 0)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isInDarkTheme() ? Color(red: 13/255, green: 13/255, blue: 17/255).opacity(0.95) : Color(.systemBackground).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC").opacity(0.35), Color(hex: "#A020F0").opacity(0.25), Color(hex: "#FF007A").opacity(0.15)]
                            : [QuantumGlass.borderAlert, QuantumGlass.borderAlertSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // REDUCED: Single shadow for performance (was dual shadows)
            .shadow(color: Color.black.opacity(isInDarkTheme() ? 0.5 : 0.12), radius: 24, x: 0, y: 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .offset(y: appear ? 0 : 300)
            .opacity(appear ? 1.0 : 0.0)
        }
        .onAppear {
            let animation: Animation = reduceMotion ? .default : .spring(response: 0.5, dampingFraction: 0.8)
            withAnimation(animation) {
                appear = true
            }
        }
        .onDisappear {
            dismissWorkItem?.cancel()
            dismissWorkItem = nil
        }
    }

    private func dismiss() {
        let animation: Animation = reduceMotion ? .default : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) {
            appear = false
        }
        let workItem = DispatchWorkItem { onDismiss() }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
}

// MARK: - Glass Sheet Header

struct GlassSheetHeader: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var icon: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [Color(hex: "#00FFCC"), Color(hex: "#A020F0"), Color(hex: "#FF007A")]
                            : [.primary.opacity(0.8), .primary.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.3) : .clear, radius: 6, x: 0, y: 2)
            }
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundColor(isInDarkTheme() ? .white : .primary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(isInDarkTheme() ? QuantumGlass.subtitleTextDark : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Glass List Row

struct GlassListRow: ViewModifier {
    @EnvironmentObject var theme: AppTheme
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(isSelected ? 0.9 : 0.5)
            )
            .padding(.horizontal, 4)
    }
}

// MARK: - Glass Navigation Bar

struct GlassNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Animated Glass Transition

struct GlassAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 10)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                let animation: Animation = reduceMotion ? .default : .spring(response: 0.5, dampingFraction: 0.8).delay(delay)
                withAnimation(animation) {
                    appeared = true
                }
            }
    }
}

struct GlassDismissModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissed = false
    var isDismissed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(dismissed ? 0 : 1)
            .blur(radius: dismissed ? 10 : 0)
            .scaleEffect(dismissed ? 0.9 : 1.0)
            .onChange(of: isDismissed) {_,  newValue in
                if newValue {
                    let animation: Animation = reduceMotion ? .default : .spring(response: 0.35, dampingFraction: 0.8)
                    withAnimation(animation) {
                        dismissed = true
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground(cornerRadius: CGFloat = 10, tint: Color? = nil, opacity: Double = 0.08) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, tint: tint, opacity: opacity))
    }

    func glassSurface(cornerRadius: CGFloat = 12, tint: Color? = nil) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint))
    }

    func glassInnerHighlight(cornerRadius: CGFloat = 10) -> some View {
        modifier(GlassInnerHighlight(cornerRadius: cornerRadius))
    }

    func glassListRow(isSelected: Bool = false) -> some View {
        modifier(GlassListRow(isSelected: isSelected))
    }

    func glassNavigationBar() -> some View {
        modifier(GlassNavigationBar())
    }

    func glassAppear(delay: Double = 0) -> some View {
        modifier(GlassAppearModifier(delay: delay))
    }

    func glassButtonStyle(tint: Color? = nil, cornerRadius: CGFloat = 8) -> some View {
        buttonStyle(GlassButtonStyle(tint: tint, cornerRadius: cornerRadius))
    }

    func glassProminentButton(gradient: LinearGradient? = nil, cornerRadius: CGFloat = 8) -> some View {
        buttonStyle(GlassProminentButtonStyle(gradient: gradient, cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Capsule (for tags, badges, chips)

struct GlassCapsule: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var text: LocalizedStringKey
    var icon: String? = nil
    var isActive: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(.footnote).weight(isActive ? .semibold : .regular))
            }
            Text(text)
                .font(.subheadline)
                .fontWeight(isActive ? .semibold : .regular)
        }
        .foregroundColor(isActive ? .white : theme.colors.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .background(
            Capsule()
                .fill(isActive
                    ? AnyShapeStyle(LinearGradient(
                        colors: [theme.colors.primary, theme.colors.primaryVariant],
                        startPoint: .leading, endPoint: .trailing
                      ))
                    : AnyShapeStyle(Color.clear)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: isInDarkTheme()
                        ? [Color(hex: "#00FFCC").opacity(0.25), Color(hex: "#A020F0").opacity(0.18), Color(hex: "#FF007A").opacity(0.1)]
                        : [QuantumGlass.borderProminent, QuantumGlass.borderSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: isActive
                ? (isInDarkTheme() ? darkThemeAccentColor().opacity(0.25) : theme.colors.primary.opacity(0.3))
                : .clear,
            radius: 6, x: 0, y: 2
        )
        .scaleEffect(isActive ? 1.04 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .contentShape(Capsule())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Glass Search Field

struct GlassSearchField: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var text: String
    var placeholder: LocalizedStringKey = "Search"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.colors.secondary)
            TextField(placeholder, text: $text)
                .foregroundColor(theme.colors.onBackground)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.colors.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isInDarkTheme()
                        ? [Color(hex: "#00FFCC").opacity(0.12), Color(hex: "#A020F0").opacity(0.08), Color(hex: "#FF007A").opacity(0.04)]
                        : [Color.white.opacity(0.5), Color.white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Glass Divider

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: isInDarkTheme()
                    ? [Color.clear, Color(hex: "#00FFCC").opacity(0.1), Color(hex: "#FF007A").opacity(0.08), Color.clear]
                    : [Color.clear, Color.white.opacity(0.3), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    var title: LocalizedStringKey
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.8) : .secondary)
            }
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : .secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
