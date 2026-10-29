//
//  ShareModel.swift
//  POPOPX SE
//
//  Created by Levitating Pineapple on 09/07/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import UniformTypeIdentifiers
import AVFoundation
import SwiftUI
import POPOPXSwitch

/// Maximum size of hex encoded media previews
private let MAX_DATA_SIZE: Int64 = 14000

/// Maximum dimension (width or height) of an image, before passed for processing
private let MAX_DOWNSAMPLE_SIZE: Int64 = 2000

@MainActor
class ShareModel: ObservableObject {
    @Published var sharedContent: SharedContent?
    @Published var chats: [SEChatData] = []
    @Published var profileImages: [ChatInfo.ID: UIImage] = [:]
    @Published var search = ""
    @Published var comment = ""
    @Published var selected: SEChatData?
    @Published var meshPeers: [MeshPeerShareData] = []
    @Published var selectedMeshPeer: MeshPeerShareData?
    @Published var isLoaded = false
    @Published var bottomBar: BottomBar = .loadingSpinner
    @Published var errorAlert: ErrorAlert?
    @Published var hasPopopxLink = false
    @Published var alertRequiresPassword = false
    var networkTimeout = CFAbsoluteTimeGetCurrent()

    enum BottomBar {
        case sendButton
        case loadingSpinner
        case loadingBar(progress: Double)

        var isLoading: Bool {
            switch self {
            case .sendButton: false
            case .loadingSpinner: true
            case .loadingBar: true
            }
        }
    }

    var completion: () -> Void = { }
    
    private var itemProvider: NSItemProvider?

    var isSendDisabled: Bool {
        sharedContent == nil || (selected == nil && selectedMeshPeer == nil) || (selected != nil && isProhibited(selected))
    }
    
    var isLinkPreview: Bool {
        switch sharedContent {
        case .url: true
        default: false
        }
    }

    func isProhibited(_ chat: SEChatData?) -> Bool {
        if let chat, let sharedContent {
            sharedContent.prohibited(in: chat, hasPopopxLink: hasPopopxLink)
        } else { false }
    }

    var filteredChats: [SEChatData] {
        search.isEmpty
        ? filterChatsToForwardTo(chats: chats)
        : filterChatsToForwardTo(chats: chats)
            .filter { foundChat($0, search.localizedLowercase) }
    }

    func setup(context: NSExtensionContext) {
        if appLocalAuthEnabledGroupDefault.get() && !allowShareExtensionGroupDefault.get() {
            errorAlert = ErrorAlert(title: LocalizedStringKey(NSLocalizedString("se_app_locked", comment: "share extension app locked alert title")), message: LocalizedStringKey(NSLocalizedString("se_app_locked_msg", comment: "share extension app locked alert message")))
            return
        }
        let allItems = context.inputItems.compactMap { $0 as? NSExtensionItem }
        let totalAttachments = allItems.reduce(0) { $0 + ($1.attachments?.count ?? 0) }
        if totalAttachments > 1 {
            errorAlert = ErrorAlert(title: LocalizedStringKey(NSLocalizedString("se_multiple_items_title", comment: "share extension multiple items alert title")), message: LocalizedStringKey(NSLocalizedString("se_multiple_items_msg", comment: "share extension multiple items alert message")))
            return
        }
        if let item = context.inputItems.first as? NSExtensionItem,
           let itemProvider = item.attachments?.first {
            self.itemProvider = itemProvider
            self.completion = {
                ShareModel.CompletionHandler.isEventLoopEnabled = false
                context.completeRequest(returningItems: [item]) {
                    Task { @MainActor in
                        self.cleanupTempFiles()
                    }
                    apiSuspendChat(expired: $0)
                }
            }
            setup()
        }
    }

    func setup(with dbKey: String? = nil) {
        // Init Chat
        Task {
            if let e = initChat(with: dbKey) {
                await MainActor.run { errorAlert = e }
            } else {
                switch activeUser() {
                case let .failure(error):
                    await MainActor.run { errorAlert = error }
                case let .success(user):
                    // Load Chats
                    Task {
                        switch fetchChats(user) {
                        case let .success(chats):
                            // Decode base64 images on background thread
                            let profileImages = chats.reduce(into: Dictionary<ChatInfo.ID, UIImage>()) { dict, chatData in
                                if let profileImage = chatData.chatInfo.image,
                                   let uiImage = imageFromBase64(profileImage) {
                                    dict[chatData.id] = uiImage
                                }
                            }
                            let meshPeers = MeshShareStore.loadPeers()
                            await MainActor.run {
                                self.chats = chats
                                self.profileImages = profileImages
                                self.meshPeers = meshPeers
                                withAnimation { isLoaded = true }
                            }
                        case let .failure(error):
                            await MainActor.run { errorAlert = error }
                        }
                    }
                    // Process Attachment
                    Task {
                        guard let itemProvider = self.itemProvider else {
                            await MainActor.run { self.errorAlert = ErrorAlert(LocalizedStringKey(NSLocalizedString("se_no_content", comment: "share extension no content error"))) }
                            return
                        }
                        switch await getSharedContent(itemProvider, user.profile) {
                        case let .success(chatItemContent):
                            await MainActor.run {
                                self.sharedContent = chatItemContent
                                self.bottomBar = .sendButton
                                if case let .text(string) = chatItemContent { comment = string }
                            }
                        case let .failure(errorAlert):
                            await MainActor.run { self.errorAlert = errorAlert }
                        }
                    }
                }
            }
        }
    }

    func send() {
        if let meshPeer = selectedMeshPeer, selected == nil {
            sendToMeshPeer(meshPeer)
            return
        }
        if let sharedContent, let selected {
            Task {
                await MainActor.run { self.bottomBar = .loadingSpinner }
                do {
                    SEChatState.shared.set(.sendingMessage)
                    await waitForOtherProcessesToSuspend()
                    let chatItems = try apiSendMessages(
                        chatInfo: selected.chatInfo,
                        composedMessages: [ComposedMessage(fileSource: sharedContent.cryptoFile, msgContent: sharedContent.msgContent(comment: self.comment))]
                    )
                    if selected.chatInfo.chatType == .local {
                        completion()
                    } else {
                        // TODO batch send: share multiple items
                        if let ci = chatItems.first {
                            await MainActor.run { self.bottomBar = .loadingBar(progress: 0) }
                            if let e = await handleEvents(
                                isGroupChat: ci.chatInfo.chatType == .group,
                                isWithoutFile: sharedContent.cryptoFile == nil,
                                chatItemId: ci.chatItem.id
                            ) {
                                await MainActor.run { errorAlert = e }
                            } else {
                                completion()
                            }
                        }
                    }
                } catch {
                    SEChatState.shared.set(.inactive)
                    if let e = error as? ErrorAlert {
                        await MainActor.run { errorAlert = e }
                    }
                }
            }
        }
    }

    private func sendToMeshPeer(_ peer: MeshPeerShareData) {
        guard let sharedContent else { return }
        let payload: MeshSharePayload
        switch sharedContent {
        case let .image(_, cryptoFile):
            payload = .image(peerIDHex: peer.peerIDHex, filePath: cryptoFile.filePath, caption: comment)
        case let .movie(_, _, cryptoFile):
            payload = .file(peerIDHex: peer.peerIDHex, filePath: cryptoFile.filePath, fileName: "video.mp4", caption: comment)
        case let .data(cryptoFile):
            payload = .file(peerIDHex: peer.peerIDHex, filePath: cryptoFile.filePath, fileName: cryptoFile.filePath, caption: comment)
        case .url:
            payload = .text(peerIDHex: peer.peerIDHex, text: comment)
        case let .text(string):
            payload = .text(peerIDHex: peer.peerIDHex, text: string.isEmpty ? comment : string)
        }
        MeshShareStore.writePayload(payload)
        completion()
    }

    private func initChat(with dbKey: String? = nil) -> ErrorAlert? {
        do {
            if hasChatCtrl() && dbKey == nil {
                try apiActivateChat()
            } else {
                resetChatCtrl() // Clears retained migration result
                registerGroupDefaults()
                haskell_init_se()
                let (_, result) = chatMigrateInit(dbKey, confirmMigrations: defaultMigrationConfirmation(), backgroundMode: false)
                if let e = migrationError(result) {
                    logger.error("ShareModel: database migration failed: \(String(describing: result))")
                    return e
                }
                try apiSetAppFilePaths(
                    filesFolder: getAppFilesDirectory().path,
                    tempFolder: getTempFilesDirectory().path,
                    assetsFolder: getWallpaperDirectory().deletingLastPathComponent().path
                )
                let isRunning = try apiStartChat()
                logger.log(level: .debug, "chat started, running: \(isRunning)")
            }
            try apiSetNetworkConfig(getNetCfg())
            try apiSetEncryptLocalFiles(privacyEncryptLocalFilesGroupDefault.get())
        } catch {
            logger.error("ShareModel: database initialization failed: \(error)")
            chatCloseStore()
            resetChatCtrl()
            return ErrorAlert(error)
        }
        return nil
    }

    private func migrationError(_ r: DBMigrationResult) -> ErrorAlert? {
        let useKeychain = storeDBPassphraseGroupDefault.get()
        let storedDBKey = kcDatabasePassword.get()
        if case .errorNotADatabase = r {
            Task { await MainActor.run { self.alertRequiresPassword = true } }
        }
        return switch r {
        case .errorNotADatabase:
            if useKeychain && storedDBKey != nil && storedDBKey != "" {
                ErrorAlert(
                    title: LocalizedStringKey(NSLocalizedString("se_wrong_passphrase", comment: "share extension wrong database passphrase error title")),
                    message: LocalizedStringKey(NSLocalizedString("se_wrong_passphrase_msg", comment: "share extension wrong database passphrase error message"))
                )
            } else {
                ErrorAlert(
                    title: LocalizedStringKey(NSLocalizedString("se_db_encrypted", comment: "share extension database encrypted error title")),
                    message: LocalizedStringKey(NSLocalizedString("se_db_encrypted_msg", comment: "share extension database passphrase required message"))
                )
            }
        case let .errorMigration(_, migrationError):
            switch migrationError {
            case .upgrade:
                ErrorAlert(
                    title: LocalizedStringKey(NSLocalizedString("se_db_upgrade", comment: "database upgrade required title")),
                    message: LocalizedStringKey(NSLocalizedString("se_db_upgrade_msg", comment: "database upgrade required message"))
                )
            case .downgrade:
                ErrorAlert(
                    title: LocalizedStringKey(NSLocalizedString("se_db_downgrade", comment: "database downgrade required title")),
                    message: LocalizedStringKey(NSLocalizedString("se_db_downgrade_msg", comment: "database downgrade required message"))
                )
            case let .migrationError(mtrError):
                ErrorAlert(
                    title: LocalizedStringKey(NSLocalizedString("se_db_incompatible", comment: "incompatible database version title")),
                    message: mtrErrorDescription(mtrError)
                )
            }
        case let .errorSQL(_, migrationSQLError):
            ErrorAlert(
                title: LocalizedStringKey(NSLocalizedString("se_db_error", comment: "database error title")),
                message: LocalizedStringKey(String(format: NSLocalizedString("se_db_error_msg", comment: "database error message"), migrationSQLError))
            )
        case .errorKeychain:
            ErrorAlert(
                title: LocalizedStringKey(NSLocalizedString("se_keychain_error", comment: "keychain error title")),
                message: LocalizedStringKey(NSLocalizedString("se_keychain_error_msg", comment: "keychain error message"))
            )
        case .errorKeyGeneration:
            ErrorAlert(
                title: LocalizedStringKey(NSLocalizedString("se_db_error", comment: "database error title")),
                message: LocalizedStringKey(NSLocalizedString("Cannot generate random database passphrase", comment: "key generation error message"))
            )
        case .invalidConfirmation:
            ErrorAlert(LocalizedStringKey(NSLocalizedString("se_invalid_migration_confirm", comment: "invalid migration confirmation error")))
        case let .unknown(json):
            ErrorAlert(
                title: LocalizedStringKey(NSLocalizedString("se_db_error", comment: "database error title")),
                message: LocalizedStringKey(String(format: NSLocalizedString("se_db_unknown_error_msg", comment: "unknown database error message"), json))
            )
        case .errorAgent:
            ErrorAlert(
                title: LocalizedStringKey(NSLocalizedString("se_db_error", comment: "database error title")),
                message: LocalizedStringKey(NSLocalizedString("Agent error during database migration", comment: "agent error message"))
            )
        case .ok: nil
        }
    }
    
    private func activeUser() -> Result<User, ErrorAlert> {
        do {
            guard let user = try apiGetActiveUser() else {
                return .failure(
                    ErrorAlert(
                        title: LocalizedStringKey(NSLocalizedString("se_no_profile", comment: "no active profile error title")),
                        message: LocalizedStringKey(NSLocalizedString("se_no_profile_msg", comment: "no active profile error message"))
                    )
                )
            }
            return .success(user)
        } catch {
            return .failure(ErrorAlert(error))
        }
    }

    private func fetchChats(_ user: User) -> Result<Array<SEChatData>, ErrorAlert> {
        do {
            return .success(try apiGetChats(userId: user.id))
        } catch {
            return .failure(ErrorAlert(error))
        }
    }

    private func cleanupTempFiles() {
        let tempDir = getTempFilesDirectory()
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for fileURL in contents {
                do {
                    try fm.removeItem(at: fileURL)
                } catch {
                    logger.error("ShareModel: failed to remove temp file \(fileURL.lastPathComponent): \(error)")
                }
            }
        } catch {
            logger.error("ShareModel: failed to enumerate temp directory: \(error)")
        }
    }

    actor CompletionHandler {
        static var isEventLoopEnabled = false
        private var fileCompleted = false
        private var messageCompleted = false

        func completeFile() { fileCompleted = true }

        func completeMessage() { messageCompleted = true }

        var isRunning: Bool {
            Self.isEventLoopEnabled && !(fileCompleted && messageCompleted)
        }
    }

    /// Polls and processes chat events
    /// Returns when message sending has completed optionally returning and error.
    private func handleEvents(isGroupChat: Bool, isWithoutFile: Bool, chatItemId: ChatItem.ID) async -> ErrorAlert? {
        func isMessage(for item: AChatItem?) -> Bool {
            item.map { $0.chatItem.id == chatItemId } ?? false
        }

        CompletionHandler.isEventLoopEnabled = true
        let ch = CompletionHandler()
        if isWithoutFile { await ch.completeFile() }
        networkTimeout = CFAbsoluteTimeGetCurrent()
        while await ch.isRunning {
            if CFAbsoluteTimeGetCurrent() - networkTimeout > 30 {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.errorAlert = ErrorAlert(title: LocalizedStringKey(NSLocalizedString("se_slow_network", comment: "slow network timeout alert title")), message: LocalizedStringKey(NSLocalizedString("se_slow_network_msg", comment: "slow network timeout alert message")))
                }
            }
            let r: APIResult<SEChatEvent>? = recvPopopxMsg(messageTimeout: 1_000_000)
            switch r {
            case let .result(.sndFileProgressXFTP(_, ci, _, sentSize, totalSize), _):
                guard isMessage(for: ci) else { continue }
                networkTimeout = CFAbsoluteTimeGetCurrent()
                await MainActor.run {
                    withAnimation {
                        let progress = Double(sentSize) / Double(totalSize)
                        bottomBar = .loadingBar(progress: progress)
                    }
                }
            case let .result(.sndFileCompleteXFTP(_, ci, _), _):
                guard isMessage(for: ci) else { continue }
                if isGroupChat {
                    await MainActor.run { bottomBar = .loadingSpinner }
                }
                await ch.completeFile()
                if await !ch.isRunning { break }
            case let .result(.chatItemsStatusesUpdated(_, chatItems), _):
                guard let ci = chatItems.last else { continue }
                guard isMessage(for: ci) else { continue }
                if let (title, message) = ci.chatItem.meta.itemStatus.statusInfo {
                    // `title` and `message` already localized and interpolated
                    return ErrorAlert(
                        title: "\(title)",
                        message: "\(message)"
                    )
                } else if case let .sndSent(sndProgress) = ci.chatItem.meta.itemStatus {
                    switch sndProgress {
                    case .complete:
                        await ch.completeMessage()
                    case .partial:
                        if isGroupChat {
                            Task { [weak ch] in
                                do {
                                    try await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
                                    await ch?.completeMessage()
                                } catch {
                                    // Task cancelled, skip completion
                                }
                            }
                        }
                    }
                }
            case let .result(.sndFileError(_, ci, _, errorMessage), _):
                guard isMessage(for: ci) else { continue }
                if let ci { cleanupFile(ci) }
                return ErrorAlert(title: LocalizedStringKey(NSLocalizedString("se_file_error", comment: "file error alert title")), message: LocalizedStringKey(fileErrorInfo(ci) ?? errorMessage))
            case let .result(.sndFileWarning(_, ci, _, errorMessage), _):
                guard isMessage(for: ci) else { continue }
                if let ci { cleanupFile(ci) }
                return ErrorAlert(title: LocalizedStringKey(NSLocalizedString("se_file_error", comment: "file error alert title")), message: LocalizedStringKey(fileErrorInfo(ci) ?? errorMessage))
            case let .error(chatError, _):
                return ErrorAlert(chatError)
            default: continue
            }
        }
        return nil
    }
    
    private func fileErrorInfo(_ ci: AChatItem?) -> String? {
        switch ci?.chatItem.file?.fileStatus {
        case let .sndError(e): e.errorInfo
        case let .sndWarning(e): e.errorInfo
        default: nil
        }
    }
}

/// Chat Item Content extracted from `NSItemProvider` without the comment
enum SharedContent {
    case image(preview: String, cryptoFile: CryptoFile)
    case movie(preview: String, duration: Int, cryptoFile: CryptoFile)
    case url(preview: LinkPreview)
    case text(string: String)
    case data(cryptoFile: CryptoFile)

    var cryptoFile: CryptoFile? {
        switch self {
        case let .image(_, cryptoFile): cryptoFile
        case let .movie(_, _, cryptoFile): cryptoFile
        case .url: nil
        case .text: nil
        case let .data(cryptoFile): cryptoFile
        }
    }

    func msgContent(comment: String) -> MsgContent {
        switch self {
        case let .image(preview, _): .image(text: comment, image: preview)
        case let .movie(preview, duration, _): .video(text: comment, image: preview, duration: duration)
        case let .url(preview): .link(text: preview.uri + (comment == "" ? "" : "\n" + comment), preview: preview)
        case .text: .text(comment)
        case .data: .file(comment)
        }
    }

    func prohibited(in chatData: SEChatData, hasPopopxLink: Bool) -> Bool {
        chatData.prohibitedByPref(
            hasPopopxLink: hasPopopxLink,
            isMediaOrFileAttachment: cryptoFile != nil,
            isVoice: false
        )
    }
}

fileprivate func getSharedContent(_ ip: NSItemProvider, _ senderProfile: LocalProfile) async -> Result<SharedContent, ErrorAlert> {
    if let type = firstMatching(of: [.image, .movie, .fileURL, .url, .text]) {
        switch type {
            // Prepare Image message
        case .image:
            // Animated
            if ip.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
                do {
                    let url = try await inPlaceUrl(type: type)
                    let data = try Data(contentsOf: url)
                    if let image = UIImage(data: data),
                       let cryptoFile = saveFile(data, generateNewFileName("IMG", "gif"), encrypted: privacyEncryptLocalFilesGroupDefault.get()),
                       let preview = await resizeImageToStrSize(image, maxDataSize: MAX_DATA_SIZE) {
                        return .success(.image(preview: preview, cryptoFile: cryptoFile))
                    }
                } catch {
                    logger.error("getSharedContent: failed to load animated image: \(error)")
                }
                return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_error_preparing", comment: "share extension error preparing message"))))

            // Static
            } else {
                if let image = await staticImage(),
                   let cryptoFile = saveImage(image),
                   let preview = await resizeImageToStrSize(image, maxDataSize: MAX_DATA_SIZE) {
                    return .success(.image(preview: preview, cryptoFile: cryptoFile))
                } else {
                    return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_error_preparing", comment: "share extension error preparing message"))))
                }
            }

        // Prepare Movie message
        case .movie:
            do {
                let url = try await inPlaceUrl(type: type)
                let size = Int64(fileSize(url) ?? 0)
                let maxSize = getMaxFileSize(.xftp, senderProfile)
                if size > maxSize {
                    return .failure(
                        ErrorAlert(
                            title: LocalizedStringKey(NSLocalizedString("se_large_file", comment: "share extension large file error title")),
                            message: LocalizedStringKey(largeFileMessage(size, badgeIssue: expiredBadgeReason(size, senderProfile)))
                        )
                    )
                }
                if let trancodedUrl = await transcodeVideo(from: url),
                   let (image, duration) = await AVURLAsset(url: trancodedUrl).generatePreview(),
                   let preview = await resizeImageToStrSize(image, maxDataSize: MAX_DATA_SIZE),
                   let cryptoFile = moveTempFileFromURL(trancodedUrl) {
                    do { try FileManager.default.removeItem(at: trancodedUrl) }
                    catch { logger.error("getSharedContent: failed to remove temp video: \(error)") }
                    return .success(.movie(preview: preview, duration: duration, cryptoFile: cryptoFile))
                }
            } catch {
                logger.error("getSharedContent: failed to load video: \(error)")
            }
            return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_error_preparing", comment: "share extension error preparing message"))))

        // Prepare Data message
        case .fileURL:
            do {
                let url = try await inPlaceUrl(type: .data)
                let size = Int64(fileSize(url) ?? 0)
                let maxSize = getMaxFileSize(.xftp, senderProfile)
                if size > maxSize {
                    return .failure(
                        ErrorAlert(
                            title: LocalizedStringKey(NSLocalizedString("se_large_file", comment: "share extension large file error title")),
                            message: LocalizedStringKey(largeFileMessage(size, badgeIssue: expiredBadgeReason(size, senderProfile)))
                        )
                    )
                }
                if let file = saveFileFromURL(url) {
                    return .success(.data(cryptoFile: file))
                }
            } catch {
                logger.error("getSharedContent: failed to load file: \(error)")
            }
            return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_error_preparing_file", comment: "share extension error preparing file"))))

        // Prepare Link message
        case .url:
            do {
                let url = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
                    ip.loadObject(ofClass: NSURL.self) { obj, error in
                        if let error = error {
                            cont.resume(throwing: error)
                        } else if let url = obj as? URL {
                            cont.resume(returning: url)
                        } else {
                            cont.resume(throwing: NSError(domain: "ShareModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load URL"]))
                        }
                    }
                }
                let content: SharedContent
                if privacyLinkPreviewsGroupDefault.get() && !privacyLinkPreviewsShowAlertGroupDefault.get(), let linkPreview = await getLinkPreview(for: url) {
                    content = .url(preview: linkPreview)
                } else {
                    content = .text(string: url.absoluteString)
                }
                return .success(content)
            } catch {
                logger.error("getSharedContent: failed to load URL: \(error)")
            }
            return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_error_preparing", comment: "share extension error preparing message"))))

        // Prepare Text message
        case .text:
            do {
                let text = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                    ip.loadObject(ofClass: NSString.self) { obj, error in
                        if let error = error {
                            cont.resume(throwing: error)
                        } else if let text = obj as? String {
                            cont.resume(returning: text)
                        } else {
                            cont.resume(throwing: NSError(domain: "ShareModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load text"]))
                        }
                    }
                }
                return .success(.text(string: text))
            } catch {
                logger.error("getSharedContent: failed to load text: \(error)")
            }
            return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_error_preparing", comment: "share extension error preparing message"))))
        default: return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_unsupported_format", comment: "share extension unsupported format error"))))
        }
    } else {
        return .failure(ErrorAlert(LocalizedStringKey(NSLocalizedString("se_unsupported_format", comment: "share extension unsupported format error"))))
    }


    func inPlaceUrl(type: UTType) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let _ = ip.loadInPlaceFileRepresentation(forTypeIdentifier: type.identifier) { url, bool, error in
                if let url = url {
                    cont.resume(returning: url)
                } else if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(throwing: NSError(domain: "ShareModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Either `url` or `error` must be present"]))
                }
            }
        }
    }

    func firstMatching(of types: Array<UTType>) -> UTType? {
        for type in types {
            if ip.hasItemConformingToTypeIdentifier(type.identifier) { return type }
        }
        return nil
    }

    func staticImage() async -> UIImage? {
        do {
            let url = try await inPlaceUrl(type: .image)
            if let downsampledImage = downsampleImage(at: url, to: MAX_DOWNSAMPLE_SIZE) {
                return downsampledImage
            }
        } catch {
            logger.error("getSharedContent: failed to load static image: \(error)")
        }
        /// Fallback to loading image directly from `ItemProvider`
        /// in case loading from disk is not possible. Required for sharing screenshots.
        do {
            let image = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UIImage, Error>) in
                ip.loadObject(ofClass: UIImage.self) { obj, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else if let image = obj as? UIImage {
                        cont.resume(returning: image)
                    } else {
                        cont.resume(throwing: NSError(domain: "ShareModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]))
                    }
                }
            }
            return image
        } catch {
            logger.error("getSharedContent: failed to load image fallback: \(error)")
            return nil
        }
    }
}


fileprivate func transcodeVideo(from input: URL) async -> URL? {
    let outputUrl = URL(
        fileURLWithPath: generateNewFileName(
            getTempFilesDirectory().path + "/" + "video", "mp4",
            fullPath: true
        )
    )
    if await makeVideoQualityLower(input, outputUrl: outputUrl) {
        return outputUrl
    } else {
        try? FileManager.default.removeItem(at: outputUrl)
        return nil
    }
}


