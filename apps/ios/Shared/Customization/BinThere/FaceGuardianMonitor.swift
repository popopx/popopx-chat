// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  FaceGuardianMonitor.swift
//  POPOPX (iOS)
//
//  Face presence & gaze monitoring for BinThere burn-after-read reveal views.
//  Dual backend:
//  - ARKit (TrueDepth devices): precise gaze via ARFaceAnchor.transform
//  - Vision (all devices): coarse yaw/pitch via VNDetectFaceRectanglesRequest
//
//  Detects:
//  - No face → content blurred
//  - Face looking away → content blurred
//  - Multiple faces → potential photographer, auto-dismiss (Vision only)
//

@preconcurrency import AVFoundation
import Vision
@preconcurrency import ARKit
import Combine
import os
import simd

enum FaceGuardianStatus: Equatable {
    case notAvailable
    case looking
    case notLooking
    case multipleFaces
}

@MainActor
class FaceGuardianMonitor: ObservableObject {
    @Published private(set) var status: FaceGuardianStatus = .notAvailable

    var onViolationCapture: ((_ reason: String, _ sampleBuffer: CMSampleBuffer) -> Void)?

    private let logger = Logger(subsystem: "im.popopx", category: "FaceGuardian")
    private let sessionQueue = DispatchQueue(label: "im.popopx.faceguardian.session", qos: .userInitiated)
    private let videoDataQueue = DispatchQueue(label: "im.popopx.faceguardian.video", qos: .userInitiated)

    private enum Backend {
        case arKit
        case vision
    }

    private var isRunning = false
    private var backend: Backend = .vision

    // Vision backend state
    private var captureSession: AVCaptureSession?
    private var requestHandler: VNSequenceRequestHandler?
    private var lastFrameTime: CFTimeInterval = 0
    private let minFrameInterval: CFTimeInterval = 1.0 / 5.0

    // ARKit backend state
    private var arSession: ARSession?
    private var arSessionHandler: ARSessionHandler?

    // Shared state
    private var consecutiveNotLookingFrames = 0
    private var consecutiveLookingFrames = 0
    private let statusChangeThreshold = 3

    func start() {
        guard !isRunning else { return }
        isRunning = true
        backend = selectBackend()
        logger.info("FaceGuardian starting with \(self.backend == .arKit ? "ARKit" : "Vision") backend")
        switch backend {
        case .arKit:
            setupARSession()
        case .vision:
            setupVisionSession()
        }
    }

    func stop() {
        isRunning = false
        captureSession?.stopRunning()
        captureSession = nil
        requestHandler = nil
        arSession?.pause()
        arSession = nil
        arSessionHandler = nil
        status = .notAvailable
    }

    private func selectBackend() -> Backend {
        ARFaceTrackingConfiguration.isSupported ? .arKit : .vision
    }

    // MARK: - Vision Backend

    private func setupVisionSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = Self.frontCameraDevice() else {
            logger.warning("Front camera not available")
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            logger.warning("Cannot create capture input")
            return
        }

        guard session.canAddInput(input) else {
            logger.warning("Cannot add capture input")
            return
        }
        session.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(FrameProcessor(monitor: self), queue: videoDataQueue)

        guard session.canAddOutput(videoOutput) else {
            logger.warning("Cannot add capture output")
            return
        }
        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0
        }

        captureSession = session
        requestHandler = VNSequenceRequestHandler()
        sessionQueue.async { [session] in
            session.startRunning()
        }
        logger.info("Vision backend started")
    }

    private static func frontCameraDevice() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
            return device
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }

    fileprivate func processFrame(_ pixelBuffer: CVPixelBuffer, sampleBuffer: CMSampleBuffer) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            if let error {
                self?.logger.warning("Face detection error: \(error)")
                return
            }
            self?.handleVisionResults(request.results as? [VNFaceObservation] ?? [], sampleBuffer: sampleBuffer)
        }

        let handler = requestHandler ?? VNSequenceRequestHandler()
        do {
            try handler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            logger.warning("Failed to perform face detection: \(error)")
        }
    }

    private func handleVisionResults(_ observations: [VNFaceObservation], sampleBuffer: CMSampleBuffer) {
        switch observations.count {
        case 0:
            consecutiveNotLookingFrames += 1
            consecutiveLookingFrames = 0
            if consecutiveNotLookingFrames >= statusChangeThreshold {
                status = .notLooking
            }

        case 1:
            let face = observations[0]
            let yaw = abs(Float(truncating: face.yaw ?? 0))
            let pitch = abs(Float(truncating: face.pitch ?? 0))
            let lookingAtScreen = yaw < Self.radians(25) && pitch < Self.radians(20)

            if lookingAtScreen {
                consecutiveLookingFrames += 1
                consecutiveNotLookingFrames = 0
                if consecutiveLookingFrames >= statusChangeThreshold {
                    status = .looking
                }
            } else {
                consecutiveNotLookingFrames += 1
                consecutiveLookingFrames = 0
                if consecutiveNotLookingFrames >= statusChangeThreshold {
                    status = .notLooking
                }
            }

        default:
            status = .multipleFaces
            consecutiveNotLookingFrames = 0
            consecutiveLookingFrames = 0
            onViolationCapture?("multiple_faces_detected", sampleBuffer)
        }
    }

    // MARK: - ARKit Backend

    private func setupARSession() {
        let session = ARSession()
        let handler = ARSessionHandler(monitor: self)
        session.delegate = handler
        arSession = session
        arSessionHandler = handler

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false

        sessionQueue.async { [session, configuration] in
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
        logger.info("ARKit backend started")
    }

    fileprivate func handleARFrame(anchor: ARFaceAnchor) {
        let transform = anchor.transform
        let m = transform
        let yaw = atan2(-m.columns.2.x, sqrt(m.columns.2.y * m.columns.2.y + m.columns.2.z * m.columns.2.z))
        let pitch = atan2(m.columns.2.y, m.columns.2.z)

        let yawDeg = abs(yaw) * Float(180.0 / .pi)
        let pitchDeg = abs(pitch) * Float(180.0 / .pi)
        let lookingAtScreen = yawDeg < 25 && pitchDeg < 20

        if lookingAtScreen {
            consecutiveLookingFrames += 1
            consecutiveNotLookingFrames = 0
            if consecutiveLookingFrames >= statusChangeThreshold {
                status = .looking
            }
        } else {
            consecutiveNotLookingFrames += 1
            consecutiveLookingFrames = 0
            if consecutiveNotLookingFrames >= statusChangeThreshold {
                status = .notLooking
            }
        }
    }

    fileprivate func handleARKitFailure(error: Error) {
        logger.error("ARKit session failed: \(error). Falling back to Vision backend.")
        arSession?.pause()
        arSession = nil
        backend = .vision
        consecutiveNotLookingFrames = 0
        consecutiveLookingFrames = 0
        setupVisionSession()
    }

    fileprivate func handleNoFaceDetected() {
        consecutiveNotLookingFrames += 1
        consecutiveLookingFrames = 0
        if consecutiveNotLookingFrames >= statusChangeThreshold {
            status = .notLooking
        }
    }

    // MARK: - Helpers

    private static func radians(_ degrees: Double) -> Float {
        Float(degrees * .pi / 180.0)
    }
}

// MARK: - Vision frame processor

private class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var monitor: FaceGuardianMonitor?

    init(monitor: FaceGuardianMonitor) {
        self.monitor = monitor
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        Task { @MainActor [weak monitor] in
            monitor?.processFrame(pixelBuffer, sampleBuffer: sampleBuffer)
        }
    }
}

// MARK: - ARKit session handler

private class ARSessionHandler: NSObject, ARSessionDelegate {
    weak var monitor: FaceGuardianMonitor?

    init(monitor: FaceGuardianMonitor) {
        self.monitor = monitor
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let faceAnchors = frame.anchors.compactMap { $0 as? ARFaceAnchor }
        if let faceAnchor = faceAnchors.first {
            Task { @MainActor [weak monitor] in
                monitor?.handleARFrame(anchor: faceAnchor)
            }
        } else {
            Task { @MainActor [weak monitor] in
                monitor?.handleNoFaceDetected()
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak monitor] in
            monitor?.handleARKitFailure(error: error)
        }
    }
}
