//
//  PXActiveCall.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 05/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/calls.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import WebKit
import POPOPXSwitch
import AVFoundation

// MARK: - POPOPX Layout Configuration
private enum PXActiveCallConfig {
    static let localVideoWidthRatio: CGFloat = 0.3
    static let localVideoCornerRadius: CGFloat = 10
    static let localVideoPadding: CGFloat = 17
    static let localVideoPortraitTallRatio: CGFloat = 1.33
    static let localVideoPortraitWideRatio: CGFloat = 1.33
    static let profileImageSize: CGFloat = 192
    static let whiteTextOpacity: Double = 0.8
    static let buttonBarCornerRadius: CGFloat = 20
    static let overlayMaterialOpacity: Double = 0.3
    static let callButtonBorderWidth: CGFloat = 0.75
    static let endCallColor: Color = QuantumColors.error
    static let controlButtonSize: CGFloat = 60
    static let buttonBarHorizontalPadding: CGFloat = 20
    static let buttonBarVerticalPadding: CGFloat = 12
    static let buttonBarBottomPadding: CGFloat = 16
    static let buttonBarMaxWidth: CGFloat = 440
    static let videoInfoHorizontalPadding: CGFloat = 16
    static let videoInfoVerticalPadding: CGFloat = 10
    static let audioInfoHorizontalPadding: CGFloat = 16
    static let audioInfoVerticalPadding: CGFloat = 10
    static let chevronIconWidth: CGFloat = 10
    static let chevronIconHeight: CGFloat = 18
    static let callNameShadowOpacity: Double = 0.4
    static let callNameShadowRadius: CGFloat = 10
    static let callNameShadowY: CGFloat = 2
    static let darkThemeShadowOpacity: Double = 0.3
    static let darkThemeShadowRadius: CGFloat = 8
    static let controlButtonVideoBackgroundOpacity: Double = 0.2
    static let controlButtonLightBackgroundOpacity: Double = 0.2
    static let borderGradientDarkOpacityPrimary: Double = 0.4
    static let borderGradientDarkOpacitySecondary: Double = 0.25
    static let borderGradientLightOpacityPrimary: Double = 0.5
    static let borderGradientLightOpacitySecondary: Double = 0.2
    static let buttonShadowDarkOpacity: Double = 0.15
    static let buttonShadowRadius: CGFloat = 8
    static let buttonShadowY: CGFloat = 4
    static let audioPickerOpacity: Double = 0.8
    static let audioPickerScale: CGFloat = 2
    static let audioPickerPadding: CGFloat = 10
    static let collapseButtonOpacity: Double = 0.8
    static let backgroundHitTestOpacity: Double = 0.000001
}

// MARK: - POPOPX View Model
@MainActor
private struct PXActiveCallViewModel {
    let call: Call
    let client: WebRTCClient?
    let isCollapsed: Bool

    var hasActiveVideo: Bool {
        call.hasVideo && client != nil
    }

    var shouldShowOverlay: Bool {
        !isCollapsed
    }

    var callStateText: LocalizedStringKey {
        call.callState.text
    }

    var encryptionStatusText: LocalizedStringKey {
        call.encryptionStatus
    }

    var contactDisplayName: String {
        call.contact.chatViewName
    }

    var shouldShowFlipCamera: Bool {
        call.localMediaSources.camera
    }

    var isMicEnabled: Bool {
        call.localMediaSources.mic
    }

    var isCameraEnabled: Bool {
        call.localMediaSources.camera
    }

    var peerHasVideo: Bool {
        call.peerMediaSources.hasVideo
    }
}

// Spec: spec/services/calls.md#PXActiveCall
struct PXActiveCall: View {
    @EnvironmentObject var m: ChatModel
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var call: Call
    @Environment(\.scenePhase) var scenePhase
    @State private var client: WebRTCClient? = nil
    @State private var localRendererAspectRatio: CGFloat? = nil
    @State var remoteContentMode: UIView.ContentMode = .scaleAspectFill
    @Binding var canConnectCall: Bool
    @State var prevColorScheme: ColorScheme = .dark
    @State var pipShown = false
    @State var wasConnected = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .bottom) {
                pxVideoLayer
                pxOverlayLayer
            }
        }
        .allowsHitTesting(!m.activeCallViewIsCollapsed)
        .opacity(m.activeCallViewIsCollapsed ? 0 : 1)
        .onAppear { pxOnViewAppear() }
        .task { await askRequiredPermissions() }
        .onChange(of: canConnectCall) { _, _ in
            logger.debug("PXActiveCall: canConnectCall changed to \(canConnectCall)")
            createWebRTCClient()
        }
        .onChange(of: m.activeCallViewIsCollapsed) { _, _ in hideKeyboard() }
        .onDisappear { pxOnViewDisappear() }
        .background(m.activeCallViewIsCollapsed ? .clear : .black)
        .preferredColorScheme(m.activeCallViewIsCollapsed || CallController.useCallKit() ? prevColorScheme : .dark)
        .popopxBranded()
    }

    // MARK: - POPOPX Extracted View Builders

    @ViewBuilder
    private var pxVideoLayer: some View {
        if let client = client, call.hasVideo {
            GeometryReader { g in
                let width = g.size.width * PXActiveCallConfig.localVideoWidthRatio
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .center) {
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(PXActiveCallConfig.backgroundHitTestOpacity))
                    .allowsHitTesting(false)

                    CallViewRemote(client: client, call: call, activeCallViewIsCollapsed: Binding(get: { m.callState.activeCallViewIsCollapsed }, set: { m.callState.activeCallViewIsCollapsed = $0 }), contentMode: $remoteContentMode, pipShown: $pipShown)
                        .onTapGesture {
                            remoteContentMode = remoteContentMode == .scaleAspectFill ? .scaleAspectFit : .scaleAspectFill
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(NSLocalizedString("call_toggle_video_fit", comment: "Toggle video fit accessibility label"))

                    pxLocalVideoPane(width: width, geoWidth: g.size.width, geoHeight: g.size.height)
                }
            }
        }
    }

    @ViewBuilder
    private func pxLocalVideoPane(width: CGFloat, geoWidth: CGFloat, geoHeight: CGFloat) -> some View {
        Group {
            let localVideoTrack = client?.activeCall?.localVideoTrack ?? client?.notConnectedCall?.localCameraAndTrack?.1
            if localVideoTrack != nil {
                CallViewLocal(client: client!, localRendererAspectRatio: $localRendererAspectRatio, pipShown: $pipShown)
                    .onDisappear { localRendererAspectRatio = nil }
            } else {
                Rectangle().fill(.black)
            }
        }
        .cornerRadius(PXActiveCallConfig.localVideoCornerRadius)
        .frame(width: width, height: pxLocalVideoHeight(width: width, geoWidth: geoWidth, geoHeight: geoHeight))
        .padding([.top, .trailing], PXActiveCallConfig.localVideoPadding)
    }

    private func pxLocalVideoHeight(width: CGFloat, geoWidth: CGFloat, geoHeight: CGFloat) -> CGFloat {
        if localRendererAspectRatio == nil {
            return geoWidth < geoHeight ? width * PXActiveCallConfig.localVideoPortraitTallRatio : width / PXActiveCallConfig.localVideoPortraitWideRatio
        }
        return width / max(localRendererAspectRatio ?? 1, 0.01)
    }

    @ViewBuilder
    private var pxOverlayLayer: some View {
        if let call = m.activeCall, let client = client, (!pipShown || !call.hasVideo) {
            ActiveCallOverlay(call: call, client: client)
        }
    }

    // MARK: - POPOPX Lifecycle Handlers

    private func pxOnViewAppear() {
        logger.debug("PXActiveCall: appear client is nil \(client == nil), scenePhase \(String(describing: scenePhase)), canConnectCall \(canConnectCall)")
        AppDelegate.keepScreenOn(true)
        createWebRTCClient()
        dismissAllSheets()
        hideKeyboard()
        prevColorScheme = colorScheme
    }

    private func pxOnViewDisappear() {
        logger.debug("PXActiveCall: disappear")
        client?.endCall()
        CallSoundsPlayer.shared.stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.soloAmbient)
        } catch {
            logger.error("Failed to reset audio session category: \(error.localizedDescription)")
        }
        if wasConnected {
            CallSoundsPlayer.shared.vibrate(long: true)
        }
        Task { await m.callCommand.setClient(nil) }
        AppDelegate.keepScreenOn(false)
        client = nil
    }

    private func createWebRTCClient() {
        if client == nil && canConnectCall {
            client = WebRTCClient({ msg in await MainActor.run { processRtcMessage(msg: msg) } }, $localRendererAspectRatio)
            Task {
                await m.callCommand.setClient(client)
            }
        }
    }

    @MainActor
    private func processRtcMessage(msg: WVAPIMessage) {
        if call == m.activeCall,
           let call = m.activeCall,
           let client = client {
            logger.debug("PXActiveCall: response \(msg.resp.respType)")
            switch msg.resp {
            case let .capabilities(capabilities):
                pxHandleCapabilities(call, client, capabilities)
            case let .offer(offer, iceCandidates, capabilities):
                pxHandleOffer(call, offer, iceCandidates, capabilities)
            case let .answer(answer, iceCandidates):
                pxHandleAnswer(call, answer, iceCandidates)
            case let .ice(iceCandidates):
                pxHandleIce(call, iceCandidates)
            case let .connection(state):
                pxHandleConnectionState(call, client, state)
            case let .connected(connectionInfo):
                pxHandleConnected(call, connectionInfo)
            case let .peerMedia(source, enabled):
                pxHandlePeerMedia(call, source, enabled)
            case .ended:
                pxHandleEnded(call, client)
            case .ok:
                pxHandleOk(call, client, msg)
            case let .error(message):
                logger.debug("PXActiveCall: command error: \(message)")
                AlertManager.shared.showAlert(Alert(title: Text(NSLocalizedString("Error", comment: "")), message: Text(message)))
            case let .invalid(type):
                logger.debug("PXActiveCall: invalid response: \(type)")
                AlertManager.shared.showAlert(Alert(title: Text(NSLocalizedString("Invalid response", comment: "")), message: Text(type)))
            }
        }
    }

    // MARK: - POPOPX RTC Message Handlers

    private func pxHandleCapabilities(_ call: Call, _ client: WebRTCClient, _ capabilities: CallCapabilities) {
        let callType = CallType(media: call.initialCallType, capabilities: capabilities)
        Task {
            do {
                try await apiSendCallInvitation(call.contact, callType)
            } catch {
                logger.error("apiSendCallInvitation \(responseError(error))")
            }
            await MainActor.run {
                call.callState = .invitationSent
                call.localCapabilities = capabilities
            }
            if call.hasVideo && !AVAudioSession.sharedInstance().hasExternalAudioDevice() {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, options: [.allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP])
                } catch {
                    logger.error("PXActiveCall: failed to set AVAudioSession category to .playback: \(error.localizedDescription)")
                }
            }
            CallSoundsPlayer.shared.startConnectingCallSound()
            activeCallWaitDeliveryReceipt()
        }
    }

    private func pxHandleOffer(_ call: Call, _ offer: String, _ iceCandidates: String, _ capabilities: CallCapabilities) {
        Task {
            do {
                try await apiSendCallOffer(call.contact, offer, iceCandidates,
                                           media: call.initialCallType, capabilities: capabilities)
            } catch {
                logger.error("apiSendCallOffer \(responseError(error))")
            }
            await MainActor.run {
                call.callState = .offerSent
                call.localCapabilities = capabilities
            }
        }
    }

    private func pxHandleAnswer(_ call: Call, _ answer: String, _ iceCandidates: String) {
        Task {
            do {
                try await apiSendCallAnswer(call.contact, answer, iceCandidates)
            } catch {
                logger.error("apiSendCallAnswer \(responseError(error))")
            }
            await MainActor.run {
                call.callState = .negotiated
                CallSoundsPlayer.shared.stop()
            }
        }
    }

    private func pxHandleIce(_ call: Call, _ iceCandidates: String) {
        Task {
            do {
                try await apiSendCallExtraInfo(call.contact, iceCandidates)
            } catch {
                logger.error("apiSendCallExtraInfo \(responseError(error))")
            }
        }
    }

    private func pxHandleConnectionState(_ call: Call, _ client: WebRTCClient, _ state: ConnectionState) {
        if let callStatus = WebRTCCallStatus.init(rawValue: state.connectionState),
           case .connected = callStatus {
            call.direction == .outgoing
            ? CallController.shared.reportOutgoingCall(call: call, connectedAt: nil)
            : CallController.shared.reportIncomingCall(call: call, connectedAt: nil)
            call.callState = .connected
            call.connectedAt = .now
            if !wasConnected {
                CallSoundsPlayer.shared.vibrate(long: false)
                wasConnected = true
            }
        }
        if state.connectionState == "closed" {
            closeCallView(client)
            if let callUUID = m.activeCall?.callUUID {
                CallController.shared.endCall(callUUID: callUUID)
            }
            m.activeCall = nil
            m.activeCallViewIsCollapsed = false
        }
        Task {
            do {
                try await apiCallStatus(call.contact, state.connectionState)
            } catch {
                logger.error("apiCallStatus \(responseError(error))")
            }
        }
    }

    private func pxHandleConnected(_ call: Call, _ connectionInfo: ConnectionInfo) {
        call.callState = .connected
        call.connectionInfo = connectionInfo
        call.connectedAt = .now
        if !wasConnected {
            CallSoundsPlayer.shared.vibrate(long: false)
            wasConnected = true
        }
    }

    private func pxHandlePeerMedia(_ call: Call, _ source: CallMediaSource, _ enabled: Bool) {
        switch source {
        case .mic: call.peerMediaSources.mic = enabled
        case .camera: call.peerMediaSources.camera = enabled
        case .screenAudio: call.peerMediaSources.screenAudio = enabled
        case .screenVideo: call.peerMediaSources.screenVideo = enabled
        case .unknown: ()
        }
    }

    private func pxHandleEnded(_ call: Call, _ client: WebRTCClient) {
        closeCallView(client)
        call.callState = .ended
        if let uuid = call.callUUID {
            CallController.shared.endCall(callUUID: uuid)
        }
    }

    private func pxHandleOk(_ call: Call, _ client: WebRTCClient, _ msg: WVAPIMessage) {
        switch msg.command {
        case .answer:
            call.callState = .negotiated
        case .end:
            closeCallView(client)
            m.activeCall = nil
            m.activeCallViewIsCollapsed = false
        default: ()
        }
    }

    private func activeCallWaitDeliveryReceipt() {
        ChatReceiver.shared.messagesChannel = { [weak call] msg in
            guard let call, let activeCall = ChatModel.shared.activeCall, activeCall.callState == .invitationSent else {
                ChatReceiver.shared.messagesChannel = nil
                return
            }
            if case let .result(.chatItemsStatusesUpdated(_, chatItems), _) = msg,
               chatItems.contains(where: { ci in
                   ci.chatInfo.id == call.contact.id &&
                   ci.chatItem.content.isSndCall &&
                   ci.chatItem.meta.itemStatus.isSndRcvd
               }) {
                CallSoundsPlayer.shared.startInCallSound()
                ChatReceiver.shared.messagesChannel = nil
            }
        }
    }

    private func askRequiredPermissions() async {
        let mic = await WebRTCClient.isAuthorized(for: .audio)
        await MainActor.run {
            call.localMediaSources.mic = mic
        }
        let cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        var camera = call.initialCallType == .audio || cameraAuthorized
        if call.initialCallType == .video && !cameraAuthorized {
            camera = await WebRTCClient.isAuthorized(for: .video)
            await MainActor.run {
                if camera, let client {
                    client.setCameraEnabled(true)
                }
            }
        }
        if !mic || !camera {
            WebRTCClient.showUnauthorizedAlert(for: !mic ? .audio : .video)
        }
    }

    private func closeCallView(_ client: WebRTCClient) {
        if m.activeCall != nil {
            m.showCallView = false
        }
    }
}

// Spec: spec/services/calls.md#ActiveCallOverlay
struct ActiveCallOverlay: View {
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject var call: Call
    var client: WebRTCClient
    @ObservedObject private var deviceManager = CallAudioDeviceManager.shared

    var body: some View {
        VStack {
            pxCallInfoSection
            Spacer()
            pxControlButtonBar
        }
        .frame(maxWidth: .infinity)
        .popopxBranded()
        .onAppear { deviceManager.start() }
        .onDisappear { deviceManager.stop() }
    }

    // MARK: - POPOPX Extracted View Builders

    @ViewBuilder
    private var pxCallInfoSection: some View {
        switch call.hasVideo {
        case true:
            videoCallInfoView(call)
                .foregroundColor(.white)
                .opacity(isInDarkTheme() ? PXActiveCallConfig.whiteTextOpacity : PXActiveCallConfig.whiteTextOpacity - 0.1)
                .padding(.horizontal, PXActiveCallConfig.videoInfoHorizontalPadding)
                .padding(.vertical, PXActiveCallConfig.videoInfoVerticalPadding)
        case false:
            pxAudioCallLayout
        }
    }

    @ViewBuilder
    private var pxAudioCallLayout: some View {
        ZStack(alignment: .topLeading) {
            Button {
                chatModel.activeCallViewIsCollapsed = true
            } label: {
                Label(NSLocalizedString("call_back_button", comment: "Back button label"), systemImage: "chevron.left")
                    .foregroundColor(.white.opacity(PXActiveCallConfig.collapseButtonOpacity))
                    .padding()
            }
            .accessibilityLabel(NSLocalizedString("Collapse call view", comment: ""))

            VStack {
                ProfileImage(imageStr: call.contact.profile.image, size: PXActiveCallConfig.profileImageSize)
                audioCallInfoView(call)
            }
            .foregroundColor(.white)
            .opacity(isInDarkTheme() ? PXActiveCallConfig.whiteTextOpacity : PXActiveCallConfig.whiteTextOpacity - 0.1)
            .padding(.horizontal, PXActiveCallConfig.audioInfoHorizontalPadding)
            .padding(.vertical, PXActiveCallConfig.audioInfoVerticalPadding)
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var pxControlButtonBar: some View {
        HStack {
            toggleMicButton()
            Spacer()
            audioDeviceButton()
            Spacer()
            endCallButton()
            Spacer()
            if call.localMediaSources.camera {
                flipCameraButton()
            } else {
                Color.clear.frame(width: PXActiveCallConfig.controlButtonSize, height: PXActiveCallConfig.controlButtonSize)
            }
            Spacer()
            toggleCameraButton()
        }
        .padding(.horizontal, PXActiveCallConfig.buttonBarHorizontalPadding)
        .padding(.vertical, PXActiveCallConfig.buttonBarVerticalPadding)
        .padding(.bottom, PXActiveCallConfig.buttonBarBottomPadding)
        .frame(maxWidth: PXActiveCallConfig.buttonBarMaxWidth, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: PXActiveCallConfig.buttonBarCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(PXActiveCallConfig.overlayMaterialOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PXActiveCallConfig.buttonBarCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            darkThemeAccentColor().opacity(isInDarkTheme() ? PXActiveCallConfig.borderGradientDarkOpacityPrimary : 0.1),
                            neonGradientSecondary().opacity(isInDarkTheme() ? PXActiveCallConfig.borderGradientDarkOpacitySecondary : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: PXActiveCallConfig.callButtonBorderWidth
                )
        )
    }

    // MARK: - POPOPX Call Info Views

    private func audioCallInfoView(_ call: Call) -> some View {
        VStack {
            Text(call.contact.chatViewName)
                .font(.title.weight(.heavy))
                .lineLimit(1)
                .foregroundStyle(LinearGradient(
                    colors: [darkThemeAccentColor(), neonGradientSecondary()],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .shadow(color: darkThemeAccentColor().opacity(PXActiveCallConfig.callNameShadowOpacity), radius: PXActiveCallConfig.callNameShadowRadius, x: 0, y: PXActiveCallConfig.callNameShadowY)
                .frame(maxWidth: .infinity, alignment: .center)
            Group {
                Text(call.callState.text)
                HStack {
                    Text(call.encryptionStatus)
                    if let connInfo = call.connectionInfo {
                        Text(verbatim: "(\(connInfo.text))")
                    }
                }
            }
            .font(.system(.subheadline))
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func videoCallInfoView(_ call: Call) -> some View {
        VStack {
            Button {
                chatModel.activeCallViewIsCollapsed = true
            } label: {
                HStack(alignment: .center, spacing: PXActiveCallConfig.videoInfoHorizontalPadding) {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .frame(width: PXActiveCallConfig.chevronIconWidth, height: PXActiveCallConfig.chevronIconHeight)
                    Text(call.contact.chatViewName)
                        .lineLimit(1)
                        .font(.title.weight(.heavy))
                        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXActiveCallConfig.darkThemeShadowOpacity) : .clear, radius: PXActiveCallConfig.darkThemeShadowRadius, x: 0, y: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityLabel(NSLocalizedString("Collapse video call", comment: ""))

            Group {
                Text(call.callState.text)
                HStack {
                    Text(call.encryptionStatus)
                    if let connInfo = call.connectionInfo {
                        Text(verbatim: "(\(connInfo.text))")
                    }
                }
            }
            .font(.system(.subheadline))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - POPOPX Control Buttons

    private func endCallButton() -> some View {
        let cc = CallController.shared
        return callButton("phone.down.fill", PXActiveCallConfig.endCallColor, padding: 10) {
            if let uuid = call.callUUID {
                cc.endCall(callUUID: uuid)
            } else {
                cc.endCall(call: call) {}
            }
        }
        .accessibilityLabel(NSLocalizedString("call_end_call", comment: "End call accessibility label"))
    }

    private func toggleMicButton() -> some View {
        controlButton(call, call.localMediaSources.mic ? "mic.fill" : "mic.slash", padding: 14) {
            Task {
                if await WebRTCClient.isAuthorized(for: .audio) {
                    client.setAudioEnabled(!call.localMediaSources.mic)
                } else { WebRTCClient.showUnauthorizedAlert(for: .audio) }
            }
        }
        .accessibilityLabel(NSLocalizedString("call_mute_microphone", comment: "Mute microphone accessibility label"))
    }

    func audioDeviceButton() -> some View {
        Group {
            if deviceManager.availableInputs.allSatisfy({ $0.portType == .builtInMic }) {
                toggleSpeakerButton()
            } else {
                audioDevicePickerButton()
            }
        }
        .onChange(of: call.localMediaSources.hasVideo) { _, hasVideo in
            let current = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType
            let speakerEnabled = current == .builtInSpeaker
            let receiverEnabled = current == .builtInReceiver
            if !speakerEnabled && hasVideo && receiverEnabled {
                client.setSpeakerEnabledAndConfigureSession(!speakerEnabled, skipExternalDevice: true)
                call.speakerEnabled = !speakerEnabled
            }
        }
    }

    private func toggleSpeakerButton() -> some View {
        controlButton(call, !call.peerMediaSources.mic ? "speaker.slash" : call.speakerEnabled ? "speaker.wave.2.fill" : "speaker.wave.1.fill", padding: !call.peerMediaSources.mic ? 16 : call.speakerEnabled ? 15 : 17) {
            let speakerEnabled = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType == .builtInSpeaker
            client.setSpeakerEnabledAndConfigureSession(!speakerEnabled)
            call.speakerEnabled = !speakerEnabled
        }
        .accessibilityLabel(NSLocalizedString("call_speaker", comment: "Speaker accessibility label"))
        .onAppear {
            deviceManager.call = call
        }
    }

    private func toggleCameraButton() -> some View {
        controlButton(call, call.localMediaSources.camera ? "video.fill" : "video.slash", padding: call.localMediaSources.camera ? 16 : 14) {
            Task {
                if await WebRTCClient.isAuthorized(for: .video) {
                    client.setCameraEnabled(!call.localMediaSources.camera)
                } else { WebRTCClient.showUnauthorizedAlert(for: .video) }
            }
        }
        .accessibilityLabel(NSLocalizedString("call_camera", comment: "Camera accessibility label"))
        .disabled(call.initialCallType == .audio && client.activeCall?.peerHasOldVersion == true)
    }

    private func flipCameraButton() -> some View {
        controlButton(call, "arrow.triangle.2.circlepath", padding: 12) {
            Task {
                if await WebRTCClient.isAuthorized(for: .video) {
                    client.flipCamera()
                }
            }
        }
        .accessibilityLabel(NSLocalizedString("call_flip_camera", comment: "Flip camera accessibility label"))
    }

    // MARK: - POPOPX Button Builders

    private func controlButton(_ call: Call, _ imageName: String, padding: CGFloat, _ perform: @escaping () -> Void) -> some View {
        callButton(imageName, call.peerMediaSources.hasVideo ? Color.black.opacity(PXActiveCallConfig.controlButtonVideoBackgroundOpacity) : Color.white.opacity(PXActiveCallConfig.controlButtonLightBackgroundOpacity), padding: padding, perform)
    }

    private func audioDevicePickerButton() -> some View {
        AudioDevicePicker()
            .opacity(isInDarkTheme() ? PXActiveCallConfig.audioPickerOpacity : PXActiveCallConfig.audioPickerOpacity - 0.1)
            .scaleEffect(PXActiveCallConfig.audioPickerScale)
            .padding(PXActiveCallConfig.audioPickerPadding)
            .frame(width: PXActiveCallConfig.controlButtonSize, height: PXActiveCallConfig.controlButtonSize)
            .background(call.peerMediaSources.hasVideo ? Color.black.opacity(PXActiveCallConfig.controlButtonVideoBackgroundOpacity) : Color.white.opacity(PXActiveCallConfig.controlButtonLightBackgroundOpacity))
            .clipShape(.circle)
    }

    private func callButton(_ imageName: String, _ background: Color, padding: CGFloat, _ perform: @escaping () -> Void) -> some View {
        Button {
            perform()
        } label: {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .foregroundColor(whiteColorWithAlpha)
                .padding(padding)
                .frame(width: PXActiveCallConfig.controlButtonSize, height: PXActiveCallConfig.controlButtonSize)
                .background(background)
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: isInDarkTheme()
                            ? [darkThemeAccentColor().opacity(PXActiveCallConfig.borderGradientDarkOpacityPrimary), neonGradientSecondary().opacity(PXActiveCallConfig.borderGradientDarkOpacitySecondary)]
                            : [Color.white.opacity(PXActiveCallConfig.borderGradientLightOpacityPrimary), Color.white.opacity(PXActiveCallConfig.borderGradientLightOpacitySecondary)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: PXActiveCallConfig.callButtonBorderWidth
                    )
                )
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXActiveCallConfig.buttonShadowDarkOpacity) : .clear, radius: PXActiveCallConfig.buttonShadowRadius, x: 0, y: PXActiveCallConfig.buttonShadowY)
        }
        .clipShape(.circle)
    }

    private var whiteColorWithAlpha: Color {
        get { Color.white.opacity(PXActiveCallConfig.whiteTextOpacity) }
    }
}

struct ActiveCallOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group{
            ActiveCallOverlay(call: Call(direction: .incoming, contact: Contact.sampleData, callUUID: UUID().uuidString.lowercased(), callState: .offerSent, initialCallType: .video), client: WebRTCClient({ _ in }, Binding.constant(nil)))
                .background(.black)
            ActiveCallOverlay(call: Call(direction: .incoming, contact: Contact.sampleData, callUUID: UUID().uuidString.lowercased(), callState: .offerSent, initialCallType: .audio), client: WebRTCClient({ _ in }, Binding.constant(nil)))
                .background(.black)
        }
    .previewEnvironment()
    }
}

// MARK: - POPOPX
extension PXActiveCall {
    static let pxComponentTag: String = "PX_ACTIVE_CALL_VIEW_MAIN"
}

// MARK: - POPOPX
extension ActiveCallOverlay {
    static let pxComponentTag: String = "PX_ACTIVE_CALL_VIEW"
    static let pxProfileImageSize: CGFloat = PXActiveCallConfig.profileImageSize
    static let pxWhiteTextOpacity: Double = PXActiveCallConfig.whiteTextOpacity
    static let pxButtonBarCornerRadius: CGFloat = PXActiveCallConfig.buttonBarCornerRadius
    static let pxOverlayMaterialOpacity: Double = PXActiveCallConfig.overlayMaterialOpacity
    static let pxCallButtonBorderWidth: CGFloat = PXActiveCallConfig.callButtonBorderWidth
    static let pxEndCallColor: Color = PXActiveCallConfig.endCallColor
}
