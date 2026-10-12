// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/privacy-compute
import SwiftUI

struct SecureVotingView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject private var mpcManager = MPCManager.shared
    @State private var newVoteOptions: String = ""
    @State private var showResults: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sealed Bid Auction section
                NavigationLink {
                    SealedBidView()
                        .environmentObject(theme)
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(QuantumColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("voting_sealed_auction_title", comment: "Title for sealed-bid auction navigation link"))
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.textPrimary)
                            Text(NSLocalizedString("voting_sealed_auction_description", comment: "Description of sealed-bid auction mechanism"))
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

                // Create vote section
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("voting_create_vote", comment: "Section header for creating a new vote"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    ZStack(alignment: .leading) {
                        if newVoteOptions.isEmpty {
                            Text(NSLocalizedString("voting_options_placeholder", comment: "Placeholder showing format for vote options"))
                                .foregroundColor(QuantumColors.textSecondary)
                                .padding(.horizontal, 14)
                        }
                        TextField("", text: $newVoteOptions)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassBackground(cornerRadius: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                            )
                    }

                    Button {
                        let options = newVoteOptions
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        guard options.count >= 2 else { return }
                        Task { await mpcManager.createVote(options: options) }
                    } label: {
                        Text(NSLocalizedString("voting_start_vote", comment: "Button to start a new vote"))
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .glassProminentButton()
                    }
                }
                .padding(16)
                .glassBackground()

                // Voting options
                if !mpcManager.voteOptions.isEmpty && !mpcManager.hasVoted {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("voting_cast_your_vote", comment: "Section header for casting votes"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)

                        ForEach(mpcManager.voteOptions) { option in
                            Button {
                                Task { await mpcManager.castVote(optionId: option.id) }
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .font(QuantumFonts.body)
                                        .foregroundColor(QuantumColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "hand.tap")
                                        .foregroundColor(QuantumColors.accent)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .glassBackground(cornerRadius: 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(mpcManager.isLoading)
                        }
                    }
                    .padding(16)
                    .glassBackground()
                }

                // Results section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("voting_results", comment: "Section header for voting results"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                        Spacer()
                        Button {
                            Task {
                                await mpcManager.tallyVotes()
                                showResults = true
                            }
                        } label: {
                            Text(NSLocalizedString("voting_tally", comment: "Button to tally votes"))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassButtonStyle()
                                .clipShape(Capsule())
                        }
                    }

                    if showResults && !mpcManager.voteResults.isEmpty {
                        let maxCount = mpcManager.voteResults.map(\.count).max() ?? 1

                        ForEach(mpcManager.voteResults) { result in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(result.label)
                                        .font(QuantumFonts.body)
                                        .foregroundColor(QuantumColors.textPrimary)
                                    Spacer()
                                    Text("\(result.count)")
                                        .font(QuantumFonts.caption)
                                        .foregroundColor(QuantumColors.textSecondary)
                                        .accessibilityLabel(String(format: NSLocalizedString("voting_vote_count", comment: "Vote count for a result option"), result.count))
                                }

                                GeometryReader { geo in
                                    let fraction = maxCount > 0 ? CGFloat(result.count) / CGFloat(maxCount) : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [QuantumColors.primaryStart, QuantumColors.primaryEnd],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * fraction)
                                        .animation(.easeInOut(duration: 0.5), value: result.count)
                                }
                                .frame(height: 8)
                                .glassBackground(cornerRadius: 4)
                            }
                        }
                    }
                }
                .padding(16)
                .glassBackground()

                if let error = mpcManager.errorMessage {
                    Text(error)
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.error)
                        .padding(.horizontal, 16)
                }
            }
            .padding(16)
        }
        .navigationTitle(NSLocalizedString("secure_voting", comment: "navigation title for secure voting view"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }
}
