// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

// MARK: - Data Hex String Extension

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
