//
//  IncognitoHelp.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 22.08.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

struct IncognitoHelp: View {
    var body: some View {
        List {
            Text(NSLocalizedString("settings_incognito_mode", comment: "Incognito mode help title"))
                .font(isInDarkTheme() ? .system(size: 28, weight: .semibold) : .largeTitle)
                .bold()
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical)
                        .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            VStack(alignment: .leading, spacing: 18) {
                Text(NSLocalizedString("settings_incognito_description_1", comment: "Incognito mode privacy explanation"))
                Text(NSLocalizedString("settings_incognito_description_2", comment: "Incognito mode anonymous connections benefit"))
                Text(NSLocalizedString("settings_incognito_description_3", comment: "Incognito profile sharing behavior"))
                ExternalLink("Read more in User Guide.", destination: URL(string: "https://popopxchat.com/docs/guide/chat-profiles.html#incognito-mode") ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground())
        .popopxBranded()
    }
}

struct IncognitoHelp_Previews: PreviewProvider {
    static var previews: some View {
        IncognitoHelp()
    }
}
