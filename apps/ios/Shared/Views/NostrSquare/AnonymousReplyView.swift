// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct AnonymousReplyView: View {
    let item: BroadcastItem
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("nostr_reply_original_label", comment: "Original message label in reply view"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(item.content)
                        .font(.body)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                }

                TextEditor(text: $replyText)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                HStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(Color.accentColor)
                    Text(NSLocalizedString("nostr_reply_privacy_notice", comment: "Privacy notice in reply view"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("nostr_reply_title", comment: "Anonymous reply navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("search_cancel_button", comment: "Cancel search button")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSending = true
                        // Anonymous DM sending is a pending Phase 5 integration with POPOPX.
                        // Until implemented, simulate a send with a short delay.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isSending = false
                            dismiss()
                        }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("nostr_reply_send_button", comment: "Send reply button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || isSending)
                }
            }
        }
        .popopxBranded()
    }
}
