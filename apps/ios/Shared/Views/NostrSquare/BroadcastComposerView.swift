// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct BroadcastComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isPublishing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    let onPublish: (String) async throws -> Void

    private let characterLimit = 500

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)

                    Text(NSLocalizedString("nostr_composer_privacy_title", comment: "Privacy title in broadcast composer"))
                        .font(.headline)

                    Text(NSLocalizedString("nostr_composer_privacy_subtitle", comment: "Privacy subtitle in broadcast composer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                TextEditor(text: $text)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Text(String(format: NSLocalizedString("nostr_composer_char_count", comment: "Character count in composer"), text.count, characterLimit))
                        .font(.caption)
                        .foregroundStyle(text.count > characterLimit ? .red : .secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("nostr_composer_title", comment: "Broadcast composer navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("search_cancel_button", comment: "Cancel search button")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isPublishing = true
                            errorMessage = nil
                            do {
                                try await onPublish(text)
                                showSuccess = true
                                try? await Task.sleep(for: .milliseconds(800))
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isPublishing = false
                        }
                    } label: {
                        if isPublishing {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("nostr_composer_send_button", comment: "Send broadcast button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || text.count > characterLimit
                              || isPublishing)
                }
            }
            .alert(LocalizedStringKey(NSLocalizedString("nostr_publish_success", comment: "Nostr publish success alert")), isPresented: $showSuccess) {
                Button(NSLocalizedString("common_ok", comment: "OK button")) { dismiss() }
            }
            .alert(LocalizedStringKey(NSLocalizedString("nostr_publish_failed", comment: "Nostr publish failed alert")), isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(NSLocalizedString("common_ok", comment: "OK button")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .popopxBranded()
    }
}
