// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import Foundation

// MARK: - Bot Platform Manager

@MainActor
class BotPlatformManager: ObservableObject {
    struct Bot: Identifiable, Codable {
        let id: UUID
        var name: String
        var webhookURL: String
        var isEnabled: Bool
        var messageCount: Int
        var createdAt: Date
    }

    @Published var bots: [Bot] = []
    @Published var newBotName: String = ""
    @Published var newBotWebhook: String = ""

    private let storageKey = "botPlatform_bots"

    init() {
        loadBots()
    }

    func addBot(name: String, webhookURL: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = webhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return }

        let bot = Bot(
            id: UUID(),
            name: trimmedName,
            webhookURL: trimmedURL,
            isEnabled: true,
            messageCount: 0,
            createdAt: Date()
        )
        bots.append(bot)
        newBotName = ""
        newBotWebhook = ""
        saveBots()
    }

    func removeBot(id: UUID) {
        bots.removeAll { $0.id == id }
        saveBots()
    }

    func toggleBot(id: UUID) {
        guard let index = bots.firstIndex(where: { $0.id == id }) else { return }
        bots[index].isEnabled.toggle()
        saveBots()
    }

    func simulateMessage(to botId: UUID) {
        guard let index = bots.firstIndex(where: { $0.id == botId }) else { return }
        bots[index].messageCount += 1
        saveBots()
    }

    private func saveBots() {
        if let data = try? JSONEncoder().encode(bots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadBots() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Bot].self, from: data) else { return }
        bots = decoded
    }
}

// MARK: - Bot Settings View

struct BotSettingsView: View {
    @StateObject private var manager = BotPlatformManager()
    @State private var showAddForm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                addBotSection
                botsListSection
                miniAppsSection
            }
            .padding()
        }
        .background(QuantumColors.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("bot_platform", comment: "navigation title for bot platform settings"))
        .popopxBranded()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 36))
                    .foregroundColor(QuantumColors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("bot_platform_title", comment: "Bot platform section header title"))
                        .font(QuantumFonts.headerTitle)
                        .foregroundColor(QuantumColors.textPrimary)
                    Text(String(format: NSLocalizedString("%d bot%@ registered", comment: "bot platform registered count"), manager.bots.count, manager.bots.count == 1 ? "" : "s"))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                }
                Spacer()
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    // MARK: - Add Bot Form

    private var addBotSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("bot_add_new", comment: "Section header for adding a new bot"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            VStack(spacing: 12) {
                TextField(NSLocalizedString("bot_name_placeholder", comment: "Placeholder for bot name input field"), text: $manager.newBotName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(QuantumColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundColor(QuantumColors.textPrimary)
                    .accessibilityLabel(NSLocalizedString("Bot name input", comment: "bot settings name field accessibility"))

                TextField(NSLocalizedString("bot_webhook_placeholder", comment: "Placeholder for webhook URL input field"), text: $manager.newBotWebhook)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(QuantumColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(QuantumColors.accent.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundColor(QuantumColors.textPrimary)
                    .accessibilityLabel(NSLocalizedString("Webhook URL input", comment: "bot settings webhook URL field accessibility"))

                Button(action: {
                    manager.addBot(name: manager.newBotName, webhookURL: manager.newBotWebhook)
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text(NSLocalizedString("bot_register", comment: "Button to register a new bot"))
                    }
                    .font(QuantumFonts.body.weight(.semibold))
                    .foregroundColor(QuantumColors.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canAddBot ? QuantumColors.accent : QuantumColors.accent.opacity(0.3))
                    )
                }
                .disabled(!canAddBot)
                .accessibilityLabel(NSLocalizedString("Register new bot", comment: "bot settings register button accessibility"))
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private var canAddBot: Bool {
        !manager.newBotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !manager.newBotWebhook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Bots List

    private var botsListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("bot_registered_list", comment: "Section header for registered bots list"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            if manager.bots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bot")
                        .font(.system(size: 40))
                        .foregroundColor(QuantumColors.textTertiary)
                    Text(NSLocalizedString("bot_none_registered", comment: "Empty state when no bots are registered"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(manager.bots) { bot in
                    botRow(bot)
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func botRow(_ bot: BotPlatformManager.Bot) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(bot.isEnabled ? QuantumColors.success : QuantumColors.textTertiary)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bot.name)
                        .font(QuantumFonts.body.weight(.semibold))
                        .foregroundColor(QuantumColors.textPrimary)

                    Text(truncatedURL(bot.webhookURL))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { bot.isEnabled },
                    set: { _ in manager.toggleBot(id: bot.id) }
                ))
                .toggleStyle(.switch)
                .tint(QuantumColors.accent)
                .labelsHidden()
                .accessibilityLabel(String(format: NSLocalizedString("Toggle %@ enabled", comment: "bot settings toggle accessibility"), bot.name))
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(QuantumColors.accent)
                    Text(String(format: NSLocalizedString("%d messages", comment: "bot settings message count"), bot.messageCount))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                }

                Spacer()

                Button(action: {
                    manager.simulateMessage(to: bot.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.caption2)
                        Text(NSLocalizedString("bot_test", comment: "Button to send a test message to a bot"))
                            .font(QuantumFonts.caption)
                    }
                    .foregroundColor(QuantumColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(QuantumColors.accent.opacity(0.5), lineWidth: 1)
                    )
                }
                .accessibilityLabel(String(format: NSLocalizedString("Send test message to %@", comment: "bot settings test message accessibility"), bot.name))

                Button(action: {
                    manager.removeBot(id: bot.id)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(QuantumColors.error)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(QuantumColors.error.opacity(0.5), lineWidth: 1)
                        )
                }
                .accessibilityLabel(String(format: NSLocalizedString("Delete %@", comment: "bot settings delete button accessibility"), bot.name))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(QuantumColors.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(QuantumColors.accent.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func truncatedURL(_ url: String) -> String {
        if url.count > 40 {
            return String(url.prefix(37)) + "..."
        }
        return url
    }

    // MARK: - Mini Apps

    private var availableMiniApps: [MiniApp] {
        BotManager.shared.miniApps
    }

    private var miniAppsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("bot_mini_apps", comment: "Section header for mini apps"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            if availableMiniApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(QuantumColors.textTertiary)
                    Text(NSLocalizedString("bot_no_mini_apps", comment: "Empty state when no mini apps are available"))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(availableMiniApps) { (app: MiniApp) in
                    if let url = URL(string: app.url) {
                        NavigationLink {
                            MiniAppWebViewContainer(url: url)
                        } label: {
                            HStack {
                                Image(systemName: app.icon.isEmpty ? "app.fill" : app.icon)
                                    .foregroundColor(QuantumColors.accent)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(QuantumFonts.body)
                                        .foregroundColor(QuantumColors.textPrimary)
                                    Text(app.description)
                                        .font(QuantumFonts.caption)
                                        .foregroundColor(QuantumColors.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(QuantumColors.textSecondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(QuantumColors.surface.opacity(0.6))
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }
}
