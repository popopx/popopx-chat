//
//  PXConnectBannerCard.swift
//  POPOPX (iOS)
//
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Banner Layout Config
private enum PXBannerConfig {
    static let imageRatio: CGFloat = 800 / 505
    static let closeSize: CGFloat = 30
    static let closeBackgroundOpacity: Double = 0.08
    static let borderLineWidth: CGFloat = 0.75
    static let cardCornerRadius: CGFloat = 12
    static let hStackSpacing: CGFloat = 2
    static let vStackSpacing: CGFloat = 3
    static let shadowRadius: CGFloat = 8
    static let shadowYOffset: CGFloat = 4
    static let lightShadowOpacity: Double = 0.08
    static let darkShadowOpacity: Double = 0.15
    static let iconLabelSpacing: CGFloat = 8
    static let labelHeight: CGFloat = 20
    static let labelVerticalPadding: CGFloat = 8
    static let fallbackIconSize: CGFloat = 40
    static let lightScale: CGFloat = 1.2
    static let darkScale: CGFloat = 1.5
}

// MARK: - POPOPX Banner View Model
private struct PXBannerCardViewModel {
    let colorScheme: ColorScheme
    let theme: AppTheme

    var pxShadowColor: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PXBannerConfig.darkShadowOpacity) : Color.black.opacity(PXBannerConfig.lightShadowOpacity)
    }

    var pxBorderGradientColors: [Color] {
        isInDarkTheme()
            ? [darkThemeAccentColor().opacity(0.35), neonGradientSecondary().opacity(0.2)]
            : [Color.white.opacity(0.3), Color.white.opacity(0.1)]
    }

    var pxGradientScale: CGFloat {
        colorScheme == .light ? PXBannerConfig.lightScale : PXBannerConfig.darkScale
    }
}

private let bannerImageRatio: CGFloat = PXBannerConfig.imageRatio

struct ConnectBannerCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    @AppStorage(DEFAULT_ADDRESS_CREATION_CARD_SHOWN) private var addressCreationCardShown = false
    @State private var showNewLink = false
    @State private var showPasteLink = false

    var body: some View {
        pxCardContainer
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxCardContainer: some View {
        let vm = PXBannerCardViewModel(colorScheme: colorScheme, theme: theme)
        VStack(alignment: .trailing, spacing: PXBannerConfig.vStackSpacing) {
            pxCloseButton
            pxBannerRow(vm: vm)
        }
        .shadow(color: vm.pxShadowColor, radius: PXBannerConfig.shadowRadius, x: 0, y: PXBannerConfig.shadowYOffset)
        .sheet(isPresented: $showNewLink) {
            NavigationStack {
                PXNewChat(selection: .invite, hidePicker: true)
                    .modifier(ThemedBackground(grouped: true, glass: true))
            }
        }
        .sheet(isPresented: $showPasteLink) {
            NavigationStack {
                PXNewChat(selection: .connect, showQRCodeScanner: true, hidePicker: true)
                    .modifier(ThemedBackground(grouped: true, glass: true))
            }
        }
        .accessibilityElement(children: .contain)
        .popopxBranded()
    }

    @ViewBuilder
    private var pxCloseButton: some View {
        Button {
            withAnimation { addressCreationCardShown = true }
        } label: {
            Image(systemName: "multiply")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.colors.secondary)
                .frame(width: PXBannerConfig.closeSize, height: PXBannerConfig.closeSize)
                .background(theme.colors.onBackground.opacity(PXBannerConfig.closeBackgroundOpacity), in: Circle())
        }
        .accessibilityLabel(Text(NSLocalizedString("a11y_dismiss_connect_banner", comment: "")))
    }

    @ViewBuilder
    private func pxBannerRow(vm: PXBannerCardViewModel) -> some View {
        HStack(spacing: PXBannerConfig.hStackSpacing) {
            pxBannerHalf(
                imageName: "banner-create-link",
                icon: "link.badge.plus",
                title: LocalizedStringKey(NSLocalizedString("connect_banner_new_link", comment: "Connect banner new link title")),
                action: {
                    showPasteLink = false
                    showNewLink = true
                }
            )
            pxBannerHalf(
                imageName: "banner-paste-link",
                icon: "qrcode.viewfinder",
                title: LocalizedStringKey(NSLocalizedString("connect_banner_paste_scan", comment: "Connect banner paste/scan title")),
                action: {
                    showNewLink = false
                    showPasteLink = true
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: PXBannerConfig.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PXBannerConfig.cardCornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: vm.pxBorderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PXBannerConfig.borderLineWidth
                )
        )
    }

    @ViewBuilder
    private func pxBannerHalf(imageName: String, icon: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                #if POPOPX_ASSETS
                Image(colorScheme == .light ? imageName : "\(imageName)-light")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                #else
                pxGradientFallback(icon: icon)
                #endif
                HStack(spacing: PXBannerConfig.iconLabelSpacing) {
                    #if POPOPX_ASSETS
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundColor(theme.colors.primary)
                    #endif
                    Text(title)
                        .font(.footnote)
                        .foregroundColor(theme.colors.onBackground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(height: PXBannerConfig.labelHeight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PXBannerConfig.labelVerticalPadding)
                .background(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private func pxGradientFallback(icon: String) -> some View {
        let gp = PXOnboardingCard.gradientPoints(
            aspectRatio: 1 / bannerImageRatio,
            scale: colorScheme == .light ? PXBannerConfig.lightScale : PXBannerConfig.darkScale
        )
        ZStack {
            LinearGradient(
                stops: colorScheme == .light ? PXOnboardingCard.lightStops : PXOnboardingCard.darkStops,
                startPoint: gp.start,
                endPoint: gp.end
            )
            Image(systemName: icon)
                .font(.system(size: PXBannerConfig.fallbackIconSize))
                .foregroundColor(theme.colors.primary)
        }
        .aspectRatio(bannerImageRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - POPOPX
extension ConnectBannerCard {
    static let pxComponentTag: String = "PX_CONNECT_BANNER_CARD"
    static let pxCloseButtonSize: CGFloat = PXBannerConfig.closeSize
    static let pxCloseBackgroundOpacity: Double = PXBannerConfig.closeBackgroundOpacity
    static let pxBorderLineWidth: CGFloat = PXBannerConfig.borderLineWidth

    var pxCardAccent: Color { .accentColor }
    var pxCardCornerRadius: CGFloat { PXBannerConfig.cardCornerRadius }
    var pxImageRatio: CGFloat { PXBannerConfig.imageRatio }
}
