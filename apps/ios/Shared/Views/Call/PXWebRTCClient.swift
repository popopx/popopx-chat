//
// Created by Avently on 09.02.2023.
// Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/calls.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

@preconcurrency import WebRTC
import LZString
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXWebRTCConfig {
    static let componentTag: String = "PX_WEB_RTC_CLIENT"
    static let videoCaptureHeight: Int32 = 1280
    static let videoMinHeight: Int32 = 480
    static let videoMaxFps: Double = 24
    static let iceInitialTimeoutMs: UInt64 = 750
    static let iceStepMs: UInt64 = 150
    static let iceRestartTimeoutMs: UInt64 = 12000
    static let iceRestartStepMs: UInt64 = 1500
    static let ivTagBytes: Int = 28
    static let enableEncryption: Bool = true
    static let audioQueueLabel: String = "com.popopxchat.popopx.audio"
    static let callStateQueueLabel: String = "com.popopxchat.popopx.callstate"
    static let muteCheckIntervalNanos: UInt64 = 1000_000000
    static let muteThresholdSeconds: Int = 3
    static let initialMuteSeconds: Int = 4
    static let iceInactiveTimeoutMs: Int = 30_000
}

enum WebRTCError: Error {
    case peerConnectionCreationFailed
}

// Spec: spec/services/calls.md#WebRTCClient
final class WebRTCClient: NSObject, @unchecked Sendable, RTCVideoViewDelegate, RTCFrameEncryptorDelegate, RTCFrameDecryptorDelegate {
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        videoEncoderFactory.preferredCodec = RTCVideoCodecInfo(name: kRTCVp8CodecName)
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    private static let ivTagBytes: Int = PXWebRTCConfig.ivTagBytes
    private static let enableEncryption: Bool = PXWebRTCConfig.enableEncryption
    private var chat_ctrl: chat_ctrl? = getChatCtrl()

    struct Call {
        var connection: RTCPeerConnection
        var iceCandidates: IceCandidates
        var localCamera: RTCVideoCapturer?
        var localAudioTrack: RTCAudioTrack?
        var localVideoTrack: RTCVideoTrack?
        var remoteAudioTrack: RTCAudioTrack?
        var remoteVideoTrack: RTCVideoTrack?
        var remoteScreenAudioTrack: RTCAudioTrack?
        var remoteScreenVideoTrack: RTCVideoTrack?
        var device: AVCaptureDevice.Position
        var aesKey: String?
        var frameEncryptor: RTCFrameEncryptor?
        var frameDecryptor: RTCFrameDecryptor?
        var peerHasOldVersion: Bool
    }

    struct NotConnectedCall {
        var audioTrack: RTCAudioTrack?
        var localCameraAndTrack: (RTCVideoCapturer, RTCVideoTrack)?
        var device: AVCaptureDevice.Position = .front
    }

    actor IceCandidates {
        private var candidates: [POPOPXSwitch.RTCIceCandidate] = []

        func getAndClear() async -> [POPOPXSwitch.RTCIceCandidate] {
            let cs = candidates
            candidates = []
            return cs
        }

        func append(_ c: POPOPXSwitch.RTCIceCandidate) async {
            candidates.append(c)
        }
    }

    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: PXWebRTCConfig.audioQueueLabel)
    private let callStateQueue = DispatchQueue(label: PXWebRTCConfig.callStateQueueLabel)
    private var sendCallResponse: (WVAPIMessage) async -> Void
    var activeCall: Call? {
        get { callStateQueue.sync { _activeCall } }
        set { callStateQueue.sync { _activeCall = newValue } }
    }
    private var _activeCall: Call?
    var notConnectedCall: NotConnectedCall? {
        get { callStateQueue.sync { _notConnectedCall } }
        set { callStateQueue.sync { _notConnectedCall = newValue } }
    }
    private var _notConnectedCall: NotConnectedCall?
    private var localRendererAspectRatio: Binding<CGFloat?>

    private var frameBuffer: UnsafeMutableRawBufferPointer?

    private var _cameraRenderers: [RTCVideoRenderer] = []
    private var _screenRenderers: [RTCVideoRenderer] = []
    var cameraRenderers: [RTCVideoRenderer] {
        get { callStateQueue.sync { _cameraRenderers } }
        set { callStateQueue.sync { _cameraRenderers = newValue } }
    }
    var screenRenderers: [RTCVideoRenderer] {
        get { callStateQueue.sync { _screenRenderers } }
        set { callStateQueue.sync { _screenRenderers = newValue } }
    }
    private var _muteUnmuteTasks: [String: Task<Void, Never>] = [:]
    private var _iceRestartInProgress = false
    private var muteUnmuteTasks: [String: Task<Void, Never>] {
        get { callStateQueue.sync { _muteUnmuteTasks } }
        set { callStateQueue.sync { _muteUnmuteTasks = newValue } }
    }
    private var iceRestartInProgress: Bool {
        get { callStateQueue.sync { _iceRestartInProgress } }
        set { callStateQueue.sync { _iceRestartInProgress = newValue } }
    }

    @available(*, unavailable)
    override init() {
        logger.error("WebRTCClient: parameterless init() was called but is unavailable — use init(_:_) instead")
        self.sendCallResponse = { _ in }
        self.localRendererAspectRatio = .constant(nil)
        super.init()
    }

    deinit {
        _endCall()
        frameBuffer?.deallocate()
        frameBuffer = nil
        logger.debug("WebRTCClient: cleaned up in deinit")
    }

    required init(_ sendCallResponse: @escaping (WVAPIMessage) async -> Void, _ localRendererAspectRatio: Binding<CGFloat?>) {
        self.sendCallResponse = sendCallResponse
        self.localRendererAspectRatio = localRendererAspectRatio
        rtcAudioSession.useManualAudio = CallController.useCallKit()
        rtcAudioSession.isAudioEnabled = !CallController.useCallKit()
        logger.debug("WebRTCClient: rtcAudioSession has manual audio \(self.rtcAudioSession.useManualAudio) and audio enabled \(self.rtcAudioSession.isAudioEnabled)")
        super.init()
    }

    let defaultIceServers: [WebRTC.RTCIceServer] = [
        WebRTC.RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
    ]

    // Spec: spec/services/calls.md#initializeCall
    func initializeCall(_ iceServers: [WebRTC.RTCIceServer]?, _ mediaType: CallMediaType, _ aesKey: String?, _ relay: Bool?) throws -> Call {
        let remoteIceServers = RemoteConfigCache.cachedIceServerStrings().flatMap { parseRTCIceServers($0)?.toWebRTCIceServers() }
        let connection = try createPeerConnection(iceServers ?? getWebRTCIceServers() ?? remoteIceServers ?? defaultIceServers, relay)
        connection.delegate = self
        let device = notConnectedCall?.device ?? .front
        var localCamera: RTCVideoCapturer? = nil
        var localAudioTrack: RTCAudioTrack? = nil
        var localVideoTrack: RTCVideoTrack? = nil
        if let localCameraAndTrack = notConnectedCall?.localCameraAndTrack {
            (localCamera, localVideoTrack) = localCameraAndTrack
        } else if notConnectedCall == nil && mediaType == .video {
            (localCamera, localVideoTrack) = createVideoTrackAndStartCapture(device)
        }
        if let audioTrack = notConnectedCall?.audioTrack {
            localAudioTrack = audioTrack
        } else if notConnectedCall == nil {
            localAudioTrack = createAudioTrack()
        }
        notConnectedCall?.localCameraAndTrack = nil
        notConnectedCall?.audioTrack = nil

        var frameEncryptor: RTCFrameEncryptor? = nil
        var frameDecryptor: RTCFrameDecryptor? = nil
        if aesKey != nil {
            let encryptor = RTCFrameEncryptor.init(sizeChange: Int32(WebRTCClient.ivTagBytes))
            encryptor.delegate = self
            frameEncryptor = encryptor

            let decryptor = RTCFrameDecryptor.init(sizeChange: 0)
            decryptor.delegate = self
            frameDecryptor = decryptor
        }
        return Call(
            connection: connection,
            iceCandidates: IceCandidates(),
            localCamera: localCamera,
            localAudioTrack: localAudioTrack,
            localVideoTrack: localVideoTrack,
            device: device,
            aesKey: aesKey,
            frameEncryptor: frameEncryptor,
            frameDecryptor: frameDecryptor,
            peerHasOldVersion: false
        )
    }

    // Spec: spec/services/calls.md#createPeerConnection
    func createPeerConnection(_ iceServers: [WebRTC.RTCIceServer], _ relay: Bool?) throws -> RTCPeerConnection {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

        guard let connection = WebRTCClient.factory.peerConnection(
            with: getCallConfig(iceServers, relay),
            constraints: constraints, delegate: nil
        )
        else {
            logger.error("WebRTCClient: unable to create RTCPeerConnection")
            throw WebRTCError.peerConnectionCreationFailed
        }
        return connection
    }

    func getCallConfig(_ iceServers: [WebRTC.RTCIceServer], _ relay: Bool?) -> RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.iceTransportPolicy = relay == true ? .relay : .all
        // Allows to wait 30 sec before `failing` connection if the answer from remote side is not received in time
        config.iceInactiveTimeout = NSNumber(value: PXWebRTCConfig.iceInactiveTimeoutMs)
        return config
    }

    // Spec: spec/services/calls.md#addIceCandidates
    func addIceCandidates(_ connection: RTCPeerConnection, _ remoteIceCandidates: [POPOPXSwitch.RTCIceCandidate]) {
        remoteIceCandidates.forEach { candidate in
            connection.add(candidate.toWebRTCCandidate()) { error in
                if let error = error {
                    logger.error("Adding candidate error \(error)")
                }
            }
        }
    }

    // Spec: spec/services/calls.md#sendCallCommand
    func sendCallCommand(command: WCallCommand) async {
        var resp: WCallResponse? = nil
        let pc = activeCall?.connection
        switch command {
        case let .capabilities(media): // outgoing
            let localCameraAndTrack: (RTCVideoCapturer, RTCVideoTrack)? = media == .video
            ? createVideoTrackAndStartCapture(.front)
            : nil
            notConnectedCall = NotConnectedCall(audioTrack: createAudioTrack(), localCameraAndTrack: localCameraAndTrack, device: .front)
            resp = .capabilities(capabilities: CallCapabilities(encryption: WebRTCClient.enableEncryption))
        case let .start(media: media, aesKey, iceServers, relay): // incoming
            logger.debug("starting incoming call - create webrtc session")
            if activeCall != nil {
                resp = .error(message: "start: call already in progress")
            } else {
            let encryption = WebRTCClient.enableEncryption
            do {
                let call = try initializeCall(iceServers?.toWebRTCIceServers(), media, encryption ? aesKey : nil, relay)
                activeCall = call
                setupLocalTracks(true, call)
                let (offer, error) = await call.connection.offer()
                if let offer = offer {
                    setupEncryptionForLocalTracks(call)
                    resp = .offer(
                        offer: compressToBase64(input: encodeJSON(CustomRTCSessionDescription(type: offer.type.toSdpType(), sdp: offer.sdp))),
                        iceCandidates: compressToBase64(input: encodeJSON(await self.getInitialIceCandidates())),
                        capabilities: CallCapabilities(encryption: encryption)
                    )
                    self.waitForMoreIceCandidates()
                } else {
                    resp = .error(message: "offer error: \(error?.localizedDescription ?? "unknown error")")
                }
            } catch {
                resp = await pxCleanupAfterFailedCallStart(error)
            }
            }
        case let .offer(offer, iceCandidates, media, aesKey, iceServers, relay): // outgoing
            if activeCall != nil {
                resp = .error(message: "accept: call already started")
            } else if !WebRTCClient.enableEncryption && aesKey != nil {
                resp = .error(message: "accept: encryption is not supported")
            } else if let offer: CustomRTCSessionDescription = decodeJSON(decompressFromBase64(input: offer)),
                      let remoteIceCandidates: [POPOPXSwitch.RTCIceCandidate] = decodeJSON(decompressFromBase64(input: iceCandidates)) {
                do {
                    let call = try initializeCall(iceServers?.toWebRTCIceServers(), media, WebRTCClient.enableEncryption ? aesKey : nil, relay)
                activeCall = call
                let pc = call.connection
                if let type = offer.type, let sdp = offer.sdp {
                    do {
                        try await pc.setRemoteDescription(RTCSessionDescription(type: type.toWebRTCSdpType(), sdp: sdp))
                        setupLocalTracks(false, call)
                        setupEncryptionForLocalTracks(call)
                        pc.transceivers.forEach { transceiver in
                            transceiver.setDirection(.sendRecv, error: nil)
                        }
                        await adaptToOldVersion(pc.transceivers.count <= 2)
                        let (answer, error) = await pc.answer()
                        if let answer = answer {
                            self.addIceCandidates(pc, remoteIceCandidates)
                            resp = .answer(
                                answer: compressToBase64(input: encodeJSON(CustomRTCSessionDescription(type: answer.type.toSdpType(), sdp: answer.sdp))),
                                iceCandidates: compressToBase64(input: encodeJSON(await self.getInitialIceCandidates()))
                            )
                            self.waitForMoreIceCandidates()
                        } else {
                            resp = .error(message: "answer error: \(error?.localizedDescription ?? "unknown error")")
                        }
                    } catch {
                        resp = .error(message: "accept: failed to set remote description: \(error.localizedDescription)")
                    }
                }
                } catch {
                    resp = await pxCleanupAfterFailedCallStart(error)
                }
            }
        case let .answer(answer, iceCandidates): // incoming
            if pc == nil {
                resp = .error(message: "answer: call not started")
            } else if pc?.localDescription == nil {
                resp = .error(message: "answer: local description is not set")
            } else if pc?.remoteDescription != nil {
                resp = .error(message: "answer: remote description already set")
            } else if let answer: CustomRTCSessionDescription = decodeJSON(decompressFromBase64(input: answer)),
                      let remoteIceCandidates: [POPOPXSwitch.RTCIceCandidate] = decodeJSON(decompressFromBase64(input: iceCandidates)),
                      let type = answer.type, let sdp = answer.sdp,
                      let pc = pc {
                do {
                    try await pc.setRemoteDescription(RTCSessionDescription(type: type.toWebRTCSdpType(), sdp: sdp))
                    var currentDirection: RTCRtpTransceiverDirection = .sendOnly
                    if pc.transceivers.count > 2 {
                        pc.transceivers[2].currentDirection(&currentDirection)
                    }
                    await adaptToOldVersion(currentDirection == .sendOnly)
                    addIceCandidates(pc, remoteIceCandidates)
                    resp = .ok
                } catch {
                    resp = .error(message: "answer: failed to set remote description: \(error.localizedDescription)")
                }
            }
        case let .ice(iceCandidates):
            if let pc = pc,
               let remoteIceCandidates: [POPOPXSwitch.RTCIceCandidate] = decodeJSON(decompressFromBase64(input: iceCandidates)) {
                addIceCandidates(pc, remoteIceCandidates)
                resp = .ok
            } else {
                resp = .error(message: "ice: call not started")
            }
        case let .media(source, enable):
            if activeCall == nil {
                resp = .error(message: "media: call not started")
            } else {
                await enableMedia(source, enable)
                resp = .ok
            }
        case .end:
            endCall()
            await sendCallResponse(.init(corrId: nil, resp: .ok, command: command))
        }
        if let resp = resp {
            await sendCallResponse(.init(corrId: nil, resp: resp, command: command))
        }
    }

    func getInitialIceCandidates() async -> [POPOPXSwitch.RTCIceCandidate] {
        await untilIceComplete(timeoutMs: PXWebRTCConfig.iceInitialTimeoutMs, stepMs: PXWebRTCConfig.iceStepMs) {}
        let candidates = await activeCall?.iceCandidates.getAndClear() ?? []
        logger.debug("WebRTCClient: sending initial ice candidates: \(candidates.count)")
        return candidates
    }

    func waitForMoreIceCandidates() {
        Task { [weak self] in
            await self?.untilIceComplete(timeoutMs: PXWebRTCConfig.iceRestartTimeoutMs, stepMs: PXWebRTCConfig.iceRestartStepMs) {
                let candidates = await self?.activeCall?.iceCandidates.getAndClear() ?? []
                if candidates.count > 0 {
                    logger.debug("WebRTCClient: sending more ice candidates: \(candidates.count)")
                    await self?.sendIceCandidates(candidates)
                }
            }
        }
    }

    // Spec: spec/services/calls.md#sendIceCandidates
    func sendIceCandidates(_ candidates: [POPOPXSwitch.RTCIceCandidate]) async {
        await self.sendCallResponse(.init(
            corrId: nil,
            resp: .ice(iceCandidates: compressToBase64(input: encodeJSON(candidates))),
            command: nil)
        )
    }

    func setupMuteUnmuteListener(_ transceiver: RTCRtpTransceiver, _ track: RTCMediaStreamTrack) {
        // logger.log("Setting up mute/unmute listener in the call without encryption for mid = \(transceiver.mid)")
        let task = Task { [weak self, weak transceiver, weak track] in
            var lastBytesReceived: Int64 = 0
            // muted initially
            var mutedSeconds = PXWebRTCConfig.initialMuteSeconds
            while !Task.isCancelled,
                  let self = self,
                  let transceiver = transceiver,
                  let track = track,
                  let call = self.activeCall,
                  track.readyState == .live {
                let stats: RTCStatisticsReport = await call.connection.statistics(for: transceiver.receiver)
                let stat = stats.statistics.values.first(where: { stat in stat.type == "inbound-rtp"})
                if let stat {
                    //logger.debug("Stat \(stat.debugDescription)")
                    let bytes = stat.values["bytesReceived"] as? Int64 ?? 0
                    if bytes <= lastBytesReceived {
                        mutedSeconds += 1
                        if mutedSeconds == PXWebRTCConfig.muteThresholdSeconds {
                            await MainActor.run { [weak self] in
                                self?.onMediaMuteUnmute(transceiver.mid, true)
                            }
                        }
                    } else {
                        if mutedSeconds >= PXWebRTCConfig.muteThresholdSeconds {
                            await MainActor.run { [weak self] in
                                self?.onMediaMuteUnmute(transceiver.mid, false)
                            }
                        }
                        lastBytesReceived = bytes
                        mutedSeconds = 0
                    }
                }
                try? await Task.sleep(nanoseconds: PXWebRTCConfig.muteCheckIntervalNanos)
            }
        }
        // Store task reference for cleanup
        muteUnmuteTasks[transceiver.mid] = task
    }

    @MainActor
    func onMediaMuteUnmute(_ transceiverMid: String?, _ mute: Bool) {
        guard let activeCall = ChatModel.shared.activeCall else { return }
        let source = mediaSourceFromTransceiverMid(transceiverMid)
        logger.log("Mute/unmute \(source.rawValue) track = \(mute) with mid = \(transceiverMid ?? "nil")")
        if source == .mic && activeCall.peerMediaSources.mic == mute {
            activeCall.peerMediaSources.mic = !mute
        } else if (source == .camera && activeCall.peerMediaSources.camera == mute) {
            activeCall.peerMediaSources.camera = !mute
        } else if (source == .screenAudio && activeCall.peerMediaSources.screenAudio == mute) {
            activeCall.peerMediaSources.screenAudio = !mute
        } else if (source == .screenVideo && activeCall.peerMediaSources.screenVideo == mute) {
            activeCall.peerMediaSources.screenVideo = !mute
        }
    }

    // Spec: spec/services/calls.md#enableMedia
    @MainActor
    func enableMedia(_ source: CallMediaSource, _ enable: Bool) {
        logger.debug("WebRTCClient: enabling media \(source.rawValue) \(enable)")
        source == .camera ? setCameraEnabled(enable) : setAudioEnabled(enable)
    }

    @MainActor
    func adaptToOldVersion(_ peerHasOldVersion: Bool) {
        activeCall?.peerHasOldVersion = peerHasOldVersion
        if peerHasOldVersion {
            logger.debug("The peer has an old version. Remote audio track is nil = \(self.activeCall?.remoteAudioTrack == nil), video = \(self.activeCall?.remoteVideoTrack == nil)")
            onMediaMuteUnmute("0", false)
            if activeCall?.remoteVideoTrack != nil {
                onMediaMuteUnmute("1", false)
            }
            if ChatModel.shared.activeCall?.localMediaSources.camera == true && ChatModel.shared.activeCall?.peerMediaSources.camera == false {
                logger.debug("Stopping video track for the old version")
                if let senders = activeCall?.connection.senders, senders.count > 1 {
                    senders[1].track = nil
                }
                ChatModel.shared.activeCall?.localMediaSources.camera = false
                (activeCall?.localCamera as? RTCCameraVideoCapturer)?.stopCapture()
                activeCall?.localCamera = nil
                activeCall?.localVideoTrack = nil
            }
        }
    }

    func addLocalRenderer(_ renderer: RTCMTLVideoView) {
        if let activeCall {
            if let track = activeCall.localVideoTrack {
                track.add(renderer)
            }
        } else if let notConnectedCall {
            if let track = notConnectedCall.localCameraAndTrack?.1 {
                track.add(renderer)
            }
        }
        // To get width and height of a frame, see videoView(videoView:, didChangeVideoSize)
        renderer.delegate = self
    }

    func removeLocalRenderer(_ renderer: RTCMTLVideoView) {
        if let activeCall {
            if let track = activeCall.localVideoTrack {
                track.remove(renderer)
            }
        } else if let notConnectedCall {
            if let track = notConnectedCall.localCameraAndTrack?.1 {
                track.remove(renderer)
            }
        }
        renderer.delegate = nil
    }

    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        guard size.height > 0 else { return }
        let ratio = size.width / size.height
        Task { @MainActor in
            localRendererAspectRatio.wrappedValue = ratio
        }
    }

    // Spec: spec/services/calls.md#setupLocalTracks
    func setupLocalTracks(_ incomingCall: Bool, _ call: Call) {
        let pc = call.connection
        let transceivers = call.connection.transceivers
        let audioTrack = call.localAudioTrack
        let videoTrack = call.localVideoTrack

        if incomingCall {
            let micCameraInit = RTCRtpTransceiverInit()
            // streamIds required for old versions which adds tracks from stream, not from track property
            micCameraInit.streamIds = ["micCamera"]

            let screenAudioVideoInit = RTCRtpTransceiverInit()
            screenAudioVideoInit.streamIds = ["screenAudioVideo"]

            // incoming call, no transceivers yet. But they should be added in order: mic, camera, screen audio, screen video
            // mid = 0, mic
            if let audioTrack {
                pc.addTransceiver(with: audioTrack, init: micCameraInit)
            } else {
                pc.addTransceiver(of: .audio, init: micCameraInit)
            }
            // mid = 1, camera
            if let videoTrack {
                pc.addTransceiver(with: videoTrack, init: micCameraInit)
            } else {
                pc.addTransceiver(of: .video, init: micCameraInit)
            }
            // mid = 2, screenAudio
            pc.addTransceiver(of: .audio, init: screenAudioVideoInit)
            // mid = 3, screenVideo
            pc.addTransceiver(of: .video, init: screenAudioVideoInit)
        } else {
            // new version
            if transceivers.count > 2 {
                // Outgoing call. All transceivers are ready. Don't addTrack() because it will create new transceivers, replace existing (nil) tracks
                transceivers
                    .first(where: { elem in mediaSourceFromTransceiverMid(elem.mid) == .mic })?
                    .sender.track = audioTrack
                transceivers
                    .first(where: { elem in mediaSourceFromTransceiverMid(elem.mid) == .camera })?
                    .sender.track = videoTrack
            } else {
                // old version, only two transceivers
                if let audioTrack {
                    pc.add(audioTrack, streamIds: ["micCamera"])
                } else {
                    // it's important to have any track in order to be able to turn it on again (currently it's off)
                    let sender = pc.add(createAudioTrack(), streamIds: ["micCamera"])
                    sender?.track = nil
                }
                if let videoTrack {
                    pc.add(videoTrack, streamIds: ["micCamera"])
                } else {
                    // it's important to have any track in order to be able to turn it on again (currently it's off)
                    let localVideoSource = WebRTCClient.factory.videoSource()
                    let localVideoTrack = WebRTCClient.factory.videoTrack(with: localVideoSource, trackId: "video0")
                    let sender = pc.add(localVideoTrack, streamIds: ["micCamera"])
                    sender?.track = nil
                }
            }
        }
    }

    func mediaSourceFromTransceiverMid(_ mid: String?) -> CallMediaSource {
        switch mid {
        case "0":
            return .mic
        case "1":
            return .camera
        case "2":
            return .screenAudio
        case "3":
            return .screenVideo
        default:
            return .unknown
        }
    }

    // Should be called after local description set
    // Spec: spec/services/calls.md#setupEncryptionForLocalTracks
    func setupEncryptionForLocalTracks(_ call: Call) {
        if let encryptor = call.frameEncryptor {
            call.connection.senders.forEach { $0.setRtcFrameEncryptor(encryptor) }
        }
    }

    func frameDecryptor(_ decryptor: RTCFrameDecryptor, mediaType: RTCRtpMediaType, withFrame encrypted: Data) -> Data? {
        guard encrypted.count > 0 else { return nil }
        let isKeyFrame = encrypted[0] & 1 == 0
        let clearTextBytesSize = mediaType.rawValue == 0 ? 1 : isKeyFrame ? 10 : 3
        guard encrypted.count >= clearTextBytesSize + WebRTCClient.ivTagBytes else { return nil }
        if var key: [CChar] = activeCall?.aesKey?.cString(using: .utf8) {
            let buffer = ensureBufferCapacity(encrypted.count)
            defer { key.withUnsafeMutableBufferPointer { ptr in ptr.baseAddress?.update(repeating: 0, count: ptr.count) } }
            let _ = encrypted.copyBytes(to: buffer.bindMemory(to: UInt8.self))
            let pointer = buffer.baseAddress!
            let decryptSize = encrypted.count - clearTextBytesSize
            guard decryptSize <= Int32.max else { return nil }
            let decryptResult = chat_decrypt_media(&key, pointer.advanced(by: clearTextBytesSize), Int32(decryptSize))
            if let r = decryptResult {
                let err = fromCString(r)
                if err != "" {
                    logger.error("decrypt error: \(err)")
                    return nil
                }
            }
            return Data(bytes: pointer, count: encrypted.count - WebRTCClient.ivTagBytes)
        } else {
            return nil
        }
    }

    func frameEncryptor(_ encryptor: RTCFrameEncryptor, mediaType: RTCRtpMediaType, withFrame unencrypted: Data) -> Data? {
        guard unencrypted.count > 0, let ctrl = chat_ctrl else { return nil }
        let isKeyFrame = unencrypted[0] & 1 == 0
        let clearTextBytesSize = mediaType.rawValue == 0 ? 1 : isKeyFrame ? 10 : 3
        guard unencrypted.count >= clearTextBytesSize else { return nil }
        if var key: [CChar] = activeCall?.aesKey?.cString(using: .utf8) {
            let totalSize = unencrypted.count + WebRTCClient.ivTagBytes
            let buffer = ensureBufferCapacity(totalSize)
            defer { key.withUnsafeMutableBufferPointer { ptr in ptr.baseAddress?.update(repeating: 0, count: ptr.count) } }
            let _ = unencrypted.copyBytes(to: buffer.bindMemory(to: UInt8.self))
            let pointer = buffer.baseAddress!
            let encryptSize = unencrypted.count + WebRTCClient.ivTagBytes - clearTextBytesSize
            guard encryptSize > 0, encryptSize <= Int32.max else { return nil }
            logCrypto("encrypt", chat_encrypt_media(ctrl, &key, pointer.advanced(by: clearTextBytesSize), Int32(encryptSize)))
            return Data(bytes: pointer, count: unencrypted.count + WebRTCClient.ivTagBytes)
        } else {
            return nil
        }
    }

    private func logCrypto(_ op: String, _ r: UnsafeMutablePointer<CChar>?) {
        if let r = r {
            let err = fromCString(r)
            if err != "" {
                logger.error("\(op) error: \(err)")
//            } else {
//                logger.debug("\(op) ok")
            }
        }
    }

    private func ensureBufferCapacity(_ size: Int) -> UnsafeMutableRawBufferPointer {
        if let buf = frameBuffer, buf.count >= size {
            return buf
        }
        frameBuffer?.deallocate()
        let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 16)
        frameBuffer = buf
        return buf
    }

    func addRemoteCameraRenderer(_ renderer: RTCVideoRenderer) {
        if activeCall?.remoteVideoTrack != nil {
            activeCall?.remoteVideoTrack?.add(renderer)
        } else {
            cameraRenderers.append(renderer)
        }
    }

    func removeRemoteCameraRenderer(_ renderer: RTCVideoRenderer) {
        if activeCall?.remoteVideoTrack != nil {
            activeCall?.remoteVideoTrack?.remove(renderer)
        } else {
            cameraRenderers.removeAll(where: { $0.isEqual(renderer) })
        }
    }

    func addRemoteScreenRenderer(_ renderer: RTCVideoRenderer) {
        if activeCall?.remoteScreenVideoTrack != nil {
            activeCall?.remoteScreenVideoTrack?.add(renderer)
        } else {
            screenRenderers.append(renderer)
        }
    }

    func removeRemoteScreenRenderer(_ renderer: RTCVideoRenderer) {
        if activeCall?.remoteScreenVideoTrack != nil {
            activeCall?.remoteScreenVideoTrack?.remove(renderer)
        } else {
            screenRenderers.removeAll(where: { $0.isEqual(renderer) })
        }
    }

    // Spec: spec/services/calls.md#startCaptureLocalVideo
    func startCaptureLocalVideo(_ device: AVCaptureDevice.Position?, _ capturer: RTCVideoCapturer?) {
#if targetEnvironment(simulator)
        guard
            let capturer = (activeCall?.localCamera ?? notConnectedCall?.localCameraAndTrack?.0) as? RTCFileVideoCapturer
        else {
            logger.error("Unable to work with a file capturer")
            return
        }
        capturer.stopCapture()
        // Drag video file named `video.mp4` to `sounds` directory in the project from any other path in filesystem
        capturer.startCapturing(fromFileNamed: "sounds/video.mp4")
#else
        guard
            let capturer = capturer as? RTCCameraVideoCapturer,
            let camera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == device })
        else {
            logger.error("Unable to find a camera or local track")
            return
        }

        let supported = RTCCameraVideoCapturer.supportedFormats(for: camera)
        let height: (AVCaptureDevice.Format) -> Int32 = { (format: AVCaptureDevice.Format) in CMVideoFormatDescriptionGetDimensions(format.formatDescription).height }
        let format = supported.first(where: { height($0) == PXWebRTCConfig.videoCaptureHeight })
                    ?? supported.first(where: { height($0) >= PXWebRTCConfig.videoMinHeight && height($0) < PXWebRTCConfig.videoCaptureHeight })
                    ?? supported.first(where: { height($0) > PXWebRTCConfig.videoCaptureHeight })
        guard
            let format = format,
            let fps = format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })
        else {
            logger.error("Unable to find any format for camera or to choose FPS")
            return
        }

        logger.debug("Format for camera is \(format.description)")

        capturer.stopCapture()
        capturer.startCapture(with: camera,
            format: format,
            fps: Int(min(PXWebRTCConfig.videoMaxFps, Double(fps.maxFrameRate))))
#endif
    }

    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }

    private func createVideoTrackAndStartCapture(_ device: AVCaptureDevice.Position) -> (RTCVideoCapturer, RTCVideoTrack) {
        let localVideoSource = WebRTCClient.factory.videoSource()

        #if targetEnvironment(simulator)
        let localCamera = RTCFileVideoCapturer(delegate: localVideoSource)
        #else
        let localCamera = RTCCameraVideoCapturer(delegate: localVideoSource)
        #endif

        let localVideoTrack = WebRTCClient.factory.videoTrack(with: localVideoSource, trackId: "video0")
        startCaptureLocalVideo(device, localCamera)
        return (localCamera, localVideoTrack)
    }

    // Spec: spec/services/calls.md#endCall
    func endCall() {
        _endCall()
    }

    /// Cleanup after a failed call initialization and return the error response.
    private func pxCleanupAfterFailedCallStart(_ error: Error) async -> WCallResponse {
        await (notConnectedCall?.localCameraAndTrack?.0 as? RTCCameraVideoCapturer)?.stopCapture()
        notConnectedCall = nil
        return .error(message: "failed to initialize call: \(error.localizedDescription)")
    }

    private func _endCall() {
        (notConnectedCall?.localCameraAndTrack?.0 as? RTCCameraVideoCapturer)?.stopCapture()
        notConnectedCall = nil
        
        // Cancel all mute/unmute listener tasks
        for (_, task) in muteUnmuteTasks {
            task.cancel()
        }
        muteUnmuteTasks.removeAll()
        iceRestartInProgress = false
        
        guard let call = activeCall else { return }
        logger.debug("WebRTCClient: ending the call")
        
        // Stop local camera capture
        (call.localCamera as? RTCCameraVideoCapturer)?.stopCapture()
        
        // Remove local tracks from senders
        for sender in call.connection.senders {
            sender.track = nil
        }
        
        // Close connection and clean up delegates
        call.connection.close()
        call.connection.delegate = nil
        call.frameEncryptor?.delegate = nil
        call.frameDecryptor?.delegate = nil
        
        audioSessionToDefaults()
        activeCall = nil
    }

    func untilIceComplete(timeoutMs: UInt64, stepMs: UInt64, action: @escaping () async -> Void) async {
        var t: UInt64 = 0
        repeat {
            _ = try? await Task.sleep(nanoseconds: stepMs * 1000000)
            t += stepMs
            await action()
        } while t < timeoutMs && activeCall != nil && activeCall?.connection.iceGatheringState != .complete
    }
}


extension WebRTC.RTCPeerConnection {
    func mediaConstraints() -> RTCMediaConstraints {
        RTCMediaConstraints(
            mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                                   kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue],
            optionalConstraints: nil)
    }

    func offer() async -> (RTCSessionDescription?, Error?) {
        await withCheckedContinuation { cont in
            offer(for: mediaConstraints()) { (sdp, error) in
                self.processSDP(cont, sdp, error)
            }
        }
    }

    func answer() async -> (RTCSessionDescription?, Error?)  {
        await withCheckedContinuation { cont in
            answer(for: mediaConstraints()) { (sdp, error) in
                self.processSDP(cont, sdp, error)
            }
        }
    }

    private func processSDP(_ cont: CheckedContinuation<(RTCSessionDescription?, Error?), Never>, _ sdp: RTCSessionDescription?, _ error: Error?) {
        if let sdp = sdp {
            self.setLocalDescription(sdp, completionHandler: { (error) in
                if let error = error {
                    cont.resume(returning: (nil, error))
                } else {
                    cont.resume(returning: (sdp, nil))
                }
            })
        } else {
            cont.resume(returning: (nil, error))
        }
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ connection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        logger.debug("Connection new signaling state: \(stateChanged.rawValue)")
    }

    func peerConnection(_ connection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.debug("Connection did add stream")
    }

    func peerConnection(_ connection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.debug("Connection did remove stream")
    }

    func peerConnectionShouldNegotiate(_ connection: RTCPeerConnection) {
        logger.debug("Connection should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        if let track = transceiver.receiver.track {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Doesn't work for outgoing video call (audio in video call works ok still, same as incoming call)
//                if let decryptor = self.activeCall?.frameDecryptor {
//                    transceiver.receiver.setRtcFrameDecryptor(decryptor)
//                }
                let source = self.mediaSourceFromTransceiverMid(transceiver.mid)
                switch source {
                case .mic: self.activeCall?.remoteAudioTrack = track as? RTCAudioTrack
                case .camera:
                    self.activeCall?.remoteVideoTrack = track as? RTCVideoTrack
                    self.cameraRenderers.forEach({ renderer in
                        self.activeCall?.remoteVideoTrack?.add(renderer)
                    })
                    self.cameraRenderers.removeAll()
                case .screenAudio: self.activeCall?.remoteScreenAudioTrack = track as? RTCAudioTrack
                case .screenVideo:
                    self.activeCall?.remoteScreenVideoTrack = track as? RTCVideoTrack
                    self.screenRenderers.forEach({ renderer in
                        self.activeCall?.remoteScreenVideoTrack?.add(renderer)
                    })
                    self.screenRenderers.removeAll()
                case .unknown: ()
                }
            }
            self.setupMuteUnmuteListener(transceiver, track)
        }
    }

    func peerConnection(_ connection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugPrint("Connection new connection state: \(newState.toString() ?? newState.rawValue.description) \(connection.receivers)")

        guard let connectionStateString = newState.toString(),
              let iceConnectionStateString = connection.iceConnectionState.toString(),
              let iceGatheringStateString = connection.iceGatheringState.toString(),
              let signalingStateString = connection.signalingState.toString()
        else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            await sendCallResponse(.init(
                corrId: nil,
                resp: .connection(state: ConnectionState(
                    connectionState: connectionStateString,
                    iceConnectionState: iceConnectionStateString,
                    iceGatheringState: iceGatheringStateString,
                    signalingState: signalingStateString)
                ),
                command: nil)
            )

            switch newState {
            case .checking:
                if let frameDecryptor = activeCall?.frameDecryptor {
                    connection.receivers.forEach { $0.setRtcFrameDecryptor(frameDecryptor) }
                }
                Task { @MainActor in
                    let enableSpeaker: Bool = ChatModel.shared.activeCall?.localMediaSources.hasVideo == true
                    self.setSpeakerEnabledAndConfigureSession(enableSpeaker)
                }
            case .connected: sendConnectedEvent(connection)
            case .disconnected:
                logger.debug("WebRTCClient: disconnected, attempting ICE restart")
                guard !iceRestartInProgress else {
                    logger.debug("WebRTCClient: ICE restart already in progress, skipping")
                    return
                }
                iceRestartInProgress = true
                let constraints = RTCMediaConstraints(mandatoryConstraints: ["IceRestart": kRTCMediaConstraintsValueTrue],
                                                      optionalConstraints: nil)
                Task { [weak self] in
                    defer { self?.iceRestartInProgress = false }
                    guard let self, self.activeCall != nil else { return }
                    let result: (RTCSessionDescription?, Error?) = await withCheckedContinuation { cont in
                        connection.offer(for: constraints) { sdp, error in
                            cont.resume(returning: (sdp, error))
                        }
                    }
                    guard self.activeCall != nil else { return }
                    if let sdp = result.0 {
                        await MainActor.run {
                            guard self.activeCall != nil else { return }
                            self.activeCall?.connection.setLocalDescription(sdp) { [weak self] _ in
                                Task { [weak self] in
                                    guard let self, self.activeCall != nil else { return }
                                    let encodedOffer = compressToBase64(input: encodeJSON(
                                        CustomRTCSessionDescription(type: sdp.type.toSdpType(), sdp: sdp.sdp)
                                    ))
                                    let candidates = await self.getInitialIceCandidates()
                                    let encodedCandidates = compressToBase64(input: encodeJSON(candidates))
                                    await self.sendCallResponse(.init(
                                        corrId: nil,
                                        resp: .ok,
                                        command: .offer(offer: encodedOffer,
                                                        iceCandidates: encodedCandidates,
                                                        media: (activeCall?.localVideoTrack != nil ? .video : .audio))
                                    ))
                                }
                            }
                        }
                    } else if let error = result.1 {
                        logger.error("ICE restart offer error: \(error)")
                        self.endCall()
                    }
                }
            case .failed: endCall()
            default: ()
            }
        }
    }

    func peerConnection(_ connection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        logger.debug("connection new gathering state: \(newState.toString() ?? "" + newState.rawValue.description)")
    }

    func peerConnection(_ connection: RTCPeerConnection, didGenerate candidate: WebRTC.RTCIceCandidate) {
//        logger.debug("Connection generated candidate \(candidate.debugDescription)")
        Task { [weak self] in
            await self?.activeCall?.iceCandidates.append(candidate.toCandidate(nil, nil))
        }
    }

    func peerConnection(_ connection: RTCPeerConnection, didRemove candidates: [WebRTC.RTCIceCandidate]) {
        logger.debug("Connection did remove candidates")
    }

    func peerConnection(_ connection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ connection: RTCPeerConnection,
                        didChangeLocalCandidate local: WebRTC.RTCIceCandidate,
                        remoteCandidate remote: WebRTC.RTCIceCandidate,
                        lastReceivedMs lastDataReceivedMs: Int32,
                        changeReason reason: String) {
//        logger.debug("Connection changed candidate \(reason) \(remote.debugDescription) \(remote.description)")
    }

    func sendConnectedEvent(_ connection: WebRTC.RTCPeerConnection) {
        connection.statistics { (stats: RTCStatisticsReport) in
            stats.statistics.values.forEach { stat in
//                logger.debug("Stat \(stat.debugDescription)")
                if stat.type == "candidate-pair", stat.values["state"] as? String == "succeeded",
                   let localId = stat.values["localCandidateId"] as? String,
                   let remoteId = stat.values["remoteCandidateId"] as? String,
                   let localStats = stats.statistics[localId],
                   let remoteStats = stats.statistics[remoteId]
                {
                    Task {
                        await self.sendCallResponse(.init(
                            corrId: nil,
                            resp: .connected(connectionInfo: ConnectionInfo(
                                localCandidate: POPOPXSwitch.RTCIceCandidate(
                                    candidateType: RTCIceCandidateType.init(rawValue: localStats.values["candidateType"] as? String ?? ""),
                                    protocol: localStats.values["protocol"] as? String,
                                    sdpMid: nil,
                                    sdpMLineIndex: nil,
                                    candidate: ""
                                ),
                                remoteCandidate: POPOPXSwitch.RTCIceCandidate(
                                    candidateType: RTCIceCandidateType.init(rawValue: remoteStats.values["candidateType"] as? String ?? ""),
                                    protocol: remoteStats.values["protocol"] as? String,
                                    sdpMid: nil,
                                    sdpMLineIndex: nil,
                                    candidate: ""))),
                            command: nil)
                        )
                    }
                }
            }
        }
    }
}

extension WebRTCClient {
    static func isAuthorized(for type: AVMediaType) async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: type)
        var isAuthorized = status == .authorized
        if status == .notDetermined {
            isAuthorized = await AVCaptureDevice.requestAccess(for: type)
        }
        return isAuthorized
    }

    @MainActor static func showUnauthorizedAlert(for type: AVMediaType) {
        if type == .audio {
            AlertManager.shared.showAlert(Alert(
                title: Text(NSLocalizedString("no_permission_speech", comment: "")),
                message: Text(NSLocalizedString("no_permission_speech_msg", comment: "")),
                primaryButton: .default(Text(NSLocalizedString("open_settings", comment: ""))) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                },
                secondaryButton: .cancel()
            ))
        } else if type == .video {
            AlertManager.shared.showAlert(Alert(
                title: Text(NSLocalizedString("no_permission_video", comment: "")),
                message: Text(NSLocalizedString("no_permission_video_msg", comment: "")),
                primaryButton: .default(Text(NSLocalizedString("open_settings", comment: ""))) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                },
                secondaryButton: .cancel()
            ))
        }
    }

    func setSpeakerEnabledAndConfigureSession( _ enabled: Bool, skipExternalDevice: Bool = false) {
        logger.debug("WebRTCClient: configuring session with speaker enabled \(enabled)")
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.rtcAudioSession.lockForConfiguration()
            defer {
                self.rtcAudioSession.unlockForConfiguration()
            }
            do {
                let hasExternalAudioDevice = self.rtcAudioSession.session.hasExternalAudioDevice()
                if enabled {
                    try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.defaultToSpeaker, .allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP])
                    try self.rtcAudioSession.setMode(AVAudioSession.Mode.videoChat.rawValue)
                    if hasExternalAudioDevice && !skipExternalDevice, let preferred = self.rtcAudioSession.session.preferredInputDevice() {
                        try self.rtcAudioSession.setPreferredInput(preferred)
                    } else {
                        try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                    }
                } else {
                    try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP])
                    try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
                    try self.rtcAudioSession.overrideOutputAudioPort(.none)
                }
                if hasExternalAudioDevice && !skipExternalDevice {
                    logger.debug("WebRTCClient: configuring session with external device available, skip configuring speaker")
                }
                try self.rtcAudioSession.setActive(true)
                logger.debug("WebRTCClient: configuring session with speaker enabled \(enabled) success")
            } catch let error {
                logger.debug("Error configuring AVAudioSession: \(error)")
            }
        }
    }

    func audioSessionToDefaults() {
        logger.debug("WebRTCClient: audioSession to defaults")
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.rtcAudioSession.lockForConfiguration()
            defer {
                self.rtcAudioSession.unlockForConfiguration()
            }
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.ambient.rawValue)
                try self.rtcAudioSession.setMode(AVAudioSession.Mode.default.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
                try self.rtcAudioSession.setActive(false)
                logger.debug("WebRTCClient: audioSession to defaults success")
            } catch let error {
                logger.debug("Error configuring AVAudioSession with defaults: \(error)")
            }
        }
    }

    @MainActor
    func setAudioEnabled(_ enabled: Bool) {
        if activeCall != nil {
            activeCall?.localAudioTrack = nil
            activeCall?.localAudioTrack = enabled ? createAudioTrack() : nil
            activeCall?.connection.transceivers.first(where: { t in mediaSourceFromTransceiverMid(t.mid) == .mic })?.sender.track = activeCall?.localAudioTrack
        } else if notConnectedCall != nil {
            notConnectedCall?.audioTrack = enabled ? createAudioTrack() : nil
        }
        ChatModel.shared.activeCall?.localMediaSources.mic = enabled
    }

    @MainActor
    func setCameraEnabled(_ enabled: Bool) {
        if let call = activeCall {
            if enabled {
                (call.localCamera as? RTCCameraVideoCapturer)?.stopCapture()
                activeCall?.localCamera = nil
                if call.localVideoTrack == nil {
                    let device = activeCall?.device ?? notConnectedCall?.device ?? .front
                    let (camera, track) = createVideoTrackAndStartCapture(device)
                    activeCall?.localCamera = camera
                    activeCall?.localVideoTrack = track
                }
            } else {
                (call.localCamera as? RTCCameraVideoCapturer)?.stopCapture()
                activeCall?.localCamera = nil
                activeCall?.localVideoTrack = nil
            }
            call.connection.transceivers
                .first(where: { t in mediaSourceFromTransceiverMid(t.mid) == .camera })?
                .sender.track = activeCall?.localVideoTrack
            ChatModel.shared.activeCall?.localMediaSources.camera = activeCall?.localVideoTrack != nil
        } else if let call = notConnectedCall {
            if enabled {
                (call.localCameraAndTrack?.0 as? RTCCameraVideoCapturer)?.stopCapture()
                let device = activeCall?.device ?? notConnectedCall?.device ?? .front
                notConnectedCall?.localCameraAndTrack = createVideoTrackAndStartCapture(device)
            } else {
                (call.localCameraAndTrack?.0 as? RTCCameraVideoCapturer)?.stopCapture()
                notConnectedCall?.localCameraAndTrack = nil
            }
            ChatModel.shared.activeCall?.localMediaSources.camera = notConnectedCall?.localCameraAndTrack != nil
        }
    }

    func flipCamera() {
        let device = activeCall?.device ?? notConnectedCall?.device
        if activeCall != nil {
            activeCall?.device = device == .front ? .back : .front
        } else {
            notConnectedCall?.device = device == .front ? .back : .front
        }
        startCaptureLocalVideo(
            activeCall?.device ?? notConnectedCall?.device,
            (activeCall?.localCamera ?? notConnectedCall?.localCameraAndTrack?.0) as? RTCCameraVideoCapturer
        )
    }
}

extension AVAudioSession {
    func hasExternalAudioDevice() -> Bool {
        availableInputs?.allSatisfy({ $0.portType == .builtInMic }) != true
    }

    func preferredInputDevice() -> AVAudioSessionPortDescription? {
//        logger.debug("Preferred input device: \(String(describing: self.availableInputs?.filter({ $0.portType != .builtInMic })))")
        return availableInputs?.filter({ $0.portType != .builtInMic }).last
    }
}

struct CustomRTCSessionDescription: Codable {
    public var type: RTCSdpType?
    public var sdp: String?
}

enum RTCSdpType: String, Codable {
    case answer
    case offer
    case pranswer
    case rollback
}

extension POPOPXSwitch.RTCIceCandidate {
    func toWebRTCCandidate() -> WebRTC.RTCIceCandidate {
        WebRTC.RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: Int32(sdpMLineIndex ?? 0),
            sdpMid: sdpMid
        )
    }
}

extension WebRTC.RTCIceCandidate {
    func toCandidate(_ candidateType: RTCIceCandidateType?, _ protocol: String?) -> POPOPXSwitch.RTCIceCandidate {
        POPOPXSwitch.RTCIceCandidate(
            candidateType: candidateType,
            protocol: `protocol`,
            sdpMid: sdpMid,
            sdpMLineIndex: Int(sdpMLineIndex),
            candidate: sdp
        )
    }
}


extension [POPOPXSwitch.RTCIceServer] {
    func toWebRTCIceServers() -> [WebRTC.RTCIceServer] {
        self.map {
            WebRTC.RTCIceServer(
                urlStrings: $0.urls,
                username: $0.username,
                credential: $0.credential
            ) }
    }
}

extension RTCSdpType {
    func toWebRTCSdpType() -> WebRTC.RTCSdpType {
        switch self {
        case .answer: return WebRTC.RTCSdpType.answer
        case .offer: return WebRTC.RTCSdpType.offer
        case .pranswer: return WebRTC.RTCSdpType.prAnswer
        case .rollback: return WebRTC.RTCSdpType.rollback
        }
    }
}

extension WebRTC.RTCSdpType {
    func toSdpType() -> RTCSdpType {
        switch self {
        case .answer: return RTCSdpType.answer
        case .offer: return RTCSdpType.offer
        case .prAnswer: return RTCSdpType.pranswer
        case .rollback: return RTCSdpType.rollback
        default: return RTCSdpType.answer // should never be here
        }
    }
}

extension RTCPeerConnectionState {
    func toString() -> String? {
        switch self {
        case .new: return "new"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .failed: return"failed"
        case .disconnected: return "disconnected"
        case .closed: return "closed"
        default: return nil // unknown
        }
    }
}

extension RTCIceConnectionState {
    func toString() -> String? {
        switch self {
        case .new: return "new"
        case .checking: return "checking"
        case .connected: return "connected"
        case .completed: return "completed"
        case .failed: return "failed"
        case .disconnected: return "disconnected"
        case .closed: return "closed"
        default: return nil // unknown or unused on the other side
        }
    }
}

extension RTCIceGatheringState {
    func toString() -> String? {
        switch self {
        case .new: return "new"
        case .gathering: return "gathering"
        case .complete: return "complete"
        default: return nil // unknown
        }
    }
}

extension RTCSignalingState {
    func toString() -> String? {
        switch self {
        case .stable: return "stable"
        case .haveLocalOffer: return "have-local-offer"
        case .haveLocalPrAnswer: return "have-local-pranswer"
        case .haveRemoteOffer: return "have-remote-offer"
        case .haveRemotePrAnswer: return "have-remote-pranswer"
        case .closed: return "closed"
        default: return nil // unknown
        }
    }
}

// MARK: - POPOPX
extension WebRTCClient {
    static let pxComponentTag: String = PXWebRTCConfig.componentTag
    static let pxVideoCaptureHeight: Int32 = PXWebRTCConfig.videoCaptureHeight
    static let pxVideoMinHeight: Int32 = PXWebRTCConfig.videoMinHeight
    static let pxVideoMaxFps: Double = PXWebRTCConfig.videoMaxFps
    static let pxIceInitialTimeoutMs: UInt64 = PXWebRTCConfig.iceInitialTimeoutMs
    static let pxIceStepMs: UInt64 = PXWebRTCConfig.iceStepMs
    static let pxIceRestartTimeoutMs: UInt64 = PXWebRTCConfig.iceRestartTimeoutMs
    static let pxIceRestartStepMs: UInt64 = PXWebRTCConfig.iceRestartStepMs
}
