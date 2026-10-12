// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import Combine
import SwiftUI

enum LaunchPhase: Int, Comparable, CaseIterable {
    case haskellRuntime = 0
    case databaseMigration = 1
    case chatInitialization = 2
    case serverConditions = 3
    case transportSetup = 4
    case complete = 5

    static func < (lhs: LaunchPhase, rhs: LaunchPhase) -> Bool { lhs.rawValue < rhs.rawValue }

    var statusText: String {
        switch self {
        case .haskellRuntime:
            return NSLocalizedString("Initializing secure runtime...", comment: "launch phase")
        case .databaseMigration:
            return NSLocalizedString("Opening database...", comment: "launch phase")
        case .chatInitialization:
            return NSLocalizedString("Starting chat engine...", comment: "launch phase")
        case .serverConditions:
            return NSLocalizedString("Loading network conditions...", comment: "launch phase")
        case .transportSetup:
            return NSLocalizedString("Connecting services...", comment: "launch phase")
        case .complete:
            return ""
        }
    }

    var progress: Double {
        switch self {
        case .haskellRuntime: return 0.1
        case .databaseMigration: return 0.3
        case .chatInitialization: return 0.5
        case .serverConditions: return 0.7
        case .transportSetup: return 0.9
        case .complete: return 1.0
        }
    }
}

@MainActor
final class LaunchCoordinator: ObservableObject {
    static let shared = LaunchCoordinator()

    @Published var phase: LaunchPhase = .haskellRuntime
    @Published var isComplete = false
    @Published var error: String?

    private var observationTask: Task<Void, Never>?

    private init() {}

    func runInitialization() async {
        error = nil
        phase = .haskellRuntime
        startObserving()
        await initChatAndMigrate()
        phase = .complete
        isComplete = true
        observationTask?.cancel()
    }

    func retry() async {
        isComplete = false
        ChatModel.shared.chatInitialized = false
        _initChatInProgress = false
        await runInitialization()
    }

    private func startObserving() {
        observationTask?.cancel()
        let m = ChatModel.shared
        observationTask = Task { [weak self] in
            let maxPolls = 240 // 2 min timeout
            var polls = 0
            while !Task.isCancelled && polls < maxPolls {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self else { return }
                polls += 1

                if ProcessInfo.processInfo.isLowPowerModeEnabled || UIApplication.shared.connectedScenes.allSatisfy({ $0.activationState != .foregroundActive }) {
                    continue
                }

                if m.chatInitialized {
                    if self.phase < .serverConditions {
                        self.phase = .serverConditions
                    }
                } else if m.chatDbStatus != nil {
                    if self.phase < .chatInitialization {
                        self.phase = .chatInitialization
                    }
                }

                if m.chatRunning == true || m.onboardingStage != nil {
                    if self.phase < .transportSetup {
                        self.phase = .transportSetup
                    }
                }
            }
        }
    }
}
