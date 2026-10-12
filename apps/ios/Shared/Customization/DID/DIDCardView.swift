// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/11-FEATURE-DID.md
import SwiftUI

struct DIDCardView: View {
    let card: PrivacyCard
    @EnvironmentObject var didManager: DIDManager

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                avatarCircle
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(QuantumColors.textPrimary)

                    Text(card.did)
                        .font(.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            if !card.credentials.isEmpty {
                credentialBadgesRow
            }

            Button(action: shareCard) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(NSLocalizedString("did_share_card", comment: "Button to share DID card"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(QuantumColors.accent)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .stroke(QuantumColors.accent, lineWidth: 1)
                )
            }

            NavigationLink(destination: VCIssuerView()) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                    Text(NSLocalizedString("did_issue_credential", comment: "Button to issue a credential"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(QuantumColors.accent)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .stroke(QuantumColors.accent, lineWidth: 1)
                )
            }

            NavigationLink(destination: VPVerifierView()) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                    Text(NSLocalizedString("did_verify_credential", comment: "Button to verify a credential"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(QuantumColors.accent)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .stroke(QuantumColors.accent, lineWidth: 1)
                )
            }
        }
        .padding(20)
        .glassBackground(cornerRadius: 20)
        .popopxBranded()
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [QuantumColors.primaryStart, QuantumColors.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            if let avatarName = card.avatar, !avatarName.isEmpty {
                Image(avatarName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
            } else {
                Text(String(card.displayName.prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(QuantumColors.textPrimary)
                    .accessibilityLabel(NSLocalizedString("Avatar initial", comment: "DID card avatar accessibility"))
            }

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 58, height: 58)
        }
    }

    private var credentialBadgesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(card.credentials) { credential in
                    credentialBadge(credential)
                }
            }
        }
    }

    private func credentialBadge(_ credential: VerifiableCredential) -> some View {
        HStack(spacing: 4) {
            Image(systemName: credential.status == "active" ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.caption2)
            Text(credential.type)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(credential.status == "active" ? QuantumColors.success : QuantumColors.error)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(
                    (credential.status == "active" ? QuantumColors.success : QuantumColors.error)
                        .opacity(0.15)
                )
        )
        .accessibilityLabel("\(credential.type), \(credential.status == "active" ? String(localized: "active") : String(localized: "invalid"))")
    }

    private func shareCard() {
        let shareText = String(format: NSLocalizedString("did_share_card_fmt", comment: "DID card share text format"), card.displayName, card.did)
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
