//
//  PXNSESubscriber.swift
//  POPOPXSwitch
//
//  Created by Evgeny on 09/12/2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
@preconcurrency import POPOPXSwitch

// MARK: - POPOPX Configuration
private enum PXNSEConfig {
    static let featureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")
    static let suspendingTimeout: TimeInterval = 2.2
    static let pollingInterval: TimeInterval = 1.2
    static let queueLabel = "im.popopx.nse.subscribers"
    static let componentIdentifier = "PXNSESubscriber"
}

private var nseSubscribers: [UUID:NSESubscriber] = [:]
private let nseSubscribersQueue = DispatchQueue(label: PXNSEConfig.queueLabel)

// POPOPX: timeout for active NSE going into "suspending" state.
private let PX_SUSPENDING_TIMEOUT: TimeInterval = PXNSEConfig.suspendingTimeout

/// POPOPX: log NSE state transitions when feature flag is active
private func pxLogNSEState(_ label: String, _ detail: String) {
    if PXNSEConfig.featureEnabled {
        logger.debug("PX: [\(label)] \(detail)")
    }
}

/// POPOPX: safely remove a subscriber by ID from the concurrent queue
private func pxRemoveSubscriber(_ id: UUID) {
    nseSubscribersQueue.sync {
        let _ = nseSubscribers.removeValue(forKey: id)
    }
}

/// POPOPX: read current NSE state from the subscribers queue
private func pxReadNSEState(_ state: NSEState) -> NSEState {
    nseSubscribersQueue.sync { state }
}

func waitNSESuspended(timeout: TimeInterval, suspended: @escaping (Bool) -> Void) {
    if timeout <= PX_SUSPENDING_TIMEOUT {
        logger.warning("waitNSESuspended: small timeout \(timeout), using \(PX_SUSPENDING_TIMEOUT + 1)")
    }
    var state = nseStateGroupDefault.get()
    if case .suspended = state {
        DispatchQueue.main.async { suspended(true) }
        return
    }
    let id = UUID()
    var suspendedCalled = false
    pxCheckTimeout()
    nseSubscribersQueue.sync {
        nseSubscribers[id] = nseMessageSubscriber { msg in
            if case let .state(newState) = msg {
                state = newState
                logger.debug("waitNSESuspended state: \(state.rawValue)")
                if case .suspended = newState {
                    pxNotifySuspended(true)
                }
            }
        }
    }
    return

    // MARK: - POPOPX Nested Helpers

    func pxNotifySuspended(_ ok: Bool) {
        logger.debug("waitNSESuspended notifySuspended: \(ok)")
        if !suspendedCalled {
            logger.debug("PX: [notifySuspended] calling suspended(\(ok)), removing subscriber")
            suspendedCalled = true
            pxRemoveSubscriber(id)
            DispatchQueue.main.async { suspended(ok) }
        }
    }

    func pxCheckTimeout() {
        if !pxSuspending() {
            pxCheckSuspendingTimeout()
        } else if pxReadNSEState(state) == .suspending {
            pxCheckSuspendedTimeout()
        }
    }

    func pxSuspending() -> Bool {
        let currentState = pxReadNSEState(state)
        let result = suspendedCalled || currentState == .suspended || currentState == .suspending
        pxLogNSEState("suspending", "suspendedCalled=\(suspendedCalled), state=\(currentState.rawValue)")
        return result
    }

    func pxCheckSuspendingTimeout() {
        Task.detached {
            try? await Task.sleep(for: .seconds(PX_SUSPENDING_TIMEOUT))
            logger.debug("PX: [checkSuspendingTimeout] checking after timeout")
            if !pxSuspending() {
                pxNotifySuspended(false)
            } else if pxReadNSEState(state) != .suspended {
                pxCheckSuspendedTimeout()
            }
        }
    }

    func pxCheckSuspendedTimeout() {
        Task.detached {
            try? await Task.sleep(for: .seconds(min(timeout - PX_SUSPENDING_TIMEOUT, 1)))
            let currentState = pxReadNSEState(state)
            logger.debug("PX: [checkSuspendedTimeout] checking state=\(currentState.rawValue)")
            if currentState != .suspended {
                pxNotifySuspended(false)
            }
        }
    }
}

// MARK: - POPOPX
extension NSESubscriber {
    static let pxComponentTag: String = PXNSEConfig.componentIdentifier
    static let pxSuspendingTimeout: TimeInterval = PXNSEConfig.suspendingTimeout
    static let pxPollingInterval: TimeInterval = PXNSEConfig.pollingInterval
    static let pxQueueLabel: String = PXNSEConfig.queueLabel

    /// POPOPX: check if the NSE feature flag is enabled
    static var pxIsFeatureEnabled: Bool {
        PXNSEConfig.featureEnabled
    }
}
