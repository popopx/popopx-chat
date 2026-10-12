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

    func pxBuildStyles() -> String {
        let codeOpacity = theme.colors.isLight ? PXConditionsLayout.lightCodeOpacity : PXConditionsLayout.darkCodeOpacity
        return """
        <style>
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
        </style>
        """
    }

    func pxBuildHead() -> String {
        "<head>\(PXConditionsLayout.viewportMeta)<meta http-equiv='Content-Security-Policy' content=\"\(pxCSP)\">\(pxBuildStyles())</head>"
    }

    var pxCSP: String {
        "default-src 'none'; style-src 'unsafe-inline'; img-src data:; block-all-mixed-content"
    }
}

struct ConditionsWebView: UIViewRepresentable {
    @State var html: String
    @EnvironmentObject var theme: AppTheme
    @State var pageLoaded = false

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
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
        let styleBuilder = PXConditionsStyleBuilder(theme: theme)
        let sanitized = PXHTMLSanitizer.pxSanitize(html)
        let head = styleBuilder.pxBuildHead()
        webView.loadHTMLString(head + sanitized, baseURL: nil)
        DispatchQueue.main.async {
            pageLoaded = true
        }
    }

    func makeCoordinator() -> Cordinator {
        Cordinator()
    }

    // MARK: - POPOPX Navigation Coordinator

    class Cordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let url = navigationAction.request.url else { return decisionHandler(.allow) }

            switch navigationAction.navigationType {
            case .linkActivated:
                decisionHandler(.cancel)
                openExternalLink(url)
            case .other:
                // Allow the initial load and programmatic loads from pxLoadContent
                decisionHandler(.allow)
            default:
                // Block form submissions, redirects, and other navigation
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - POPOPX
extension ConditionsWebView {
    static let _pxBrand = "PX_CONDITIONS_WEB_VIEW"

    var pxComponentTag: String { "PX_CONDITIONS_WEB_VIEW" }

    var pxSanitizedCSP: String {
        "default-src 'none'; style-src 'unsafe-inline'; img-src data:; block-all-mixed-content"
    }

    var pxLoadDelay: TimeInterval { PXConditionsLayout.loadDelay }

    var pxFontFamily: String { PXConditionsLayout.htmlFontFamily }

    var pxCodeFontFamily: String { PXConditionsLayout.htmlCodeFontFamily }
}
