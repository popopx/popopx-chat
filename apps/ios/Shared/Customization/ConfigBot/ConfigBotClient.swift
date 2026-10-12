// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import OSLog
import POPOPXSwitch

@MainActor
final class ConfigBotClient: ObservableObject {
    static let shared = ConfigBotClient()

    @Published var botChatId: Int64?
    @Published var lastConfigFetch: Date?
    @Published var botDirectory: [BotDirectoryEntry] = []

    private var pendingConfig: CheckedContinuation<RemoteServerConfig, Error>?
    private var pendingConfigResolved: LockedBool?
    private let timeoutSeconds: UInt64 = 15
    private let botType = "config"
    private let chatIdKey = "config_bot_chat_id"

    private init() {
        let stored = UserDefaults.standard.integer(forKey: chatIdKey)
        if stored != 0 {
            botChatId = Int64(stored)
        }
    }

    func configure(botChatId: Int64) {
        self.botChatId = botChatId
        UserDefaults.standard.set(botChatId, forKey: chatIdKey)
    }

    // MARK: - Config Request

    func requestConfig() async throws -> RemoteServerConfig {
        guard let chatId = botChatId, chatId != 0 else {
            throw ConfigBotError.notConfigured
        }

        let resolved = LockedBool(false)
        self.pendingConfigResolved = resolved

        let config = try await withTimeout(seconds: timeoutSeconds) {
            try await withCheckedThrowingContinuation { continuation in
                self.pendingConfig = continuation
                // Send AFTER setting up the continuation, so the response is never lost
                Task {
                    let command = "/config"
                    let composedMessage = ComposedMessage(msgContent: .text(command))
                    _ = await apiSendMessages(
                        type: .direct,
                        id: chatId,
                        scope: nil,
                        composedMessages: [composedMessage]
                    )
                }
            }
        }
        self.pendingConfigResolved = nil

        RemoteConfigCache.save(config)
        lastConfigFetch = Date()

        if let dir = config.botDirectory {
            botDirectory = dir
            await syncBotDirectory(dir)
        }

        return config
    }

    // MARK: - Response Handling

    func handleBotResponse(text: String) {
        guard let data = text.data(using: .utf8) else {
            if pendingConfigResolved?.setTrue() == true {
                pendingConfig?.resume(throwing: ConfigBotError.invalidResponse)
            }
            pendingConfig = nil
            return
        }

        do {
            let config = try JSONDecoder().decode(RemoteServerConfig.self, from: data)
            if pendingConfigResolved?.setTrue() == true {
                pendingConfig?.resume(returning: config)
            }
        } catch {
            logger.warning("ConfigBot: failed to parse response: \(error.localizedDescription)")
            if pendingConfigResolved?.setTrue() == true {
                pendingConfig?.resume(throwing: ConfigBotError.invalidResponse)
            }
        }
        pendingConfig = nil
    }

    // MARK: - Bot Directory Sync

    private func syncBotDirectory(_ entries: [BotDirectoryEntry]) async {
        do {
            let jsonData = try JSONEncoder().encode(entries)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            try await apiSyncBotDirectory(json: jsonString)
            logger.debug("ConfigBot: synced \(entries.count) bot directory entries")
        } catch {
            logger.warning("ConfigBot: failed to sync directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Auto Connect

    func autoConnect() async {
        guard botChatId == nil || botChatId == 0 else { return }
        do {
            let bots = try await apiGetBinThereBots(botType: botType)
            if let bot = bots.first, !bot.botAddress.isEmpty {
                logger.info("ConfigBot: found config bot address, auto-connect not yet implemented")
            }
        } catch {
            logger.debug("ConfigBot: no config bot in directory yet")
        }
    }
}

// MARK: - Error

enum ConfigBotError: LocalizedError {
    case notConfigured
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured: return NSLocalizedString("config_bot_not_configured", comment: "Config bot not configured")
        case .invalidResponse: return NSLocalizedString("config_bot_invalid_response", comment: "Invalid config response")
        case .timeout: return NSLocalizedString("config_bot_timeout", comment: "Config bot request timed out")
        }
    }
}

// MARK: - Timeout Helper

private final class LockedBool {
    private var value: Bool
    private let lock = NSLock()
    init(_ v: Bool) { value = v }
    @discardableResult
    func setTrue() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !value else { return false }
        value = true
        return true
    }
}

private func withTimeout<T>(seconds: UInt64, operation: @escaping () async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        let resolved = LockedBool(false)
        var timeoutTask: Task<Void, Never>?

        let task = Task {
            do {
                let result = try await operation()
                timeoutTask?.cancel()
                if resolved.setTrue() {
                    continuation.resume(returning: result)
                }
            } catch {
                timeoutTask?.cancel()
                if resolved.setTrue() {
                    continuation.resume(throwing: error)
                }
            }
        }

        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            task.cancel()
            if resolved.setTrue() {
                continuation.resume(throwing: ConfigBotError.timeout)
            }
        }
    }
}
