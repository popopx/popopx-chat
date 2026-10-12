//
//  PXCIImageView.swift
//  POPOPX
//
//  POPOPX chat image thumbnail with full-screen cover and download handling.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration

private enum PXCIImageConfig {
    static let stackSpacing: CGFloat = 7
    static let iconSizeSmall: CGFloat = 10
    static let iconSizeAccept: CGFloat = 14
    static let iconPaddingDefault: CGFloat = 13
    static let iconPaddingAccept: CGFloat = 11
    static let progressFrameSize: CGFloat = 22
    static let progressTint: Color = .white
    static let progressPadding: CGFloat = 9
    static let darkThemeOverlayOpacity: Double = 0.82
    static let lightThemeOverlayOpacity: Double = 1.0
    static let portraitWidthRatio: CGFloat = 0.75
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXCIImageViewModel {
    let chatItem: ChatItem
    let smallView: Bool
    let blurred: Bool

    var loadedImage: UIImage? {
        getLoadedImage(chatItem.file, smallView: smallView)
    }

    var hasFile: Bool { chatItem.file != nil }

    var fileStatus: CIFileStatus? { chatItem.file?.fileStatus }

    var shouldShowDownloadOverlay: Bool {
        guard let status = fileStatus else { return false }
        switch status {
        case .rcvInvitation, .rcvAborted: return true
        default: return false
        }
    }

    var showStatusOverlay: Bool {
        !blurred || !shouldShowDownloadOverlay
    }

    func imageWidth(for imageSize: CGSize, maxWidth: CGFloat) -> CGFloat {
        imageSize.width <= imageSize.height ? maxWidth * PXCIImageConfig.portraitWidthRatio : maxWidth
    }

    func canAcceptFile(from senderProfile: LocalProfile?) -> Bool {
        guard let file = chatItem.file else { return false }
        return fileSizeValid(file)
    }
}

// Spec: spec/client/chat-view.md#CIImageView
struct CIImageView: View {
    @EnvironmentObject var m: ChatModel
    let chatItem: ChatItem
    var scrollToItem: ((ChatItem.ID) -> Void)? = nil
    var preview: UIImage?
    let maxWidth: CGFloat
    var imgWidth: CGFloat?
    var smallView: Bool = false
    @Binding var showFullScreenImage: Bool
    @State private var blurred: Bool = UserDefaults.standard.integer(forKey: DEFAULT_PRIVACY_MEDIA_BLUR_RADIUS) > 0

    private var pxVM: PXCIImageViewModel {
        PXCIImageViewModel(chatItem: chatItem, smallView: smallView, blurred: blurred)
    }

    var body: some View {
        VStack(alignment: .center, spacing: PXCIImageConfig.stackSpacing) {
            if let uiImage = pxVM.loadedImage {
                pxLoadedImageContent(uiImage)
            } else if let preview {
                pxPreviewImageContent(preview)
            }
        }
        .onDisappear {
            showFullScreenImage = false
        }
        .popopxBranded()
    }

    // MARK: - POPOPX extracted view builders

    @ViewBuilder
    private func pxPreviewImageContent(_ img: UIImage) -> some View {
        Group {
            if smallView {
                smallViewImageView(img)
            } else {
                imageView(img).modifier(PrivacyBlur(blurred: $blurred))
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            pxHandlePreviewTap()
        })
        .accessibilityLabel(Text(NSLocalizedString("a11y_chat_image_preview", comment: "")))
    }

    private func pxHandlePreviewTap() {
        guard let file = chatItem.file else { return }
        switch file.fileStatus {
        case .rcvInvitation, .rcvAborted:
            if let prohibited = file.fileProhibited {
                showProhibitedFileAlert(file, prohibited)
            } else {
                Task {
                    if let user = m.currentUser {
                        await receiveFile(user: user, fileId: file.fileId)
                    }
                }
            }
        case .rcvAccepted:
            switch file.fileProtocol {
            case .xftp:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("waiting_for_image_title", comment: "Waiting for image alert title")),
                    message: LocalizedStringKey(NSLocalizedString("waiting_for_image_xftp_message", comment: "Waiting for image xftp message"))
                )
            case .smp:
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("waiting_for_image_title", comment: "Waiting for image alert title")),
                    message: LocalizedStringKey(NSLocalizedString("waiting_for_image_smp_message", comment: "Waiting for image smp message"))
                )
            case .local: ()
            }
        case .rcvTransfer: ()
        case .rcvComplete: ()
        case .rcvCancelled: logger.debug("CIImageView: transfer cancelled")
        case let .rcvError(rcvFileError):
            showFileErrorAlert(rcvFileError, file)
        case let .rcvWarning(rcvFileError):
            showFileErrorAlert(rcvFileError, temporary: true)
        case let .sndError(sndFileError):
            showFileErrorAlert(sndFileError)
        case let .sndWarning(sndFileError):
            showFileErrorAlert(sndFileError, temporary: true)
        default: ()
        }
    }


    private func pxLoadedImageContent(_ uiImage: UIImage) -> some View {
        Group { if smallView { smallViewImageView(uiImage) } else { imageView(uiImage) } }
            .fullScreenCover(isPresented: $showFullScreenImage) {
                FullScreenMediaView(chatItem: chatItem, scrollToItem: scrollToItem, image: uiImage, showView: $showFullScreenImage)
            }
            .if(!smallView) { view in
                view.modifier(PrivacyBlur(blurred: $blurred))
            }
            .if(!blurred) { v in
                v.simultaneousGesture(TapGesture().onEnded { showFullScreenImage = true })
            }
            .onChange(of: m.activeCallViewIsCollapsed) {_, _ in
                showFullScreenImage = false
            }
            .accessibilityLabel(Text(NSLocalizedString("a11y_chat_image", comment: "")))
    }

    private func imageView(_ img: UIImage) -> some View {
        let w = pxVM.imageWidth(for: img.size, maxWidth: maxWidth)
        return ZStack(alignment: .topTrailing) {
            if img.imageData == nil {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: w * heightRatio(img.size))
                    .clipped()
            } else {
                SwiftyGif(image: img, contentMode: .scaleAspectFill)
                    .frame(width: w, height: w * heightRatio(img.size))
                    .clipped()
            }
            if pxVM.showStatusOverlay {
                pxLoadingOverlay
            }
        }
    }

    private func smallViewImageView(_ img: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            if img.imageData == nil {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: maxWidth, height: maxWidth)
            } else {
                SwiftyGif(image: img, contentMode: .scaleAspectFill)
                    .frame(width: maxWidth, height: maxWidth)
            }
            if chatItem.file?.showStatusIconInSmallView == true {
                pxLoadingOverlay
            }
        }
    }

    // MARK: - POPOPX loading overlay

    @ViewBuilder
    private var pxLoadingOverlay: some View {
        if let file = chatItem.file {
            switch file.fileStatus {
            case .sndStored:
                switch file.fileProtocol {
                case .xftp: pxProgressIndicator
                case .smp: EmptyView()
                case .local: EmptyView()
                }
            case .sndTransfer: pxProgressIndicator
            case .sndComplete: pxStatusIcon("checkmark", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .sndCancelled: pxStatusIcon("xmark", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .sndError: pxStatusIcon("xmark", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .sndWarning: pxStatusIcon("exclamationmark.triangle.fill", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .rcvInvitation: pxStatusIcon(file.expired && fileSizeValid(file) ? "xmark" : "arrow.down", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .rcvAccepted: pxStatusIcon("ellipsis", size: PXCIImageConfig.iconSizeAccept, padding: PXCIImageConfig.iconPaddingAccept)
            case .rcvTransfer: pxProgressIndicator
            case .rcvAborted: pxStatusIcon("exclamationmark.arrow.circlepath", size: PXCIImageConfig.iconSizeAccept, padding: PXCIImageConfig.iconPaddingAccept)
            case .rcvComplete: EmptyView()
            case .rcvCancelled: pxStatusIcon("xmark", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .rcvError: pxStatusIcon("xmark", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .rcvWarning: pxStatusIcon("exclamationmark.triangle.fill", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            case .invalid: pxStatusIcon("questionmark", size: PXCIImageConfig.iconSizeSmall, padding: PXCIImageConfig.iconPaddingDefault)
            }
        }
    }

    private func pxStatusIcon(_ icon: String, size: CGFloat, padding: CGFloat) -> some View {
        Image(systemName: icon)
            .resizable()
            .invertedForegroundStyle()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .padding(padding)
            .accessibilityHidden(true)
    }

    private var pxProgressIndicator: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(PXCIImageConfig.progressTint)
            .frame(width: PXCIImageConfig.progressFrameSize, height: PXCIImageConfig.progressFrameSize)
            .padding(PXCIImageConfig.progressPadding)
            .accessibilityLabel(Text(NSLocalizedString("a11y_loading_image", comment: "")))
    }
}

// MARK: - POPOPX
extension CIImageView {
    var pxComponentTag: String { "PX_CI_IMAGE_VIEW" }
    var pxIsSmallMode: Bool { smallView }
    var pxIsBlurred: Bool { blurred }
}
