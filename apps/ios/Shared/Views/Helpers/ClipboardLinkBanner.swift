// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct ClipboardLinkBanner: View {
    let link: String
    let onDismiss: () -> Void
    let onConnect: () -> Void
    @EnvironmentObject var theme: AppTheme

    private var linkDescription: String {
        if link.hasPrefix("popopx://enc#") {
            return NSLocalizedString("clipboard_link_encrypted", comment: "clipboard banner link type")
        }
        let lower = link.lowercased()
        if lower.contains("/contact") || lower.contains("/a#") || lower.contains("/c#") {
            return NSLocalizedString("clipboard_link_contact", comment: "clipboard banner link type")
        }
        if lower.contains("/invitation") || lower.contains("/i#") {
            return NSLocalizedString("clipboard_link_invitation", comment: "clipboard banner link type")
        }
        if lower.contains("/group") || lower.contains("/g#") {
            return NSLocalizedString("clipboard_link_group", comment: "clipboard banner link type")
        }
        return NSLocalizedString("clipboard_link_unknown", comment: "clipboard banner link type")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(theme.colors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("clipboard_detected_link", comment: "clipboard banner title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.colors.primary)
                    Text(linkDescription)
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onConnect()
                } label: {
                    Text(NSLocalizedString("clipboard_connect_button", comment: "clipboard banner connect button"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(theme.colors.primary, in: Capsule())
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.colors.background)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}
