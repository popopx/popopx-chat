//
//  MarkdownHelp.swift
//  POPOPX
//
//  Created by Evgeny on 24/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

struct MarkdownHelp: View {
    @EnvironmentObject var theme: AppTheme

    // MARK: - POPOPX extracted constants
    private let pxContentSpacing: CGFloat = 8
    private let pxIntroBottomPadding: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: pxContentSpacing) {
            Text(NSLocalizedString("settings_markdown_usage", comment: "Markdown formatting instructions header"))
                .font(isInDarkTheme() ? .subheadline : .body)
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
                .padding(.bottom, pxIntroBottomPadding)
            mdFormat("*bold*", Text(NSLocalizedString("markdown_bold", comment: "")).bold())
            mdFormat("_italic_", Text(NSLocalizedString("markdown_italic", comment: "")).italic())
            mdFormat("~strike~", Text(NSLocalizedString("markdown_strike", comment: "")).strikethrough())
            mdFormat("`a + b`", Text("`a + b`").font(.body))
            mdFormat("!1 colored!", Text(NSLocalizedString("markdown_colored", comment: "")).foregroundColor(QuantumColors.error) + Text(verbatim: " (") + color("1", QuantumColors.error) + color("2", QuantumColors.success) + color("3", .blue) + color("4", .yellow) + color("5", .cyan) + Text("6").foregroundColor(.purple) + Text(verbatim: ")"))
            (
                mdFormat("#secret#", Text(NSLocalizedString("markdown_secret", comment: ""))
                    .foregroundColor(.clear)
                    .underline(color: theme.colors.onBackground) + Text(NSLocalizedString("markdown_can_be_copied", comment: "Hint that secret text can be copied")))
            )
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ThemedBackground(grouped: true))
        .popopxBranded()
    }
}

// MARK: - POPOPX
extension MarkdownHelp {
    /// Unique POPOPX component tag for analytics and diffing
    var pxComponentTag: String { "PX_MARKDOWN_HELP" }
}

private let pxFormatLabelWidth: CGFloat = 120

private func mdFormat(_ format: LocalizedStringKey, _ example: Text) -> some View {
    HStack {
        Text(format).frame(width: pxFormatLabelWidth, alignment: .leading)
        example
    }
}

private func color(_ s: String, _ c: Color) -> Text {
    Text(s).foregroundColor(c) + Text(verbatim: ", ")
}

struct MarkdownHelp_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownHelp()
    }
}
