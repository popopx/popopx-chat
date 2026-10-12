// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ProfileTabView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var showNewChatSheet = false
    @State private var navigationPath = NavigationPath()
    
    // Callback to navigate back to home (chats tab)
    var onBackToHome: (() -> Void)? = nil

    var body: some View {
        let user = chatModel.currentUser ?? User.sampleData
        let isDark = isInDarkTheme()

        NavigationStack(path: $navigationPath) {
            List {
            Section {
                HStack(spacing: 16) {
                    GlowAvatarView(size: 72) {
                        ProfileImage(imageStr: user.image, size: 64, color: Color(uiColor: .quaternaryLabel), showTierBadge: true)
                            .frame(width: 64, height: 64)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.displayName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(theme.colors.primary)

                        if let userAddress = chatModel.userAddress {
                            let displayLink = userAddress.connLinkContact.encryptedConnLink
                                ?? userAddress.connLinkContact.connShortLink
                            if let shortLink = displayLink {
                                Text(shortLink)
                                    .font(.system(size: 12).monospaced())
                                    .foregroundStyle(theme.colors.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(isDark ? Color(hex: "#181829").opacity(0.6) : Color(hex: "#FFFFFF").opacity(0.7))
                                    )
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
            }
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)

            Section {
                NavigationLink {
                    UserAddressView(shareViaProfile: chatModel.currentUser?.addressShared ?? false)
                        .environmentObject(chatModel)
                        .environmentObject(theme)
                } label: {
                    Label(NSLocalizedString("profile_address_label", comment: "POPOPX address label"), systemImage: "qrcode")
                }
                .profileGlassCard()

                NavigationLink {
                    PXUserProfiles()
                        .environmentObject(chatModel)
                        .environmentObject(theme)
                } label: {
                    Label(NSLocalizedString("profile_chat_profiles_label", comment: "Your chat profiles label"), systemImage: "person.crop.rectangle.stack")
                }
                .profileGlassCard()

                NavigationLink {
                    ConnectDesktopView()
                        .environmentObject(chatModel)
                        .environmentObject(theme)
                } label: {
                    Label(NSLocalizedString("profile_connect_desktop_label", comment: "Connect to desktop label"), systemImage: "desktopcomputer")
                }
                .profileGlassCard()

                NavigationLink {
                    PreferencesView(
                        profile: user.profile,
                        preferences: user.fullPreferences,
                        currentPreferences: user.fullPreferences
                    )
                    .environmentObject(chatModel)
                } label: {
                    Label(NSLocalizedString("profile_preferences_label", comment: "Your preferences label"), systemImage: "slider.horizontal.3")
                }
                .profileGlassCard()
                
                NavigationLink {
                    SettingsView()
                        .environmentObject(chatModel)
                        .environmentObject(theme)
                } label: {
                    Label(NSLocalizedString("profile_settings_label", comment: "Your settings label"), systemImage: "gearshape.fill")
                }
                .profileGlassCard()

            }
            .listSectionSeparator(.hidden)
        } // End of List
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("profile_nav_title", comment: "navigation title for profile tab"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast(navigationPath.count)
                    } else {
                        onBackToHome?()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.colors.primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NewChatMenuButton(showNewChatSheet: $showNewChatSheet)
            }
        }
        .appSheet(isPresented: $showNewChatSheet) {
            NewChatSheet()
        }
        .popopxBranded()
        } // End of NavigationStack wrapper
    } // End of body var
} // End of ProfileTabView struct
