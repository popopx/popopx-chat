//
//  ImagePicker.swift
//  POPOPX
//
//  Created by Evgeny on 23/03/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import PhotosUI
import SwiftyGif
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxPickerFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_PICKER_FEATURE_ENABLED")

// POPOPX: media picker queue and temp-file naming constants
private enum PXMediaConstants {
    static let pxQueueLabel = "com.popopxchat.popopx.LibraryMediaListPicker"
    static let pxRawVideoTag = "rawvideo"
    static let pxConvertedVideoTag = "video"
    static let pxConvertedExtension = "mp4"
}

/// Wraps the system photo library picker for single-image selection.
struct LibraryImagePicker: View {
    @Binding var image: UIImage?
    var didFinishPicking: (_ didSelectImage: Bool) async -> Void
    @State var mediaAdded = false

    var body: some View {
        LibraryMediaListPicker(addMedia: pxHandleMedia, selectionLimit: 1, didFinishPicking: didFinishPicking)
            .popopxBranded()
    }

    // POPOPX: guard against duplicate media additions
    private func pxHandleMedia(_ content: UploadContent) async {
        guard !mediaAdded else { return }
        await MainActor.run {
            mediaAdded = true
            image = content.uiImage
        }
    }
}

struct LibraryMediaListPicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = PHPickerViewController
    var addMedia: (_ content: UploadContent) async -> Void
    var selectionLimit: Int
    var filter: PHPickerFilter = .any(of: [.images, .videos])
    var finishedPreprocessing: () -> Void = {}
    var didFinishPicking: (_ didSelectItems: Bool) async -> Void

    class Coordinator: PHPickerViewControllerDelegate {
        var parent: LibraryMediaListPicker
        let dispatchQueue = DispatchQueue(label: PXMediaConstants.pxQueueLabel)

        init(_ parent: LibraryMediaListPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            Task {
                await parent.didFinishPicking(!results.isEmpty)
                guard !results.isEmpty else { return }
                for pxResult in results {
                    await pxLoadProvider(pxResult.itemProvider)
                }
                parent.finishedPreprocessing()
            }
        }

        // POPOPX: route item provider to the correct loader
        private func pxLoadProvider(_ pxProvider: NSItemProvider) async {
            logger.debug("PX: [loadItem] called")
            logger.debug("LibraryMediaListPicker result")
            if pxProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                await pxHandleVideoProvider(pxProvider)
                return
            }
            if pxProvider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                await pxHandleDataProvider(pxProvider)
            } else if pxProvider.canLoadObject(ofClass: UIImage.self) {
                await pxHandleImageProvider(pxProvider)
            }
        }

        private func pxHandleVideoProvider(_ pxProvider: NSItemProvider) async {
            if let pxVideo = await loadVideo(pxProvider) {
                await self.parent.addMedia(pxVideo)
                logger.debug("LibraryMediaListPicker: added video")
            }
        }

        private func pxHandleDataProvider(_ pxProvider: NSItemProvider) async {
            if let pxImg = await loadImageData(pxProvider) {
                await self.parent.addMedia(pxImg)
                logger.debug("LibraryMediaListPicker: added image")
            }
        }

        private func pxHandleImageProvider(_ pxProvider: NSItemProvider) async {
            if let pxImg = await loadImage(pxProvider) {
                await self.parent.addMedia(.simpleImage(image: pxImg))
                logger.debug("LibraryMediaListPicker: added image")
            }
        }

        private func loadImageData(_ p: NSItemProvider) async -> UploadContent? {
            await withCheckedContinuation { cont in
                loadFileURL(p, type: UTType.data) { url in
                    if let url = url {
                        let img = UploadContent.loadFromURL(url: url)
                        cont.resume(returning: img)
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            }
        }

        private func loadImage(_ p: NSItemProvider) async -> UIImage? {
            await withCheckedContinuation { cont in
                p.loadObject(ofClass: UIImage.self)  { obj, err in
                    if let err = err {
                        logger.error("LibraryMediaListPicker result image error: \(err.localizedDescription)")
                        cont.resume(returning: nil)
                    } else  {
                        cont.resume(returning: obj as? UIImage)
                    }
                }
            }
        }

        // POPOPX: video loading with temp-file conversion pipeline
        private func loadVideo(_ p: NSItemProvider) async -> UploadContent? {
            logger.debug("PX: [loadVideo] called")
            return await withCheckedContinuation { cont in
                loadFileURL(p, type: UTType.movie) { url in
                    guard let pxSourceUrl = url else {
                        cont.resume(returning: nil)
                        return
                    }
                    let pxTempDir = getTempFilesDirectory().path
                    let pxRawPath = generateNewFileName(pxTempDir + "/" + PXMediaConstants.pxRawVideoTag, pxSourceUrl.pathExtension, fullPath: true)
                    let pxConvertedPath = generateNewFileName(pxTempDir + "/" + PXMediaConstants.pxConvertedVideoTag, PXMediaConstants.pxConvertedExtension, fullPath: true)
                    let pxTempUrl = URL(fileURLWithPath: pxRawPath)
                    let pxOutputUrl = URL(fileURLWithPath: pxConvertedPath)
                    do {
                        try FileManager.default.copyItem(at: pxSourceUrl, to: pxTempUrl)
                    } catch let err {
                        logger.error("LibraryMediaListPicker copyItem error: \(err.localizedDescription)")
                        return cont.resume(returning: nil)
                    }
                    Task {
                        let pxConversionOk = await makeVideoQualityLower(pxTempUrl, outputUrl: pxOutputUrl)
                        try? FileManager.default.removeItem(at: pxTempUrl)
                        if pxConversionOk {
                            _ = ChatModel.shared.filesToDelete.insert(pxOutputUrl)
                            let pxVideo = await UploadContent.loadVideoFromURL(url: pxOutputUrl)
                            return cont.resume(returning: pxVideo)
                        }
                        try? FileManager.default.removeItem(at: pxOutputUrl)
                        cont.resume(returning: nil)
                    }
                }
            }
        }

        private func loadFileURL(_ p: NSItemProvider, type: UTType, completion: @escaping (URL?) -> Void) {
            p.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, err in
                if let err = err {
                    logger.error("LibraryMediaListPicker loadFileURL error: \(err.localizedDescription)")
                    completion(nil)
                } else {
                    completion(url)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = filter
        config.selectionLimit = selectionLimit
        config.selection = .ordered
        config.preferredAssetRepresentationMode = .current
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.parent = self
    }
}

struct CameraImageListPicker: View {
    @Binding var images: [UploadContent]
    @State var image: UIImage?

    var body: some View {
        CameraImagePicker(image: $image)
            .onChange(of: image) {_,  pxNewImage in
                if let pxNewImage = pxNewImage {
                    images = [UploadContent.simpleImage(image: pxNewImage)]
                } else {
                    images = []
                }
            }
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<CameraImagePicker>) {

    }
}

// MARK: - POPOPX

private let pxComponentTag = "PXImagePicker"
