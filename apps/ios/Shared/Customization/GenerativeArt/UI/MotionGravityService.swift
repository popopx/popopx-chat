// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  MotionGravityService.swift
//  POPOPX
//
//  CoreMotion wrapper for gyro-based gravity direction in particle effects.
//

import CoreMotion
import SwiftUI

@MainActor
class MotionGravityService: ObservableObject {
    static let shared = MotionGravityService()

    var gravityVector: CGVector = CGVector(dx: 0, dy: 2300) // POPOPX: removed @Published — consumers read from TimelineView
    var parallaxOffset: CGSize = .zero // POPOPX: removed @Published — prevents cascade re-renders

    private let motionManager = CMMotionManager()
    private var isTracking = false
    private var consumerCount = 0
    private var wasTrackingBeforePause = false

    private let gravityScale: CGFloat = 2500
    private let defaultGravity: CGVector = CGVector(dx: 0, dy: 2300)
    private let parallaxScale: CGFloat = 12

    private init() {}

    func start() {
        consumerCount += 1
        guard consumerCount == 1 else { return }
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 1.0 // POPOPX: 1fps sufficient for subtle parallax, was 60fps
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            let gravity = motion.gravity
            let userAccel = motion.userAcceleration

            let gx = CGFloat(gravity.x + userAccel.x) * self.gravityScale
            let gy = CGFloat(gravity.y + userAccel.y) * self.gravityScale

            let px = CGFloat(motion.attitude.roll) * self.parallaxScale
            let py = CGFloat(motion.attitude.pitch) * self.parallaxScale

            self.gravityVector = CGVector(dx: gx, dy: gy)
            self.parallaxOffset = CGSize(width: px, height: py)
        }

        isTracking = true
    }

    func stop() {
        consumerCount = max(0, consumerCount - 1)
        guard consumerCount == 0 else { return }
        motionManager.stopDeviceMotionUpdates()
        isTracking = false
        gravityVector = defaultGravity
        parallaxOffset = .zero
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase != .active {
            if isTracking {
                wasTrackingBeforePause = true
                motionManager.stopDeviceMotionUpdates()
                isTracking = false
            }
        } else if wasTrackingBeforePause && consumerCount > 0 {
            wasTrackingBeforePause = false
            motionManager.deviceMotionUpdateInterval = 1.0 / 1.0 // POPOPX: match start() interval
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }

                let gravity = motion.gravity
                let userAccel = motion.userAcceleration

                let gx = CGFloat(gravity.x + userAccel.x) * self.gravityScale
                let gy = CGFloat(gravity.y + userAccel.y) * self.gravityScale

                let px = CGFloat(motion.attitude.roll) * self.parallaxScale
                let py = CGFloat(motion.attitude.pitch) * self.parallaxScale

                self.gravityVector = CGVector(dx: gx, dy: gy)
                self.parallaxOffset = CGSize(width: px, height: py)
            }
            isTracking = true
        }
    }
}
