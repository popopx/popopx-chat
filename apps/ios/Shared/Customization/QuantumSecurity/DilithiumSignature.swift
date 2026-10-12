// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import CryptoKit
import os

// WARNING: Despite the "Dilithium" naming, this uses Ed25519 (classical cryptography).
// Real Dilithium (ML-DSA / FIPS 204) requires a dedicated post-quantum library.
// This is an educational demo only — do NOT use for security-critical signatures.

// MARK: - Verification Result

enum SignatureVerificationResult: String {
    case valid = "Valid"
    case invalid = "Invalid"
}

// MARK: - Signature Manager

@MainActor
class DilithiumSignatureManager: ObservableObject {
    @Published var publicKeyHex: String = ""
    @Published var signatureHex: String?
    @Published var verificationResult: SignatureVerificationResult?

    private var privateKey: Curve25519.Signing.PrivateKey?

    func generateKeyPair() {
        let key = Curve25519.Signing.PrivateKey()
        self.privateKey = key
        self.publicKeyHex = key.publicKey.rawRepresentation.hexString
        self.signatureHex = nil
        self.verificationResult = nil
    }

    func sign(message: String) -> String? {
        guard let privateKey = self.privateKey,
              let messageData = message.data(using: .utf8) else {
            return nil
        }

        do {
            let signature = try privateKey.signature(for: messageData)
            let hex = signature.hexString
            self.signatureHex = hex
            self.verificationResult = nil
            return hex
        } catch {
            os_log(.error, "DilithiumSignature: signing failed: %{public}@", error.localizedDescription)
            self.signatureHex = nil
            return nil
        }
    }

    func verify(message: String, signature: String, publicKey externalPublicKey: Data? = nil) -> Bool {
        let resolvedPublicKey: Curve25519.Signing.PublicKey?

        if let externalPublicKey = externalPublicKey {
            resolvedPublicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: externalPublicKey)
        } else if let privateKey = self.privateKey {
            resolvedPublicKey = privateKey.publicKey
        } else {
            resolvedPublicKey = nil
        }

        guard let publicKey = resolvedPublicKey,
              let messageData = message.data(using: .utf8),
              let signatureData = Data(hexString: signature) else {
            self.verificationResult = .invalid
            return false
        }

        let isValid = publicKey.isValidSignature(signatureData, for: messageData)
        self.verificationResult = isValid ? .valid : .invalid
        return isValid
    }
}

// MARK: - View

struct DilithiumSignatureView: View {
    @EnvironmentObject var theme: AppTheme
    @StateObject private var manager = DilithiumSignatureManager()
    @State private var messageText: String = ""
    @State private var showSignature: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header icon
                Image(systemName: "doc.badge.key.fill")
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

                Text(NSLocalizedString("quantum_dilithium_title", comment: "Title for Ed25519 digital signature view"))
                    .font(QuantumFonts.headerTitle)
                    .foregroundColor(QuantumColors.textPrimary)

                Text(NSLocalizedString("quantum_dilithium_demo_warning", comment: "Warning that Ed25519 is classical, not post-quantum"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.warning)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("quantum_dilithium_description", comment: "Description of Ed25519 signature algorithm"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
                    .multilineTextAlignment(.center)

                // Public Key section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "key.viewfinder")
                            .foregroundColor(QuantumColors.accent)
                        Text(NSLocalizedString("quantum_signing_public_key", comment: "Section header for signing public key"))
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

                // Message input section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "text.bubble.fill")
                            .foregroundColor(QuantumColors.accentSecondary)
                        Text(NSLocalizedString("quantum_message_label", comment: "Section header for message input"))
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)
                    }

                    ZStack(alignment: .topLeading) {
                        if messageText.isEmpty {
                            Text(NSLocalizedString("quantum_message_placeholder", comment: "Placeholder prompting user to enter a message to sign"))
                                .font(QuantumFonts.body)
                                .foregroundColor(QuantumColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        TextEditor(text: $messageText)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(minHeight: 80)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(QuantumColors.surface.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(QuantumColors.surfaceElevated, lineWidth: 1)
                    )
                    .accessibilityLabel(NSLocalizedString("Message input for signing", comment: "Dilithium signature message input accessibility"))
                }
                .padding(16)
                .glassBackground(cornerRadius: 12)

                // Signature display
                if let signature = manager.signatureHex {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "signature")
                                .foregroundColor(QuantumColors.warning)
                            Text(NSLocalizedString("quantum_signature_label", comment: "Section header for signature output"))
                                .font(QuantumFonts.sectionHeader)
                                .foregroundColor(QuantumColors.textPrimary)
                            Spacer()
                            Button {
                                showSignature.toggle()
                            } label: {
                                Image(systemName: showSignature ? "eye.slash" : "eye")
                                    .foregroundColor(QuantumColors.textSecondary)
                            }
                            .accessibilityLabel(showSignature ? NSLocalizedString("Hide signature", comment: "Dilithium hide signature accessibility") : NSLocalizedString("Show signature", comment: "Dilithium show signature accessibility"))
                        }

                        if showSignature {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(signature)
                                    .font(QuantumFonts.encryptionLabel)
                                    .foregroundColor(QuantumColors.warning)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(QuantumColors.warning.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(QuantumColors.warning.opacity(0.25), lineWidth: 0.5)
                            )
                        } else {
                            Text(String(repeating: "\u{2022}", count: 48))
                                .font(QuantumFonts.encryptionLabel)
                                .foregroundColor(QuantumColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                    }
                    .padding(16)
                    .glassBackground(cornerRadius: 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Verification result
                if let result = manager.verificationResult {
                    verificationBadge(result: result)
                        .transition(.opacity.combined(with: .scale))
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            manager.generateKeyPair()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(NSLocalizedString("quantum_generate_key_pair", comment: "Button to generate a new signing key pair"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GlassProminentButtonStyle())
                    .accessibilityLabel(NSLocalizedString("Generate a new Ed25519 signing key pair", comment: "Dilithium generate key pair accessibility"))

                    Button {
                        guard !messageText.isEmpty else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            _ = manager.sign(message: messageText)
                            showSignature = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil.and.outline")
                            Text(NSLocalizedString("quantum_sign_message", comment: "Button to sign the message"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GlassButtonStyle(tint: QuantumColors.warning))
                    .disabled(messageText.isEmpty || manager.publicKeyHex.isEmpty)
                    .opacity(messageText.isEmpty || manager.publicKeyHex.isEmpty ? 0.5 : 1.0)
                    .accessibilityLabel(NSLocalizedString("Sign the message with the current key pair", comment: "Dilithium sign message accessibility"))

                    Button {
                        guard let signature = manager.signatureHex, !messageText.isEmpty else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            _ = manager.verify(message: messageText, signature: signature)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                            Text(NSLocalizedString("quantum_verify_signature", comment: "Button to verify the signature"))
                        }
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.encryptionEnhanced)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(GlassButtonStyle(tint: QuantumColors.encryptionEnhanced))
                    .disabled(manager.signatureHex == nil || messageText.isEmpty)
                    .opacity(manager.signatureHex == nil || messageText.isEmpty ? 0.5 : 1.0)
                    .accessibilityLabel(NSLocalizedString("Verify the signature against the message", comment: "Dilithium verify signature accessibility"))
                }

                // Algorithm info
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("quantum_algorithm_details", comment: "Section header for algorithm details"))
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    infoRow(label: NSLocalizedString("quantum_algorithm_label", comment: "Label for algorithm name"), value: "Ed25519")
                    infoRow(label: NSLocalizedString("quantum_key_size", comment: "Label for key size"), value: "256-bit")
                    infoRow(label: NSLocalizedString("quantum_signature_size", comment: "Label for signature size"), value: "64 bytes")
                    infoRow(label: NSLocalizedString("quantum_curve", comment: "Label for elliptic curve name"), value: "Curve25519")
                }
                .padding(16)
                .glassBackground(cornerRadius: 12)
            }
            .padding(16)
        }
        .background(QuantumGradients.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("dilithium_nav_title", comment: "navigation title for Ed25519 signature view"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.generateKeyPair()
        }
        .popopxBranded()
    }

    // MARK: - Subviews

    private func verificationBadge(result: SignatureVerificationResult) -> some View {
        let color: Color = result == .valid ? QuantumColors.success : QuantumColors.error
        let icon: String = result == .valid ? "checkmark.seal.fill" : "xmark.seal.fill"

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("quantum_verification_result", comment: "Label for signature verification result badge"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
                Text(result == .valid
                    ? NSLocalizedString("quantum_result_valid", comment: "Signature verification passed")
                    : NSLocalizedString("quantum_result_invalid", comment: "Signature verification failed"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding(14)
        .glassBackground(cornerRadius: 12, tint: color, opacity: 0.1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
        )
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

// MARK: - Data Hex Init

private extension Data {
    init?(hexString: String) {
        let hex = hexString.lowercased()
        guard hex.count % 2 == 0 else { return nil }

        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
