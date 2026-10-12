// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereClient.swift
//  POPOPX (iOS)
//
//  Manages communication with the BinThere bot via POPOPX commands.
//  Uses per-pasteId continuation maps for concurrent request isolation.
//  Gets bot addresses from Haskell database with least-used-first selection.
//

import Foundation
import OSLog
import POPOPXSwitch

@MainActor
final class BinThereClient: ObservableObject {
    static let shared = BinThereClient()

    @Published var botChatId: Int64?
    @Published var currentBotId: Int64?

    private var pendingStore: CheckedContinuation<String, Error>?
    private var pendingGets: [String: CheckedContinuation<Data, Error>] = [:]
    private var pendingGetOrder: [String] = []
    private let timeoutSeconds: UInt64 = 10
    private let botType = "binthere"

    private init() {
        loadBotChatId()
    }

    // MARK: - Bot Configuration (Legacy - UserDefaults fallback)

    func configure(botChatId: Int64) {
        self.botChatId = botChatId
        UserDefaults.standard.set(botChatId, forKey: "binthere_bot_chat_id")
    }

    private func loadBotChatId() {
        let stored = UserDefaults.standard.integer(forKey: "binthere_bot_chat_id")
        if stored != 0 {
            botChatId = Int64(stored)
        }
    }

    // MARK: - Bot Resolution

    /// Get the bot chatId to use for communication.
    /// Uses stored botChatId (set when user connects to bot via UI).
    /// Queries Haskell database for bot info (logging/verification only).
    func resolveBot() async throws -> Int64 {
        // Primary: use stored botChatId (set via configure() from UI)
        if let chatId = botChatId, chatId != 0 {
            // Try to log which bot we're using from database
            do {
                let bots = try await apiGetBinThereBots(botType: botType)
                if let bot = bots.first {
                    currentBotId = bot.botId
                    logger.debug("resolveBot: using botChatId=\(chatId) with botId=\(bot.botId)")
                }
            } catch {
                logger.debug("resolveBot: using botChatId=\(chatId) (no database bots)")
            }
            return chatId
        }

        throw BinThereError.botNotConfigured
    }

    /// Report that a bot was used (increments usage count)
    func reportBotUsage() async {
        guard let botId = currentBotId else { return }
        do {
            try await apiReportBinThereBotUse(botId: botId)
            logger.debug("reportBotUsage: reported usage for botId=\(botId)")
        } catch {
            logger.warning("reportBotUsage: failed to report: \(error.localizedDescription)")
        }
    }

    /// Add a new bot address to the database
    static func addBot(address: String, name: String? = nil) async throws {
        try await apiInsertBinThereBot(address: address, name: name, botType: "binthere")
    }

    // MARK: - Store Paste

    func storePaste(ciphertextB64: String) async throws -> String {
        // Guard against concurrent store calls overwriting the pending continuation
        guard pendingStore == nil else {
            throw BinThereError.concurrentOperation
        }

        // Resolve bot first
        let botId = try await resolveBot()

        let command = "/store \(ciphertextB64)"
        let composedMessage = ComposedMessage(msgContent: .text(command))

        _ = await apiSendMessages(
            type: .direct,
            id: botId,
            scope: nil,
            composedMessages: [composedMessage]
        )

        let pasteId = try await withTimeout(seconds: timeoutSeconds) {
            try await withCheckedThrowingContinuation { continuation in
                self.pendingStore = continuation
            }
        }

        // Report usage after successful store
        await reportBotUsage()

        return pasteId
    }

    // MARK: - Fetch Paste (Lock, not burn)

    func fetchPaste(pasteId: String) async throws -> Data {
        // Resolve bot first
        let botId = try await resolveBot()

        let command = "/get \(pasteId)"
        let composedMessage = ComposedMessage(msgContent: .text(command))

        _ = await apiSendMessages(
            type: .direct,
            id: botId,
            scope: nil,
            composedMessages: [composedMessage]
        )

        let data = try await withTimeout(seconds: timeoutSeconds) {
            try await withCheckedThrowingContinuation { continuation in
                self.pendingGets[pasteId] = continuation
                self.pendingGetOrder.append(pasteId)
            }
        }

        // Report usage after successful fetch
        await reportBotUsage()

        return data
    }

    // MARK: - Burn Confirmation (fire-and-forget)

    func burnPaste(pasteId: String) async {
        guard let botId = botChatId else { return }
        let command = "/burned \(pasteId)"
        let composedMessage = ComposedMessage(msgContent: .text(command))
        _ = await apiSendMessages(
            type: .direct,
            id: botId,
            scope: nil,
            composedMessages: [composedMessage]
        )
    }

    // MARK: - Response Handling

    func handleBotResponse(text: String) {
        if text.hasPrefix("STORED:") {
            let pasteId = String(text.dropFirst("STORED:".count))
            pendingStore?.resume(returning: pasteId)
            pendingStore = nil

        } else if text.hasPrefix("LOCKED:") {
            let payload = String(text.dropFirst("LOCKED:".count))
            guard let colonIdx = payload.firstIndex(of: ":") else { return }
            let pasteId = String(payload[..<colonIdx])
            let ciphertextB64 = String(payload[payload.index(after: colonIdx)...])
            guard let continuation = pendingGets.removeValue(forKey: pasteId) else { return }
            if let data = Data(base64URLEncoded: ciphertextB64) {
                continuation.resume(returning: data)
            } else {
                continuation.resume(throwing: BinThereError.decryptionFailed)
            }

        } else if text.hasPrefix("GONE:") {
            let pasteId = String(text.dropFirst("GONE:".count))
            if let continuation = pendingGets.removeValue(forKey: pasteId) {
                continuation.resume(throwing: BinThereError.pasteGone)
            }

        } else if text.hasPrefix("BURNED:") {
            // Fire-and-forget confirmation, no continuation to resume

        } else if text.hasPrefix("Error") || text.hasPrefix("Usage") {
            pendingStore?.resume(throwing: BinThereError.botTimeout)
            pendingStore = nil
            for (_, cont) in pendingGets {
                cont.resume(throwing: BinThereError.botTimeout)
            }
            pendingGets.removeAll()

        } else if text.hasPrefix("PASTE:") {
            // Backward compat: old bot format PASTE:<ciphertext>
            // Match the most recently requested paste (last in insertion order)
            let ciphertextB64 = String(text.dropFirst("PASTE:".count))
            if let pasteId = pendingGetOrder.last,
               let continuation = pendingGets.removeValue(forKey: pasteId) {
                pendingGetOrder.removeLast()
                if let data = Data(base64URLEncoded: ciphertextB64) {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: BinThereError.decryptionFailed)
                }
            }

        } else if text == "GONE" {
            // Backward compat: old bot format bare GONE
            // Match the most recently requested paste (last in insertion order)
            if let pasteId = pendingGetOrder.last,
               let continuation = pendingGets.removeValue(forKey: pasteId) {
                pendingGetOrder.removeLast()
                continuation.resume(throwing: BinThereError.pasteGone)
            }
        }
    }
}

// MARK: - Timeout Helper (double-resume safe)

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
                continuation.resume(throwing: BinThereError.botTimeout)
            }
        }
    }
}

// MARK: - Base64URL Extension

private extension Data {
    init?(base64URLEncoded: String) {
        var padded = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder > 0 {
            padded.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: padded)
    }
}
