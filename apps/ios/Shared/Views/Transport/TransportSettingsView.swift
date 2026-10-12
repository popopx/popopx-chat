// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import BitchatMesh

struct TransportSettingsView: View {
    @ObservedObject var chatModel: ChatModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $chatModel.meshTransportEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Bluetooth Mesh", comment: "Bluetooth Mesh transport toggle"))
                            .font(.subheadline.weight(.semibold))
                        Text(NSLocalizedString("Enable backup transport via BLE mesh", comment: "Bluetooth Mesh description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .tint(darkThemeAccentColor())
                .onChange(of: chatModel.meshTransportEnabled) {_,  newValue in
                    meshTransportEnabledGroupDefault.set(newValue)
                }

                Toggle(isOn: $chatModel.meshAutoSwitch) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Auto-Switch", comment: "Auto-Switch transport toggle"))
                            .font(.subheadline.weight(.semibold))
                        Text(NSLocalizedString("Automatically switch to mesh when internet is unavailable", comment: "Auto-Switch description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .tint(darkThemeAccentColor())
                .disabled(!chatModel.meshTransportEnabled)
                .onChange(of: chatModel.meshAutoSwitch) {_,  newValue in
                    meshAutoSwitchGroupDefault.set(newValue)
                }

                Toggle(isOn: $chatModel.meshGatewayEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Internet Bridge", comment: "Internet Bridge toggle"))
                            .font(.subheadline.weight(.semibold))
                        Text(NSLocalizedString("Share internet connection with BLE mesh via Nostr relays", comment: "Internet Bridge description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .tint(darkThemeAccentColor())
                .disabled(!chatModel.meshTransportEnabled)
                .onChange(of: chatModel.meshGatewayEnabled) {_,  newValue in
                    meshGatewayEnabledGroupDefault.set(newValue)
                    BitchatSharedRuntime.shared.enableGateway(newValue)
                    BitchatSharedRuntime.shared.enableBridge(newValue)
                    if newValue {
                        BitchatSharedRuntime.shared.connectNostrRelays()
                    } else {
                        BitchatSharedRuntime.shared.disconnectNostrRelays()
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(darkThemeAccentColor())
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("TRANSPORT MODE", comment: "Transport mode section header"))
                        .font(.caption.weight(.bold))
                }
            }

            Section {
                HStack {
                    Text(NSLocalizedString("Current Transport", comment: "Current transport label"))
                        .font(.footnote)
                    Spacer()
                    Text(chatModel.currentTransportID.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            chatModel.currentTransportID == "bluetooth"
                                ? neonGradientSecondary()
                                : darkThemeAccentColor()
                        )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("Current transport: %@", comment: "Current transport accessibility"), chatModel.currentTransportID))

                HStack {
                    Text(NSLocalizedString("Nearby Peers", comment: "Nearby peers label"))
                        .font(.footnote)
                    Spacer()
                    Text("\(chatModel.nearbyMeshPeers.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(darkThemeAccentColor())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("Nearby peers: %d", comment: "Nearby peers accessibility"), chatModel.nearbyMeshPeers.count))
            } header: {
                Text(NSLocalizedString("STATUS", comment: "Status section header"))
                    .font(.caption.weight(.bold))
            }

            if chatModel.meshTransportEnabled {
                Section {
                    Button {
                        if let key = chatModel.meshBridge?.myNoisePublicKeyHex {
                            UIPasteboard.general.setItems([["public.utf8-plain-text": key]], options: [.expirationDate: Date().addingTimeInterval(120), .localOnly: true])
                        }
                    } label: {
                        HStack {
                            Text(NSLocalizedString("Noise Key", comment: "Noise key label"))
                                .font(.footnote)
                            Spacer()
                            Text(chatModel.meshBridge?.myNoisePublicKeyHex ?? "N/A")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(neonGradientSecondary())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("Copy noise key", comment: "Copy noise key accessibility"))
                    .accessibilityHint(NSLocalizedString("Copies the key to the clipboard", comment: "Copy noise key hint"))
                } header: {
                    Text(NSLocalizedString("IDENTITY", comment: "Identity section header"))
                        .font(.caption.weight(.bold))
                }

                Section {
                    NavigationLink {
                        MeshTopologyView(chatModel: chatModel)
                    } label: {
                        HStack {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .foregroundStyle(darkThemeAccentColor())
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("Mesh Topology", comment: "Mesh topology navigation"))
                                .font(.footnote)
                        }
                    }

                    NavigationLink {
                        MeshBoardView(chatModel: chatModel)
                    } label: {
                        HStack {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(neonGradientSecondary())
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("Board", comment: "Board navigation"))
                                .font(.footnote)
                        }
                    }

                    NavigationLink {
                        MeshGroupsView(chatModel: chatModel)
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(darkThemeAccentColor())
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("Mesh Groups", comment: "Mesh groups navigation"))
                                .font(.footnote)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("FEATURES", comment: "Features section header"))
                        .font(.caption.weight(.bold))
                }

                Section {
                    NearbyPeersView(chatModel: chatModel)
                } header: {
                    Text(NSLocalizedString("DISCOVERED PEERS", comment: "Discovered peers section header"))
                        .font(.caption.weight(.bold))
                }
            }

            if !chatModel.meshInboxMessages.isEmpty {
                Section {
                    ForEach(chatModel.meshInboxMessages.prefix(20)) { msg in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(msg.senderID.prefix(8))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(neonGradientSecondary())
                                Spacer()
                                Text(msg.receivedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(msg.text)
                                .font(.caption)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(format: NSLocalizedString("Message from %@, %@", comment: "Mesh inbox message accessibility"), String(msg.senderID.prefix(8)), msg.text))
                    }
                } header: {
                    HStack {
                        Text(NSLocalizedString("MESH INBOX", comment: "Mesh inbox section header"))
                            .font(.caption.weight(.bold))
                        Spacer()
                        Text("\(chatModel.meshInboxMessages.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(darkThemeAccentColor())
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("Mesh Settings", comment: "Mesh settings navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(NSLocalizedString("Bluetooth Permission Required", comment: "Bluetooth permission alert title"), isPresented: $chatModel.bluetoothPermissionDenied) {
            Button(NSLocalizedString("Open Settings", comment: "Open settings button")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Please enable Bluetooth in Settings to use mesh transport.", comment: "Bluetooth permission alert message"))
        }
        .popopxBranded()
    }
}
