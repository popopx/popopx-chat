//
//  DeveloperView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 26/03/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct DeveloperView: View {
    @EnvironmentObject var theme: AppTheme
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @AppStorage(GROUP_DEFAULT_CONFIRM_DB_UPGRADES, store: groupDefaults) private var confirmDatabaseUpgrades = false
    @State private var hintsUnchanged = hintDefaultsUnchanged()
    @State private var popopxLinkMode = privacyPopopxLinkModeDefault.get()

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            List {
                Section {
                    #if DEBUG
                    NavigationLink {
                        PXTerminal()
                    } label: {
                        settingsRow("terminal", color: theme.colors.secondary) { Text(NSLocalizedString("settings_chat_console", comment: "Chat console navigation link")) }
                    }
                    #endif
                    settingsRow("lightbulb.max", color: theme.colors.secondary) {
                        Button(NSLocalizedString("settings_reset_hints", comment: "Reset all UI hints to defaults"), action: resetHintDefaults)
                        .disabled(hintsUnchanged)
                    }
                    settingsRow("chevron.left.forwardslash.chevron.right", color: theme.colors.secondary) {
                        Toggle(NSLocalizedString("dev_show_options_toggle", comment: "Show developer options toggle"), isOn: $developerTools)
                    }
                } header: {
                    Text("")
                } footer: {
                    Text(developerTools
                        ? "\(NSLocalizedString("dev_show_label", comment: "Show toggle label")) \(NSLocalizedString("settings_show_hide_db_ids", comment: "Developer options description"))"
                        : "\(NSLocalizedString("dev_hide_label", comment: "Hide toggle label")) \(NSLocalizedString("settings_show_hide_db_ids", comment: "Developer options description"))")
                        .foregroundColor(theme.colors.secondary)
                }
                
                if developerTools {
                    Section {
                        settingsRow("internaldrive", color: theme.colors.secondary) {
                            Toggle(NSLocalizedString("dev_confirm_db_upgrades_toggle", comment: "Confirm database upgrades toggle"), isOn: $confirmDatabaseUpgrades)
                        }
                        NavigationLink {
                            StorageView()
                                .navigationTitle(NSLocalizedString("settings_storage_label", comment: "Storage navigation title"))
                                .navigationBarTitleDisplayMode(.large)
                        } label: {
                            settingsRow("internaldrive", color: theme.colors.secondary) { Text(NSLocalizedString("dev_storage_button", comment: "Storage navigation button")) }
                        }
                    } header: {
                        Text(NSLocalizedString("settings_developer_options", comment: "Developer options section header"))
                            .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                    }
                }

                Section(NSLocalizedString("dev_deprecated_options_section", comment: "Deprecated options section header")) {
                    settingsRow("link", color: theme.colors.secondary) {
                        Picker(NSLocalizedString("dev_popopx_links_picker", comment: "POPOPX links picker label"), selection: $popopxLinkMode) {
                            ForEach(
                                LinkDisplayMode.values + (LinkDisplayMode.values.contains(popopxLinkMode) ? [] : [popopxLinkMode])
                            ) { mode in
                                Text(mode.text)
                            }
                        }
                    }
                    .frame(height: 36)
                    .onChange(of: popopxLinkMode) {_,  mode in
                        privacyPopopxLinkModeDefault.set(mode)
                    }
                }
            }
            .modifier(ThemedBackground(grouped: true, glass: true))
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .popopxBranded()
    }
    
    private func resetHintDefaults() {
        for def in hintDefaults {
            if let val = appDefaults[def] as? Bool {
                UserDefaults.standard.set(val, forKey: def)
            }
        }
        for def in hintGroupDefaults {
            if let val = groupAppDefaults[def] as? Bool {
                groupDefaults.set(val, forKey: def)
            }
        }
        hintsUnchanged = true
    }
}

private func hintDefaultsUnchanged() -> Bool {
    hintDefaults.allSatisfy { def in
        appDefaults[def] as? Bool == UserDefaults.standard.bool(forKey: def)
    } && hintGroupDefaults.allSatisfy { def in
        groupAppDefaults[def] as? Bool == groupDefaults.bool(forKey: def)
    }
}

struct DeveloperView_Previews: PreviewProvider {
    static var previews: some View {
        DeveloperView()
    }
}
