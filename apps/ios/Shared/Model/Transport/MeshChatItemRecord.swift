// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

/// Codable representation of a mesh ChatItem for persistence.
/// ChatItem itself is only Decodable, so we store the minimal data
/// needed to reconstruct it via MeshChatItemFactory.
struct MeshChatItemRecord: Codable {
    let chatId: String
    let itemId: Int64
    let itemTs: Date
    let direction: Direction
    let senderNickname: String
    let contentType: ContentType
    let textContent: String?
    let filePath: String?
    let fileName: String?
    let fileSize: Int64?
    let duration: Int?
    let imageBase64: String?
    let itemStatus: String

    enum Direction: String, Codable {
        case meshSnd
        case meshRcv
        case meshGroupSnd
        case meshGroupRcv
    }

    enum ContentType: String, Codable {
        case text
        case voice
        case image
        case file
    }

    /// Reconstruct a ChatItem from this record.
    @MainActor
    func toChatItem() -> ChatItem? {
        let timestamp = itemTs
        let isSent: Bool
        let nickname: String

        switch direction {
        case .meshSnd:
            isSent = true
            nickname = "you"
        case .meshRcv:
            isSent = false
            nickname = senderNickname
        case .meshGroupSnd:
            isSent = true
            nickname = "you"
        case .meshGroupRcv:
            isSent = false
            nickname = senderNickname
        }

        switch contentType {
        case .text:
            guard let text = textContent else { return nil }
            if direction == .meshGroupSnd || direction == .meshGroupRcv {
                return MeshChatItemFactory.groupTextItem(content: text, senderNickname: nickname, timestamp: timestamp, isSent: isSent)
            }
            return MeshChatItemFactory.textItem(content: text, senderNickname: nickname, timestamp: timestamp, isSent: isSent)

        case .voice:
            guard let filePath = filePath, let fileName = fileName, let duration = duration else { return nil }
            let data: Data
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            } catch {
                return nil
            }
            return MeshChatItemFactory.voiceItem(data: data, fileName: fileName, duration: duration, senderNickname: nickname, timestamp: timestamp, isSent: isSent)

        case .image:
            if let filePath = filePath {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                    return MeshChatItemFactory.imageItem(data: data, senderNickname: nickname, timestamp: timestamp, isSent: isSent)
                } catch {
                    // Fall through to base64 fallback
                }
            }
            if let base64 = imageBase64, let data = Data(base64Encoded: base64) {
                return MeshChatItemFactory.imageItem(data: data, senderNickname: nickname, timestamp: timestamp, isSent: isSent)
            }
            return nil

        case .file:
            guard let filePath = filePath, let fileName = fileName else { return nil }
            let data: Data
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            } catch {
                return nil
            }
            return MeshChatItemFactory.fileItem(data: data, fileName: fileName, senderNickname: nickname, timestamp: timestamp, isSent: isSent)
        }
    }

    /// Create a record from a ChatItem.
    static func from(chatId: String, item: ChatItem) -> MeshChatItemRecord? {
        let direction: Direction
        let senderNickname: String

        switch item.chatDir {
        case .meshSnd:
            direction = .meshSnd
            senderNickname = "you"
        case .meshRcv(let name):
            direction = .meshRcv
            senderNickname = name
        case .meshGroupSnd:
            direction = .meshGroupSnd
            senderNickname = "you"
        case .meshGroupRcv(let name):
            direction = .meshGroupRcv
            senderNickname = name
        default:
            return nil
        }

        let contentType: ContentType
        var textContent: String?
        var filePath: String?
        var fileName: String?
        var fileSize: Int64?
        var duration: Int?
        var imageBase64: String?

        switch item.content {
        case .sndMsgContent(let msgContent), .rcvMsgContent(let msgContent):
            switch msgContent {
            case .text(let text):
                contentType = .text
                textContent = text
            case .voice(_, let dur):
                contentType = .voice
                duration = dur
                filePath = item.file?.fileSource?.filePath
                fileName = item.file?.fileName
                fileSize = item.file?.fileSize
            case .image(let text, let base64):
                contentType = .image
                textContent = text
                imageBase64 = base64
                filePath = item.file?.fileSource?.filePath
                fileName = item.file?.fileName
                fileSize = item.file?.fileSize
            case .file(let fname):
                contentType = .file
                fileName = fname
                filePath = item.file?.fileSource?.filePath
                fileSize = item.file?.fileSize
            default:
                contentType = .text
                textContent = nil
            }
        default:
            return nil
        }

        let statusStr: String
        switch item.meta.itemStatus {
        case .sndSent: statusStr = "sndSent"
        case .rcvNew: statusStr = "rcvNew"
        case .rcvRead: statusStr = "rcvRead"
        default: statusStr = "rcvNew"
        }

        return MeshChatItemRecord(
            chatId: chatId,
            itemId: item.meta.itemId,
            itemTs: item.meta.itemTs,
            direction: direction,
            senderNickname: senderNickname,
            contentType: contentType,
            textContent: textContent,
            filePath: filePath,
            fileName: fileName,
            fileSize: fileSize,
            duration: duration,
            imageBase64: imageBase64,
            itemStatus: statusStr
        )
    }
}
