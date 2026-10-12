//
//  HowItWorks.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 08/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
//  Spec: spec/client/navigation.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

// MARK: - POPOPX Layout Configuration
private enum PxHowItWorksLayout {
    static let contentSpacing: CGFloat = 16
    static let onboardingPadding: CGFloat = 25
    static let settingsPadding: CGFloat = 16
    static let scrollBottomPadding: CGFloat = 16
}

// MARK: - POPOPX Content Model
private struct PxManifestoParagraph {
    let pxLocalizedKey: String
    let pxComment: String
}

private enum PxManifestoContent {
    static let pxTitle = PxManifestoParagraph(
        pxLocalizedKey: "You were born without an account",
        pxComment: "WhyPOPOPX title"
    )

    static let pxParagraphs: [PxManifestoParagraph] = [
        PxManifestoParagraph(
            pxLocalizedKey: "Nobody tracked your conversations. No one drew a map of where you'd been. Privacy was never a feature - it was the way of life.",
            pxComment: "WhyPOPOPX paragraph 1"
        ),
        PxManifestoParagraph(
            pxLocalizedKey: "Then we moved online, and every platform asked for a piece of you - your name, your number, your friends. We accepted that the price of talking to others is letting someone know who we talk to. Every generation, people and tech, had it this way - telephone, email, messengers, social media. It seemed the only way possible.",
            pxComment: "WhyPOPOPX paragraph 2"
        ),
        PxManifestoParagraph(
            pxLocalizedKey: "There is another way. A network with no phone numbers. No usernames. No accounts. No user identities of any kind. A network that connects people and carries encrypted messages without knowing who is connected.",
            pxComment: "WhyPOPOPX paragraph 3"
        ),
        PxManifestoParagraph(
            pxLocalizedKey: "Not a better lock on someone else's door. Not a nicer landlord that respects your privacy, but still keeps the record of all visitors. You are not a guest. You are home. No king can enter it - you are sovereign.",
            pxComment: "WhyPOPOPX paragraph 4"
        ),
        PxManifestoParagraph(
            pxLocalizedKey: "Your conversations belong to you, as it had always been before the Internet. The network is not a place you visit. It is a place you create and own. And nobody can take it from you, whether you make it private or public.",
            pxComment: "WhyPOPOPX paragraph 5"
        ),
        PxManifestoParagraph(
            pxLocalizedKey: "The oldest human freedom - to speak to another person without being watched - built on infrastructure that cannot betray it.",
            pxComment: "WhyPOPOPX paragraph 6"
        ),
        PxManifestoParagraph(
            pxLocalizedKey: "Because we destroyed the power to know who you are. So that your power can never be taken.",
            pxComment: "WhyPOPOPX paragraph 7"
        ),
    ]

    static let pxClosing = PxManifestoParagraph(
        pxLocalizedKey: "Be free in your network.",
        pxComment: "WhyPOPOPX closing"
    )
}

// MARK: - POPOPX Main View

struct WhyPOPOPX: View {
    @Environment(\.dismiss) private var pxDismiss: DismissAction
    @EnvironmentObject var m: ChatModel
    var onboarding: Bool
    @Binding var createProfileNavLinkActive: Bool

    private var pxCurrentPadding: CGFloat {
        onboarding ? PxHowItWorksLayout.onboardingPadding : PxHowItWorksLayout.settingsPadding
    }

    var body: some View {
        VStack(alignment: .leading) {
            pxScrollContent
            Spacer()
            if onboarding {
                pxCreateProfileAction
            }
        }
        .padding(pxCurrentPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(ThemedBackground())
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PxHowItWorksLayout.contentSpacing) {
                pxManifestoTitle
                ForEach(Array(PxManifestoContent.pxParagraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(NSLocalizedString(paragraph.pxLocalizedKey, comment: paragraph.pxComment))
                }
                pxManifestoClosing
            }
        }
        .padding(.bottom, PxHowItWorksLayout.scrollBottomPadding)
    }

    @ViewBuilder
    private var pxManifestoTitle: some View {
        Text(NSLocalizedString(PxManifestoContent.pxTitle.pxLocalizedKey, comment: PxManifestoContent.pxTitle.pxComment))
            .font(.headline.weight(.bold))
            .padding(.top)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var pxManifestoClosing: some View {
        Text(NSLocalizedString(PxManifestoContent.pxClosing.pxLocalizedKey, comment: PxManifestoContent.pxClosing.pxComment))
            .accessibilityLabel(Text(NSLocalizedString(PxManifestoContent.pxClosing.pxLocalizedKey, comment: PxManifestoContent.pxClosing.pxComment)))
    }

    @ViewBuilder
    private var pxCreateProfileAction: some View {
        Button {
            pxDismiss()
            createProfileNavLinkActive = true
        } label: {
            Text(NSLocalizedString("Get started", comment: "Get started button"))
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
        .accessibilityLabel(Text(NSLocalizedString("Get started", comment: "Get started button")))
    }
}

// MARK: - POPOPX Previews

struct WhyPOPOPX_Previews: PreviewProvider {
    static var previews: some View {
        WhyPOPOPX(
            onboarding: true,
            createProfileNavLinkActive: Binding.constant(false)
        )
    }
}
