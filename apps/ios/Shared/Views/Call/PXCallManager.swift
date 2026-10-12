//
//  CallManager.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 22/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXCallConfig {
    static let pxFeatureKey = "PX_FEATURE_ENABLED"
    static let pxActiveCallDelayFactor: Double = 1.2
    static let pxNoCallDelay: Double = 0.0
    static let pxDelayBaseSeconds: Double = 1.0
    static let pxTag: String = "PX_CALL_MANAGER"
}

private let pxCallFeatureEnabled = UserDefaults.standard.bool(forKey: PXCallConfig.pxFeatureKey)

@MainActor
class CallManager {

    // MARK: - Outgoing call lifecycle

    func newOutgoingCall(_ contact: Contact, _ media: CallMediaType) -> String {
        let pxUUID = UUID().uuidString.lowercased()
        logger.debug("\(PXCallConfig.pxTag): [newOutgoingCall] contactId=\(contact.id), media=\(String(describing: media)), uuid=\(pxUUID)")
        let call = pxBuildOutgoingCall(contact: contact, uuid: pxUUID, media: media)
        ChatModel.shared.activeCall = call
        return pxUUID
    }

    func startOutgoingCall(callUUID: String) -> Bool {
        let m = ChatModel.shared
        guard let pxCall = m.activeCall, pxCall.callUUID == callUUID else {
            logger.debug("\(PXCallConfig.pxTag): [startOutgoingCall] no active call matching uuid=\(callUUID)")
            return false
        }
        logger.debug("\(PXCallConfig.pxTag): [startOutgoingCall] starting call uuid=\(callUUID)")
        pxActivateCallView(m)
        pxSendCapabilities(m, media: pxCall.initialCallType)
        return true
    }

    // MARK: - Incoming call lifecycle

    func answerIncomingCall(callUUID: String) -> Bool {
        guard let pxInvitation = pxFindInvitation(callUUID) else {
            logger.debug("\(PXCallConfig.pxTag): [answerIncomingCall] no invitation found for uuid=\(callUUID)")
            return false
        }
        answerIncomingCall(invitation: pxInvitation)
        return true
    }

    func answerIncomingCall(invitation: RcvCallInvitation) {
        let m = ChatModel.shared
        m.callInvitations.removeValue(forKey: invitation.contact.id)
        let call = pxBuildIncomingCall(invitation: invitation)
        let useRelay = UserDefaults.standard.bool(forKey: DEFAULT_WEBRTC_POLICY_RELAY)
        let iceServers = getIceServers()
        logger.debug("answerIncomingCall useRelay: \(useRelay)")
        logger.debug("answerIncomingCall iceServers: count=\(iceServers?.count ?? 0)")
        let pxDelay = Self.pxAcceptDelay(hasActiveCall: m.activeCall != nil)
        logger.debug("\(PXCallConfig.pxTag): [answerIncomingCall] delay=\(pxDelay)")
        pxScheduleAccept(m, call: call, delay: pxDelay, media: invitation.callType.media, aesKey: invitation.sharedKey, iceServers: iceServers, relay: useRelay)
    }

    // MARK: - Media control

    func enableMedia(source: CallMediaSource, enable: Bool, callUUID: String) -> Bool {
        guard let pxCall = ChatModel.shared.activeCall, pxCall.callUUID == callUUID else { return false }
        logger.debug("\(PXCallConfig.pxTag): [enableMedia] source=\(String(describing: source)), enable=\(enable)")
        let m = ChatModel.shared
        Task { await m.callCommand.processCommand(.media(source: source, enable: enable)) }
        return true
    }

    // MARK: - End call

    func endCall(callUUID: String, completed: @escaping (Bool) -> Void) {
        if let call = ChatModel.shared.activeCall, call.callUUID == callUUID {
            endCall(call: call) { completed(true) }
        } else if let invitation = pxFindInvitation(callUUID) {
            endCall(invitation: invitation) { completed(true) }
        } else {
            completed(false)
        }
    }

    func endCall(call: Call, completed: @escaping () -> Void) {
        let m = ChatModel.shared
        if case .ended = call.callState {
            logger.debug("CallManager.endCall: call ended")
            pxResetCallState(m, completed: completed)
        } else {
            logger.debug("CallManager.endCall: ending call...")
            Task {
                await m.callCommand.processCommand(.end)
                await MainActor.run { pxResetCallState(m, completed: completed) }
                do {
                    try await apiEndCall(call.contact)
                } catch {
                    logger.error("CallController.provider apiEndCall error: \(responseError(error))")
                }
            }
        }
    }

    func endCall(invitation: RcvCallInvitation, completed: @escaping () -> Void) {
        ChatModel.shared.callInvitations.removeValue(forKey: invitation.contact.id)
        Task {
            do {
                try await apiRejectCall(invitation.contact)
            } catch {
                logger.error("CallController.provider apiRejectCall error: \(responseError(error))")
            }
            completed()
        }
    }

    // MARK: - POPOPX private helpers

    private func pxBuildOutgoingCall(contact: Contact, uuid: String, media: CallMediaType) -> Call {
        let call = Call(direction: .outgoing, contact: contact, callUUID: uuid, callState: .waitCapabilities, initialCallType: media)
        call.speakerEnabled = media == .video
        return call
    }

    private func pxBuildIncomingCall(invitation: RcvCallInvitation) -> Call {
        let call = Call(
            direction: .incoming,
            contact: invitation.contact,
            callUUID: invitation.callUUID,
            callState: .invitationAccepted,
            initialCallType: invitation.callType.media,
            sharedKey: invitation.sharedKey
        )
        call.speakerEnabled = invitation.callType.media == .video
        return call
    }

    private func pxActivateCallView(_ m: ChatModel) {
        m.showCallView = true
    }

    private func pxSendCapabilities(_ m: ChatModel, media: CallMediaType) {
        Task { await m.callCommand.processCommand(.capabilities(media: media)) }
    }

    private func pxResetCallState(_ m: ChatModel, completed: () -> Void) {
        m.activeCall = nil
        m.activeCallViewIsCollapsed = false
        m.showCallView = false
        completed()
    }

    private func pxScheduleAccept(_ m: ChatModel, call: Call, delay: Double, media: CallMediaType, aesKey: String?, iceServers: [RTCIceServer]?, relay: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak m] in
            guard let m else { return }
            m.activeCall = call
            m.showCallView = true
            Task {
                await m.callCommand.processCommand(.start(
                    media: media,
                    aesKey: aesKey,
                    iceServers: iceServers,
                    relay: relay
                ))
            }
        }
    }

    private func pxFindInvitation(_ callUUID: String) -> RcvCallInvitation? {
        if let (_, invitation) = ChatModel.shared.callInvitations.first(where: { (_, inv) in inv.callUUID == callUUID }) {
            return invitation
        }
        return nil
    }

    private func getCallInvitation(_ callUUID: String) -> RcvCallInvitation? {
        pxFindInvitation(callUUID)
    }
}

// MARK: - POPOPX
extension CallManager {
    static let pxComponentTag: String = PXCallConfig.pxTag
    static let pxActiveCallAcceptDelay: Double = PXCallConfig.pxDelayBaseSeconds * PXCallConfig.pxActiveCallDelayFactor
    static let pxMultiCallAcceptDelay: Double = PXCallConfig.pxNoCallDelay

    static func pxAcceptDelay(hasActiveCall: Bool) -> Double {
        let pxDelay = hasActiveCall ? pxActiveCallAcceptDelay : pxMultiCallAcceptDelay
        if pxCallFeatureEnabled {
            logger.debug("\(PXCallConfig.pxTag): [pxAcceptDelay] feature enabled, delay=\(pxDelay)")
        }
        return pxDelay
    }
}
