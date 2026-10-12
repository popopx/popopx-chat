// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

/// Membership Wallet - Credential List View
struct MembershipWalletView: View {
    @StateObject private var wallet = MembershipWallet.shared
    @State private var showingAddCredential = false
    @State private var selectedCredential: MembershipCredential?

    var body: some View {
        NavigationView {
            Group {
                if wallet.credentials.isEmpty {
                    emptyStateView
                } else {
                    credentialListView
                }
            }
            .navigationTitle("membership_wallet_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCredential = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if wallet.isLoading {
                        ProgressView()
                    } else if let lastSync = wallet.lastSyncDate {
                        Text("membership_last_sync")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                await wallet.verifyAllCredentials()
            }
            .refreshable {
                await wallet.verifyAllCredentials()
            }
            .sheet(isPresented: $showingAddCredential) {
                AddCredentialView()
            }
            .sheet(item: $selectedCredential) { credential in
                MembershipCredentialDetailView(credential: credential)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ticket")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("membership_wallet_empty")
                .font(.title2)
                .fontWeight(.semibold)

            Text("membership_wallet_empty_description")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingAddCredential = true }) {
                Text("membership_add_credential")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }

    private var credentialListView: some View {
        List {
            ForEach(wallet.credentials) { credential in
                MembershipCredentialRow(credential: credential)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCredential = credential
                    }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

/// Add Credential View (placeholder)
struct AddCredentialView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("membership_add_credential_description")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                // TODO: Add options for:
                // 1. Purchase via StoreKit
                // 2. Import from QR code
                // 3. Enter code manually

                Spacer()
            }
            .navigationTitle("membership_add_credential")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Localization Keys

extension String {
    static let membershipWalletTitle = "membership_wallet_title"
    static let membershipLastSync = "membership_last_sync"
    static let membershipWalletEmpty = "membership_wallet_empty"
    static let membershipWalletEmptyDescription = "membership_wallet_empty_description"
    static let membershipAddCredential = "membership_add_credential"
    static let membershipAddCredentialDescription = "membership_add_credential_description"
}
