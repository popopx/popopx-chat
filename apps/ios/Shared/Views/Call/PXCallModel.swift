//
//  CallModel.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 03/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import SwiftUI
import POPOPXSwitch
import AVFoundation

@MainActor
class Call: ObservableObject, Equatable {
    let contactApiId: Int64
    nonisolated static func == (lhs: Call, rhs: Call) -> Bool {
        lhs.contactApiId == rhs.contactApiId
    }

    var direction: CallDirection
    var contact: Contact
    var callUUID: String?
    var initialCallType: CallMediaType
    @Published var localMediaSources: CallMediaSources
    @Published var callState: CallState
    @Published var localCapabilities: CallCapabilities?
    @Published var peerMediaSources: CallMediaSources = CallMediaSources()
    @Published var sharedKey: String?
    @Published var speakerEnabled = false
    @Published var connectionInfo: ConnectionInfo?
    @Published var connectedAt: Date? = nil

    init(
        direction: CallDirection,
        contact: Contact,
        callUUID: String?,
        callState: CallState,
        initialCallType: CallMediaType,
        sharedKey: String? = nil
    ) {
        self.contactApiId = contact.apiId
        self.direction = direction
        self.contact = contact
        self.callUUID = callUUID
        self.callState = callState
        self.initialCallType = initialCallType
        self.sharedKey = sharedKey
        self.localMediaSources = CallMediaSources(
            mic: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            camera: initialCallType == .video && AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
    }

    var encrypted: Bool { get { localEncrypted && sharedKey != nil } }
    private var localEncrypted: Bool { get { localCapabilities?.encryption ?? false } }
    var encryptionStatus: LocalizedStringKey {
        get {
            switch callState {
            case .waitCapabilities: return ""
            case .invitationSent: return localEncrypted ? "e2e encrypted" : "no e2e encryption"
            case .invitationAccepted: return sharedKey == nil ? "contact has no e2e encryption" : "contact has e2e encryption"
            default: return !localEncrypted ? "no e2e encryption" : sharedKey == nil ? "contact has no e2e encryption" : "e2e encrypted"
            }
        }
    }
    var hasVideo: Bool { get { localMediaSources.hasVideo || peerMediaSources.hasVideo } }
}

// MARK: - POPOPX
fileprivate let _pxBrandCallModel = "PX_CALL_MODEL"
