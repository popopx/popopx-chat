// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import BitchatMesh
import Combine
import CoreBluetooth
import POPOPXSwitch

@MainActor
class TransportManager {
    static let shared = TransportManager()

    private var internetTransport: InternetTransport?
    private var bluetoothTransport: BitchatTransportAdapter?
    private var nostrTransport: NostrTransportAdapter?
    private var cancellables = Set<AnyCancellable>()
    private var peerUpdateTimer: Timer?

    private let peerSubject = CurrentValueSubject<[PublicPeerSnapshot], Never>([])

    // Bluetooth permission handling
    private var permissionCentralManager: CBCentralManager?
    private var permissionCompletion: (() -> Void)?

    private init() {}

    func initialize() async {
        let router = ChatModel.shared.transportRouter

        let internet = InternetTransport()
        internetTransport = internet
        await router.registerTransport("internet", transport: internet)
        await router.setPreferredTransport("internet")

        let nostr = NostrTransportAdapter()
        self.nostrTransport = nostr
        Task {
            await router.registerTransport("nostr", transport: nostr)
        }

        ChatModel.shared.meshTransportEnabled = meshTransportEnabledGroupDefault.get()
        ChatModel.shared.meshAutoSwitch = meshAutoSwitchGroupDefault.get()
        ChatModel.shared.meshGatewayEnabled = meshGatewayEnabledGroupDefault.get()

        ChatModel.shared.appState.$meshTransportEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.startBluetooth()
                } else {
                    self?.stopBluetooth()
                }
            }
            .store(in: &cancellables)
    }

    func updateInternetAvailability(_ available: Bool) {
        internetTransport?.updateAvailability(available)
    }

    func sendMessage(_ text: String, recipientID: String? = nil) async throws {
        let payload = Data(text.utf8)
        let message = TransportMessage(
            id: UUID().uuidString,
            recipientID: recipientID,
            payload: payload,
            priority: .normal
        )
        try await ChatModel.shared.transportRouter.send(message)
    }

    private func startBluetooth() {
        if CBCentralManager.authorization != .allowedAlways {
            ChatModel.shared.bluetoothPermissionDenied = true
            return
        }
        BitchatRuntimeBridge.shared.ensureStarted()
        guard let meshTransport = BitchatRuntimeBridge.shared.meshTransport else {
            logger.error("Failed to start bitchat mesh service")
            return
        }

        let adapter = BitchatTransportAdapter(transport: meshTransport)
        bluetoothTransport = adapter

        adapter.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleMeshMessage(message)
            }
        }

        do {
            try adapter.start()
        } catch {
            logger.error("Failed to start Bluetooth transport: \(error)")
        }

        if ChatModel.shared.meshBridge == nil {
            ChatModel.shared.meshBridge = MeshChatBridge()
        }
        guard let bridge = ChatModel.shared.meshBridge else {
            logger.error("Failed to create MeshChatBridge")
            return
        }
        bridge.start(transport: meshTransport, chatModel: ChatModel.shared)

        // Nostr relay connect + subscribe is handled by NostrTransportAdapter.start()
        // via NostrRelayBridge.connect() — do not duplicate here.
        do {
            try nostrTransport?.start()
        } catch {
            logger.error("TransportManager: failed to start Nostr transport: \(error)")
        }

        // Enable gateway and bridge if configured
        if ChatModel.shared.meshGatewayEnabled {
            BitchatSharedRuntime.shared.enableGateway(true)
            BitchatSharedRuntime.shared.enableBridge(true)
        }

        let router = ChatModel.shared.transportRouter
        Task {
            await router.registerTransport("bluetooth", transport: adapter)
        }

        startPeerUpdates()
    }

    /// Request Bluetooth permission during onboarding
    func requestBluetoothPermission(completion: @escaping () -> Void) {
        guard CBCentralManager.authorization == .notDetermined else {
            completion()
            return
        }
        // Store the completion and create a central manager with a delegate
        // that fires when the user responds to the permission dialog.
        permissionCompletion = completion
        permissionCentralManager = CBCentralManager(
            delegate: BTPermissionDelegate.shared,
            queue: .main
        )
        BTPermissionDelegate.shared.handler = { [weak self] in
            self?.permissionCompletion?()
            self?.permissionCompletion = nil
            self?.permissionCentralManager = nil
        }
    }

    private func stopBluetooth() {
        BitchatSharedRuntime.shared.enableGateway(false)
        BitchatSharedRuntime.shared.enableBridge(false)
        nostrTransport?.stop()
        BitchatSharedRuntime.shared.disconnectNostrRelays()
        ChatModel.shared.meshBridge?.stop()
        ChatModel.shared.meshConversations.removeAll()
        bluetoothTransport?.stop()
        bluetoothTransport = nil
        stopPeerUpdates()
        peerSubject.send([])
        MeshPeerPublisher.publish([])
        let router = ChatModel.shared.transportRouter
        Task {
            await router.setPreferredTransport("internet")
            await router.flushQueue()
        }
        ChatModel.shared.currentTransportID = "internet"
    }

    private func startPeerUpdates() {
        stopPeerUpdates()
        peerUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let peers = self.bluetoothTransport?.nearbyPeers() ?? []
                self.peerSubject.send(peers)
                ChatModel.shared.nearbyMeshPeers = peers
                MeshPeerPublisher.publish(peers)
            }
        }
    }

    private func stopPeerUpdates() {
        peerUpdateTimer?.invalidate()
        peerUpdateTimer = nil
    }

    /// Pause peer update timer when app enters background
    func pausePeerUpdates() {
        peerUpdateTimer?.invalidate()
        peerUpdateTimer = nil
    }

    /// Resume peer update timer when app returns to foreground, if Bluetooth is enabled
    func resumePeerUpdates() {
        guard bluetoothTransport != nil else { return }
        startPeerUpdates()
    }

    private func handleMeshMessage(_ message: TransportMessage) {
        logger.debug("Received mesh transport message: \(message.id)")
        guard let text = String(data: message.payload, encoding: .utf8) else { return }
        let inboxMsg = MeshInboxMessage(
            id: message.id,
            senderID: message.senderID ?? "unknown",
            text: text,
            receivedAt: Date()
        )
        ChatModel.shared.meshInboxMessages.insert(inboxMsg, at: 0)
        if ChatModel.shared.meshInboxMessages.count > 100 {
            ChatModel.shared.meshInboxMessages.removeLast()
        }
        Task {
            await MeshToPOPOPXGateway.shared.handleMeshMessage(message)
        }
    }

    private func handleNostrInbound(data: Data, from senderPubKey: String) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let inboxMsg = MeshInboxMessage(
            id: UUID().uuidString,
            senderID: senderPubKey.prefix(16).description,
            text: text,
            receivedAt: Date()
        )
        ChatModel.shared.meshInboxMessages.insert(inboxMsg, at: 0)
        if ChatModel.shared.meshInboxMessages.count > 100 {
            ChatModel.shared.meshInboxMessages.removeLast()
        }
    }

    var nearbyPeersPublisher: AnyPublisher<[PublicPeerSnapshot], Never> {
        peerSubject.eraseToAnyPublisher()
    }
}

// MARK: - Bluetooth Permission Delegate

/// Helper delegate that waits for the user's response to the Bluetooth
/// permission dialog and fires a completion handler once authorization
/// is determined. This replaces the previous blind 2-second timer.
private class BTPermissionDelegate: NSObject, CBCentralManagerDelegate {
    static let shared = BTPermissionDelegate()
    var handler: (() -> Void)?

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Authorization is no longer .notDetermined once the user responds
        if central.state != .unknown || CBCentralManager.authorization != .notDetermined {
            handler?()
            handler = nil
        }
    }
}
