// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/13-FEATURE-COMMUNITY-PAYMENT.md
import SwiftUI

struct ProposalView: View {
    let proposal: CommunityProposal
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var timeRemaining: String = ""
    @State private var countdownTimer: Timer?
    @State private var votedOption: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            descriptionSection
            votingSection
            countdownSection
        }
        .padding()
        .glassBackground()
        .onAppear {
            updateCountdown()
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                countdownTimer?.invalidate()
                countdownTimer = nil
            case .active:
                if countdownTimer == nil {
                    updateCountdown()
                }
            default:
                break
            }
        }
        .popopxBranded()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(proposal.title)
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)

            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(proposal.status == "active" ? QuantumColors.success : QuantumColors.textTertiary)
                Text(proposal.status.capitalized)
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }
        }
    }

    private var descriptionSection: some View {
        Text(proposal.description)
            .font(QuantumFonts.body)
            .foregroundColor(QuantumColors.textSecondary)
    }

    private var votingSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(proposal.options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    communityManager.vote(proposalId: proposal.id, optionIndex: index)
                    votedOption = index
                }) {
                    HStack {
                        Text(option)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)

                        Spacer()

                        if votedOption == index {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(QuantumColors.success)
                        }

                        Text("\(index < proposal.votes.count ? proposal.votes[index] : 0)")
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accent)
                    }
                    .padding()
                    .glassBackground(cornerRadius: 16)
                    .overlay(
                        GeometryReader { geometry in
                            let totalVotes = max(proposal.votes.reduce(0, +), 1)
                            let voteCount = index < proposal.votes.count ? proposal.votes[index] : 0
                            let percentage = CGFloat(voteCount) / CGFloat(totalVotes)
                            Rectangle()
                                .fill(QuantumColors.accent.opacity(0.3))
                                .frame(width: geometry.size.width * percentage)
                                .cornerRadius(12)
                        }
                    )
                }
                .disabled(proposal.status != "active")
            }
        }
    }

    private var countdownSection: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(QuantumColors.warning)
            Text(timeRemaining)
                .font(QuantumFonts.caption)
                .foregroundColor(QuantumColors.textSecondary)
        }
    }

    private func updateCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak communityManager] timer in
            let now = Date()
            let timeInterval = proposal.votingEndsAt.timeIntervalSince(now)

            if timeInterval <= 0 {
                timeRemaining = NSLocalizedString("Voting ended", comment: "proposal voting ended")
                Task { @MainActor in
                    if let communityManager,
                       let idx = communityManager.proposals.firstIndex(where: { $0.id == proposal.id }) {
                        communityManager.proposals[idx].status = "expired"
                    }
                }
                timer.invalidate()
                return
            }

            let days = Int(timeInterval) / 86400
            let hours = (Int(timeInterval) % 86400) / 3600
            let minutes = (Int(timeInterval) % 3600) / 60
            let seconds = Int(timeInterval) % 60

            if days > 0 {
                timeRemaining = String(format: NSLocalizedString("%dd %dh remaining", comment: "proposal voting days remaining"), days, hours)
            } else if hours > 0 {
                timeRemaining = String(format: NSLocalizedString("%dh %dm remaining", comment: "proposal voting hours remaining"), hours, minutes)
            } else {
                timeRemaining = String(format: NSLocalizedString("%dm %ds remaining", comment: "proposal voting minutes remaining"), minutes, seconds)
            }
        }
        if let timer = countdownTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}
