//
//  KeyRotationNoticeView.swift
//  POPOPXSwitch
//
//  Security enhancement - key rotation notice
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct KeyRotationNoticeView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "key.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(theme.colors.primary)
                    .padding(.top, 32)

                Text(LocalizedStringKey(NSLocalizedString("db_key_rotation_title", comment: "Database key rotation title")))
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey(NSLocalizedString("db_key_rotation_desc", comment: "Database key rotation description")))
                        .font(.body)

                    Text(LocalizedStringKey(NSLocalizedString("db_key_rotation_action", comment: "Database key rotation action")))
                        .font(.body)
                        .foregroundColor(theme.colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    rotationStep(NSLocalizedString("Go to Settings > Database", comment: "Key rotation instruction step 1"), icon: "gear")
                    rotationStep(NSLocalizedString("Tap 'Database passphrase'", comment: "Key rotation instruction step 2"), icon: "key")
                    rotationStep(NSLocalizedString("Set a new strong passphrase", comment: "Key rotation instruction step 3"), icon: "lock.shield")
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                Button {
                    dismiss()
                } label: {
                    Text(LocalizedStringKey(NSLocalizedString("db_key_rotation_understood", comment: "Database key rotation understood button")))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.colors.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("Security Notice", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }

    private func rotationStep(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.colors.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
