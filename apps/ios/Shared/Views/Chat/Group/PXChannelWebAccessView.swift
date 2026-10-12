//
//  ChannelWebAccessView.swift
//  POPOPX (iOS)
//
//  Created by simplex.chat on 31/05/2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXChannelWebAccessConfig {
    static let scrollMaxHeight: CGFloat = 88
    static let clipboardExpiration: TimeInterval = 120
    static let rowTopInset: CGFloat = 8
    static let rowHorizontalInset: CGFloat = 16
    static let urlFieldCornerRadius: CGFloat = 10
    static let saveButtonOpacity: Double = 0.9
}

@MainActor
private struct PXChannelWebAccessViewModel {
    let groupInfo: GroupInfo

    var currentWebPage: String {
        groupInfo.groupProfile.publicGroup?.publicGroupAccess?.groupWebPage ?? ""
    }
    var currentEmbedding: Bool {
        groupInfo.groupProfile.publicGroup?.publicGroupAccess?.allowEmbedding ?? false
    }
    var isChannel: Bool { groupInfo.isChannel }
    var groupId: Int64 { groupInfo.groupId }

    func hasChanges(webPage: String, allowEmbedding: Bool) -> Bool {
        webPage != currentWebPage || allowEmbedding != currentEmbedding
    }
}

struct ChannelWebAccessView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @Binding var groupInfo: GroupInfo
    @State private var webPage: String
    @State private var allowEmbedding: Bool
    @State private var saving = false
    @State private var groupRelays: [GroupRelay] = []

    private var vm: PXChannelWebAccessViewModel {
        PXChannelWebAccessViewModel(groupInfo: groupInfo)
    }

    init(groupInfo: Binding<GroupInfo>) {
        _groupInfo = groupInfo
        let access = groupInfo.wrappedValue.groupProfile.publicGroup?.publicGroupAccess
        _webPage = State(initialValue: access?.groupWebPage ?? "")
        _allowEmbedding = State(initialValue: access?.allowEmbedding ?? false)
    }

    var body: some View {
        List {
            pxWebpageInfoOrCode
            pxURLInputSection
            pxEmbedToggleSection
            pxSaveSection
        }
        .modifier(ThemedBackground(grouped: true))
        .task {
            let relays = await apiGetGroupRelays(vm.groupId)
            await MainActor.run { groupRelays = relays }
        }
        .onDisappear {
            if vm.hasChanges(webPage: webPage, allowEmbedding: allowEmbedding) {
                showAlert(
                    title: NSLocalizedString("Save webpage settings?", comment: "alert title"),
                    message: NSLocalizedString("Webpage settings were changed. If you save, the updated settings will be sent to subscribers.", comment: "alert message"),
                    buttonTitle: NSLocalizedString("Save", comment: "alert button"),
                    buttonAction: pxSaveAccess,
                    cancelButton: true
                )
            }
        }
        .popopxBranded()
    }

    // MARK: - View Builders

    @ViewBuilder
    private var pxWebpageInfoOrCode: some View {
        if let code = pxEmbedCode {
            pxWebpageInfo(NSLocalizedString("channel_webpage_create_description", comment: "Description for creating a webpage"))
            pxEmbedCodeSection(code)
        } else {
            pxWebpageInfo(NSLocalizedString("channel_webpage_not_supported", comment: "Message when chat relays don't support webpages"))
        }
    }

    @ViewBuilder
    private func pxEmbedCodeSection(_ code: String) -> some View {
        Section {
            ScrollView {
                Text(code)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: PXChannelWebAccessConfig.scrollMaxHeight)
            .accessibilityLabel(Text(NSLocalizedString("Embed code content", comment: "Accessibility label for embed code scroll view")))

            Button {
                UIPasteboard.general.setItems(
                    [["public.utf8-plain-text": code]],
                    options: [
                        .expirationDate: Date().addingTimeInterval(PXChannelWebAccessConfig.clipboardExpiration),
                        .localOnly: true
                    ]
                )
            } label: {
                Label(NSLocalizedString("group_copy_code", comment: "Copy webpage embed code button"), systemImage: "doc.on.doc")
            }
            .accessibilityLabel(Text(NSLocalizedString("Copy embed code to clipboard", comment: "Accessibility label for copy code button")))
        } header: {
            Text(NSLocalizedString("group_webpage_code", comment: "Section header for embed code"))
        } footer: {
            Text(NSLocalizedString("group_webpage_code_instructions", comment: "Instructions for using embed code"))
        }
    }

    @ViewBuilder
    private func pxWebpageInfo(_ text: LocalizedStringKey) -> some View {
        Section {
            Text(text).foregroundColor(theme.colors.secondary)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: PXChannelWebAccessConfig.rowTopInset,
            leading: PXChannelWebAccessConfig.rowHorizontalInset,
            bottom: 0,
            trailing: PXChannelWebAccessConfig.rowHorizontalInset
        ))
    }

    @ViewBuilder
    private var pxURLInputSection: some View {
        Section {
            TextField(NSLocalizedString("channel_webpage_url_placeholder", comment: "URL placeholder"), text: $webPage)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityLabel(Text(NSLocalizedString("Webpage URL input", comment: "Accessibility label for URL text field")))
        } header: {
            Text(NSLocalizedString("group_enter_webpage_url", comment: "Section header for URL input"))
        } footer: {
            Text(NSLocalizedString("group_webpage_url_instructions", comment: "Instructions for webpage URL"))
        }
    }

    @ViewBuilder
    private var pxEmbedToggleSection: some View {
        Section {
            Toggle(NSLocalizedString("channel_allow_embed_toggle", comment: "Allow embedding toggle"), isOn: $allowEmbedding)
                .accessibilityLabel(Text(allowEmbedding
                    ? NSLocalizedString("Embedding allowed", comment: "Accessibility label when embedding is on")
                    : NSLocalizedString("Embedding disabled", comment: "Accessibility label when embedding is off")
                ))
        } footer: {
            Text(allowEmbedding
                ? NSLocalizedString("channel_embed_any_page", comment: "Footer when embedding allowed")
                : NSLocalizedString("channel_embed_only_your_page", comment: "Footer when only your page can show preview")
            )
        }
    }

    @ViewBuilder
    private var pxSaveSection: some View {
        Section {
            Button {
                pxSaveAccess()
            } label: {
                HStack {
                    Text(vm.isChannel
                        ? NSLocalizedString("channel_save_notify_subscribers", comment: "Save and notify subscribers button")
                        : NSLocalizedString("channel_save_notify_members", comment: "Save and notify members button")
                    )
                    if saving { Spacer(); ProgressView() }
                }
            }
            .disabled(!vm.hasChanges(webPage: webPage, allowEmbedding: allowEmbedding) || saving)
            .opacity(PXChannelWebAccessConfig.saveButtonOpacity)
            .accessibilityLabel(Text(NSLocalizedString("Save webpage settings", comment: "Accessibility label for save button")))
        }
    }

    // MARK: - Computed Properties

    private var pxRelayDomains: [String] {
        groupRelays.compactMap { $0.relayCap.webDomain }
    }

    private var pxEmbedCode: String? {
        nil
    }

    // MARK: - Save Logic

    private func pxSaveAccess() {
        logger.debug("POPOPX: ChannelWebAccessView pxSaveAccess")
        saving = true
        Task {
            do {
                var gp = groupInfo.groupProfile
                if var pg = gp.publicGroup {
                    let trimmedPage = webPage.trimmingCharacters(in: .whitespacesAndNewlines)
                    let existingAccess = pg.publicGroupAccess
                    pg.publicGroupAccess = PublicGroupAccess(
                        groupWebPage: trimmedPage.isEmpty ? nil : trimmedPage,
                        groupDomainClaim: existingAccess?.groupDomainClaim,
                        domainWebPage: existingAccess?.domainWebPage ?? false,
                        allowEmbedding: allowEmbedding
                    )
                    gp.publicGroup = pg
                }
                let gInfo = try await apiUpdateGroup(vm.groupId, gp)
                await MainActor.run {
                    groupInfo = gInfo
                    ChatModel.shared.updateGroup(gInfo)
                    saving = false
                }
            } catch {
                logger.error("ChannelWebAccessView apiUpdateGroup error: \(responseError(error))")
                await MainActor.run { saving = false }
            }
        }
    }
}

// MARK: - POPOPX
extension ChannelWebAccessView {
    var pxComponentTag: String { "px-channel-web-access" }
}
