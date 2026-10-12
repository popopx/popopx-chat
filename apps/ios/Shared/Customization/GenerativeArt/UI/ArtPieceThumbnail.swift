// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct ArtPieceThumbnail: View {
    let piece: ArtPiece
    @State private var thumbnailImage: UIImage?

    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                ProgressView()
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.purple.opacity(0.3), radius: 4)
        .onAppear {
            loadThumbnail()
        }
        .popopxBranded()
    }

    private func loadThumbnail() {
        Task {
            do {
                let image = try await ArtVault.shared.load(piece)
                // Create thumbnail
                let size = CGSize(width: 100, height: 100)
                let renderer = UIGraphicsImageRenderer(size: size)
                thumbnailImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            } catch {
                // Silent failure
            }
        }
    }
}
