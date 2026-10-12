// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import OSLog
import SwiftUI
#if !POPOPXSwitch
import POPOPXSwitch
#endif

@MainActor
class DeadMansSwitch: ObservableObject {
    static let shared = DeadMansSwitch()

    private let logger = Logger(subsystem: "im.popopx", category: "DeadMansSwitch")
    private let configKey = "im.popopx.deadmansswitch.config"
    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.popopxchat.popopx") ?? .standard

    struct SwitchConfig: Codable {
        var enabled: Bool = false
        var inactivityDays: Int = 30
        var lastActivityDate: Date = Date()
        var actions: [SwitchAction] = []
        var trustedContacts: [String] = []
        var warningDays: Int = 7
    }

    enum SwitchAction: Codable, Identifiable {
        case sendMessage(contactId: String, text: String)
        case deleteAllData
        case exportData(recipientContactId: String)
        case runShortcut(shortcutName: String)

        var id: String {
            switch self {
            case .sendMessage(let contactId, _):
                return "send_\(contactId)"
            case .deleteAllData:
                return "delete_all"
            case .exportData(let recipientId):
                return "export_\(recipientId)"
            case .runShortcut(let name):
                return "shortcut_\(name)"
            }
        }
    }

    @Published var config = SwitchConfig()
    @Published var daysRemaining: Int = 0
    @Published var isWarningPhase: Bool = false

    private var checkTimer: Timer?

    private init() {
        loadConfig()
        startMonitoring()
    }

    func recordActivity() {
        config.lastActivityDate = Date()
        saveConfig()
        updateStatus()
    }

    func updateConfig(_ newConfig: SwitchConfig) {
        config = newConfig
        saveConfig()
        updateStatus()
    }

    func addAction(_ action: SwitchAction) {
        config.actions.append(action)
        saveConfig()
    }

    func removeAction(at index: Int) {
        guard index < config.actions.count else { return }
        config.actions.remove(at: index)
        saveConfig()
    }

    func addTrustedContact(_ contactId: String) {
        if !config.trustedContacts.contains(contactId) {
            config.trustedContacts.append(contactId)
            saveConfig()
        }
    }

    func removeTrustedContact(_ contactId: String) {
        config.trustedContacts.removeAll { $0 == contactId }
        saveConfig()
    }

    private func startMonitoring() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkInactivity()
            }
        }
        updateStatus()
    }

    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    func checkInactivity() {
        guard config.enabled else { return }

        let daysSince = Self.utcCalendar.dateComponents(
            [.day], from: config.lastActivityDate, to: Date()
        ).day ?? 0

        if daysSince >= config.inactivityDays {
            logger.warning("Dead Man's Switch triggered: \(daysSince) days inactive")
            executeActions()
        } else if daysSince >= (config.inactivityDays - config.warningDays) {
            isWarningPhase = true
            logger.info("Dead Man's Switch warning: \(daysSince) days inactive")
        } else {
            isWarningPhase = false
        }

        updateStatus()
    }

    private func executeActions() {
        // Disable immediately before any async work to prevent re-triggering
        // if the app is killed during action execution
        config.enabled = false
        saveConfig()

        logger.info("Executing Dead Man's Switch actions")

        for action in config.actions {
            switch action {
            case .sendMessage(let contactId, let text):
                Task {
                    await sendMessageToContact(contactId: contactId, text: text)
                }
            case .deleteAllData:
                deleteAllLocalData()
            case .exportData(let recipientId):
                Task {
                    await exportDataToContact(recipientId: recipientId)
                }
            case .runShortcut(let name):
                runShortcut(name: name)
            }
        }
    }

    private func sendMessageToContact(contactId: String, text: String) async {
        logger.info("Sending message to contact: \(contactId)")
        // Pending POPOPXAPI integration: call the chat API to deliver the message
        // to the specified contact once the dead man's switch is triggered.
    }

    private func deleteAllLocalData() {
        logger.warning("Deleting all local data")
        // Clear local extraction store.
        // Additional cleanup may be needed: keychain entries, cached images,
        // app group defaults, and any pending upload queues.
        LocalExtractionStore.shared.deleteAll()
    }

    private func exportDataToContact(recipientId: String) async {
        logger.info("Exporting data to contact: \(recipientId)")
        // Pending implementation: serialize chat archive or selected data,
        // encrypt it, and deliver via the chat API to the designated recipient.
    }

    private func runShortcut(name: String) {
        logger.info("Running shortcut: \(name)")
        // Pending Shortcuts framework integration: look up the shortcut by name
        // and execute it via INShortcut or SiriShortcuts APIs.
    }

    private func updateStatus() {
        let daysSince = Self.utcCalendar.dateComponents(
            [.day], from: config.lastActivityDate, to: Date()
        ).day ?? 0
        daysRemaining = max(0, config.inactivityDays - daysSince)
        isWarningPhase = daysSince >= (config.inactivityDays - config.warningDays)
    }

    private func loadConfig() {
        guard let data = Self.appGroupDefaults.data(forKey: configKey) else { return }
        do {
            let decrypted = try CryptoEncrypt.shared.decrypt(data)
            config = try JSONDecoder().decode(SwitchConfig.self, from: decrypted)
        } catch {
            logger.error("Failed to load DeadMansSwitch config: \(error) — clearing stale data")
            Self.appGroupDefaults.removeObject(forKey: configKey)
        }
    }

    private func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: configKey)
        } catch {
            logger.error("Failed to save DeadMansSwitch config: \(error)")
        }
    }
}
