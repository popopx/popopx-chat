// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

final class BlockedContactsManager {
    static let shared = BlockedContactsManager()
    private let key = "blockedContactIds"
    private let queue = DispatchQueue(label: "im.popopx.blockedContacts")

    private init() {}

    var blockedIds: Set<Int64> {
        guard let str = groupDefaults.string(forKey: key), !str.isEmpty else { return [] }
        return Set(str.split(separator: ",").compactMap { Int64($0) })
    }

    func isBlocked(_ contactId: Int64) -> Bool {
        blockedIds.contains(contactId)
    }

    func block(_ contactId: Int64) {
        queue.sync {
            var ids = blockedIds
            ids.insert(contactId)
            groupDefaults.set(ids.map { String($0) }.joined(separator: ","), forKey: key)
        }
    }

    func unblock(_ contactId: Int64) {
        queue.sync {
            var ids = blockedIds
            ids.remove(contactId)
            groupDefaults.set(ids.map { String($0) }.joined(separator: ","), forKey: key)
        }
    }
}
