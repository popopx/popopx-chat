// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereImageRevealView.swift
//  POPOPX (iOS)
//
//  Full-screen image reveal for burn-after-read images.
//  Uses isSecureTextEntry trick to black out content in screenshots/recordings.
//  Supports pinch-to-zoom and double-tap zoom via UIScrollView.
//  Auto-dismisses on screenshot or screen recording detection.
//

import SwiftUI
import UIKit

struct BinThereImageRevealView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var faceGuardian = FaceGuardianMonitor()

    let imageData: Data
    let onDismiss: () -> Void

    @State private var warningMsg: String?
    @State private var pxScreenshotObserver: NSObjectProtocol?
    @State private var pxRecordingObserver: NSObjectProtocol?
    @State private var mosaicActive = false
    @AppStorage(DEFAULT_BINTHERE_SECURITY) private var securityEnhanced = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: imageData) {
                SecureImageZoomableView(image: uiImage)
                    .ignoresSafeArea()
                    .blur(radius: faceGuardian.status == .notLooking ? 50 : 0)
                    .allowsHitTesting(faceGuardian.status != .notLooking)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(QuantumColors.textSecondary)
                    Text(NSLocalizedString("Failed to load image", comment: ""))
                        .foregroundColor(QuantumColors.textSecondary)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }

            VStack {
                Spacer()

                faceGuardianStatusView

                if let warningMsg {
                    Text(warningMsg)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }

            BinThereMosaicDissolve(isActive: $mosaicActive) {
                dismiss()
            }

            if securityEnhanced {
                BinThereMoireDefense()
            }
        }
        .onAppear {
            registerScreenshotDetection()
            registerRecordingDetection()
            if securityEnhanced {
                faceGuardian.onViolationCapture = { reason, sampleBuffer in
                    BinThereEvidenceManager.shared.handleViolation(reason: reason, sampleBuffer: sampleBuffer)
                }
                faceGuardian.start()
            }
        }
        .onDisappear {
            if let obs = pxScreenshotObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = pxRecordingObserver { NotificationCenter.default.removeObserver(obs) }
            pxScreenshotObserver = nil
            pxRecordingObserver = nil
            faceGuardian.stop()
            onDismiss()
        }
        .onChange(of: faceGuardian.status) { _, newStatus in
            switch newStatus {
            case .notLooking:
                warningMsg = NSLocalizedString("Please look at the screen", comment: "")
            case .multipleFaces:
                warningMsg = NSLocalizedString("Multiple faces detected — content protected", comment: "")
                triggerMosaicDissolve()
            case .looking:
                if warningMsg == NSLocalizedString("Please look at the screen", comment: "") {
                    warningMsg = nil
                }
            case .notAvailable:
                break
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !mosaicActive {
                triggerMosaicDissolve()
            }
        }
        .popopxBranded()
    }

    @ViewBuilder
    private var faceGuardianStatusView: some View {
        switch faceGuardian.status {
        case .notLooking:
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                Text(NSLocalizedString("binthere_look_to_reveal", comment: "Instruction to look at screen to reveal content"))
            }
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 80)
        case .multipleFaces:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text(NSLocalizedString("binthere_multiple_faces", comment: "Warning that multiple faces were detected"))
            }
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 80)
        case .looking, .notAvailable:
            EmptyView()
        }
    }

    private func registerScreenshotDetection() {
        pxScreenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            warningMsg = NSLocalizedString("Screenshots are disabled for this message", comment: "")
            triggerMosaicDissolve()
        }
    }

    private func registerRecordingDetection() {
        pxRecordingObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               scene.screen.isCaptured {
                triggerMosaicDissolve()
            }
        }
    }

    private func triggerMosaicDissolve() {
        withAnimation(.easeIn(duration: 0.3)) {
            mosaicActive = true
        }
    }
}

// MARK: - Screenshot-protected zoomable image

private struct SecureImageZoomableView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SecureContainerView {
        let container = SecureContainerView()

        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.clipsToBounds = true
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.protect(contentView: scrollView)

        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return container
    }

    func updateUIView(_ container: SecureContainerView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              let scrollView = context.coordinator.scrollView else { return }
        imageView.image = image
        context.coordinator.centerImageView(in: scrollView)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView(in: scrollView)
        }

        func centerImageView(in scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(
                    width: scrollView.bounds.width / 2.0,
                    height: scrollView.bounds.height / 2.0
                )
                let origin = CGPoint(
                    x: point.x - size.width / 2.0,
                    y: point.y - size.height / 2.0
                )
                scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
            }
        }
    }
}
