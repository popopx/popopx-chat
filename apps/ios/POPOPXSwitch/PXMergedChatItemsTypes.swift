//
//  PXMergedChatItemsTypes.swift
//  POPOPXSwitch
//
//  Core types for merged chat items: MergedItem, SplitRange, ListItem.
//  Split from PXMergedChatItems.swift so these types live in POPOPXSwitch
//  and are accessible to the test target at runtime.
//
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

public enum MergedItem: Identifiable, Hashable, Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hash == rhs.hash
    }

    public var id: Int64 { newest().item.id }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
    }

    public var hash: String {
        switch self {
        case .single(_, _, let hash): hash + " 1"
        case .grouped(let items, _, _, _, _, _, _, let hash): hash + " \(items.boxedValue.count)"
        }
    }

    case single(
        item: ListItem,
        startIndexInReversedItems: Int,
        hash: String
    )

    case grouped (
        items: BoxedValue<[ListItem]>,
        revealed: Bool,
        revealedIdsWithinGroup: BoxedValue<[Int64]>,
        rangeInReversed: BoxedValue<ClosedRange<Int>>,
        mergeCategory: CIMergeCategory?,
        unreadIds: BoxedValue<Set<Int64>>,
        startIndexInReversedItems: Int,
        hash: String
    )

    public func revealItems(_ reveal: Bool, _ revealedItems: Binding<Set<Int64>>) {
        if case .grouped(let items, _, let revealedIdsWithinGroup, _, _, _, _, _) = self {
            var newRevealed = revealedItems.wrappedValue
            var i = 0
            if reveal {
                while i < items.boxedValue.count {
                    newRevealed.insert(items.boxedValue[i].item.id)
                    i += 1
                }
            } else {
                while i < revealedIdsWithinGroup.boxedValue.count {
                    newRevealed.remove(revealedIdsWithinGroup.boxedValue[i])
                    i += 1
                }
                revealedIdsWithinGroup.boxedValue.removeAll()
            }
            revealedItems.wrappedValue = newRevealed
        }
    }

    public var startIndexInReversedItems: Int {
        get {
            switch self {
            case let .single(_, startIndexInReversedItems, _): startIndexInReversedItems
            case let .grouped(_, _, _, _, _, _, startIndexInReversedItems, _): startIndexInReversedItems
            }
        }
    }

    public func hasUnread() -> Bool {
        switch self {
        case let .single(item, _, _): item.item.isRcvNew
        case let .grouped(_, _, _, _, _, unreadIds, _, _): !unreadIds.boxedValue.isEmpty
        }
    }

    public func newest() -> ListItem {
        switch self {
        case let .single(item, _, _): item
        case let .grouped(items, _, _, _, _, _, _, _): items.boxedValue[0]
        }
    }

    public func oldest() -> ListItem {
        switch self {
        case let .single(item, _, _): item
        case let .grouped(items, _, _, _, _, _, _, _): items.boxedValue[items.boxedValue.count - 1]
        }
    }

    public func lastIndexInReversed() -> Int {
        switch self {
        case .single: startIndexInReversedItems
        case let .grouped(items, _, _, _, _, _, _, _): startIndexInReversedItems + items.boxedValue.count - 1
        }
    }
}

public struct SplitRange {
    public let itemId: Int64
    public let indexRangeInReversed: ClosedRange<Int>
    public let indexRangeInParentItems: ClosedRange<Int>

    public init(itemId: Int64, indexRangeInReversed: ClosedRange<Int>, indexRangeInParentItems: ClosedRange<Int>) {
        self.itemId = itemId
        self.indexRangeInReversed = indexRangeInReversed
        self.indexRangeInParentItems = indexRangeInParentItems
    }
}

public struct ListItem: Hashable {
    public let item: ChatItem
    public let prevItem: ChatItem?
    public let nextItem: ChatItem?
    public let unreadBefore: Int

    public init(item: ChatItem, prevItem: ChatItem?, nextItem: ChatItem?, unreadBefore: Int) {
        self.item = item
        self.prevItem = prevItem
        self.nextItem = nextItem
        self.unreadBefore = unreadBefore
    }

    private func chatDirHash(_ chatDir: CIDirection?) -> Int {
        guard let chatDir else { return 0 }
        return switch chatDir {
        case .directSnd: 0
        case .directRcv: 1
        case .groupSnd: 2
        case let .groupRcv(mem): "\(mem.groupMemberId) \(mem.displayName) \(mem.memberStatus.rawValue) \(mem.memberRole.rawValue) \(mem.image?.hash ?? 0)".hash
        case .channelRcv: 3
        case .localSnd: 4
        case .localRcv: 5
        case .meshSnd: 6
        case .meshRcv: 7
        case .meshGroupSnd: 8
        case .meshGroupRcv: 9
        }
    }

    public func genHash(_ prevRevealed: Bool, _ nextRevealed: Bool) -> String {
        "\(item.meta.itemId) \(item.meta.updatedAt.hashValue) \(item.meta.itemEdited) \(item.meta.itemDeleted?.hashValue ?? 0) \(item.meta.itemTimed?.hashValue ?? 0) \(item.meta.itemStatus.hashValue) \(item.meta.sentViaProxy ?? false) \(item.mergeCategory?.hashValue ?? 0) \(chatDirHash(item.chatDir)) \(item.reactions.hashValue) \(item.meta.isRcvNew) \(item.text.hash) \(item.file?.hashValue ?? 0) \(item.quotedItem?.itemId ?? 0) \(unreadBefore) \(prevItem?.id ?? 0) \(chatDirHash(prevItem?.chatDir)) \(prevItem?.mergeCategory?.hashValue ?? 0) \(prevRevealed) \(nextItem?.id ?? 0) \(chatDirHash(nextItem?.chatDir)) \(nextItem?.mergeCategory?.hashValue ?? 0) \(nextRevealed)"
    }
}
