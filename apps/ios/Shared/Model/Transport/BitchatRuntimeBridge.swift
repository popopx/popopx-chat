// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import BitchatMesh
import Combine

/// Shared access to bitchat's runtime for POPOPX transport integration.
@MainActor
final class BitchatRuntimeBridge {
    static let shared = BitchatRuntimeBridge()

    var meshTransport: RichMeshTransport? { BitchatSharedRuntime.shared.meshTransport }
    var isRunning: Bool { BitchatSharedRuntime.shared.isRunning }

    private init() {}

    func ensureStarted() {
        BitchatSharedRuntime.shared.ensureStarted()
    }
}
