// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct BroadcastCardView: View {
    let item: BroadcastItem
    let tickerDate: Date
    @State private var showReply = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            Text(item.content)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            footerRow
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .sheet(isPresented: $showReply) {
            AnonymousReplyView(item: item)
        }
        .popopxBranded()
    }

    private var headerRow: some View {
        HStack {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor.opacity(0.6))

            Text(NSLocalizedString("nostr_card_anonymous_label", comment: "Anonymous sender label in broadcast card"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(timeRemainingString)
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(item.timeRemaining < 3600 ? .red : .secondary)
        }
    }

    private var footerRow: some View {
        HStack {
            Button {
                showReply = true
            } label: {
                Label(NSLocalizedString("nostr_card_resonate_button", comment: "Resonate/reply button in broadcast card"), systemImage: "bubble.left")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text(NSLocalizedString("nostr_card_ttl_label", comment: "TTL/time remaining label in broadcast card"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var timeRemainingString: String {
        let remaining = max(0, TimeInterval(item.expiresAt) - tickerDate.timeIntervalSince1970)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
