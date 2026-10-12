//
//  PXRTCModelsTypes.swift
//  POPOPXSwitch
//
//  RTC data types needed by WCallResponse: RTCIceServer, ConnectionState,
//  ConnectionInfo, RTCIceCandidate, RTCIceCandidateType.
//  Split from PXRTCModels.swift so WCallResponse can live in POPOPXSwitch.
//
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation
import SwiftUI

public struct ConnectionState: Codable, Equatable {
    public var connectionState: String
    public var iceConnectionState: String
    public var iceGatheringState: String
    public var signalingState: String

    public init(connectionState: String, iceConnectionState: String, iceGatheringState: String, signalingState: String) {
        self.connectionState = connectionState
        self.iceConnectionState = iceConnectionState
        self.iceGatheringState = iceGatheringState
        self.signalingState = signalingState
    }
}

public struct ConnectionInfo: Codable, Equatable {
    public var localCandidate: RTCIceCandidate?
    public var remoteCandidate: RTCIceCandidate?

    public init(localCandidate: RTCIceCandidate? = nil, remoteCandidate: RTCIceCandidate? = nil) {
        self.localCandidate = localCandidate
        self.remoteCandidate = remoteCandidate
    }

    public var text: LocalizedStringKey {
        let local = localCandidate?.candidateType
        let remote = remoteCandidate?.candidateType
        if local == .host && remote == .host {
            return "peer-to-peer"
        } else if local == .relay && remote == .relay {
            return "via relay"
        } else {
            let unknown = NSLocalizedString("unknown", comment: "connection info")
            return "\(local?.rawValue ?? unknown) / \(remote?.rawValue ?? unknown)"
        }
    }
}

public struct RTCIceCandidate: Codable, Equatable {
    public var candidateType: RTCIceCandidateType?
    public var `protocol`: String?
    public var sdpMid: String?
    public var sdpMLineIndex: Int?
    public var candidate: String

    public init(candidateType: RTCIceCandidateType? = nil, protocol: String? = nil, sdpMid: String? = nil, sdpMLineIndex: Int? = nil, candidate: String) {
        self.candidateType = candidateType
        self.protocol = `protocol`
        self.sdpMid = sdpMid
        self.sdpMLineIndex = sdpMLineIndex
        self.candidate = candidate
    }
}

public enum RTCIceCandidateType: String, Codable {
    case host = "host"
    case serverReflexive = "srflx"
    case peerReflexive = "prflx"
    case relay = "relay"
}

public struct RTCIceServer: Codable, Equatable {
    public var urls: [String]
    public var username: String? = nil
    public var credential: String? = nil

    public init(urls: [String], username: String? = nil, credential: String? = nil) {
        self.urls = urls
        self.username = username
        self.credential = credential
    }
}
