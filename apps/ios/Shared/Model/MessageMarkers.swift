// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  MessageMarkers.swift
//  POPOPX (iOS)
//
//  Encodes rich payloads (shared location, compute-token red packet) inside plain
//  text messages so they travel over the existing protocol without core changes.
//  Older/other clients degrade gracefully to a readable maps link / text.
//

import Foundation

// MARK: - Shared location

let SX_LOC_PREFIX = "📍SXLOC:"

struct SharedLocation: Codable, Equatable {
    var lat: Double
    var lng: Double
    var name: String
}

func encodeLocationMessage(_ loc: SharedLocation) -> String {
    let payload = encodeMarkerPayload(loc) ?? ""
    let mapsURL = "https://maps.apple.com/?ll=\(loc.lat),\(loc.lng)"
    let title = loc.name.isEmpty ? NSLocalizedString("location_shared_location", comment: "Shared location fallback") : loc.name
    return "\(SX_LOC_PREFIX)\(payload)\n📍 \(title)\n\(mapsURL)"
}

func parseLocationMessage(_ text: String) -> SharedLocation? {
    guard let range = text.range(of: SX_LOC_PREFIX) else { return nil }
    let afterPrefix = text[range.upperBound...]
    let token = afterPrefix.prefix { $0 != "\n" }
    return decodeMarkerPayload(String(token))
}

// MARK: - Compute-token red packet

let SX_RP_PREFIX = "🧧SXRP:"

struct RedPacketInfo: Codable, Equatable, Identifiable {
    var id: String
    var amount: Double
    var message: String
    var from: String
}

func encodeRedPacketMessage(_ rp: RedPacketInfo) -> String {
    let payload = encodeMarkerPayload(rp) ?? ""
    let note = rp.message.isEmpty ? "Compute-token gift" : rp.message
    return "\(SX_RP_PREFIX)\(payload)\n🧧 \(note) · \(formatTokens(rp.amount)) tokens"
}

func parseRedPacketMessage(_ text: String) -> RedPacketInfo? {
    guard let range = text.range(of: SX_RP_PREFIX) else { return nil }
    let afterPrefix = text[range.upperBound...]
    let token = afterPrefix.prefix { $0 != "\n" }
    return decodeMarkerPayload(String(token))
}

// MARK: - Helpers

func formatTokens(_ amount: Double) -> String {
    guard amount.isFinite && amount >= 0 else { return "0" }
    let clamped = min(amount, Double(Int.max))
    return clamped.truncatingRemainder(dividingBy: 1) == 0
    ? String(Int(clamped))
    : String(format: "%.2f", clamped)
}

private func encodeMarkerPayload<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return data.base64EncodedString()
}

private func decodeMarkerPayload<T: Decodable>(_ token: String) -> T? {
    guard let data = Data(base64Encoded: token),
          let value = try? JSONDecoder().decode(T.self, from: data)
    else { return nil }
    return value
}
