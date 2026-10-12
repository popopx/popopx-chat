// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/14-FEATURE-DEVELOPER-BRIDGE.md
import SwiftUI
import Combine
import Foundation
import Security
import os
import POPOPXSwitch

// MARK: - Email Bridge Errors

enum EmailBridgeError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case tlsNegotiationFailed
    case invalidResponse(String)
    case timeout
    case passwordNotAvailable

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let detail):
            return String(format: NSLocalizedString("Connection failed: %@", comment: "Email bridge connection failed error"), detail)
        case .authenticationFailed:
            return NSLocalizedString("Authentication failed. Check your email and password.", comment: "Email bridge auth failed error")
        case .tlsNegotiationFailed:
            return NSLocalizedString("TLS negotiation failed. The server may not support encryption.", comment: "Email bridge TLS failed error")
        case .invalidResponse(let detail):
            return String(format: NSLocalizedString("Unexpected server response: %@", comment: "Email bridge invalid response error"), detail)
        case .timeout:
            return NSLocalizedString("Connection timed out. Check the host and port settings.", comment: "Email bridge timeout error")
        case .passwordNotAvailable:
            return NSLocalizedString("Password could not be retrieved from Keychain.", comment: "Email bridge password not available error")
        }
    }
}

// MARK: - Keychain Password Store

private enum KeychainPasswordStore {
    private static let service = "com.popopx.emailbridge"
    private static let account = "emailPassword"

    static func save(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrAccessGroup as String: ACCESS_GROUP
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
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
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
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

// MARK: - TCP Stream Helpers

private enum StreamOp {
    /// Read a single line (terminated by \r\n) from the input stream.
    static func readLine(from input: InputStream, timeout: TimeInterval = 15) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var buffer = [UInt8]()
        var gotCR = false

        while Date() < deadline {
            if input.hasBytesAvailable {
                var byte: UInt8 = 0
                let count = input.read(&byte, maxLength: 1)
                if count == 0 { break }
                if count < 0 {
                    throw EmailBridgeError.connectionFailed(
                        input.streamError?.localizedDescription ?? "Read error")
                }
                if gotCR && byte == 0x0A { // \n
                    break
                }
                gotCR = (byte == 0x0D) // \r
                if byte != 0x0D && byte != 0x0A {
                    buffer.append(byte)
                }
            } else if input.streamStatus == .atEnd {
                break
            } else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
        }
        return String(bytes: buffer, encoding: .utf8) ?? ""
    }

    /// Read a multi-line IMAP response until we see a line starting with the given tag.
    static func readTaggedResponse(from input: InputStream, tag: String,
                                   timeout: TimeInterval = 15) throws -> [String] {
        let deadline = Date().addingTimeInterval(timeout)
        var lines: [String] = []

        while Date() < deadline {
            let line = try readLine(from: input, timeout: max(0.1, deadline.timeIntervalSinceNow))
            lines.append(line)
            if line.hasPrefix(tag) {
                return lines
            }
        }
        throw EmailBridgeError.timeout
    }

    /// Write a string followed by \r\n to the output stream.
    static func writeLine(_ string: String, to output: OutputStream) throws {
        guard let data = (string + "\r\n").data(using: .utf8) else { return }
        var bytesWritten = 0
        let totalBytes = data.count
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw EmailBridgeError.connectionFailed("Invalid data buffer")
            }
            while bytesWritten < totalBytes {
                let count = output.write(baseAddress.advanced(by: bytesWritten),
                                         maxLength: totalBytes - bytesWritten)
                if count < 0 {
                    throw EmailBridgeError.connectionFailed(
                        output.streamError?.localizedDescription ?? "Write error")
                }
                bytesWritten += count
            }
        }
    }

    /// Open streams to a host:port, returning (input, output).
    static func openStreams(host: String, port: Int, timeout: TimeInterval = 15) throws -> (InputStream, OutputStream) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            host as CFString,
            UInt32(port),
            &readStream,
            &writeStream
        )

        guard let cfInput = readStream?.takeRetainedValue(),
              let cfOutput = writeStream?.takeRetainedValue() else {
            throw EmailBridgeError.connectionFailed("Could not create streams to \(host):\(port)")
        }

        let inStream = cfInput as InputStream
        let outStream = cfOutput as OutputStream

        inStream.open()
        outStream.open()

        // Wait for connection with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while inStream.streamStatus != .open || outStream.streamStatus != .open {
            if Date() > deadline {
                inStream.close()
                outStream.close()
                throw EmailBridgeError.timeout
            }
            if inStream.streamStatus == .error || outStream.streamStatus == .error {
                let err = inStream.streamError ?? outStream.streamError
                inStream.close()
                outStream.close()
                throw EmailBridgeError.connectionFailed(err?.localizedDescription ?? "Stream error")
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return (inStream, outStream)
    }
}

// MARK: - TLS Certificate Validation

/// Validate that the server's TLS certificate is trusted and matches the expected hostname.
/// Returns true if the certificate chain is valid and trusted.
private func validateTLSCertificate(input: InputStream, output: OutputStream, host: String) -> Bool {
    guard let trustInput = input.property(forKey: Stream.PropertyKey.socketSecurityLevelKey) as? String,
          !trustInput.isEmpty else {
        return false
    }
    guard let trust = input.property(forKey: kCFStreamPropertySSLPeerTrust as Stream.PropertyKey) else {
        return false
    }
    let secTrust = trust as! SecTrust
    SecTrustSetPolicies(secTrust, SecPolicyCreateSSL(true, host as CFString))
    var error: CFError?
    let isValid = SecTrustEvaluateWithError(secTrust, &error)
    if !isValid {
        // Close streams on validation failure
        input.close()
        output.close()
    }
    return isValid
}

// MARK: - SMTP Client

final class SMTPClient: @unchecked Sendable {
    private var input: InputStream?
    private var output: OutputStream?
    private(set) var isConnected = false

    /// Connect, perform EHLO, require STARTTLS, then AUTH PLAIN.
    func connect(host smtpHost: String, port: Int, username: String, password: String) throws {
        let (inStream, outStream) = try StreamOp.openStreams(host: smtpHost, port: port)
        self.input = inStream
        self.output = outStream

        // Read server greeting
        let greeting = try StreamOp.readLine(from: inStream)
        guard greeting.hasPrefix("220") else {
            cleanup()
            throw EmailBridgeError.invalidResponse("SMTP greeting: \(greeting)")
        }

        // EHLO
        try StreamOp.writeLine("EHLO \(smtpHost)", to: outStream)
        let ehloResponse = try readMultiLineResponse(expectedPrefix: "250")
        guard !ehloResponse.isEmpty else {
            cleanup()
            throw EmailBridgeError.invalidResponse("EHLO rejected")
        }

        // Require TLS before authentication
        let advertisesStartTLS = ehloResponse.contains { $0.uppercased().contains("STARTTLS") }
        if port == 465 {
            // Implicit TLS — upgrade immediately
            try upgradeToTLS(input: inStream, output: outStream, host: smtpHost)
        } else if port == 587 && advertisesStartTLS {
            try StreamOp.writeLine("STARTTLS", to: outStream)
            let tlsResponse = try StreamOp.readLine(from: inStream)
            guard tlsResponse.hasPrefix("220") else {
                cleanup()
                throw EmailBridgeError.tlsNegotiationFailed
            }
            try upgradeToTLS(input: inStream, output: outStream, host: smtpHost)
            // Re-issue EHLO after TLS upgrade
            try StreamOp.writeLine("EHLO \(smtpHost)", to: outStream)
            let _ = try readMultiLineResponse(expectedPrefix: "250")
        } else {
            cleanup()
            throw EmailBridgeError.tlsNegotiationFailed
        }

        // AUTH PLAIN (only over TLS)
        let credentials = "\0\(username)\0\(password)"
        guard let credData = credentials.data(using: .utf8) else {
            cleanup()
            throw EmailBridgeError.authenticationFailed
        }
        let encoded = credData.base64EncodedString()
        try StreamOp.writeLine("AUTH PLAIN \(encoded)", to: outStream)
        let authResponse = try StreamOp.readLine(from: inStream)
        guard authResponse.hasPrefix("235") else {
            cleanup()
            throw EmailBridgeError.authenticationFailed
        }

        isConnected = true
    }

    func disconnect() {
        guard let out = output else { return }
        try? StreamOp.writeLine("QUIT", to: out)
        cleanup()
    }

    // MARK: - Private

    private func readMultiLineResponse(expectedPrefix: String) throws -> [String] {
        guard let inStream = input else { throw EmailBridgeError.connectionFailed("No input stream") }
        var lines: [String] = []
        let deadline = Date().addingTimeInterval(15)

        while Date() < deadline {
            let line = try StreamOp.readLine(from: inStream)
            lines.append(line)
            // SMTP multi-line: "250-..." continues, "250 ..." is final
            if line.hasPrefix(expectedPrefix) {
                guard line.count > 3 else { break }
                let fourthChar = line[line.index(line.startIndex, offsetBy: 3)]
                if fourthChar == Character(" ") {
                    break
                }
            }
        }
        return lines
    }

    private func upgradeToTLS(input oldInput: InputStream, output oldOutput: OutputStream, host: String) throws {
        // Enforce secure transport with minimum TLS 1.2 using CFStream APIs
        let sslSettings: [NSString: Any] = [
            kCFStreamSSLLevel: "kCFStreamSocketSecurityLevelTLSv1_2",
            kCFStreamSSLValidatesCertificateChain: true
        ]
        oldInput.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
        oldOutput.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)

        oldInput.setProperty(StreamSocketSecurityLevel.negotiatedSSL,
                            forKey: Stream.PropertyKey.socketSecurityLevelKey)
        oldOutput.setProperty(StreamSocketSecurityLevel.negotiatedSSL,
                             forKey: Stream.PropertyKey.socketSecurityLevelKey)

        // Wait for TLS handshake
        let deadline = Date().addingTimeInterval(10)
        while oldInput.streamStatus != .open || oldOutput.streamStatus != .open {
            if Date() > deadline {
                throw EmailBridgeError.tlsNegotiationFailed
            }
            if oldInput.streamStatus == .error || oldOutput.streamStatus == .error {
                throw EmailBridgeError.tlsNegotiationFailed
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        // Validate server certificate
        guard validateTLSCertificate(input: oldInput, output: oldOutput, host: host) else {
            throw EmailBridgeError.tlsNegotiationFailed
        }

        // Verify secure transport is active
        guard let securityLevel = oldInput.property(forKey: Stream.PropertyKey.socketSecurityLevelKey) as? String,
              securityLevel == StreamSocketSecurityLevel.negotiatedSSL.rawValue else {
            oldInput.close()
            oldOutput.close()
            throw EmailBridgeError.tlsNegotiationFailed
        }

        self.input = oldInput
        self.output = oldOutput
    }

    private func cleanup() {
        input?.close()
        output?.close()
        input = nil
        output = nil
        isConnected = false
    }
}

// MARK: - IMAP Client

final class IMAPClient: @unchecked Sendable {
    private var input: InputStream?
    private var output: OutputStream?
    private(set) var isConnected = false
    private var tagCounter = 0

    private func nextTag() -> String {
        tagCounter += 1
        return String(format: "a%03d", tagCounter)
    }

    /// Connect, CAPABILITY, require STARTTLS, then LOGIN.
    func connect(host imapHost: String, port: Int, username: String, password: String) throws {
        let (inStream, outStream) = try StreamOp.openStreams(host: imapHost, port: port)
        self.input = inStream
        self.output = outStream

        // Read server greeting (untagged OK)
        let greeting = try StreamOp.readLine(from: inStream)
        guard greeting.contains("OK") else {
            cleanup()
            throw EmailBridgeError.invalidResponse("IMAP greeting: \(greeting)")
        }

        // CAPABILITY
        let capTag = nextTag()
        try StreamOp.writeLine("\(capTag) CAPABILITY", to: outStream)
        let capResponse = try StreamOp.readTaggedResponse(from: inStream, tag: capTag)

        // Require TLS before LOGIN
        if port == 993 {
            // Implicit TLS — upgrade streams to TLS immediately
            try upgradeToTLS(input: inStream, output: outStream, host: imapHost)
        } else if port == 143 {
            let advertisesStartTLS = capResponse.contains { $0.uppercased().contains("STARTTLS") }
            guard advertisesStartTLS else {
                cleanup()
                throw EmailBridgeError.tlsNegotiationFailed
            }
            let starttlsTag = nextTag()
            try StreamOp.writeLine("\(starttlsTag) STARTTLS", to: outStream)
            let tlsResponse = try StreamOp.readTaggedResponse(from: inStream, tag: starttlsTag)
            guard let lastLine = tlsResponse.last, lastLine.hasPrefix("\(starttlsTag) OK") else {
                cleanup()
                throw EmailBridgeError.tlsNegotiationFailed
            }
            try upgradeToTLS(input: inStream, output: outStream, host: imapHost)
        } else {
            cleanup()
            throw EmailBridgeError.tlsNegotiationFailed
        }

        // LOGIN (only over TLS)
        let loginTag = nextTag()
        let escapedUser = imapQuote(username)
        let escapedPass = imapQuote(password)
        try StreamOp.writeLine("\(loginTag) LOGIN \(escapedUser) \(escapedPass)", to: outStream)
        let loginResponse = try StreamOp.readTaggedResponse(from: inStream, tag: loginTag)

        guard let lastLine = loginResponse.last, lastLine.hasPrefix("\(loginTag) OK") else {
            cleanup()
            throw EmailBridgeError.authenticationFailed
        }

        isConnected = true
    }

    /// Fetch recent messages from INBOX (up to `limit` latest).
    func fetchMessages(limit: Int = 20) throws -> [EmailMessage] {
        guard isConnected, let inStream = input, let outStream = output else {
            throw EmailBridgeError.connectionFailed("Not connected")
        }

        // SELECT INBOX
        let selectTag = nextTag()
        try StreamOp.writeLine("\(selectTag) SELECT INBOX", to: outStream)
        let selectResponse = try StreamOp.readTaggedResponse(from: inStream, tag: selectTag)
        guard let lastSelect = selectResponse.last, lastSelect.hasPrefix("\(selectTag) OK") else {
            throw EmailBridgeError.invalidResponse("SELECT INBOX failed")
        }

        // Parse EXISTS count from untagged responses
        var messageCount = 0
        for line in selectResponse {
            if line.contains(" EXISTS") {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
                if let first = parts.first, let count = Int(first) {
                    messageCount = count
                }
            }
        }

        guard messageCount > 0 else { return [] }

        let startSeq = max(1, messageCount - limit + 1)

        // FETCH envelope and body preview
        let fetchTag = nextTag()
        try StreamOp.writeLine("\(fetchTag) FETCH \(startSeq):\(messageCount) (BODY[HEADER.FIELDS (FROM SUBJECT DATE)] BODY[TEXT])", to: outStream)

        // Read all response lines until tagged completion
        let fetchResponse = try StreamOp.readTaggedResponse(from: inStream, tag: fetchTag)
        guard let lastFetch = fetchResponse.last, lastFetch.hasPrefix("\(fetchTag) OK") else {
            throw EmailBridgeError.invalidResponse("FETCH failed")
        }

        return parseIMAPFetchResponse(fetchResponse)
    }

    private func parseIMAPFetchResponse(_ lines: [String]) -> [EmailMessage] {
        var messages: [EmailMessage] = []
        var currentFrom = ""
        var currentSubject = ""
        var currentDate = ""
        var currentBody = ""
        var inHeader = true

        for line in lines {
            if line.hasPrefix("*") && line.contains("FETCH") {
                // Start of a new message
                if !currentFrom.isEmpty || !currentSubject.isEmpty {
                    messages.append(EmailMessage(
                        id: generateSecureID(),
                        from: currentFrom.isEmpty ? NSLocalizedString("email_unknown_sender", comment: "Unknown sender") : currentFrom.trimmingCharacters(in: .whitespacesAndNewlines),
                        subject: currentSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                        body: currentBody.trimmingCharacters(in: .whitespacesAndNewlines),
                        receivedAt: parseIMAPDate(currentDate)
                    ))
                }
                currentFrom = ""
                currentSubject = ""
                currentDate = ""
                currentBody = ""
                inHeader = true
                continue
            }

            if inHeader {
                if line.isEmpty || line == ")" {
                    inHeader = false
                    continue
                }
                if line.uppercased().hasPrefix("FROM:") {
                    currentFrom = String(line.dropFirst(5))
                } else if line.uppercased().hasPrefix("SUBJECT:") {
                    currentSubject = String(line.dropFirst(8))
                } else if line.uppercased().hasPrefix("DATE:") {
                    currentDate = String(line.dropFirst(5))
                }
            } else {
                currentBody += line + "\n"
            }
        }

        // Last message
        if !currentFrom.isEmpty || !currentSubject.isEmpty {
            messages.append(EmailMessage(
                id: generateSecureID(),
                from: currentFrom.isEmpty ? NSLocalizedString("email_unknown_sender", comment: "Unknown sender") : currentFrom.trimmingCharacters(in: .whitespacesAndNewlines),
                subject: currentSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                body: currentBody.trimmingCharacters(in: .whitespacesAndNewlines),
                receivedAt: parseIMAPDate(currentDate)
            ))
        }

        return messages
    }

    private func parseIMAPDate(_ dateStr: String) -> Date {
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Date() }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        if let date = formatter.date(from: trimmed) { return date }
        formatter.dateFormat = "d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: trimmed) ?? Date()
    }

    private func generateSecureID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func disconnect() {
        guard let out = output else { return }
        let tag = nextTag()
        try? StreamOp.writeLine("\(tag) LOGOUT", to: out)
        cleanup()
    }

    // MARK: - Private

    private func imapQuote(_ s: String) -> String {
        // Strip CR and LF to prevent CRLF injection in IMAP commands
        let sanitized = s.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
        if sanitized.contains(" ") || sanitized.contains("\"") || sanitized.contains("\\") {
            let escaped = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return sanitized
    }

    private func upgradeToTLS(input oldInput: InputStream, output oldOutput: OutputStream, host: String) throws {
        // Enforce secure transport with minimum TLS 1.2 using CFStream APIs
        let sslSettings: [NSString: Any] = [
            kCFStreamSSLLevel: "kCFStreamSocketSecurityLevelTLSv1_2",
            kCFStreamSSLValidatesCertificateChain: true
        ]
        oldInput.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
        oldOutput.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)

        oldInput.setProperty(StreamSocketSecurityLevel.negotiatedSSL,
                            forKey: Stream.PropertyKey.socketSecurityLevelKey)
        oldOutput.setProperty(StreamSocketSecurityLevel.negotiatedSSL,
                             forKey: Stream.PropertyKey.socketSecurityLevelKey)

        let deadline = Date().addingTimeInterval(10)
        while oldInput.streamStatus != .open || oldOutput.streamStatus != .open {
            if Date() > deadline {
                throw EmailBridgeError.tlsNegotiationFailed
            }
            if oldInput.streamStatus == .error || oldOutput.streamStatus == .error {
                throw EmailBridgeError.tlsNegotiationFailed
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        // Validate server certificate
        guard validateTLSCertificate(input: oldInput, output: oldOutput, host: host) else {
            throw EmailBridgeError.tlsNegotiationFailed
        }

        // Verify secure transport is active
        guard let securityLevel = oldInput.property(forKey: Stream.PropertyKey.socketSecurityLevelKey) as? String,
              securityLevel == StreamSocketSecurityLevel.negotiatedSSL.rawValue else {
            oldInput.close()
            oldOutput.close()
            throw EmailBridgeError.tlsNegotiationFailed
        }

        self.input = oldInput
        self.output = oldOutput
    }

    private func cleanup() {
        input?.close()
        output?.close()
        input = nil
        output = nil
        isConnected = false
    }
}

// MARK: - Email Message Model

struct EmailMessage: Identifiable, Equatable {
    let id: String
    let from: String
    let subject: String
    let body: String
    let receivedAt: Date
}

// MARK: - Email Bridge Manager

@MainActor
final class EmailBridgeManager: ObservableObject {
    @Published var smtpHost: String = ""
    @Published var smtpPort: Int = 587
    @Published var imapHost: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isConnected: Bool = false
    @Published var isTesting: Bool = false
    @Published var testResult: String?
    @Published var forwardedMessages: [EmailMessage] = []

    private let defaultsKey = "emailBridgeConfig"
    private var smtpClient: SMTPClient?
    private var imapClient: IMAPClient?

    private struct StoredConfig: Codable {
        var smtpHost: String
        var smtpPort: Int
        var imapHost: String
        var email: String
    }

    init() {
        loadConfig()
        // Pre-fill password from Keychain if available
        if let stored = KeychainPasswordStore.load() {
            self.password = stored
        }
    }

    // MARK: - Persistence

    func saveConfig() {
        let config = StoredConfig(
            smtpHost: smtpHost,
            smtpPort: smtpPort,
            imapHost: imapHost,
            email: email
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        // Persist password to Keychain
        if !password.isEmpty {
            _ = KeychainPasswordStore.save(password)
        }
    }

    private func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let config = try? JSONDecoder().decode(StoredConfig.self, from: data) else {
            return
        }
        smtpHost = config.smtpHost
        smtpPort = config.smtpPort
        imapHost = config.imapHost
        email = config.email
    }

    // MARK: - Validation

    private var isConfigValid: Bool {
        !smtpHost.trimmingCharacters(in: .whitespaces).isEmpty &&
        smtpPort > 0 &&
        !imapHost.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    func connect() {
        guard isConfigValid else {
            testResult = NSLocalizedString("Please fill in all fields before connecting.", comment: "Email bridge connect guard message")
            return
        }
        saveConfig()

        Task {
            let result = await performConnection()
            switch result {
            case .success(let clients):
                self.smtpClient = clients.0
                self.imapClient = clients.1
                isConnected = true
                testResult = nil
            case .failure(let error):
                isConnected = false
                testResult = error.localizedDescription
            }
        }
    }

    func disconnect() {
        smtpClient?.disconnect()
        imapClient?.disconnect()
        smtpClient = nil
        imapClient = nil
        isConnected = false
        testResult = nil
    }

    func testConnection() {
        guard !smtpHost.isEmpty && !imapHost.isEmpty && !email.isEmpty else {
            testResult = NSLocalizedString("Configure host and email fields before testing.", comment: "Email bridge test connection guard message")
            return
        }
        guard !password.isEmpty else {
            testResult = NSLocalizedString("Password is required for connection test.", comment: "Email bridge password required guard message")
            return
        }
        isTesting = true
        testResult = nil

        Task {
            let result = await performTestConnection()
            isTesting = false
            switch result {
            case .success(let message):
                testResult = message
            case .failure(let error):
                testResult = error.localizedDescription
            }
        }
    }

    func checkNewMessages() {
        guard let imap = imapClient, imap.isConnected else {
            testResult = NSLocalizedString("Not connected. Connect first to check messages.", comment: "Email bridge not connected guard message")
            return
        }
        Task {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[EmailMessage], EmailBridgeError>, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let messages = try imap.fetchMessages(limit: 20)
                        continuation.resume(returning: .success(messages))
                    } catch let error as EmailBridgeError {
                        continuation.resume(returning: .failure(error))
                    } catch {
                        continuation.resume(returning: .failure(.connectionFailed(error.localizedDescription)))
                    }
                }
            }
            switch result {
            case .success(let messages):
                let existingIds = Set(self.forwardedMessages.map(\.id))
                let newOnly = messages.filter { !existingIds.contains($0.id) }
                if !newOnly.isEmpty {
                    self.forwardedMessages.insert(contentsOf: newOnly, at: 0)
                }
                self.testResult = String(format: NSLocalizedString("Fetched %d messages, %d new.", comment: "Email bridge fetched messages count"), messages.count, newOnly.count)
            case .failure(let error):
                self.testResult = error.localizedDescription
            }
        }
    }

    private func generateSecureID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private Connection Logic

    private func performConnection() async -> Result<(SMTPClient, IMAPClient), EmailBridgeError> {
        let smtpHost = self.smtpHost
        let smtpPort = self.smtpPort
        let imapHost = self.imapHost
        let email = self.email
        let password = self.password
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // SMTP connection
                let smtp = SMTPClient()
                do {
                    try smtp.connect(
                        host: smtpHost,
                        port: smtpPort,
                        username: email,
                        password: password
                    )
                } catch let error as EmailBridgeError {
                    continuation.resume(returning: .failure(error))
                    return
                } catch {
                    continuation.resume(returning: .failure(.connectionFailed(error.localizedDescription)))
                    return
                }

                // IMAP connection
                let imap = IMAPClient()
                let imapPort = smtpPort == 465 ? 993 : (smtpPort == 25 ? 143 : 993)
                do {
                    try imap.connect(
                        host: imapHost,
                        port: imapPort,
                        username: email,
                        password: password
                    )
                } catch let error as EmailBridgeError {
                    smtp.disconnect()
                    continuation.resume(returning: .failure(error))
                    return
                } catch {
                    smtp.disconnect()
                    continuation.resume(returning: .failure(.connectionFailed(error.localizedDescription)))
                    return
                }

                continuation.resume(returning: .success((smtp, imap)))
            }
        }
    }

    private func performTestConnection() async -> Result<String, EmailBridgeError> {
        let smtpHost = self.smtpHost
        let smtpPort = self.smtpPort
        let imapHost = self.imapHost
        let email = self.email
        let password = self.password
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var smtpOK = false
                var imapOK = false
                var errors: [String] = []

                // Test SMTP
                let smtp = SMTPClient()
                do {
                    try smtp.connect(
                        host: smtpHost,
                        port: smtpPort,
                        username: email,
                        password: password
                    )
                    smtpOK = true
                    smtp.disconnect()
                } catch let error as EmailBridgeError {
                    errors.append("SMTP: \(error.localizedDescription)")
                } catch {
                    errors.append("SMTP: \(error.localizedDescription)")
                }

                // Test IMAP
                let imap = IMAPClient()
                let imapPort = smtpPort == 465 ? 993 : (smtpPort == 25 ? 143 : 993)
                do {
                    try imap.connect(
                        host: imapHost,
                        port: imapPort,
                        username: email,
                        password: password
                    )
                    imapOK = true
                    imap.disconnect()
                } catch let error as EmailBridgeError {
                    errors.append("IMAP: \(error.localizedDescription)")
                } catch {
                    errors.append("IMAP: \(error.localizedDescription)")
                }

                if smtpOK && imapOK {
                    continuation.resume(returning: .success(
                        NSLocalizedString("Connection test succeeded. SMTP and IMAP servers responded.", comment: "Email bridge test success message")))
                } else if smtpOK || imapOK {
                    let working = smtpOK ? "SMTP" : "IMAP"
                    let failed = smtpOK ? "IMAP" : "SMTP"
                    let errorDetail = errors.joined(separator: "; ")
                    continuation.resume(returning: .success(
                        String(format: NSLocalizedString("Partial success: %@ connected, but %@ failed. %@", comment: "Email bridge partial test success"), working, failed, errorDetail)))
                } else {
                    let detail = errors.joined(separator: "; ")
                    continuation.resume(returning: .failure(
                        .connectionFailed(String(format: NSLocalizedString("Both servers failed. %@", comment: "Email bridge both servers failed"), detail))))
                }
            }
        }
    }
}

// MARK: - Email Bridge View

struct EmailBridgeView: View {
    @StateObject private var manager = EmailBridgeManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 28))
                        .foregroundColor(QuantumColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("bridge_email_title", comment: "Email Bridge header title"))
                            .font(QuantumFonts.headerTitle)
                            .foregroundColor(QuantumColors.textPrimary)
                        Text(NSLocalizedString("bridge_email_subtitle", comment: "Email Bridge subtitle"))
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
                    Text(NSLocalizedString("bridge_email_configuration", comment: "Email bridge configuration section header"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    glassField(label: NSLocalizedString("bridge_email_smtp_host", comment: "Email bridge SMTP host field label"), text: $manager.smtpHost, placeholder: "smtp.example.com")
                        .accessibilityLabel(NSLocalizedString("SMTP host address", comment: "Email bridge SMTP host accessibility"))

                    HStack(spacing: 10) {
                        Text(NSLocalizedString("bridge_email_port", comment: "Email bridge port field label"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                            .frame(width: 40, alignment: .leading)
                        TextField("587", value: $manager.smtpPort, format: .number)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassBackground(cornerRadius: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                            )
                            .accessibilityLabel(NSLocalizedString("SMTP port number", comment: "Email bridge SMTP port accessibility"))
                    }

                    glassField(label: NSLocalizedString("bridge_email_imap_host", comment: "Email bridge IMAP host field label"), text: $manager.imapHost, placeholder: "imap.example.com")
                        .accessibilityLabel(NSLocalizedString("IMAP host address", comment: "Email bridge IMAP host accessibility"))

                    glassField(label: NSLocalizedString("bridge_email_email", comment: "Email bridge email field label"), text: $manager.email, placeholder: "you@example.com")
                        .accessibilityLabel(NSLocalizedString("Email address", comment: "Email bridge email field accessibility"))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("bridge_email_password", comment: "Email bridge password field label"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        SecureField(NSLocalizedString("bridge_email_app_password", comment: "Email bridge app password field placeholder"), text: $manager.password)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassBackground(cornerRadius: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                            )
                            .accessibilityLabel(NSLocalizedString("Email password (stored in Keychain)", comment: "Email bridge password field accessibility"))
                    }

                    Text(NSLocalizedString("bridge_email_password_note", comment: "Email bridge password encryption note"))
                        .font(QuantumFonts.encryptionLabel)
                        .foregroundColor(QuantumColors.textTertiary)
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
                            Text(manager.isConnected ? NSLocalizedString("bridge_email_disconnect", comment: "Email bridge disconnect button") : NSLocalizedString("bridge_email_connect", comment: "Email bridge connect button"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassProminentButton()
                    }
                    .disabled(!manager.isConnected && !isFormFilled)
                    .opacity(!manager.isConnected && !isFormFilled ? 0.6 : 1.0)
                    .accessibilityLabel(manager.isConnected ? NSLocalizedString("Disconnect email bridge", comment: "Email bridge disconnect accessibility") : NSLocalizedString("Connect email bridge", comment: "Email bridge connect accessibility"))

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
                                Text(NSLocalizedString("bridge_email_test_connection", comment: "Email bridge test connection button"))
                            }
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassButtonStyle()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(manager.isTesting)
                        .accessibilityLabel(NSLocalizedString("Test email connection", comment: "Email bridge test connection button accessibility"))

                        Button {
                            manager.checkNewMessages()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                Text(NSLocalizedString("bridge_email_check_messages", comment: "Email bridge check messages button"))
                            }
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .glassButtonStyle()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel(NSLocalizedString("Check for new email messages", comment: "Email bridge check messages button accessibility"))
                    }

                    if let result = manager.testResult {
                        let isError = result.contains("failed") || result.contains("fill")
                            || result.contains("Configure") || result.contains("timed out")
                            || result.contains("Unexpected") || result.contains("could not")
                            || result.contains("Authentication") || result.contains("Password")
                            || result.contains("TLS") || result.contains("Both servers")
                        HStack(spacing: 8) {
                            Image(systemName: isError
                                  ? "exclamationmark.triangle.fill"
                                  : "checkmark.circle.fill")
                                .foregroundColor(isError
                                                 ? QuantumColors.error
                                                 : QuantumColors.success)
                            Text(result)
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .glassBackground(cornerRadius: 10)
                        .accessibilityLabel(String(format: NSLocalizedString("Test result: %@", comment: "Email bridge test result accessibility"), result))
                    }
                }
                .padding(16)
                .glassBackground()

                // Forwarded messages
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("bridge_email_forwarded_messages", comment: "Email bridge forwarded messages section header"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                        Spacer()
                        Text("\(manager.forwardedMessages.count)")
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassBackground(cornerRadius: 8)
                    }

                    if manager.forwardedMessages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(QuantumColors.textTertiary)
                            Text(NSLocalizedString("bridge_email_no_messages_yet", comment: "Email bridge no forwarded messages empty state"))
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(manager.forwardedMessages) { msg in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(QuantumColors.accent)
                                        .font(.system(size: 14))
                                    Text(msg.from)
                                        .font(QuantumFonts.caption)
                                        .foregroundColor(QuantumColors.accent)
                                    Spacer()
                                    Text(msg.receivedAt, style: .time)
                                        .font(QuantumFonts.encryptionLabel)
                                        .foregroundColor(QuantumColors.textTertiary)
                                }
                                Text(msg.subject)
                                    .font(QuantumFonts.body)
                                    .foregroundColor(QuantumColors.textPrimary)
                                    .lineLimit(1)
                                Text(msg.body)
                                    .font(QuantumFonts.caption)
                                    .foregroundColor(QuantumColors.textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(12)
                            .glassBackground(cornerRadius: 10)
                            .accessibilityLabel(String(format: NSLocalizedString("Email from %@, subject: %@", comment: "Email bridge forwarded message accessibility"), msg.from, msg.subject))
                        }
                    }
                }
                .padding(16)
                .glassBackground()
            }
            .padding(16)
        }
        .background(QuantumGradients.background)
        .navigationTitle(NSLocalizedString("bridge_email_navigation_title", comment: "Email Bridge navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }

    // MARK: - Helpers

    private var isFormFilled: Bool {
        !manager.smtpHost.isEmpty &&
        manager.smtpPort > 0 &&
        !manager.imapHost.isEmpty &&
        !manager.email.isEmpty &&
        !manager.password.isEmpty
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
            Text(manager.isConnected ? NSLocalizedString("bridge_email_connected", comment: "Email bridge connected status") : NSLocalizedString("bridge_email_disconnected", comment: "Email bridge disconnected status"))
                .font(QuantumFonts.encryptionLabel)
                .foregroundColor(manager.isConnected ? QuantumColors.success : QuantumColors.textSecondary)
        }
        .accessibilityLabel(manager.isConnected ? NSLocalizedString("Status: connected", comment: "Email bridge connected status accessibility") : NSLocalizedString("Status: disconnected", comment: "Email bridge disconnected status accessibility"))
    }

    @ViewBuilder
    private func glassField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(QuantumFonts.caption)
                .foregroundColor(QuantumColors.textSecondary)
            TextField(placeholder, text: text)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassBackground(cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                )
        }
    }
}
