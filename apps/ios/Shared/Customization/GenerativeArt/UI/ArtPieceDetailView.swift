// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct ArtPieceDetailView: View {
    let piece: ArtPiece
    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var showExportSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ProgressView()
                        .tint(.white)
                }

                // Metadata overlay
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(piece.generatorType)
                            .font(.caption)
                            .foregroundStyle(.purple)

                        Text(String(format: NSLocalizedString("art_seed_value", comment: "Art piece seed number display"), piece.seed))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(piece.sourceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text(piece.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
            .navigationTitle(NSLocalizedString("art_piece_title", comment: "Navigation title for art piece detail view"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("art_close", comment: "Close button for art piece detail")) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(NSLocalizedString("art_set_background", comment: "Set art as chat background action")) {
                            CyberThemeManager.shared.setActiveArtPiece(piece)
                            dismiss()
                        }

                        Button(NSLocalizedString("art_export_photos", comment: "Export art to Photos action")) {
                            exportToPhotos()
                        }

                        Button(NSLocalizedString("art_delete", comment: "Delete art piece action"), role: .destructive) {
                            deletePiece()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert(NSLocalizedString("art_exported_photos", comment: "Alert title confirming art exported to Photos"), isPresented: $showExportSuccess) {
                Button(NSLocalizedString("art_ok", comment: "OK button to dismiss alert")) {}
            }
            .onAppear {
                loadFullImage()
            }
        }
        .popopxBranded()
    }

    private func loadFullImage() {
        Task {
            do {
                fullImage = try await ArtVault.shared.load(piece)
            } catch {
                // Silent failure
            }
        }
    }

    private func exportToPhotos() {
        Task {
            do {
                try await ArtVault.shared.exportToPhotos(piece)
                showExportSuccess = true
            } catch {
                // Silent failure
            }
        }
    }

    private func deletePiece() {
        do {
            try ArtVault.shared.delete(piece)
            dismiss()
        } catch {
            // Silent failure
        }
    }
}
