// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/13-FEATURE-COMMUNITY-PAYMENT.md
import SwiftUI

struct CommunityChannelView: View {
    let channel: CommunityChannel
    @EnvironmentObject var communityManager: CommunityManager

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            GlassDivider()
            contentSection
        }
        .padding()
        .glassBackground()
        .popopxBranded()
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(
                    colors: [QuantumColors.primaryStart, QuantumColors.primaryEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(channel.name.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(QuantumColors.textPrimary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    if channel.isPaid {
                        Text(String(format: NSLocalizedString("%d tokens", comment: "community channel price tokens"), channel.priceTokens))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accentWarm)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassBackground(cornerRadius: 12, tint: QuantumColors.accentWarm, opacity: 0.15)
                    }
                }

                Text(String(format: NSLocalizedString("%d members", comment: "community channel member count"), channel.memberCount))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }

            Spacer()
        }
    }

    private var contentSection: some View {
        VStack(spacing: 12) {
            if channel.isSubscribed {
                Text(channel.description)
                    .font(QuantumFonts.body)
                    .foregroundColor(QuantumColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundColor(QuantumColors.accent)

                    Text(NSLocalizedString("community_subscribe_to_view", comment: "Prompt to subscribe to view channel content"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    if channel.isPaid {
                        Text(String(format: NSLocalizedString("This channel requires %d tokens to join", comment: "community channel paid requirement"), channel.priceTokens))
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        communityManager.subscribe(to: channel.id)
                    }) {
                        Text(NSLocalizedString("community_subscribe", comment: "Button to subscribe to community channel"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(QuantumColors.textPrimary)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .glassProminentButton()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }
}

struct CommunityListView: View {
    @EnvironmentObject var communityManager: CommunityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Proposals section
                NavigationLink {
                    ProposalsListView()
                        .environmentObject(communityManager)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(QuantumColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("community_proposals_title", comment: "Community proposals navigation link title"))
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.textPrimary)
                            Text(NSLocalizedString("community_proposals_description", comment: "Community proposals description"))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(QuantumColors.textSecondary)
                    }
                    .padding()
                    .glassBackground()
                }

                if communityManager.channels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(QuantumColors.textSecondary)
                        Text(NSLocalizedString("community_no_channels", comment: "Empty state when no community channels exist"))
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(communityManager.channels) { channel in
                        NavigationLink {
                            CommunityChannelView(channel: channel)
                                .environmentObject(communityManager)
                        } label: {
                            HStack {
                                Image(systemName: channel.isSubscribed ? "bell.fill" : "bell.slash")
                                    .foregroundColor(QuantumColors.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.name)
                                        .font(QuantumFonts.body)
                                        .foregroundColor(QuantumColors.textPrimary)
                                    Text(String(format: NSLocalizedString("%d members", comment: "community channel member count"), channel.memberCount))
                                        .font(QuantumFonts.caption)
                                        .foregroundColor(QuantumColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(QuantumColors.textSecondary)
                            }
                            .padding()
                            .glassBackground()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("community_channels", comment: "navigation title for community channels list"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProposalsListView: View {
    @EnvironmentObject var communityManager: CommunityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if communityManager.proposals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(QuantumColors.textSecondary)
                        Text(NSLocalizedString("community_no_proposals", comment: "Empty state when no active community proposals"))
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(communityManager.proposals) { proposal in
                        NavigationLink {
                            ProposalView(proposal: proposal)
                                .environmentObject(communityManager)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(proposal.title)
                                        .font(QuantumFonts.body)
                                        .foregroundColor(QuantumColors.textPrimary)
                                    Text(String(format: NSLocalizedString("community_proposal_status", comment: "Community proposal status display"), proposal.status))
                                        .font(QuantumFonts.caption)
                                        .foregroundColor(QuantumColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(QuantumColors.textSecondary)
                            }
                            .padding()
                            .glassBackground()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("community_proposals", comment: "navigation title for community proposals list"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
