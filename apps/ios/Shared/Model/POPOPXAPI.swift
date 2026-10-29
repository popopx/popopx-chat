//
//  ChatAPI.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/api.md | spec/architecture.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import Foundation
import UIKit
@preconcurrency import Dispatch
import BackgroundTasks
import SwiftUI
@preconcurrency import POPOPXSwitch

enum TerminalItem: Identifiable {
    case cmd(Date, ChatCommand)
    case res(Date, ChatAPIResult)
    case err(Date, ChatError)
    case bad(Date, String, Data?)

    var id: Date {
        switch self {
        case let .cmd(d, _): d
        case let .res(d, _): d
        case let .err(d, _): d
        case let .bad(d, _, _): d
        }
    }

    var label: String {
        switch self {
        case let .cmd(_, cmd): "> \(cmd.cmdString.prefix(30))"
        case let .res(_, res): "< \(res.responseType)"
        case let .err(_, err): "< error \(err.errorType)"
        case let .bad(_, type, _): "< * \(type)"
        }
    }

    var details: String {
        switch self {
        case let .cmd(_, cmd): cmd.cmdString
        case let .res(_, res): res.details
        case let .err(_, err): String(describing: err)
        case let .bad(_, _, json): dataToString(json)
        }
    }
}

// Spec: spec/architecture.md#beginBGTask
func beginBGTask(_ handler: (() -> Void)? = nil) -> (() -> Void) {
    let lock = NSLock()
    var id: UIBackgroundTaskIdentifier = .invalid
    var running = true
    let endTask = {
        var shouldEnd = false
        lock.lock()
        if running {
            running = false
            shouldEnd = true
        }
        lock.unlock()
        if shouldEnd {
            if let h = handler {
                h()
            }
            lock.lock()
            let currentId = id
            lock.unlock()
            if currentId != .invalid {
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(currentId)
                }
                lock.lock()
                id = .invalid
                lock.unlock()
            }
        }
    }
    let newId = UIApplication.shared.beginBackgroundTask(expirationHandler: endTask)
    lock.lock()
    id = newId
    lock.unlock()
    return endTask
}

let msgDelay: Double = 7.5
let maxTaskDuration: Double = 15

/// Dedicated serial queue for synchronous FFI calls.
/// Prevents blocking the GCD cooperative thread pool which can cause thread explosion and priority inversions.
private let ffiQueueKey = DispatchSpecificKey<Void>()
let ffiQueue: DispatchQueue = {
    let q = DispatchQueue(label: "chat.popopx.ffi", qos: .userInitiated)
    q.setSpecific(key: ffiQueueKey, value: ())
    return q
}()

/// Separate queue for FFI receive (chat_recv_msg_wait).
/// Prevents the blocking recv call (up to 15s) from starving send commands on the same serial queue.
private let ffiRecvQueue: DispatchQueue = {
    let q = DispatchQueue(label: "chat.popopx.ffi.recv", qos: .userInitiated)
    return q
}()

private func withBGTask<T>(bgDelay: Double? = nil, f: @escaping () -> T) -> T {
    let endTask = beginBGTask()
    DispatchQueue.global().asyncAfter(deadline: .now() + maxTaskDuration, execute: endTask)
    let r = f()
    if let d = bgDelay {
        DispatchQueue.global().asyncAfter(deadline: .now() + d, execute: endTask)
    } else {
        endTask()
    }
    return r
}

// Spec: spec/api.md#chatSendCmdSync
@inline(__always)
func chatSendCmdSync<R: ChatAPIResult>(_ cmd: ChatCommand, bgTask: Bool = true, bgDelay: Double? = nil, ctrl: chat_ctrl? = nil, log: Bool = true) throws -> R {
    let res: APIResult<R> = chatApiSendCmdSync(cmd, bgTask: bgTask, bgDelay: bgDelay, ctrl: ctrl, log: log)
    return try apiResult(res)
}

// Spec: spec/api.md#chatApiSendCmdSync
func chatApiSendCmdSync<R: ChatAPIResult>(_ cmd: ChatCommand, bgTask: Bool = true, bgDelay: Double? = nil, ctrl: chat_ctrl? = nil, retryNum: Int32 = 0, log: Bool = true) -> APIResult<R> {
    let doWork = {
        if log {
            logger.debug("chatSendCmd \(cmd.cmdType)")
        }
        let start = Date.now
        let resp: APIResult<R> = bgTask
                    ? withBGTask(bgDelay: bgDelay) { sendPopopxCmd(cmd, ctrl, retryNum: retryNum) }
                    : sendPopopxCmd(cmd, ctrl, retryNum: retryNum)
        if log {
            logger.debug("chatSendCmd \(cmd.cmdType): \(resp.responseType)")
            if case let .invalid(_, json) = resp {
                logger.debug("chatSendCmd \(cmd.cmdType) invalid response: \(json.count) bytes")
            }
            _ = Task {
                await TerminalItems.shared.addCommand(start, cmd.obfuscated, resp)
            }
        }
        return resp
    }
    // Avoid deadlock: if already on ffiQueue (e.g. called from chatApiSendCmd's ffiQueue.async),
    // execute directly instead of calling ffiQueue.sync which would deadlock on a serial queue.
    if DispatchQueue.getSpecific(key: ffiQueueKey) != nil {
        return doWork()
    } else {
        return ffiQueue.sync { doWork() }
    }
}

// Spec: spec/api.md#chatSendCmd
@inline(__always)
func chatSendCmd<R: ChatAPIResult>(_ cmd: ChatCommand, bgTask: Bool = true, bgDelay: Double? = nil, ctrl: chat_ctrl? = nil, log: Bool = true) async throws -> R {
    let res: APIResult<R> = await chatApiSendCmd(cmd, bgTask: bgTask, bgDelay: bgDelay, ctrl: ctrl, log: log)
    return try apiResult(res)
}

// Spec: spec/api.md#chatApiSendCmdWithRetry
/// Sends a command with automatic retry on network errors, showing a retry alert to the user.
/// - Parameter inProgress: Optional cancellation token. Set `inProgress.boxedValue = false` to cancel retry loop.
///   The function checks this before each retry attempt.
func chatApiSendCmdWithRetry<R: ChatAPIResult>(_ cmd: ChatCommand, bgTask: Bool = true, bgDelay: Double? = nil, ctrl: chat_ctrl? = nil, inProgress: BoxedValue<Bool>? = nil, retryNum: Int32 = 0, maxRetries: Int32 = 3, log: Bool = true) async -> APIResult<R>? {
    var currentRetry = retryNum
    while currentRetry <= maxRetries {
        let r: APIResult<R> = await chatApiSendCmd(cmd, bgTask: bgTask, bgDelay: bgDelay, ctrl: ctrl, retryNum: currentRetry, log: log)
        
        if inProgress == nil || inProgress?.boxedValue == true,
           case let .error(e, _) = r, let alert = retryableNetworkErrorAlert(e) {
            if currentRetry >= maxRetries {
                logger.error("chatApiSendCmdWithRetry: max retries (\(maxRetries)) reached, returning error: \(e)")
                return r
            }
            
            let shouldRetry = await withCheckedContinuation { cont in
                showRetryAlert(
                    alert,
                    onCancel: { _ in
                        cont.resume(returning: false)
                    },
                    onRetry: {
                        cont.resume(returning: true)
                    }
                )
            }
            
            if shouldRetry {
                let delaySeconds = pow(2.0, Double(currentRetry + 1)) * Double.random(in: 0.8...1.2)
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                currentRetry += 1
                continue
            } else {
                return nil
            }
        } else {
            return r
        }
    }
    return nil
}

@inline(__always)
func showRetryAlert(_ alert: (title: String, message: String), onCancel: @escaping (UIAlertAction) -> Void, onRetry: @escaping () async -> Void) {
    DispatchQueue.main.async {
        showAlert(
            alert.title,
            message: alert.message,
            actions: {[
                UIAlertAction(
                    title: NSLocalizedString("Cancel", comment: "alert action"),
                    style: .cancel,
                    handler: onCancel
                ),
                UIAlertAction(
                    title: NSLocalizedString("Retry", comment: "alert action"),
                    style: .default,
                    handler: { _ in Task(operation: onRetry) }
                )
            ]}
        )
    }
}

func retryableNetworkErrorAlert(_ e: ChatError) -> (title: String, message: String)? {
    switch e {
    case let .errorAgent(.BROKER(addr, .TIMEOUT)): (
        title: NSLocalizedString("Connection timeout", comment: "alert title"),
        message: serverErrorAlertMessage(addr)
    )
    case .errorAgent(.BROKER(_, .NETWORK(.unknownCAError))): nil
    case let .errorAgent(.BROKER(addr, .NETWORK)): (
        title: NSLocalizedString("Connection error", comment: "alert title"),
        message: serverErrorAlertMessage(addr)
    )
    case let .errorAgent(.SMP(serverAddress, .PROXY(.BROKER(.TIMEOUT)))): (
        title: NSLocalizedString("Private routing timeout", comment: "alert title"),
        message: proxyErrorAlertMessage(serverAddress)
    )
    case .errorAgent(.SMP(_, .PROXY(.BROKER(.NETWORK(.unknownCAError))))): nil
    case let .errorAgent(.SMP(serverAddress, .PROXY(.BROKER(.NETWORK)))): (
        title: NSLocalizedString("Private routing error", comment: "alert title"),
        message: proxyErrorAlertMessage(serverAddress)
    )
    case let .errorAgent(.PROXY(proxyServer, destServer, .protocolError(.PROXY(.BROKER(.TIMEOUT))))): (
        title: NSLocalizedString("Private routing timeout", comment: "alert title"),
        message: proxyDestinationErrorAlertMessage(proxyServer: proxyServer, destServer: destServer)
    )
    case .errorAgent(.PROXY(_, _, .protocolError(.PROXY(.BROKER(.NETWORK(.unknownCAError)))))): nil
    case let .errorAgent(.PROXY(proxyServer, destServer, .protocolError(.PROXY(.BROKER(.NETWORK))))): (
        title: NSLocalizedString("Private routing error", comment: "alert title"),
        message: proxyDestinationErrorAlertMessage(proxyServer: proxyServer, destServer: destServer)
    )
    case let .errorAgent(.PROXY(proxyServer, destServer, .protocolError(.PROXY(.NO_SESSION)))): (
        title: NSLocalizedString("No private routing session", comment: "alert title"),
        message: proxyDestinationErrorAlertMessage(proxyServer: proxyServer, destServer: destServer)
    )
    case .errorAgent(.AGENT(.A_SERVICE(.timeout))): (
        title: NSLocalizedString("Connection timeout", comment: "alert title"),
        message: NSLocalizedString("The service did not respond. Please try again.", comment: "alert message")
    )
    default: nil
    }
}

func serverErrorAlertMessage(_ addr: String) -> String {
    String.localizedStringWithFormat(NSLocalizedString("Please check your network connection with %@ and try again.", comment: "alert message"), serverHostname(addr))
}

func proxyErrorAlertMessage(_ addr: String) -> String {
    String.localizedStringWithFormat(NSLocalizedString("Error connecting to forwarding server %@. Please try later.", comment: "alert message"), serverHostname(addr))
}

func proxyDestinationErrorAlertMessage(proxyServer: String, destServer: String) -> String {
    String.localizedStringWithFormat(NSLocalizedString("Forwarding server %@ failed to connect to destination server %@. Please try later.", comment: "alert message"), serverHostname(proxyServer), serverHostname(destServer))
}

// Spec: spec/api.md#chatApiSendCmd
@inline(__always)
func chatApiSendCmd<R: ChatAPIResult>(_ cmd: ChatCommand, bgTask: Bool = true, bgDelay: Double? = nil, ctrl: chat_ctrl? = nil, retryNum: Int32 = 0, log: Bool = true) async -> APIResult<R> {
    await withCheckedContinuation { cont in
        nonisolated(unsafe) let safeCtrl = ctrl
        ffiQueue.async {
            if safeCtrl != nil && getChatCtrl() == nil {
                logger.error("chatApiSendCmd: ctrl pointer stale (chat controller closed)")
                cont.resume(returning: APIResult.error(.invalidJSON(json: nil), seq: 0))
                return
            }
            cont.resume(returning: chatApiSendCmdSync(cmd, bgTask: bgTask, bgDelay: bgDelay, ctrl: safeCtrl, retryNum: retryNum, log: log))
        }
    }
}

@inline(__always)
func apiResult<R: ChatAPIResult>(_ res: APIResult<R>) throws -> R {
    switch res {
    case let .result(r, _): return r
    case let .error(e, _):
        logger.error("apiResult error: \(e)")
        throw e
    case let .invalid(type, _): throw ChatError.unexpectedResult(type: type)
    }
}

// Spec: spec/api.md#chatRecvMsg
// Safety: The BG task endTask returned by withBGTask is intentionally discarded (_ =).
// The BG task has two cleanup paths: (1) the 30s safety timeout via timeoutWorkItem, and
// (2) the bgDelay timer inside withBGTask. Both call endTask, and endTask is idempotent
// (guarded by the `running` flag in beginBGTask), so double-ending is harmless.
// The NSLock + `resumed` flag ensures the continuation is resumed exactly once, whether
// the FFI call returns first or the 30s timeout fires first.
func chatRecvMsg(_ ctrl: chat_ctrl? = nil) async -> APIResult<ChatEvent>? {
    await withCheckedContinuation { cont in
        // Safety: ctrl lifetime is managed by the chat lifecycle.
        // It is freed only via resetChatCtrl/chatCloseStore which are called
        // after chatRecvMsg tasks are cancelled during shutdown.
        nonisolated(unsafe) let capturedCtrl = ctrl
        var resumed = false
        let lock = NSLock()
        let timeoutWorkItem = DispatchWorkItem {
            lock.lock()
            guard !resumed else { lock.unlock(); return }
            resumed = true
            lock.unlock()
            logger.warning("chatRecvMsg: timed out after 30 seconds")
            cont.resume(returning: nil)
        }
        nonisolated(unsafe) let capturedTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 30, execute: capturedTimeoutWorkItem)
        ffiRecvQueue.async {
            _ = withBGTask(bgDelay: msgDelay) { () -> APIResult<ChatEvent>? in
                let evt: APIResult<ChatEvent>? = recvPopopxMsg(capturedCtrl)
                lock.lock()
                guard !resumed else { lock.unlock(); return evt }
                resumed = true
                lock.unlock()
                capturedTimeoutWorkItem.cancel()
                cont.resume(returning: evt)
                return evt
            }
        }
    }
}

func apiGetActiveUser(ctrl: chat_ctrl? = nil) throws -> User? {
    let r: APIResult<ChatResponse0> = chatApiSendCmdSync(.showActiveUser, ctrl: ctrl)
    switch r {
    case let .result(.activeUser(user), _):
        logger.debug("apiGetActiveUser: Found active user: userId=\(user.userId, privacy: .private)")
        return user
    case .error(.error(.noActiveUser), _):
        logger.debug("apiGetActiveUser: No active user found in database")
        return nil
    case .error(.invalidJSON(let json), _):
        if let data = json, let str = String(data: data, encoding: .utf8), str.contains("noActiveUser") {
            logger.debug("apiGetActiveUser: No active user (invalidJSON fallback)")
            return nil
        }
        logger.error("apiGetActiveUser: Unexpected response: \(String(describing: r))")
        throw r.unexpected
    default:
        logger.error("apiGetActiveUser: Unexpected response: \(String(describing: r))")
        throw r.unexpected
    }
}

func apiCreateActiveUser(_ p: Profile?, pastTimestamp: Bool = false, ctrl: chat_ctrl? = nil) throws -> User {
    let r: ChatResponse0 = try chatSendCmdSync(.createActiveUser(profile: p, pastTimestamp: pastTimestamp), ctrl: ctrl)
    if case let .activeUser(user) = r { return user }
    throw r.unexpected
}

func listUsers() throws -> [UserInfo] {
    return try listUsersResponse(chatSendCmdSync(.listUsers))
}

func listUsersAsync() async throws -> [UserInfo] {
    return try listUsersResponse(await chatSendCmd(.listUsers))
}

private func listUsersResponse(_ r: ChatResponse0) throws -> [UserInfo] {
    if case let .usersList(users) = r {
        return users.sorted { $0.user.chatViewName.compare($1.user.chatViewName) == .orderedAscending }
    }
    throw r.unexpected
}

func apiSetActiveUser(_ userId: Int64, viewPwd: String?) throws -> User {
    let r: ChatResponse0 = try chatSendCmdSync(.apiSetActiveUser(userId: userId, viewPwd: viewPwd))
    if case let .activeUser(user) = r { return user }
    throw r.unexpected
}

func apiSetActiveUserAsync(_ userId: Int64, viewPwd: String?) async throws -> User {
    let r: ChatResponse0 = try await chatSendCmd(.apiSetActiveUser(userId: userId, viewPwd: viewPwd))
    if case let .activeUser(user) = r { return user }
    throw r.unexpected
}

func apiSetAllContactReceipts(enable: Bool) async throws {
    try await sendCommandOkResp(.setAllContactReceipts(enable: enable))
}

func apiSetUserContactReceipts(_ userId: Int64, userMsgReceiptSettings: UserMsgReceiptSettings) async throws {
    try await sendCommandOkResp(.apiSetUserContactReceipts(userId: userId, userMsgReceiptSettings: userMsgReceiptSettings))
}

func apiSetUserGroupReceipts(_ userId: Int64, userMsgReceiptSettings: UserMsgReceiptSettings) async throws {
    try await sendCommandOkResp(.apiSetUserGroupReceipts(userId: userId, userMsgReceiptSettings: userMsgReceiptSettings))
}

func apiSetUserAutoAcceptMemberContacts(_ userId: Int64, enable: Bool) async throws {
    try await sendCommandOkResp(.apiSetUserAutoAcceptMemberContacts(userId: userId, enable: enable))
}

func apiSetUserAutoAcceptGroupInvitations(_ userId: Int64, enable: Bool) async throws {
    try await sendCommandOkResp(.apiSetUserAutoAcceptGroupInvitations(userId: userId, enable: enable))
}

func apiSetUserChatRelay(_ userId: Int64, enable: Bool) async throws {
    try await sendCommandOkResp(.apiSetUserChatRelay(userId: userId, enable: enable))
}

func apiSetClientService(_ userId: Int64, enable: Bool) async throws {
    try await sendCommandOkResp(.apiSetClientService(userId: userId, enable: enable))
}

func apiHideUser(_ userId: Int64, viewPwd: String) async throws -> User {
    try await setUserPrivacy_(.apiHideUser(userId: userId, viewPwd: viewPwd))
}

func apiUnhideUser(_ userId: Int64, viewPwd: String) async throws -> User {
    try await setUserPrivacy_(.apiUnhideUser(userId: userId, viewPwd: viewPwd))
}

func apiMuteUser(_ userId: Int64) async throws -> User {
    try await setUserPrivacy_(.apiMuteUser(userId: userId))
}

func apiUnmuteUser(_ userId: Int64) async throws -> User {
    try await setUserPrivacy_(.apiUnmuteUser(userId: userId))
}

func setUserPrivacy_(_ cmd: ChatCommand) async throws -> User {
    let r: ChatResponse1 = try await chatSendCmd(cmd)
    if case let .userPrivacy(_, updatedUser) = r { return updatedUser }
    throw r.unexpected
}

func apiDeleteUser(_ userId: Int64, _ delSMPQueues: Bool, viewPwd: String?) async throws {
    try await sendCommandOkResp(.apiDeleteUser(userId: userId, delSMPQueues: delSMPQueues, viewPwd: viewPwd))
}

func apiStartChat(ctrl: chat_ctrl? = nil) throws -> Bool {
    let r: ChatResponse0 = try chatSendCmdSync(.startChat(mainApp: true, enableSndFiles: true), ctrl: ctrl)
    switch r {
    case .chatStarted: return true
    case .chatRunning: return false
    default: throw r.unexpected
    }
}

func apiCheckChatRunning() throws -> Bool {
    let r: ChatResponse0 = try chatSendCmdSync(.checkChatRunning)
    switch r {
    case .chatRunning: return true
    case .chatStopped: return false
    default: throw r.unexpected
    }
}

func apiStopChat() async throws {
    let r: ChatResponse0 = try await chatSendCmd(.apiStopChat)
    switch r {
    case .chatStopped: return
    default: throw r.unexpected
    }
}

// Spec: spec/architecture.md#apiActivateChat
func apiActivateChat() {
    chatReopenStore()
    do {
        try sendCommandOkRespSync(.apiActivateChat(restoreChat: true))
    } catch {
        logger.error("apiActivateChat error: \(responseError(error))")
    }
}

// Spec: spec/architecture.md#apiSuspendChat
func apiSuspendChat(timeoutMicroseconds: Int) {
    do {
        try sendCommandOkRespSync(.apiSuspendChat(timeoutMicroseconds: timeoutMicroseconds))
    } catch {
        logger.error("apiSuspendChat error: \(responseError(error))")
    }
}

// Spec: spec/services/files.md#apiSetAppFilePaths
func apiSetAppFilePaths(filesFolder: String, tempFolder: String, assetsFolder: String, ctrl: chat_ctrl? = nil) throws {
    let r: ChatResponse2 = try chatSendCmdSync(.apiSetAppFilePaths(filesFolder: filesFolder, tempFolder: tempFolder, assetsFolder: assetsFolder), ctrl: ctrl)
    if case .cmdOk = r { return }
    throw r.unexpected
}

// Spec: spec/services/files.md#apiSetEncryptLocalFiles
func apiSetEncryptLocalFiles(_ enable: Bool) throws {
    try sendCommandOkRespSync(.apiSetEncryptLocalFiles(enable: enable))
}

func apiSaveAppSettings(settings: AppSettings) throws {
    try sendCommandOkRespSync(.apiSaveSettings(settings: settings))
}

func apiGetAppSettings(settings: AppSettings) throws -> AppSettings {
    let r: ChatResponse2 = try chatSendCmdSync(.apiGetSettings(settings: settings))
    if case let .appSettings(settings) = r { return settings }
    throw r.unexpected
}

func apiExportArchive(config: ArchiveConfig) async throws -> [ArchiveError] {
    let r: ChatResponse2 = try await chatSendCmd(.apiExportArchive(config: config))
    if case let .archiveExported(archiveErrors) = r { return archiveErrors }
    throw r.unexpected
}

func apiImportArchive(config: ArchiveConfig) async throws -> [ArchiveError] {
    let r: ChatResponse2 = try await chatSendCmd(.apiImportArchive(config: config))
    if case let .archiveImported(archiveErrors) = r { return archiveErrors }
    throw r.unexpected
}

func apiDeleteStorage() async throws {
    try await sendCommandOkResp(.apiDeleteStorage)
}

func apiStorageEncryption(currentKey: String = "", newKey: String = "") async throws {
    try await sendCommandOkResp(.apiStorageEncryption(config: DBEncryptionConfig(currentKey: currentKey, newKey: newKey)))
}

func testStorageEncryption(key: String, ctrl: chat_ctrl? = nil) async throws {
    try await sendCommandOkResp(.testStorageEncryption(key: key), ctrl: ctrl)
}

@MainActor
func apiGetChats() throws -> [ChatData] {
    let userId = try currentUserId("apiGetChats")
    return try apiChatsResponse(try chatSendCmdSync(.apiGetChats(userId: userId)))
}

func apiGetChatsAsync() async throws -> [ChatData] {
    let userId = try await currentUserId("apiGetChats")
    return try apiChatsResponse(await chatSendCmd(.apiGetChats(userId: userId)))
}

private func apiChatsResponse(_ r: ChatResponse0) throws -> [ChatData] {
    if case let .apiChats(_, chats) = r { return chats }
    throw r.unexpected
}

@MainActor
func apiGetChatTags() throws -> [ChatTag] {
    let userId = try currentUserId("apiGetChatTags")
    let r: ChatResponse0 = try chatSendCmdSync(.apiGetChatTags(userId: userId))
    if case let .chatTags(_, tags) = r { return tags }
    throw r.unexpected
}

func apiGetChatTagsAsync() async throws -> [ChatTag] {
    let userId = try await currentUserId("apiGetChatTags")
    let r: ChatResponse0 = try await chatSendCmd(.apiGetChatTags(userId: userId))
    if case let .chatTags(_, tags) = r { return tags }
    throw r.unexpected
}

let loadItemsPerPage = 50

func apiGetChat(chatId: ChatId, scope: GroupChatScope?, contentTag: MsgContentTag? = nil, pagination: ChatPagination, search: String = "") async throws -> (Chat, NavigationInfo) {
    let r: ChatResponse0 = try await chatSendCmd(.apiGetChat(chatId: chatId, scope: scope, contentTag: contentTag, pagination: pagination, search: search))
    // MainActor.run is needed: Chat is @MainActor, and this function is not @MainActor-isolated.
    // After the await above, the executor is the generic executor, not MainActor.
    if case let .apiChat(_, chat, navInfo) = r { return (await MainActor.run { Chat.init(chat) }, navInfo ?? NavigationInfo()) }
    throw r.unexpected
}

func apiGetChatContentTypes(chatId: ChatId, scope: GroupChatScope? = nil) async throws -> [MsgContentTag] {
    let r: ChatResponse0 = try await chatSendCmd(.apiGetChatContentTypes(chatId: chatId, scope: scope))
    if case let .chatContentTypes(types) = r { return types.filter { if case .unknown = $0 { return false }; return true } }
    throw r.unexpected
}

func loadChat(chat: Chat, im: ItemsModel, contentTag: MsgContentTag? = nil, search: String = "", clearItems: Bool = true) async {
    await loadChat(chatId: chat.chatInfo.id, im: im, contentTag: contentTag, search: search, clearItems: clearItems)
}

func loadChat(chatId: ChatId, im: ItemsModel, contentTag: MsgContentTag? = nil, search: String = "", openAroundItemId: ChatItem.ID? = nil, clearItems: Bool = true) async {
    await MainActor.run {
        if clearItems {
            im.reversedChatItems = []
            im.chatState.clear()
        }
    }
    await apiLoadMessages(
        chatId,
        im,
        ( // pagination
            { () -> ChatPagination in
                if let aroundId = openAroundItemId {
                    return .around(chatItemId: aroundId, count: loadItemsPerPage)
                } else if contentTag == nil && search == "" {
                    return .initial(count: loadItemsPerPage)
                } else {
                    return .last(count: loadItemsPerPage)
                }
            }()
        ),
        contentTag,
        search,
        openAroundItemId,
        { 0...0 }
    )
}

func apiGetChatItemInfo(type: ChatType, id: Int64, scope: GroupChatScope?, itemId: Int64) async throws -> (AChatItem, ChatItemInfo) {
    let r: ChatResponse0 = try await chatSendCmd(.apiGetChatItemInfo(type: type, id: id, scope: scope, itemId: itemId))
    if case let .chatItemInfo(_, aci, chatItemInfo) = r { return (aci, chatItemInfo) }
    throw r.unexpected
}

func apiPlanForwardChatItems(type: ChatType, id: Int64, scope: GroupChatScope?, itemIds: [Int64]) async throws -> ([Int64], ForwardConfirmation?) {
    let r: ChatResponse1 = try await chatSendCmd(.apiPlanForwardChatItems(fromChatType: type, fromChatId: id, fromScope: scope, itemIds: itemIds))
    if case let .forwardPlan(_, _, chatItemIds, forwardConfimation) = r { return (chatItemIds, forwardConfimation) }
    throw r.unexpected
}

func apiShareChatMsgContent(shareChatType: ChatType, shareChatId: Int64, toChatType: ChatType, toChatId: Int64, toScope: GroupChatScope?, sendAsGroup: Bool) async throws -> MsgContent {
    let r: ChatResponse1 = try await chatSendCmd(.apiShareChatMsgContent(shareChatType: shareChatType, shareChatId: shareChatId, toChatType: toChatType, toChatId: toChatId, toScope: toScope, sendAsGroup: sendAsGroup))
    if case let .chatMsgContent(_, mc) = r { return mc }
    throw r.unexpected
}

func apiForwardChatItems(toChatType: ChatType, toChatId: Int64, toScope: GroupChatScope?, sendAsGroup: Bool = false, fromChatType: ChatType, fromChatId: Int64, fromScope: GroupChatScope?, itemIds: [Int64], ttl: Int?) async -> [ChatItem]? {
    let cmd: ChatCommand = .apiForwardChatItems(toChatType: toChatType, toChatId: toChatId, toScope: toScope, sendAsGroup: sendAsGroup, fromChatType: fromChatType, fromChatId: fromChatId, fromScope: fromScope, itemIds: itemIds, ttl: ttl)
    return await processSendMessageCmd(toChatType: toChatType, cmd: cmd)
}

func apiCreateChatTag(tag: ChatTagData) async throws -> [ChatTag] {
    let r: ChatResponse0 = try await chatSendCmd(.apiCreateChatTag(tag: tag))
    if case let .chatTags(_, userTags) = r {
        return userTags
    }
    throw r.unexpected
}

func apiSetChatTags(type: ChatType, id: Int64, tagIds: [Int64]) async throws -> ([ChatTag], [Int64]) {
    let r: ChatResponse0 = try await chatSendCmd(.apiSetChatTags(type: type, id: id, tagIds: tagIds))
    if case let .tagsUpdated(_, userTags, chatTags) = r {
        return (userTags, chatTags)
    }
    throw r.unexpected
}

func apiDeleteChatTag(tagId: Int64) async throws  {
    try await sendCommandOkResp(.apiDeleteChatTag(tagId: tagId))
}

func apiUpdateChatTag(tagId: Int64, tag: ChatTagData) async throws  {
    try await sendCommandOkResp(.apiUpdateChatTag(tagId: tagId, tagData: tag))
}

func apiReorderChatTags(tagIds: [Int64]) async throws {
    try await sendCommandOkResp(.apiReorderChatTags(tagIds: tagIds))
}

func apiGetNtfToken() -> (DeviceToken?, NtfTknStatus?, NotificationsMode, String?) {
    let r: APIResult<ChatResponse2> = chatApiSendCmdSync(.apiGetNtfToken)
    logger.debug("apiGetNtfToken response received")
    switch r {
    case let .result(.ntfToken(token, status, ntfMode, ntfServer), _):
        logger.debug("apiGetNtfToken: success - token=present, status=\(String(describing: status), privacy: .private), mode=\(String(describing: ntfMode), privacy: .private), server=\(ntfServer, privacy: .private)")
        return (token, status, ntfMode, ntfServer)
    case .error(.errorAgent(.CMD(.PROHIBITED, _)), _):
        logger.debug("apiGetNtfToken: PROHIBITED - no active user")
        return (nil, nil, .off, nil)
    default:
        logger.error("apiGetNtfToken unexpected response: \(String(describing: r))")
        return (nil, nil, .off, nil)
    }
}

func apiRegisterToken(token: DeviceToken, notificationMode: NotificationsMode) async throws -> NtfTknStatus {
    let r: ChatResponse2 = try await chatSendCmd(.apiRegisterToken(token: token, notificationMode: notificationMode))
    if case let .ntfTokenStatus(status) = r { return status }
    throw r.unexpected
}

@MainActor
func registerToken(token: DeviceToken) {
    let m = ChatModel.shared
    let mode = m.notificationMode
    if mode != .off && !m.tokenRegistered {
        m.tokenRegistered = true
        logger.debug("registerToken \(mode.rawValue)")
        Task {
            do {
                let status = try await apiRegisterToken(token: token, notificationMode: mode)
                await MainActor.run {
                    m.tokenStatus = status
                    if !status.workingToken {
                        m.reRegisterTknStatus = status
                    }
                }
            } catch let error {
                logger.error("registerToken apiRegisterToken error: \(responseError(error))")
                await MainActor.run {
                    // Reset flag on failure to allow retry on next call
                    m.tokenRegistered = false
                }
            }
        }
    }
}

func tokenStatusInfo(_ status: NtfTknStatus, register: Bool) -> String {
    String.localizedStringWithFormat(NSLocalizedString("Token status: %@.", comment: "token status"), status.text)
    + "\n" + status.info(register: register)
}

@MainActor
func reRegisterToken(token: DeviceToken) {
    let m = ChatModel.shared
    let mode = m.notificationMode
    logger.debug("reRegisterToken \(mode.rawValue)")
    Task {
        do {
            let status = try await apiRegisterToken(token: token, notificationMode: mode)
            await MainActor.run {
                m.tokenStatus = status
                showAlert(
                    status.workingToken
                    ? NSLocalizedString("Notifications status", comment: "alert title")
                    : NSLocalizedString("Notifications error", comment: "alert title"),
                    message: tokenStatusInfo(status, register: false)
                )
            }
        } catch let error {
            logger.error("reRegisterToken apiRegisterToken error: \(responseError(error))")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error registering for notifications", comment: "alert title"),
                    message: responseError(error)
                )
            }
        }
    }
}

func apiVerifyToken(token: DeviceToken, nonce: String, code: String) async throws {
    try await sendCommandOkResp(.apiVerifyToken(token: token, nonce: nonce, code: code))
}

func apiCheckToken(token: DeviceToken) async throws -> NtfTknStatus {
    let r: ChatResponse2 = try await chatSendCmd(.apiCheckToken(token: token))
    if case let .ntfTokenStatus(status) = r { return status }
    throw r.unexpected
}

func apiDeleteToken(token: DeviceToken) async throws {
    try await sendCommandOkResp(.apiDeleteToken(token: token))
}

func testProtoServer(server: String) async throws -> Result<(), ProtocolTestFailure> {
    let userId = try await currentUserId("testProtoServer")
    let r: ChatResponse0 = try await chatSendCmd(.apiTestProtoServer(userId: userId, server: server))
    if case let .serverTestResult(_, _, testFailure, _) = r {
        if let t = testFailure {
            return .failure(t)
        }
        return .success(())
    }
    throw r.unexpected
}

func testChatRelay(address: String) async throws -> (RelayProfile?, RelayTestFailure?) {
    let userId = try await currentUserId("testChatRelay")
    let r: ChatResponse0 = try await chatSendCmd(.apiTestChatRelay(userId: userId, address: address))
    if case let .chatRelayTestResult(_, relayProfile, relayTestFailure) = r {
        return (relayProfile, relayTestFailure)
    }
    throw r.unexpected
}

func getServerOperatorsSync() throws -> ServerOperatorConditions {
    let r: ChatResponse0 = try chatSendCmdSync(.apiGetServerOperators)
    if case let .serverOperatorConditions(conditions) = r {
        return conditions
    }
    logger.error("getServerOperators error: \(String(describing: r))")
    throw r.unexpected
}

// Database lock retry — separate from chatApiSendCmdWithRetry network retry.
// This retries on transient errors (e.g., database busy) that occur during initialization
// when the Haskell core may not yet be fully ready to respond.
func apiGetServerOperators() async throws -> ServerOperatorConditions {
    var lastError: Error?
    for attempt in 1...3 {
        do {
            logger.debug("apiGetServerOperators: Attempt \(attempt)/3 - sending command to Haskell core")
            let r: ChatResponse0 = try await chatSendCmd(.apiGetServerOperators)
            logger.debug("apiGetServerOperators: Received response type=\(r.responseType)")
            if case let .serverOperatorConditions(conditions) = r {
                logger.debug("apiGetServerOperators: SUCCESS - loaded \(conditions.serverOperators.count) operators, conditionsId=\(conditions.currentConditions.conditionsId), commit=\(conditions.currentConditions.conditionsCommit)")
                return conditions
            }
            logger.error("apiGetServerOperators: Unexpected response type=\(r.responseType), expected .serverOperatorConditions")
            throw r.unexpected
        } catch let error {
            lastError = error
            logger.warning("apiGetServerOperators: Attempt \(attempt) failed with error: \(responseError(error))")
            logger.warning("apiGetServerOperators: Error details: \(String(describing: error))")
            if attempt < 3 {
                let delay = UInt64(1_000_000_000) * UInt64(attempt) // 1s, 2s, 3s escalating delay
                logger.debug("apiGetServerOperators: Waiting \(delay / 1_000_000_000)s before retry...")
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }
    logger.error("apiGetServerOperators: ALL 3 ATTEMPTS FAILED")
    logger.error("apiGetServerOperators: Last error was: \(String(describing: lastError))")
    throw lastError ?? ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_failed_load_server_operators", comment: "Error message when server operators fail to load")))
}

// Database lock retry with escalating delays — separate from chatApiSendCmdWithRetry network retry.
// Uses longer delays (500ms * attempt) to handle database locks that occur after acceptConditions
// writes, which can hold the database lock briefly.
func setServerOperators(operators: [ServerOperator]) async throws -> ServerOperatorConditions {
    guard !operators.isEmpty else {
        throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_cannot_set_empty_operators", comment: "Error message when trying to set empty operators list")))
    }
    logger.debug("setServerOperators: operators count=\(operators.count), ids=\(operators.map { $0.operatorId })")
    
    // Retry up to 5 times with longer delays to handle database locks after acceptConditions
    var lastError: Error?
    for attempt in 1...5 {
        do {
            logger.debug("setServerOperators: Attempt \(attempt)/5")
            let r: ChatResponse0 = try await chatSendCmd(.apiSetServerOperators(operators: operators))
            logger.debug("setServerOperators: Attempt \(attempt) response type=\(r.responseType)")
            if case let .serverOperatorConditions(conditions) = r {
                logger.debug("setServerOperators: SUCCESS - got \(conditions.serverOperators.count) operators, conditionsId=\(conditions.currentConditions.conditionsId)")
                return conditions
            }
            logger.error("setServerOperators: Unexpected response type=\(r.responseType)")
            throw r.unexpected
        } catch let error {
            lastError = error
            logger.warning("setServerOperators: Attempt \(attempt) failed: \(responseError(error))")
            if attempt < 5 {
                let delayMs = attempt * 500 // 500ms, 1000ms, 1500ms, 2000ms
                logger.debug("setServerOperators: Waiting \(delayMs)ms before retry...")
                try await Task.sleep(nanoseconds: UInt64(delayMs * 1_000_000))
            }
        }
    }
    
    logger.error("setServerOperators: ALL 5 ATTEMPTS FAILED")
    throw lastError ?? ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_failed_set_server_operators", comment: "Error message when setting server operators fails")))
}

func getUserServers() async throws -> [UserOperatorServers] {
    let userId = try await currentUserId("getUserServers")
    let r: ChatResponse0 = try await chatSendCmd(.apiGetUserServers(userId: userId))
    if case let .userServers(_, userServers) = r {
        logger.debug("getUserServers: loaded \(userServers.count) operators")
        return userServers
    }
    logger.error("getUserServers error: \(String(describing: r))")
    throw r.unexpected
}

// MARK: - BinThere Bot API

func apiGetBinThereBots(botType: String = "binthere") async throws -> [BinThereBotInfo] {
    let userId = try await currentUserId("apiGetBinThereBots")
    let r: ChatResponse0 = try await chatSendCmd(.apiGetBinThereBots(userId: userId, botType: botType))
    if case let .binThereBots(_, bots) = r {
        logger.debug("apiGetBinThereBots: loaded \(bots.count) bots")
        return bots
    }
    logger.error("apiGetBinThereBots error: \(String(describing: r))")
    throw r.unexpected
}

func apiInsertBinThereBot(address: String, name: String? = nil, botType: String = "binthere") async throws {
    let userId = try await currentUserId("apiInsertBinThereBot")
    let r: ChatResponse2 = try await chatSendCmd(.apiInsertBinThereBot(userId: userId, address: address, name: name, botType: botType))
    if case .cmdOk = r {
        logger.debug("apiInsertBinThereBot: success")
        return
    }
    logger.error("apiInsertBinThereBot error: \(String(describing: r))")
    throw r.unexpected
}

func apiReportBinThereBotUse(botId: Int64) async throws {
    let userId = try await currentUserId("apiReportBinThereBotUse")
    let r: ChatResponse2 = try await chatSendCmd(.apiReportBinThereBotUse(userId: userId, botId: botId))
    if case .cmdOk = r {
        logger.debug("apiReportBinThereBotUse: success for botId=\(botId)")
        return
    }
    logger.error("apiReportBinThereBotUse error: \(String(describing: r))")
    throw r.unexpected
}

func apiSyncBotDirectory(json: String) async throws {
    let userId = try await currentUserId("apiSyncBotDirectory")
    let r: ChatResponse2 = try await chatSendCmd(.apiSyncBotDirectory(userId: userId, json: json))
    if case .cmdOk = r {
        logger.debug("apiSyncBotDirectory: success")
        return
    }
    logger.error("apiSyncBotDirectory error: \(String(describing: r))")
    throw r.unexpected
}

// Database lock retry with 2s delays — separate from chatApiSendCmdWithRetry network retry.
// Uses 2s delays to allow database write operations to complete before retrying.
func setUserServers(userServers: [UserOperatorServers]) async throws {
    let userId = try await currentUserId("setUserServers")

    let jsonStr = encodeJSON(userServers)
    logger.debug("setUserServers: command length=\(jsonStr.count)")

    var lastError: Error?
    for attempt in 1...3 {
        do {
            logger.debug("setUserServers: Attempt \(attempt)/3")
            let r: ChatResponse2 = try await chatSendCmd(.apiSetUserServers(userId: userId, userServers: userServers))
            if case .cmdOk = r {
                logger.debug("setUserServers: Success on attempt \(attempt)")
                return
            }
            logger.error("setUserServers error: \(String(describing: r))")
            throw r.unexpected
        } catch let error {
            lastError = error
            logger.warning("setUserServers: Attempt \(attempt) failed: \(responseError(error))")
            if attempt < 3 {
                // Increase delay to 2 seconds to allow database operations to complete
                try await Task.sleep(nanoseconds: UInt64(2_000_000_000)) // 2 second delay
            }
        }
    }
    
    logger.error("setUserServers: All attempts failed")
    throw lastError ?? ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_failed_save_servers", comment: "Error message when saving servers fails")))
}

// Database lock retry with 2s delays — separate from chatApiSendCmdWithRetry network retry.
// Uses 2s delays to allow database write operations to complete before retrying.
func validateServers(userServers: [UserOperatorServers]) async throws -> ([UserServersError], [UserServersWarning]) {
    let userId = try await currentUserId("validateServers")
    
    let jsonStr = encodeJSON(userServers)
    logger.debug("validateServers: userId=\(userId), command length=\(jsonStr.count), array count=\(userServers.count)")

    var lastError: Error?
    for attempt in 1...3 {
        do {
            logger.debug("validateServers: Attempt \(attempt)/3")
            let r: ChatResponse0 = try await chatSendCmd(.apiValidateServers(userId: userId, userServers: userServers))
            if case let .userServersValidation(_, serverErrors, serverWarnings) = r {
                logger.debug("validateServers: Success on attempt \(attempt)")
                return (serverErrors, serverWarnings)
            }
            logger.error("validateServers error: \(String(describing: r))")
            throw r.unexpected
        } catch let error {
            lastError = error
            logger.warning("validateServers: Attempt \(attempt) failed: \(responseError(error))")
            if attempt < 3 {
                try await Task.sleep(nanoseconds: UInt64(2_000_000_000)) // 2 second delay
            }
        }
    }
    
    logger.error("validateServers: All attempts failed")
    throw lastError ?? ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_failed_validate_servers", comment: "Error message when validating servers fails")))
}

// Database lock retry — separate from chatApiSendCmdWithRetry network retry.
// This retries on transient errors (e.g., database busy) that occur when loading
// usage conditions text from the Haskell core.
func getUsageConditions() async throws -> (UsageConditions, String?, UsageConditions?) {
    var lastError: Error?
    for attempt in 1...3 {
        do {
            logger.debug("getUsageConditions: Attempt \(attempt)/3 - requesting conditions text from Haskell core")
            let r: ChatResponse0 = try await chatSendCmd(.apiGetUsageConditions)
            logger.debug("getUsageConditions: Received response type=\(r.responseType)")
            if case let .usageConditions(usageConditions, conditionsText, acceptedConditions) = r {
                logger.debug("getUsageConditions: SUCCESS - conditionsId=\(usageConditions.conditionsId), commit=\(usageConditions.conditionsCommit), text length=\(conditionsText.count)")
                return (usageConditions, conditionsText, acceptedConditions)
            }
            logger.error("getUsageConditions: Unexpected response type=\(r.responseType), expected .usageConditions")
            throw r.unexpected
        } catch let error {
            lastError = error
            logger.warning("getUsageConditions: Attempt \(attempt) failed with error: \(responseError(error))")
            if attempt < 3 {
                let delay = UInt64(500_000_000) * UInt64(attempt) // 0.5s, 1s, 1.5s escalating delay
                logger.debug("getUsageConditions: Waiting \(Double(delay) / 1_000_000_000)s before retry...")
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }
    logger.error("getUsageConditions: ALL 3 ATTEMPTS FAILED")
    throw lastError ?? ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_failed_load_conditions", comment: "Error message when loading usage conditions fails")))
}

func setConditionsNotified(conditionsId: Int64) async throws {
    let r: ChatResponse2 = try await chatSendCmd(.apiSetConditionsNotified(conditionsId: conditionsId))
    if case .cmdOk = r { return }
    logger.error("setConditionsNotified error: \(String(describing: r))")
    throw r.unexpected
}

func acceptConditions(conditionsId: Int64, operatorIds: [Int64]) async throws -> ServerOperatorConditions {
    logger.debug("acceptConditions: conditionsId=\(conditionsId), operatorIds=\(operatorIds)")
    guard !operatorIds.isEmpty else {
        logger.error("acceptConditions: called with empty operatorIds")
        throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_no_operators_for_conditions", comment: "Error message when no operators specified for conditions")))
    }
    guard conditionsId > 0 else {
        logger.error("acceptConditions: called with invalid conditionsId=\(conditionsId)")
        throw ChatError.error(errorType: ChatErrorType.commandError(message: NSLocalizedString("error_invalid_conditions_id", comment: "Error message when conditions ID is invalid")))
    }
    logger.debug("acceptConditions: sending command to apiAcceptConditions")
    let r: ChatResponse0 = try await chatSendCmd(.apiAcceptConditions(conditionsId: conditionsId, operatorIds: operatorIds))
    logger.debug("acceptConditions response: \(String(describing: r))")
    if case let .serverOperatorConditions(conditions) = r { return conditions }
    logger.error("acceptConditions error: \(String(describing: r))")
    throw r.unexpected
}

@MainActor
func getChatItemTTL() throws -> ChatItemTTL {
    let userId = try currentUserId("getChatItemTTL")
    return try chatItemTTLResponse(try chatSendCmdSync(.apiGetChatItemTTL(userId: userId)))
}

func getChatItemTTLAsync() async throws -> ChatItemTTL {
    let userId = try await currentUserId("getChatItemTTLAsync")
    return try chatItemTTLResponse(await chatSendCmd(.apiGetChatItemTTL(userId: userId)))
}

private func chatItemTTLResponse(_ r: ChatResponse0) throws -> ChatItemTTL {
    if case let .chatItemTTL(_, chatItemTTL) = r {
        if let ttl = chatItemTTL {
            return ChatItemTTL(ttl)
        } else {
            throw RuntimeError("chatItemTTLResponse: invalid ttl")
        }
    }
    throw r.unexpected
}

func setChatItemTTL(_ chatItemTTL: ChatItemTTL) async throws {
    let userId = try await currentUserId("setChatItemTTL")
    try await sendCommandOkResp(.apiSetChatItemTTL(userId: userId, seconds: chatItemTTL.seconds))
}

func setChatTTL(chatType: ChatType, id: Int64, _ chatItemTTL: ChatTTL) async throws {
    let userId = try await currentUserId("setChatItemTTL")
    try await sendCommandOkResp(.apiSetChatTTL(userId: userId, type: chatType, id: id, seconds: chatItemTTL.value))
}

func getNetworkConfig() async throws -> NetCfg? {
    let r: ChatResponse0 = try await chatSendCmd(.apiGetNetworkConfig)
    if case let .networkConfig(cfg) = r { return cfg }
    throw r.unexpected
}

func setNetworkConfig(_ cfg: NetCfg, ctrl: chat_ctrl? = nil) throws {
    let r: ChatResponse2 = try chatSendCmdSync(.apiSetNetworkConfig(networkConfig: cfg), ctrl: ctrl)
    if case .cmdOk = r { return }
    throw r.unexpected
}

func apiSetNetworkInfo(_ networkInfo: UserNetworkInfo) throws {
    let r: ChatResponse2 = try chatSendCmdSync(.apiSetNetworkInfo(networkInfo: networkInfo))
    if case .cmdOk = r { return }
    throw r.unexpected
}

func reconnectAllServers() async throws {
    try await sendCommandOkResp(.reconnectAllServers)
}

func reconnectServer(smpServer: String) async throws {
    let userId = try await currentUserId("reconnectServer")
    try await sendCommandOkResp(.reconnectServer(userId: userId, smpServer: smpServer))
}

func apiSetChatSettings(type: ChatType, id: Int64, chatSettings: ChatSettings) async throws {
    try await sendCommandOkResp(.apiSetChatSettings(type: type, id: id, chatSettings: chatSettings))
}

func apiSetMemberSettings(_ groupId: Int64, _ groupMemberId: Int64, _ memberSettings: GroupMemberSettings) async throws {
    try await sendCommandOkResp(.apiSetMemberSettings(groupId: groupId, groupMemberId: groupMemberId, memberSettings: memberSettings))
}

func apiGetUpdatedGroupLinkData(_ groupId: Int64) async -> GroupInfo? {
    let r: APIResult<ChatResponse0> = await chatApiSendCmd(.apiGetUpdatedGroupLinkData(groupId: groupId))
    if case let .result(.groupInfo(_, groupInfo), _) = r { return groupInfo }
    logger.error("apiGetUpdatedGroupLinkData unexpected response: \(String(describing: r))")
    return nil
}

func apiContactInfo(_ contactId: Int64) async throws -> (ConnectionStats?, Profile?) {
    let r: ChatResponse0 = try await chatSendCmd(.apiContactInfo(contactId: contactId))
    if case let .contactInfo(_, _, connStats, customUserProfile) = r { return (connStats, customUserProfile) }
    throw r.unexpected
}

func apiGroupMemberInfoSync(_ groupId: Int64, _ groupMemberId: Int64) throws -> (GroupMember, ConnectionStats?) {
    let r: ChatResponse0 = try chatSendCmdSync(.apiGroupMemberInfo(groupId: groupId, groupMemberId: groupMemberId))
    if case let .groupMemberInfo(_, _, member, connStats_) = r { return (member, connStats_) }
    throw r.unexpected
}

func apiGroupMemberInfo(_ groupId: Int64, _ groupMemberId: Int64) async throws -> (GroupMember, ConnectionStats?) {
    let r: ChatResponse0 = try await chatSendCmd(.apiGroupMemberInfo(groupId: groupId, groupMemberId: groupMemberId))
    if case let .groupMemberInfo(_, _, member, connStats_) = r { return (member, connStats_) }
    throw r.unexpected
}

func apiContactQueueInfo(_ contactId: Int64) async throws -> (RcvMsgInfo?, ServerQueueInfo)? {
    let r: APIResult<ChatResponse0>? = await chatApiSendCmdWithRetry(.apiContactQueueInfo(contactId: contactId))
    if case let .result(.queueInfo(_, rcvMsgInfo, queueInfo), _) = r { return (rcvMsgInfo, queueInfo) }
    if let r { throw r.unexpected } else { return nil }
}

func apiGroupMemberQueueInfo(_ groupId: Int64, _ groupMemberId: Int64) async throws -> (RcvMsgInfo?, ServerQueueInfo)? {
    let r: APIResult<ChatResponse0>? = await chatApiSendCmdWithRetry(.apiGroupMemberQueueInfo(groupId: groupId, groupMemberId: groupMemberId))
    if case let .result(.queueInfo(_, rcvMsgInfo, queueInfo), _) = r { return (rcvMsgInfo, queueInfo) }
    if let r { throw r.unexpected } else { return nil }
}

func apiSwitchContact(contactId: Int64) throws -> ConnectionStats {
    let r: ChatResponse0 = try chatSendCmdSync(.apiSwitchContact(contactId: contactId))
    if case let .contactSwitchStarted(_, _, connectionStats) = r { return connectionStats }
    throw r.unexpected
}

func apiSwitchGroupMember(_ groupId: Int64, _ groupMemberId: Int64) throws -> ConnectionStats {
    let r: ChatResponse0 = try chatSendCmdSync(.apiSwitchGroupMember(groupId: groupId, groupMemberId: groupMemberId))
    if case let .groupMemberSwitchStarted(_, _, _, connectionStats) = r { return connectionStats }
    throw r.unexpected
}

func apiAbortSwitchContact(_ contactId: Int64) throws -> ConnectionStats {
    let r: ChatResponse0 = try chatSendCmdSync(.apiAbortSwitchContact(contactId: contactId))
    if case let .contactSwitchAborted(_, _, connectionStats) = r { return connectionStats }
    throw r.unexpected
}

func apiAbortSwitchGroupMember(_ groupId: Int64, _ groupMemberId: Int64) throws -> ConnectionStats {
    let r: ChatResponse0 = try chatSendCmdSync(.apiAbortSwitchGroupMember(groupId: groupId, groupMemberId: groupMemberId))
    if case let .groupMemberSwitchAborted(_, _, _, connectionStats) = r { return connectionStats }
    throw r.unexpected
}

func apiSyncContactRatchet(_ contactId: Int64, _ force: Bool) throws -> ConnectionStats {
    let r: ChatResponse0 = try chatSendCmdSync(.apiSyncContactRatchet(contactId: contactId, force: force))
    if case let .contactRatchetSyncStarted(_, _, connectionStats) = r { return connectionStats }
    throw r.unexpected
}

func apiSyncGroupMemberRatchet(_ groupId: Int64, _ groupMemberId: Int64, _ force: Bool) throws -> (GroupMember, ConnectionStats) {
    let r: ChatResponse0 = try chatSendCmdSync(.apiSyncGroupMemberRatchet(groupId: groupId, groupMemberId: groupMemberId, force: force))
    if case let .groupMemberRatchetSyncStarted(_, _, member, connectionStats) = r { return (member, connectionStats) }
    throw r.unexpected
}

func apiGetContactCode(_ contactId: Int64) async throws -> (Contact, String) {
    let r: ChatResponse0 = try await chatSendCmd(.apiGetContactCode(contactId: contactId))
    if case let .contactCode(_, contact, connectionCode) = r { return (contact, connectionCode) }
    throw r.unexpected
}

func apiGetGroupMemberCode(_ groupId: Int64, _ groupMemberId: Int64) async throws -> (GroupMember, String) {
    let r: ChatResponse0 = try await chatSendCmd(.apiGetGroupMemberCode(groupId: groupId, groupMemberId: groupMemberId))
    if case let .groupMemberCode(_, _, member, connectionCode) = r { return (member, connectionCode) }
    throw r.unexpected
}

func apiVerifyContact(_ contactId: Int64, connectionCode: String?) -> (Bool, String)? {
    let r: APIResult<ChatResponse0> = chatApiSendCmdSync(.apiVerifyContact(contactId: contactId, connectionCode: connectionCode))
    if case let .result(.connectionVerified(_, verified, expectedCode), _) = r { return (verified, expectedCode) }
    logger.error("apiVerifyContact error: \(String(describing: r))")
    return nil
}

func apiVerifyGroupMember(_ groupId: Int64, _ groupMemberId: Int64, connectionCode: String?) -> (Bool, String)? {
    let r: APIResult<ChatResponse0> = chatApiSendCmdSync(.apiVerifyGroupMember(groupId: groupId, groupMemberId: groupMemberId, connectionCode: connectionCode))
    if case let .result(.connectionVerified(_, verified, expectedCode), _) = r { return (verified, expectedCode) }
    logger.error("apiVerifyGroupMember error: \(String(describing: r))")
    return nil
}

func apiDeleteChat(type: ChatType, id: Int64, chatDeleteMode: ChatDeleteMode = .full(notify: true)) async throws {
    let chatId = type.rawValue + id.description
    await MainActor.run { _ = ChatModel.shared.deletedChats.insert(chatId) }
    defer { Task { @MainActor in ChatModel.shared.deletedChats.remove(chatId) } }
    let r: ChatResponse1 = try await chatSendCmd(.apiDeleteChat(type: type, id: id, chatDeleteMode: chatDeleteMode), bgTask: false)
    if case .direct = type, case .contactDeleted = r { return }
    if case .contactConnection = type, case .contactConnectionDeleted = r { return }
    if case .group = type, case .groupDeletedUser = r { return }
    throw r.unexpected
}

func deleteChat(_ chat: Chat, chatDeleteMode: ChatDeleteMode = .full(notify: true)) async {
    do {
        let cInfo = await MainActor.run { chat.chatInfo }
        try await apiDeleteChat(type: cInfo.chatType, id: cInfo.apiId, chatDeleteMode: chatDeleteMode)
        await MainActor.run {
            ChatModel.shared.removeChat(cInfo.id)
            UnifiedConnectionHandler.shared.removePeerByChatID(cInfo.id)
        }
    } catch let error {
        logger.error("deleteChat apiDeleteChat error: \(responseError(error))")
        await AlertManager.shared.showAlertMsg(
            title: LocalizedStringKey(NSLocalizedString("model_error_deleting_chat_title", comment: "alert title")),
            message: LocalizedStringKey(String(format: NSLocalizedString("model_error_detail_message", comment: "alert message"), responseError(error)))
        )
    }
}

func apiClearChat(type: ChatType, id: Int64) async throws -> ChatInfo {
    let r: ChatResponse1 = try await chatSendCmd(.apiClearChat(type: type, id: id), bgTask: false)
    if case let .chatCleared(_, updatedChatInfo) = r { return updatedChatInfo }
    throw r.unexpected
}

func clearChat(_ chat: Chat) async {
    do {
        let cInfo = await MainActor.run { chat.chatInfo }
        let updatedChatInfo = try await apiClearChat(type: cInfo.chatType, id: cInfo.apiId)
        await MainActor.run { ChatModel.shared.clearChat(updatedChatInfo) }
    } catch {
        logger.error("clearChat apiClearChat error: \(responseError(error))")
        showAlert(NSLocalizedString("model_error_clearing_chat_title", comment: "alert title"), message: responseError(error))
    }
}

func apiUpdateProfile(profile: Profile) async throws -> (Profile, [Contact])? {
    let userId = try await currentUserId("apiUpdateProfile")
    let r: APIResult<ChatResponse1> = await chatApiSendCmd(.apiUpdateProfile(userId: userId, profile: profile))
    switch r {
    case .result(.userProfileNoChange, _): return (profile, [])
    case let .result(.userProfileUpdated(_, _, toProfile, updateSummary), _): return (toProfile, updateSummary.changedContacts)
    case .error(.errorStore(.duplicateName), _), .error(.error(.userExists), _): return nil;
    case .error(.invalidJSON(let json), _):
        if let data = json, let str = String(data: data, encoding: .utf8), str.contains("duplicateName") { return nil }
        fallthrough
    default:
        await MainActor.run {
            showErrorAlert(r.unexpected, NSLocalizedString("Error saving profile", comment: "alert title"))
        }
        throw r.unexpected
    }
}

func apiSetProfileAddress(on: Bool) async throws -> User? {
    let userId = try await currentUserId("apiSetProfileAddress")
    let r: ChatResponse1 = try await chatSendCmd(.apiSetProfileAddress(userId: userId, on: on))
    switch r {
    case .userProfileNoChange: return nil
    case let .userProfileUpdated(user, _, _, _): return user
    default: throw r.unexpected
    }
}

func apiSetConnectionAlias(connId: Int64, localAlias: String) async throws -> PendingContactConnection? {
    let r: ChatResponse1 = try await chatSendCmd(.apiSetConnectionAlias(connId: connId, localAlias: localAlias))
    if case let .connectionAliasUpdated(_, toConnection) = r { return toConnection }
    throw r.unexpected
}

func apiSetUserUIThemes(userId: Int64, themes: ThemeModeOverrides?) async -> Bool {
    do {
        try await sendCommandOkResp(.apiSetUserUIThemes(userId: userId, themes: themes))
        return true
    } catch {
        logger.error("apiSetUserUIThemes bad response: \(responseError(error))")
        return false
    }
}

func apiSetChatUIThemes(chatId: ChatId, themes: ThemeModeOverrides?) async -> Bool {
    do {
        try await sendCommandOkResp(.apiSetChatUIThemes(chatId: chatId, themes: themes))
        return true
    } catch {
        logger.error("apiSetChatUIThemes bad response: \(responseError(error))")
        return false
    }
}


func apiCreateUserAddress() async throws -> CreatedConnLink? {
    let userId = try await currentUserId("apiCreateUserAddress")
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiCreateMyAddress(userId: userId))
    if case let .result(.userContactLinkCreated(_, connLink, encryptedConnLink), _) = r {
        logger.info("apiCreateUserAddress: encryptedConnLink present=\(encryptedConnLink != nil), prefix=\(encryptedConnLink.map { String($0.prefix(8)) + "..." } ?? "nil")")
        var mutableConnLink = connLink
        if let enc = encryptedConnLink {
            mutableConnLink.encryptedConnLink = enc
        } else if mutableConnLink.encryptedConnLink == nil {
            mutableConnLink.encryptedConnLink = encryptConnLinkText(mutableConnLink.connFullLink)
        }
        if let enc = mutableConnLink.encryptedConnLink {
            groupDefaults.set(enc, forKey: GROUP_DEFAULT_ENCRYPTED_CONN_LINK)
            logger.info("apiCreateUserAddress: stored encryptedConnLink in UserDefaults")
        }
        return mutableConnLink
    }
    if case let .error(.errorAgent(.NOTICE(server, preset, expires)), _) = r {
        showClientNotice(server, preset, expires)
        return nil
    }
    if let r { throw r.unexpected } else { return nil }
}

func apiDeleteUserAddress() async throws -> User? {
    let userId = try await currentUserId("apiDeleteUserAddress")
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiDeleteMyAddress(userId: userId))
    if case let .result(.userContactLinkDeleted(user), _) = r {
        groupDefaults.removeObject(forKey: GROUP_DEFAULT_ENCRYPTED_CONN_LINK)
        return user
    }
    if let r { throw r.unexpected } else { return nil }
}

@MainActor
func apiGetUserAddress() throws -> UserContactLink? {
    let userId = try currentUserId("apiGetUserAddress")
    return try userAddressResponse(chatApiSendCmdSync(.apiShowMyAddress(userId: userId)))
}

func apiGetUserAddressAsync() async throws -> UserContactLink? {
    let userId = try await currentUserId("apiGetUserAddressAsync")
    return try userAddressResponse(await chatApiSendCmd(.apiShowMyAddress(userId: userId)))
}

private func userAddressResponse(_ r: APIResult<ChatResponse1>) throws -> UserContactLink? {
    logger.debug("userAddressResponse: response type=\(r.responseType)")
    switch r {
    case let .result(.userContactLink(_, contactLink), _):
        logger.debug("userAddressResponse: SUCCESS - got contact link")
        let storedEncLink = groupDefaults.string(forKey: GROUP_DEFAULT_ENCRYPTED_CONN_LINK)
        logger.info("userAddressResponse: storedEncLink=\(storedEncLink ?? "nil")")
        var updatedLink = contactLink
        if let storedEncLink = storedEncLink {
            updatedLink.connLinkContact.encryptedConnLink = storedEncLink
            logger.info("userAddressResponse: applied stored encryptedConnLink")
        } else if updatedLink.connLinkContact.encryptedConnLink == nil {
            updatedLink.connLinkContact.encryptedConnLink = encryptConnLinkText(updatedLink.connLinkContact.connFullLink)
            if let enc = updatedLink.connLinkContact.encryptedConnLink {
                groupDefaults.set(enc, forKey: GROUP_DEFAULT_ENCRYPTED_CONN_LINK)
            }
        }
        logger.info("userAddressResponse: final encryptedConnLink=\(updatedLink.connLinkContact.encryptedConnLink ?? "nil")")
        return updatedLink
    case let .error(e, _):
        if case .errorStore(storeError: .userContactLinkNotFound) = e {
            logger.debug("userAddressResponse: userContactLinkNotFound, returning nil")
            return nil
        }
        if case let .invalidJSON(json) = e,
           let data = json, let str = String(data: data, encoding: .utf8), str.contains("userContactLinkNotFound") {
            logger.debug("userAddressResponse: userContactLinkNotFound (invalidJSON fallback), returning nil")
            return nil
        }
        logger.warning("userAddressResponse: ERROR - \(e)")
        throw r.unexpected
    default:
        logger.error("userAddressResponse: UNEXPECTED - \(r.responseType)")
        throw r.unexpected
    }
}

func apiAddMyAddressShortLink() async throws -> UserContactLink? {
    let userId = try await currentUserId("apiAddMyAddressShortLink")
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiAddMyAddressShortLink(userId: userId))
    if case let .result(.userContactLink(_, contactLink), _) = r { return contactLink }
    if let r { throw r.unexpected } else { return nil }
}

func apiSetUserAddressSettings(_ settings: AddressSettings) async throws -> UserContactLink? {
    let userId = try await currentUserId("apiSetUserAddressSettings")
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiSetAddressSettings(userId: userId, addressSettings: settings))
    switch r {
    case let .result(.userContactLinkUpdated(_, contactLink), _): return contactLink
    case .error(.errorStore(storeError: .userContactLinkNotFound), _): return nil
    case .error(.invalidJSON(let json), _):
        if let data = json, let str = String(data: data, encoding: .utf8), str.contains("userContactLinkNotFound") { return nil }
        if let r { throw r.unexpected } else { return nil }
    default: if let r { throw r.unexpected } else { return nil }
    }
}

func apiChatRead(type: ChatType, id: Int64) async throws {
    try await sendCommandOkResp(.apiChatRead(type: type, id: id, scope: nil))
}

func apiSupportChatRead(type: ChatType, id: Int64, scope: GroupChatScope) async throws -> (GroupInfo, GroupMember) {
    let r: ChatResponse2 = try await chatSendCmd(.apiChatRead(type: type, id: id, scope: scope))
    if case let .memberSupportChatRead(_, groupInfo, member) = r { return (groupInfo, member) }
    throw r.unexpected
}

func apiChatItemsRead(type: ChatType, id: Int64, scope: GroupChatScope?, itemIds: [Int64]) async throws -> ChatInfo {
    let r: ChatResponse1 = try await chatSendCmd(.apiChatItemsRead(type: type, id: id, scope: scope, itemIds: itemIds))
    if case let .itemsReadForChat(_, updatedChatInfo) = r { return updatedChatInfo }
    throw r.unexpected
}

func apiChatUnread(type: ChatType, id: Int64, unreadChat: Bool) async throws {
    try await sendCommandOkResp(.apiChatUnread(type: type, id: id, unreadChat: unreadChat))
}

func uploadStandaloneFile(user: any UserLike, file: CryptoFile, ctrl: chat_ctrl? = nil) async -> (FileTransferMeta?, String?) {
    let r: APIResult<ChatResponse2> = await chatApiSendCmd(.apiUploadStandaloneFile(userId: user.userId, file: file), ctrl: ctrl)
    if case let .result(.sndStandaloneFileCreated(_, fileTransferMeta), _) = r {
        return (fileTransferMeta, nil)
    } else {
        let err = responseError(r.unexpected)
        logger.error("uploadStandaloneFile error: \(err)")
        return (nil, err)
    }
}

func downloadStandaloneFile(user: any UserLike, url: String, file: CryptoFile, ctrl: chat_ctrl? = nil) async -> (RcvFileTransfer?, String?) {
    let r: APIResult<ChatResponse2> = await chatApiSendCmd(.apiDownloadStandaloneFile(userId: user.userId, url: url, file: file), ctrl: ctrl)
    if case let .result(.rcvStandaloneFileCreated(_, rcvFileTransfer), _) = r {
        return (rcvFileTransfer, nil)
    } else {
        let err = responseError(r.unexpected)
        logger.error("downloadStandaloneFile error: \(err)")
        return (nil, err)
    }
}

func standaloneFileInfo(url: String, ctrl: chat_ctrl? = nil) async -> MigrationFileLinkData? {
    let r: APIResult<ChatResponse2> = await chatApiSendCmd(.apiStandaloneFileInfo(url: url), ctrl: ctrl)
    if case let .result(.standaloneFileInfo(fileMeta), _) = r {
        return fileMeta
    } else {
        logger.error("standaloneFileInfo error: \(responseError(r.unexpected))")
        return nil
    }
}

// Spec: spec/services/files.md#receiveFile
func receiveFile(user: any UserLike, fileId: Int64, userApprovedRelays: Bool = false, auto: Bool = false) async {
    await receiveFiles(
        user: user,
        fileIds: [fileId],
        userApprovedRelays: userApprovedRelays,
        auto: auto
    )
}

func receiveFiles(user: any UserLike, fileIds: [Int64], userApprovedRelays: Bool = false, auto: Bool = false) async {
    var fileIdsToApprove: [Int64] = []
    var srvsToApprove: Set<String> = []
    var otherFileErrs: [APIResult<ChatResponse2>] = []

    for fileId in fileIds {
        let r: APIResult<ChatResponse2> = await chatApiSendCmd(
            .receiveFile(
                fileId: fileId,
                userApprovedRelays: userApprovedRelays || !privacyAskToApproveRelaysGroupDefault.get(),
                encrypted: privacyEncryptLocalFilesGroupDefault.get(),
                inline: nil
            )
        )
        switch r {
        case let .result(.rcvFileAccepted(_, chatItem), _):
            await chatItemSimpleUpdate(user, chatItem)
            // TODO [BLOCKED: rcvFileAcceptedSndCancelled event not yet implemented in upstream FFI]
            //        case let .rcvFileAcceptedSndCancelled(user, aChatItem, _):
            //            await chatItemSimpleUpdate(user, aChatItem)
            //            Task { cleanupFile(aChatItem) }
        case let .error(.error(.fileNotApproved(fileId, unknownServers)), _):
            fileIdsToApprove.append(fileId)
            srvsToApprove.formUnion(unknownServers)
        default:
            otherFileErrs.append(r)
        }
    }

    if !auto {
        let otherErrsStr = fileErrorStrs(otherFileErrs)
        // If there are not approved files, alert is shown the same way both in case of singular and plural files reception
        if !fileIdsToApprove.isEmpty {
            let srvs = srvsToApprove
                .map { s in
                    if let srv = parseServerAddress(s), !srv.hostnames.isEmpty {
                        srv.hostnames[0]
                    } else {
                        serverHost(s)
                    }
                }
                .sorted()
                .joined(separator: ", ")
            let fIds = fileIdsToApprove
            await MainActor.run {
                showAlert(
                    title: NSLocalizedString("Unknown servers!", comment: "alert title"),
                    message: (
                        String.localizedStringWithFormat(NSLocalizedString("Without Tor or VPN, your IP address will be visible to these XFTP relays: %@.", comment: "alert message"), srvs) +
                        (otherErrsStr != "" ? "\n\n" + String.localizedStringWithFormat(NSLocalizedString("Other file errors:\n%@", comment: "alert message"), otherErrsStr) : "")
                    ),
                    buttonTitle: NSLocalizedString("Download", comment: "alert button"),
                    buttonAction: {
                        Task {
                            logger.debug("apiReceiveFile fileNotApproved alert - in Task")
                            if let user = ChatModel.shared.currentUser {
                                await receiveFiles(user: user, fileIds: fIds, userApprovedRelays: true)
                            }
                        }
                    },
                    cancelButton: true
                )
            }
        } else if let errorResponse = otherFileErrs.first, otherFileErrs.count == 1 {
            switch errorResponse {
            case let .result(.rcvFileAcceptedSndCancelled(_, rcvFileTransfer), _):
                logger.debug("receiveFiles error: sender cancelled file transfer \(rcvFileTransfer.fileId)")
                await MainActor.run {
                    showAlert(
                        NSLocalizedString("Cannot receive file", comment: "alert title"),
                        message: NSLocalizedString("Sender cancelled file transfer.", comment: "alert message")
                    )
                }
            case .error(.error(.fileCancelled), _), .error(.error(.fileAlreadyReceiving), _):
                logger.debug("receiveFiles ignoring FileCancelled or FileAlreadyReceiving error")
            default:
                await MainActor.run {
                    showAlert(
                        NSLocalizedString("Error receiving file", comment: "alert title"),
                        message: responseError(errorResponse.unexpected)
                    )
                }
            }
        } else if otherFileErrs.count > 1 { // If there are multiple other errors, we show general alert
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error receiving file", comment: "alert title"),
                    message: String.localizedStringWithFormat(NSLocalizedString("File errors:\n%@", comment: "alert message"), otherErrsStr)
                )
            }
        }
    }

    func fileErrorStrs(_ errs: [APIResult<ChatResponse2>]) -> String {
        var errStr = ""
        if errs.count >= 1 {
            errStr = String(describing: errs[0].unexpected)
        }
        if errs.count >= 2 {
            errStr += "\n\(String(describing: errs[1].unexpected))"
        }
        if errs.count > 2 {
            errStr += "\n" + String(format: NSLocalizedString("error_and_others_count", comment: "Appended when more than 2 errors occur"), errs.count - 2)
        }
        return errStr
    }
}

// Spec: spec/services/files.md#cancelFile
func cancelFile(user: User, fileId: Int64) async {
    if let chatItem = await apiCancelFile(fileId: fileId) {
        await chatItemSimpleUpdate(user, chatItem)
        cleanupFile(chatItem)
    }
}

func apiCancelFile(fileId: Int64, ctrl: chat_ctrl? = nil) async -> AChatItem? {
    let r: APIResult<ChatResponse2> = await chatApiSendCmd(.cancelFile(fileId: fileId), ctrl: ctrl)
    switch r {
    case let .result(.sndFileCancelled(_, chatItem, _, _), _): return chatItem
    case let .result(.rcvFileCancelled(_, chatItem, _), _): return chatItem
    default:
        logger.error("apiCancelFile error: \(responseError(r.unexpected))")
        return nil
    }
}

func setLocalDeviceName(_ displayName: String) throws {
    try sendCommandOkRespSync(.setLocalDeviceName(displayName: displayName))
}

// Spec: spec/architecture.md#connectRemoteCtrl
func connectRemoteCtrl(desktopAddress: String) async throws -> (RemoteCtrlInfo?, CtrlAppInfo, String) {
    let r: ChatResponse2 = try await chatSendCmd(.connectRemoteCtrl(xrcpInvitation: desktopAddress))
    if case let .remoteCtrlConnecting(rc_, ctrlAppInfo, v) = r { return (rc_, ctrlAppInfo, v) }
    throw r.unexpected
}

func confirmRemoteCtrl(_ rcId: Int64) async throws -> (RemoteCtrlInfo?, CtrlAppInfo, String) {
    let r: ChatResponse2 = try await chatSendCmd(.confirmRemoteCtrl(remoteCtrlId: rcId))
    if case let .remoteCtrlConnecting(rc_, ctrlAppInfo, v) = r { return (rc_, ctrlAppInfo, v) }
    throw r.unexpected
}

func verifyRemoteCtrlSession(_ sessCode: String) async throws -> RemoteCtrlInfo {
    let r: ChatResponse2 = try await chatSendCmd(.verifyRemoteCtrlSession(sessionCode: sessCode))
    if case let .remoteCtrlConnected(rc, _) = r { return rc }
    throw r.unexpected
}

func listRemoteCtrls() throws -> [RemoteCtrlInfo] {
    let r: ChatResponse2 = try chatSendCmdSync(.listRemoteCtrls)
    if case let .remoteCtrlList(rcInfo) = r { return rcInfo }
    throw r.unexpected
}

func stopRemoteCtrl() async throws {
    try await sendCommandOkResp(.stopRemoteCtrl)
}

func deleteRemoteCtrl(_ rcId: Int64) async throws {
    try await sendCommandOkResp(.deleteRemoteCtrl(remoteCtrlId: rcId))
}

func networkErrorAlert<R>(_ res: APIResult<R>) -> Alert? {
    if case let .error(e, _) = res, let alert = getNetworkErrorAlert(e) {
        let message = alert.message.map { LocalizedStringKey($0) }
        return mkAlert(title: LocalizedStringKey(alert.title), message: message)
    } else {
        return nil
    }
}

func apiSendCallInvitation(_ contact: Contact, _ callType: CallType) async throws {
    try await sendCommandOkResp(.apiSendCallInvitation(contact: contact, callType: callType))
}

func apiRejectCall(_ contact: Contact) async throws {
    try await sendCommandOkResp(.apiRejectCall(contact: contact))
}

func apiSendCallOffer(_ contact: Contact, _ rtcSession: String, _ rtcIceCandidates: String, media: CallMediaType, capabilities: CallCapabilities) async throws {
    let webRtcSession = WebRTCSession(rtcSession: rtcSession, rtcIceCandidates: rtcIceCandidates)
    let callOffer = WebRTCCallOffer(callType: CallType(media: media, capabilities: capabilities), rtcSession: webRtcSession)
    try await sendCommandOkResp(.apiSendCallOffer(contact: contact, callOffer: callOffer))
}

func apiSendCallAnswer(_ contact: Contact, _ rtcSession: String, _ rtcIceCandidates: String) async throws {
    let answer = WebRTCSession(rtcSession: rtcSession, rtcIceCandidates: rtcIceCandidates)
    try await sendCommandOkResp(.apiSendCallAnswer(contact: contact, answer: answer))
}

func apiSendCallExtraInfo(_ contact: Contact, _ rtcIceCandidates: String) async throws {
    let extraInfo = WebRTCExtraInfo(rtcSession: nil, rtcIceCandidates: rtcIceCandidates)
    try await sendCommandOkResp(.apiSendCallExtraInfo(contact: contact, extraInfo: extraInfo))
}

func apiEndCall(_ contact: Contact) async throws {
    try await sendCommandOkResp(.apiEndCall(contact: contact))
}

func apiGetCallInvitationsSync() throws -> [RcvCallInvitation] {
    let r: ChatResponse2 = try chatSendCmdSync(.apiGetCallInvitations)
    if case let .callInvitations(invs) = r { return invs }
    throw r.unexpected
}

func apiGetCallInvitations() async throws -> [RcvCallInvitation] {
    let r: ChatResponse2 = try await chatSendCmd(.apiGetCallInvitations)
    if case let .callInvitations(invs) = r { return invs }
    throw r.unexpected
}

func apiCallStatus(_ contact: Contact, _ status: String) async throws {
    if let callStatus = WebRTCCallStatus.init(rawValue: status) {
        try await sendCommandOkResp(.apiCallStatus(contact: contact, callStatus: callStatus))
    } else {
        logger.debug("apiCallStatus: call status \(status) not used")
    }
}

func markChatRead(_ im: ItemsModel, _ chat: Chat) async {
    do {
        if (await MainActor.run { chat.chatStats.unreadCount }) > 0 {
            let cInfo = await MainActor.run { chat.chatInfo }
            try await apiChatRead(type: cInfo.chatType, id: cInfo.apiId)
            await MainActor.run {
                withAnimation { ChatModel.shared.markAllChatItemsRead(im, cInfo) }
            }
        }
        if (await MainActor.run { chat.chatStats.unreadChat }) {
            await markChatUnread(chat, unreadChat: false)
        }
    } catch {
        logger.error("markChatRead apiChatRead error: \(responseError(error))")
    }
}

func markChatUnread(_ chat: Chat, unreadChat: Bool = true) async {
    do {
        let cInfo = await MainActor.run { chat.chatInfo }
        try await apiChatUnread(type: cInfo.chatType, id: cInfo.apiId, unreadChat: unreadChat)
        await MainActor.run {
            withAnimation { ChatModel.shared.markChatUnread(cInfo, unreadChat: unreadChat) }
        }
    } catch {
        logger.error("markChatUnread apiChatUnread error: \(responseError(error))")
    }
}

func markSupportChatRead(_ groupInfo: GroupInfo, _ member: GroupMember) async {
    do {
        if member.supportChatNotRead {
            let (updatedGroupInfo, updatedMember) = try await apiSupportChatRead(type: .group, id: groupInfo.apiId, scope: .memberSupport(groupMemberId_: member.groupMemberId))
            await MainActor.run {
                _ = ChatModel.shared.upsertGroupMember(updatedGroupInfo, updatedMember)
                ChatModel.shared.updateGroup(updatedGroupInfo)
            }
        }
    } catch {
        logger.error("markSupportChatRead apiChatRead error: \(responseError(error))")
    }
}

func apiMarkChatItemsRead(_ im: ItemsModel, _ cInfo: ChatInfo, _ itemIds: [ChatItem.ID], mentionsRead: Int) async {
    do {
        let updatedChatInfo = try await apiChatItemsRead(type: cInfo.chatType, id: cInfo.apiId, scope: cInfo.groupChatScope(), itemIds: itemIds)
        await MainActor.run {
            ChatModel.shared.updateChatInfo(updatedChatInfo)
            ChatModel.shared.markChatItemsRead(im, cInfo, itemIds, mentionsRead)
        }
    } catch {
        logger.error("apiChatItemsRead error: \(responseError(error))")
    }
}

private func sendCommandOkResp(_ cmd: ChatCommand, ctrl: chat_ctrl? = nil) async throws {
    let r: ChatResponse2 = try await chatSendCmd(cmd, ctrl: ctrl)
    if case .cmdOk = r { return }
    throw r.unexpected
}

private func sendCommandOkRespSync(_ cmd: ChatCommand) throws {
    let r: ChatResponse2 = try chatSendCmdSync(cmd)
    if case .cmdOk = r { return }
    throw r.unexpected
}

func apiGetVersion() throws -> CoreVersionInfo {
    let r: ChatResponse2 = try chatSendCmdSync(.showVersion)
    if case let .versionInfo(info, _, _) = r { return info }
    throw r.unexpected
}

func getAgentSubsTotal() async throws -> (SMPServerSubs, Bool) {
    let userId = try await currentUserId("getAgentSubsTotal")
    let r: ChatResponse2 = try await chatSendCmd(.getAgentSubsTotal(userId: userId), log: false)
    if case let .agentSubsTotal(_, subsTotal, hasSession) = r { return (subsTotal, hasSession) }
    logger.error("getAgentSubsTotal error: \(String(describing: r))")
    throw r.unexpected
}

@MainActor
func getAgentServersSummary() throws -> PresentedServersSummary {
    let userId = try currentUserId("getAgentServersSummary")
    let r: ChatResponse2 = try chatSendCmdSync(.getAgentServersSummary(userId: userId), log: false)
    if case let .agentServersSummary(_, serversSummary) = r { return serversSummary }
    logger.error("getAgentServersSummary error: \(String(describing: r))")
    throw r.unexpected
}

func resetAgentServersStats() async throws {
    try await sendCommandOkResp(.resetAgentServersStats)
}

// log: false because the code is a bearer secret until it is redeemed - it is in the command.
// nil when the user cancels the retry alert.
func apiRedeemBadgeCode(_ userId: Int64, _ code: String) async throws -> (user: User, newBadge: Bool, badgeState: BadgeState?)? {
    let r: APIResult<ChatResponse2>? = await chatApiSendCmdWithRetry(.apiRedeemBadgeCode(userId: userId, code: code), log: false)
    guard let r else { return nil }
    // redeemedBadge is dropped: the user's profile carries what is shown
    if case let .result(.badgeRedeemed(user, _, newBadge, badgeState), _) = r { return (user, newBadge, badgeState) }
    throw r.unexpected
}

// localized where the user can act on it; otherwise the error itself, so a screenshot says what happened
func redeemErrorText(_ error: Error) -> String {
    if case let .error(.badgeRedeemError(e)) = error as? ChatError {
        switch e {
        case .invalidCode: return NSLocalizedString("This code is not valid.", comment: "alert message")
        case .serviceNotConfigured: return NSLocalizedString("This app version cannot redeem badge codes.", comment: "alert message")
        case .badgeActive: return NSLocalizedString("This profile already has a badge. Redeem the code on another profile, or once this badge ends.", comment: "alert message")
        case let .serviceError(code): if let text = badgeServiceErrorText(code) { return text }
        case let .invalidResponse(message):
            return String.localizedStringWithFormat(NSLocalizedString("The badge service sent an unexpected response: %@", comment: "alert message"), message)
        case .unknownKeyIndex, .credentialNotVerified: return NSLocalizedString("This app version cannot verify this badge. Please update the app.", comment: "alert message")
        }
    }
    return String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "alert message"), responseError(error))
}

func apiGetBadgeState(_ userId: Int64) async throws -> BadgeState? {
    let r: ChatResponse2 = try await chatSendCmd(.apiGetBadgeState(userId: userId))
    if case let .badgeState(_, badgeState) = r { return badgeState }
    throw r.unexpected
}

func apiGetBadgeStateSync(_ userId: Int64) throws -> BadgeState? {
    let r: ChatResponse2 = try chatSendCmdSync(.apiGetBadgeState(userId: userId))
    if case let .badgeState(_, badgeState) = r { return badgeState }
    throw r.unexpected
}

func apiGetBadgeLedger(_ userId: Int64, _ badgePurchaseId: Int64) async throws -> [StatementEntry] {
    let r: ChatResponse2 = try await chatSendCmd(.apiGetBadgeLedger(userId: userId, badgePurchaseId: badgePurchaseId))
    if case let .badgeLedger(_, badgeLedger) = r { return badgeLedger }
    throw r.unexpected
}

func apiAckBadgeAlert(_ userId: Int64, _ badgePurchaseId: Int64, _ alertKind: BadgeAlertKind, snooze: Bool, episode: String) async throws -> BadgeState? {
    let r: ChatResponse2 = try await chatSendCmd(.apiAckBadgeAlert(userId: userId, badgePurchaseId: badgePurchaseId, alertKind: alertKind, snooze: snooze, episode: episode))
    if case let .badgeState(_, badgeState) = r { return badgeState }
    throw r.unexpected
}

// An API call and not a stored flag: the ack is kept on the purchase in core, which then stops
// raising this occurrence on every pass and across restarts, or until a snooze lapses.
func ackBadgeAlert(snooze: Bool) async {
    let badgeModel = BadgeModel.shared
    guard let userId = badgeModel.userId, let purchaseId = badgeModel.badgeState?.badgePurchaseId, let alert = badgeModel.alert else { return }
    do {
        let badgeState = try await apiAckBadgeAlert(userId, purchaseId, alert.kind, snooze: snooze, episode: alert.episode)
        await MainActor.run { badgeModel.set(userId: userId, badgeState: badgeState) }
    } catch let error {
        logger.error("ackBadgeAlert: \(responseError(error))")
    }
}

@MainActor
func currentUserId(_ funcName: String) throws -> Int64 {
    if let userId = ChatModel.shared.currentUser?.userId {
        return userId
    }
    throw RuntimeError("\(funcName): no current user")
}

@MainActor
func initializeChat(start: Bool, confirmStart: Bool = false, dbKey: String? = nil, refreshInvitations: Bool = true, confirmMigrations: MigrationConfirmation? = nil) async throws {
    let m = ChatModel.shared
    m.ctrlInitInProgress = true
    defer { m.ctrlInitInProgress = false }
    
    logger.debug("initializeChat: STARTING - start=\(start), confirmStart=\(confirmStart)")
    logger.debug("initializeChat: Before chatMigrateInit - chatInitialized=\(m.chatInitialized)")
    
    (m.chatDbEncrypted, m.chatDbStatus) = chatMigrateInit(dbKey, confirmMigrations: confirmMigrations)
    
    logger.debug("initializeChat: After chatMigrateInit - chatDbStatus=\(String(describing: m.chatDbStatus)), chatDbEncrypted=\((m.chatDbEncrypted ?? false) ? "true" : "false")")

    // Check if chat controller was successfully initialized
    // If chatController is nil, the Haskell FFI call failed and all subsequent API calls will fail
    if getChatCtrl() == nil {
        let status = String(describing: m.chatDbStatus)
        let dbPath = getAppDatabasePath().path
        logger.error("initializeChat: chatController is nil after chatMigrateInit, status: \(status), dbPath: \(dbPath)")
        throw RuntimeError("Database initialization failed: chatController is nil, dbStatus=\(status)")
    }
    
    logger.debug("initializeChat: chatController initialized successfully")
    if m.chatDbStatus != .ok {
        logger.debug("initializeChat: clearing chatDbStatus from \(String(describing: m.chatDbStatus)) to .ok - controller is functional")
        m.chatDbStatus = .ok
    }

    NetworkObserver.shared.restartMonitor()
    // If we migrated successfully means previous re-encryption process on database level finished successfully too
    if encryptionStartedDefault.get() {
        encryptionStartedDefault.set(false)
    }
    
    logger.debug("initializeChat: Setting app file paths...")
    try apiSetAppFilePaths(filesFolder: getAppFilesDirectory().path, tempFolder: getTempFilesDirectory().path, assetsFolder: getWallpaperDirectory().deletingLastPathComponent().path)
    logger.debug("initializeChat: Setting encrypt local files...")
    try apiSetEncryptLocalFiles(privacyEncryptLocalFilesGroupDefault.get())
    logger.debug("initializeChat: Setting chatInitialized = true")
    m.chatInitialized = true
    do {
        logger.debug("initializeChat: Calling apiGetActiveUser to check for existing user...")
        m.currentUser = try apiGetActiveUser()
        if let user = m.currentUser {
            logger.debug("initializeChat: Found existing user: userId=\(user.userId, privacy: .private)")
        } else {
            logger.debug("initializeChat: No existing user found - deferring to startChat/listUsers")
        }
    } catch {
        logger.error("initializeChat: apiGetActiveUser failed: \(responseError(error))")
        m.currentUser = nil
    }
    Task {
        await UnifiedIdentityManager.shared.initialize()
    }
    do {
        let conditions: ServerOperatorConditions = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ServerOperatorConditions, Error>) in
            ffiQueue.async {
                do { cont.resume(returning: try getServerOperatorsSync()) }
                catch { cont.resume(throwing: error) }
            }
        }
        await MainActor.run {
            m.conditions = conditions
            logger.debug("initializeChat: getServerOperatorsSync returned - operators=\(conditions.serverOperators.count), conditionsId=\(conditions.currentConditions.conditionsId)")
        }
        if conditions.serverOperators.isEmpty {
            logger.warning("getServerOperatorsSync returned empty operators, retrying with longer delay...")
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            let retry: ServerOperatorConditions = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ServerOperatorConditions, Error>) in
                ffiQueue.async {
                    do { cont.resume(returning: try getServerOperatorsSync()) }
                    catch { cont.resume(throwing: error) }
                }
            }
            await MainActor.run { m.conditions = retry }
        }
    } catch {
        logger.error("getServerOperatorsSync failed: \(responseError(error)), retrying with longer delay...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        do {
            let retry: ServerOperatorConditions = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ServerOperatorConditions, Error>) in
                ffiQueue.async {
                    do { cont.resume(returning: try getServerOperatorsSync()) }
                    catch { cont.resume(throwing: error) }
                }
            }
            await MainActor.run { m.conditions = retry }
        } catch {
            logger.error("getServerOperatorsSync retry failed: \(responseError(error)), using empty")
            await MainActor.run { m.conditions = .empty }
        }
    }
    if shouldImportAppSettingsDefault.get() {
        do {
            let appSettings = try apiGetAppSettings(settings: AppSettings.current.prepareForExport())
            appSettings.importIntoApp()
            shouldImportAppSettingsDefault.set(false)
        } catch {
            logger.error("Error while importing app settings: \(error)")
        }
    }
    if m.currentUser == nil {
        let currentStage = onboardingStageDefault.get()
        if currentStage != .onboardingComplete {
            advanceOnboarding(to: .step1_WelcomeIdentity)
        } else if !hasDatabase() {
            // DB was deleted but onboarding stage persists (simulator erase incomplete, app reinstall)
            // Reset onboarding so user goes through setup again
            logger.debug("initializeChat: no user, onboarding complete, but no database - resetting to step1")
            advanceOnboarding(to: .step1_WelcomeIdentity)
        } else {
            // DB exists but no active user - check if there are any users at all
            do {
                let users = try listUsers()
                if users.isEmpty {
                    // Database is empty (fresh install or all users deleted) - reset onboarding
                    logger.debug("initializeChat: no user, onboarding complete, database exists but empty - resetting to step1")
                    advanceOnboarding(to: .step1_WelcomeIdentity)
                } else {
                    // There are users but none is active - this shouldn't happen normally
                    // Keep onboarding stage, user selection will be handled elsewhere
                    logger.debug("initializeChat: no active user but \(users.count) users exist, keeping onboarding stage")
                }
            } catch {
                // Failed to list users - database might be corrupted or key wrong
                logger.error("initializeChat: failed to list users: \(error), resetting to step1")
                advanceOnboarding(to: .step1_WelcomeIdentity)
            }
        }
        privacyDeliveryReceiptsSet.set(true)
    } else if confirmStart {
        showStartChatAfterRestartAlert { start in
            do {
                if start { AppChatState.shared.set(.active) }
                try chatInitialized(start: start, refreshInvitations: refreshInvitations)
            } catch let error {
                logger.error("ChatInitialized error: \(error)")
            }
        }
    } else {
        try chatInitialized(start: start, refreshInvitations: refreshInvitations)
    }
}

func showStartChatAfterRestartAlert(result: @escaping (_ start: Bool) -> Void) {
    Task { @MainActor in
        AlertManager.shared.showAlert(Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("api_start_chat_title", comment: "Start chat alert title"))),
            message: Text(LocalizedStringKey(NSLocalizedString("api_start_chat_message", comment: "Start chat alert message"))),
            primaryButton: .default(Text(LocalizedStringKey(NSLocalizedString("api_start_chat_ok", comment: "OK button")))) {
                result(true)
            },
            secondaryButton: .cancel {
                result(false)
            }
        ))
    }
}

@MainActor
private func chatInitialized(start: Bool, refreshInvitations: Bool) throws {
    let m = ChatModel.shared
    if m.currentUser == nil { return }
    if start {
        try startChat(refreshInvitations: refreshInvitations)
    } else {
        m.chatRunning = false
        try getUserChatData()
        Task { @MainActor in NtfManager.shared.setNtfBadgeCount(m.totalUnreadCountForAllUsers()) }
        m.onboardingStage = onboardingStageDefault.get()
    }
}

// Spec: spec/architecture.md#startChat
@MainActor
func startChat(refreshInvitations: Bool = true, onboarding: Bool = false) throws {
    logger.debug("startChat")
    let m = ChatModel.shared
    try setNetworkConfig(getNetCfg())
    let chatRunning = try apiCheckChatRunning()
    m.users = try listUsers()
    if !chatRunning {
        try getUserChatData()
        Task { @MainActor in NtfManager.shared.setNtfBadgeCount(m.totalUnreadCountForAllUsers()) }
        if (refreshInvitations) {
            Task { try? await refreshCallInvitations() }
        }
        (m.savedToken, m.tokenStatus, m.notificationMode, m.notificationServer) = apiGetNtfToken()
        _ = try apiStartChat()
        // deviceToken is set when AppDelegate.application(didRegisterForRemoteNotificationsWithDeviceToken:) is called,
        // when it is called before startChat
        if let token = m.deviceToken {
            registerToken(token: token)
        }
        if !onboarding {
            withAnimation {
                let savedOnboardingStage = onboardingStageDefault.get()
                m.onboardingStage = savedOnboardingStage
                if m.onboardingStage == .onboardingComplete && !privacyDeliveryReceiptsSet.get() {
                    m.setDeliveryReceipts = true
                }
            }
        }
    }
    ChatReceiver.shared.start()
    m.chatRunning = true
    chatLastStartGroupDefault.set(Date.now)
    if shouldDeleteDatabaseBackupsDefault.get() {
        deleteDatabaseBackups()
        shouldDeleteDatabaseBackupsDefault.set(false)
    }
}

func startChatWithTemporaryDatabase(ctrl: chat_ctrl) throws -> User? {
    logger.debug("startChatWithTemporaryDatabase")
    let migrationActiveUser: User?
    do {
        migrationActiveUser = try apiGetActiveUser(ctrl: ctrl) ?? apiCreateActiveUser(Profile(displayName: "Temp", fullName: ""), ctrl: ctrl)
    } catch {
        logger.error("startChatWithTemporaryDatabase: failed to get/create active user: \(error)")
        migrationActiveUser = nil
    }
    try setNetworkConfig(getNetCfg(), ctrl: ctrl)
    try apiSetAppFilePaths(filesFolder: getMigrationTempFilesDirectory().path, tempFolder: getMigrationTempFilesDirectory().path, assetsFolder: getWallpaperDirectory().deletingLastPathComponent().path, ctrl: ctrl)
    _ = try apiStartChat(ctrl: ctrl)
    return migrationActiveUser
}

@MainActor
func changeActiveUser(_ userId: Int64, viewPwd: String?) {
    do {
        try changeActiveUser_(userId, viewPwd: viewPwd)
    } catch let error {
        logger.error("Unable to set active user: \(responseError(error))")
    }
}

@MainActor
private func changeActiveUser_(_ userId: Int64, viewPwd: String?) throws {
    let m = ChatModel.shared
    m.resetAllState()
    m.currentUser = try apiSetActiveUser(userId, viewPwd: viewPwd)
    m.users = try listUsers()
    try getUserChatData()
}

func changeActiveUserAsync_(_ userId: Int64?, viewPwd: String?, keepingChatId: String? = nil) async throws {
    let currentUser = if let userId = userId {
        try await apiSetActiveUserAsync(userId, viewPwd: viewPwd)
    } else {
        try apiGetActiveUser()
    }
    let users = try await listUsersAsync()
    await MainActor.run {
        let m = ChatModel.shared
        let wasRunning = m.chatRunning
        m.resetAllState()
        m.chatRunning = wasRunning
        m.currentUser = currentUser
        m.users = users
        m.onboardingStage = .onboardingComplete
    }
    try await getUserChatDataAsync(keepingChatId: keepingChatId)
    await MainActor.run {
        if let currentUser = currentUser, var (_, invitation) = ChatModel.shared.callInvitations.first(where: { _, inv in inv.user.userId == userId }) {
            invitation.user = currentUser
            activateCall(invitation)
        }
    }
}

@MainActor
func getUserChatData() throws {
    let m = ChatModel.shared
    m.userAddress = try apiGetUserAddress()
    m.chatItemTTL = try getChatItemTTL()
    let chats = try apiGetChats()
    let tags = try apiGetChatTags()
    m.updateChats(chats)
    let tm = ChatTagsModel.shared
    tm.activeFilter = nil
    tm.userTags = tags
    tm.updateChatTags(m.chats)
    loadBadgeState()
}

// Not thrown: a failed badge read must not stop the app starting, and the model is left alone
// rather than set to nil, which would read as "no badge".
@MainActor
private func loadBadgeState() {
    do {
        let userId = try currentUserId("loadBadgeState")
        let badgeState = try apiGetBadgeStateSync(userId)
        BadgeModel.shared.set(userId: userId, badgeState: badgeState)
    } catch let error {
        logger.error("loadBadgeState: \(responseError(error))")
    }
}

private func loadBadgeStateAsync(_ userId: Int64) async {
    do {
        let badgeState = try await apiGetBadgeState(userId)
        await MainActor.run { BadgeModel.shared.set(userId: userId, badgeState: badgeState) }
    } catch let error {
        logger.error("loadBadgeState: \(responseError(error))")
    }
}

private func getUserChatDataAsync(keepingChatId: String?) async throws {
    let m = await MainActor.run { ChatModel.shared }
    let tm = await MainActor.run { ChatTagsModel.shared }
    let currentUserId = await MainActor.run { m.currentUser?.userId }
    if let userId = currentUserId {
        let userAddress = try await apiGetUserAddressAsync()
        let chatItemTTL = try await getChatItemTTLAsync()
        let chats = try await apiGetChatsAsync()
        let tags = try await apiGetChatTagsAsync()
        await MainActor.run {
            m.userAddress = userAddress
            m.chatItemTTL = chatItemTTL
            m.updateChats(chats, keepingChatId: keepingChatId)
            tm.activeFilter = nil
            tm.userTags = tags
            tm.updateChatTags(m.chats)
        }
        await loadBadgeStateAsync(userId)
    } else {
        await MainActor.run {
            m.userAddress = nil
            m.updateChats([])
            tm.activeFilter = nil
            tm.userTags = []
            tm.presetTags = [:]
        }
    }
}

// Spec: spec/architecture.md#ChatReceiver
@MainActor
class ChatReceiver {
    private var receiveLoop: Task<Void, Never>?
    private var receiveMessages = true
    private var _lastMsgTime = Date.now

    var messagesChannel: ((APIResult<ChatEvent>) -> Void)? = nil

    static let shared = ChatReceiver()

    var lastMsgTime: Date { get { _lastMsgTime } }

    func start() {
        logger.debug("ChatReceiver.start")
        receiveMessages = true
        _lastMsgTime = .now
        if receiveLoop != nil { return }
        receiveLoop = Task { await receiveMsgLoop() }
    }

    func receiveMsgLoop() async {
        while self.receiveMessages {
            if let msg = await chatRecvMsg() {
                self._lastMsgTime = .now
                Task { await TerminalItems.shared.addResult(msg) }
                switch msg {
                case let .result(evt, _): await processReceivedMsg(evt)
                case let .error(err, _): logger.debug("chatRecvMsg error: \(responseError(err))")
                case let .invalid(type, json): logger.debug("chatRecvMsg event: * \(type) \(json.count) bytes")
                }
                if let messagesChannel {
                    messagesChannel(msg)
                }
            } else {
                _ = try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func stop() {
        logger.debug("ChatReceiver.stop")
        receiveMessages = false
        receiveLoop?.cancel()
        receiveLoop = nil
    }
}

@MainActor
func switchToLocalSession() {
    let m = ChatModel.shared
    m.remoteCtrlSession = nil
    do {
        m.users = try listUsers()
        try getUserChatData()
    } catch let error {
        logger.debug("error updating chat data: \(responseError(error))")
    }
}

func refreshCallInvitations() async throws {
    let m = await MainActor.run { ChatModel.shared }
    let callInvitations = try await apiGetCallInvitations()
    await MainActor.run {
        m.callInvitations = callsByChat(callInvitations)
        if let (chatId, ntfAction) = m.ntfCallInvitationAction,
           let invitation = m.callInvitations.removeValue(forKey: chatId) {
            m.ntfCallInvitationAction = nil
            CallController.shared.callAction(invitation: invitation, action: ntfAction)
        } else if let invitation = callInvitations.last(where: { $0.user.showNotifications }) {
            activateCall(invitation)
        }
    }
}

func justRefreshCallInvitations() async throws {
    let callInvitations = try apiGetCallInvitationsSync()
    await MainActor.run {
        ChatModel.shared.callInvitations = callsByChat(callInvitations)
    }
}

private func callsByChat(_ callInvitations: [RcvCallInvitation]) -> [ChatId: RcvCallInvitation] {
    callInvitations.reduce(into: [ChatId: RcvCallInvitation]()) {
        result, inv in result[inv.contact.id] = inv
    }
}

func activateCall(_ callInvitation: RcvCallInvitation) {
    Task { @MainActor in
        let m = ChatModel.shared
        logger.debug("reportNewIncomingCall activeCallUUID \(String(describing: m.activeCall?.callUUID)) invitationUUID \(String(describing: callInvitation.callUUID))")
        if !callInvitation.user.showNotifications || m.activeCall?.callUUID == callInvitation.callUUID { return }
        CallController.shared.reportNewIncomingCall(invitation: callInvitation) { error in
            if let error = error {
                DispatchQueue.main.async {
                    m.callInvitations[callInvitation.contact.id]?.callUUID = nil
                }
                logger.error("reportNewIncomingCall error: \(error.localizedDescription)")
            } else {
                logger.debug("reportNewIncomingCall success")
            }
        }
    }
}

private struct UserResponse: Decodable {
    var user: User?
    var error: String?
}

func showClientNotice(_ server: String, _ preset: Bool, _ expiresAt: Date?) {
    DispatchQueue.main.async {
        let serverType = preset
            ? NSLocalizedString("model_notice_preset_server", comment: "server type")
            : NSLocalizedString("model_notice_this_server", comment: "server type")
        var message = String(format: NSLocalizedString("model_notice_base_message", comment: "client notice message"), server, serverType)
        if let expiresAt {
            message += "\n\n" + String(format: NSLocalizedString("model_notice_expiry_message", comment: "client notice expiry"), expiresAt.formatted(date: .abbreviated, time: .shortened))
        }
        showAlert(NSLocalizedString("model_not_allowed_title", comment: "alert title"), message: message) {
            let howItWorks = UIAlertAction(title: NSLocalizedString("How it works", comment: "alert button"), style: .default, handler: { _ in
                UIApplication.shared.open(contentModerationPostLink)
            })
            return preset
                    ? [
                        okAlertAction,
                        UIAlertAction(title: NSLocalizedString("Conditions of use", comment: "alert button"), style: .default, handler: { _ in
                            UIApplication.shared.open(conditionsURL)
                        }),
                        howItWorks
                    ]
                    : [okAlertAction, howItWorks]
        }
    }
}
