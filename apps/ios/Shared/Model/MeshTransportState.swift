//
//  MeshTransportState.swift
//  POPOPX
//
//  Extracted from AppStateModel - Bluetooth mesh transport state
//

import Foundation
import Combine
import BitchatMesh

@MainActor
final class MeshTransportState: ObservableObject {
    static let shared = MeshTransportState()

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

    func reset() {
        meshTransportEnabled = false
        meshAutoSwitch = true
        meshGatewayEnabled = false
        currentTransportID = "internet"
        activeTransportName = "Online"
        queuedMessageCount = 0
        nearbyMeshPeers = []
        meshInboxMessages = []
        meshBridge = nil
        meshConversations = []
        bluetoothPermissionDenied = false
    }
}
