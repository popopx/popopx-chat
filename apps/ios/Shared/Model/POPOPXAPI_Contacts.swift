//
//  POPOPXAPI_Contacts.swift
//  POPOPX
//
//  Extracted from POPOPXAPI.swift
//  Contact-related API functions
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import UIKit
import Dispatch
import BackgroundTasks
import SwiftUI
@preconcurrency import POPOPXSwitch

// MARK: - Contact Connection Functions

func apiAddContact(incognito: Bool) async -> ((CreatedConnLink, PendingContactConnection)?, Alert?) {
    let userId = await MainActor.run { ChatModel.shared.currentUser?.userId }
    guard let userId else {
        logger.error("apiAddContact: no current user")
        return (nil, nil)
    }
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiAddContact(userId: userId, incognito: incognito), bgTask: false)
    if case let .result(.invitation(_, connLinkInv, encryptedConnLink, connection), _) = r {
        var mutableConnLinkInv = connLinkInv
        if let enc = encryptedConnLink {
            mutableConnLinkInv.encryptedConnLink = enc
        } else if mutableConnLinkInv.encryptedConnLink == nil {
            mutableConnLinkInv.encryptedConnLink = encryptConnLinkText(mutableConnLinkInv.connFullLink)
        }
        var mutableConnection = connection
        mutableConnection.connLinkInv = mutableConnLinkInv
        return ((mutableConnLinkInv, mutableConnection), nil)
    }
    if let r { logger.error("apiAddContact error: \(responseError(r.unexpected))") }
    let alert: Alert? = if let r { connectionErrorAlert(r) } else { nil }
    return (nil, alert)
}

func apiSetConnectionIncognito(connId: Int64, incognito: Bool) async throws -> PendingContactConnection? {
    let r: ChatResponse1 = try await chatSendCmd(.apiSetConnectionIncognito(connId: connId, incognito: incognito))
    if case let .connectionIncognitoUpdated(_, toConnection) = r { return toConnection }
    throw r.unexpected
}

func apiChangeConnectionUser(connId: Int64, userId: Int64) async throws -> PendingContactConnection? {
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiChangeConnectionUser(connId: connId, userId: userId))
    if case let .result(.connectionUserChanged(_, _, toConnection, _), _) = r {return toConnection}
    if let r { throw r.unexpected } else { return nil }
}

func apiConnectPlan(connLink: String, linkOwnerSig: LinkOwnerSig? = nil, inProgress: BoxedValue<Bool>) async -> ((CreatedConnLink, ConnectionPlan)?, Alert?) {
    let userId = await MainActor.run { ChatModel.shared.currentUser?.userId }
    guard let userId else {
        logger.error("apiConnectPlan: no current user")
        return (nil, nil)
    }
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiConnectPlan(userId: userId, connLink: connLink, linkOwnerSig: linkOwnerSig), inProgress: inProgress)
    if case let .result(.connectionPlan(_, connLink, connPlan), _) = r { return ((connLink, connPlan), nil) }
    if let r { logger.error("apiConnectPlan error: \(responseError(r.unexpected))") }
    let alert: Alert? = if let r { apiConnectResponseAlert(r) } else { nil }
    return (nil, alert)
}

func apiConnect(incognito: Bool, connLink: CreatedConnLink) async -> (ConnReqType, PendingContactConnection)? {
    let (r, alert) = await apiConnect_(incognito: incognito, connLink: connLink)
    if let alert = alert {
        await AlertManager.shared.showAlert(alert)
        return nil
    } else {
        return r
    }
}

func apiConnect_(incognito: Bool, connLink: CreatedConnLink) async -> ((ConnReqType, PendingContactConnection)?, Alert?) {
    let userId = await MainActor.run { ChatModel.shared.currentUser?.userId }
    guard let userId else {
        logger.error("apiConnect: no current user")
        return (nil, nil)
    }
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiConnect(userId: userId, incognito: incognito, connLink: connLink))
    let m = await MainActor.run { ChatModel.shared }
    switch r {
    case let .result(.sentConfirmation(_, connection), _):
        return ((.invitation, connection), nil)
    case let .result(.sentInvitation(_, connection), _):
        return ((.contact, connection), nil)
    case let .result(.contactAlreadyExists(_, contact), _):
        await MainActor.run {
            if let c = m.getContactChat(contact.contactId) {
                ItemsModel.shared.loadOpenChat(c.id)
            }
        }
        let alert = contactAlreadyExistsAlert(contact)
        return (nil, alert)
    default: ()
    }
    if let r { logger.error("apiConnect error: \(responseError(r.unexpected))") }
    let alert: Alert? = if let r { apiConnectResponseAlert(r) } else { nil }
    return (nil, alert)
}

func apiConnectResponseAlert<R>(_ r: APIResult<R>) -> Alert {
    switch r.unexpected {
    case .error(.invalidConnReq):
        mkAlert(
            title: LocalizedStringKey(NSLocalizedString("model_invalid_connection_link_title", comment: "alert title")),
            message: LocalizedStringKey(NSLocalizedString("model_invalid_connection_link_message", comment: "alert message"))
        )
    case .error(.unsupportedConnReq):
        mkAlert(
            title: LocalizedStringKey(NSLocalizedString("model_unsupported_connection_link_title", comment: "alert title")),
            message: LocalizedStringKey(NSLocalizedString("model_unsupported_connection_link_message", comment: "alert message"))
        )
    case .errorAgent(.SMP(_, .AUTH)):
        mkAlert(
            title: LocalizedStringKey(NSLocalizedString("model_connection_error_auth_title", comment: "alert title")),
            message: LocalizedStringKey(NSLocalizedString("model_connection_error_auth_message", comment: "alert message"))
        )
    case let .errorAgent(.SMP(_, .BLOCKED(info))):
        Alert(
            title: Text(LocalizedStringKey(NSLocalizedString("api_contact_blocked_title", comment: "Connection blocked title"))),
            message: Text(LocalizedStringKey(String(format: NSLocalizedString("api_contact_blocked_message", comment: "Connection blocked message"), info.reason.text))),
            primaryButton: .default(Text(LocalizedStringKey(NSLocalizedString("api_contact_ok", comment: "OK button")))),
            secondaryButton: .default(Text(LocalizedStringKey(NSLocalizedString("api_contact_how_it_works", comment: "How it works button")))) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(contentModerationPostLink)
                }
            }
        )
    case .errorAgent(.SMP(_, .QUOTA)):
        mkAlert(
            title: LocalizedStringKey(NSLocalizedString("model_undelivered_messages_title", comment: "alert title")),
            message: LocalizedStringKey(NSLocalizedString("model_undelivered_messages_message", comment: "alert message"))
        )
    case let .errorAgent(.INTERNAL(internalErr)):
        if internalErr == "SEUniqueID" {
            mkAlert(
                title: LocalizedStringKey(NSLocalizedString("model_already_connected_title", comment: "alert title")),
                message: LocalizedStringKey(String(format: NSLocalizedString("model_already_connected_message", comment: "alert message"), internalErr))
            )
        } else {
            connectionErrorAlert(r)
        }
    default: connectionErrorAlert(r)
    }
}

func connErrorText(_ e: ChatError) -> String {
    switch e {
    case .error(.invalidConnReq):
        NSLocalizedString("Invalid connection link", comment: "conn error description")
    case .error(.unsupportedConnReq):
        NSLocalizedString("Unsupported connection link", comment: "conn error description")
    case .errorAgent(.SMP(_, .AUTH)):
        NSLocalizedString("Connection error (AUTH)", comment: "conn error description")
    case let .errorAgent(.SMP(_, .BLOCKED(info))):
        NSLocalizedString("Connection blocked: \(info.reason.text)", comment: "conn error description")
    case .errorAgent(.SMP(_, .QUOTA)):
        NSLocalizedString("The connection reached the limit of undelivered messages", comment: "conn error description")
    default:
        if getNetworkErrorAlert(e) != nil {
            NSLocalizedString("Network error", comment: "conn error description")
        } else {
            "\(NSLocalizedString("Error", comment: "conn error description")): \(responseError(e))"
        }
    }
}

func contactAlreadyExistsAlert(_ contact: Contact) -> Alert {
    mkAlert(
        title: LocalizedStringKey(NSLocalizedString("model_contact_already_exists_title", comment: "alert title")),
        message: LocalizedStringKey(String(format: NSLocalizedString("model_contact_already_exists_message", comment: "alert message"), contact.displayName))
    )
}

private func connectionErrorAlert<R>(_ r: APIResult<R>) -> Alert {
    if let networkErrorAlert = networkErrorAlert(r) {
        return networkErrorAlert
    } else {
        return mkAlert(
            title: LocalizedStringKey(NSLocalizedString("model_connection_error_title", comment: "alert title")),
            message: LocalizedStringKey(String(format: NSLocalizedString("model_connection_error_message", comment: "alert message"), responseError(r.unexpected)))
        )
    }
}

// MARK: - Prepared Contact Functions

func apiPrepareContact(connLink: CreatedConnLink, contactShortLinkData: ContactShortLinkData) async throws -> ChatData {
    let userId = try await currentUserId("apiPrepareContact")
    let r: ChatResponse1 = try await chatSendCmd(.apiPrepareContact(userId: userId, connLink: connLink, contactShortLinkData: contactShortLinkData))
    if case let .newPreparedChat(_, chat) = r { return chat }
    throw r.unexpected
}

func apiChangePreparedContactUser(contactId: Int64, newUserId: Int64) async throws -> Contact {
    let r: ChatResponse1 = try await chatSendCmd(.apiChangePreparedContactUser(contactId: contactId, newUserId: newUserId))
    if case let .contactUserChanged(_, _, _, toContact) = r {return toContact}
    throw r.unexpected
}

func apiConnectPreparedContact(contactId: Int64, incognito: Bool, msg: MsgContent?) async -> Contact? {
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiConnectPreparedContact(contactId: contactId, incognito: incognito, msg: msg))
    if case let .result(.startedConnectionToContact(_, contact), _) = r { return contact }
    if let r {
        logger.error("apiConnectPreparedContact error: \(responseError(r.unexpected))")
        await AlertManager.shared.showAlert(apiConnectResponseAlert(r))
    }
    return nil
}

func apiConnectContactViaAddress(incognito: Bool, contactId: Int64) async -> (Contact?, Alert?) {
    let userId = await MainActor.run { ChatModel.shared.currentUser?.userId }
    guard let userId else {
        logger.error("apiConnectContactViaAddress: no current user")
        return (nil, nil)
    }
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiConnectContactViaAddress(userId: userId, incognito: incognito, contactId: contactId))
    if case let .result(.sentInvitationToContact(_, contact, _), _) = r { return (contact, nil) }
    if let r {
        logger.error("apiConnectContactViaAddress error: \(responseError(r.unexpected))")
        return (nil, connectionErrorAlert(r))
    } else {
        return (nil, nil)
    }
}

// MARK: - Contact Deletion Functions

func apiDeleteContact(id: Int64, chatDeleteMode: ChatDeleteMode = .full(notify: true)) async throws -> Contact {
    let type: ChatType = .direct
    let chatId = type.rawValue + id.description
    if case .full = chatDeleteMode {
        await MainActor.run { _ = ChatModel.shared.deletedChats.insert(chatId) }
    }
    let r: ChatResponse1 = try await chatSendCmd(.apiDeleteChat(type: type, id: id, chatDeleteMode: chatDeleteMode), bgTask: false)
    if case let .contactDeleted(_, contact) = r {
        if case .full = chatDeleteMode {
            await MainActor.run { _ = ChatModel.shared.deletedChats.remove(chatId) }
        }
        return contact
    }
    throw r.unexpected
}

func deleteContactChat(_ chat: Chat, chatDeleteMode: ChatDeleteMode = .full(notify: true)) async -> Alert? {
    do {
        let cInfo = await MainActor.run { chat.chatInfo }
        let ct = try await apiDeleteContact(id: cInfo.apiId, chatDeleteMode: chatDeleteMode)
        await MainActor.run {
            withAnimation(nil) {
                switch chatDeleteMode {
                case .full:
                    ChatModel.shared.removeChat(cInfo.id)
                case .entity:
                    ChatModel.shared.removeChat(cInfo.id)
                    ChatModel.shared.addChat(Chat(
                        chatInfo: .direct(contact: ct),
                        chatItems: chat.chatItems
                    ))
                case .messages:
                    ChatModel.shared.removeChat(cInfo.id)
                    ChatModel.shared.addChat(Chat(
                        chatInfo: .direct(contact: ct),
                        chatItems: []
                    ))
                }
            }
            UnifiedConnectionHandler.shared.removePeerByChatID(cInfo.id)
        }
    } catch let error {
        logger.error("deleteContactChat apiDeleteContact error: \(responseError(error))")
        return mkAlert(
            title: LocalizedStringKey(NSLocalizedString("model_error_deleting_chat_title", comment: "alert title")),
            message: LocalizedStringKey(String(format: NSLocalizedString("model_error_detail_message", comment: "alert message"), responseError(error)))
        )
    }
    return nil
}

// MARK: - Contact List and Settings Functions

@MainActor
func apiListContacts() throws -> [Contact] {
    let userId = try currentUserId("apiListContacts")
    let r: ChatResponse1 = try chatSendCmdSync(.apiListContacts(userId: userId))
    if case let .contactsList(_, contacts) = r { return contacts }
    throw r.unexpected
}

func apiSetContactPrefs(contactId: Int64, preferences: Preferences) async throws -> Contact? {
    let r: ChatResponse1 = try await chatSendCmd(.apiSetContactPrefs(contactId: contactId, preferences: preferences))
    if case let .contactPrefsUpdated(_, _, toContact) = r { return toContact }
    throw r.unexpected
}

func apiSetContactAlias(contactId: Int64, localAlias: String) async throws -> Contact? {
    let r: ChatResponse1 = try await chatSendCmd(.apiSetContactAlias(contactId: contactId, localAlias: localAlias))
    if case let .contactAliasUpdated(_, toContact) = r { return toContact }
    throw r.unexpected
}

// MARK: - Contact Request Functions

func apiAcceptContactRequest(incognito: Bool, contactReqId: Int64) async -> Contact? {
    let r: APIResult<ChatResponse1>? = await chatApiSendCmdWithRetry(.apiAcceptContact(incognito: incognito, contactReqId: contactReqId))

    if case let .result(.acceptingContactRequest(_, contact), _) = r { return contact }
    if case .error(.errorAgent(.SMP(_, .AUTH)), _) = r {
        await AlertManager.shared.showAlertMsg(
            title: LocalizedStringKey(NSLocalizedString("model_connection_error_auth_title", comment: "alert title")),
            message: LocalizedStringKey(NSLocalizedString("model_sender_deleted_connection_message", comment: "alert message"))
        )
    } else if let r {
        if let networkErrorAlert = networkErrorAlert(r) {
            await AlertManager.shared.showAlert(networkErrorAlert)
        } else {
            logger.error("apiAcceptContactRequest error: \(String(describing: r))")
            await AlertManager.shared.showAlertMsg(
                title: LocalizedStringKey(NSLocalizedString("model_error_accepting_request_title", comment: "alert title")),
                message: LocalizedStringKey(String(format: NSLocalizedString("model_error_detail_message", comment: "alert message"), responseError(r.unexpected)))
            )
        }
    }
    return nil
}

func apiRejectContactRequest(contactReqId: Int64) async throws -> Contact? {
    let r: ChatResponse1 = try await chatSendCmd(.apiRejectContact(contactReqId: contactReqId))
    if case let .contactRequestRejected(_, _, contact_) = r { return contact_ }
    throw r.unexpected
}

/// Tracks contact request IDs currently being accepted, to prevent duplicate acceptances.
@MainActor
private var acceptingContactRequests: Set<Int64> = []

func acceptContactRequest(incognito: Bool, contactRequestId: Int64, inProgress: Binding<Bool>? = nil) async {
    await MainActor.run {
        guard !acceptingContactRequests.contains(contactRequestId) else { return }
        acceptingContactRequests.insert(contactRequestId)
        inProgress?.wrappedValue = true
    }
    defer {
        Task { @MainActor in
            acceptingContactRequests.remove(contactRequestId)
        }
    }
    if let contact = await apiAcceptContactRequest(incognito: incognito, contactReqId: contactRequestId) {
        let chat = await MainActor.run { Chat(chatInfo: ChatInfo.direct(contact: contact), chatItems: []) }
        await MainActor.run {
            if contact.contactRequestId != nil { // means contact request was initially created with contact, so we don't need to replace it
                ChatModel.shared.updateContact(contact)
            } else {
                ChatModel.shared.replaceChat(contactRequestChatId(contactRequestId), chat)
            }
            inProgress?.wrappedValue = false
        }
        if contact.sndReady {
            let chatId = await MainActor.run { chat.id }
            Task { @MainActor in
                dismissAllSheets(animated: true) {
                    ItemsModel.shared.loadOpenChat(chatId)
                }
            }
        }
    } else {
        await MainActor.run { inProgress?.wrappedValue = false }
    }
}

func rejectContactRequest(_ contactRequestId: Int64, dismissToChatList: Bool = false) async {
    do {
        let contact_ = try await apiRejectContactRequest(contactReqId: contactRequestId)
        await MainActor.run {
            if let contact = contact_ { // means contact request was initially created with contact, so we need to remove contact chat
                ChatModel.shared.removeChat(contact.id)
            } else {
                ChatModel.shared.removeChat(contactRequestChatId(contactRequestId))
            }
            if dismissToChatList {
                ChatModel.shared.chatId = nil
            }
        }
    } catch let error {
        logger.error("rejectContactRequest: \(responseError(error))")
        await MainActor.run {
            showAlert(
                NSLocalizedString("Error rejecting contact request", comment: "alert title"),
                message: responseError(error)
            )
        }
    }
}
