// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import BitchatMesh

struct PingResult: Equatable {
    let rtt: Double?
    let hops: Int?
    let timestamp: Date
}

struct NearbyPeersView: View {
    @ObservedObject var chatModel: ChatModel
    @State private var pingResults: [String: PingResult] = [:]

    var body: some View {
        let meshAccent: Color = darkThemeAccentColor()
        let meshAlert: Color = QuantumColors.error
        let showGlow = true

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(meshAccent)
                    .accessibilityHidden(true)
                    .shadow(color: showGlow ? meshAccent.opacity(0.6) : .clear, radius: 3)

                Text(NSLocalizedString("mesh_nearby_peers_header", comment: "Section header for nearby mesh peers list"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(meshAccent)

                Spacer()

                Text("\(chatModel.nearbyMeshPeers.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(meshAlert)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(meshAlert.opacity(0.15))
                            .overlay(Capsule().strokeBorder(meshAlert.opacity(0.5), lineWidth: 0.5))
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("mesh_nearby_peers_count", comment: "Accessibility label for nearby peers section"), chatModel.nearbyMeshPeers.count))

            if chatModel.nearbyMeshPeers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                    
                    Text(NSLocalizedString("mesh_no_peers_yet", comment: "Empty state message when no mesh peers found"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("mesh_enable_bluetooth_help", comment: "Help text for discovering mesh peers"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
            } else {
                ForEach(chatModel.nearbyMeshPeers) { peer in
                    PeerRow(peer: peer, pingResult: pingResults[peer.peerIDHex], chatModel: chatModel) {
                        performPing(peer)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(meshAccent.opacity(0.2), lineWidth: 0.5)
                )
        )
        .popopxBranded()
    }

    private func performPing(_ peer: PublicPeerSnapshot) {
        chatModel.meshBridge?.pingPeer(peer.peerIDHex) { rtt, hops in
            pingResults[peer.peerIDHex] = PingResult(rtt: rtt, hops: hops, timestamp: Date())
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                pingResults.removeValue(forKey: peer.peerIDHex)
            }
        }
    }
}

private struct PeerRow: View {
    let peer: PublicPeerSnapshot
    let pingResult: PingResult?
    let chatModel: ChatModel
    let onPing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(peer.isConnected ? darkThemeAccentColor() : .gray)
                    .frame(width: 8, height: 8)
                    .shadow(color: peer.isConnected ? darkThemeAccentColor().opacity(0.8) : .clear, radius: 3)
                    .accessibilityHidden(true)

                Text(peer.nickname)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                if pingResult == nil {
                    Button {
                        onPing()
                    } label: {
                        Image(systemName: "gauge")
                            .font(.caption)
                            .foregroundStyle(darkThemeAccentColor())
                            .accessibilityHidden(true)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: NSLocalizedString("mesh_ping_peer_accessibility", comment: "Ping button accessibility label"), peer.nickname))
                }
            }

            if let result = pingResult {
                HStack(spacing: 4) {
                    if let rtt = result.rtt {
                        Text(String(format: NSLocalizedString("mesh_ping_rtt_format", comment: "Round-trip time measurement in milliseconds"), Int(rtt)))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(darkThemeAccentColor())
                    } else {
                        Text(NSLocalizedString("mesh_ping_timeout", comment: "Ping timeout error message"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(QuantumColors.error)
                    }
                    if let hops = result.hops {
                        Text("\u{00b7}")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("^[\(hops) hop](inflect: true)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: pingResult?.rtt)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("mesh_peer_status_format", comment: "Accessibility label for peer connection status"), peer.nickname, peer.isConnected ? NSLocalizedString("mesh_connected_status", comment: "Connected status") : NSLocalizedString("mesh_disconnected_status", comment: "Disconnected status")))
    }
}
