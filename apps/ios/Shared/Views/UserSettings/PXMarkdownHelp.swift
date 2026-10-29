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
            mdFormat("*bold*", { var a = AttributedString(NSLocalizedString("markdown_bold", comment: "")); a.font = .body.bold(); return a }())
            mdFormat("_italic_", { var a = AttributedString(NSLocalizedString("markdown_italic", comment: "")); a.font = .body.italic(); return a }())
            mdFormat("~strike~", { var a = AttributedString(NSLocalizedString("markdown_strike", comment: "")); a.strikethroughStyle = .single; return a }())
            mdFormat("`a + b`", { var a = AttributedString("`a + b`"); a.font = .body; return a }())
            mdFormat("!1 colored!", {
                var r = AttributedString(NSLocalizedString("markdown_colored", comment: ""))
                r.foregroundColor = QuantumColors.error
                r += AttributedString(" (")
                for (s, c) in [("1", QuantumColors.error), ("2", QuantumColors.success), ("3", Color.blue), ("4", Color.yellow), ("5", Color.cyan)] {
                    var part = AttributedString(s)
                    part.foregroundColor = c
                    r += part
                    r += AttributedString(", ")
                }
                var six = AttributedString("6")
                six.foregroundColor = .purple
                r += six
                r += AttributedString(")")
                return r
            }())
            (
                mdFormat("#secret#", {
                    var a = AttributedString("\(NSLocalizedString("markdown_secret", comment: ""))\(NSLocalizedString("markdown_can_be_copied", comment: "Hint that secret text can be copied"))")
                    a.foregroundColor = .clear
                    let pxNsAttr = NSMutableAttributedString(string: String(a.characters))
                    pxNsAttr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: pxNsAttr.length))
                    pxNsAttr.addAttribute(.underlineColor, value: UIColor(theme.colors.onBackground), range: NSRange(location: 0, length: pxNsAttr.length))
                    return AttributedString(pxNsAttr)
                }())
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

private func mdFormat(_ format: LocalizedStringKey, _ example: AttributedString) -> some View {
    HStack {
        Text(format).frame(width: pxFormatLabelWidth, alignment: .leading)
        Text(example)
    }
}

struct MarkdownHelp_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownHelp()
    }
}
