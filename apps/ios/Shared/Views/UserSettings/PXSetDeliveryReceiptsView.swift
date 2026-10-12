//
//  PXSetDeliveryReceiptsView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 12/07/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout & Theme Config
private enum PXDeliveryReceiptsConfig {
    static let titleSize: CGFloat = 28
    static let titleWeight: Font.Weight = .semibold
    static let titleVerticalPadding: CGFloat = 8
    static let enableShadowRadius: CGFloat = 8
    static let enableShadowYOffset: CGFloat = 4
    static let enableShadowOpacity: Double = 0.4
    static let outerSpacing: CGFloat = 16
    static let skipButtonSpacing: CGFloat = 8
    static let hintFont: Font = .footnote
    static let chevronIcon: String = "chevron.right"
}

// MARK: - POPOPX View Model
private struct PXDeliveryReceiptsViewModel {
    let userCount: Int
    let hasCurrentUser: Bool

    var multiProfileExplanation: String {
        userCount > 1
            ? String(localized: "Sending delivery receipts will be enabled for all contacts in all visible chat profiles.", comment: "Explanation text when multiple chat profiles exist")
            : String(localized: "Sending delivery receipts will be enabled for all contacts.", comment: "Explanation text when only one chat profile exists")
    }

    var canEnable: Bool { hasCurrentUser }
}

struct SetDeliveryReceiptsView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        pxMainContainer
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxMainContainer: some View {
        VStack(spacing: PXDeliveryReceiptsConfig.outerSpacing) {
            pxTitleSection
            Spacer()
            pxEnableButton
            pxExplanationSection
            Spacer()
            pxSkipSection
        }
        .padding()
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(ThemedBackground(grouped: true))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("a11y_delivery_receipts_setup_screen", comment: "")))
        .popopxBranded()
    }

    @ViewBuilder
    private var pxTitleSection: some View {
        Text(String(localized: "Delivery receipts!", comment: "Title for delivery receipts setup screen"))
            .font(.system(size: PXDeliveryReceiptsConfig.titleSize, weight: PXDeliveryReceiptsConfig.titleWeight))
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            .padding(.vertical, PXDeliveryReceiptsConfig.titleVerticalPadding)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var pxEnableButton: some View {
        Button(String(localized: "Enable", comment: "Button to enable delivery receipts feature")) {
            pxHandleEnableAction()
        }
        .font(.largeTitle)
        .shadow(
            color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXDeliveryReceiptsConfig.enableShadowOpacity) : .clear,
            radius: PXDeliveryReceiptsConfig.enableShadowRadius,
            x: 0,
            y: PXDeliveryReceiptsConfig.enableShadowYOffset
        )
        .accessibilityLabel(Text(NSLocalizedString("a11y_enable_delivery_receipts", comment: "")))
        .accessibilityHint(Text(NSLocalizedString("a11y_activates_delivery_receipts_all_contacts", comment: "")))
    }

    @ViewBuilder
    private var pxExplanationSection: some View {
        let vm = PXDeliveryReceiptsViewModel(userCount: m.users.count, hasCurrentUser: m.currentUser != nil)
        Text(vm.multiProfileExplanation)
            .multilineTextAlignment(.center)
            .accessibilityLabel(Text(vm.multiProfileExplanation))
    }

    @ViewBuilder
    private var pxSkipSection: some View {
        VStack(spacing: PXDeliveryReceiptsConfig.skipButtonSpacing) {
            Button {
                pxShowSkipAlert()
            } label: {
                HStack {
                    Text(String(localized: "Don't enable", comment: "Button to decline enabling delivery receipts now"))
                    Image(systemName: PXDeliveryReceiptsConfig.chevronIcon)
                }
            }
            .accessibilityLabel(Text(NSLocalizedString("a11y_skip_enable_delivery_receipts", comment: "")))
            Text(String(localized: "You can enable later via Settings", comment: "Hint text showing where to enable feature later"))
                .font(PXDeliveryReceiptsConfig.hintFont)
        }
    }

    // MARK: - POPOPX Actions

    private func pxHandleEnableAction() {
        Task {
            do {
                if let currentUser = m.currentUser {
                    try await apiSetAllContactReceipts(enable: true)
                    await MainActor.run {
                        var updatedUser = currentUser
                        updatedUser.sendRcptsContacts = true
                        m.updateUser(updatedUser)
                        m.setDeliveryReceipts = false
                        privacyDeliveryReceiptsSet.set(true)
                    }
                    do {
                        let users = try await listUsersAsync()
                        await MainActor.run { m.users = users }
                    } catch let error {
                        logger.debug("listUsers error: \(responseError(error))")
                    }
                }
            } catch let error {
                AlertManager.shared.showAlert(Alert(
                    title: Text(String(localized: "Error enabling delivery receipts!", comment: "Error alert title when delivery receipts setup fails")),
                    message: Text(String(localized: "Error: \(responseError(error))", comment: "Error alert message with technical details"))
                ))
                await MainActor.run {
                    m.setDeliveryReceipts = false
                }
            }
        }
    }

    private func pxShowSkipAlert() {
        AlertManager.shared.showAlert(Alert(
            title: Text(String(localized: "Delivery receipts are disabled!", comment: "Alert title confirming delivery receipts remain disabled")),
            message: Text(String(localized: "You can enable them later via app Your privacy settings.", comment: "Alert message explaining how to enable later")),
            primaryButton: .default(Text(String(localized: "Don't show again", comment: "Button to dismiss and not show this prompt again"))) {
                m.setDeliveryReceipts = false
                privacyDeliveryReceiptsSet.set(true)
            },
            secondaryButton: .default(Text(String(localized: "Ok", comment: "Standard OK button label"))) {
                m.setDeliveryReceipts = false
            }
        ))
    }
}

struct SetDeliveryReceiptsView_Previews: PreviewProvider {
    static var previews: some View {
        SetDeliveryReceiptsView()
    }
}

// MARK: - POPOPX
extension SetDeliveryReceiptsView {
    var pxComponentTag: String { "PX_SET_DELIVERY_RECEIPTS" }
    var pxReceiptIconName: String { "checkmark.message" }
    var pxAccentColor: Color { isInDarkTheme() ? darkThemeAccentColor() : .accentColor }
    var pxTitleFont: Font { .system(size: PXDeliveryReceiptsConfig.titleSize, weight: PXDeliveryReceiptsConfig.titleWeight) }
}
