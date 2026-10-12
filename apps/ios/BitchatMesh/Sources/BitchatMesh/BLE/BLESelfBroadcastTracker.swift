// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import BitFoundation
import Foundation

struct BLESelfBroadcastTracker {
    private struct Entry {
        let messageID: String
        let sentAt: Date
    }

    private var entriesByDedupID: [String: Entry] = [:]

    var isEmpty: Bool {
        entriesByDedupID.isEmpty
    }

    var count: Int {
        entriesByDedupID.count
    }

    mutating func record(messageID: String, packet: BitchatPacket, sentAt: Date) {
        entriesByDedupID[Self.dedupID(for: packet)] = Entry(messageID: messageID, sentAt: sentAt)
    }

    mutating func takeMessageID(for packet: BitchatPacket) -> String? {
        entriesByDedupID.removeValue(forKey: Self.dedupID(for: packet))?.messageID
    }

    mutating func prune(before cutoff: Date) {
        guard !entriesByDedupID.isEmpty else { return }
        entriesByDedupID = entriesByDedupID.filter { cutoff <= $0.value.sentAt }
    }

    mutating func removeAll() {
        entriesByDedupID.removeAll()
    }

    static func dedupID(for packet: BitchatPacket) -> String {
        "\(packet.senderID.hexEncodedString())-\(packet.timestamp)-\(packet.type)"
    }
}
