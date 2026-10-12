// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/privacy-compute
// NOTE: Despite the "MPC" naming, this implements centralized "Private Voting" and sealed-bid auctions,
// not true Multi-Party Computation. All voting and bidding logic is server-authoritative.
import Foundation
import CryptoKit
import Security
import OSLog

struct VoteOption: Identifiable, Codable {
    let id: UUID
    let label: String
    var count: Int

    init(id: UUID = UUID(), label: String, count: Int = 0) {
        self.id = id
        self.label = label
        self.count = count
    }
}

struct SealedBid: Identifiable, Codable {
    let id: UUID
    let bidderId: String
    let commitment: String
    var amount: Int?
    var nonce: String?
    var revealed: Bool

    init(id: UUID = UUID(), bidderId: String, commitment: String, amount: Int? = nil, nonce: String? = nil, revealed: Bool = false) {
        self.id = id
        self.bidderId = bidderId
        self.commitment = commitment
        self.amount = amount
        self.nonce = nonce
        self.revealed = revealed
    }
}

@MainActor
/// Manages private voting and sealed-bid auction features.
/// This is a centralized implementation (server-authoritative), not true MPC.
class MPCManager: ObservableObject {
    static let shared = MPCManager()

    @Published var voteOptions: [VoteOption] = []
    @Published var voteResults: [VoteOption] = []
    @Published var bids: [SealedBid] = []
    @Published var hasVoted: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Voting

    func createVote(options: [String]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await ServerAPI.shared.post(
                "privacy/vote/create",
                body: ["options": options]
            )
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let opts = json["options"] as? [[String: Any]] {
                voteOptions = opts.compactMap { dict in
                    guard let idStr = dict["id"] as? String,
                          let id = UUID(uuidString: idStr),
                          let label = dict["label"] as? String else { return nil }
                    return VoteOption(id: id, label: label)
                }
            }
        } catch {
            os_log(.error, "MPCManager: createVote failed: %{public}@", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func castVote(optionId: UUID) async {
        guard !hasVoted else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let _ = try await ServerAPI.shared.post(
                "privacy/vote/cast",
                body: ["option_id": optionId.uuidString]
            )
            hasVoted = true
        } catch {
            os_log(.error, "MPCManager: castVote failed: %{public}@", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func tallyVotes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await ServerAPI.shared.post(
                "privacy/vote/tally",
                body: [:]
            )
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                voteResults = results.compactMap { dict in
                    guard let idStr = dict["id"] as? String,
                          let id = UUID(uuidString: idStr),
                          let label = dict["label"] as? String,
                          let count = dict["count"] as? Int else { return nil }
                    return VoteOption(id: id, label: label, count: count)
                }
            }
        } catch {
            os_log(.error, "MPCManager: tallyVotes failed: %{public}@", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sealed Bids

    func createBid(amount: Int) -> (commitment: String, nonce: String) {
        var nonceBytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, nonceBytes.count, &nonceBytes) == errSecSuccess else {
            return ("", "")
        }
        let nonce = nonceBytes.map { String(format: "%02x", $0) }.joined()
        let payload = "\(amount):\(nonce)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        let commitment = digest.map { String(format: "%02x", $0) }.joined()
        return (commitment, nonce)
    }

    func submitBid(commitment: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let bidderId = EntitlementStore.shared.deviceId

            let _ = try await ServerAPI.shared.post(
                "privacy/bid/commit",
                body: [
                    "bidder_id": bidderId,
                    "commitment": commitment
                ]
            )
        } catch {
            os_log(.error, "MPCManager: submitBid failed: %{public}@", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func revealBid(amount: Int, nonce: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let bidderId = EntitlementStore.shared.deviceId

            let _ = try await ServerAPI.shared.post(
                "privacy/bid/reveal",
                body: [
                    "bidder_id": bidderId,
                    "amount": amount,
                    "nonce": nonce
                ]
            )
        } catch {
            os_log(.error, "MPCManager: revealBid failed: %{public}@", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func fetchBidResults() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await ServerAPI.shared.post(
                "privacy/bid/results",
                body: [:]
            )
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let bidList = json["bids"] as? [[String: Any]] {
                bids = bidList.compactMap { dict in
                    guard let bidderId = dict["bidder_id"] as? String,
                          let commitment = dict["commitment"] as? String else { return nil }
                    let revealed = dict["revealed"] as? Bool ?? false
                    let amount = dict["amount"] as? Int
                    let nonce = dict["nonce"] as? String
                    return SealedBid(
                        bidderId: bidderId,
                        commitment: commitment,
                        amount: amount,
                        nonce: nonce,
                        revealed: revealed
                    )
                }

                // Verify commitments for revealed bids
                for bid in bids where bid.revealed {
                    guard let amount = bid.amount, let nonce = bid.nonce else { continue }
                    let payload = "\(amount):\(nonce)"
                    let digest = SHA256.hash(data: Data(payload.utf8))
                    let computed = digest.map { String(format: "%02x", $0) }.joined()
                    if computed != bid.commitment {
                        os_log(.error, "MPCManager: commitment mismatch for bid %@: expected %@, got %@", bid.bidderId, bid.commitment, computed)
                    }
                }
            }
        } catch {
            os_log(.error, "MPCManager: fetchBidResults failed: %{public}@", error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
}
