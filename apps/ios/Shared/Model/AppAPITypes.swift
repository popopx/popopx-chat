//
//  APITypes.swift
//  POPOPX
//
//  Created by EP on 01/05/2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/api.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import POPOPXSwitch
import SwiftUI
import os

private let apiTypesLogger = Logger(subsystem: "com.popopxchat.popopx", category: "APITypes")

// some constructors are used in SEChatCommand or NSEChatCommand types as well - they must be syncronised
// Spec: spec/api.md#ChatCommand
enum ChatCommand: ChatCmdProtocol, @unchecked Sendable {
    case showActiveUser
    case createActiveUser(profile: Profile?, pastTimestamp: Bool)
    case listUsers
    case apiSetActiveUser(userId: Int64, viewPwd: String?)
    case setAllContactReceipts(enable: Bool)
    case apiSetUserContactReceipts(userId: Int64, userMsgReceiptSettings: UserMsgReceiptSettings)
    case apiSetUserGroupReceipts(userId: Int64, userMsgReceiptSettings: UserMsgReceiptSettings)
    case apiSetUserAutoAcceptMemberContacts(userId: Int64, enable: Bool)
    case apiSetUserAutoAcceptGroupInvitations(userId: Int64, enable: Bool)
    case apiSetUserChatRelay(userId: Int64, enable: Bool)
    case apiSetClientService(userId: Int64, enable: Bool)
    case apiHideUser(userId: Int64, viewPwd: String)
    case apiUnhideUser(userId: Int64, viewPwd: String)
    case apiMuteUser(userId: Int64)
    case apiUnmuteUser(userId: Int64)
    case apiDeleteUser(userId: Int64, delSMPQueues: Bool, viewPwd: String?)
    case startChat(mainApp: Bool, enableSndFiles: Bool)
    case checkChatRunning
    case apiStopChat
    case apiActivateChat(restoreChat: Bool)
    case apiSuspendChat(timeoutMicroseconds: Int)
    case apiSetAppFilePaths(filesFolder: String, tempFolder: String, assetsFolder: String)
    case apiSetEncryptLocalFiles(enable: Bool)
    case apiExportArchive(config: ArchiveConfig)
    case apiImportArchive(config: ArchiveConfig)
    case apiDeleteStorage
    case apiStorageEncryption(config: DBEncryptionConfig)
    case testStorageEncryption(key: String)
    case apiSaveSettings(settings: AppSettings)
    case apiGetSettings(settings: AppSettings)
    case apiGetChatTags(userId: Int64)
    case apiGetChats(userId: Int64)
    case apiGetChat(chatId: ChatId, scope: GroupChatScope?, contentTag: MsgContentTag?, pagination: ChatPagination, search: String)
    case apiGetChatContentTypes(chatId: ChatId, scope: GroupChatScope?)
    case apiGetChatItemInfo(type: ChatType, id: Int64, scope: GroupChatScope?, itemId: Int64)
    case apiSendMessages(type: ChatType, id: Int64, scope: GroupChatScope?, sendAsGroup: Bool, live: Bool, ttl: Int?, composedMessages: [ComposedMessage])
    case apiCreateChatTag(tag: ChatTagData)
    case apiSetChatTags(type: ChatType, id: Int64, tagIds: [Int64])
    case apiDeleteChatTag(tagId: Int64)
    case apiUpdateChatTag(tagId: Int64, tagData: ChatTagData)
    case apiReorderChatTags(tagIds: [Int64])
    case apiCreateChatItems(noteFolderId: Int64, composedMessages: [ComposedMessage])
    case apiReportMessage(groupId: Int64, chatItemId: Int64, reportReason: ReportReason, reportText: String)
    case apiUpdateChatItem(type: ChatType, id: Int64, scope: GroupChatScope?, itemId: Int64, updatedMessage: UpdatedMessage, live: Bool)
    case apiDeleteChatItem(type: ChatType, id: Int64, scope: GroupChatScope?, itemIds: [Int64], mode: CIDeleteMode)
    case apiDeleteMemberChatItem(groupId: Int64, itemIds: [Int64])
    case apiArchiveReceivedReports(groupId: Int64)
    case apiDeleteReceivedReports(groupId: Int64, itemIds: [Int64], mode: CIDeleteMode)
    case apiChatItemReaction(type: ChatType, id: Int64, scope: GroupChatScope?, itemId: Int64, add: Bool, reaction: MsgReaction)
    case apiGetReactionMembers(userId: Int64, groupId: Int64, itemId: Int64, reaction: MsgReaction)
    case apiPlanForwardChatItems(fromChatType: ChatType, fromChatId: Int64, fromScope: GroupChatScope?, itemIds: [Int64])
    case apiForwardChatItems(toChatType: ChatType, toChatId: Int64, toScope: GroupChatScope?, sendAsGroup: Bool, fromChatType: ChatType, fromChatId: Int64, fromScope: GroupChatScope?, itemIds: [Int64], ttl: Int?)
    case apiShareChatMsgContent(shareChatType: ChatType, shareChatId: Int64, toChatType: ChatType, toChatId: Int64, toScope: GroupChatScope?, sendAsGroup: Bool)
    case apiGetNtfToken
    case apiRegisterToken(token: DeviceToken, notificationMode: NotificationsMode)
    case apiVerifyToken(token: DeviceToken, nonce: String, code: String)
    case apiCheckToken(token: DeviceToken)
    case apiDeleteToken(token: DeviceToken)
    case apiGetNtfConns(nonce: String, encNtfInfo: String)
    case apiGetConnNtfMessages(connMsgReqs: [ConnMsgReq])
    case apiNewGroup(userId: Int64, incognito: Bool, groupProfile: GroupProfile)
    case apiNewPublicGroup(userId: Int64, incognito: Bool, relayIds: [Int64], groupProfile: GroupProfile)
    case apiGetGroupRelays(groupId: Int64)
    case apiAddGroupRelays(groupId: Int64, relayIds: [Int64])
    case apiAddMember(groupId: Int64, contactId: Int64, memberRole: GroupMemberRole)
    case apiJoinGroup(groupId: Int64)
    case apiAcceptMember(groupId: Int64, groupMemberId: Int64, memberRole: GroupMemberRole)
    case apiDeleteMemberSupportChat(groupId: Int64, groupMemberId: Int64)
    case apiMembersRole(groupId: Int64, memberIds: [Int64], memberRole: GroupMemberRole)
    case apiBlockMembersForAll(groupId: Int64, memberIds: [Int64], blocked: Bool)
    case apiRemoveMembers(groupId: Int64, memberIds: [Int64], withMessages: Bool)
    case apiLeaveGroup(groupId: Int64)
    case apiListMembers(groupId: Int64)
    case apiUpdateGroupProfile(groupId: Int64, groupProfile: GroupProfile)
    case apiCreateGroupLink(groupId: Int64, memberRole: GroupMemberRole)
    case apiGroupLinkMemberRole(groupId: Int64, memberRole: GroupMemberRole)
    case apiDeleteGroupLink(groupId: Int64)
    case apiGetGroupLink(groupId: Int64)
    case apiAddGroupShortLink(groupId: Int64)
    case apiCreateMemberContact(groupId: Int64, groupMemberId: Int64)
    case apiSendMemberContactInvitation(contactId: Int64, msg: MsgContent)
    case apiAcceptMemberContact(contactId: Int64)
    case apiTestProtoServer(userId: Int64, server: String)
    case apiTestChatRelay(userId: Int64, address: String)
    case apiGetServerOperators
    case apiSetServerOperators(operators: [ServerOperator])
    case apiGetUserServers(userId: Int64)
    case apiSetUserServers(userId: Int64, userServers: [UserOperatorServers])
    case apiValidateServers(userId: Int64, userServers: [UserOperatorServers])
    case apiGetBinThereBots(userId: Int64, botType: String)
    case apiInsertBinThereBot(userId: Int64, address: String, name: String?, botType: String)
    case apiReportBinThereBotUse(userId: Int64, botId: Int64)
    case apiSyncBotDirectory(userId: Int64, json: String)
    case apiGetComputeBalance(userId: Int64)
    case apiRecordComputePurchase(userId: Int64, purchase: ComputePurchaseFFI)
    case apiGetComputePurchases(userId: Int64)
    case apiGetUsageConditions
    case apiSetConditionsNotified(conditionsId: Int64)
    case apiAcceptConditions(conditionsId: Int64, operatorIds: [Int64])
    case apiSetChatItemTTL(userId: Int64, seconds: Int64)
    case apiGetChatItemTTL(userId: Int64)
    case apiSetChatTTL(userId: Int64, type: ChatType, id: Int64, seconds: Int64?)
    case apiSetNetworkConfig(networkConfig: NetCfg)
    case apiGetNetworkConfig
    case apiSetNetworkInfo(networkInfo: UserNetworkInfo)
    case reconnectAllServers
    case reconnectServer(userId: Int64, smpServer: String)
    case apiSetChatSettings(type: ChatType, id: Int64, chatSettings: ChatSettings)
    case apiSetMemberSettings(groupId: Int64, groupMemberId: Int64, memberSettings: GroupMemberSettings)
    case apiGetUpdatedGroupLinkData(groupId: Int64)
    case apiContactInfo(contactId: Int64)
    case apiGroupMemberInfo(groupId: Int64, groupMemberId: Int64)
    case apiContactQueueInfo(contactId: Int64)
    case apiGroupMemberQueueInfo(groupId: Int64, groupMemberId: Int64)
    case apiSwitchContact(contactId: Int64)
    case apiSwitchGroupMember(groupId: Int64, groupMemberId: Int64)
    case apiAbortSwitchContact(contactId: Int64)
    case apiAbortSwitchGroupMember(groupId: Int64, groupMemberId: Int64)
    case apiSyncContactRatchet(contactId: Int64, force: Bool)
    case apiSyncGroupMemberRatchet(groupId: Int64, groupMemberId: Int64, force: Bool)
    case apiGetContactCode(contactId: Int64)
    case apiGetGroupMemberCode(groupId: Int64, groupMemberId: Int64)
    case apiVerifyContact(contactId: Int64, connectionCode: String?)
    case apiVerifyGroupMember(groupId: Int64, groupMemberId: Int64, connectionCode: String?)
    case apiAddContact(userId: Int64, incognito: Bool)
    case apiSetConnectionIncognito(connId: Int64, incognito: Bool)
    case apiChangeConnectionUser(connId: Int64, userId: Int64)
    case apiConnectPlan(userId: Int64, connLink: String, linkOwnerSig: LinkOwnerSig?)
    case apiPrepareContact(userId: Int64, connLink: CreatedConnLink, contactShortLinkData: ContactShortLinkData)
    case apiPrepareGroup(userId: Int64, connLink: CreatedConnLink, directLink: Bool, groupShortLinkData: GroupShortLinkData)
    case apiChangePreparedContactUser(contactId: Int64, newUserId: Int64)
    case apiChangePreparedGroupUser(groupId: Int64, newUserId: Int64)
    case apiConnectPreparedContact(contactId: Int64, incognito: Bool, msg: MsgContent?)
    case apiConnectPreparedGroup(groupId: Int64, incognito: Bool, msg: MsgContent?)
    case apiConnect(userId: Int64, incognito: Bool, connLink: CreatedConnLink)
    case apiConnectContactViaAddress(userId: Int64, incognito: Bool, contactId: Int64)
    case apiDeleteChat(type: ChatType, id: Int64, chatDeleteMode: ChatDeleteMode)
    case apiClearChat(type: ChatType, id: Int64)
    case apiListContacts(userId: Int64)
    case apiUpdateProfile(userId: Int64, profile: Profile)
    case apiSetContactPrefs(contactId: Int64, preferences: Preferences)
    case apiSetContactAlias(contactId: Int64, localAlias: String)
    case apiSetGroupAlias(groupId: Int64, localAlias: String)
    case apiSetConnectionAlias(connId: Int64, localAlias: String)
    case apiSetUserUIThemes(userId: Int64, themes: ThemeModeOverrides?)
    case apiSetChatUIThemes(chatId: String, themes: ThemeModeOverrides?)
    case apiCreateMyAddress(userId: Int64)
    case apiDeleteMyAddress(userId: Int64)
    case apiShowMyAddress(userId: Int64)
    case apiAddMyAddressShortLink(userId: Int64)
    case apiSetProfileAddress(userId: Int64, on: Bool)
    case apiSetAddressSettings(userId: Int64, addressSettings: AddressSettings)
    case apiAcceptContact(incognito: Bool, contactReqId: Int64)
    case apiRejectContact(contactReqId: Int64)
    // WebRTC calls
    case apiSendCallInvitation(contact: Contact, callType: CallType)
    case apiRejectCall(contact: Contact)
    case apiSendCallOffer(contact: Contact, callOffer: WebRTCCallOffer)
    case apiSendCallAnswer(contact: Contact, answer: WebRTCSession)
    case apiSendCallExtraInfo(contact: Contact, extraInfo: WebRTCExtraInfo)
    case apiEndCall(contact: Contact)
    case apiGetCallInvitations
    case apiCallStatus(contact: Contact, callStatus: WebRTCCallStatus)
    // WebRTC calls /
    case apiChatRead(type: ChatType, id: Int64, scope: GroupChatScope?)
    case apiChatItemsRead(type: ChatType, id: Int64, scope: GroupChatScope?, itemIds: [Int64])
    case apiChatUnread(type: ChatType, id: Int64, unreadChat: Bool)
    case receiveFile(fileId: Int64, userApprovedRelays: Bool, encrypted: Bool?, inline: Bool?)
    case setFileToReceive(fileId: Int64, userApprovedRelays: Bool, encrypted: Bool?)
    case cancelFile(fileId: Int64)
    // remote desktop commands
    case setLocalDeviceName(displayName: String)
    case connectRemoteCtrl(xrcpInvitation: String)
    case confirmRemoteCtrl(remoteCtrlId: Int64)
    case verifyRemoteCtrlSession(sessionCode: String)
    case listRemoteCtrls
    case stopRemoteCtrl
    case deleteRemoteCtrl(remoteCtrlId: Int64)
    case apiUploadStandaloneFile(userId: Int64, file: CryptoFile)
    case apiDownloadStandaloneFile(userId: Int64, url: String, file: CryptoFile)
    case apiStandaloneFileInfo(url: String)
    // badges
    case apiRedeemBadgeCode(userId: Int64, code: String)
    case apiGetBadgeState(userId: Int64)
    case apiGetBadgeLedger(userId: Int64, badgePurchaseId: Int64)
    case apiAckBadgeAlert(userId: Int64, badgePurchaseId: Int64, alertKind: BadgeAlertKind, snooze: Bool, episode: String)
    // misc
    case showVersion
    case getAgentSubsTotal(userId: Int64)
    case getAgentServersSummary(userId: Int64)
    case resetAgentServersStats
    case string(String)

    var cmdString: String {
        get {
            switch self {
            case .showActiveUser: return "/u"
            case let .createActiveUser(profile, pastTimestamp):
                let user = NewUser(profile: profile, pastTimestamp: pastTimestamp)
                return "/_create user \(encodeJSON(user))"
            case .listUsers: return "/users"
            case let .apiSetActiveUser(userId, viewPwd): return "/_user \(userId)\(maybePwd(viewPwd))"
            case let .setAllContactReceipts(enable): return "/set receipts all \(onOff(enable))"
            case let .apiSetUserContactReceipts(userId, userMsgReceiptSettings):
                let umrs = userMsgReceiptSettings
                return "/_set receipts contacts \(userId) \(onOff(umrs.enable)) clear_overrides=\(onOff(umrs.clearOverrides))"
            case let .apiSetUserGroupReceipts(userId, userMsgReceiptSettings):
                let umrs = userMsgReceiptSettings
                return "/_set receipts groups \(userId) \(onOff(umrs.enable)) clear_overrides=\(onOff(umrs.clearOverrides))"
            case let .apiSetUserAutoAcceptMemberContacts(userId, enable):
                return "/_set accept member contacts \(userId) \(onOff(enable))"
            case let .apiSetUserAutoAcceptGroupInvitations(userId, enable):
                return "/_set accept group invitations \(userId) \(onOff(enable))"
            case let .apiSetUserChatRelay(userId, enable):
                return "/_set chat relay \(userId) \(onOff(enable))"
            case let .apiSetClientService(userId, enable):
                return "/_set client service \(userId) \(onOff(enable))"
            case let .apiHideUser(userId, viewPwd): return "/_hide user \(userId) \(encodeJSON(viewPwd))"
            case let .apiUnhideUser(userId, viewPwd): return "/_unhide user \(userId) \(encodeJSON(viewPwd))"
            case let .apiMuteUser(userId): return "/_mute user \(userId)"
            case let .apiUnmuteUser(userId): return "/_unmute user \(userId)"
            case let .apiDeleteUser(userId, delSMPQueues, viewPwd): return "/_delete user \(userId) del_smp=\(onOff(delSMPQueues))\(maybePwd(viewPwd))"
            case let .startChat(mainApp, enableSndFiles): return "/_start main=\(onOff(mainApp)) snd_files=\(onOff(enableSndFiles))"
            case .checkChatRunning: return "/_check running"
            case .apiStopChat: return "/_stop"
            case let .apiActivateChat(restore): return "/_app activate restore=\(onOff(restore))"
            case let .apiSuspendChat(timeoutMicroseconds): return "/_app suspend \(timeoutMicroseconds)"
            case let .apiSetAppFilePaths(filesFolder, tempFolder, assetsFolder): return "/set file paths \(encodeJSON(AppFilePaths(appFilesFolder: filesFolder, appTempFolder: tempFolder, appAssetsFolder: assetsFolder)))"
            case let .apiSetEncryptLocalFiles(enable): return "/_files_encrypt \(onOff(enable))"
            case let .apiExportArchive(cfg): return "/_db export \(encodeJSON(cfg))"
            case let .apiImportArchive(cfg): return "/_db import \(encodeJSON(cfg))"
            case .apiDeleteStorage: return "/_db delete"
            case let .apiStorageEncryption(cfg): return "/_db encryption \(encodeJSON(cfg))"
            case let .testStorageEncryption(key): return "/db test key \(key)"
            case let .apiSaveSettings(settings): return "/_save app settings \(encodeJSON(settings))"
            case let .apiGetSettings(settings): return "/_get app settings \(encodeJSON(settings))"
            case let .apiGetChatTags(userId): return "/_get tags \(userId)"
            case let .apiGetChats(userId): return "/_get chats \(userId) pcc=on"
            case let .apiGetChat(chatId, scope, contentTag, pagination, search):
                let tag = contentTag != nil ? " content=\(contentTag?.rawValue ?? "")" : ""
                return "/_get chat \(chatId)\(scopeRef(scope))\(tag) \(pagination.cmdString)" + (search == "" ? "" : " search=\(search)")
            case let .apiGetChatContentTypes(chatId, scope): return "/_get content types \(chatId)\(scopeRef(scope))"
            case let .apiGetChatItemInfo(type, id, scope, itemId): return "/_get item info \(ref(type, id, scope: scope)) \(itemId)"
            case let .apiSendMessages(type, id, scope, sendAsGroup, live, ttl, composedMessages):
                let msgs = encodeJSON(composedMessages)
                let ttlStr = ttl != nil ? "\(ttl ?? 0)" : "default"
                let asGroup = sendAsGroup ? "(as_group=on)" : ""
                return "/_send \(ref(type, id, scope: scope))\(asGroup) live=\(onOff(live)) ttl=\(ttlStr) json \(msgs)"
            case let .apiCreateChatTag(tag): return "/_create tag \(encodeJSON(tag))"
            case let .apiSetChatTags(type, id, tagIds): return "/_tags \(ref(type, id, scope: nil)) \(tagIds.map({ "\($0)" }).joined(separator: ","))"
            case let .apiDeleteChatTag(tagId): return "/_delete tag \(tagId)"
            case let .apiUpdateChatTag(tagId, tagData): return "/_update tag \(tagId) \(encodeJSON(tagData))"
            case let .apiReorderChatTags(tagIds): return "/_reorder tags \(tagIds.map({ "\($0)" }).joined(separator: ","))"
            case let .apiCreateChatItems(noteFolderId, composedMessages):
                let msgs = encodeJSON(composedMessages)
                return "/_create *\(noteFolderId) json \(msgs)"
            case let .apiReportMessage(groupId, chatItemId, reportReason, reportText):
                let safeText = sanitizeFFIParam(reportText, maxLen: 2048)
                return "/_report #\(groupId) \(chatItemId) reason=\(reportReason) \(safeText)"
            case let .apiUpdateChatItem(type, id, scope, itemId, um, live): return "/_update item \(ref(type, id, scope: scope)) \(itemId) live=\(onOff(live)) \(um.cmdString)"
            case let .apiDeleteChatItem(type, id, scope, itemIds, mode): return "/_delete item \(ref(type, id, scope: scope)) \(itemIds.map({ "\($0)" }).joined(separator: ",")) \(mode.rawValue)"
            case let .apiDeleteMemberChatItem(groupId, itemIds): return "/_delete member item #\(groupId) \(itemIds.map({ "\($0)" }).joined(separator: ","))"
            case let .apiArchiveReceivedReports(groupId): return "/_archive reports #\(groupId)"
            case let .apiDeleteReceivedReports(groupId, itemIds, mode): return "/_delete reports #\(groupId) \(itemIds.map({ "\($0)" }).joined(separator: ",")) \(mode.rawValue)"
            case let .apiChatItemReaction(type, id, scope, itemId, add, reaction): return "/_reaction \(ref(type, id, scope: scope)) \(itemId) \(onOff(add)) \(encodeJSON(reaction))"
            case let .apiGetReactionMembers(userId, groupId, itemId, reaction): return "/_reaction members \(userId) #\(groupId) \(itemId) \(encodeJSON(reaction))"
            case let .apiPlanForwardChatItems(type, id, scope, itemIds): return "/_forward plan \(ref(type, id, scope: scope)) \(itemIds.map({ "\($0)" }).joined(separator: ","))"
            case let .apiForwardChatItems(toChatType, toChatId, toScope, sendAsGroup, fromChatType, fromChatId, fromScope, itemIds, ttl):
                let ttlStr = ttl != nil ? "\(ttl ?? 0)" : "default"
                let asGroup = sendAsGroup ? " as_group=on" : ""
                return "/_forward \(ref(toChatType, toChatId, scope: toScope))\(asGroup) \(ref(fromChatType, fromChatId, scope: fromScope)) \(itemIds.map({ "\($0)" }).joined(separator: ",")) ttl=\(ttlStr)"
            case let .apiShareChatMsgContent(shareChatType, shareChatId, toChatType, toChatId, toScope, sendAsGroup):
                let asGroup = sendAsGroup ? "(as_group=on)" : ""
                return "/_share chat content \(ref(shareChatType, shareChatId, scope: nil)) \(ref(toChatType, toChatId, scope: toScope))\(asGroup)"
            case .apiGetNtfToken: return "/_ntf get "
            case let .apiRegisterToken(token, notificationMode): return "/_ntf register \(token.cmdString) \(notificationMode.rawValue)"
            case let .apiVerifyToken(token, nonce, code): return "/_ntf verify \(token.cmdString) \(nonce) \(code)"
            case let .apiCheckToken(token): return "/_ntf check \(token.cmdString)"
            case let .apiDeleteToken(token): return "/_ntf delete \(token.cmdString)"
            case let .apiGetNtfConns(nonce, encNtfInfo): return "/_ntf conns \(nonce) \(encNtfInfo)"
            case let .apiGetConnNtfMessages(connMsgReqs): return "/_ntf conn messages \(connMsgReqs.map { $0.cmdString }.joined(separator: ","))"
            case let .apiNewGroup(userId, incognito, groupProfile): return "/_group \(userId) incognito=\(onOff(incognito)) \(encodeJSON(groupProfile))"
            case let .apiNewPublicGroup(userId, incognito, relayIds, groupProfile): return "/_public group \(userId) incognito=\(onOff(incognito)) \(relayIds.map(String.init).joined(separator: ",")) \(encodeJSON(groupProfile))"
            case let .apiGetGroupRelays(groupId): return "/_get relays #\(groupId)"
            case let .apiAddGroupRelays(groupId, relayIds): return "/_add relays #\(groupId) \(relayIds.map(String.init).joined(separator: ","))"
            case let .apiAddMember(groupId, contactId, memberRole): return "/_add #\(groupId) \(contactId) \(memberRole)"
            case let .apiJoinGroup(groupId): return "/_join #\(groupId)"
            case let .apiAcceptMember(groupId, groupMemberId, memberRole): return "/_accept member #\(groupId) \(groupMemberId) \(memberRole.rawValue)"
            case let .apiDeleteMemberSupportChat(groupId, groupMemberId): return "/_delete member chat #\(groupId) \(groupMemberId)"
            case let .apiMembersRole(groupId, memberIds, memberRole): return "/_member role #\(groupId) \(memberIds.map({ "\($0)" }).joined(separator: ",")) \(memberRole.rawValue)"
            case let .apiBlockMembersForAll(groupId, memberIds, blocked): return "/_block #\(groupId) \(memberIds.map({ "\($0)" }).joined(separator: ",")) blocked=\(onOff(blocked))"
            case let .apiRemoveMembers(groupId, memberIds, withMessages): return "/_remove #\(groupId) \(memberIds.map({ "\($0)" }).joined(separator: ",")) messages=\(onOff(withMessages))"
            case let .apiLeaveGroup(groupId): return "/_leave #\(groupId)"
            case let .apiListMembers(groupId): return "/_members #\(groupId)"
            case let .apiUpdateGroupProfile(groupId, groupProfile): return "/_group_profile #\(groupId) \(encodeJSON(groupProfile))"
            case let .apiCreateGroupLink(groupId, memberRole): return "/_create link #\(groupId) \(memberRole)"
            case let .apiGroupLinkMemberRole(groupId, memberRole): return "/_set link role #\(groupId) \(memberRole)"
            case let .apiDeleteGroupLink(groupId): return "/_delete link #\(groupId)"
            case let .apiGetGroupLink(groupId): return "/_get link #\(groupId)"
            case let .apiAddGroupShortLink(groupId): return "/_short link #\(groupId)"
            case let .apiCreateMemberContact(groupId, groupMemberId): return "/_create member contact #\(groupId) \(groupMemberId)"
            case let .apiSendMemberContactInvitation(contactId, mc): return "/_invite member contact @\(contactId) \(mc.cmdString)"
            case let .apiAcceptMemberContact(contactId): return "/_accept member contact @\(contactId)"
            case let .apiTestProtoServer(userId, server): return "/_server test \(userId) \(server)"
            case let .apiTestChatRelay(userId, address): return "/_relay test \(userId) \(address)"
            case .apiGetServerOperators: return "/_operators"
            case let .apiSetServerOperators(operators): return "/_operators \(encodeJSON(operators))"
            case let .apiGetUserServers(userId): return "/_servers \(userId)"
            case let .apiSetUserServers(userId, userServers): return "/_servers \(userId) \(encodeJSON(userServers))"
            case let .apiValidateServers(userId, userServers): return "/_validate_servers \(userId) \(encodeJSON(userServers))"
            case let .apiGetBinThereBots(userId, botType): return "/_binthere_bots \(userId) \(botType)"
            case let .apiInsertBinThereBot(userId, address, name, botType): return "/_binthere_bot_add \(userId) \(address) \(name ?? "") \(botType)"
            case let .apiReportBinThereBotUse(userId, botId): return "/_binthere_bot_use \(userId) \(botId)"
            case let .apiSyncBotDirectory(userId, json): return "/_bot_directory_sync \(userId) \(json)"
            case let .apiGetComputeBalance(userId): return "/_compute_balance \(userId)"
            case let .apiRecordComputePurchase(userId, purchase): return "/_compute_purchase_record \(userId) \(encodeJSON(purchase))"
            case let .apiGetComputePurchases(userId): return "/_compute_purchases \(userId)"
            case .apiGetUsageConditions: return "/_conditions"
            case let .apiSetConditionsNotified(conditionsId): return "/_conditions_notified \(conditionsId)"
            case let .apiAcceptConditions(conditionsId, operatorIds): return "/_accept_conditions \(conditionsId) \(joinedIds(operatorIds))"
            case let .apiSetChatItemTTL(userId, seconds): return "/_ttl \(userId) \(chatItemTTLStr(seconds: seconds))"
            case let .apiGetChatItemTTL(userId): return "/_ttl \(userId)"
            case let .apiSetChatTTL(userId, type, id, seconds): return "/_ttl \(userId) \(ref(type, id, scope: nil)) \(chatItemTTLStr(seconds: seconds))"
            case let .apiSetNetworkConfig(networkConfig): return "/_network \(encodeJSON(networkConfig))"
            case .apiGetNetworkConfig: return "/network"
            case let .apiSetNetworkInfo(networkInfo): return "/_network info \(encodeJSON(networkInfo))"
            case .reconnectAllServers: return "/reconnect"
            case let .reconnectServer(userId, smpServer): return "/reconnect \(userId) \(smpServer)"
            case let .apiSetChatSettings(type, id, chatSettings): return "/_settings \(ref(type, id, scope: nil)) \(encodeJSON(chatSettings))"
            case let .apiSetMemberSettings(groupId, groupMemberId, memberSettings): return "/_member settings #\(groupId) \(groupMemberId) \(encodeJSON(memberSettings))"
            case let .apiGetUpdatedGroupLinkData(groupId): return "/_get group link data #\(groupId)"
            case let .apiContactInfo(contactId): return "/_info @\(contactId)"
            case let .apiGroupMemberInfo(groupId, groupMemberId): return "/_info #\(groupId) \(groupMemberId)"
            case let .apiContactQueueInfo(contactId): return "/_queue info @\(contactId)"
            case let .apiGroupMemberQueueInfo(groupId, groupMemberId): return "/_queue info #\(groupId) \(groupMemberId)"
            case let .apiSwitchContact(contactId): return "/_switch @\(contactId)"
            case let .apiSwitchGroupMember(groupId, groupMemberId): return "/_switch #\(groupId) \(groupMemberId)"
            case let .apiAbortSwitchContact(contactId): return "/_abort switch @\(contactId)"
            case let .apiAbortSwitchGroupMember(groupId, groupMemberId): return "/_abort switch #\(groupId) \(groupMemberId)"
            case let .apiSyncContactRatchet(contactId, force): if force {
                return "/_sync @\(contactId) force=on"
            } else {
                return "/_sync @\(contactId)"
            }
            case let .apiSyncGroupMemberRatchet(groupId, groupMemberId, force): if force {
                return "/_sync #\(groupId) \(groupMemberId) force=on"
            } else {
                return "/_sync #\(groupId) \(groupMemberId)"
            }
            case let .apiGetContactCode(contactId): return "/_get code @\(contactId)"
            case let .apiGetGroupMemberCode(groupId, groupMemberId): return "/_get code #\(groupId) \(groupMemberId)"
            case let .apiVerifyContact(contactId, .some(connectionCode)): return "/_verify code @\(contactId) \(connectionCode)"
            case let .apiVerifyContact(contactId, .none): return "/_verify code @\(contactId)"
            case let .apiVerifyGroupMember(groupId, groupMemberId, .some(connectionCode)): return "/_verify code #\(groupId) \(groupMemberId) \(connectionCode)"
            case let .apiVerifyGroupMember(groupId, groupMemberId, .none): return "/_verify code #\(groupId) \(groupMemberId)"
            case let .apiAddContact(userId, incognito): return "/_connect \(userId) incognito=\(onOff(incognito))"
            case let .apiSetConnectionIncognito(connId, incognito): return "/_set incognito :\(connId) \(onOff(incognito))"
            case let .apiChangeConnectionUser(connId, userId): return "/_set conn user :\(connId) \(userId)"
            case let .apiConnectPlan(userId, connLink, linkOwnerSig):
                let sigStr = if let linkOwnerSig { " sig=\(encodeJSON(linkOwnerSig))" } else { "" }
                return "/_connect plan \(userId) \(connLink)\(sigStr)"
            case let .apiPrepareContact(userId, connLink, contactShortLinkData): return "/_prepare contact \(userId) \(connLink.connFullLink) \(connLink.connShortLink ?? "") \(encodeJSON(contactShortLinkData))"
            case let .apiPrepareGroup(userId, connLink, directLink, groupShortLinkData): return "/_prepare group \(userId) \(connLink.connFullLink) \(connLink.connShortLink ?? "") direct=\(onOff(directLink)) \(encodeJSON(groupShortLinkData))"
            case let .apiChangePreparedContactUser(contactId, newUserId): return "/_set contact user @\(contactId) \(newUserId)"
            case let .apiChangePreparedGroupUser(groupId, newUserId): return "/_set group user #\(groupId) \(newUserId)"
            case let .apiConnectPreparedContact(contactId, incognito, mc): return "/_connect contact @\(contactId) incognito=\(onOff(incognito))\(maybeContent(mc))"
            case let .apiConnectPreparedGroup(groupId, incognito, mc): return "/_connect group #\(groupId) incognito=\(onOff(incognito))\(maybeContent(mc))"
            case let .apiConnect(userId, incognito, connLink): return "/_connect \(userId) incognito=\(onOff(incognito)) \(connLink.connFullLink) \(connLink.connShortLink ?? "")"
            case let .apiConnectContactViaAddress(userId, incognito, contactId): return "/_connect contact \(userId) incognito=\(onOff(incognito)) \(contactId)"
            case let .apiDeleteChat(type, id, chatDeleteMode): return "/_delete \(ref(type, id, scope: nil)) \(chatDeleteMode.cmdString)"
            case let .apiClearChat(type, id): return "/_clear chat \(ref(type, id, scope: nil))"
            case let .apiListContacts(userId): return "/_contacts \(userId)"
            case let .apiUpdateProfile(userId, profile): return "/_profile \(userId) \(encodeJSON(profile))"
            case let .apiSetContactPrefs(contactId, preferences): return "/_set prefs @\(contactId) \(encodeJSON(preferences))"
            case let .apiSetContactAlias(contactId, localAlias): return "/_set alias @\(contactId) \(sanitizeFFIParam(localAlias, maxLen: 256))"
            case let .apiSetGroupAlias(groupId, localAlias): return "/_set alias #\(groupId) \(sanitizeFFIParam(localAlias, maxLen: 256))"
            case let .apiSetConnectionAlias(connId, localAlias): return "/_set alias :\(connId) \(sanitizeFFIParam(localAlias, maxLen: 256))"
            case let .apiSetUserUIThemes(userId, themes): return "/_set theme user \(userId) \(themes != nil ? encodeJSON(themes) : "")"
            case let .apiSetChatUIThemes(chatId, themes): return "/_set theme \(chatId) \(themes != nil ? encodeJSON(themes) : "")"
            case let .apiCreateMyAddress(userId): return "/_address \(userId)"
            case let .apiDeleteMyAddress(userId): return "/_delete_address \(userId)"
            case let .apiShowMyAddress(userId): return "/_show_address \(userId)"
            case let .apiAddMyAddressShortLink(userId): return "/_short_link_address \(userId)"
            case let .apiSetProfileAddress(userId, on): return "/_profile_address \(userId) \(onOff(on))"
            case let .apiSetAddressSettings(userId, addressSettings): return "/_address_settings \(userId) \(encodeJSON(addressSettings))"
            case let .apiAcceptContact(incognito, contactReqId): return "/_accept incognito=\(onOff(incognito)) \(contactReqId)"
            case let .apiRejectContact(contactReqId): return "/_reject \(contactReqId)"
            case let .apiSendCallInvitation(contact, callType): return "/_call invite @\(contact.apiId) \(encodeJSON(callType))"
            case let .apiRejectCall(contact): return "/_call reject @\(contact.apiId)"
            case let .apiSendCallOffer(contact, callOffer): return "/_call offer @\(contact.apiId) \(encodeJSON(callOffer))"
            case let .apiSendCallAnswer(contact, answer): return "/_call answer @\(contact.apiId) \(encodeJSON(answer))"
            case let .apiSendCallExtraInfo(contact, extraInfo): return "/_call extra @\(contact.apiId) \(encodeJSON(extraInfo))"
            case let .apiEndCall(contact): return "/_call end @\(contact.apiId)"
            case .apiGetCallInvitations: return "/_call get"
            case let .apiCallStatus(contact, callStatus): return "/_call status @\(contact.apiId) \(callStatus.rawValue)"
            case let .apiChatRead(type, id, scope): return "/_read chat \(ref(type, id, scope: scope))"
            case let .apiChatItemsRead(type, id, scope, itemIds): return "/_read chat items \(ref(type, id, scope: scope)) \(joinedIds(itemIds))"
            case let .apiChatUnread(type, id, unreadChat): return "/_unread chat \(ref(type, id, scope: nil)) \(onOff(unreadChat))"
            case let .receiveFile(fileId, userApprovedRelays, encrypt, inline): return "/freceive \(fileId)\(onOffParam("approved_relays", userApprovedRelays))\(onOffParam("encrypt", encrypt))\(onOffParam("inline", inline))"
            case let .setFileToReceive(fileId, userApprovedRelays, encrypt): return "/_set_file_to_receive \(fileId)\(onOffParam("approved_relays", userApprovedRelays))\(onOffParam("encrypt", encrypt))"
            case let .cancelFile(fileId): return "/fcancel \(fileId)"
            case let .setLocalDeviceName(displayName): return "/set device name \(displayName)"
            case let .connectRemoteCtrl(xrcpInv): return "/connect remote ctrl \(xrcpInv)"
            case let .confirmRemoteCtrl(rcId): return "/confirm remote ctrl \(rcId)"
            case let .verifyRemoteCtrlSession(sessCode): return "/verify remote ctrl \(sessCode)"
            case .listRemoteCtrls: return "/list remote ctrls"
            case .stopRemoteCtrl: return "/stop remote ctrl"
            case let .deleteRemoteCtrl(rcId): return "/delete remote ctrl \(rcId)"
            case let .apiUploadStandaloneFile(userId, file): return "/_upload \(userId) \(sanitizeFFIParam(file.filePath, maxLen: 4096))"
            case let .apiDownloadStandaloneFile(userId, link, file): return "/_download \(userId) \(sanitizeFFIParam(link, maxLen: 4096)) \(sanitizeFFIParam(file.filePath, maxLen: 4096))"
            case let .apiStandaloneFileInfo(link): return "/_download info \(sanitizeFFIParam(link, maxLen: 4096))"
            case let .apiRedeemBadgeCode(userId, code): return "/_redeem_badge_code \(userId) \(code)"
            case let .apiGetBadgeState(userId): return "/_badge state \(userId)"
            case let .apiGetBadgeLedger(userId, badgePurchaseId): return "/_badge ledger \(userId) \(badgePurchaseId)"
            case let .apiAckBadgeAlert(userId, badgePurchaseId, alertKind, snooze, episode):
                return "/_badge ack \(userId) \(badgePurchaseId) \(badgeAlertKindParam(alertKind)) \(onOff(snooze)) \(episode)"
            case .showVersion: return "/version"
            case let .getAgentSubsTotal(userId): return "/get subs total \(userId)"
            case let .getAgentServersSummary(userId): return "/get servers summary \(userId)"
            case .resetAgentServersStats: return "/reset servers stats"
            case let .string(str): return str
            }
        }
    }

    var cmdType: String {
        get {
            switch self {
            case .showActiveUser: return "showActiveUser"
            case .createActiveUser: return "createActiveUser"
            case .listUsers: return "listUsers"
            case .apiSetActiveUser: return "apiSetActiveUser"
            case .setAllContactReceipts: return "setAllContactReceipts"
            case .apiSetUserContactReceipts: return "apiSetUserContactReceipts"
            case .apiSetUserGroupReceipts: return "apiSetUserGroupReceipts"
            case .apiSetUserAutoAcceptMemberContacts: return "apiSetUserAutoAcceptMemberContacts"
            case .apiSetUserAutoAcceptGroupInvitations: return "apiSetUserAutoAcceptGroupInvitations"
            case .apiSetUserChatRelay: return "apiSetUserChatRelay"
            case .apiSetClientService: return "apiSetClientService"
            case .apiHideUser: return "apiHideUser"
            case .apiUnhideUser: return "apiUnhideUser"
            case .apiMuteUser: return "apiMuteUser"
            case .apiUnmuteUser: return "apiUnmuteUser"
            case .apiDeleteUser: return "apiDeleteUser"
            case .startChat: return "startChat"
            case .checkChatRunning: return "checkChatRunning"
            case .apiStopChat: return "apiStopChat"
            case .apiActivateChat: return "apiActivateChat"
            case .apiSuspendChat: return "apiSuspendChat"
            case .apiSetAppFilePaths: return "apiSetAppFilePaths"
            case .apiSetEncryptLocalFiles: return "apiSetEncryptLocalFiles"
            case .apiExportArchive: return "apiExportArchive"
            case .apiImportArchive: return "apiImportArchive"
            case .apiDeleteStorage: return "apiDeleteStorage"
            case .apiStorageEncryption: return "apiStorageEncryption"
            case .testStorageEncryption: return "testStorageEncryption"
            case .apiSaveSettings: return "apiSaveSettings"
            case .apiGetSettings: return "apiGetSettings"
            case .apiGetChatTags: return "apiGetChatTags"
            case .apiGetChats: return "apiGetChats"
            case .apiGetChat: return "apiGetChat"
            case .apiGetChatContentTypes: return "apiGetChatContentTypes"
            case .apiGetChatItemInfo: return "apiGetChatItemInfo"
            case .apiSendMessages: return "apiSendMessages"
            case .apiCreateChatTag: return "apiCreateChatTag"
            case .apiSetChatTags: return "apiSetChatTags"
            case .apiDeleteChatTag: return "apiDeleteChatTag"
            case .apiUpdateChatTag: return "apiUpdateChatTag"
            case .apiReorderChatTags: return "apiReorderChatTags"
            case .apiCreateChatItems: return "apiCreateChatItems"
            case .apiReportMessage: return "apiReportMessage"
            case .apiUpdateChatItem: return "apiUpdateChatItem"
            case .apiDeleteChatItem: return "apiDeleteChatItem"
            case .apiConnectContactViaAddress: return "apiConnectContactViaAddress"
            case .apiDeleteMemberChatItem: return "apiDeleteMemberChatItem"
            case .apiArchiveReceivedReports: return "apiArchiveReceivedReports"
            case .apiDeleteReceivedReports: return "apiDeleteReceivedReports"
            case .apiChatItemReaction: return "apiChatItemReaction"
            case .apiGetReactionMembers: return "apiGetReactionMembers"
            case .apiPlanForwardChatItems: return "apiPlanForwardChatItems"
            case .apiForwardChatItems: return "apiForwardChatItems"
            case .apiShareChatMsgContent: return "apiShareChatMsgContent"
            case .apiGetNtfToken: return "apiGetNtfToken"
            case .apiRegisterToken: return "apiRegisterToken"
            case .apiVerifyToken: return "apiVerifyToken"
            case .apiCheckToken: return "apiCheckToken"
            case .apiDeleteToken: return "apiDeleteToken"
            case .apiGetNtfConns: return "apiGetNtfConns"
            case .apiGetConnNtfMessages: return "apiGetConnNtfMessages"
            case .apiNewGroup: return "apiNewGroup"
            case .apiNewPublicGroup: return "apiNewPublicGroup"
            case .apiGetGroupRelays: return "apiGetGroupRelays"
            case .apiAddGroupRelays: return "apiAddGroupRelays"
            case .apiAddMember: return "apiAddMember"
            case .apiJoinGroup: return "apiJoinGroup"
            case .apiAcceptMember: return "apiAcceptMember"
            case .apiDeleteMemberSupportChat: return "apiDeleteMemberSupportChat"
            case .apiMembersRole: return "apiMembersRole"
            case .apiBlockMembersForAll: return "apiBlockMembersForAll"
            case .apiRemoveMembers: return "apiRemoveMembers"
            case .apiLeaveGroup: return "apiLeaveGroup"
            case .apiListMembers: return "apiListMembers"
            case .apiUpdateGroupProfile: return "apiUpdateGroupProfile"
            case .apiCreateGroupLink: return "apiCreateGroupLink"
            case .apiGroupLinkMemberRole: return "apiGroupLinkMemberRole"
            case .apiDeleteGroupLink: return "apiDeleteGroupLink"
            case .apiGetGroupLink: return "apiGetGroupLink"
            case .apiAddGroupShortLink: return "apiAddGroupShortLink"
            case .apiCreateMemberContact: return "apiCreateMemberContact"
            case .apiSendMemberContactInvitation: return "apiSendMemberContactInvitation"
            case .apiAcceptMemberContact: return "apiAcceptMemberContact"
            case .apiTestProtoServer: return "apiTestProtoServer"
            case .apiTestChatRelay: return "apiTestChatRelay"
            case .apiGetServerOperators: return "apiGetServerOperators"
            case .apiSetServerOperators: return "apiSetServerOperators"
            case .apiGetUserServers: return "apiGetUserServers"
            case .apiSetUserServers: return "apiSetUserServers"
            case .apiValidateServers: return "apiValidateServers"
            case .apiGetUsageConditions: return "apiGetUsageConditions"
            case .apiSetConditionsNotified: return "apiSetConditionsNotified"
            case .apiAcceptConditions: return "apiAcceptConditions"
            case .apiSetChatItemTTL: return "apiSetChatItemTTL"
            case .apiGetChatItemTTL: return "apiGetChatItemTTL"
            case .apiSetChatTTL: return "apiSetChatTTL"
            case .apiSetNetworkConfig: return "apiSetNetworkConfig"
            case .apiGetNetworkConfig: return "apiGetNetworkConfig"
            case .apiSetNetworkInfo: return "apiSetNetworkInfo"
            case .reconnectAllServers: return "reconnectAllServers"
            case .reconnectServer: return "reconnectServer"
            case .apiSetChatSettings: return "apiSetChatSettings"
            case .apiSetMemberSettings: return "apiSetMemberSettings"
            case .apiGetUpdatedGroupLinkData: return "apiGetUpdatedGroupLinkData"
            case .apiContactInfo: return "apiContactInfo"
            case .apiGroupMemberInfo: return "apiGroupMemberInfo"
            case .apiContactQueueInfo: return "apiContactQueueInfo"
            case .apiGroupMemberQueueInfo: return "apiGroupMemberQueueInfo"
            case .apiSwitchContact: return "apiSwitchContact"
            case .apiSwitchGroupMember: return "apiSwitchGroupMember"
            case .apiAbortSwitchContact: return "apiAbortSwitchContact"
            case .apiAbortSwitchGroupMember: return "apiAbortSwitchGroupMember"
            case .apiSyncContactRatchet: return "apiSyncContactRatchet"
            case .apiSyncGroupMemberRatchet: return "apiSyncGroupMemberRatchet"
            case .apiGetContactCode: return "apiGetContactCode"
            case .apiGetGroupMemberCode: return "apiGetGroupMemberCode"
            case .apiVerifyContact: return "apiVerifyContact"
            case .apiVerifyGroupMember: return "apiVerifyGroupMember"
            case .apiAddContact: return "apiAddContact"
            case .apiSetConnectionIncognito: return "apiSetConnectionIncognito"
            case .apiChangeConnectionUser: return "apiChangeConnectionUser"
            case .apiConnectPlan: return "apiConnectPlan"
            case .apiPrepareContact: return "apiPrepareContact"
            case .apiPrepareGroup: return "apiPrepareGroup"
            case .apiChangePreparedContactUser: return "apiChangePreparedContactUser"
            case .apiChangePreparedGroupUser: return "apiChangePreparedGroupUser"
            case .apiConnectPreparedContact: return "apiConnectPreparedContact"
            case .apiConnectPreparedGroup: return "apiConnectPreparedGroup"
            case .apiConnect: return "apiConnect"
            case .apiDeleteChat: return "apiDeleteChat"
            case .apiClearChat: return "apiClearChat"
            case .apiListContacts: return "apiListContacts"
            case .apiUpdateProfile: return "apiUpdateProfile"
            case .apiSetContactPrefs: return "apiSetContactPrefs"
            case .apiSetContactAlias: return "apiSetContactAlias"
            case .apiSetGroupAlias: return "apiSetGroupAlias"
            case .apiSetConnectionAlias: return "apiSetConnectionAlias"
            case .apiSetUserUIThemes: return "apiSetUserUIThemes"
            case .apiSetChatUIThemes: return "apiSetChatUIThemes"
            case .apiCreateMyAddress: return "apiCreateMyAddress"
            case .apiDeleteMyAddress: return "apiDeleteMyAddress"
            case .apiShowMyAddress: return "apiShowMyAddress"
            case .apiAddMyAddressShortLink: return "apiAddMyAddressShortLink"
            case .apiSetProfileAddress: return "apiSetProfileAddress"
            case .apiSetAddressSettings: return "apiSetAddressSettings"
            case .apiAcceptContact: return "apiAcceptContact"
            case .apiRejectContact: return "apiRejectContact"
            case .apiSendCallInvitation: return "apiSendCallInvitation"
            case .apiRejectCall: return "apiRejectCall"
            case .apiSendCallOffer: return "apiSendCallOffer"
            case .apiSendCallAnswer: return "apiSendCallAnswer"
            case .apiSendCallExtraInfo: return "apiSendCallExtraInfo"
            case .apiEndCall: return "apiEndCall"
            case .apiGetCallInvitations: return "apiGetCallInvitations"
            case .apiCallStatus: return "apiCallStatus"
            case .apiChatRead: return "apiChatRead"
            case .apiChatItemsRead: return "apiChatItemsRead"
            case .apiChatUnread: return "apiChatUnread"
            case .receiveFile: return "receiveFile"
            case .setFileToReceive: return "setFileToReceive"
            case .cancelFile: return "cancelFile"
            case .setLocalDeviceName: return "setLocalDeviceName"
            case .connectRemoteCtrl: return "connectRemoteCtrl"
            case .confirmRemoteCtrl: return "confirmRemoteCtrl"
            case .verifyRemoteCtrlSession: return "verifyRemoteCtrlSession"
            case .listRemoteCtrls: return "listRemoteCtrls"
            case .stopRemoteCtrl: return "stopRemoteCtrl"
            case .deleteRemoteCtrl: return "deleteRemoteCtrl"
            case .apiUploadStandaloneFile: return "apiUploadStandaloneFile"
            case .apiDownloadStandaloneFile: return "apiDownloadStandaloneFile"
            case .apiStandaloneFileInfo: return "apiStandaloneFileInfo"
            case .apiRedeemBadgeCode: return "apiRedeemBadgeCode"
            case .apiGetBadgeState: return "apiGetBadgeState"
            case .apiGetBadgeLedger: return "apiGetBadgeLedger"
            case .apiAckBadgeAlert: return "apiAckBadgeAlert"
            case .showVersion: return "showVersion"
            case .getAgentSubsTotal: return "getAgentSubsTotal"
            case .getAgentServersSummary: return "getAgentServersSummary"
            case .resetAgentServersStats: return "resetAgentServersStats"
            case .string: return "console command"
            case .apiGetBinThereBots: return "apiGetBinThereBots"
            case .apiInsertBinThereBot: return "apiInsertBinThereBot"
            case .apiReportBinThereBotUse: return "apiReportBinThereBotUse"
            case .apiSyncBotDirectory: return "apiSyncBotDirectory"
            case .apiGetComputeBalance: return "apiGetComputeBalance"
            case .apiRecordComputePurchase: return "apiRecordComputePurchase"
            case .apiGetComputePurchases: return "apiGetComputePurchases"
            }
        }
    }

    func ref(_ type: ChatType, _ id: Int64, scope: GroupChatScope?) -> String {
        "\(type.rawValue)\(id)\(scopeRef(scope))"
    }

    func scopeRef(_ scope: GroupChatScope?) -> String {
        switch (scope) {
        case .none: ""
        case let .memberSupport(groupMemberId_):
            if let groupMemberId = groupMemberId_ {
                "(_support:\(groupMemberId))"
            } else {
                "(_support)"
            }
        case .reports:
            "(reports, prohibited)" // can't use surrogate Reports scope
        }
    }

    func joinedIds(_ ids: [Int64]) -> String {
        ids.map { "\($0)" }.joined(separator: ",")
    }

    func chatItemTTLStr(seconds: Int64?) -> String {
        if let seconds = seconds {
            return String(seconds)
        } else {
            return "default"
        }
    }

    var obfuscated: ChatCommand {
        switch self {
        case let .apiStorageEncryption(cfg):
            return .apiStorageEncryption(config: DBEncryptionConfig(currentKey: obfuscate(cfg.currentKey), newKey: obfuscate(cfg.newKey)))
        case let .apiSetActiveUser(userId, viewPwd):
            return .apiSetActiveUser(userId: userId, viewPwd: obfuscate(viewPwd))
        case let .apiHideUser(userId, viewPwd):
            return .apiHideUser(userId: userId, viewPwd: obfuscate(viewPwd))
        case let .apiUnhideUser(userId, viewPwd):
            return .apiUnhideUser(userId: userId, viewPwd: obfuscate(viewPwd))
        case let .apiDeleteUser(userId, delSMPQueues, viewPwd):
            return .apiDeleteUser(userId: userId, delSMPQueues: delSMPQueues, viewPwd: obfuscate(viewPwd))
        case let .testStorageEncryption(key):
            return .testStorageEncryption(key: obfuscate(key))
        // a code is a bearer secret until it is redeemed, and the terminal shows and copies cmdString
        case let .apiRedeemBadgeCode(userId, code):
            return .apiRedeemBadgeCode(userId: userId, code: obfuscate(code))
        default: return self
        }
    }

    private func obfuscate(_ s: String) -> String {
        s == "" ? "" : "***"
    }

    private func obfuscate(_ s: String?) -> String? {
        if let s = s {
            return obfuscate(s)
        }
        return nil
    }

    private func onOffParam(_ param: String, _ b: Bool?) -> String {
        if let b = b {
            return " \(param)=\(onOff(b))"
        }
        return ""
    }

    private func maybePwd(_ pwd: String?) -> String {
        pwd == "" || pwd == nil ? "" : " " + encodeJSON(pwd)
    }

    // /_badge ack takes the kind in core's text encoding, not the JSON tag
    private func badgeAlertKindParam(_ kind: BadgeAlertKind) -> String {
        switch kind {
        case .renewalApproaching: "renewal_approaching"
        case .paymentIssue: "payment_issue"
        case .subscriptionEnded: "subscription_ended"
        case .prepaidEnding: "prepaid_ending"
        case .supportEnded: "support_ended"
        case .issueFailed: "issue_failed"
        }
    }

    private func maybeContent(_ mc: MsgContent?) -> String {
        if case let .text(s) = mc, s.isEmpty {
            ""
        } else if let mc {
            " " + mc.cmdString
        } else {
            ""
        }
    }
}

// ChatResponse is split to three enums to reduce stack size used when parsing it, parsing large enums is very inefficient.
// Spec: spec/api.md#ChatResponse0
enum ChatResponse0: Decodable, ChatAPIResult, @unchecked Sendable {
    case activeUser(user: User)
    case usersList(users: [UserInfo])
    case chatStarted
    case chatRunning
    case chatStopped
    case apiChats(user: UserRef, chats: [ChatData])
    case apiChat(user: UserRef, chat: ChatData, navInfo: NavigationInfo?)
    case chatContentTypes(contentTypes: [MsgContentTag])
    case chatTags(user: UserRef, userTags: [ChatTag])
    case chatItemInfo(user: UserRef, chatItem: AChatItem, chatItemInfo: ChatItemInfo)
    case serverTestResult(user: UserRef, testServer: String, testFailure: ProtocolTestFailure?, serverInfo: ServerInfoEither?)
    case chatRelayTestResult(user: UserRef, relayProfile: RelayProfile?, relayTestFailure: RelayTestFailure?)
    case serverOperatorConditions(conditions: ServerOperatorConditions)
    case userServers(user: UserRef, userServers: [UserOperatorServers])
    case binThereBots(user: UserRef, bots: [BinThereBotInfo])
    case computeBalance(user: UserRef, computeBalance: ComputeBalanceFFI)
    case computePurchaseRecorded(user: UserRef, computeBalance: ComputeBalanceFFI)
    case computePurchases(user: UserRef, purchases: [ComputePurchaseFFI])
    case userServersValidation(user: UserRef, serverErrors: [UserServersError], serverWarnings: [UserServersWarning])
    case usageConditions(usageConditions: UsageConditions, conditionsText: String, acceptedConditions: UsageConditions?)
    case chatItemTTL(user: UserRef, chatItemTTL: Int64?)
    case networkConfig(networkConfig: NetCfg)
    case contactInfo(user: UserRef, contact: Contact, connectionStats_: ConnectionStats?, customUserProfile: Profile?)
    case groupInfo(user: UserRef, groupInfo: GroupInfo)
    case groupMemberInfo(user: UserRef, groupInfo: GroupInfo, member: GroupMember, connectionStats_: ConnectionStats?)
    case queueInfo(user: UserRef, rcvMsgInfo: RcvMsgInfo?, queueInfo: ServerQueueInfo)
    case contactSwitchStarted(user: UserRef, contact: Contact, connectionStats: ConnectionStats)
    case groupMemberSwitchStarted(user: UserRef, groupInfo: GroupInfo, member: GroupMember, connectionStats: ConnectionStats)
    case contactSwitchAborted(user: UserRef, contact: Contact, connectionStats: ConnectionStats)
    case groupMemberSwitchAborted(user: UserRef, groupInfo: GroupInfo, member: GroupMember, connectionStats: ConnectionStats)
    case contactRatchetSyncStarted(user: UserRef, contact: Contact, connectionStats: ConnectionStats)
    case groupMemberRatchetSyncStarted(user: UserRef, groupInfo: GroupInfo, member: GroupMember, connectionStats: ConnectionStats)
    case contactCode(user: UserRef, contact: Contact, connectionCode: String)
    case groupMemberCode(user: UserRef, groupInfo: GroupInfo, member: GroupMember, connectionCode: String)
    case connectionVerified(user: UserRef, verified: Bool, expectedCode: String)
    case tagsUpdated(user: UserRef, userTags: [ChatTag], chatTags: [Int64])
    // Additional upstream constructors for full parity
    case chats(user: UserRef, chats: [ChatData])  // CRChats - list all chats without pagination
    case chatItems(user: UserRef, chatItems: [AChatItem])  // CRChatItems - batch chat items response
    case chatItemId(user: UserRef, chatItemId: Int64?)  // CRChatItemId - single chat item ID reference (Maybe)
    case broadcastSent(user: UserRef, successes: Int64)  // CRBroadcastSent - broadcast message sent confirmation
    case chatHelp(helpSection: String)  // CRChatHelp - help documentation response
    case welcome(user: UserRef)  // CRWelcome - welcome with user reference

    var responseType: String {
        switch self {
        case .activeUser: "activeUser"
        case .usersList: "usersList"
        case .chatStarted: "chatStarted"
        case .chatRunning: "chatRunning"
        case .chatStopped: "chatStopped"
        case .apiChats: "apiChats"
        case .apiChat: "apiChat"
        case .chatContentTypes: "chatContentTypes"
        case .chatTags: "chatTags"
        case .chatItemInfo: "chatItemInfo"
        case .serverTestResult: "serverTestResult"
        case .chatRelayTestResult: "chatRelayTestResult"
        case .serverOperatorConditions: "serverOperatorConditions"
        case .userServers: "userServers"
        case .binThereBots: "binThereBots"
        case .computeBalance: "computeBalance"
        case .computePurchaseRecorded: "computePurchaseRecorded"
        case .computePurchases: "computePurchases"
        case .userServersValidation: "userServersValidation"
        case .usageConditions: "usageConditions"
        case .chatItemTTL: "chatItemTTL"
        case .networkConfig: "networkConfig"
        case .contactInfo: "contactInfo"
        case .groupInfo: "groupInfo"
        case .groupMemberInfo: "groupMemberInfo"
        case .queueInfo: "queueInfo"
        case .contactSwitchStarted: "contactSwitchStarted"
        case .groupMemberSwitchStarted: "groupMemberSwitchStarted"
        case .contactSwitchAborted: "contactSwitchAborted"
        case .groupMemberSwitchAborted: "groupMemberSwitchAborted"
        case .contactRatchetSyncStarted: "contactRatchetSyncStarted"
        case .groupMemberRatchetSyncStarted: "groupMemberRatchetSyncStarted"
        case .contactCode: "contactCode"
        case .groupMemberCode: "groupMemberCode"
        case .connectionVerified: "connectionVerified"
        case .tagsUpdated: "tagsUpdated"
        case .chats: "chats"
        case .chatItems: "chatItems"
        case .chatItemId: "chatItemId"
        case .broadcastSent: "broadcastSent"
        case .chatHelp: "chatHelp"
        case .welcome: "welcome"
        }
    }

    var details: String {
        switch self {
        case let .activeUser(user): return String(describing: user)
        case let .usersList(users): return String(describing: users)
        case .chatStarted: return noDetails
        case .chatRunning: return noDetails
        case .chatStopped: return noDetails
        case let .apiChats(u, chats): return withUser(u, String(describing: chats))
        case let .apiChat(u, chat, navInfo): return withUser(u, "chat: \(String(describing: chat))\nnavInfo: \(String(describing: navInfo))")
        case let .chatContentTypes(types): return "content types: \(String(describing: types))"
        case let .chatTags(u, userTags): return withUser(u, "userTags: \(String(describing: userTags))")
        case let .chatItemInfo(u, chatItem, chatItemInfo): return withUser(u, "chatItem: \(String(describing: chatItem))\nchatItemInfo: \(String(describing: chatItemInfo))")
        case let .serverTestResult(u, server, testFailure, serverInfo): return withUser(u, "server: \(server)\nresult: \(String(describing: testFailure))\nserverInfo: \(String(describing: serverInfo))")
        case let .chatRelayTestResult(u, relayProfile, relayTestFailure): return withUser(u, "relayProfile: \(String(describing: relayProfile))\nresult: \(String(describing: relayTestFailure))")
        case let .serverOperatorConditions(conditions): return "conditions: \(String(describing: conditions))"
        case let .userServers(u, userServers): return withUser(u, "userServers: \(String(describing: userServers))")
        case let .binThereBots(u, bots): return withUser(u, "binThereBots: \(String(describing: bots))")
        case let .computeBalance(u, bal): return withUser(u, "computeBalance: \(String(describing: bal))")
        case let .computePurchaseRecorded(u, bal): return withUser(u, "computePurchaseRecorded: \(String(describing: bal))")
        case let .computePurchases(u, purchases): return withUser(u, "computePurchases: \(String(describing: purchases))")
        case let .userServersValidation(u, serverErrors, serverWarnings): return withUser(u, "serverErrors: \(String(describing: serverErrors))\nserverWarnings: \(String(describing: serverWarnings))")
        case let .usageConditions(usageConditions, _, acceptedConditions): return "usageConditions: \(String(describing: usageConditions))\nacceptedConditions: \(String(describing: acceptedConditions))"
        case let .chatItemTTL(u, chatItemTTL): return withUser(u, String(describing: chatItemTTL))
        case let .networkConfig(networkConfig): return String(describing: networkConfig)
        case let .contactInfo(u, contact, connectionStats_, customUserProfile): return withUser(u, "contact: \(String(describing: contact))\nconnectionStats_: \(String(describing: connectionStats_))\ncustomUserProfile: \(String(describing: customUserProfile))")
        case let .groupInfo(u, groupInfo): return withUser(u, "groupInfo: \(String(describing: groupInfo))")
        case let .groupMemberInfo(u, groupInfo, member, connectionStats_): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nconnectionStats_: \(String(describing: connectionStats_))")
        case let .queueInfo(u, rcvMsgInfo, queueInfo):
            let msgInfo = if let info = rcvMsgInfo { encodeJSON(info) } else { "none" }
            return withUser(u, "rcvMsgInfo: \(msgInfo)\nqueueInfo: \(encodeJSON(queueInfo))")
        case let .contactSwitchStarted(u, contact, connectionStats): return withUser(u, "contact: \(String(describing: contact))\nconnectionStats: \(String(describing: connectionStats))")
        case let .groupMemberSwitchStarted(u, groupInfo, member, connectionStats): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nconnectionStats: \(String(describing: connectionStats))")
        case let .contactSwitchAborted(u, contact, connectionStats): return withUser(u, "contact: \(String(describing: contact))\nconnectionStats: \(String(describing: connectionStats))")
        case let .groupMemberSwitchAborted(u, groupInfo, member, connectionStats): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nconnectionStats: \(String(describing: connectionStats))")
        case let .contactRatchetSyncStarted(u, contact, connectionStats): return withUser(u, "contact: \(String(describing: contact))\nconnectionStats: \(String(describing: connectionStats))")
        case let .groupMemberRatchetSyncStarted(u, groupInfo, member, connectionStats): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nconnectionStats: \(String(describing: connectionStats))")
        case let .contactCode(u, contact, connectionCode): return withUser(u, "contact: \(String(describing: contact))\nconnectionCode: \(connectionCode)")
        case let .groupMemberCode(u, groupInfo, member, connectionCode): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nconnectionCode: \(connectionCode)")
        case let .connectionVerified(u, verified, expectedCode): return withUser(u, "verified: \(verified)\nconnectionCode: \(expectedCode)")
        case let .tagsUpdated(u, userTags, chatTags): return withUser(u, "userTags: \(String(describing: userTags))\nchatTags: \(String(describing: chatTags))")
        // New constructors for parity
        case let .chats(u, chats): return withUser(u, String(describing: chats))
        case let .chatItems(u, items): return withUser(u, "items: \(items.count)")
        case let .chatItemId(u, itemId): return withUser(u, "itemId: \(String(describing: itemId))")
        case let .broadcastSent(u, successes): return withUser(u, "successes: \(successes)")
        case let .chatHelp(section): return "helpSection: \(section.prefix(100))"
        case let .welcome(u): return withUser(u, "welcome")
        }
    }

    static func fallbackResult(_ type: String, _ json: NSDictionary) -> ChatResponse0? {
        if type == "activeUser" {
            if let jActiveUser = json["activeUser"] as? NSDictionary,
               let userObj = jActiveUser["user"] {
                do {
                    let user: User = try decodeObject(userObj)
                    return .activeUser(user: user)
                } catch {
                    logger.error("ChatResponse0.fallbackResult: failed to decode activeUser: \(error)")
                    return nil
                }
            }
        } else if type == "usersList" {
            if let jUsersList = json["usersList"] as? NSDictionary,
               let usersData = jUsersList["users"] as? [Any] {
                do {
                    let users = try usersData.compactMap({ try decodeObject($0) as UserInfo })
                    return .usersList(users: users)
                } catch {
                    logger.error("ChatResponse0.fallbackResult: failed to decode usersList: \(error)")
                    return nil
                }
            }
        } else if type == "chatStarted" {
            return .chatStarted
        } else if type == "chatRunning" {
            return .chatRunning
        } else if type == "chatStopped" {
            return .chatStopped
        } else if type == "chatItemTTL" {
            if let jTTL = json["chatItemTTL"] as? NSDictionary,
               let userObj = jTTL["user"] {
                do {
                    let user: UserRef = try decodeObject(userObj)
                    let ttl = jTTL["chatItemTTL"] as? Int64
                    return .chatItemTTL(user: user, chatItemTTL: ttl)
                } catch {
                    logger.error("ChatResponse0.fallbackResult: failed to decode chatItemTTL user: \(error)")
                    return nil
                }
            }
        } else if type == "networkConfig" {
            if let jCfg = json["networkConfig"] as? NSDictionary {
                do {
                    let cfg: NetCfg = try decodeObject(jCfg)
                    return .networkConfig(networkConfig: cfg)
                } catch {
                    logger.error("ChatResponse0.fallbackResult: failed to decode networkConfig: \(error)")
                    return nil
                }
            }
        } else if type == "chatContentTypes" {
            if let jTypes = json["chatContentTypes"] as? [Any] {
                do {
                    let types = try jTypes.compactMap({ try decodeObject($0) as MsgContentTag })
                    return .chatContentTypes(contentTypes: types)
                } catch {
                    logger.error("ChatResponse0.fallbackResult: failed to decode chatContentTypes: \(error)")
                    return nil
                }
            }
        } else if type == "chatTags" {
            if let jTags = json["chatTags"] as? NSDictionary,
               let userObj = jTags["user"],
               let userTagsData = jTags["userTags"] as? [Any] {
                do {
                    let user: UserRef = try decodeObject(userObj)
                    let userTags = try userTagsData.compactMap({ try decodeObject($0) as ChatTag })
                    return .chatTags(user: user, userTags: userTags)
                } catch {
                    logger.error("ChatResponse0.fallbackResult: failed to decode chatTags: \(error)")
                    return nil
                }
            }
        } else if type == "usageConditions" {
            if let jCond = json["usageConditions"] as? NSDictionary,
               let conditionsText = jCond["conditionsText"] as? String {
                let conditions = UsageConditions()
                let accepted: UsageConditions? = (jCond["acceptedConditions"] as? NSDictionary).flatMap { try? decodeObject($0) }
                return .usageConditions(usageConditions: conditions, conditionsText: conditionsText, acceptedConditions: accepted)
            }
        } else if type == "chatRelayTestResult" {
            guard let jRelay = json["chatRelayTestResult"] as? NSDictionary,
                  let userObj = jRelay["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            let relayProfile: RelayProfile? = (jRelay["relayProfile"] as? NSDictionary).flatMap { try? decodeObject($0) }
            let relayTestFailure: RelayTestFailure? = (jRelay["relayTestFailure"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .chatRelayTestResult(user: user, relayProfile: relayProfile, relayTestFailure: relayTestFailure)
        } else if type == "binThereBots" {
            guard let jVal = json["binThereBots"] as? NSDictionary,
                  let userObj = jVal["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            let bots: [BinThereBotInfo] = (jVal["bots"] as? [Any])?.compactMap { try? decodeObject($0) } ?? []
            return .binThereBots(user: user, bots: bots)
        } else if type == "computeBalance" {
            guard let jVal = json["computeBalance"] as? NSDictionary,
                  let userObj = jVal["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let bal: ComputeBalanceFFI = (jVal["computeBalance"] as? NSDictionary).flatMap { try? decodeObject($0) } else { return nil }
            return .computeBalance(user: user, computeBalance: bal)
        } else if type == "computePurchaseRecorded" {
            guard let jVal = json["computePurchaseRecorded"] as? NSDictionary,
                  let userObj = jVal["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let bal: ComputeBalanceFFI = (jVal["computeBalance"] as? NSDictionary).flatMap { try? decodeObject($0) } else { return nil }
            return .computePurchaseRecorded(user: user, computeBalance: bal)
        } else if type == "computePurchases" {
            guard let jVal = json["computePurchases"] as? NSDictionary,
                  let userObj = jVal["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            let purchases: [ComputePurchaseFFI] = (jVal["purchases"] as? [Any])?.compactMap { try? decodeObject($0) } ?? []
            return .computePurchases(user: user, purchases: purchases)
        } else if type == "userServersValidation" {
            guard let jVal = json["userServersValidation"] as? NSDictionary,
                  let userObj = jVal["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            let serverErrors: [UserServersError] = (jVal["serverErrors"] as? [Any])?.compactMap { try? decodeObject($0) } ?? []
            let serverWarnings: [UserServersWarning] = (jVal["serverWarnings"] as? [Any])?.compactMap { try? decodeObject($0) } ?? []
            return .userServersValidation(user: user, serverErrors: serverErrors, serverWarnings: serverWarnings)
        } else if type == "queueInfo" {
            guard let jQ = json["queueInfo"] as? NSDictionary,
                  let userObj = jQ["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            let rcvMsgInfo: RcvMsgInfo? = (jQ["rcvMsgInfo"] as? NSDictionary).flatMap { try? decodeObject($0) }
            guard let queueObj = jQ["queueInfo"],
                  let queueInfo: ServerQueueInfo = try? decodeObject(queueObj) else { return nil }
            return .queueInfo(user: user, rcvMsgInfo: rcvMsgInfo, queueInfo: queueInfo)
        } else if type == "contactSwitchStarted" {
            guard let jEvt = json["contactSwitchStarted"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = jEvt["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let statsObj = jEvt["connectionStats"],
                  let connectionStats: ConnectionStats = try? decodeObject(statsObj) else { return nil }
            return .contactSwitchStarted(user: user, contact: contact, connectionStats: connectionStats)
        } else if type == "groupMemberSwitchStarted" {
            guard let jEvt = json["groupMemberSwitchStarted"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let groupObj = jEvt["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(groupObj),
                  let memberObj = jEvt["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let statsObj = jEvt["connectionStats"],
                  let connectionStats: ConnectionStats = try? decodeObject(statsObj) else { return nil }
            return .groupMemberSwitchStarted(user: user, groupInfo: groupInfo, member: member, connectionStats: connectionStats)
        } else if type == "contactSwitchAborted" {
            guard let jEvt = json["contactSwitchAborted"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = jEvt["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let statsObj = jEvt["connectionStats"],
                  let connectionStats: ConnectionStats = try? decodeObject(statsObj) else { return nil }
            return .contactSwitchAborted(user: user, contact: contact, connectionStats: connectionStats)
        } else if type == "groupMemberSwitchAborted" {
            guard let jEvt = json["groupMemberSwitchAborted"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let groupObj = jEvt["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(groupObj),
                  let memberObj = jEvt["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let statsObj = jEvt["connectionStats"],
                  let connectionStats: ConnectionStats = try? decodeObject(statsObj) else { return nil }
            return .groupMemberSwitchAborted(user: user, groupInfo: groupInfo, member: member, connectionStats: connectionStats)
        } else if type == "contactRatchetSyncStarted" {
            guard let jEvt = json["contactRatchetSyncStarted"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = jEvt["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let statsObj = jEvt["connectionStats"],
                  let connectionStats: ConnectionStats = try? decodeObject(statsObj) else { return nil }
            return .contactRatchetSyncStarted(user: user, contact: contact, connectionStats: connectionStats)
        } else if type == "groupMemberRatchetSyncStarted" {
            guard let jEvt = json["groupMemberRatchetSyncStarted"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let groupObj = jEvt["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(groupObj),
                  let memberObj = jEvt["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let statsObj = jEvt["connectionStats"],
                  let connectionStats: ConnectionStats = try? decodeObject(statsObj) else { return nil }
            return .groupMemberRatchetSyncStarted(user: user, groupInfo: groupInfo, member: member, connectionStats: connectionStats)
        } else if type == "contactCode" {
            guard let jEvt = json["contactCode"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = jEvt["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let connectionCode = jEvt["connectionCode"] as? String else { return nil }
            return .contactCode(user: user, contact: contact, connectionCode: connectionCode)
        } else if type == "groupMemberCode" {
            guard let jEvt = json["groupMemberCode"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let groupObj = jEvt["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(groupObj),
                  let memberObj = jEvt["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let connectionCode = jEvt["connectionCode"] as? String else { return nil }
            return .groupMemberCode(user: user, groupInfo: groupInfo, member: member, connectionCode: connectionCode)
        } else if type == "connectionVerified" {
            guard let jEvt = json["connectionVerified"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let verified = jEvt["verified"] as? Bool,
                  let expectedCode = jEvt["expectedCode"] as? String else { return nil }
            return .connectionVerified(user: user, verified: verified, expectedCode: expectedCode)
        } else if type == "tagsUpdated" {
            guard let jEvt = json["tagsUpdated"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let userTagsData = jEvt["userTags"] as? [Any],
                  let userTags = try? userTagsData.compactMap({ try decodeObject($0) as ChatTag }),
                  let chatTags = jEvt["chatTags"] as? [Int64] else { return nil }
            return .tagsUpdated(user: user, userTags: userTags, chatTags: chatTags)
        } else if type == "chatItemInfo" {
            if let jInfo = json["chatItemInfo"] as? NSDictionary,
               let userObj = jInfo["user"],
               let user: UserRef = try? decodeObject(userObj),
               let chatItemObj = jInfo["chatItem"],
               let chatItem: AChatItem = try? decodeObject(chatItemObj),
               let chatItemInfoObj = jInfo["chatItemInfo"],
               let chatItemInfo: ChatItemInfo = try? decodeObject(chatItemInfoObj) {
                return .chatItemInfo(user: user, chatItem: chatItem, chatItemInfo: chatItemInfo)
            }
        } else if type == "apiChats" {
            if let r = parseApiChats(json) {
                return .apiChats(user: r.user, chats: r.chats)
            }
        } else if type == "apiChat" {
            if let jApiChat = json["apiChat"] as? NSDictionary,
               let userObj = jApiChat["user"],
               let user: UserRef = try? decodeObject(userObj),
               let jChat = jApiChat["chat"] as? NSDictionary,
               let (chat, navInfo) = try? parseChatData(jChat, jApiChat["navInfo"] as? NSDictionary) {
                return .apiChat(user: user, chat: chat, navInfo: navInfo)
            }
        } else if type == "serverOperatorConditions" {
            if let conditions = parseServerOperatorConditions(json) {
                return .serverOperatorConditions(conditions: conditions)
            }
        } else if type == "userServers" {
            if let (user, servers) = parseUserServers(json) {
                return .userServers(user: user, userServers: servers)
            }
        } else if type == "contactInfo" {
            if let (user, contact, connStats, profile) = parseContactInfo(json) {
                return .contactInfo(user: user, contact: contact, connectionStats_: connStats, customUserProfile: profile)
            }
        } else if type == "groupInfo" {
            if let (user, groupInfo) = parseGroupInfoResponse(json) {
                return .groupInfo(user: user, groupInfo: groupInfo)
            }
        } else if type == "groupMemberInfo" {
            if let (user, groupInfo, member, connStats) = parseGroupMemberInfo(json) {
                return .groupMemberInfo(user: user, groupInfo: groupInfo, member: member, connectionStats_: connStats)
            }
        } else if type == "chats" {
            logger.warning("ChatResponse0.fallbackResult: 'chats' response has no user field in Haskell CRChats, returning nil")
            return nil
        } else if type == "chatItems" {
            guard let jEvt = json["chatItems"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let itemsData = jEvt["chatItems"] as? [Any],
                  let items = try? itemsData.compactMap({ try decodeObject($0) as AChatItem }) else { return nil }
            return .chatItems(user: user, chatItems: items)
        } else if type == "chatItemId" {
            guard let jEvt = json["chatItemId"] as? NSDictionary else { return nil }
            let user: UserRef
            if let userObj = jEvt["user"], let u: UserRef = try? decodeObject(userObj) {
                user = u
            } else if let userObj = jEvt[""], let u: UserRef = try? decodeObject(userObj) {
                user = u
            } else {
                return nil
            }
            let itemId = jEvt["chatItemId"] as? Int64
            return .chatItemId(user: user, chatItemId: itemId)
        } else if type == "broadcastSent" {
            guard let jEvt = json["broadcastSent"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            let successes = jEvt["successes"] as? Int64 ?? 0
            return .broadcastSent(user: user, successes: successes)
        } else if type == "chatHelp" {
            let section: String
            if let jEvt = json["chatHelp"] as? NSDictionary {
                section = jEvt["helpSection"] as? String ?? String(describing: jEvt["helpSection"])
            } else {
                section = json["helpSection"] as? String ?? String(describing: json["helpSection"])
            }
            return .chatHelp(helpSection: section)
        } else if type == "welcome" {
            guard let jEvt = json["welcome"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj) else { return nil }
            return .welcome(user: user)
        } else if type == "serverTestResult" {
            guard let jEvt = json["serverTestResult"] as? NSDictionary,
                  let userObj = jEvt["user"],
                  let user: UserRef = try? decodeObject(userObj) else {
                logger.error("ChatResponse0.fallbackResult: serverTestResult missing user field, JSON: \(json)")
                return nil
            }
            let testServer: String
            if let s = jEvt["testServer"] as? String {
                testServer = s
            } else if let obj = jEvt["testServer"] {
                testServer = String(describing: obj)
            } else {
                testServer = ""
            }
            let testFailure: ProtocolTestFailure? = (jEvt["testFailure"] as? NSDictionary).flatMap { try? decodeObject($0) }
            let serverInfo: ServerInfoEither? = (jEvt["serverInfo"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .serverTestResult(user: user, testServer: testServer, testFailure: testFailure, serverInfo: serverInfo)
        }
        logger.warning("ChatResponse0.fallbackResult: unhandled response type '\(type)', full JSON: \(json)")
        return nil
    }

    static let useManualDecoding = true
}

// Spec: spec/api.md#ChatResponse1
enum ChatResponse1: Decodable, ChatAPIResult, @unchecked Sendable {
    case invitation(user: UserRef, connLinkInvitation: CreatedConnLink, encryptedConnLink: String?, connection: PendingContactConnection)
    case connectionIncognitoUpdated(user: UserRef, toConnection: PendingContactConnection)
    case connectionUserChanged(user: UserRef, fromConnection: PendingContactConnection, toConnection: PendingContactConnection, newUser: UserRef)
    case connectionPlan(user: UserRef, connLink: CreatedConnLink, connectionPlan: ConnectionPlan)
    case newPreparedChat(user: UserRef, chat: ChatData)
    case contactUserChanged(user: UserRef, fromContact: Contact, newUser: UserRef, toContact: Contact)
    case groupUserChanged(user: UserRef, fromGroup: GroupInfo, newUser: UserRef, toGroup: GroupInfo)
    case sentConfirmation(user: UserRef, connection: PendingContactConnection)
    case sentInvitation(user: UserRef, connection: PendingContactConnection)
    case startedConnectionToContact(user: UserRef, contact: Contact)
    case startedConnectionToGroup(user: UserRef, groupInfo: GroupInfo, relayResults: [RelayConnectionResult])
    case sentInvitationToContact(user: UserRef, contact: Contact, customUserProfile: Profile?)
    case contactAlreadyExists(user: UserRef, contact: Contact)
    case contactDeleted(user: UserRef, contact: Contact)
    case contactConnectionDeleted(user: UserRef, connection: PendingContactConnection)
    case groupDeletedUser(user: UserRef, groupInfo: GroupInfo, msgSigned: Bool)
    case itemsReadForChat(user: UserRef, chatInfo: ChatInfo)
    case chatCleared(user: UserRef, chatInfo: ChatInfo)
    case userProfileNoChange(user: User)
    case userProfileUpdated(user: User, fromProfile: Profile, toProfile: Profile, updateSummary: UserProfileUpdateSummary)
    case userPrivacy(user: User, updatedUser: User)
    case contactAliasUpdated(user: UserRef, toContact: Contact)
    case groupAliasUpdated(user: UserRef, toGroup: GroupInfo)
    case connectionAliasUpdated(user: UserRef, toConnection: PendingContactConnection)
    case contactPrefsUpdated(user: User, fromContact: Contact, toContact: Contact)
    case userContactLink(user: User, contactLink: UserContactLink)
    case userContactLinkUpdated(user: User, contactLink: UserContactLink)
    case userContactLinkCreated(user: User, connLinkContact: CreatedConnLink, encryptedConnLink: String?)
    case userContactLinkDeleted(user: User)
    case acceptingContactRequest(user: UserRef, contact: Contact)
    case contactRequestRejected(user: UserRef, contactRequest: UserContactRequest, contact_: Contact?)
    case newChatItems(user: UserRef, chatItems: [AChatItem])
    case chatMsgContent(user: UserRef, msgContent: MsgContent)
    case groupChatItemsDeleted(user: UserRef, groupInfo: GroupInfo, chatItemIDs: Set<Int64>, byUser: Bool, member_: GroupMember?)
    case forwardPlan(user: UserRef, itemsCount: Int, chatItemIds: [Int64], forwardConfirmation: ForwardConfirmation?)
    case chatItemUpdated(user: UserRef, chatItem: AChatItem)
    case chatItemNotChanged(user: UserRef, chatItem: AChatItem)
    case chatItemReaction(user: UserRef, added: Bool, reaction: ACIReaction)
    case reactionMembers(user: UserRef, memberReactions: [MemberReaction])
    case chatItemsDeleted(user: UserRef, chatItemDeletions: [ChatItemDeletion], byUser: Bool, timed: Bool)
    case contactsList(user: UserRef, contacts: [Contact])

    var responseType: String {
        switch self {
        case .invitation: "invitation"
        case .connectionIncognitoUpdated: "connectionIncognitoUpdated"
        case .connectionUserChanged: "connectionUserChanged"
        case .connectionPlan: "connectionPlan"
        case .newPreparedChat: "newPreparedChat"
        case .contactUserChanged: "contactUserChanged"
        case .groupUserChanged: "groupUserChanged"
        case .sentConfirmation: "sentConfirmation"
        case .sentInvitation: "sentInvitation"
        case .startedConnectionToContact: "startedConnectionToContact"
        case .startedConnectionToGroup: "startedConnectionToGroup"
        case .sentInvitationToContact: "sentInvitationToContact"
        case .contactAlreadyExists: "contactAlreadyExists"
        case .contactDeleted: "contactDeleted"
        case .contactConnectionDeleted: "contactConnectionDeleted"
        case .groupDeletedUser: "groupDeletedUser"
        case .itemsReadForChat: "itemsReadForChat"
        case .chatCleared: "chatCleared"
        case .userProfileNoChange: "userProfileNoChange"
        case .userProfileUpdated: "userProfileUpdated"
        case .userPrivacy: "userPrivacy"
        case .contactAliasUpdated: "contactAliasUpdated"
        case .groupAliasUpdated: "groupAliasUpdated"
        case .connectionAliasUpdated: "connectionAliasUpdated"
        case .contactPrefsUpdated: "contactPrefsUpdated"
        case .userContactLink: "userContactLink"
        case .userContactLinkUpdated: "userContactLinkUpdated"
        case .userContactLinkCreated: "userContactLinkCreated"
        case .userContactLinkDeleted: "userContactLinkDeleted"
        case .acceptingContactRequest: "acceptingContactRequest"
        case .contactRequestRejected: "contactRequestRejected"
        case .newChatItems: "newChatItems"
        case .chatMsgContent: "chatMsgContent"
        case .groupChatItemsDeleted: "groupChatItemsDeleted"
        case .forwardPlan: "forwardPlan"
        case .chatItemUpdated: "chatItemUpdated"
        case .chatItemNotChanged: "chatItemNotChanged"
        case .chatItemReaction: "chatItemReaction"
        case .reactionMembers: "reactionMembers"
        case .chatItemsDeleted: "chatItemsDeleted"
        case .contactsList: "contactsList"
        }
    }

    var details: String {
        switch self {
        case let .contactDeleted(u, contact): return withUser(u, String(describing: contact))
        case let .contactConnectionDeleted(u, connection): return withUser(u, String(describing: connection))
        case let .groupDeletedUser(u, groupInfo, _): return withUser(u, String(describing: groupInfo))
        case let .itemsReadForChat(u, chatInfo): return withUser(u, String(describing: chatInfo))
        case let .chatCleared(u, chatInfo): return withUser(u, String(describing: chatInfo))
        case .userProfileNoChange: return noDetails
        case let .userProfileUpdated(u, _, toProfile, _): return withUser(u, String(describing: toProfile))
        case let .userPrivacy(u, updatedUser): return withUser(u, String(describing: updatedUser))
        case let .contactAliasUpdated(u, toContact): return withUser(u, String(describing: toContact))
        case let .groupAliasUpdated(u, toGroup): return withUser(u, String(describing: toGroup))
        case let .connectionAliasUpdated(u, toConnection): return withUser(u, String(describing: toConnection))
        case let .contactPrefsUpdated(u, fromContact, toContact): return withUser(u, "fromContact: \(String(describing: fromContact))\ntoContact: \(String(describing: toContact))")
        case let .userContactLink(u, contactLink): return withUser(u, String(describing: contactLink))
        case let .userContactLinkUpdated(u, contactLink): return withUser(u, String(describing: contactLink))
        case let .userContactLinkCreated(u, connLink, _): return withUser(u, String(describing: connLink))
        case .userContactLinkDeleted: return noDetails
        case let .acceptingContactRequest(u, contact): return withUser(u, String(describing: contact))
        case let .contactRequestRejected(u, contactRequest, contact_): return withUser(u, "contactRequest: \(String(describing: contactRequest))\ncontact_: \(String(describing: contact_))")
        case let .newChatItems(u, chatItems):
            let itemsString = chatItems.map { chatItem in String(describing: chatItem) }.joined(separator: "\n")
            return withUser(u, itemsString)
        case let .chatMsgContent(u, mc): return withUser(u, String(describing: mc))
        case let .groupChatItemsDeleted(u, gInfo, chatItemIDs, byUser, member_):
            return withUser(u, "chatItemIDs: \(String(describing: chatItemIDs))\ngroupInfo: \(String(describing: gInfo))\nbyUser: \(byUser)\nmember_: \(String(describing: member_))")
        case let .forwardPlan(u, itemsCount, chatItemIds, forwardConfirmation): return withUser(u, "itemsCount: \(itemsCount)\nitems: \(chatItemIds) forwardConfirmation: \(String(describing: forwardConfirmation))")
        case let .chatItemUpdated(u, chatItem): return withUser(u, String(describing: chatItem))
        case let .chatItemNotChanged(u, chatItem): return withUser(u, String(describing: chatItem))
        case let .chatItemReaction(u, added, reaction): return withUser(u, "added: \(added)\n\(String(describing: reaction))")
        case let .reactionMembers(u, reaction): return withUser(u, "memberReactions: \(String(describing: reaction))")
        case let .chatItemsDeleted(u, items, byUser, timed):
            let itemsString = items.map { item in
                "deletedChatItem:\n\(String(describing: item.deletedChatItem))\ntoChatItem:\n\(String(describing: item.toChatItem))" }.joined(separator: "\n")
            return withUser(u, itemsString + "\nbyUser: \(byUser)\ntimed: \(timed)")
        case let .contactsList(u, contacts): return withUser(u, String(describing: contacts))
        case let .invitation(u, connLinkInvitation, _, connection): return withUser(u, "connLinkInvitation: \(connLinkInvitation)\nconnection: \(connection)")
        case let .connectionIncognitoUpdated(u, toConnection): return withUser(u, String(describing: toConnection))
        case let .connectionUserChanged(u, fromConnection, toConnection, newUser): return withUser(u, "fromConnection: \(String(describing: fromConnection))\ntoConnection: \(String(describing: toConnection))\nnewUserId: \(String(describing: newUser.userId))")
        case let .connectionPlan(u, connLink, connectionPlan): return withUser(u, "connLink: \(String(describing: connLink))\nconnectionPlan: \(String(describing: connectionPlan))")
        case let .newPreparedChat(u, chat): return withUser(u, String(describing: chat))
        case let .contactUserChanged(u, fromContact, newUser, toContact): return withUser(u, "fromContact: \(String(describing: fromContact))\nnewUserId: \(String(describing: newUser.userId))\ntoContact: \(String(describing: toContact))")
        case let .groupUserChanged(u, fromGroup, newUser, toGroup): return withUser(u, "fromGroup: \(String(describing: fromGroup))\nnewUserId: \(String(describing: newUser.userId))\ntoGroup: \(String(describing: toGroup))")
        case let .sentConfirmation(u, connection): return withUser(u, String(describing: connection))
        case let .sentInvitation(u, connection): return withUser(u, String(describing: connection))
        case let .startedConnectionToContact(u, contact): return withUser(u, String(describing: contact))
        case let .startedConnectionToGroup(u, groupInfo, relayResults): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nrelayResults: \(String(describing: relayResults))")
        case let .sentInvitationToContact(u, contact, _): return withUser(u, String(describing: contact))
        case let .contactAlreadyExists(u, contact): return withUser(u, String(describing: contact))
        }
    }

    static func fallbackResult(_ type: String, _ json: NSDictionary) -> ChatResponse1? {
        #if DEBUG
        apiTypesLogger.debug("fallbackResult CALLED with type='\(type)', json keys=\(json.allKeys)")
        #endif
        let data = json[type] as? NSDictionary ?? json
        switch type {
        case "invitation":
            #if DEBUG
            apiTypesLogger.debug("fallbackResult: processing invitation, data keys=\(data.allKeys)")
            #endif
            let encLinkRaw = data["encryptedConnLink"]
            #if DEBUG
            apiTypesLogger.debug("fallbackResult: encLinkRaw = \(String(describing: encLinkRaw))")
            #endif
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cliObj = data["connLinkInvitation"],
                  var connLinkInvitation: CreatedConnLink = try? decodeObject(cliObj),
                  let cObj = data["connection"],
                  let connection: PendingContactConnection = try? decodeObject(cObj) else { return nil }
            let encryptedConnLink = data["encryptedConnLink"] as? String
            #if DEBUG
            apiTypesLogger.debug("fallbackResult: decoded encryptedConnLink = \(String(describing: encryptedConnLink))")
            #endif
            if let enc = encryptedConnLink {
                connLinkInvitation.encryptedConnLink = enc
                #if DEBUG
                apiTypesLogger.debug("fallbackResult: set connLinkInvitation.encryptedConnLink")
                #endif
            }
            return .invitation(user: user, connLinkInvitation: connLinkInvitation, encryptedConnLink: encryptedConnLink, connection: connection)
        case "connectionIncognitoUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["toConnection"],
                  let toConnection: PendingContactConnection = try? decodeObject(cObj) else { return nil }
            return .connectionIncognitoUpdated(user: user, toConnection: toConnection)
        case "connectionUserChanged":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let fcObj = data["fromConnection"],
                  let fromConnection: PendingContactConnection = try? decodeObject(fcObj),
                  let tcObj = data["toConnection"],
                  let toConnection: PendingContactConnection = try? decodeObject(tcObj),
                  let nuObj = data["newUser"],
                  let newUser: UserRef = try? decodeObject(nuObj) else { return nil }
            return .connectionUserChanged(user: user, fromConnection: fromConnection, toConnection: toConnection, newUser: newUser)
        case "connectionPlan":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let clObj = data["connLink"],
                  let connLink: CreatedConnLink = try? decodeObject(clObj),
                  let cpObj = data["connectionPlan"],
                  let connectionPlan: ConnectionPlan = try? decodeObject(cpObj) else { return nil }
            return .connectionPlan(user: user, connLink: connLink, connectionPlan: connectionPlan)
        case "newPreparedChat":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let chObj = data["chat"],
                  let chat: ChatData = try? decodeObject(chObj) else { return nil }
            return .newPreparedChat(user: user, chat: chat)
        case "contactUserChanged":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let fcObj = data["fromContact"],
                  let fromContact: Contact = try? decodeObject(fcObj),
                  let nuObj = data["newUser"],
                  let newUser: UserRef = try? decodeObject(nuObj),
                  let tcObj = data["toContact"],
                  let toContact: Contact = try? decodeObject(tcObj) else { return nil }
            return .contactUserChanged(user: user, fromContact: fromContact, newUser: newUser, toContact: toContact)
        case "groupUserChanged":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let fgObj = data["fromGroup"],
                  let fromGroup: GroupInfo = try? decodeObject(fgObj),
                  let nuObj = data["newUser"],
                  let newUser: UserRef = try? decodeObject(nuObj),
                  let tgObj = data["toGroup"],
                  let toGroup: GroupInfo = try? decodeObject(tgObj) else { return nil }
            return .groupUserChanged(user: user, fromGroup: fromGroup, newUser: newUser, toGroup: toGroup)
        case "sentConfirmation":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["connection"],
                  let connection: PendingContactConnection = try? decodeObject(cObj) else { return nil }
            return .sentConfirmation(user: user, connection: connection)
        case "sentInvitation":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["connection"],
                  let connection: PendingContactConnection = try? decodeObject(cObj) else { return nil }
            return .sentInvitation(user: user, connection: connection)
        case "startedConnectionToContact":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj) else { return nil }
            return .startedConnectionToContact(user: user, contact: contact)
        case "startedConnectionToGroup":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let rrData = data["relayResults"] as? [Any],
                  let relayResults = try? rrData.compactMap({ try decodeObject($0) as RelayConnectionResult }) else { return nil }
            return .startedConnectionToGroup(user: user, groupInfo: groupInfo, relayResults: relayResults)
        case "sentInvitationToContact":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj) else { return nil }
            let customUserProfile: Profile? = (data["customUserProfile"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .sentInvitationToContact(user: user, contact: contact, customUserProfile: customUserProfile)
        case "contactAlreadyExists":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj) else { return nil }
            return .contactAlreadyExists(user: user, contact: contact)
        case "contactDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj) else { return nil }
            return .contactDeleted(user: user, contact: contact)
        case "contactConnectionDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["connection"],
                  let connection: PendingContactConnection = try? decodeObject(cObj) else { return nil }
            return .contactConnectionDeleted(user: user, connection: connection)
        case "groupDeletedUser":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let msgSigned = data["msgSigned"] as? Bool else { return nil }
            return .groupDeletedUser(user: user, groupInfo: groupInfo, msgSigned: msgSigned)
        case "itemsReadForChat":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatInfo"],
                  let chatInfo: ChatInfo = try? decodeObject(ciObj) else { return nil }
            return .itemsReadForChat(user: user, chatInfo: chatInfo)
        case "chatCleared":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatInfo"],
                  let chatInfo: ChatInfo = try? decodeObject(ciObj) else { return nil }
            return .chatCleared(user: user, chatInfo: chatInfo)
        case "userProfileNoChange":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj) else { return nil }
            return .userProfileNoChange(user: user)
        case "userProfileUpdated":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj),
                  let fpObj = data["fromProfile"],
                  let fromProfile: Profile = try? decodeObject(fpObj),
                  let tpObj = data["toProfile"],
                  let toProfile: Profile = try? decodeObject(tpObj),
                  let usObj = data["updateSummary"],
                  let updateSummary: UserProfileUpdateSummary = try? decodeObject(usObj) else { return nil }
            return .userProfileUpdated(user: user, fromProfile: fromProfile, toProfile: toProfile, updateSummary: updateSummary)
        case "userPrivacy":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj),
                  let uuObj = data["updatedUser"],
                  let updatedUser: User = try? decodeObject(uuObj) else { return nil }
            return .userPrivacy(user: user, updatedUser: updatedUser)
        case "contactAliasUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["toContact"],
                  let toContact: Contact = try? decodeObject(cObj) else { return nil }
            return .contactAliasUpdated(user: user, toContact: toContact)
        case "groupAliasUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let gObj = data["toGroup"],
                  let toGroup: GroupInfo = try? decodeObject(gObj) else { return nil }
            return .groupAliasUpdated(user: user, toGroup: toGroup)
        case "connectionAliasUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["toConnection"],
                  let toConnection: PendingContactConnection = try? decodeObject(cObj) else { return nil }
            return .connectionAliasUpdated(user: user, toConnection: toConnection)
        case "contactPrefsUpdated":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj),
                  let fcObj = data["fromContact"],
                  let fromContact: Contact = try? decodeObject(fcObj),
                  let tcObj = data["toContact"],
                  let toContact: Contact = try? decodeObject(tcObj) else { return nil }
            return .contactPrefsUpdated(user: user, fromContact: fromContact, toContact: toContact)
        case "userContactLink":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj),
                  let clObj = data["contactLink"],
                  let contactLink: UserContactLink = try? decodeObject(clObj) else { return nil }
            return .userContactLink(user: user, contactLink: contactLink)
        case "userContactLinkUpdated":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj),
                  let clObj = data["contactLink"],
                  let contactLink: UserContactLink = try? decodeObject(clObj) else { return nil }
            return .userContactLinkUpdated(user: user, contactLink: contactLink)
        case "userContactLinkCreated":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj),
                  let clObj = data["connLinkContact"],
                  let connLinkContact: CreatedConnLink = try? decodeObject(clObj) else { return nil }
            let encryptedConnLink: String? = data["encryptedConnLink"] as? String
            return .userContactLinkCreated(user: user, connLinkContact: connLinkContact, encryptedConnLink: encryptedConnLink)
        case "userContactLinkDeleted":
            guard let uObj = data["user"],
                  let user: User = try? decodeObject(uObj) else { return nil }
            return .userContactLinkDeleted(user: user)
        case "acceptingContactRequest":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj) else { return nil }
            return .acceptingContactRequest(user: user, contact: contact)
        case "contactRequestRejected":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let crObj = data["contactRequest"],
                  let contactRequest: UserContactRequest = try? decodeObject(crObj) else { return nil }
            let contact_: Contact? = (data["contact_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .contactRequestRejected(user: user, contactRequest: contactRequest, contact_: contact_)
        case "newChatItems":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let itemsData = data["chatItems"] as? [Any],
                  let chatItems = try? itemsData.compactMap({ try decodeObject($0) as AChatItem }) else { return nil }
            return .newChatItems(user: user, chatItems: chatItems)
        case "chatMsgContent":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let mcObj = data["msgContent"],
                  let msgContent: MsgContent = try? decodeObject(mcObj) else { return nil }
            return .chatMsgContent(user: user, msgContent: msgContent)
        case "groupChatItemsDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let idsData = data["chatItemIDs"] as? [Int64],
                  let byUser = data["byUser"] as? Bool else { return nil }
            let chatItemIDs = Set(idsData)
            let member_: GroupMember? = (data["member_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .groupChatItemsDeleted(user: user, groupInfo: groupInfo, chatItemIDs: chatItemIDs, byUser: byUser, member_: member_)
        case "forwardPlan":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let itemsCount = data["itemsCount"] as? Int,
                  let idsData = data["chatItemIds"] as? [Int64] else { return nil }
            let forwardConfirmation: ForwardConfirmation? = (data["forwardConfirmation"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .forwardPlan(user: user, itemsCount: itemsCount, chatItemIds: idsData, forwardConfirmation: forwardConfirmation)
        case "chatItemUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .chatItemUpdated(user: user, chatItem: chatItem)
        case "chatItemNotChanged":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .chatItemNotChanged(user: user, chatItem: chatItem)
        case "chatItemReaction":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let added = data["added"] as? Bool,
                  let rObj = data["reaction"],
                  let reaction: ACIReaction = try? decodeObject(rObj) else { return nil }
            return .chatItemReaction(user: user, added: added, reaction: reaction)
        case "reactionMembers":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let mrData = data["memberReactions"] as? [Any],
                  let memberReactions = try? mrData.compactMap({ try decodeObject($0) as MemberReaction }) else { return nil }
            return .reactionMembers(user: user, memberReactions: memberReactions)
        case "chatItemsDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let deletionsData = data["chatItemDeletions"] as? [Any],
                  let chatItemDeletions = try? deletionsData.compactMap({ try decodeObject($0) as ChatItemDeletion }),
                  let byUser = data["byUser"] as? Bool,
                  let timed = data["timed"] as? Bool else { return nil }
            return .chatItemsDeleted(user: user, chatItemDeletions: chatItemDeletions, byUser: byUser, timed: timed)
        case "contactsList":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactsData = data["contacts"] as? [Any],
                  let contacts = try? contactsData.compactMap({ try decodeObject($0) as Contact }) else { return nil }
            return .contactsList(user: user, contacts: contacts)
        default:
            return nil
        }
    }

    static let useManualDecoding = true
}

// Spec: spec/api.md#ChatResponse2
enum ChatResponse2: Decodable, ChatAPIResult, @unchecked Sendable {
    // group responses
    case groupCreated(user: UserRef, groupInfo: GroupInfo)
    case publicGroupCreated(user: UserRef, groupInfo: GroupInfo, groupLink: GroupLink, groupRelays: [GroupRelay])
    case publicGroupCreationFailed(user: UserRef, addRelayResults: [AddRelayResult])
    case groupRelays(user: UserRef, groupInfo: GroupInfo, groupRelays: [GroupRelay])
    case relayGroupAllowed(user: UserRef, groupInfo: GroupInfo)
    case groupRelaysAdded(user: UserRef, groupInfo: GroupInfo, groupLink: GroupLink, groupRelays: [GroupRelay])
    case groupRelaysAddFailed(user: UserRef, addRelayResults: [AddRelayResult])
    case sentGroupInvitation(user: UserRef, groupInfo: GroupInfo, contact: Contact, member: GroupMember)
    case userAcceptedGroupSent(user: UserRef, groupInfo: GroupInfo, hostContact: Contact?)
    case userDeletedMembers(user: UserRef, groupInfo: GroupInfo, members: [GroupMember], withMessages: Bool, msgSigned: Bool)
    case leftMemberUser(user: UserRef, groupInfo: GroupInfo)
    case groupMembers(user: UserRef, group: POPOPXSwitch.Group)
    case memberAccepted(user: UserRef, groupInfo: GroupInfo, member: GroupMember)
    case memberSupportChats(user: UserRef, groupInfo: GroupInfo, members: [GroupMember])  // CRMemberSupportChats - list all member support chats
    case memberSupportChatRead(user: UserRef, groupInfo: GroupInfo, member: GroupMember)
    case memberSupportChatDeleted(user: UserRef, groupInfo: GroupInfo, member: GroupMember)
    case membersRoleUser(user: UserRef, groupInfo: GroupInfo, members: [GroupMember], toRole: GroupMemberRole, msgSigned: Bool)
    case membersBlockedForAllUser(user: UserRef, groupInfo: GroupInfo, members: [GroupMember], blocked: Bool, msgSigned: Bool)
    case groupUpdated(user: UserRef, fromGroup: GroupInfo, toGroup: GroupInfo, member_: GroupMember?, msgSigned: Bool)
    case groupLinkCreated(user: UserRef, groupInfo: GroupInfo, groupLink: GroupLink)
    case groupLink(user: UserRef, groupInfo: GroupInfo, groupLink: GroupLink)
    case groupLinkDeleted(user: UserRef, groupInfo: GroupInfo)
    case newMemberContact(user: UserRef, contact: Contact, groupInfo: GroupInfo, member: GroupMember)
    case newMemberContactSentInv(user: UserRef, contact: Contact, groupInfo: GroupInfo, member: GroupMember)
    case memberContactAccepted(user: UserRef, contact: Contact)
    // receiving file responses
    case rcvFileAccepted(user: UserRef, chatItem: AChatItem)
    case rcvFileAcceptedSndCancelled(user: UserRef, rcvFileTransfer: RcvFileTransfer)
    case standaloneFileInfo(fileMeta: MigrationFileLinkData?)
    case rcvStandaloneFileCreated(user: UserRef, rcvFileTransfer: RcvFileTransfer)
    case rcvFileCancelled(user: UserRef, chatItem_: AChatItem?, rcvFileTransfer: RcvFileTransfer)
    // sending file responses
    case sndFileCancelled(user: UserRef, chatItem_: AChatItem?, fileTransferMeta: FileTransferMeta, sndFileTransfers: [SndFileTransfer])
    case sndStandaloneFileCreated(user: UserRef, fileTransferMeta: FileTransferMeta) // returned by _upload
    // call invitations
    case callInvitations(callInvitations: [RcvCallInvitation])
    // notifications
    case ntfTokenStatus(status: NtfTknStatus)
    case ntfToken(token: DeviceToken, status: NtfTknStatus, ntfMode: NotificationsMode, ntfServer: String)
    case ntfConns(ntfConns: [NtfConn])
    case connNtfMessages(receivedMsgs: [RcvNtfMsgInfo])
    // remote desktop responses
    case remoteCtrlList(remoteCtrls: [RemoteCtrlInfo])
    case remoteCtrlConnecting(remoteCtrl_: RemoteCtrlInfo?, ctrlAppInfo: CtrlAppInfo, appVersion: String)
    case remoteCtrlConnected(remoteCtrl: RemoteCtrlInfo, compression: Bool)
    // misc
    case versionInfo(versionInfo: CoreVersionInfo, chatMigrations: [UpMigration], agentMigrations: [UpMigration])
    case cmdOk(user_: UserRef?)
    case agentSubsTotal(user: UserRef, subsTotal: SMPServerSubs, hasSession: Bool)
    case agentServersSummary(user: UserRef, serversSummary: PresentedServersSummary)
    case agentSubsSummary(user: UserRef, subsSummary: SMPServerSubs)
    case archiveExported(archiveErrors: [ArchiveError])
    case archiveImported(archiveErrors: [ArchiveError])
    case appSettings(appSettings: AppSettings)
    // badges
    // the full user, not UserRef: its profile carries the badge that setUserBadge just stored
    case badgeRedeemed(user: User, redeemedBadge: LocalBadge, newBadge: Bool, badgeState: BadgeState?)
    case badgeState(user: UserRef, badgeState: BadgeState?)
    case badgeLedger(user: UserRef, badgeLedger: [StatementEntry])
    // domain verification events
    case contactDomainVerified(user: UserRef, contact: Contact, verificationFailure: String?)
    case groupDomainVerified(user: UserRef, groupInfo: GroupInfo, verificationFailure: String?)

    var responseType: String {
        switch self {
        case .groupCreated: "groupCreated"
        case .publicGroupCreated: "publicGroupCreated"
        case .publicGroupCreationFailed: "publicGroupCreationFailed"
        case .groupRelays: "groupRelays"
        case .groupRelaysAdded: "groupRelaysAdded"
        case .groupRelaysAddFailed: "groupRelaysAddFailed"
        case .sentGroupInvitation: "sentGroupInvitation"
        case .userAcceptedGroupSent: "userAcceptedGroupSent"
        case .userDeletedMembers: "userDeletedMembers"
        case .leftMemberUser: "leftMemberUser"
        case .groupMembers: "groupMembers"
        case .memberAccepted: "memberAccepted"
        case .memberSupportChatRead: "memberSupportChatRead"
        case .memberSupportChatDeleted: "memberSupportChatDeleted"
        case .membersRoleUser: "membersRoleUser"
        case .membersBlockedForAllUser: "membersBlockedForAllUser"
        case .groupUpdated: "groupUpdated"
        case .groupLinkCreated: "groupLinkCreated"
        case .groupLink: "groupLink"
        case .groupLinkDeleted: "groupLinkDeleted"
        case .newMemberContact: "newMemberContact"
        case .newMemberContactSentInv: "newMemberContactSentInv"
        case .memberContactAccepted: "memberContactAccepted"
        case .rcvFileAccepted: "rcvFileAccepted"
        case .rcvFileAcceptedSndCancelled: "rcvFileAcceptedSndCancelled"
        case .standaloneFileInfo: "standaloneFileInfo"
        case .rcvStandaloneFileCreated: "rcvStandaloneFileCreated"
        case .rcvFileCancelled: "rcvFileCancelled"
        case .sndFileCancelled: "sndFileCancelled"
        case .sndStandaloneFileCreated: "sndStandaloneFileCreated"
        case .callInvitations: "callInvitations"
        case .ntfTokenStatus: "ntfTokenStatus"
        case .ntfToken: "ntfToken"
        case .ntfConns: "ntfConns"
        case .connNtfMessages: "connNtfMessages"
        case .remoteCtrlList: "remoteCtrlList"
        case .remoteCtrlConnecting: "remoteCtrlConnecting"
        case .remoteCtrlConnected: "remoteCtrlConnected"
        case .versionInfo: "versionInfo"
        case .cmdOk: "cmdOk"
        case .agentSubsTotal: "agentSubsTotal"
        case .agentServersSummary: "agentServersSummary"
        case .agentSubsSummary: "agentSubsSummary"
        case .archiveExported: "archiveExported"
        case .archiveImported: "archiveImported"
        case .appSettings: "appSettings"
        case .badgeRedeemed: "badgeRedeemed"
        case .badgeState: "badgeState"
        case .badgeLedger: "badgeLedger"
        case .relayGroupAllowed: "relayGroupAllowed"
        case .memberSupportChats: "memberSupportChats"
        case .contactDomainVerified: "contactDomainVerified"
        case .groupDomainVerified: "groupDomainVerified"
        }
    }

    var details: String {
        switch self {
        case let .groupCreated(u, groupInfo): return withUser(u, String(describing: groupInfo))
        case let .publicGroupCreated(u, groupInfo, groupLink, groupRelays): return withUser(u, "groupInfo: \(groupInfo)\ngroupLink: \(groupLink)\ngroupRelays: \(groupRelays)")
        case let .publicGroupCreationFailed(u, addRelayResults): return withUser(u, "addRelayResults: \(addRelayResults)")
        case let .groupRelays(u, groupInfo, groupRelays): return withUser(u, "groupInfo: \(groupInfo)\ngroupRelays: \(groupRelays)")
        case let .relayGroupAllowed(u, groupInfo): return withUser(u, "groupInfo: \(groupInfo)")
        case let .groupRelaysAdded(u, groupInfo, groupLink, groupRelays): return withUser(u, "groupInfo: \(groupInfo)\ngroupLink: \(groupLink)\ngroupRelays: \(groupRelays)")
        case let .groupRelaysAddFailed(u, addRelayResults): return withUser(u, "addRelayResults: \(addRelayResults)")
        case let .sentGroupInvitation(u, groupInfo, contact, member): return withUser(u, "groupInfo: \(groupInfo)\ncontact: \(contact)\nmember: \(member)")
        case let .userAcceptedGroupSent(u, groupInfo, hostContact): return withUser(u, "groupInfo: \(groupInfo)\nhostContact: \(String(describing: hostContact))")
        case let .userDeletedMembers(u, groupInfo, members, withMessages, _): return withUser(u, "groupInfo: \(groupInfo)\nmembers: \(members)\nwithMessages: \(withMessages)")
        case let .leftMemberUser(u, groupInfo): return withUser(u, String(describing: groupInfo))
        case let .groupMembers(u, group): return withUser(u, String(describing: group))
        case let .memberAccepted(u, groupInfo, member): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)")
        case let .memberSupportChats(u, groupInfo, members): return withUser(u, "groupInfo: \(groupInfo)\nmembers: \(members.count)")
        case let .memberSupportChatRead(u, groupInfo, member): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)")
        case let .memberSupportChatDeleted(u, groupInfo, member): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)")
        case let .membersRoleUser(u, groupInfo, members, toRole, _): return withUser(u, "groupInfo: \(groupInfo)\nmembers: \(members)\ntoRole: \(toRole)")
        case let .membersBlockedForAllUser(u, groupInfo, members, blocked, _): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(members)\nblocked: \(blocked)")
        case let .groupUpdated(u, _, toGroup, _, _): return withUser(u, String(describing: toGroup))
        case let .groupLinkCreated(u, groupInfo, groupLink): return withUser(u, "groupInfo: \(groupInfo)\ngroupLink: \(groupLink)")
        case let .groupLink(u, groupInfo, groupLink): return withUser(u, "groupInfo: \(groupInfo)\ngroupLink: \(groupLink)")
        case let .groupLinkDeleted(u, groupInfo): return withUser(u, String(describing: groupInfo))
        case let .newMemberContact(u, contact, groupInfo, member): return withUser(u, "contact: \(contact)\ngroupInfo: \(groupInfo)\nmember: \(member)")
        case let .newMemberContactSentInv(u, contact, groupInfo, member): return withUser(u, "contact: \(contact)\ngroupInfo: \(groupInfo)\nmember: \(member)")
        case let .memberContactAccepted(u, contact): return withUser(u, "contact: \(contact)")
        case let .rcvFileAccepted(u, chatItem): return withUser(u, String(describing: chatItem))
        case .rcvFileAcceptedSndCancelled: return noDetails
        case let .standaloneFileInfo(fileMeta): return String(describing: fileMeta)
        case .rcvStandaloneFileCreated: return noDetails
        case let .rcvFileCancelled(u, chatItem, _): return withUser(u, String(describing: chatItem))
        case let .sndFileCancelled(u, chatItem, _, _): return withUser(u, String(describing: chatItem))
        case .sndStandaloneFileCreated: return noDetails
        case let .callInvitations(invs): return String(describing: invs)
        case let .ntfTokenStatus(status): return String(describing: status)
        case let .ntfToken(token, status, ntfMode, ntfServer): return "token: \(token)\nstatus: \(status.rawValue)\nntfMode: \(ntfMode.rawValue)\nntfServer: \(ntfServer)"
        case let .ntfConns(ntfConns): return String(describing: ntfConns)
        case let .connNtfMessages(receivedMsgs): return "receivedMsgs: \(String(describing: receivedMsgs))"
        case let .remoteCtrlList(remoteCtrls): return String(describing: remoteCtrls)
        case let .remoteCtrlConnecting(remoteCtrl_, ctrlAppInfo, appVersion): return "remoteCtrl_:\n\(String(describing: remoteCtrl_))\nctrlAppInfo:\n\(String(describing: ctrlAppInfo))\nappVersion: \(appVersion)"
        case let .remoteCtrlConnected(remoteCtrl, compression): return "\(String(describing: remoteCtrl))\ncompression: \(compression)"
        case let .versionInfo(versionInfo, chatMigrations, agentMigrations): return "\(String(describing: versionInfo))\n\nchat migrations: \(chatMigrations.map(\.upName))\n\nagent migrations: \(agentMigrations.map(\.upName))"
        case .cmdOk: return noDetails
        case let .agentSubsTotal(u, subsTotal, hasSession): return withUser(u, "subsTotal: \(String(describing: subsTotal))\nhasSession: \(hasSession)")
        case let .agentServersSummary(u, serversSummary): return withUser(u, String(describing: serversSummary))
        case let .agentSubsSummary(u, subsSummary): return withUser(u, String(describing: subsSummary))
        case let .archiveExported(archiveErrors): return String(describing: archiveErrors)
        case let .archiveImported(archiveErrors): return String(describing: archiveErrors)
        case let .appSettings(appSettings): return String(describing: appSettings)
        case let .badgeRedeemed(u, redeemedBadge, newBadge, badgeState): return withUser(u, "redeemedBadge: \(String(describing: redeemedBadge))\nnewBadge: \(newBadge)\nbadgeState: \(String(describing: badgeState))")
        case let .badgeState(u, badgeState): return withUser(u, String(describing: badgeState))
        case let .badgeLedger(u, badgeLedger): return withUser(u, String(describing: badgeLedger))
        case let .contactDomainVerified(u, contact, verificationFailure): return withUser(u, "contact: \(String(describing: contact))\nverificationFailure: \(String(describing: verificationFailure))")
        case let .groupDomainVerified(u, groupInfo, verificationFailure): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nverificationFailure: \(String(describing: verificationFailure))")
        }
    }

    static func fallbackResult(_ type: String, _ json: NSDictionary) -> ChatResponse2? {
        let data = json[type] as? NSDictionary ?? json
        switch type {
        case "cmdOk":
            let user: UserRef? = (data["user_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .cmdOk(user_: user)
        case "groupCreated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            return .groupCreated(user: user, groupInfo: groupInfo)
        case "publicGroupCreated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let glObj = data["groupLink"],
                  let groupLink: GroupLink = try? decodeObject(glObj),
                  let groupRelays = data["groupRelays"] as? [Any],
                  let relays = try? groupRelays.map({ try decodeObject($0) as GroupRelay }) else { return nil }
            return .publicGroupCreated(user: user, groupInfo: groupInfo, groupLink: groupLink, groupRelays: relays)
        case "versionInfo":
            guard let viObj = data["versionInfo"],
                  let versionInfo: CoreVersionInfo = try? decodeObject(viObj),
                  let chatMigrations = data["chatMigrations"] as? [Any],
                  let agentMigrations = data["agentMigrations"] as? [Any],
                  let chatMigs = try? chatMigrations.map({ try decodeObject($0) as UpMigration }),
                  let agentMigs = try? agentMigrations.map({ try decodeObject($0) as UpMigration }) else { return nil }
            return .versionInfo(versionInfo: versionInfo, chatMigrations: chatMigs, agentMigrations: agentMigs)
        case "appSettings":
            guard let asObj = data["appSettings"],
                  let appSettings: AppSettings = try? decodeObject(asObj) else { return nil }
            return .appSettings(appSettings: appSettings)
        case "ntfTokenStatus":
            guard let stObj = data["status"],
                  let status: NtfTknStatus = decodeRaw(stObj) else { return nil }
            return .ntfTokenStatus(status: status)
        case "contactDomainVerified":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            let verificationFailure: String? = data["verificationFailure"] as? String
            return .contactDomainVerified(user: user, contact: contact, verificationFailure: verificationFailure)
        case "groupDomainVerified":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            let verificationFailure: String? = data["verificationFailure"] as? String
            return .groupDomainVerified(user: user, groupInfo: groupInfo, verificationFailure: verificationFailure)
        case "relayGroupAllowed":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            return .relayGroupAllowed(user: user, groupInfo: groupInfo)
        case "memberSupportChats":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let membersData = data["members"] as? [Any],
                  let members = try? membersData.compactMap({ try decodeObject($0) as GroupMember }) else { return nil }
            return .memberSupportChats(user: user, groupInfo: groupInfo, members: members)
        case "publicGroupCreationFailed":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let resultsData = data["addRelayResults"] as? [Any],
                  let addRelayResults = try? resultsData.compactMap({ try decodeObject($0) as AddRelayResult }) else { return nil }
            return .publicGroupCreationFailed(user: user, addRelayResults: addRelayResults)
        case "groupRelays":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let relaysData = data["groupRelays"] as? [Any],
                  let groupRelays = try? relaysData.compactMap({ try decodeObject($0) as GroupRelay }) else { return nil }
            return .groupRelays(user: user, groupInfo: groupInfo, groupRelays: groupRelays)
        case "groupRelaysAdded":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let glObj = data["groupLink"],
                  let groupLink: GroupLink = try? decodeObject(glObj),
                  let relaysData = data["groupRelays"] as? [Any],
                  let groupRelays = try? relaysData.compactMap({ try decodeObject($0) as GroupRelay }) else { return nil }
            return .groupRelaysAdded(user: user, groupInfo: groupInfo, groupLink: groupLink, groupRelays: groupRelays)
        case "groupRelaysAddFailed":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let resultsData = data["addRelayResults"] as? [Any],
                  let addRelayResults = try? resultsData.compactMap({ try decodeObject($0) as AddRelayResult }) else { return nil }
            return .groupRelaysAddFailed(user: user, addRelayResults: addRelayResults)
        case "sentGroupInvitation":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj),
                  let mObj = data["member"],
                  let member: GroupMember = try? decodeObject(mObj) else { return nil }
            return .sentGroupInvitation(user: user, groupInfo: groupInfo, contact: contact, member: member)
        case "userAcceptedGroupSent":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            let hostContact: Contact? = (data["hostContact"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .userAcceptedGroupSent(user: user, groupInfo: groupInfo, hostContact: hostContact)
        case "userDeletedMembers":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let membersData = data["members"] as? [Any],
                  let members = try? membersData.compactMap({ try decodeObject($0) as GroupMember }),
                  let withMessages = data["withMessages"] as? Bool,
                  let msgSigned = data["msgSigned"] as? Bool else { return nil }
            return .userDeletedMembers(user: user, groupInfo: groupInfo, members: members, withMessages: withMessages, msgSigned: msgSigned)
        case "leftMemberUser":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            return .leftMemberUser(user: user, groupInfo: groupInfo)
        case "groupMembers":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let gObj = data["group"],
                  let group: POPOPXSwitch.Group = try? decodeObject(gObj) else { return nil }
            return .groupMembers(user: user, group: group)
        case "memberAccepted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let mObj = data["member"],
                  let member: GroupMember = try? decodeObject(mObj) else { return nil }
            return .memberAccepted(user: user, groupInfo: groupInfo, member: member)
        case "memberSupportChatRead":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let mObj = data["member"],
                  let member: GroupMember = try? decodeObject(mObj) else { return nil }
            return .memberSupportChatRead(user: user, groupInfo: groupInfo, member: member)
        case "memberSupportChatDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let mObj = data["member"],
                  let member: GroupMember = try? decodeObject(mObj) else { return nil }
            return .memberSupportChatDeleted(user: user, groupInfo: groupInfo, member: member)
        case "membersRoleUser":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let membersData = data["members"] as? [Any],
                  let members = try? membersData.compactMap({ try decodeObject($0) as GroupMember }),
                  let toRoleRaw = data["toRole"],
                  let toRole: GroupMemberRole = decodeRaw(toRoleRaw),
                  let msgSigned = data["msgSigned"] as? Bool else { return nil }
            return .membersRoleUser(user: user, groupInfo: groupInfo, members: members, toRole: toRole, msgSigned: msgSigned)
        case "membersBlockedForAllUser":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let membersData = data["members"] as? [Any],
                  let members = try? membersData.compactMap({ try decodeObject($0) as GroupMember }),
                  let blocked = data["blocked"] as? Bool,
                  let msgSigned = data["msgSigned"] as? Bool else { return nil }
            return .membersBlockedForAllUser(user: user, groupInfo: groupInfo, members: members, blocked: blocked, msgSigned: msgSigned)
        case "groupUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let fgObj = data["fromGroup"],
                  let fromGroup: GroupInfo = try? decodeObject(fgObj),
                  let tgObj = data["toGroup"],
                  let toGroup: GroupInfo = try? decodeObject(tgObj),
                  let msgSigned = data["msgSigned"] as? Bool else { return nil }
            let member_: GroupMember? = (data["member_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .groupUpdated(user: user, fromGroup: fromGroup, toGroup: toGroup, member_: member_, msgSigned: msgSigned)
        case "groupLinkCreated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let glObj = data["groupLink"],
                  let groupLink: GroupLink = try? decodeObject(glObj) else { return nil }
            return .groupLinkCreated(user: user, groupInfo: groupInfo, groupLink: groupLink)
        case "groupLink":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let glObj = data["groupLink"],
                  let groupLink: GroupLink = try? decodeObject(glObj) else { return nil }
            return .groupLink(user: user, groupInfo: groupInfo, groupLink: groupLink)
        case "groupLinkDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            return .groupLinkDeleted(user: user, groupInfo: groupInfo)
        case "newMemberContact":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let mObj = data["member"],
                  let member: GroupMember = try? decodeObject(mObj) else { return nil }
            return .newMemberContact(user: user, contact: contact, groupInfo: groupInfo, member: member)
        case "newMemberContactSentInv":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let mObj = data["member"],
                  let member: GroupMember = try? decodeObject(mObj) else { return nil }
            return .newMemberContactSentInv(user: user, contact: contact, groupInfo: groupInfo, member: member)
        case "memberContactAccepted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let cObj = data["contact"],
                  let contact: Contact = try? decodeObject(cObj) else { return nil }
            return .memberContactAccepted(user: user, contact: contact)
        case "rcvFileAccepted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .rcvFileAccepted(user: user, chatItem: chatItem)
        case "rcvFileAcceptedSndCancelled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(ftObj) else { return nil }
            return .rcvFileAcceptedSndCancelled(user: user, rcvFileTransfer: rcvFileTransfer)
        case "standaloneFileInfo":
            let fileMeta: MigrationFileLinkData? = (data["fileMeta"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .standaloneFileInfo(fileMeta: fileMeta)
        case "rcvStandaloneFileCreated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(ftObj) else { return nil }
            return .rcvStandaloneFileCreated(user: user, rcvFileTransfer: rcvFileTransfer)
        case "rcvFileCancelled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(ftObj) else { return nil }
            let chatItem_: AChatItem? = (data["chatItem_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .rcvFileCancelled(user: user, chatItem_: chatItem_, rcvFileTransfer: rcvFileTransfer)
        case "sndFileCancelled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj),
                  let sndData = data["sndFileTransfers"] as? [Any],
                  let sndFileTransfers = try? sndData.compactMap({ try decodeObject($0) as SndFileTransfer }) else { return nil }
            let chatItem_: AChatItem? = (data["chatItem_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .sndFileCancelled(user: user, chatItem_: chatItem_, fileTransferMeta: fileTransferMeta, sndFileTransfers: sndFileTransfers)
        case "sndStandaloneFileCreated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj) else { return nil }
            return .sndStandaloneFileCreated(user: user, fileTransferMeta: fileTransferMeta)
        case "callInvitations":
            guard let invsData = data["callInvitations"] as? [Any],
                  let callInvitations = try? invsData.compactMap({ try decodeObject($0) as RcvCallInvitation }) else { return nil }
            return .callInvitations(callInvitations: callInvitations)
        case "ntfToken":
            // Fields are at top level of data (not nested under "ntfToken")
            guard let tObj = data["token"] else {
                logger.error("ntfToken: missing token field")
                return nil
            }
            guard let token: DeviceToken = try? decodeObject(tObj) else {
                logger.error("ntfToken: failed to decode DeviceToken from \(String(describing: tObj))")
                return nil
            }
            guard let stObj = data["status"] else {
                logger.error("ntfToken: missing status field")
                return nil
            }
            guard let status: NtfTknStatus = decodeRaw(stObj) else {
                logger.error("ntfToken: failed to decode NtfTknStatus from \(String(describing: stObj))")
                return nil
            }
            guard let nmObj = data["ntfMode"] else {
                logger.error("ntfToken: missing ntfMode field")
                return nil
            }
            guard let ntfMode: NotificationsMode = decodeRaw(nmObj) else {
                logger.error("ntfToken: failed to decode NotificationsMode from \(String(describing: nmObj))")
                return nil
            }
            guard let ntfServer = data["ntfServer"] as? String else {
                logger.error("ntfToken: missing or invalid ntfServer field: \(String(describing: data["ntfServer"]))")
                return nil
            }
            return .ntfToken(token: token, status: status, ntfMode: ntfMode, ntfServer: ntfServer)
        case "ntfConns":
            guard let connsData = data["ntfConns"] as? [Any],
                  let ntfConns = try? connsData.compactMap({ try decodeObject($0) as NtfConn }) else { return nil }
            return .ntfConns(ntfConns: ntfConns)
        case "connNtfMessages":
            guard let msgsData = data["receivedMsgs"] as? [Any],
                  let receivedMsgs = try? msgsData.compactMap({ try decodeObject($0) as RcvNtfMsgInfo }) else { return nil }
            return .connNtfMessages(receivedMsgs: receivedMsgs)
        case "remoteCtrlList":
            guard let rcsData = data["remoteCtrls"] as? [Any],
                  let remoteCtrls = try? rcsData.compactMap({ try decodeObject($0) as RemoteCtrlInfo }) else { return nil }
            return .remoteCtrlList(remoteCtrls: remoteCtrls)
        case "remoteCtrlConnecting":
            guard let caiObj = data["ctrlAppInfo"],
                  let ctrlAppInfo: CtrlAppInfo = try? decodeObject(caiObj),
                  let appVersion = data["appVersion"] as? String else { return nil }
            let remoteCtrl_: RemoteCtrlInfo? = (data["remoteCtrl_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .remoteCtrlConnecting(remoteCtrl_: remoteCtrl_, ctrlAppInfo: ctrlAppInfo, appVersion: appVersion)
        case "remoteCtrlConnected":
            guard let rcObj = data["remoteCtrl"],
                  let remoteCtrl: RemoteCtrlInfo = try? decodeObject(rcObj) else { return nil }
            let compression = data["compression"] as? Bool ?? false
            return .remoteCtrlConnected(remoteCtrl: remoteCtrl, compression: compression)
        case "agentSubsTotal":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let stObj = data["subsTotal"],
                  let subsTotal: SMPServerSubs = try? decodeObject(stObj),
                  let hasSession = data["hasSession"] as? Bool else { return nil }
            return .agentSubsTotal(user: user, subsTotal: subsTotal, hasSession: hasSession)
        case "agentServersSummary":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ssObj = data["serversSummary"],
                  let serversSummary: PresentedServersSummary = try? decodeObject(ssObj) else { return nil }
            return .agentServersSummary(user: user, serversSummary: serversSummary)
        case "agentSubsSummary":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ssObj = data["subsSummary"],
                  let subsSummary: SMPServerSubs = try? decodeObject(ssObj) else { return nil }
            return .agentSubsSummary(user: user, subsSummary: subsSummary)
        case "archiveExported":
            guard let errorsData = data["archiveErrors"] as? [Any],
                  let archiveErrors = try? errorsData.compactMap({ try decodeObject($0) as ArchiveError }) else { return nil }
            return .archiveExported(archiveErrors: archiveErrors)
        case "archiveImported":
            guard let errorsData = data["archiveErrors"] as? [Any],
                  let archiveErrors = try? errorsData.compactMap({ try decodeObject($0) as ArchiveError }) else { return nil }
            return .archiveImported(archiveErrors: archiveErrors)
        default:
            return nil
        }
    }

    static let useManualDecoding = true
}

// Placeholder types for ChatEvent cases
struct ServiceSubEvent: Decodable, Equatable {}
struct DatabaseDiff: Decodable, Equatable {}
struct DeletedRcvQueue: Decodable, Equatable {}
struct RcvFileDescr: Decodable, Equatable {}
enum TerminalEvent: Decodable, Equatable {
    case unknown
}

// Spec: spec/api.md#ChatEvent
enum ChatEvent: ChatAPIResult, @unchecked Sendable {
    case chatSuspended
    case contactSwitch(user: UserRef, contact: Contact, switchProgress: SwitchProgress)
    case groupMemberSwitch(user: UserRef, groupInfo: GroupInfo, member: GroupMember, switchProgress: SwitchProgress)
    case contactRatchetSync(user: UserRef, contact: Contact, ratchetSyncProgress: RatchetSyncProgress)
    case groupMemberRatchetSync(user: UserRef, groupInfo: GroupInfo, member: GroupMember, ratchetSyncProgress: RatchetSyncProgress)
    case contactDeletedByContact(user: UserRef, contact: Contact)
    case contactConnected(user: UserRef, contact: Contact, userCustomProfile: Profile?)
    case contactConnecting(user: UserRef, contact: Contact)
    case contactSndReady(user: UserRef, contact: Contact)
    case receivedContactRequest(user: UserRef, contactRequest: UserContactRequest, chat_: ChatData?)
    case contactUpdated(user: UserRef, fromContact: Contact, toContact: Contact)
    case groupMemberUpdated(user: UserRef, groupInfo: GroupInfo, fromMember: GroupMember, toMember: GroupMember)
    case subscriptionStatus(server: String, subscriptionStatus: SubscriptionStatus, connections: [String])
    case chatInfoUpdated(user: UserRef, chatInfo: ChatInfo)
    case newChatItems(user: UserRef, chatItems: [AChatItem])
    case chatItemsStatusesUpdated(user: UserRef, chatItems: [AChatItem])
    case chatItemUpdated(user: UserRef, chatItem: AChatItem)
    case chatItemReaction(user: UserRef, added: Bool, reaction: ACIReaction)
    case chatItemsDeleted(user: UserRef, chatItemDeletions: [ChatItemDeletion], byUser: Bool, timed: Bool)
    // group events
    case groupChatItemsDeleted(user: UserRef, groupInfo: GroupInfo, chatItemIDs: Set<Int64>, byUser: Bool, member_: GroupMember?)
    case receivedGroupInvitation(user: UserRef, groupInfo: GroupInfo, contact: Contact, fromMemberRole: GroupMemberRole, memberRole: GroupMemberRole)
    case receivedGroupInvitationViaGroup(user: UserRef, groupInfo: GroupInfo, viaGroupInfo: GroupInfo, viaMember: GroupMember, memberRole: GroupMemberRole)
    case userAcceptedGroupSent(user: UserRef, groupInfo: GroupInfo, hostContact: Contact?)
    case groupLinkConnecting(user: UserRef, groupInfo: GroupInfo, hostMember: GroupMember)
    case businessLinkConnecting(user: UserRef, groupInfo: GroupInfo, hostMember: GroupMember, fromContact: Contact)
    case joinedGroupMemberConnecting(user: UserRef, groupInfo: GroupInfo, hostMember: GroupMember, member: GroupMember)
    case memberAcceptedByOther(user: UserRef, groupInfo: GroupInfo, acceptingMember: GroupMember, member: GroupMember)
    case memberRole(user: UserRef, groupInfo: GroupInfo, byMember: GroupMember, member: GroupMember, fromRole: GroupMemberRole, toRole: GroupMemberRole, msgSigned: MsgSigStatus?)
    case memberBlockedForAll(user: UserRef, groupInfo: GroupInfo, byMember: GroupMember, member: GroupMember, blocked: Bool, msgSigned: MsgSigStatus?)
    case deletedMemberUser(user: UserRef, groupInfo: GroupInfo, member: GroupMember, withMessages: Bool, msgSigned: MsgSigStatus?)
    case deletedMember(user: UserRef, groupInfo: GroupInfo, byMember: GroupMember, deletedMember: GroupMember, withMessages: Bool, msgSigned: MsgSigStatus?)
    case leftMember(user: UserRef, groupInfo: GroupInfo, member: GroupMember, msgSigned: MsgSigStatus?)
    case groupDeleted(user: UserRef, groupInfo: GroupInfo, member: GroupMember, msgSigned: MsgSigStatus?)
    case userJoinedGroup(user: UserRef, groupInfo: GroupInfo, hostMember: GroupMember)
    case joinedGroupMember(user: UserRef, groupInfo: GroupInfo, member: GroupMember)
    case connectedToGroupMember(user: UserRef, groupInfo: GroupInfo, member: GroupMember, memberContact: Contact?)
    case groupUpdated(user: UserRef, fromGroup: GroupInfo, toGroup: GroupInfo, member_: GroupMember?, msgSigned: MsgSigStatus?)
    case groupLinkDataUpdated(user: UserRef, groupInfo: GroupInfo, groupLink: GroupLink, groupRelays: [GroupRelay], relaysChanged: Bool)
    case groupRelayUpdated(user: UserRef, groupInfo: GroupInfo, member: GroupMember, groupRelay: GroupRelay)
    case newMemberContactReceivedInv(user: UserRef, contact: Contact, groupInfo: GroupInfo, member: GroupMember)
    // receiving file events
    case rcvFileAccepted(user: UserRef, chatItem: AChatItem)
    case rcvFileAcceptedSndCancelled(user: UserRef, rcvFileTransfer: RcvFileTransfer)
    case rcvFileStart(user: UserRef, chatItem: AChatItem) // send by chats
    case rcvFileProgressXFTP(user: UserRef, chatItem_: AChatItem?, receivedSize: Int64, totalSize: Int64, rcvFileTransfer: RcvFileTransfer)
    case rcvFileComplete(user: UserRef, chatItem: AChatItem)
    case rcvStandaloneFileComplete(user: UserRef, targetPath: String, rcvFileTransfer: RcvFileTransfer)
    case rcvFileSndCancelled(user: UserRef, chatItem: AChatItem, rcvFileTransfer: RcvFileTransfer)
    case rcvFileError(user: UserRef, chatItem_: AChatItem?, agentError: AgentErrorType, rcvFileTransfer: RcvFileTransfer)
    case rcvFileWarning(user: UserRef, chatItem_: AChatItem?, agentError: AgentErrorType, rcvFileTransfer: RcvFileTransfer)
    // sending file events
    case sndFileStart(user: UserRef, chatItem: AChatItem, sndFileTransfer: SndFileTransfer)
    case sndFileComplete(user: UserRef, chatItem: AChatItem, sndFileTransfer: SndFileTransfer)
    case sndFileRcvCancelled(user: UserRef, chatItem_: AChatItem?, sndFileTransfer: SndFileTransfer)
    case sndFileProgressXFTP(user: UserRef, chatItem_: AChatItem?, fileTransferMeta: FileTransferMeta, sentSize: Int64, totalSize: Int64)
    case sndFileRedirectStartXFTP(user: UserRef, fileTransferMeta: FileTransferMeta, redirectMeta: FileTransferMeta)
    case sndFileCompleteXFTP(user: UserRef, chatItem: AChatItem, fileTransferMeta: FileTransferMeta)
    case sndStandaloneFileComplete(user: UserRef, fileTransferMeta: FileTransferMeta, rcvURIs: [String])
    case sndFileError(user: UserRef, chatItem_: AChatItem?, fileTransferMeta: FileTransferMeta, errorMessage: String)
    case sndFileWarning(user: UserRef, chatItem_: AChatItem?, fileTransferMeta: FileTransferMeta, errorMessage: String)
    // call events
    case callInvitation(callInvitation: RcvCallInvitation)
    case callOffer(user: UserRef, contact: Contact, callType: CallType, offer: WebRTCSession, sharedKey: String?, askConfirmation: Bool)
    case callAnswer(user: UserRef, contact: Contact, answer: WebRTCSession)
    case callExtraInfo(user: UserRef, contact: Contact, extraInfo: WebRTCExtraInfo)
    case callEnded(user: UserRef, contact: Contact)
    case contactDisabled(user: UserRef, contact: Contact)
    // notification marker
    case ntfMessage(user: UserRef, connEntity: ConnectionEntity, ntfMessage: NtfMsgAckInfo)
    // host connection events
    case hostConnected(protocol: String, transportHost: String)
    case hostDisconnected(protocol: String, transportHost: String)
    // remote desktop responses
    case remoteCtrlFound(remoteCtrl: RemoteCtrlInfo, ctrlAppInfo_: CtrlAppInfo?, appVersion: String, compatible: Bool)
    case remoteCtrlSessionCode(remoteCtrl_: RemoteCtrlInfo?, sessionCode: String)
    case remoteCtrlConnected(remoteCtrl: RemoteCtrlInfo)
    case remoteCtrlStopped(remoteCtrl_: RemoteCtrlInfo?, rcsState: RemoteCtrlSessionState, rcStopReason: RemoteCtrlStopReason)
    // pq
    case contactPQEnabled(user: UserRef, contact: Contact, pqEnabled: Bool)
    // badges
    case badgeChanged(user: User, badgeState: BadgeState?)
    case badgeAlert(user: UserRef, badgeAlert: BadgeAlert)
    case storePurchaseCredited(user: UserRef, invoiceId: String)
    case storePurchaseRefused(user: UserRef, invoiceId: String, refusal: BadgeIssueFailure)
    // remote host events
    case remoteHostSessionCode(remoteHost_: RemoteHostInfo?, sessionCode: String)
    case newRemoteHost(remoteHost: RemoteHostInfo)
    case remoteHostConnected(remoteHost: RemoteHostInfo, compression: Bool)
    case remoteHostStopped(remoteHostId_: Int64?, rhsState: RemoteHostSessionState, rhStopReason: RemoteHostStopReason)
    case duplicateGroupMessage(user: UserRef, member: GroupMember)
    // additional events to match Haskell ChatEvent
    case contactAnotherClient(user: UserRef, contact: Contact)
    case connectionsDiff(userIds: DatabaseDiff, connIds: DatabaseDiff)
    case subscriptionEnd(user: UserRef, connectionEntity: ConnectionEntity)
    case serviceSubStatus(server: String, serviceSubEvent: ServiceSubEvent)
    case chatItemNotChanged(user: UserRef, chatItem: AChatItem)
    case chatItemDeletedNotFound(user: UserRef, contact: Contact, sharedMsgId: String)
    case serviceRequest(user: UserRef, requestId: String, signerKey: String?, requestData: [String: String])
    case serviceReplySent(connectionId: String)
    case contactRequestRejected(user: UserRef, contact: Contact, rejectionReason: String?)
    case acceptingContactRequest(user: UserRef, contact: Contact)
    case acceptingBusinessRequest(user: UserRef, groupInfo: GroupInfo)
    case contactRequestAlreadyAccepted(user: UserRef, contact: Contact)
    case businessRequestAlreadyAccepted(user: UserRef, groupInfo: GroupInfo)
    case rcvFileDescrReady(user: UserRef, chatItem: AChatItem, rcvFileTransfer: RcvFileTransfer, rcvFileDescr: RcvFileDescr)
    case contactAndMemberAssociated(user: UserRef, contact: Contact, groupInfo: GroupInfo, member: GroupMember, updatedContact: Contact)
    case unknownMemberCreated(user: UserRef, groupInfo: GroupInfo, forwardedByMember: GroupMember, member: GroupMember)
    case unknownMemberBlocked(user: UserRef, groupInfo: GroupInfo, blockedByMember: GroupMember, member: GroupMember)
    case unknownMemberAnnounced(user: UserRef, groupInfo: GroupInfo, announcingMember: GroupMember, unknownMember: GroupMember, announcedMember: GroupMember)
    case acceptingGroupJoinRequestMember(user: UserRef, groupInfo: GroupInfo, member: GroupMember)
    case noMemberContactCreating(user: UserRef, groupInfo: GroupInfo, member: GroupMember)
    case connectionDisabled(connectionEntity: ConnectionEntity)
    case connectionInactive(connectionEntity: ConnectionEntity, inactive: Bool)
    case agentRcvQueuesDeleted(deletedRcvQueues: [DeletedRcvQueue])
    case agentConnsDeleted(agentConnIds: [String])
    case agentUserDeleted(agentUserId: Int64)
    case messageError(user: UserRef, severity: String, errorMessage: String)
    case chatErrors(chatErrors: [ChatError])
    case timedAction(action: String, durationMilliseconds: Int64)
    case terminalEvent(terminalEvent: TerminalEvent)
    case customChatEvent(user_: UserRef?, response: String)

    static let useManualDecoding = true

    var responseType: String {
        switch self {
        case .chatSuspended: "chatSuspended"
        case .contactSwitch: "contactSwitch"
        case .groupMemberSwitch: "groupMemberSwitch"
        case .contactRatchetSync: "contactRatchetSync"
        case .groupMemberRatchetSync: "groupMemberRatchetSync"
        case .contactDeletedByContact: "contactDeletedByContact"
        case .contactConnected: "contactConnected"
        case .contactConnecting: "contactConnecting"
        case .contactSndReady: "contactSndReady"
        case .receivedContactRequest: "receivedContactRequest"
        case .contactUpdated: "contactUpdated"
        case .groupMemberUpdated: "groupMemberUpdated"
        case .subscriptionStatus: "subscriptionStatus"
        case .chatInfoUpdated: "chatInfoUpdated"
        case .newChatItems: "newChatItems"
        case .chatItemsStatusesUpdated: "chatItemsStatusesUpdated"
        case .chatItemUpdated: "chatItemUpdated"
        case .chatItemReaction: "chatItemReaction"
        case .chatItemsDeleted: "chatItemsDeleted"
        case .groupChatItemsDeleted: "groupChatItemsDeleted"
        case .receivedGroupInvitation: "receivedGroupInvitation"
        case .receivedGroupInvitationViaGroup: "receivedGroupInvitationViaGroup"
        case .userAcceptedGroupSent: "userAcceptedGroupSent"
        case .groupLinkConnecting: "groupLinkConnecting"
        case .businessLinkConnecting: "businessLinkConnecting"
        case .joinedGroupMemberConnecting: "joinedGroupMemberConnecting"
        case .memberAcceptedByOther: "memberAcceptedByOther"
        case .memberRole: "memberRole"
        case .memberBlockedForAll: "memberBlockedForAll"
        case .deletedMemberUser: "deletedMemberUser"
        case .deletedMember: "deletedMember"
        case .leftMember: "leftMember"
        case .groupDeleted: "groupDeleted"
        case .userJoinedGroup: "userJoinedGroup"
        case .joinedGroupMember: "joinedGroupMember"
        case .connectedToGroupMember: "connectedToGroupMember"
        case .groupUpdated: "groupUpdated"
        case .groupLinkDataUpdated: "groupLinkDataUpdated"
        case .groupRelayUpdated: "groupRelayUpdated"
        case .newMemberContactReceivedInv: "newMemberContactReceivedInv"
        case .rcvFileAccepted: "rcvFileAccepted"
        case .rcvFileAcceptedSndCancelled: "rcvFileAcceptedSndCancelled"
        case .rcvFileStart: "rcvFileStart"
        case .rcvFileProgressXFTP: "rcvFileProgressXFTP"
        case .rcvFileComplete: "rcvFileComplete"
        case .rcvStandaloneFileComplete: "rcvStandaloneFileComplete"
        case .rcvFileSndCancelled: "rcvFileSndCancelled"
        case .rcvFileError: "rcvFileError"
        case .rcvFileWarning: "rcvFileWarning"
        case .sndFileStart: "sndFileStart"
        case .sndFileComplete: "sndFileComplete"
        case .sndFileRcvCancelled: "sndFileRcvCancelled"
        case .sndFileProgressXFTP: "sndFileProgressXFTP"
        case .sndFileRedirectStartXFTP: "sndFileRedirectStartXFTP"
        case .sndFileCompleteXFTP: "sndFileCompleteXFTP"
        case .sndStandaloneFileComplete: "sndStandaloneFileComplete"
        case .sndFileError: "sndFileError"
        case .sndFileWarning: "sndFileWarning"
        case .callInvitation: "callInvitation"
        case .callOffer: "callOffer"
        case .callAnswer: "callAnswer"
        case .callExtraInfo: "callExtraInfo"
        case .callEnded: "callEnded"
        case .contactDisabled: "contactDisabled"
        case .ntfMessage: "ntfMessage"
        case .hostConnected: "hostConnected"
        case .hostDisconnected: "hostDisconnected"
        case .remoteCtrlFound: "remoteCtrlFound"
        case .remoteCtrlSessionCode: "remoteCtrlSessionCode"
        case .remoteCtrlConnected: "remoteCtrlConnected"
        case .remoteCtrlStopped: "remoteCtrlStopped"
        case .contactPQEnabled: "contactPQEnabled"
        case .badgeChanged: "badgeChanged"
        case .badgeAlert: "badgeAlert"
        case .storePurchaseCredited: "storePurchaseCredited"
        case .storePurchaseRefused: "storePurchaseRefused"
        case .remoteHostSessionCode: "remoteHostSessionCode"
        case .newRemoteHost: "newRemoteHost"
        case .remoteHostConnected: "remoteHostConnected"
        case .remoteHostStopped: "remoteHostStopped"
        case .duplicateGroupMessage: "duplicateGroupMessage"
        case .contactAnotherClient: "contactAnotherClient"
        case .connectionsDiff: "connectionsDiff"
        case .subscriptionEnd: "subscriptionEnd"
        case .serviceSubStatus: "serviceSubStatus"
        case .chatItemNotChanged: "chatItemNotChanged"
        case .chatItemDeletedNotFound: "chatItemDeletedNotFound"
        case .serviceRequest: "serviceRequest"
        case .serviceReplySent: "serviceReplySent"
        case .contactRequestRejected: "contactRequestRejected"
        case .acceptingContactRequest: "acceptingContactRequest"
        case .acceptingBusinessRequest: "acceptingBusinessRequest"
        case .contactRequestAlreadyAccepted: "contactRequestAlreadyAccepted"
        case .businessRequestAlreadyAccepted: "businessRequestAlreadyAccepted"
        case .rcvFileDescrReady: "rcvFileDescrReady"
        case .contactAndMemberAssociated: "contactAndMemberAssociated"
        case .unknownMemberCreated: "unknownMemberCreated"
        case .unknownMemberBlocked: "unknownMemberBlocked"
        case .unknownMemberAnnounced: "unknownMemberAnnounced"
        case .acceptingGroupJoinRequestMember: "acceptingGroupJoinRequestMember"
        case .noMemberContactCreating: "noMemberContactCreating"
        case .connectionDisabled: "connectionDisabled"
        case .connectionInactive: "connectionInactive"
        case .agentRcvQueuesDeleted: "agentRcvQueuesDeleted"
        case .agentConnsDeleted: "agentConnsDeleted"
        case .agentUserDeleted: "agentUserDeleted"
        case .messageError: "messageError"
        case .chatErrors: "chatErrors"
        case .timedAction: "timedAction"
        case .terminalEvent: "terminalEvent"
        case .customChatEvent: "customChatEvent"
        }
    }

    var details: String {
        switch self {
        case .chatSuspended: return noDetails
        case let .contactSwitch(u, contact, switchProgress): return withUser(u, "contact: \(String(describing: contact))\nswitchProgress: \(String(describing: switchProgress))")
        case let .groupMemberSwitch(u, groupInfo, member, switchProgress): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nswitchProgress: \(String(describing: switchProgress))")
        case let .contactRatchetSync(u, contact, ratchetSyncProgress): return withUser(u, "contact: \(String(describing: contact))\nratchetSyncProgress: \(String(describing: ratchetSyncProgress))")
        case let .groupMemberRatchetSync(u, groupInfo, member, ratchetSyncProgress): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nratchetSyncProgress: \(String(describing: ratchetSyncProgress))")
        case let .contactDeletedByContact(u, contact): return withUser(u, String(describing: contact))
        case let .contactConnected(u, contact, _): return withUser(u, String(describing: contact))
        case let .contactConnecting(u, contact): return withUser(u, String(describing: contact))
        case let .contactSndReady(u, contact): return withUser(u, String(describing: contact))
        case let .receivedContactRequest(u, contactRequest, chat_): return withUser(u, "contactRequest: \(String(describing: contactRequest))\nchat_: \(String(describing: chat_))")
        case let .contactUpdated(u, fromContact, toContact): return withUser(u, "fromContact: \(String(describing: fromContact))\ntoContact: \(String(describing: toContact))")
        case let .groupMemberUpdated(u, groupInfo, fromMember, toMember): return withUser(u, "groupInfo: \(groupInfo)\nfromMember: \(fromMember)\ntoMember: \(toMember)")
        case let .subscriptionStatus(server, status, conns): return "server: \(server)\nsubscriptionStatus: \(String(describing: status))\nconnections: \(String(describing: conns))"
        case let .chatInfoUpdated(u, chatInfo): return withUser(u, String(describing: chatInfo))
        case let .newChatItems(u, chatItems):
            let itemsString = chatItems.map { chatItem in String(describing: chatItem) }.joined(separator: "\n")
            return withUser(u, itemsString)
        case let .chatItemsStatusesUpdated(u, chatItems):
            let itemsString = chatItems.map { chatItem in String(describing: chatItem) }.joined(separator: "\n")
            return withUser(u, itemsString)
        case let .chatItemUpdated(u, chatItem): return withUser(u, String(describing: chatItem))
        case let .chatItemReaction(u, added, reaction): return withUser(u, "added: \(added)\n\(String(describing: reaction))")
        case let .chatItemsDeleted(u, items, byUser, timed):
            let itemsString = items.map { item in
                "deletedChatItem:\n\(String(describing: item.deletedChatItem))\ntoChatItem:\n\(String(describing: item.toChatItem))" }.joined(separator: "\n")
            return withUser(u, itemsString + "\nbyUser: \(byUser)\ntimed: \(timed)")
        case let .groupChatItemsDeleted(u, gInfo, chatItemIDs, byUser, member_):
            return withUser(u, "chatItemIDs: \(String(describing: chatItemIDs))\ngroupInfo: \(String(describing: gInfo))\nbyUser: \(byUser)\nmember_: \(String(describing: member_))")
        case let .receivedGroupInvitation(u, groupInfo, contact, fromMemberRole, memberRole): return withUser(u, "groupInfo: \(groupInfo)\ncontact: \(contact)\nfromMemberRole: \(fromMemberRole)\nmemberRole: \(memberRole)")
        case let .receivedGroupInvitationViaGroup(u, groupInfo, viaGroupInfo, viaMember, memberRole): return withUser(u, "groupInfo: \(groupInfo)\nviaGroupInfo: \(viaGroupInfo)\nviaMember: \(viaMember)\nmemberRole: \(memberRole)")
        case let .userAcceptedGroupSent(u, groupInfo, hostContact): return withUser(u, "groupInfo: \(groupInfo)\nhostContact: \(String(describing: hostContact))")
        case let .groupLinkConnecting(u, groupInfo, hostMember): return withUser(u, "groupInfo: \(groupInfo)\nhostMember: \(String(describing: hostMember))")
        case let .businessLinkConnecting(u, groupInfo, hostMember, fromContact): return withUser(u, "groupInfo: \(groupInfo)\nhostMember: \(String(describing: hostMember))\nfromContact: \(String(describing: fromContact))")
        case let .joinedGroupMemberConnecting(u, groupInfo, hostMember, member): return withUser(u, "groupInfo: \(groupInfo)\nhostMember: \(hostMember)\nmember: \(member)")
        case let .memberAcceptedByOther(u, groupInfo, acceptingMember, member): return withUser(u, "groupInfo: \(groupInfo)\nacceptingMember: \(acceptingMember)\nmember: \(member)")
        case let .memberRole(u, groupInfo, byMember, member, fromRole, toRole, _): return withUser(u, "groupInfo: \(groupInfo)\nbyMember: \(byMember)\nmember: \(member)\nfromRole: \(fromRole)\ntoRole: \(toRole)")
        case let .memberBlockedForAll(u, groupInfo, byMember, member, blocked, _): return withUser(u, "groupInfo: \(groupInfo)\nbyMember: \(byMember)\nmember: \(member)\nblocked: \(blocked)")
        case let .deletedMemberUser(u, groupInfo, member, withMessages, _): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)\nwithMessages: \(withMessages)")
        case let .deletedMember(u, groupInfo, byMember, deletedMember, withMessages, _): return withUser(u, "groupInfo: \(groupInfo)\nbyMember: \(byMember)\ndeletedMember: \(deletedMember)\nwithMessages: \(withMessages)")
        case let .leftMember(u, groupInfo, member, _): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)")
        case let .groupDeleted(u, groupInfo, member, _): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)")
        case let .userJoinedGroup(u, groupInfo, _): return withUser(u, String(describing: groupInfo))
        case let .joinedGroupMember(u, groupInfo, member): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)")
        case let .connectedToGroupMember(u, groupInfo, member, memberContact): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)\nmemberContact: \(String(describing: memberContact))")
        case let .groupUpdated(u, _, toGroup, _, _): return withUser(u, String(describing: toGroup))
        case let .groupLinkDataUpdated(u, groupInfo, groupLink, groupRelays, relaysChanged): return withUser(u, "groupInfo: \(groupInfo)\ngroupLink: \(groupLink)\ngroupRelays: \(groupRelays)\nrelaysChanged: \(relaysChanged)")
        case let .groupRelayUpdated(u, groupInfo, member, groupRelay): return withUser(u, "groupInfo: \(groupInfo)\nmember: \(member)\ngroupRelay: \(groupRelay)")
        case let .newMemberContactReceivedInv(u, contact, groupInfo, member): return withUser(u, "contact: \(contact)\ngroupInfo: \(groupInfo)\nmember: \(member)")
        case let .rcvFileAccepted(u, chatItem): return withUser(u, String(describing: chatItem))
        case .rcvFileAcceptedSndCancelled: return noDetails
        case let .rcvFileStart(u, chatItem): return withUser(u, String(describing: chatItem))
        case let .rcvFileProgressXFTP(u, chatItem, receivedSize, totalSize, _): return withUser(u, "chatItem: \(String(describing: chatItem))\nreceivedSize: \(receivedSize)\ntotalSize: \(totalSize)")
        case let .rcvStandaloneFileComplete(u, targetPath, _): return withUser(u, targetPath)
        case let .rcvFileComplete(u, chatItem): return withUser(u, String(describing: chatItem))
        case let .rcvFileSndCancelled(u, chatItem, _): return withUser(u, String(describing: chatItem))
        case let .rcvFileError(u, chatItem, agentError, _): return withUser(u, "agentError: \(String(describing: agentError))\nchatItem: \(String(describing: chatItem))")
        case let .rcvFileWarning(u, chatItem, agentError, _): return withUser(u, "agentError: \(String(describing: agentError))\nchatItem: \(String(describing: chatItem))")
        case let .sndFileStart(u, chatItem, _): return withUser(u, String(describing: chatItem))
        case let .sndFileComplete(u, chatItem, _): return withUser(u, String(describing: chatItem))
        case let .sndFileRcvCancelled(u, chatItem, _): return withUser(u, String(describing: chatItem))
        case let .sndFileProgressXFTP(u, chatItem, _, sentSize, totalSize): return withUser(u, "chatItem: \(String(describing: chatItem))\nsentSize: \(sentSize)\ntotalSize: \(totalSize)")
        case let .sndFileRedirectStartXFTP(u, _, redirectMeta): return withUser(u, String(describing: redirectMeta))
        case let .sndFileCompleteXFTP(u, chatItem, _): return withUser(u, String(describing: chatItem))
        case let .sndStandaloneFileComplete(u, _, rcvURIs): return withUser(u, String(rcvURIs.count))
        case let .sndFileError(u, chatItem, _, err): return withUser(u, "error: \(String(describing: err))\nchatItem: \(String(describing: chatItem))")
        case let .sndFileWarning(u, chatItem, _, err): return withUser(u, "error: \(String(describing: err))\nchatItem: \(String(describing: chatItem))")
        case let .callInvitation(inv): return String(describing: inv)
        case let .callOffer(u, contact, callType, offer, sharedKey, askConfirmation): return withUser(u, "contact: \(contact.id)\ncallType: \(String(describing: callType))\nsharedKey: \(sharedKey ?? "")\naskConfirmation: \(askConfirmation)\noffer: \(String(describing: offer))")
        case let .callAnswer(u, contact, answer): return withUser(u, "contact: \(contact.id)\nanswer: \(String(describing: answer))")
        case let .callExtraInfo(u, contact, extraInfo): return withUser(u, "contact: \(contact.id)\nextraInfo: \(String(describing: extraInfo))")
        case let .callEnded(u, contact): return withUser(u, "contact: \(contact.id)")
        case let .contactDisabled(u, contact): return withUser(u, String(describing: contact))
        case let .ntfMessage(u, connEntity, ntfMessage): return withUser(u, "connEntity: \(String(describing: connEntity))\nntfMessage: \(String(describing: ntfMessage))")
        case let .hostConnected(protocol_, transportHost): return "protocol: \(protocol_)\ntransportHost: \(transportHost)"
        case let .hostDisconnected(protocol_, transportHost): return "protocol: \(protocol_)\ntransportHost: \(transportHost)"
        case let .remoteCtrlFound(remoteCtrl, ctrlAppInfo_, appVersion, compatible): return "remoteCtrl:\n\(String(describing: remoteCtrl))\nctrlAppInfo_:\n\(String(describing: ctrlAppInfo_))\nappVersion: \(appVersion)\ncompatible: \(compatible)"
        case let .remoteCtrlSessionCode(remoteCtrl_, sessionCode): return "remoteCtrl_:\n\(String(describing: remoteCtrl_))\nsessionCode: \(sessionCode)"
        case let .remoteCtrlConnected(remoteCtrl): return String(describing: remoteCtrl)
        case let .remoteCtrlStopped(remoteCtrl_, rcsState, rcStopReason): return "remoteCtrl_: \(String(describing: remoteCtrl_))\nrcsState: \(String(describing: rcsState))\nrcStopReason: \(String(describing: rcStopReason))"
        case let .contactPQEnabled(u, contact, pqEnabled): return withUser(u, "contact: \(String(describing: contact))\npqEnabled: \(pqEnabled)")
        case let .badgeChanged(u, badgeState): return withUser(u, String(describing: badgeState))
        case let .badgeAlert(u, badgeAlert): return withUser(u, String(describing: badgeAlert))
        case let .storePurchaseCredited(u, invoiceId): return withUser(u, "invoiceId: \(invoiceId)")
        case let .storePurchaseRefused(u, invoiceId, refusal): return withUser(u, "invoiceId: \(invoiceId)\nrefusal: \(String(describing: refusal))")
        case let .remoteHostSessionCode(remoteHost_, sessionCode): return "remoteHost_: \(String(describing: remoteHost_))\nsessionCode: \(sessionCode)"
        case let .newRemoteHost(remoteHost): return "remoteHost: \(String(describing: remoteHost))"
        case let .remoteHostConnected(remoteHost, compression): return "remoteHost: \(String(describing: remoteHost))\ncompression: \(compression)"
        case let .remoteHostStopped(remoteHostId_, rhsState, rhStopReason): return "remoteHostId_: \(String(describing: remoteHostId_))\nrhsState: \(String(describing: rhsState))\nrhStopReason: \(String(describing: rhStopReason))"
        case let .duplicateGroupMessage(u, member): return withUser(u, "member: \(String(describing: member))")
        case let .contactAnotherClient(u, contact): return withUser(u, String(describing: contact))
        case let .connectionsDiff(userIds, connIds): return "userIds: \(String(describing: userIds))\nconnIds: \(String(describing: connIds))"
        case let .subscriptionEnd(u, connectionEntity): return withUser(u, String(describing: connectionEntity))
        case let .serviceSubStatus(server, serviceSubEvent): return "server: \(server)\nserviceSubEvent: \(String(describing: serviceSubEvent))"
        case let .chatItemNotChanged(u, chatItem): return withUser(u, String(describing: chatItem))
        case let .chatItemDeletedNotFound(u, contact, sharedMsgId): return withUser(u, "contact: \(String(describing: contact))\nsharedMsgId: \(sharedMsgId)")
        case let .serviceRequest(u, requestId, signerKey, requestData): return withUser(u, "requestId: \(requestId)\nsignerKey: \(String(describing: signerKey))\nrequestData: \(String(describing: requestData))")
        case let .serviceReplySent(connectionId): return "connectionId: \(connectionId)"
        case let .contactRequestRejected(u, contact, rejectionReason): return withUser(u, "contact: \(String(describing: contact))\nrejectionReason: \(String(describing: rejectionReason))")
        case let .acceptingContactRequest(u, contact): return withUser(u, String(describing: contact))
        case let .acceptingBusinessRequest(u, groupInfo): return withUser(u, String(describing: groupInfo))
        case let .contactRequestAlreadyAccepted(u, contact): return withUser(u, String(describing: contact))
        case let .businessRequestAlreadyAccepted(u, groupInfo): return withUser(u, String(describing: groupInfo))
        case let .rcvFileDescrReady(u, chatItem, rcvFileTransfer, rcvFileDescr): return withUser(u, "chatItem: \(String(describing: chatItem))\nrcvFileTransfer: \(String(describing: rcvFileTransfer))\nrcvFileDescr: \(String(describing: rcvFileDescr))")
        case let .contactAndMemberAssociated(u, contact, groupInfo, member, updatedContact): return withUser(u, "contact: \(String(describing: contact))\ngroupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))\nupdatedContact: \(String(describing: updatedContact))")
        case let .unknownMemberCreated(u, groupInfo, forwardedByMember, member): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nforwardedByMember: \(String(describing: forwardedByMember))\nmember: \(String(describing: member))")
        case let .unknownMemberBlocked(u, groupInfo, blockedByMember, member): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nblockedByMember: \(String(describing: blockedByMember))\nmember: \(String(describing: member))")
        case let .unknownMemberAnnounced(u, groupInfo, announcingMember, unknownMember, announcedMember): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nannouncingMember: \(String(describing: announcingMember))\nunknownMember: \(String(describing: unknownMember))\nannouncedMember: \(String(describing: announcedMember))")
        case let .acceptingGroupJoinRequestMember(u, groupInfo, member): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))")
        case let .noMemberContactCreating(u, groupInfo, member): return withUser(u, "groupInfo: \(String(describing: groupInfo))\nmember: \(String(describing: member))")
        case let .connectionDisabled(connectionEntity): return String(describing: connectionEntity)
        case let .connectionInactive(connectionEntity, inactive): return "connectionEntity: \(String(describing: connectionEntity))\ninactive: \(inactive)"
        case let .agentRcvQueuesDeleted(deletedRcvQueues): return "deletedRcvQueues: \(String(describing: deletedRcvQueues))"
        case let .agentConnsDeleted(agentConnIds): return "agentConnIds: \(String(describing: agentConnIds))"
        case let .agentUserDeleted(agentUserId): return "agentUserId: \(agentUserId)"
        case let .messageError(u, severity, errorMessage): return withUser(u, "severity: \(severity)\nerrorMessage: \(errorMessage)")
        case let .chatErrors(chatErrors): return "chatErrors: \(String(describing: chatErrors))"
        case let .timedAction(action, durationMilliseconds): return "action: \(action)\ndurationMilliseconds: \(durationMilliseconds)"
        case let .terminalEvent(terminalEvent): return String(describing: terminalEvent)
        case let .customChatEvent(user_, response): return "\(String(describing: user_))\nresponse: \(response)"
        }
    }

    static func fallbackResult(_ type: String, _ json: NSDictionary) -> ChatEvent? {
        let inner = json[type] as? NSDictionary ?? json
        if let event = decodeEvent(type: type, data: inner) {
            return event
        }
        logger.warning("ChatEvent: unknown event type '\(type)', treating as customChatEvent")
        let user: UserRef? = (inner["user"] as? NSDictionary).flatMap { try? decodeObject($0) }
        return .customChatEvent(user_: user, response: "{\"type\":\"\(type)\",\"data\":\(inner)}")
    }

    private static func decodeEvent(type: String, data: NSDictionary) -> ChatEvent? {
        if let e = decodeEvent1(type: type, data: data) { return e }
        if let e = decodeEvent2(type: type, data: data) { return e }
        if let e = decodeEvent3(type: type, data: data) { return e }
        return decodeEvent4(type: type, data: data)
    }

    private static func decodeEvent1(type: String, data: NSDictionary) -> ChatEvent? {
        switch type {
        case "chatSuspended":
            return .chatSuspended
        case "contactSwitch":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let spObj = data["switchProgress"],
                  let switchProgress: SwitchProgress = try? decodeObject(spObj) else { return nil }
            return .contactSwitch(user: user, contact: contact, switchProgress: switchProgress)
        case "groupMemberSwitch":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let spObj = data["switchProgress"],
                  let switchProgress: SwitchProgress = try? decodeObject(spObj) else { return nil }
            return .groupMemberSwitch(user: user, groupInfo: groupInfo, member: member, switchProgress: switchProgress)
        case "contactRatchetSync":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let rspObj = data["ratchetSyncProgress"],
                  let ratchetSyncProgress: RatchetSyncProgress = try? decodeObject(rspObj) else { return nil }
            return .contactRatchetSync(user: user, contact: contact, ratchetSyncProgress: ratchetSyncProgress)
        case "groupMemberRatchetSync":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let rspObj = data["ratchetSyncProgress"],
                  let ratchetSyncProgress: RatchetSyncProgress = try? decodeObject(rspObj) else { return nil }
            return .groupMemberRatchetSync(user: user, groupInfo: groupInfo, member: member, ratchetSyncProgress: ratchetSyncProgress)
        case "contactDeletedByContact":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .contactDeletedByContact(user: user, contact: contact)
        case "contactConnected":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            let userCustomProfile: Profile? = data["userCustomProfile"].flatMap { try? decodeObject($0) }
            return .contactConnected(user: user, contact: contact, userCustomProfile: userCustomProfile)
        case "contactConnecting":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .contactConnecting(user: user, contact: contact)
        case "contactSndReady":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .contactSndReady(user: user, contact: contact)
        case "receivedContactRequest":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let crObj = data["contactRequest"],
                  let contactRequest: UserContactRequest = try? decodeObject(crObj) else { return nil }
            let chat: ChatData? = data["chat_"].flatMap { try? decodeObject($0) }
            return .receivedContactRequest(user: user, contactRequest: contactRequest, chat_: chat)
        case "contactUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let fcObj = data["fromContact"],
                  let fromContact: Contact = try? decodeObject(fcObj),
                  let tcObj = data["toContact"],
                  let toContact: Contact = try? decodeObject(tcObj) else { return nil }
            return .contactUpdated(user: user, fromContact: fromContact, toContact: toContact)
        case "groupMemberUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let fmObj = data["fromMember"],
                  let fromMember: GroupMember = try? decodeObject(fmObj),
                  let tmObj = data["toMember"],
                  let toMember: GroupMember = try? decodeObject(tmObj) else { return nil }
            return .groupMemberUpdated(user: user, groupInfo: groupInfo, fromMember: fromMember, toMember: toMember)
        case "subscriptionStatus":
            guard let server = data["server"] as? String,
                  let ssObj = data["subscriptionStatus"],
                  let subscriptionStatus: SubscriptionStatus = try? decodeObject(ssObj),
                  let connections = data["connections"] as? [String] else { return nil }
            return .subscriptionStatus(server: server, subscriptionStatus: subscriptionStatus, connections: connections)
        case "chatInfoUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatInfo"],
                  let chatInfo: ChatInfo = try? decodeObject(ciObj) else { return nil }
            return .chatInfoUpdated(user: user, chatInfo: chatInfo)
        case "newChatItems":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let chatItems = data["chatItems"] as? [Any],
                  let items = try? chatItems.map({ try decodeObject($0) as AChatItem }) else { return nil }
            return .newChatItems(user: user, chatItems: items)
        case "chatItemsStatusesUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let chatItems = data["chatItems"] as? [Any],
                  let items = try? chatItems.map({ try decodeObject($0) as AChatItem }) else { return nil }
            return .chatItemsStatusesUpdated(user: user, chatItems: items)
        case "chatItemUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .chatItemUpdated(user: user, chatItem: chatItem)
        case "chatItemReaction":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let added = data["added"] as? Bool,
                  let rObj = data["reaction"],
                  let reaction: ACIReaction = try? decodeObject(rObj) else { return nil }
            return .chatItemReaction(user: user, added: added, reaction: reaction)
        case "chatItemsDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let chatItemDeletions = data["chatItemDeletions"] as? [Any],
                  let deletions = try? chatItemDeletions.map({ try decodeObject($0) as ChatItemDeletion }),
                  let byUser = data["byUser"] as? Bool,
                  let timed = data["timed"] as? Bool else { return nil }
            return .chatItemsDeleted(user: user, chatItemDeletions: deletions, byUser: byUser, timed: timed)
        case "groupChatItemsDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let chatItemIDs = data["chatItemIDs"] as? [Int64],
                  let byUser = data["byUser"] as? Bool else { return nil }
            let member: GroupMember? = data["member_"].flatMap { try? decodeObject($0) }
            return .groupChatItemsDeleted(user: user, groupInfo: groupInfo, chatItemIDs: Set(chatItemIDs), byUser: byUser, member_: member)
        default:
            return nil
        }
    }

    private static func decodeEvent2(type: String, data: NSDictionary) -> ChatEvent? {
        switch type {
        case "receivedGroupInvitation":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let fmrObj = data["fromMemberRole"],
                  let fromMemberRole: GroupMemberRole = try? decodeObject(fmrObj),
                  let mrObj = data["memberRole"],
                  let memberRole: GroupMemberRole = try? decodeObject(mrObj) else { return nil }
            return .receivedGroupInvitation(user: user, groupInfo: groupInfo, contact: contact, fromMemberRole: fromMemberRole, memberRole: memberRole)
        case "receivedGroupInvitationViaGroup":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let vgiObj = data["viaGroupInfo"],
                  let viaGroupInfo: GroupInfo = try? decodeObject(vgiObj),
                  let vmObj = data["viaMember"],
                  let viaMember: GroupMember = try? decodeObject(vmObj),
                  let mrObj = data["memberRole"],
                  let memberRole: GroupMemberRole = try? decodeObject(mrObj) else { return nil }
            return .receivedGroupInvitationViaGroup(user: user, groupInfo: groupInfo, viaGroupInfo: viaGroupInfo, viaMember: viaMember, memberRole: memberRole)
        case "userAcceptedGroupSent":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            let hostContact: Contact? = data["hostContact"].flatMap { try? decodeObject($0) }
            return .userAcceptedGroupSent(user: user, groupInfo: groupInfo, hostContact: hostContact)
        case "groupLinkConnecting":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let hmObj = data["hostMember"],
                  let hostMember: GroupMember = try? decodeObject(hmObj) else { return nil }
            return .groupLinkConnecting(user: user, groupInfo: groupInfo, hostMember: hostMember)
        case "businessLinkConnecting":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let hmObj = data["hostMember"],
                  let hostMember: GroupMember = try? decodeObject(hmObj),
                  let fcObj = data["fromContact"],
                  let fromContact: Contact = try? decodeObject(fcObj) else { return nil }
            return .businessLinkConnecting(user: user, groupInfo: groupInfo, hostMember: hostMember, fromContact: fromContact)
        case "joinedGroupMemberConnecting":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let hmObj = data["hostMember"],
                  let hostMember: GroupMember = try? decodeObject(hmObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .joinedGroupMemberConnecting(user: user, groupInfo: groupInfo, hostMember: hostMember, member: member)
        case "memberAcceptedByOther":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let amObj = data["acceptingMember"],
                  let acceptingMember: GroupMember = try? decodeObject(amObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .memberAcceptedByOther(user: user, groupInfo: groupInfo, acceptingMember: acceptingMember, member: member)
        case "memberRole":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let bmObj = data["byMember"],
                  let byMember: GroupMember = try? decodeObject(bmObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let frObj = data["fromRole"],
                  let fromRole: GroupMemberRole = try? decodeObject(frObj),
                  let trObj = data["toRole"],
                  let toRole: GroupMemberRole = try? decodeObject(trObj) else { return nil }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .memberRole(user: user, groupInfo: groupInfo, byMember: byMember, member: member, fromRole: fromRole, toRole: toRole, msgSigned: msgSigned)
        case "memberBlockedForAll":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let bmObj = data["byMember"],
                  let byMember: GroupMember = try? decodeObject(bmObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let blocked = data["blocked"] as? Bool else { return nil }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .memberBlockedForAll(user: user, groupInfo: groupInfo, byMember: byMember, member: member, blocked: blocked, msgSigned: msgSigned)
        case "deletedMemberUser":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let withMessages = data["withMessages"] as? Bool else { return nil }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .deletedMemberUser(user: user, groupInfo: groupInfo, member: member, withMessages: withMessages, msgSigned: msgSigned)
        case "deletedMember":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let bmObj = data["byMember"],
                  let byMember: GroupMember = try? decodeObject(bmObj),
                  let dmObj = data["deletedMember"],
                  let deletedMember: GroupMember = try? decodeObject(dmObj),
                  let withMessages = data["withMessages"] as? Bool else { return nil }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .deletedMember(user: user, groupInfo: groupInfo, byMember: byMember, deletedMember: deletedMember, withMessages: withMessages, msgSigned: msgSigned)
        case "leftMember":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .leftMember(user: user, groupInfo: groupInfo, member: member, msgSigned: msgSigned)
        case "groupDeleted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .groupDeleted(user: user, groupInfo: groupInfo, member: member, msgSigned: msgSigned)
        case "userJoinedGroup":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let hmObj = data["hostMember"],
                  let hostMember: GroupMember = try? decodeObject(hmObj) else { return nil }
            return .userJoinedGroup(user: user, groupInfo: groupInfo, hostMember: hostMember)
        case "joinedGroupMember":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .joinedGroupMember(user: user, groupInfo: groupInfo, member: member)
        case "connectedToGroupMember":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            let memberContact: Contact? = data["memberContact"].flatMap { try? decodeObject($0) }
            return .connectedToGroupMember(user: user, groupInfo: groupInfo, member: member, memberContact: memberContact)
        case "groupUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let fgObj = data["fromGroup"],
                  let fromGroup: GroupInfo = try? decodeObject(fgObj),
                  let tgObj = data["toGroup"],
                  let toGroup: GroupInfo = try? decodeObject(tgObj) else { return nil }
            let member: GroupMember? = data["member_"].flatMap { try? decodeObject($0) }
            let msgSigned: MsgSigStatus? = data["msgSigned"].flatMap { try? decodeObject($0) }
            return .groupUpdated(user: user, fromGroup: fromGroup, toGroup: toGroup, member_: member, msgSigned: msgSigned)
        case "groupLinkDataUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let glObj = data["groupLink"],
                  let groupLink: GroupLink = try? decodeObject(glObj),
                  let groupRelays = data["groupRelays"] as? [Any],
                  let relays = try? groupRelays.map({ try decodeObject($0) as GroupRelay }),
                  let relaysChanged = data["relaysChanged"] as? Bool else { return nil }
            return .groupLinkDataUpdated(user: user, groupInfo: groupInfo, groupLink: groupLink, groupRelays: relays, relaysChanged: relaysChanged)
        case "groupRelayUpdated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let grObj = data["groupRelay"],
                  let groupRelay: GroupRelay = try? decodeObject(grObj) else { return nil }
            return .groupRelayUpdated(user: user, groupInfo: groupInfo, member: member, groupRelay: groupRelay)
        case "newMemberContactReceivedInv":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .newMemberContactReceivedInv(user: user, contact: contact, groupInfo: groupInfo, member: member)
        default:
            return nil
        }
    }

    private static func decodeEvent3(type: String, data: NSDictionary) -> ChatEvent? {
        switch type {
        case "rcvFileAccepted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .rcvFileAccepted(user: user, chatItem: chatItem)
        case "rcvFileAcceptedSndCancelled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj) else { return nil }
            return .rcvFileAcceptedSndCancelled(user: user, rcvFileTransfer: rcvFileTransfer)
        case "rcvFileStart":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .rcvFileStart(user: user, chatItem: chatItem)
        case "rcvFileProgressXFTP":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let receivedSize = data["receivedSize"] as? Int64,
                  let totalSize = data["totalSize"] as? Int64,
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj) else { return nil }
            let chatItem: AChatItem? = data["chatItem_"].flatMap { try? decodeObject($0) }
            return .rcvFileProgressXFTP(user: user, chatItem_: chatItem, receivedSize: receivedSize, totalSize: totalSize, rcvFileTransfer: rcvFileTransfer)
        case "rcvFileComplete":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .rcvFileComplete(user: user, chatItem: chatItem)
        case "rcvStandaloneFileComplete":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let targetPath = data["targetPath"] as? String,
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj) else { return nil }
            return .rcvStandaloneFileComplete(user: user, targetPath: targetPath, rcvFileTransfer: rcvFileTransfer)
        case "rcvFileSndCancelled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj),
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj) else { return nil }
            return .rcvFileSndCancelled(user: user, chatItem: chatItem, rcvFileTransfer: rcvFileTransfer)
        case "rcvFileError":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let aeObj = data["agentError"],
                  let agentError: AgentErrorType = try? decodeObject(aeObj),
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj) else { return nil }
            let chatItem: AChatItem? = data["chatItem_"].flatMap { try? decodeObject($0) }
            return .rcvFileError(user: user, chatItem_: chatItem, agentError: agentError, rcvFileTransfer: rcvFileTransfer)
        case "rcvFileWarning":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let aeObj = data["agentError"],
                  let agentError: AgentErrorType = try? decodeObject(aeObj),
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj) else { return nil }
            let chatItem: AChatItem? = data["chatItem_"].flatMap { try? decodeObject($0) }
            return .rcvFileWarning(user: user, chatItem_: chatItem, agentError: agentError, rcvFileTransfer: rcvFileTransfer)
        case "sndFileStart":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj),
                  let sftObj = data["sndFileTransfer"],
                  let sndFileTransfer: SndFileTransfer = try? decodeObject(sftObj) else { return nil }
            return .sndFileStart(user: user, chatItem: chatItem, sndFileTransfer: sndFileTransfer)
        case "sndFileComplete":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj),
                  let sftObj = data["sndFileTransfer"],
                  let sndFileTransfer: SndFileTransfer = try? decodeObject(sftObj) else { return nil }
            return .sndFileComplete(user: user, chatItem: chatItem, sndFileTransfer: sndFileTransfer)
        case "sndFileRcvCancelled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj),
                  let sftObj = data["sndFileTransfer"],
                  let sndFileTransfer: SndFileTransfer = try? decodeObject(sftObj) else { return nil }
            return .sndFileRcvCancelled(user: user, chatItem_: chatItem, sndFileTransfer: sndFileTransfer)
        case "sndFileProgressXFTP":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj),
                  let sentSize = data["sentSize"] as? Int64,
                  let totalSize = data["totalSize"] as? Int64 else { return nil }
            let chatItem: AChatItem? = data["chatItem_"].flatMap { try? decodeObject($0) }
            return .sndFileProgressXFTP(user: user, chatItem_: chatItem, fileTransferMeta: fileTransferMeta, sentSize: sentSize, totalSize: totalSize)
        case "sndFileRedirectStartXFTP":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj),
                  let rmObj = data["redirectMeta"],
                  let redirectMeta: FileTransferMeta = try? decodeObject(rmObj) else { return nil }
            return .sndFileRedirectStartXFTP(user: user, fileTransferMeta: fileTransferMeta, redirectMeta: redirectMeta)
        case "sndFileCompleteXFTP":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj) else { return nil }
            return .sndFileCompleteXFTP(user: user, chatItem: chatItem, fileTransferMeta: fileTransferMeta)
        case "sndStandaloneFileComplete":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj),
                  let rcvURIs = data["rcvURIs"] as? [String] else { return nil }
            return .sndStandaloneFileComplete(user: user, fileTransferMeta: fileTransferMeta, rcvURIs: rcvURIs)
        case "sndFileError":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj),
                  let errorMessage = data["errorMessage"] as? String else { return nil }
            let chatItem: AChatItem? = data["chatItem_"].flatMap { try? decodeObject($0) }
            return .sndFileError(user: user, chatItem_: chatItem, fileTransferMeta: fileTransferMeta, errorMessage: errorMessage)
        case "sndFileWarning":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ftmObj = data["fileTransferMeta"],
                  let fileTransferMeta: FileTransferMeta = try? decodeObject(ftmObj),
                  let errorMessage = data["errorMessage"] as? String else { return nil }
            let chatItem: AChatItem? = data["chatItem_"].flatMap { try? decodeObject($0) }
            return .sndFileWarning(user: user, chatItem_: chatItem, fileTransferMeta: fileTransferMeta, errorMessage: errorMessage)
        case "callInvitation":
            guard let ciObj = data["callInvitation"],
                  let callInvitation: RcvCallInvitation = try? decodeObject(ciObj) else { return nil }
            return .callInvitation(callInvitation: callInvitation)
        case "callOffer":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let ctObj = data["callType"],
                  let callType: CallType = try? decodeObject(ctObj),
                  let offerObj = data["offer"],
                  let offer: WebRTCSession = try? decodeObject(offerObj),
                  let askConfirmation = data["askConfirmation"] as? Bool else { return nil }
            let sharedKey: String? = data["sharedKey"] as? String
            return .callOffer(user: user, contact: contact, callType: callType, offer: offer, sharedKey: sharedKey, askConfirmation: askConfirmation)
        case "callAnswer":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let answerObj = data["answer"],
                  let answer: WebRTCSession = try? decodeObject(answerObj) else { return nil }
            return .callAnswer(user: user, contact: contact, answer: answer)
        case "callExtraInfo":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let eiObj = data["extraInfo"],
                  let extraInfo: WebRTCExtraInfo = try? decodeObject(eiObj) else { return nil }
            return .callExtraInfo(user: user, contact: contact, extraInfo: extraInfo)
        case "callEnded":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .callEnded(user: user, contact: contact)
        case "contactDisabled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .contactDisabled(user: user, contact: contact)
        case "ntfMessage":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ceObj = data["connEntity"],
                  let connEntity: ConnectionEntity = try? decodeObject(ceObj),
                  let nmObj = data["ntfMessage"],
                  let ntfMessage: NtfMsgAckInfo = try? decodeObject(nmObj) else { return nil }
            return .ntfMessage(user: user, connEntity: connEntity, ntfMessage: ntfMessage)
        case "hostConnected":
            guard let protocol_ = data["protocol"] as? String,
                  let transportHost = data["transportHost"] as? String else { return nil }
            return .hostConnected(protocol: protocol_, transportHost: transportHost)
        case "hostDisconnected":
            guard let protocol_ = data["protocol"] as? String,
                  let transportHost = data["transportHost"] as? String else { return nil }
            return .hostDisconnected(protocol: protocol_, transportHost: transportHost)
        default:
            return nil
        }
    }

    private static func decodeEvent4(type: String, data: NSDictionary) -> ChatEvent? {
        switch type {
        case "remoteCtrlFound":
            guard let rcObj = data["remoteCtrl"],
                  let remoteCtrl: RemoteCtrlInfo = try? decodeObject(rcObj),
                  let appVersion = data["appVersion"] as? String,
                  let compatible = data["compatible"] as? Bool else { return nil }
            let ctrlAppInfo: CtrlAppInfo? = data["ctrlAppInfo_"].flatMap { try? decodeObject($0) }
            return .remoteCtrlFound(remoteCtrl: remoteCtrl, ctrlAppInfo_: ctrlAppInfo, appVersion: appVersion, compatible: compatible)
        case "remoteCtrlSessionCode":
            guard let sessionCode = data["sessionCode"] as? String else { return nil }
            let remoteCtrl: RemoteCtrlInfo? = data["remoteCtrl_"].flatMap { try? decodeObject($0) }
            return .remoteCtrlSessionCode(remoteCtrl_: remoteCtrl, sessionCode: sessionCode)
        case "remoteCtrlConnected":
            guard let rcObj = data["remoteCtrl"],
                  let remoteCtrl: RemoteCtrlInfo = try? decodeObject(rcObj) else { return nil }
            return .remoteCtrlConnected(remoteCtrl: remoteCtrl)
        case "remoteCtrlStopped":
            guard let rcsObj = data["rcsState"],
                  let rcsState: RemoteCtrlSessionState = try? decodeObject(rcsObj),
                  let rcrObj = data["rcStopReason"],
                  let rcStopReason: RemoteCtrlStopReason = try? decodeObject(rcrObj) else { return nil }
            let remoteCtrl: RemoteCtrlInfo? = (data["remoteCtrl_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .remoteCtrlStopped(remoteCtrl_: remoteCtrl, rcsState: rcsState, rcStopReason: rcStopReason)
        case "contactPQEnabled":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let pqEnabled = data["pqEnabled"] as? Bool else { return nil }
            return .contactPQEnabled(user: user, contact: contact, pqEnabled: pqEnabled)
        case "contactAnotherClient":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .contactAnotherClient(user: user, contact: contact)
        case "connectionsDiff":
            guard let uidObj = data["userIds"],
                  let userIds: DatabaseDiff = try? decodeObject(uidObj),
                  let cidObj = data["connIds"],
                  let connIds: DatabaseDiff = try? decodeObject(cidObj) else { return nil }
            return .connectionsDiff(userIds: userIds, connIds: connIds)
        case "subscriptionEnd":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ceObj = data["connectionEntity"],
                  let connectionEntity: ConnectionEntity = try? decodeObject(ceObj) else { return nil }
            return .subscriptionEnd(user: user, connectionEntity: connectionEntity)
        case "serviceSubStatus":
            guard let server = data["server"] as? String,
                  let sseObj = data["serviceSubEvent"],
                  let serviceSubEvent: ServiceSubEvent = try? decodeObject(sseObj) else { return nil }
            return .serviceSubStatus(server: server, serviceSubEvent: serviceSubEvent)
        case "chatItemNotChanged":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj) else { return nil }
            return .chatItemNotChanged(user: user, chatItem: chatItem)
        case "chatItemDeletedNotFound":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let sharedMsgId = data["sharedMsgId"] as? String else { return nil }
            return .chatItemDeletedNotFound(user: user, contact: contact, sharedMsgId: sharedMsgId)
        case "serviceRequest":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let requestId = data["requestId"] as? String,
                  let requestData = data["requestData"] as? [String: String] else { return nil }
            let signerKey: String? = data["signerKey"] as? String
            return .serviceRequest(user: user, requestId: requestId, signerKey: signerKey, requestData: requestData)
        case "serviceReplySent":
            guard let connectionId = data["connectionId"] as? String else { return nil }
            return .serviceReplySent(connectionId: connectionId)
        case "contactRequestRejected":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            let rejectionReason: String? = data["rejectionReason"] as? String
            return .contactRequestRejected(user: user, contact: contact, rejectionReason: rejectionReason)
        case "acceptingContactRequest":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .acceptingContactRequest(user: user, contact: contact)
        case "acceptingBusinessRequest":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            return .acceptingBusinessRequest(user: user, groupInfo: groupInfo)
        case "contactRequestAlreadyAccepted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj) else { return nil }
            return .contactRequestAlreadyAccepted(user: user, contact: contact)
        case "businessRequestAlreadyAccepted":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj) else { return nil }
            return .businessRequestAlreadyAccepted(user: user, groupInfo: groupInfo)
        case "rcvFileDescrReady":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let ciObj = data["chatItem"],
                  let chatItem: AChatItem = try? decodeObject(ciObj),
                  let rftObj = data["rcvFileTransfer"],
                  let rcvFileTransfer: RcvFileTransfer = try? decodeObject(rftObj),
                  let rfdObj = data["rcvFileDescr"],
                  let rcvFileDescr: RcvFileDescr = try? decodeObject(rfdObj) else { return nil }
            return .rcvFileDescrReady(user: user, chatItem: chatItem, rcvFileTransfer: rcvFileTransfer, rcvFileDescr: rcvFileDescr)
        case "contactAndMemberAssociated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let contactObj = data["contact"],
                  let contact: Contact = try? decodeObject(contactObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj),
                  let ucObj = data["updatedContact"],
                  let updatedContact: Contact = try? decodeObject(ucObj) else { return nil }
            return .contactAndMemberAssociated(user: user, contact: contact, groupInfo: groupInfo, member: member, updatedContact: updatedContact)
        case "unknownMemberCreated":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let fbmObj = data["forwardedByMember"],
                  let forwardedByMember: GroupMember = try? decodeObject(fbmObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .unknownMemberCreated(user: user, groupInfo: groupInfo, forwardedByMember: forwardedByMember, member: member)
        case "unknownMemberBlocked":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let bbmObj = data["blockedByMember"],
                  let blockedByMember: GroupMember = try? decodeObject(bbmObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .unknownMemberBlocked(user: user, groupInfo: groupInfo, blockedByMember: blockedByMember, member: member)
        case "unknownMemberAnnounced":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let amObj = data["announcingMember"],
                  let announcingMember: GroupMember = try? decodeObject(amObj),
                  let umObj = data["unknownMember"],
                  let unknownMember: GroupMember = try? decodeObject(umObj),
                  let anmObj = data["announcedMember"],
                  let announcedMember: GroupMember = try? decodeObject(anmObj) else { return nil }
            return .unknownMemberAnnounced(user: user, groupInfo: groupInfo, announcingMember: announcingMember, unknownMember: unknownMember, announcedMember: announcedMember)
        case "acceptingGroupJoinRequestMember":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .acceptingGroupJoinRequestMember(user: user, groupInfo: groupInfo, member: member)
        case "noMemberContactCreating":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let giObj = data["groupInfo"],
                  let groupInfo: GroupInfo = try? decodeObject(giObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .noMemberContactCreating(user: user, groupInfo: groupInfo, member: member)
        case "connectionDisabled":
            guard let ceObj = data["connectionEntity"],
                  let connectionEntity: ConnectionEntity = try? decodeObject(ceObj) else { return nil }
            return .connectionDisabled(connectionEntity: connectionEntity)
        case "connectionInactive":
            guard let ceObj = data["connectionEntity"],
                  let connectionEntity: ConnectionEntity = try? decodeObject(ceObj),
                  let inactive = data["inactive"] as? Bool else { return nil }
            return .connectionInactive(connectionEntity: connectionEntity, inactive: inactive)
        case "agentRcvQueuesDeleted":
            guard let deletedRcvQueues = data["deletedRcvQueues"] as? [Any],
                  let queues = try? deletedRcvQueues.map({ try decodeObject($0) as DeletedRcvQueue }) else { return nil }
            return .agentRcvQueuesDeleted(deletedRcvQueues: queues)
        case "agentConnsDeleted":
            guard let agentConnIds = data["agentConnIds"] as? [String] else { return nil }
            return .agentConnsDeleted(agentConnIds: agentConnIds)
        case "agentUserDeleted":
            guard let agentUserId = data["agentUserId"] as? Int64 else { return nil }
            return .agentUserDeleted(agentUserId: agentUserId)
        case "messageError":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let severity = data["severity"] as? String,
                  let errorMessage = data["errorMessage"] as? String else { return nil }
            return .messageError(user: user, severity: severity, errorMessage: errorMessage)
        case "chatErrors":
            guard let chatErrors = data["chatErrors"] as? [Any],
                  let errors = try? chatErrors.map({ try decodeObject($0) as ChatError }) else { return nil }
            return .chatErrors(chatErrors: errors)
        case "timedAction":
            guard let action = data["action"] as? String,
                  let durationMilliseconds = data["durationMilliseconds"] as? Int64 else { return nil }
            return .timedAction(action: action, durationMilliseconds: durationMilliseconds)
        case "terminalEvent":
            guard let teObj = data["terminalEvent"],
                  let terminalEvent: TerminalEvent = try? decodeObject(teObj) else { return nil }
            return .terminalEvent(terminalEvent: terminalEvent)
        case "storePurchaseCredited":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let invoiceId = data["invoiceId"] as? String else { return nil }
            return .storePurchaseCredited(user: user, invoiceId: invoiceId)
        case "storePurchaseRefused":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let invoiceId = data["invoiceId"] as? String else { return nil }
            let refusal: BadgeIssueFailure? = (data["refusal"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .storePurchaseRefused(user: user, invoiceId: invoiceId, refusal: refusal ?? .invalidCredential)
        case "remoteHostSessionCode":
            guard let sessionCode = data["sessionCode"] as? String else { return nil }
            let remoteHost: RemoteHostInfo? = (data["remoteHost_"] as? NSDictionary).flatMap { try? decodeObject($0) }
            return .remoteHostSessionCode(remoteHost_: remoteHost, sessionCode: sessionCode)
        case "newRemoteHost":
            guard let rhObj = data["remoteHost"],
                  let remoteHost: RemoteHostInfo = try? decodeObject(rhObj) else { return nil }
            return .newRemoteHost(remoteHost: remoteHost)
        case "remoteHostConnected":
            guard let rhObj = data["remoteHost"],
                  let remoteHost: RemoteHostInfo = try? decodeObject(rhObj),
                  let compression = data["compression"] as? Bool else { return nil }
            return .remoteHostConnected(remoteHost: remoteHost, compression: compression)
        case "remoteHostStopped":
            guard let stateObj = data["rhsState"],
                  let rhsState: RemoteHostSessionState = try? decodeObject(stateObj),
                  let reasonObj = data["rhStopReason"],
                  let rhStopReason: RemoteHostStopReason = try? decodeObject(reasonObj) else { return nil }
            let remoteHostId: Int64? = data["remoteHostId_"] as? Int64
            return .remoteHostStopped(remoteHostId_: remoteHostId, rhsState: rhsState, rhStopReason: rhStopReason)
        case "duplicateGroupMessage":
            guard let userObj = data["user"],
                  let user: UserRef = try? decodeObject(userObj),
                  let memberObj = data["member"],
                  let member: GroupMember = try? decodeObject(memberObj) else { return nil }
            return .duplicateGroupMessage(user: user, member: member)
        default:
            return nil
        }
    }
}

struct NewUser: Encodable {
    var profile: Profile?
    var pastTimestamp: Bool
    var userChatRelay: Bool = false
}

enum ChatPagination {
    static let INITIAL_COUNT = 75
    static let PRELOAD_COUNT = 100
    static let UNTIL_PRELOAD_COUNT = 50

    case last(count: Int)
    case after(chatItemId: Int64, count: Int)
    case before(chatItemId: Int64, count: Int)
    case around(chatItemId: Int64, count: Int)
    case initial(count: Int)

    var cmdString: String {
        switch self {
        case let .last(count): return "count=\(count)"
        case let .after(chatItemId, count): return "after=\(chatItemId) count=\(count)"
        case let .before(chatItemId, count): return "before=\(chatItemId) count=\(count)"
        case let .around(chatItemId, count): return "around=\(chatItemId) count=\(count)"
        case let .initial(count): return "initial=\(count)"
        }
    }
}

enum OwnerVerification: Decodable, Hashable {
    case verified
    case failed(reason: String)
}

enum ConnectionPlan: Decodable, Hashable {
    case invitationLink(invitationLinkPlan: InvitationLinkPlan)
    case contactAddress(contactAddressPlan: ContactAddressPlan)
    case groupLink(groupLinkPlan: GroupLinkPlan)
    case error(chatError: ChatError)
}

enum InvitationLinkPlan: Decodable, Hashable {
    case ok(contactSLinkData_: ContactShortLinkData?, ownerVerification: OwnerVerification?)
    case ownLink
    case connecting(contact_: Contact?)
    case known(contact: Contact)
}

enum ContactAddressPlan: Decodable, Hashable {
    case ok(contactSLinkData_: ContactShortLinkData?, ownerVerification: OwnerVerification?)
    case ownLink
    case connectingConfirmReconnect
    case connectingProhibit(contact: Contact)
    case known(contact: Contact)
    case contactViaAddress(contact: Contact)
}

public struct GroupShortLinkInfo: Decodable, Hashable {
    public var direct: Bool
    public var groupRelays: [String]
    public var publicGroupId: String?
}

enum GroupLinkPlan: Decodable, Hashable {
    case ok(groupSLinkInfo_: GroupShortLinkInfo?, groupSLinkData_: GroupShortLinkData?, ownerVerification: OwnerVerification?)
    case ownLink(groupInfo: GroupInfo)
    case connectingConfirmReconnect
    case connectingProhibit(groupInfo_: GroupInfo?)
    case known(groupInfo: GroupInfo)
    case noRelays(groupSLinkData_: GroupShortLinkData?)
    case updateRequired(groupSLinkData_: GroupShortLinkData?)
}

struct ChatTagData: Encodable {
    var emoji: String?
    var text: String
}

struct UpdatedMessage: Encodable {
    var msgContent: MsgContent
    var mentions: [String: Int64]

    var cmdString: String {
        "json \(encodeJSON(self))"
    }
}

enum ChatDeleteMode: Codable {
    case full(notify: Bool)
    case entity(notify: Bool)
    case messages

    var cmdString: String {
        switch self {
        case let .full(notify): "full notify=\(onOff(notify))"
        case let .entity(notify): "entity notify=\(onOff(notify))"
        case .messages: "messages"
        }
    }

    var isEntity: Bool {
        switch self {
        case .entity: return true
        default: return false
        }
    }
}

enum ForwardConfirmation: Decodable, Hashable {
    case filesNotAccepted(fileIds: [Int64])
    case filesInProgress(filesCount: Int)
    case filesMissing(filesCount: Int)
    case filesFailed(filesCount: Int)
}

struct UserMsgReceiptSettings: Codable {
    var enable: Bool
    var clearOverrides: Bool
}

protocol PopopxAddress {
    var connLinkContact: CreatedConnLink { get }
    var shortLinkDataSet: Bool { get }
    var shortLinkLargeDataSet: Bool { get }
}

extension PopopxAddress {
    var shouldBeUpgraded: Bool {
        connLinkContact.connShortLink == nil || !shortLinkDataSet || !shortLinkLargeDataSet
    }

    func shareAddress(short: Bool) {
        showShareSheet(items: [popopxChatLink(connLinkContact.popopxChatUri(short: short))])
    }
}

struct UserContactLink: Decodable, Hashable, PopopxAddress {
    var connLinkContact: CreatedConnLink
    var shortLinkDataSet: Bool
    var shortLinkLargeDataSet: Bool
    var addressSettings: AddressSettings

    init(_ ccLink: CreatedConnLink) {
        connLinkContact = ccLink
        let slDataSet = ccLink.connShortLink != nil
        shortLinkDataSet = slDataSet
        shortLinkLargeDataSet = slDataSet
        addressSettings = AddressSettings(businessAddress: false)
    }
}

struct AddressSettings: Codable, Hashable {
    var businessAddress: Bool
    var autoAccept: AutoAccept?
    var autoReply: MsgContent?
}

struct AutoAccept: Codable, Hashable {
    var acceptIncognito: Bool
}

struct GroupLink: Decodable, Hashable, PopopxAddress {
    var userContactLinkId: Int64
    var connLinkContact: CreatedConnLink
    var shortLinkDataSet: Bool
    var shortLinkLargeDataSet: Bool
    var groupLinkId: String
    var acceptMemberRole: GroupMemberRole
}

struct DeviceToken: Decodable {
    var pushProvider: PushProvider
    var token: String

    var cmdString: String {
        "\(pushProvider) \(token)"
    }
}

enum PushEnvironment: String {
    case development
    case production
}

enum PushProvider: String, Decodable {
    case apns_dev
    case apns_prod

    init(env: PushEnvironment) {
        switch env {
        case .development: self = .apns_dev
        case .production: self = .apns_prod
        }
    }
}

// This notification mode is for app core, UI uses AppNotificationsMode.off to mean completely disable,
// and .local for periodic background checks
enum NotificationsMode: String, Decodable, SelectableItem {
    case off = "OFF"
    case periodic = "PERIODIC"
    case instant = "INSTANT"

    var label: LocalizedStringKey {
        switch self {
        case .off: LocalizedStringKey(NSLocalizedString("No push server", comment: ""))
        case .periodic: LocalizedStringKey(NSLocalizedString("Periodic", comment: ""))
        case .instant: LocalizedStringKey(NSLocalizedString("Instant", comment: ""))
        }
    }

    var icon: String {
        switch self {
        case .off: return "arrow.clockwise"
        case .periodic: return "timer"
        case .instant: return "bolt"
        }
    }

    var id: String { self.rawValue }

    static var values: [NotificationsMode] = [.instant, .periodic, .off]
}

struct RemoteCtrlInfo: Decodable {
    var remoteCtrlId: Int64
    var ctrlDeviceName: String
    var sessionState: RemoteCtrlSessionState?

    var deviceViewName: String {
        ctrlDeviceName == "" ? "\(remoteCtrlId)" : ctrlDeviceName
    }
}

enum RemoteCtrlSessionState: Decodable {
    case starting
    case searching
    case connecting
    case pendingConfirmation(sessionCode: String)
    case connected(sessionCode: String)

    private enum CodingKeys: String, CodingKey { case _owsf, starting, searching, connecting, pendingConfirmation, connected }
    private enum DataKeys: String, CodingKey { case sessionCode }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(._owsf) {
            let key = try c.allKeys.first { $0.stringValue != "_owsf" }
            switch key?.stringValue {
            case "starting": self = .starting
            case "searching": self = .searching
            case "connecting": self = .connecting
            case "pendingConfirmation":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .pendingConfirmation(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
            case "connected":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .connected(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
            default: self = .starting
            }
        } else if c.contains(.starting) { self = .starting
        } else if c.contains(.searching) { self = .searching
        } else if c.contains(.connecting) { self = .connecting
        } else if c.contains(.pendingConfirmation) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .pendingConfirmation)
            self = .pendingConfirmation(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
        } else if c.contains(.connected) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .connected)
            self = .connected(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
        } else {
            self = .starting
        }
    }
}

enum RemoteCtrlStopReason: Decodable {
    case discoveryFailed(chatError: ChatError)
    case connectionFailed(chatError: ChatError)
    case setupFailed(chatError: ChatError)
    case disconnected

    private enum CodingKeys: String, CodingKey { case _owsf, discoveryFailed, connectionFailed, setupFailed, disconnected }
    private enum DataKeys: String, CodingKey { case chatError }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(._owsf) {
            let key = try c.allKeys.first { $0.stringValue != "_owsf" }
            switch key?.stringValue {
            case "discoveryFailed":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .discoveryFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
            case "connectionFailed":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .connectionFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
            case "setupFailed":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .setupFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
            default: self = .disconnected
            }
        } else if c.contains(.discoveryFailed) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .discoveryFailed)
            self = .discoveryFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
        } else if c.contains(.connectionFailed) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .connectionFailed)
            self = .connectionFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
        } else if c.contains(.setupFailed) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .setupFailed)
            self = .setupFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
        } else {
            self = .disconnected
        }
    }
}

enum RHKey: Decodable, Hashable {
    case rhNew
    case rhId(remoteHostId: Int64)

    private enum CodingKeys: String, CodingKey { case _owsf, rhNew, rhId }
    private enum DataKeys: String, CodingKey { case remoteHostId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(._owsf) {
            if let allKeys = try? c.allKeys.first(where: { $0.stringValue != "_owsf" }) {
                switch allKeys.stringValue {
                case "rhNew": self = .rhNew
                case "rhId":
                    let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: allKeys)
                    self = .rhId(remoteHostId: try nested.decode(Int64.self, forKey: .remoteHostId))
                default: self = .rhNew
                }
            } else { self = .rhNew }
        } else if c.contains(.rhNew) {
            self = .rhNew
        } else if c.contains(.rhId) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .rhId)
            self = .rhId(remoteHostId: try nested.decode(Int64.self, forKey: .remoteHostId))
        } else {
            self = .rhNew
        }
    }
}

struct RemoteHostInfo: Decodable {
    var remoteHostId: Int64
    var hostDeviceName: String
    var sessionState: RemoteHostSessionState?
}

enum RemoteHostSessionState: Decodable {
    case starting
    case connecting(invitation: String)
    case pendingConfirmation(sessionCode: String)
    case confirmed(sessionCode: String)
    case connected(sessionCode: String)

    private enum CodingKeys: String, CodingKey { case _owsf, starting, connecting, pendingConfirmation, confirmed, connected }
    private enum DataKeys: String, CodingKey { case invitation, sessionCode }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(._owsf) {
            let key = try c.allKeys.first { $0.stringValue != "_owsf" }
            switch key?.stringValue {
            case "starting": self = .starting
            case "connecting":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .connecting(invitation: try nested.decode(String.self, forKey: .invitation))
            case "pendingConfirmation":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .pendingConfirmation(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
            case "confirmed":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .confirmed(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
            case "connected":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .connected(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
            default: self = .starting
            }
        } else if c.contains(.starting) {
            self = .starting
        } else if c.contains(.connecting) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .connecting)
            self = .connecting(invitation: try nested.decode(String.self, forKey: .invitation))
        } else if c.contains(.pendingConfirmation) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .pendingConfirmation)
            self = .pendingConfirmation(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
        } else if c.contains(.confirmed) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .confirmed)
            self = .confirmed(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
        } else if c.contains(.connected) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .connected)
            self = .connected(sessionCode: try nested.decode(String.self, forKey: .sessionCode))
        } else {
            self = .starting
        }
    }
}

enum RemoteHostError: Decodable, Hashable {
    case missing
    case inactive
    case busy
    case timeout
    case badState
    case badVersion(appVersion: String)
    case localCommand
    case disconnected(reason: String)
    case protocolError(protocolErr: ProtocolErrorType)

    private enum CodingKeys: String, CodingKey {
        case _owsf, missing, inactive, busy, timeout, badState, badVersion, localCommand, disconnected, protocolError
    }
    private enum DataKeys: String, CodingKey { case appVersion, reason, protocolErr }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(._owsf) {
            let key = try c.allKeys.first { $0.stringValue != "_owsf" }
            switch key?.stringValue {
            case "missing": self = .missing
            case "inactive": self = .inactive
            case "busy": self = .busy
            case "timeout": self = .timeout
            case "badState": self = .badState
            case "badVersion":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .badVersion(appVersion: try nested.decode(String.self, forKey: .appVersion))
            case "localCommand": self = .localCommand
            case "disconnected":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .disconnected(reason: try nested.decode(String.self, forKey: .reason))
            case "protocolError":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .protocolError(protocolErr: try nested.decode(ProtocolErrorType.self, forKey: .protocolErr))
            default: self = .missing
            }
        } else if c.contains(.missing) { self = .missing
        } else if c.contains(.inactive) { self = .inactive
        } else if c.contains(.busy) { self = .busy
        } else if c.contains(.timeout) { self = .timeout
        } else if c.contains(.badState) { self = .badState
        } else if c.contains(.badVersion) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .badVersion)
            self = .badVersion(appVersion: try nested.decode(String.self, forKey: .appVersion))
        } else if c.contains(.localCommand) { self = .localCommand
        } else if c.contains(.disconnected) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .disconnected)
            self = .disconnected(reason: try nested.decode(String.self, forKey: .reason))
        } else if c.contains(.protocolError) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .protocolError)
            self = .protocolError(protocolErr: try nested.decode(ProtocolErrorType.self, forKey: .protocolErr))
        } else {
            self = .missing
        }
    }
}

enum RemoteHostStopReason: Decodable {
    case connectionFailed(chatError: ChatError)
    case crashed(chatError: ChatError)
    case disconnected

    private enum CodingKeys: String, CodingKey { case _owsf, connectionFailed, crashed, disconnected }
    private enum DataKeys: String, CodingKey { case chatError }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(._owsf) {
            let key = try c.allKeys.first { $0.stringValue != "_owsf" }
            switch key?.stringValue {
            case "connectionFailed":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .connectionFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
            case "crashed":
                let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: key!)
                self = .crashed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
            default: self = .disconnected
            }
        } else if c.contains(.connectionFailed) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .connectionFailed)
            self = .connectionFailed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
        } else if c.contains(.crashed) {
            let nested = try c.nestedContainer(keyedBy: DataKeys.self, forKey: .crashed)
            self = .crashed(chatError: try nested.decode(ChatError.self, forKey: .chatError))
        } else {
            self = .disconnected
        }
    }
}

struct CtrlAppInfo: Decodable {
    var appVersionRange: AppVersionRange
    var deviceName: String
}

struct AppVersionRange: Decodable {
    var minVersion: String
    var maxVersion: String
}

struct CoreVersionInfo: Decodable {
    var version: String
    var popopxmqVersion: String
    var popopxmqCommit: String
}

struct ArchiveConfig: Encodable {
    var archivePath: String
    var disableCompression: Bool?
}

struct DBEncryptionConfig: Codable {
    var currentKey: String
    var newKey: String
}

enum OperatorTag: String, Codable {
    case flux = "flux"
    case popopx = "popopx"
}

struct ServerOperatorInfo {
    var description: [String]
    var website: URL
    var selfhost: (text: String, link: URL)? = nil
    var logo: String
    var largeLogo: String
    var logoDarkMode: String
    var largeLogoDarkMode: String
}

let operatorsInfo: Dictionary<OperatorTag, ServerOperatorInfo> = [
    .flux: ServerOperatorInfo(
        description: [
            "Flux is the largest decentralized cloud, based on a global network of user-operated nodes.",
            "Flux offers a powerful, scalable, and affordable cutting edge technology platform for all.",
            "Flux operates servers in POPOPX network to improve its privacy and decentralization."
        ],
        website: URL(string: "https://runonflux.com") ?? URL(fileURLWithPath: "/dev/null"),
        selfhost: (text: "Self-host POPOPX servers on Flux", link: URL(string: "https://home.runonflux.io/apps/marketplace?q=popopx") ?? URL(fileURLWithPath: "/dev/null")),
        logo: "flux_logo_symbol",
        largeLogo: "flux_logo",
        logoDarkMode: "flux_logo_symbol",
        largeLogoDarkMode: "flux_logo-light"
    ),
    .popopx: ServerOperatorInfo(
        description: [
            "POPOPX Chat is a decentralized communication operator running infrastructure on POPOPX network.",
            "POPOPX Chat Ltd operates SMP, XFTP, and chat relay servers for message routing and file storage."
        ],
        website: URL(string: "https://popopxchat.com") ?? URL(fileURLWithPath: "/dev/null"),
        logo: "popopx_app_icon",
        largeLogo: "logo",
        logoDarkMode: "popopx_app_icon",
        largeLogoDarkMode: "logo"
    ),
]

struct UsageConditions: Decodable {
    var conditionsId: Int64 = 0
    var conditionsCommit: String = ""
    var notifiedAt: Date?
    var createdAt: Date = Date.distantPast

    static var sampleData = UsageConditions(
        conditionsId: 1,
        conditionsCommit: "11a44dc1fd461a93079f897048b46998db55da5c",
        notifiedAt: nil,
        createdAt: Date.now
    )
}

enum UsageConditionsAction: Decodable {
    case review(operators: [ServerOperator], deadline: Date?, showNotice: Bool)
    case accepted(operators: [ServerOperator])

    var showNotice: Bool {
        switch self {
        case let .review(_, _, showNotice): showNotice
        case .accepted: false
        }
    }
}

struct ServerOperatorConditions: Decodable {
    var serverOperators: [ServerOperator]
    var currentConditions: UsageConditions
    var conditionsAction: UsageConditionsAction?

    static var empty = ServerOperatorConditions(
        serverOperators: [],
        currentConditions: UsageConditions(conditionsId: 0, conditionsCommit: "empty", notifiedAt: nil, createdAt: .now),
        conditionsAction: nil
    )
}

private func parseServerRoles(_ dict: NSDictionary) -> ServerRoles {
    ServerRoles(
        storage: dict["storage"] as? Bool ?? false,
        proxy: dict["proxy"] as? Bool ?? false,
        names: dict["names"] as? Bool ?? false
    )
}

private func parseConditionsAcceptance(_ dict: NSDictionary) -> ConditionsAcceptance {
    let inner = dict["_owsf"] as? NSDictionary ?? dict
    if let jAccepted = inner["accepted"] as? NSDictionary {
        let acceptedAt = parseISODate(jAccepted["acceptedAt"])
        let autoAccepted = jAccepted["autoAccepted"] as? Bool ?? false
        return .accepted(acceptedAt: acceptedAt, autoAccepted: autoAccepted)
    } else if let jRequired = inner["required"] as? NSDictionary {
        let deadline = parseISODate(jRequired["deadline"])
        return .required(deadline: deadline)
    }
    return .required(deadline: nil)
}

private func parseServerOperator(_ jOp: NSDictionary) -> ServerOperator? {
    guard let operatorId = jOp["operatorId"] as? Int64,
          let tradeName = jOp["tradeName"] as? String,
          let serverDomains = jOp["serverDomains"] as? [String],
          let enabled = jOp["enabled"] as? Bool else { return nil }

    let operatorTag: OperatorTag? = (jOp["operatorTag"] as? String).flatMap { OperatorTag(rawValue: $0) }
    let legalName = jOp["legalName"] as? String

    let conditionsAcceptance: ConditionsAcceptance
    if let jAcceptance = jOp["conditionsAcceptance"] as? NSDictionary {
        conditionsAcceptance = parseConditionsAcceptance(jAcceptance)
    } else {
        conditionsAcceptance = .required(deadline: nil)
    }

    let smpRoles = (jOp["smpRoles"] as? NSDictionary).map { parseServerRoles($0) } ?? ServerRoles(storage: false, proxy: false, names: false)
    let xftpRoles = (jOp["xftpRoles"] as? NSDictionary).map { parseServerRoles($0) } ?? ServerRoles(storage: false, proxy: false, names: false)

    return ServerOperator(
        operatorId: operatorId,
        operatorTag: operatorTag,
        tradeName: tradeName,
        legalName: legalName,
        serverDomains: serverDomains,
        conditionsAcceptance: conditionsAcceptance,
        enabled: enabled,
        smpRoles: smpRoles,
        xftpRoles: xftpRoles
    )
}

private func parseUsageConditionsAction(_ dict: NSDictionary) -> UsageConditionsAction? {
    let inner = dict["_owsf"] as? NSDictionary ?? dict
    if let jReview = inner["review"] as? NSDictionary {
        let ops: [ServerOperator]
        if let jOps = jReview["operators"] as? [NSDictionary] {
            ops = jOps.compactMap { parseServerOperator($0) }
        } else {
            ops = []
        }
        let deadline = parseISODate(jReview["deadline"])
        let showNotice = jReview["showNotice"] as? Bool ?? false
        return .review(operators: ops, deadline: deadline, showNotice: showNotice)
    } else if let jAccepted = inner["accepted"] as? NSDictionary {
        let ops: [ServerOperator]
        if let jOps = jAccepted["operators"] as? [NSDictionary] {
            ops = jOps.compactMap { parseServerOperator($0) }
        } else {
            ops = []
        }
        return .accepted(operators: ops)
    }
    return nil
}

func parseServerOperatorConditions(_ json: NSDictionary) -> ServerOperatorConditions? {
    guard let jWrapper = json["serverOperatorConditions"] as? NSDictionary else {
        logger.warning("parseServerOperatorConditions: missing serverOperatorConditions key")
        return nil
    }
    guard let jConditions = jWrapper["conditions"] as? NSDictionary else {
        logger.warning("parseServerOperatorConditions: missing conditions key inside wrapper")
        return nil
    }

    let serverOperators: [ServerOperator]
    if let jOps = jConditions["serverOperators"] as? [NSDictionary] {
        serverOperators = jOps.compactMap { parseServerOperator($0) }
    } else {
        serverOperators = []
    }

    let currentConditions: UsageConditions
    if let jCurrent = jConditions["currentConditions"] as? NSDictionary,
       let conditionsId = jCurrent["conditionsId"] as? Int64,
       let conditionsCommit = jCurrent["conditionsCommit"] as? String {
        let createdAt = parseISODate(jCurrent["createdAt"]) ?? .now
        let notifiedAt = parseISODate(jCurrent["notifiedAt"])
        currentConditions = UsageConditions(
            conditionsId: conditionsId,
            conditionsCommit: conditionsCommit,
            notifiedAt: notifiedAt,
            createdAt: createdAt
        )
    } else {
        currentConditions = UsageConditions(conditionsId: 0, conditionsCommit: "empty", notifiedAt: nil, createdAt: .now)
    }

    let conditionsAction: UsageConditionsAction?
    if let jAction = jConditions["conditionsAction"] as? NSDictionary {
        conditionsAction = parseUsageConditionsAction(jAction)
    } else {
        conditionsAction = nil
    }

    return ServerOperatorConditions(
        serverOperators: serverOperators,
        currentConditions: currentConditions,
        conditionsAction: conditionsAction
    )
}

private func parseISODate(_ value: Any?) -> Date? {
    guard let str = value as? String else { return value as? Date }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: str) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: str)
}

private func parseUserServer(_ jServer: NSDictionary) -> UserServer? {
    let serverId = jServer["serverId"] as? Int64
    guard let server = jServer["server"] as? String,
          let preset = jServer["preset"] as? Bool,
          let enabled = jServer["enabled"] as? Bool,
          let deleted = jServer["deleted"] as? Bool else { return nil }
    let tested = jServer["tested"] as? Bool
    
    // Parse roles field (ServerRolesOverride) - added in commit 2ea5940e8
    var roles = ServerRolesOverride.default
    if let jRoles = jServer["roles"] as? NSDictionary {
        roles = ServerRolesOverride(
            storage: jRoles["storage"] as? Bool,
            proxy: jRoles["proxy"] as? Bool,
            names: jRoles["names"] as? Bool
        )
    }
    
    let createdAt = parseISODate(jServer["createdAt"]) ?? .now
    return UserServer(
        serverId: serverId,
        server: server,
        preset: preset,
        tested: tested,
        enabled: enabled,
        roles: roles,
        deleted: deleted,
        createdAt: createdAt
    )
}

private func parseUserChatRelay(_ jRelay: NSDictionary) -> UserChatRelay? {
    let chatRelayId = jRelay["chatRelayId"] as? Int64
    guard let address = jRelay["address"] as? String,
          let domains = jRelay["domains"] as? [String],
          let preset = jRelay["preset"] as? Bool,
          let enabled = jRelay["enabled"] as? Bool,
          let deleted = jRelay["deleted"] as? Bool else { return nil }
    let tested = jRelay["tested"] as? Bool
    let name: String
    if let profile = jRelay["relayProfile"] as? NSDictionary {
        name = profile["displayName"] as? String ?? ""
    } else {
        name = ""
    }
    let createdAt = parseISODate(jRelay["createdAt"]) ?? .now
    return UserChatRelay(
        chatRelayId: chatRelayId,
        address: address,
        name: name,
        domains: domains,
        preset: preset,
        tested: tested,
        enabled: enabled,
        deleted: deleted,
        createdAt: createdAt
    )
}

private func parseUserOperatorServers(_ jOpServers: NSDictionary) -> UserOperatorServers? {
    let operator_: ServerOperator?
    if let jOp = jOpServers["operator"] as? NSDictionary {
        operator_ = parseServerOperator(jOp)
    } else {
        operator_ = nil
    }

    let smpServers: [UserServer]
    if let jServers = jOpServers["smpServers"] as? [NSDictionary] {
        smpServers = jServers.compactMap { parseUserServer($0) }
    } else {
        smpServers = []
    }

    let xftpServers: [UserServer]
    if let jServers = jOpServers["xftpServers"] as? [NSDictionary] {
        xftpServers = jServers.compactMap { parseUserServer($0) }
    } else {
        xftpServers = []
    }

    let chatRelays: [UserChatRelay]
    if let jRelays = jOpServers["chatRelays"] as? [NSDictionary] {
        chatRelays = jRelays.compactMap { parseUserChatRelay($0) }
    } else {
        chatRelays = []
    }

    return UserOperatorServers(
        operator: operator_,
        smpServers: smpServers,
        xftpServers: xftpServers,
        chatRelays: chatRelays
    )
}

func parseUserServers(_ json: NSDictionary) -> (UserRef, [UserOperatorServers])? {
    guard let jUserServers = json["userServers"] as? NSDictionary else { return nil }
    guard let jUser = jUserServers["user"] as? NSDictionary,
          let user: UserRef = try? decodeObject(jUser) else { return nil }

    let servers: [UserOperatorServers]
    if let jOps = jUserServers["userServers"] as? [NSDictionary] {
        servers = jOps.compactMap { parseUserOperatorServers($0) }
    } else {
        servers = []
    }

    return (user, servers)
}

// MARK: - ConnStatus Parser

private func parseConnStatus(_ jStatus: NSDictionary) -> ConnStatus? {
    if jStatus["new"] is NSDictionary {
        return .new
    } else if jStatus["prepared"] is NSDictionary {
        return .prepared
    } else if jStatus["joined"] is NSDictionary {
        return .joined
    } else if jStatus["requested"] is NSDictionary {
        return .requested
    } else if jStatus["accepted"] is NSDictionary {
        return .accepted
    } else if jStatus["sndReady"] is NSDictionary {
        return .sndReady
    } else if jStatus["ready"] is NSDictionary {
        return .ready
    } else if jStatus["deleted"] is NSDictionary {
        return .deleted
    } else if let jFailed = jStatus["failed"] as? NSDictionary {
        let connError = jFailed["connError"] as? String ?? ""
        return .failed(connError: connError)
    }
    return nil
}

// MARK: - InvitedBy Parser

private func parseInvitedBy(_ jInvited: NSDictionary) -> InvitedBy? {
    if let jContact = jInvited["contact"] as? NSDictionary {
        let byContactId = jContact["byContactId"] as? Int64 ?? 0
        return .contact(byContactId: byContactId)
    } else if let _ = jInvited["user"] as? NSDictionary {
        return .user
    } else if let _ = jInvited["unknown"] as? NSDictionary {
        return .unknown
    }
    return nil
}

// MARK: - Connection Parser

private func parseConnection(_ jConn: NSDictionary) -> Connection? {
    if let data = try? JSONSerialization.data(withJSONObject: jConn, options: []) {
        return try? jsonDecoder.decode(Connection.self, from: data)
    }
    return nil
}

// MARK: - Contact Parser

private func parseContact(_ jContact: NSDictionary) -> Contact? {
    if let data = try? JSONSerialization.data(withJSONObject: jContact, options: []) {
        if let contact = try? jsonDecoder.decode(Contact.self, from: data) {
            return contact
        }
    }
    return nil
}

// MARK: - GroupMember Parser

private func parseGroupMember(_ jMember: NSDictionary) -> GroupMember? {
    if let data = try? JSONSerialization.data(withJSONObject: jMember, options: []) {
        if let member = try? jsonDecoder.decode(GroupMember.self, from: data) {
            return member
        }
    }
    return nil
}

// MARK: - GroupInfo Parser

private func parseGroupInfo(_ jGroupInfo: NSDictionary) -> GroupInfo? {
    if let data = try? JSONSerialization.data(withJSONObject: jGroupInfo, options: []) {
        if let groupInfo = try? jsonDecoder.decode(GroupInfo.self, from: data) {
            return groupInfo
        }
    }
    return nil
}

// MARK: - Response Parsers

func parseContactInfo(_ json: NSDictionary) -> (UserRef, Contact, ConnectionStats?, Profile?)? {
    guard let jContactInfo = json["contactInfo"] as? NSDictionary else { return nil }
    guard let jUser = jContactInfo["user"] as? NSDictionary,
          let user: UserRef = try? decodeObject(jUser) else { return nil }
    guard let jContact = jContactInfo["contact"] as? NSDictionary,
          let contact = parseContact(jContact) else { return nil }

    let connStats: ConnectionStats?
    if let jStats = jContactInfo["connectionStats_"] as? NSDictionary,
       let data = try? JSONSerialization.data(withJSONObject: jStats, options: []) {
        connStats = try? jsonDecoder.decode(ConnectionStats.self, from: data)
    } else {
        connStats = nil
    }

    let profile: Profile?
    if let jProfile = jContactInfo["customUserProfile"] as? NSDictionary,
       let data = try? JSONSerialization.data(withJSONObject: jProfile, options: []) {
        profile = try? jsonDecoder.decode(Profile.self, from: data)
    } else {
        profile = nil
    }

    return (user, contact, connStats, profile)
}

func parseGroupInfoResponse(_ json: NSDictionary) -> (UserRef, GroupInfo)? {
    guard let jGroupInfo = json["groupInfo"] as? NSDictionary else { return nil }
    guard let jUser = jGroupInfo["user"] as? NSDictionary,
          let user: UserRef = try? decodeObject(jUser) else { return nil }
    guard let jInfo = jGroupInfo["groupInfo"] as? NSDictionary,
          let groupInfo = parseGroupInfo(jInfo) else { return nil }

    return (user, groupInfo)
}

func parseGroupMemberInfo(_ json: NSDictionary) -> (UserRef, GroupInfo, GroupMember, ConnectionStats?)? {
    guard let jMemberInfo = json["groupMemberInfo"] as? NSDictionary else { return nil }
    guard let jUser = jMemberInfo["user"] as? NSDictionary,
          let user: UserRef = try? decodeObject(jUser) else { return nil }
    guard let jInfo = jMemberInfo["groupInfo"] as? NSDictionary,
          let groupInfo = parseGroupInfo(jInfo) else { return nil }
    guard let jMember = jMemberInfo["member"] as? NSDictionary,
          let member = parseGroupMember(jMember) else { return nil }

    let connStats: ConnectionStats?
    if let jStats = jMemberInfo["connectionStats_"] as? NSDictionary,
       let data = try? JSONSerialization.data(withJSONObject: jStats, options: []) {
        connStats = try? jsonDecoder.decode(ConnectionStats.self, from: data)
    } else {
        connStats = nil
    }

    return (user, groupInfo, member, connStats)
}

enum ConditionsAcceptance: Equatable, Codable, Hashable {
    case accepted(acceptedAt: Date?, autoAccepted: Bool)
    // If deadline is present, it means there's a grace period to review and accept conditions during which user can continue to use the operator.
    // No deadline indicates it's required to accept conditions for the operator to start using it.
    case required(deadline: Date?)

    var conditionsAccepted: Bool {
        switch self {
        case .accepted: true
        case .required: false
        }
    }

    var usageAllowed: Bool {
        switch self {
        case .accepted: true
        case let .required(deadline): deadline != nil
        }
    }
}

struct ServerOperator: Identifiable, Equatable, Codable {
    var operatorId: Int64
    var operatorTag: OperatorTag?
    var tradeName: String
    var legalName: String?
    var serverDomains: [String]
    var conditionsAcceptance: ConditionsAcceptance
    var enabled: Bool
    var smpRoles: ServerRoles
    var xftpRoles: ServerRoles

    var id: Int64 { operatorId }

    static func == (l: ServerOperator, r: ServerOperator) -> Bool {
        l.operatorId == r.operatorId && l.operatorTag == r.operatorTag && l.tradeName == r.tradeName && l.legalName == r.legalName &&
        l.serverDomains == r.serverDomains && l.conditionsAcceptance == r.conditionsAcceptance && l.enabled == r.enabled &&
        l.smpRoles == r.smpRoles && l.xftpRoles == r.xftpRoles
    }

    var legalName_: String {
        legalName ?? tradeName
    }

    var info: ServerOperatorInfo {
        return if let operatorTag = operatorTag {
            operatorsInfo[operatorTag] ?? ServerOperator.dummyOperatorInfo
        } else {
            ServerOperator.dummyOperatorInfo
        }
    }

    static let dummyOperatorInfo = ServerOperatorInfo(
        description: ["Default"],
        website: URL(string: "https://popopxchat.com") ?? URL(fileURLWithPath: "/dev/null"),
        logo: "logo-light",
        largeLogo: "logo",
        logoDarkMode: "logo-light",
        largeLogoDarkMode: "logo"
    )

    func logo(_ colorScheme: ColorScheme) -> String {
        colorScheme == .light ? info.logo : info.logoDarkMode
    }

    func largeLogo(_ colorScheme: ColorScheme) -> String {
        colorScheme == .light ? info.largeLogo : info.largeLogoDarkMode
    }

    static var sampleData1 = ServerOperator(
        operatorId: 1,
        operatorTag: .popopx,
        tradeName: "POPOPX Chat",
        legalName: "POPOPX Chat Ltd",
        serverDomains: ["popopxchat.com"],
        conditionsAcceptance: .accepted(acceptedAt: nil, autoAccepted: false),
        enabled: true,
        smpRoles: ServerRoles(storage: true, proxy: true, names: true),
        xftpRoles: ServerRoles(storage: true, proxy: true, names: true)
    )
}

struct ServerRoles: Equatable, Codable {
    var storage: Bool
    var proxy: Bool
    var names: Bool

    static let noOperatorDefault = ServerRoles(storage: false, proxy: false, names: false)
}

enum MsgSigStatus: String, Codable, Hashable {
    case verified = "verified"
    case signedNoKey = "signedNoKey"
}

struct UserOperatorServers: Identifiable, Equatable, Codable {
    var `operator`: ServerOperator?
    var smpServers: [UserServer]
    var xftpServers: [UserServer]
    var chatRelays: [UserChatRelay]

    var id: String {
        if let op = self.operator {
            "\(op.operatorId)"
        } else {
            "nil operator"
        }
    }

    var operator_: ServerOperator {
        get {
            self.operator ?? ServerOperator(
                operatorId: 0,
                operatorTag: nil,
                tradeName: "",
                legalName: "",
                serverDomains: [],
                conditionsAcceptance: .accepted(acceptedAt: nil, autoAccepted: false),
                enabled: false,
                smpRoles: ServerRoles(storage: true, proxy: true, names: true),
                xftpRoles: ServerRoles(storage: true, proxy: true, names: true)
            )
        }
        set { `operator` = newValue }
    }

    static var sampleData1 = UserOperatorServers(
        operator: ServerOperator.sampleData1,
        smpServers: [UserServer.sampleData.preset],
        xftpServers: [UserServer.sampleData.xftpPreset],
        chatRelays: []
    )

    static var sampleDataNilOperator = UserOperatorServers(
        operator: nil,
        smpServers: [UserServer.sampleData.preset],
        xftpServers: [UserServer.sampleData.xftpPreset],
        chatRelays: []
    )
}

// MARK: - BinThere Bot

struct BinThereBotInfo: Identifiable, Equatable, Codable {
    var botId: Int64
    var botAddress: String
    var botName: String?
    var botType: String
    var usageCount: Int64
    var description: String?
    var iconUrl: String?
    var tokenCount: Int64
    var pricingUnit: String?
    var pricingAmount: Int64

    var id: Int64 { botId }
}

struct BotDirectoryEntry: Identifiable, Equatable, Codable {
    var botAddress: String
    var botName: String
    var botType: String
    var description: String?
    var iconUrl: String?
    var tokenCount: Int64
    var pricingUnit: String?
    var pricingAmount: Int64

    var id: String { botAddress }

    enum CodingKeys: String, CodingKey {
        case botAddress = "bot_address"
        case botName = "bot_name"
        case botType = "bot_type"
        case description
        case iconUrl = "icon_url"
        case tokenCount = "token_count"
        case pricingUnit = "pricing_unit"
        case pricingAmount = "pricing_amount"
    }
}

// MARK: - Compute Purchase FFI types

struct ComputePurchaseFFI: Codable, Equatable {
    var transactionId: String
    var productId: String
    var purchaseType: String
    var tokenAmount: Double
    var priceUsd: Double
    var status: String
    var metadata: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case productId = "product_id"
        case purchaseType = "purchase_type"
        case tokenAmount = "token_amount"
        case priceUsd = "price_usd"
        case status
        case metadata
        case createdAt = "created_at"
    }
}

struct ComputeBalanceFFI: Codable, Equatable {
    var userId: Int64
    var balance: Double
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case balance
        case updatedAt = "updated_at"
    }
}

public enum UserServersWarning: Decodable {
    case noChatRelays(user: UserRef?)
    case noNamesServers(user: UserRef?)
}

enum UserServersError: Decodable {
    case noServers(protocol: ServerProtocol, user: UserRef?)
    case storageMissing(protocol: ServerProtocol, user: UserRef?)
    case proxyMissing(protocol: ServerProtocol, user: UserRef?)
    case duplicateServer(protocol: ServerProtocol, duplicateServer: String, duplicateHost: String)
    case tooManyHosts(protocol: ServerProtocol, tooManyHostsServer: String)
    case duplicateChatRelayAddress(duplicateChatRelay: String, duplicateAddress: String)

    var globalError: String? {
        switch self {
        case .tooManyHosts:
            return globalSMPError
        case let .noServers(`protocol`, _):
            switch `protocol` {
            case .smp: return globalSMPError
            case .xftp: return globalXFTPError
            }
        case let .storageMissing(`protocol`, _):
            switch `protocol` {
            case .smp: return globalSMPError
            case .xftp: return globalXFTPError
            }
        case let .proxyMissing(`protocol`, _):
            switch `protocol` {
            case .smp: return globalSMPError
            case .xftp: return globalXFTPError
            }
        default: return nil
        }
    }

    var globalSMPError: String? {
        switch self {
        case let .noServers(.smp, user):
            let text = NSLocalizedString("No message servers.", comment: "servers error")
            if let user = user {
                return userStr(user) + " " + text
            } else {
                return text
            }
        case let .storageMissing(.smp, user):
            let text = NSLocalizedString("No servers to receive messages.", comment: "servers error")
            if let user = user {
                return userStr(user) + " " + text
            } else {
                return text
            }
        case let .proxyMissing(.smp, user):
            let text = NSLocalizedString("No servers for private message routing.", comment: "servers error")
            if let user = user {
                return userStr(user) + " " + text
            } else {
                return text
            }
        case let .tooManyHosts(.smp, server):
            return String.localizedStringWithFormat(NSLocalizedString("Server %@ has more than two host names.", comment: "servers error"), serverHostname(server))
        default:
            return nil
        }
    }

    var globalXFTPError: String? {
        switch self {
        case let .noServers(.xftp, user):
            let text = NSLocalizedString("No media & file servers.", comment: "servers error")
            if let user = user {
                return userStr(user) + " " + text
            } else {
                return text
            }
        case let .storageMissing(.xftp, user):
            let text = NSLocalizedString("No servers to send files.", comment: "servers error")
            if let user = user {
                return userStr(user) + " " + text
            } else {
                return text
            }
        case let .proxyMissing(.xftp, user):
            let text = NSLocalizedString("No servers to receive files.", comment: "servers error")
            if let user = user {
                return userStr(user) + " " + text
            } else {
                return text
            }
        default:
            return nil
        }
    }

    private func userStr(_ user: UserRef) -> String {
        String.localizedStringWithFormat(NSLocalizedString("For chat profile %@:", comment: "servers error"), user.localDisplayName)
    }
}

// Server roles override - matches Haskell's ServerRolesOverride in Operators.hs
struct ServerRolesOverride: Codable, Hashable {
    var storage: Bool?
    var proxy: Bool?
    var names: Bool?
    
    static let `default` = ServerRolesOverride(storage: nil, proxy: nil, names: nil)

    init(storage: Bool? = nil, proxy: Bool? = nil, names: Bool? = nil) {
        self.storage = storage
        self.proxy = proxy
        self.names = names
    }

    enum CodingKeys: String, CodingKey {
        case storage
        case proxy
        case names
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.storage = try container.decodeIfPresent(Bool.self, forKey: .storage)
        self.proxy = try container.decodeIfPresent(Bool.self, forKey: .proxy)
        self.names = try container.decodeIfPresent(Bool.self, forKey: .names)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(storage, forKey: .storage)
        try container.encode(proxy, forKey: .proxy)
        try container.encode(names, forKey: .names)
    }
}

// MARK: - Server Information Types (from popopxmq library)

public struct ServerPublicInfo: Decodable, Hashable {
    public var sourceCode: String  // Required by AGPLv3 license
    public var usageConditions: ServerConditions?
    public var `operator`: Entity?
    public var website: String?
    public var adminContacts: ServerContactAddress?
    public var complaintsContacts: ServerContactAddress?
    public var hosting: Entity?
    public var hostingType: HostingType?
    public var serverCountry: String?
    
    enum CodingKeys: String, CodingKey {
        case sourceCode = "source_code"
        case usageConditions = "usage_conditions"
        case `operator`
        case website
        case adminContacts = "admin_contacts"
        case complaintsContacts = "complaints_contacts"
        case hosting
        case hostingType = "hosting_type"
        case serverCountry = "server_country"
    }
}

public struct ServerConditions: Decodable, Hashable {
    public var conditions: String
    public var amendments: String?
}

public enum HostingType: String, Decodable, Hashable {
    case virtual = "virtual"
    case dedicated = "dedicated"
    case colocation = "colocation"
    case owned = "owned"
}

public struct Entity: Decodable, Hashable {
    public var name: String
    public var country: String?
}

public struct ServerContactAddress: Decodable, Hashable {
    public var popopx: String?  // Connection link
    public var email: String?
    public var pgp: PGPKey?

    enum CodingKeys: String, CodingKey {
        case popopx
        case email
        case pgp
    }
}

public struct PGPKey: Decodable, Hashable {
    public var pkURI: String
    public var pkFingerprint: String
    
    enum CodingKeys: String, CodingKey {
        case pkURI = "pk_uri"
        case pkFingerprint = "pk_fingerprint"
    }
}

// Wrapper for Either<String, ServerPublicInfo> from Haskell
public enum ServerInfoEither: Decodable, Hashable {
    case left(String)   // Error message
    case right(ServerPublicInfo)  // Success with info
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as String first (error case)
        if let errorString = try? container.decode(String.self) {
            self = .left(errorString)
            return
        }
        
        // Try to decode as ServerPublicInfo (success case)
        if let info = try? container.decode(ServerPublicInfo.self) {
            self = .right(info)
            return
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected either String or ServerPublicInfo"
        )
    }
    
    public static func == (lhs: ServerInfoEither, rhs: ServerInfoEither) -> Bool {
        switch (lhs, rhs) {
        case let (.left(l), .left(r)):
            return l == r
        case let (.right(l), .right(r)):
            return l == r
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .left(let str):
            hasher.combine(0)
            hasher.combine(str)
        case .right(let info):
            hasher.combine(1)
            hasher.combine(info)
        }
    }
}

struct UserServer: Identifiable, Equatable, Codable, Hashable {
    var serverId: Int64?
    var server: String
    var preset: Bool
    var tested: Bool?
    var enabled: Bool
    var roles: ServerRolesOverride = .default
    var deleted: Bool
    var createdAt = Date()

    static func == (l: UserServer, r: UserServer) -> Bool {
        l.serverId == r.serverId && l.server == r.server && l.preset == r.preset && l.tested == r.tested &&
        l.enabled == r.enabled && l.roles == r.roles && l.deleted == r.deleted
    }

    var id: String { "\(server) \(createdAt)" }

    static var empty = UserServer(serverId: nil, server: "", preset: false, tested: nil, enabled: false, roles: .default, deleted: false)

    var isEmpty: Bool {
        server.trimmingCharacters(in: .whitespaces) == ""
    }

    struct SampleData {
        var preset: UserServer
        var custom: UserServer
        var untested: UserServer
        var xftpPreset: UserServer
    }

    static var sampleData = SampleData(
        preset: UserServer(
            serverId: 1,
            server: "smp://abcd@smp8.popopxchat.com",
            preset: true,
            tested: true,
            enabled: true,
            roles: .default,
            deleted: false
        ),
        custom: UserServer(
            serverId: 2,
            server: "smp://abcd@smp9.popopxchat.com",
            preset: false,
            tested: false,
            enabled: false,
            roles: .default,
            deleted: false
        ),
        untested: UserServer(
            serverId: 3,
            server: "smp://abcd@smp10.popopxchat.com",
            preset: false,
            tested: nil,
            enabled: true,
            roles: .default,
            deleted: false
        ),
        xftpPreset: UserServer(
            serverId: 4,
            server: "xftp://abcd@xftp8.popopxchat.com",
            preset: true,
            tested: true,
            enabled: true,
            roles: .default,
            deleted: false
        )
    )

    enum CodingKeys: CodingKey {
        case serverId
        case server
        case preset
        case tested
        case enabled
        case roles
        case deleted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serverId, forKey: .serverId)
        try container.encode(server, forKey: .server)
        try container.encode(preset, forKey: .preset)
        try container.encode(tested, forKey: .tested)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(roles, forKey: .roles)
        try container.encode(deleted, forKey: .deleted)
    }
}

struct RelayConnectionResult: Decodable {
    var relayMember: GroupMember
    var relayError: ChatError?
}

struct AddRelayResult: Decodable {
    var relay: UserChatRelay
    var relayError: ChatError?
}

enum ProtocolTestStep: String, Decodable, Equatable {
    case connect
    case disconnect
    case createQueue
    case secureQueue
    case deleteQueue
    case createFile
    case uploadFile
    case downloadFile
    case compareFile
    case deleteFile

    var text: String {
        switch self {
        case .connect: return NSLocalizedString("Connect", comment: "server test step")
        case .disconnect: return NSLocalizedString("Disconnect", comment: "server test step")
        case .createQueue: return NSLocalizedString("Create queue", comment: "server test step")
        case .secureQueue: return NSLocalizedString("Secure queue", comment: "server test step")
        case .deleteQueue: return NSLocalizedString("Delete queue", comment: "server test step")
        case .createFile: return NSLocalizedString("Create file", comment: "server test step")
        case .uploadFile: return NSLocalizedString("Upload file", comment: "server test step")
        case .downloadFile: return NSLocalizedString("Download file", comment: "server test step")
        case .compareFile: return NSLocalizedString("Compare file", comment: "server test step")
        case .deleteFile: return NSLocalizedString("Delete file", comment: "server test step")
        }
    }
}

struct ProtocolTestFailure: Decodable, Error, Equatable {
    var testStep: ProtocolTestStep
    var testError: AgentErrorType

    static func == (l: ProtocolTestFailure, r: ProtocolTestFailure) -> Bool {
        l.testStep == r.testStep
    }

    var localizedDescription: String {
        let err = String.localizedStringWithFormat(NSLocalizedString("Test failed at step %@.", comment: "server test failure"), testStep.text)
        switch testError {
        case .SMP(_, .AUTH):
            return err + " " + NSLocalizedString("Server requires authorization to create queues, check password.", comment: "server test error")
        case .XFTP(.AUTH):
            return err + " " + NSLocalizedString("Server requires authorization to upload, check password.", comment: "server test error")
        case .BROKER(_, .NETWORK(.unknownCAError)):
            return err + " " + NSLocalizedString("Fingerprint in server address does not match certificate.", comment: "server test error")
        default:
            return err + " " + String.localizedStringWithFormat(NSLocalizedString("Error: %@.", comment: "server test error"), String(describing: testError))
        }
    }
}

public enum RelayTestStep: String, Decodable {
    case getLink
    case decodeLink
    case connect
    case waitResponse
    case verify

    var text: String {
        switch self {
        case .getLink: return NSLocalizedString("Get link", comment: "relay test step")
        case .decodeLink: return NSLocalizedString("Decode link", comment: "relay test step")
        case .connect: return NSLocalizedString("Connect", comment: "relay test step")
        case .waitResponse: return NSLocalizedString("Wait response", comment: "relay test step")
        case .verify: return NSLocalizedString("Verify", comment: "relay test step")
        }
    }
}

public struct RelayTestFailure: Decodable, Error {
    public var rtfStep: RelayTestStep
    public var rtfError: ChatError

    var localizedDescription: String {
        let err = String.localizedStringWithFormat(NSLocalizedString("Test failed at step %@.", comment: "relay test failure"), rtfStep.text)
        switch rtfError {
        case .errorAgent(agentError: .SMP(_, .AUTH)):
            return err + " " + NSLocalizedString("Server requires authorization to connect to relay, check password.", comment: "relay test error")
        case .errorAgent(agentError: .BROKER(_, .NETWORK(.unknownCAError))):
            return err + " " + NSLocalizedString("Fingerprint in server address does not match certificate.", comment: "relay test error")
        default:
            return err + " " + String.localizedStringWithFormat(NSLocalizedString("Error: %@.", comment: "relay test error"), String(describing: rtfError))
        }
    }
}

struct MigrationFileLinkData: Codable {
    let networkConfig: NetworkConfig?

    struct NetworkConfig: Codable {
        let socksProxy: String?
        let networkProxy: NetworkProxy?
        let hostMode: HostMode?
        let requiredHostMode: Bool?

        func transformToPlatformSupported() -> NetworkConfig {
            return if let hostMode, let requiredHostMode {
                NetworkConfig(
                    socksProxy: nil,
                    networkProxy: nil,
                    hostMode: hostMode == .onionViaSocks ? .onionHost : hostMode,
                    requiredHostMode: requiredHostMode
                )
            } else { self }
        }
    }

    func addToLink(link: String) -> String {
        "\(link)&data=\(encodeJSON(self).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"
    }

    static func readFromLink(link: String) -> MigrationFileLinkData? {
//        standaloneFileInfo(link)
        nil
    }
}

struct AppSettings: Codable, Equatable {
    var networkConfig: NetCfg? = nil
    var networkProxy: NetworkProxy? = nil
    var privacyEncryptLocalFiles: Bool? = nil
    var privacyAskToApproveRelays: Bool? = nil
    var privacyAcceptImages: Bool? = nil
    var privacyLinkPreviews: Bool? = nil
    var privacySanitizeLinks: Bool? = nil
    var privacyShowChatPreviews: Bool? = nil
    var privacySaveLastDraft: Bool? = nil
    var privacyProtectScreen: Bool? = nil
    var privacyMediaBlurRadius: Int? = nil
    var notificationMode: AppSettingsNotificationMode? = nil
    var notificationPreviewMode: NotificationPreviewMode? = nil
    var webrtcPolicyRelay: Bool? = nil
    var webrtcICEServers: [String]? = nil
    var confirmRemoteSessions: Bool? = nil
    var developerTools: Bool? = nil
    var confirmDBUpgrades: Bool? = nil
    var androidCallOnLockScreen: AppSettingsLockScreenCalls? = nil
    var iosCallKitEnabled: Bool? = nil
    var iosCallKitCallsInRecents: Bool? = nil
    var uiProfileImageCornerRadius: Double? = nil
    var uiChatItemRoundness: Double? = nil
    var uiChatItemTail: Bool? = nil
    var uiColorScheme: String? = nil
    var uiDarkColorScheme: String? = nil
    var uiCurrentThemeIds: [String: String]? = nil
    var uiThemes: [ThemeOverrides]? = nil
    var oneHandUI: Bool? = nil
    var chatBottomBar: Bool? = nil

    func prepareForExport() -> AppSettings {
        var empty = AppSettings()
        let def = AppSettings.defaults
        if networkConfig != def.networkConfig { empty.networkConfig = networkConfig }
        if networkProxy != def.networkProxy { empty.networkProxy = networkProxy }
        if privacyEncryptLocalFiles != def.privacyEncryptLocalFiles { empty.privacyEncryptLocalFiles = privacyEncryptLocalFiles }
        if privacyAskToApproveRelays != def.privacyAskToApproveRelays { empty.privacyAskToApproveRelays = privacyAskToApproveRelays }
        if privacyAcceptImages != def.privacyAcceptImages { empty.privacyAcceptImages = privacyAcceptImages }
        if privacyLinkPreviews != def.privacyLinkPreviews { empty.privacyLinkPreviews = privacyLinkPreviews }
        if privacySanitizeLinks != def.privacySanitizeLinks { empty.privacySanitizeLinks = privacySanitizeLinks }
        if privacyShowChatPreviews != def.privacyShowChatPreviews { empty.privacyShowChatPreviews = privacyShowChatPreviews }
        if privacySaveLastDraft != def.privacySaveLastDraft { empty.privacySaveLastDraft = privacySaveLastDraft }
        if privacyProtectScreen != def.privacyProtectScreen { empty.privacyProtectScreen = privacyProtectScreen }
        if privacyMediaBlurRadius != def.privacyMediaBlurRadius { empty.privacyMediaBlurRadius = privacyMediaBlurRadius }
        if notificationMode != def.notificationMode { empty.notificationMode = notificationMode }
        if notificationPreviewMode != def.notificationPreviewMode { empty.notificationPreviewMode = notificationPreviewMode }
        if webrtcPolicyRelay != def.webrtcPolicyRelay { empty.webrtcPolicyRelay = webrtcPolicyRelay }
        if webrtcICEServers != def.webrtcICEServers { empty.webrtcICEServers = webrtcICEServers }
        if confirmRemoteSessions != def.confirmRemoteSessions { empty.confirmRemoteSessions = confirmRemoteSessions }
        if developerTools != def.developerTools { empty.developerTools = developerTools }
        if confirmDBUpgrades != def.confirmDBUpgrades { empty.confirmDBUpgrades = confirmDBUpgrades }
        if androidCallOnLockScreen != def.androidCallOnLockScreen { empty.androidCallOnLockScreen = androidCallOnLockScreen }
        if iosCallKitEnabled != def.iosCallKitEnabled { empty.iosCallKitEnabled = iosCallKitEnabled }
        if iosCallKitCallsInRecents != def.iosCallKitCallsInRecents { empty.iosCallKitCallsInRecents = iosCallKitCallsInRecents }
        if uiProfileImageCornerRadius != def.uiProfileImageCornerRadius { empty.uiProfileImageCornerRadius = uiProfileImageCornerRadius }
        if uiChatItemRoundness != def.uiChatItemRoundness { empty.uiChatItemRoundness = uiChatItemRoundness }
        if uiChatItemTail != def.uiChatItemTail { empty.uiChatItemTail = uiChatItemTail }
        if uiColorScheme != def.uiColorScheme { empty.uiColorScheme = uiColorScheme }
        if uiDarkColorScheme != def.uiDarkColorScheme { empty.uiDarkColorScheme = uiDarkColorScheme }
        if uiCurrentThemeIds != def.uiCurrentThemeIds { empty.uiCurrentThemeIds = uiCurrentThemeIds }
        if uiThemes != def.uiThemes { empty.uiThemes = uiThemes }
        if oneHandUI != def.oneHandUI { empty.oneHandUI = oneHandUI }
        if chatBottomBar != def.chatBottomBar { empty.chatBottomBar = chatBottomBar }
        return empty
    }

    static var defaults: AppSettings {
        AppSettings (
            networkConfig: NetCfg.defaults,
            networkProxy: NetworkProxy.def,
            privacyEncryptLocalFiles: true,
            privacyAskToApproveRelays: true,
            privacyAcceptImages: true,
            privacyLinkPreviews: true,
            privacySanitizeLinks: false,
            privacyShowChatPreviews: true,
            privacySaveLastDraft: true,
            privacyProtectScreen: false,
            privacyMediaBlurRadius: 0,
            notificationMode: AppSettingsNotificationMode.instant,
            notificationPreviewMode: NotificationPreviewMode.message,
            webrtcPolicyRelay: true,
            webrtcICEServers: [],
            confirmRemoteSessions: false,
            developerTools: false,
            confirmDBUpgrades: false,
            androidCallOnLockScreen: AppSettingsLockScreenCalls.show,
            iosCallKitEnabled: true,
            iosCallKitCallsInRecents: false,
            uiProfileImageCornerRadius: 22.5,
            uiChatItemRoundness: 0.75,
            uiChatItemTail: true,
            uiColorScheme: DefaultTheme.DARK.themeName,
            uiDarkColorScheme: DefaultTheme.DARK.themeName,
            uiCurrentThemeIds: nil as [String: String]?,
            uiThemes: nil as [ThemeOverrides]?,
            oneHandUI: true,
            chatBottomBar: true
        )
    }
}

enum AppSettingsNotificationMode: String, Codable {
    case off
    case periodic
    case instant

    func toNotificationsMode() -> NotificationsMode {
        switch self {
        case .instant: .instant
        case .periodic: .periodic
        case .off: .off
        }
    }

    static func from(_ mode: NotificationsMode) -> AppSettingsNotificationMode {
        switch mode {
        case .instant: .instant
        case .periodic: .periodic
        case .off: .off
        }
    }
}

//enum NotificationPreviewMode: Codable {
//    case hidden
//    case contact
//    case message
//}

enum AppSettingsLockScreenCalls: String, Codable {
    case disable
    case show
    case accept
}

struct UserNetworkInfo: Codable, Equatable {
    let networkType: UserNetworkType
    let online: Bool
}

enum UserNetworkType: String, Codable {
    case none
    case cellular
    case wifi
    case ethernet
    case other

    var text: LocalizedStringKey {
        switch self {
        case .none: LocalizedStringKey(NSLocalizedString("No network connection", comment: ""))
        case .cellular: LocalizedStringKey(NSLocalizedString("Cellular", comment: ""))
        case .wifi: LocalizedStringKey(NSLocalizedString("WiFi", comment: ""))
        case .ethernet: LocalizedStringKey(NSLocalizedString("Wired ethernet", comment: ""))
        case .other: LocalizedStringKey(NSLocalizedString("Other", comment: ""))
        }
    }
}

struct RcvMsgInfo: Codable {
    var msgId: Int64
    var msgDeliveryId: Int64
    var msgDeliveryStatus: String
    var agentMsgId: Int64
    var agentMsgMeta: String
}

struct ServerQueueInfo: Codable {
    var server: String
    var rcvId: String
    var sndId: String
    var ntfId: String?
    var status: String
    var info: QueueInfo
}

struct QueueInfo: Codable {
    var qiSnd: Bool
    var qiNtf: Bool
    var qiSub: QSub?
    var qiSize: Int
    var qiMsg: MsgInfo?
}

struct QSub: Codable {
    var qSubThread: QSubThread
    var qDelivered: String?
}

enum QSubThread: String, Codable {
    case noSub
    case subPending
    case subThread
    case prohibitSub
}

struct MsgInfo: Codable {
    var msgId: String
    var msgTs: Date
    var msgType: MsgType
}

enum MsgType: String, Codable {
    case message
    case quota
}

struct PresentedServersSummary: Codable {
    var statsStartedAt: Date
    var allUsersSMP: SMPServersSummary
    var allUsersXFTP: XFTPServersSummary
    var currentUserSMP: SMPServersSummary
    var currentUserXFTP: XFTPServersSummary
}

struct SMPServersSummary: Codable {
    var smpTotals: SMPTotals
    var currentlyUsedSMPServers: [SMPServerSummary]
    var previouslyUsedSMPServers: [SMPServerSummary]
    var onlyProxiedSMPServers: [SMPServerSummary]
}

struct SMPTotals: Codable {
    var sessions: ServerSessions
    var subs: SMPServerSubs
    var stats: AgentSMPServerStatsData
}

struct SMPServerSummary: Codable, Identifiable {
    var smpServer: String
    var known: Bool?
    var sessions: ServerSessions?
    var subs: SMPServerSubs?
    var stats: AgentSMPServerStatsData?

    var id: String { smpServer }

    var hasSubs: Bool { subs != nil }

    var sessionsOrNew: ServerSessions { sessions ?? ServerSessions.newServerSessions }

    var subsOrNew: SMPServerSubs { subs ?? SMPServerSubs.newSMPServerSubs }
}

struct ServerSessions: Codable {
    var ssConnected: Int
    var ssErrors: Int
    var ssConnecting: Int

    static var newServerSessions = ServerSessions(
        ssConnected: 0,
        ssErrors: 0,
        ssConnecting: 0
    )

    var hasSess: Bool { ssConnected > 0 }
}

struct SMPServerSubs: Codable {
    var ssActive: Int
    var ssPending: Int

    static var newSMPServerSubs = SMPServerSubs(
        ssActive: 0,
        ssPending: 0
    )

    var total: Int { ssActive + ssPending }

    var shareOfActive: Double {
        guard total != 0 else { return 0.0 }
        return Double(ssActive) / Double(total)
    }
}

struct AgentSMPServerStatsData: Codable {
    var _sentDirect: Int
    var _sentViaProxy: Int
    var _sentProxied: Int
    var _sentDirectAttempts: Int
    var _sentViaProxyAttempts: Int
    var _sentProxiedAttempts: Int
    var _sentAuthErrs: Int
    var _sentQuotaErrs: Int
    var _sentExpiredErrs: Int
    var _sentOtherErrs: Int
    var _recvMsgs: Int
    var _recvDuplicates: Int
    var _recvCryptoErrs: Int
    var _recvErrs: Int
    var _ackMsgs: Int
    var _ackAttempts: Int
    var _ackNoMsgErrs: Int
    var _ackOtherErrs: Int
    var _connCreated: Int
    var _connSecured: Int
    var _connCompleted: Int
    var _connDeleted: Int
    var _connDelAttempts: Int
    var _connDelErrs: Int
    var _connSubscribed: Int
    var _connSubAttempts: Int
    var _connSubIgnored: Int
    var _connSubErrs: Int
    var _ntfKey: Int
    var _ntfKeyAttempts: Int
    var _ntfKeyDeleted: Int
    var _ntfKeyDeleteAttempts: Int
}

struct XFTPServersSummary: Codable {
    var xftpTotals: XFTPTotals
    var currentlyUsedXFTPServers: [XFTPServerSummary]
    var previouslyUsedXFTPServers: [XFTPServerSummary]
}

struct XFTPTotals: Codable {
    var sessions: ServerSessions
    var stats: AgentXFTPServerStatsData
}

struct XFTPServerSummary: Codable, Identifiable {
    var xftpServer: String
    var known: Bool?
    var sessions: ServerSessions?
    var stats: AgentXFTPServerStatsData?
    var rcvInProgress: Bool
    var sndInProgress: Bool
    var delInProgress: Bool

    var id: String { xftpServer }
}

struct AgentXFTPServerStatsData: Codable {
    var _uploads: Int
    var _uploadsSize: Int64
    var _uploadAttempts: Int
    var _uploadErrs: Int
    var _downloads: Int
    var _downloadsSize: Int64
    var _downloadAttempts: Int
    var _downloadAuthErrs: Int
    var _downloadErrs: Int
    var _deletions: Int
    var _deleteAttempts: Int
    var _deleteErrs: Int
}

struct AgentNtfServerStatsData: Codable {
    var _ntfCreated: Int
    var _ntfCreateAttempts: Int
    var _ntfChecked: Int
    var _ntfCheckAttempts: Int
    var _ntfDeleted: Int
    var _ntfDelAttempts: Int
}

private func sanitizeFFIParam(_ input: String, maxLen: Int) -> String {
    let dangerous = CharacterSet(charactersIn: "'\"\\;|&$`(){}[]!#~<>")
    let cleaned = input.unicodeScalars.filter { scalar in
        !scalar.properties.isWhitespace
        && scalar.value >= 0x20
        && scalar.value != 0x7F
        && !dangerous.contains(scalar)
    }
    let truncated = cleaned.prefix(maxLen)
    return String(truncated)
}
