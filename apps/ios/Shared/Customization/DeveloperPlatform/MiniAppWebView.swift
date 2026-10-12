// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/14-FEATURE-DEVELOPER-BRIDGE.md
import SwiftUI
import WebKit

private let allowedMiniAppDomains: Set<String> = {
    var domains: Set<String> = [
        "apps.popopxchat.com",
        "mini.popopxchat.com",
    ]
    #if DEBUG
    domains.insert("localhost")
    #endif
    return domains
}()

struct MiniAppWebView: UIViewRepresentable {
    let url: URL
    @Binding var title: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        
        // Explicitly allow JavaScript — required for mini-app functionality
        // This is intentional; the domain whitelist and HTTPS-only policy provide the security boundary
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            // Restrict navigation to only app-bound domains (iOS 14+)
            config.limitsNavigationsToAppBoundDomains = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        
        config.userContentController.add(context.coordinator, name: "popopxBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        injectJavaScriptBridge(webView: webView)
        loadRequest(webView: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            loadRequest(webView: webView)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "popopxBridge")
        context.coordinator.onTitleChange = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isURLAllowed: { url in self.isURLAllowed(url) },
            onTitleChange: { newTitle in
                DispatchQueue.main.async {
                    self.title = newTitle
                }
            }
        )
    }

    private func loadRequest(webView: WKWebView) {
        guard isURLAllowed(url) else {
            logger.error("MiniAppWebView: blocked URL \(url.absoluteString)")
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    private func injectJavaScriptBridge(webView: WKWebView) {
        let bridgeScript = """
        window.POPOPX = {
            sendMessage: function(type, payload) {
                window.webkit.messageHandlers.popopxBridge.postMessage({
                    type: type,
                    payload: payload
                });
            },
            getUser: function() {
                return new Promise(function(resolve) {
                    var callbackId = 'cb_' + Date.now();
                    window.webkit.messageHandlers.popopxBridge.postMessage({
                        type: 'getUser',
                        callbackId: callbackId
                    });
                    window.popopxCallbacks = window.popopxCallbacks || {};
                    window.popopxCallbacks[callbackId] = resolve;
                });
            },
            onMessage: function(handler) {
                window.popopxMessageHandler = handler;
            }
        };
        """

        let userScript = WKUserScript(
            source: bridgeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(userScript)
    }

    private func isURLAllowed(_ url: URL) -> Bool {
        guard let host = url.host, let scheme = url.scheme else {
            return false
        }
        #if DEBUG
        if host == "localhost" && (scheme == "http" || scheme == "https") { return true }
        #endif
        guard scheme == "https" else { return false }
        let allowedSubdomains: Set<String> = ["apps", "mini"]
        if let firstComponent = host.split(separator: ".").first,
           host.hasSuffix(".popopxchat.com"),
           allowedSubdomains.contains(String(firstComponent)) {
            return true
        }
        return allowedMiniAppDomains.contains(host)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let isURLAllowed: (URL) -> Bool
        var onTitleChange: ((String) -> Void)?

        init(isURLAllowed: @escaping (URL) -> Bool, onTitleChange: @escaping (String) -> Void) {
            self.isURLAllowed = isURLAllowed
            self.onTitleChange = onTitleChange
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Block file:// scheme access to prevent local file disclosure attacks
            if navigationAction.request.url?.scheme == "file" {
                logger.error("MiniAppWebView: blocked file:// URL access")
                decisionHandler(.cancel)
                return
            }
            
            if let url = navigationAction.request.url, isURLAllowed(url) {
                decisionHandler(.allow)
            } else if navigationAction.request.url?.scheme == "about" {
                decisionHandler(.allow)
            } else {
                logger.error("MiniAppWebView: blocked navigation to \(navigationAction.request.url?.absoluteString ?? "nil")")
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.title") { [onTitleChange] result, error in
                if let title = result as? String, let onTitleChange {
                    DispatchQueue.main.async {
                        onTitleChange(title)
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "getUser":
                guard let callbackId = body["callbackId"] as? String,
                      callbackId.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return }
                let userData = ["displayName": "User"]
                guard let json = try? JSONSerialization.data(withJSONObject: userData),
                      let jsonString = String(data: json, encoding: .utf8) else { return }
                let safeCallbackId = callbackId.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "_"))) ?? callbackId
                // Comprehensive escaping for JavaScript string literal context
                let escapedJSON = jsonString
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\t", with: "\\t")
                    .replacingOccurrences(of: "\0", with: "\\0")
                    .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                    .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
                    .replacingOccurrences(of: "</", with: "<\\/")
                let script = "window.popopxCallbacks['\(safeCallbackId)'](JSON.parse('\(escapedJSON)'))"
                message.webView?.evaluateJavaScript(script, completionHandler: nil)

            default:
                break
            }
        }
    }
}

struct MiniAppWebViewContainer: View {
    let url: URL
    @State private var title: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassBackground()
            }

            MiniAppWebView(url: url, title: $title)
        }
        .popopxBranded()
    }
}
