// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct MeshTopologyView: View {
    @ObservedObject var chatModel: ChatModel
    @State private var nodes: [String] = []
    @State private var edges: [(a: String, b: String)] = []
    @State private var localPeerID: String = ""
    @State private var lastRefresh: Date?

    var body: some View {
        content
            .navigationTitle(NSLocalizedString("Mesh Topology", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshTopology()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(darkThemeAccentColor())
                    }
                    .accessibilityLabel(NSLocalizedString("Refresh topology", comment: ""))
                }
            }
            .onAppear { refreshTopology() }
        .popopxBranded()
    }

    @ViewBuilder
    private var content: some View {
        if nodes.isEmpty {
            emptyState
        } else {
            topologyList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(NSLocalizedString("mesh_no_topology", comment: "Empty state when no topology data is available"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let lastRefresh {
                Text(String(format: NSLocalizedString("mesh_last_updated", comment: "Timestamp of last topology refresh"), lastRefresh.formatted(date: .omitted, time: .standard)))
                    .font(.caption2)
                    
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topologyList: some View {
        List {
            Section {
                HStack {
                    Text(NSLocalizedString("mesh_local_peer", comment: "Label for local peer in topology overview"))
                        .font(.footnote)
                    Spacer()
                    Text(localPeerID.count > 16 ? localPeerID.prefix(16) + "..." : localPeerID)
                        .font(.caption2)
                        
                        .fontWeight(.bold)
                        .foregroundStyle(darkThemeAccentColor())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("Local peer, %@", comment: "Topology local peer accessibility label"), localPeerID))

                HStack {
                    Text(NSLocalizedString("mesh_nodes", comment: "Label for node count in topology overview"))
                        .font(.footnote)
                    Spacer()
                    Text("\(nodes.count)")
                        .font(.caption)
                        
                        .fontWeight(.bold)
                        .foregroundStyle(darkThemeAccentColor())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("Nodes, %d", comment: "Topology nodes accessibility label"), nodes.count))

                HStack {
                    Text(NSLocalizedString("mesh_edges", comment: "Label for edge count in topology overview"))
                        .font(.footnote)
                    Spacer()
                    Text("\(edges.count)")
                        .font(.caption)
                        
                        .fontWeight(.bold)
                        .foregroundStyle(darkThemeAccentColor())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("Edges, %d", comment: "Topology edges accessibility label"), edges.count))
            } header: {
                Text(NSLocalizedString("mesh_overview_header", comment: "Section header for topology overview"))
                    .font(.caption)
                    
                    .fontWeight(.bold)
            }

            Section {
                ForEach(nodes, id: \.self) { nodeID in
                    HStack {
                        Circle()
                            .fill(nodeID == localPeerID
                                ? darkThemeAccentColor()
                                : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(nodeID.count > 16 ? nodeID.prefix(16) + "..." : nodeID)
                            .font(.caption2)
                            
                            .fontWeight(nodeID == localPeerID ? .bold : .regular)
                            .foregroundStyle(nodeID == localPeerID
                                ? darkThemeAccentColor()
                                : .primary)
                    }
                }
            } header: {
                Text(NSLocalizedString("mesh_nodes_header", comment: "Section header for nodes list"))
                    .font(.caption)
                    
                    .fontWeight(.bold)
            }

            if !edges.isEmpty {
                Section {
                    ForEach(edges, id: \.a) { edge in
                        HStack {
                            Text(edge.a.count > 10 ? edge.a.prefix(10) + "..." : edge.a)
                                .font(.caption2)
                                
                                .fontWeight(.bold)
                                .foregroundStyle(neonGradientSecondary())
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(edge.b.count > 10 ? edge.b.prefix(10) + "..." : edge.b)
                                .font(.caption2)
                                
                                .fontWeight(.bold)
                                .foregroundStyle(neonGradientSecondary())
                        }
                    }
                } header: {
                    Text(NSLocalizedString("mesh_edges_header", comment: "Section header for edges list"))
                        .font(.caption)
                        
                        .fontWeight(.bold)
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func refreshTopology() {
        guard let json = chatModel.meshBridge?.meshTopologyJSON(),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            nodes = []
            edges = []
            localPeerID = ""
            return
        }

        localPeerID = dict["localPeerID"] as? String ?? ""
        nodes = (dict["nodes"] as? [String]) ?? []

        if let edgeDicts = dict["edges"] as? [[String: String]] {
            edges = edgeDicts.compactMap { e in
                guard let a = e["a"], let b = e["b"] else { return nil }
                return (a: a, b: b)
            }
        }

        lastRefresh = Date()
    }
}
