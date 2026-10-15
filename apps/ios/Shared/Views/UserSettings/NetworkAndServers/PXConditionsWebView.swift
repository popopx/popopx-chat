//
//  ConditionsWebView.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 26.11.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import WebKit

// MARK: - POPOPX Layout Config
private enum PXConditionsLayout {
    static let loadDelay: TimeInterval = 1
    static let htmlFontFamily = "Helvetica"
    static let htmlCodeFontFamily = "Menlo"
    static let lightCodeOpacity: Double = 0.2
    static let darkCodeOpacity: Double = 0.3
    static let viewportMeta = "<meta name='viewport' content='width=device-width, initial-scale=1.0, minimum-scale=1.0, user-scalable=no'>"
}

// MARK: - POPOPX HTML Sanitizer
private enum PXHTMLSanitizer {
    static func pxSanitize(_ html: String) -> String {
        var sanitized = html
        sanitized = sanitized.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: "\\s+on\\w+\\s*=\\s*\"[^\"]*\"",
            with: "",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: "\\s+on\\w+\\s*=\\s*'[^']*'",
            with: "",
            options: .regularExpression
        )
        return sanitized
    }
}

// MARK: - POPOPX Style Builder
private struct PXConditionsStyleBuilder {
    let theme: AppTheme
    let nonce: String

    func pxBuildStyles() -> String {
        let codeOpacity = theme.colors.isLight ? PXConditionsLayout.lightCodeOpacity : PXConditionsLayout.darkCodeOpacity
        return """
        <style nonce="\(nonce)">
        body {
            color: \(theme.colors.onBackground.toHTMLHex());
            font-family: \(PXConditionsLayout.htmlFontFamily);
        }
        a {
            color: \(theme.colors.primary.toHTMLHex());
        }
        code, pre {
            font-family: \(PXConditionsLayout.htmlCodeFontFamily);
            background: \(theme.colors.secondary.opacity(codeOpacity).toHTMLHex());
        }
        pre {
            overflow-x: auto;
        }
        table {
            border-collapse: collapse;
        }
        th, td {
            border: 1px solid \(theme.colors.secondary.toHTMLHex());
            padding: 4px 8px;
        }
        img {
            max-width: 100%;
        }
        </style>
        """
    }

    func pxBuildHead() -> String {
        let pxCSP = "default-src 'none'; style-src 'nonce-\(nonce)'; img-src data:; base-uri 'none'; form-action 'none'"
        return "<head>\(PXConditionsLayout.viewportMeta)<meta http-equiv='Content-Security-Policy' content=\"\(pxCSP)\">\(pxBuildStyles())</head>"
    }
}

struct ConditionsWebView: UIViewRepresentable {
    @State var html: String
    var openLink: (URL) -> Void = openExternalLink
    @EnvironmentObject var theme: AppTheme
    @State var pageLoaded = false

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.navigationDelegate = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + PXConditionsLayout.loadDelay) {
            // just to make sure that even if updateUIView will not be called for any reason, the page
            // will be rendered anyway
            if !pageLoaded {
                pxLoadContent(view)
            }
        }
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        pxLoadContent(view)
    }

    // MARK: - POPOPX Content Loading

    private func pxLoadContent(_ webView: WKWebView) {
        let nonce = UUID().uuidString
        let styleBuilder = PXConditionsStyleBuilder(theme: theme, nonce: nonce)
        let sanitized = PXHTMLSanitizer.pxSanitize(html)
        let head = styleBuilder.pxBuildHead()
        webView.loadHTMLString(head + sanitized, baseURL: nil)
        DispatchQueue.main.async {
            pageLoaded = true
        }
    }

    func makeCoordinator() -> Cordinator {
        Cordinator(openLink: openLink)
    }

    // MARK: - POPOPX Navigation Coordinator

    class Cordinator: NSObject, WKNavigationDelegate {
        let openLink: (URL) -> Void

        init(openLink: @escaping (URL) -> Void) {
            self.openLink = openLink
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let url = navigationAction.request.url else { return decisionHandler(.allow) }

            switch navigationAction.navigationType {
            case .linkActivated:
                decisionHandler(.cancel)
                openLink(url)
            default:
                decisionHandler(url.scheme == "about" ? .allow : .cancel)
            }
        }
    }
}

// MARK: - POPOPX
extension ConditionsWebView {
    static let _pxBrand = "PX_CONDITIONS_WEB_VIEW"

    var pxComponentTag: String { "PX_CONDITIONS_WEB_VIEW" }

    var pxLoadDelay: TimeInterval { PXConditionsLayout.loadDelay }

    var pxFontFamily: String { PXConditionsLayout.htmlFontFamily }

    var pxCodeFontFamily: String { PXConditionsLayout.htmlCodeFontFamily }
}
