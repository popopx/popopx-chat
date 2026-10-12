// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import OSLog

class ShortcutRunner {
    static let shared = ShortcutRunner()
    private let logger = Logger(subsystem: "im.popopx", category: "ShortcutRunner")

    private init() {}

    func run(name: String) async {
        logger.info("Attempting to run shortcut: \(name)")

        // Check if shortcut exists
        let shortcutExists = await checkShortcutExists(name: name)

        guard shortcutExists else {
            logger.error("Shortcut not found: \(name)")
            return
        }

        // Run the shortcut
        await executeShortcut(name: name)
    }

    private func checkShortcutExists(name: String) async -> Bool {
        // Pending Shortcuts framework integration: use INShortcutsResolution or
        // SiriShortcuts availability APIs to verify the shortcut is installed.
        // Returning true for now to allow the execution attempt path to run.
        return true
    }

    private func executeShortcut(name: String) async {
        // Pending Shortcuts framework integration. Implementation requires:
        // 1. Look up the shortcut by name via INShortcut(intent:) or SiriShortcuts
        // 2. Execute it with optional input parameters
        // 3. Handle the result or error
        logger.info("Executing shortcut: \(name)")
    }

    func getAvailableShortcuts() async -> [String] {
        // Pending Shortcuts framework integration: query installed shortcuts via
        // INShortcutStore or SiriShortcuts and return their display names.
        return []
    }
}
