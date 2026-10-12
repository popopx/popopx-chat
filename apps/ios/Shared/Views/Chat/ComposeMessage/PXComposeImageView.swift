//
//  ComposeImageView.swift
//  POPOPX
//
//  Created by JRoberts on 11/04/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ComposeImageView: View {
    @EnvironmentObject var theme: AppTheme
    let images: [String]
    let cancelImage: (() -> Void)
    let cancelEnabled: Bool

    // POPOPX layout tuning
    private static let pxRowSpacing: CGFloat = 8
    private static let pxImgMaxW: CGFloat = 82
    private static let pxImgMinH: CGFloat = 42
    private static let pxImgMaxH: CGFloat = 62
    private static let pxTrailingPad: CGFloat = 14
    private static let pxMinRowH: CGFloat = 56

    var body: some View {
        HStack(alignment: .center, spacing: Self.pxRowSpacing) {
            let decoded: [UIImage] = images.compactMap { image in
                imageFromBase64(image)
            }
            if decoded.isEmpty {
                imageLoadingPlaceholder
            } else {
                imageStrip(decoded)
            }
            Spacer()
            if cancelEnabled {
                Button { cancelImage() } label: {
                    Image(systemName: "multiply")
                }
            }
        }
        .background(theme.appColors.sentMessage)
        .padding(.vertical, 1)
        .padding(.trailing, Self.pxTrailingPad)
        .frame(minHeight: Self.pxMinRowH)
        .frame(maxWidth: .infinity)
        .popopxBranded()
    }

    /// Shown while images are still being decoded from base64
    private var imageLoadingPlaceholder: some View {
        ProgressView()
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 60, alignment: .leading)
    }

    /// Horizontally scrollable strip of attached images
    private func imageStrip(_ imgs: [UIImage]) -> some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(Array(imgs.enumerated()), id: \.offset) { index, img in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: Self.pxImgMaxW, minHeight: Self.pxImgMinH, maxHeight: Self.pxImgMaxH)
                }
            }
        }
    }
}
