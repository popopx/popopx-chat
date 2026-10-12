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
                    ((developerTools ? Text(NSLocalizedString("dev_show_label", comment: "Show toggle label")) : Text(NSLocalizedString("dev_hide_label", comment: "Hide toggle label"))) + textSpace + Text(NSLocalizedString("settings_show_hide_db_ids", comment: "Developer options description")))
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
                Section {
                    settingsRow("server.rack", color: theme.colors.secondary) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("settings_compute_store_url", comment: "Compute store URL label")).font(.subheadline)
                            #if DEBUG
                            TextField("https://api.example.com", text: Binding(
                                get: { EntitlementStore.shared.storeBaseURL },
                                set: { newURL in
                                    if newURL.hasPrefix("https://") {
                                        EntitlementStore.shared.storeBaseURL = newURL
                                    }
                                }
                            ))
                            .font(.footnote)
                            .foregroundColor(theme.colors.secondary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            #else
                            Text(EntitlementStore.shared.storeBaseURL)
                                .font(.footnote)
                                .foregroundColor(theme.colors.secondary)
                            #endif
                        }
                    }
                } header: {
                    Text(NSLocalizedString("dev_compute_store_header", comment: "Compute Store section header"))
                        .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                } footer: {
                    Text(NSLocalizedString("dev_compute_store_footer", comment: "Compute Store configuration description"))
                        .foregroundColor(theme.colors.secondary)
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
