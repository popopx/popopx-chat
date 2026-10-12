// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/11-FEATURE-DID.md
import SwiftUI

struct VCIssuerView: View {
    @EnvironmentObject var didManager: DIDManager
    @State private var holderDID: String = ""
    @State private var selectedType: String = "Subscription"
    @State private var issuerName: String = ""
    @State private var showConfirmation: Bool = false

    private let credentialTypes = ["Subscription", "CommunityMember", "SkillCert"]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: Text(NSLocalizedString("vc_issuer_credential_details", comment: "Section header for credential details form"))
                    .foregroundColor(QuantumColors.textSecondary)
                    .font(QuantumFonts.caption)) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("vc_issuer_holder_did", comment: "Label for holder DID field"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        TextField(NSLocalizedString("vc_issuer_did_placeholder", comment: "Placeholder for DID input field"), text: $holderDID)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("vc_issuer_credential_type", comment: "Label for credential type picker"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        Picker(NSLocalizedString("vc_issuer_type", comment: "Picker label for credential type"), selection: $selectedType) {
                            ForEach(credentialTypes, id: \.self) { type in
                                Text(type)
                                    .foregroundColor(QuantumColors.textPrimary)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(QuantumColors.accent)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("vc_issuer_issuer_label", comment: "Label for issuer name field"))
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                        TextField(NSLocalizedString("vc_issuer_name_placeholder", comment: "Placeholder for issuer name input"), text: $issuerName)
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(action: issueCredential) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                            Text(NSLocalizedString("vc_issuer_issue_credential", comment: "Button to issue a new credential"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(QuantumColors.accent)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                }

                Section(header: Text(NSLocalizedString("vc_issuer_issued_credentials", comment: "Section header for list of issued credentials"))
                    .foregroundColor(QuantumColors.textSecondary)
                    .font(QuantumFonts.caption)) {

                    if didManager.credentials.isEmpty {
                        Text(NSLocalizedString("vc_issuer_no_credentials", comment: "Empty state when no credentials have been issued"))
                            .foregroundColor(QuantumColors.textSecondary)
                            .font(QuantumFonts.body)
                    } else {
                        ForEach(didManager.credentials) { credential in
                            credentialRow(credential)
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("vc_issue_credential", comment: "navigation title for verifiable credential issuer"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if holderDID.isEmpty, let did = didManager.currentDID {
                holderDID = did
            }
        }
        .alert(NSLocalizedString("vc_credential_issued", comment: "alert title when credential is issued"), isPresented: $showConfirmation) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(String(format: NSLocalizedString("vc_new_credential_issued_fmt", comment: "alert message when new credential issued"), selectedType)))
        }
        .popopxBranded()
    }

    private func credentialRow(_ credential: VerifiableCredential) -> some View {
        HStack(spacing: 12) {
            Image(systemName: credential.status == "active" ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundColor(credential.status == "active" ? QuantumColors.success : QuantumColors.error)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(credential.type)
                    .font(QuantumFonts.body)
                    .fontWeight(.medium)
                    .foregroundColor(QuantumColors.textPrimary)
                Text(String(format: NSLocalizedString("vc_issuer_issued_date_fmt", comment: "VC credential issuance date"), credential.issuanceDate))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }

            Spacer()

            if credential.status == "active" {
                Button(action: { didManager.revokeCredential(credential.id) }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(QuantumColors.error)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }

    private func issueCredential() {
        guard !holderDID.isEmpty else { return }
        guard holderDID.hasPrefix("did:popopx:") else { return }
        let issuer = issuerName.isEmpty ? "self" : issuerName
        _ = didManager.issueCredential(type: selectedType, issuer: issuer)
        showConfirmation = true
    }
}
