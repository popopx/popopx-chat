// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import CryptoKit
import os

// WARNING: Despite the "Kyber" naming, this uses X25519 ECDH (classical cryptography).
// Real Kyber (ML-KEM / FIPS 203) requires a dedicated post-quantum library.
// This is an educational demo only — do NOT use for security-critical key exchange.

// MARK: - Exchange Status

enum ExchangeStatus: String {
    case idle = "Idle"
    case exchanging = "Exchanging..."
    case complete = "Complete"
}

// MARK: - Key Exchange Manager

@MainActor
class KyberKeyExchangeManager: ObservableObject {
    @Published var publicKeyHex: String = ""
    @Published var sharedSecretHex: String?
    @Published var status: ExchangeStatus = .idle

    private var privateKey: Curve25519.KeyAgreement.PrivateKey?

    func generateKeyPair() {
        // Release previous key before generating a new one.
        // Note: CryptoKit doesn't support explicit memory zeroing,
        // but nil-ing the reference allows ARC to deallocate it.
        self.privateKey = nil
        let key = Curve25519.KeyAgreement.PrivateKey()
        self.privateKey = key
        self.publicKeyHex = key.publicKey.rawRepresentation.hexString
        self.sharedSecretHex = nil
        self.status = .idle
    }

    func performKeyExchange() {
        guard let privateKey = self.privateKey else { return }

        self.status = .exchanging
        self.sharedSecretHex = nil

        // Generate an ephemeral key pair to simulate the other party
        let ephemeralPrivate = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublic = ephemeralPrivate.publicKey

        do {
            let sharedSecret1 = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublic)
            let sharedSecret2 = try ephemeralPrivate.sharedSecretFromKeyAgreement(with: privateKey.publicKey)

            let bytes1 = sharedSecret1.withUnsafeBytes { Data($0) }
            let bytes2 = sharedSecret2.withUnsafeBytes { Data($0) }
            assert(bytes1 == bytes2, "Key agreement mismatch")

            let derivedKey = SymmetricKey(data: bytes1)
            let derivedData = derivedKey.withUnsafeBytes { Data($0) }

            self.sharedSecretHex = derivedData.hexString
            self.status = .complete
        } catch {
            os_log(.error, "KyberKeyExchange: key exchange failed: %{public}@", error.localizedDescription)
            self.status = .idle
            self.sharedSecretHex = nil
        }
    }
}

// MARK: - View

struct KyberKeyExchangeView: View {
    @EnvironmentObject var theme: AppTheme
    @StateObject private var manager = KyberKeyExchangeManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header icon
                Image(systemName: "key.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: QuantumColors.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                    .padding(.top, 8)

                Text(NSLocalizedString("quantum_kyber_title", comment: "Title for X25519 key exchange view"))
                    .font(QuantumFonts.headerTitle)
                    .foregroundColor(QuantumColors.textPrimary)

                Text(NSLocalizedString("quantum_kyber_demo_warning", comment: "Warning that X25519 is classical ECDH, not post-quantum"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.warning)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("quantum_kyber_description", comment: "Description of X25519 key exchange algorithm"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
                    .multilineTextAlignment(.center)

                // Status indicator
                statusBadge

                // Public Key section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "key.viewfinder")
                            .foregroundColor(QuantumColors.accent)
                        Text(NSLocalizedString("quantum_public_key", comment: "Section header for public key"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                    }

                    if manager.publicKeyHex.isEmpty {
                        Text(NSLocalizedString("quantum_no_key_pair", comment: "Placeholder when no key pair has been generated"))
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(manager.publicKeyHex)
                                .font(QuantumFonts.encryptionLabel)
                                .foregroundColor(QuantumColors.accent)
                                .textSelection(.enabled)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(QuantumColors.surface.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(QuantumColors.accent.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
                .padding(16)
                .glassBackground(cornerRadius: 12)

                // Shared Secret section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(QuantumColors.encryptionEnhanced)
                        Text(NSLocalizedString("quantum_shared_secret", comment: "Section header for shared secret"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                    }

                    if let secret = manager.sharedSecretHex {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(secret)
                                .font(QuantumFonts.encryptionLabel)
                                .foregroundColor(QuantumColors.encryptionEnhanced)
                                .textSelection(.enabled)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(QuantumColors.success.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(QuantumColors.success.opacity(0.3), lineWidth: 0.5)
                        )
                    } else {
                        Text(manager.status == .exchanging
                            ? NSLocalizedString("quantum_deriving_secret", comment: "Status text while deriving shared secret")
                            : NSLocalizedString("quantum_perform_exchange_hint", comment: "Hint to perform key exchange to derive secret"))
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }
                .padding(16)
                .glassBackground(cornerRadius: 12)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            manager.generateKeyPair()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(NSLocalizedString("quantum_generate_key_pair", comment: "Button to generate a new key pair"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GlassProminentButtonStyle())
                    .accessibilityLabel(NSLocalizedString("Generate a new X25519 key pair", comment: "Kyber generate key pair accessibility"))

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            manager.performKeyExchange()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right")
                            Text(NSLocalizedString("quantum_perform_exchange", comment: "Button to perform key exchange"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GlassButtonStyle(tint: QuantumColors.accent))
                    .disabled(manager.publicKeyHex.isEmpty || manager.status == .exchanging)
                    .opacity(manager.publicKeyHex.isEmpty || manager.status == .exchanging ? 0.5 : 1.0)
                    .accessibilityLabel(NSLocalizedString("Perform an X25519 key exchange", comment: "Kyber key exchange accessibility"))
                }

                // Algorithm info
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("quantum_algorithm_details", comment: "Section header for algorithm details"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    infoRow(label: NSLocalizedString("quantum_algorithm_label", comment: "Label for algorithm name"), value: "X25519 ECDH")
                    infoRow(label: NSLocalizedString("quantum_key_size", comment: "Label for key size"), value: "256-bit")
                    infoRow(label: NSLocalizedString("quantum_security_level", comment: "Label for security level"), value: "128-bit")
                    infoRow(label: NSLocalizedString("quantum_curve", comment: "Label for elliptic curve name"), value: "Curve25519")
                }
                .padding(16)
                .glassBackground(cornerRadius: 12)
            }
            .padding(16)
        }
        .background(QuantumGradients.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("kyber_nav_title", comment: "navigation title for X25519 key exchange view"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.generateKeyPair()
        }
        .popopxBranded()
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.6), radius: 4)

            Text(statusText)
                .font(QuantumFonts.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(statusColor.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch manager.status {
        case .idle: return QuantumColors.textSecondary
        case .exchanging: return QuantumColors.warning
        case .complete: return QuantumColors.success
        }
    }

    private var statusText: String {
        switch manager.status {
        case .idle: return NSLocalizedString("quantum_status_idle", comment: "Key exchange status: idle")
        case .exchanging: return NSLocalizedString("quantum_status_exchanging", comment: "Key exchange Status: in progress")
        case .complete: return NSLocalizedString("quantum_status_complete", comment: "Key exchange status: complete")
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(QuantumFonts.caption)
                .foregroundColor(QuantumColors.textSecondary)
            Spacer()
            Text(value)
                .font(QuantumFonts.encryptionLabel)
                .foregroundColor(QuantumColors.accent)
        }
    }
}

