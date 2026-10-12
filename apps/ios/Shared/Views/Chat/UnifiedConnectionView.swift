// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import CodeScanner

struct UnifiedConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: AppTheme
    @ObservedObject private var handler = UnifiedConnectionHandler.shared

    @State private var myQRString: String?
    @State private var showScanner = false
    @State private var scanError: String?
    @State private var connectedPeer: UnifiedPeerInfo?

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            Divider()

            actionButtons

            if let peer = connectedPeer {
                connectedPeerCard(peer)
            }

            peerList

            Spacer()
        }
        .padding()
        .navigationTitle(NSLocalizedString("add_contact_nav_title", comment: "Add Contact navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ThemedBackground())
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
        .task {
            await handler.initialize()
            myQRString = await handler.generateMyQR()
        }
        .alert(LocalizedStringKey(NSLocalizedString("connection_error_title", comment: "Connection error alert title")), isPresented: Binding(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Button(NSLocalizedString("OK", comment: "")) { scanError = nil }
        } message: {
            Text(scanError ?? "")
        }
        .popopxBranded()
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.largeTitle)
                .foregroundColor(theme.colors.primary)

            Text(NSLocalizedString("Connect via POPOPX", comment: "unified connection title"))
                .font(.title2.bold())

            Text(NSLocalizedString("Scan a unified QR to connect via both online and Bluetooth mesh with a single scan.", comment: "unified QR explanation"))
                .font(.subheadline)
                .foregroundColor(theme.colors.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                showScanner = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title)
                    Text(NSLocalizedString("Scan QR", comment: "button to scan a QR code"))
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.colors.primary)
                )
                .foregroundColor(.white)
            }

            Button {
                showMyQRSheet()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.title)
                    Text(NSLocalizedString("Share My QR", comment: "button to share my QR code"))
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.colors.primary, lineWidth: 1.5)
                )
                .foregroundColor(theme.colors.primary)
            }
        }
    }

    private func connectedPeerCard(_ peer: UnifiedPeerInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(theme.colors.primary)
                Text(peer.displayName ?? "Unknown")
                    .font(.headline)
                Spacer()
                if let status = handler.connectionStatus[peer.identityPubKeyHex] {
                    statusBadge(status)
                }
            }

            HStack {
                ForEach(peer.availableTransports, id: \.self) { transport in
                    transportIcon(transport)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.colors.primary.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func statusBadge(_ status: UnifiedConnectionHandler.ConnectionStatus) -> some View {
        let color: Color = switch status {
        case .bothActive: QuantumColors.success
        case .online: QuantumColors.accent
        case .nearby: QuantumColors.warning
        case .connecting: QuantumColors.warning
        case .offline: QuantumColors.textTertiary
        }

        return Text(localizedConnectionStatus(status))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }

    private func transportIcon(_ transport: String) -> some View {
        let (icon, label): (String, String) = switch transport {
        case "smp": ("globe", NSLocalizedString("connection_transport_online", comment: ""))
        case "ble": ("antenna.radiowaves.left.and.right", NSLocalizedString("connection_transport_bluetooth", comment: ""))
        case "multipeer": ("wifi", NSLocalizedString("connection_transport_wifi", comment: ""))
        case "nostr": ("satellite", NSLocalizedString("connection_transport_nostr", comment: ""))
        default: ("questionmark.circle", transport)
        }

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(theme.colors.surface)
        )
        .overlay(
            Capsule().strokeBorder(theme.colors.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func localizedConnectionStatus(_ status: UnifiedConnectionHandler.ConnectionStatus) -> String {
        switch status {
        case .bothActive: return NSLocalizedString("connection_status_both_active", comment: "")
        case .online: return NSLocalizedString("connection_status_online", comment: "")
        case .nearby: return NSLocalizedString("connection_status_nearby", comment: "")
        case .connecting: return NSLocalizedString("connection_status_connecting", comment: "")
        case .offline: return NSLocalizedString("connection_status_offline", comment: "")
        }
    }

    private var peerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !handler.knownPeers.isEmpty {
                Text(NSLocalizedString("Known Peers", comment: "title for list of known peers"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.colors.secondary)

                ForEach(Array(handler.knownPeers.values), id: \.identityPubKeyHex) { peer in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(theme.colors.primary)
                        Text(peer.displayName ?? String(peer.identityPubKeyHex.prefix(8)))
                            .font(.body)
                        Spacer()
                        if let status = handler.connectionStatus[peer.identityPubKeyHex] {
                            statusBadge(status)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var scannerSheet: some View {
        VStack {
            CodeScannerView(codeTypes: [.qr], scanMode: .oncePerCode) { result in
                switch result {
                case .success(let scanResult):
                    Task {
                        if let peer = await handler.handleScannedQR(scanResult.string) {
                            await MainActor.run {
                                connectedPeer = peer
                                showScanner = false
                            }
                        } else {
                            await MainActor.run {
                                scanError = NSLocalizedString("Invalid POPOPX QR code", comment: "error message when scanned QR is not a valid POPOPX code")
                                showScanner = false
                            }
                        }
                    }
                case .failure:
                    showScanner = false
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(10)
            .padding()

            Text(NSLocalizedString("Scan a POPOPX unified QR code", comment: "instruction to scan unified QR code"))
                .font(.subheadline)
                .foregroundColor(theme.colors.secondary)
                .padding(.bottom)
        }
    }

    private func showMyQRSheet() {
        // Use a simple share sheet with the QR code
        guard let qrString = myQRString else { return }
        UIPasteboard.general.setItems([["public.utf8-plain-text": qrString]], options: [.expirationDate: Date().addingTimeInterval(120), .localOnly: true])
    }
}

#Preview {
    NavigationStack {
        UnifiedConnectionView()
    }
}
