// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct ExtractionCardView: View {
    let extraction: Extraction
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: extraction.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colorForType(extraction.type))
                    .frame(width: 28, height: 28)
                    .background(colorForType(extraction.type).opacity(0.15))
                    .clipShape(Circle())
                    .accessibilityLabel(extraction.type.displayName)

                Text(extraction.type.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(extraction.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Delete"))
                }
            }

            ForEach(extraction.data.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top, spacing: 6) {
                    Text(displayKey(key))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }

            if !extraction.sourceText.isEmpty {
                Text(extraction.sourceText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(colorForType(extraction.type).opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func colorForType(_ type: ExtractionType) -> Color {
        switch type {
        case .calendar: return .blue
        case .expense: return .orange
        case .todo: return .green
        case .note: return .gray
        case .asset: return .purple
        case .contact: return .teal
        }
    }

    private func displayKey(_ key: String) -> String {
        let localized: [String: String] = [
            "event": NSLocalizedString("needle.field.event", comment: ""),
            "time": NSLocalizedString("needle.field.time", comment: ""),
            "location": NSLocalizedString("needle.field.location", comment: ""),
            "amount": NSLocalizedString("needle.field.amount", comment: ""),
            "category": NSLocalizedString("needle.field.category", comment: ""),
            "currency": NSLocalizedString("needle.field.currency", comment: ""),
            "payee": NSLocalizedString("needle.field.payee", comment: ""),
            "task": NSLocalizedString("needle.field.task", comment: ""),
            "deadline": NSLocalizedString("needle.field.deadline", comment: ""),
            "asset": NSLocalizedString("needle.field.asset", comment: ""),
            "action": NSLocalizedString("needle.field.action", comment: ""),
            "name": NSLocalizedString("needle.field.name", comment: ""),
            "content": NSLocalizedString("needle.field.content", comment: ""),
        ]
        return localized[key] ?? key
    }
}
