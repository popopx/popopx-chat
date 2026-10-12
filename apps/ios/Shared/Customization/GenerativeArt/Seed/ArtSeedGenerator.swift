// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import CryptoKit
import Foundation

/// Generates deterministic 64-bit seeds from message text and emotion signals.
final class ArtSeedGenerator {
    static let shared = ArtSeedGenerator()

    // Keyword → generator mapping for explicit triggers
    let explicitTriggers: [String: ArtGenerator] = [
        "赛博遁入": .circuitBoard,
        "灵感泵发": .flowField,
        "虚空模式": .waveInterference,
        "几何冥想": .geometricHarmony,
        "细胞觉醒": .cellularAutomata,
        "cyberdive": .circuitBoard,
        "inspiration": .flowField,
        "entropy": .waveInterference,
        "sacred": .geometricHarmony,
        "emergence": .cellularAutomata,
    ]

    // Emotion keyword lists
    private let cyberKeywords = ["代码", "极客", "赛博", "hacker", "crypto", "cyber", "geek", "glitch", "neon", "neural", "quantum", "blockchain", "加密", "算法"]
    private let anxietyKeywords = ["焦虑", "压力", "崩溃", "stress", "anxiety", "panic", "overwhelm", "burnout", "窒息", "恐惧"]
    private let joyKeywords = ["开心", "快乐", "兴奋", "happy", "joy", "love", "amazing", "wonderful", "太棒了", "美好"]

    private init() {}

    /// Generate a deterministic seed from message content and extractions.
    func generateSeed(from input: ArtSeedInput) -> ArtSeed {
        let canonical = canonicalize(input)
        let hash = SHA256.hash(data: Data(canonical.utf8))
        let hashData = Data(hash.prefix(8))
        let truncated = hashData.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).bigEndian }
        let hex = String(truncated, radix: 16).uppercased().padding(toLength: 16, withPad: "0", startingAt: 0)

        let emotion = detectEmotionSignals(from: input.extractions, text: input.messageText)
        let generatorType = classifyGenerator(from: emotion)

        return ArtSeed(hex: hex, uint64: truncated, generatorHint: generatorType, emotion: emotion)
    }

    /// Check if text contains an explicit trigger keyword.
    func findExplicitTrigger(in text: String) -> ArtGenerator? {
        let lower = text.lowercased()
        for (keyword, generator) in explicitTriggers {
            if lower.contains(keyword.lowercased()) {
                return generator
            }
        }
        return nil
    }

    // MARK: - Private

    private func canonicalize(_ input: ArtSeedInput) -> String {
        var parts: [String] = [input.messageText]

        // Add sorted extraction type signatures
        let extractionTypes = input.extractions.map { $0.type.rawValue }.sorted()
        parts.append(extractionTypes.joined(separator: ","))

        // Add keyword flags
        let lower = input.messageText.lowercased()
        let hasCyber = cyberKeywords.contains { lower.contains($0.lowercased()) }
        let hasAnxiety = anxietyKeywords.contains { lower.contains($0.lowercased()) }
        let hasJoy = joyKeywords.contains { lower.contains($0.lowercased()) }
        parts.append("cyber:\(hasCyber)")
        parts.append("anxiety:\(hasAnxiety)")
        parts.append("joy:\(hasJoy)")

        return parts.joined(separator: "|")
    }

    func detectEmotionSignals(from extractions: [Extraction], text: String) -> EmotionProfile {
        let lower = text.lowercased()

        let cyberCount = cyberKeywords.filter { lower.contains($0.lowercased()) }.count
        let anxietyCount = anxietyKeywords.filter { lower.contains($0.lowercased()) }.count
        let joyCount = joyKeywords.filter { lower.contains($0.lowercased()) }.count

        let totalKeywords = max(cyberCount + anxietyCount + joyCount, 1)

        // Extraction-based signals
        let hasExpense = extractions.contains { $0.type == .expense }
        let hasNote = extractions.contains { $0.type == .note }

        let anxietyScore = min(1.0, Double(anxietyCount) / 3.0 + (hasExpense ? 0.2 : 0))
        let cyberScore = min(1.0, Double(cyberCount) / 2.0 + (hasNote ? 0.1 : 0))
        let joyScore = min(1.0, Double(joyCount) / 2.0)
        let complexity = min(1.0, Double(totalKeywords) / 5.0)

        return EmotionProfile(
            anxietyScore: anxietyScore,
            cyberScore: cyberScore,
            joyScore: joyScore,
            complexity: complexity
        )
    }

    private func classifyGenerator(from emotion: EmotionProfile) -> ArtGenerator {
        // High anxiety + high cyber → Circuit Board
        if emotion.anxietyScore > 0.5 && emotion.cyberScore > 0.5 {
            return .circuitBoard
        }
        // High joy → Flow Field
        if emotion.joyScore > 0.5 {
            return .flowField
        }
        // High complexity → Wave Interference
        if emotion.complexity > 0.6 {
            return .waveInterference
        }
        // High cyber alone → Geometric Harmony
        if emotion.cyberScore > 0.5 {
            return .geometricHarmony
        }
        // Default: Cellular Automata for emergent complexity
        return .cellularAutomata
    }
}

// MARK: - Models

struct ArtSeedInput {
    let messageText: String
    let extractions: [Extraction]
}

struct ArtSeed {
    let hex: String
    let uint64: UInt64
    let generatorHint: ArtGenerator
    let emotion: EmotionProfile
}

struct EmotionProfile: Codable {
    var anxietyScore: Double
    var cyberScore: Double
    var joyScore: Double
    var complexity: Double

    init(anxietyScore: Double = 0, cyberScore: Double = 0, joyScore: Double = 0, complexity: Double = 0) {
        self.anxietyScore = anxietyScore
        self.cyberScore = cyberScore
        self.joyScore = joyScore
        self.complexity = complexity
    }
}
