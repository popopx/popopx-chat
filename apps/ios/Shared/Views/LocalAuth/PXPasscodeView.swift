//
//  PXPasscodeView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 11/04/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

// MARK: - POPOPX Configuration
private enum PXPasscodeConfig {
    static let pxHorizontalPadding: CGFloat = 40
    static let pxVerticalSpacing: CGFloat = 8
    static let pxButtonSpacing: CGFloat = 48
    static let pxVerticalPadding: CGFloat = 32
    static let pxTopPadding: CGFloat = 8
    static let pxReasonTopPadding: CGFloat = 4
    static let pxCircleLargeSize: CGFloat = 350
    static let pxCircleSmallSize: CGFloat = 300
    static let pxCircleLargeBlur: CGFloat = 80
    static let pxCircleSmallBlur: CGFloat = 60
    static let pxCircleLargeOpacity: Double = 0.04
    static let pxCircleSmallOpacity: Double = 0.03
    static let pxTitleShadowRadius: CGFloat = 10
    static let pxTitleShadowOpacity: Double = 0.4
    static let pxComponentId = "PX_PASSCODE_VIEW"
}

// MARK: - POPOPX View Model
private struct PXPasscodeLayout {
    let isVertical: Bool
    let width: CGFloat
    let height: CGFloat

    init(geometry: GeometryProxy) {
        self.width = geometry.size.width
        self.height = geometry.size.height
        self.isVertical = geometry.size.width < geometry.size.height * 2 / 3
    }

    var pxButtonsMaxHeight: CGFloat { height / 5 * 3 * 0.97 }
}

struct PasscodeView: View {
    @Binding var passcode: String
    var title: LocalizedStringKey
    var reason: String? = nil
    var submitLabel: LocalizedStringKey
    var submitEnabled: ((String) -> Bool)?
    @Binding var buttonsEnabled: Bool

    var submit: () -> Void
    var cancel: () -> Void

    var body: some View {
        GeometryReader { g in
            let layout = PXPasscodeLayout(geometry: g)
            if layout.isVertical {
                pxVerticalLayout(layout)
            } else {
                pxHorizontalLayout(layout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PXPasscodeConfig.pxHorizontalPadding)
        .background(pxBackgroundLayer)
        .popopxBranded()
    }

    // MARK: - POPOPX Layout Builders

    private func pxVerticalLayout(_ layout: PXPasscodeLayout) -> some View {
        VStack(spacing: PXPasscodeConfig.pxVerticalSpacing) {
            pxPasscodeEntry(layout)
            Spacer()
            HStack(spacing: PXPasscodeConfig.pxButtonSpacing) {
                pxButtons
            }
        }
        .padding(.vertical, PXPasscodeConfig.pxVerticalPadding)
    }

    private func pxHorizontalLayout(_ layout: PXPasscodeLayout) -> some View {
        HStack(alignment: .bottom, spacing: PXPasscodeConfig.pxButtonSpacing) {
            VStack(spacing: PXPasscodeConfig.pxVerticalSpacing) {
                pxPasscodeEntry(layout)
            }
            VStack(spacing: PXPasscodeConfig.pxButtonSpacing) {
                pxButtons
            }
            .frame(maxHeight: layout.pxButtonsMaxHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    @ViewBuilder private func pxPasscodeEntry(_ layout: PXPasscodeLayout) -> some View {
        Text(title)
            .font(.title.weight(.heavy))
            .bold()
            .foregroundStyle(pxTitleGradient)
            .shadow(color: pxShadowColor, radius: PXPasscodeConfig.pxTitleShadowRadius, x: 0, y: 2)
            .padding(.top, PXPasscodeConfig.pxTopPadding)
            .accessibilityLabel(Text(verbatim: NSLocalizedString("a11y_passcode_title", comment: "")))
        if let reason = reason {
            Text(reason)
                .font(.system(.callout))
                .padding(.top, PXPasscodeConfig.pxReasonTopPadding)
        }
        Spacer()
        PasscodeEntry(width: layout.width, height: layout.height, password: $passcode)
    }

    @ViewBuilder private var pxButtons: some View {
        Button(action: cancel) {
            Label(NSLocalizedString("cancel_button", comment: "Cancel button"), systemImage: "multiply")
        }
        .disabled(!buttonsEnabled)
        .accessibilityLabel(Text(verbatim: NSLocalizedString("a11y_cancel_passcode", comment: "")))
        Button(action: submit) {
            Label(submitLabel, systemImage: "checkmark")
        }
        .disabled(submitEnabled?(passcode) == false || passcode.count < 4 || !buttonsEnabled)
        .accessibilityLabel(Text(verbatim: NSLocalizedString("a11y_submit_passcode", comment: "")))
    }

    // MARK: - POPOPX Visual Helpers

    private var pxTitleGradient: LinearGradient {
        let pxColors: [Color] = isInDarkTheme()
            ? [darkThemeAccentColor(), neonGradientSecondary()]
            : [Color.primary, Color.secondary]
        return LinearGradient(colors: pxColors, startPoint: .leading, endPoint: .trailing)
    }

    private var pxShadowColor: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PXPasscodeConfig.pxTitleShadowOpacity) : .clear
    }

    private var pxBackgroundLayer: some View {
        ZStack {
            AppTheme.shared.colors.background
            if isInDarkTheme() {
                Circle()
                    .fill(darkThemeAccentColor().opacity(PXPasscodeConfig.pxCircleLargeOpacity))
                    .frame(width: PXPasscodeConfig.pxCircleLargeSize, height: PXPasscodeConfig.pxCircleLargeSize)
                    .offset(x: -80, y: -200)
                    .blur(radius: PXPasscodeConfig.pxCircleLargeBlur)
                Circle()
                    .fill(neonGradientSecondary().opacity(PXPasscodeConfig.pxCircleSmallOpacity))
                    .frame(width: PXPasscodeConfig.pxCircleSmallSize, height: PXPasscodeConfig.pxCircleSmallSize)
                    .offset(x: 100, y: 200)
                    .blur(radius: PXPasscodeConfig.pxCircleSmallBlur)
            }
        }
    }
}

struct PasscodeViewView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodeView(
            passcode: Binding.constant(""),
            title: "Enter Passcode",
            reason: "Unlock app",
            submitLabel: "Submit",
            buttonsEnabled: Binding.constant(true),
            submit: {},
            cancel: {}
        )
    }
}

// MARK: - POPOPX
extension PasscodeView {
    var pxComponentTag: String { PXPasscodeConfig.pxComponentId }
    var pxPasscodeLength: Int { 6 }
}
