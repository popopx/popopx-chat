// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct GenerativeArtGalleryView: View {
    @ObservedObject private var vault = ArtVault.shared
    @State private var selectedPiece: ArtPiece?
    @State private var showDetail = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if vault.pieces.isEmpty {
                    emptyStateView
                } else {
                    galleryView
                }
            }
            .navigationTitle(NSLocalizedString("art_gallery_title", comment: "Navigation title for art gallery"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDetail) {
                if let piece = selectedPiece {
                    ArtPieceDetailView(piece: piece)
                }
            }
        }
        .popopxBranded()
    }

    private var galleryView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(vault.pieces) { piece in
                    ArtPieceThumbnail(piece: piece)
                        .onTapGesture {
                            selectedPiece = piece
                            showDetail = true
                        }
                }
            }
            .padding(8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.purple.opacity(0.5))

            Text(NSLocalizedString("art_empty_title", comment: "Title for empty art gallery state"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("art_empty_description", comment: "Description for empty art gallery state"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("art_try_keywords", comment: "Prompt to try art generation keywords"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ForEach(["赛博遁入", "灵感泵发", "虚空模式", "几何冥想", "细胞觉醒"], id: \.self) { keyword in
                    Text("• \(keyword)")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.top, 10)
        }
        .padding()
    }
}
