// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

/// Membership Credential Row
struct MembershipCredentialRow: View {
    let credential: MembershipCredential

    var body: some View {
        HStack(spacing: 12) {
            // Tier icon
            Image(systemName: tierIcon)
                .font(.title2)
                .foregroundColor(tierColor)
                .frame(width: 44, height: 44)
                .background(tierColor.opacity(0.15))
                .cornerRadius(10)

            // Credential info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(credential.tierDisplayName)
                        .font(.headline)

                    Spacer()

                    statusBadge
                }

                Text("membership_expires \(credential.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var tierIcon: String {
        switch credential.tier {
        case "premium": return "crown.fill"
        case "basic": return "star.fill"
        default: return "ticket.fill"
        }
    }

    private var tierColor: Color {
        switch credential.tier {
        case "premium": return .yellow
        case "basic": return .blue
        default: return .gray
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color) = statusInfo

        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }

    private var statusInfo: (String, Color) {
        if credential.isExpired {
            return ("membership_status_expired", .red)
        }

        switch credential.status {
        case .unused:
            return ("membership_status_unused", .orange)
        case .active:
            return ("membership_status_active", .green)
        case .expired:
            return ("membership_status_expired", .red)
        case .revoked:
            return ("membership_status_revoked", .gray)
        }
    }
}

// MARK: - Localization

extension String {
    static let membershipExpires = "membership_expires"
    static let membershipStatusUnused = "membership_status_unused"
    static let membershipStatusActive = "membership_status_active"
    static let membershipStatusExpired = "membership_status_expired"
    static let membershipStatusRevoked = "membership_status_revoked"
}
