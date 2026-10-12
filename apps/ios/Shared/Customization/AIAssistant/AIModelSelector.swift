// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/ai-assistant
import SwiftUI

struct AIModelSelector: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var selectedModel: AIModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(AIModel.allCases) { model in
                        ModelCard(model: model, isSelected: model == selectedModel) {
                            selectedModel = model
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(NSLocalizedString("Select Model", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Done", comment: "")) { dismiss() }
                        .foregroundColor(QuantumColors.accent)
                }
            }
        }
        .popopxBranded()
    }
}

private struct ModelCard: View {
    let model: AIModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.rawValue)
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(QuantumColors.accent)
                    }
                }

                HStack(spacing: 16) {
                    Label {
                        Text(model.provider)
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                    } icon: {
                        Image(systemName: "server.rack")
                            .font(.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                    }

                    Label {
                        Text(model.costPerToken)
                            .font(QuantumFonts.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                    } icon: {
                        Image(systemName: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(QuantumColors.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected
                        ? QuantumColors.accent
                        : QuantumColors.surfaceElevated,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
