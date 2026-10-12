//
//  PXChatHelp.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 10/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

private enum PXChatHelpConfig {
    static let contentSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let questionsSectionSpacing: CGFloat = 0
    static let buttonTopPadding: CGFloat = 3
    static let outerPadding: CGFloat = 16
}

struct ChatHelp: View {
    @EnvironmentObject var chatModel: ChatModel
    @State private var showNewChatSheet = false
    let dismissSettingsSheet: DismissAction

    var body: some View {
        ScrollView { chatHelp() }
            .popopxBranded()
    }

    func chatHelp() -> some View {
        VStack(alignment: .leading, spacing: PXChatHelpConfig.contentSpacing) {
            Text(NSLocalizedString("chat_help_thanks", comment: "chat help thank you message"))

            VStack(alignment: .leading, spacing: PXChatHelpConfig.questionsSectionSpacing) {
                Text(NSLocalizedString("chat_help_questions", comment: "chat help questions prompt"))
                Button(NSLocalizedString("chat_help_connect_devs", comment: "chat help connect to developers button")) {
                    dismissSettingsSheet()
                    DispatchQueue.main.async {
                        // popopxTeamURL targets this same app; route to the in-app connect flow
                        // (UIApplication.shared.open is dropped for self-owned URLs in the foreground)
                        ChatModel.shared.appOpenUrl = popopxTeamURL
                    }
                }
                .padding(.top, PXChatHelpConfig.buttonTopPadding)
                .accessibilityLabel(NSLocalizedString("chat_help_connect_devs", comment: "chat help connect to developers button"))
            }

            VStack(alignment: .leading, spacing: PXChatHelpConfig.contentSpacing) {
                Text(NSLocalizedString("chat_help_new_connection", comment: "chat help section header"))
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text(NSLocalizedString("chat_help_tap_button", comment: "chat help tap button instruction"))
                    NewChatMenuButton(showNewChatSheet: $showNewChatSheet)
                    Text(NSLocalizedString("chat_help_above_then_choose", comment: "chat help above then choose instruction"))
                }

                Text(LocalizedStringKey(NSLocalizedString("chat_help_create_link_desc", comment: "chat help create link description")))
                Text(LocalizedStringKey(NSLocalizedString("chat_help_scan_paste_desc", comment: "chat help scan/paste link description")))
                Text(LocalizedStringKey(NSLocalizedString("chat_help_create_group_desc", comment: "chat help create group description")))
            }
            .padding(.top, PXChatHelpConfig.sectionSpacing)

            VStack(alignment: .leading, spacing: PXChatHelpConfig.contentSpacing) {
                Text(NSLocalizedString("chat_help_markdown", comment: "chat help markdown section header"))
                    .font(.title2)
                    .fontWeight(.bold)

                MarkdownHelp()
            }
            .padding(.top, PXChatHelpConfig.sectionSpacing)
        }
        .padding(PXChatHelpConfig.outerPadding)
    }
}

struct ChatHelp_Previews: PreviewProvider {
    @Environment(\.dismiss) static var mockDismiss

    static var previews: some View {
        ChatHelp(dismissSettingsSheet: mockDismiss)
    }
}

// MARK: - POPOPX
extension ChatHelp {
    static let pxComponentTag: String = "px_chat_help"
    var pxHelpVersion: String { "px-2.0" }
}
