// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

@Observable
class TouchRepulsionService { // POPOPX: removed @MainActor — accessed from Sendable visualEffect closures
    static let shared = TouchRepulsionService()

    var touchLocation: CGPoint? // POPOPX: @Observable — no @Published needed

    private var lastUpdateTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 1.0 / 30.0 // POPOPX: 30fps throttle

    private init() {}

    func update(location: CGPoint) {
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= throttleInterval else { return }
        lastUpdateTime = now
        touchLocation = location
    }

    func end() {
        touchLocation = nil
        lastUpdateTime = 0
    }
}

// MARK: - POPOPX
extension TouchRepulsionService {
    static let pxComponentTag: String = "PX_TOUCH_REPULSION"
    static let pxRepulsionRadius: CGFloat = 120.0
    static let pxMaxDisplacement: CGFloat = 15.0
}
