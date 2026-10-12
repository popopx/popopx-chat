//
//  RadialActionMenu.swift
//  POPOPX
//
//  Circular action menu that blooms around a long-pressed chat bubble.
//  Carries the same actions the old swipeActions used to expose,
//  plus context-specific actions for contact requests and groups.
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct RadialAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void
}

struct RadialActionMenu: View {
    @Binding var isPresented: Bool
    let chat: Chat
    let onNavigate: () -> Void
    let onTag: () -> Void

    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUnread: Bool {
        chat.chatStats.unreadCount > 0 || chat.chatStats.unreadChat
    }

    private var dynamicRadius: CGFloat {
        actions.count > 8 ? 140 : 120
    }

    private var dynamicMenuSize: CGFloat {
        actions.count > 8 ? 340 : 300
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            ZStack {
                Circle()
                    .strokeBorder(
                        isUnread ? Color(hex: "#00FFD2").opacity(0.4) : Color(hex: "#6E25C4").opacity(0.4),
                        style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                    )
                    .frame(width: dynamicRadius * 2, height: dynamicRadius * 2)
                    .opacity(isPresented ? 1 : 0)

                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    let angle = angleFor(index: index, total: actions.count)
                    actionButton(action, angle: angle)
                        .offset(
                            x: cos(angle) * dynamicRadius,
                            y: sin(angle) * dynamicRadius
                        )
                        .scaleEffect(isPresented ? 1 : 0.3)
                        .opacity(isPresented ? 1 : 0)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)
                                .delay(Double(index) * 0.03),
                            value: isPresented
                        )
                }
            }
            .frame(width: dynamicMenuSize, height: dynamicMenuSize)
        }
        .transition(.opacity)
    }

    private var actions: [RadialAction] {
        var result: [RadialAction] = []

        result.append(contentsOf: contextActions)
        result.append(contentsOf: baseActions)

        return result
    }

    private var contextActions: [RadialAction] {
        var result: [RadialAction] = []

        switch chat.chatInfo {
        case let .direct(contact):
            if contact.nextAcceptContactRequest, let contactRequestId = contact.contactRequestId {
                result.append(RadialAction(
                    icon: "checkmark",
                    label: NSLocalizedString("accept_contact_request", comment: "Button to accept a contact request"),
                    tint: theme.colors.primary
                ) {
                    dismiss {
                        Task { await acceptContactRequest(incognito: false, contactRequestId: contactRequestId) }
                    }
                })

                if !ChatModel.shared.addressShortLinkDataSet {
                    result.append(RadialAction(
                        icon: "theatermasks.fill",
                        label: NSLocalizedString("incognito_accept", comment: "Button to accept contact request incognito"),
                        tint: QuantumColors.accent
                    ) {
                        dismiss {
                            Task { await acceptContactRequest(incognito: true, contactRequestId: contactRequestId) }
                        }
                    })
                }

                result.append(RadialAction(
                    icon: "multiply",
                    label: NSLocalizedString("reject_contact_request", comment: "Button to reject a contact request"),
                    tint: theme.colors.error
                ) {
                    dismiss {
                        AlertManager.shared.showAlert(rejectContactRequestAlert(contactRequestId))
                    }
                })
            } else if let groupDirectInv = contact.groupDirectInv, !groupDirectInv.memberRemoved {
                result.append(RadialAction(
                    icon: "ipad.and.arrow.forward",
                    label: NSLocalizedString("join_group", comment: "Button to join a group"),
                    tint: theme.colors.primary
                ) {
                    dismiss {
                        acceptMemberContactRequest(contact)
                    }
                })
            }

            if chat.chatStats.reportsCount > 0 {
                result.append(RadialAction(
                    icon: "archivebox",
                    label: NSLocalizedString("archive_reports", comment: "Button to archive all reports"),
                    tint: .secondary
                ) {
                    dismiss {
                        AlertManager.shared.showAlert(archiveAllReportsAlert)
                    }
                })
            }

        case let .group(groupInfo, _):
            result.append(RadialAction(
                icon: "rectangle.portrait.and.arrow.right.fill",
                label: NSLocalizedString("leave_group_action", comment: "Button to leave a group"),
                tint: QuantumColors.warning
            ) {
                dismiss {
                    AlertManager.shared.showAlert(leaveGroupAlert(groupInfo))
                }
            })

            if chat.chatStats.reportsCount > 0 {
                result.append(RadialAction(
                    icon: "archivebox",
                    label: NSLocalizedString("archive_reports", comment: "Button to archive all reports"),
                    tint: .secondary
                ) {
                    dismiss {
                        AlertManager.shared.showAlert(archiveAllReportsAlert)
                    }
                })
            }

        default:
            break
        }

        return result
    }

    private var baseActions: [RadialAction] {
        let isFavorite = chat.chatInfo.chatSettings?.favorite == true

        return [
            RadialAction(
                icon: isUnread ? "checkmark" : "circlebadge.fill",
                label: isUnread ? NSLocalizedString("mark_read", comment: "Button to mark chat as read") : NSLocalizedString("mark_unread", comment: "Button to mark chat as unread"),
                tint: Color(hex: "#6E25C4")
            ) {
                dismiss {
                    Task {
                        if isUnread { await markChatRead(ItemsModel.shared, chat) }
                        else { await markChatUnread(chat) }
                    }
                }
            },
            RadialAction(
                icon: isFavorite ? "star.slash.fill" : "star.fill",
                label: isFavorite ? NSLocalizedString("unfavorite_chat", comment: "Button to unfavorite chat") : NSLocalizedString("favorite_chat", comment: "Button to favorite chat"),
                tint: QuantumColors.success
            ) {
                dismiss {
                    triggerHapticFeedback(.light)
                    toggleChatFavorite(chat, favorite: !isFavorite)
                }
            },
            RadialAction(
                icon: notificationIcon,
                label: notificationLabel,
                tint: Color(hex: "#00FFD2")
            ) {
                dismiss {
                    if let nextMode = chat.chatInfo.nextNtfMode {
                        toggleNotifications(chat, enableNtfs: nextMode)
                    }
                }
            },
            RadialAction(
                icon: "tag.fill",
                label: NSLocalizedString("chat_list", comment: "Button to add chat to list"),
                tint: QuantumColors.success
            ) {
                dismiss {
                    triggerHapticFeedback(.light)
                    onTag()
                }
            },
            RadialAction(
                icon: "gobackward",
                label: NSLocalizedString("clear_conversation", comment: "Button to clear conversation"),
                tint: QuantumColors.warning
            ) {
                dismiss {
                    triggerHapticFeedback(.heavy)
                    AlertManager.shared.showAlert(clearAlert)
                }
            },
            RadialAction(
                icon: "trash.fill",
                label: NSLocalizedString("delete_chat", comment: "Button to delete chat"),
                tint: theme.colors.error
            ) {
                dismiss {
                    AlertManager.shared.showAlert(deleteAlert)
                }
            },
        ]
    }

    private var notificationIcon: String {
        if let nextMode = chat.chatInfo.nextNtfMode {
            return nextMode.iconFilled
        }
        return "bell.fill"
    }

    private var notificationLabel: String {
        if let nextMode = chat.chatInfo.nextNtfMode {
            return nextMode.text(mentions: chat.chatInfo.hasMentions)
        }
        return NSLocalizedString("swipe_action_mute", comment: "Swipe action: mute")
    }

    private var clearAlert: Alert {
        let isNoteFolder: Bool = {
            if case .local = chat.chatInfo { return true }
            return false
        }()
        return Alert(
            title: Text(isNoteFolder ? NSLocalizedString("clear_private_notes_title", comment: "Alert title for clearing private notes") : NSLocalizedString("clear_conversation_title", comment: "Alert title for clearing conversation")),
            message: Text(
                isNoteFolder
                    ? NSLocalizedString("clear_private_notes_message", comment: "Alert message for clearing private notes")
                    : NSLocalizedString("clear_conversation_message", comment: "Alert message for clearing conversation")
            ),
            primaryButton: .destructive(Text(NSLocalizedString("clear_action", comment: "Button to clear messages"))) {
                Task { await clearChat(chat) }
            },
            secondaryButton: .cancel()
        )
    }

    private var deleteAlert: Alert {
        Alert(
            title: Text(NSLocalizedString("delete_chat_confirmation_title", comment: "delete chat confirmation title")),
            message: Text(NSLocalizedString("delete_chat_confirmation_message", comment: "delete chat confirmation message")),
            primaryButton: .destructive(Text(NSLocalizedString("delete_chat_confirm_button", comment: "delete chat confirm button"))) {
                Task { await deleteChat(chat) }
            },
            secondaryButton: .cancel(Text(NSLocalizedString("cancel_delete_chat", comment: "cancel delete chat")))
        )
    }

    private var archiveAllReportsAlert: Alert {
        Alert(
            title: Text(NSLocalizedString("archive_reports_title", comment: "Alert title for archiving reports")),
            message: Text(NSLocalizedString("archive_reports_message", comment: "Alert message for archiving reports")),
            primaryButton: .destructive(Text(NSLocalizedString("archive_action", comment: "Button to archive reports"))) {
                Task {
                    do {
                        if case let .groupChatItemsDeleted(user, groupInfo, chatItemIDs, _, member) = try await apiArchiveReceivedReports(groupId: chat.chatInfo.apiId) {
                            await groupChatItemsDeleted(user, groupInfo, chatItemIDs, member)
                        }
                    } catch {
                        logger.error("archiveAllReports error: \(responseError(error))")
                    }
                }
            },
            secondaryButton: .cancel()
        )
    }

    private func leaveGroupAlert(_ groupInfo: GroupInfo) -> Alert {
        Alert(
            title: Text(NSLocalizedString("leave_group_title", comment: "Alert title for leaving group")),
            message: Text(NSLocalizedString("leave_group_message", comment: "Alert message for leaving group")),
            primaryButton: .destructive(Text(NSLocalizedString("leave_action", comment: "Button to leave group"))) {
                Task { await leaveGroup(groupInfo.groupId) }
            },
            secondaryButton: .cancel()
        )
    }

    private func angleFor(index: Int, total: Int) -> CGFloat {
        let step = (2 * CGFloat.pi) / CGFloat(total)
        return -CGFloat.pi / 2 + CGFloat(index) * step
    }

    private func actionButton(_ action: RadialAction, angle: CGFloat) -> some View {
        Button {
            action.action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle().strokeBorder(action.tint.opacity(0.6), lineWidth: 1)
                    )
                    .foregroundColor(action.tint)
                    .shadow(color: action.tint.opacity(0.6), radius: 6)

                Text(action.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(action.label) \(chat.chatInfo.chatViewName)"))
    }

    private func dismiss(_ after: @escaping () -> Void = {}) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: after)
    }
}

private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
