//
//  BadgesSupportPopopxView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 28.07.2026.
//  Copyright © 2026 SimpleX Chat. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct BadgesSupportPopopxView: View {
    @EnvironmentObject var theme: AppTheme
    // set true when presented as a sheet root (from the chat-list banner) — that path doesn't
    // reserve nav-bar space like a NavigationLink push does, so the title lands too close to the top
    var showsAsSheet: Bool = false
    @State private var whyBuiltActive = false
    @State private var howItWorksActive = false
    @State private var chooseLevelActive = false
    @State private var redeemCodeActive = false

    var body: some View {
        GeometryReader { g in
            VStack(alignment: .center, spacing: 16) {
                Text("Support POPOPX")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(theme.colors.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Get a badge to send larger files (2-5GB) that stay available longer (7-21 days), and to show it on your profile.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // TODO [badges] restore whyBuiltButton() when in-app purchase lands: the level screen
                // returns to the flow and howItWorksButton() moves there, leaving this one alone here.
                howItWorksButton()

                Spacer(minLength: 0)

                PhoneSupporterHero()
                    .frame(maxWidth: g.size.width * 0.55)
                    .layoutPriority(-1)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    redeemCodeButton()
                        .padding(.vertical, 10)
                    getCodeButton()
                        .frame(height: 22)
                }
                .padding(.bottom, g.safeAreaInsets.bottom == 0 ? 20 : 0)
            }
            .padding(.horizontal, 25)
            .padding(.top, showsAsSheet ? 48 : 0)
            .padding(.bottom, 20)
            // .frame(height:) not minHeight — inside the banner sheet's NavigationView minHeight
            // would let the VStack expand past the visible area and inflate the hero.
            .frame(height: g.size.height)
        }
        .frame(maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $whyBuiltActive) {
            WhyPOPOPX(onboarding: false, createProfileNavLinkActive: .constant(false))
        }
        .navigationDestination(isPresented: $howItWorksActive) {
            BadgesHowItWorksView()
                .modifier(ThemedBackground())
        }
        .navigationDestination(isPresented: $chooseLevelActive) {
            BadgesYourLevelView()
                .modifier(ThemedBackground())
        }
        .navigationDestination(isPresented: $redeemCodeActive) {
            BadgesRedeemCodeView()
                .modifier(ThemedBackground())
        }
    }

    // the in-app purchase path, kept compiling and uncalled until payments return after the MVP
    private func chooseLevelButton() -> some View {
        Button {
            chooseLevelActive = true
        } label: {
            Text("Choose your level")
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
    }

    private func whyBuiltButton() -> some View {
        Button { whyBuiltActive = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text("Why POPOPX is built.").fontWeight(.medium)
            }
            .font(.body)
        }
    }

    private func howItWorksButton() -> some View {
        Button { howItWorksActive = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text("How badges protect your privacy").fontWeight(.medium)
            }
            .font(.body)
        }
    }

    private func redeemCodeButton() -> some View {
        Button {
            redeemCodeActive = true
        } label: {
            Text("Redeem badge code")
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
    }

    private func getCodeButton() -> some View {
        Button {
            openExternalLink(URL(string: "https://popopxchat.com/badges/")!)
        } label: {
            Text("Get your code")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.primary)
        }
    }
}

struct PhoneSupporterHero: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        #if POPOPX_ASSETS
        Image(colorScheme == .light ? "phone-supporter" : "phone-supporter-light")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
        #else
        ZStack {
            let gp = PXOnboardingCard.gradientPoints(aspectRatio: 1.0, scale: colorScheme == .light ? 1.2 : 1.5)
            LinearGradient(
                stops: colorScheme == .light ? PXOnboardingCard.lightStops : PXOnboardingCard.darkStops,
                startPoint: gp.start,
                endPoint: gp.end
            )
            Image("badge-supporter")
                .resizable()
                .scaledToFit()
                .frame(width: 96)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: .infinity)
        #endif
    }
}

struct BadgesSupportPopopxView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BadgesSupportPopopxView()
        }
    }
}
