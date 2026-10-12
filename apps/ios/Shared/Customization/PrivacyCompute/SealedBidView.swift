// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/privacy-compute
import SwiftUI

struct SealedBidView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject private var mpcManager = MPCManager.shared

    @State private var bidAmount: String = ""
    @State private var revealAmount: String = ""
    @State private var revealNonce: String = ""
    @State private var savedCommitment: String = ""
    @State private var savedNonce: String = ""
    @State private var phase: BidPhase = .commit
    @State private var showResults: Bool = false

    enum BidPhase {
        case commit, reveal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Phase selector
                HStack(spacing: 0) {
                    phaseButton(title: NSLocalizedString("Commit", comment: "sealed bid commit phase button"), isActive: phase == .commit) {
                        phase = .commit
                    }
                    phaseButton(title: NSLocalizedString("Reveal", comment: "sealed bid reveal phase button"), isActive: phase == .reveal) {
                        phase = .reveal
                    }
                }
                .padding(4)
                .glassBackground(cornerRadius: 12)

                // Commit phase
                if phase == .commit {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("sealed_submit_title", comment: "Section title for submitting a sealed bid"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)

                        Text(NSLocalizedString("sealed_commit_description", comment: "Description of sealed bid commitment process"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)

                        ZStack(alignment: .leading) {
                            if bidAmount.isEmpty {
                                Text(NSLocalizedString("sealed_bid_amount_placeholder", comment: "Placeholder for bid amount input"))
                                    .foregroundColor(QuantumColors.textSecondary)
                                    .padding(.horizontal, 14)
                            }
                            TextField("", text: $bidAmount)
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.textPrimary)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .glassBackground(cornerRadius: 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                                )
                        }

                        Button {
                            guard let amount = Int(bidAmount), amount > 0 else { return }
                            let result = mpcManager.createBid(amount: amount)
                            savedCommitment = result.commitment
                            savedNonce = result.nonce
                            Task { await mpcManager.submitBid(commitment: result.commitment) }
                        } label: {
                            Text(NSLocalizedString("sealed_submit_commitment", comment: "Button to submit bid commitment"))
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .glassProminentButton()
                        }
                        .disabled(bidAmount.isEmpty || mpcManager.isLoading)
                        .opacity(bidAmount.isEmpty || mpcManager.isLoading ? 0.6 : 1.0)

                        if !savedCommitment.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(NSLocalizedString("sealed_commitment_saved", comment: "Label indicating commitment was saved"), systemImage: "lock.fill")
                                    .font(QuantumFonts.caption)
                                    .foregroundColor(QuantumColors.encryptionEnhanced)

                                Text(NSLocalizedString("sealed_nonce_instruction", comment: "Instruction to save nonce for bid reveal"))
                                    .font(QuantumFonts.encryptionLabel)
                                    .foregroundColor(QuantumColors.textSecondary)

                                Text(savedNonce)
                                    .font(QuantumFonts.encryptionLabel)
                                    .foregroundColor(QuantumColors.accent)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .glassBackground(cornerRadius: 12)
                            }
                            .padding(12)
                            .glassBackground(cornerRadius: 12)
                        }
                    }
                    .padding(16)
                    .glassBackground()
                }

                // Reveal phase
                if phase == .reveal {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("sealed_reveal_title", comment: "Section title for revealing a sealed bid"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)

                        Text(NSLocalizedString("sealed_reveal_description", comment: "Description of bid reveal process with amount and nonce"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)

                        ZStack(alignment: .leading) {
                            if revealAmount.isEmpty {
                                Text(NSLocalizedString("sealed_bid_amount_placeholder", comment: "Placeholder for bid amount input"))
                                    .foregroundColor(QuantumColors.textSecondary)
                                    .padding(.horizontal, 14)
                            }
                            TextField("", text: $revealAmount)
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.textPrimary)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .glassBackground(cornerRadius: 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                                )
                        }

                        ZStack(alignment: .leading) {
                            if revealNonce.isEmpty {
                                Text(NSLocalizedString("sealed_nonce_placeholder", comment: "Placeholder for nonce input"))
                                    .foregroundColor(QuantumColors.textSecondary)
                                    .padding(.horizontal, 14)
                            }
                            TextField("", text: $revealNonce)
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
                            guard let amount = Int(revealAmount), amount > 0, !revealNonce.isEmpty else { return }
                            Task {
                                await mpcManager.revealBid(amount: amount, nonce: revealNonce)
                            }
                        } label: {
                            Text(NSLocalizedString("sealed_reveal_bid", comment: "Button to reveal sealed bid"))
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .glassProminentButton()
                        }
                        .disabled(revealAmount.isEmpty || revealNonce.isEmpty || mpcManager.isLoading)
                        .opacity(revealAmount.isEmpty || revealNonce.isEmpty || mpcManager.isLoading ? 0.6 : 1.0)
                    }
                    .padding(16)
                    .glassBackground()
                }

                // Results
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("sealed_auction_results", comment: "Section header for auction results"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                        Spacer()
                        Button {
                            Task {
                                await mpcManager.fetchBidResults()
                                showResults = true
                            }
                        } label: {
                            Text(NSLocalizedString("sealed_refresh", comment: "Button to refresh auction results"))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassButtonStyle()
                                .clipShape(Capsule())
                        }
                    }

                    if showResults {
                        let revealedBids = mpcManager.bids.filter { $0.revealed && $0.amount != nil }
                        let highestBid = revealedBids.max(by: { ($0.amount ?? 0) < ($1.amount ?? 0) })

                        ForEach(mpcManager.bids) { bid in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(bid.bidderId.prefix(8)) + "...")
                                        .font(QuantumFonts.encryptionLabel)
                                        .foregroundColor(QuantumColors.textSecondary)

                                    if bid.revealed, let amount = bid.amount {
                                        Text(String(format: NSLocalizedString("%d tokens", comment: "sealed bid amount display"), amount))
                                            .font(QuantumFonts.body)
                                            .foregroundColor(
                                                bid.id == highestBid?.id ? QuantumColors.warning : QuantumColors.textPrimary
                                            )
                                    } else {
                                        Text(NSLocalizedString("sealed_status", comment: "Status label for a sealed (unrevealed) bid"))
                                            .font(QuantumFonts.caption)
                                            .foregroundColor(QuantumColors.textSecondary)
                                    }
                                }

                                Spacer()

                                if bid.revealed {
                                    Image(systemName: "lock.open.fill")
                                        .foregroundColor(QuantumColors.encryptionEnhanced)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(QuantumColors.accent)
                                }
                            }
                            .padding(12)
                            .background(
                                bid.id == highestBid?.id
                                ? QuantumColors.warning.opacity(0.1)
                                : Color.clear
                            )
                            .glassBackground(cornerRadius: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let winner = highestBid {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(QuantumColors.warning)
                                Text(String(format: NSLocalizedString("Winner: %@...", comment: "sealed bid winner display"), String(winner.bidderId.prefix(8))))
                                    .font(QuantumFonts.body)
                                    .foregroundColor(QuantumColors.warning)
                                Spacer()
                                Text(String(format: NSLocalizedString("%d tokens", comment: "sealed bid winner amount display"), winner.amount ?? 0))
                                    .font(QuantumFonts.body)
                                    .foregroundColor(QuantumColors.warning)
                            }
                            .padding(12)
                            .glassBackground(tint: QuantumColors.warning, opacity: 0.15)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .navigationTitle(NSLocalizedString("sealed_nav_title", comment: "Navigation title for sealed bid auction view"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }

    @ViewBuilder
    private func phaseButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(QuantumFonts.body)
                .foregroundColor(isActive ? QuantumColors.textPrimary : QuantumColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassButtonStyle()
                .cornerRadius(12)
        }
    }
}
