// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct WalletView: View {
    @ObservedObject private var walletManager = WalletManager.shared

    var body: some View {
        SwiftUI.Group {
            if walletManager.entries.isEmpty {
                emptyStateView
            } else {
                walletListView
            }
        }
        .navigationTitle(NSLocalizedString("wallet_navigation_title", comment: "Wallet navigation title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        walletManager.clearAllEntries()
                    } label: {
                        Label(NSLocalizedString("wallet_clear_all", comment: "Clear all wallet entries button"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("wallet_no_assets_title", comment: "Empty wallet state title"))
                .font(.title2)
                .fontWeight(.medium)

            Text(NSLocalizedString("wallet_no_assets_description", comment: "Empty wallet state description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var walletListView: some View {
        List {
            Section(header: Text(NSLocalizedString("wallet_overview", comment: "Wallet overview section header"))) {
                ForEach(walletManager.getAllAssets(), id: \.self) { asset in
                    AssetSummaryRow(
                        asset: asset,
                        balance: walletManager.getBalance(for: asset)
                    )
                }
            }

            Section(header: Text(NSLocalizedString("wallet_all_entries", comment: "All wallet entries section header"))) {
                ForEach(Array(walletManager.entries.enumerated()), id: \.element.id) { index, entry in
                    WalletEntryRow(entry: entry) {
                        walletManager.removeEntry(at: index)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        walletManager.removeEntry(at: index)
                    }
                }
            }
        }
    }
}

struct AssetSummaryRow: View {
    let asset: String
    let balance: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(asset)
                    .font(.headline)
                Text(NSLocalizedString("wallet_balance", comment: "Balance label in asset summary"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formatBalance(balance))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(balance >= 0 ? .green : .red)
                .accessibilityValue(balance >= 0 ? String(localized: "positive") : String(localized: "negative"))
        }
        .padding(.vertical, 4)
    }

    private func formatBalance(_ balance: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
    }
}

struct WalletEntryRow: View {
    let entry: WalletManager.WalletEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.asset)
                        .font(.headline)
                    Spacer()
                    Text(formatDate(entry.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(entry.sourceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.amount)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(entry.action.capitalized)
                    .font(.caption2)
                    .foregroundColor(actionColor)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(NSLocalizedString("wallet_delete", comment: "Delete wallet entry context menu action"), systemImage: "trash")
            }
        }
    }

    private var actionColor: Color {
        switch entry.action.lowercased() {
        case "invest", "receive", "buy":
            return .green
        case "send", "sell", "spend":
            return .red
        default:
            return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        WalletView()
    }
}
