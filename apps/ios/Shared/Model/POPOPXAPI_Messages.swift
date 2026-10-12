//
//  POPOPXAPI_Messages.swift
//  POPOPX
//
//  Extracted from POPOPXAPI.swift
//  Message processing API functions
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import Foundation
import Dispatch
import SwiftUI
@preconcurrency import POPOPXSwitch

/// Thread-safe reference wrapper for sharing mutable state between actors
final class ThreadSafeRef<T> {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) {
        _value = value
    }

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

// MARK: - Send Message Functions

private func isCRcvConnectionError(_ error: ChatError) -> Bool {
    if case let .errorAgent(.CONN(connErr: .ONE_WAY, errContext: context)) = error {
        return context.contains("CRcv")
    }
    return false
}

private func isSendSuccess<R: ChatAPIResult>(_ result: APIResult<R>) -> Bool {
    if case .result = result { return true }
    return false
}

func apiSendMessages(type: ChatType, id: Int64, scope: GroupChatScope?, sendAsGroup: Bool = false, live: Bool = false, ttl: Int? = nil, composedMessages: [ComposedMessage]) async -> [ChatItem]? {
    let cmd: ChatCommand = .apiSendMessages(type: type, id: id, scope: scope, sendAsGroup: sendAsGroup, live: live, ttl: ttl, composedMessages: composedMessages)
    return await processSendMessageCmd(toChatType: type, cmd: cmd)
}

func processSendMessageCmd(toChatType: ChatType, cmd: ChatCommand) async -> [ChatItem]? {
    let r: APIResult<ChatResponse1>
    if toChatType == .direct {
        let cItemRef = ThreadSafeRef<ChatItem?>(nil)
        let endTask = beginBGTask({
            if let cItem = cItemRef.value {
                DispatchQueue.main.async {
                    _ = ChatModel.shared.removeMessageDelivery(cItem.id)
                }
            }
        })
        r = await chatApiSendCmd(cmd, bgTask: false)
        if case let .result(.newChatItems(_, aChatItems), _) = r {
            let cItems = aChatItems.map { $0.chatItem }
            if let cItemLast = cItems.last {
                cItemRef.value = cItemLast
                await MainActor.run { ChatModel.shared.messageDelivery[cItemLast.id] = endTask }
            }
            return cItems
        }
        if isCRcvConnectionError(r.unexpected) {
            logger.warning("send failed with CRcv connection state, attempting multi-stage recovery")

            // Stage 1: Reconnect all SMP servers
            logger.info("CRcv recovery stage 1: reconnecting all servers")
            do {
                try await reconnectAllServers()
            } catch {
                logger.error("CRcv recovery stage 1 reconnect failed: \(error)")
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            var retryResult: APIResult<ChatResponse1> = await chatApiSendCmd(cmd, bgTask: false)

            // Stage 2: If still failing, restart chat controller to reset connection states
            if !isSendSuccess(retryResult) {
                logger.info("CRcv recovery stage 1 failed, attempting chat restart")
                do {
                    try await apiStopChat()
                } catch {
                    logger.error("CRcv recovery stage 2 apiStopChat failed: \(error)")
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    do {
                        try startChat(refreshInvitations: false)
                    } catch {
                        logger.error("CRcv recovery stage 2 startChat failed: \(error)")
                    }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                retryResult = await chatApiSendCmd(cmd, bgTask: false)
            }

            if isSendSuccess(retryResult) {
                if case let .result(.newChatItems(_, aChatItems), _) = retryResult {
                    let cItems = aChatItems.map { $0.chatItem }
                    if let cItemLast = cItems.last {
                        cItemRef.value = cItemLast
                        await MainActor.run { ChatModel.shared.messageDelivery[cItemLast.id] = endTask }
                    }
                    logger.info("CRcv recovery succeeded")
                    return cItems
                }
            }

            logger.error("CRcv recovery failed after all stages: \(String(describing: retryResult.unexpected))")
            await AlertManager.shared.showAlertMsg(
                title: LocalizedStringKey(NSLocalizedString("model_connection_issue_title", comment: "alert title")),
                message: LocalizedStringKey(NSLocalizedString("model_connection_stuck_message", comment: "alert message"))
            )
        } else if let networkErrorAlert = networkErrorAlert(r) {
            await AlertManager.shared.showAlert(networkErrorAlert)
        } else {
            sendMessageErrorAlert(r.unexpected)
        }
        endTask()
        return nil
    } else {
        r = await chatApiSendCmd(cmd, bgDelay: msgDelay)
        if case let .result(.newChatItems(_, aChatItems), _) = r {
            return aChatItems.map { $0.chatItem }
        }
        sendMessageErrorAlert(r.unexpected)
        return nil
    }
}

func apiCreateChatItems(noteFolderId: Int64, composedMessages: [ComposedMessage]) async -> [ChatItem]? {
    let r: APIResult<ChatResponse1> = await chatApiSendCmd(.apiCreateChatItems(noteFolderId: noteFolderId, composedMessages: composedMessages))
    if case let .result(.newChatItems(_, aChatItems), _) = r { return aChatItems.map { $0.chatItem } }
    createChatItemsErrorAlert(r.unexpected)
    return nil
}

func apiReportMessage(groupId: Int64, chatItemId: Int64, reportReason: ReportReason, reportText: String) async -> [ChatItem]? {
    let r: APIResult<ChatResponse1> = await chatApiSendCmd(.apiReportMessage(groupId: groupId, chatItemId: chatItemId, reportReason: reportReason, reportText: reportText))
    if case let .result(.newChatItems(_, aChatItems), _) = r { return aChatItems.map { $0.chatItem } }

    logger.error("apiReportMessage error: \(String(describing: r))")
    await AlertManager.shared.showAlertMsg(
        title: LocalizedStringKey(NSLocalizedString("model_error_creating_report_title", comment: "alert title")),
        message: LocalizedStringKey(String(format: NSLocalizedString("model_error_detail_message", comment: "alert message"), responseError(r.unexpected)))
    )
    return nil
}

private func sendMessageErrorAlert(_ r: ChatError) {
    logger.error("send message error: \(String(describing: r))")
    Task { @MainActor in
        AlertManager.shared.showAlertMsg(
            title: LocalizedStringKey(NSLocalizedString("model_error_sending_message_title", comment: "alert title")),
            message: LocalizedStringKey(String(format: NSLocalizedString("model_error_detail_message", comment: "alert message"), responseError(r)))
        )
    }
}

private func createChatItemsErrorAlert(_ r: ChatError) {
    logger.error("apiCreateChatItems error: \(String(describing: r))")
    Task { @MainActor in
        AlertManager.shared.showAlertMsg(
            title: LocalizedStringKey(NSLocalizedString("model_error_creating_message_title", comment: "alert title")),
            message: LocalizedStringKey(String(format: NSLocalizedString("model_error_detail_message", comment: "alert message"), responseError(r)))
        )
    }
}

// MARK: - Update/Delete Chat Item Functions

func apiUpdateChatItem(type: ChatType, id: Int64, scope: GroupChatScope?, itemId: Int64, updatedMessage: UpdatedMessage, live: Bool = false) async throws -> ChatItem {
    let r: ChatResponse1 = try await chatSendCmd(.apiUpdateChatItem(type: type, id: id, scope: scope, itemId: itemId, updatedMessage: updatedMessage, live: live), bgDelay: msgDelay)
    switch r {
    case let .chatItemUpdated(_, aChatItem): return aChatItem.chatItem
    case let .chatItemNotChanged(_, aChatItem): return aChatItem.chatItem
    default: throw r.unexpected
    }
}

func apiChatItemReaction(type: ChatType, id: Int64, scope: GroupChatScope?, itemId: Int64, add: Bool, reaction: MsgReaction) async throws -> ChatItem {
    let r: ChatResponse1 = try await chatSendCmd(.apiChatItemReaction(type: type, id: id, scope: scope, itemId: itemId, add: add, reaction: reaction), bgDelay: msgDelay)
    if case let .chatItemReaction(_, _, reaction) = r { return reaction.chatReaction.chatItem }
    throw r.unexpected
}

func apiGetReactionMembers(groupId: Int64, itemId: Int64, reaction: MsgReaction) async throws -> [MemberReaction] {
    let userId = try await currentUserId("apiGetReactionMembers")
    let r: ChatResponse1 = try await chatSendCmd(.apiGetReactionMembers(userId: userId, groupId: groupId, itemId: itemId, reaction: reaction ))
    if case let .reactionMembers(_, memberReactions) = r { return memberReactions }
    throw r.unexpected
}

func apiDeleteChatItems(type: ChatType, id: Int64, scope: GroupChatScope?, itemIds: [Int64], mode: CIDeleteMode) async throws -> [ChatItemDeletion] {
    let r: ChatResponse1 = try await chatSendCmd(.apiDeleteChatItem(type: type, id: id, scope: scope, itemIds: itemIds, mode: mode), bgDelay: msgDelay)
    if case let .chatItemsDeleted(_, items, _, _) = r { return items }
    throw r.unexpected
}

func apiDeleteMemberChatItems(groupId: Int64, itemIds: [Int64]) async throws -> [ChatItemDeletion] {
    let r: ChatResponse1 = try await chatSendCmd(.apiDeleteMemberChatItem(groupId: groupId, itemIds: itemIds), bgDelay: msgDelay)
    if case let .chatItemsDeleted(_, items, _, _) = r { return items }
    throw r.unexpected
}

func apiArchiveReceivedReports(groupId: Int64) async throws -> ChatResponse1 {
    let r: ChatResponse1 = try await chatSendCmd(.apiArchiveReceivedReports(groupId: groupId), bgDelay: msgDelay)
    if case .groupChatItemsDeleted = r { return r }
    throw r.unexpected
}

func apiDeleteReceivedReports(groupId: Int64, itemIds: [Int64], mode: CIDeleteMode) async throws -> [ChatItemDeletion] {
    let r: ChatResponse1 = try await chatSendCmd(.apiDeleteReceivedReports(groupId: groupId, itemIds: itemIds, mode: mode), bgDelay: msgDelay)
    if case let .chatItemsDeleted(_, chatItemDeletions, _, _) = r { return chatItemDeletions }
    throw r.unexpected
}

// MARK: - Process Received Messages

@MainActor
func processReceivedMsg(_ res: ChatEvent) async {
    let m = ChatModel.shared
    let seq = m.nextEventSequence()
    logger.debug("processReceivedMsg: \(res.responseType) seq=\(seq)")
    switch res {
    case let .contactDeletedByContact(user, contact):
        if active(user) && contact.directOrUsed {
            m.updateContact(contact)
        }
    case let .contactConnected(user, contact, _):
        if active(user) && contact.directOrUsed {
            m.updateContact(contact)
            if let conn = contact.activeConn {
                m.dismissConnReqView(conn.id)
                m.removeChat(conn.id)
            }
            if contact.id == m.chatId, let conn = contact.activeConn {
                m.chatAgentConnId = conn.agentConnId
                m.chatSubStatus = .active
            }
        }
        if contact.directOrUsed {
            NtfManager.shared.notifyContactConnected(user, contact)
        }
    case let .contactConnecting(user, contact):
        if active(user) && contact.directOrUsed {
            m.updateContact(contact)
            if let conn = contact.activeConn {
                m.dismissConnReqView(conn.id)
                m.removeChat(conn.id)
            }
        }
    case let .contactSndReady(user, contact):
        if active(user) && contact.directOrUsed {
            m.updateContact(contact)
            if let conn = contact.activeConn {
                m.dismissConnReqView(conn.id)
                m.removeChat(conn.id)
            }
        }
    case let .receivedContactRequest(user, contactRequest, chat_):
        if active(user) {
            if let chat = chat_ { // means contact request was created with contact, so we need to add/update contact chat
                if !m.hasChat(chat.id) {
                    m.addChat(Chat(chat))
                } else if m.chatId == chat.id {
                    m.updateChatInfo(chat.chatInfo)
                } else {
                    m.replaceChat(chat.id, Chat(chat))
                }
            } else {
                let cInfo = ChatInfo.contactRequest(contactRequest: contactRequest)
                if m.hasChat(contactRequest.id) {
                    m.updateChatInfo(cInfo)
                } else {
                    m.addChat(Chat(
                        chatInfo: cInfo,
                        chatItems: []
                    ))
                }
            }
        }
        NtfManager.shared.notifyContactRequest(user, contactRequest)
    case let .contactUpdated(user, _, toContact):
        if active(user) && m.hasChat(toContact.id) {
            let cInfo = ChatInfo.direct(contact: toContact)
            m.updateChatInfo(cInfo)
        }
    case let .groupMemberUpdated(user, groupInfo, _, toMember):
        if active(user) {
            _ = m.upsertGroupMember(groupInfo, toMember)
        }
    case let .subscriptionStatus(_, status, connections):
        if let chatAgentConnId = m.chatAgentConnId, connections.contains(chatAgentConnId) {
            m.chatSubStatus = status
        }
    case let .chatInfoUpdated(user, chatInfo):
        if active(user) {
            m.updateChatInfo(chatInfo)
        }
    case let .newChatItems(user, chatItems):
        for chatItem in chatItems {
            let cInfo = chatItem.chatInfo
            let cItem = chatItem.chatItem
            m.trackNewItem(cItem.id)
            if active(user) {
                m.addChatItem(cInfo, cItem)
                if cItem.isActiveReport {
                    m.increaseGroupReportsCounter(cInfo.id)
                }
            } else if cItem.isRcvNew && cInfo.ntfsEnabled(chatItem: cItem) {
                m.increaseUnreadCounter(user: user)
            }
            if let file = cItem.autoReceiveFile() {
                Task {
                    await receiveFile(user: user, fileId: file.fileId, auto: true)
                }
            }
            if let botId = BinThereClient.shared.botChatId,
               cInfo.id == "@\(botId)",
               case .rcvMsgContent(msgContent: .text(let msgText)) = cItem.content {
                BinThereClient.shared.handleBotResponse(text: msgText)
            }
            if let configBotId = ConfigBotClient.shared.botChatId,
               cInfo.id == "@\(configBotId)",
               case .rcvMsgContent(msgContent: .text(let msgText)) = cItem.content {
                ConfigBotClient.shared.handleBotResponse(text: msgText)
            }
            if case .local = cInfo {
                DeadMansSwitch.shared.recordActivity()
            }
            switch cInfo {
            case .local, .direct, .group:
                let msgText: String?
                switch cItem.content {
                case .rcvMsgContent(msgContent: .text(let text)):
                    msgText = text
                case .sndMsgContent(msgContent: .text(let text)):
                    msgText = text
                default:
                    msgText = nil
                }
                if let text = msgText {
                    let chatId = cInfo.id
                    Task.detached(priority: .background) {
                        do {
                            let extractions = try await NeedleProcessor.shared.extract(from: text)
                            let tagged = extractions.map {
                                Extraction(id: $0.id, type: $0.type, data: $0.data,
                                           sourceText: $0.sourceText, chatId: chatId,
                                           createdAt: $0.createdAt)
                            }
                            if !tagged.isEmpty {
                                LocalExtractionStore.shared.save(tagged)

                                await MainActor.run {
                                    for extraction in extractions where extraction.type == .asset {
                                        WalletManager.shared.addEntry(from: extraction)
                                    }
                                }
                            }
                            await GenerativeArtTrigger.shared.evaluateOnReceive(text: text, extractions: extractions)
                        } catch {
                            logger.warning("Needle extraction failed: \(error)")
                        }
                    }
                }
            default:
                break
            }
            let isBinThereBot: Bool = {
                guard let botId = BinThereClient.shared.botChatId else { return false }
                return cInfo.id == "@\(botId)"
            }()
            let isConfigBot: Bool = {
                guard let botId = ConfigBotClient.shared.botChatId else { return false }
                return cInfo.id == "@\(botId)"
            }()
            if cItem.showNotification, !isBinThereBot, !isConfigBot {
                NtfManager.shared.notifyMessageReceived(user, cInfo, cItem)
            }
        }
    case let .chatItemsStatusesUpdated(user, chatItems):
        var tasksToEnd: [() -> Void] = []
        for chatItem in chatItems {
            let cInfo = chatItem.chatInfo
            let cItem = chatItem.chatItem
            if !m.isKnownItem(cItem.id) {
                logger.warning("processReceivedMsg: chatItemsStatusesUpdated for unknown item \(cItem.id) at seq=\(seq) - possible out-of-order delivery")
                m.trackNewItem(cItem.id)
            }
            if !cItem.isDeletedContent && active(user) {
                _ = m.upsertChatItem(cInfo, cItem)
            }
            if let endTask = m.removeMessageDelivery(cItem.id) {
                switch cItem.meta.itemStatus {
                case .sndSent, .sndRcvd, .sndErrorAuth, .sndError, .sndWarning:
                    tasksToEnd.append(endTask)
                default:
                    // Clean up background task even for non-terminal status updates
                    // to prevent leaks when intermediate statuses arrive
                    endTask()
                }
            }
        }
        for task in tasksToEnd { task() }
    case let .chatItemUpdated(user, aChatItem):
        await chatItemSimpleUpdate(user, aChatItem)
    case let .chatItemReaction(user, _, r):
        if active(user) {
            m.updateChatItem(r.chatInfo, r.chatReaction.chatItem)
        }
    case let .chatItemsDeleted(user, items, _, _):
        if !active(user) {
            for item in items {
                let d = item.deletedChatItem
                if item.toChatItem == nil && d.chatItem.isRcvNew && d.chatInfo.ntfsEnabled(chatItem: d.chatItem) {
                    m.decreaseUnreadCounter(user: user)
                }
            }
            return
        }

        for item in items {
            if let toChatItem = item.toChatItem {
                _ = m.upsertChatItem(toChatItem.chatInfo, toChatItem.chatItem)
            } else {
                m.removeChatItem(item.deletedChatItem.chatInfo, item.deletedChatItem.chatItem)
            }
            if item.deletedChatItem.chatItem.isActiveReport {
                m.decreaseGroupReportsCounter(item.deletedChatItem.chatInfo.id)
            }
        }
        if let updatedChatInfo = items.last?.deletedChatItem.chatInfo {
            m.updateChatInfo(updatedChatInfo)
        }
    case let .groupChatItemsDeleted(user, groupInfo, chatItemIDs, _, member_):
        await groupChatItemsDeleted(user, groupInfo, chatItemIDs, member_)
    case let .receivedGroupInvitation(user, groupInfo, _, _, _):
        if active(user) {
            m.updateGroup(groupInfo) // update so that repeat group invitations are not duplicated
            NtfManager.shared.notifyGroupInvitation(user, groupInfo)
        }
    case let .userAcceptedGroupSent(user, groupInfo, hostContact):
        if !active(user) { return }

        m.updateGroup(groupInfo)
        if let conn = hostContact?.activeConn {
            m.dismissConnReqView(conn.id)
            m.removeChat(conn.id)
        }
    case let .groupLinkConnecting(user, groupInfo, hostMember):
        if !active(user) { return }
        m.updateGroup(groupInfo)
        _ = m.upsertGroupMember(groupInfo, hostMember)
        if let hostConn = hostMember.activeConn {
            m.dismissConnReqView(hostConn.id)
            m.removeChat(hostConn.id)
        }
    case let .businessLinkConnecting(user, groupInfo, _, fromContact):
        if !active(user) { return }

        m.updateGroup(groupInfo)
        if m.chatId == fromContact.id {
            ItemsModel.shared.loadOpenChat(groupInfo.id)
        }
        m.removeChat(fromContact.id)
    case let .joinedGroupMemberConnecting(user, groupInfo, _, member):
        if active(user) {
            _ = m.upsertGroupMember(groupInfo, member)
        }
    case let .memberAcceptedByOther(user, groupInfo, _, member):
        if active(user) {
            _ = m.upsertGroupMember(groupInfo, member)
            m.updateGroup(groupInfo)
        }
    case let .deletedMemberUser(user, groupInfo, member, withMessages, _):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, groupInfo.membership)
            if withMessages {
                m.removeMemberItems(groupInfo.membership, byMember: member, groupInfo)
            }
        }
    case let .deletedMember(user, groupInfo, byMember, deletedMember, withMessages, _):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, deletedMember)
            if withMessages {
                m.removeMemberItems(deletedMember, byMember: byMember, groupInfo)
            }
        }
    case let .leftMember(user, groupInfo, member, _):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, member)
        }
    case let .groupDeleted(user, groupInfo, _, _):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, groupInfo.membership)
        }
    case let .userJoinedGroup(user, groupInfo, hostMember):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, hostMember)
            if m.chatId == groupInfo.id {
                if groupInfo.membership.memberPending {
                    m.secondaryPendingInviteeChatOpened = true
                } else if case .memberSupport(nil) = m.secondaryIM?.groupScopeInfo {
                    m.secondaryPendingInviteeChatOpened = false
                }
            }
        }
    case let .joinedGroupMember(user, groupInfo, member):
        if active(user) {
            _ = m.upsertGroupMember(groupInfo, member)
        }
    case let .connectedToGroupMember(user, groupInfo, member, _):
        if active(user) {
            _ = m.upsertGroupMember(groupInfo, member)
        }
    case let .groupUpdated(user, _, toGroup, _, _):
        if active(user) {
            m.updateGroup(toGroup)
        }
    case let .groupLinkDataUpdated(user, groupInfo, _, groupRelays, _):
        if active(user) {
            m.updateGroup(groupInfo)
            let relaysModel = ChannelRelaysModel.shared
            if relaysModel.groupId == groupInfo.groupId {
                relaysModel.set(groupId: groupInfo.groupId, groupRelays: groupRelays)
            }
        }
    case let .groupRelayUpdated(user, groupInfo, member, groupRelay):
        if active(user) {
            _ = m.upsertGroupMember(groupInfo, member)
            ChannelRelaysModel.shared.updateRelay(groupInfo, groupRelay)
        }
    case let .memberRole(user, groupInfo, byMember: _, member: member, fromRole: _, toRole: _, _):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, member)
        }
    case let .memberBlockedForAll(user, groupInfo, byMember: _, member: member, blocked: _, _):
        if active(user) {
            m.updateGroup(groupInfo)
            _ = m.upsertGroupMember(groupInfo, member)
        }
    case let .newMemberContactReceivedInv(user, contact, _, _):
        if active(user) {
            m.updateContact(contact)
        }
    case let .rcvFileAccepted(user, aChatItem): // usually rcvFileAccepted is a response, but it's also an event for XFTP files auto-accepted from NSE
        await chatItemSimpleUpdate(user, aChatItem)
// TODO [BLOCKED: rcvFileAcceptedSndCancelled event not yet implemented in upstream FFI]
//    case let .rcvFileAcceptedSndCancelled(user, aChatItem, _): // usually rcvFileAcceptedSndCancelled is a response, but it's also an event for legacy files auto-accepted from NSE.
//        await chatItemSimpleUpdate(user, aChatItem)
//        Task { cleanupFile(aChatItem) }
    case let .rcvFileStart(user, aChatItem):
        await chatItemSimpleUpdate(user, aChatItem)
    case let .rcvFileComplete(user, aChatItem):
        await chatItemSimpleUpdate(user, aChatItem)
    case let .rcvFileSndCancelled(user, aChatItem, _):
        await chatItemSimpleUpdate(user, aChatItem)
        Task { cleanupFile(aChatItem) }
    case let .rcvFileProgressXFTP(user, aChatItem, _, _, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
        }
    case let .rcvFileError(user, aChatItem, _, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
            Task { cleanupFile(aChatItem) }
        }
    case let .rcvFileWarning(user, aChatItem, _, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
        }
    case let .sndFileStart(user, aChatItem, _):
        await chatItemSimpleUpdate(user, aChatItem)
    case let .sndFileComplete(user, aChatItem, _):
        await chatItemSimpleUpdate(user, aChatItem)
        Task { cleanupDirectFile(aChatItem) }
    case let .sndFileRcvCancelled(user, aChatItem, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
            Task { cleanupDirectFile(aChatItem) }
        }
    case let .sndFileProgressXFTP(user, aChatItem, _, _, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
        }
    case let .sndFileCompleteXFTP(user, aChatItem, _):
        await chatItemSimpleUpdate(user, aChatItem)
    case let .sndFileError(user, aChatItem, _, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
            Task { cleanupFile(aChatItem) }
        }
    case let .sndFileWarning(user, aChatItem, _, _):
        if let aChatItem = aChatItem {
            await chatItemSimpleUpdate(user, aChatItem)
        }
    case let .callInvitation(invitation):
        m.callInvitations[invitation.contact.id] = invitation
        activateCall(invitation)
    case let .callOffer(_, contact, callType, offer, sharedKey, askConfirmation):
        await withCall(contact) { call in
            await MainActor.run {
                call.callState = .offerReceived
                call.sharedKey = sharedKey
            }
            if askConfirmation {
                showUnencryptedCallAlert(call) {
                    Task { await processCallOffer(callType, offer, sharedKey) }
                }
            } else {
                await processCallOffer(callType, offer, sharedKey)
            }
        }
    case let .callAnswer(_, contact, answer):
        await withCall(contact) { call in
            call.callState = .answerReceived
            await m.callCommand.processCommand(.answer(answer: answer.rtcSession, iceCandidates: answer.rtcIceCandidates))
        }
    case let .callExtraInfo(_, contact, extraInfo):
        await withCall(contact) { _ in
            await m.callCommand.processCommand(.ice(iceCandidates: extraInfo.rtcIceCandidates))
        }
    case let .callEnded(_, contact):
        if let invitation = m.callInvitations.removeValue(forKey: contact.id) {
            CallController.shared.reportCallRemoteEnded(invitation: invitation)
        }
        await withCall(contact) { call in
            await m.callCommand.processCommand(.end)
            CallController.shared.reportCallRemoteEnded(call: call)
        }
    case .chatSuspended:
        chatSuspended()
    case let .contactSwitch(user, contact, switchProgress):
        if active(user) {
            m.updateContactConnectionStats(contact, switchProgress.connectionStats)
        }
    case let .groupMemberSwitch(user, groupInfo, member, switchProgress):
        if active(user) {
            m.updateGroupMemberConnectionStats(groupInfo, member, switchProgress.connectionStats)
        }
    case let .contactRatchetSync(user, contact, ratchetSyncProgress):
        if active(user) {
            m.updateContactConnectionStats(contact, ratchetSyncProgress.connectionStats)
        }
    case let .groupMemberRatchetSync(user, groupInfo, member, ratchetSyncProgress):
        if active(user) {
            m.updateGroupMemberConnectionStats(groupInfo, member, ratchetSyncProgress.connectionStats)
        }
    case let .contactDisabled(user, contact):
        if active(user) {
            m.updateContact(contact)
        }
    case let .remoteCtrlFound(remoteCtrl, ctrlAppInfo_, appVersion, compatible):
        if let sess = m.remoteCtrlSession, case .searching = sess.sessionState {
            let state = UIRemoteCtrlSessionState.found(remoteCtrl: remoteCtrl, compatible: compatible)
            m.remoteCtrlSession = RemoteCtrlSession(
                ctrlAppInfo: ctrlAppInfo_,
                appVersion: appVersion,
                sessionState: state
            )
        }
    case let .remoteCtrlSessionCode(remoteCtrl_, sessionCode):
        let state = UIRemoteCtrlSessionState.pendingConfirmation(remoteCtrl_: remoteCtrl_, sessionCode: sessionCode)
        m.remoteCtrlSession = m.remoteCtrlSession?.updateState(state)
    case let .remoteCtrlConnected(remoteCtrl):
        // TODO [BLOCKED: verify if remoteCtrlConnected is truly redundant after upstream changes — keeping defensive handling]
        let state = UIRemoteCtrlSessionState.connected(remoteCtrl: remoteCtrl, sessionCode: m.remoteCtrlSession?.sessionCode ?? "")
        m.remoteCtrlSession = m.remoteCtrlSession?.updateState(state)
    case let .remoteCtrlStopped(_, rcStopReason):
        // This delay is needed to cancel the session that fails on network failure,
        // e.g. when user did not grant permission to access local network yet.
        if let sess = m.remoteCtrlSession {
            m.remoteCtrlSession = nil
            dismissAllSheets() {
                switch rcStopReason {
                case .disconnected:
                    ()
                case .connectionFailed(.errorAgent(.RCP(.identity))):
                    AlertManager.shared.showAlertMsg(
                        title: LocalizedStringKey(NSLocalizedString("model_desktop_stopped_title", comment: "alert title")),
                        message: LocalizedStringKey(NSLocalizedString("model_desktop_stopped_identity_message", comment: "alert message"))
                    )
                default:
                    AlertManager.shared.showAlert(Alert(
                        title: Text(LocalizedStringKey(NSLocalizedString("api_desktop_connection_stopped_title", comment: "Desktop connection stopped title"))),
                        message: Text(LocalizedStringKey(NSLocalizedString("api_desktop_connection_stopped_message", comment: "Desktop connection stopped message"))),
                        primaryButton: .default(Text(LocalizedStringKey(NSLocalizedString("api_desktop_ok", comment: "OK button")))),
                        secondaryButton: .default(Text(LocalizedStringKey(NSLocalizedString("api_desktop_copy_error", comment: "Copy error button")))) {
                            UIPasteboard.general.setItems([["public.utf8-plain-text": String(describing: rcStopReason)]], options: [.expirationDate: Date().addingTimeInterval(60), .localOnly: true])
                        }
                    ))
                }
            }
            if case .connected = sess.sessionState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    switchToLocalSession()
                }
            }
        }
    case let .contactPQEnabled(user, contact, _):
        if active(user) {
            m.updateContact(contact)
        }
    case let .hostConnected(protocol_, transportHost):
        logger.info("Notification host connected: \(protocol_) @ \(transportHost)")
    case let .hostDisconnected(protocol_, transportHost):
        logger.warning("Notification host disconnected: \(protocol_) @ \(transportHost)")
    case let .badgeChanged(user, badgeState):
        await MainActor.run {
            m.updateUser(user)
            if active(user) {
                BadgeModel.shared.set(userId: user.userId, badgeState: badgeState)
            }
        }
    case let .badgeAlert(user, badgeAlert):
        if active(user) {
            await MainActor.run {
                BadgeModel.shared.setAlert(userId: user.userId, alert: badgeAlert)
            }
        }
    default:
        logger.warning("Unhandled ChatEvent: \(res.responseType)")
    }

    func withCall(_ contact: Contact, _ perform: (Call) async -> Void) async {
        if let call = m.activeCall, call.contact.apiId == contact.apiId {
            await perform(call)
        } else {
            logger.debug("processReceivedMsg: ignoring \(res.responseType), not in call with the contact \(contact.id)")
        }
    }

    func processCallOffer(_ callType: CallType, _ offer: WebRTCSession, _ sharedKey: String?) async {
        let useRelay = UserDefaults.standard.bool(forKey: DEFAULT_WEBRTC_POLICY_RELAY)
        let iceServers = getIceServers()
        logger.debug(".callOffer useRelay \(useRelay)")
        logger.debug(".callOffer iceServers count=\(iceServers?.count ?? 0)")
        await m.callCommand.processCommand(.offer(
            offer: offer.rtcSession,
            iceCandidates: offer.rtcIceCandidates,
            media: callType.media, aesKey: sharedKey,
            iceServers: iceServers,
            relay: useRelay
        ))
    }

    func showUnencryptedCallAlert(_ call: Call, onContinue: @escaping () -> Void) {
        DispatchQueue.main.async {
            showAlert(
                NSLocalizedString("Call is not encrypted", comment: "alert title"),
                message: String.localizedStringWithFormat(NSLocalizedString("%@ accepted the call without end-to-end encryption.", comment: "alert message"), call.contact.displayName),
                actions: {[
                    UIAlertAction(title: NSLocalizedString("End call", comment: "alert action"), style: .destructive) { _ in
                        guard m.activeCall === call else { return }
                        if let uuid = call.callUUID {
                            CallController.shared.endCall(callUUID: uuid)
                        } else {
                            CallController.shared.endCall(call: call) {}
                        }
                    },
                    UIAlertAction(title: NSLocalizedString("Continue", comment: "alert action"), style: .default) { _ in
                        if m.activeCall === call { onContinue() }
                    }
                ]}
            )
        }
    }
}

// MARK: - Chat Item Update Helpers

@MainActor
func active(_ user: any UserLike) -> Bool {
    user.userId == ChatModel.shared.currentUser?.id
}

@MainActor
func chatItemSimpleUpdate(_ user: any UserLike, _ aChatItem: AChatItem) async {
    let m = ChatModel.shared
    let cInfo = aChatItem.chatInfo
    let cItem = aChatItem.chatItem
    if active(user) {
        if m.upsertChatItem(cInfo, cItem) {
            if cItem.showNotification {
                NtfManager.shared.notifyMessageReceived(user, cInfo, cItem)
            }
        }
    }
}

@MainActor
func groupChatItemsDeleted(_ user: UserRef, _ groupInfo: GroupInfo, _ chatItemIDs: Set<Int64>, _ member_: GroupMember?) async {
    let m = ChatModel.shared
    if !active(user) {
        do {
            let users = try await Task { try listUsers() }.value
            m.users = users
        } catch {
            logger.error("Error loading users: \(error)")
        }
        return
    }
    let im = ItemsModel.shared
    let cInfo = ChatInfo.group(groupInfo: groupInfo, groupChatScope: nil)
    m.decreaseGroupReportsCounter(cInfo.id, by: chatItemIDs.count)
    var notFound = chatItemIDs.count
    for ci in im.reversedChatItems {
        if chatItemIDs.contains(ci.id) {
            let deleted = if case let .groupRcv(groupMember) = ci.chatDir, let member_, groupMember.groupMemberId != member_.groupMemberId {
                CIDeleted.moderated(deletedTs: Date.now, byGroupMember: member_)
            } else {
                CIDeleted.deleted(deletedTs: Date.now)
            }
            var newItem = ci
            newItem.meta.itemDeleted = deleted
            _ = m.upsertChatItem(cInfo, newItem)
            notFound -= 1
            if notFound == 0 { break }
        }
    }
}
