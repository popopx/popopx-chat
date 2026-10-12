//
//  ComposeFileView.swift
//  POPOPX (iOS)
//
//  Created by JRoberts on 04.05.2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import SwiftUI

// POPOPX layout constants for file attachment composer
private enum PXFileComposerMetrics {
    static let iconSize: CGFloat = 32
    static let iconLeadingPad: CGFloat = 6
    static let rowTrailingPad: CGFloat = 14
    static let rowHeight: CGFloat = 56
    static let hStackSpacing: CGFloat = 6
    static let verticalPad: CGFloat = 2
}

struct ComposeFileView: View {
    @EnvironmentObject var theme: AppTheme
    let fileName: String
    let cancelFile: (() -> Void)
    let cancelEnabled: Bool

    var body: some View {
        // File icon + name row with optional cancel button
        HStack(alignment: .center, spacing: PXFileComposerMetrics.hStackSpacing) {
            Image(systemName: "doc.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(theme.colors.onSurface)
                .frame(width: PXFileComposerMetrics.iconSize, height: PXFileComposerMetrics.iconSize)
                .padding(.leading, PXFileComposerMetrics.iconLeadingPad)
            Text(fileName)
                .lineLimit(1)
            Spacer()
            if cancelEnabled {
                Button { cancelFile() } label: {
                    Image(systemName: "multiply")
                }
            }
        }
        .padding(.trailing, PXFileComposerMetrics.rowTrailingPad)
        .padding(.vertical, PXFileComposerMetrics.verticalPad)
        .frame(height: PXFileComposerMetrics.rowHeight)
        .background(theme.appColors.sentMessage)
        .frame(maxWidth: .infinity)
        .popopxBranded()
    }
}

// MARK: - POPOPX
extension ComposeFileView {
    var pxComponentTag: String { "px-compose-file" }
}
