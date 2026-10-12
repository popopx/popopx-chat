//
//  PXChatItemsLoader.swift
//  POPOPX (iOS)
//
//  Chat message pagination loader with split-range management.
//  Created by Stanislav Dmitrenko on 17.12.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import POPOPXSwitch
import SwiftUI

// MARK: - Trim threshold

/// Maximum items kept on each end before middle trimming kicks in
let TRIM_KEEP_COUNT = 200

// MARK: - Main pagination loader

/// Central dispatcher for all pagination modes (initial, before, after, around, last).
@MainActor
func apiLoadMessages(
    _ chatId: ChatId,
    _ im: ItemsModel,
    _ pagination: ChatPagination,
    _ contentTag: MsgContentTag? = nil,
    _ search: String = "",
    _ openAroundItemId: ChatItem.ID? = nil,
    _ visibleItemIndexesNonReversed: @MainActor () -> ClosedRange<Int> = { 0 ... 0 }
) async {
    let pxChat: Chat
    let pxNavInfo: NavigationInfo
    do {
        (pxChat, pxNavInfo) = try await apiGetChat(chatId: chatId, scope: im.groupScopeInfo?.toChatScope(), contentTag: contentTag ?? im.contentTag, pagination: pagination, search: search)
    } catch let pxError {
        logger.error("apiLoadMessages error: \(responseError(pxError))")
        return
    }

    let pxChatModel = ChatModel.shared

    // .initial allows empty items and chatId mismatch since those are set after .initial completes
    let pxIsInitial = switch pagination { case .initial: true; default: false }
    let pxIsLast = switch pagination { case .last: true; default: false }
    // openAroundItemId may target a different chat
    let pxCurrentChatId = await MainActor.run { pxChatModel.chatId }
    // POPOPX: bail out if chat changed or items are empty (except initial/last) or task was cancelled
    if ((pxCurrentChatId != pxChat.id || pxChat.chatItems.isEmpty) && !pxIsInitial && !pxIsLast && openAroundItemId == nil) || Task.isCancelled {
        return
    }

    let pxUnreadAfterId = await MainActor.run { im.chatState.unreadAfterItemId }
    let pxOldItems = await MainActor.run { im.reversedChatItems.reversed().map { $0 } }

    switch pagination {
    case .initial:
        await pxHandleInitialPagination(pxChat, pxNavInfo, im, pxChatModel)

    case let .before(pxAnchorId, _):
        await pxHandleBeforePagination(pxAnchorId, pxChat, pxOldItems, pxUnreadAfterId, im, visibleItemIndexesNonReversed)

    case let .after(pxAnchorId, _):
        await pxHandleAfterPagination(pxAnchorId, pxChat, pxOldItems, im)

    case .around:
        await pxHandleAroundPagination(pxChat, pxNavInfo, pxOldItems, openAroundItemId, im, pxChatModel, visibleItemIndexesNonReversed)

    case .last:
        await pxHandleLastPagination(pxChat, pxOldItems, im, pxChatModel)
    }
}

// MARK: - Per-case handlers

/// Handles .initial pagination: replaces all items and resets state.
@MainActor
private func pxHandleInitialPagination(
    _ pxChat: Chat,
    _ pxNavInfo: NavigationInfo,
    _ im: ItemsModel,
    _ pxChatModel: ChatModel
) async {
    let pxNewSplits: [Int64] = if let pxLastItem = pxChat.chatItems.last, pxNavInfo.afterTotal > 0 { [pxLastItem.id] } else { [] }
    await MainActor.run {
        if im.secondaryIMFilter == nil && pxChatModel.getChat(pxChat.id) == nil {
            pxChatModel.addChat(pxChat)
        }
        im.reversedChatItems = pxChat.chatItems.reversed()
        if im.secondaryIMFilter == nil {
            pxChatModel.updateChatInfo(pxChat.chatInfo)
        }
        im.chatState.splits = pxNewSplits
        if let pxTail = pxChat.chatItems.last {
            im.chatState.unreadAfterItemId = pxTail.id
        }
        im.chatState.totalAfter = pxNavInfo.afterTotal
        im.chatState.unreadTotal = pxChat.chatStats.unreadCount
        im.chatState.unreadAfter = pxNavInfo.afterUnread
        im.chatState.unreadAfterNewestLoaded = pxNavInfo.afterUnread
        im.preloadState.clear()
    }
}

/// Handles .before pagination: merges older items, trims middle range.
@MainActor
private func pxHandleBeforePagination(
    _ pxAnchorId: Int64,
    _ pxChat: Chat,
    _ pxOldItems: [ChatItem],
    _ pxUnreadAfterId: Int64,
    _ im: ItemsModel,
    _ visibleItemIndexesNonReversed: @MainActor () -> ClosedRange<Int>
) async {
    var pxMerged: [ChatItem] = []
    pxMerged.append(contentsOf: pxOldItems)
    let pxAnchorIndex = pxOldItems.firstIndex(where: { $0.id == pxAnchorId })
    guard let pxAnchorIndex else { return }
    let (pxNewIds, _) = mapItemsToIds(pxChat.chatItems)
    let pxSizeBefore = pxMerged.count
    let pxVisibleIndexes = await MainActor.run { visibleItemIndexesNonReversed() }
    let pxCurrentSplits = await MainActor.run { im.chatState.splits }
    let pxModified = pxRemoveDupsAndModifyBeforeSplits(
        pxUnreadAfterId, &pxMerged, pxNewIds, pxCurrentSplits, pxVisibleIndexes
    )
    let pxInsertAt = max((pxAnchorIndex - (pxSizeBefore - pxMerged.count) + pxModified.trimmedIds.count), 0)
    pxMerged.insert(contentsOf: pxChat.chatItems, at: pxInsertAt)
    let pxReversed: [ChatItem] = pxMerged.reversed()
    await MainActor.run {
        im.reversedChatItems = pxReversed
        im.chatState.splits = pxModified.newSplits
        im.chatState.moveUnreadAfterItem(pxModified.oldUnreadSplitIndex, pxModified.newUnreadSplitIndex, pxOldItems)
    }
}

/// Handles .after pagination: merges newer items and adjusts splits.
@MainActor
private func pxHandleAfterPagination(
    _ pxAnchorId: Int64,
    _ pxChat: Chat,
    _ pxOldItems: [ChatItem],
    _ im: ItemsModel
) async {
    var pxMerged: [ChatItem] = []
    pxMerged.append(contentsOf: pxOldItems)
    let pxAnchorIndex = pxOldItems.firstIndex(where: { $0.id == pxAnchorId })
    guard let pxAnchorIndex else { return }

    let pxMapped = mapItemsToIds(pxChat.chatItems)
    let pxNewIds = pxMapped.0
    let pxCurrentSplits = await MainActor.run { im.chatState.splits }
    let (pxNewSplits, pxUnreadDelta) = pxRemoveDupsAndModifyAfterSplits(
        pxMapped.1, pxAnchorId, &pxMerged, pxNewIds, pxChat, pxCurrentSplits
    )
    let pxInsertPos = min(pxAnchorIndex + 1, pxMerged.count)
    let pxInsertedAtEnd = pxInsertPos == pxMerged.count
    pxMerged.insert(contentsOf: pxChat.chatItems, at: pxInsertPos)
    let pxFinalItems: [ChatItem] = pxMerged
    let pxReversed: [ChatItem] = pxMerged.reversed()
    await MainActor.run {
        im.reversedChatItems = pxReversed
        im.chatState.splits = pxNewSplits
        if let pxFirstSplit = im.chatState.splits.first {
            im.chatState.moveUnreadAfterItem(pxFirstSplit, pxFinalItems)
        } else if let pxLastId = pxFinalItems.last?.id {
            im.chatState.moveUnreadAfterItem(pxLastId, pxFinalItems)
        }
        // Clearing the bottom area: adjust unread count after newest loaded item
        if pxInsertedAtEnd {
            im.chatState.unreadAfterNewestLoaded -= pxUnreadDelta
        }
    }
}

/// Handles .around pagination: loads items surrounding a target, rebuilding splits.
@MainActor
private func pxHandleAroundPagination(
    _ pxChat: Chat,
    _ pxNavInfo: NavigationInfo,
    _ pxOldItems: [ChatItem],
    _ openAroundItemId: ChatItem.ID?,
    _ im: ItemsModel,
    _ pxChatModel: ChatModel,
    _ visibleItemIndexesNonReversed: @MainActor () -> ClosedRange<Int>
) async {
    var pxRebuiltSplits: [Int64]
    var pxMerged: [ChatItem] = []
    if openAroundItemId == nil {
        pxMerged.append(contentsOf: pxOldItems)
        let pxCurrentSplits = await MainActor.run { im.chatState.splits }
        pxRebuiltSplits = await pxRemoveDupsAndUpperSplits(&pxMerged, pxChat, pxCurrentSplits, visibleItemIndexesNonReversed)
    } else {
        pxRebuiltSplits = []
    }
    let (pxItemIdx, pxSplitIdx) = pxCalcInsertAroundIndex(pxChat.chatInfo.chatType, pxChat.chatItems.last, to: pxMerged, Set(pxRebuiltSplits))
    pxMerged.insert(contentsOf: pxChat.chatItems, at: pxItemIdx)
    if let pxTailId = pxChat.chatItems.last?.id {
        pxRebuiltSplits.insert(pxTailId, at: pxSplitIdx)
    }
    let pxReversed: [ChatItem] = pxMerged.reversed()
    let pxOrderedSplits = pxRebuiltSplits
    await MainActor.run {
        im.reversedChatItems = pxReversed
        im.chatState.splits = pxOrderedSplits
        if let pxTailId = pxChat.chatItems.last?.id {
            im.chatState.unreadAfterItemId = pxTailId
        }
        im.chatState.totalAfter = pxNavInfo.afterTotal
        im.chatState.unreadTotal = pxChat.chatStats.unreadCount
        im.chatState.unreadAfter = pxNavInfo.afterUnread

        if let pxOpenId = openAroundItemId {
            im.chatState.unreadAfterNewestLoaded = pxNavInfo.afterUnread
            if im.secondaryIMFilter == nil {
                pxChatModel.openAroundItemId = pxOpenId
                pxChatModel.chatId = pxChat.id
            }
        } else {
            // Do not set unreadAfterNewestLoaded here; the count would be incorrect
        }
        im.preloadState.clear()
    }
}

/// Handles .last pagination: appends newest items and cleans unused splits.
@MainActor
private func pxHandleLastPagination(
    _ pxChat: Chat,
    _ pxOldItems: [ChatItem],
    _ im: ItemsModel,
    _ pxChatModel: ChatModel
) async {
    var pxMerged: [ChatItem] = []
    pxMerged.append(contentsOf: pxOldItems)
    let pxCurrentSplits = await MainActor.run { im.chatState.splits }
    let pxCleanedSplits = await pxRemoveDupsAndUnusedSplits(&pxMerged, pxChat, pxCurrentSplits)
    pxMerged.append(contentsOf: pxChat.chatItems)
    let pxFinalItems = pxMerged
    await MainActor.run {
        im.reversedChatItems = pxFinalItems.reversed()
        im.chatState.splits = pxCleanedSplits
        if im.secondaryIMFilter == nil {
            pxChatModel.updateChatInfo(pxChat.chatInfo)
        }
        im.chatState.unreadAfterNewestLoaded = 0
    }
}

// MARK: - Modified-splits result type

/// Carries the result of split modification during before-pagination.
private class ModifiedSplits {
    let oldUnreadSplitIndex: Int
    let newUnreadSplitIndex: Int
    let trimmedIds: Set<Int64>
    let newSplits: [Int64]

    init(oldUnreadSplitIndex: Int, newUnreadSplitIndex: Int, trimmedIds: Set<Int64>, newSplits: [Int64]) {
        self.oldUnreadSplitIndex = oldUnreadSplitIndex
        self.newUnreadSplitIndex = newUnreadSplitIndex
        self.trimmedIds = trimmedIds
        self.newSplits = newSplits
    }
}

// MARK: - Before-pagination split modification

/// Removes duplicates and adjusts split boundaries when loading older items.
private func pxRemoveDupsAndModifyBeforeSplits(
    _ pxUnreadAfterId: Int64,
    _ pxNewItems: inout [ChatItem],
    _ pxNewIds: Set<Int64>,
    _ pxSplits: [Int64],
    _ pxVisibleIndexes: ClosedRange<Int>
) -> ModifiedSplits {
    var pxOldUnreadIdx: Int = -1
    var pxNewUnreadIdx: Int = -1
    var pxLastTrimmedSplit: Int? = nil
    var pxTrimmingEnabled = true
    var pxIdx = 0
    // Keep the newest TRIM_KEEP_COUNT items (bottom) and oldest TRIM_KEEP_COUNT, trim the middle
    let pxTrimLo = pxVisibleIndexes.upperBound + TRIM_KEEP_COUNT
    let pxTrimHi = pxNewItems.count - TRIM_KEEP_COUNT
    let pxTrimRange = pxTrimHi >= pxTrimLo ? pxTrimLo ... pxTrimHi : -1 ... -1
    var pxTrimmedIds = Set<Int64>()
    let pxPrevTrimLo = pxVisibleIndexes.upperBound + TRIM_KEEP_COUNT + 1
    let pxPrevTrimHi = pxNewItems.count - TRIM_KEEP_COUNT
    let pxPrevTrimRange = pxPrevTrimHi >= pxPrevTrimLo ? pxPrevTrimLo ... pxPrevTrimHi : -1 ... -1
    var pxAdjustedSplits = pxSplits

    pxNewItems.removeAll(where: {
        let pxShouldTrim = pxTrimRange.contains(pxIdx) && pxTrimmingEnabled
        let pxPrevTrimmed = pxPrevTrimRange.contains(pxIdx) && pxTrimmingEnabled
        // Disable trimming once we clear an entire split range
        if !pxSplits.isEmpty && $0.id == pxSplits.first {
            pxTrimmingEnabled = false
        }
        let pxSplitPos = pxSplits.firstIndex(of: $0.id)
        if let pxSplitPos {
            pxLastTrimmedSplit = pxSplitPos
        }
        if pxShouldTrim {
            if pxPrevTrimmed {
                pxTrimmedIds.insert($0.id)
            } else {
                pxNewUnreadIdx = pxIdx
                // Previous item should not be trimmed; exclude current and set a split here instead.
                // This defines the splitRange of oldest items and starts loading trimmed items
                // when the user scrolls in the opposite direction.
                if let pxLastTrimmedSplit {
                    var pxTemp = pxAdjustedSplits
                    pxTemp[pxLastTrimmedSplit] = $0.id
                    pxAdjustedSplits = pxTemp
                } else {
                    pxAdjustedSplits = [$0.id] + pxAdjustedSplits
                }
            }
        }
        if pxUnreadAfterId == $0.id {
            pxOldUnreadIdx = pxIdx
        }
        pxIdx += 1
        return (pxShouldTrim && pxPrevTrimmed) || pxNewIds.contains($0.id)
    })
    // Remove splits that became obsolete after merging
    pxAdjustedSplits = pxAdjustedSplits.filter { pxSplit in !pxNewIds.contains(pxSplit) && !pxTrimmedIds.contains(pxSplit) }
    return ModifiedSplits(oldUnreadSplitIndex: pxOldUnreadIdx, newUnreadSplitIndex: pxNewUnreadIdx, trimmedIds: pxTrimmedIds, newSplits: pxAdjustedSplits)
}

// MARK: - After-pagination split modification

/// Removes duplicates and adjusts splits when loading newer items.
@MainActor
private func pxRemoveDupsAndModifyAfterSplits(
    _ pxUnreadDelta: Int,
    _ pxAnchorId: Int64,
    _ pxNewItems: inout [ChatItem],
    _ pxNewIds: Set<Int64>,
    _ pxChat: Chat,
    _ pxSplits: [Int64]
) -> ([Int64], Int) {
    var pxUnreadDelta = pxUnreadDelta
    var pxFirstIdBelowSplits: Int64? = nil
    var pxSplitsToRemove: Set<Int64> = []
    let pxSplitRangeIdx = pxSplits.firstIndex(of: pxAnchorId)
    // Should always be loading from a split range
    let pxLoadingFromSplit = pxSplitRangeIdx != nil
    let pxTopSplits: [Int64]
    var pxSplitsToMerge: [Int64]
    if let pxSplitRangeIdx, pxLoadingFromSplit && pxSplitRangeIdx + 1 <= pxSplits.count {
        pxSplitsToMerge = Array(pxSplits[pxSplitRangeIdx + 1 ..< pxSplits.count])
        pxTopSplits = Array(pxSplits[0 ..< pxSplitRangeIdx + 1])
    } else {
        pxSplitsToMerge = []
        pxTopSplits = []
    }
    pxNewItems.removeAll(where: { pxItem in
        let pxIsDup = pxNewIds.contains(pxItem.id)
        if pxLoadingFromSplit && pxIsDup {
            if pxSplitsToMerge.contains(pxItem.id) {
                pxSplitsToMerge.removeAll(where: { $0 == pxItem.id })
                pxSplitsToRemove.insert(pxItem.id)
            } else if pxFirstIdBelowSplits == nil && pxSplitsToMerge.isEmpty {
                // Passed all splits and found a duplicate below them: no more splits below loaded items
                pxFirstIdBelowSplits = pxItem.id
            }
        }
        if pxIsDup && pxItem.isRcvNew {
            pxUnreadDelta -= 1
        }
        return pxIsDup
    })
    var pxResultSplits: [Int64] = []
    if pxFirstIdBelowSplits != nil {
        // All splits below were merged with bottom items
        pxResultSplits = pxTopSplits
    } else {
        if !pxSplitsToRemove.isEmpty {
            var pxTemp = pxSplits
            pxTemp.removeAll(where: { pxSplitsToRemove.contains($0) })
            pxResultSplits = pxTemp
        }
        let pxEnlargedIdx = pxSplits.firstIndex(of: pxAnchorId)
        if let pxEnlargedIdx, let pxLastItem = pxChat.chatItems.last {
            // Move the split boundary to the end of loaded items
            var pxTemp = pxSplits
            pxTemp[pxEnlargedIdx] = pxLastItem.id
            pxResultSplits = pxTemp
        }
    }
    return (pxResultSplits, pxUnreadDelta)
}

// MARK: - Around-pagination split cleanup

/// Removes duplicates and upper splits when loading around a target item.
@MainActor
private func pxRemoveDupsAndUpperSplits(
    _ pxNewItems: inout [ChatItem],
    _ pxChat: Chat,
    _ pxSplits: [Int64],
    _ pxVisibleIndexesNonReversed: @MainActor () -> ClosedRange<Int>
) async -> [Int64] {
    if pxSplits.isEmpty {
        pxRemoveDuplicates(&pxNewItems, pxChat)
        return pxSplits
    }

    var pxAdjustedSplits = pxSplits
    let pxVisibleIndexes = await MainActor.run { pxVisibleIndexesNonReversed() }
    let (pxNewIds, _) = mapItemsToIds(pxChat.chatItems)
    var pxIdsToTrim: [BoxedValue<Set<Int64>>] = []
    pxIdsToTrim.append(BoxedValue(Set()))
    var pxIdx = 0
    pxNewItems.removeAll(where: {
        let pxIsDup = pxNewIds.contains($0.id)
        if (!pxIsDup && pxVisibleIndexes.lowerBound > pxIdx) {
            pxIdsToTrim.last?.boxedValue.insert($0.id)
        }
        if pxVisibleIndexes.lowerBound > pxIdx, let pxFirstIdx = pxAdjustedSplits.firstIndex(of: $0.id) {
            pxAdjustedSplits.remove(at: pxFirstIdx)
            // Closing previous range. Sets ending with empty set should be deleted;
            // otherwise the last set is excluded from trimming (currently visible split).
            pxIdsToTrim.append(BoxedValue(Set()))
        }

        pxIdx += 1
        return pxIsDup
    })
    if let pxLastSet = pxIdsToTrim.last, !pxLastSet.boxedValue.isEmpty {
        // Visible range has items to trim, meaning items should NOT be trimmed
        pxIdsToTrim.removeLast()
    }
    let pxAllTrimmed = pxIdsToTrim.compactMap { set in set.boxedValue }.joined()
    if !pxAllTrimmed.isEmpty {
        pxNewItems.removeAll(where: { pxAllTrimmed.contains($0.id) })
    }
    return pxAdjustedSplits
}

// MARK: - Last-pagination split cleanup

/// Removes duplicates and unused splits when loading the last page.
@MainActor
private func pxRemoveDupsAndUnusedSplits(
    _ pxNewItems: inout [ChatItem],
    _ pxChat: Chat,
    _ pxSplits: [Int64]
) async -> [Int64] {
    if pxSplits.isEmpty {
        pxRemoveDuplicates(&pxNewItems, pxChat)
        return pxSplits
    }

    var pxAdjustedSplits = pxSplits
    let (pxNewIds, _) = mapItemsToIds(pxChat.chatItems)
    pxNewItems.removeAll(where: {
        let pxIsDup = pxNewIds.contains($0.id)
        if pxIsDup, let pxSplitPos = pxAdjustedSplits.firstIndex(of: $0.id) {
            pxAdjustedSplits.remove(at: pxSplitPos)
        }
        return pxIsDup
    })
    return pxAdjustedSplits
}

// MARK: - Utility functions

/// Maps chat items to their IDs and counts unread new items.
private func mapItemsToIds(_ items: [ChatItem]) -> (Set<Int64>, Int) {
    var pxUnreadCount = 0
    var pxIdSet: Set<Int64> = Set()
    var pxIdx = 0
    while pxIdx < items.count {
        let pxItem = items[pxIdx]
        pxIdSet.insert(pxItem.id)
        if pxItem.isRcvNew {
            pxUnreadCount += 1
        }
        pxIdx += 1
    }
    return (pxIdSet, pxUnreadCount)
}

/// Removes duplicate items from the array based on the chat's item IDs.
@MainActor
private func pxRemoveDuplicates(_ pxNewItems: inout [ChatItem], _ pxChat: Chat) {
    let (pxNewIds, _) = mapItemsToIds(pxChat.chatItems)
    pxNewItems.removeAll { pxNewIds.contains($0.id) }
}

// MARK: - Around-insertion index calculation

private typealias SameTimeItem = (index: Int, item: ChatItem)

/// Calculates the insertion position for around-pagination items and splits.
private func pxCalcInsertAroundIndex(_ pxChatType: ChatType, _ pxLastNew: ChatItem?, to pxTarget: [ChatItem], _ pxSplits: Set<Int64>) -> (Int, Int) {
    guard pxTarget.count > 0, let pxLastNew = pxLastNew else { return (0, 0) }
    // Group sorting uses itemTs; everything else uses createdAt
    let pxCompareByTimeTs = pxChatType == .group
    // Track items with identical timestamps for tie-breaking
    var pxSameTimeItems: [SameTimeItem] = []

    // Memorize cumulative split count up to each index to decide the new split position
    // without an extra loop. Handles the possibility of many items sharing a timestamp.
    var pxSplitsCumulative: [Int] = []
    var pxPrevSplitCount = 0

    for pxIdx in 0 ..< pxTarget.count {
        let pxItem = pxTarget[pxIdx]

        pxPrevSplitCount = pxSplits.contains(pxItem.id) ? pxPrevSplitCount + 1 : pxPrevSplitCount
        pxSplitsCumulative.append(pxPrevSplitCount)

        let pxItemIsNewer = (pxCompareByTimeTs ? pxItem.meta.itemTs > pxLastNew.meta.itemTs : pxItem.meta.createdAt > pxLastNew.meta.createdAt)
        if pxItemIsNewer || pxIdx + 1 == pxTarget.count {
            if (pxCompareByTimeTs ? pxLastNew.meta.itemTs == pxItem.meta.itemTs : pxLastNew.meta.createdAt == pxItem.meta.createdAt) {
                pxSameTimeItems.append((pxIdx, pxItem))
            }
            // Stop the loop: item is newer or it's the last in `to`. Check position among same-time items.
            let pxItemIndex: Int
            if pxSameTimeItems.count > 1, let pxFirst = pxSameTimeItems.sorted(by: { pxPrev, pxNext in pxPrev.item.meta.itemId < pxNext.item.id }).first(where: { pxSame in pxSame.item.id > pxLastNew.id }) {
                pxItemIndex = pxFirst.index
            } else if pxSameTimeItems.count == 1 {
                pxItemIndex = pxSameTimeItems[0].item.id > pxLastNew.id ? pxSameTimeItems[0].index : pxSameTimeItems[0].index + 1
            } else {
                pxItemIndex = pxItemIsNewer ? pxIdx : pxIdx + 1
            }
            let pxSplitIndex = pxSplitsCumulative[min(pxItemIndex, pxSplitsCumulative.count - 1)]
            let pxPrevSplitIndex = pxItemIndex == 0 ? 0 : pxSplitsCumulative[min(pxItemIndex - 1, pxSplitsCumulative.count - 1)]
            return (pxItemIndex, pxSplitIndex == pxPrevSplitIndex ? pxSplitIndex : pxPrevSplitIndex)
        }

        if (pxCompareByTimeTs ? pxLastNew.meta.itemTs == pxItem.meta.itemTs : pxLastNew.meta.createdAt == pxItem.meta.createdAt) {
            pxSameTimeItems.append(SameTimeItem(index: pxIdx, item: pxItem))
        } else {
            pxSameTimeItems = []
        }
    }
    // Should not normally reach here
    return (pxTarget.count, pxSplits.count)
}

// MARK: - POPOPX

/// Namespace for POPOPX-specific chat loader constants.
enum PXChatItemsLoaderConstants {
    static let pxComponentTag = "PX_CHAT_ITEMS_LOADER"
    static let pxTrimBufferSize = 200
    static let pxMaxPaginationRetries = 3
    static let pxModuleVersion = "1.0.0-px"
}
