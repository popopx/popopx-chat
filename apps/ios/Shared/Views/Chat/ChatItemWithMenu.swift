//
//  ChatItemWithMenu.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch
import SwiftyGif
import Photos

// Spec: spec/client/chat-view.md#ChatItemWithMenu
struct ChatItemWithMenu: View {
    @ObservedObject var im: ItemsModel
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DEFAULT_PROFILE_IMAGE_CORNER_RADIUS) private var profileRadius = defaultProfileImageCorner
    @ObservedObject var chat: Chat
    @ObservedObject var dummyModel: ChatItemDummyModel = .shared
    // POPOPX: @ObservedObject removed — visualEffect reads TouchRepulsionService.shared directly, no body re-render cascade
    let index: Int
    let isLastItem: Bool
    let chatItem: ChatItem
    let scrollToItem: (ChatItem.ID) -> Void
    @Binding var scrollToItemId: ChatItem.ID?
    let merged: MergedItem
    let maxWidth: CGFloat
    @Binding var composeState: ComposeState
    @Binding var selectedMember: GMember?
    @Binding var showChatInfoSheet: Bool
    @Binding var revealedItems: Set<Int64>

    @State private var deletingItem: ChatItem? = nil
    @State private var showDeleteMessage = false
    @State private var deletingItems: [Int64] = []
    @State private var showDeleteMessages = false
    @State private var archivingReports: Set<Int64>? = nil
    @State private var showArchivingReports = false
    @State private var showChatItemInfoSheet: Bool = false
    @State private var chatItemInfo: ChatItemInfo?
    @State private var msgWidth: CGFloat = 0
    @State private var touchInProgress: Bool = false

    @Binding var selectedChatItems: Set<Int64>?
    @Binding var forwardedChatItems: [ChatItem]

    @Binding var searchText: String
    @Binding var contentFilter: ContentFilter?
    var closeKeyboardAndRun: (@escaping () -> Void) -> Void

    @State private var allowMenu: Bool = true
    @State private var markedRead = false
    @State private var markReadTask: Task<Void, Never>? = nil
    @State private var actionSheet: SomeActionSheet? = nil
    @State private var swipeOffset: CGFloat = 0
    @State private var popSwipeOffset: CGFloat = 0
    @State private var isPopping: Bool = false

    var revealed: Bool { revealedItems.contains(chatItem.id) }

    typealias ItemSeparation = (timestamp: Bool, largeGap: Bool, date: Date?)

    private func reveal(_ yes: Bool) -> Void {
        merged.revealItems(yes, $revealedItems)
    }

    func getItemSeparation(_ chatItem: ChatItem, _ prevItem: ChatItem?) -> ItemSeparation {
        guard let prevItem else {
            return ItemSeparation(timestamp: true, largeGap: true, date: nil)
        }

        let sameMemberAndDirection = if case .groupRcv(let prevGroupMember) = prevItem.chatDir, case .groupRcv(let groupMember) = chatItem.chatDir {
            groupMember.groupMemberId == prevGroupMember.groupMemberId
        } else if case .channelRcv = chatItem.chatDir, case .channelRcv = prevItem.chatDir {
            true
        } else {
            chatItem.chatDir.sent == prevItem.chatDir.sent
        }
        let largeGap = !sameMemberAndDirection || prevItem.meta.itemTs.timeIntervalSince(chatItem.meta.itemTs) > 60

        return ItemSeparation(
            timestamp: largeGap || formatTimestampMeta(chatItem.meta.itemTs) != formatTimestampMeta(prevItem.meta.itemTs),
            largeGap: largeGap,
            date: Calendar.current.isDate(chatItem.meta.itemTs, inSameDayAs: prevItem.meta.itemTs) ? nil : prevItem.meta.itemTs
        )
    }

    func shouldShowAvatar(_ current: ChatItem, _ older: ChatItem?) -> Bool {
        let oldIsGroupRcv = switch older?.chatDir {
        case .groupRcv: true
        case .channelRcv: true
        default: false
        }
        let sameMember = switch (older?.chatDir, current.chatDir) {
        case (.groupRcv(let oldMember), .groupRcv(let member)):
            oldMember.memberId == member.memberId
        case (.channelRcv, .channelRcv):
            true
        default:
            false
        }
        if case .groupRcv = current.chatDir, (older == nil || (!oldIsGroupRcv || !sameMember)) {
            return true
        } else if case .channelRcv = current.chatDir, (older == nil || (!oldIsGroupRcv || !sameMember)) {
            return true
        } else {
            return false
        }
    }

    var body: AnyView {
        let listItem = merged.newest()
        let last = isLastItem ? im.reversedChatItems.last : nil
        let item = listItem.item
        let range: ClosedRange<Int>? = if case let .grouped(_, _, _, rangeInReversed, _, _, _, _) = merged {
            rangeInReversed.boxedValue
        } else {
            nil
        }
        let showAvatar = shouldShowAvatar(item, merged.oldest().nextItem)
            let single = switch merged {
            case .single: true
            default: false
            }
            let itemSeparation = getItemSeparation(item, single || revealed ? listItem.prevItem: nil)
        return AnyView(VStack(spacing: 0) {
            if let last {
                DateSeparator(date: last.meta.itemTs).padding(8)
            }
            chatItemListView(range, showAvatar, item, itemSeparation)
                .overlay {
                    if let selected = selectedChatItems, chatItem.canBeDeletedForSelf {
                        Color.clear
                            .contentShape(Rectangle())
                            .simultaneousGesture(TapGesture().onEnded {
                                let checked = selected.contains(chatItem.id)
                                selectUnselectChatItem(select: !checked, chatItem)
                            })
                    }
                }
            if let date = itemSeparation.date {
                DateSeparator(date: date).padding(8)
            }
        }
        .onAppear {
            if markedRead {
                return
            } else {
                markedRead = true
            }
            if let range {
                let (itemIds, unreadMentions) = unreadItemIds(range)
                if !itemIds.isEmpty {
                    waitToMarkRead {
                        await apiMarkChatItemsRead(im, chat.chatInfo, itemIds, mentionsRead: unreadMentions)
                    }
                }
            } else if chatItem.isRcvNew  {
                waitToMarkRead {
                    await apiMarkChatItemsRead(im, chat.chatInfo, [chatItem.id], mentionsRead: chatItem.meta.userMention ? 1 : 0)
                }
            }
        }
        .onDisappear {
            markReadTask?.cancel()
            markedRead = false
        }
        .actionSheet(item: $actionSheet) { $0.actionSheet }
        // skip updating struct on touch if no need to show GoTo button
        .if(touchInProgress || searchIsNotBlank || (chatItem.meta.itemForwarded != nil && chatItem.meta.itemForwarded != .unknown)) {
            // long press listener steals taps from top-level listener, so repeating it's logic here as well
            $0.onTapGesture {
                hideKeyboard()
            }
            .onLongPressGesture(minimumDuration: .infinity, perform: {}, onPressingChanged: { pressing in
                touchInProgress = pressing
            })
        }
        )
    }

    private func unreadItemIds(_ range: ClosedRange<Int>) -> ([ChatItem.ID], Int) {
        var unreadItems: [ChatItem.ID] = []
        var unreadMentions: Int = 0

        for i in range {
            if i < 0 || i >= im.reversedChatItems.count {
                break
            }
            let ci = im.reversedChatItems[i]
            if ci.isRcvNew {
                unreadItems.append(ci.id)
                if ci.meta.userMention {
                    unreadMentions += 1
                }
            }
        }

        return (unreadItems, unreadMentions)
    }

    private func waitToMarkRead(_ op: @Sendable @escaping () async -> Void) {
        markReadTask = Task {
            do {
                _ = try await Task.sleep(nanoseconds: 600_000000)
                if m.chatId == chat.chatInfo.id {
                    await op()
                }
            } catch {
                // task was cancelled
            }
        }
    }

    private var searchIsNotBlank: Bool {
        get {
            (searchText.count > 0 && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || contentFilter != nil
        }
    }

    struct MemberLayout: Layout {
        let spacing: Double
        let msgWidth: Double

        private func sizes(subviews: Subviews, proposal: ProposedViewSize) -> (CGSize, CGSize) {
            guard subviews.count == 2 else { return (.zero, .zero) }
            let roleSize = subviews[1].sizeThatFits(proposal)
            let memberSize = subviews[0].sizeThatFits(
                ProposedViewSize(
                    width: (proposal.width ?? msgWidth) - roleSize.width,
                    height: proposal.height
                )
            )
            return (memberSize, roleSize)
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
            let (memberSize, roleSize) = sizes(subviews: subviews, proposal: proposal)
            return CGSize(
                width: min(
                    proposal.width ?? msgWidth,
                    max(msgWidth, roleSize.width + spacing + memberSize.width)
                ),
                height: max(memberSize.height, roleSize.height)
            )
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
            let (memberSize, roleSize) = sizes(subviews: subviews, proposal: proposal)
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY - memberSize.height / 2),
                proposal: ProposedViewSize(memberSize)
            )
            subviews[1].place(
                at: CGPoint(
                    x: bounds.minX + max(memberSize.width + spacing, msgWidth - roleSize.width),
                    y: bounds.midY - roleSize.height / 2
                ),
                proposal: ProposedViewSize(roleSize)
            )
        }
    }

    @ViewBuilder func chatItemListView(
        _ range: ClosedRange<Int>?,
        _ showAvatar: Bool,
        _ ci: ChatItem,
        _ itemSeparation: ItemSeparation
    ) -> some View {
        let bottomPadding: Double = itemSeparation.largeGap ? 10 : 2
        if case .channelRcv = ci.chatDir,
           case let .group(groupInfo, _) = chat.chatInfo {
            if showAvatar {
                VStack(alignment: .leading, spacing: 4) {
                    if ci.content.showMemberName {
                        Group {
                            Group {
                                MemberLayout(spacing: 16, msgWidth: msgWidth) {
                                    Text(groupInfo.chatViewName)
                                        .lineLimit(1)
                                    Text(NSLocalizedString("channel", comment: "shown as sender role for channel messages"))
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .padding(.trailing, 8)
                                }
                            }
                            .frame(
                                maxWidth: maxWidth,
                                alignment: chatItem.chatDir.sent ? .trailing : .leading
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, memberImageSize + 14 + (selectedChatItems != nil && ci.canBeDeletedForSelf ? 12 + 24 : 0))
                        .padding(.top, 3)
                    }
                    HStack(alignment: .center, spacing: 0) {
                        if selectedChatItems != nil && ci.canBeDeletedForSelf {
                            SelectedChatItem(ciId: ci.id, selectedChatItems: $selectedChatItems)
                                .padding(.trailing, 12)
                        }
                        HStack(alignment: .top, spacing: 10) {
                            ProfileImage(imageStr: groupInfo.image, iconName: groupInfo.chatIconName, size: memberImageSize, backgroundColor: theme.colors.background)
                                .simultaneousGesture(TapGesture().onEnded {
                                    showChatInfoSheet = true
                                })
                            chatItemWithMenu(ci, range, maxWidth, itemSeparation)
                                .onPreferenceChange(DetermineWidth.Key.self) { msgWidth = $0 }
                        }
                    }
                }
                .padding(.bottom, bottomPadding)
                .padding(.trailing)
                .padding(.leading, 12)
            } else {
                HStack(alignment: .center, spacing: 0) {
                    if selectedChatItems != nil && ci.canBeDeletedForSelf {
                        SelectedChatItem(ciId: ci.id, selectedChatItems: $selectedChatItems)
                            .padding(.leading, 12)
                    }
                    chatItemWithMenu(ci, range, maxWidth, itemSeparation)
                        .padding(.trailing)
                        .padding(.leading, 10 + memberImageSize + 12)
                }
                .padding(.bottom, bottomPadding)
            }
        } else if case let .groupRcv(member) = ci.chatDir,
           case let .group(groupInfo, _) = chat.chatInfo {
            if showAvatar {
                VStack(alignment: .leading, spacing: 4) {
                    if ci.content.showMemberName {
                        Group {
                            let (prevMember, memCount): (GroupMember?, Int) =
                            if let range = range {
                                m.getPrevHiddenMember(member, range)
                            } else {
                                (nil, 1)
                            }
                            if memCount == 1 && (member.memberRole > .member || ci.meta.showGroupAsSender) {
                                let (name, role) = if ci.meta.showGroupAsSender {
                                    (groupInfo.chatViewName, NSLocalizedString("group", comment: "shown on group welcome message"))
                                } else {
                                    (member.chatViewName, member.memberRole.text)
                                }
                                Group {
                                    MemberLayout(spacing: 16, msgWidth: msgWidth) {
                                        NameWithBadge(Text(name), ci.meta.showGroupAsSender ? nil : member.nameBadge, .caption1)
                                            .lineLimit(1)
                                        Text(role)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .padding(.trailing, 8)
                                    }
                                }
                                .frame(
                                    maxWidth: maxWidth,
                                    alignment: chatItem.chatDir.sent ? .trailing : .leading
                                )
                            } else {
                                NameWithBadge(Text(memberNames(member, prevMember, memCount)), memCount == 1 ? member.nameBadge : nil, .caption1)
                                    .lineLimit(2)
                            }
                        }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, memberImageSize + 14 + (selectedChatItems != nil && ci.canBeDeletedForSelf ? 12 + 24 : 0))
                            .padding(.top, 3) // this is in addition to message sequence gap
                    }
                    HStack(alignment: .center, spacing: 0) {
                        if selectedChatItems != nil && ci.canBeDeletedForSelf {
                            SelectedChatItem(ciId: ci.id, selectedChatItems: $selectedChatItems)
                                .padding(.trailing, 12)
                        }
                        HStack(alignment: .top, spacing: 10) {
                            if ci.meta.showGroupAsSender {
                                ProfileImage(imageStr: groupInfo.image, iconName: groupInfo.chatIconName, size: memberImageSize, backgroundColor: theme.colors.background)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        showChatInfoSheet = true
                                    })
                            } else {
                                MemberProfileImage(member, size: memberImageSize, backgroundColor: theme.colors.background)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        if let mem = m.getGroupMember(member.groupMemberId) {
                                            selectedMember = mem
                                        } else {
                                            let mem = GMember.init(member)
                                            m.groupMembers.append(mem)
                                            m.groupMembersIndexes[member.groupMemberId] = m.groupMembers.count - 1
                                            selectedMember = mem
                                        }
                                    })
                            }
                            chatItemWithMenu(ci, range, maxWidth, itemSeparation)
                                .onPreferenceChange(DetermineWidth.Key.self) { msgWidth = $0 }
                        }
                    }
                }
                .padding(.bottom, bottomPadding)
                .padding(.trailing)
                .padding(.leading, 12)
            } else {
                HStack(alignment: .center, spacing: 0) {
                    if selectedChatItems != nil && ci.canBeDeletedForSelf {
                        SelectedChatItem(ciId: ci.id, selectedChatItems: $selectedChatItems)
                            .padding(.leading, 12)
                    }
                    chatItemWithMenu(ci, range, maxWidth, itemSeparation)
                        .padding(.trailing)
                        .padding(.leading, 10 + memberImageSize + 12)
                }
                .padding(.bottom, bottomPadding)
            }
        } else {
            HStack(alignment: .center, spacing: 0) {
                if selectedChatItems != nil && ci.canBeDeletedForSelf {
                    if chat.chatInfo.chatType == .group {
                        SelectedChatItem(ciId: ci.id, selectedChatItems: $selectedChatItems)
                            .padding(.leading, 12)
                    } else {
                        SelectedChatItem(ciId: ci.id, selectedChatItems: $selectedChatItems)
                            .padding(.leading)
                    }
                }
                chatItemWithMenu(ci, range, maxWidth, itemSeparation)
                    .padding(.horizontal)
            }
            .padding(.bottom, bottomPadding)
        }
    }

    private func memberNames(_ member: GroupMember, _ prevMember: GroupMember?, _ memCount: Int) -> LocalizedStringKey {
        let name = member.displayName
        return if let prevName = prevMember?.displayName {
            memCount > 2
            ? "\(name), \(prevName) and \(memCount - 2) members"
            : "\(name) and \(prevName)"
        } else {
            "\(name)"
        }
    }

    func chatItemWithMenu(_ ci: ChatItem, _ range: ClosedRange<Int>?, _ maxWidth: CGFloat, _ itemSeparation: ItemSeparation) -> AnyView {
        let alignment: Alignment = ci.chatDir.sent ? .trailing : .leading
        let live = composeState.liveMessage != nil
        let canReply = ci.meta.itemDeleted == nil && !ci.isLiveDummy && !live && !ci.localNote && selectedChatItems == nil && chat.chatInfo.sendMsgEnabled
        return AnyView(ZStack(alignment: .trailing) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.headline)
                .foregroundColor(.secondary)
                .opacity(min(1, -swipeOffset / 30))
                .offset(x: swipeOffset + 40)
            VStack(alignment: alignment.horizontal, spacing: 3) {
                HStack {
                    if ci.chatDir.sent {
                        goToItemButton(true)
                    }
                    PXChatItem(
                        chat: chat,
                        im: im,
                        chatItem: ci,
                        scrollToItem: scrollToItem,
                        scrollToItemId: $scrollToItemId,
                        maxWidth: maxWidth,
                        allowMenu: $allowMenu
                    )
                    .environment(\.revealed, revealed)
                    .environment(\.showTimestamp, itemSeparation.timestamp)
                    .modifier(ChatItemClipped(ci, tailVisible: itemSeparation.largeGap && (ci.meta.itemDeleted == nil || revealed)))
                    // POPOPX: shadow removed — already applied in PXFramedItemView, was duplicating GPU pass
                    .contextMenu { menu(ci, range, live: live) }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel({
                        var parts: [String] = []
                        if !ci.chatDir.sent, let sender = ci.memberDisplayName { parts.append(sender) }
                        if !ci.content.text.isEmpty { parts.append(ci.content.text) }
                        return parts.joined(separator: ", ")
                    }())
                    .accessibilityHint(String(localized: "Swipe left to reply"))
                    if !ci.chatDir.sent {
                        goToItemButton(false)
                    }
                }
                if ci.content.msgContent != nil && (ci.meta.itemDeleted == nil || revealed) && ci.reactions.count > 0 {
                    chatItemReactions(ci)
                        .padding(.bottom, 4)
                }
            }
            // POPOPX: liquidFloat removed for battery — chat-list float preserved
            // POPOPX: touch repulsion via visualEffect — no GeometryReader/onChange/@State cascade
            // POPOPX: capture @MainActor values before Sendable closure
            .visualEffect { [swipeOffset, popSwipeOffset] content, proxy in
                let touchLocation = TouchRepulsionService.shared.touchLocation
                let radius = TouchRepulsionService.pxRepulsionRadius
                let maxDisp = TouchRepulsionService.pxMaxDisplacement
                let frame = proxy.frame(in: .global)
                let itemCenter = CGPoint(x: frame.midX, y: frame.midY)
                guard let touchLocation else {
                    return content.offset(x: swipeOffset + popSwipeOffset)
                }
                let dx = itemCenter.x - touchLocation.x
                let dy = itemCenter.y - touchLocation.y
                let distance = sqrt(dx * dx + dy * dy)
                // POPOPX: epsilon threshold avoids snap-at-center; smoothstep fade at boundary edge
                guard distance < radius, distance > 0.5 else {
                    return content.offset(x: swipeOffset + popSwipeOffset)
                }
                let normalized = distance / radius
                let smoothFade = normalized < 0.8 ? 1.0 : max(0, (1.0 - normalized) / 0.2)
                let force = (1.0 - normalized) * smoothFade * maxDisp
                let angle = atan2(dy, dx)
                let repulsionX = cos(angle) * force
                let repulsionY = sin(angle) * force
                return content.offset(x: repulsionX + swipeOffset + popSwipeOffset, y: repulsionY)
            }
            .zIndex(swipeOffset != 0 || popSwipeOffset != 0 ? 1 : 0) // POPOPX: swiped bubble renders above neighbors
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let x = value.translation.width
                        if x < 0 {
                            guard canReply else { return }
                            swipeOffset = max(x * 0.63, -56)
                        } else if x > 0 {
                            guard canSwipeToPop(ci) else { return }
                            popSwipeOffset = min(x * 0.63, 56)
                            let progress = popSwipeOffset / 56
                            if Int(progress * 10) % 3 == 0 {
                                BubbleHapticsManager.shared.swipeTrail(intensity: Float(progress) * 0.5)
                            }
                        }
                    }
                    .onEnded { _ in
                        if swipeOffset < -42 {
                            withAnimation {
                                if composeState.editing {
                                    composeState = ComposeState(contextItem: .quotedItem(chatItem: ci))
                                } else {
                                    composeState = composeState.copy(contextItem: .quotedItem(chatItem: ci))
                                }
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        if popSwipeOffset > 34 && canSwipeToPop(ci) {
                            triggerSwipeToPop(ci)
                        }
                        let animation: Animation = reduceMotion ? .default : .spring(response: 0.25)
                        withAnimation(animation) {
                            swipeOffset = 0
                            if !isPopping {
                                popSwipeOffset = 0
                            }
                        }
                    }
            )
        }
            .confirmationDialog(NSLocalizedString("Delete message?", comment: "confirmation dialog title"), isPresented: $showDeleteMessage, titleVisibility: .visible) {
                if publicGroupEditor(chat) {
                    Button(NSLocalizedString("compose_delete_from_history", comment: "Delete message from history button"), role: .destructive) {
                        deleteMessage(.cidmHistory, moderate: false)
                    }
                } else {
                    Button(NSLocalizedString("Delete for me", comment: "delete message button"), role: .destructive) {
                        deleteMessage(.cidmInternal, moderate: false)
                    }
                }
                if let di = deletingItem, di.meta.deletable && !di.localNote && !di.isReport {
                    Button(broadcastDeleteButtonText(chat), role: .destructive) {
                        deleteMessage(.cidmBroadcast, moderate: false)
                    }
                }
            }
            .confirmationDialog(deleteMessagesTitle, isPresented: $showDeleteMessages, titleVisibility: .visible) {
                if publicGroupEditor(chat) {
                    Button(NSLocalizedString("compose_delete_from_history", comment: "Delete messages from history button"), role: .destructive) {
                        deleteMessages(chat, deletingItems, .cidmHistory, moderate: false)
                    }
                } else {
                    Button(NSLocalizedString("Delete for me", comment: "delete message button"), role: .destructive) {
                        deleteMessages(chat, deletingItems, moderate: false)
                    }
                }
            }
            .confirmationDialog(archivingReports?.count == 1 ? NSLocalizedString("archive_report_title", comment: "archive single report confirmation title") : String(format: NSLocalizedString("archive_reports_title", comment: "archive multiple reports confirmation title"), archivingReports?.count ?? 0), isPresented: $showArchivingReports, titleVisibility: .visible) {
                Button(NSLocalizedString("For me", comment: "archive reports button"), role: .destructive) {
                    if let reports = self.archivingReports {
                        archiveReports(chat, reports.sorted(), false)
                        self.archivingReports = []
                    }
                }
                if case let ChatInfo.group(groupInfo, _) = chat.chatInfo, groupInfo.membership.memberActive {
                    Button(NSLocalizedString("For all moderators", comment: "archive reports button"), role: .destructive) {
                        if let reports = self.archivingReports {
                            archiveReports(chat, reports.sorted(), true)
                            self.archivingReports = []
                        }
                    }
                }
            }
            .frame(maxWidth: maxWidth, maxHeight: .infinity, alignment: alignment)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: alignment)
            .sheet(isPresented: $showChatItemInfoSheet, onDismiss: {
                chatItemInfo = nil
            }) {
                ChatItemInfoView(ci: ci, userMemberId: chat.chatInfo.groupInfo?.membership.memberId, chatItemInfo: $chatItemInfo)
            }
        )
    }

    private func showMemberImage(_ member: GroupMember, _ prevItem: ChatItem?) -> Bool {
        switch (prevItem?.chatDir) {
        case .groupSnd: return true
        case let .groupRcv(prevMember): return prevMember.groupMemberId != member.groupMemberId
        case .channelRcv: return true
        default: return false
        }
    }

    private func chatItemReactions(_ ci: ChatItem) -> some View {
        HStack(spacing: 4) {
            ForEach(ci.reactions, id: \.reaction) { r in
                let v = HStack(spacing: 4) {
                    switch r.reaction {
                    case let .emoji(emoji): Text(emoji.rawValue).font(.caption)
                    case .unknown: EmptyView()
                    }
                    if r.totalReacted > 1 {
                        Text(LocalizedStringKey("\(r.totalReacted)"))
                            .font(.caption)
                            .fontWeight(r.userReacted ? .bold : .light)
                            .foregroundColor(r.userReacted ? theme.colors.primary : theme.colors.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .if(chat.chatInfo.featureEnabled(.reactions) && (ci.allowAddReaction || r.userReacted)) { v in
                    v.simultaneousGesture(TapGesture().onEnded {
                        setReaction(ci, add: !r.userReacted, reaction: r.reaction)
                    })
                }
                switch chat.chatInfo {
                case let .group(groupInfo, _):
                    v.contextMenu {
                        ReactionContextMenu(
                            groupInfo: groupInfo,
                            itemId: ci.id,
                            reactionCount: r,
                            selectedMember: $selectedMember,
                            profileRadius: profileRadius
                        )
                    }
                case let .direct(contact):
                    v.contextMenu {
                        contactReactionMenu(contact, r)
                    }
                default:
                    v
                }
            }
        }
    }

    @ViewBuilder
    private func menu(_ ci: ChatItem, _ range: ClosedRange<Int>?, live: Bool) -> some View {
        if case let .group(gInfo, _) = chat.chatInfo, ci.isReport, ci.meta.itemDeleted == nil {
            if ci.chatDir != .groupSnd, gInfo.membership.memberRole >= .moderator {
                archiveReportButton(ci)
            }
            deleteButton(ci, label: LocalizedStringKey(NSLocalizedString("delete_report_label", comment: "Delete report button label")))
        } else if let mc = ci.content.msgContent, !ci.isReport, ci.meta.itemDeleted == nil || revealed {
            if chat.chatInfo.featureEnabled(.reactions) && ci.allowAddReaction,
               availableReactions.count > 0 {
                reactionsGroup
            }
            if ci.meta.itemDeleted == nil && !ci.isLiveDummy && !live && !ci.localNote && chat.chatInfo.sendMsgEnabled {
                replyButton
            }
            let fileSource = getLoadedFileSource(ci.file)
            let fileExists = if let fs = fileSource, FileManager.default.fileExists(atPath: getAppFilePath(fs.filePath).path) { true } else { false }
            let copyAndShareAllowed = !ci.content.text.isEmpty || (ci.content.msgContent?.isImage == true && fileExists)
            if copyAndShareAllowed {
                shareButton(ci)
                copyButton(ci)
            }
            if let fileSource = fileSource, fileExists {
                if case .image = ci.content.msgContent, let image = getLoadedImage(ci.file) {
                    if image.imageData != nil {
                        saveButton(file: fileSource)
                    } else {
                        saveButton(image: image)
                    }
                } else {
                    saveButton(file: fileSource)
                }
            } else if let file = ci.file, case .rcvInvitation = file.fileStatus, fileSizeValid(file) {
                downloadButton(file: file)
            }
            if ci.meta.editable && !mc.isVoice && !live {
                editButton(chatItem)
            }
            if ci.meta.itemDeleted == nil
                && (ci.file == nil || (fileSource != nil && fileExists))
                && !ci.isLiveDummy && !live {
                forwardButton
            }
            if !ci.isLiveDummy {
                viewInfoButton(ci)
            }
            if revealed {
               hideButton()
            }
            if ci.meta.itemDeleted == nil && !ci.localNote,
               let file = ci.file,
               let cancelAction = file.cancelAction {
                cancelFileButton(file.fileId, cancelAction)
            }
            if !live || !ci.meta.isLive {
                deleteButton(ci)
            }
            if ci.chatDir != .groupSnd {
                if let (groupInfo, _) = ci.memberToModerate(chat.chatInfo) {
                    moderateButton(ci, groupInfo)
                } else if ci.meta.itemDeleted == nil && chat.groupFeatureEnabled(.reports),
                          case let .group(gInfo, _) = chat.chatInfo,
                          gInfo.membership.memberRole == .member
                            && !live
                            && composeState.voiceMessageRecordingState == .noRecording {
                    reportButton(ci)
                }
            }
        } else if ci.meta.itemDeleted != nil {
            if revealed {
                hideButton()
            } else if !ci.isDeletedContent {
                revealButton(ci)
            } else if range != nil {
                expandButton()
            }
            viewInfoButton(ci)
            deleteButton(ci)
        } else if ci.isDeletedContent {
            viewInfoButton(ci)
            deleteButton(ci)
        } else if ci.mergeCategory != nil && ((range?.count ?? 0) > 1 || revealed) {
            if revealed { shrinkButton() } else { expandButton() }
            deleteButton(ci)
        } else if ci.showLocalDelete {
            deleteButton(ci)
        } else {
            EmptyView()
        }
        if selectedChatItems == nil && ci.canBeDeletedForSelf {
            GlassDivider()
            selectButton(ci)
        }
    }

    var replyButton: Button<some View> {
        Button {
            withAnimation {
                if composeState.editing {
                    composeState = ComposeState(contextItem: .quotedItem(chatItem: chatItem))
                } else {
                    composeState = composeState.copy(contextItem: .quotedItem(chatItem: chatItem))
                }
            }
        } label: {
            Label(
                NSLocalizedString("Reply", comment: "chat item action"),
                systemImage: "arrowshape.turn.up.left"
            )
        }
    }

    var forwardButton: Button<some View> {
        Button {
            forwardedChatItems = [chatItem]
        } label: {
            Label(
                NSLocalizedString("Forward", comment: "chat item action"),
                systemImage: "arrowshape.turn.up.forward"
            )
        }
    }

    private var reactionsGroup: some View {
        return ControlGroup {
            if availableReactions.count > 4 {
                reactions(till: 3)
                Menu {
                    reactions(from: 3)
                } label: {
                    Image(systemName: "ellipsis")
                }
            } else { reactions() }
        }.controlGroupStyle(.compactMenu)
    }

    func reactions(from: Int? = nil, till: Int? = nil) -> some View {
        ForEach(availableReactions[(from ?? 0)..<(till ?? availableReactions.count)]) { reaction in
            Button(reaction.text) {
                setReaction(chatItem, add: true, reaction: reaction)
            }
        }
    }

    /// Reactions, which has not been used yet
    private var availableReactions: Array<MsgReaction> {
        MsgReaction.values
            .filter { reaction in
                !chatItem.reactions.contains {
                    $0.userReacted && $0.reaction == reaction
                }
            }
    }

    private func setReaction(_ ci: ChatItem, add: Bool, reaction: MsgReaction) {
        Task {
            do {
                let cInfo = chat.chatInfo
                let chatItem = try await apiChatItemReaction(
                    type: cInfo.chatType,
                    id: cInfo.apiId,
                    scope: cInfo.groupChatScope(),
                    itemId: ci.id,
                    add: add,
                    reaction: reaction
                )
                await MainActor.run {
                    m.updateChatItem(chat.chatInfo, chatItem)
                }
            } catch let error {
                logger.error("apiChatItemReaction error: \(responseError(error))")
            }
        }
    }

    private func shareButton(_ ci: ChatItem) -> Button<some View> {
        Button {
            var shareItems: [Any] = [ci.content.text]
            if case .image = ci.content.msgContent, let image = getLoadedImage(ci.file) {
                shareItems.append(image)
            }
            showShareSheet(items: shareItems)
        } label: {
            Label(
                NSLocalizedString("Share", comment: "chat item action"),
                systemImage: "square.and.arrow.up"
            )
        }
    }

    private func copyButton(_ ci: ChatItem) -> Button<some View> {
        Button {
            if case let .image(text, _) = ci.content.msgContent,
               text == "",
               let image = getLoadedImage(ci.file) {
                UIPasteboard.general.setItems([["public.image": image]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true])
            } else {
                UIPasteboard.general.setItems([["public.utf8-plain-text": ci.content.text]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true])
            }
        } label: {
            Label(NSLocalizedString("compose_copy", comment: "Copy message content button"), systemImage: "doc.on.doc")
        }
    }

    func saveButton(image: UIImage) -> Button<some View> {
        Button {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            switch status {
            case .authorized:
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    if newStatus == .authorized {
                        DispatchQueue.main.async {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }
                    }
                }
            default:
                break
            }
        } label: {
            Label(
                NSLocalizedString("Save", comment: "chat item action"),
                systemImage: "square.and.arrow.down"
            )
        }
    }

    func saveButton(file: CryptoFile) -> Button<some View> {
        Button {
            saveCryptoFile(file)
        } label: {
            Label(
                NSLocalizedString("Save", comment: "chat item action"),
                systemImage: "square.and.arrow.down"
            )
        }
    }

    func downloadButton(file: CIFile) -> Button<some View> {
        Button {
            Task {
                logger.debug("ChatView downloadFileAction, in Task")
                if let user = m.currentUser {
                    await receiveFile(user: user, fileId: file.fileId)
                }
            }
        } label: {
            Label(
                NSLocalizedString("Download", comment: "chat item action"),
                systemImage: "arrow.down.doc"
            )
        }
    }

    private func editButton(_ ci: ChatItem) -> Button<some View> {
        Button {
            withAnimation {
                composeState = ComposeState(editingItem: ci)
            }
        } label: {
            Label(
                NSLocalizedString("Edit", comment: "chat item action"),
                systemImage: "square.and.pencil"
            )
        }
    }

    private func selectButton(_ ci: ChatItem) -> Button<some View> {
        Button {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    selectUnselectChatItem(select: true, ci)
                }
            }
        } label: {
            Label(
                NSLocalizedString("Select", comment: "chat item action"),
                systemImage: "checkmark.circle"
            )
        }
    }

    private func viewInfoButton(_ ci: ChatItem) -> Button<some View> {
        Button {
            Task {
                do {
                    let cInfo = chat.chatInfo
                    let (_, ciInfo) = try await apiGetChatItemInfo(type: cInfo.chatType, id: cInfo.apiId, scope: cInfo.groupChatScope(), itemId: ci.id)
                    await MainActor.run {
                        chatItemInfo = ciInfo
                    }
                    if case let .group(gInfo, _) = chat.chatInfo {
                        await m.loadGroupMembers(gInfo)
                    }
                } catch let error {
                    logger.error("apiGetChatItemInfo error: \(responseError(error))")
                }
                await MainActor.run { showChatItemInfoSheet = true }
            }
        } label: {
            Label(
                NSLocalizedString("Info", comment: "chat item action"),
                systemImage: "info.circle"
            )
        }
    }

    private func cancelFileButton(_ fileId: Int64, _ cancelAction: CancelAction) -> Button<some View> {
        Button {
            AlertManager.shared.showAlert(Alert(
                title: Text(cancelAction.alert.title),
                message: Text(cancelAction.alert.message),
                primaryButton: .destructive(Text(cancelAction.alert.confirm)) {
                    Task {
                        if let user = m.currentUser {
                            await cancelFile(user: user, fileId: fileId)
                        }
                    }
                },
                secondaryButton: .cancel()
            ))
        } label: {
            Label(
                cancelAction.uiAction,
                systemImage: "xmark"
            )
        }
    }

    private func hideButton() -> Button<some View> {
        Button {
            pxWithConditionalAnimation {
                reveal(false)
            }
        } label: {
            Label(
                NSLocalizedString("Hide", comment: "chat item action"),
                systemImage: "eye.slash"
            )
        }
    }

    private func deleteButton(_ ci: ChatItem, label: LocalizedStringKey = "Delete") -> Button<some View> {
        Button(role: .destructive) {
            if !revealed,
               let currIndex = m.getChatItemIndex(im, ci),
               let ciCategory = ci.mergeCategory {
                let (prevHidden, _) = m.getPrevShownChatItem(currIndex, ciCategory)
                if let range = itemsRange(currIndex, prevHidden) {
                    var itemIds: [Int64] = []
                    for i in range {
                        itemIds.append(im.reversedChatItems[i].id)
                    }
                    showDeleteMessages = true
                    deletingItems = itemIds
                } else {
                    showDeleteMessage = true
                    deletingItem = ci
                }
            } else {
                showDeleteMessage = true
                deletingItem = ci
            }
        } label: {
            Label(label, systemImage: "trash")
        }
    }

    private func itemsRange(_ currIndex: Int?, _ prevHidden: Int?) -> ClosedRange<Int>? {
        if let currIndex = currIndex,
           let prevHidden = prevHidden,
           prevHidden > currIndex {
            currIndex...prevHidden
        } else {
            nil
        }
    }

    private func moderateButton(_ ci: ChatItem, _ groupInfo: GroupInfo) -> Button<some View> {
        Button(role: .destructive) {
            AlertManager.shared.showAlert(Alert(
                title: Text(LocalizedStringKey(NSLocalizedString("chat_delete_member_msg_title", comment: ""))),
                message: Text(
                    groupInfo.fullGroupPreferences.fullDelete.on
                    ? NSLocalizedString("moderate_delete_message_all", comment: "Moderate delete message confirmation")
                    : NSLocalizedString("moderate_moderated_message_all", comment: "Moderate message confirmation")
                ),
                primaryButton: .destructive(Text(LocalizedStringKey("Delete"))) {
                    deletingItem = ci
                    deleteMessage(.cidmBroadcast, moderate: true)
                },
                secondaryButton: .cancel()
            ))
        } label: {
            Label(
                NSLocalizedString("Moderate", comment: "chat item action"),
                systemImage: "flag"
            )
        }
    }

    private func archiveReportButton(_ cItem: ChatItem) -> Button<some View> {
        Button {
            archivingReports = [cItem.id]
            showArchivingReports = true
        } label: {
            Label(NSLocalizedString("compose_archive_report", comment: "Archive member report button"), systemImage: "archivebox")
        }
    }

    private func revealButton(_ ci: ChatItem) -> Button<some View> {
        Button {
            pxWithConditionalAnimation {
                reveal(true)
            }
        } label: {
            Label(
                NSLocalizedString("Reveal", comment: "chat item action"),
                systemImage: "eye"
            )
        }
    }

    private func expandButton() -> Button<some View> {
        Button {
            pxWithConditionalAnimation {
                reveal(true)
            }
        } label: {
            Label(
                NSLocalizedString("Expand", comment: "chat item action"),
                systemImage: "arrow.up.and.line.horizontal.and.arrow.down"
            )
        }
    }

    private func shrinkButton() -> Button<some View> {
        Button {
            pxWithConditionalAnimation {
                reveal(false)
            }
        } label: {
            Label (
                NSLocalizedString("Hide", comment: "chat item action"),
                systemImage: "arrow.down.and.line.horizontal.and.arrow.up"
            )
        }
    }

    private func reportButton(_ ci: ChatItem) -> Button<some View> {
        Button(role: .destructive) {
            var buttons: [ActionSheet.Button] = ReportReason.supportedReasons.map { reason in
                .default(Text(reason.text)) {
                    withAnimation {
                        if composeState.editing {
                            composeState = ComposeState(preview: .noPreview, contextItem: .reportedItem(chatItem: chatItem, reason: reason))
                        } else {
                            composeState = composeState.copy(preview: .noPreview, contextItem: .reportedItem(chatItem: chatItem, reason: reason))
                        }
                    }
                }
            }

            buttons.append(.cancel())

            actionSheet = SomeActionSheet(
                actionSheet: ActionSheet(
                    title: Text(LocalizedStringKey(NSLocalizedString("chat_report_reason_title", comment: ""))),
                    buttons: buttons
                ),
                id: "reportChatMessage"
            )
        } label: {
            Label (
                NSLocalizedString("Report", comment: "chat item action"),
                systemImage: "flag"
            )
        }
    }

    var deleteMessagesTitle: LocalizedStringKey {
        let n = deletingItems.count
        return n == 1 ? "Delete message?" : "Delete \(n) messages?"
    }

    private func selectUnselectChatItem(select: Bool, _ ci: ChatItem) {
        selectedChatItems = selectedChatItems ?? []
        var itemIds: [Int64] = []
        if !revealed,
           let currIndex = m.getChatItemIndex(im, ci),
           let ciCategory = ci.mergeCategory {
            let (prevHidden, _) = m.getPrevShownChatItem(currIndex, ciCategory)
            if let range = itemsRange(currIndex, prevHidden) {
                for i in range {
                    itemIds.append(im.reversedChatItems[i].id)
                }
            } else {
                itemIds.append(ci.id)
            }
        } else {
            itemIds.append(ci.id)
        }
        if select {
            if let sel = selectedChatItems {
                selectedChatItems = sel.union(itemIds)
            }
        } else {
            itemIds.forEach { selectedChatItems?.remove($0) }
        }
    }

    private func deleteMessage(_ mode: CIDeleteMode, moderate: Bool) {
        logger.debug("ChatView deleteMessage")
        Task {
            logger.debug("ChatView deleteMessage: in Task")
            do {
                if let di = deletingItem {
                    let r = if case .cidmBroadcast = mode,
                       moderate,
                       let (groupInfo, _) = di.memberToModerate(chat.chatInfo) {
                        try await apiDeleteMemberChatItems(
                            groupId: groupInfo.apiId,
                            itemIds: [di.id]
                        )
                    } else {
                        try await apiDeleteChatItems(
                            type: chat.chatInfo.chatType,
                            id: chat.chatInfo.apiId,
                            scope: chat.chatInfo.groupChatScope(),
                            itemIds: [di.id],
                            mode: mode
                        )
                    }
                    if let itemDeletion = r.first {
                        await MainActor.run {
                            deletingItem = nil
                            if let toItem = itemDeletion.toChatItem {
                                _ = m.upsertChatItem(chat.chatInfo, toItem.chatItem)
                            } else {
                                m.removeChatItem(chat.chatInfo, itemDeletion.deletedChatItem.chatItem)
                            }
                            let deletedItem = itemDeletion.deletedChatItem.chatItem
                            if deletedItem.isActiveReport {
                                m.decreaseGroupReportsCounter(chat.chatInfo.id)
                            }
                            m.updateChatInfo(itemDeletion.deletedChatItem.chatInfo)
                        }
                    }
                }
            } catch {
                logger.error("ChatView.deleteMessage error: \(error)")
                await MainActor.run {
                    showAlert(NSLocalizedString("Error deleting message", comment: "alert title"), message: responseError(error))
                }
            }
        }
    }

    @ViewBuilder private func contactReactionMenu(_ contact: Contact, _ r: CIReactionCount) -> some View {
        if !r.userReacted || r.totalReacted > 1 {
            Button { showChatInfoSheet = true } label: {
                profileMenuItem(Text(contact.displayName), contact.image, radius: profileRadius)
            }
        }
        if r.userReacted {
            Button {} label: {
                profileMenuItem(Text(LocalizedStringKey("you")), m.currentUser?.profile.image, radius: profileRadius)
            }
            .disabled(true)
        }
    }

    func goToItemInnerButton(_ alignStart: Bool, _ image: String, touchInProgress: Bool, _ onClick: @escaping () -> Void) -> some View {
        Image(systemName: image)
            .resizable()
            .frame(width: 13, height: 13)
            .padding([alignStart ? .trailing : .leading], 10)
            .tint(theme.colors.secondary.opacity(touchInProgress ? 1.0 : 0.4))
            .contentShape(Rectangle().inset(by: -15))
            .simultaneousGesture(TapGesture().onEnded(onClick))
    }

    @ViewBuilder
    func goToItemButton(_ alignStart: Bool) -> some View {
        let chatTypeApiIdMsgId = chatItem.meta.itemForwarded?.chatTypeApiIdMsgId
        if searchIsNotBlank {
            goToItemInnerButton(alignStart, "magnifyingglass", touchInProgress: touchInProgress) {
                closeKeyboardAndRun {
                    im.loadOpenChatNoWait(chat.id, chatItem.id)
                }
            }
        } else if let chatTypeApiIdMsgId {
            goToItemInnerButton(alignStart, "arrow.right", touchInProgress: touchInProgress) {
                closeKeyboardAndRun {
                    let (chatType, apiId, msgId) = chatTypeApiIdMsgId
                    im.loadOpenChatNoWait("\(chatType.rawValue)\(apiId)", msgId)
                }
            }
        }
    }

    private struct SelectedChatItem: View {
        @EnvironmentObject var theme: AppTheme
        var ciId: Int64
        @Binding var selectedChatItems: Set<Int64>?
        @State var checked: Bool = false
        var body: some View {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .resizable()
                .foregroundColor(checked ? theme.colors.primary : Color(uiColor: .tertiaryLabel))
                .frame(width: 24, height: 24)
                .onAppear {
                    checked = selectedChatItems?.contains(ciId) == true
                }
                .onChange(of: selectedChatItems) {_,  selected in
                    checked = selected?.contains(ciId) == true
                }
        }
    }

    private func canSwipeToPop(_ ci: ChatItem) -> Bool {
        let featureEnabled = UserDefaults.standard.bool(forKey: "PX_SWIPE_TO_POP_ENABLED")
        guard featureEnabled else { return false }
        guard ci.meta.itemTimed != nil, ci.meta.itemDeleted == nil else { return false }
        return !reduceMotion
    }

    private func triggerSwipeToPop(_ ci: ChatItem) {
        isPopping = true
        BubbleHapticsManager.shared.popManual()
        withAnimation(.easeIn(duration: 0.2)) {
            popSwipeOffset = 0
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500000000)
            isPopping = false
            popSwipeOffset = 0
        }
    }
}
