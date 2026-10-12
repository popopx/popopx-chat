//
//  UserAddressLearnMore.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 27.04.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

struct UserAddressLearnMore: View {
    @State var showCreateAddressButton = false
    @State private var createAddressLinkActive = false
    @State private var createOneTimeLinkActive = false

    var body: some View {
        VStack {
            List {
                VStack(alignment: .leading, spacing: 12) {
                    (Text(Image(systemName: "envelope")).foregroundColor(.secondary) + textSpace + Text(NSLocalizedString("share_address_publicly", comment: "Bold header for sharing address publicly")).bold().font(QuantumFonts.sectionHeader).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary))
                    Text(NSLocalizedString("address_wont_lose_contacts", comment: "Hint that deleting address won't lose contacts"))

                    (Text(Image(systemName: "link.badge.plus")).foregroundColor(.secondary) + textSpace + Text(NSLocalizedString("share_onetime_link_friend", comment: "Bold header for 1-time link sharing")).font(QuantumFonts.sectionHeader).bold().foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary))
                        .padding(.top)
                    Text(NSLocalizedString("onetime_link_usage_hint", comment: "Explanation of 1-time link usage"))
                    Text(NSLocalizedString("set_connection_name_hint", comment: "Hint about setting connection name"))

                    if !showCreateAddressButton {
                        (Text(Image(systemName: "shield")).foregroundColor(.secondary) + textSpace + Text(NSLocalizedString("connection_security", comment: "Bold header for connection security")).font(QuantumFonts.sectionHeader).bold().foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary))
                            .padding(.top)
                        Text(NSLocalizedString("address_links_safe_share", comment: "Reassurance that addresses are safe to share"))
                        Text(NSLocalizedString("compare_security_codes", comment: "Suggestion to compare security codes"))
                        ExternalLink("read_more_user_guide", destination: URL(string: "https://popopxchat.com/docs/guide/making-connections.html#comparison-of-1-time-invitation-links-and-simplex-contact-addresses") ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                            .padding(.top)
                    }

                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
            .frame(maxHeight: .infinity, alignment: .top)

            Spacer()
            
            if showCreateAddressButton {
                VStack {
                    addressCreationButton()
                        .padding(.bottom)

                    createOneTimeLinkButton()
                }
                .padding()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .popopxBranded()
    }
    
    private func addressCreationButton() -> some View {
        ZStack {
            Button {
                createAddressLinkActive = true
            } label: {
                Text(NSLocalizedString("create_popopx_address", comment: "Button to create POPOPX address"))
            }
            .buttonStyle(OnboardingButtonStyle())
        }
        .navigationDestination(isPresented: $createAddressLinkActive) {
            UserAddressView(autoCreate: true)
                .navigationTitle(NSLocalizedString("popopx_address_title", comment: "Navigation title for POPOPX address"))
                .navigationBarTitleDisplayMode(.large)
        }
    }

    private func createOneTimeLinkButton() -> some View {
        ZStack {
            Button {
                createOneTimeLinkActive = true
            } label: {
                Text(NSLocalizedString("create_onetime_link", comment: "Button to create 1-time link"))
                    .font(.callout)
            }
        }
        .navigationDestination(isPresented: $createOneTimeLinkActive) {
            PXNewChat(selection: .invite)
                .navigationTitle(NSLocalizedString("new_chat_title", comment: "Navigation title for new chat"))
                .navigationBarTitleDisplayMode(.large)
                .modifier(ThemedBackground(grouped: true))
        }
    }
}

struct UserAddressLearnMore_Previews: PreviewProvider {
    static var previews: some View {
        UserAddressLearnMore()
    }
}
