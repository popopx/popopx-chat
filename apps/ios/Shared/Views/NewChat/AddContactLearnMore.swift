//
//  AddContactLearnMore.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 27.04.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

struct AddContactLearnMore: View {
    var showTitle: Bool

    var body: some View {
        List {
            if showTitle {
                Text(LocalizedStringKey(NSLocalizedString("onetime_invitation_link", comment: "One-time invitation link title")))
                    .font(.title.weight(.heavy))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical)
                                .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            VStack(alignment: .leading, spacing: 18) {
                Text(LocalizedStringKey(NSLocalizedString("add_contact_scan_qr", comment: "Add contact scan QR code hint")))
                Text(LocalizedStringKey(NSLocalizedString("add_contact_video_call", comment: "Add contact video call hint")))
                ExternalLink("Read more in User Guide.", destination: URL(string: "https://popopxchat.com/docs/guide/readme.html#connect-to-friends") ?? URL(fileURLWithPath: "/dev/null"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .popopxBranded()
    }
}

struct AddContactLearnMore_Previews: PreviewProvider {
    static var previews: some View {
        AddContactLearnMore(showTitle: true)
    }
}
