//
//  NavLinkPlain.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 11/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct NavLinkPlain<Label: View>: View {
    let chatId: ChatId
    @Binding var selection: ChatId?
    @ViewBuilder var label: () -> Label
    var disabled = false

    var body: some View {
        Button {
            ItemsModel.shared.loadOpenChat(chatId)
        } label: {
            label()
        }
        .disabled(disabled)
        .buttonStyle(PlainButtonStyle())
        .focusable()
        .accessibilityLabel(String(localized: "Open chat", comment: "Accessibility label for chat list item button"))
        .accessibilityHint(String(localized: "Double-tap to open this conversation", comment: "VoiceOver hint for chat list item"))
        .popopxBranded()
    }
}

//struct NavLinkPlain_Previews: PreviewProvider {
//    static var previews: some View {
//        NavLinkPlain()
//    }
//}
