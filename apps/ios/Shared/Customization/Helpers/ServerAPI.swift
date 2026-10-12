// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/helpers
import Foundation
import os
import POPOPXSwitch

struct RemoteServerConfig: Codable {
    let iceServers: [String]?
    let presetOperators: [RemoteOperatorConfig]?
    let botDirectory: [BotDirectoryEntry]?
    let chatRelays: [RemoteChatRelayConfig]?

    enum CodingKeys: String, CodingKey {
        case iceServers = "ice_servers"
        case presetOperators = "preset_operators"
        case botDirectory = "bot_directory"
        case chatRelays = "chat_relays"
    }
}

struct RemoteChatRelayConfig: Codable, Identifiable {
    let name: String
    let url: String
    let domains: [String]?
    let enabled: Bool?

    var id: String { url }
    var isEnabled: Bool { enabled ?? true }
}

struct RemoteOperatorConfig: Codable {
    let operatorTag: String
    let tradeName: String?
    let smpServers: [String]?
    let xftpServers: [String]?

    enum CodingKeys: String, CodingKey {
        case operatorTag = "operator_tag"
        case tradeName = "trade_name"
        case smpServers = "smp_servers"
        case xftpServers = "xftp_servers"
    }
}

enum RemoteConfigCache {
    private static let cacheKey = "remote_server_config"
    private static let cacheTimeKey = "remote_server_config_time"

    static func save(_ config: RemoteServerConfig) {
        if let data = try? JSONEncoder().encode(config) {
            if let encrypted = try? CryptoEncrypt.shared.encrypt(data) {
                UserDefaults.standard.set(encrypted, forKey: cacheKey)
                UserDefaults.standard.set(Date(), forKey: cacheTimeKey)
            }
        }
    }

    static func load() -> RemoteServerConfig? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decrypted = try? CryptoEncrypt.shared.decrypt(data) else { return nil }
        return try? JSONDecoder().decode(RemoteServerConfig.self, from: decrypted)
    }

    static func lastFetchTime() -> Date? {
        UserDefaults.standard.object(forKey: cacheTimeKey) as? Date
    }

    static func cachedIceServerStrings() -> [String]? {
        load()?.iceServers
    }
}

struct ServerAPI {
    static let shared = ServerAPI()

    private let session = PinnedURLSession.shared

    private static let allowedHosts: Set<String> = ["api.popopxchat.com"]

    static var backendURL: String {
        let stored = groupDefaults.string(forKey: "backend_base_url")
        let url = stored ?? "https://api.popopxchat.com"
        guard url.hasPrefix("https://") else { return "https://api.popopxchat.com" }
        return url
    }

    private func validateURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host else { return false }
        return Self.allowedHosts.contains(host)
    }

    func get(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        guard var url = ServerConfig.url(for: endpoint) else {
            throw ServerError.invalidURL
        }
        guard validateURL(url) else {
            throw ServerError.invalidURL
        }
        if let queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            if let resolved = components?.url { url = resolved }
        }
        guard validateURL(url) else {
            throw ServerError.invalidURL
        }
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        addAuthHeaders(&request)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    func post(_ endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = ServerConfig.url(for: endpoint) else {
            throw ServerError.invalidURL
        }
        guard validateURL(url) else {
            throw ServerError.invalidURL
        }
        guard JSONSerialization.isValidJSONObject(body) else {
            throw ServerError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        addAuthHeaders(&request)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    // MARK: - Remote Server Config

    func fetchServerConfig() async throws -> RemoteServerConfig {
        guard let url = ServerConfig.url(for: "servers/config") else {
            throw ServerError.invalidURL
        }
        guard validateURL(url) else {
            throw ServerError.invalidURL
        }
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        addAuthHeaders(&request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let config: RemoteServerConfig
        do {
            config = try JSONDecoder().decode(RemoteServerConfig.self, from: data)
        } catch {
            os_log(.error, "ServerAPI: failed to decode RemoteServerConfig: %{public}@", String(describing: error))
            throw ServerError.decodingError
        }
        RemoteConfigCache.save(config)

        if let jsonData = try? JSONEncoder().encode(config),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            do {
                let _: ChatResponse0? = try await chatSendCmd(.apiUpdateRemoteConfig(json: jsonString), log: false)
            } catch {
                os_log(.error, "ServerAPI: failed to sync remote config to chat controller: %{public}@", String(describing: error))
            }
        }

        return config
    }

    // MARK: - Device Registration

    func registerDevice() async {
        guard !groupDefaults.bool(forKey: "device_registered") else { return }

        let deviceId = EntitlementStore.shared.deviceId
        guard !deviceId.isEmpty else {
            os_log(.error, "ServerAPI: device registration skipped — empty deviceId")
            return
        }

        let region = Locale.current.region?.identifier ?? ""
        let locale = Locale.current.identifier
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let body: [String: Any] = [
            "device_id": deviceId,
            "storefront_country": region,
            "locale": locale,
            "app_version": appVersion,
            "platform": "iOS",
        ]

        do {
            guard let url = ServerConfig.url(for: "device/register") else {
                os_log(.error, "ServerAPI: device registration failed — invalid URL")
                return
            }
            guard validateURL(url) else {
                os_log(.error, "ServerAPI: device registration failed — URL validation failed")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            addAuthHeaders(&request)
            let (_, response) = try await session.data(for: request)
            try validateResponse(response)
            groupDefaults.set(true, forKey: "device_registered")
            os_log(.info, "ServerAPI: device registered successfully")
        } catch {
            os_log(.error, "ServerAPI: device registration failed (will retry): %{public}@", error.localizedDescription)
        }
    }

    private func addAuthHeaders(_ request: inout URLRequest) {
        if let token = Self.loadAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let deviceId = EntitlementStore.shared.deviceId
        request.addValue(deviceId, forHTTPHeaderField: "X-Device-ID")
    }

    // MARK: - Auth Token (Keychain)

    private static let authTokenKey = "com.popopxchat.popopx.authToken"

    static func saveAuthToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.popopxchat.popopx",
            kSecAttrAccount as String: authTokenKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrAccessGroup as String: ACCESS_GROUP,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            os_log(.error, "ServerAPI: failed to save auth token to Keychain: %d", Int(status))
        }
    }

    static func loadAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.popopxchat.popopx",
            kSecAttrAccount as String: authTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: ACCESS_GROUP,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    static func clearAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.popopxchat.popopx",
            kSecAttrAccount as String: authTokenKey,
            kSecAttrAccessGroup as String: ACCESS_GROUP,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            os_log(.error, "ServerAPI: response is not HTTPURLResponse")
            throw ServerError.invalidRequest
        }
        if http.statusCode >= 400 {
            os_log(.error, "ServerAPI: HTTP %d error", Int(http.statusCode))
            throw ServerError.httpError(statusCode: http.statusCode)
        }
    }
}

enum ServerError: Error, LocalizedError {
    case invalidURL
    case invalidRequest
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return NSLocalizedString("server_api_invalid_url", comment: "Invalid server URL")
        case .invalidRequest: return NSLocalizedString("server_api_invalid_body", comment: "Invalid request body")
        case .httpError(let code): return String(format: NSLocalizedString("server_api_error", comment: "Server error"), code)
        case .decodingError: return NSLocalizedString("server_api_parse_failed", comment: "Failed to parse server response")
        }
    }
}

