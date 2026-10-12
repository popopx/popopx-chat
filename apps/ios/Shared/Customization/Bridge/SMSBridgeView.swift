// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/14-FEATURE-DEVELOPER-BRIDGE.md
import SwiftUI
import Combine
import Security
import os
import POPOPXSwitch

// MARK: - SMS Message Model

struct SMSMessage: Identifiable, Equatable {
    let id: String
    let fromNumber: String
    let body: String
    let receivedAt: Date
}

// MARK: - SMS Provider

enum SMSProvider: String, CaseIterable, Identifiable {
    case twilio = "Twilio"
    case vonage = "Vonage"
    case custom = "Custom"

    var id: String { rawValue }
}

// MARK: - SMS Bridge Errors

enum SMSBridgeError: LocalizedError {
    case invalidConfig
    case authenticationFailed
    case networkError(String)
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfig: return NSLocalizedString("Phone number and API key are required.", comment: "SMS bridge invalid config error")
        case .authenticationFailed: return NSLocalizedString("API key rejected by provider. Check your credentials.", comment: "SMS bridge auth failed error")
        case .networkError(let detail): return String(format: NSLocalizedString("Network error: %@", comment: "SMS bridge network error"), detail)
        case .providerError(let detail): return String(format: NSLocalizedString("Provider error: %@", comment: "SMS bridge provider error"), detail)
        }
    }
}

// MARK: - SMS Keychain Store

private enum SMSKeychainStore {
    private static let service = "com.popopx.smsbridge"
    private static let account = "apiKey"

    static func save(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - SMS Provider Client

private enum SMSProviderClient {
    struct ProviderEndpoint {
        let baseURL: String
        let messagesPath: String
        let authHeader: String
        let authPrefix: String
    }

    static func endpoint(for provider: String) -> ProviderEndpoint {
        switch provider {
        case "Twilio":
            return ProviderEndpoint(
                baseURL: "https://api.twilio.com/2010-04-01",
                messagesPath: "/Accounts/{accountId}/Messages.json",
                authHeader: "Authorization",
                authPrefix: "Basic "
            )
        case "Vonage":
            return ProviderEndpoint(
                baseURL: "https://rest.nexmo.com",
                messagesPath: "/sms",
                authHeader: "Authorization",
                authPrefix: "Bearer "
            )
        default:
            return ProviderEndpoint(
                baseURL: "https://api.example.com",
                messagesPath: "/sms",
                authHeader: "X-API-Key",
                authPrefix: ""
            )
        }
    }

    static func validateConnection(provider: String, apiKey: String, phoneNumber: String) async throws -> String {
        let endpoint = self.endpoint(for: provider)
        let url: URL
        let request: URLRequest

        switch provider {
        case "Twilio":
            guard let u = URL(string: "\(endpoint.baseURL)/Accounts/\(phoneNumber)/Messages.json?PageSize=1") else {
                throw SMSBridgeError.invalidConfig
            }
            url = u
            var req = URLRequest(url: url)
            guard let credData = "\(phoneNumber):\(apiKey)".data(using: .utf8) else {
                throw SMSBridgeError.invalidConfig
            }
            let credentials = credData.base64EncodedString()
            req.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            req.httpMethod = "GET"
            request = req

        case "Vonage":
            guard let u = URL(string: "\(endpoint.baseURL)/account/get-balance") else {
                throw SMSBridgeError.invalidConfig
            }
            url = u
            var req = URLRequest(url: url)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.httpMethod = "GET"
            request = req

        default:
            guard let u = URL(string: "\(endpoint.baseURL)/health") else {
                throw SMSBridgeError.invalidConfig
            }
            url = u
            var req = URLRequest(url: url)
            req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            req.httpMethod = "GET"
            request = req
        }

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse else {
            throw SMSBridgeError.networkError("Invalid response")
        }

        switch httpResp.statusCode {
        case 200:
            return String(format: NSLocalizedString("%@ connection verified. Endpoint responded successfully.", comment: "SMS provider connection verified"), provider)
        case 401, 403:
            throw SMSBridgeError.authenticationFailed
        case 404:
            throw SMSBridgeError.providerError("Endpoint not found. Check phone number format.")
        default:
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw SMSBridgeError.providerError("HTTP \(httpResp.statusCode): \(body.prefix(200))")
        }
    }

    static func fetchMessages(provider: String, apiKey: String, phoneNumber: String, limit: Int = 20) async throws -> [SMSMessage] {
        let endpoint = self.endpoint(for: provider)

        let url: URL
        let request: URLRequest

        switch provider {
        case "Twilio":
            guard let u = URL(string: "\(endpoint.baseURL)/Accounts/\(phoneNumber)/Messages.json?PageSize=\(limit)&To=\(phoneNumber)") else {
                throw SMSBridgeError.invalidConfig
            }
            url = u
            var req = URLRequest(url: url)
            guard let credData = "\(phoneNumber):\(apiKey)".data(using: .utf8) else {
                throw SMSBridgeError.invalidConfig
            }
            let credentials = credData.base64EncodedString()
            req.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            request = req

        default:
            guard let u = URL(string: "\(endpoint.baseURL)/messages?phone=\(phoneNumber)&limit=\(limit)") else {
                throw SMSBridgeError.invalidConfig
            }
            url = u
            var req = URLRequest(url: url)
            req.setValue(apiKey, forHTTPHeaderField: endpoint.authHeader)
            request = req
        }

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw SMSBridgeError.networkError("Failed to fetch messages")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        // Twilio returns { "messages": [...] }
        let messagesArray: [[String: Any]]
        if let twilioMessages = json["messages"] as? [[String: Any]] {
            messagesArray = twilioMessages
        } else if let records = json["records"] as? [[String: Any]] {
            messagesArray = records
        } else {
            return []
        }

        return messagesArray.compactMap { msg in
            let from = (msg["from"] as? String) ?? "Unknown"
            let body = (msg["body"] as? String) ?? ""
            let dateStr = (msg["date_created"] as? String) ?? (msg["received_at"] as? String) ?? ""
            let id = (msg["sid"] as? String) ?? (msg["id"] as? String) ?? UUID().uuidString

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            let date = formatter.date(from: dateStr) ?? Date()

            return SMSMessage(id: id, fromNumber: from, body: body, receivedAt: date)
        }
    }
}

// MARK: - SMS Bridge Manager

@MainActor
final class SMSBridgeManager: ObservableObject {
    @Published var phoneNumber: String = ""
    @Published var apiKey: String = ""
    @Published var provider: String = SMSProvider.twilio.rawValue
    @Published var isConnected: Bool = false
    @Published var isTesting: Bool = false
    @Published var testResult: String?
    @Published var forwardedMessages: [SMSMessage] = []

    private let defaultsKey = "smsBridgeConfig"

    private struct StoredConfig: Codable {
        var phoneNumber: String
        var provider: String
    }

    init() {
        loadConfig()
        if let stored = SMSKeychainStore.load() {
            self.apiKey = stored
        }
    }

    // MARK: - Persistence

    func saveConfig() {
        let config = StoredConfig(
            phoneNumber: phoneNumber,
            provider: provider
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        if !apiKey.isEmpty {
            _ = SMSKeychainStore.save(apiKey)
        }
    }

    private func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let config = try? JSONDecoder().decode(StoredConfig.self, from: data) else {
            return
        }
        phoneNumber = config.phoneNumber
        provider = config.provider
    }

    // MARK: - Validation

    private var isConfigValid: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty &&
        !provider.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    func connect() {
        guard isConfigValid else {
            testResult = SMSBridgeError.invalidConfig.localizedDescription
            return
        }
        saveConfig()
        isTesting = true
        testResult = nil

        Task {
            do {
                let message = try await SMSProviderClient.validateConnection(
                    provider: provider, apiKey: apiKey, phoneNumber: phoneNumber
                )
                isTesting = false
                isConnected = true
                testResult = message
            } catch {
                isTesting = false
                isConnected = false
                testResult = error.localizedDescription
            }
        }
    }

    func disconnect() {
        isConnected = false
        testResult = nil
        forwardedMessages = []
    }

    func testConnection() {
        guard !phoneNumber.isEmpty && !apiKey.isEmpty else {
            testResult = NSLocalizedString("Configure phone number and API key before testing.", comment: "SMS bridge test connection guard message")
            return
        }
        isTesting = true
        testResult = nil
        Task {
            do {
                let message = try await SMSProviderClient.validateConnection(
                    provider: provider, apiKey: apiKey, phoneNumber: phoneNumber
                )
                isTesting = false
                testResult = message
            } catch {
                isTesting = false
                testResult = error.localizedDescription
            }
        }
    }

    func checkNewMessages() {
        guard isConnected else {
            testResult = NSLocalizedString("Not connected. Connect first to check messages.", comment: "SMS bridge not connected guard message")
            return
        }
        Task {
            do {
                let messages = try await SMSProviderClient.fetchMessages(
                    provider: provider, apiKey: apiKey, phoneNumber: phoneNumber
                )
                let existingIds = Set(forwardedMessages.map(\.id))
                let newOnly = messages.filter { !existingIds.contains($0.id) }
                if !newOnly.isEmpty {
                    forwardedMessages.insert(contentsOf: newOnly, at: 0)
                }
                testResult = String(format: NSLocalizedString("Fetched %d messages, %d new.", comment: "SMS bridge fetched messages count"), messages.count, newOnly.count)
            } catch {
                testResult = error.localizedDescription
            }
        }
    }
}

// MARK: - SMS Bridge View

struct SMSBridgeView: View {
    @StateObject private var manager = SMSBridgeManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 28))
                        .foregroundColor(QuantumColors.accentSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("bridge_sms_title", comment: "SMS Bridge header title"))
                            .font(QuantumFonts.headerTitle)
                            .foregroundColor(QuantumColors.textPrimary)
                        Text(NSLocalizedString("bridge_sms_subtitle", comment: "SMS Bridge subtitle"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                    }
                    Spacer()
                    connectionIndicator
                }
                .padding(16)
                .glassBackground(cornerRadius: 14)

                // Configuration form
                VStack(alignment: .leading, spacing: 14) {
                    Text(NSLocalizedString("bridge_sms_configuration", comment: "SMS bridge configuration section header"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("bridge_sms_phone_number", comment: "SMS bridge phone number field label"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        TextField("+1-555-0100", text: $manager.phoneNumber)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .keyboardType(.phonePad)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassBackground(cornerRadius: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                            )
                            .accessibilityLabel(NSLocalizedString("Phone number for SMS bridge", comment: "SMS bridge phone number field accessibility"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("bridge_sms_api_key", comment: "SMS bridge API key field label"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        SecureField(NSLocalizedString("bridge_sms_provider_api_key", comment: "SMS bridge provider API key placeholder"), text: $manager.apiKey)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassBackground(cornerRadius: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                            )
                            .accessibilityLabel(NSLocalizedString("API key (not stored)", comment: "SMS bridge API key field accessibility"))
                    }

                    Text(NSLocalizedString("bridge_sms_api_key_note", comment: "SMS bridge API key storage note"))
                        .font(QuantumFonts.encryptionLabel)
                        .foregroundColor(QuantumColors.textTertiary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("bridge_sms_provider", comment: "SMS bridge provider field label"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        Picker(NSLocalizedString("bridge_sms_provider_picker", comment: "SMS provider picker label"), selection: $manager.provider) {
                            ForEach(SMSProvider.allCases) { p in
                                Text(p.rawValue).tag(p.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(NSLocalizedString("SMS provider selection", comment: "SMS bridge provider picker accessibility"))
                    }
                }
                .padding(16)
                .glassBackground()

                // Connection controls
                VStack(spacing: 12) {
                    Button {
                        if manager.isConnected {
                            manager.disconnect()
                        } else {
                            manager.connect()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: manager.isConnected ? "link.slash" : "link")
                            Text(manager.isConnected ? NSLocalizedString("bridge_sms_disconnect", comment: "SMS bridge disconnect button") : NSLocalizedString("bridge_sms_connect", comment: "SMS bridge connect button"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassProminentButton()
                    }
                    .disabled(!manager.isConnected && !isFormFilled)
                    .opacity(!manager.isConnected && !isFormFilled ? 0.6 : 1.0)
                    .accessibilityLabel(manager.isConnected ? NSLocalizedString("Disconnect SMS bridge", comment: "SMS bridge disconnect accessibility") : NSLocalizedString("Connect SMS bridge", comment: "SMS bridge connect accessibility"))

                    HStack(spacing: 12) {
                        Button {
                            manager.testConnection()
                        } label: {
                            HStack(spacing: 6) {
                                if manager.isTesting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.7)
                                }
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text(NSLocalizedString("bridge_sms_test_connection", comment: "SMS bridge test connection button"))
                            }
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accentSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassButtonStyle()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(manager.isTesting)
                        .accessibilityLabel(NSLocalizedString("Test SMS connection", comment: "SMS bridge test connection button accessibility"))

                        Button {
                            manager.checkNewMessages()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                Text(NSLocalizedString("bridge_sms_check_messages", comment: "SMS bridge check messages button"))
                            }
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accentSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassButtonStyle()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel(NSLocalizedString("Check for new SMS messages", comment: "SMS bridge check messages button accessibility"))
                    }

                    if let result = manager.testResult {
                        HStack(spacing: 8) {
                            Image(systemName: result.contains("failed") || result.contains("fill") || result.contains("Configure")
                                  ? "exclamationmark.triangle.fill"
                                  : "checkmark.circle.fill")
                                .foregroundColor(result.contains("failed") || result.contains("fill") || result.contains("Configure")
                                                 ? QuantumColors.error
                                                 : QuantumColors.success)
                            Text(result)
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .glassBackground(cornerRadius: 10)
                        .accessibilityLabel(String(format: NSLocalizedString("Test result: %@", comment: "SMS bridge test result accessibility"), result))
                    }
                }
                .padding(16)
                .glassBackground()

                // Forwarded messages
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("bridge_sms_forwarded_messages", comment: "SMS bridge forwarded messages section header"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                        Spacer()
                        Text("\(manager.forwardedMessages.count)")
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accentSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassBackground(cornerRadius: 8)
                    }

                    if manager.forwardedMessages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(QuantumColors.textTertiary)
                            Text(NSLocalizedString("bridge_sms_no_messages_yet", comment: "SMS bridge no forwarded messages empty state"))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(manager.forwardedMessages) { msg in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(QuantumColors.accentSecondary)
                                        .font(.system(size: 14))
                                    Text(msg.fromNumber)
                                        .font(QuantumFonts.caption)
                                        .foregroundColor(QuantumColors.accentSecondary)
                                    Spacer()
                                    Text(msg.receivedAt, style: .time)
                                        .font(QuantumFonts.encryptionLabel)
                                        .foregroundColor(QuantumColors.textTertiary)
                                }
                                Text(msg.body)
                                    .font(QuantumFonts.body)
                                    .foregroundColor(QuantumColors.textPrimary)
                                    .lineLimit(3)
                            }
                            .padding(12)
                            .glassBackground(cornerRadius: 10)
                            .accessibilityLabel(String(format: NSLocalizedString("SMS from %@: %@", comment: "SMS bridge forwarded message accessibility"), msg.fromNumber, msg.body))
                        }
                    }
                }
                .padding(16)
                .glassBackground()
            }
            .padding(16)
        }
        .background(QuantumGradients.background)
        .navigationTitle(NSLocalizedString("bridge_sms_navigation_title", comment: "SMS Bridge navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }

    // MARK: - Helpers

    private var isFormFilled: Bool {
        !manager.phoneNumber.isEmpty &&
        !manager.apiKey.isEmpty &&
        !manager.provider.isEmpty
    }

    @ViewBuilder
    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(manager.isConnected ? QuantumColors.success : QuantumColors.error)
                .frame(width: 10, height: 10)
                .shadow(
                    color: (manager.isConnected ? QuantumColors.success : QuantumColors.error).opacity(0.6),
                    radius: 4
                )
            Text(manager.isConnected ? NSLocalizedString("bridge_sms_connected", comment: "SMS bridge connected status") : NSLocalizedString("bridge_sms_disconnected", comment: "SMS bridge disconnected status"))
                .font(QuantumFonts.encryptionLabel)
                .foregroundColor(manager.isConnected ? QuantumColors.success : QuantumColors.textSecondary)
        }
        .accessibilityLabel(manager.isConnected ? NSLocalizedString("Status: connected", comment: "SMS bridge connected status accessibility") : NSLocalizedString("Status: disconnected", comment: "SMS bridge disconnected status accessibility"))
    }
}
