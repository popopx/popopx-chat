//
//  SwipeToPopModifier.swift
//  POPOPX
//
//  "Swipe to Pop" — right-swipe gesture that pops/deletes a chat bubble
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch


final class SwipeCoordinator: ObservableObject {
    static let shared = SwipeCoordinator()
    @Published var activeSwipeChatId: Chat.ID?
}
struct SwipeToPopModifier: ViewModifier {
    @ObservedObject var chat: Chat
    @EnvironmentObject var chatModel: ChatModel
    @State private var dragOffset: CGFloat = 0
    @State private var isPopping = false
    @State private var showDeleteConfirmation = false

    private let popThreshold: CGFloat = 140

    func body(content: Content) -> some View {
        content
            .offset(x: max(0, dragOffset))
            .scaleEffect(isPopping ? 1.08 : 1.0)
            .opacity(isPopping ? 0 : 1)
            .overlay(alignment: .leading) {
                if dragOffset > 10 {
                    needleLine
                        .transition(.opacity)
                }
            }
            .overlay {
                if isPopping {
                    Color(hex: "#6E25C4")
                        .opacity(0.6)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !isPopping else { return }
                        let dx = value.translation.width
                        if dx > 0 {
                            dragOffset = dx
                            if dx > 20 {
                                BubbleHapticsManager.shared.swipeTrail(intensity: Float(min(dx / popThreshold, 1.0)) * 0.3)
                            }
                        }
                    }
                    .onEnded { value in
                        guard !isPopping else { return }
                        let dx = value.translation.width
                        if dx > popThreshold {
                            triggerPop()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .animation(.easeOut(duration: 0.1), value: dragOffset)
            .confirmationDialog(
                NSLocalizedString("delete_chat_confirmation_title", comment: "delete chat confirmation title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    NSLocalizedString("delete_chat_confirm_button", comment: "delete chat confirm button"),
                    role: .destructive
                ) {
                    performPop()
                }
                Button(NSLocalizedString("cancel_delete_chat", comment: "cancel delete chat"), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("delete_chat_confirmation_message", comment: "delete chat confirmation message"))
            }
    }

    private var needleLine: some View {
        let width = min(dragOffset, 300)
        return ZStack(alignment: .leading) {
            LinearGradient(
                colors: [
                    .clear,
                    Color(hex: "#C0C0C0").opacity(0.4),
                    Color.white.opacity(0.95),
                    Color(hex: "#C0C0C0").opacity(0.4),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width, height: 2)

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width, height: 10)
            .blur(radius: 4)
        }
        .offset(x: max(0, dragOffset) - 2)
    }

    private func triggerPop() {
        dragOffset = 0
        showDeleteConfirmation = true
    }

    private func performPop() {
        isPopping = true

        BubbleHapticsManager.shared.popExplosion()

        let chatId = chat.chatInfo.id

        ChatPopCoordinator.shared.triggerPop(chatId: chatId)

        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await deleteChat(chat)
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                isPopping = false
            }
        }
    }
}
struct SwipeActionsModifier: ViewModifier {
    @ObservedObject var chat: Chat
    let theme: AppTheme

    let onMarkRead: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleNtfs: () -> Void
    let onTag: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @EnvironmentObject private var swipeCoordinator: SwipeCoordinator

    private let actionThreshold: CGFloat = 80
    private let buttonWidth: CGFloat = 70
    private let buttonSpacing: CGFloat = 8
    private let edgePadding: CGFloat = 12

    private var totalActionWidth: CGFloat {
        buttonWidth * 3 + buttonSpacing * 2 + edgePadding
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if dragOffset > 5 {
                HStack(spacing: buttonSpacing) {
                    rightActionButtons
                    Spacer(minLength: 0)
                }
                .padding(.leading, edgePadding)
                .frame(height: nil, alignment: .leading)
                .transition(.opacity)
            }

            if dragOffset < -5 {
                HStack(spacing: buttonSpacing) {
                    Spacer(minLength: 0)
                    leftActionButtons
                }
                .padding(.trailing, edgePadding)
                .frame(height: nil, alignment: .trailing)
                .transition(.opacity)
            }

            content
                .offset(x: dragOffset)
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if dragOffset != 0 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                                swipeCoordinator.activeSwipeChatId = nil
                                isDragging = false
                            }
                        }
                )
        }
        .onChange(of: swipeCoordinator.activeSwipeChatId) { oldId, newId in
                if newId != chat.chatInfo.id && dragOffset != 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                    isDragging = false
                }
            }
            .onAppear {
                if swipeCoordinator.activeSwipeChatId == chat.chatInfo.id && dragOffset != 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                    swipeCoordinator.activeSwipeChatId = nil
                }
            }
            .onDisappear {
                if dragOffset != 0 {
                    dragOffset = 0
                    swipeCoordinator.activeSwipeChatId = nil
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy) else { return }
                        isDragging = true
                        swipeCoordinator.activeSwipeChatId = chat.chatInfo.id
                        dragOffset = dx
                        if abs(dragOffset) > 20 {
                            BubbleHapticsManager.shared.swipeTrail(intensity: Float(min(abs(dragOffset) / totalActionWidth, 1.0)) * 0.3)
                        }
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy) else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                            isDragging = false
                            return
                        }

                        if abs(dx) < actionThreshold {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                            swipeCoordinator.activeSwipeChatId = nil
                        } else {
                            let targetOffset = dx > 0 ? totalActionWidth : -totalActionWidth
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = targetOffset
                            }
                        }
                        isDragging = false
                    }
            )
            .animation(.easeOut(duration: 0.1), value: dragOffset)
    }
    
    private var leftActionButtons: some View {
        HStack(spacing: 8) {
            actionButton(
                title: NSLocalizedString("swipe_action_read", comment: "Swipe action: mark as read"),
                systemImage: "checkmark",
                color: theme.colors.primary,
                show: chat.chatStats.unreadCount > 0 || chat.chatStats.unreadChat
            ) {
                onMarkRead()
            }

            actionButton(
                title: chat.chatInfo.chatSettings?.favorite == true
                    ? NSLocalizedString("swipe_action_unfavorite", comment: "Swipe action: unfavorite")
                    : NSLocalizedString("swipe_action_favorite", comment: "Swipe action: favorite"),
                systemImage: chat.chatInfo.chatSettings?.favorite == true ? "star.slash" : "star.fill",
                color: chat.chatInfo.chatSettings?.favorite == true ? QuantumColors.warning : QuantumColors.success
            ) {
                onToggleFavorite()
            }

            actionButton(
                title: chat.chatInfo.nextNtfMode?.text(mentions: chat.chatInfo.hasMentions) ?? NSLocalizedString("swipe_action_mute", comment: "Swipe action: mute"),
                systemImage: chat.chatInfo.nextNtfMode?.iconFilled ?? "bell.slash",
                color: theme.colors.primary,
                show: chat.chatInfo.nextNtfMode != nil
            ) {
                onToggleNtfs()
            }
        }
    }
    
    private var rightActionButtons: some View {
        HStack(spacing: 8) {
            actionButton(
                title: NSLocalizedString("swipe_action_list", comment: "Swipe action: tag/list"),
                systemImage: "tag.fill",
                color: theme.colors.primary
            ) {
                onTag()
            }

            actionButton(
                title: NSLocalizedString("swipe_action_clear", comment: "Swipe action: clear messages"),
                systemImage: "gobackward",
                color: QuantumColors.warning,
                show: !chat.chatItems.isEmpty
            ) {
                onClear()
            }

            actionButton(
                title: NSLocalizedString("swipe_action_delete", comment: "Swipe action: delete"),
                systemImage: "trash",
                color: theme.colors.error
            ) {
                onDelete()
            }
        }
    }
    
    private func actionButton(
        title: String,
        systemImage: String,
        color: Color,
        show: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if show {
                Button(action: action) {
                    VStack(spacing: 4) {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: buttonWidth, height: buttonWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color)
                    )
                }
            } else {
                Color.clear
                    .frame(width: buttonWidth, height: buttonWidth)
            }
        }
    }
}
