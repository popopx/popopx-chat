//
//  AppState.swift
//  POPOPX
//
//  Extracted from ChatModel.swift - App-level state
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Combine
import SwiftUI
import BitchatMesh
@preconcurrency import POPOPXSwitch

/// Manages app-level state: onboarding, authentication, terminal, mesh, migration, etc.
@MainActor
final class AppStateModel: ObservableObject {
    // Onboarding
    @Published var onboardingStage: OnboardingStage?

    // Database migration
    @Published var v3DBMigration: V3DBMigrationState = v3DBMigrationDefault.get()
    @Published var chatInitialized = false
    @Published var chatRunning: Bool?
    @Published var chatDbChanged = false
    @Published var chatDbEncrypted: Bool?
    @Published var chatDbStatus: DBMigrationResult?
    @Published var ctrlInitInProgress: Bool = false

    // Local authentication
    @Published var contentViewAccessAuthenticated: Bool = false
    @Published var laRequest: LocalAuthRequest?

    // Terminal
    @Published var showingTerminal = false
    @Published var terminalItems: [TerminalItem] = []

    // App URLs
    @Published var appOpenUrl: URL?
    @Published var appOpenUrlLater: URL?

    // Clipboard auto-detect: popopx:/ link found in pasteboard on app activation
    @Published var clipboardDetectedLink: String?

    // Tab navigation
    @Published var switchToChatsTab = false

    // Remote desktop
    @Published var remoteCtrlSession: RemoteCtrlSession?

    // Invitation
    @Published var showingInvitation: ShowingInvitation?

    // Migration
    @Published var migrationState: MigrationToState? = MigrationToDeviceState.makeMigrationState()

    // Audio recording/playback
    @Published var stopPreviousRecPlay: URL? = nil
    @Published var draft: ComposeState?
    @Published var draftChatId: String?

    // Network
    @Published var networkInfo = UserNetworkInfo(networkType: .other, online: true)

    // Bluetooth mesh transport
    let transportRouter = TransportRouter()
    @Published var meshTransportEnabled = false
    @Published var meshAutoSwitch = true
    @Published var meshGatewayEnabled = false
    @Published var currentTransportID = "internet"
    @Published var activeTransportName = "Online"
    @Published var queuedMessageCount = 0
    @Published var nearbyMeshPeers: [PublicPeerSnapshot] = []
    @Published var meshInboxMessages: [MeshInboxMessage] = []
    @Published var meshBridge: MeshChatBridge?
    @Published var meshConversations: [Chat] = []
    @Published var bluetoothPermissionDenied = false

    // Compute store
    @Published var showComputeStore = false

    // Monetization
    @Published var showPaywall = false

    // Security notices
    @Published var showKeyRotationNotice = false

    // Usage conditions
    @Published var conditions: ServerOperatorConditions = .empty

    static let shared = AppStateModel()

    var activeRemoteCtrl: Bool {
        remoteCtrlSession?.active ?? false
    }

    // MARK: - Reset

    func reset() {
        onboardingStage = nil
        chatInitialized = false
        chatRunning = nil
        chatDbChanged = false
        chatDbEncrypted = nil
        chatDbStatus = nil
        ctrlInitInProgress = false
        contentViewAccessAuthenticated = false
        laRequest = nil
        showingTerminal = false
        terminalItems = []
        appOpenUrl = nil
        appOpenUrlLater = nil
        remoteCtrlSession = nil
        showingInvitation = nil
        migrationState = MigrationToDeviceState.makeMigrationState()
        stopPreviousRecPlay = nil
        draft = nil
        draftChatId = nil
        networkInfo = UserNetworkInfo(networkType: .other, online: true)
        meshTransportEnabled = false
        meshAutoSwitch = true
        meshGatewayEnabled = false
        currentTransportID = "internet"
        activeTransportName = "Online"
        queuedMessageCount = 0
        nearbyMeshPeers = []
        meshInboxMessages = []
        meshConversations = []
        bluetoothPermissionDenied = false
        showComputeStore = false
        showPaywall = false
        conditions = .empty
    }
}
