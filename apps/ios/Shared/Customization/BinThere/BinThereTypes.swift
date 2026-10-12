// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereTypes.swift
//  POPOPX (iOS)
//
//  Types and encoding for burn-after-read message markers.
//  Follows the MessageMarkers.swift pattern (prefix + base64 JSON + fallback).
//

import Foundation
import Security
import os

let SX_BT_PREFIX = "🔐SXBT:"

struct BinThereInfo: Codable, Equatable {
    var pid: String
    var key: String
    var bot: String
    var contentType: String?
    var imageWidth: CGFloat?
    var imageHeight: CGFloat?

    var isImage: Bool { contentType == "image" }
    var effectiveContentType: String { contentType ?? "text" }
}

func encodeBinThereMessage(_ info: BinThereInfo) -> String {
    let payload = encodeBTPayload(info) ?? ""
    return "\(SX_BT_PREFIX)\(payload)\n🔐 Burn-after-read message\nbinthere://p/\(info.pid)#\(info.key)"
}

func parseBinThereMessage(_ text: String) -> BinThereInfo? {
    guard let range = text.range(of: SX_BT_PREFIX) else { return nil }
    let afterPrefix = text[range.upperBound...]
    let token = afterPrefix.prefix { $0 != "\n" }
    return decodeBTPayload(String(token))
}

private func encodeBTPayload(_ info: BinThereInfo) -> String? {
    guard let data = try? JSONEncoder().encode(info) else { return nil }
    return data.base64EncodedString()
}

private func decodeBTPayload(_ token: String) -> BinThereInfo? {
    guard let data = Data(base64Encoded: token),
          let info = try? JSONDecoder().decode(BinThereInfo.self, from: data)
    else { return nil }
    return info
}

// MARK: - Consumed state persistence

enum BinThereConsumed {
    private static let service = "chat.popopx.binthere-consumed"
    private static let account = "consumed-ids"
    private static let maxEntries = 500

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Try update first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist yet — create it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status != errSecSuccess {
            os_log(.error, "BinThereConsumed: keychain write failed: %d", Int(status))
        }
    }

    static func markConsumed(_ pasteId: String) {
        let current = readFromKeychain() ?? ""
        var ids = current.isEmpty ? [] : current.components(separatedBy: ",")
        guard !ids.contains(pasteId) else { return }
        ids.append(pasteId)
        if ids.count > maxEntries {
            ids = Array(ids.suffix(maxEntries))
        }
        writeToKeychain(ids.joined(separator: ","))
    }

    static func isConsumed(_ pasteId: String) -> Bool {
        let current = readFromKeychain() ?? ""
        guard !current.isEmpty else { return false }
        let ids = current.components(separatedBy: ",")
        return ids.contains(pasteId)
    }
}
