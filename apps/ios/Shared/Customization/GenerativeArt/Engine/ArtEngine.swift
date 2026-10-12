// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import JavaScriptCore
import UIKit
import os

/// Deterministic generative art engine using JavaScriptCore.
/// Renders Art Blocks–style JS generator scripts into UIImage.
@MainActor
final class ArtEngine {
    static let shared = ArtEngine()

    private let logger = Logger(subsystem: "im.popopx", category: "ArtEngine")
    private let renderQueue = DispatchQueue(label: "im.popopx.artengine.render")
    private let jsContext: JSContext

    private init() {
        jsContext = JSContext()
        installExceptionHandler()
    }

    /// Render a generator script with a given seed.
    /// - Parameters:
    ///   - generator: The ArtGenerator type to render
    ///   - seed: 64-bit deterministic seed
    ///   - size: Output size (default 512×512)
    /// - Returns: Rendered UIImage
    func render(generator: ArtGenerator, seed: UInt64, size: CGSize = CGSize(width: 512, height: 512)) throws -> UIImage {
        let intSize = CGSize(width: Int(size.width), height: Int(size.height))
        guard let newBridge = ArtCanvasBridge(width: Int(intSize.width), height: Int(intSize.height)) else {
            throw ArtEngineError.contextCreationFailed
        }

        // Reset context
        jsContext.exception = nil

        // Inject seeded PRNG (Mulberry32)
        injectPRNG(seed: seed)

        // Register canvas bridge
        newBridge.register(with: jsContext)

        // Set seed global
        jsContext.setObject(Double(seed), forKeyedSubscript: "__SEED__" as NSString)

        // Load and execute generator script
        guard let scriptURL = Bundle.main.url(forResource: generator.scriptName, withExtension: "js") else {
            throw ArtEngineError.generatorNotFound(generator.scriptName)
        }
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        jsContext.evaluateScript(script)

        if let exception = jsContext.exception {
            logger.error("JS exception in \(generator.scriptName): \(exception.toString() ?? "unknown")")
            throw ArtEngineError.renderFailed(exception.toString() ?? "unknown")
        }

        guard let image = newBridge.toUIImage() else {
            throw ArtEngineError.renderFailed("Failed to create UIImage from bitmap context")
        }

        return image
    }

    /// Async wrapper for render (runs on background queue).
    func renderAsync(generator: ArtGenerator, seed: UInt64, size: CGSize = CGSize(width: 512, height: 512)) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            renderQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ArtEngineError.renderFailed("Engine deallocated"))
                    return
                }
                Task { @MainActor in
                    do {
                        let image = try self.render(generator: generator, seed: seed, size: size)
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Private

    /// Inject Mulberry32 seeded PRNG, replacing Math.random.
    private func injectPRNG(seed: UInt64) {
        // Mulberry32: fast, 32-bit state, deterministic
        // We fold the 64-bit seed into 32-bit state
        let state = UInt32(seed & 0xFFFFFFFF) ^ UInt32(seed >> 32)
        let prngScript = """
        (function(initialState) {
            var state = initialState | 0;
            Math.random = function() {
                state = (state + 0x6D2B79F5) | 0;
                var t = Math.imul(state ^ (state >>> 15), 1 | state);
                t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
                return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
            };
            // Freeze Math.random to prevent generator tampering
            Object.defineProperty(Math, 'random', {
                configurable: false,
                writable: false
            });
        })(\(state));
        """
        jsContext.evaluateScript(prngScript)
    }

    private func installExceptionHandler() {
        jsContext.exceptionHandler = { [weak self] _, exception in
            self?.logger.error("JSContext exception: \(exception?.toString() ?? "nil")")
        }
    }
}

enum ArtGenerator: String, CaseIterable, Codable {
    case flowField = "FlowField"
    case circuitBoard = "CircuitBoard"
    case geometricHarmony = "GeometricHarmony"
    case waveInterference = "WaveInterference"
    case cellularAutomata = "CellularAutomata"

    var scriptName: String { rawValue }

    var displayName: String {
        switch self {
        case .flowField: return NSLocalizedString("art_generator_flow_field", comment: "Art generator type: flow field")
        case .circuitBoard: return NSLocalizedString("art_generator_circuit_board", comment: "Art generator type: circuit board")
        case .geometricHarmony: return NSLocalizedString("art_generator_geometric_harmony", comment: "Art generator type: geometric harmony")
        case .waveInterference: return NSLocalizedString("art_generator_wave_interference", comment: "Art generator type: wave interference")
        case .cellularAutomata: return NSLocalizedString("art_generator_cellular_automata", comment: "Art generator type: cellular automata")
        }
    }
}

enum ArtEngineError: LocalizedError {
    case generatorNotFound(String)
    case renderFailed(String)
    case contextCreationFailed

    var errorDescription: String? {
        switch self {
        case .generatorNotFound(let name):
            return String(format: NSLocalizedString("art_engine_script_not_found", comment: "Generator script not found"), name)
        case .renderFailed(let reason):
            return String(format: NSLocalizedString("art_engine_render_failed", comment: "Render failed"), reason)
        case .contextCreationFailed:
            return NSLocalizedString("art_engine_context_failed", comment: "Failed to create bitmap rendering context")
        }
    }
}
