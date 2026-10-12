// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

/// Geohash encoding utility for location-based board post filtering.
/// Uses standard base32 geohash algorithm with 5-character precision (~2.4km).
enum Geohash {
    private static let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"

    static func encode(latitude: Double, longitude: Double, precision: Int = 5) -> String {
        guard (-90...90).contains(latitude),
              (-180...180).contains(longitude),
              (1...12).contains(precision) else {
            return ""
        }

        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var isLon = true
        var bit = 0
        var ch = 0

        while hash.count < precision {
            if isLon {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    ch = (ch << 1) | 1
                    lonRange.0 = mid
                } else {
                    ch = ch << 1
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    ch = (ch << 1) | 1
                    latRange.0 = mid
                } else {
                    ch = ch << 1
                    latRange.1 = mid
                }
            }
            isLon = !isLon
            bit += 1
            if bit == 5 {
                hash.append(base32[base32.index(base32.startIndex, offsetBy: ch)])
                bit = 0
                ch = 0
            }
        }
        return hash
    }
}
