//
//  ContactPreferencesView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 13/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ContactPreferencesView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var contact: Contact
    @Binding var featuresAllowed: ContactFeaturesAllowed
    @Binding var currentFeaturesAllowed: ContactFeaturesAllowed
    @State private var showSaveDialogue = false
    let savePreferences: () -> Void

    private let pxPickerHeight: CGFloat = 36
    private let pxDefaultTimedMessagesTTL: Int = 86400

    var body: some View {
        guard let user: User = chatModel.currentUser else {
            return AnyView(ProgressView("Loading..."))
        }

        return AnyView(

        VStack {
            List {
                timedMessagesFeatureSection()
                featureSection(.fullDelete, user.fullPreferences.fullDelete.allow, contact.mergedPreferences.fullDelete, $featuresAllowed.fullDelete)
                featureSection(.reactions, user.fullPreferences.reactions.allow, contact.mergedPreferences.reactions, $featuresAllowed.reactions)
                featureSection(.voice, user.fullPreferences.voice.allow, contact.mergedPreferences.voice, $featuresAllowed.voice)
                featureSection(.files, user.fullPreferences.files.allow, contact.mergedPreferences.files, $featuresAllowed.files)
                featureSection(.calls, user.fullPreferences.calls.allow, contact.mergedPreferences.calls, $featuresAllowed.calls)

                Section {
                    Button(NSLocalizedString("Reset", comment: "reset preferences button")) { featuresAllowed = currentFeaturesAllowed }
                    Button(NSLocalizedString("Save and notify contact", comment: "save preferences button")) { savePreferences() }
                }
                .disabled(currentFeaturesAllowed == featuresAllowed)
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        }
        .modifier(BackButton(disabled: Binding.constant(false)) {
            if currentFeaturesAllowed == featuresAllowed {
                dismiss()
            } else {
                showSaveDialogue = true
            }
        })
        .confirmationDialog(NSLocalizedString("Save preferences?", comment: "confirmation dialog title"), isPresented: $showSaveDialogue) {
            Button(NSLocalizedString("Save and notify contact", comment: "save preferences button")) {
                savePreferences()
                dismiss()
            }
            Button(NSLocalizedString("Exit without saving", comment: "discard preferences button")) {
                featuresAllowed = currentFeaturesAllowed
                dismiss()
            }
        }
        .popopxBranded()
        )
    }

    private func featureSection(_ feature: ChatFeature, _ userDefault: FeatureAllowed, _ pref: ContactUserPreference<SimplePreference>, _ allowFeature: Binding<ContactFeatureAllowed>) -> some View {
        let enabled = FeatureEnabled.enabled(
            asymmetric: feature.asymmetric,
            user: SimplePreference(allow: allowFeature.wrappedValue.allowed),
            contact: pref.contactPreference
        )
        return Section {
            Picker(NSLocalizedString("prefs_you_allow_picker", comment: "You allow picker label"), selection: allowFeature) {
                ForEach(ContactFeatureAllowed.values(userDefault)) { allow in
                    Text(allow.text)
                }
            }
            .frame(height: pxPickerHeight)
            infoRow(LocalizedStringKey(NSLocalizedString("prefs_contact_allows", comment: "Contact allows label")), pref.contactPreference.allow.text)
        }
        header: { featureHeader(feature, enabled).foregroundColor(theme.colors.secondary) }
        footer: { featureFooter(feature, enabled).foregroundColor(theme.colors.secondary) }
    }

    private func timedMessagesFeatureSection() -> some View {
        let pref = contact.mergedPreferences.timedMessages
        let enabled = FeatureEnabled.enabled(
            asymmetric: ChatFeature.timedMessages.asymmetric,
            user: TimedMessagesPreference(allow: featuresAllowed.timedMessagesAllowed ? .yes : .no),
            contact: pref.contactPreference
        )
        return Section {
            Toggle(NSLocalizedString("prefs_you_allow_toggle", comment: "You allow toggle label"), isOn: $featuresAllowed.timedMessagesAllowed)
                .onChange(of: featuresAllowed.timedMessagesAllowed) {_,  allow in
                    if allow {
                        if featuresAllowed.timedMessagesTTL == nil {
                            featuresAllowed.timedMessagesTTL = pxDefaultTimedMessagesTTL
                        }
                    } else {
                        featuresAllowed.timedMessagesTTL = currentFeaturesAllowed.timedMessagesTTL
                    }
                }
            infoRow(LocalizedStringKey(NSLocalizedString("prefs_contact_allows", comment: "Contact allows label")), pref.contactPreference.allow.text)
            if featuresAllowed.timedMessagesAllowed {
                PXDropdownTimePicker(
                    selection: $featuresAllowed.timedMessagesTTL,
                    label: LocalizedStringKey(NSLocalizedString("prefs_delete_after", comment: "Delete after label")),
                    dropdownValues: TimedMessagesPreference.ttlValues,
                    customPickerConfirmButtonText: LocalizedStringKey(NSLocalizedString("prefs_select_button", comment: "Select button")),
                    customPickerDescription: LocalizedStringKey(NSLocalizedString("prefs_delete_after", comment: "Delete after description"))
                )
                .frame(height: pxPickerHeight)
            } else if pref.contactPreference.allow == .yes || pref.contactPreference.allow == .always {
                infoRow(LocalizedStringKey(NSLocalizedString("prefs_delete_after", comment: "Delete after label")), timeText(pref.contactPreference.ttl))
            }
        }
        header: { featureHeader(.timedMessages, enabled).foregroundColor(theme.colors.secondary) }
        footer: { featureFooter(.timedMessages, enabled).foregroundColor(theme.colors.secondary) }
    }

    private func featureHeader(_ feature: ChatFeature, _ enabled: FeatureEnabled) -> some View {
        HStack {
            Image(systemName: feature.iconFilled)
                .foregroundColor(enabled.forUser ? QuantumColors.success : enabled.forContact ? QuantumColors.warning : QuantumColors.error)
            Text(feature.text)
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func featureFooter(_ feature: ChatFeature, _ enabled: FeatureEnabled) -> some View {
        Text(feature.enabledDescription(enabled))
    }
}

struct ContactPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        ContactPreferencesView(
            contact: Binding.constant(Contact.sampleData),
            featuresAllowed: Binding.constant(ContactFeaturesAllowed.sampleData),
            currentFeaturesAllowed: Binding.constant(ContactFeaturesAllowed.sampleData),
            savePreferences: {}
        )
        .previewEnvironment()
    }
}

// MARK: - POPOPX
extension ContactPreferencesView {
    var pxComponentTag: String { "PX_CONTACT_PREFERENCES" }
    var pxFeatureCount: Int {
        var n = 5 // fullDelete, reactions, voice, files, calls
        if contact.mergedPreferences.timedMessages.contactPreference.allow != .no { n += 1 }
        return n
    }
}
