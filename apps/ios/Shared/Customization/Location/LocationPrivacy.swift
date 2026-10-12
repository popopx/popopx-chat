// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/06-FEATURE-LOCATION.md
import CoreLocation
import Security

enum LocationPrecision: String, Codable, CaseIterable {
    case exact, fuzzy, region

    var displayName: String {
        switch self {
        case .exact: return NSLocalizedString("location_precision_exact", comment: "Location precision: exact GPS")
        case .fuzzy: return NSLocalizedString("location_precision_fuzzy", comment: "Location precision: ~1km accuracy")
        case .region: return NSLocalizedString("location_precision_region", comment: "Location precision: ~10km region")
        }
    }

    var description: String {
        switch self {
        case .exact: return NSLocalizedString("location_precision_exact_desc", comment: "Description for exact location precision")
        case .fuzzy: return NSLocalizedString("location_precision_fuzzy_desc", comment: "Description for fuzzy location precision")
        case .region: return NSLocalizedString("location_precision_region_desc", comment: "Description for region location precision")
        }
    }

    var iconName: String {
        switch self {
        case .exact: return "location.fill"
        case .fuzzy: return "location.circle.fill"
        case .region: return "globe"
        }
    }
}

enum LocationPrivacy {
    static func applyPrecision(_ coordinate: CLLocationCoordinate2D, precision: LocationPrecision) -> (lat: Double, lng: Double) {
        switch precision {
        case .exact:
            return (coordinate.latitude, coordinate.longitude)
        case .fuzzy:
            let lat = (coordinate.latitude * 100).rounded() / 100
                + secureRandomDouble(in: -0.005...0.005)
            let lng = (coordinate.longitude * 100).rounded() / 100
                + secureRandomDouble(in: -0.005...0.005)
            return (lat, lng)
        case .region:
            let lat = (coordinate.latitude * 10).rounded() / 10
                + secureRandomDouble(in: -0.05...0.05)
            let lng = (coordinate.longitude * 10).rounded() / 10
                + secureRandomDouble(in: -0.05...0.05)
            return (lat, lng)
        }
    }

    private static func secureRandomDouble(in range: ClosedRange<Double>) -> Double {
        var bytes = [UInt8](repeating: 0, count: 8)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return 0 }
        let randomUInt64 = bytes.withUnsafeBufferPointer { buffer -> UInt64 in
            guard let base = buffer.baseAddress else { return 0 }
            return base.withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
        }
        let normalized = Double(randomUInt64 >> 11) / Double(1 << 53)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}
