//
//  PXCallModelTypes.swift
//  POPOPXSwitch
//
//  Call-related value types: CallDirection, CallState, CallMediaSources.
//  Split from PXCallModel.swift so these types live in POPOPXSwitch
//  and are accessible to the test target at runtime.
//
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation
import SwiftUI

public enum CallDirection {
    case incoming
    case outgoing
}

public enum CallState {
    case waitCapabilities   // outgoing call started
    case invitationSent     // outgoing call - sent invitation
    case invitationAccepted // incoming call started
    case offerSent          // incoming - webrtc started and offer sent
    case offerReceived      // outgoing - webrtc offer received via API
    case answerReceived     // incoming - webrtc answer received via API
    case negotiated         // outgoing - webrtc offer processed and answer sent, incoming - webrtc answer processed
    case connected
    case ended

    public var text: LocalizedStringKey {
        switch self {
        case .waitCapabilities: return "starting…"
        case .invitationSent: return "waiting for answer…"
        case .invitationAccepted: return "starting…"
        case .offerSent: return "waiting for confirmation…"
        case .offerReceived: return "received answer…"
        case .answerReceived: return "received confirmation…"
        case .negotiated: return "connecting…"
        case .connected: return "connected"
        case .ended: return "ended"
        }
    }
}

public struct CallMediaSources: Equatable, Codable {
    public var mic: Bool = false
    public var camera: Bool = false
    public var screenAudio: Bool = false
    public var screenVideo: Bool = false

    public init(mic: Bool = false, camera: Bool = false, screenAudio: Bool = false, screenVideo: Bool = false) {
        self.mic = mic
        self.camera = camera
        self.screenAudio = screenAudio
        self.screenVideo = screenVideo
    }

    public var hasVideo: Bool { get { camera || screenVideo } }
}
