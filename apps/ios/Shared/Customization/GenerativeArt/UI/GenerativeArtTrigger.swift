// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import os

/// Evaluates incoming/outgoing messages and triggers generative art creation.
@MainActor
final class GenerativeArtTrigger {
    static let shared = GenerativeArtTrigger()

    private let logger = Logger(subsystem: "im.popopx", category: "GenerativeArtTrigger")
    private var lastTriggerTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 60

    private init() {}

    /// Evaluate a sent message for art generation.
    func evaluateOnSend(_ text: String) {
        guard !text.isEmpty else { return }
        evaluate(text: text, extractions: [])
    }

    /// Evaluate a received message with extractions for art generation.
    func evaluateOnReceive(text: String, extractions: [Extraction]) {
        guard !text.isEmpty else { return }
        evaluate(text: text, extractions: extractions)
    }

    // MARK: - Private

    private func evaluate(text: String, extractions: [Extraction]) {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= cooldownInterval else {
            logger.debug("Cooldown active, skipping art trigger")
            return
        }

        let seedGen = ArtSeedGenerator.shared
        let emotion = seedGen.detectEmotionSignals(from: extractions, text: text)

        let shouldTrigger: Bool
        let generatorOverride: ArtGenerator?

        // Explicit keyword trigger
        if let explicit = seedGen.findExplicitTrigger(in: text) {
            shouldTrigger = true
            generatorOverride = explicit
        }
        // Passive emotion trigger
        else if emotion.anxietyScore > 0.7 || emotion.cyberScore > 0.6 {
            shouldTrigger = true
            generatorOverride = nil
        } else {
            shouldTrigger = false
            generatorOverride = nil
        }

        guard shouldTrigger else { return }
        lastTriggerTime = now

        let input = ArtSeedInput(messageText: text, extractions: extractions)
        let seed = seedGen.generateSeed(from: input)

        let generator = generatorOverride ?? seed.generatorHint

        Task.detached(priority: .background) { [seed, generator, text, emotion] in
            do {
                let image = try await ArtEngine.shared.renderAsync(
                    generator: generator,
                    seed: seed.uint64
                )

                let piece = ArtPiece(
                    id: UUID(),
                    seed: seed.hex,
                    generatorType: generator.rawValue,
                    sourceText: String(text.prefix(200)),
                    emotionProfile: emotion,
                    createdAt: Date(),
                    filename: ""
                )

                try await ArtVault.shared.save(image: image, metadata: piece)
            } catch {
                Logger(subsystem: "im.popopx", category: "GenerativeArtTrigger")
                    .error("Art generation failed: \(error)")
            }
        }
    }
}
