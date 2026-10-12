// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/ai-assistant
import Foundation

class AIPrivacyGuard {
    private let patterns: [(regex: NSRegularExpression, replacement: String)]

    init() {
        let pairs: [(String, String)] = [
            (#"(\+?\d{1,2}[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}"#, "[PHONE]"),
            (#"\+\d{1,3}[\s.-]?\d{1,4}[\s.-]?\d{1,4}[\s.-]?\d{1,9}"#, "[PHONE]"),
            (#"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#, "[EMAIL]"),
            (#"\b\d{3}-\d{2}-\d{4}\b"#, "[SSN]"),
            (#"\b(?:\d{4}[\s-]){3}\d{4}\b|\b\d{16}\b"#, "[CARD]"),
            (#"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#, "[IP_ADDRESS]"),
            (#"\b\d+\s+[\w\s]+(?:street|st|avenue|ave|road|rd|blvd|boulevard|drive|dr|lane|ln|way|court|ct|place|pl)\b\.?"#, "[ADDRESS]"),
            (#"https?://[^\s<>\"']+"#, "[URL]"),
        ]
        self.patterns = pairs.compactMap { pattern, replacement in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (regex, replacement)
        }
    }

    func sanitize(_ input: String) -> String {
        var result = input
        for (regex, replacement) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
        }
        return result
    }

}
