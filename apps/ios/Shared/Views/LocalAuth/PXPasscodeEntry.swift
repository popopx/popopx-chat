//
//  PasscodeEntry.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 10/04/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

// MARK: - POPOPX Feature
private let pxPasscodeFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_PASSCODE_FEATURE_ENABLED")

// MARK: - POPOPX Layout Metrics
private enum PXPasscodeMetrics {
    /// Ratio applied to row height for visual breathing room
    static let pxRowHeightScale: CGFloat = 0.93
    /// Maximum passcode length before digit input is disabled
    static let pxMaxPasscodeLength: Int = 16
    /// Number of grouped digits shown before a space separator
    static let pxShortGroupSize: Int = 8
    /// Fallback group size for longer passcodes
    static let pxLongGroupSize: Int = 4
    /// Vertical grid divisor for button cell width
    static let pxVertGridDivisor: CGFloat = 3
    /// Horizontal grid divisor for button cell height
    static let pxHorizGridDivisor: CGFloat = 5
    /// Multiplier for horizontal grid total width
    static let pxHorizWidthMul: CGFloat = 4
    /// Multiplier for horizontal grid total height
    static let pxHorizHeightMul: CGFloat = 3
    /// Multiplier for vertical grid total height
    static let pxVertHeightMul: CGFloat = 4
    /// Bottom padding below the password text field
    static let pxPasswordBottomPad: CGFloat = 6
    /// Font size for the passcode display text
    static let pxPasscodeDisplayFontSize: CGFloat = 24
    /// Fixed frame height for the passcode text row
    static let pxPasscodeTextRowHeight: CGFloat = 36
    /// Corner radius for the background circle behind each digit
    static let pxDigitBgCornerRadius: CGFloat = 2
}

struct PasscodeEntry: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    var width: CGFloat
    var height: CGFloat
    @Binding var password: String
    @State private var showPassword = false

    var body: some View {
        VStack {
            pxPasswordTextField()
                .padding(.bottom, PXPasscodeMetrics.pxPasswordBottomPad)
            if width < height * 2 / 3 {
                pxVerticalGrid()
            } else {
                pxHorizontalGrid()
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX: password display text with toggle
    private func pxPasswordTextField() -> some View {
        Text(
            password == ""
            ? " "
            : pxSplitPasscode()
        )
        .font(showPassword ? .system(size: PXPasscodeMetrics.pxPasscodeDisplayFontSize, weight: .medium) : .system(size: PXPasscodeMetrics.pxPasscodeDisplayFontSize))
        .onTapGesture {
            showPassword = !showPassword
        }
        .frame(height: PXPasscodeMetrics.pxPasscodeTextRowHeight)
    }

    /// Splits the passcode into groups with space separators, masking digits when hidden
    private func pxSplitPasscode() -> String {
        logger.debug("PX: [splitPassword] password length=\(password.count)")
        let pxGroupLen = password.count < PXPasscodeMetrics.pxShortGroupSize ? PXPasscodeMetrics.pxShortGroupSize : PXPasscodeMetrics.pxLongGroupSize
        return password.enumerated().reduce("") { pxAccum, pxChar in
            pxAccum
            + (showPassword ? String(pxChar.element) : "●")
            + ((pxChar.offset + 1) % pxGroupLen == 0 ? " " : "")
        }
    }

    // MARK: - POPOPX: vertical layout for narrow screens
    private func pxVerticalGrid() -> some View {
        let pxCellSize = width / PXPasscodeMetrics.pxVertGridDivisor
        return VStack(spacing: 0) {
            pxVertRow(pxCellSize, 1, 2, 3)
            GlassDivider()
            pxVertRow(pxCellSize, 4, 5, 6)
            GlassDivider()
            pxVertRow(pxCellSize, 7, 8, 9)
            GlassDivider()
            pxBottomButtonRow(pxCellSize)
        }
        .frame(width: width, height: pxCellSize * PXPasscodeMetrics.pxVertHeightMul * PXPasscodeMetrics.pxRowHeightScale)
    }

    /// Bottom row with clear, zero, and delete buttons for vertical layout
    private func pxBottomButtonRow(_ pxCellSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            pxActionButton(pxCellSize, image: "multiply") {
                password = ""
            }
            GlassDivider()
            pxDigitButton(pxCellSize, 0)
            GlassDivider()
            pxActionButton(pxCellSize, image: "delete.backward") {
                pxDeleteLastDigit()
            }
        }
        .frame(height: pxCellSize)
    }

    /// Removes the last digit from the passcode if non-empty
    private func pxDeleteLastDigit() {
        if password != "" { password.removeLast() }
    }

    // MARK: - POPOPX: horizontal layout for wide screens
    private func pxHorizontalGrid() -> some View {
        let pxCellSize = height / PXPasscodeMetrics.pxHorizGridDivisor
        return VStack(spacing: 0) {
            pxHorizRow(pxCellSize, 1, 2, 3) {
                pxActionButton(pxCellSize, image: "multiply") {
                    password = ""
                }
            }
            GlassDivider()
            pxHorizRow(pxCellSize, 4, 5, 6) {
                pxDigitButton(pxCellSize, 0)
            }
            GlassDivider()
            pxHorizRow(pxCellSize, 7, 8, 9) {
                pxActionButton(pxCellSize, image: "delete.backward") {
                    pxDeleteLastDigit()
                }
            }
        }
        .frame(width: pxCellSize * PXPasscodeMetrics.pxHorizWidthMul, height: pxCellSize * PXPasscodeMetrics.pxHorizHeightMul * PXPasscodeMetrics.pxRowHeightScale)
    }

    private func pxVertRow(_ pxSize: CGFloat, _ pxD1: Int, _ pxD2: Int, _ pxD3: Int) -> some View {
        HStack(spacing: 0) {
            pxDigitButton(pxSize, pxD1)
            GlassDivider()
            pxDigitButton(pxSize, pxD2)
            GlassDivider()
            pxDigitButton(pxSize, pxD3)
        }
        .frame(height: pxSize * PXPasscodeMetrics.pxRowHeightScale)
    }

    private func pxHorizRow<V: View>(_ pxSize: CGFloat, _ pxD1: Int, _ pxD2: Int, _ pxD3: Int, _ pxButton: @escaping () -> V) -> some View {
        HStack(spacing: 0) {
            pxVertRow(pxSize, pxD1, pxD2, pxD3)
            GlassDivider()
            pxButton()
        }
        .frame(height: pxSize * PXPasscodeMetrics.pxRowHeightScale)
    }

    // MARK: - POPOPX: individual button builders
    private func pxDigitButton(_ pxSize: CGFloat, _ pxDigit: Int) -> some View {
        let pxLabel = String(describing: pxDigit)
        return pxButtonTemplate(pxSize) {
            if password.count < PXPasscodeMetrics.pxMaxPasscodeLength {
                password = password + pxLabel
            }
        } label: {
            Text(pxLabel).font(.title2.weight(.medium))
        }
        .disabled(password.count >= PXPasscodeMetrics.pxMaxPasscodeLength)
    }

    private func pxActionButton(_ pxSize: CGFloat, image pxImageName: String, action pxAction: @escaping () -> Void) -> some View {
        pxButtonTemplate(pxSize, action: pxAction) {
            Image(systemName: pxImageName)
        }
    }

    private func pxButtonTemplate<V: View>(_ pxSize: CGFloat, action pxAction: @escaping () -> Void, label pxLabel: () -> V) -> some View {
        let pxBtnHeight = pxSize * PXPasscodeMetrics.pxRowHeightScale
        return Button(action: pxAction) {
            ZStack {
                Circle()
                    .frame(width: pxBtnHeight, height: pxBtnHeight)
                    .foregroundColor(AppTheme.shared.colors.background)
                pxLabel()
            }
        }
        .foregroundColor(theme.colors.secondary)
        .frame(width: pxSize, height: pxBtnHeight)
    }
}

struct PasscodeEntry_Previews: PreviewProvider {
    static var previews: some View {
        PasscodeEntry(width: 800, height: 420, password: Binding.constant(""))
    }
}

// MARK: - POPOPX
extension PasscodeEntry {
    var pxComponentTag: String { "PX_PASSCODE_ENTRY" }
    static let pxPasswordFrameHeight: CGFloat = PXPasscodeMetrics.pxPasscodeTextRowHeight
    static let pxDigitFontSize: CGFloat = PXPasscodeMetrics.pxPasscodeDisplayFontSize
}
