// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereRevealView.swift
//  POPOPX (iOS)
//
//  Full-screen reveal for a burn-after-read message.
//  Uses isSecureTextEntry trick to black out content in screenshots/recordings.
//  Auto-dismisses on screenshot or screen recording detection.
//

import SwiftUI
import UIKit

struct BinThereRevealView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var faceGuardian = FaceGuardianMonitor()

    var text: String
    var onDismiss: () -> Void

    @State private var warningMsg: String?
    @State private var pxScreenshotObserver: NSObjectProtocol?
    @State private var pxRecordingObserver: NSObjectProtocol?
    @State private var mosaicActive = false
    @AppStorage(DEFAULT_BINTHERE_SECURITY) private var securityEnhanced = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(QuantumColors.accent.gradient)

                SecureTextScrollableView(text: text)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal)
                    .blur(radius: faceGuardian.status == .notLooking ? 40 : 0)
                    .allowsHitTesting(faceGuardian.status != .notLooking)

                if let warningMsg {
                    Text(warningMsg)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .transition(.opacity)
                }

                faceGuardianStatusView

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text(NSLocalizedString("Destroy & Close", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(QuantumColors.error.gradient)
                    )
                }
            }
            .padding()

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
    }

    @ViewBuilder
    private var faceGuardianStatusView: some View {
        switch faceGuardian.status {
        case .notLooking:
            Label(NSLocalizedString("binthere_look_at_screen", comment: "Look at the screen to reveal content label"), systemImage: "eye.slash")
                .font(.caption)
                .foregroundColor(.orange)
        case .multipleFaces:
            Label(NSLocalizedString("binthere_multiple_faces", comment: "Multiple faces detected label"), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.red)
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

// MARK: - Screenshot-protected scrollable text

private struct SecureTextScrollableView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> SecureContainerView {
        let container = SecureContainerView()

        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.clipsToBounds = true

        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .white
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(label)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.protect(contentView: scrollView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            label.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        return container
    }

    func updateUIView(_ uiView: SecureContainerView, context: Context) {
        guard let scrollView = uiView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView,
              let label = scrollView.subviews.compactMap({ $0 as? UILabel }).first else { return }
        label.text = text
    }
}
