//
//  ProfilePrivacyView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 17/03/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct HiddenProfileView: View {
    @State var user: User
    @Binding var profileHidden: Bool
    @EnvironmentObject private var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @State private var hidePassword = ""
    @State private var confirmHidePassword = ""
    @State private var saveErrorAlert = false
    @State private var savePasswordError: String?

    var body: some View {
        List {
            Text(NSLocalizedString("hidden_profile_title", comment: "Hide profile title"))
                .font(.system(size: 28, weight: .semibold))
                .bold()
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        
            Section() {
                ProfilePreview(profileOf: user)
                    .padding(.leading, -8)
            }

            Section {
                PassphraseField(key: $hidePassword, placeholder: NSLocalizedString("hidden_profile_password_placeholder", comment: "Password to show placeholder"), valid: passwordValid, showStrength: true)
                PassphraseField(key: $confirmHidePassword, placeholder: NSLocalizedString("hidden_profile_confirm_password", comment: "Confirm password placeholder"), valid: confirmValid)

                settingsRow("lock", color: theme.colors.secondary) {
                    Button(NSLocalizedString("hidden_profile_save_button", comment: "Save profile password button")) {
                        Task {
                            do {
                                let u = try await apiHideUser(user.userId, viewPwd: hidePassword)
                                await MainActor.run {
                                    m.updateUser(u)
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + pxHideAnimationDelay) {
                                        withAnimation { profileHidden = true }
                                    }
                                }
                            } catch let error {
                                saveErrorAlert = true
                                savePasswordError = responseError(error)
                            }
                        }
                    }
                }
                .disabled(saveDisabled)
            } header: {
                Text(NSLocalizedString("hidden_profile_password_header", comment: "Hidden profile password header"))
                    .font(isInDarkTheme() ? darkThemeHeaderFont() : .body)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            } footer: {
                Text(NSLocalizedString("hidden_profile_instructions", comment: "Instructions to reveal hidden profile"))
                    .foregroundColor(theme.colors.secondary)
                    .font(.body)
                    .padding(.top, 8)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .alert(isPresented: $saveErrorAlert) {
            Alert(
                title: Text(NSLocalizedString("hidden_profile_error_title", comment: "Error saving password alert title")),
                message: Text(savePasswordError ?? "")
            )
        }
        .modifier(ThemedBackground(grouped: true))
        .popopxBranded()
    }

    var passwordValid: Bool { hidePassword == hidePassword.trimmingCharacters(in: .whitespaces) }

    var confirmValid: Bool { confirmHidePassword == "" || hidePassword == confirmHidePassword }

    var saveDisabled: Bool { hidePassword == "" || !passwordValid || confirmHidePassword == "" || !confirmValid }
}

// MARK: - POPOPX
extension HiddenProfileView {
    /// Unique POPOPX component tag for analytics and diffing
    var pxComponentTag: String { "PX_HIDDEN_PROFILE_VIEW" }

    /// Delay before animating profile-hidden state
    var pxHideAnimationDelay: Double { 0.5 }
}

struct ProfilePrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        HiddenProfileView(user: User.sampleData, profileHidden: Binding.constant(false))
    }
}
