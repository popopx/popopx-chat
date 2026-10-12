// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

/// A single item in the global broadcast square feed.
struct BroadcastItem: Identifiable, Equatable {
    let id: String
    let content: String
    let pubkey: String
    let createdAt: Int64
    let expiresAt: Int64

    /// Seconds remaining until the event expires (NIP-40).
    var timeRemaining: TimeInterval {
        max(0, TimeInterval(expiresAt) - Date().timeIntervalSince1970)
    }

    var isExpired: Bool {
        timeRemaining <= 0
    }

    /// Human-readable countdown for the card UI.
    var formattedTimeRemaining: String {
        let totalSeconds = Int(timeRemaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func == (lhs: BroadcastItem, rhs: BroadcastItem) -> Bool {
        lhs.id == rhs.id
    }
}
