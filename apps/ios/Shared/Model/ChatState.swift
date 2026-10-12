//
//  ChatState.swift
//  POPOPX
//
//  Extracted from ChatModel.swift - Chat-related state
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Combine
import SwiftUI
@preconcurrency import POPOPXSwitch

/// Manages chat list, current chat, and group member state
@MainActor
final class ChatState: ObservableObject {
    // Chat list
    @Published var chats: [Chat] = [] {
        didSet { chatIndexMap = Dictionary(chats.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first }) }
    }
    @Published var deletedChats: Set<String> = []
    private var chatIndexMap: [String: Int] = [:]

    // Current chat
    @Published var chatId: String?
    @Published var chatAgentConnId: String?
    @Published var chatSubStatus: SubscriptionStatus?
    @Published var openAroundItemId: ChatItem.ID? = nil
    @Published var chatToTop: String?
    @Published var creatingChannelId: String?

    // Group members
    @Published var groupMembers: [GMember] = []
    @Published var groupMembersIndexes: Dictionary<Int64, Int> = [:]
    @Published var membersLoaded = false
    @Published var channelRelayHostnames: [Int64: [String]] = [:]

    // Secondary chat view
    @Published var secondaryIM: ItemsModel? = nil
    @Published var secondaryPendingInviteeChatOpened = false

    // Chat item TTL
    @Published var chatItemTTL: ChatItemTTL = .none

    // Delivery receipts
    @Published var setDeliveryReceipts = false

    static let shared = ChatState()

    // MARK: - Chat Access

    func hasChat(_ id: String) -> Bool {
        chatIndexMap[id] != nil
    }

    func getChat(_ id: String) -> Chat? {
        chatIndexMap[id].map { chats[$0] }
    }

    func getChatIndex(_ id: String) -> Int? {
        chatIndexMap[id]
    }

    func getContactChat(_ contactId: Int64) -> Chat? {
        chats.first { chat in
            if case let .direct(contact) = chat.chatInfo {
                return contact.contactId == contactId
            } else {
                return false
            }
        }
    }

    func getGroupChat(_ groupId: Int64) -> Chat? {
        chats.first { chat in
            if case let .group(groupInfo, _) = chat.chatInfo {
                return groupInfo.groupId == groupId
            } else {
                return false
            }
        }
    }

    // MARK: - Group Members

    func populateGroupMembersIndexes() {
        groupMembersIndexes.removeAll()
        for (i, member) in groupMembers.enumerated() {
            groupMembersIndexes[member.groupMemberId] = i
        }
    }

    func getGroupMember(_ groupMemberId: Int64) -> GMember? {
        if let i = groupMembersIndexes[groupMemberId] {
            return groupMembers[i]
        }
        return nil
    }

    // MARK: - Reset

    func reset() {
        chats = []
        chatIndexMap = [:]
        deletedChats = []
        chatId = nil
        chatAgentConnId = nil
        chatSubStatus = nil
        openAroundItemId = nil
        chatToTop = nil
        creatingChannelId = nil
        groupMembers = []
        groupMembersIndexes = [:]
        membersLoaded = false
        channelRelayHostnames = [:]
        chatItemTTL = .none
        setDeliveryReceipts = false
        secondaryIM = nil
        secondaryPendingInviteeChatOpened = false
    }
}
