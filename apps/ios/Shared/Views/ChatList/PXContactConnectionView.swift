//
//  ContactConnectionView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 24/04/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// POPOPX layout metrics for pending-contact connection row
private enum PXConnConnectionMetrics {
    static let iconSize: CGFloat = 50
    static let iconContainerSize: CGFloat = 65
    static let leadingPad: CGFloat = 6
    static let nameHorizontalPad: CGFloat = 10
    static let nameTopPad: CGFloat = 2
    static let nameBottomPad: CGFloat = 1
    static let timestampTrailingPad: CGFloat = 10
    static let timestampVerticalPad: CGFloat = 6
    static let timestampMinWidth: CGFloat = 62
    static let rowSpacing: CGFloat = 10
    static let bottomSectionPad: CGFloat = 3
    static let descHorizontalPad: CGFloat = 10
    static let incognitoTopPad: CGFloat = 28
    static let nameShadowRadius: CGFloat = 5
    static let nameShadowOpacity: Double = 0.18
}

struct ContactConnectionView: View {
    @EnvironmentObject var m: ChatModel
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
    @State private var localAlias = ""
    @FocusState private var aliasTextFieldFocused: Bool

    var body: some View {
        Group {
        if case let .contactConnection(conn) = chat.chatInfo {
            contactConnectionView(conn)
        }
        }
        .popopxBranded()
    }

    func contactConnectionView(_ contactConnection: PendingContactConnection) -> some View {
        HStack(spacing: PXConnConnectionMetrics.rowSpacing) {
            // Link status icon with container
            Group {
                Image(systemName: contactConnection.initiated ? "link.badge.plus" : "link")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(Color(uiColor: .tertiarySystemGroupedBackground).asAnotherColorFromSecondaryVariant(theme))
                    .frame(width: PXConnConnectionMetrics.iconSize, height: PXConnConnectionMetrics.iconSize)
            }
            .padding(.leading, PXConnConnectionMetrics.leadingPad)
            .frame(width: PXConnConnectionMetrics.iconContainerSize, height: PXConnConnectionMetrics.iconContainerSize)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(contactConnection.chatViewName)
                        .font(.headline.weight(.bold))
                        .allowsTightening(false)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.88) : theme.colors.secondary)
                        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXConnConnectionMetrics.nameShadowOpacity) : .clear, radius: PXConnConnectionMetrics.nameShadowRadius, x: 0, y: 1)
                        .padding(.horizontal, PXConnConnectionMetrics.nameHorizontalPad)
                        .padding(.top, PXConnConnectionMetrics.nameTopPad)
                        .padding(.bottom, PXConnConnectionMetrics.nameBottomPad)
                        .frame(alignment: .topLeading)

                    Spacer()

                    formatTimestampText(contactConnection.updatedAt)
                        .font(.subheadline)
                        .padding(.trailing, PXConnConnectionMetrics.timestampTrailingPad)
                        .padding(.vertical, PXConnConnectionMetrics.timestampVerticalPad)
                        .frame(minWidth: PXConnConnectionMetrics.timestampMinWidth, alignment: .trailing)
                        .foregroundColor(theme.colors.secondary)
                }
                .padding(.bottom, PXConnConnectionMetrics.bottomSectionPad)

                ZStack(alignment: .topTrailing) {
                    Text(contactConnection.description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    incognitoIcon(contactConnection.incognito, theme.colors.secondary, size: dynamicSize(userFont).incognitoSize)
                        .padding(.top, PXConnConnectionMetrics.incognitoTopPad)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, PXConnConnectionMetrics.descHorizontalPad)

                Spacer()
            }
            .frame(maxHeight: .infinity)
        }
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 80)) {
    ContactConnectionView(chat: Chat(chatInfo: ChatInfo.sampleData.contactConnection))
}

// MARK: - POPOPX
extension ContactConnectionView {
    static let pxComponentTag: String = "PX_CONTACT_CONNECTION_VIEW"
    static let pxIconSize: CGFloat = PXConnConnectionMetrics.iconSize
    static let pxIconContainerSize: CGFloat = PXConnConnectionMetrics.iconContainerSize
}
