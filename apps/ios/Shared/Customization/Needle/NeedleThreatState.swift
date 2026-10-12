// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

@MainActor
class NeedleThreatState: ObservableObject {
    static let shared = NeedleThreatState()

    @Published var isThreatActive = false

    private var clearTask: DispatchWorkItem?

    private init() {}

    func trigger() {
        clearTask?.cancel()
        isThreatActive = true

        let task = DispatchWorkItem { [weak self] in
            self?.isThreatActive = false
        }
        clearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}
