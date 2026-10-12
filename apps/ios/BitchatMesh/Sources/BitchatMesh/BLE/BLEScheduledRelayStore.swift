// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

struct BLEScheduledRelayStore {
    private var relays: [String: DispatchWorkItem] = [:]

    var count: Int {
        relays.count
    }

    var isEmpty: Bool {
        relays.isEmpty
    }

    mutating func schedule(_ workItem: DispatchWorkItem, messageID: String) {
        relays[messageID] = workItem
    }

    @discardableResult
    mutating func remove(messageID: String) -> DispatchWorkItem? {
        relays.removeValue(forKey: messageID)
    }

    @discardableResult
    mutating func cancel(messageID: String) -> Bool {
        guard let workItem = relays.removeValue(forKey: messageID) else {
            return false
        }

        workItem.cancel()
        return true
    }

    mutating func cancelAll() {
        relays.values.forEach { $0.cancel() }
        relays.removeAll()
    }

    mutating func removeAllIfOverCapacity(_ maxCount: Int) {
        if relays.count > maxCount {
            relays.removeAll()
        }
    }
}
