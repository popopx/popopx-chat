//
//  PXWebRTCProtocolTypes.swift
//  POPOPXSwitch
//
//  WebRTC protocol data types: WVAPICall, WVAPIMessage, WCallCommand, WCallResponse.
//  Split from PXWebRTCProtocol.swift so these types live in POPOPXSwitch
//  and are accessible to the test target at runtime.
//
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation

public struct WVAPICall: Encodable {
    public var corrId: Int? = nil
    public var command: WCallCommand

    public init(corrId: Int? = nil, command: WCallCommand) {
        self.corrId = corrId
        self.command = command
    }
}

public struct WVAPIMessage: Equatable, Decodable, Encodable {
    public var corrId: Int?
    public var resp: WCallResponse
    public var command: WCallCommand?

    public init(corrId: Int? = nil, resp: WCallResponse, command: WCallCommand? = nil) {
        self.corrId = corrId
        self.resp = resp
        self.command = command
    }
}

public enum WCallCommand: Equatable, Encodable, Decodable {
    case capabilities(media: CallMediaType)
    case start(media: CallMediaType, aesKey: String? = nil, iceServers: [RTCIceServer]? = nil, relay: Bool? = nil)
    case offer(offer: String, iceCandidates: String, media: CallMediaType, aesKey: String? = nil, iceServers: [RTCIceServer]? = nil, relay: Bool? = nil)
    case answer(answer: String, iceCandidates: String)
    case ice(iceCandidates: String)
    case media(source: CallMediaSource, enable: Bool)
    case end

    enum CodingKeys: String, CodingKey {
        case type
        case media
        case source
        case aesKey
        case offer
        case answer
        case iceCandidates
        case enable
        case iceServers
        case relay
    }

    public var cmdType: String {
        get {
            switch self {
            case .capabilities: return "capabilities"
            case .start: return "start"
            case .offer: return "offer"
            case .answer: return "answer"
            case .ice: return "ice"
            case .media: return "media"
            case .end: return "end"
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .capabilities(media):
            try container.encode("capabilities", forKey: .type)
            try container.encode(media, forKey: .media)
        case let .start(media, aesKey, iceServers, relay):
            try container.encode("start", forKey: .type)
            try container.encode(media, forKey: .media)
            try container.encode(aesKey, forKey: .aesKey)
            try container.encode(iceServers, forKey: .iceServers)
            try container.encode(relay, forKey: .relay)
        case let .offer(offer, iceCandidates, media, aesKey, iceServers, relay):
            try container.encode("offer", forKey: .type)
            try container.encode(offer, forKey: .offer)
            try container.encode(iceCandidates, forKey: .iceCandidates)
            try container.encode(media, forKey: .media)
            try container.encode(aesKey, forKey: .aesKey)
            try container.encode(iceServers, forKey: .iceServers)
            try container.encode(relay, forKey: .relay)
        case let .answer(answer, iceCandidates):
            try container.encode("answer", forKey: .type)
            try container.encode(answer, forKey: .answer)
            try container.encode(iceCandidates, forKey: .iceCandidates)
        case let .ice(iceCandidates):
            try container.encode("ice", forKey: .type)
            try container.encode(iceCandidates, forKey: .iceCandidates)
        case let .media(source, enable):
            try container.encode("media", forKey: .type)
            try container.encode(source, forKey: .source)
            try container.encode(enable, forKey: .enable)
        case .end:
            try container.encode("end", forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: CodingKeys.type)
        switch type {
        case "capabilities":
            let media = try container.decode(CallMediaType.self, forKey: CodingKeys.media)
            self = .capabilities(media: media)
        case "start":
            let media = try container.decode(CallMediaType.self, forKey: CodingKeys.media)
            let aesKey = try? container.decode(String.self, forKey: CodingKeys.aesKey)
            let iceServers = try container.decode(([RTCIceServer]?).self, forKey: .iceServers)
            let relay = try container.decode((Bool?).self, forKey: .relay)
            self = .start(media: media, aesKey: aesKey, iceServers: iceServers, relay: relay)
        case "offer":
            let offer = try container.decode(String.self, forKey: CodingKeys.offer)
            let iceCandidates = try container.decode(String.self, forKey: CodingKeys.iceCandidates)
            let media = try container.decode(CallMediaType.self, forKey: CodingKeys.media)
            let aesKey = try? container.decode(String.self, forKey: CodingKeys.aesKey)
            let iceServers = try container.decode(([RTCIceServer]?).self, forKey: .iceServers)
            let relay = try container.decode((Bool?).self, forKey: .relay)
            self = .offer(offer: offer, iceCandidates: iceCandidates, media: media, aesKey: aesKey, iceServers: iceServers, relay: relay)
        case "answer":
            let answer = try container.decode(String.self, forKey: CodingKeys.answer)
            let iceCandidates = try container.decode(String.self, forKey: CodingKeys.iceCandidates)
            self = .answer(answer: answer, iceCandidates: iceCandidates)
        case "ice":
            let iceCandidates = try container.decode(String.self, forKey: CodingKeys.iceCandidates)
            self = .ice(iceCandidates: iceCandidates)
        case "media":
            let source = try container.decode(CallMediaSource.self, forKey: CodingKeys.source)
            let enable = try container.decode(Bool.self, forKey: CodingKeys.enable)
            self = .media(source: source, enable: enable)
        case "end":
            self = .end
        default:
            throw DecodingError.typeMismatch(WCallCommand.self, DecodingError.Context(codingPath: [CodingKeys.type], debugDescription: "cannot decode WCallCommand, unknown type \(type)"))
        }
    }
}


public enum WCallResponse: Equatable, Decodable {
    case capabilities(capabilities: CallCapabilities)
    case offer(offer: String, iceCandidates: String, capabilities: CallCapabilities)
    case answer(answer: String, iceCandidates: String)
    case ice(iceCandidates: String)
    case connection(state: ConnectionState)
    case connected(connectionInfo: ConnectionInfo)
    case peerMedia(source: CallMediaSource, enabled: Bool)
    case ended
    case ok
    case error(message: String)
    case invalid(type: String)

    enum CodingKeys: String, CodingKey {
        case type
        case capabilities
        case offer
        case answer
        case iceCandidates
        case state
        case connectionInfo
        case message
        case source
        case enabled
    }

    public var respType: String {
        get {
            switch self {
            case .capabilities: return "capabilities"
            case .offer: return "offer"
            case .answer: return "answer"
            case .ice: return "ice"
            case .connection: return "connection"
            case .connected: return "connected"
            case .peerMedia: return "peerMedia"
            case .ended: return "ended"
            case .ok: return "ok"
            case .error: return "error"
            case .invalid: return "invalid"
            }
        }
    }

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: CodingKeys.type)
            switch type {
            case "capabilities":
                let capabilities = try container.decode(CallCapabilities.self, forKey: CodingKeys.capabilities)
                self = .capabilities(capabilities: capabilities)
            case "offer":
                let offer = try container.decode(String.self, forKey: CodingKeys.offer)
                let iceCandidates = try container.decode(String.self, forKey: CodingKeys.iceCandidates)
                let capabilities = try container.decode(CallCapabilities.self, forKey: CodingKeys.capabilities)
                self = .offer(offer: offer, iceCandidates: iceCandidates, capabilities: capabilities)
            case "answer":
                let answer = try container.decode(String.self, forKey: CodingKeys.answer)
                let iceCandidates = try container.decode(String.self, forKey: CodingKeys.iceCandidates)
                self = .answer(answer: answer, iceCandidates: iceCandidates)
            case "ice":
                let iceCandidates = try container.decode(String.self, forKey: CodingKeys.iceCandidates)
                self = .ice(iceCandidates: iceCandidates)
            case "connection":
                let state = try container.decode(ConnectionState.self, forKey: CodingKeys.state)
                self = .connection(state: state)
            case "connected":
                let connectionInfo = try container.decode(ConnectionInfo.self, forKey: CodingKeys.connectionInfo)
                self = .connected(connectionInfo: connectionInfo)
            case "peerMedia":
                let source = try container.decode(CallMediaSource.self, forKey: CodingKeys.source)
                let enabled = try container.decode(Bool.self, forKey: CodingKeys.enabled)
                self = .peerMedia(source: source, enabled: enabled)
            case "ended":
                self = .ended
            case "ok":
                self = .ok
            case "error":
                let message = try container.decode(String.self, forKey: CodingKeys.message)
                self = .error(message: message)
            default:
                self = .invalid(type: type)
            }
        } catch {
            self = .invalid(type: "unknown")
        }
    }
}

extension WCallResponse: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .capabilities:
            try container.encode("capabilities", forKey: .type)
        case let .offer(offer, iceCandidates, capabilities):
            try container.encode("offer", forKey: .type)
            try container.encode(offer, forKey: .offer)
            try container.encode(iceCandidates, forKey: .iceCandidates)
            try container.encode(capabilities, forKey: .capabilities)
        case let .answer(answer, iceCandidates):
            try container.encode("answer", forKey: .type)
            try container.encode(answer, forKey: .answer)
            try container.encode(iceCandidates, forKey: .iceCandidates)
        case let .ice(iceCandidates):
            try container.encode("ice", forKey: .type)
            try container.encode(iceCandidates, forKey: .iceCandidates)
        case let .connection(state):
            try container.encode("connection", forKey: .type)
            try container.encode(state, forKey: .state)
        case let .connected(connectionInfo):
            try container.encode("connected", forKey: .type)
            try container.encode(connectionInfo, forKey: .connectionInfo)
        case let .peerMedia(source, enabled):
            try container.encode("peerMedia", forKey: .type)
            try container.encode(source, forKey: .source)
            try container.encode(enabled, forKey: .enabled)
        case .ended:
            try container.encode("ended", forKey: .type)
        case .ok:
            try container.encode("ok", forKey: .type)
        case let .error(message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case let .invalid(type):
            try container.encode(type, forKey: .type)
        }
    }
}
