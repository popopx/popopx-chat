//
//  ChatToolbarViews.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - Toolbar Helper Views

struct ConnectInProgressView: View {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            GlassDivider()

            HStack(spacing: 12) {
                ProgressView()
                Text(text)

                Spacer()

                Button {
                    ConnectProgressManager.shared.cancelConnectProgress()
                } label: {
                    Image(systemName: "multiply")
                }
                .tint(theme.colors.primary)
            }
            .padding(12)
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ToolbarMaterial.material(toolbarMaterial))
        }
        .popopxBranded()
    }
}

struct UserMemberKnockingTitleBar: View {
    @EnvironmentObject var theme: AppTheme

    var body: some View {
         VStack(spacing: 0) {
             Text(LocalizedStringKey("Chat with admins"))
                 .font(.headline)
                 .foregroundColor(theme.colors.onBackground)
                 .padding(.top, 8)
                 .padding(.bottom, 14)
                 .frame(maxWidth: .infinity)
                 .background(ToolbarMaterial.material(ToolbarMaterial.defaultMaterial))
             GlassDivider()
         }
    }
}

struct SearchToolbar: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var searchText: String
    @FocusState.Binding var searchFocussed: Bool
    @Binding var showSearch: Bool
    let contentFilter: ContentFilter?
    let closeSearch: () -> Void
    let searchTextChanged: (String) -> Void

    var body: some View {
        let placeholder: LocalizedStringKey = contentFilter?.searchPlaceholder ?? "Search"
        return HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                if let contentFilter {
                    Image(systemName: contentFilter.icon)
                }
                TextField(placeholder, text: $searchText)
                    .focused($searchFocussed)
                    .foregroundColor(theme.colors.onBackground)
                    .frame(maxWidth: .infinity)

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").opacity(searchText == "" ? 0 : 1)
                }
            }
            .padding(EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7))
            .foregroundColor(theme.colors.secondary)
            .background(Color(.tertiarySystemFill))
            .cornerRadius(10.0)

            Button ("Cancel") {
                closeSearch()
                searchTextChanged("")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
