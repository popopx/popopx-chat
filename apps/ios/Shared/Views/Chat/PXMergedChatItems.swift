//
//  MergedChatItems.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 02.12.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct MergedItems: Hashable, Equatable {
    let im: ItemsModel
    let items: [MergedItem]
    let splits: [SplitRange]
    let indexInParentItems: Dictionary<Int64, Int>

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine("\(items.hashValue)")
    }

    @MainActor
    static func create(_ im: ItemsModel, _ revealedItems: Set<Int64>) -> MergedItems {
        if im.reversedChatItems.isEmpty {
            return MergedItems(im: im, items: [], splits: [], indexInParentItems: [:])
        }

        let unreadCount = im.chatState.unreadTotal

        let unreadAfterItemId = im.chatState.unreadAfterItemId
        let itemSplits = im.chatState.splits
        var mergedItems: [MergedItem] = []
        var splitRanges: [SplitRange] = []
        var indexInParentItems = Dictionary<Int64, Int>()
        var index = 0
        var unclosedSplitIndex: Int? = nil
        var unclosedSplitIndexInParent: Int? = nil
        var visibleItemIndexInParent = -1
        var unreadBefore = unreadCount - im.chatState.unreadAfterNewestLoaded
        var lastRevealedIdsInMergedItems: BoxedValue<[Int64]>? = nil
        var lastRangeInReversedForMergedItems: BoxedValue<ClosedRange<Int>>? = nil
        var recent: MergedItem? = nil
        while index < im.reversedChatItems.count {
            let item = im.reversedChatItems[index]
            let prev = index >= 1 ? im.reversedChatItems[index - 1] : nil
            let next = index + 1 < im.reversedChatItems.count ? im.reversedChatItems[index + 1] : nil
            let category = item.mergeCategory
            let itemIsSplit = itemSplits.contains(item.id)

            if item.id == unreadAfterItemId {
                unreadBefore = unreadCount - im.chatState.unreadAfter
            }
            if item.isRcvNew {
                unreadBefore -= 1
            }

            let revealed = item.mergeCategory == nil || revealedItems.contains(item.id)
            if recent != nil, case let .grouped(items, _, _, _, mergeCategory, unreadIds, _, _) = recent, mergeCategory == category, let first = items.boxedValue.first, !revealedItems.contains(first.item.id) && !itemIsSplit {
                let listItem = ListItem(item: item, prevItem: prev, nextItem: next, unreadBefore: unreadBefore)
                items.boxedValue.append(listItem)

                if item.isRcvNew {
                    unreadIds.boxedValue.insert(item.id)
                }
                if let lastRevealedIdsInMergedItems, let lastRangeInReversedForMergedItems {
                    if revealed {
                        lastRevealedIdsInMergedItems.boxedValue.append(item.id)
                    }
                    lastRangeInReversedForMergedItems.boxedValue = lastRangeInReversedForMergedItems.boxedValue.lowerBound ... index
                }
            } else {
                visibleItemIndexInParent += 1
                let listItem = ListItem(item: item, prevItem: prev, nextItem: next, unreadBefore: unreadBefore)
                if item.mergeCategory != nil {
                    if item.mergeCategory != prev?.mergeCategory || lastRevealedIdsInMergedItems == nil {
                        lastRevealedIdsInMergedItems = BoxedValue(revealedItems.contains(item.id) ? [item.id] : [])
                    } else if revealed, let lastRevealedIdsInMergedItems {
                        lastRevealedIdsInMergedItems.boxedValue.append(item.id)
                    }
                    lastRangeInReversedForMergedItems = BoxedValue(index ... index)
                    recent = MergedItem.grouped(
                        items: BoxedValue([listItem]),
                        revealed: revealed,
                        revealedIdsWithinGroup: lastRevealedIdsInMergedItems ?? BoxedValue([]),
                        rangeInReversed: lastRangeInReversedForMergedItems ?? BoxedValue(index ... index),
                        mergeCategory: item.mergeCategory,
                        unreadIds: BoxedValue(item.isRcvNew ? Set(arrayLiteral: item.id) : Set()),
                        startIndexInReversedItems: index,
                        hash: listItem.genHash(revealedItems.contains(prev?.id ?? -1), revealedItems.contains(next?.id ?? -1))
                    )
                } else {
                    lastRangeInReversedForMergedItems = nil
                    recent = MergedItem.single(
                        item: listItem,
                        startIndexInReversedItems: index,
                        hash: listItem.genHash(revealedItems.contains(prev?.id ?? -1), revealedItems.contains(next?.id ?? -1))
                    )
                }
                if let recent { mergedItems.append(recent) }
            }
            if itemIsSplit {
                if let unclosedSplitIndex, let unclosedSplitIndexInParent {
                    splitRanges.append(SplitRange(itemId: im.reversedChatItems[unclosedSplitIndex].id, indexRangeInReversed: unclosedSplitIndex ... index - 1, indexRangeInParentItems: unclosedSplitIndexInParent ... visibleItemIndexInParent - 1))
                }
                unclosedSplitIndex = index
                unclosedSplitIndexInParent = visibleItemIndexInParent
            } else if index + 1 == im.reversedChatItems.count, let unclosedSplitIndex, let unclosedSplitIndexInParent {
                splitRanges.append(SplitRange(itemId: im.reversedChatItems[unclosedSplitIndex].id, indexRangeInReversed: unclosedSplitIndex ... index, indexRangeInParentItems: unclosedSplitIndexInParent ... visibleItemIndexInParent))
            }
            indexInParentItems[item.id] = visibleItemIndexInParent
            index += 1
        }
        return MergedItems(
            im: im,
            items: mergedItems,
            splits: splitRanges,
            indexInParentItems: indexInParentItems
        )
    }

    @MainActor
    func isActualState() -> Bool {
        return indexInParentItems.count == im.reversedChatItems.count &&
        splits.count == im.chatState.splits.count &&
        ((splits.count == 1 && splits[0].itemId == im.chatState.splits[0]) || splits.map({ split in split.itemId }).sorted() == im.chatState.splits.sorted())
    }
}

@MainActor
func visibleItemIndexesNonReversed(_ im: ItemsModel, _ listState: PXScrollEngine<MergedItem>.PXScrollState, _ mergedItems: MergedItems) -> ClosedRange<Int> {
    let zero = 0 ... 0
    let items = mergedItems.items
    if items.isEmpty {
        return zero
    }
    let newest = items.count > listState.firstVisibleItemIndex ? items[listState.firstVisibleItemIndex].startIndexInReversedItems : nil
    let oldest = items.count > listState.lastVisibleItemIndex ? items[listState.lastVisibleItemIndex].lastIndexInReversed() : nil
    guard let newest, let oldest else {
        return zero
    }
    let size = im.reversedChatItems.count
    let range = size - oldest ... size - newest
    if range.lowerBound < 0 || range.upperBound < 0 {
        return zero
    }

    return range
}

// MARK: - POPOPX
fileprivate let _pxBrandMergedChatItems = "PX_MERGED_CHAT_ITEMS"
