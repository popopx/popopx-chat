// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

/// Factory for creating POPOPX ChatItem instances from mesh transport data.
/// Uses synthetic IDs in a range that never collides with Haskell-assigned positive IDs.
@MainActor
final class MeshChatItemFactory {
    private static var nextSyntheticID: Int64 = Int64.min

    static func initialize(from existingItems: [ChatItem]) {
        let maxExisting = existingItems.map { $0.meta.itemId }.max() ?? Int64.min
        if maxExisting >= nextSyntheticID {
            nextSyntheticID = maxExisting + 1
        }
    }

    static func nextID() -> Int64 {
        let id = nextSyntheticID
        nextSyntheticID += 1
        return id
    }

    static func textItem(content: String, senderNickname: String, timestamp: Date, isSent: Bool) -> ChatItem {
        let direction: CIDirection = isSent ? .meshSnd : .meshRcv(peerNickname: senderNickname)
        let msgContent: MsgContent = .text(content)
        let ciContent: CIContent = isSent ? .sndMsgContent(msgContent: msgContent) : .rcvMsgContent(msgContent: msgContent)
        let status: CIStatus = isSent ? .sndSent(sndProgress: .complete) : .rcvNew
        let id = nextID()
        let meta = CIMeta.getSample(id, timestamp, content, status)
        return ChatItem(chatDir: direction, meta: meta, content: ciContent)
    }

    static func groupTextItem(content: String, senderNickname: String, timestamp: Date, isSent: Bool) -> ChatItem {
        let direction: CIDirection = isSent ? .meshGroupSnd : .meshGroupRcv(senderNickname: senderNickname)
        let msgContent: MsgContent = .text(content)
        let ciContent: CIContent = isSent ? .sndMsgContent(msgContent: msgContent) : .rcvMsgContent(msgContent: msgContent)
        let status: CIStatus = isSent ? .sndSent(sndProgress: .complete) : .rcvNew
        let id = nextID()
        let meta = CIMeta.getSample(id, timestamp, content, status)
        return ChatItem(chatDir: direction, meta: meta, content: ciContent)
    }

    static func voiceItem(data: Data, fileName: String, duration: Int, senderNickname: String, timestamp: Date, isSent: Bool) -> ChatItem {
        let direction: CIDirection = isSent ? .meshSnd : .meshRcv(peerNickname: senderNickname)
        let msgContent: MsgContent = .voice(text: "", duration: duration)
        let ciContent: CIContent = isSent ? .sndMsgContent(msgContent: msgContent) : .rcvMsgContent(msgContent: msgContent)
        let status: CIStatus = isSent ? .sndSent(sndProgress: .complete) : .rcvNew
        let id = nextID()
        let meta = CIMeta.getSample(id, timestamp, "Voice message", status)
        let fileURL = MeshMediaStore.shared.saveVoice(data, fileName: fileName)
        let ciFile = CIFile.getSample(fileId: id, fileName: fileName, fileSize: Int64(data.count), filePath: fileURL, fileStatus: .rcvComplete)
        return ChatItem(chatDir: direction, meta: meta, content: ciContent, file: ciFile)
    }

    static func imageItem(data: Data, senderNickname: String, timestamp: Date, isSent: Bool) -> ChatItem {
        let direction: CIDirection = isSent ? .meshSnd : .meshRcv(peerNickname: senderNickname)
        let fileName = "mesh_image_\(Int(timestamp.timeIntervalSince1970)).jpg"
        let fileURL = MeshMediaStore.shared.saveImage(data, fileName: fileName)
        let base64Image = data.base64EncodedString()
        let msgContent: MsgContent = .image(text: "", image: base64Image)
        let ciContent: CIContent = isSent ? .sndMsgContent(msgContent: msgContent) : .rcvMsgContent(msgContent: msgContent)
        let status: CIStatus = isSent ? .sndSent(sndProgress: .complete) : .rcvNew
        let id = nextID()
        let meta = CIMeta.getSample(id, timestamp, "Image", status)
        let ciFile = CIFile.getSample(fileId: id, fileName: fileName, fileSize: Int64(data.count), filePath: fileURL, fileStatus: .rcvComplete)
        return ChatItem(chatDir: direction, meta: meta, content: ciContent, file: ciFile)
    }

    static func fileItem(data: Data, fileName: String, senderNickname: String, timestamp: Date, isSent: Bool) -> ChatItem {
        let direction: CIDirection = isSent ? .meshSnd : .meshRcv(peerNickname: senderNickname)
        let msgContent: MsgContent = .file(fileName)
        let ciContent: CIContent = isSent ? .sndMsgContent(msgContent: msgContent) : .rcvMsgContent(msgContent: msgContent)
        let status: CIStatus = isSent ? .sndSent(sndProgress: .complete) : .rcvNew
        let id = nextID()
        let meta = CIMeta.getSample(id, timestamp, fileName, status)
        let fileURL = MeshMediaStore.shared.saveFile(data, fileName: fileName)
        let ciFile = CIFile.getSample(fileId: id, fileName: fileName, fileSize: Int64(data.count), filePath: fileURL, fileStatus: .rcvComplete)
        return ChatItem(chatDir: direction, meta: meta, content: ciContent, file: ciFile)
    }

    static func systemItem(content: String, timestamp: Date = .now) -> ChatItem {
        let direction: CIDirection = .meshRcv(peerNickname: "system")
        let msgContent: MsgContent = .text(content)
        let ciContent: CIContent = .rcvMsgContent(msgContent: msgContent)
        let id = nextID()
        let meta = CIMeta.getSample(id, timestamp, content, .rcvRead)
        return ChatItem(chatDir: direction, meta: meta, content: ciContent)
    }
}
