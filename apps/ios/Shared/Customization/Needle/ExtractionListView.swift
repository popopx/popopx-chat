// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct ExtractionListView: View {
    @State private var extractions: [Extraction] = []
    @State private var selectedType: ExtractionType? = nil
    @State private var isLoading = true

    var chatId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typeFilterBar

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if extractions.isEmpty {
                    emptyState
                } else {
                    extractionList
                }
            }
            .navigationTitle(NSLocalizedString("needle.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !extractions.isEmpty {
                        Menu {
                            Button {
                                exportAsJSON()
                            } label: {
                                Label(NSLocalizedString("export_json_button", comment: "Export JSON button label"), systemImage: "doc.text")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .onAppear { loadExtractions() }
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: NSLocalizedString("needle.filter.all", comment: ""),
                    icon: "square.grid.2x2",
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                    loadExtractions()
                }

                ForEach(ExtractionType.allCases, id: \.self) { type in
                    FilterChip(
                        label: type.displayName,
                        icon: type.icon,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                        loadExtractions()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var extractionList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(extractions, id: \.id) { extraction in
                    ExtractionCardView(extraction: extraction) {
                        deleteExtraction(extraction)
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedType?.icon ?? "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(NSLocalizedString("needle.empty", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(NSLocalizedString("needle.empty.hint", comment: ""))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadExtractions() {
        isLoading = true
        DispatchQueue.main.async {
            if let chatId {
                extractions = LocalExtractionStore.shared.fetchByChatId(chatId)
            } else if let type = selectedType {
                extractions = LocalExtractionStore.shared.fetchByType(type)
            } else {
                extractions = LocalExtractionStore.shared.fetchAll()
            }
            isLoading = false
        }
    }

    private func deleteExtraction(_ extraction: Extraction) {
        LocalExtractionStore.shared.delete(id: extraction.id)
        extractions.removeAll { $0.id == extraction.id }
    }

    private func exportAsJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(extractions),
           let json = String(data: data, encoding: .utf8) {
            let uniqueName = "needle_extractions_\(UUID().uuidString).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName)
            try? json.write(to: tempURL, atomically: true, encoding: .utf8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    private var chipForeground: Color {
        isSelected ? .white : Color(200, 184, 232, a: 255)
    }

    private var chipBackground: Color {
        isSelected ? Color(110, 37, 196, a: 255) : Color(30, 20, 51, a: 255)
    }

    private var chipBorder: Color {
        isSelected ? Color(155, 109, 255, a: 255) : Color(110, 37, 196, a: 102)
    }

    var body: some View {
        Button(action: action) {
            chipContent
        }
        .buttonStyle(.plain)
    }

    private var chipContent: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(chipForeground)
        .background(Capsule().fill(chipBackground))
        .overlay(Capsule().strokeBorder(chipBorder, lineWidth: 1))
    }
}
