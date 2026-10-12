// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

enum UserPickerSheet: Identifiable {
    case address
    case chatPreferences
    case chatProfiles
    case currentProfile
    case useFromDesktop
    case settings

    var id: Self { self }

    var navigationTitle: LocalizedStringKey {
        switch self {
        case .address: LocalizedStringKey(NSLocalizedString("POPOPX address", comment: ""))
        case .chatPreferences: LocalizedStringKey(NSLocalizedString("Your preferences", comment: ""))
        case .chatProfiles: LocalizedStringKey(NSLocalizedString("Your chat profiles", comment: ""))
        case .currentProfile: LocalizedStringKey(NSLocalizedString("Your current profile", comment: ""))
        case .useFromDesktop: LocalizedStringKey(NSLocalizedString("Connect to desktop", comment: ""))
        case .settings: LocalizedStringKey(NSLocalizedString("Your settings", comment: ""))
        }
    }
}

// Spec: spec/client/chat-list.md#PresetTag
enum PresetTag: Int, Identifiable, CaseIterable, Equatable {
    case groupReports = 0
    case favorites = 1
    case contacts = 2
    case groups = 3
    case channels = 4
    case business = 5
    case notes = 6

    var id: Int { rawValue }
    
    var сollapse: Bool {
        self != .groupReports
    }
}

// Spec: spec/client/chat-list.md#ActiveFilter
enum ActiveFilter: Identifiable, Equatable {
    case presetTag(PresetTag)
    case userTag(ChatTag)
    case unread
    
    var id: String {
        switch self {
        case let .presetTag(tag): "preset \(tag.id)"
        case let .userTag(tag): "user \(tag.chatTagId)"
        case .unread: "unread"
        }
    }
}

@MainActor
class SaveableSettings: ObservableObject {
    @Published var servers: ServerSettings = ServerSettings(currUserServers: [], userServers: [], serverErrors: [], serverWarnings: [])
}

struct ServerSettings {
    public var currUserServers: [UserOperatorServers]
    public var userServers: [UserOperatorServers]
    public var serverErrors: [UserServersError]
    public var serverWarnings: [UserServersWarning]
}

struct UserPickerSheetView: View {
    let sheet: UserPickerSheet
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var ss: SaveableSettings

    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                if loaded, let currentUser = chatModel.currentUser {
                    switch sheet {
                    case .address:
                        UserAddressView(shareViaProfile: currentUser.addressShared)
                    case .chatPreferences:
                        PreferencesView(
                            profile: currentUser.profile,
                            preferences: currentUser.fullPreferences,
                            currentPreferences: currentUser.fullPreferences
                        )
                    case .chatProfiles:
                        PXUserProfiles()
                    case .currentProfile:
                        UserProfile()
                    case .useFromDesktop:
                        ConnectDesktopView()
                    case .settings:
                        SettingsView()
                    }
                }
                Color.clear // Required for list background to be rendered during loading
            }
            .navigationTitle(sheet.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .modifier(ThemedBackground(grouped: true, glass: true))
        }
        .overlay {
            if let la = chatModel.laRequest {
                LocalAuthView(authRequest: la)
            }
        }
        .task {
            withAnimation(
                .easeOut(duration: 0.1),
                { loaded = true }
            )
        }
        .onDisappear {
            if serversCanBeSaved(
                ss.servers.currUserServers,
                ss.servers.userServers,
                ss.servers.serverErrors
            ) {
                showAlert(
                    title: NSLocalizedString("Save servers?", comment: "alert title"),
                    buttonTitle: NSLocalizedString("Save", comment: "alert button"),
                    buttonAction: { Task { saveServers($ss.servers.currUserServers, $ss.servers.userServers) } },
                    cancelButton: true
                )
            }
        }
        .environmentObject(ss)
        .popopxBranded()
    }
}

// Spec: spec/client/chat-list.md#ChatListView
