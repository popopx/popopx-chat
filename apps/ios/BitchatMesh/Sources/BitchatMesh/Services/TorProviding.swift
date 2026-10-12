// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

/// Protocol abstracting Tor lifecycle management.
/// Allows swapping the stub implementation with a real Arti-based Tor client.
public protocol TorProviding: AnyObject {
    var isReady: Bool { get }
    var torEnforced: Bool { get }

    func isForeground() -> Bool
    func isAutoStartAllowed() -> Bool
    func setAutoStartAllowed(_ allowed: Bool)
    func setAppForeground(_ foreground: Bool)
    func goDormantOnBackground()
    func ensureRunningOnForeground()
    func startIfNeeded()
    func shutdownCompletely()
    func awaitReady(timeout: Int) async -> Bool
}
