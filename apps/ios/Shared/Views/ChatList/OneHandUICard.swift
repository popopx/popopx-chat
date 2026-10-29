//
//  OneHandUICard.swift
//  POPOPX (iOS)
//
//  Created by EP on 06/08/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PxOneHandMetrics {
    static let outerSpacing: CGFloat = 2
    static let innerSpacing: CGFloat = 8
    static let horizontalPad: CGFloat = 16
    static let verticalPad: CGFloat = 4
    static let dismissBtnSide: CGFloat = 44
    static let dismissTrailPad: CGFloat = 12
    static let capsuleBorderWidth: CGFloat = 0.5
    static let shadowRadius: CGFloat = 4
    static let shadowYOffset: CGFloat = 2
    static let dismissIcon: Font = .title3
}

// MARK: - POPOPX Theme-aware Colors
private enum PxOneHandPalette {
    static let lightSegmentFill = Color(uiColor: .systemGray5)
    static let darkBorderPrimaryOpacity: Double = 0.3
    static let darkBorderSecondaryOpacity: Double = 0.15
    static let lightBorderPrimaryOpacity: Double = 0.3
    static let lightBorderSecondaryOpacity: Double = 0.1
    static let darkShadowOpacity: Double = 0.06
    static let selectedBgDarkOpacity: Double = 0.1
}

// MARK: - POPOPX Segment Descriptor
private struct PxToolbarSegment {
    let pxSymbolName: String
    let pxTitle: LocalizedStringKey
    let pxIsActive: Bool
    let pxOnTap: () -> Void
}

struct OneHandUICard: View {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(GROUP_DEFAULT_ONE_HAND_UI, store: groupDefaults) private var oneHandUI = true
    @AppStorage(DEFAULT_ONE_HAND_UI_CARD_SHOWN) private var oneHandUICardShown = false
    @AppStorage(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    @State private var pxPresentDismissAlert = false

    var body: some View {
        pxOuterContainer
            .clipShape(Capsule())
            .overlay(pxCapsuleStroke)
            .shadow(color: pxShadowTint, radius: PxOneHandMetrics.shadowRadius, x: 0, y: PxOneHandMetrics.shadowYOffset)
            .alert(isPresented: $pxPresentDismissAlert) {
                pxAlertDefinition
            }
            .popopxBranded()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(NSLocalizedString("Toolbar position", comment: "One hand UI card accessibility")))
    }

    // MARK: - POPOPX Outer Container

    @ViewBuilder
    private var pxOuterContainer: some View {
        HStack(spacing: PxOneHandMetrics.outerSpacing) {
            pxBottomBarSegment
            pxTopBarSegmentWithDismiss
        }
    }

    // MARK: - POPOPX Segments

    @ViewBuilder
    private var pxBottomBarSegment: some View {
        pxSegmentView(
            PxToolbarSegment(
                pxSymbolName: "platter.filled.bottom.and.arrow.down.iphone",
                pxTitle: LocalizedStringKey("Bottom bar"),
                pxIsActive: oneHandUI,
                pxOnTap: { withAnimation { oneHandUI = true } }
            )
        )
        .background { if oneHandUI { pxActiveSegmentFill } }
        .background(ToolbarMaterial.material(toolbarMaterial))
    }

    @ViewBuilder
    private var pxTopBarSegmentWithDismiss: some View {
        ZStack(alignment: .trailing) {
            pxSegmentView(
                PxToolbarSegment(
                    pxSymbolName: "platter.filled.top.and.arrow.up.iphone",
                    pxTitle: LocalizedStringKey("Top bar"),
                    pxIsActive: !oneHandUI,
                    pxOnTap: { withAnimation { oneHandUI = false } }
                )
            )
            pxCloseButton
                .frame(width: PxOneHandMetrics.dismissBtnSide, height: PxOneHandMetrics.dismissBtnSide)
                .contentShape(Circle())
                .padding(.trailing, PxOneHandMetrics.dismissTrailPad)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if !oneHandUI { pxInactiveSegmentFill } }
        .background(ToolbarMaterial.material(toolbarMaterial))
    }

    // MARK: - POPOPX Segment Builder

    @ViewBuilder
    private func pxSegmentView(_ descriptor: PxToolbarSegment) -> some View {
        HStack(spacing: PxOneHandMetrics.innerSpacing) {
            Image(systemName: descriptor.pxSymbolName)
                .font(.body)
                .foregroundColor(descriptor.pxIsActive ? theme.colors.secondary : theme.colors.primary)
            Text(descriptor.pxTitle)
                .font(.subheadline)
                .foregroundColor(descriptor.pxIsActive ? theme.colors.secondary : theme.colors.onBackground)
        }
        .padding(.horizontal, PxOneHandMetrics.horizontalPad)
        .padding(.vertical, PxOneHandMetrics.verticalPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(descriptor.pxIsActive ? .isSelected : [])
        .accessibilityLabel(pxSegmentAccessibilityText(descriptor))
        .onTapGesture { descriptor.pxOnTap() }
    }

    // MARK: - POPOPX Close Button

    @ViewBuilder
    private var pxCloseButton: some View {
        Button {
            pxPresentDismissAlert = true
        } label: {
            Image(systemName: "multiply.circle.fill")
                .font(PxOneHandMetrics.dismissIcon)
                .foregroundColor(theme.colors.secondary)
        }
        .accessibilityLabel(Text(NSLocalizedString("Dismiss", comment: "Dismiss one hand UI card")))
    }

    // MARK: - POPOPX Alert Definition

    private var pxAlertDefinition: Alert {
        Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("one_hand_toolbar_title", comment: "One hand UI toolbar alert title"))),
            message: Text(LocalizedStringKey(NSLocalizedString("one_hand_toolbar_message", comment: "One hand UI toolbar alert message"))),
            dismissButton: .default(Text(LocalizedStringKey(NSLocalizedString("common_ok", comment: "")))) {
                withAnimation {
                    oneHandUICardShown = true
                }
            }
        )
    }

    // MARK: - POPOPX Appearance Helpers

    private var pxActiveSegmentFill: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PxOneHandPalette.selectedBgDarkOpacity) : PxOneHandPalette.lightSegmentFill
    }

    private var pxInactiveSegmentFill: Color {
        isInDarkTheme() ? neonGradientSecondary().opacity(PxOneHandPalette.selectedBgDarkOpacity) : PxOneHandPalette.lightSegmentFill
    }

    private var pxCapsuleStroke: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: pxCapsuleGradientStops,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: PxOneHandMetrics.capsuleBorderWidth
            )
    }

    private var pxCapsuleGradientStops: [Color] {
        if isInDarkTheme() {
            return [
                darkThemeAccentColor().opacity(PxOneHandPalette.darkBorderPrimaryOpacity),
                neonGradientSecondary().opacity(PxOneHandPalette.darkBorderSecondaryOpacity)
            ]
        }
        return [
            Color.white.opacity(PxOneHandPalette.lightBorderPrimaryOpacity),
            Color.white.opacity(PxOneHandPalette.lightBorderSecondaryOpacity)
        ]
    }

    private var pxShadowTint: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PxOneHandPalette.darkShadowOpacity) : .clear
    }

    private func pxSegmentAccessibilityText(_ descriptor: PxToolbarSegment) -> Text {
        let stateKey = descriptor.pxIsActive
            ? NSLocalizedString("selected_state", comment: "Accessibility label for selected state")
            : NSLocalizedString("not_selected_state", comment: "Accessibility label for not selected state")
        return Text(verbatim: "\(stateKey) \(descriptor.pxTitle)")
    }
}

// MARK: - POPOPX Previews

#Preview {
    OneHandUICard()
}
