//
//  SettingsView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 31/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import StoreKit
import POPOPXSwitch
import BitchatMesh

let popopxTeamURL = URL(string: "popopx:/a#lrdvu2d8A1GumSmoKb2krQmtKhWXq-tyGpHuM7aMwsw?h=smp6.popopxchat.com")

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")  as? String

let DEFAULT_SHOW_LA_NOTICE = "showLocalAuthenticationNotice"
let DEFAULT_LA_NOTICE_SHOWN = "localAuthenticationNoticeShown"
let DEFAULT_PERFORM_LA = "performLocalAuthentication" // deprecated, moved to app group
let DEFAULT_LA_MODE = "localAuthenticationMode"
let DEFAULT_LA_LOCK_DELAY = "localAuthenticationLockDelay"
let DEFAULT_LA_SELF_DESTRUCT = "localAuthenticationSelfDestruct"
let DEFAULT_LA_SELF_DESTRUCT_DISPLAY_NAME = "localAuthenticationSelfDestructDisplayName"
let DEFAULT_NOTIFICATION_ALERT_SHOWN = "notificationAlertShown"
let DEFAULT_WEBRTC_POLICY_RELAY = "webrtcPolicyRelay"
let DEFAULT_WEBRTC_ICE_SERVERS = "webrtcICEServers"
let DEFAULT_CALL_KIT_CALLS_IN_RECENTS = "callKitCallsInRecents"
let DEFAULT_PRIVACY_ACCEPT_IMAGES = "privacyAcceptImages" // unused. Use GROUP_DEFAULT_PRIVACY_ACCEPT_IMAGES instead
let DEFAULT_PRIVACY_LINK_PREVIEWS = "privacyLinkPreviews" // deprecated, moved to app group
let DEFAULT_PRIVACY_POPOPX_LINK_MODE = "privacyPopopxLinkMode"
let DEFAULT_PRIVACY_SHOW_CHAT_PREVIEWS = "privacyShowChatPreviews"
let DEFAULT_PRIVACY_SAVE_LAST_DRAFT = "privacySaveLastDraft"
let DEFAULT_PRIVACY_PROTECT_SCREEN = "privacyProtectScreen"
let DEFAULT_BINTHERE_SECURITY = "binThereSecurityEnhanced"
let DEFAULT_PRIVACY_DELIVERY_RECEIPTS_SET = "privacyDeliveryReceiptsSet"
let DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS = "privacyMediaBlurRadius"
let DEFAULT_EXPERIMENTAL_CALLS = "experimentalCalls"
let DEFAULT_CHAT_ARCHIVE_NAME = "chatArchiveName"
let DEFAULT_CHAT_ARCHIVE_TIME = "chatArchiveTime"
let DEFAULT_CHAT_V3_DB_MIGRATION = "chatV3DBMigration"
let DEFAULT_SHOULD_IMPORT_APP_SETTINGS = "shouldImportAppSettings"
let DEFAULT_DEVELOPER_TOOLS = "developerTools"
let DEFAULT_ENCRYPTION_STARTED = "encryptionStarted"
let DEFAULT_ENCRYPTION_STARTED_AT = "encryptionStartedAt"
let DEFAULT_SHOULD_DELETE_DATABASE_BACKUPS = "shouldDeleteDatabaseBackups"
let DEFAULT_ACCENT_COLOR_RED = "accentColorRed" // deprecated, only used for migration
let DEFAULT_ACCENT_COLOR_GREEN = "accentColorGreen" // deprecated, only used for migration
let DEFAULT_ACCENT_COLOR_BLUE = "accentColorBlue" // deprecated, only used for migration
let DEFAULT_USER_INTERFACE_STYLE = "userInterfaceStyle" // deprecated, only used for migration
let DEFAULT_PROFILE_IMAGE_CORNER_RADIUS = "profileImageCornerRadius"
let DEFAULT_CHAT_ITEM_ROUNDNESS = "chatItemRoundness"
let DEFAULT_CHAT_ITEM_TAIL = "chatItemTail"
let DEFAULT_ONE_HAND_UI_CARD_SHOWN = "oneHandUICardShown"
let DEFAULT_ADDRESS_CREATION_CARD_SHOWN = "addressCreationCardShown"
let DEFAULT_SUPPORTER_BANNER_SHOWN = "supporterBannerShown"
let DEFAULT_SUPPORTER_BANNER_TAPPED = "supporterBannerTapped"
let DEFAULT_GET_STAKE_BANNER_TAPPED = "getStakeBannerTapped"
let DEFAULT_GET_STAKE_BANNER_DISMISSED = "getStakeBannerDismissed"
let DEFAULT_TOOLBAR_MATERIAL = "toolbarMaterial"
let DEFAULT_CONNECT_VIA_LINK_TAB = "connectViaLinkTab"
let DEFAULT_LIVE_MESSAGE_ALERT_SHOWN = "liveMessageAlertShown"
let DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE = "showHiddenProfilesNotice"
let DEFAULT_SHOW_MUTE_PROFILE_ALERT = "showMuteProfileAlert"
let DEFAULT_SHOW_REPORTS_IN_SUPPORT_CHAT_ALERT = "showReportsInSupportChatAlert"
let DEFAULT_WHATS_NEW_VERSION = "defaultWhatsNewVersion"
let DEFAULT_ONBOARDING_STAGE = "onboardingStage"
let DEFAULT_MIGRATION_TO_STAGE = "migrationToStage"
let DEFAULT_MIGRATION_FROM_STAGE = "migrationFromStage"
let DEFAULT_CUSTOM_DISAPPEARING_MESSAGE_TIME = "customDisappearingMessageTime"
let DEFAULT_SHOW_UNREAD_AND_FAVORITES = "showUnreadAndFavorites"
let DEFAULT_CONFIRM_REMOTE_SESSIONS = "confirmRemoteSessions"
let DEFAULT_SHOW_DELETE_CONVERSATION_NOTICE = "showDeleteConversationNotice"
let DEFAULT_SHOW_DELETE_CONTACT_NOTICE = "showDeleteContactNotice"
let DEFAULT_SHOW_SENT_VIA_RPOXY = "showSentViaProxy"
let DEFAULT_PRIVACY_SHOW_SIGNATURE = "privacyShowSignature"
let DEFAULT_PRIVACY_SHOW_FILE_ENCRYPTION = "privacyShowFileEncryption"
let DEFAULT_PRIVACY_VERIFY_POPOPX_NAMES = "privacyVerifyPopopxNames"
let DEFAULT_SHOW_SUBSCRIPTION_PERCENTAGE = "showSubscriptionPercentage"
let DEFAULT_MARKDOWN_FILE_TEXT_VIEW = "markdownFileTextView"

let DEFAULT_CURRENT_THEME = "currentTheme"
let DEFAULT_SYSTEM_DARK_THEME = "systemDarkTheme"
let DEFAULT_CURRENT_THEME_IDS = "currentThemeIds"
let DEFAULT_THEME_OVERRIDES = "themeOverrides"

let DEFAULT_NETWORK_PROXY = "networkProxy"

let ANDROID_DEFAULT_CALL_ON_LOCK_SCREEN = "androidCallOnLockScreen"

let defaultChatItemRoundness: Double = 0.75

let appDefaults: [String: Any] = [
    DEFAULT_SHOW_LA_NOTICE: false,
    DEFAULT_LA_NOTICE_SHOWN: false,
    DEFAULT_PERFORM_LA: false,
    DEFAULT_LA_MODE: LAMode.system.rawValue,
    DEFAULT_LA_LOCK_DELAY: 30,
    DEFAULT_LA_SELF_DESTRUCT: false,
    DEFAULT_NOTIFICATION_ALERT_SHOWN: false,
    DEFAULT_WEBRTC_POLICY_RELAY: true,
    DEFAULT_CALL_KIT_CALLS_IN_RECENTS: false,
    DEFAULT_PRIVACY_ACCEPT_IMAGES: true,
    DEFAULT_PRIVACY_LINK_PREVIEWS: true,
    DEFAULT_PRIVACY_POPOPX_LINK_MODE: LinkDisplayMode.description.rawValue,
    DEFAULT_PRIVACY_SHOW_CHAT_PREVIEWS: true,
    DEFAULT_PRIVACY_SAVE_LAST_DRAFT: true,
    DEFAULT_PRIVACY_PROTECT_SCREEN: false,
    DEFAULT_BINTHERE_SECURITY: true,
    DEFAULT_PRIVACY_DELIVERY_RECEIPTS_SET: false,
    DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS: 0,
    DEFAULT_EXPERIMENTAL_CALLS: false,
    DEFAULT_CHAT_V3_DB_MIGRATION: V3DBMigrationState.offer.rawValue,
    DEFAULT_DEVELOPER_TOOLS: false,
    DEFAULT_ENCRYPTION_STARTED: false,
    DEFAULT_PROFILE_IMAGE_CORNER_RADIUS: defaultProfileImageCorner,
    DEFAULT_CHAT_ITEM_ROUNDNESS: defaultChatItemRoundness,
    DEFAULT_CHAT_ITEM_TAIL: true,
    DEFAULT_ONE_HAND_UI_CARD_SHOWN: false,
    DEFAULT_ADDRESS_CREATION_CARD_SHOWN: false,
    DEFAULT_SUPPORTER_BANNER_SHOWN: false,
    DEFAULT_SUPPORTER_BANNER_TAPPED: false,
    DEFAULT_GET_STAKE_BANNER_TAPPED: false,
    DEFAULT_GET_STAKE_BANNER_DISMISSED: false,
    DEFAULT_TOOLBAR_MATERIAL: ToolbarMaterial.defaultMaterial,
    DEFAULT_CONNECT_VIA_LINK_TAB: ConnectViaLinkTab.scan.rawValue,
    DEFAULT_LIVE_MESSAGE_ALERT_SHOWN: false,
    DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE: true,
    DEFAULT_SHOW_MUTE_PROFILE_ALERT: true,
    DEFAULT_SHOW_REPORTS_IN_SUPPORT_CHAT_ALERT: true,
    DEFAULT_ONBOARDING_STAGE: OnboardingStage.onboardingComplete.rawValue,
    DEFAULT_CUSTOM_DISAPPEARING_MESSAGE_TIME: 300,
    DEFAULT_SHOW_UNREAD_AND_FAVORITES: false,
    DEFAULT_CONFIRM_REMOTE_SESSIONS: false,
    DEFAULT_SHOW_DELETE_CONVERSATION_NOTICE: true,
    DEFAULT_SHOW_DELETE_CONTACT_NOTICE: true,
    DEFAULT_SHOW_SENT_VIA_RPOXY: false,
    DEFAULT_SHOW_SUBSCRIPTION_PERCENTAGE: false,
    DEFAULT_MARKDOWN_FILE_TEXT_VIEW: false,
    ANDROID_DEFAULT_CALL_ON_LOCK_SCREEN: AppSettingsLockScreenCalls.show.rawValue,

    DEFAULT_THEME_OVERRIDES: "{}",
    DEFAULT_CURRENT_THEME: DefaultTheme.SYSTEM_THEME_NAME,
    DEFAULT_SYSTEM_DARK_THEME: DefaultTheme.DARK.themeName,
    DEFAULT_CURRENT_THEME_IDS: "{}"
]

// only Bool defaults can be used here,
// or hintDefaultsUnchanged and resetHintDefaults need to be changed
let hintDefaults = [
    DEFAULT_LA_NOTICE_SHOWN,
    DEFAULT_ONE_HAND_UI_CARD_SHOWN,
    DEFAULT_ADDRESS_CREATION_CARD_SHOWN,
    DEFAULT_SUPPORTER_BANNER_SHOWN,
    DEFAULT_SUPPORTER_BANNER_TAPPED,
    DEFAULT_GET_STAKE_BANNER_TAPPED,
    DEFAULT_GET_STAKE_BANNER_DISMISSED,
    DEFAULT_LIVE_MESSAGE_ALERT_SHOWN,
    DEFAULT_SHOW_HIDDEN_PROFILES_NOTICE,
    DEFAULT_SHOW_MUTE_PROFILE_ALERT,
    DEFAULT_SHOW_REPORTS_IN_SUPPORT_CHAT_ALERT,
    DEFAULT_SHOW_DELETE_CONVERSATION_NOTICE,
    DEFAULT_SHOW_DELETE_CONTACT_NOTICE
]

let hintGroupDefaults = [
    GROUP_DEFAULT_PRIVACY_LINK_PREVIEWS_SHOW_ALERT
]

// not used anymore
enum ConnectViaLinkTab: String {
    case scan
    case paste
}

enum LinkDisplayMode: String, Identifiable {
    case description
    case full
    case browser

    static var values: [LinkDisplayMode] = [.description, .full]

    public var id: Self { self }

    var text: LocalizedStringKey {
        switch self {
        case .description: return "Description"
        case .full: return "Full link"
        case .browser: return "Via browser"
        }
    }
}

private var indent: CGFloat = 36

let chatArchiveTimeDefault = DateDefault(defaults: UserDefaults.standard, forKey: DEFAULT_CHAT_ARCHIVE_TIME)

let encryptionStartedDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_ENCRYPTION_STARTED)

let encryptionStartedAtDefault = DateDefault(defaults: UserDefaults.standard, forKey: DEFAULT_ENCRYPTION_STARTED_AT)

let shouldDeleteDatabaseBackupsDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_SHOULD_DELETE_DATABASE_BACKUPS)

let connectViaLinkTabDefault = EnumDefault<ConnectViaLinkTab>(defaults: UserDefaults.standard, forKey: DEFAULT_CONNECT_VIA_LINK_TAB, withDefault: .scan)

let privacyPopopxLinkModeDefault = EnumDefault<LinkDisplayMode>(defaults: UserDefaults.standard, forKey: DEFAULT_PRIVACY_POPOPX_LINK_MODE, withDefault: .description)

let privacyLocalAuthModeDefault = EnumDefault<LAMode>(defaults: UserDefaults.standard, forKey: DEFAULT_LA_MODE, withDefault: .system)

let privacyDeliveryReceiptsSet = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_PRIVACY_DELIVERY_RECEIPTS_SET)

let onboardingStageDefault = EnumDefault<OnboardingStage>(defaults: UserDefaults.standard, forKey: DEFAULT_ONBOARDING_STAGE, withDefault: .onboardingComplete)

let customDisappearingMessageTimeDefault = IntDefault(defaults: UserDefaults.standard, forKey: DEFAULT_CUSTOM_DISAPPEARING_MESSAGE_TIME)

let showDeleteConversationNoticeDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_SHOW_DELETE_CONVERSATION_NOTICE)
let showDeleteContactNoticeDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_SHOW_DELETE_CONTACT_NOTICE)

let showReportsInSupportChatAlertDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_SHOW_REPORTS_IN_SUPPORT_CHAT_ALERT)

/// after importing new database, this flag will be set and unset only after importing app settings in `initializeChat` */
let shouldImportAppSettingsDefault = BoolDefault(defaults: UserDefaults.standard, forKey: DEFAULT_SHOULD_IMPORT_APP_SETTINGS)
let currentThemeDefault = StringDefault(defaults: UserDefaults.standard, forKey: DEFAULT_CURRENT_THEME, withDefault: DefaultTheme.DARK.themeName)
let systemDarkThemeDefault = StringDefault(defaults: UserDefaults.standard, forKey: DEFAULT_SYSTEM_DARK_THEME, withDefault: DefaultTheme.DARK.themeName)
let currentThemeIdsDefault = CodableDefault<[String: String]>(defaults: UserDefaults.standard, forKey: DEFAULT_CURRENT_THEME_IDS, withDefault: [:] )
let themeOverridesDefault: CodableDefault<[ThemeOverrides]> = CodableDefault(defaults: UserDefaults.standard, forKey: DEFAULT_THEME_OVERRIDES, withDefault: [])

func setGroupDefaults() {
    privacyAcceptImagesGroupDefault.set(UserDefaults.standard.bool(forKey: DEFAULT_PRIVACY_ACCEPT_IMAGES))
    appLocalAuthEnabledGroupDefault.set(UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA))
    privacyLinkPreviewsGroupDefault.set(UserDefaults.standard.bool(forKey: DEFAULT_PRIVACY_LINK_PREVIEWS))
    profileImageCornerRadiusGroupDefault.set(UserDefaults.standard.double(forKey: DEFAULT_PROFILE_IMAGE_CORNER_RADIUS))
}

public class StringDefault {
    var defaults: UserDefaults
    var key: String
    var defaultValue: String

    public init(defaults: UserDefaults = UserDefaults.standard, forKey: String, withDefault: String) {
        self.defaults = defaults
        self.key = forKey
        self.defaultValue = withDefault
    }

    public func get() -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    public func set(_ value: String) {
        defaults.set(value, forKey: key)
    }
}

public class CodableDefault<T: Codable> {
    var defaults: UserDefaults
    var key: String
    var defaultValue: T

    public init(defaults: UserDefaults = UserDefaults.standard, forKey: String, withDefault: T) {
        self.defaults = defaults
        self.key = forKey
        self.defaultValue = withDefault
    }

    public func get() -> T {
        if let value = defaults.string(forKey: key) {
            return decodeJSON(value) ?? defaultValue
        }
        return defaultValue
    }

    public func set(_ value: T) {
        defaults.set(encodeJSON(value), forKey: key)
    }
}

let networkProxyDefault: CodableDefault<NetworkProxy> = CodableDefault(defaults: UserDefaults.standard, forKey: DEFAULT_NETWORK_PROXY, withDefault: NetworkProxy.def)

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showProgress: Bool = false
    @State private var settingsTab: SettingsTab = .regular

    private enum SettingsTab: String, CaseIterable {
        case regular = "settings_tab_general"
        case advanced = "settings_tab_advanced"
        case custom = "settings_tab_help"
    }

    var body: some View {
        ZStack {
            if isInDarkTheme() {
                Circle()
                    .fill(darkThemeAccentColor().opacity(0.03))
                    .frame(width: 400, height: 400)
                    .offset(x: -120, y: -300)
                    .blur(radius: 50)
                Circle()
                    .fill(neonGradientSecondary().opacity(0.02))
                    .frame(width: 350, height: 350)
                    .offset(x: 140, y: 250)
                    .blur(radius: 40)
            }
            settingsView()
            if showProgress {
                progressView()
            }
        }
        .popopxBranded()
    }

    func settingsView() -> some View {
        VStack(spacing: 0) {
            Picker(LocalizedStringKey(NSLocalizedString("settings_tab_picker", comment: "Settings tab picker label")), selection: $settingsTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(verbatim: NSLocalizedString(tab.rawValue, comment: "settings tab")).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch settingsTab {
            case .regular: regularTab()
            case .advanced: advancedTab()
            case .custom: customTab()
            }
        }
        .navigationTitle(NSLocalizedString("settings_title", comment: "Settings page title"))
        .modifier(ThemedBackground(grouped: true, glass: true))
        .onDisappear {
            chatModel.showingTerminal = false
            chatModel.terminalItems = []
        }
    }

    // MARK: - General tab

    private func regularTab() -> some View {
        List {
            Section(header: GradientSectionHeader(title: NSLocalizedString("Settings", comment: "Settings section header"))) {
                NavigationLink {
                    PXNotifications()
                        .environmentObject(theme)
                        .navigationTitle(NSLocalizedString("Notifications", comment: "Notifications settings title"))
                        .modifier(ThemedBackground(grouped: true, glass: true))
                } label: {
                    HStack {
                        notificationsIcon()
                        Text(NSLocalizedString("Notifications", comment: "Notifications settings row"))
                    }
                }
                .disabled(chatModel.chatRunning != true)

                NavigationLink {
                    CallSettings()
                        .environmentObject(theme)
                        .navigationTitle(NSLocalizedString("Your calls", comment: "Call settings title"))
                        .modifier(ThemedBackground(grouped: true, glass: true))
                } label: {
                    settingsRow("video", color: theme.colors.secondary) { Text(NSLocalizedString("Audio & video calls", comment: "Audio & video calls settings row")) }
                }
                .disabled(chatModel.chatRunning != true)

                NavigationLink {
                    PrivacySettings()
                        .environmentObject(theme)
                        .navigationTitle(NSLocalizedString("Your privacy", comment: "Privacy settings title"))
                        .modifier(ThemedBackground(grouped: true, glass: true))
                } label: {
                    settingsRow("lock", color: theme.colors.secondary) { Text(NSLocalizedString("Privacy & security", comment: "Privacy & security settings row")) }
                }
                .disabled(chatModel.chatRunning != true)

                NavigationLink {
                    PXAppearanceConfig()
                        .environmentObject(theme)
                        .navigationTitle(NSLocalizedString("Appearance", comment: "Appearance settings title"))
                        .modifier(ThemedBackground(grouped: true, glass: true))
                } label: {
                    settingsRow("sun.max", color: theme.colors.secondary) { Text(NSLocalizedString("Appearance", comment: "Appearance settings row")) }
                }
                .disabled(chatModel.chatRunning != true)
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Quantum", comment: "Quantum section header"))) {
                NavigationLink {
                    SubscriptionView()
                } label: {
                    settingsRow("crown", color: theme.colors.secondary) { Text(NSLocalizedString("Membership", comment: "Membership settings row")) }
                }
                NavigationLink {
                    MembershipCardView()
                } label: {
                    settingsRow("creditcard.fill", color: theme.colors.secondary) { Text(NSLocalizedString("Membership Card", comment: "Membership card purchase and redemption")) }
                }
                NavigationLink {
                    ComputeStoreView()
                } label: {
                    settingsRow("bolt", color: theme.colors.secondary) { Text(NSLocalizedString("Compute store", comment: "Compute store settings row")) }
                }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Bluetooth Mesh", comment: "Bluetooth Mesh section header"))) {
                NavigationLink {
                    TransportSettingsView(chatModel: chatModel)
                } label: {
                    settingsRow("antenna.radiowaves.left.and.right", color: theme.colors.secondary) { Text(NSLocalizedString("Mesh transport", comment: "Mesh transport settings row")) }
                }
                NavigationLink {
                    BitchatBridgeView()
                } label: {
                    settingsRow("message.badge.fill", color: theme.colors.secondary) { Text(NSLocalizedString("Mesh Chat", comment: "Mesh Chat settings row")) }
                }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Privacy Features", comment: "Privacy Features section header"))) {
                NavigationLink {
                    AIChatView()
                        .environmentObject(theme)
                        .environmentObject(AIChatManager.shared)
                } label: {
                    settingsRow("brain.head.profile", color: theme.colors.secondary) { Text(NSLocalizedString("AI Assistant", comment: "AI Assistant settings row")) }
                }
                NavigationLink {
                    SecureVotingView()
                        .environmentObject(theme)
                        .environmentObject(MPCManager.shared)
                } label: {
                    settingsRow("lock.shield.fill", color: theme.colors.secondary) { Text(NSLocalizedString("Privacy Computing", comment: "Privacy Computing settings row")) }
                }
                NavigationLink {
                    DIDCardView(card: DIDManager.shared.currentCard)
                        .environmentObject(DIDManager.shared)
                } label: {
                    settingsRow("person.badge.key.fill", color: theme.colors.secondary) { Text(NSLocalizedString("DID Identity", comment: "DID Identity settings row")) }
                }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Community", comment: "settings section header"))) {
                NavigationLink {
                    CommunityListView()
                        .environmentObject(CommunityManager.shared)
                } label: {
                    settingsRow("bubble.left.and.bubble.right.fill", color: theme.colors.secondary) { Text(NSLocalizedString("settings_community_channels", comment: "Community channels settings row")) }
                }
            }

            Section {
                NavigationLink {
                    BadgesView()
                        .modifier(ThemedBackground())
                } label: {
                    let badgeType = chatModel.currentUser?.profile.localBadge?.badge.badgeType ?? .supporter
                    ZStack(alignment: .leading) {
                        Image(badgeImageName(badgeType))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(NSLocalizedString("Supporter perks", comment: "Badges and supporter perks row")).padding(.leading, indent)
                    }
                }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Generative Art", comment: "Generative Art settings section header"))) {
                NavigationLink {
                    GenerativeArtGalleryView()
                } label: {
                    settingsRow("paintpalette.fill", color: theme.colors.secondary) { Text(NSLocalizedString("Art Gallery", comment: "Generative art gallery settings row")) }
                }
                Toggle(isOn: Binding(
                    get: { CyberThemeManager.shared.isCyberMode },
                    set: { CyberThemeManager.shared.setCyberMode($0) }
                )) {
                    settingsRow("sparkles", color: theme.colors.secondary) { Text(NSLocalizedString("Cyber Mode", comment: "Cyber mode toggle in settings")) }
                }
            }

        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.05) : .clear, radius: 20, x: 0, y: 0)
    }

    // MARK: - Advanced tab

    private func advancedTab() -> some View {
        List {
            Section(header: GradientSectionHeader(title: NSLocalizedString("Network", comment: "settings section header"))) {
                NavigationLink {
                    NetworkAndServers()
                        .navigationTitle(NSLocalizedString("settings_network_servers_title", comment: "Network and servers navigation title"))
                        .modifier(ThemedBackground(grouped: true, glass: true))
                } label: {
                    settingsRow("externaldrive.connected.to.line.below", color: theme.colors.secondary) {
                        HStack {
                            Text(NSLocalizedString("settings_network_servers", comment: "Network and servers settings row"))
                            if !subscription.hasActiveSubscription {
                                Text(NSLocalizedString("settings_premium", comment: "Premium badge label"))
                                    .font(.caption)
                                    .foregroundColor(theme.colors.secondary)
                            }
                        }
                    }
                }
                .disabled(chatModel.chatRunning != true)
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Cryptography", comment: "settings section header"))) {
                NavigationLink {
                    KyberKeyExchangeView()
                } label: {
                    settingsRow("key.fill", color: theme.colors.secondary) {
                        HStack {
                            Text(NSLocalizedString("settings_x25519_key_exchange", comment: "X25519 key exchange settings row"))
                            Text(NSLocalizedString("settings_demo", comment: "Demo badge label")).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(QuantumColors.accent.opacity(0.2)))
                        }
                    }
                }
                NavigationLink {
                    DilithiumSignatureView()
                } label: {
                    settingsRow("pencil.and.outline", color: theme.colors.secondary) {
                        HStack {
                            Text(NSLocalizedString("settings_ed25519_signatures", comment: "Ed25519 signatures settings row"))
                            Text(NSLocalizedString("settings_demo", comment: "Demo badge label")).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(QuantumColors.accent.opacity(0.2)))
                        }
                    }
                }
                NavigationLink {
                    DataMarketView()
                } label: {
                    settingsRow("cart.fill", color: theme.colors.secondary) { Text(NSLocalizedString("settings_data_market", comment: "Data market settings row")) }
                }
                NavigationLink {
                    ComplianceSettingsView()
                } label: {
                    settingsRow("checkmark.shield.fill", color: theme.colors.secondary) { Text(NSLocalizedString("settings_compliance", comment: "Compliance settings row")) }
                }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Chat database", comment: "settings section header"))) {
                chatDatabaseRow()
                NavigationLink {
                    MigrateFromDevice(showProgressOnSettings: $showProgress)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                Text(NSLocalizedString("settings_migrate_device", comment: "Migrate device toolbar title")).font(.headline)
                            }
                        }
                        .modifier(ThemedBackground(grouped: true, glass: true))
                        .navigationBarTitleDisplayMode(.large)
                } label: {
                    settingsRow("tray.and.arrow.up", color: theme.colors.secondary) { Text(NSLocalizedString("settings_migrate_to_device", comment: "Migrate to another device settings row")) }
                }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Bots & Bridges", comment: "settings section header"))) {
                NavigationLink {
                    BotSettingsView()
                        .environmentObject(BotManager.shared)
                } label: {
                    settingsRow("gearshape.2.fill", color: theme.colors.secondary) { Text(NSLocalizedString("settings_bot_settings", comment: "Bot settings row")) }
                }
                NavigationLink {
                    EmailBridgeView()
                } label: {
                    settingsRow("envelope.fill", color: theme.colors.secondary) { Text(NSLocalizedString("settings_email_bridge", comment: "Email bridge settings row")) }
                }
                NavigationLink {
                    SMSBridgeView()
                } label: {
                    settingsRow("message.fill", color: theme.colors.secondary) { Text(NSLocalizedString("settings_sms_bridge", comment: "SMS bridge settings row")) }
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.05) : .clear, radius: 20, x: 0, y: 0)
    }

    // MARK: - Help tab

    @ViewBuilder
    private func membershipStatusRow() -> some View {
        if subscription.hasActiveSubscription {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(LinearGradient(colors: [QuantumColors.accent, QuantumColors.accentSecondary], startPoint: .leading, endPoint: .trailing))
                    Text(NSLocalizedString("Active Member", comment: ""))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let days = subscription.daysUntilExpiration {
                        Text(String(format: NSLocalizedString("%d days remaining", comment: ""), days))
                            .font(.caption)
                            .foregroundColor(days <= 7 ? QuantumColors.warning : theme.colors.secondary)
                    }
                }

                if let expiry = subscription.subscriptionExpirationDate {
                    HStack {
                        Text(NSLocalizedString("Expires", comment: ""))
                            .font(.caption)
                            .foregroundColor(theme.colors.secondary)
                        Spacer()
                        Text(expiry.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(theme.colors.secondary)
                    }
                }

                Button {
                    Task {
                        #if canImport(UIKit)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            await subscription.showManageSubscriptions(in: windowScene)
                        }
                        #endif
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(NSLocalizedString("Renew / Manage", comment: ""))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(QuantumColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(QuantumColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        } else {
            NavigationLink {
                SubscriptionView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.colors.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(QuantumColors.accent.opacity(0.1))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Membership", comment: ""))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                        Text(NSLocalizedString("Not subscribed", comment: ""))
                            .font(.caption)
                            .foregroundColor(theme.colors.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                }
            }
        }
    }

    private func customTab() -> some View {
        List {
            Section(header: GradientSectionHeader(title: NSLocalizedString("Help", comment: "settings section header"))) {
                if let user = chatModel.currentUser {
                    NavigationLink {
                        ChatHelp(dismissSettingsSheet: dismiss)
                            .navigationTitle(String(format: NSLocalizedString("settings_welcome_user", comment: "Welcome navigation title with user name"), user.displayName))
                            .modifier(ThemedBackground())
                            .frame(maxHeight: .infinity, alignment: .top)
                    } label: {
                        settingsRow("questionmark", color: theme.colors.secondary) { Text(NSLocalizedString("settings_how_to_use", comment: "How to use help row")) }
                    }
                }
                NavigationLink {
                    WhatsNewView(viaSettings: true, updatedConditions: false)
                        .modifier(ThemedBackground())
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    settingsRow("plus", color: theme.colors.secondary) { Text(NSLocalizedString("settings_whats_new", comment: "What's new settings row")) }
                }
                NavigationLink {
                    AppInfoView(onboarding: false)
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .modifier(ThemedBackground())
                        .frame(maxHeight: .infinity, alignment: .top)
                } label: {
                    settingsRow("info", color: theme.colors.secondary) { Text(NSLocalizedString("settings_about_app", comment: "About app settings row")) }
                }
                NavigationLink {
                    OpenSourceLicenseView()
                        .modifier(ThemedBackground())
                } label: {
                    settingsRow("doc.text", color: theme.colors.secondary) { Text(NSLocalizedString("settings_licenses", comment: "Open source licenses settings row")) }
                }
                Button {
                    dismiss()
                    if let url = popopxTeamURL {
                        DispatchQueue.main.async {
                            ChatModel.shared.appOpenUrl = url
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "number")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(theme.colors.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : theme.colors.primary.opacity(0.15))
                            )
                            .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.2) : theme.colors.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                        Text(NSLocalizedString("settings_send_feedback", comment: "Send questions and ideas button label"))
                            .foregroundColor(isInDarkTheme() ? .white : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(theme.colors.secondary)
                    }
                }
                .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                .disabled(chatModel.chatRunning != true)
                settingsRow("envelope", color: theme.colors.secondary) { Text("[\(NSLocalizedString("settings_send_us_email", comment: "Send us email link"))](mailto:support@popopxchat.com)") }
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Membership", comment: "Membership section header"))) {
                membershipStatusRow()
            }

            Section(header: GradientSectionHeader(title: NSLocalizedString("Develop", comment: "settings section header"))) {
                NavigationLink {
                    DeveloperView()
                        .navigationTitle(NSLocalizedString("settings_developer_tools_title", comment: "Developer tools navigation title"))
                        .modifier(ThemedBackground(grouped: true, glass: true))
                } label: {
                    settingsRow("chevron.left.forwardslash.chevron.right", color: theme.colors.secondary) { Text(NSLocalizedString("settings_developer_tools", comment: "Developer tools settings row")) }
                }
                NavigationLink {
                    VersionView()
                        .navigationTitle(NSLocalizedString("settings_app_version_title", comment: "App version navigation title"))
                        .modifier(ThemedBackground())
                } label: {
                    Text(String(format: NSLocalizedString("settings_version_format", comment: "Version format string like v1.0 (123)"), appVersion ?? "?", appBuild ?? "?"))
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.05) : .clear, radius: 20, x: 0, y: 0)
    }
    
    private func chatDatabaseRow() -> some View {
        NavigationLink {
            DatabaseView(dismissSettingsSheet: dismiss, chatItemTTL: chatModel.chatItemTTL)
                .navigationTitle(NSLocalizedString("settings_chat_database_title", comment: "Chat database navigation title"))
                .modifier(ThemedBackground(grouped: true))
        } label: {
            let color: Color = chatModel.chatDbEncrypted == false ? QuantumColors.warning : theme.colors.secondary
            settingsRow("internaldrive", color: color) {
                HStack {
                    Text(NSLocalizedString("settings_db_passphrase_export", comment: "Database passphrase and export row label"))
                    Spacer()
                    if chatModel.chatRunning == false {
                        Image(systemName: "exclamationmark.octagon.fill").foregroundColor(theme.colors.error)
                    }
                }
            }
        }
    }

    private func progressView() -> some View {
        VStack {
            // BrandedProgressView.swift is not yet in the Xcode project; using ProgressView as placeholder.
            ProgressView()
                .scaleEffect(1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity )
    }

    private enum NotificationAlert {
        case enable
        case error(LocalizedStringKey, String)
    }

    private func notificationsIcon() -> some View {
        let icon: String
        let color: Color
        switch (chatModel.tokenStatus) {
        case .new:
            icon = "bolt"
            color = theme.colors.secondary
        case .registered:
            icon = "bolt.fill"
            color = theme.colors.secondary
        case .invalid: fallthrough
        case .invalidBad: fallthrough
        case .invalidTopic: fallthrough
        case .invalidExpired: fallthrough
        case .invalidUnregistered:
            icon = "bolt.slash"
            color = theme.colors.secondary
        case .confirmed:
            icon = "bolt.fill"
            color = QuantumColors.warning
        case .active:
            icon = "bolt.fill"
            color = QuantumColors.success
        case .expired:
            icon = "bolt.slash.fill"
            color = theme.colors.secondary
        case .none:
            icon = "bolt"
            color = theme.colors.secondary
        }
        return Image(systemName: icon)
            .padding(.trailing, 9)
            .foregroundColor(color)
    }
}

struct SettingsRow<Content: View>: View {
    @EnvironmentObject var theme: AppTheme
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .leading) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AnyShapeStyle(LinearGradient(
                        colors: isInDarkTheme()
                        ? [darkThemeAccentColor().opacity(0.15), neonGradientSecondary().opacity(0.1)]
                        : [theme.colors.primary.opacity(0.15), theme.colors.primaryVariant.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(color)
            }
            .frame(maxWidth: 32, maxHeight: 32, alignment: .center)
            .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.2) : theme.colors.primary.opacity(0.2), radius: 4, x: 0, y: 2)
            content().padding(.leading, indent)
        }
    }
}

func settingsRow<Content : View>(_ icon: String, color: Color, content: @escaping () -> Content) -> some View {
    SettingsRow(icon: icon, color: color, content: content)
}

struct GradientSectionHeader: View {
    @EnvironmentObject var theme: AppTheme
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.primary)
                .textCase(.uppercase)
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.4) : .clear, radius: 6, x: 0, y: 0)
            Rectangle()
                .fill(AnyShapeStyle(LinearGradient(
                    colors: isInDarkTheme()
                    ? [darkThemeAccentColor().opacity(0.9), neonGradientSecondary().opacity(0.7)]
                    : [theme.colors.primary.opacity(0.7), theme.colors.primaryVariant.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )))
                .frame(height: 1.5)
                .cornerRadius(1)
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.5) : .clear, radius: 6, x: 0, y: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct ProfilePreview: View {
    var profileOf: NamedChat
    var color = Color(uiColor: .tertiarySystemGroupedBackground)
    var badge: LocalBadge? = nil

    var body: some View {
        HStack {
            ProfileImage(imageStr: profileOf.image, size: 44, color: color, showTierBadge: true)
                .padding(.trailing, 6)
            NameWithBadge(profileName(profileOf), badge, .title2)
                .lineLimit(1)
        }
    }
}

func profileName(_ profileOf: NamedChat) -> Text {
    var t = Text(profileOf.displayName).fontWeight(.semibold).font(.title2)
    if profileOf.fullName != "" && profileOf.fullName != profileOf.displayName {
        t = t + Text(verbatim: " (" + profileOf.fullName + ")")
//                        .font(.callout)
        }
    return t
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let chatModel = ChatModel()
        chatModel.currentUser = User.sampleData
        return SettingsView()
            .environmentObject(chatModel)
    }
}
