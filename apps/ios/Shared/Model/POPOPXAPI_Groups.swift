//
//  POPOPXAPI_Groups.swift
//  POPOPX
//
//  Extracted from POPOPXAPI.swift
//  Group-related API functions
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Dispatch
import SwiftUI
@preconcurrency import POPOPXSwitch

// MARK: - Group Settings

func apiSetGroupAlias(groupId: Int64, localAlias: String) async throws -> GroupInfo? {
    let r: ChatResponse1 = try await chatSendCmd(.apiSetGroupAlias(groupId: groupId, localAlias: localAlias))
    if case let .groupAliasUpdated(_, toGroup) = r { return toGroup }
    throw r.unexpected
}

// MARK: - Group Creation Functions

func apiNewGroup(incognito: Bool, groupProfile: GroupProfile) async throws -> GroupInfo {
    let userId = try await currentUserId("apiNewGroup")
    let r: ChatResponse2 = try await chatSendCmd(.apiNewGroup(userId: userId, incognito: incognito, groupProfile: groupProfile))
    if case let .groupCreated(_, groupInfo) = r { return groupInfo }
    throw r.unexpected
}

enum PublicGroupCreationResult {
    case created(GroupInfo, GroupLink, [GroupRelay])
    case creationFailed([AddRelayResult])
}

func apiNewPublicGroup(incognito: Bool, relayIds: [Int64], groupProfile: GroupProfile) async throws -> PublicGroupCreationResult? {
    let userId = try await currentUserId("apiNewPublicGroup")
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiNewPublicGroup(userId: userId, incognito: incognito, relayIds: relayIds, groupProfile: groupProfile))
    switch r {
    case let .result(.publicGroupCreated(_, groupInfo, groupLink, groupRelays), _):
        return .created(groupInfo, groupLink, groupRelays)
    case let .result(.publicGroupCreationFailed(_, addRelayResults), _):
        return .creationFailed(addRelayResults)
    default: if let r { throw r.unexpected } else { return nil }
    }
}

func apiGetGroupRelays(_ groupId: Int64) async -> [GroupRelay] {
    let r: APIResult<ChatResponse2> = await chatApiSendCmd(.apiGetGroupRelays(groupId: groupId))
    if case let .result(.groupRelays(_, _, relays), _) = r { return relays }
    logger.error("apiGetGroupRelays unexpected response: \(String(describing: r))")
    return []
}

enum AddGroupRelaysResult {
    case added(GroupInfo, GroupLink, [GroupRelay])
    case addFailed([AddRelayResult])
}

func apiAddGroupRelays(_ groupId: Int64, relayIds: [Int64]) async throws -> AddGroupRelaysResult? {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiAddGroupRelays(groupId: groupId, relayIds: relayIds))
    switch r {
    case let .result(.groupRelaysAdded(_, groupInfo, groupLink, groupRelays), _):
        return .added(groupInfo, groupLink, groupRelays)
    case let .result(.groupRelaysAddFailed(_, addRelayResults), _):
        return .addFailed(addRelayResults)
    default: if let r { throw r.unexpected } else { return nil }
    }
}

// MARK: - Group Member Functions

func apiAddMember(_ groupId: Int64, _ contactId: Int64, _ memberRole: GroupMemberRole) async throws -> GroupMember {
    let r: ChatResponse2 = try await chatSendCmd(.apiAddMember(groupId: groupId, contactId: contactId, memberRole: memberRole))
    if case let .sentGroupInvitation(_, _, _, member) = r { return member }
    throw r.unexpected
}

enum JoinGroupResult {
    case joined(groupInfo: GroupInfo)
    case invitationRemoved
    case groupNotFound
}

func apiJoinGroup(_ groupId: Int64) async throws -> JoinGroupResult? {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiJoinGroup(groupId: groupId))
    switch r {
    case let .result(.userAcceptedGroupSent(_, groupInfo, _), _): return .joined(groupInfo: groupInfo)
    case .error(.errorAgent(.SMP(_, .AUTH)), _): return .invitationRemoved
    case .error(.errorStore(.groupNotFound), _): return .groupNotFound
    default: if let r { throw r.unexpected } else { return nil }
    }
}

func apiAcceptMember(_ groupId: Int64, _ groupMemberId: Int64, _ memberRole: GroupMemberRole) async throws -> (GroupInfo, GroupMember) {
    let r: ChatResponse2 = try await chatSendCmd(.apiAcceptMember(groupId: groupId, groupMemberId: groupMemberId, memberRole: memberRole))
    if case let .memberAccepted(_, groupInfo, member) = r { return (groupInfo, member) }
    throw r.unexpected
}

func apiDeleteMemberSupportChat(_ groupId: Int64, _ groupMemberId: Int64) async throws -> (GroupInfo, GroupMember) {
    let r: ChatResponse2 = try await chatSendCmd(.apiDeleteMemberSupportChat(groupId: groupId, groupMemberId: groupMemberId))
    if case let .memberSupportChatDeleted(_, groupInfo, member) = r { return (groupInfo, member) }
    throw r.unexpected
}

func apiRemoveMembers(_ groupId: Int64, _ memberIds: [Int64], _ withMessages: Bool) async throws -> (GroupInfo, [GroupMember]) {
    let r: ChatResponse2 = try await chatSendCmd(.apiRemoveMembers(groupId: groupId, memberIds: memberIds, withMessages: withMessages), bgTask: false)
    if case let .userDeletedMembers(_, updatedGroupInfo, members, _, _) = r { return (updatedGroupInfo, members) }
    throw r.unexpected
}

func apiMembersRole(_ groupId: Int64, _ memberIds: [Int64], _ memberRole: GroupMemberRole) async throws -> [GroupMember] {
    let r: ChatResponse2 = try await chatSendCmd(.apiMembersRole(groupId: groupId, memberIds: memberIds, memberRole: memberRole), bgTask: false)
    if case let .membersRoleUser(_, _, members, _, _) = r { return members }
    throw r.unexpected
}

func apiBlockMembersForAll(_ groupId: Int64, _ memberIds: [Int64], _ blocked: Bool) async throws -> [GroupMember] {
    let r: ChatResponse2 = try await chatSendCmd(.apiBlockMembersForAll(groupId: groupId, memberIds: memberIds, blocked: blocked), bgTask: false)
    if case let .membersBlockedForAllUser(_, _, members, _, _) = r { return members }
    throw r.unexpected
}

func leaveGroup(_ groupId: Int64) async {
    do {
        let groupInfo = try await apiLeaveGroup(groupId)
        await MainActor.run { ChatModel.shared.updateGroup(groupInfo) }
    } catch let error {
        logger.error("leaveGroup error: \(responseError(error))")
    }
}

func apiLeaveGroup(_ groupId: Int64) async throws -> GroupInfo {
    let r: ChatResponse2 = try await chatSendCmd(.apiLeaveGroup(groupId: groupId), bgTask: false)
    if case let .leftMemberUser(_, groupInfo) = r { return groupInfo }
    throw r.unexpected
}

// use ChatModel's loadGroupMembers from views
func apiListMembers(_ groupId: Int64) async -> [GroupMember] {
    let r: APIResult<ChatResponse2> = await chatApiSendCmd(.apiListMembers(groupId: groupId))
    if case let .result(.groupMembers(_, group), _) = r { return group.members }
    logger.error("apiListMembers unexpected response: \(String(describing: r))")
    return []
}

@MainActor
func filterMembersToAdd(_ ms: [GMember]) -> [Contact] {
    let memberContactIds = ms.compactMap{ m in m.wrapped.memberCurrent ? m.wrapped.memberContactId : nil }
    return ChatModel.shared.chats
        .compactMap{ c in c.chatInfo.sendMsgEnabled ? c.chatInfo.contact : nil }
        .filter{ c in !c.sendMsgToConnect && !memberContactIds.contains(c.apiId) }
        .sorted{ $0.displayName.lowercased() < $1.displayName.lowercased() }
}

// MARK: - Group Update Functions

func apiUpdateGroup(_ groupId: Int64, _ groupProfile: GroupProfile) async throws -> GroupInfo {
    let r: ChatResponse2 = try await chatSendCmd(.apiUpdateGroupProfile(groupId: groupId, groupProfile: groupProfile))
    if case let .groupUpdated(_, _, toGroup, _, _) = r { return toGroup }
    throw r.unexpected
}

// MARK: - Group Link Functions

func apiCreateGroupLink(_ groupId: Int64, memberRole: GroupMemberRole = .member) async throws -> GroupLink? {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiCreateGroupLink(groupId: groupId, memberRole: memberRole))
    if case let .result(.groupLinkCreated(_, _, groupLink), _) = r { return groupLink }
    if case let .error(.errorAgent(.NOTICE(server, preset, expires)), _) = r {
        showClientNotice(server, preset, expires)
        return nil
    }
    if let r { throw r.unexpected } else { return nil }
}

func apiGroupLinkMemberRole(_ groupId: Int64, memberRole: GroupMemberRole = .member) async throws -> GroupLink {
    let r: ChatResponse2 = try await chatSendCmd(.apiGroupLinkMemberRole(groupId: groupId, memberRole: memberRole))
    if case let .groupLink(_, _, groupLink) = r { return groupLink }
    throw r.unexpected
}

func apiDeleteGroupLink(_ groupId: Int64) async throws {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiDeleteGroupLink(groupId: groupId))
    if case .result(.groupLinkDeleted, _) = r { return }
    if let r { throw r.unexpected }
}

func apiGetGroupLink(_ groupId: Int64) throws -> GroupLink? {
    let r: APIResult<ChatResponse2> = chatApiSendCmdSync(.apiGetGroupLink(groupId: groupId))
    switch r {
    case let .result(.groupLink(_, _, groupLink), _):
        return groupLink
    case .error(.errorStore(storeError: .groupLinkNotFound), _):
        return nil
    default: throw r.unexpected
    }
}

func apiAddGroupShortLink(_ groupId: Int64) async throws -> GroupLink? {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiAddGroupShortLink(groupId: groupId))
    if case let .result(.groupLink(_, _, groupLink), _) = r { return groupLink }
    if let r { throw r.unexpected } else { return nil }
}

// MARK: - Member Contact Functions

func apiCreateMemberContact(_ groupId: Int64, _ groupMemberId: Int64) async throws -> Contact {
    let r: ChatResponse2 = try await chatSendCmd(.apiCreateMemberContact(groupId: groupId, groupMemberId: groupMemberId))
    if case let .newMemberContact(_, contact, _, _) = r { return contact }
    throw r.unexpected
}

func apiSendMemberContactInvitation(_ contactId: Int64, _ msg: MsgContent) async throws -> Contact {
    let r: ChatResponse2 = try await chatSendCmd(.apiSendMemberContactInvitation(contactId: contactId, msg: msg), bgDelay: msgDelay)
    if case let .newMemberContactSentInv(_, contact, _, _) = r { return contact }
    throw r.unexpected
}

func apiAcceptMemberContact(contactId: Int64) async -> Contact? {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiAcceptMemberContact(contactId: contactId))
    if case let .result(.memberContactAccepted(_, contact), _) = r { return contact }
    if let r {
        logger.error("apiAcceptMemberContact error: \(responseError(r.unexpected))")
        await AlertManager.shared.showAlert(apiConnectResponseAlert(r))
    }
    return nil
}

func acceptMemberContact(contactId: Int64, inProgress: Binding<Bool>? = nil) async {
    await MainActor.run { inProgress?.wrappedValue = true }
    if let contact = await apiAcceptMemberContact(contactId: contactId) {
        await MainActor.run {
            ChatModel.shared.updateContact(contact)
            inProgress?.wrappedValue = false
        }
        if contact.sndReady {
            DispatchQueue.main.async {
                dismissAllSheets(animated: true) {
                    ItemsModel.shared.loadOpenChat(contact.id)
                }
            }
        }
    } else {
        await MainActor.run { inProgress?.wrappedValue = false }
    }
}

func apiPrepareGroup(connLink: CreatedConnLink, directLink: Bool, groupShortLinkData: GroupShortLinkData) async throws -> ChatData {
    let userId = try await MainActor.run { try currentUserId("apiPrepareGroup") }
    let r: ChatResponse1 = try await chatSendCmd(.apiPrepareGroup(userId: userId, connLink: connLink, directLink: directLink, groupShortLinkData: groupShortLinkData))
    if case let .newPreparedChat(_, chat) = r { return chat }
    throw r.unexpected
}

func apiChangePreparedGroupUser(groupId: Int64, newUserId: Int64) async throws -> GroupInfo {
    let r: ChatResponse1 = try await chatSendCmd(.apiChangePreparedGroupUser(groupId: groupId, newUserId: newUserId))
    if case let .groupUserChanged(_, _, _, toGroup) = r { return toGroup }
    throw r.unexpected
}

func apiConnectPreparedGroup(groupId: Int64, incognito: Bool, msg: MsgContent?) async -> (GroupInfo, [RelayConnectionResult])? {
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiConnectPreparedGroup(groupId: groupId, incognito: incognito, msg: msg))
    if case let .result(.startedConnectionToGroup(_, groupInfo, relayResults), _) = r { return (groupInfo, relayResults) }
    if let r {
        logger.error("apiConnectPreparedGroup error: \(responseError(r.unexpected))")
        await AlertManager.shared.showAlert(apiConnectResponseAlert(r))
    }
    return nil
}
