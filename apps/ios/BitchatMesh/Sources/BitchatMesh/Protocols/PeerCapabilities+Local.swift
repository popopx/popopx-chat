// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import BitFoundation

extension PeerCapabilities {
    /// Capabilities this build advertises in its announce packets.
    /// Each feature adds its bit here when it ships.
    static let localSupported: PeerCapabilities = [
        .vouch,
        .prekeys,
        .groups,
        .privateMedia,
        .privateMediaReceipts
    ]
}
