//
//  ContactConnectionInfo.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 06/10/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ContactConnectionInfo: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @State var contactConnection: PendingContactConnection
    @State private var showShortLink: Bool = true
    @State private var alert: CCInfoAlert?
    @State private var localAlias = ""
    @State private var showIncognitoSheet = false
    @FocusState private var aliasTextFieldFocused: Bool

    enum CCInfoAlert: Identifiable {
        case deleteInvitationAlert
        case error(title: LocalizedStringKey, error: LocalizedStringKey?)

        var id: String {
            switch self {
            case .deleteInvitationAlert: return "deleteInvitationAlert"
            case let .error(title, _): return "error \(title)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            pxMainList
                .modifier(ThemedBackground(grouped: true))
        }
        .alert(item: $alert) { _alert in
            switch _alert {
            case .deleteInvitationAlert:
                return deleteContactConnectionAlert(contactConnection, showError: { alert = .error(title: $0.title, error: $0.message) }, success: { dismiss() })
            case let .error(title, error): return mkAlert(title: title, message: error)
            }
        }
        .onAppear {
            localAlias = contactConnection.localAlias
            if var linkInv = contactConnection.connLinkInv, linkInv.encryptedConnLink == nil {
                linkInv.encryptedConnLink = encryptConnLinkText(linkInv.connFullLink)
                contactConnection.connLinkInv = linkInv
            }
        }
        .onDisappear(perform: setConnectionAlias)
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxMainList: some View {
        List {
            pxStatusHeader
            pxConnectionContentSection
            pxDeleteSection
        }
        .scrollContentBackground(.hidden)
        .onTapGesture { aliasTextFieldFocused = false }
    }

    @ViewBuilder
    private var pxStatusHeader: some View {
        Group {
            Text(contactConnection.initiated ? NSLocalizedString("you_invited_contact", comment: "Status text when user initiated contact") : NSLocalizedString("you_accepted_connection", comment: "Status text when user accepted connection"))
                .font(.title.weight(.heavy))
                .bold()
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXContactConnectionInfoConfig.titleShadowOpacity) : .clear, radius: PXContactConnectionInfoConfig.titleShadowRadius, x: 0, y: 2)
                .padding(.bottom)
                .accessibilityLabel(Text(NSLocalizedString("Connection status", comment: "Accessibility label for connection status header")))

            Text(contactConnectionText(contactConnection))
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(PXContactConnectionInfoConfig.zeroRowInsets)
    }

    @ViewBuilder
    private var pxConnectionContentSection: some View {
        Section {
            pxAliasRow
            if contactConnection.initiated,
               let connLinkInv = contactConnection.connLinkInv {
                let displayLink = connLinkInv.encryptedConnLink ?? encryptConnLinkText(connLinkInv.connFullLink) ?? connLinkInv.connFullLink
                pxQRAndLinkSection(displayLink)
                incognitoEnabled()
                oneTimeLinkLearnMoreButton()
            } else {
                incognitoEnabled()
                oneTimeLinkLearnMoreButton()
            }
        } header: {
            if let connLinkInv = contactConnection.connLinkInv, connLinkInv.connShortLink != nil {
                ToggleShortLinkHeader(text: Text(""), link: connLinkInv, short: $showShortLink)
            }
        } footer: {
            sharedProfileInfo(contactConnection.incognito)
                .foregroundColor(theme.colors.secondary)
        }
    }

    @ViewBuilder
    private var pxAliasRow: some View {
        if contactConnection.groupLinkId == nil {
            settingsRow("pencil", color: theme.colors.secondary) {
                TextField(NSLocalizedString("Set contact name…", comment: ""), text: $localAlias)
                    .autocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .focused($aliasTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(setConnectionAlias)
                    .accessibilityLabel(Text(NSLocalizedString("Contact alias input", comment: "Accessibility label for alias text field")))
            }
            .onTapGesture { aliasTextFieldFocused = true }
        }
    }

    @ViewBuilder
    private func pxQRAndLinkSection(_ displayLink: String) -> some View {
        QRCode(uri: displayLink)
            .id("popopx-invitation-qrcode-\(displayLink)")
            .accessibilityLabel(Text(NSLocalizedString("Invitation QR code", comment: "Accessibility label for QR code")))

        HStack(spacing: PXContactConnectionInfoConfig.linkSpacing) {
            linkTextView(displayLink)
            Button {
                showShareSheet(items: [displayLink])
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .padding(.top, -7)
                    .padding(.horizontal, 8)
            }
            .accessibilityLabel(Text(NSLocalizedString("Share link", comment: "Accessibility label for share button")))
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(PXContactConnectionInfoConfig.zeroRowInsets)
    }

    @ViewBuilder
    private var pxDeleteSection: some View {
        Section {
            Button(role: .destructive) {
                alert = .deleteInvitationAlert
            } label: {
                Label(NSLocalizedString("delete_connection", comment: "Button to delete connection"), systemImage: "trash")
                    .foregroundColor(theme.colors.error)
            }
            .accessibilityLabel(Text(NSLocalizedString("Delete connection", comment: "Accessibility label for delete button")))
        }
    }

    // MARK: - POPOPX Actions

    private func setConnectionAlias() {
        if localAlias == contactConnection.localAlias {
            aliasTextFieldFocused = false
            return
        }
        Task {
            let prevAlias = contactConnection.localAlias
            contactConnection.localAlias = localAlias
            do {
                if let conn = try await apiSetConnectionAlias(connId: contactConnection.pccConnId, localAlias: localAlias) {
                    await MainActor.run {
                        contactConnection = conn
                        m.updateContactConnection(conn)
                        dismiss()
                    }
                }
            } catch {
                logger.error("setContactAlias error: \(responseError(error))")
                contactConnection.localAlias = prevAlias
            }
        }
    }

    private func contactConnectionText(_ contactConnection: PendingContactConnection) -> LocalizedStringKey {
        contactConnection.viaContactUri
        ? (contactConnection.groupLinkId != nil
           ? "group_connection_pending"
           : "connection_request_pending"
        )
        : "contact_device_pending"
    }

    @ViewBuilder private func incognitoEnabled() -> some View {
        if contactConnection.incognito {
            ZStack(alignment: .leading) {
                Image(systemName: "theatermasks.fill")
                    .frame(maxWidth: PXContactConnectionInfoConfig.incognitoIconSize, maxHeight: PXContactConnectionInfoConfig.incognitoIconSize, alignment: .center)
                    .foregroundColor(QuantumColors.accent)
                    .font(.footnote)
                HStack(spacing: PXContactConnectionInfoConfig.incognitoTextSpacing) {
                    Text(NSLocalizedString("incognito_mode", comment: "Label for incognito mode"))
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.colors.primary)
                        .font(.footnote)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showIncognitoSheet = true
                }
                .padding(.leading, PXContactConnectionInfoConfig.incognitoLeadingPadding)
            }
            .sheet(isPresented: $showIncognitoSheet) {
                IncognitoHelp()
            }
        }
    }
}

private func shareLinkButton(_ connLinkInvitation: CreatedConnLink, short: Bool) -> some View {
    Button {
        showShareSheet(items: [connLinkInvitation.popopxChatUri(short: short)])
    } label: {
        Label(NSLocalizedString("share_onetime_link", comment: "Button to share one-time invitation link"), systemImage: "square.and.arrow.up")
    }
}

private func oneTimeLinkLearnMoreButton() -> some View {
    NavigationLink {
        AddContactLearnMore(showTitle: false)
            .navigationTitle(NSLocalizedString("onetime_invitation_title", comment: "Title for one-time invitation link help"))
            .modifier(ThemedBackground())
            .navigationBarTitleDisplayMode(.large)
    } label: {
        Label(NSLocalizedString("learn_more", comment: "Button to learn more about invitation links"), systemImage: "info.circle")
    }
}

struct ContactConnectionInfo_Previews: PreviewProvider {
    static var previews: some View {
        ContactConnectionInfo(contactConnection: PendingContactConnection.getSampleData())
    }
}

// MARK: - POPOPX Config & Tag

private enum PXContactConnectionInfoConfig {
    static let titleShadowOpacity: Double = 0.3
    static let titleShadowRadius: CGFloat = 8
    static let linkSpacing: CGFloat = 8
    static let incognitoIconSize: CGFloat = 24
    static let incognitoTextSpacing: CGFloat = 6
    static let incognitoLeadingPadding: CGFloat = 36
    static let zeroRowInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

extension ContactConnectionInfo {
    static let pxComponentTag: String = "PX_CONTACT_CONNECTION_INFO"
}
