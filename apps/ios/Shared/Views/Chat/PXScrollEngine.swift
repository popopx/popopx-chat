//
//  PXScrollEngine.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 25.01.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Scroll Configuration
struct PXScrollConfig {
    static let insetTop: CGFloat = 104
    static let insetBottom: CGFloat = 104
    static let averageItemHeight: CGFloat = 33
    static let scrollBarWidth: CGFloat = 11
    static let scrollStepMultiplier: CGFloat = 0.39
    static let hideAndRemoveDelay: TimeInterval = 0.26
    static let overscrollDampingFactor: CGFloat = 2.1
    static let preloadDebounceNs: UInt64 = 480_000000
    static let lastBatchSize: Int = 48
    static let maxScrollIterations: Int = 180
    static let scrollSlowdownFactor: CGFloat = 0.48

    static var featureEnabled: Bool {
        UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")
    }
    static var adaptiveEnabled: Bool {
        UserDefaults.standard.bool(forKey: "PX_ADAPTIVE_SCROLL_ENABLED")
    }
}

// MARK: - POPOPX Scroll Representable
struct PXScrollRepresentable<Content: View, ScrollItem>: UIViewControllerRepresentable where ScrollItem : Identifiable, ScrollItem: Hashable {

    let scrollView: PXScrollEngine<ScrollItem>
    let content: (Int, ScrollItem) -> Content

    func makeUIViewController(context: Context) -> ScrollController {
        ScrollController.init(scrollView: scrollView, content: content)
    }

    func updateUIViewController(_ controller: ScrollController, context: Context) {}

    class ScrollController: UIViewController, UIGestureRecognizerDelegate {
        let scrollView: PXScrollEngine<ScrollItem>
        fileprivate var items: [ScrollItem] = []
        fileprivate let content: (Int, ScrollItem) -> Content

        fileprivate init(scrollView: PXScrollEngine<ScrollItem>, content: @escaping (Int, ScrollItem) -> Content) {
            self.scrollView = scrollView
            self.content = content
            super.init(nibName: nil, bundle: nil)
            self.view = scrollView
            scrollView.createCell = { [weak self] idx, itms, cls in self?.createCell(idx, itms, &cls) }
            scrollView.updateCell = { [weak self] v, idx, itms in self?.updateCell(cell: v, idx, itms) }
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidLoad() {
            super.viewDidLoad()
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleRepulsionPan(_:)))
            pan.delegate = self
            scrollView.addGestureRecognizer(pan)
        }

        @objc private func handleRepulsionPan(_ gesture: UIPanGestureRecognizer) {
            // Touch repulsion tracking requires TouchRepulsionService.swift added to the Xcode project.
            // When available, convert local/global point and call
            // TouchRepulsionService.shared.update(location:) on .began/.changed
            // and TouchRepulsionService.shared.end() on .ended/.cancelled/.failed.
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        private func createCell(_ index: Int, _ items: [ScrollItem], _ cellsToReuse: inout [UIView]) -> UIView {
            let item: ScrollItem? = index >= 0 && index < items.count ? items[index] : nil
            let cell: UIView
            let c = cellsToReuse.isEmpty ? HostingCell<Content>() : (cellsToReuse.removeLast() as? HostingCell<Content> ?? HostingCell<Content>())
            if let item {
                c.set(content: self.content(index, item), parent: self)
            }
            cell = c
            cell.isHidden = false
            cell.backgroundColor = .clear
            let size = cell.systemLayoutSizeFitting(CGSizeMake(scrollView.bounds.width, CGFloat.greatestFiniteMagnitude))
            cell.frame.size.width = scrollView.bounds.width
            cell.frame.size.height = size.height
            return cell
        }

        private func updateCell(cell: UIView, _ index: Int, _ items: [ScrollItem]) {
            let item = items[index]
            if let cell = cell as? HostingCell<Content> {
                cell.set(content: self.content(index, item), parent: self)
            } else {
                logger.error("PXScrollEngine: unexpected cell type for item at index \(index)")
            }
            let size = cell.systemLayoutSizeFitting(CGSizeMake(scrollView.bounds.width, CGFloat.greatestFiniteMagnitude))
            cell.frame.size.width = scrollView.bounds.width
            cell.frame.size.height = size.height
            cell.setNeedsLayout()
        }
    }
}

// MARK: - POPOPX Scroll Engine
class PXScrollEngine<ScrollItem>: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate where ScrollItem : Identifiable, ScrollItem: Hashable {

    let listState: PXScrollState = PXScrollState()

    var initialOffset: CGFloat = 100000000

    fileprivate static var DEFAULT_ITEM_ID: any Hashable { get { Int64.min } }

    var prevProcessedOffset: CGFloat = 0

    var oldScreenHeight: CGFloat = 0

    var estimatedContentHeight: PXContentMetrics = PXContentMetrics()

    var averageItemHeight: CGFloat = PXScrollConfig.averageItemHeight

    var scrollStepMultiplier: CGFloat = PXScrollConfig.scrollStepMultiplier

    var insetTop: CGFloat = PXScrollConfig.insetTop

    var insetBottom: CGFloat = PXScrollConfig.insetBottom

    var scrollToItemIndexDelayed: Int? = nil

    let scrollBarView: UIScrollView = UIScrollView(frame: .zero)

    var cellsToReuse: [UIView] = []

    var createCell: (Int, [ScrollItem], inout [UIView]) -> UIView? = { _, _, _ in nil }
    var updateCell: (UIView, Int, [ScrollItem]) -> Void = { cell, _, _ in }


    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - PXScrollState (formerly ListState)
    class PXScrollState: NSObject {

        var onUpdateListener: () -> Void = {}

        var items: [ScrollItem] = [] {
            didSet {
                onUpdateListener()
            }
        }

        var totalItemsCount: Int {
            items.count
        }

        var visibleItems: [PXVisibleItem] = []

        var firstVisibleItemIndex: Int = 0

        var firstVisibleItemId: any Hashable = PXScrollEngine<ScrollItem>.DEFAULT_ITEM_ID

        var firstVisibleItemOffset: CGFloat = -100

        var lastVisibleItemIndex: Int {
            visibleItems.last?.index ?? 0
        }

        var itemsCanCoverScreen: Bool = false

        var isScrolling: Bool = false
        var isAnimatedScrolling: Bool = false

        override init() {
            super.init()
        }
    }

    // MARK: - PXVisibleItem
    class PXVisibleItem {
        let index: Int
        let item: ScrollItem
        let view: UIView
        var offset: CGFloat

        init(index: Int, item: ScrollItem, view: UIView, offset: CGFloat) {
            self.index = index
            self.item = item
            self.view = view
            self.offset = offset
        }
    }

    // MARK: - PXContentMetrics (formerly ContentHeight)
    class PXContentMetrics {
        var topOffsetY: CGFloat = 0
        var bottomOffsetY: CGFloat = 0

        var virtualScrollOffsetY: CGFloat = 0

        var overscrolledTop: CGFloat = 0

        var inset: CGFloat = 100

        var height: CGFloat {
            get { bottomOffsetY - topOffsetY }
        }

        var virtualOverscrolledHeight: CGFloat {
            get {
                bottomOffsetY - topOffsetY + overscrolledTop - inset * 2
            }
        }

        func update(
            _ contentOffset: CGPoint,
            _ listState: PXScrollState,
            _ averageItemHeight: CGFloat,
            _ updateStaleHeight: Bool
        ) {
            let lastVisible = listState.visibleItems.last
            let firstVisible = listState.visibleItems.first
            guard let last = lastVisible, let first = firstVisible else {
                topOffsetY = contentOffset.y
                bottomOffsetY = contentOffset.y
                virtualScrollOffsetY = 0
                overscrolledTop = 0
                return
            }
            topOffsetY = last.view.frame.origin.y - CGFloat(listState.totalItemsCount - last.index - 1) * averageItemHeight - self.inset
            bottomOffsetY = first.view.frame.origin.y + first.view.bounds.height + CGFloat(first.index) * averageItemHeight + self.inset
            virtualScrollOffsetY = contentOffset.y - topOffsetY
            overscrolledTop = max(0, last.index == listState.totalItemsCount - 1 ? last.view.frame.origin.y - contentOffset.y : 0)
        }
    }

    var topY: CGFloat {
        get { contentOffset.y }
    }

    var bottomY: CGFloat {
        get { contentOffset.y + bounds.height }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if contentSize.height == 0 {
            setup()
        }
        let newScreenHeight = bounds.height
        if newScreenHeight != oldScreenHeight && oldScreenHeight != 0 {
            contentOffset.y += oldScreenHeight - newScreenHeight
            scrollBarView.frame = CGRectMake(frame.width - PXScrollConfig.scrollBarWidth, self.insetTop, PXScrollConfig.scrollBarWidth, frame.height - self.insetTop - self.insetBottom)
        }
        oldScreenHeight = newScreenHeight
        adaptItems(listState.items, false)
        if let index = scrollToItemIndexDelayed {
            scrollToItem(index)
            scrollToItemIndexDelayed = nil
        }
    }

    private func setup() {
        contentSize = CGSizeMake(frame.size.width, initialOffset * 2)
        prevProcessedOffset = initialOffset
        contentOffset = CGPointMake(0, initialOffset)

        showsVerticalScrollIndicator = false
        scrollBarView.showsHorizontalScrollIndicator = false
        panGestureRecognizer.delegate = self
        addGestureRecognizer(scrollBarView.panGestureRecognizer)
        if let sv = superview {
            sv.addSubview(scrollBarView)
        }
    }

    func updateItems(_ items: [ScrollItem], _ forceReloadVisible: Bool = false) {
        if !Thread.isMainThread {
            logger.error("Use main thread to update items")
            return
        }
        if bounds.height == 0 {
            self.listState.items = items
            return
        }
        adaptItems(items, forceReloadVisible)
        snapToContent(animated: false)
    }

    private func adaptItems(_ items: [ScrollItem], _ forceReloadVisible: Bool, overridenOffset: CGFloat? = nil) {
        if items.isEmpty {
            listState.visibleItems.forEach { item in item.view.removeFromSuperview() }
            listState.visibleItems = []
            listState.itemsCanCoverScreen = false
            listState.firstVisibleItemId = PXScrollEngine<ScrollItem>.DEFAULT_ITEM_ID
            listState.firstVisibleItemIndex = 0
            listState.firstVisibleItemOffset = -insetTop

            estimatedContentHeight.update(contentOffset, listState, averageItemHeight, true)
            scrollBarView.contentSize = .zero
            scrollBarView.contentOffset = .zero

            prevProcessedOffset = contentOffset.y
            if !self.listState.items.isEmpty {
                self.listState.items = items
            }
            return
        }

        let contentOffsetY = overridenOffset ?? contentOffset.y

        var oldVisible = listState.visibleItems
        var newVisible: [PXVisibleItem] = []
        var visibleItemsHeight: CGFloat = 0
        let offsetsDiff = contentOffsetY - prevProcessedOffset

        var shouldBeFirstVisible = items.firstIndex(where: { item in item.id == (listState.firstVisibleItemId as? ScrollItem.ID) }) ?? 0

        var wasFirstVisibleItemOffset = listState.firstVisibleItemOffset
        var alreadyChangedIndexWhileScrolling = false
        var allowOneMore = false
        var nextOffsetY: CGFloat = 0
        var i = shouldBeFirstVisible
        while i >= 0 && i < items.count {
            let item = items[i]
            let visibleIndex = oldVisible.firstIndex(where: { vis in vis.item.id == item.id })
            let visible: PXVisibleItem?
            if let visibleIndex {
                let v = oldVisible.remove(at: visibleIndex)
                if forceReloadVisible || v.view.bounds.width != bounds.width || v.item.hashValue != item.hashValue {
                    let wasHeight = v.view.bounds.height
                    updateCell(v.view, i, items)
                    if wasHeight < v.view.bounds.height && i == 0 && shouldBeFirstVisible == i {
                        v.view.frame.origin.y -= v.view.bounds.height - wasHeight
                    }
                }
                visible = v
            } else {
                visible = nil
            }
            if shouldBeFirstVisible == i {
                if let vis = visible {
                    if (listState.isAnimatedScrolling && vis.view.frame.origin.y + vis.view.bounds.height < contentOffsetY + bounds.height) ||
                        !isVisible(vis.view) {
                        let newIndex: Int
                        if listState.isAnimatedScrolling {
                            var indexDiff = !alreadyChangedIndexWhileScrolling ? Int(ceil(abs(offsetsDiff / averageItemHeight))) : 0
                            alreadyChangedIndexWhileScrolling = true
                            indexDiff = offsetsDiff <= 0 ? indexDiff : -indexDiff
                            newIndex = max(0, min(items.count - 1, i + indexDiff))
                            wasFirstVisibleItemOffset = 0
                        } else {
                            newIndex = i + (offsetsDiff <= 0 ? 1 : -1)
                        }
                        shouldBeFirstVisible = newIndex
                        i = newIndex

                        cellsToReuse.append(vis.view)
                        hideAndRemoveFromSuperviewIfNeeded(vis.view)
                        continue
                    }
                }
                let vis: PXVisibleItem
                if let visible {
                    vis = PXVisibleItem(index: i, item: item, view: visible.view, offset: offsetToBottom(visible.view))
                } else {
                    guard let cell = createCell(i, items, &cellsToReuse) else { continue }
                    cell.frame.origin.y = bottomY + wasFirstVisibleItemOffset - cell.frame.height
                    vis = PXVisibleItem(index: i, item: item, view: cell, offset: offsetToBottom(cell))
                }
                if vis.view.superview == nil {
                    addSubview(vis.view)
                }
                newVisible.append(vis)
                visibleItemsHeight += vis.view.frame.height
                nextOffsetY = vis.view.frame.origin.y
            } else {
                let vis: PXVisibleItem
                if let visible {
                    vis = PXVisibleItem(index: i, item: item, view: visible.view, offset: offsetToBottom(visible.view))
                    nextOffsetY -= vis.view.frame.height
                    vis.view.frame.origin.y = nextOffsetY
                } else {
                    guard let cell = createCell(i, items, &cellsToReuse) else { continue }
                    nextOffsetY -= cell.frame.height
                    cell.frame.origin.y = nextOffsetY
                    vis = PXVisibleItem(index: i, item: item, view: cell, offset: offsetToBottom(cell))
                }
                if vis.view.superview == nil {
                    addSubview(vis.view)
                }
                newVisible.append(vis)
                visibleItemsHeight += vis.view.frame.height
            }
            if abs(nextOffsetY) < contentOffsetY && !allowOneMore {
                break
            } else if abs(nextOffsetY) < contentOffsetY {
                allowOneMore = false
            }
            i += 1
        }
        if let firstVisible = newVisible.first, firstVisible.view.frame.origin.y + firstVisible.view.frame.height < contentOffsetY + bounds.height, firstVisible.index > 0 {
            var offset: CGFloat = firstVisible.view.frame.origin.y + firstVisible.view.frame.height
            let index = firstVisible.index
            for i in stride(from: index - 1, through: 0, by: -1) {
                let item = items[i]
                let visibleIndex = oldVisible.firstIndex(where: { vis in vis.item.id == item.id })
                let vis: PXVisibleItem
                if let visibleIndex {
                    let visible = oldVisible.remove(at: visibleIndex)
                    visible.view.frame.origin.y = offset
                    vis = PXVisibleItem(index: i, item: item, view: visible.view, offset: offsetToBottom(visible.view))
                } else {
                    guard let cell = createCell(i, items, &cellsToReuse) else { continue }
                    cell.frame.origin.y = offset
                    vis = PXVisibleItem(index: i, item: item, view: cell, offset: offsetToBottom(cell))
                }
                if vis.view.superview == nil {
                    addSubview(vis.view)
                }
                offset += vis.view.frame.height
                newVisible.insert(vis, at: 0)
                visibleItemsHeight += vis.view.frame.height
                if offset >= contentOffsetY + bounds.height {
                    break
                }
            }
        }

        oldVisible.forEach { vis in
            cellsToReuse.append(vis.view)
            hideAndRemoveFromSuperviewIfNeeded(vis.view)
        }
        let itemsCountChanged = listState.items.count != items.count
        prevProcessedOffset = contentOffsetY

        listState.visibleItems = newVisible
        listState.itemsCanCoverScreen = visibleItemsHeight >= bounds.height - insetTop

        listState.firstVisibleItemId = listState.visibleItems.first?.item.id ?? PXScrollEngine<ScrollItem>.DEFAULT_ITEM_ID
        listState.firstVisibleItemIndex = listState.visibleItems.first?.index ?? 0
        listState.firstVisibleItemOffset = listState.visibleItems.first?.offset ?? -insetTop
        listState.items = items

        estimatedContentHeight.update(contentOffset, listState, averageItemHeight, itemsCountChanged)
        scrollBarView.contentSize = CGSizeMake(bounds.width, estimatedContentHeight.virtualOverscrolledHeight)
        scrollBarView.contentOffset = CGPointMake(0, estimatedContentHeight.virtualScrollOffsetY)
        scrollBarView.isHidden = listState.visibleItems.count == listState.items.count && (listState.visibleItems.isEmpty || -listState.firstVisibleItemOffset + (listState.visibleItems.last?.offset ?? 0) + insetTop < bounds.height)
    }

    func setScrollPosition(_ index: Int, _ id: Int64, _ offset: CGFloat = 0) {
        listState.firstVisibleItemIndex = index
        listState.firstVisibleItemId = id
        listState.firstVisibleItemOffset = offset == 0 ? -bounds.height + insetTop + insetBottom : offset
    }

    func scrollToItem(_ index: Int, top: Bool = true) {
        if index >= listState.items.count || listState.isScrolling || listState.isAnimatedScrolling {
            return
        }
        if bounds.height == 0 || contentSize.height == 0 {
            scrollToItemIndexDelayed = index
            return
        }
        listState.isScrolling = true
        defer {
            listState.isScrolling = false
        }

        listState.firstVisibleItemIndex = index
        listState.firstVisibleItemId = listState.items[index].id
        listState.firstVisibleItemOffset = -bounds.height + insetTop + insetBottom
        scrollBarView.flashScrollIndicators()
        adaptItems(listState.items, false)

        var adjustedOffset = self.contentOffset.y
        var i = 0

        var upPrev = index > listState.firstVisibleItemIndex

        var stepSlowdownMultiplier: CGFloat = 1
        while i < PXScrollConfig.maxScrollIterations {
            let up = index > listState.firstVisibleItemIndex
            if upPrev != up {
                stepSlowdownMultiplier = stepSlowdownMultiplier * PXScrollConfig.scrollSlowdownFactor
                upPrev = up
            }

            let firstOrLastIndex = up ? listState.visibleItems.last?.index ?? 0 : listState.firstVisibleItemIndex
            let step: CGFloat = max(0.1, CGFloat(abs(index - firstOrLastIndex)) * scrollStepMultiplier) * stepSlowdownMultiplier

            let offsetToScroll = (up ? -averageItemHeight : averageItemHeight) * step
            adjustedOffset += offsetToScroll
            if let item = listState.visibleItems.first(where: { $0.index == index }) {
                let y = if top {
                    min(estimatedContentHeight.bottomOffsetY - bounds.height, item.view.frame.origin.y - insetTop)
                } else {
                    max(estimatedContentHeight.topOffsetY - insetTop - insetBottom, item.view.frame.origin.y + item.view.bounds.height - bounds.height + insetBottom)
                }
                setContentOffset(CGPointMake(contentOffset.x, y), animated: false)
                scrollBarView.flashScrollIndicators()
                break
            }
            contentOffset = CGPointMake(contentOffset.x, adjustedOffset)
            adaptItems(listState.items, false)
            snapToContent(animated: false)
            i += 1
        }
        adaptItems(listState.items, false)
        snapToContent(animated: false)
        estimatedContentHeight.update(contentOffset, listState, averageItemHeight, true)
    }

    func scrollToItemAnimated(_ index: Int, top: Bool = true) async {
        if index >= listState.items.count || listState.isScrolling || listState.isAnimatedScrolling {
            return
        }
        listState.isAnimatedScrolling = true
        defer {
            listState.isAnimatedScrolling = false
        }

        if UIAccessibility.isReduceMotionEnabled {
            scrollToItem(index, top: top)
            return
        }

        var adjustedOffset = self.contentOffset.y
        var i = 0

        var upPrev = index > listState.firstVisibleItemIndex

        var stepSlowdownMultiplier: CGFloat = 1
        while i < PXScrollConfig.maxScrollIterations {
            let up = index > listState.firstVisibleItemIndex
            if upPrev != up {
                stepSlowdownMultiplier = stepSlowdownMultiplier * PXScrollConfig.scrollSlowdownFactor
                upPrev = up
            }

            let firstOrLastIndex = up ? listState.visibleItems.last?.index ?? 0 : listState.firstVisibleItemIndex
            let step: CGFloat = max(0.1, CGFloat(abs(index - firstOrLastIndex)) * scrollStepMultiplier) * stepSlowdownMultiplier

            let offsetToScroll = (up ? -averageItemHeight : averageItemHeight) * step
            adjustedOffset += offsetToScroll
            if let item = listState.visibleItems.first(where: { $0.index == index }) {
                let y = if top {
                    min(estimatedContentHeight.bottomOffsetY - bounds.height, item.view.frame.origin.y - insetTop)
                } else {
                    max(estimatedContentHeight.topOffsetY - insetTop - insetBottom, item.view.frame.origin.y + item.view.bounds.height - bounds.height + insetBottom)
                }
                let animated = !UIAccessibility.isReduceMotionEnabled
                setContentOffset(CGPointMake(contentOffset.x, y), animated: animated)
                scrollBarView.flashScrollIndicators()
                break
            }
            contentOffset = CGPointMake(contentOffset.x, adjustedOffset)

            if prevProcessedOffset - contentOffset.y != 0 {
                adaptItems(listState.items, false)
                snapToContent(animated: false)
            }
            await MainActor.run {}

            i += 1
        }
        estimatedContentHeight.update(contentOffset, listState, averageItemHeight, true)
    }

    func scrollToBottom() {
        scrollToItem(0, top: false)
    }

    func scrollToBottomAnimated() {
        Task {
            await scrollToItemAnimated(0, top: false)
        }
    }

    func scroll(by: CGFloat, animated: Bool = true) {
        setContentOffset(CGPointMake(contentOffset.x, contentOffset.y + by), animated: animated)
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if !listState.items.isEmpty {
            scrollToBottomAnimated()
        }
        return false
    }

    private func snapToContent(animated: Bool) {
        let topBlankSpace = estimatedContentHeight.height < bounds.height ? bounds.height - estimatedContentHeight.height : 0
        if topY < estimatedContentHeight.topOffsetY - topBlankSpace {
            setContentOffset(CGPointMake(0, estimatedContentHeight.topOffsetY - topBlankSpace), animated: animated)
        } else if bottomY > estimatedContentHeight.bottomOffsetY {
            setContentOffset(CGPointMake(0, estimatedContentHeight.bottomOffsetY - bounds.height), animated: animated)
        }
    }

    func offsetToBottom(_ view: UIView) -> CGFloat {
        bottomY - (view.frame.origin.y + view.frame.height)
    }

    func hideAndRemoveFromSuperviewIfNeeded(_ view: UIView) {
        if view.isHidden {
            return
        }
        (view as? ReusableView)?.prepareForReuse()
        view.isHidden = true
        let removeDelay: TimeInterval = PXScrollConfig.hideAndRemoveDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + removeDelay) {
            if view.isHidden { view.removeFromSuperview() }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToContent(animated: true)
        }
    }

    override var contentOffset: CGPoint {
        get { super.contentOffset }
        set {
            var newOffset = newValue
            let topBlankSpace = estimatedContentHeight.height < bounds.height ? bounds.height - estimatedContentHeight.height : 0
            if contentOffset.y > 0 && newOffset.y < estimatedContentHeight.topOffsetY - topBlankSpace && contentOffset.y > newOffset.y {
                if !isDecelerating {
                    newOffset.y = min(contentOffset.y, newOffset.y + abs(newOffset.y - estimatedContentHeight.topOffsetY + topBlankSpace) / PXScrollConfig.overscrollDampingFactor)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.setContentOffset(newValue, animated: false)
                        self?.snapToContent(animated: true)
                    }
                }
            } else if contentOffset.y > 0 && newOffset.y + bounds.height > estimatedContentHeight.bottomOffsetY && contentOffset.y < newOffset.y {
                if !isDecelerating {
                    newOffset.y = max(contentOffset.y, newOffset.y - abs(newOffset.y + bounds.height - estimatedContentHeight.bottomOffsetY) / PXScrollConfig.overscrollDampingFactor)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.setContentOffset(newValue, animated: false)
                        self?.snapToContent(animated: true)
                    }
                }
            }
            super.contentOffset = newOffset
        }
    }

    private func stopScrolling() {
        let pxTopDistance = abs(contentOffset.y - estimatedContentHeight.topOffsetY)
        let pxBottomDistance = abs(bottomY - estimatedContentHeight.bottomOffsetY)
        let offsetYToStopAt = pxTopDistance < pxBottomDistance
            ? estimatedContentHeight.topOffsetY
            : estimatedContentHeight.bottomOffsetY - bounds.height
        setContentOffset(CGPointMake(contentOffset.x, offsetYToStopAt), animated: false)
    }

    func isVisible(_ view: UIView) -> Bool {
        if view.superview == nil {
             return false
        }
        return view.frame.intersects(CGRectMake(0, contentOffset.y, bounds.width, bounds.height))
    }
}

// MARK: - POPOPX Scroll Loading (merged from ChatScrollHelpers)
@MainActor
func pxLoadLastItems(_ loadingMoreItems: Binding<Bool>, loadingBottomItems: Binding<Bool>, _ chat: Chat, _ im: ItemsModel) async {
    await MainActor.run {
        loadingMoreItems.wrappedValue = true
        loadingBottomItems.wrappedValue = true
    }
    try? await Task.sleep(nanoseconds: PXScrollConfig.preloadDebounceNs)
    if ChatModel.shared.chatId != chat.chatInfo.id {
        await MainActor.run {
            loadingMoreItems.wrappedValue = false
            loadingBottomItems.wrappedValue = false
        }
        return
    }
    await apiLoadMessages(chat.chatInfo.id, im, ChatPagination.last(count: PXScrollConfig.lastBatchSize))
    await MainActor.run {
        loadingMoreItems.wrappedValue = false
        loadingBottomItems.wrappedValue = false
    }
}

@MainActor
func pxPreloadIfNeeded(
    _ im: ItemsModel,
    _ allowLoadMoreItems: Binding<Bool>,
    _ ignoreLoadingRequests: Binding<Int64?>,
    _ listState: PXScrollEngine<MergedItem>.PXScrollState,
    _ mergedItems: BoxedValue<MergedItems>,
    loadItems: @escaping (Bool, ChatPagination) async -> Bool,
    loadLastItems: @escaping () async -> Void
) {
    let state = im.preloadState
    guard !listState.isScrolling && !listState.isAnimatedScrolling,
          !state.preloading,
          listState.totalItemsCount > 0
    else {
        return
    }
    guard let firstVisibleId = listState.firstVisibleItemId as? Int64 else { return }
    if state.prevFirstVisible != firstVisibleId || state.prevItemsCount != mergedItems.boxedValue.indexInParentItems.count {
        state.preloading = true
        let allowLoadMore = allowLoadMoreItems.wrappedValue
        Task {
            defer { state.preloading = false }
            var triedToLoad = true
            await pxPreloadItems(im, mergedItems.boxedValue, allowLoadMore, listState, ignoreLoadingRequests) { pagination in
                triedToLoad = await loadItems(false, pagination)
                return triedToLoad
            }
            if triedToLoad {
                state.prevFirstVisible = firstVisibleId
                state.prevItemsCount = mergedItems.boxedValue.indexInParentItems.count
            }
            if listState.itemsCanCoverScreen && !im.lastItemsLoaded {
                await loadLastItems()
            }
        }
    } else if listState.itemsCanCoverScreen && !im.lastItemsLoaded {
        state.preloading = true
        Task {
            defer { state.preloading = false }
            await loadLastItems()
        }
    }
}

@MainActor
func pxPreloadItems(
    _ im: ItemsModel,
    _ mergedItems: MergedItems,
    _ allowLoadMoreItems: Bool,
    _ listState: PXScrollEngine<MergedItem>.PXScrollState,
    _ ignoreLoadingRequests: Binding<Int64?>,
    _ loadItems: @escaping (ChatPagination) async -> Bool)
async {
    let allowLoad = allowLoadMoreItems || mergedItems.items.count == listState.lastVisibleItemIndex + 1
    let remaining = ChatPagination.UNTIL_PRELOAD_COUNT
    let firstVisibleIndex = listState.firstVisibleItemIndex

    if !(await preloadItemsBefore()) {
        await preloadItemsAfter()
    }

    func preloadItemsBefore() async -> Bool {
        let splits = mergedItems.splits
        let lastVisibleIndex = listState.lastVisibleItemIndex
        var lastIndexToLoadFrom: Int? = pxFindLastIndexToLoadFromInSplits(firstVisibleIndex, lastVisibleIndex, remaining, splits)
        let items: [ChatItem] = im.reversedChatItems.reversed()
        if splits.isEmpty && !items.isEmpty && lastVisibleIndex > mergedItems.items.count - remaining {
            lastIndexToLoadFrom = items.count - 1
        }
        let loadFromItemId: Int64?
        if allowLoad, let lastIndexToLoadFrom {
            let index = items.count - 1 - lastIndexToLoadFrom
            loadFromItemId = index >= 0 ? items[index].id : nil
        } else {
            loadFromItemId = nil
        }
        guard let loadFromItemId, ignoreLoadingRequests.wrappedValue != loadFromItemId else {
            return false
        }
        let sizeWas = items.count
        let firstItemIdWas = items.first?.id
        let triedToLoad = await loadItems(ChatPagination.before(chatItemId: loadFromItemId, count: ChatPagination.PRELOAD_COUNT))
        if triedToLoad && sizeWas == im.reversedChatItems.count && firstItemIdWas == im.reversedChatItems.last?.id {
            ignoreLoadingRequests.wrappedValue = loadFromItemId
            return false
        }
        return triedToLoad
    }

    func preloadItemsAfter() async {
        let splits = mergedItems.splits
        let split = splits.last(where: { $0.indexRangeInParentItems.contains(firstVisibleIndex) })
        let reversedItems: [ChatItem] = im.reversedChatItems
        if let split, split.indexRangeInParentItems.lowerBound + remaining > firstVisibleIndex {
            let index = split.indexRangeInReversed.lowerBound
            if index >= 0 {
                let loadFromItemId = reversedItems[index].id
                _ = await loadItems(ChatPagination.after(chatItemId: loadFromItemId, count: ChatPagination.PRELOAD_COUNT))
            }
        }
    }
}

func pxOldestPartiallyVisibleListItemOrNull(_ listState: PXScrollEngine<MergedItem>.PXScrollState) -> ListItem? {
    if listState.lastVisibleItemIndex < listState.items.count {
        return listState.items[listState.lastVisibleItemIndex].oldest()
    } else {
        return listState.items.last?.oldest()
    }
}

private func pxFindLastIndexToLoadFromInSplits(_ firstVisibleIndex: Int, _ lastVisibleIndex: Int, _ remaining: Int, _ splits: [SplitRange]) -> Int? {
    for split in splits {
        if split.indexRangeInParentItems.lowerBound > firstVisibleIndex {
            if lastVisibleIndex > (split.indexRangeInParentItems.lowerBound - remaining) {
                return split.indexRangeInReversed.lowerBound - 1
            }
            break
        }
        let containsInRange = split.indexRangeInParentItems.contains(firstVisibleIndex)
        if containsInRange {
            if lastVisibleIndex > (split.indexRangeInParentItems.upperBound - remaining) {
                return split.indexRangeInReversed.upperBound
            }
            break
        }
    }
    return nil
}

func pxWithConditionalAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(animation, body)
}

// MARK: - POPOPX Extensions
extension PXScrollEngine {
    var pxComponentTag: String { "PX_SCROLL_ENGINE" }
    var pxVisibleRatio: CGFloat {
        guard listState.items.count > 0 else { return 0 }
        return CGFloat(listState.visibleItems.count) / CGFloat(listState.totalItemsCount)
    }
    var pxEstimatedTotalHeight: CGFloat { estimatedContentHeight.height }
}

extension PXScrollRepresentable {
    var pxComponentTag: String { "PX_SCROLL_REPRESENTABLE" }
}
