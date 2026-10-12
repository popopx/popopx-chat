//
//  ContactListNavLink.swift
//  POPOPX (iOS)
//
//  Created by Diogo Cunha on 01/08/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXContactListNavLinkConfig {
    static let profileImageSize: CGFloat = 30
    static let iconOpacity: Double = 0.65
    static let archivedIconSize: CGFloat = 18
    static let favoriteIconSize: CGFloat = 18
    static let incognitoIconSize: CGFloat = 22
    static let envelopeIconSize: CGFloat = 14
    static let checkmarkIconSize: CGFloat = 14
    static let sheetFraction: CGFloat = 0.4
    static let darkThemeTitleOpacity: Double = 0.9
}

// MARK: - POPOPX ViewModel
@MainActor
private struct PXContactListNavLinkVM {
    let chat: Chat
    let showDeletedChatIcon: Bool

    var isDirectWithRequest: Bool {
        if case let .direct(contact) = chat.chatInfo {
            return contact.nextAcceptContactRequest
        }
        return false
    }

    var isDirectContactCard: Bool {
        if case let .direct(contact) = chat.chatInfo {
            return contact.isContactCard
        }
        return false
    }

    var isDeletedChat: Bool {
        if case let .direct(contact) = chat.chatInfo {
            return contact.chatDeleted
        }
        return false
    }

    var isActiveRecentContact: Bool {
        if case let .direct(contact) = chat.chatInfo {
            return contact.active
        }
        return false
    }

    var isContactRequest: Bool {
        if case .contactRequest = chat.chatInfo { return true }
        return false
    }

    var isFavorite: Bool {
        chat.chatInfo.chatSettings?.favorite ?? false
    }

    var directContact: Contact? {
        if case let .direct(contact) = chat.chatInfo { return contact }
        return nil
    }

    var contactRequest: UserContactRequest? {
        if case let .contactRequest(req) = chat.chatInfo { return req }
        return nil
    }
}

struct ContactListNavLink: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    var showDeletedChatIcon: Bool
    @State private var alert: SomeAlert? = nil
    @State private var actionSheet: SomeActionSheet? = nil
    @State private var sheet: SomeSheet<AnyView>? = nil
    @State private var showConnectContactViaAddressDialog = false
    @State private var showContactRequestDialog = false

    private var pxVM: PXContactListNavLinkVM {
        PXContactListNavLinkVM(chat: chat, showDeletedChatIcon: showDeletedChatIcon)
    }

    var body: some View {
        Group {
            switch (chat.chatInfo) {
            case let .direct(contact):
                if contact.nextAcceptContactRequest {
                    contactWithRequestNavLink(contact)
                } else if contact.isContactCard {
                    contactCardNavLink(contact)
                } else if contact.chatDeleted {
                    deletedChatNavLink(contact)
                } else if contact.active {
                    recentContactNavLink(contact)
                }
            case let .contactRequest(contactRequest):
                contactRequestNavLink(contactRequest)
            default:
                EmptyView()
            }
        }
        .alert(item: $alert) { $0.alert }
        .actionSheet(item: $actionSheet) { $0.actionSheet }
        .sheet(item: $sheet) {
            $0.content
                .presentationDetents([.fraction(PXContactListNavLinkConfig.sheetFraction)])
        }
        .popopxBranded()
    }

    func recentContactNavLink(_ contact: Contact) -> some View {
        Button {
            dismissAllSheets(animated: true) {
                ItemsModel.shared.loadOpenChat(contact.id)
            }
        } label: {
            contactPreview(contact, titleColor: contact.sendMsgToConnect ? theme.colors.primary : theme.colors.onBackground)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                deleteContactDialog(
                    chat,
                    contact,
                    dismissToChatList: false,
                    showAlert: { alert = $0 },
                    showActionSheet: { actionSheet = $0 },
                    showSheetContent: { sheet = $0 }
                )
            } label: {
                Label(NSLocalizedString("delete_button", comment: "Delete button label"), systemImage: "trash")
            }
            .tint(QuantumColors.error)
        }
    }

    func contactWithRequestNavLink(_ contact: Contact) -> some View {
        Button {
            dismissAllSheets(animated: true) {
                ItemsModel.shared.loadOpenChat(contact.id)
            }
        } label: {
            contactRequestPreview(color: contact.groupDirectInv?.memberRemoved == true ? theme.colors.secondary : theme.colors.primary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let contactRequestId = contact.contactRequestId {
                Button {
                    Task { @MainActor in await acceptContactRequest(incognito: false, contactRequestId: contactRequestId) }
                } label: {
                    Label(NSLocalizedString("Accept", comment: ""), systemImage: "checkmark")
                }
                .tint(theme.colors.primary)
                if !ChatModel.shared.addressShortLinkDataSet {
                    Button {
                        Task { @MainActor in await acceptContactRequest(incognito: true, contactRequestId: contactRequestId) }
                    } label: {
                        Label(NSLocalizedString("Accept incognito", comment: ""), systemImage: "theatermasks")
                    }
                    .tint(QuantumColors.accent)
                }
                Button {
                    alert = SomeAlert(alert: rejectContactRequestAlert(contactRequestId), id: "rejectContactRequestAlert")
                } label: {
                    Label(NSLocalizedString("Reject", comment: ""), systemImage: "multiply")
                }
                .tint(QuantumColors.error)
            } else if let groupDirectInv = contact.groupDirectInv, !groupDirectInv.memberRemoved {
                Button {
                    acceptMemberContactRequest(contact)
                } label: {
                    Label(NSLocalizedString("Accept", comment: ""), systemImage: "checkmark")
                }
                .tint(theme.colors.primary)
                Button {
                    showRejectMemberContactRequestAlert(contact)
                } label: {
                    Label(NSLocalizedString("Reject", comment: ""), systemImage: "multiply")
                }
                .tint(QuantumColors.error)
            } else {
                Button {
                    deleteContactDialog(
                        chat,
                        contact,
                        dismissToChatList: false,
                        showAlert: { alert = $0 },
                        showActionSheet: { actionSheet = $0 },
                        showSheetContent: { sheet = $0 }
                    )
                } label: {
                    Label(NSLocalizedString("delete_button", comment: "Delete button label"), systemImage: "trash")
                }
                .tint(QuantumColors.error)
            }
        }
    }

    func deletedChatNavLink(_ contact: Contact) -> some View {
        Button {
            Task {
                await MainActor.run {
                    dismissAllSheets(animated: true) {
                        ItemsModel.shared.loadOpenChat(contact.id)
                    }
                }
            }
        } label: {
            contactPreview(contact, titleColor: theme.colors.onBackground)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                deleteContactDialog(
                    chat,
                    contact,
                    dismissToChatList: false,
                    showAlert: { alert = $0 },
                    showActionSheet: { actionSheet = $0 },
                    showSheetContent: { sheet = $0 }
                )
            } label: {
                Label(NSLocalizedString("delete_button", comment: "Delete button label"), systemImage: "trash")
            }
            .tint(QuantumColors.error)
        }
    }

    func contactPreview(_ contact: Contact, titleColor: Color) -> some View {
        let darkTheme = isInDarkTheme()
        return HStack{
            ProfileImage(imageStr: contact.image, size: PXContactListNavLinkConfig.profileImageSize)

            previewTitle(contact, titleColor: titleColor)

            Spacer()

            HStack {
                if showDeletedChatIcon && contact.chatDeleted {
                    Image(systemName: "archivebox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: PXContactListNavLinkConfig.archivedIconSize, height: PXContactListNavLinkConfig.archivedIconSize)
                        .foregroundColor(.secondary.opacity(darkTheme ? PXContactListNavLinkConfig.darkThemeTitleOpacity : PXContactListNavLinkConfig.iconOpacity))
                        .accessibilityLabel(Text(NSLocalizedString("Archived", comment: "archived chat indicator")))
                } else if chat.chatInfo.chatSettings?.favorite ?? false {
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: PXContactListNavLinkConfig.favoriteIconSize, height: PXContactListNavLinkConfig.favoriteIconSize)
                        .foregroundColor(.secondary.opacity(darkTheme ? PXContactListNavLinkConfig.darkThemeTitleOpacity : PXContactListNavLinkConfig.iconOpacity))
                        .accessibilityLabel(Text(NSLocalizedString("Favorite", comment: "favorite chat indicator")))
                }
                if contact.contactConnIncognito {
                    Image(systemName: "theatermasks")
                        .resizable()
                        .scaledToFit()
                        .frame(width: PXContactListNavLinkConfig.incognitoIconSize, height: PXContactListNavLinkConfig.incognitoIconSize)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(Text(NSLocalizedString("Incognito", comment: "incognito connection indicator")))
                }
            }
        }
    }

    private func previewTitle(_ contact: Contact, titleColor: Color) -> some View {
        let t = Text(chat.chatInfo.chatViewName).foregroundColor(titleColor)
        return NameWithBadge(
            contact.verified == true ? verifiedIcon + t : t,
            chat.chatInfo.nameBadge
        )
        .lineLimit(1)
    }

    private var verifiedIcon: Text {
        (Text(Image(systemName: "checkmark.shield")) + textSpace)
            .foregroundColor(.secondary)
            .baselineOffset(1)
            .kerning(-2)
    }

    func contactCardNavLink(_ contact: Contact) -> some View {
        Button {
            showConnectContactViaAddressDialog = true
        } label: {
            contactCardPreview(contact)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                deleteContactDialog(
                    chat,
                    contact,
                    dismissToChatList: false,
                    showAlert: { alert = $0 },
                    showActionSheet: { actionSheet = $0 },
                    showSheetContent: { sheet = $0 }
                )
            } label: {
                Label(NSLocalizedString("delete_button", comment: "Delete button label"), systemImage: "trash")
            }
            .tint(QuantumColors.error)
        }
        .confirmationDialog(String(format: NSLocalizedString("Connect with %@", comment: ""), contact.chatViewName), isPresented: $showConnectContactViaAddressDialog, titleVisibility: .visible) {
            if !contact.profileChangeProhibited {
                Button(NSLocalizedString("Use current profile", comment: "")) { connectContactViaAddress_(contact, false) }
                Button(NSLocalizedString("Use new incognito profile", comment: "")) { connectContactViaAddress_(contact, true) }
            } else if !contact.contactConnIncognito {
                Button(NSLocalizedString("Use current profile", comment: "")) { connectContactViaAddress_(contact, false) }
            } else {
                Button(NSLocalizedString("Use incognito profile", comment: "")) { connectContactViaAddress_(contact, true) }
            }
        }
    }

    private func connectContactViaAddress_(_ contact: Contact, _ incognito: Bool) {
        Task {
            let ok = await connectContactViaAddress(contact.contactId, incognito)
            if ok {
                ItemsModel.shared.loadOpenChat(contact.id) {
                    dismissAllSheets(animated: true) {
                        AlertManager.shared.showAlert(connReqSentAlert(.contact))
                    }
                }
            }
        }
    }

    func contactCardPreview(_ contact: Contact) -> some View {
        HStack{
            ProfileImage(imageStr: contact.image, size: PXContactListNavLinkConfig.profileImageSize)

            Text(chat.chatInfo.chatViewName)
                .foregroundColor(.accentColor)
                .lineLimit(1)

            Spacer()

            Image(systemName: "envelope")
                .resizable()
                .scaledToFill()
                .frame(width: PXContactListNavLinkConfig.envelopeIconSize, height: PXContactListNavLinkConfig.envelopeIconSize)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
        }
    }

    func contactRequestNavLink(_ contactRequest: UserContactRequest) -> some View {
        Button {
            showContactRequestDialog = true
        } label: {
            contactRequestPreview(color: theme.colors.primary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Task { @MainActor in await acceptContactRequest(incognito: false, contactRequestId: contactRequest.apiId) }
            } label: { Label(NSLocalizedString("Accept", comment: ""), systemImage: "checkmark") }
                .tint(theme.colors.primary)
            if !ChatModel.shared.addressShortLinkDataSet {
                Button {
                    Task { @MainActor in await acceptContactRequest(incognito: true, contactRequestId: contactRequest.apiId) }
                } label: {
                    Label(NSLocalizedString("Accept incognito", comment: ""), systemImage: "theatermasks")
                }
                .tint(QuantumColors.accent)
            }
            Button {
                alert = SomeAlert(alert: rejectContactRequestAlert(contactRequest.apiId), id: "rejectContactRequestAlert")
            } label: {
                Label(NSLocalizedString("Reject", comment: ""), systemImage: "multiply")
            }
            .tint(QuantumColors.error)
        }
        .confirmationDialog(NSLocalizedString("Accept connection request?", comment: ""), isPresented: $showContactRequestDialog, titleVisibility: .visible) {
            Button(NSLocalizedString("Accept", comment: "")) { Task { @MainActor in await acceptContactRequest(incognito: false, contactRequestId: contactRequest.apiId) } }
            if !ChatModel.shared.addressShortLinkDataSet {
                Button(NSLocalizedString("Accept incognito", comment: "")) { Task { @MainActor in await acceptContactRequest(incognito: true, contactRequestId: contactRequest.apiId) } }
            }
            Button(NSLocalizedString("Reject (sender NOT notified)", comment: ""), role: .destructive) { Task { @MainActor in await rejectContactRequest(contactRequest.apiId) } }
        }
    }

    func contactRequestPreview(color: Color) -> some View {
        HStack{
            ProfileImage(imageStr: chat.chatInfo.image, size: PXContactListNavLinkConfig.profileImageSize)

            NameWithBadge(Text(chat.chatInfo.chatViewName).foregroundColor(color), chat.chatInfo.nameBadge)
                .lineLimit(1)

            Spacer()

            Image(systemName: "checkmark")
                .resizable()
                .scaledToFill()
                .frame(width: PXContactListNavLinkConfig.checkmarkIconSize, height: PXContactListNavLinkConfig.checkmarkIconSize)
                .foregroundColor(color)
                .accessibilityLabel(Text(NSLocalizedString("Connection request", comment: "connection request indicator")))
        }
    }
}

// MARK: - POPOPX
extension ContactListNavLink {
    var pxComponentTag: String { "px-contact-list-nav-link" }
    var pxContactPreviewTag: String { "px-contact-preview" }
    var pxIsFavorite: Bool { pxVM.isFavorite }
}
