// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

enum RelayURLError: Error {
    case insecureScheme
    case invalidURL
}

enum NostrRelayURL {
    static func normalized(_ rawValue: String, defaultScheme: String? = nil) -> String? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if !value.contains("://"), let defaultScheme {
            value = "\(defaultScheme)://\(value)"
        }

        guard var components = URLComponents(string: value),
              let rawScheme = components.scheme?.lowercased(),
              let rawHost = components.host?.lowercased(),
              !rawHost.isEmpty else {
            return nil
        }

        switch rawScheme {
        case "wss", "https":
            components.scheme = "wss"
            if components.port == 443 {
                components.port = nil
            }
        case "ws", "http":
            // Reject plaintext relay URLs — all relay communication must be encrypted
            return nil
        default:
            return nil
        }

        components.host = rawHost
        if components.path == "/" {
            components.path = ""
        }
        components.fragment = nil

        return components.string
    }
}
