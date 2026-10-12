// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

/// Internet transport adapter for the TransportRouter.
/// Actual internet message delivery is handled by the Haskell FFI (POPOPX API).
/// This transport exists to track internet availability for the router's fallback logic.
/// When internet is available, ComposeView routes messages through apiSendMessages() directly.
class InternetTransport: MessageTransport {
    let transportID = "internet"

    var onMessageReceived: ((TransportMessage) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    private(set) var isAvailable: Bool = true

    func start() throws {
        Task { @MainActor in
            isAvailable = true
            onAvailabilityChanged?(true)
        }
    }

    func stop() {
        Task { @MainActor in
            isAvailable = false
            onAvailabilityChanged?(false)
        }
    }

    func send(_ message: TransportMessage, completion: @escaping (Result<Void, TransportError>) -> Void) {
        completion(.failure(.sendFailed("Internet delivery requires FFI path")))
    }

    func updateAvailability(_ available: Bool) {
        Task { @MainActor in
            guard available != isAvailable else { return }
            isAvailable = available
            onAvailabilityChanged?(available)
        }
    }
}
