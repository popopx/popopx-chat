// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct PXDiscoverTabView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme

    var onBackToHome: (() -> Void)? = nil

    var body: some View {
        List {
            discoverGridSection
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("tab_discover", comment: "Discover tab"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }

    private var discoverGridSection: some View {
        Section {
            NavigationLink {
                GlobalSquareView(embedded: true)
            } label: {
                discoverRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconGradient: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E53")],
                    title: NSLocalizedString("discover_treehole", comment: "TreeHole / anonymous broadcast"),
                    subtitle: NSLocalizedString("discover_treehole_subtitle", comment: "TreeHole subtitle")
                )
            }

            NavigationLink {
                PXChannelsListView()
                    .environmentObject(chatModel)
                    .environmentObject(theme)
            } label: {
                discoverRow(
                    icon: "antenna.radiowaves.left.and.right.circle.fill",
                    iconGradient: [Color(hex: "#00B4D8"), Color(hex: "#00FFD2")],
                    title: NSLocalizedString("discover_channels", comment: "Channels"),
                    subtitle: NSLocalizedString("discover_channels_subtitle", comment: "Channels subtitle")
                )
            }

            NavigationLink {
                CommunityHubView()
                    .environmentObject(CommunityManager.shared)
                    .environmentObject(theme)
            } label: {
                discoverRow(
                    icon: "globe.asia.australia.fill",
                    iconGradient: [Color(hex: "#6E25C4"), Color(hex: "#A855F7")],
                    title: NSLocalizedString("discover_community", comment: "Community"),
                    subtitle: NSLocalizedString("discover_community_subtitle", comment: "Community subtitle")
                )
            }
        }
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
    }

    private func discoverRow(icon: String, iconGradient: [Color], title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.colors.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.secondary.opacity(0.5))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Channels List View

struct PXChannelsListView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var showChannelCreator = false

    private var channelChats: [Chat] {
        chatModel.chats.filter { chat in
            if case let .group(groupInfo, _) = chat.chatInfo {
                return groupInfo.isChannel
            }
            return false
        }
    }

    var body: some View {
        List {
            if channelChats.isEmpty {
                emptyStateSection
            } else {
                channelsSection
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("discover_channels", comment: "Channels"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showChannelCreator = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color(hex: "#6E25C4"))
                }
            }
        }
        .appSheet(isPresented: $showChannelCreator) {
            NavigationStack {
                PXChannelCreator()
                    .navigationTitle(NSLocalizedString("create_channel_nav_title", comment: "Create public channel navigation title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .modifier(ThemedBackground(grouped: true))
            }
        }
        .popopxBranded()
    }

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.colors.secondary.opacity(0.5))

                Text(NSLocalizedString("channels_empty_title", comment: "Channels empty state title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.colors.primary)

                Text(NSLocalizedString("channels_empty_subtitle", comment: "Channels empty state subtitle"))
                    .font(.system(size: 14))
                    .foregroundStyle(theme.colors.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showChannelCreator = true
                } label: {
                    Text(NSLocalizedString("channels_create_first", comment: "Create first channel button"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2")], startPoint: .leading, endPoint: .trailing))
                        )
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var channelsSection: some View {
        Section {
            ForEach(channelChats, id: \.viewId) { chat in
                channelRow(chat: chat)
            }
        }
        .listRowSeparator(.hidden)
    }

    private func channelRow(chat: Chat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(hex: "#00B4D8"))

            VStack(alignment: .leading, spacing: 4) {
                Text(chat.chatInfo.chatViewName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.colors.primary)

                Text(chat.chatInfo.chatTs, style: .relative)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.colors.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Community Hub View

struct CommunityHubView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        List {
            if communityManager.channels.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "globe.asia.australia")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.colors.secondary.opacity(0.5))

                        Text(NSLocalizedString("community_empty_title", comment: "Community empty title"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.colors.primary)

                        Text(NSLocalizedString("community_empty_subtitle", comment: "Community empty subtitle"))
                            .font(.system(size: 14))
                            .foregroundStyle(theme.colors.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(communityManager.channels) { channel in
                        CommunityChannelView(channel: channel)
                            .environmentObject(communityManager)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("discover_community", comment: "Community"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }
}
