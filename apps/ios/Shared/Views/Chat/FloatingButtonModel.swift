//
//  FloatingButtonModel.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/chat-view.md#FloatingButtonModel
@MainActor
class FloatingButtonModel: ObservableObject {
    @ObservedObject var im: ItemsModel

    public init(im: ItemsModel) {
        self.im = im
    }

    struct ScrollState: Equatable {
        var unreadAbove: Int = 0
        var unreadBelow: Int = 0
        var isNearBottom: Bool = true
        var date: Date? = nil
        var isDateVisible: Bool = false
    }

    @Published var state = ScrollState()
    var hideDateWorkItem: DispatchWorkItem? = nil

    var unreadAbove: Int { state.unreadAbove }
    var unreadBelow: Int { state.unreadBelow }
    var isNearBottom: Bool { state.isNearBottom }
    var date: Date? { state.date }
    var isDateVisible: Bool { state.isDateVisible }

    func updateOnListChange(_ listState: PXScrollEngine<MergedItem>.PXScrollState) {
        let lastVisibleItem = pxOldestPartiallyVisibleListItemOrNull(listState)
        let unreadBelow = if let lastVisibleItem {
            max(0, im.chatState.unreadTotal - lastVisibleItem.unreadBefore)
        } else {
            0
        }
        let unreadAbove = im.chatState.unreadTotal - unreadBelow
        let date: Date? =
        if let lastVisible = listState.visibleItems.last {
            Calendar.current.startOfDay(for: lastVisible.item.oldest().item.meta.itemTs)
            } else {
                nil
            }

        var newState = state
        newState.unreadAbove = unreadAbove
        newState.unreadBelow = unreadBelow
        newState.date = date
        setDate(visibility: true, state: &newState)
        state = newState // POPOPX: single objectWillChange per scroll event, was 3-5

        // set floating button indication mode
        let nearBottom = listState.firstVisibleItemIndex < 1
        if nearBottom != state.isNearBottom {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.state.isNearBottom = nearBottom
            }
        }

        // hide Date indicator after 1 second of no scrolling
        hideDateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let it = self else { return }
            var s = it.state
            it.setDate(visibility: false, state: &s)
            it.state = s
            it.hideDateWorkItem = nil
        }
        self.hideDateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    func resetDate() {
        hideDateWorkItem?.cancel()
        hideDateWorkItem = nil
        state.date = nil
        state.isDateVisible = false
    }

    private func setDate(visibility isVisible: Bool, state: inout ScrollState) {
        if isVisible {
            if !state.isNearBottom,
               !state.isDateVisible,
               let date = state.date, !Calendar.current.isDateInToday(date) {
                withAnimation { state.isDateVisible = true }
            }
        } else if state.isDateVisible {
            withAnimation { state.isDateVisible = false }
        }
    }

}
