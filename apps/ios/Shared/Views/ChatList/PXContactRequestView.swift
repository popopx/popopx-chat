//
//  ContactRequestView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 02/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// POPOPX layout metrics for contact-request row
private enum PXContactRequestMetrics {
    static let rowSpacing: CGFloat = 10
    static let avatarLeadingPad: CGFloat = 6
    static let nameLeadingPad: CGFloat = 10
    static let timestampTrailingPad: CGFloat = 10
    static let timestampTopPad: CGFloat = 6
    static let timestampMinWidth: CGFloat = 62
    static let bottomSectionPad: CGFloat = 3
    static let descHorizontalPad: CGFloat = 10
    static let nameShadowRadius: CGFloat = 5
    static let nameShadowOpacity: Double = 0.18
}

struct ContactRequestView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dynamicTypeSize) private var userFont: DynamicTypeSize
    var contactRequest: UserContactRequest
    @ObservedObject var chat: Chat

    var body: some View {
        HStack(spacing: PXContactRequestMetrics.rowSpacing) {
            ChatInfoImage(chat: chat, size: dynamicSize(userFont).profileImageSize)
                .padding(.leading, PXContactRequestMetrics.avatarLeadingPad)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    NameWithBadge(
                        Text(contactRequest.chatViewName)
                            .font(.headline.weight(.bold))
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.primary),
                        chat.chatInfo.nameBadge,
                        .title3
                    )
                    .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXContactRequestMetrics.nameShadowOpacity) : .clear, radius: PXContactRequestMetrics.nameShadowRadius, x: 0, y: 1)
                    .padding(.leading, PXContactRequestMetrics.nameLeadingPad)
                    .frame(alignment: .topLeading)
                    Spacer()
                    formatTimestampText(contactRequest.updatedAt)
                        .font(.subheadline)
                        .padding(.trailing, PXContactRequestMetrics.timestampTrailingPad)
                        .padding(.top, PXContactRequestMetrics.timestampTopPad)
                        .frame(minWidth: PXContactRequestMetrics.timestampMinWidth, alignment: .trailing)
                        .foregroundColor(theme.colors.secondary)
                }
                .padding(.bottom, PXContactRequestMetrics.bottomSectionPad)

                // Localized connection-request prompt
                Text(String(localized: "wants to connect to you!", comment: "Contact request message shown when someone wants to connect"))
                    .frame(alignment: .topLeading)
                    .padding([.leading, .trailing], PXContactRequestMetrics.descHorizontalPad)

                Spacer()
            }
            .frame(maxHeight: .infinity)
        }
        .popopxBranded()
    }
}

struct ContactRequestView_Previews: PreviewProvider {
    static var previews: some View {
        ContactRequestView(contactRequest: UserContactRequest.sampleData, chat: Chat(chatInfo: ChatInfo.sampleData.contactRequest , chatItems: []))
            .previewLayout(.fixed(width: 360, height: 80))
    }
}

// MARK: - POPOPX
extension ContactRequestView {
    static let pxComponentTag: String = "PX_CONTACT_REQUEST_VIEW"
    static let pxTimestampMinWidth: CGFloat = PXContactRequestMetrics.timestampMinWidth
    static let pxHStackSpacing: CGFloat = PXContactRequestMetrics.rowSpacing
}
