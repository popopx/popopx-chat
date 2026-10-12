// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct PXContactsTabView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var searchMode = false
    @FocusState private var searchFocussed: Bool
    @State private var searchText = ""
    @State private var searchShowingPopopxLink = false
    @State private var searchChatFilteredByPopopxLink: String? = nil
    @State private var connectNameCandidate: String? = nil
    @State private var showNewChatSheet = false

    var onBackToHome: (() -> Void)? = nil

    var body: some View {
        List {
            searchSection

            quickActionsSection

            ContactsList(
                chatPredicate: contactListPredicate,
                searchMode: $searchMode,
                searchText: $searchText,
                header: NSLocalizedString("contacts_all_header", comment: "All contacts header"),
                searchFocussed: $searchFocussed,
                searchShowingPopopxLink: $searchShowingPopopxLink,
                searchChatFilteredByPopopxLink: $searchChatFilteredByPopopxLink,
                showDeletedChatIcon: false
            )
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("tab_contacts", comment: "Contacts tab"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewChatSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#6E25C4"))
                }
            }
        }
        .appSheet(isPresented: $showNewChatSheet) {
            NewChatSheet()
        }
        .popopxBranded()
    }

    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.colors.secondary)

                TextField(NSLocalizedString("contacts_search_placeholder", comment: "Search contacts"), text: $searchText)
                    .font(.system(size: 15))
                    .focused($searchFocussed)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.colors.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colors.primary.opacity(0.06))
            )
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var quickActionsSection: some View {
        Section {
            NavigationLink {
                PXNewChat(selection: .invite, hidePicker: true)
                    .modifier(ThemedBackground(grouped: true))
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                quickActionRow(
                    icon: "person.badge.plus",
                    iconGradient: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E53")],
                    title: NSLocalizedString("contacts_new_friends", comment: "New friends entry")
                )
            }

            NavigationLink {
                AddGroupView()
                    .navigationTitle(NSLocalizedString("create_group_nav_title", comment: "Create group navigation title"))
                    .modifier(ThemedBackground(grouped: true))
                    .navigationBarTitleDisplayMode(.large)
            } label: {
                quickActionRow(
                    icon: "person.3.fill",
                    iconGradient: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2")],
                    title: NSLocalizedString("contacts_group_chats", comment: "Group chats entry")
                )
            }

            NavigationLink {
                PXChannelCreator()
                    .navigationTitle(NSLocalizedString("create_channel_nav_title", comment: "Create public channel navigation title"))
                    .modifier(ThemedBackground(grouped: true))
                    .navigationBarTitleDisplayMode(.large)
            } label: {
                quickActionRow(
                    icon: "antenna.radiowaves.left.and.right",
                    iconGradient: [Color(hex: "#00B4D8"), Color(hex: "#00FFD2")],
                    title: NSLocalizedString("contacts_channels", comment: "Channels entry")
                )
            }
        }
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
    }

    private func quickActionRow(icon: String, iconGradient: [Color], title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.colors.primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func contactListPredicate(_ chat: Chat, _ withSearch: Bool) -> Bool {
        switch chat.chatInfo {
        case .contactRequest: true
        case let .direct(contact): contact.isContactCard || contact.active || (contact.chatDeleted && withSearch)
        default: false
        }
    }
}
