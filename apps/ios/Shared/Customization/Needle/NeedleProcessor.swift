// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import CactusEngine
import os

@MainActor
class NeedleProcessor: ObservableObject {
    static let shared = NeedleProcessor()

    private let logger = Logger(subsystem: "im.popopx", category: "Needle")
    private var model: UnsafeMutableRawPointer?
    private var isInitialized = false
    private var isShuttingDown = false

    @Published var isReady = false
    @Published var lastError: String?

    private let responseBufferSize = 8192
    private var inFlightTask: Task<(Int, String), Never>?

    private let systemPrompt = """
    You are a structured data extractor. Parse the user message and output a JSON array of extracted items.
    Each item must have a "type" field with one of: calendar, expense, todo, note, asset, contact.
    Include relevant fields based on the type. Output ONLY valid JSON. No explanation.

    Examples:
    Input: "明天下午3点和老张在星巴克开会"
    Output: [{"type":"calendar","event":"与老张开会","time":"2026-09-06T15:00","location":"星巴克"}]

    Input: "午饭花了45块"
    Output: [{"type":"expense","amount":"45","category":"lunch","currency":"CNY"}]

    Input: "今天投资5个太达币，帮我把下午和王律师的咨询费2000元记上"
    Output: [{"type":"asset","action":"invest","asset":"TDD","amount":"5"},{"type":"expense","amount":"2000","category":"consultation","payee":"王律师"}]
    """

    private init() {}

    func initialize() {
        isShuttingDown = false
        guard !isInitialized else { return }

        guard let modelPath = findModelPath() else {
            logger.warning("Needle model not found in app bundle")
            lastError = "model_not_found"
            return
        }

        #if targetEnvironment(simulator)
        _ = "cpu".withCString { ptr in cactus_set_backend(ptr) }
        logger.info("Simulator detected — forcing CPU backend for CactusEngine")
        #endif

        model = modelPath.withCString { pathPtr in
            cactus_init(pathPtr, nil, false)
        }

        if model != nil {
            isInitialized = true
            isReady = true
            cactus_log_set_level(3)
            logger.info("Cactus engine initialized with model: \(modelPath)")
        } else {
            let err = cactus_get_last_error()
            let errMsg = err.map { String(cString: $0) } ?? "unknown"
            lastError = errMsg
            logger.error("Cactus engine init failed: \(errMsg)")
        }
    }

    func extract(from text: String) async throws -> [Extraction] {
        #if targetEnvironment(simulator)
        return fallbackExtract(from: text)
        #else
        if !isInitialized {
            initialize()
        }
        guard isInitialized, model != nil else {
            logger.warning("Engine not initialized, falling back to keyword extraction (lastError: \(self.lastError ?? "nil"))")
            return fallbackExtract(from: text)
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]

        let messagesData = try JSONSerialization.data(withJSONObject: messages)
        guard let messagesJson = String(data: messagesData, encoding: .utf8) else {
            throw NeedleError.encodingFailed
        }

        let currentModel = model
        let bufSize = responseBufferSize
        guard !isShuttingDown, let currentModel else {
            logger.warning("extract() falling back to keywords: shutting down or model unavailable")
            return fallbackExtract(from: text)
        }
        let task: Task<(Int, String), Never> = Task.detached(priority: .userInitiated) {
            let localBuf = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
            localBuf.initialize(repeating: 0, count: bufSize)
            defer {
                localBuf.deinitialize(count: bufSize)
                localBuf.deallocate()
            }
            var code: Int32 = -1
            messagesJson.withCString { msgPtr in
                code = cactus_complete(
                    currentModel,
                    msgPtr,
                    localBuf,
                    bufSize,
                    nil, nil, nil, nil, nil, 0
                )
            }
            // Ensure null terminator at last position to prevent reading past buffer
            localBuf[bufSize - 1] = 0
            let text = String(cString: localBuf)
            return (Int(code), text)
        }
        inFlightTask = task
        let (result, responseText) = await task.value
        inFlightTask = nil

        guard result == 0 else {
            let err = cactus_get_last_error()
            let errMsg = err.map { String(cString: $0) } ?? "unknown error (code: \(result))"
            logger.error("Cactus completion failed (code: \(result)): \(errMsg), falling back to keywords")
            return fallbackExtract(from: text)
        }

        return try parseExtractions(responseText, sourceText: text)
        #endif
    }

    private func fallbackExtract(from text: String) -> [Extraction] {
        var results: [Extraction] = []

        let calendarPatterns = ["会议", "开会", "见面", "约会", "日程", "安排", "上午", "下午", "晚上", "明天", "后天", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        if calendarPatterns.contains(where: { text.contains($0) }) {
            results.append(Extraction(type: .calendar, data: ["text": text], sourceText: text))
        }

        let expensePatterns = ["花了", "花费", "消费", "买了", "支付", "元", "块", "¥", "￥"]
        if expensePatterns.contains(where: { text.contains($0) }) {
            results.append(Extraction(type: .expense, data: ["text": text], sourceText: text))
        }

        let todoPatterns = ["待办", "TODO", "todo", "记得", "别忘了", "需要", "要做"]
        if todoPatterns.contains(where: { text.contains($0) }) {
            results.append(Extraction(type: .todo, data: ["text": text], sourceText: text))
        }

        let assetPatterns = ["投资", "买入", "卖出", "股票", "基金", "币", "TDD", "BTC", "ETH"]
        if assetPatterns.contains(where: { text.contains($0) }) {
            results.append(Extraction(type: .asset, data: ["text": text], sourceText: text))
        }

        if results.isEmpty && text.count >= 10 {
            results.append(Extraction(type: .note, data: ["text": text], sourceText: text))
        }

        return results
    }

    /// Lightweight content-quality gate for the global broadcast feed.
    ///
    /// Rejects obviously short/long content up front, then asks the extractor
    /// whether the text contains any structured signal. Falls back to a
    /// keyword blocklist when the engine is unavailable so the filter still
    /// provides baseline spam protection.
    func shouldShow(content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5, trimmed.count <= 500 else { return false }

        guard isInitialized else {
            let lower = trimmed.lowercased()
            return !lower.contains("spam") && !lower.contains("广告")
        }

        do {
            let extractions = try await extract(from: trimmed)
            return !extractions.isEmpty
        } catch {
            return false
        }
    }

    func stop() {
        if let model {
            cactus_stop(model)
        }
    }

    func shutdown() async {
        isShuttingDown = true
        if let task = inFlightTask {
            _ = await task.value
            inFlightTask = nil
        }
        if let model {
            cactus_destroy(model)
            self.model = nil
        }
        isInitialized = false
        isReady = false
    }

    private func findModelPath() -> String? {
        let bundleNames = ["NeedleModel"]
        for name in bundleNames {
            guard let path = Bundle.main.path(forResource: name, ofType: nil) else {
                logger.warning("Bundle.main.path(forResource: \"\(name)\") returned nil. Bundle resources: \(Bundle.main.resourcePath ?? "nil")")
                continue
            }
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                logger.warning("NeedleModel path does not exist: \(path)")
                continue
            }
            if !isDir.boolValue {
                logger.warning("NeedleModel path is not a directory: \(path)")
                continue
            }
            let configPath = (path as NSString).appendingPathComponent("config.txt")
            if !FileManager.default.fileExists(atPath: configPath) {
                logger.warning("config.txt not found at: \(configPath)")
                continue
            }
            return path
        }
        return nil
    }

    private func parseExtractions(_ json: String, sourceText: String) throws -> [Extraction] {
        let cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw NeedleError.parseFailed
        }

        let trimmed: Data
        if cleaned.hasPrefix("["),
           let lastBracket = cleaned.lastIndex(of: "]") {
            let sub = cleaned[cleaned.startIndex...lastBracket]
            trimmed = sub.data(using: .utf8) ?? data
        } else {
            trimmed = data
        }

        guard let array = try JSONSerialization.jsonObject(with: trimmed) as? [[String: Any]] else {
            logger.warning("Failed to parse extraction result as JSON array")
            return []
        }

        return array.compactMap { dict -> Extraction? in
            guard let typeStr = dict["type"] as? String,
                  let type = ExtractionType(rawValue: typeStr) else {
                return nil
            }

            var stringData: [String: String] = [:]
            for (key, value) in dict {
                if key == "type" { continue }
                stringData[key] = String(describing: value)
            }

            return Extraction(type: type, data: stringData, sourceText: sourceText)
        }
    }
}

enum NeedleError: LocalizedError {
    case notInitialized
    case encodingFailed
    case completionFailed(String)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .notInitialized: return NSLocalizedString("needle_not_initialized", comment: "Needle engine not initialized")
        case .encodingFailed: return NSLocalizedString("needle_encode_failed", comment: "Failed to encode messages")
        case .completionFailed(let msg): return String(format: NSLocalizedString("needle_completion_failed", comment: "Completion failed"), msg)
        case .parseFailed: return NSLocalizedString("needle_parse_failed", comment: "Failed to parse extraction result")
        }
    }
}
