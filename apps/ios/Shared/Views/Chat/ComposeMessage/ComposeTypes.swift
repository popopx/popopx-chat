// Spec: spec/client/compose.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import SwiftyGif
import PhotosUI

let MAX_NUMBER_OF_MENTIONS = 3

// Spec: spec/client/compose.md#ComposePreview
indirect enum ComposePreview {
    case noPreview
    case linkPreview(linkPreview: LinkPreview?)
    case chatLinkPreview(chatLink: MsgChatLink, ownerSig: LinkOwnerSig?)
    case mediaPreviews(mediaPreviews: [(String, UploadContent?)])
    case voicePreview(recordingFileName: String, duration: Int)
    case filePreview(fileName: String, file: URL)
}

// Spec: spec/client/compose.md#ComposeContextItem
indirect enum ComposeContextItem: Equatable {
    case noContextItem
    case quotedItem(chatItem: ChatItem)
    case editingItem(chatItem: ChatItem)
    case forwardingItems(chatItems: [ChatItem], fromChatInfo: ChatInfo)
    case reportedItem(chatItem: ChatItem, reason: ReportReason)
}

// Spec: spec/client/compose.md#VoiceMessageRecordingState
enum VoiceMessageRecordingState {
    case noRecording
    case recording
    case finished
}

// Spec: spec/client/compose.md#LiveMessage
private class _ChatItemBox: Hashable {
    var value: ChatItem
    init(_ value: ChatItem) { self.value = value }
    static func == (lhs: _ChatItemBox, rhs: _ChatItemBox) -> Bool { lhs.value == rhs.value }
    func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

struct LiveMessage {
    private var _chatItem: _ChatItemBox
    var typedMsg: String
    var sentMsg: String?

    var chatItem: ChatItem {
        get { _chatItem.value }
        set { _chatItem.value = newValue }
    }

    init(chatItem: ChatItem, typedMsg: String, sentMsg: String? = nil) {
        self._chatItem = _ChatItemBox(chatItem)
        self.typedMsg = typedMsg
        self.sentMsg = sentMsg
    }
}

typealias MentionedMembers = [String: CIMention]

// Spec: spec/client/compose.md#ComposeState
struct ComposeState {
    var message: String
    var parsedMessage: [FormattedText]
    var liveMessage: LiveMessage? = nil
    var preview: ComposePreview
    var contextItem: ComposeContextItem
    var voiceMessageRecordingState: VoiceMessageRecordingState
    var inProgress = false
    var progressByTimeout = false
    var useLinkPreviews = true
    var mentions: MentionedMembers = [:]

    init(
        message: String = "",
        parsedMessage: [FormattedText] = [],
        liveMessage: LiveMessage? = nil,
        preview: ComposePreview = .noPreview,
        contextItem: ComposeContextItem = .noContextItem,
        voiceMessageRecordingState: VoiceMessageRecordingState = .noRecording,
        mentions: MentionedMembers = [:]
    ) {
        self.message = message
        self.parsedMessage = parsedMessage
        self.liveMessage = liveMessage
        self.preview = preview
        self.contextItem = contextItem
        self.voiceMessageRecordingState = voiceMessageRecordingState
        self.mentions = mentions
    }

    init(editingItem: ChatItem) {
        let text = if case let .chat(t, chatLink, _) = editingItem.content.msgContent {
            stripTextLink(t, chatLink.connLinkStr)
        } else {
            editingItem.content.text
        }
        self.message = text
        self.parsedMessage = editingItem.formattedText ?? FormattedText.plain(text)
        self.preview = chatItemPreview(chatItem: editingItem)
        self.contextItem = .editingItem(chatItem: editingItem)
        if let emc = editingItem.content.msgContent,
           case .voice = emc {
            self.voiceMessageRecordingState = .finished
        } else {
            self.voiceMessageRecordingState = .noRecording
        }
        self.mentions = editingItem.mentions ?? [:]
    }

    init(forwardingItems: [ChatItem], fromChatInfo: ChatInfo) {
        self.message = ""
        self.parsedMessage = []
        self.preview = .noPreview
        self.contextItem = .forwardingItems(chatItems: forwardingItems, fromChatInfo: fromChatInfo)
        self.voiceMessageRecordingState = .noRecording
    }

    func copy(
        message: String? = nil,
        parsedMessage: [FormattedText]? = nil,
        liveMessage: LiveMessage? = nil,
        preview: ComposePreview? = nil,
        contextItem: ComposeContextItem? = nil,
        voiceMessageRecordingState: VoiceMessageRecordingState? = nil,
        mentions: MentionedMembers? = nil
    ) -> ComposeState {
        ComposeState(
            message: message ?? self.message,
            parsedMessage: parsedMessage ?? self.parsedMessage,
            liveMessage: liveMessage ?? self.liveMessage,
            preview: preview ?? self.preview,
            contextItem: contextItem ?? self.contextItem,
            voiceMessageRecordingState: voiceMessageRecordingState ?? self.voiceMessageRecordingState,
            mentions: mentions ?? self.mentions
        )
    }

    func mentionMemberName(_ name: String) -> String {
        var n = 0
        var tryName = name
        while mentions[tryName] != nil {
            n += 1
            tryName = "\(name)_\(n)"
        }
        return tryName
    }

    var memberMentions: [String: Int64] {
        self.mentions.compactMapValues { $0.memberRef?.groupMemberId }
    }

    var editing: Bool {
        switch contextItem {
        case .editingItem: return true
        default: return false
        }
    }

    var quoting: Bool {
        switch contextItem {
        case .quotedItem: return true
        default: return false
        }
    }

    var forwarding: Bool {
        switch contextItem {
        case .forwardingItems: return true
        default: return false
        }
    }

    var reporting: Bool {
        switch contextItem {
        case .reportedItem: return true
        default: return false
        }
    }

    var submittingValidReport: Bool {
        switch contextItem {
        case let .reportedItem(_, reason):
            switch reason {
            case .other: return !message.isEmpty
            default: return true
            }
        default: return false
        }
    }

    var sendEnabled: Bool {
        switch preview {
        case let .mediaPreviews(media): return !media.isEmpty
        case .voicePreview: return voiceMessageRecordingState == .finished
        case .chatLinkPreview: return true
        case .filePreview: return true
        default: return !whitespaceOnly || forwarding || liveMessage != nil || submittingValidReport
        }
    }

    var endLiveDisabled: Bool {
        liveMessage != nil && message.isEmpty && noPreview && !quoting
    }

    var linkPreviewAllowed: Bool {
        switch preview {
        case .chatLinkPreview: return false
        case .mediaPreviews: return false
        case .voicePreview: return false
        case .filePreview: return false
        default: return useLinkPreviews
        }
    }

    var linkPreview: LinkPreview? {
        switch preview {
        case let .linkPreview(linkPreview): return linkPreview
        default: return nil
        }
    }

    var voiceMessageRecordingFileName: String? {
        switch preview {
        case let .voicePreview(recordingFileName: recordingFileName, _): return recordingFileName
        default: return nil
        }
    }

    var noPreview: Bool {
        switch preview {
        case .noPreview: return true
        default: return false
        }
    }

    var voicePreview: Bool {
        switch preview {
        case .voicePreview: return true
        default: return false
        }
    }

    var manyMediaPreviews: Bool {
        switch preview {
        case let .mediaPreviews(mediaPreviews): return mediaPreviews.count > 1
        default: return false
        }
    }

    var attachmentDisabled: Bool {
        if editing || forwarding || liveMessage != nil || inProgress || reporting { return true }
        switch preview {
        case .noPreview: return false
        case .linkPreview: return false
        default: return true
        }
    }

    var attachmentPreview: Bool {
        switch preview {
        case .noPreview: false
        case .linkPreview: false
        case .chatLinkPreview: false
        case let .mediaPreviews(mediaPreviews): !mediaPreviews.isEmpty
        case .voicePreview: false
        case .filePreview: true
        }
    }

    var placeholder: String? {
        switch contextItem {
        case let .reportedItem(_, reason):
            return reason.text
        default:
            return nil
        }
    }

    var empty: Bool {
        whitespaceOnly && noPreview
    }

    var whitespaceOnly: Bool {
        message.allSatisfy { $0.isWhitespace }
    }
}

// Spec: spec/client/compose.md#chatItemPreview
func chatItemPreview(chatItem: ChatItem) -> ComposePreview {
    switch chatItem.content.msgContent {
    case .text:
        return .noPreview
    case let .link(_, preview: preview):
        return .linkPreview(linkPreview: preview)
    case let .image(_, image):
        return .mediaPreviews(mediaPreviews: [(image, nil)])
    case let .video(_, image, _):
        return .mediaPreviews(mediaPreviews: [(image, nil)])
    case let .voice(_, duration):
        return .voicePreview(recordingFileName: chatItem.file?.fileName ?? "", duration: duration)
    case .file:
        let fileName = chatItem.file?.fileName ?? ""
        return .filePreview(fileName: fileName, file: getAppFilePath(fileName))
    default:
        return .noPreview
    }
}

// Spec: spec/client/compose.md#UploadContent
enum UploadContent: Equatable {
    case simpleImage(image: UIImage)
    case animatedImage(image: UIImage)
    case video(image: UIImage, url: URL, duration: Int)

    var uiImage: UIImage {
        switch self {
        case let .simpleImage(image): return image
        case let .animatedImage(image): return image
        case let .video(image, _, _): return image
        }
    }

    static func loadFromURL(url: URL) -> UploadContent? {
        do {
            let data = try Data(contentsOf: url)
            if let image = UIImage(data: data) {
                try image.setGifFromData(data, levelOfIntegrity: 1.0)
                logger.log("UploadContent: added animated image")
                return .animatedImage(image: image)
            } else { return nil }
        } catch {
            do {
                if let image = try UIImage(data: Data(contentsOf: url)) {
                    logger.log("UploadContent: added simple image")
                    return .simpleImage(image: image)
                }
            } catch {
                logger.error("ComposeView: failed to process image: \(error.localizedDescription)")
            }
        }
        return nil
    }

    static func loadVideoFromURL(url: URL) async -> UploadContent? {
        let asset = AVAsset(url: url)
        if let (image, duration) = await asset.generatePreview() {
            return .video(image: image, url: url, duration: duration)
        }
        return nil
    }
}

