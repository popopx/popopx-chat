//
//  FloatingButtons.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Custom button style with scale animation for press feedback
struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    let duration: Double
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: duration), value: configuration.isPressed)
    }
}

struct FloatingButtons: View {
    @ObservedObject var im: ItemsModel
    let theme: AppTheme
    let scrollView: PXScrollEngine<MergedItem>
    let chat: Chat
    @Binding var loadingMoreItems: Bool
    @Binding var loadingTopItems: Bool
    @Binding var requestedTopScroll: Bool
    @Binding var loadingBottomItems: Bool
    @Binding var requestedBottomScroll: Bool
    @Binding var animatedScrollingInProgress: Bool
    let listState: PXScrollEngine<MergedItem>.PXScrollState
    @ObservedObject var model: FloatingButtonModel
    let reloadItems: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if let date = model.date, date.timeIntervalSince1970 > 0 {
                 DateSeparator(date: date)
                     .padding(.vertical, 4).padding(.horizontal, 8)
                     .background(.ultraThinMaterial)
                     .clipShape(Capsule())
                     .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isInDarkTheme() ? 0.15 : 0.5),
                                        Color.white.opacity(isInDarkTheme() ? 0.05 : 0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                     )
                     .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : Color.black.opacity(0.06), radius: isInDarkTheme() ? 8 : 6, x: 0, y: 2)
                     .opacity(model.isDateVisible ? 1 : 0)
                     .padding(.vertical, 4)
            }
            VStack {
                if model.unreadAbove > 0 && !animatedScrollingInProgress {
                    if loadingTopItems && requestedTopScroll {
                        circleButton(
                            { ProgressView() },
                            label: NSLocalizedString("Loading messages", comment: ""),
                            hint: NSLocalizedString("Waiting for more messages to load", comment: "")
                        ) { }
                    } else {
                        circleButton(
                            { unreadCountText(model.unreadAbove).font(.callout).foregroundColor(theme.colors.primary) },
                            label: NSLocalizedString("Scroll to top unread messages", comment: "Accessibility label for floating button that scrolls to first unread message"),
                            hint: NSLocalizedString("Double-tap to jump to first unread message", comment: "")
                        ) {
                            scrollToTopUnread()
                        }
                        .contextMenu {
                            Button {
                                Task {
                                    await markChatRead(im, chat)
                                }
                            } label: {
                                Label(NSLocalizedString("compose_mark_read", comment: "Mark chat as read button"), systemImage: "checkmark")
                            }
                        }
                    }
                }
                Spacer()
                if listState.firstVisibleItemIndex != 0 && !animatedScrollingInProgress {
                    if loadingBottomItems && requestedBottomScroll {
                        circleButton(
                            { ProgressView() },
                            label: NSLocalizedString("Loading messages", comment: ""),
                            hint: NSLocalizedString("Waiting for more messages to load", comment: "")
                        ) { }
                    } else {
                        circleButton(
                            {
                                Group {
                                    if model.unreadBelow > 0 {
                                        unreadCountText(model.unreadBelow)
                                            .font(.callout)
                                            .foregroundColor(theme.colors.primary)
                                    } else {
                                        Image(systemName: "chevron.down").foregroundColor(theme.colors.primary)
                                    }
                                }
                            },
                            label: model.unreadBelow > 0
                                ? NSLocalizedString("Scroll to next unread", comment: "Accessibility label for floating button that scrolls to next unread message")
                                : NSLocalizedString("Scroll to bottom", comment: "Accessibility label for floating button that scrolls to bottom of chat"),
                            hint: model.unreadBelow > 0
                                ? NSLocalizedString("Double-tap to jump to next unread message", comment: "")
                                : nil
                        ) {
                            if loadingBottomItems || !im.lastItemsLoaded {
                                requestedTopScroll = false
                                requestedBottomScroll = true
                            } else {
                                scrollToBottom()
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: loadingTopItems) {_,  loading in
            if !loading && requestedTopScroll {
                requestedTopScroll = false
                scrollToTopUnread()
            }
        }
        .onChange(of: loadingBottomItems) {_,  loading in
            if !loading && requestedBottomScroll && im.lastItemsLoaded {
                requestedBottomScroll = false
                scrollToBottom()
            }
        }
        .onDisappear(perform: model.resetDate)
        .popopxBranded()
    }

    private func scrollToTopUnread() {
        Task {
            if !im.chatState.splits.isEmpty {
                await MainActor.run { loadingMoreItems = true }
                await loadChat(chatId: chat.id, im: im, openAroundItemId: nil, clearItems: false)
                await MainActor.run { reloadItems() }
                if let index = listState.items.lastIndex(where: { $0.hasUnread() }) {
                    await MainActor.run { animatedScrollingInProgress = true }
                    await scrollView.scrollToItemAnimated(index)
                    await MainActor.run { animatedScrollingInProgress = false }
                }
                await MainActor.run { loadingMoreItems = false }
            } else if let index = listState.items.lastIndex(where: { $0.hasUnread() }) {
                await MainActor.run { animatedScrollingInProgress = true }
                // scroll to the top unread item
                await scrollView.scrollToItemAnimated(index)
                await MainActor.run { animatedScrollingInProgress = false }
            } else {
                logger.debug("No more unread items, total: \(listState.items.count)")
            }
        }
    }

    private func scrollToBottom() {
        animatedScrollingInProgress = true
        Task {
            await scrollView.scrollToItemAnimated(0, top: false)
            await MainActor.run { animatedScrollingInProgress = false }
        }
    }

    private func circleButton<Content: View>(
        _ content: @escaping () -> Content,
        label: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            Circle()
                .foregroundColor(Color(uiColor: .tertiarySystemGroupedBackground))
                .frame(width: 44, height: 44)
            content()
        }
        .buttonStyle(
            ScaleButtonStyle(
                scale: 0.92,
                duration: 0.15
            )
        )
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .focusable()
        .onTapGesture(perform: action)
    }
}

struct DateSeparator: View {
    let date: Date

    var body: some View {
        Text(String.localizedStringWithFormat(
            NSLocalizedString("%@, %@", comment: "format for date separator in chat"),
            date.formatted(.dateTime.weekday(.abbreviated)),
            date.formatted(
                Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
                ? .dateTime.day().month(.abbreviated)
                : .dateTime.day().month(.abbreviated).year()
            )
        ))
        .font(.callout)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
    }
}
