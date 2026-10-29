//
//  PreferencesView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 13/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Config
private enum PXPreferencesConfig {
    static let buttonSpacing: CGFloat = 12
    static let pickerFrameHeight: CGFloat = 36
    static let featureCount: Int = 5
}

// MARK: - POPOPX View Model
@MainActor
private struct PXPreferencesViewModel {
    let currentPreferences: FullPreferences
    let preferences: FullPreferences
    let profile: LocalProfile

    var pxHasUnsavedChanges: Bool { currentPreferences != preferences }
    var pxCanSave: Bool { currentPreferences != preferences }
    var pxProfileRef: LocalProfile { profile }
}

struct PreferencesView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State var profile: LocalProfile
    @State var preferences: FullPreferences
    @State var currentPreferences: FullPreferences

    var body: some View {
        pxMainContainer
            .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxMainContainer: some View {
        VStack {
            pxPreferencesList
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onDisappear { pxHandleDisappear() }
    }

    @ViewBuilder
    private var pxPreferencesList: some View {
        List {
            pxTimedMessagesSection
            pxFeatureSection(.fullDelete, $preferences.fullDelete.allow)
            pxFeatureSection(.reactions, $preferences.reactions.allow)
            pxFeatureSection(.voice, $preferences.voice.allow)
            pxFeatureSection(.calls, $preferences.calls.allow)
            pxActionButtonsSection
        }
        .modifier(ThemedBackground(grouped: true, glass: true))
    }

    @ViewBuilder
    private var pxTimedMessagesSection: some View {
        timedMessagesFeatureSection($preferences.timedMessages.allow, $preferences.timedMessages.ttl)
    }

    @ViewBuilder
    private var pxActionButtonsSection: some View {
        Section {
            HStack(spacing: PXPreferencesConfig.buttonSpacing) {
                Button(NSLocalizedString("preferences_reset_button", comment: "Reset button")) {
                    preferences = currentPreferences
                }
                .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                .accessibilityLabel(Text(NSLocalizedString("a11y_reset_preferences_defaults", comment: "")))

                Button(NSLocalizedString("preferences_save_notify", comment: "Save and notify contacts button")) {
                    pxSavePreferences()
                }
                .buttonStyle(GlassButtonStyle(tint: theme.colors.primary))
                .accessibilityLabel(Text(NSLocalizedString("a11y_save_preferences_notify_contacts", comment: "")))
            }
        }
        .disabled(currentPreferences == preferences)
    }

    private func pxFeatureSection(_ feature: ChatFeature, _ allowFeature: Binding<FeatureAllowed>) -> some View {
        Section {
            settingsRow(feature.icon, color: pxFeatureIconColor) {
                Picker(feature.text, selection: allowFeature) {
                    ForEach(FeatureAllowed.values) { allow in
                        Text(allow.text)
                    }
                }
                .frame(height: PXPreferencesConfig.pickerFrameHeight)
            }
        }
        footer: { pxFeatureFooter(for: feature, allowFeature: allowFeature) }
    }

    @ViewBuilder private func timedMessagesFeatureSection(_ allowFeature: Binding<FeatureAllowed>, _ ttl: Binding<Int?>) -> some View {
        let allow = Binding(
            get: { allowFeature.wrappedValue == .always || allowFeature.wrappedValue == .yes },
            set: { yes, _ in allowFeature.wrappedValue = yes ? .yes : .no }
        )
        Section {
            settingsRow(ChatFeature.timedMessages.icon, color: pxFeatureIconColor) {
                Toggle(ChatFeature.timedMessages.text, isOn: allow)
            }
            if allow.wrappedValue {
                Picker(NSLocalizedString("preferences_delete_after", comment: "Delete after picker label"), selection: ttl) {
                    ForEach(TimedMessagesPreference.profileLevelTTLValues, id: \.self) { value in
                        Text(pxTimeText(value)).tag(value)
                    }
                }
                .frame(height: PXPreferencesConfig.pickerFrameHeight)
            }
        }
        footer: {
            let featureDescription = ChatFeature.timedMessages.allowDescription(allowFeature.wrappedValue)
            if allow.wrappedValue && ttl.wrappedValue != nil {
                Text(verbatim: "\(featureDescription)\n\(NSLocalizedString("preferences_time_disappear_new_contacts", comment: "Time to disappear set for new contacts notice"))")
                    .foregroundColor(theme.colors.secondary)
            } else {
                Text(featureDescription)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    // MARK: - POPOPX Helpers

    private var pxFeatureIconColor: Color { theme.colors.secondary }

    private func pxFeatureFooter(for feature: ChatFeature, allowFeature: Binding<FeatureAllowed>) -> Text {
        Text(feature.allowDescription(allowFeature.wrappedValue))
            .foregroundColor(theme.colors.secondary)
    }

    private func pxTimeText(_ value: Int?) -> String {
        timeText(value)
    }

    // MARK: - POPOPX Actions

    private func pxHandleDisappear() {
        let vm = PXPreferencesViewModel(
            currentPreferences: currentPreferences,
            preferences: preferences,
            profile: profile
        )
        if vm.pxHasUnsavedChanges {
            showAlert(
                title: NSLocalizedString("preferences_changed_title", comment: "Preferences changed alert title"),
                message: NSLocalizedString("preferences_changed_message", comment: "Chat preferences changed alert message"),
                buttonTitle: NSLocalizedString("preferences_save_button", comment: "Save button"),
                buttonAction: pxSavePreferences,
                cancelButton: true
            )
        }
    }

    private func pxSavePreferences() {
        logger.debug("px: PreferencesView.savePreferences")
        Task {
            do {
                var p = fromLocalProfile(profile)
                p.preferences = fullPreferencesToPreferences(preferences)
                if let (newProfile, updatedContacts) = try await apiUpdateProfile(profile: p) {
                    await MainActor.run {
                        chatModel.updateCurrentUser(newProfile, preferences)
                        updatedContacts.forEach(chatModel.updateContact)
                        currentPreferences = preferences
                    }
                }
            } catch {
                logger.error("PreferencesView apiUpdateProfile error: \(responseError(error))")
            }
        }
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(
            profile: LocalProfile(profileId: 1, displayName: "alice", fullName: "", localAlias: ""),
            preferences: FullPreferences.sampleData,
            currentPreferences: FullPreferences.sampleData
        )
    }
}

// MARK: - POPOPX
extension PreferencesView {
    var pxComponentTag: String { "PX_PREFERENCES_VIEW" }
    var pxHasUnsavedChanges: Bool { currentPreferences != preferences }
    var pxFeatureCount: Int { PXPreferencesConfig.featureCount }
    var pxButtonSpacing: CGFloat { PXPreferencesConfig.buttonSpacing }
    var pxPickerHeight: CGFloat { PXPreferencesConfig.pickerFrameHeight }
}
