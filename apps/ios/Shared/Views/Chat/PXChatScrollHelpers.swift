//
//  PXChatScrollHelpers.swift
//  POPOPX (iOS)
//
//  Scroll preloading orchestration for chat item lists.
//  Created by Stanislav Dmitrenko on 20.12.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX scroll loading constants

/// Debounce delay when requesting the last page of messages
private let pxLoadLastItemsDelayNs: UInt64 = 500_000000

/// Number of items fetched in the final batch request
private let pxLastItemsPaginationCount: Int = 50

// MARK: - Last-items loader

/// Fetches the most recent chat items, guarding against chat-switch races.
@MainActor
func loadLastItems(_ loadingMoreItems: Binding<Bool>, loadingBottomItems: Binding<Bool>, _ chat: Chat, _ im: ItemsModel) async {
    await MainActor.run {
        loadingMoreItems.wrappedValue = true
        loadingBottomItems.wrappedValue = true
    }
    try? await Task.sleep(nanoseconds: pxLoadLastItemsDelayNs)
    // Abort if the user already navigated away
    let pxCurrentChatId = await MainActor.run { ChatModel.shared.chatId }
    if pxCurrentChatId != chat.chatInfo.id {
        await MainActor.run {
            loadingMoreItems.wrappedValue = false
            loadingBottomItems.wrappedValue = false
        }
        return
    }
    await apiLoadMessages(chat.chatInfo.id, im, ChatPagination.last(count: pxLastItemsPaginationCount))
    await MainActor.run {
        loadingMoreItems.wrappedValue = false
        loadingBottomItems.wrappedValue = false
    }
}

// MARK: - Conditional preloading

/// Triggers a preload cycle when the scroll position has changed since the last check.
@MainActor
func preloadIfNeeded(
    _ im: ItemsModel,
    _ allowLoadMoreItems: Binding<Bool>,
    _ ignoreLoadingRequests: Binding<Int64?>,
    _ listState: EndlessScrollView<MergedItem>.ListState,
    _ mergedItems: BoxedValue<MergedItems>,
    loadItems: @escaping (Bool, ChatPagination) async -> Bool,
    loadLastItems: @escaping () async -> Void
) {
    let pxPreloadState = im.preloadState
    // Skip if the user is actively scrolling or a preload is already in-flight
    guard !listState.isScrolling && !listState.isAnimatedScrolling,
          !pxPreloadState.preloading,
          listState.totalItemsCount > 0
    else {
        return
    }
    guard let pxFirstVisibleId = listState.firstVisibleItemId as? Int64 else { return }
    let pxItemsCountSnapshot = mergedItems.boxedValue.indexInParentItems.count
    if pxPreloadState.prevFirstVisible != pxFirstVisibleId || pxPreloadState.prevItemsCount != pxItemsCountSnapshot {
        pxPreloadState.preloading = true
        let pxAllowMore = allowLoadMoreItems.wrappedValue
        Task {
            defer { pxPreloadState.preloading = false }
            var pxTriedToLoad = true
            await preloadItems(im, mergedItems.boxedValue, pxAllowMore, listState, ignoreLoadingRequests) { pagination in
                pxTriedToLoad = await loadItems(false, pagination)
                return pxTriedToLoad
            }
            if pxTriedToLoad {
                pxPreloadState.prevFirstVisible = pxFirstVisibleId
                pxPreloadState.prevItemsCount = pxItemsCountSnapshot
            }
            // Important: only request last items once the viewport is fully covered,
            // otherwise items from different splits merge and scroll position jumps.
            if listState.itemsCanCoverScreen && !im.lastItemsLoaded {
                await loadLastItems()
            }
        }
    } else if listState.itemsCanCoverScreen && !im.lastItemsLoaded {
        pxPreloadState.preloading = true
        Task {
            defer { pxPreloadState.preloading = false }
            await loadLastItems()
        }
    }
}

// MARK: - Bidirectional preload

/// Attempts to preload items both above and below the currently visible range.
@MainActor
func preloadItems(
    _ im: ItemsModel,
    _ mergedItems: MergedItems,
    _ allowLoadMoreItems: Bool,
    _ listState: EndlessScrollView<MergedItem>.ListState,
    _ ignoreLoadingRequests: Binding<Int64?>,
    _ loadItems: @escaping (ChatPagination) async -> Bool)
async {
    let pxCanLoadMore = allowLoadMoreItems || mergedItems.items.count == listState.lastVisibleItemIndex + 1
    let pxRemainingThreshold = ChatPagination.UNTIL_PRELOAD_COUNT
    let pxFirstVisibleIdx = listState.firstVisibleItemIndex

    // Try the upward direction first; fall back to downward
    if !(await pxPreloadUpward(pxCanLoadMore, pxRemainingThreshold, pxFirstVisibleIdx, im, mergedItems, listState, ignoreLoadingRequests, loadItems)) {
        await pxPreloadDownward(pxRemainingThreshold, pxFirstVisibleIdx, im, mergedItems, listState, loadItems)
    }
}

// MARK: - Preload helpers (upward / downward)

/// Preloads older items above the current visible window.
@MainActor
private func pxPreloadUpward(
    _ pxCanLoadMore: Bool,
    _ pxRemainingThreshold: Int,
    _ pxFirstVisibleIdx: Int,
    _ im: ItemsModel,
    _ mergedItems: MergedItems,
    _ listState: EndlessScrollView<MergedItem>.ListState,
    _ ignoreLoadingRequests: Binding<Int64?>,
    _ loadItems: @escaping (ChatPagination) async -> Bool
) async -> Bool {
    let pxSplits = mergedItems.splits
    let pxLastVisibleIdx = listState.lastVisibleItemIndex
    var pxLastIndexToLoad: Int? = findLastIndexToLoadFromInSplits(pxFirstVisibleIdx, pxLastVisibleIdx, pxRemainingThreshold, pxSplits)
    let pxReversedItems: [ChatItem] = im.reversedChatItems.reversed()
    if pxSplits.isEmpty && !pxReversedItems.isEmpty && pxLastVisibleIdx > mergedItems.items.count - pxRemainingThreshold {
        pxLastIndexToLoad = pxReversedItems.count - 1
    }
    let pxLoadFromId: Int64?
    if pxCanLoadMore, let pxLastIndexToLoad {
        let pxIdx = pxReversedItems.count - 1 - pxLastIndexToLoad
        pxLoadFromId = pxIdx >= 0 ? pxReversedItems[pxIdx].id : nil
    } else {
        pxLoadFromId = nil
    }
    guard let pxLoadFromId, ignoreLoadingRequests.wrappedValue != pxLoadFromId else {
        return false
    }
    let pxSizeBefore = pxReversedItems.count
    let pxFirstIdBefore = pxReversedItems.first?.id
    let pxTried = await loadItems(ChatPagination.before(chatItemId: pxLoadFromId, count: ChatPagination.PRELOAD_COUNT))
    if pxTried && pxSizeBefore == im.reversedChatItems.count && pxFirstIdBefore == im.reversedChatItems.last?.id {
        ignoreLoadingRequests.wrappedValue = pxLoadFromId
        return false
    }
    return pxTried
}

/// Preloads newer items below the current visible window.
@MainActor
private func pxPreloadDownward(
    _ pxRemainingThreshold: Int,
    _ pxFirstVisibleIdx: Int,
    _ im: ItemsModel,
    _ mergedItems: MergedItems,
    _ listState: EndlessScrollView<MergedItem>.ListState,
    _ loadItems: @escaping (ChatPagination) async -> Bool
) async {
    let pxSplits = mergedItems.splits
    let pxSplit = pxSplits.last(where: { $0.indexRangeInParentItems.contains(pxFirstVisibleIdx) })
    // Inside a splitRange: top --- [end of split --- we are here --- start of split] --- bottom
    let pxReversedItems: [ChatItem] = im.reversedChatItems
    if let pxSplit, pxSplit.indexRangeInParentItems.lowerBound + pxRemainingThreshold > pxFirstVisibleIdx {
        let pxIdx = pxSplit.indexRangeInReversed.lowerBound
        if pxIdx >= 0 {
            let pxAnchorId = pxReversedItems[pxIdx].id
            _ = await loadItems(ChatPagination.after(chatItemId: pxAnchorId, count: ChatPagination.PRELOAD_COUNT))
        }
    }
}

// MARK: - Visible item lookup

/// Returns the oldest partially visible list item, or nil if none.
func oldestPartiallyVisibleListItemInListStateOrNull(_ listState: EndlessScrollView<MergedItem>.ListState) -> ListItem? {
    if listState.lastVisibleItemIndex < listState.items.count {
        return listState.items[listState.lastVisibleItemIndex].oldest()
    } else {
        return listState.items.last?.oldest()
    }
}

// MARK: - Split-range index search

/// Walks split ranges to find the best index from which to start an upward preload.
private func findLastIndexToLoadFromInSplits(_ firstVisibleIndex: Int, _ lastVisibleIndex: Int, _ remaining: Int, _ splits: [SplitRange]) -> Int? {
    for split in splits {
        // Position is before any split
        if split.indexRangeInParentItems.lowerBound > firstVisibleIndex {
            if lastVisibleIndex > (split.indexRangeInParentItems.lowerBound - remaining) {
                return split.indexRangeInReversed.lowerBound - 1
            }
            break
        }
        let pxContained = split.indexRangeInParentItems.contains(firstVisibleIndex)
        if pxContained {
            if lastVisibleIndex > (split.indexRangeInParentItems.upperBound - remaining) {
                return split.indexRangeInReversed.upperBound
            }
            break
        }
    }
    return nil
}

// MARK: - Animation wrapper

/// Applies animation unconditionally; originally guarded by iOS 16 availability.
func withConditionalAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(animation, body)
}

// MARK: - POPOPX

/// Namespace for POPOPX-specific scroll-helper constants.
enum PXScrollHelpers {
    static let pxComponentTag = "PX_CHAT_SCROLL_HELPERS"
    static let pxPreloadDebounceNs: UInt64 = 500_000000
    static let pxLastBatchSize = 50
    static let pxModuleVersion = "1.0.0-px"
    /// Minimum item count before a preload cycle is triggered
    static let pxMinItemsForPreload: Int = 1
    /// Maximum nanoseconds to wait before re-checking scroll position
    static let pxMaxScrollSettleNs: UInt64 = 750_000000
}
