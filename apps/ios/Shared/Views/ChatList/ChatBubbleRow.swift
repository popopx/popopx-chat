//
//  ChatBubbleRow.swift
//  POPOPX
//
//  3D capsule-shaped floating bubble with CoreMotion gravity coupling,
//  TTL countdown, unread glow, self-destruct visual, and long-press
//  radial action menu.
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import CoreImage

struct ChatBubbleRow: View {
    @ObservedObject var chat: Chat
    @Binding var parentSheet: SomeSheet<AnyView>?
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared // POPOPX: 方案5
    @Environment(\.scenePhase) private var scenePhase // POPOPX: 方案5

    @State private var showRadialMenu = false
    @State private var showContactConnectionInfo = false
    @State private var showDeleteConfirmation = false

    private var rowHeight: CGFloat { dynamicSize(userFont).rowHeight }

    private var isUnread: Bool {
        chat.chatStats.unreadCount > 0 || chat.chatStats.unreadChat
    }

    private var isTTLActive: Bool {
        if let ttl = chat.chatInfo.timedMessagesTTL, ttl > 0 { return true }
        return false
    }

    var body: some View {
        ZStack {
            bubbleButton

            if showRadialMenu {
                RadialActionMenu(
                    isPresented: $showRadialMenu,
                    chat: chat,
                    onNavigate: {
                        ItemsModel.shared.loadOpenChat(chat.chatInfo.id)
                    },
                    onTag: { setTagChatSheet(chat) }
                )
            }
        }
        .modifier(SwipeActionsModifier(
            chat: chat,
            theme: theme,
            onMarkRead: {
                Task { await markChatRead(ItemsModel.shared, chat) }
            },
            onToggleFavorite: {
                triggerHapticFeedback(.light)
                let isFavorite = chat.chatInfo.chatSettings?.favorite == true
                toggleChatFavorite(chat, favorite: !isFavorite)
            },
            onToggleNtfs: {
                if let nextMode = chat.chatInfo.nextNtfMode {
                    toggleNotifications(chat, enableNtfs: nextMode)
                }
            },
            onTag: {
                setTagChatSheet(chat)
            },
            onClear: {
                Task {
                    await clearChat(chat)
                }
            },
            onDelete: {
                showDeleteConfirmation = true
            }
        ))
        .environmentObject(SwipeCoordinator.shared)
        .zIndex(showRadialMenu ? 10 : 0)
        .confirmationDialog(
            NSLocalizedString("delete_chat_confirmation_title", comment: "delete chat confirmation title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                NSLocalizedString("delete_chat_confirm_button", comment: "delete chat confirm button"),
                role: .destructive
            ) {
                Task { await deleteChat(chat) }
            }
            Button(NSLocalizedString("cancel_delete_chat", comment: "cancel delete chat"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("delete_chat_confirmation_message", comment: "delete chat confirmation message"))
        }
    }

    private var bubbleButton: some View {
        bubbleContent
            .contentShape(Capsule())
            .onTapGesture {
                guard SwipeCoordinator.shared.activeSwipeChatId != chat.chatInfo.id else { return }
                if !showRadialMenu {
                    triggerHapticFeedback(.light)
                    if case .contactConnection = chat.chatInfo {
                        showContactConnectionInfo = true
                    } else {
                        ItemsModel.shared.loadOpenChat(chat.chatInfo.id)
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showRadialMenu = true
                }
            }
            .appSheet(isPresented: $showContactConnectionInfo) {
                if case let .contactConnection(contactConnection) = chat.chatInfo {
                    ContactConnectionInfo(contactConnection: contactConnection)
                        .modifier(ThemedBackground(grouped: true))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel({
                var parts = [chat.chatInfo.chatViewName]
                if chat.chatInfo.chatSettings?.favorite == true { parts.append(String(localized: "favorite")) }
                if case let .contactConnection(conn) = chat.chatInfo {
                    if !conn.description.isEmpty { parts.append(conn.description) }
                } else {
                    let lastItem = chat.chatItems.last
                    let deleted = lastItem?.isDeletedContent == true || lastItem?.meta.itemDeleted != nil
                    let preview = deleted ? "..." : (lastItem?.content.msgContent?.text ?? "")
                    if !preview.isEmpty { parts.append(preview) }
                }
                return parts.joined(separator: ", ")
            }())
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(String(localized: "Double-tap to open. Long-press for actions."))
    }

    private var bubbleContent: some View {
        let preview: String
        let chatTs: Date?
        if case let .contactConnection(conn) = chat.chatInfo {
            preview = conn.description
            chatTs = conn.updatedAt
        } else {
            let lastItem = chat.chatItems.last
            let deleted = lastItem?.isDeletedContent == true || lastItem?.meta.itemDeleted != nil
            preview = deleted ? "..." : (lastItem?.content.msgContent?.text ?? "")
            chatTs = lastItem?.meta.itemTs ?? chat.chatInfo.chatTs
        }

        return HStack(spacing: 12) {
            Group {
                if case .contactConnection = chat.chatInfo {
                    Image(systemName: "link")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.secondary)
                } else {
                    ChatInfoImage(chat: chat, size: 44)
                }
            }
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chat.chatInfo.chatViewName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if chat.chatInfo.chatSettings?.favorite == true {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .minimumScaleFactor(0.7)
                            .foregroundColor(QuantumColors.success)
                    }

                    Spacer(minLength: 8)

                    if isTTLActive, let ttl = chat.chatInfo.timedMessagesTTL {
                        ttlCountdown(ttl: ttl)
                    } else if let ts = chatTs {
                        formatTimestampText(ts)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    unreadBadge
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)

                HStack {
                    if case .contactConnection = chat.chatInfo,
                       case let .contactConnection(contactConnection) = chat.chatInfo,
                       contactConnection.initiated,
                       let connLinkInv = contactConnection.connLinkInv {
                        let uri = connLinkInv.encryptedConnLink ?? encryptConnLinkText(connLinkInv.connFullLink) ?? connLinkInv.connFullLink
                        HStack(spacing: 6) {
                            if let qrImage = generateQRCode(from: uri) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            Text(uri)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } else {
                        Text(preview.isEmpty ? " " : preview)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.bottom, 4)
                .padding(.horizontal, 4)
                .padding(.trailing, 12)
            }
            .padding(.vertical, 10)
            .padding(.trailing, 4)
        }
        .frame(minHeight: rowHeight)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(Color(hex: "#1E1433").opacity(0.85)) // POPOPX: 方案1 — ultraThinMaterial → solid for battery
        )
        .background(
            Capsule(style: .continuous)
                .fill(Color(hex: "#6E25C4").opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    isTTLActive
                        ? LinearGradient(
                            colors: [Color(hex: "#FF00A0").opacity(0.6), Color(hex: "#FF00A0").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : QuantumGlass.iridescentBorderGradient(opacity: 0.15),
                    lineWidth: isTTLActive ? 1.0 : 0.6
                )
        )
        // POPOPX: Disabled 3D tilt on chat list page to reduce energy consumption (kept on conversation page)
        // .modifier(PX3DBubbleStyle(isUnread: isUnread, isTTLActive: isTTLActive, enableMotionTilt: !isContactConnection))
        .mask(alignment: .top) {
            if isTTLActive {
                LinearGradient(
                    colors: [.black.opacity(0.5), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle().fill(.black)
            }
        }
        .compositingGroup() // POPOPX: flatten before shadow
        .shadow(color: isUnread ? Color(hex: "#00FFD2").opacity(0.35) : .clear, radius: 8)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var unreadBadge: some View {
        if isUnread {
            let count = chat.chatStats.unreadCount
            Text(count > 0 ? "\(count)" : "•")
                .font(.system(size: 11, weight: .bold))
                .minimumScaleFactor(0.7)
                .foregroundColor(.white)
                .frame(minWidth: 18, minHeight: 18)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: "#00FFD2"), Color(hex: "#6E25C4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: Color(hex: "#00FFD2").opacity(0.4), radius: 4)
        }
    }

    private func ttlCountdown(ttl: Int) -> some View {
        TimelineView(.animation(minimumInterval: 2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { context in // POPOPX: 方案5 — added paused guard
            let remaining = pxTTLRemaining(ttl: ttl, lastActivity: chat.chatInfo.chatTs)
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                    .minimumScaleFactor(0.7)
                Text(pxFormatTTL(remaining))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(Color(hex: "#FF00A0"))
        }
    }

    private func pxTTLRemaining(ttl: Int, lastActivity: Date) -> Int {
        let elapsed = Int(Date.now.timeIntervalSince(lastActivity))
        return max(0, ttl - elapsed)
    }

    private func pxFormatTTL(_ seconds: Int) -> String {
        if seconds >= 86400 {
            return "\(seconds / 86400)d"
        } else if seconds >= 3600 {
            return "\(seconds / 3600)h"
        } else if seconds >= 60 {
            return "\(seconds / 60)m"
        } else {
            return "\(seconds)s"
        }
    }

    private func setTagChatSheet(_ chat: Chat) {
        let screenHeight = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.bounds.height) ?? 800
        let reservedSpace: Double = 4 * 44
        let tagsSpace = Double(max(ChatTagsModel.shared.userTags.count, 3)) * 44
        let fraction = min((reservedSpace + tagsSpace) / screenHeight, 0.62)

        parentSheet = SomeSheet(
            content: {
                AnyView(
                    NavigationStack {
                        if ChatTagsModel.shared.userTags.isEmpty {
                            TagListEditor(chat: chat)
                        } else {
                            PXTagFilterList(chat: chat)
                        }
                    }
                )
            },
            id: "lists sheet",
            fraction: fraction
        )
    }
}

private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

private func generateQRCode(from string: String) -> UIImage? {
    guard !string.isEmpty,
          let data = string.data(using: .ascii),
          let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let ciImage = filter.outputImage else { return nil }
    let scale = 120.0 / ciImage.extent.width
    let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let cgImage = QRCodeRenderer.sharedContext.createCGImage(transformed, from: transformed.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

private enum QRCodeRenderer {
    static let sharedContext = CIContext(options: [.useSoftwareRenderer: false])
}
