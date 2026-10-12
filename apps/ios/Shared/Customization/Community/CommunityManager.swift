// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/13-FEATURE-COMMUNITY-PAYMENT.md
import Foundation

struct CommunityChannel: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var ownerUserId: String
    var memberCount: Int
    var isPaid: Bool
    var priceTokens: Int
    var isSubscribed: Bool
    var isDAO: Bool
}

struct CommunityProposal: Identifiable, Codable {
    let id: String
    var channelId: String
    var title: String
    var description: String
    var options: [String]
    var votes: [Int]
    var votingEndsAt: Date
    var status: String
}

@MainActor
class CommunityManager: ObservableObject {
    static let shared = CommunityManager()

    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.popopxchat.popopx") ?? .standard
    private static let votedProposalIdsKey = "communityVotedProposalIds"
    private static let channelsKey = "communityChannels"
    private static let proposalsKey = "communityProposals"

    @Published var channels: [CommunityChannel] = [] {
        didSet { saveChannels() }
    }
    @Published var proposals: [CommunityProposal] = [] {
        didSet { saveProposals() }
    }
    private var votedProposalIds: Set<String> = []

    init() {
        let stored = Self.appGroupDefaults.stringArray(forKey: Self.votedProposalIdsKey) ?? []
        votedProposalIds = Set(stored)
        if let data = Self.appGroupDefaults.data(forKey: Self.channelsKey),
           let value = try? JSONDecoder().decode([CommunityChannel].self, from: data) {
            channels = value
        }
        if let data = Self.appGroupDefaults.data(forKey: Self.proposalsKey),
           let value = try? JSONDecoder().decode([CommunityProposal].self, from: data) {
            proposals = value
        }
        pruneVotedProposalIds()
    }

    /// Remove voted proposal IDs for proposals no longer in the active proposals list.
    private func pruneVotedProposalIds() {
        let activeIds = Set(proposals.map { $0.id })
        let pruned = votedProposalIds.intersection(activeIds)
        if pruned.count != votedProposalIds.count {
            votedProposalIds = pruned
            Self.appGroupDefaults.set(Array(votedProposalIds), forKey: Self.votedProposalIdsKey)
        }
    }

    // MARK: - Persistence

    private func saveChannels() {
        if let data = try? JSONEncoder().encode(channels) {
            Self.appGroupDefaults.set(data, forKey: Self.channelsKey)
        }
    }

    private func saveProposals() {
        if let data = try? JSONEncoder().encode(proposals) {
            Self.appGroupDefaults.set(data, forKey: Self.proposalsKey)
        }
    }

    func createChannel(name: String, description: String, isPaid: Bool, priceTokens: Int) {
        let channel = CommunityChannel(
            id: UUID().uuidString, name: name, description: description,
            ownerUserId: "self", memberCount: 1, isPaid: isPaid,
            priceTokens: priceTokens, isSubscribed: true, isDAO: false
        )
        channels.append(channel)
    }

    func subscribe(to channelId: String) {
        if let idx = channels.firstIndex(where: { $0.id == channelId }) {
            guard !channels[idx].isSubscribed else { return }
            channels[idx].isSubscribed = true
            channels[idx].memberCount += 1
        }
    }

    func createProposal(channelId: String, title: String, options: [String]) {
        let proposal = CommunityProposal(
            id: UUID().uuidString, channelId: channelId, title: title,
            description: "", options: options, votes: Array(repeating: 0, count: options.count),
            votingEndsAt: Date().addingTimeInterval(7 * 86400), status: "active"
        )
        proposals.append(proposal)
    }

    func vote(proposalId: String, optionIndex: Int) {
        guard !votedProposalIds.contains(proposalId) else { return }
        guard let idx = proposals.firstIndex(where: { $0.id == proposalId }) else { return }
        guard proposals[idx].status == "active" else { return }
        guard proposals[idx].votingEndsAt > Date() else { return }
        guard optionIndex >= 0, optionIndex < proposals[idx].votes.count else { return }
        proposals[idx].votes[optionIndex] += 1
        votedProposalIds.insert(proposalId)
        Self.appGroupDefaults.set(Array(votedProposalIds), forKey: Self.votedProposalIdsKey)
    }
}
