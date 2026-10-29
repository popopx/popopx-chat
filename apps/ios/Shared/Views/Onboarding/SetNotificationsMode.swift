//
//  SetNotificationsMode.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 03/07/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
//  Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PxNotifLayout {
    static let sectionSpacing: CGFloat = 20
    static let topPadding: CGFloat = 25
    static let outerPadding: CGFloat = 25
    static let buttonGroupSpacing: CGFloat = 10
    static let cardCornerRadius: CGFloat = 12
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4
    static let selectedBorderOpacity: Double = 0.6
    static let unselectedBorderOpacity: Double = 0.2
    static let selectedSecondaryOpacity: Double = 0.3
    static let unselectedSecondaryOpacity: Double = 0.1
    static let selectedShadowOpacity: Double = 0.2
    static let unselectedShadowOpacity: Double = 0.08
    static let titleShadowRadius: CGFloat = 10
    static let titleShadowOpacity: Double = 0.4
}

// MARK: - POPOPX Icon Metrics
private enum PxNotifIconMetrics {
    static let standardSize: CGFloat = 18
    static let boltWidth: CGFloat = 14
    static let boltHeight: CGFloat = 18
}

// MARK: - POPOPX Card Padding
private enum PxNotifCardPadding {
    static let vertical: CGFloat = 12
    static let trailing: CGFloat = 12
    static let leading: CGFloat = 16
    static let iconTextSpacing: CGFloat = 4
}

struct SetNotificationsMode: View {
    @Environment(\.dismiss) private var pxDismiss
    @Binding var notificationMode: NotificationsMode
    @State private var pxShowInfoSheet = false

    var body: some View {
        ZStack {
            QuantumFieldBackground()

            ScrollView {
                VStack(alignment: .center, spacing: PxNotifLayout.sectionSpacing) {
                    pxTitleView
                    pxPrivacyInfoButton
                    Spacer()
                    pxModeList
                    Spacer()
                    pxDismissSection
                }
                .padding(PxNotifLayout.outerPadding)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $pxShowInfoSheet) {
            NotificationsInfoView()
        }
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxTitleView: some View {
        Text(NSLocalizedString("Push notifications", comment: "Push notifications title"))
            .font(.system(.title).weight(.heavy))
            .padding(.top, PxNotifLayout.topPadding)
            .shadow(color: QuantumColors.accent.opacity(PxNotifLayout.titleShadowOpacity), radius: PxNotifLayout.titleShadowRadius, x: 0, y: 2)
            .foregroundStyle(LinearGradient(
                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .accessibilityLabel(Text(NSLocalizedString("Push notifications", comment: "Push notifications title")))
    }

    @ViewBuilder
    private var pxPrivacyInfoButton: some View {
        Button {
            pxShowInfoSheet = true
        } label: {
            Label(NSLocalizedString("How it affects privacy", comment: "Privacy impact label"), systemImage: "info.circle")
                .font(.headline)
                .foregroundColor(QuantumColors.accent)
        }
        .accessibilityHint(NSLocalizedString("Shows how notifications affect your privacy", comment: ""))
    }

    @ViewBuilder
    private var pxModeList: some View {
        ForEach(NotificationsMode.values) { mode in
            NtfModeSelector(mode: mode, selection: $notificationMode)
        }
    }

    @ViewBuilder
    private var pxDismissSection: some View {
        VStack(spacing: PxNotifLayout.buttonGroupSpacing) {
            Button {
                pxDismiss()
            } label: {
                Text(NSLocalizedString("OK", comment: "OK button"))
            }
            .buttonStyle(QuantumButtonStyle(primary: true))
            onboardingButtonPlaceholder()
        }
    }
}

// MARK: - POPOPX Mode Selector

struct NtfModeSelector: View {
    @EnvironmentObject var theme: AppTheme
    var mode: NotificationsMode
    @Binding var selection: NotificationsMode
    @State private var pxIsPressed = false

    private var pxIsCurrentlySelected: Bool { selection == mode }
    private var pxIconTint: Color { pxIsCurrentlySelected ? QuantumColors.accent : QuantumColors.textSecondary }
    private var pxLabelTint: Color { pxIsCurrentlySelected ? QuantumColors.textPrimary : QuantumColors.textSecondary }
    private var pxDescriptionTint: Color { Color(hex: "#887FA0") }

    private var pxIconWidth: CGFloat {
        mode.icon == "bolt" ? PxNotifIconMetrics.boltWidth : PxNotifIconMetrics.standardSize
    }

    private var pxBorderGradientColors: [Color] {
        if pxIsCurrentlySelected {
            return [QuantumColors.accent.opacity(PxNotifLayout.selectedBorderOpacity), QuantumColors.accentSecondary.opacity(PxNotifLayout.selectedSecondaryOpacity)]
        }
        return [QuantumColors.accent.opacity(PxNotifLayout.unselectedBorderOpacity), QuantumColors.accentSecondary.opacity(PxNotifLayout.unselectedSecondaryOpacity)]
    }

    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                pxIconColumn
                pxTextColumn
            }
            .padding(.vertical, PxNotifCardPadding.vertical)
            .padding(.trailing, PxNotifCardPadding.trailing)
            .padding(.leading, PxNotifCardPadding.leading)
        }
        .background(QuantumColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: PxNotifLayout.cardCornerRadius))
        .overlay(pxBorderOverlay)
        .shadow(color: QuantumColors.accent.opacity(pxIsCurrentlySelected ? PxNotifLayout.selectedShadowOpacity : PxNotifLayout.unselectedShadowOpacity), radius: PxNotifLayout.cardShadowRadius, x: 0, y: PxNotifLayout.cardShadowY)
        .frame(maxWidth: .infinity, alignment: .leading)
        ._onButtonGesture { pxIsPressed = $0; if $0 { selection = mode } } perform: {}
        .accessibilityLabel(Text(mode.label))
        .accessibilityValue(Text(ntfModeShortDescription(mode)))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - POPOPX Sub-builders

    @ViewBuilder
    private var pxIconColumn: some View {
        Image(systemName: mode.icon)
            .resizable()
            .scaledToFill()
            .frame(width: pxIconWidth, height: PxNotifIconMetrics.standardSize)
            .foregroundColor(pxIconTint)
    }

    @ViewBuilder
    private var pxTextColumn: some View {
        VStack(alignment: .leading, spacing: PxNotifCardPadding.iconTextSpacing) {
            Text(mode.label)
                .font(.headline)
                .foregroundColor(pxLabelTint)
            Text(ntfModeShortDescription(mode))
                .lineLimit(2)
                .font(.callout)
                .foregroundColor(pxDescriptionTint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pxBorderOverlay: some View {
        RoundedRectangle(cornerRadius: PxNotifLayout.cardCornerRadius)
            .strokeBorder(
                LinearGradient(
                    colors: pxBorderGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - POPOPX Notifications Info Sheet

struct NotificationsInfoView: View {
    var body: some View {
        VStack(alignment: .leading) {
            pxInfoTitle
            pxInfoScrollContent
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(ThemedBackground())
    }

    @ViewBuilder
    private var pxInfoTitle: some View {
        Text(NSLocalizedString("Notifications privacy", comment: "Notifications privacy title"))
            .font(.system(.title).weight(.heavy))
            .padding(.vertical)
            .accessibilityLabel(Text(NSLocalizedString("Notifications privacy", comment: "Notifications privacy title")))
    }

    @ViewBuilder
    private var pxInfoScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Group {
                    ForEach(NotificationsMode.values) { mode in
                        pxInfoModeBlock(mode)
                    }
                }
                .padding(.bottom)
            }
        }
    }

    private func pxInfoModeBlock(_ mode: NotificationsMode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(mode.label, systemImage: mode.icon)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(ntfModeDescription(mode))
                .lineLimit(10)
                .font(.callout)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - POPOPX Previews

struct NotificationsModeView_Previews: PreviewProvider {
    static var previews: some View {
        SetNotificationsMode(notificationMode: .constant(.instant))
            .previewEnvironment()
    }
}
