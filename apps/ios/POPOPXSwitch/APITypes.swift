//
//  POPOPXAPI.swift
//  POPOPX NSE
//
//  Created by Evgeny on 26/04/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/api.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import Foundation
import SwiftUI
import Network

extension String {
    func appendToURL(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            handle.write(self.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try self.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

public let jsonDecoder = getJSONDecoder()
public let jsonEncoder = getJSONEncoder()

public protocol ChatCmdProtocol {
    var cmdString: String { get }
}

@inline(__always)
public func onOff(_ b: Bool) -> String {
    b ? "on" : "off"
}

// Spec: spec/api.md#APIResult
public enum APIResult<R>: Decodable, @unchecked Sendable where R: Decodable, R: ChatAPIResult {
    case result(R, seq: Int)
    case error(ChatError, seq: Int)
    case invalid(type: String, json: Data)
    
    public var responseType: String {
        switch self {
        case let .result(r, _): r.responseType
        case let .error(e, _): "error \(e.errorType)"
        case let .invalid(type, _): "* \(type)"
        }
    }
    
    public var unexpected: ChatError {
        switch self {
        case let .result(r, _): .unexpectedResult(type: r.responseType)
        case let .error(e, _): e
        case let .invalid(type, _): .unexpectedResult(type: "* \(type)")
        }
    }

    public var sequenceNumber: Int {
        switch self {
        case let .result(_, seq): seq
        case let .error(_, seq): seq
        case .invalid: -1
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seq = try container.decodeIfPresent(Int.self, forKey: .seq) ?? 0
        if container.contains(.result) {
            let result = try container.decode(R.self, forKey: .result)
            self = .result(result, seq: seq)
        } else {
            let error = try container.decode(ChatError.self, forKey: .error)
            self = .error(error, seq: seq)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case result, error, seq
    }
}

// Spec: spec/api.md#ChatAPIResult
public protocol ChatAPIResult: Decodable, Sendable {
    var responseType: String { get }
    var details: String { get }
    static func fallbackResult(_ type: String, _ json: NSDictionary) -> Self?
    static var useManualDecoding: Bool { get }
}

extension ChatAPIResult {
    public var noDetails: String { "\(self.responseType): no details" }

    @inline(__always)
    public static var useManualDecoding: Bool { false }

    @inline(__always)
    public static func fallbackResult(_ type: String, _ json: NSDictionary) -> Self? {
        nil
    }
    
    @inline(__always)
    public var unexpected: ChatError {
        .unexpectedResult(type: self.responseType)
    }
}

// Spec: spec/api.md#decodeAPIResult
public func decodeAPIResult<R: ChatAPIResult>(_ d: Data) -> APIResult<R> {
    let debugFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("debug_log.txt")
    if let debugFile { try? "decodeAPIResult CALLED with \(d.count) bytes\n".appendToURL(debugFile) }
    if d.count > 1000 {
        if let jsonStr = String(data: d, encoding: .utf8) {
            if jsonStr.contains("\"invitation\"") {
                if let debugFile { try? "FULL JSON: \(jsonStr)\n".appendToURL(debugFile) }
            } else {
                if let debugFile { try? "JSON: \(jsonStr.prefix(500))...\n".appendToURL(debugFile) }
            }
        }
    }
    do {
        return try withLargeStack { try jsonDecoder.decode(APIResult<R>.self, from: d) }
    } catch {
        if let debugFile { try? "decodeAPIResult: standard decoding failed: \(error)\n".appendToURL(debugFile) }
    }
    if let j = try? JSONSerialization.jsonObject(with: d) as? NSDictionary {
        let seq = (j["seq"] as? Int) ?? 0
        if let (_, jErr) = getOWSF(j, "error") {
            return APIResult.error(.invalidJSON(json: errorJson(jErr)), seq: seq) as APIResult<R>
        } else if let (type, jRes) = getOWSF(j, "result") {
            do {
                return try withLargeStack {
                    if let r = R.fallbackResult(type, jRes) {
                        return APIResult.result(r, seq: seq)
                    } else {
                        logger.warning("decodeAPIResult: unhandled response type '\(type)' for \(R.self)")
                        return APIResult.invalid(type: type, json: dataPrefix(d))
                    }
                }
            } catch {
                logger.error("decodeAPIResult: fallbackResult threw for type '\(type)': \(error)")
                return APIResult.invalid(type: type, json: dataPrefix(d))
            }
        } else {
            logger.warning("decodeAPIResult: no 'result' or 'error' key found in JSON")
        }
    } else {
        logger.error("decodeAPIResult: failed to parse JSON from response data (\(d.count) bytes)")
    }
    return APIResult.invalid(type: "invalid", json: dataPrefix(d))
}

// Default stack size for the main thread is 1mb, for secondary threads - 512 kb.
// This function can be used to test what size is used (or to increase available stack size).
// Stack size must be a multiple of system page size (16kb).
private let stackSizeLimit: Int = 16 * 1024 * 1024

private final class LargeStackRunner {
    static let shared = LargeStackRunner(poolSize: 2)

    private let poolSize: Int
    private let workers: [Worker]
    private let assignLock = NSLock()
    private var nextWorker = 0

    private final class Worker {
        let jobReady = DispatchSemaphore(value: 0)
        let jobDone = DispatchSemaphore(value: 0)
        var job: (() -> Void)?

        init(stackSize: Int, index: Int) {
            let t = Thread(target: self, selector: #selector(loop), object: nil)
            t.stackSize = stackSize
            t.name = "chat.popopx.decoding.\(index)"
            t.qualityOfService = .userInitiated
            t.start()
        }

        @objc private func loop() {
            while true {
                jobReady.wait()
                job?()
                jobDone.signal()
            }
        }

        func run(_ f: @escaping () -> Void) {
            job = f
            jobReady.signal()
            jobDone.wait()
            job = nil
        }
    }

    init(poolSize: Int) {
        self.poolSize = poolSize
        self.workers = (0..<poolSize).map { Worker(stackSize: stackSizeLimit, index: $0) }
    }

    func run<T>(_ f: @escaping () throws -> T) throws -> T {
        guard !workers.isEmpty else {
            throw NSError(domain: "LargeStackRunner", code: -2, userInfo: [NSLocalizedDescriptionKey: "Worker pool not initialized"])
        }
        assignLock.lock()
        let worker = workers[nextWorker]
        nextWorker = (nextWorker + 1) % poolSize
        assignLock.unlock()

        var result: Result<T, Error> = .failure(NSError(domain: "LargeStackRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Job did not produce result"]))
        worker.run { result = Result(catching: f) }
        return try result.get()
    }
}

func withLargeStack<T>(_ work: @escaping () throws -> T) throws -> T {
    try LargeStackRunner.shared.run(work)
}

public func parseApiChats(_ jResp: NSDictionary) -> (user: UserRef, chats: [ChatData])? {
    if let jApiChats = jResp["apiChats"] as? NSDictionary,
       let user: UserRef = try? decodeObject(jApiChats["user"] as Any),
       let jChats = jApiChats["chats"] as? NSArray {
        let chats = jChats.map { jChat in
            if let chatData = try? parseChatData(jChat) {
                return chatData.0
            }
            return ChatData.invalidJSON(serializeJSON(jChat, options: .prettyPrinted))
        }
        return (user, chats)
    } else {
        return nil
    }
}

public func withUser(_ u: (any UserLike)?, _ s: String) -> String {
    if let id = u?.userId {
        return "userId: \(id)\n\(s)"
    }
    return s
}

public struct CreatedConnLink: Decodable, Hashable {
    public var connFullLink: String
    public var connShortLink: String?
    public var encryptedConnLink: String?

    public init(connFullLink: String, connShortLink: String?, encryptedConnLink: String? = nil) {
        self.connFullLink = connFullLink
        self.connShortLink = connShortLink
        self.encryptedConnLink = encryptedConnLink
    }

    public func popopxChatUri(short: Bool = true) -> String {
        // Always prefer encryptedConnLink if available (it should be popopx protocol)
        if let enc = encryptedConnLink { return enc }

        // Fallback: convert popopx links to popopx protocol
        let baseLink = short ? (connShortLink ?? connFullLink) : connFullLink

        // If already popopx protocol, return as-is
        if baseLink.starts(with: "popopx:/") || baseLink.starts(with: "popop:/") {
            return baseLink
        }

        // Convert https:// links to popopx:/ (except already-branded domains)
        if baseLink.starts(with: "https://"), !baseLink.starts(with: "https://popopxchat.com") {
            return baseLink.replacingOccurrences(of: "https://", with: "popopx:/")
        }

        return baseLink
    }
}

public func popopxChatLink(_ uri: String) -> String {
    if uri.starts(with: "popopx://enc#") { return uri }
    if uri.starts(with: "popopx:/") {
        return uri.replacingOccurrences(of: "popopx:/", with: "https://popopxchat.com/")
    }
    if uri.starts(with: "popop:/") {
        return uri.replacingOccurrences(of: "popop:/", with: "https://popopxchat.com/")
    }
    return uri
}

public struct ComposedMessage: Encodable {
    public var fileSource: CryptoFile?
    var quotedItemId: Int64?
    public var msgContent: MsgContent
    public var mentions: [String: Int64]

    public init(fileSource: CryptoFile? = nil, quotedItemId: Int64? = nil, msgContent: MsgContent, mentions: [String: Int64] = [:]) {
        self.fileSource = fileSource
        self.quotedItemId = quotedItemId
        self.msgContent = msgContent
        self.mentions = mentions
    }
}

public enum ServerProtocol: String, Decodable {
    case smp
    case xftp
}

public struct ServerAddress: Decodable {
    public var serverProtocol: ServerProtocol
    public var hostnames: [String]
    public var port: String
    public var keyHash: String
    public var basicAuth: String

    public init(serverProtocol: ServerProtocol, hostnames: [String], port: String, keyHash: String, basicAuth: String = "") {
        self.serverProtocol = serverProtocol
        self.hostnames = hostnames
        self.port = port
        self.keyHash = keyHash
        self.basicAuth = basicAuth
    }

    public var uri: String {
        "\(serverProtocol)://\(keyHash)\(basicAuth == "" ? "" : ":" + basicAuth)@\(hostnames.joined(separator: ","))"
    }

    public var valid: Bool {
        hostnames.count > 0 && Set(hostnames).count == hostnames.count
    }

    static func empty(_ serverProtocol: ServerProtocol) -> ServerAddress {
        ServerAddress(
            serverProtocol: serverProtocol,
            hostnames: [],
            port: "",
            keyHash: "",
            basicAuth: ""
        )
    }

    static public var sampleData = ServerAddress(
        serverProtocol: .smp,
        hostnames: ["smp.popopxchat.com", "1234.onion"],
        port: "",
        keyHash: "LcJUMfVhwD8yxjAiSaDzzGF3-kLG4Uh0Fl_ZIjrRwjI=",
        basicAuth: "server_password"
    )
}

public struct NetCfg: Codable, Equatable {
    public var socksProxy: String? = nil
    var socksMode: SocksMode = .always
    public var hostMode: HostMode = .publicHost
    public var requiredHostMode = true
    public var sessionMode = TransportSessionMode.user
    public var smpProxyMode: SMPProxyMode = .always
    public var smpProxyFallback: SMPProxyFallback = .allowProtected
    public var smpWebPortServers: SMPWebPortServers = .preset
    public var tcpConnectTimeout: NetworkTimeout
    public var tcpTimeout: NetworkTimeout
    public var tcpTimeoutPerKb: Int // microseconds
    public var rcvConcurrency: Int // pool size
    public var tcpKeepAlive: KeepAliveOpts? = KeepAliveOpts.defaults
    public var smpPingInterval: Int // microseconds
    public var smpPingCount: Int = 3 // times
    public var logTLSErrors: Bool = false

    public static let defaults: NetCfg = NetCfg(
        tcpConnectTimeout: NetworkTimeout(backgroundTimeout: 45_000_000, interactiveTimeout: 15_000_000),
        tcpTimeout: NetworkTimeout(backgroundTimeout: 30_000_000, interactiveTimeout: 10_000_000),
        tcpTimeoutPerKb: 10_000,
        rcvConcurrency: 12,
        smpPingInterval: 1200_000_000
    )

    static let proxyDefaults: NetCfg = NetCfg(
        tcpConnectTimeout: NetworkTimeout(backgroundTimeout: 60_000_000, interactiveTimeout: 30_000_000),
        tcpTimeout: NetworkTimeout(backgroundTimeout: 40_000_000, interactiveTimeout: 20_000_000),
        tcpTimeoutPerKb: 15_000,
        rcvConcurrency: 8,
        smpPingInterval: 1200_000_000
    )

    public var withProxyTimeouts: NetCfg {
        var cfg = self
        cfg.tcpConnectTimeout = NetCfg.proxyDefaults.tcpConnectTimeout
        cfg.tcpTimeout = NetCfg.proxyDefaults.tcpTimeout
        cfg.tcpTimeoutPerKb = NetCfg.proxyDefaults.tcpTimeoutPerKb
        cfg.rcvConcurrency = NetCfg.proxyDefaults.rcvConcurrency
        cfg.smpPingInterval = NetCfg.proxyDefaults.smpPingInterval
        return cfg
    }

    public var hasProxyTimeouts: Bool {
        tcpConnectTimeout == NetCfg.proxyDefaults.tcpConnectTimeout &&
        tcpTimeout == NetCfg.proxyDefaults.tcpTimeout &&
        tcpTimeoutPerKb == NetCfg.proxyDefaults.tcpTimeoutPerKb &&
        rcvConcurrency == NetCfg.proxyDefaults.rcvConcurrency &&
        smpPingInterval == NetCfg.proxyDefaults.smpPingInterval
    }

    public var enableKeepAlive: Bool { tcpKeepAlive != nil }
}

public struct NetworkTimeout: Codable, Equatable {
    public var backgroundTimeout: Int // microseconds
    public var interactiveTimeout: Int // microseconds
}

public enum HostMode: String, Codable {
    case onionViaSocks
    case onionHost = "onion"
    case publicHost = "public"
}

public enum SocksMode: String, Codable {
    case always = "always"
    case onion = "onion"
}

public enum SMPProxyMode: String, Codable, SelectableItem {
    case always = "always"
    case unknown = "unknown"
    case unprotected = "unprotected"
    case never = "never"

    public var label: LocalizedStringKey {
        switch self {
        case .always: return "always"
        case .unknown: return "unknown servers"
        case .unprotected: return "unprotected"
        case .never: return "never"
        }
    }

    public var id: SMPProxyMode { self }

    public static let values: [SMPProxyMode] = [.always, .unknown, .unprotected, .never]
}

public enum SMPProxyFallback: String, Codable, SelectableItem {
    case allow = "allow"
    case allowProtected = "allowProtected"
    case prohibit = "prohibit"

    public var label: LocalizedStringKey {
        switch self {
        case .allow: return "yes"
        case .allowProtected: return "when IP hidden"
        case .prohibit: return "no"
        }
    }

    public var id: SMPProxyFallback { self }

    public static let values: [SMPProxyFallback] = [.allow, .allowProtected, .prohibit]
}

public enum SMPWebPortServers: String, Codable, CaseIterable {
    case all = "all"
    case preset = "preset"
    case off = "off"
    
    public var text: LocalizedStringKey {
        switch self {
        case .all: "All servers"
        case .preset: "Preset servers"
        case .off: "Off"
        }
    }
}

public enum OnionHosts: String, Identifiable {
    case no
    case prefer
    case require

    public var text: LocalizedStringKey {
        switch self {
        case .no: return "No"
        case .prefer: return "When available"
        case .require: return "Required"
        }
    }

    public var hostMode: (HostMode, Bool) {
        switch self {
        case .no: return (.publicHost, true)
        case .prefer: return (.onionHost, false)
        case .require: return (.onionHost, true)
        }
    }

    public init(netCfg: NetCfg) {
        switch netCfg.hostMode {
        case .onionViaSocks: self = .no
        case .onionHost: self = netCfg.requiredHostMode ? .require : .prefer
        case .publicHost: self = .no
        }
    }

    public var id: OnionHosts { self }

    public static let values: [OnionHosts] = [.no, .prefer, .require]
}

public enum TransportSessionMode: String, Codable, Identifiable {
    case user
    case session
    case server
    case entity

    public var text: LocalizedStringKey {
        switch self {
        case .user: return "Chat profile"
        case .session: return "App session"
        case .server: return "Server"
        case .entity: return "Connection"
        }
    }

    public var id: TransportSessionMode { self }

    public static let values: [TransportSessionMode] = [.user, .session, .server, .entity]
}

public struct KeepAliveOpts: Codable, Equatable {
    public var keepIdle: Int // seconds
    public var keepIntvl: Int // seconds
    public var keepCnt: Int // times

    public static let defaults: KeepAliveOpts = KeepAliveOpts(keepIdle: 30, keepIntvl: 15, keepCnt: 4)
}

public struct NetworkProxy: Equatable, Codable {
    public var host: String = ""
    public var port: Int = 0
    public var auth: NetworkProxyAuth = .username
    public var username: String = ""
    public var password: String = ""

    public static var def: NetworkProxy {
        NetworkProxy()
    }

    public var valid: Bool {
        let hostOk = switch NWEndpoint.Host(host) {
        case .ipv4: true
        case .ipv6: true
        default: false
        }
        return hostOk &&
                port > 0 && port <= 65535 &&
                NetworkProxy.validCredential(username) && NetworkProxy.validCredential(password)
    }

    public static func validCredential(_ s: String) -> Bool {
        !s.contains(":") && !s.contains("@")
    }

    public func toProxyString() -> String? {
        if !valid { return nil }
        var res = ""
        switch auth {
        case .username:
            let usernameTrimmed = username.trimmingCharacters(in: .whitespaces)
            let passwordTrimmed = password.trimmingCharacters(in: .whitespaces)
            if usernameTrimmed != "" || passwordTrimmed != "" {
                res += usernameTrimmed + ":" + passwordTrimmed + "@"
            } else {
                res += "@"
            }
        case .isolate: ()
        }
        if host != "" {
            if host.contains(":") {
                res += "[\(host.trimmingCharacters(in: [" ", "[", "]"]))]"
            } else {
                res += host.trimmingCharacters(in: .whitespaces)
            }
        }
        res += ":\(port)"
        return res
    }
}

public enum NetworkProxyAuth: String, Codable {
    case username
    case isolate
}

public struct ChatSettings: Codable, Hashable {
    public var enableNtfs: MsgFilter
    public var sendRcpts: Bool?
    public var favorite: Bool

    public init(enableNtfs: MsgFilter, sendRcpts: Bool?, favorite: Bool) {
        self.enableNtfs = enableNtfs
        self.sendRcpts = sendRcpts
        self.favorite = favorite
    }

    public static let defaults: ChatSettings = ChatSettings(enableNtfs: .all, sendRcpts: nil, favorite: false)
}

public struct NavigationInfo: Decodable {
    public var afterUnread: Int = 0
    public var afterTotal: Int = 0

    public init(afterUnread: Int = 0, afterTotal: Int = 0) {
        self.afterUnread = afterUnread
        self.afterTotal = afterTotal
    }
}

public enum MsgFilter: String, Codable, Hashable {
    case none
    case all
    case mentions
    
    public func nextMode(mentions: Bool) -> MsgFilter {
        switch self {
        case .all: mentions ? .mentions : .none
        case .mentions: .none
        case .none: .all
        }
    }
    
    public func text(mentions: Bool) -> String {
        switch self {
        case .all: NSLocalizedString("Unmute", comment: "notification label action")
        case .mentions: NSLocalizedString("Mute", comment: "notification label action")
        case .none:
            mentions
            ? NSLocalizedString("Mute all", comment: "notification label action")
            : NSLocalizedString("Mute", comment: "notification label action")
        }
    }
    
    public var icon: String {
        return switch self {
        case .all: "speaker.wave.2"
        case .mentions: "speaker.badge.exclamationmark"
        case .none: "speaker.slash"
        }
    }
    
    public var iconFilled: String {
        return switch self {
        case .all: "speaker.wave.2.fill"
        case .mentions: "speaker.badge.exclamationmark.fill"
        case .none: "speaker.slash.fill"
        }
    }
}

public struct ConnectionStats: Decodable, Hashable {
    public var connAgentVersion: Int
    public var rcvQueuesInfo: [RcvQueueInfo]
    public var sndQueuesInfo: [SndQueueInfo]
    public var ratchetSyncState: RatchetSyncState
    public var ratchetSyncSupported: Bool
    public var subStatus: SubscriptionStatus?

    public var ratchetSyncAllowed: Bool {
        ratchetSyncSupported && [.allowed, .required].contains(ratchetSyncState)
    }

    public var ratchetSyncSendProhibited: Bool {
        [.required, .started, .agreed].contains(ratchetSyncState)
    }

    public var ratchetSyncInProgress: Bool {
        [.started, .agreed].contains(ratchetSyncState)
    }
}

public struct RcvQueueInfo: Decodable, Hashable {
    public var rcvServer: String
    public var status: QueueStatus
    public var rcvSwitchStatus: RcvSwitchStatus?
    public var canAbortSwitch: Bool
    public var subStatus: SubscriptionStatus
}

public enum RcvSwitchStatus: String, Decodable, Hashable {
    case switchStarted = "switch_started"
    case sendingQADD = "sending_qadd"
    case sendingQUSE = "sending_quse"
    case receivedMessage = "received_message"
    case receivedQEND = "received_qend"
}

public struct SndQueueInfo: Decodable, Hashable {
    public var sndServer: String
    public var status: QueueStatus
    public var sndSwitchStatus: SndSwitchStatus?
}

public enum SndSwitchStatus: String, Decodable, Hashable {
    case sendingQKEY = "sending_qkey"
    case sendingQTEST = "sending_qtest"
}

public enum QueueDirection: String, Decodable {
    case rcv
    case snd
}

public struct SwitchProgress: Decodable {
    public var queueDirection: QueueDirection
    public var switchPhase: SwitchPhase
    public var connectionStats: ConnectionStats
}

public struct RatchetSyncProgress: Decodable {
    public var ratchetSyncStatus: RatchetSyncState
    public var connectionStats: ConnectionStats
}

public enum RatchetSyncState: String, Decodable {
    case ok
    case allowed
    case required
    case started
    case agreed
}

public enum QueueStatus: String, Decodable, Hashable {
    case new
    case confirmed
    case secured
    case active
    case disabled
}

public enum SubscriptionStatus: Decodable, Hashable {
    case active
    case pending
    case removed(subError: String)
    case noSub

    public var statusString: LocalizedStringKey {
        switch self {
        case .active: "connected"
        case .pending: "connecting"
        case .removed: "error"
        case .noSub: "no subscription"
        }
    }

    public var statusExplanation: String {
        switch self {
        case .active: NSLocalizedString("You are connected to the server used to receive messages from this connection.", comment: "subscription status explanation")
        case .pending: NSLocalizedString("Trying to connect to the server used to receive messages from this connection.", comment: "subscription status explanation")
        case let .removed(err): String.localizedStringWithFormat(NSLocalizedString("Error connecting to the server used to receive messages from this connection: %@", comment: "subscription status explanation"), err)
        case .noSub: NSLocalizedString("You are not connected to the server used to receive messages from this connection (no subscription).", comment: "subscription status explanation")
        }
    }

    public var imageName: String {
        switch self {
        case .active: "circle.fill"
        case .pending: "ellipsis.circle.fill"
        case .removed: "exclamationmark.circle.fill"
        case .noSub: "circle.dotted"
        }
    }
}

public protocol SelectableItem: Identifiable, Equatable {
    var label: LocalizedStringKey { get }
    static var values: [Self] { get }
}

public enum NotificationPreviewMode: String, SelectableItem, Codable {
    case hidden
    case contact
    case message

    public var label: LocalizedStringKey {
        switch self {
        case .hidden: return "Hidden"
        case .contact: return "Contact name"
        case .message: return "Message text"
        }
    }

    public var id: String { self.rawValue }

    public static var values: [NotificationPreviewMode] = [.message, .contact, .hidden]
}

public func decodeJSON<T: Decodable>(_ json: String) -> T? {
    guard !json.isEmpty else { return nil }
    if let data = json.data(using: .utf8) {
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch let DecodingError.typeMismatch(type, context) {
            let preview = json.prefix(100)
            logger.debug("decodeJSON type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), input: \(preview)")
        } catch let DecodingError.dataCorrupted(context) {
            let preview = json.prefix(100)
            logger.debug("decodeJSON data corrupted: \(context.debugDescription), input: \(preview)")
        } catch {
            let preview = json.prefix(100)
            logger.debug("decodeJSON failed: \(error), input: \(preview)")
        }
    }
    return nil
}

public func encodeJSON<T: Encodable>(_ value: T) -> String {
    do {
        let data = try jsonEncoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    } catch {
        logger.error("encodeJSON failed: \(error)")
        return "{}"
    }
}

private func encodeCJSON<T: Encodable>(_ value: T) -> [CChar] {
    guard let cStr = encodeJSON(value).cString(using: .utf8) else {
        logger.error("encodeCJSON: UTF8 encoding failed")
        return []
    }
    return cStr
}

// Spec: spec/api.md#ChatError
public enum ChatError: Decodable, Hashable, Error {
    case error(errorType: ChatErrorType)
    case errorAgent(agentError: AgentErrorType)
    case errorStore(storeError: StoreError)
    case errorDatabase(databaseError: DatabaseError)
    case errorRemoteCtrl(remoteCtrlError: RemoteCtrlError)
    case invalidJSON(json: Data?) // additional case used to pass errors that failed to parse
    case unexpectedResult(type: String) // additional case used to pass unexpected responses
    
    public var errorType: String {
        switch self {
        case .error: "chat"
        case .errorAgent: "agent"
        case .errorStore: "store"
        case .errorDatabase: "database"
        case .errorRemoteCtrl: "remoteCtrl"
        case .invalidJSON: "invalid"
        case let .unexpectedResult(type): "! \(type)"
        }
    }
}

public struct MsgMetaJSON: Decodable, Hashable {
    public var integrity: String
    public var rcvId: Int64
    public var rcvTs: String
    public var serverId: String
    public var serverTs: String
    public var sndId: Int64
}

public struct SuspectedMember: Hashable {
    public var groupInfo: GroupInfo
    public var groupMember: GroupMember

    public init(groupInfo: GroupInfo, groupMember: GroupMember) {
        self.groupInfo = groupInfo
        self.groupMember = groupMember
    }
}

extension SuspectedMember: Decodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        groupInfo = try container.decode(GroupInfo.self)
        groupMember = try container.decode(GroupMember.self)
    }
}

// Spec: spec/api.md#ChatErrorType
public enum ChatErrorType: Decodable, Hashable {
    case noActiveUser
    case noConnectionUser(agentConnId: String)
    case noSndFileUser(agentSndFileId: String)
    case noRcvFileUser(agentRcvFileId: String)
    case userUnknown
    case activeUserExists
    case userExists(contactName: ContactName)
    case chatRelayExists
    case invalidDisplayName(displayName: String, validName: String)
    case differentActiveUser(commandUserId: Int64, activeUserId: Int64)
    case cantDeleteActiveUser(userId: Int64)
    case cantDeleteLastUser(userId: Int64)
    case cantHideLastUser(userId: Int64)
    case hiddenUserAlwaysMuted(userId: Int64)
    case emptyUserPassword(userId: Int64)
    case userAlreadyHidden(userId: Int64)
    case userNotHidden(userId: Int64)
    case chatNotStarted
    case chatNotStopped
    case chatStoreChanged
    case invalidConnReq
    case popopxDomainNotReady(popopxDomain: PopopxNameDomain, popopxDomainError: PopopxDomainError)
    case notResolvedLocally
    case unsupportedConnReq
    case invalidChatMessage(connection: Connection, msgMeta: MsgMetaJSON?, messageData: String, message: String)
    case connReqMessageProhibited
    case contactNotReady(contact: Contact)
    case contactNotActive(contact: Contact)
    case contactDisabled(contact: Contact)
    case connectionDisabled(connection: Connection)
    case groupUserRole(groupInfo: GroupInfo, requiredRole: GroupMemberRole)
    case groupMemberInitialRole(groupInfo: GroupInfo, initialRole: GroupMemberRole)
    case contactIncognitoCantInvite
    case groupIncognitoCantInvite
    case groupContactRole(contactName: ContactName)
    case groupDuplicateMember(contactName: ContactName)
    case groupDuplicateMemberId
    case groupNotJoined(groupInfo: GroupInfo)
    case groupMemberNotActive
    case groupMemberUserRemoved
    case groupMemberNotFound
    case groupCantResendInvitation(groupInfo: GroupInfo, contactName: ContactName)
    case groupInternal(message: String)
    case fileNotFound(message: String)
    case fileSize(filePath: String)
    case fileAlreadyReceiving(message: String)
    case fileCancelled(message: String)
    case fileCancel(fileId: Int64, message: String)
    case fileAlreadyExists(filePath: String)
    case fileWrite(filePath: String, message: String)
    case fileSend(fileId: Int64, agentError: String)
    case fileRcvChunk(message: String)
    case fileInternal(message: String)
    case fileImageType(filePath: String)
    case fileImageSize(filePath: String)
    case fileNotReceived(fileId: Int64)
    case fileNotApproved(fileId: Int64, unknownServers: [String])
    case fallbackToSMPProhibited(fileId: Int64)
    case inlineFileProhibited(fileId: Int64)
    case invalidQuote
    case invalidForward
    case invalidChatItemUpdate
    case invalidChatItemDelete
    case hasCurrentCall
    case noCurrentCall
    case callContact(contactId: Int64)
    case callState(currentCallState: String)
    case directMessagesProhibited(direction: MsgDirection, contact: Contact)
    case agentVersion
    case agentNoSubResult(agentConnId: String)
    case commandError(message: String)
    case badgeRedeemError(badgeRedeemError: BadgeRedeemError)
    case serverProtocol(serverProtocol: String)
    case agentCommandError(message: String)
    case invalidFileDescription(message: String)
    case connectionIncognitoChangeProhibited
    case connectionUserChangeProhibited
    case peerChatVRangeIncompatible
    case relayTestError(message: String)
    case contactNotFound(contactName: ContactName, suspectedMember: SuspectedMember?)
    case cantBlockMemberForSelf(groupInfo: GroupInfo, member: GroupMember, setShowMessages: Bool)
    case internalError(message: String)
    case exception(message: String)
}

public enum BadgeRedeemError: Decodable, Hashable {
    case invalidCode
    case serviceNotConfigured
    case badgeActive
    case serviceError(serviceError: BadgeServiceErrorCode)
    case invalidResponse(message: String)
    case unknownKeyIndex
    case credentialNotVerified
}

// the service is deployed ahead of clients, so a code this version does not know keeps its tag
public enum BadgeServiceErrorCode: Decodable, Hashable {
    case badRequest
    case unsupportedVersion
    case unknownPurchaseKey
    case unknownOfferId
    case offerDisabled
    case offerMismatch
    case productUnavailable
    case paymentNotEntitled
    case paymentPending
    case providerUnavailable
    case rateLimited
    case codeInvalid
    case codeUsed
    case codeExpired
    case receiptInvalid
    case receiptUsed
    case internalError
    case unknown(String)

    public var text: String {
        switch self {
        case .badRequest: "bad_request"
        case .unsupportedVersion: "unsupported_version"
        case .unknownPurchaseKey: "unknown_purchase_key"
        case .unknownOfferId: "unknown_offer_id"
        case .offerDisabled: "offer_disabled"
        case .offerMismatch: "offer_mismatch"
        case .productUnavailable: "product_unavailable"
        case .paymentNotEntitled: "payment_not_entitled"
        case .paymentPending: "payment_pending"
        case .providerUnavailable: "provider_unavailable"
        case .rateLimited: "rate_limited"
        case .codeInvalid: "code_invalid"
        case .codeUsed: "code_used"
        case .codeExpired: "code_expired"
        case .receiptInvalid: "receipt_invalid"
        case .receiptUsed: "receipt_used"
        case .internalError: "internal"
        case let .unknown(s): s
        }
    }

    public init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "bad_request": self = .badRequest
        case "unsupported_version": self = .unsupportedVersion
        case "unknown_purchase_key": self = .unknownPurchaseKey
        case "unknown_offer_id": self = .unknownOfferId
        case "offer_disabled": self = .offerDisabled
        case "offer_mismatch": self = .offerMismatch
        case "product_unavailable": self = .productUnavailable
        case "payment_not_entitled": self = .paymentNotEntitled
        case "payment_pending": self = .paymentPending
        case "provider_unavailable": self = .providerUnavailable
        case "rate_limited": self = .rateLimited
        case "code_invalid": self = .codeInvalid
        case "code_used": self = .codeUsed
        case "code_expired": self = .codeExpired
        case "receipt_invalid": self = .receiptInvalid
        case "receipt_used": self = .receiptUsed
        case "internal": self = .internalError
        case let s: self = .unknown(s)
        }
    }
}

public func badgeServiceErrorText(_ code: BadgeServiceErrorCode) -> String? {
    switch code {
    case .codeInvalid: NSLocalizedString("This code was not recognized.", comment: "alert message")
    case .codeUsed: NSLocalizedString("This code has already been used.", comment: "alert message")
    case .codeExpired: NSLocalizedString("This code has expired.", comment: "alert message")
    case .rateLimited: NSLocalizedString("Too many attempts. Please try again later.", comment: "alert message")
    case .unsupportedVersion: NSLocalizedString("This app version is too old for the badge service. Please update the app.", comment: "alert message")
    case .unknownPurchaseKey: NSLocalizedString("The badge service does not recognize this badge.", comment: "alert message")
    case .internalError: NSLocalizedString("The badge service reported an internal error.", comment: "alert message")
    case .badRequest, .unknownOfferId, .offerDisabled, .offerMismatch, .productUnavailable,
         .paymentNotEntitled, .paymentPending, .providerUnavailable, .receiptInvalid, .receiptUsed, .unknown: nil
    }
}

public enum StoreError: Decodable, Hashable {
    case duplicateName
    case userNotFound(userId: Int64)
    case relayUserNotFound
    case userNotFoundByName(contactName: ContactName)
    case userNotFoundByContactId(contactId: Int64)
    case userNotFoundByGroupId(groupId: Int64)
    case userNotFoundByFileId(fileId: Int64)
    case userNotFoundByContactRequestId(contactRequestId: Int64)
    case contactNotFound(contactId: Int64)
    case contactNotFoundByName(contactName: ContactName)
    case contactNotFoundByMemberId(groupMemberId: Int64)
    case contactNotReady(contactName: ContactName)
    case duplicateContactLink
    case userContactLinkNotFound
    case contactRequestNotFound(contactRequestId: Int64)
    case contactRequestNotFoundByName(contactName: ContactName)
    case invalidContactRequestEntity(contactRequestId: Int64)
    case invalidBusinessChatContactRequest
    case groupNotFound(groupId: Int64)
    case groupNotFoundByName(groupName: GroupName)
    case groupMemberNameNotFound(groupId: Int64, groupMemberName: ContactName)
    case groupMemberNotFound(groupMemberId: Int64)
    case groupHostMemberNotFound(groupId: Int64)
    case groupMemberNotFoundByMemberId(memberId: String)
    case memberContactGroupMemberNotFound(contactId: Int64)
    case groupWithoutUser
    case duplicateGroupMember
    case duplicateMemberId
    case groupAlreadyJoined
    case groupInvitationNotFound
    case sndFileNotFound(fileId: Int64)
    case sndFileInvalid(fileId: Int64)
    case rcvFileNotFound(fileId: Int64)
    case rcvFileDescrNotFound(fileId: Int64)
    case fileNotFound(fileId: Int64)
    case rcvFileInvalid(fileId: Int64)
    case rcvFileInvalidDescrPart
    case sharedMsgIdNotFoundByFileId(fileId: Int64)
    case fileIdNotFoundBySharedMsgId(sharedMsgId: String)
    case sndFileNotFoundXFTP(agentSndFileId: String)
    case rcvFileNotFoundXFTP(agentRcvFileId: String)
    case extraFileDescrNotFoundXFTP(fileId: Int64)
    case connectionNotFound(agentConnId: String)
    case connectionNotFoundById(connId: Int64)
    case connectionNotFoundByMemberId(groupMemberId: Int64)
    case pendingConnectionNotFound(connId: Int64)
    case introNotFound
    case uniqueID
    case internalError(message: String)
    case noMsgDelivery(connId: Int64, agentMsgId: String)
    case badChatItem(itemId: Int64)
    case chatItemNotFound(itemId: Int64)
    case chatItemNotFoundByText(text: String)
    case chatItemSharedMsgIdNotFound(sharedMsgId: String)
    case chatItemNotFoundByFileId(fileId: Int64)
    case chatItemNotFoundByGroupId(groupId: Int64)
    case profileNotFound(profileId: Int64)
    case duplicateGroupLink(groupInfo: GroupInfo)
    case groupLinkNotFound(groupInfo: GroupInfo)
    case hostMemberIdNotFound(groupId: Int64)
    case contactNotFoundByFileId(fileId: Int64)
    case noGroupSndStatus(itemId: Int64, groupMemberId: Int64)
    case userChatRelayNotFound(chatRelayId: Int64)
    case groupRelayNotFound(groupRelayId: Int64)
    case groupRelayNotFoundByMemberId(groupMemberId: Int64)
    case dBException(message: String)
}

public enum DatabaseError: Decodable, Hashable {
    case errorEncrypted
    case errorPlaintext
    case errorNoFile(dbFile: String)
    case errorExport(sqliteError: SQLiteError)
    case errorOpen(sqliteError: SQLiteError)
}

public enum SQLiteError: Decodable, Hashable {
    case errorNotADatabase
    case error(dbError: String)
}

public enum AgentErrorType: Decodable, Hashable {
    case CMD(cmdErr: CommandErrorType, errContext: String)
    case CONN(connErr: ConnectionErrorType, errContext: String)
    case SMP(serverAddress: String, smpErr: ProtocolErrorType)
    case NTF(ntfErr: ProtocolErrorType)
    case XFTP(xftpErr: XFTPErrorType)
    case PROXY(proxyServer: String, relayServer: String, proxyErr: ProxyClientError)
    case RCP(rcpErr: RCErrorType)
    case BROKER(brokerAddress: String, brokerErr: BrokerErrorType)
    case AGENT(agentErr: SMPAgentError)
    case NOTICE(server: String, preset: Bool, expiresAt: Date?)
    case INTERNAL(internalErr: String)
    case CRITICAL(offerRestart: Bool, criticalErr: String)
    case INACTIVE
    case NO_NAME_SERVERS
}

public enum NameErrorType: Decodable, Hashable {
    case NO_RESOLVER
    case NOT_FOUND
    case RESOLVER(resolverErr: String)
}

public enum CommandErrorType: Decodable, Hashable {
    case PROHIBITED
    case SYNTAX
    case NO_CONN
    case SIZE
    case LARGE
}

public enum ConnectionErrorType: Decodable, Hashable {
    case NOT_FOUND
    case DUPLICATE
    case ONE_WAY
    case NOT_ACCEPTED
    case NOT_AVAILABLE
}

public enum BrokerErrorType: Decodable, Hashable {
    case RESPONSE(smpErr: String)
    case UNEXPECTED
    case NETWORK(networkError: NetworkError)
    case HOST
    case TRANSPORT(transportErr: ProtocolTransportError)
    case TIMEOUT
}

public enum ProtocolErrorType: Decodable, Hashable {
    case BLOCK
    case SESSION
    case CMD(cmdErr: ProtocolCommandError)
    indirect case PROXY(proxyErr: ProxyError)
    case AUTH
    case BLOCKED(blockInfo: BlockingInfo)
    case CRYPTO
    case QUOTA
    case STORE(storeErr: String)
    case NO_MSG
    case LARGE_MSG
    case EXPIRED
    case INTERNAL
    case NAME(nameErr: NameErrorType)
}

public enum ProxyError: Decodable, Hashable {
    case PROTOCOL(protocolErr: ProtocolErrorType)
    case BROKER(brokerErr: BrokerErrorType)
    case BASIC_AUTH
    case NO_SESSION
}

public struct BlockingInfo: Decodable, Equatable, Hashable {
    public var reason: BlockingReason
}

public enum BlockingReason: String, Decodable {
    case spam
    case content

    public var text: String {
        switch self {
        case .spam: NSLocalizedString("Spam", comment: "blocking reason")
        case .content: NSLocalizedString("Content violates conditions of use", comment: "blocking reason")
        }
    }
}

public enum XFTPErrorType: Decodable, Hashable {
    case BLOCK
    case SESSION
    case CMD(cmdErr: ProtocolCommandError)
    case AUTH
    case BLOCKED(blockInfo: BlockingInfo)
    case SIZE
    case QUOTA
    case DIGEST
    case CRYPTO
    case NO_FILE
    case HAS_FILE
    case FILE_IO
    case TIMEOUT
    case REDIRECT(redirectError: String)
    case INTERNAL
}

public enum ProxyClientError: Decodable, Hashable {
    case protocolError(protocolErr: ProtocolErrorType)
    case unexpectedResponse(responseStr: String)
    case responseError(responseErr: ProtocolErrorType)
}

public enum RCErrorType: Decodable, Hashable {
    case `internal`(internalErr: String)
    case identity
    case noLocalAddress
    case newController
    case notDiscovered
    case tlsStartFailed
    case exception(exception: String)
    case ctrlAuth
    case ctrlNotFound
    case ctrlError(ctrlErr: String)
    case version
    case encrypt
    case decrypt
    case blockSize
    case syntax(syntaxErr: String)
}

public enum ProtocolCommandError: Decodable, Hashable {
    case UNKNOWN
    case SYNTAX
    case PROHIBITED
    case NO_AUTH
    case HAS_AUTH
    case NO_ENTITY
}

public enum NetworkError: Decodable, Hashable {
    case connectError(connectError: String)
    case tLSError(tlsError: String)
    case unknownCAError
    case failedError
    case timeoutError
    case subscribeError(subscribeError: String)
}

public enum ProtocolTransportError: Decodable, Hashable {
    case badBlock
    case version
    case largeMsg
    case badSession
    case noServerAuth
    case handshake(handshakeErr: SMPHandshakeError)
}

public enum SMPHandshakeError: Decodable, Hashable {
    case PARSE
    case VERSION
    case IDENTITY
    case BAD_AUTH
}

public enum SMPAgentError: Decodable, Hashable {
    case A_MESSAGE
    case A_PROHIBITED(prohibitedErr: String)
    case A_VERSION
    case A_LINK(linkErr: String)
    case A_CRYPTO
    case A_DUPLICATE
    case A_QUEUE(queueErr: String)
    case A_SERVICE(serviceError: AgentServiceError)
}

public enum AgentServiceError: Decodable, Hashable {
    case rejected
    case timeout
    case noPendingRequest
    case notDRAddress
    case badSignature
}

public enum ArchiveError: Decodable, Hashable {
    case `import`(importError: String)
    case fileError(file: String, fileError: String)
}

public enum RemoteCtrlError: Decodable, Hashable {
    case inactive
    case badState
    case busy
    case timeout
    case noKnownControllers
    case badController
    case disconnected(remoteCtrlId: Int64, reason: String)
    case badInvitation
    case badVersion(appVersion: String)
    case hTTP2Error(http2Error: String)
    case protocolError(protocolErr: ProtocolErrorType)
}

public struct AppFilePaths: Encodable {
    public let appFilesFolder: String
    public let appTempFolder: String
    public let appAssetsFolder: String
    
    public init(appFilesFolder: String, appTempFolder: String, appAssetsFolder: String) {
        self.appFilesFolder = appFilesFolder
        self.appTempFolder = appTempFolder
        self.appAssetsFolder = appAssetsFolder
    }
}
