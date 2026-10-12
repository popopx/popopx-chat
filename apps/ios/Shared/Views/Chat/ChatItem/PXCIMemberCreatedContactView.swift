//
//  CIMemberCreatedContactView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 19.09.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//
//  Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX layout + feature config
private enum PXMemberCreatedContactConfig {
    static let leadingPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 8
    static let hStackSpacing: CGFloat = 0
    static let featureFlagKey: String = "PX_FEATURE_ENABLED"
    static let openButtonWeight: Font.Weight = .medium
    static let timestampWeight: Font.Weight = .light
    static let bodyFont: Font = .caption
    static let lightThemeTextOpacity: Double = 0.95
}

// MARK: - POPOPX Feature
private let pxMemberContactFeatureEnabled = UserDefaults.standard.bool(forKey: PXMemberCreatedContactConfig.featureFlagKey)

// Spec: spec/client/chat-view.md#CIMemberCreatedContactView
struct CIMemberCreatedContactView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem

    var body: some View {
        HStack(alignment: .bottom, spacing: PXMemberCreatedContactConfig.hStackSpacing) {
            switch chatItem.chatDir {
            case let .groupRcv(groupMember):
                if let contactId = groupMember.memberContactId {
                    memberCreatedContactView(openText: "Open")
                        .simultaneousGesture(TapGesture().onEnded {
                            ItemsModel.shared.loadOpenChat("@\(contactId)") {
                                dismissAllSheets(animated: true)
                            }
                        })
                        .accessibilityLabel(Text(verbatim: NSLocalizedString("a11y_open_conversation", comment: "")))
                } else {
                    memberCreatedContactView()
                }
            default:
                EmptyView()
            }
        }
        .textSelection(.disabled)
        .padding(.bottom, PXMemberCreatedContactConfig.bottomPadding)
        .padding(.leading, PXMemberCreatedContactConfig.leadingPadding)
        .popopxBranded()
    }

    private func memberCreatedContactView(openText: LocalizedStringKey? = nil) -> some View {
        var r = pxBuildEventText()
        if let openText {
            r = r
            + Text(openText)
                .fontWeight(PXMemberCreatedContactConfig.openButtonWeight)
                .foregroundColor(theme.colors.primary)
            + Text(verbatim: "  ")
        }
        r = r + chatItem.timestampText
            .fontWeight(PXMemberCreatedContactConfig.timestampWeight)
            .foregroundColor(theme.colors.secondary)
        return r.font(PXMemberCreatedContactConfig.bodyFont)
            .opacity(isInDarkTheme() ? 1.0 : PXMemberCreatedContactConfig.lightThemeTextOpacity)
    }

    // MARK: - POPOPX
    private func pxBuildEventText() -> Text {
        guard let pxMemberName = chatItem.memberDisplayName else {
            if pxMemberContactFeatureEnabled {
                logger.debug("PX: [pxBuildEventText] no member display name")
            }
            return Text(chatItem.content.text + "  ")
                .fontWeight(PXMemberCreatedContactConfig.timestampWeight)
                .foregroundColor(theme.colors.secondary)
        }
        logger.debug("PX: [pxBuildEventText] member=\(pxMemberName)")
        return Text(pxMemberName + " " + chatItem.content.text + "  ")
            .fontWeight(PXMemberCreatedContactConfig.timestampWeight)
            .foregroundColor(theme.colors.secondary)
    }

    private func eventText() -> Text {
        pxBuildEventText()
    }
}

struct CIMemberCreatedContactView_Previews: PreviewProvider {
    static var previews: some View {
        let content = CIContent.rcvGroupEvent(rcvGroupEvent: .memberCreatedContact)
        let chatItem = ChatItem(
            chatDir: .groupRcv(groupMember: GroupMember.sampleData),
            meta: CIMeta.getSample(1, .now, content.text, .rcvRead),
            content: content,
            quotedItem: nil,
            file: nil
        )
        CIMemberCreatedContactView(chatItem: chatItem)
    }
}

// MARK: - POPOPX
extension CIMemberCreatedContactView {
    static let pxComponentTag: String = "px-member-created-contact"
}
