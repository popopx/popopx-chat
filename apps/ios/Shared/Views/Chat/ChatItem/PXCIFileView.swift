//
//  CIFileView.swift
//  POPOPX
//
//  Created by JRoberts on 28/04/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxFileFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FILE_FEATURE_ENABLED")

// MARK: - POPOPX layout constants
private let pxFileIndicatorTopPadding: CGFloat = 4
private let pxFileIndicatorBottomPadding: CGFloat = 4
private let pxFileHStackTopPadding: CGFloat = 5
private let pxFileHStackBottomPadding: CGFloat = 5
private let pxFileHStackLeadingPadding: CGFloat = 12
private let pxFileHStackTrailingPadding: CGFloat = 10

// Spec: spec/client/chat-view.md#CIFileView
struct CIFileView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.showTimestamp) var showTimestamp: Bool
    @AppStorage(DEFAULT_SHOW_SENT_VIA_RPOXY) private var showSentViaProxy = false
    @AppStorage(DEFAULT_PRIVACY_SHOW_SIGNATURE) private var showSignature = true
    @AppStorage(DEFAULT_PRIVACY_SHOW_FILE_ENCRYPTION) private var showFileEncryption = true
    @ObservedObject var chat: Chat
    let file: CIFile?
    let meta: CIMeta
    var smallViewSize: CGFloat?

    var body: some View {
        POPOPXMediaView {
        if smallViewSize != nil {
            fileIndicator()
            .simultaneousGesture(TapGesture().onEnded { fileAction(file) })
        } else {
            // reserve exact space for the overlaid meta (timestamp + all icons), rendered transparently - matches MsgContentView
            let encrypted: Bool? = if let fileSource = file?.fileSource { fileSource.cryptoArgs != nil } else { nil }
            let metaReserve = Text(verbatim: "   ") + pxBuildMetaText(meta, chatTTL: chat.chatInfo.timedMessagesTTL, encrypted: encrypted, colorMode: .transparent, showViaProxy: showSentViaProxy, showTimesamp: showTimestamp, signedFileVerified: file?.loaded, showSignature: showSignature, showFileEncryption: showFileEncryption)
            HStack(alignment: .bottom, spacing: 6) {
                fileIndicator()
                    .padding(.top, pxFileIndicatorTopPadding)
                    .padding(.bottom, pxFileIndicatorBottomPadding)
                if let file = file {
                    let prettyFileSize = ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .binary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.fileName)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(theme.colors.onBackground)
                        (Text(prettyFileSize) + metaReserve)
                            .font(.caption)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(theme.colors.secondary)
                    }
                } else {
                    metaReserve.font(.caption)
                }
            }
            .padding(.top, pxFileHStackTopPadding)
            .padding(.bottom, pxFileHStackBottomPadding)
            .padding(.leading, pxFileHStackLeadingPadding)
            .padding(.trailing, pxFileHStackTrailingPadding)
            .simultaneousGesture(TapGesture().onEnded { fileAction(file) })
            .disabled(!itemInteractive)
        }
        }
        .popopxBranded()
    }

    // POPOPX: determines whether the file indicator responds to user interaction
    @inline(__always)
    private var itemInteractive: Bool {
        if let file = file {
            switch (file.fileStatus) {
            case .sndStored: return file.fileProtocol == .local
            case .sndTransfer: return false
            case .sndComplete: return true
            case .sndCancelled: return false
            case .sndError: return true
            case .sndWarning: return true
            case .rcvInvitation: return true
            case .rcvAccepted: return true
            case .rcvTransfer: return false
            case .rcvAborted: return true
            case .rcvComplete: return true
            case .rcvCancelled: return false
            case .rcvError: return true
            case .rcvWarning: return true
            case .invalid: return false
            }
        }
        return false
    }

    // POPOPX: file download/save action with protocol-aware status handling
    private func fileAction(_ file: CIFile?) {
        logger.debug("PX: [fileAction] called")
        if let file = file {
        switch (file.fileStatus) {
        case .rcvInvitation, .rcvAborted:
            if let prohibited = file.fileProhibited {
                showProhibitedFileAlert(file, prohibited)
            } else {
                m.openWhenReceived(file) { fileAction($0) }
                Task {
                    logger.debug("CIFileView fileAction - in .rcvInvitation, .rcvAborted, in Task")
                    if let user = m.currentUser {
                        await receiveFile(user: user, fileId: file.fileId)
                    }
                }
            }
        case .rcvAccepted:
            switch file.fileProtocol {
            case .xftp:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("waiting_for_file_title", comment: "Waiting for file alert title")),
                    message: LocalizedStringKey(NSLocalizedString("waiting_for_file_xftp_message", comment: "Waiting for file xftp message"))
                )
            case .smp:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("waiting_for_file_title", comment: "Waiting for file alert title")),
                    message: LocalizedStringKey(NSLocalizedString("waiting_for_file_smp_message", comment: "Waiting for file smp message"))
                )
            case .local: ()
            }
        case .rcvComplete:
            logger.debug("CIFileView fileAction - in .rcvComplete")
            if let fileSource = getLoadedFileSource(file) {
                openFile(file, fileSource)
            }
        case let .rcvError(rcvFileError):
            logger.debug("CIFileView fileAction - in .rcvError")
            showFileErrorAlert(rcvFileError, file)
        case let .rcvWarning(rcvFileError):
            logger.debug("CIFileView fileAction - in .rcvWarning")
            showFileErrorAlert(rcvFileError, temporary: true)
        case .sndStored:
            logger.debug("CIFileView fileAction - in .sndStored")
            if file.fileProtocol == .local, let fileSource = getLoadedFileSource(file) {
                openFile(file, fileSource)
            }
        case .sndComplete:
            logger.debug("CIFileView fileAction - in .sndComplete")
            if let fileSource = getLoadedFileSource(file) {
                openFile(file, fileSource)
            }
        case let .sndError(sndFileError):
            logger.debug("CIFileView fileAction - in .sndError")
            showFileErrorAlert(sndFileError)
        case let .sndWarning(sndFileError):
            logger.debug("CIFileView fileAction - in .sndWarning")
            showFileErrorAlert(sndFileError, temporary: true)
        default: break
        }
        }
    }

    private func openFile(_ file: CIFile, _ fileSource: CryptoFile) {
        if isMarkdownFile(file) {
            showMarkdownFile(file)
        } else {
            saveCryptoFile(fileSource)
        }
    }

    @ViewBuilder private func fileIndicator() -> some View {
        if let file = file {
            switch file.fileStatus {
            case .sndStored:
                switch file.fileProtocol {
                case .xftp: progressView()
                case .smp: fileIcon("doc.fill")
                case .local: fileIcon("doc.fill")
                }
            case let .sndTransfer(sndProgress, sndTotal):
                switch file.fileProtocol {
                case .xftp: progressCircle(sndProgress, sndTotal)
                case .smp: progressView()
                case .local: EmptyView()
                }
            case .sndComplete: fileIcon("doc.fill", innerIcon: "checkmark", innerIconSize: 10)
            case .sndCancelled: fileIcon("doc.fill", innerIcon: "xmark", innerIconSize: 10)
            case .sndError: fileIcon("doc.fill", innerIcon: "xmark", innerIconSize: 10)
            case .sndWarning: fileIcon("doc.fill", innerIcon: "exclamationmark.triangle.fill", innerIconSize: 10)
            case .rcvInvitation:
                if !fileSizeValid(file) {
                    fileIcon("doc.fill", color: QuantumColors.warning, innerIcon: "exclamationmark", innerIconSize: 12)
                } else if file.expired {
                    fileIcon("doc.fill", innerIcon: "xmark", innerIconSize: 10)
                } else {
                    fileIcon("arrow.down.doc.fill", color: theme.colors.primary)
                }
            case .rcvAccepted: fileIcon("doc.fill", innerIcon: "ellipsis", innerIconSize: 12)
            case let .rcvTransfer(rcvProgress, rcvTotal):
                if file.fileProtocol == .xftp && rcvProgress < rcvTotal {
                    progressCircle(rcvProgress, rcvTotal)
                } else {
                    progressView()
                }
            case .rcvAborted:
                fileIcon("doc.fill", color: theme.colors.primary, innerIcon: "exclamationmark.arrow.circlepath", innerIconSize: 12)
            case .rcvComplete: fileIcon("doc.fill")
            case .rcvCancelled: fileIcon("doc.fill", innerIcon: "xmark", innerIconSize: 10)
            case .rcvError: fileIcon("doc.fill", innerIcon: "xmark", innerIconSize: 10)
            case .rcvWarning: fileIcon("doc.fill", innerIcon: "exclamationmark.triangle.fill", innerIconSize: 10)
            case .invalid: fileIcon("doc.fill", innerIcon: "questionmark", innerIconSize: 10)
            }
        } else {
            fileIcon("doc.fill")
        }
    }

    private func fileIcon(_ icon: String, color: Color? = nil, innerIcon: String? = nil, innerIconSize: CGFloat? = nil) -> some View {
        let resolvedColor = color ?? theme.colors.secondary
        let size = smallViewSize ?? 30
        return ZStack(alignment: .center) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(resolvedColor)
            if let innerIcon = innerIcon,
               let innerIconSize = innerIconSize, (smallViewSize == nil || file?.showStatusIconInSmallView == true) {
                Image(systemName: innerIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 16)
                    .frame(width: innerIconSize, height: innerIconSize)
                    .foregroundColor(.white)
                    .padding(.top, size / 2.5)
            }
        }
    }

    private func progressView() -> some View {
        ProgressView().frame(width: 30, height: 30)
    }

    // MARK: - POPOPX progressCircle with extracted style
    private func progressCircle(_ progress: Int64, _ total: Int64) -> some View {
        let pxStrokeStyle = StrokeStyle(lineWidth: 3)
        let pxFraction = Double(progress) / Double(total)
        return Circle()
            .trim(from: 0, to: pxFraction)
            .stroke(
                theme.colors.secondary,
                style: pxStrokeStyle
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 30, height: 30)
    }
}

// the core decides whether a received file is above the size the sender's badge allows
func fileSizeValid(_ file: CIFile?) -> Bool {
    if let file = file {
        return file.fileProhibited == nil
    }
    return false
}

func showProhibitedFileAlert(_ file: CIFile, _ prohibited: FileProhibited) {
    let badgeIssue = switch prohibited.badgeStatus {
    case .none, .some(.active): ""
    case .some(.expired), .some(.expiredOld): NSLocalizedString("Contact's badge expired.", comment: "file alert")
    case .some(.failed): NSLocalizedString("Contact's badge verification failed.", comment: "file alert")
    case .some(.unknownKey): NSLocalizedString("No key to verify contact's badge.", comment: "file alert")
    }
    showAlert(
        NSLocalizedString("Large file!", comment: "file alert title"),
        message: largeFileMessage(file.fileSize, badgeIssue: badgeIssue)
    )
}

func saveCryptoFile(_ fileSource: CryptoFile) {
    if let cfArgs = fileSource.cryptoArgs {
        let url = getAppFilePath(fileSource.filePath)
        let tempUrl = getTempFilesDirectory().appendingPathComponent(fileSource.filePath)
        Task {
            do {
                try decryptCryptoFile(fromPath: url.path, cryptoArgs: cfArgs, toPath: tempUrl.path)
                await MainActor.run {
                    showShareSheet(items: [tempUrl]) {
                        removeFile(tempUrl)
                    }
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error decrypting file", comment: "file decryption error")), message: LocalizedStringKey(String(format: NSLocalizedString("Error: %@", comment: "error with description"), error.localizedDescription)))
                }
            }
        }
    } else {
        let url = getAppFilePath(fileSource.filePath)
        showShareSheet(items: [url])
    }
}

func showFileErrorAlert(_ err: FileError, _ file: CIFile? = nil, temporary: Bool = false) {
    if let file, file.expired, let fileExpires = file.fileExpires, err == .auth || err == .noFile {
        showAlert(
            NSLocalizedString("File expired", comment: "file error alert title"),
            message: String.localizedStringWithFormat(NSLocalizedString("File was available until %@.", comment: "file error text"), localTimestamp(fileExpires))
        )
        return
    }
    let title: String = if temporary {
        NSLocalizedString("Temporary file error", comment: "file error alert title")
    } else {
        NSLocalizedString("File error", comment: "file error alert title")
    }
    if err.moreInfoButton != nil {
        showAlert(title, message: err.errorInfo) {
            [
                okAlertAction,
                UIAlertAction(title: NSLocalizedString("How it works", comment: "alert button"), style: .default, handler: { _ in
                    UIApplication.shared.open(contentModerationPostLink)
                })
            ]
        }
    } else {
        showAlert(title, message: err.errorInfo)
    }
}

struct CIFileView_Previews: PreviewProvider {
    static var previews: some View {
        let im = ItemsModel.shared
        let sentFile: ChatItem = ChatItem(
            chatDir: .directSnd,
            meta: CIMeta.getSample(1, .now, "", .sndSent(sndProgress: .complete), itemEdited: true),
            content: .sndMsgContent(msgContent: .file("")),
            quotedItem: nil,
            file: CIFile.getSample(fileStatus: .sndComplete)
        )
        let fileChatItemWtFile = ChatItem(
            chatDir: .directRcv,
            meta: CIMeta.getSample(1, .now, "", .rcvRead),
            content: .rcvMsgContent(msgContent: .file("")),
            quotedItem: nil,
            file: nil
        )
        Group {
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: sentFile, scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(fileName: "some_long_file_name_here", fileStatus: .rcvInvitation), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(fileStatus: .rcvAccepted), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(fileStatus: .rcvTransfer(rcvProgress: 7, rcvTotal: 10)), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(fileStatus: .rcvCancelled), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(fileSize: 1_000_000_000, fileStatus: .rcvInvitation), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(text: "Hello there", fileStatus: .rcvInvitation), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: ChatItem.getFileMsgContentSample(text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.", fileStatus: .rcvInvitation), scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
            PXChatItem(chat: Chat.sampleData, im: im, chatItem: fileChatItemWtFile, scrollToItem: { _ in }, scrollToItemId: Binding.constant(nil))
        }
        .environment(\.revealed, false)
        .previewLayout(.fixed(width: 360, height: 360))
    }
}

// MARK: - POPOPX
extension CIFileView {
    var pxComponentTag: String { "px-file-item" }
}
