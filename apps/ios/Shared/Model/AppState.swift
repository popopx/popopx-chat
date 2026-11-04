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

/// Manages app-level state by composing focused sub-state objects.
/// Backward-compatible computed properties delegate to sub-states.
@MainActor
final class AppStateModel: ObservableObject {
    static let shared = AppStateModel()

    // MARK: - Sub-state objects

    let onboarding = OnboardingState.shared
    let database = DatabaseState.shared
    let authentication = AuthenticationState.shared
    let mesh = MeshTransportState.shared

    private var subStateCancellables = Set<AnyCancellable>()

    private init() {
        onboarding.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subStateCancellables)
        database.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subStateCancellables)
        authentication.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subStateCancellables)
        mesh.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subStateCancellables)
    }

    // MARK: - Onboarding (delegates to onboarding sub-state)

    var onboardingStage: OnboardingStage? { get { onboarding.onboardingStage } set { onboarding.onboardingStage = newValue } }
    var migrationState: MigrationToState? { get { onboarding.migrationState } set { onboarding.migrationState = newValue } }

    // MARK: - Database (delegates to database sub-state)

    var v3DBMigration: V3DBMigrationState { get { database.v3DBMigration } set { database.v3DBMigration = newValue } }
    var chatInitialized: Bool { get { database.chatInitialized } set { database.chatInitialized = newValue } }
    var chatRunning: Bool? { get { database.chatRunning } set { database.chatRunning = newValue } }
    var chatDbChanged: Bool { get { database.chatDbChanged } set { database.chatDbChanged = newValue } }
    var chatDbEncrypted: Bool? { get { database.chatDbEncrypted } set { database.chatDbEncrypted = newValue } }
    var chatDbStatus: DBMigrationResult? { get { database.chatDbStatus } set { database.chatDbStatus = newValue } }
    var ctrlInitInProgress: Bool { get { database.ctrlInitInProgress } set { database.ctrlInitInProgress = newValue } }

    // MARK: - Authentication (delegates to authentication sub-state)

    var contentViewAccessAuthenticated: Bool { get { authentication.contentViewAccessAuthenticated } set { authentication.contentViewAccessAuthenticated = newValue } }
    var laRequest: LocalAuthRequest? { get { authentication.laRequest } set { authentication.laRequest = newValue } }

    // MARK: - Mesh transport (delegates to mesh sub-state)

    var transportRouter: TransportRouter { mesh.transportRouter }
    var meshTransportEnabled: Bool { get { mesh.meshTransportEnabled } set { mesh.meshTransportEnabled = newValue } }
    var meshAutoSwitch: Bool { get { mesh.meshAutoSwitch } set { mesh.meshAutoSwitch = newValue } }
    var meshGatewayEnabled: Bool { get { mesh.meshGatewayEnabled } set { mesh.meshGatewayEnabled = newValue } }
    var currentTransportID: String { get { mesh.currentTransportID } set { mesh.currentTransportID = newValue } }
    var activeTransportName: String { get { mesh.activeTransportName } set { mesh.activeTransportName = newValue } }
    var queuedMessageCount: Int { get { mesh.queuedMessageCount } set { mesh.queuedMessageCount = newValue } }
    var nearbyMeshPeers: [PublicPeerSnapshot] { get { mesh.nearbyMeshPeers } set { mesh.nearbyMeshPeers = newValue } }
    var meshInboxMessages: [MeshInboxMessage] { get { mesh.meshInboxMessages } set { mesh.meshInboxMessages = newValue } }
    var meshBridge: MeshChatBridge? { get { mesh.meshBridge } set { mesh.meshBridge = newValue } }
    var meshConversations: [Chat] { get { mesh.meshConversations } set { mesh.meshConversations = newValue } }
    var bluetoothPermissionDenied: Bool { get { mesh.bluetoothPermissionDenied } set { mesh.bluetoothPermissionDenied = newValue } }

    // MARK: - Terminal

    @Published var showingTerminal = false
    @Published var terminalItems: [TerminalItem] = []

    // MARK: - App URLs

    @Published var appOpenUrl: URL?
    @Published var appOpenUrlLater: URL?

    // MARK: - Clipboard

    @Published var clipboardDetectedLink: String?

    // MARK: - Tab navigation

    @Published var switchToChatsTab = false

    // MARK: - Remote desktop

    @Published var remoteCtrlSession: RemoteCtrlSession?

    // MARK: - Invitation

    @Published var showingInvitation: ShowingInvitation?

    // MARK: - Audio recording/playback

    @Published var stopPreviousRecPlay: URL? = nil
    @Published var draft: ComposeState?
    @Published var draftChatId: String?

    // MARK: - Network

    @Published var networkInfo = UserNetworkInfo(networkType: .other, online: true)

    // MARK: - Compute store

    @Published var showComputeStore = false

    // MARK: - Monetization

    @Published var showPaywall = false

    // MARK: - Security notices

    @Published var showKeyRotationNotice = false

    // MARK: - Usage conditions

    @Published var conditions: ServerOperatorConditions = .empty

    var activeRemoteCtrl: Bool {
        remoteCtrlSession?.active ?? false
    }

    // MARK: - Reset

    func reset() {
        onboarding.reset()
        database.reset()
        authentication.reset()
        mesh.reset()
        showingTerminal = false
        terminalItems = []
        appOpenUrl = nil
        appOpenUrlLater = nil
        clipboardDetectedLink = nil
        switchToChatsTab = false
        remoteCtrlSession = nil
        showingInvitation = nil
        stopPreviousRecPlay = nil
        draft = nil
        draftChatId = nil
        networkInfo = UserNetworkInfo(networkType: .other, online: true)
        showComputeStore = false
        showPaywall = false
        showKeyRotationNotice = false
        conditions = .empty
    }
}
