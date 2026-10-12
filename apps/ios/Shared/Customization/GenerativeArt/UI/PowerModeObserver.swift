// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  PowerModeObserver.swift
//  POPOPX
//
//  Observes Low Power Mode state changes for animation throttling.
//

import Foundation
import SwiftUI

@MainActor
class PowerModeObserver: ObservableObject {
    static let shared = PowerModeObserver()

    @Published var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    @objc private func powerStateDidChange() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
