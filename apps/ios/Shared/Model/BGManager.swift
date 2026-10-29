//
//  BGManager.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 08/02/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/services/notifications.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import BackgroundTasks
import POPOPXSwitch

private let receiveTaskId = "com.popopxchat.popopx.receive"

// TCP timeout + 2 sec
private let waitForMessages: TimeInterval = 6

// This is the smallest interval between refreshes, and also target interval in "off" mode
private let bgRefreshInterval: TimeInterval = 600 // 10 minutes

// This intervals are used for background refresh in instant and periodic modes
private let periodicBgRefreshInterval: TimeInterval = 1200 // 20 minutes

private let maxBgRefreshInterval: TimeInterval = 2400 // 40 minutes

private let maxTimerCount = 9

// Spec: spec/services/notifications.md#BGManager
class BGManager: @unchecked Sendable {
    static let shared = BGManager()
    private let syncQueue = DispatchQueue(label: "bgmanager.sync")
    var chatReceiver: ChatReceiver? {
        get { syncQueue.sync { _chatReceiver } }
        set { syncQueue.sync { _chatReceiver = newValue } }
    }
    private var _chatReceiver: ChatReceiver?
    var bgTimer: Timer? {
        get { syncQueue.sync { _bgTimer } }
        set { syncQueue.sync { _bgTimer = newValue } }
    }
    private var _bgTimer: Timer?
    var completed: Bool {
        get { syncQueue.sync { _completed } }
        set { syncQueue.sync { _completed = newValue } }
    }
    private var _completed = true
    var timerCount: Int {
        get { syncQueue.sync { _timerCount } }
        set { syncQueue.sync { _timerCount = newValue } }
    }
    private var _timerCount = 0

    deinit {
        syncQueue.sync {
            _bgTimer?.invalidate()
            _bgTimer = nil
        }
    }

    // Spec: spec/services/notifications.md#register
    func register() {
        logger.debug("BGManager.register")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: receiveTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                logger.error("BGManager: expected BGAppRefreshTask but got \(type(of: task))")
                return
            }
            Task { @MainActor in
                self.handleRefresh(refreshTask)
            }
        }
    }

    // Spec: spec/services/notifications.md#schedule
    @MainActor
    func schedule(interval: TimeInterval? = nil) {
        if !ChatModel.shared.ntfEnableLocal {
            logger.debug("BGManager.schedule: disabled")
            return
        }
        logger.debug("BGManager.schedule")
        let request = BGAppRefreshTaskRequest(identifier: receiveTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval ?? runInterval)
        BGTaskScheduler.shared.submitTaskRequest(request) { error in
            if let error {
                logger.error("BGManager.schedule error: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    var runInterval: TimeInterval {
        switch ChatModel.shared.notificationMode {
        case .instant: maxBgRefreshInterval
        case .periodic: periodicBgRefreshInterval
        case .off: bgRefreshInterval
        }
    }

    @MainActor
    var lastRanLongAgo: Bool {
        Date.now.timeIntervalSince(chatLastBackgroundRunGroupDefault.get()) > runInterval
    }

    // Spec: spec/services/notifications.md#handleRefresh
    @MainActor
    private func handleRefresh(_ task: BGAppRefreshTask) {
        if !ChatModel.shared.ntfEnableLocal {
            logger.debug("BGManager.handleRefresh: disabled")
            task.setTaskCompleted(success: true)
            return
        }
        logger.debug("BGManager.handleRefresh")
        let shouldRun_ = lastRanLongAgo
        if allowBackgroundRefresh() && shouldRun_ {
            schedule()
            let completeRefresh = completionHandler {
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { completeRefresh("expirationHandler") }
            receiveMessages(completeRefresh)
        } else {
            schedule(interval: shouldRun_ ? bgRefreshInterval : runInterval)
            logger.debug("BGManager.completionHandler: already active, not started")
            task.setTaskCompleted(success: true)
        }
    }

    func completionHandler(_ complete: @escaping () -> Void) -> ((String) -> Void) {
        { reason in
            logger.debug("BGManager.completionHandler: \(reason)")
            if !self.completed {
                self.completed = true
                Task { @MainActor in self.chatReceiver?.stop() }
                self.chatReceiver = nil
                self.bgTimer?.invalidate()
                self.bgTimer = nil
                self.timerCount = 0
                Task { @MainActor in suspendBgRefresh() }
                complete()
            }
        }
    }

    // Spec: spec/services/notifications.md#receiveMessages-BG
    func receiveMessages(_ completeReceiving: @escaping (String) -> Void) {
        if (!self.completed) {
            logger.debug("BGManager.receiveMessages: in progress, exiting")
            completeReceiving("already in progress")
            return
        }
        self.completed = false
        DispatchQueue.main.async {
            Task { @MainActor in
                chatLastBackgroundRunGroupDefault.set(Date.now)
                let m = ChatModel.shared
                if (!m.chatInitialized) {
                    setAppState(.bgRefresh)
                    do {
                        try await initializeChat(start: true)
                    } catch let error {
                        logger.error("BGManager: Failed to start or load chats: \(responseError(error))")
                        completeReceiving("failed to initialize chat")
                        return
                    }
                }
                activateChat(appState: .bgRefresh)
                if m.currentUser == nil {
                    completeReceiving("no current user")
                    return
                }
                logger.debug("BGManager.receiveMessages: starting chat")
                let cr = ChatReceiver()
                self.chatReceiver = cr
                cr.start()
                Task { @MainActor in
                    var lastMsgTime = cr.lastMsgTime
                    let timer = Timer(timeInterval: 2, repeats: true) { t in
                        logger.debug("BGManager.receiveMessages: timer")
                        self.bgTimer = t
                        self.timerCount += 1
                        lastMsgTime = MainActor.assumeIsolated { cr.lastMsgTime }
                        if lastMsgTime.distance(to: Date.now) >= waitForMessages {
                            t.invalidate()
                            completeReceiving("timer (no messages after \(waitForMessages) seconds)")
                        } else if self.timerCount >= maxTimerCount {
                            t.invalidate()
                            completeReceiving("timer (called \(maxTimerCount) times)")
                        }
                    }
                    RunLoop.main.add(timer, forMode: .common)
                }
            }
        }
    }
}
