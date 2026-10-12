//
//  CallSettings.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 27/05/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct CallSettings: View {
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var subscription: SubscriptionManager
    @AppStorage(DEFAULT_WEBRTC_POLICY_RELAY) private var webrtcPolicyRelay = true
    @AppStorage(GROUP_DEFAULT_CALL_KIT_ENABLED, store: groupDefaults) private var callKitEnabled = true
    @AppStorage(DEFAULT_CALL_KIT_CALLS_IN_RECENTS) private var callKitCallsInRecents = false
    private let allowChangingCallsHistory = false

    var body: some View {
        VStack {
            List {
                Section {
                    if subscription.effectiveTier == .premium {
                        NavigationLink {
                            RTCServers()
                                .navigationTitle(NSLocalizedString("settings_your_ice_servers", comment: "Your ICE servers navigation title"))
                                .modifier(ThemedBackground(grouped: true))
                        } label: {
                            Text(NSLocalizedString("settings_webrtc_ice_servers", comment: "WebRTC ICE servers navigation label"))
                        }
                    }
                    Toggle(NSLocalizedString("settings_always_use_relay", comment: "Always use relay toggle"), isOn: $webrtcPolicyRelay)
                } header: {
                    Text(NSLocalizedString("settings_call_settings_header", comment: "Call settings section header"))
                        .font(pxSectionHeaderFont())
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                } footer: {
                    if webrtcPolicyRelay {
                        Text(NSLocalizedString("settings_relay_protects_ip", comment: "Relay protects IP address description"))
                            .foregroundColor(theme.colors.secondary)
                    } else {
                        Text(NSLocalizedString("settings_relay_only_if_necessary", comment: "Relay only used when necessary description"))
                            .foregroundColor(theme.colors.secondary)
                    }
                }

                if !CallController.isInChina {
                    Section {
                        Toggle(NSLocalizedString("settings_use_ios_call_interface", comment: "Use iOS call interface toggle"), isOn: $callKitEnabled)
                        Toggle(NSLocalizedString("settings_show_calls_in_history", comment: "Show calls in phone history toggle"), isOn: $callKitCallsInRecents)
                        .disabled(!callKitEnabled)
                        .onChange(of: callKitCallsInRecents) {_,  value in
                            CallController.shared.showInRecents(value)
                        }
                    } header: {
                        Text(NSLocalizedString("settings_interface_section", comment: "Interface section header"))
                            .font(pxSectionHeaderFont())
                            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
                    } footer: {
                        if callKitEnabled {
                            Text(NSLocalizedString("settings_accept_calls_lockscreen", comment: "Accept calls from lock screen description"))
                        } else {
                            Text(NSLocalizedString("settings_auth_required_before_connect", comment: "Authentication required before connect description"))
                        }
                    }
                }

                Section(header: Text(NSLocalizedString("settings_limitations_section", comment: "Limitations section header")).font(pxSectionHeaderFont()).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                    VStack(alignment: .leading, spacing: PXCallLayout.limitationsSpacing) {
                        textListItem("1.", NSLocalizedString("settings_no_emergency_calls", comment: "Do NOT use for emergency calls warning"))
                        textListItem("2.", NSLocalizedString("settings_enable_dnd_mode", comment: "Enable Do Not Disturb mode instruction"))
                    }
                    .font(.callout)
                    .padding(.vertical, PXCallLayout.limitationsVerticalPadding)
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .popopxBranded()
    }
}

func textListItem(_ n: String, _ text: String) -> some View {
    ZStack(alignment: .topLeading) {
        Text(n)
        Text(verbatim: text).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, PXCallLayout.numberPadding)
    }
}

struct CallSettings_Previews: PreviewProvider {
    static var previews: some View {
        CallSettings()
    }
}

// MARK: - POPOPX
extension CallSettings {
    var pxComponentTag: String { "PX_CALL_SETTINGS" }

    func pxSectionHeaderFont() -> Font {
        isInDarkTheme() ? darkThemeHeaderFont() : .body
    }
}

private enum PXCallLayout {
    static let numberPadding: CGFloat = 20
    static let limitationsSpacing: CGFloat = 8
    static let limitationsVerticalPadding: CGFloat = 8
}
