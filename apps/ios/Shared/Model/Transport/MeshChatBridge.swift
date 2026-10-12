// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import Combine
import POPOPXSwitch
import BitchatMesh

/// Bridge that converts mesh transport events into POPOPX ChatItems
/// and manages mesh peer conversations within ChatModel.
@MainActor
final class MeshChatBridge: ObservableObject {
    private weak var chatModel: ChatModel?
    private var transport: RichMeshTransport?
    private var peerContacts: [String: MeshPeerContact] = [:]
    @Published var meshBoardPosts: [PublicBoardPost] = []
    @Published var meshGroups: [PublicGroupInfo] = []
    private var groupConversations: [String: [ChatItem]] = [:]
    private var transportMessageIDToChatItemID: [String: Int64] = [:]
    private var transportMessageIDOrder: [String] = []
    private let maxTransportMappings = 1000
    private let transportMappingEvictCount = 100
    private var persistedConversationMeta: [MeshConversationMeta] = []
    private var persistDebounceWorkItem: DispatchWorkItem?
    private var persistContactsWorkItem: DispatchWorkItem?

    private struct MeshConversationMeta: Codable {
        let peerIDHex: String
        let nickname: String
        let isGroup: Bool
        let groupIDHex: String?
        let groupName: String?
    }

    func start(transport: RichMeshTransport, chatModel: ChatModel) {
        self.transport = transport
        self.chatModel = chatModel
        loadPersistedPeerContacts()
        loadPersistedConversations()
        transport.onTransportEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleTransportEvent(event)
            }
        }
        transport.onBoardPostArrival = { [weak self] post in
            Task { @MainActor in
                guard let self else { return }
                self.meshBoardPosts.insert(post, at: 0)
            }
        }
        meshGroups = transport.myMeshGroups()
    }

    func stop() {
        persistPeerContacts()
        persistDebounceWorkItem?.cancel()
        persistDebounceWorkItem = nil
        persistContactsWorkItem?.cancel()
        persistContactsWorkItem = nil
        persistConversations()
        transport?.onTransportEvent = nil
        transport?.onBoardPostArrival = nil
        transport = nil
        chatModel = nil
        peerContacts.removeAll()
        meshBoardPosts.removeAll()
        meshGroups.removeAll()
        groupConversations.removeAll()
        transportMessageIDToChatItemID.removeAll()
        transportMessageIDOrder.removeAll()
    }

    // MARK: - Event handling

    private func handleTransportEvent(_ event: RichTransportEvent) {
        guard let chatModel = chatModel else { return }

        switch event {
        case .messageReceived(let msgID, let senderPeerIDHex, let senderNickname, let content, let timestamp, _):
            let item = MeshChatItemFactory.textItem(
                content: content,
                senderNickname: senderNickname,
                timestamp: timestamp,
                isSent: false
            )
            let contact = ensurePeerContact(peerIDHex: senderPeerIDHex, nickname: senderNickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)
            if chatModel.chatId != chatInfo.id {
                NotificationService.shared.sendLocalNotification(
                    title: senderNickname,
                    body: String(content.prefix(100)),
                    identifier: "mesh-msg-\(msgID)",
                    userInfo: ["peerIDHex": senderPeerIDHex, "chatId": chatInfo.id]
                )
            }

        case .publicMessageReceived(let peerIDHex, let nickname, let content, let timestamp, _):
            let item = MeshChatItemFactory.textItem(
                content: content,
                senderNickname: nickname,
                timestamp: timestamp,
                isSent: false
            )
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)

        case .noisePayloadReceived(let peerIDHex, let payloadTypeRaw, let payload, let timestamp):
            handleNoisePayload(peerIDHex: peerIDHex, typeRaw: payloadTypeRaw, payload: payload, timestamp: timestamp)

        case .publicVoiceFrameReceived(let peerIDHex, let nickname, let payload, let timestamp):
            let duration = estimateVoiceDuration(from: payload)
            let item = MeshChatItemFactory.voiceItem(
                data: payload,
                fileName: "voice_\(Int(timestamp.timeIntervalSince1970)).opus",
                duration: duration,
                senderNickname: nickname,
                timestamp: timestamp,
                isSent: false
            )
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)

        case .peerConnected(let peerIDHex):
            updatePeerConnection(peerIDHex: peerIDHex, isConnected: true)
            if let noiseKeyData = transport?.noisePublicKeyData(forPeerIDHex: peerIDHex) {
                let noisePubKeyHex = noiseKeyData.hexEncodedString()
                UnifiedConnectionHandler.shared.peerAppeared(blePeerID: peerIDHex, noisePubKeyHex: noisePubKeyHex)
            }

        case .peerDisconnected(let peerIDHex):
            updatePeerConnection(peerIDHex: peerIDHex, isConnected: false)
            UnifiedConnectionHandler.shared.peerDisappeared(blePeerID: peerIDHex)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(300))
                guard let self, self.transport != nil else { return }
                await MainActor.run {
                    if let contact = self.peerContacts[peerIDHex], !contact.isConnected {
                        self.peerContacts.removeValue(forKey: peerIDHex)
                        self.schedulePersistPeerContacts()
                        self.updateMeshConversationsList()
                    }
                }
            }

        case .peerSnapshotsUpdated(let snapshots):
            for snapshot in snapshots {
                let _ = ensurePeerContact(peerIDHex: snapshot.peerIDHex, nickname: snapshot.nickname, isConnected: snapshot.isConnected)
            }
            updateMeshConversationsList()

        case .messageDeliveryStatusUpdated(let messageID, let statusRaw):
            if let chatItemID = transportMessageIDToChatItemID[messageID] {
                outerLoop: for idx in chatModel.meshConversations.indices {
                    for itemIdx in chatModel.meshConversations[idx].chatItems.indices {
                        if chatModel.meshConversations[idx].chatItems[itemIdx].meta.itemId == chatItemID {
                            switch statusRaw {
                            case "sent", "delivered":
                                chatModel.meshConversations[idx].chatItems[itemIdx].meta.itemStatus = .sndSent(sndProgress: .complete)
                            case "read":
                                chatModel.meshConversations[idx].chatItems[itemIdx].meta.itemStatus = .rcvRead
                            case "sending":
                                chatModel.meshConversations[idx].chatItems[itemIdx].meta.itemStatus = .sndNew
                            case "failed":
                                chatModel.meshConversations[idx].chatItems[itemIdx].meta.itemStatus = .sndError(agentError: .other(sndError: "Mesh delivery failed"))
                            default:
                                break
                            }
                            break outerLoop
                        }
                    }
                }
            }

        case .bluetoothStateUpdated:
            break

        case .peerListUpdated:
            updateMeshConversationsList()

        case .groupMessageReceived:
            break

        case .groupMessageDecrypted(let groupIDHex, let groupName, let messageID, let senderNickname, let content, let timestamp):
            let item = MeshChatItemFactory.groupTextItem(
                content: content,
                senderNickname: senderNickname,
                timestamp: timestamp,
                isSent: false
            )
            let chatId = "meshgroup:\(groupIDHex)"
            let chatInfo = ChatInfo.meshGroup(groupIDHex: groupIDHex, name: groupName, memberCount: 0)
            addGroupChatItem(chatId: chatId, chatInfo: chatInfo, item: item)
            if chatModel.chatId != chatId {
                NotificationService.shared.sendLocalNotification(
                    title: groupName,
                    body: "\(senderNickname): \(String(content.prefix(80)))",
                    identifier: "mesh-group-msg-\(messageID)",
                    userInfo: ["groupIDHex": groupIDHex, "chatId": chatId]
                )
            }

        case .groupListUpdated(let groups):
            meshGroups = groups
        }
    }

    private func handleNoisePayload(peerIDHex: String, typeRaw: UInt8, payload: Data, timestamp: Date) {
        guard let chatModel = chatModel, transport != nil else { return }
        let nickname = peerContacts[peerIDHex]?.nickname ?? peerIDHex.prefix(8).description

        // 0x01 = privateMessage (text content inside noise)
        if typeRaw == 0x01, let text = String(data: payload, encoding: .utf8) {
            let item = MeshChatItemFactory.textItem(content: text, senderNickname: nickname, timestamp: timestamp, isSent: false)
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)
        }
        // 0x20 = privateFile
        else if typeRaw == 0x20 {
            let item = MeshChatItemFactory.fileItem(data: payload, fileName: "file_\(Int(timestamp.timeIntervalSince1970))", senderNickname: nickname, timestamp: timestamp, isSent: false)
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)
        }
    }

    // MARK: - Peer management

    private func ensurePeerContact(peerIDHex: String, nickname: String, isConnected: Bool) -> MeshPeerContact {
        if var existing = peerContacts[peerIDHex] {
            existing.isConnected = isConnected
            existing.nickname = nickname
            peerContacts[peerIDHex] = existing
            schedulePersistPeerContacts()
            return existing
        }
        let contact = MeshPeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: isConnected)
        peerContacts[peerIDHex] = contact
        schedulePersistPeerContacts()
        return contact
    }

    private func updatePeerConnection(peerIDHex: String, isConnected: Bool) {
        if var contact = peerContacts[peerIDHex] {
            contact.isConnected = isConnected
            peerContacts[peerIDHex] = contact
        }
        updateMeshConversationsList()
    }

    // MARK: - Chat model integration

    private func addMeshChatItem(_ chatInfo: ChatInfo, _ item: ChatItem, to chatModel: ChatModel) {
        let chatId = chatInfo.id

        if let idx = chatModel.meshConversations.firstIndex(where: { $0.chatInfo.id == chatId }) {
            let chat = chatModel.meshConversations[idx]
            chat.chatItems.append(item)
            chatModel.meshConversations[idx] = chat
        } else {
            let chat = Chat(chatInfo: chatInfo, chatItems: [item])
            chatModel.meshConversations.insert(chat, at: 0)
        }

        if chatModel.chatId == chatId {
            chatModel.im.reversedChatItems.insert(item, at: 0)
        }
        schedulePersistChatItems()
    }

    func loadMeshConversation(peerID: String) {
        guard let chatModel = chatModel else { return }
        let chatId = "mesh:\(peerID)"
        chatModel.im.reset()
        chatModel.chatId = chatId

        if let chat = chatModel.meshConversations.first(where: { $0.chatInfo.id == chatId }) {
            chatModel.im.reversedChatItems = chat.chatItems
        }
    }

    // MARK: - Send methods

    private func trackTransportMapping(_ messageID: String, chatItemID: Int64) {
        transportMessageIDToChatItemID[messageID] = chatItemID
        transportMessageIDOrder.append(messageID)
        if transportMessageIDOrder.count > maxTransportMappings {
            for oldKey in transportMessageIDOrder.prefix(transportMappingEvictCount) {
                transportMessageIDToChatItemID.removeValue(forKey: oldKey)
            }
            transportMessageIDOrder.removeFirst(transportMappingEvictCount)
        }
    }

    @discardableResult
    func sendText(_ text: String, to peerIDHex: String) -> Bool {
        guard let transport = transport, let chatModel = chatModel else { return false }
        let messageID = UUID().uuidString
        let nickname = peerContacts[peerIDHex]?.nickname ?? peerIDHex.prefix(8).description
        let item = MeshChatItemFactory.textItem(content: text, senderNickname: nickname, timestamp: .now, isSent: true)
        trackTransportMapping(messageID, chatItemID: item.meta.itemId)
        transport.sendPrivateMessage(text, to: peerIDHex)

        let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
        let chatInfo = ChatInfo.meshPeer(peer: contact)
        addMeshChatItem(chatInfo, item, to: chatModel)
        return true
    }

    func sendPublicText(_ text: String) {
        guard let transport = transport else { return }
        transport.sendPublicMessage(text)
    }

    func sendVoice(_ data: Data, to peerIDHex: String, duration: Int) {
        guard let transport = transport, let chatModel = chatModel else { return }
        let fileName = "voice_\(Int(Date.now.timeIntervalSince1970)).opus"
        let messageID = UUID().uuidString
        let nickname = peerContacts[peerIDHex]?.nickname ?? peerIDHex.prefix(8).description
        let item = MeshChatItemFactory.voiceItem(data: data, fileName: fileName, duration: duration, senderNickname: nickname, timestamp: .now, isSent: true)
        trackTransportMapping(messageID, chatItemID: item.meta.itemId)
        transport.sendVoiceFrame(data, to: peerIDHex)

        let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
        let chatInfo = ChatInfo.meshPeer(peer: contact)
        addMeshChatItem(chatInfo, item, to: chatModel)
    }

    func sendImage(_ data: Data, to peerIDHex: String) {
        guard let transport = transport, let chatModel = chatModel else { return }
        let fileName = "mesh_image_\(Int(Date.now.timeIntervalSince1970)).jpg"
        let transferId = UUID().uuidString
        let messageID = transferId
        let packet = BitchatFilePacket(fileName: fileName, fileSize: UInt64(data.count), mimeType: "image/jpeg", content: data)

        let nickname = peerContacts[peerIDHex]?.nickname ?? peerIDHex.prefix(8).description
        if let packetData = packet.encode() {
            let item = MeshChatItemFactory.imageItem(data: data, senderNickname: nickname, timestamp: .now, isSent: true)
            trackTransportMapping(messageID, chatItemID: item.meta.itemId)
            transport.sendFilePrivate(packetData, to: peerIDHex, transferId: transferId)
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)
        } else {
            let item = MeshChatItemFactory.imageItem(data: data, senderNickname: nickname, timestamp: .now, isSent: true)
            var mutableItem = item
            mutableItem.meta.itemStatus = .sndError(agentError: .other(sndError: "Failed to encode image"))
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, mutableItem, to: chatModel)
        }
    }

    func sendFile(_ data: Data, fileName: String, to peerIDHex: String) {
        guard let transport = transport, let chatModel = chatModel else { return }
        let transferId = UUID().uuidString
        let messageID = transferId
        let packet = BitchatFilePacket(fileName: fileName, fileSize: UInt64(data.count), mimeType: nil, content: data)

        let nickname = peerContacts[peerIDHex]?.nickname ?? peerIDHex.prefix(8).description
        if let packetData = packet.encode() {
            let item = MeshChatItemFactory.fileItem(data: data, fileName: fileName, senderNickname: nickname, timestamp: .now, isSent: true)
            trackTransportMapping(messageID, chatItemID: item.meta.itemId)
            transport.sendFilePrivate(packetData, to: peerIDHex, transferId: transferId)
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, item, to: chatModel)
        } else {
            let item = MeshChatItemFactory.fileItem(data: data, fileName: fileName, senderNickname: nickname, timestamp: .now, isSent: true)
            var mutableItem = item
            mutableItem.meta.itemStatus = .sndError(agentError: .other(sndError: "Failed to encode file"))
            let contact = ensurePeerContact(peerIDHex: peerIDHex, nickname: nickname, isConnected: true)
            let chatInfo = ChatInfo.meshPeer(peer: contact)
            addMeshChatItem(chatInfo, mutableItem, to: chatModel)
        }
    }

    // MARK: - Conversation list

    private func updateMeshConversationsList() {
        guard let chatModel = chatModel else { return }
        for (idx, chat) in chatModel.meshConversations.enumerated() {
            if case .meshPeer(let peer) = chat.chatInfo {
                if let updated = peerContacts[peer.peerIDHex] {
                    chatModel.meshConversations[idx] = Chat(chatInfo: .meshPeer(peer: updated), chatItems: chat.chatItems)
                }
            }
        }
        persistConversations()
    }

    func isMeshConversation(chatId: String?) -> Bool {
        chatId?.hasPrefix("mesh:") == true || chatId?.hasPrefix("meshgroup:") == true
    }

    func peerIDHex(from chatId: String) -> String? {
        if chatId.hasPrefix("meshgroup:") {
            return String(chatId.dropFirst(10))
        }
        guard chatId.hasPrefix("mesh:") else { return nil }
        return String(chatId.dropFirst(5))
    }

    // MARK: - Group conversations

    private func addGroupChatItem(chatId: String, chatInfo: ChatInfo, item: ChatItem) {
        guard let chatModel = chatModel else { return }
        groupConversations[chatId, default: []].append(item)

        if let idx = chatModel.meshConversations.firstIndex(where: { $0.chatInfo.id == chatId }) {
            let chat = chatModel.meshConversations[idx]
            chat.chatItems.append(item)
            chatModel.meshConversations[idx] = chat
        } else {
            let chat = Chat(chatInfo: chatInfo, chatItems: [item])
            chatModel.meshConversations.insert(chat, at: 0)
        }

        if chatModel.chatId == chatId {
            chatModel.im.reversedChatItems.insert(item, at: 0)
        }
        schedulePersistChatItems()
    }

    func loadMeshGroupConversation(groupIDHex: String) {
        guard let chatModel = chatModel else { return }
        let chatId = "meshgroup:\(groupIDHex)"
        chatModel.chatId = chatId
        if let items = groupConversations[chatId], !items.isEmpty {
            chatModel.im.reversedChatItems = items
        } else if let chat = chatModel.meshConversations.first(where: { $0.chatInfo.id == chatId }) {
            chatModel.im.reversedChatItems = chat.chatItems
            groupConversations[chatId] = chat.chatItems
        } else {
            chatModel.im.reversedChatItems = []
        }
    }

    @discardableResult
    func sendGroupText(_ text: String, groupIDHex: String) -> Bool {
        guard let transport = transport, chatModel != nil else { return false }
        transport.sendMeshGroupText(groupIDHex: groupIDHex, content: text)

        let group = meshGroups.first { $0.groupIDHex == groupIDHex }
        let groupName = group?.name ?? "Group"
        let item = MeshChatItemFactory.groupTextItem(content: text, senderNickname: "you", timestamp: .now, isSent: true)
        let chatId = "meshgroup:\(groupIDHex)"
        let chatInfo = ChatInfo.meshGroup(groupIDHex: groupIDHex, name: groupName, memberCount: group?.memberCount ?? 0)
        addGroupChatItem(chatId: chatId, chatInfo: chatInfo, item: item)
        return true
    }

    func createMeshGroup(named name: String) {
        guard let transport = transport else { return }
        if transport.createMeshGroup(named: name) != nil {
            meshGroups = transport.myMeshGroups()
        }
    }

    // MARK: - Board

    func loadBoardPosts(geohash: String = "") -> [PublicBoardPost] {
        transport?.boardPosts(geohash: geohash) ?? []
    }

    func postToBoard(content: String, geohash: String = "", isUrgent: Bool = false) {
        _ = transport?.postToBoard(content: content, geohash: geohash, isUrgent: isUrgent)
    }

    // MARK: - Broadcast voice

    func broadcastVoice(_ data: Data) {
        transport?.sendVoiceFrameBroadcast(data)
    }

    @Published var isBroadcastVoiceRecording = false
    private var broadcastVoiceSession: PTTLiveVoiceSession?

    func startBroadcastVoiceRecording() async {
        let session = PTTLiveVoiceSession(sendPacket: { [weak self] packet in
            self?.broadcastVoice(packet)
        })
        broadcastVoiceSession = session
        guard await session.requestPermission() else { return }
        do {
            try await session.start()
            isBroadcastVoiceRecording = true
        } catch {
            logger.error("startBroadcastVoiceRecording: session start failed: \(error)")
            broadcastVoiceSession = nil
        }
    }

    func finishBroadcastVoiceRecording() async {
        _ = await broadcastVoiceSession?.finish()
        broadcastVoiceSession = nil
        isBroadcastVoiceRecording = false
    }

    func cancelBroadcastVoiceRecording() async {
        await broadcastVoiceSession?.cancel()
        broadcastVoiceSession = nil
        isBroadcastVoiceRecording = false
    }

    /// Estimate voice duration from Opus payload size.
    /// Opus at typical voice quality (~24kbps) is roughly 3KB/s.
    /// Returns a minimum of 1 second for any non-empty payload.
    private func estimateVoiceDuration(from payload: Data) -> Int {
        let bytesPerSecond = 3000
        let estimated = max(1, payload.count / bytesPerSecond)
        return estimated
    }

    // MARK: - Diagnostics

    var myNoisePublicKeyHex: String? {
        transport?.myNoisePublicKeyHex
    }

    func meshTopologyJSON() -> String? {
        transport?.currentMeshTopologyJSON()
    }

    func pingPeer(_ peerIDHex: String, completion: @escaping (Double?, Int?) -> Void) {
        transport?.sendMeshPing(to: peerIDHex, completion: completion)
    }

    // MARK: - Persistence

    private func schedulePersistPeerContacts() {
        persistContactsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.persistContactsWorkItem = nil
            self.persistPeerContacts()
        }
        persistContactsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func persistPeerContacts() {
        do {
            let data = try JSONEncoder().encode(Array(peerContacts.values))
            groupDefaults.set(data, forKey: GROUP_DEFAULT_MESH_PEER_CONTACTS)
        } catch {
            logger.error("MeshChatBridge.persistPeerContacts: failed to encode peer contacts: \(error)")
        }
    }

    private func loadPersistedPeerContacts() {
        guard let data = groupDefaults.data(forKey: GROUP_DEFAULT_MESH_PEER_CONTACTS) else { return }
        do {
            let contacts = try JSONDecoder().decode([MeshPeerContact].self, from: data)
            for contact in contacts {
                peerContacts[contact.peerIDHex] = contact
            }
            if let chatModel = chatModel {
                for contact in peerContacts.values {
                    let chatInfo = ChatInfo.meshPeer(peer: contact)
                    let chatId = chatInfo.id
                    if !chatModel.meshConversations.contains(where: { $0.chatInfo.id == chatId }) {
                        chatModel.meshConversations.append(Chat(chatInfo: chatInfo, chatItems: []))
                    }
                }
            }
        } catch {
            logger.error("MeshChatBridge.loadPersistedPeerContacts: failed to decode peer contacts: \(error)")
        }
    }

    private func persistConversations() {
        guard let chatModel = chatModel else { return }
        var metaList: [MeshConversationMeta] = []
        for chat in chatModel.meshConversations {
            switch chat.chatInfo {
            case .meshPeer(let peer):
                metaList.append(MeshConversationMeta(
                    peerIDHex: peer.peerIDHex,
                    nickname: peer.nickname,
                    isGroup: false,
                    groupIDHex: nil,
                    groupName: nil
                ))
            case .meshGroup(let groupIDHex, let name, _):
                metaList.append(MeshConversationMeta(
                    peerIDHex: "",
                    nickname: name,
                    isGroup: true,
                    groupIDHex: groupIDHex,
                    groupName: name
                ))
            default:
                break
            }
        }
        persistedConversationMeta = metaList
        do {
            let data = try JSONEncoder().encode(metaList)
            groupDefaults.set(data, forKey: GROUP_DEFAULT_MESH_CONVERSATIONS)
        } catch {
            logger.error("MeshChatBridge.persistConversations: failed to encode conversation metadata: \(error)")
        }
    }

    private func loadPersistedConversations() {
        guard let chatModel = chatModel else { return }
        guard let data = groupDefaults.data(forKey: GROUP_DEFAULT_MESH_CONVERSATIONS) else { return }
        do {
            let metaList = try JSONDecoder().decode([MeshConversationMeta].self, from: data)
            persistedConversationMeta = metaList
            for meta in metaList {
                let chatId: String
                let chatInfo: ChatInfo
                if meta.isGroup, let groupIDHex = meta.groupIDHex {
                    chatId = "meshgroup:\(groupIDHex)"
                    chatInfo = .meshGroup(groupIDHex: groupIDHex, name: meta.groupName ?? "Group", memberCount: 0)
                } else {
                    chatId = "mesh:\(meta.peerIDHex)"
                    let contact = peerContacts[meta.peerIDHex] ?? MeshPeerContact(peerIDHex: meta.peerIDHex, nickname: meta.nickname, isConnected: false)
                    chatInfo = .meshPeer(peer: contact)
                }
                if !chatModel.meshConversations.contains(where: { $0.chatInfo.id == chatId }) {
                    chatModel.meshConversations.append(Chat(chatInfo: chatInfo, chatItems: []))
                }
            }
            loadPersistedChatItems()
        } catch {
            logger.error("MeshChatBridge.loadPersistedConversations: failed to decode conversation metadata: \(error)")
        }
    }

    // MARK: - Chat item persistence

    private func schedulePersistChatItems() {
        persistDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.persistDebounceWorkItem = nil
            self.persistChatItems()
        }
        persistDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func persistChatItems() {
        guard let chatModel = chatModel else { return }
        var records: [MeshChatItemRecord] = []
        for chat in chatModel.meshConversations {
            let chatId = chat.chatInfo.id
            for item in chat.chatItems {
                if let record = MeshChatItemRecord.from(chatId: chatId, item: item) {
                    records.append(record)
                }
            }
        }
        do {
            let data = try JSONEncoder().encode(records)
            groupDefaults.set(data, forKey: GROUP_DEFAULT_MESH_CHAT_ITEMS)
        } catch {
            logger.error("MeshChatBridge.persistChatItems: failed to encode chat items: \(error)")
        }
    }

    private func loadPersistedChatItems() {
        guard let chatModel = chatModel else { return }
        guard let data = groupDefaults.data(forKey: GROUP_DEFAULT_MESH_CHAT_ITEMS) else { return }
        do {
            let records = try JSONDecoder().decode([MeshChatItemRecord].self, from: data)

            let allExistingItems = chatModel.meshConversations.flatMap { $0.chatItems }
            MeshChatItemFactory.initialize(from: allExistingItems)

            var itemsByChatId: [String: [ChatItem]] = [:]
            for record in records {
                guard let item = record.toChatItem() else { continue }
                itemsByChatId[record.chatId, default: []].append(item)
            }

            for idx in chatModel.meshConversations.indices {
                let chatId = chatModel.meshConversations[idx].chatInfo.id
                if let items = itemsByChatId[chatId] {
                    chatModel.meshConversations[idx].chatItems = items.sorted { $0.meta.itemTs < $1.meta.itemTs }
                }
            }
        } catch {
            logger.error("MeshChatBridge.loadPersistedChatItems: failed to decode chat items: \(error)")
        }
    }

    // MARK: - Share extension integration

    func consumePendingSharePayload() {
        guard let payload = MeshShareStore.consumePendingPayload() else { return }
        let tempDir = FileManager.default.temporaryDirectory.standardized.path
        switch payload {
        case let .text(peerIDHex, text):
            sendText(text, to: peerIDHex)
        case let .image(peerIDHex, filePath, caption):
            let resolved = URL(fileURLWithPath: filePath).standardized.path
            guard resolved.hasPrefix(tempDir) else { return }
            do {
                // Check file size before loading into memory to prevent OOM
                let fileAttrs = try FileManager.default.attributesOfItem(atPath: resolved)
                if let fileSize = fileAttrs[.size] as? Int64, fileSize > MAX_FILE_SIZE_SMP {
                    logger.error("MeshChatBridge.consumePendingSharePayload: image too large (\(fileSize) bytes, max \(MAX_FILE_SIZE_SMP))")
                    return
                }
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                sendImage(data, to: peerIDHex)
                if !caption.isEmpty {
                    sendText(caption, to: peerIDHex)
                }
                // Clean up temp file after successful send
                try? FileManager.default.removeItem(atPath: filePath)
            } catch {
                logger.error("MeshChatBridge.consumePendingSharePayload: failed to load image from \(filePath): \(error)")
            }
        case let .file(peerIDHex, filePath, fileName, caption):
            let resolved = URL(fileURLWithPath: filePath).standardized.path
            guard resolved.hasPrefix(tempDir) else { return }
            do {
                // Check file size before loading into memory to prevent OOM
                let fileAttrs = try FileManager.default.attributesOfItem(atPath: resolved)
                if let fileSize = fileAttrs[.size] as? Int64, fileSize > MAX_FILE_SIZE_SMP {
                    logger.error("MeshChatBridge.consumePendingSharePayload: file too large (\(fileSize) bytes, max \(MAX_FILE_SIZE_SMP))")
                    return
                }
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                sendFile(data, fileName: fileName, to: peerIDHex)
                if !caption.isEmpty {
                    sendText(caption, to: peerIDHex)
                }
                // Clean up temp file after successful send
                try? FileManager.default.removeItem(atPath: filePath)
            } catch {
                logger.error("MeshChatBridge.consumePendingSharePayload: failed to load file from \(filePath): \(error)")
            }
        }
    }
}
