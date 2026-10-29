//
//  PXCallController.swift
//  POPOPX (iOS)
//
//  Call session lifecycle, CallKit integration and PushKit voIP handling.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/calls.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
@preconcurrency import CallKit
import StoreKit
@preconcurrency import PushKit
import AVFoundation
import POPOPXSwitch
import WebRTC

// MARK: - Storefront country code cache (thread-safe, async-resolved)

private let _storefrontLock = NSLock()
private var _storefrontCountryCode: String? = nil

private func _updateStorefrontCountryCode(_ code: String) {
    _storefrontLock.lock()
    _storefrontCountryCode = code
    _storefrontLock.unlock()
}

// MARK: - POPOPX Call Timing Constants

// POPOPX: all magic numbers for call lifecycle timing extracted to named constants
private enum PXCallTiming {
    /// Milliseconds to wait for chat startup before failing a CallKit action
    static let chatStartupTimeoutMs: UInt64 = 30_000
    /// Polling interval while waiting for chat startup
    static let chatStartupPollMs: UInt64 = 500
    /// Delay before suspending chat after all calls end (seconds)
    static let suspendDelaySeconds: Double = 3.5
    /// Number of iterations for audio device preference retry loop
    static let audioRetryCount: Int = 5
    /// Delay before reporting an expired call as ended (seconds)
    static let expiredCallReportDelay: Double = 1.2
    /// Base nanosecond sleep increment for audio retry backoff
    static let retrySleepBaseNanos: UInt64 = 280_000_000
    /// Milliseconds per second conversion factor
    static let msToNanos: UInt64 = 1_000_000
}

// POPOPX: audio session category options for different call modes
private enum PXCallAudioConfig {
    /// Options for video calls (includes speaker default)
    static let videoCallOptions: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP
    ]
    /// Options for audio-only calls
    static let audioCallOptions: AVAudioSession.CategoryOptions = [
        .mixWithOthers, .allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP
    ]
}

// Spec: spec/services/calls.md#CallController
@MainActor
class CallController: NSObject, @preconcurrency CXProviderDelegate, @preconcurrency PKPushRegistryDelegate, ObservableObject {
    static let shared = CallController()
    // POPOPX: SKPaymentQueue deprecated in iOS 27.0 SDK; Storefront.current is async
    // so we cache the country code with a safe default (false = CallKit enabled)
    // and resolve it asynchronously on first access.
    nonisolated static let isInChina: Bool = {
        _storefrontLock.lock()
        if _storefrontCountryCode == nil {
            _storefrontCountryCode = ""
            Task {
                let code = await Storefront.current?.countryCode ?? ""
                _updateStorefrontCountryCode(code)
            }
        }
        let code = _storefrontCountryCode ?? ""
        _storefrontLock.unlock()
        return code == "CHN"
    }()
    nonisolated static func useCallKit() -> Bool { !isInChina && callKitEnabledGroupDefault.get() }

    /// CallKit provider configured with video support and POPOPX icon
    private let pxProvider = CXProvider(configuration: {
        let pxCfg = CXProviderConfiguration()
        pxCfg.supportsVideo = true
        pxCfg.supportedHandleTypes = [.generic]
        pxCfg.includesCallsInRecents = UserDefaults.standard.bool(forKey: DEFAULT_CALL_KIT_CALLS_IN_RECENTS)
        pxCfg.maximumCallGroups = 1
        pxCfg.maximumCallsPerCallGroup = 1
        pxCfg.iconTemplateImageData = UIImage(named: CallController.pxIconTemplateName)?.pngData()
        return pxCfg
    }())
    private let pxCallController = CXCallController()
    private let pxCallManager = CallManager()
    /// Dedicated queue for audio session operations to avoid blocking main
    private let pxAudioQueue = DispatchQueue(label: CallController.pxQueueLabel)
    @Published var activeCallInvitation: RcvCallInvitation?
    var shouldSuspendChat: Bool = false
    private var pxSuspendWorkItem: DispatchWorkItem? = nil
    var fulfillOnConnect: CXAnswerCallAction? = nil

    // PKPushRegistry is used from notification service extension
    private let pxRegistry = PKPushRegistry(queue: nil)

    override init() {
        super.init()
        pxProvider.setDelegate(self, queue: nil)
        pxRegistry.delegate = self
        pxRegistry.desiredPushTypes = [.voIP]
    }

    func providerDidReset(_ provider: CXProvider) {
        logger.debug("CallController.providerDidReset")
        if ChatModel.shared.activeCall != nil {
            ChatModel.shared.activeCall = nil
            logger.debug("CallController.providerDidReset: cleared active call")
        }
        activeCallInvitation = nil
        fulfillOnConnect?.fail()
        fulfillOnConnect = nil
        shouldSuspendChat = false
        pxSuspendWorkItem?.cancel()
        pxSuspendWorkItem = nil
    }

    // Spec: spec/services/calls.md#CXStartCallAction
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        logger.debug("CallController.provider CXStartCallAction")
        if pxCallManager.startOutgoingCall(callUUID: action.callUUID.uuidString.lowercased()) {
            action.fulfill()
            pxProvider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
        } else {
            action.fail()
        }
    }

    // Spec: spec/services/calls.md#CXAnswerCallAction
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        logger.debug("CallController.provider CXAnswerCallAction")
        Task {
            let pxChatReady = await pxWaitForChatStartup()
            logger.debug("CallController chat started \(pxChatReady) \(ChatModel.shared.chatInitialized) \(ChatModel.shared.chatRunning == true) \(String(describing: AppChatState.shared.value))")
            if !pxChatReady {
                action.fail()
                return
            }
            if !ChatModel.shared.callInvitations.values.contains(where: { pxInv in pxInv.callUUID == action.callUUID.uuidString.lowercased() }) {
                try? await justRefreshCallInvitations()
                logger.debug("CallController: updated call invitations chat")
            }
            await MainActor.run {
                logger.debug("CallController.provider will answer on call")

                if pxCallManager.answerIncomingCall(callUUID: action.callUUID.uuidString.lowercased()) {
                    logger.debug("CallController.provider answered on call")
                    // WebRTC call should be in connected state to fulfill.
                    // Otherwise no audio and mic working on lockscreen
                    fulfillOnConnect = action
                } else {
                    logger.debug("CallController.provider will fail the call")
                    action.fail()
                }
            }
        }
    }

    // Spec: spec/services/calls.md#CXEndCallAction
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        logger.debug("CallController.provider CXEndCallAction")
        // Should be nil here if connection was in connected state
        fulfillOnConnect?.fail()
        fulfillOnConnect = nil
        pxCallManager.endCall(callUUID: action.callUUID.uuidString.lowercased()) { pxOk in
            if pxOk {
                action.fulfill()
            } else {
                action.fail()
            }
            self.pxSuspendAfterCallEnd()
        }
    }

    // Spec: spec/services/calls.md#CXSetMutedCallAction
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if pxCallManager.enableMedia(source: .mic, enable: !action.isMuted, callUUID: action.callUUID.uuidString.lowercased()) {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        logger.debug("timed out: \(String(describing: action))")
        action.fulfill()
    }

    // POPOPX: audio session activation with dedicated queue and retry loop
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        logger.debug("CallController: activating audioSession and audio in WebRTCClient")
        let pxHasVideo = ChatModel.shared.activeCall?.hasVideo == true
        pxAudioQueue.async {
            RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
            RTCAudioSession.sharedInstance().isAudioEnabled = true
            do {
                if pxHasVideo {
                    try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: PXCallAudioConfig.videoCallOptions)
                } else {
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: PXCallAudioConfig.audioCallOptions)
                }
                logger.debug("audioSession category set")
                try audioSession.setActive(true)
                logger.debug("audioSession activated")
            } catch {
                logger.error("failed activating audio session")
            }
        }
        // POPOPX: incremental backoff for audio device preference setting
        Task {
            for pxIter in 0 ..< PXCallTiming.audioRetryCount {
                try? await Task.sleep(nanoseconds: UInt64(pxIter) * PXCallTiming.retrySleepBaseNanos)
                if let pxPreferred = audioSession.preferredInputDevice() {
                    await MainActor.run {
                        do { try audioSession.setPreferredInput(pxPreferred) }
                        catch { logger.error("Failed to set preferred audio input: \(error)") }
                    }
                } else if pxHasVideo {
                    await MainActor.run {
                        do { try audioSession.overrideOutputAudioPort(.speaker) }
                        catch { logger.error("Failed to override audio output port: \(error)") }
                    }
                }
            }
        }
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        logger.debug("CallController: deactivating audioSession and audio in WebRTCClient")
        pxAudioQueue.async {
            RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
            RTCAudioSession.sharedInstance().isAudioEnabled = false
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                logger.debug("audioSession deactivated")
            } catch {
                logger.error("failed deactivating audio session")
            }
        }
        pxSuspendAfterCallEnd()
    }

    // POPOPX: suspend chat after call ends with configurable delay
    private func pxSuspendAfterCallEnd() {
        if shouldSuspendChat {
            // The delay allows to accept the second call before suspending a chat
            // see `.onChange(of: scenePhase)` in POPOPXApp
            DispatchQueue.main.asyncAfter(deadline: .now() + PXCallTiming.suspendDelaySeconds) { [weak self] in
                logger.debug("CallController: shouldSuspendChat \(String(describing: self?.shouldSuspendChat))")
                if ChatModel.shared.activeCall == nil && self?.shouldSuspendChat == true {
                    self?.shouldSuspendChat = false
                    suspendChat()
                    BGManager.shared.schedule()
                }
            }
        }
    }

    // POPOPX: wait for chat to initialize with timeout
    private func pxWaitForChatStartup() async -> Bool {
        logger.debug("CallController waiting until chat started")
        var pxEllapsed: UInt64 = 0
        repeat {
            if ChatModel.shared.chatInitialized, ChatModel.shared.chatRunning == true, case .active = AppChatState.shared.value {
                return true
            }
            _ = try? await Task.sleep(nanoseconds: PXCallTiming.chatStartupPollMs * PXCallTiming.msToNanos)
            pxEllapsed += PXCallTiming.chatStartupPollMs
        } while pxEllapsed < PXCallTiming.chatStartupTimeoutMs
        return false
    }

    @objc(pushRegistry:didUpdatePushCredentials:forType:)
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        logger.debug("CallController: didUpdate push credentials for type \(type.rawValue)")
    }

    // Spec: spec/services/calls.md#pushRegistryDidReceive
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        logger.debug("CallController: did receive push with type \(type.rawValue)")
        guard type == .voIP else {
            completion()
            return
        }
        guard AppChatState.shared.value != .stopped else {
            self.pxReportExpiredCall(payload: payload, completion)
            return
        }
        // Extract the call information from the push notification payload
        let pxChatModel = ChatModel.shared
        if let pxContactId = payload.dictionaryPayload["contactId"] as? String,
           let pxDisplayName = payload.dictionaryPayload["displayName"] as? String,
           let pxCallUUID = payload.dictionaryPayload["callUUID"] as? String,
           let pxUUID = UUID(uuidString: pxCallUUID),
           let pxCallTsInterval = payload.dictionaryPayload["callTs"] as? TimeInterval,
           let pxMediaStr = payload.dictionaryPayload["media"] as? String,
           let pxMedia = CallMediaType(rawValue: pxMediaStr) {
            let pxUpdate = self.pxBuildCallUpdate(pxContactId, pxDisplayName, pxMedia)
            let pxCallTs = Date(timeIntervalSince1970: pxCallTsInterval)
            if pxCallTs.timeIntervalSinceNow >= -CallController.pxCallExpirySeconds {
                logger.debug("CallController: report pushkit call via CallKit")
                self.pxProvider.reportNewIncomingCall(with: pxUUID, update: pxUpdate) { pxError in
                    if pxError != nil {
                        Task { @MainActor in
                            pxChatModel.callInvitations.removeValue(forKey: pxContactId)
                        }
                    }
                    // Tell PushKit that the notification is handled.
                    completion()
                }
            } else {
                logger.debug("CallController will expire call 1")
                self.pxReportExpiredCall(update: pxUpdate, completion)
            }
        } else {
            logger.debug("CallController will expire call 2")
            self.pxReportExpiredCall(payload: payload, completion)
        }
        return
    }

    // This function fulfils the requirement to always report a call when PushKit notification is received,
    // even when there is no more active calls by the time PushKit payload is processed.
    // See the note in the bottom of this article:
    // https://developer.apple.com/documentation/pushkit/pkpushregistrydelegate/2875784-pushregistry
    private func pxReportExpiredCall(update: CXCallUpdate, _ completion: @escaping () -> Void) {
        logger.debug("CallController: report expired pushkit call via CallKit")
        let pxUUID = UUID()
        pxProvider.reportNewIncomingCall(with: pxUUID, update: update) { pxError in
            if pxError == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + PXCallTiming.expiredCallReportDelay) {
                    self.pxProvider.reportCall(with: pxUUID, endedAt: nil, reason: .remoteEnded)
                }
            }
            completion()
        }
    }

    private func pxReportExpiredCall(payload: PKPushPayload, _ completion: @escaping () -> Void) {
        let pxUpdate = CXCallUpdate()
        let pxDisplayName = payload.dictionaryPayload["displayName"] as? String
        let pxMedia = payload.dictionaryPayload["media"] as? String
        pxUpdate.localizedCallerName = pxDisplayName ?? NSLocalizedString("Unknown caller", comment: "callkit banner")
        pxUpdate.hasVideo = pxMedia == CallMediaType.video.rawValue
        pxReportExpiredCall(update: pxUpdate, completion)
    }

    // Spec: spec/services/calls.md#reportNewIncomingCall
    func reportNewIncomingCall(invitation: RcvCallInvitation, completion: @escaping @Sendable (Error?) -> Void) {
        logger.debug("CallController.reportNewIncomingCall, UUID=\(String(describing: invitation.callUUID))")
        if CallController.useCallKit(), let pxCallUUID = invitation.callUUID, let pxUUID = UUID(uuidString: pxCallUUID) {
            if invitation.callTs.timeIntervalSinceNow >= -CallController.pxCallExpirySeconds {
                let pxUpdate = pxBuildCallUpdate(invitation: invitation)
                pxProvider.reportNewIncomingCall(with: pxUUID, update: pxUpdate, completion: completion)
            }
        } else {
            NtfManager.shared.notifyCallInvitation(invitation)
            if invitation.callTs.timeIntervalSinceNow >= -180 {
                activeCallInvitation = invitation
            }
        }
    }

    // POPOPX: build CXCallUpdate from an invitation
    private func pxBuildCallUpdate(invitation: RcvCallInvitation) -> CXCallUpdate {
        let pxUpdate = CXCallUpdate()
        pxUpdate.remoteHandle = CXHandle(type: .generic, value: invitation.contact.id)
        pxUpdate.hasVideo = invitation.callType.media == .video
        pxUpdate.localizedCallerName = invitation.contact.displayName
        return pxUpdate
    }

    // POPOPX: build CXCallUpdate from raw payload fields
    private func pxBuildCallUpdate(_ pxContactId: String, _ pxDisplayName: String, _ pxMedia: CallMediaType) -> CXCallUpdate {
        let pxUpdate = CXCallUpdate()
        pxUpdate.remoteHandle = CXHandle(type: .generic, value: pxContactId)
        pxUpdate.hasVideo = pxMedia == .video
        pxUpdate.localizedCallerName = pxDisplayName
        return pxUpdate
    }

    func reportIncomingCall(call: Call, connectedAt dateConnected: Date?) {
        logger.debug("CallController: reporting incoming call connected")
        if CallController.useCallKit() {
            // Fulfilling this action only after connect, otherwise there are no audio and mic on lockscreen
            fulfillOnConnect?.fulfill()
            fulfillOnConnect = nil
        }
    }

    // Spec: spec/services/calls.md#reportOutgoingCall
    func reportOutgoingCall(call: Call, connectedAt dateConnected: Date?) {
        logger.debug("CallController: reporting outgoing call connected")
        if CallController.useCallKit(), let pxCallUUID = call.callUUID, let pxUUID = UUID(uuidString: pxCallUUID) {
            pxProvider.reportOutgoingCall(with: pxUUID, connectedAt: dateConnected)
        }
    }

    func reportCallRemoteEnded(invitation: RcvCallInvitation) {
        logger.debug("CallController: reporting remote ended")
        if CallController.useCallKit(), let pxCallUUID = invitation.callUUID, let pxUUID = UUID(uuidString: pxCallUUID) {
            pxProvider.reportCall(with: pxUUID, endedAt: nil, reason: .remoteEnded)
        } else if invitation.contact.id == activeCallInvitation?.contact.id {
            activeCallInvitation = nil
        }
    }

    func reportCallRemoteEnded(call: Call) {
        logger.debug("CallController: reporting remote ended")
        if CallController.useCallKit(), let pxCallUUID = call.callUUID, let pxUUID = UUID(uuidString: pxCallUUID) {
            pxProvider.reportCall(with: pxUUID, endedAt: nil, reason: .remoteEnded)
        }
    }

    func startCall(_ contact: Contact, _ media: CallMediaType) {
        logger.debug("CallController.startCall")
        let pxNewUUID = pxCallManager.newOutgoingCall(contact, media)
        guard let pxUUID = UUID(uuidString: pxNewUUID) else {
            return
        }
        if CallController.useCallKit() {
            let pxHandle = CXHandle(type: .generic, value: contact.id)
            let pxAction = CXStartCallAction(call: pxUUID, handle: pxHandle)
            pxAction.isVideo = media == .video
            pxRequestTransaction(with: pxAction) {
                let pxUpdate = CXCallUpdate()
                pxUpdate.remoteHandle = CXHandle(type: .generic, value: contact.id)
                pxUpdate.hasVideo = media == .video
                pxUpdate.localizedCallerName = contact.displayName
                self.pxProvider.reportCall(with: pxUUID, updated: pxUpdate)
            }
        } else if pxCallManager.startOutgoingCall(callUUID: pxNewUUID) {
            logger.debug("CallController.startCall: call started")
        } else {
            logger.error("CallController.startCall: no active call")
        }
    }

    func answerCall(invitation: RcvCallInvitation) {
        logger.debug("CallController: answering a call")
        if CallController.useCallKit(), let pxCallUUID = invitation.callUUID, let pxUUID = UUID(uuidString: pxCallUUID) {
            pxRequestTransaction(with: CXAnswerCallAction(call: pxUUID))
        } else {
            pxCallManager.answerIncomingCall(invitation: invitation)
        }
        if invitation.contact.id == self.activeCallInvitation?.contact.id {
            self.activeCallInvitation = nil
        }
    }

    func endCall(callUUID: String) {
        let pxUUID = UUID(uuidString: callUUID)
        logger.debug("CallController: ending the call with UUID \(callUUID)")
        if CallController.useCallKit() {
            if let pxUUID {
                pxRequestTransaction(with: CXEndCallAction(call: pxUUID))
            }
        } else {
            pxCallManager.endCall(callUUID: callUUID) { pxOk in
                if pxOk {
                    logger.debug("CallController.endCall: call ended")
                } else {
                    logger.error("CallController.endCall: no active call pr call invitation to end")
                }
            }
        }
    }

    func endCall(invitation: RcvCallInvitation) {
        logger.debug("CallController: ending the call with invitation")
        pxCallManager.endCall(invitation: invitation) { [weak self] in
            if invitation.contact.id == self?.activeCallInvitation?.contact.id {
                DispatchQueue.main.async {
                    self?.activeCallInvitation = nil
                }
            }
        }
    }

    func endCall(call: Call, completed: @escaping () -> Void) {
        logger.debug("CallController: ending the call with call instance")
        pxCallManager.endCall(call: call, completed: completed)
    }

    func callAction(invitation: RcvCallInvitation, action: NtfCallAction) {
        switch action {
        case .accept: answerCall(invitation: invitation)
        case .reject: endCall(invitation: invitation)
        }
    }

    func showInRecents(_ show: Bool) {
        let pxConf = pxProvider.configuration
        pxConf.includesCallsInRecents = show
        pxProvider.configuration = pxConf
    }

    // Spec: spec/services/calls.md#hasActiveCalls
    func hasActiveCalls() -> Bool {
        pxCallController.callObserver.calls.count > 0
    }

    // POPOPX: request a CallKit transaction with error logging
    private func pxRequestTransaction(with action: CXAction, onSuccess: @escaping () -> Void = {}) {
        pxCallController.request(CXTransaction(action: action)) { pxError in
            if let pxError = pxError {
                logger.error("CallController.requestTransaction error requesting transaction: \(pxError.localizedDescription)")
            } else {
                logger.debug("CallController.requestTransaction requested transaction successfully")
                onSuccess()
            }
        }
    }
}

// MARK: - POPOPX
extension CallController {
    static let pxComponentTag: String = "PX_CALL_CONTROLLER"
    static let pxQueueLabel = "chat.popopx.audiosession"
    static let pxCallExpirySeconds: TimeInterval = 180
    static let pxSleepMultiplier: UInt64 = PXCallTiming.retrySleepBaseNanos
    static let pxIconTemplateName = "popopx_app_icon"
    static var pxHasActiveCall: Bool { shared.activeCallInvitation != nil || ChatModel.shared.activeCall != nil }
    static var pxActiveCallUUID: String? { shared.activeCallInvitation?.callUUID ?? ChatModel.shared.activeCall?.callUUID }
}
