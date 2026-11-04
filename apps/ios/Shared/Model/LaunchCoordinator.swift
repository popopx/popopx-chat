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
        case .haskellRuntime: return 0.15
        case .databaseMigration: return 0.35
        case .chatInitialization: return 0.55
        case .serverConditions: return 0.75
        case .transportSetup: return 0.92
        case .complete: return 1.0
        }
    }
}

@MainActor
final class LaunchCoordinator: ObservableObject {
    static let shared = LaunchCoordinator()

    @Published var phase: LaunchPhase = .haskellRuntime
    @Published var isComplete = false
    @Published var timeoutReached = false
    @Published var error: String?

    private var cancellables = Set<AnyCancellable>()
    private var timeoutTask: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetries = 3

    private init() {}

    func runInitialization() async {
        error = nil
        phase = .haskellRuntime
        timeoutReached = false

        logger.debug("LaunchCoordinator: starting initialization")

        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.timeoutReached = true
                logger.warning("LaunchCoordinator: timeout reached after 15s")
            }
        }

        startObserving()
        
        await initChatAndMigrate()
        timeoutTask?.cancel()
        timeoutReached = false
        phase = .complete
        isComplete = true
        retryCount = 0
        cancellables.removeAll()
        logger.debug("LaunchCoordinator: initialization complete")
    }

    func retry() async {
        guard self.retryCount < self.maxRetries else {
            logger.error("LaunchCoordinator: max retries (\(self.maxRetries)) exceeded")
            error = "Unable to initialize after multiple attempts. Please restart the app."
            return
        }
        
        self.retryCount += 1
        logger.debug("LaunchCoordinator: retry attempt \(self.retryCount)/\(self.maxRetries)")
        isComplete = false
        timeoutReached = false
        ChatModel.shared.chatInitialized = false
        _initChatInProgress = false
        await runInitialization()
    }

    private func startObserving() {
        cancellables.removeAll()
        let db = AppStateModel.shared.database
        let onboarding = AppStateModel.shared.onboarding
        let _ = AppStateModel.shared.mesh
        
        db.$chatInitialized
            .sink { [weak self] initialized in
                guard let self, initialized, self.phase < .serverConditions else { return }
                self.phase = .serverConditions
            }
            .store(in: &cancellables)
        
        db.$chatDbStatus
            .sink { [weak self] status in
                guard let self, status != nil, self.phase < .chatInitialization else { return }
                self.phase = .chatInitialization
            }
            .store(in: &cancellables)
        
        db.$chatRunning
            .sink { [weak self] running in
                guard let self, running == true, self.phase < .transportSetup else { return }
                self.phase = .transportSetup
            }
            .store(in: &cancellables)
        
        onboarding.$onboardingStage
            .sink { [weak self] stage in
                guard let self, stage != nil, self.phase < .transportSetup else { return }
                self.phase = .transportSetup
            }
            .store(in: &cancellables)
    }
}
