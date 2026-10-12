//
//  OnboardingCards.swift
//  POPOPX (iOS)
//
//  Created by POPOPX Team on 06.04.2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxOnboardingFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_ONBOARDING_FEATURE_ENABLED")

// MARK: - POPOPX Layout & Style Configuration
private enum PXOnboardingCardConfig {
    static let cornerRadius: CGFloat = 22
    static let labelPadding: CGFloat = 18
    static let gradientAngleDegrees: Double = 82.0
    static let minScaleFactor: CGFloat = 0.72
    static let cardPadding: CGFloat = 22
    static let cardSpacing: CGFloat = 18
    static let lightScaleFactor: Double = 1.2
    static let darkScaleFactor: Double = 1.5
    static let subtitleOpacity: Double = 0.7
    static let darkModeSubtitleOpacity: Double = 0.78
    static let imageFontRatio: Double = 0.25
}

// MARK: - POPOPX View Model
struct PXOnboardingCardViewModel {
    let colorScheme: ColorScheme
    let imageName: String
    let icon: String
    let labelHeightRatio: CGFloat

    var pxImageHeightRatio: CGFloat { max(1 - labelHeightRatio, 0.01) }
    var pxUsesLightPalette: Bool { colorScheme == .light }
    var pxGradientScale: CGFloat { pxUsesLightPalette ? CGFloat(PXOnboardingCardConfig.lightScaleFactor) : CGFloat(PXOnboardingCardConfig.darkScaleFactor) }

    var pxImageName: String {
        pxUsesLightPalette ? imageName : "\(imageName)-light"
    }
}

// MARK: - Card component

struct PXOnboardingCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    let imageName: String
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let labelHeightRatio: CGFloat
    let action: () -> Void

    static let lightStops: [Gradient.Stop] = [
        .init(color: oklch(0.9219, 0.0431, 249.4), location: 0.0),
        .init(color: oklch(0.9198, 0.0471, 240.7), location: 0.5),
        .init(color: oklch(0.9772, 0.0358, 196.6), location: 0.9),
        .init(color: oklch(0.9829, 0.0104, 70.0), location: 0.95),
        .init(color: oklch(0.9886, 0.0272, 99.1), location: 1.0)
    ]

    static let darkStops: [Gradient.Stop] = [
        .init(color: oklch(0.08, 0.06, 270), location: 0.4),
        .init(color: oklch(0.25, 0.12, 260), location: 0.72),
        .init(color: oklch(0.82, 0.14, 195), location: 0.9),
        .init(color: oklch(0.65, 0.22, 350), location: 0.95),
        .init(color: oklch(0.88, 0.16, 90), location: 1.0)
    ]

    static let gradientAngle: Double = PXOnboardingCardConfig.gradientAngleDegrees * .pi / 180.0

    static func gradientPoints(aspectRatio: CGFloat, scale: CGFloat) -> (start: UnitPoint, end: UnitPoint) {
        let r = Double(aspectRatio)
        let s = Double(scale)
        let dx = cos(gradientAngle)
        let dy = -sin(gradientAngle) / r
        let dLenSq = dx * dx + dy * dy
        let projections = [
            -0.5 * dx + (-0.5) * dy,
             0.5 * dx + (-0.5) * dy,
            -0.5 * dx + 0.5 * dy,
             0.5 * dx + 0.5 * dy
        ]
        guard let tMin = projections.min(), let tMax = projections.max() else { return (start: .top, end: .bottom) }
        let startX = 0.5 + tMin * dx / dLenSq
        let startY = 0.5 + tMin * dy / dLenSq
        let endX = 0.5 + tMax * dx / dLenSq
        let endY = 0.5 + tMax * dy / dLenSq
        return (
            start: .init(x: 0.5 + (startX - 0.5) * s, y: 0.5 + (startY - 0.5) * s),
            end: .init(x: 0.5 + (endX - 0.5) * s, y: 0.5 + (endY - 0.5) * s)
        )
    }

    private var pxViewModel: PXOnboardingCardViewModel {
        PXOnboardingCardViewModel(
            colorScheme: colorScheme,
            imageName: imageName,
            icon: icon,
            labelHeightRatio: labelHeightRatio
        )
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let labelHeight = geo.size.width * labelHeightRatio
                let imageHeight = max(geo.size.height - labelHeight, 1)
                let imageAspect = imageHeight / geo.size.width
                let gp = Self.gradientPoints(
                    aspectRatio: imageAspect,
                    scale: pxViewModel.pxGradientScale
                )
                VStack(spacing: 0) {
                    pxCardImageLayer(imageHeight: imageHeight, gradientPoints: gp)
                    pxLabelRow(height: labelHeight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PXOnboardingCardConfig.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private func pxCardImageLayer(imageHeight: CGFloat, gradientPoints gp: (start: UnitPoint, end: UnitPoint)) -> some View {
        ZStack {
            LinearGradient(
                stops: colorScheme == .light ? Self.lightStops : Self.darkStops,
                startPoint: gp.start,
                endPoint: gp.end
            )
            #if POPOPX_ASSETS
            Image(pxViewModel.pxImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            #else
            Image(systemName: icon)
                .font(.system(size: imageHeight * PXOnboardingCardConfig.imageFontRatio))
                .foregroundColor(theme.colors.primary)
            #endif
        }
        .frame(height: imageHeight)
    }

    @ViewBuilder
    private func pxLabelRow(height: CGFloat) -> some View {
        VStack {
            HStack {
                #if POPOPX_ASSETS
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(theme.colors.primary)
                #endif
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.onBackground)
                    .lineLimit(1)
                    .minimumScaleFactor(PXOnboardingCardConfig.minScaleFactor)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(
                        theme.colors.onBackground.opacity(
                            isInDarkTheme()
                                ? PXOnboardingCardConfig.darkModeSubtitleOpacity
                                : PXOnboardingCardConfig.subtitleOpacity
                        )
                    )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, PXOnboardingCardConfig.labelPadding)
        .background(ToolbarMaterial.material(toolbarMaterial))
    }
}

// MARK: - Onboarding pager

private let backButtonHeight: CGFloat = 44

// MARK: - POPOPX Pager View Model
struct PXOnboardingPagerViewModel {
    let hasUserAddress: Bool
    let currentPage: Int

    var pxIsOnInitialPage: Bool { currentPage == 0 }
    var pxAddressTitleKey: LocalizedStringKey {
        hasUserAddress
            ? LocalizedStringKey(NSLocalizedString("onboarding_your_public_address", comment: "Onboarding card title"))
            : LocalizedStringKey(NSLocalizedString("onboarding_create_public_address", comment: "Onboarding card title"))
    }
}

struct ConnectOnboardingView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var currentPage = 0
    @State private var showConnectViaLink = false
    @State private var showInviteSomeone = false
    @State private var showCreateAddress = false

    private var pxPagerVM: PXOnboardingPagerViewModel {
        PXOnboardingPagerViewModel(
            hasUserAddress: m.userAddress != nil,
            currentPage: currentPage
        )
    }

    var body: some View {
        TabView(selection: $currentPage) {
            pxTalkToSomeonePage.tag(0)
            pxConnectWithSomeonePage.tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sheet(isPresented: $showConnectViaLink) {
            NavigationStack {
                PXNewChat(selection: .connect, showQRCodeScanner: true, onboarding: true)
                    .modifier(ThemedBackground(grouped: true))
            }
        }
        .sheet(isPresented: $showInviteSomeone) {
            NavigationStack {
                PXNewChat(selection: .invite, onboarding: true)
                    .modifier(ThemedBackground(grouped: true))
            }
        }
        .sheet(isPresented: $showCreateAddress) {
            NavigationStack {
                UserAddressView(autoCreate: true, onboarding: true)
                    .modifier(ThemedBackground(grouped: true))
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func pxCardPair<C1: View, C2: View>(
        _ geo: GeometryProxy,
        @ViewBuilder card1: () -> C1,
        @ViewBuilder card2: () -> C2
    ) -> some View {
        let pxPadding: CGFloat = PXOnboardingCardConfig.cardPadding
        let pxSpacing: CGFloat = PXOnboardingCardConfig.cardSpacing
        let isLandscape = verticalSizeClass == .compact
        let cardWidth = isLandscape
            ? (geo.size.width - pxPadding * 2 - pxSpacing) / 2
            : geo.size.width - pxPadding * 2
        let maxCardHeight = cardWidth * 0.75

        if isLandscape {
            HStack(spacing: pxSpacing) {
                card1().frame(maxHeight: maxCardHeight)
                card2().frame(maxHeight: maxCardHeight)
            }
            .padding(.horizontal, pxPadding)
        } else {
            VStack(spacing: pxSpacing) {
                card1().frame(maxHeight: maxCardHeight)
                card2().frame(maxHeight: maxCardHeight)
            }
            .padding(.horizontal, pxPadding)
        }
    }

    // MARK: Screen 1

    @ViewBuilder
    private func pxPageHeader(_ title: LocalizedStringKey, showBack: Bool) -> some View {
        let isLandscape = verticalSizeClass == .compact
        let titleView = Text(title)
            .font(.largeTitle)
            .bold()
            .lineLimit(1)
            .minimumScaleFactor(0.67)
            .frame(maxWidth: .infinity, alignment: .center)
        if isLandscape {
            ZStack(alignment: .leading) {
                if showBack { pxBackButton }
                titleView
            }
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 0) {
                if showBack {
                    pxBackButton.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Color.clear.frame(height: backButtonHeight)
                }
                titleView
            }
            .padding(.horizontal, 16)
        }
    }

    private var pxBackButton: some View {
        Button {
            withAnimation { currentPage = 0 }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text(LocalizedStringKey(NSLocalizedString("onboarding_back_button", comment: "Onboarding back button")))
            }
        }
        .frame(height: backButtonHeight)
        .accessibilityLabel(Text(NSLocalizedString("onboarding_back_button", comment: "Onboarding back button")))
    }

    // MARK: Screen 1

    private var pxTalkToSomeonePage: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                pxPageHeader(
                    LocalizedStringKey(NSLocalizedString("onboarding_talk_to_someone", comment: "Onboarding page header")),
                    showBack: false
                )

                Spacer(minLength: 16)

                pxCardPair(geo) {
                    PXOnboardingCard(
                        imageName: "card-let-someone-connect-to-you-alpha",
                        icon: "link.badge.plus",
                        title: LocalizedStringKey(NSLocalizedString("onboarding_let_someone_connect", comment: "Onboarding card title")),
                        labelHeightRatio: 0.132,
                        action: { withAnimation { currentPage = 1 } }
                    )
                } card2: {
                    PXOnboardingCard(
                        imageName: "card-connect-via-link-alpha",
                        icon: "qrcode.viewfinder",
                        title: LocalizedStringKey(NSLocalizedString("onboarding_connect_via_link", comment: "Onboarding card title")),
                        labelHeightRatio: 0.132,
                        action: { pxDismissAllSheets(except: .connectViaLink) }
                    )
                }

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Screen 2

    private var pxConnectWithSomeonePage: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                pxPageHeader(
                    LocalizedStringKey(NSLocalizedString("onboarding_create_your_link", comment: "Onboarding page header")),
                    showBack: true
                )

                Spacer(minLength: 16)

                pxCardPair(geo) {
                    PXOnboardingCard(
                        imageName: "card-invite-someone-privately-alpha",
                        icon: "link.badge.plus",
                        title: LocalizedStringKey(NSLocalizedString("onboarding_invite_privately", comment: "Onboarding card title")),
                        subtitle: LocalizedStringKey(NSLocalizedString("onboarding_invite_privately_subtitle", comment: "Onboarding card subtitle")),
                        labelHeightRatio: 0.195,
                        action: { pxDismissAllSheets(except: .inviteSomeone) }
                    )
                } card2: {
                    PXOnboardingCard(
                        imageName: "card-create-your-public-address-alpha",
                        icon: "qrcode",
                        title: pxPagerVM.pxAddressTitleKey,
                        subtitle: LocalizedStringKey(NSLocalizedString("onboarding_for_anyone_to_reach", comment: "Onboarding card subtitle")),
                        labelHeightRatio: 0.195,
                        action: { pxDismissAllSheets(except: .createAddress) }
                    )
                }

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - POPOPX Sheet Management

    private enum PXActiveSheet {
        case connectViaLink, inviteSomeone, createAddress
    }

    private func pxDismissAllSheets(except target: PXActiveSheet) {
        switch target {
        case .connectViaLink:
            showInviteSomeone = false; showCreateAddress = false; showConnectViaLink = true
        case .inviteSomeone:
            showConnectViaLink = false; showCreateAddress = false; showInviteSomeone = true
        case .createAddress:
            showConnectViaLink = false; showInviteSomeone = false; showCreateAddress = true
        }
    }
}

// MARK: - POPOPX
extension PXOnboardingCard {
    static let pxComponentTag: String = "PXOnboardingCards"
    static let pxCardCornerRadius: CGFloat = PXOnboardingCardConfig.cornerRadius
    static let pxCardPadding: CGFloat = PXOnboardingCardConfig.cardPadding
    static let pxCardSpacing: CGFloat = PXOnboardingCardConfig.cardSpacing
}
