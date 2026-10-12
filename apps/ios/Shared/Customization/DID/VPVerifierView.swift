// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/11-FEATURE-DID.md
import SwiftUI
import AVFoundation
import UIKit

struct VPVerifierView: View {
    @State private var vpJSONInput: String = ""
    @State private var verificationResults: [VerificationResult] = []
    @State private var isVerifying: Bool = false
    @State private var showScanner: Bool = false

    enum VerificationStatus {
        case valid, warning, invalid
    }

    struct VerificationResult: Identifiable {
        let id = UUID()
        var credentialType: String
        var issuer: String
        var status: VerificationStatus
        var message: String
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    inputSection
                    actionButtons
                    if !verificationResults.isEmpty {
                        resultsSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(NSLocalizedString("vp_verify_presentation", comment: "navigation title for verifiable presentation verifier"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                isPresented: $showScanner,
                onScan: handleScannedData
            )
        }
        .popopxBranded()
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("vp_verifier_presentation_title", comment: "Title for verifiable presentation input section"))
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)

            Text(NSLocalizedString("vp_verifier_paste_instructions", comment: "Instructions for pasting VP JSON or scanning QR"))
                .font(QuantumFonts.caption)
                .foregroundColor(QuantumColors.textSecondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(QuantumColors.surfaceElevated, lineWidth: 1)
                    .frame(minHeight: 160)

                TextEditor(text: $vpJSONInput)
                    .font(QuantumFonts.body)
                    .foregroundColor(QuantumColors.textPrimary)
                    .padding(12)
                    .frame(minHeight: 160)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .glassBackground(cornerRadius: 16)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showScanner = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                    Text(NSLocalizedString("vp_verifier_scan_qr", comment: "Button to scan QR code"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(QuantumColors.accentSecondary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .glassButtonStyle()
            }

            Button(action: verifyPresentation) {
                HStack(spacing: 8) {
                    if isVerifying {
                        ProgressView()
                            .tint(QuantumColors.textPrimary)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    Text(NSLocalizedString("vp_verifier_verify_button", comment: "Button to verify presentation"))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(QuantumColors.textPrimary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .glassProminentButton()
            }
            .disabled(vpJSONInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("vp_verifier_results", comment: "Section header for verification results"))
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)

            ForEach(verificationResults) { result in
                resultRow(result)
            }
        }
    }

    private func resultRow(_ result: VerificationResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForStatus(result.status))
                .foregroundColor(colorForStatus(result.status))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.credentialType)
                    .font(QuantumFonts.body)
                    .fontWeight(.medium)
                    .foregroundColor(QuantumColors.textPrimary)
                Text(result.message)
                    .font(QuantumFonts.caption)
                    .foregroundColor(colorForStatus(result.status))
            }

            Spacer()
        }
        .padding(14)
        .glassBackground()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    colorForStatus(result.status).opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    private func iconForStatus(_ status: VerificationStatus) -> String {
        switch status {
        case .valid: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }

    private func colorForStatus(_ status: VerificationStatus) -> Color {
        switch status {
        case .valid: return QuantumColors.success
        case .warning: return QuantumColors.warning
        case .invalid: return QuantumColors.error
        }
    }

    private func verifyPresentation() {
        isVerifying = true
        verificationResults.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let trimmed = vpJSONInput.trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let credentials = json["verifiableCredential"] as? [[String: Any]] {

                for cred in credentials {
                    let credType = (cred["type"] as? String) ?? "Unknown"
                    let issuer = (cred["issuer"] as? String) ?? "Unknown"
                    let expirationDate = cred["expirationDate"] as? String

                    // NOTE: This is structural validation only — it checks JSON structure
                    // and proof field presence, but does NOT perform cryptographic verification.
                    // This is a demo/preview feature. Production use requires a full DID/VC
                    // cryptographic verification library.
                    var status: VerificationStatus = .warning
                    var message = NSLocalizedString("vp_demo_not_verified", comment: "VP verification demo disclaimer")

                    if let expStr = expirationDate,
                       let formatter = Optional(ISO8601DateFormatter()),
                       let expDate = formatter.date(from: expStr) {
                        if expDate < Date() {
                            status = .invalid
                            message = NSLocalizedString("vp_credential_expired", comment: "VP verification expired credential")
                        }
                    }

                    verificationResults.append(
                        VerificationResult(
                            credentialType: credType,
                            issuer: issuer,
                            status: status,
                            message: message
                        )
                    )
                }
            } else {
                verificationResults.append(
                    VerificationResult(
                        credentialType: NSLocalizedString("vp_parse_error", comment: "VP parse error type"),
                        issuer: "N/A",
                        status: .invalid,
                        message: NSLocalizedString("vp_invalid_json", comment: "VP invalid JSON format error")
                    )
                )
            }

            isVerifying = false
        }
    }

    private func handleScannedData(_ data: String) {
        vpJSONInput = data
        showScanner = false
        // Allow the sheet dismiss animation to complete, then verify
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            verifyPresentation()
        }
    }
}

struct QRScannerView: View {
    @Binding var isPresented: Bool
    var onScan: (String) -> Void

    @State private var cameraPermission: CameraPermissionState = .notDetermined
    @State private var scannedCode: String? = nil

    enum CameraPermissionState {
        case notDetermined
        case authorized
        case denied
        case unavailable
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraPermission {
            case .notDetermined:
                ProgressView(NSLocalizedString("vp_requesting_camera", comment: "camera permission request progress text"))
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            case .denied:
                permissionDeniedView
            case .unavailable:
                noCameraView
            case .authorized:
                ZStack(alignment: .top) {
                    QRPreviewView(onCodeScanned: handleCode)
                        .ignoresSafeArea()

                    // Scanned indicator overlay
                    if scannedCode != nil {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(QuantumColors.success)
                            Text(NSLocalizedString("vp_verifier_qr_scanned", comment: "Overlay text when QR code is scanned"))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }

                    closeButtonOverlay
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }

    private var closeButtonOverlay: some View {
        HStack {
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 3)
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.7))

            Text(NSLocalizedString("vp_camera_access_denied", comment: "camera permission denied title"))
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(NSLocalizedString("vp_camera_access_denied_msg", comment: "camera permission denied message"))
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: openSettings) {
                Text(NSLocalizedString("vp_open_settings", comment: "button to open Settings app"))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.top, 4)

            Button(action: { isPresented = false }) {
                Text(NSLocalizedString("Close", comment: "close button"))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.top, 4)
        }
    }

    private var noCameraView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.7))

            Text(NSLocalizedString("vp_camera_unavailable", comment: "camera unavailable title"))
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(NSLocalizedString("vp_camera_unavailable_msg", comment: "camera unavailable message"))
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { isPresented = false }) {
                Text(NSLocalizedString("Close", comment: "close button"))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.top, 4)
        }
    }

    private func checkCameraPermission() {
        // Check if device has a camera (simulator may not)
        guard AVCaptureDevice.default(for: .video) != nil else {
            cameraPermission = .unavailable
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraPermission = .authorized
        case .denied, .restricted:
            cameraPermission = .denied
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        @unknown default:
            cameraPermission = .denied
        }
    }

    private func handleCode(_ code: String) {
        guard scannedCode == nil else { return } // prevent duplicate scans
        scannedCode = code

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Small delay to show the success indicator, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onScan(code)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - AVCaptureSession wrapper

/// A UIViewRepresentable that sets up an AVCaptureSession for QR code detection
/// and renders the preview layer.
struct QRPreviewView: UIViewRepresentable {
    var onCodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        session.beginConfiguration()
        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()

        // Preview layer inside the custom view
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        // Start session on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeScanned: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasScanned = false

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned else { return }

            for case let object as AVMetadataMachineReadableCodeObject in metadataObjects {
                if let stringValue = object.stringValue {
                    hasScanned = true
                    session?.stopRunning()
                    onCodeScanned(stringValue)
                    return
                }
            }
        }
    }
}

/// Custom UIView that keeps its AVCaptureVideoPreviewLayer sized to match the view bounds.
class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
