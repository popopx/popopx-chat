//
//  ActiveChatState.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 02.12.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

@MainActor
class ActiveChatState: ObservableObject {
    @Published var splits: [Int64] = []
    @Published var unreadAfterItemId: Int64 = -1
    @Published var totalAfter: Int = 0
    @Published var unreadTotal: Int = 0
    @Published var unreadAfter: Int = 0
    @Published var unreadAfterNewestLoaded: Int = 0

    func reset() {
        splits = []
        unreadAfterItemId = -1
        totalAfter = 0
        unreadTotal = 0
        unreadAfter = 0
        unreadAfterNewestLoaded = 0
    }

    func moveUnreadAfterItem(_ toItemId: Int64?, _ nonReversedItems: [ChatItem]) {
        guard let toItemId else { return }
        let currentIndex = nonReversedItems.firstIndex(where: { $0.id == unreadAfterItemId })
        let newIndex = nonReversedItems.firstIndex(where: { $0.id == toItemId })
        guard let currentIndex, let newIndex else {
            return
        }
        unreadAfterItemId = toItemId
        let unreadDiff = newIndex > currentIndex
        ? -nonReversedItems[currentIndex + 1..<newIndex + 1].filter { $0.isRcvNew }.count
        : nonReversedItems[newIndex + 1..<currentIndex + 1].filter { $0.isRcvNew }.count
        unreadAfter += unreadDiff
    }

    func moveUnreadAfterItem(_ fromIndex: Int, _ toIndex: Int, _ nonReversedItems: [ChatItem]) {
        if fromIndex == -1 || toIndex == -1 {
            return
        }
        unreadAfterItemId = nonReversedItems[toIndex].id
        let unreadDiff = toIndex > fromIndex
        ? -nonReversedItems[fromIndex + 1..<toIndex + 1].filter { $0.isRcvNew }.count
        : nonReversedItems[toIndex + 1..<fromIndex + 1].filter { $0.isRcvNew }.count
        unreadAfter += unreadDiff
    }

    func clear() {
        splits = []
        unreadAfterItemId = -1
        totalAfter = 0
        unreadTotal = 0
        unreadAfter = 0
        unreadAfterNewestLoaded = 0
    }

    func itemsRead(_ itemIds: Set<Int64>?, _ newItems: [ChatItem]) {
        guard let itemIds else {
            unreadTotal = 0
            unreadAfter = 0
            return
        }
        var unreadAfterItemIndex: Int = -1
        var i = newItems.count - 1
        var ids = itemIds
        var newUnreadTotal = unreadTotal
        var newUnreadAfter = unreadAfter
        while i >= 0 {
            let item = newItems[i]
            if item.id == unreadAfterItemId {
                unreadAfterItemIndex = i
            }
            if ids.contains(item.id) {
                if (unreadAfterItemIndex == -1) {
                    newUnreadAfter -= 1
                }
                newUnreadTotal -= 1
                ids.remove(item.id)
                if ids.isEmpty {
                    break
                }
            }
            i -= 1
        }
        unreadTotal = newUnreadTotal
        unreadAfter = newUnreadAfter
    }

    func itemAdded(_ item: (Int64, Bool), _ index: Int) {
        if item.1 {
            unreadAfter += 1
            unreadTotal += 1
        }
    }

    func itemsRemoved(_ itemIds: [(Int64, Int, Bool)], _ newItems: [ChatItem]) {
        var newSplits: [Int64] = []
        for split in splits {
            let index = itemIds.firstIndex(where: { (delId, _, _) in delId == split })
            if let index {
                let idx = itemIds[index].1 - itemIds.filter { (_, delIndex, _) in delIndex <= index }.count
                let newSplit = newItems.count > idx && idx >= 0 ? newItems[idx].id : nil
                if let newSplit, !newSplits.contains(newSplit) {
                    newSplits.append(newSplit)
                }
            } else {
                newSplits.append(split)
            }
        }
        splits = newSplits

        let index = itemIds.firstIndex(where: { (delId, _, _) in delId == unreadAfterItemId })
        if let index {
            let idx = itemIds[index].1 - itemIds.filter { (_, delIndex, _) in delIndex <= index }.count
            var newUnreadAfterItemId = newItems.count > idx && idx >= 0 ? newItems[idx].id : nil
            let newUnreadAfterItemWasNull = newUnreadAfterItemId == nil
            if newUnreadAfterItemId == nil {
                newUnreadAfterItemId = newItems.first?.id
            }
            if let newUnreadAfterItemId {
                unreadAfterItemId = newUnreadAfterItemId
                totalAfter -= itemIds.filter { (_, delIndex, _) in delIndex > index }.count
                unreadTotal -= itemIds.filter { (_, delIndex, isRcvNew) in delIndex <= index && isRcvNew }.count
                unreadAfter -= itemIds.filter { (_, delIndex, isRcvNew) in delIndex > index && isRcvNew }.count
                if newUnreadAfterItemWasNull {
                    if newItems.first?.isRcvNew == true {
                        unreadTotal += 1
                        unreadAfter -= 1
                    }
                }
            } else {
                unreadAfterItemId = -1
                totalAfter = 0
                unreadTotal = 0
                unreadAfter = 0
            }
        } else {
            totalAfter -= itemIds.count
        }
    }
}

// MARK: - POPOPX
fileprivate let _pxBrandActiveChatState = "PX_ACTIVE_CHAT_STATE"
