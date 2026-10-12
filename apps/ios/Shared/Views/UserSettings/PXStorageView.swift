//
//  PXStorageView.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 13.01.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Storage Layout

// POPOPX: extracted layout and styling constants for storage view
private enum PXStorageLayout {
    /// Padding around the directory sections
    static let sectionPadding: CGFloat = 20
    /// Spacing between directory entries
    static let entrySpacing: CGFloat = 4
    /// Font size for section headers in light mode
    static let headerFontSize: CGFloat = 18
}

// POPOPX: styling helpers for storage view appearance
private enum PXStorageStyling {
    /// Returns the appropriate section header font based on theme
    static func sectionHeaderFont() -> Font {
        isInDarkTheme() ? QuantumFonts.sectionHeader : .headline
    }

    /// Returns the appropriate section header color based on theme
    static func sectionHeaderColor() -> Color {
        isInDarkTheme() ? darkThemeAccentColor() : .primary
    }
}

struct StorageView: View {
    @State var appGroupFiles: [String: Int64] = [:]
    @State var documentsFiles: [String: Int64] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PXStorageLayout.entrySpacing) {
                pxDirectorySection(title: "App group:", contents: appGroupFiles)
                if !documentsFiles.isEmpty {
                    pxDirectorySection(title: "Documents:", contents: documentsFiles)
                }
            }
        }
        .padding(PXStorageLayout.sectionPadding)
        .modifier(ThemedBackground(grouped: true))
        .onAppear {
            pxLoadDirectoryContents()
        }
        .popopxBranded()
    }

    // POPOPX: trigger file traversal for both container directories
    private func pxLoadDirectoryContents() {
        appGroupFiles = pxTraverseDirectory(in: getGroupContainerDirectory())
        documentsFiles = pxTraverseDirectory(in: getDocumentsDirectory())
    }

    // POPOPX: render a single directory section with header and file entries
    @ViewBuilder
    private func pxDirectorySection(title pxName: LocalizedStringKey, contents pxContents: [String: Int64]) -> some View {
        Text(pxName)
            .font(PXStorageStyling.sectionHeaderFont())
            .foregroundColor(PXStorageStyling.sectionHeaderColor())
        ForEach(Array(pxContents), id: \.key) { (pxKey, pxValue) in
            Text(pxKey).bold() + Text(verbatim: "   ") + Text(ByteCountFormatter.string(fromByteCount: pxValue, countStyle: .binary))
        }
    }

    // POPOPX: traverse a directory tree and aggregate file sizes by root folder
    private func pxTraverseDirectory(in pxDir: URL) -> [String: Int64] {
        logger.info("PX: traversing storage directory")
        var pxAccumulator: [String: Int64] = [:]
        let pxFileManager = FileManager.default
        do {
            if let pxEnumerator = pxFileManager.enumerator(at: pxDir, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .fileAllocatedSizeKey]) {
                for case let pxURL as URL in pxEnumerator {
                    let pxAttrs = try pxURL.resourceValues(forKeys: [/*.isDirectoryKey, .fileSizeKey,*/ .fileAllocatedSizeKey])
                    let pxPathParts = pxURL.absoluteString.replacingOccurrences(of: pxDir.absoluteString, with: "").split(separator: "/")
                    guard let pxFirstPart = pxPathParts.first else { continue }
                    let pxRootKey = String(pxFirstPart)
                    pxAccumulator[pxRootKey] = (pxAccumulator[pxRootKey] ?? 0) + Int64(pxAttrs.fileAllocatedSize ?? 0)
                }
            }
        } catch {
            logger.error("Error traversing files: \(error)")
        }
        return pxAccumulator
    }
}

// MARK: - POPOPX
extension StorageView {
    var pxComponentTag: String { "PX_STORAGE_VIEW" }
}
