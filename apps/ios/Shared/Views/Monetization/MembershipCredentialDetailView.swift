// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import CoreImage.CIFilterBuiltins

/// Membership Credential Detail View
struct MembershipCredentialDetailView: View {
    let credential: MembershipCredential
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var wallet = MembershipWallet.shared
    @State private var isRedeeming = false
    @State private var showShareSheet = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // QR Code
                    qrCodeSection

                    // Credential details
                    detailsSection

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("membership_credential_detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("common_alert", isPresented: $showAlert) {
                Button("common_ok", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: credential.tier == "premium" ? "crown.fill" : "star.fill")
                .font(.system(size: 48))
                .foregroundColor(credential.tier == "premium" ? .yellow : .blue)

            Text(credential.tierDisplayName)
                .font(.title)
                .fontWeight(.bold)

            Text("membership_credential_subtitle")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    private var qrCodeSection: some View {
        VStack(spacing: 12) {
            Text("membership_scan_to_import")
                .font(.headline)

            // Generate QR code
            if let qrImage = generateQRCode(from: credentialURL) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Text("membership_qr_generation_failed")
                            .foregroundColor(.secondary)
                    )
            }

            Text("membership_qr_hint")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 16) {
            detailRow(title: "membership_detail_tier", value: credential.tierDisplayName)
            detailRow(title: "membership_detail_expires", value: credential.expiresAt.formatted(date: .long, time: .omitted))
            detailRow(title: "membership_detail_status", value: statusText)
            detailRow(title: "membership_detail_source", value: sourceText)
            detailRow(title: "membership_detail_created", value: credential.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if credential.status == .unused && !credential.isExpired {
                Button(action: redeemCredential) {
                    if isRedeeming {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("membership_redeem_now")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(isRedeeming)
            }

            Button(action: copyCredential) {
                Label("membership_copy_credential", systemImage: "doc.on.doc")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }

            Button(action: shareCredential) {
                Label("membership_share_credential", systemImage: "square.and.arrow.up")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Computed Properties

    private var credentialURL: String {
        return "popopx://membership?x=\(credential.credentialX)&s=\(credential.signatureS)"
    }

    private var statusText: String {
        if credential.isExpired {
            return "membership_status_expired"
        }
        switch credential.status {
        case .unused: return "membership_status_unused"
        case .active: return "membership_status_active"
        case .expired: return "membership_status_expired"
        case .revoked: return "membership_status_revoked"
        }
    }

    private var sourceText: String {
        switch credential.source {
        case .purchase: return "membership_source_purchase"
        case .gift: return "membership_source_gift"
        case .redeemCode: return "membership_source_code"
        }
    }

    // MARK: - Actions

    private func redeemCredential() {
        isRedeeming = true

        Task {
            do {
                let result = try await wallet.redeemCredential(credential)
                isRedeeming = false

                if let success = result["success"] as? Bool, success {
                    alertMessage = "membership_redeem_success"
                } else {
                    alertMessage = result["error"] as? String ?? "membership_redeem_failed"
                }
                showAlert = true
            } catch {
                isRedeeming = false
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func copyCredential() {
        UIPasteboard.general.string = credentialURL
        alertMessage = "membership_credential_copied"
        showAlert = true
    }

    private func shareCredential() {
        showShareSheet = true
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Localization

extension String {
    static let membershipCredentialDetail = "membership_credential_detail"
    static let membershipCredentialSubtitle = "membership_credential_subtitle"
    static let membershipScanToImport = "membership_scan_to_import"
    static let membershipQrGenerationFailed = "membership_qr_generation_failed"
    static let membershipQrHint = "membership_qr_hint"
    static let membershipDetailTier = "membership_detail_tier"
    static let membershipDetailExpires = "membership_detail_expires"
    static let membershipDetailStatus = "membership_detail_status"
    static let membershipDetailSource = "membership_detail_source"
    static let membershipDetailCreated = "membership_detail_created"
    static let membershipRedeemNow = "membership_redeem_now"
    static let membershipCopyCredential = "membership_copy_credential"
    static let membershipShareCredential = "membership_share_credential"
    static let membershipRedeemSuccess = "membership_redeem_success"
    static let membershipRedeemFailed = "membership_redeem_failed"
    static let membershipCredentialCopied = "membership_credential_copied"
    static let membershipSourcePurchase = "membership_source_purchase"
    static let membershipSourceGift = "membership_source_gift"
    static let membershipSourceCode = "membership_source_code"
}
