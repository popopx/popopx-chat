// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

private let pxTransientBubblesEnabled = UserDefaults.standard.object(forKey: "PX_TRANSIENT_BUBBLES_ENABLED") as? Bool ?? true

struct LiquidFloatModifier: ViewModifier {
    let itemID: Int64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var motionService = MotionGravityService.shared

    private var phase: Double {
        let hash = abs(Int(itemID))
        return Double(hash % 100) / 100.0 * .pi * 2
    }

    func body(content: Content) -> some View {
        if reduceMotion || !pxTransientBubblesEnabled {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 1.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in // POPOPX: 1fps for battery, was 15fps
                let t = timeline.date.timeIntervalSinceReferenceDate
                let sineY = sin(t * 0.8 + phase) * 4.0
                let sineX = sin(t * 0.5 + phase * 1.3) * 2.5
                let parallaxScale: CGFloat = 0.4
                let gx = motionService.parallaxOffset.width * parallaxScale
                let gy = motionService.parallaxOffset.height * parallaxScale

                let rawX = sineX + gx
                let rawY = sineY + gy

                let boundedX = pxBoundaryClamp(rawX)
                let boundedY = pxBoundaryClamp(rawY)

                content
                    .offset(x: boundedX, y: boundedY)
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.6), value: boundedX)
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.6), value: boundedY)
            }
        }
    }

    private let pxBoundaryRadius: CGFloat = 20.0
    private let pxBoundaryDamping: CGFloat = 0.3

    private func pxBoundaryClamp(_ value: CGFloat) -> CGFloat {
        let absValue = abs(value)
        if absValue <= pxBoundaryRadius {
            return value
        }
        let excess = absValue - pxBoundaryRadius
        let sign: CGFloat = value >= 0 ? 1 : -1
        return sign * (pxBoundaryRadius + excess * pxBoundaryDamping)
    }
}

extension LiquidFloatModifier {
    static let pxComponentTag: String = "PX_LIQUID_FLOAT"
}

struct TouchRepulsionModifier: ViewModifier {
    let itemID: Int64
    let itemPosition: CGRect?

    private let repulsionService = TouchRepulsionService.shared // POPOPX: @Observable — no @ObservedObject needed
    @ObservedObject private var powerMode = PowerModeObserver.shared

    private var displacement: CGPoint {
        guard !powerMode.isLowPowerMode,
              let touchLocation = repulsionService.touchLocation,
              let itemPos = itemPosition else {
            return .zero
        }

        let itemCenter = CGPoint(x: itemPos.midX, y: itemPos.midY)
        let dx = itemCenter.x - touchLocation.x
        let dy = itemCenter.y - touchLocation.y
        let distance = sqrt(dx * dx + dy * dy)
        let radius = TouchRepulsionService.pxRepulsionRadius

        // POPOPX: epsilon threshold + smoothstep boundary fade
        guard distance < radius, distance > 0.5 else {
            return .zero
        }

        let normalized = distance / radius
        let smoothFade = normalized < 0.8 ? 1.0 : max(0, (1.0 - normalized) / 0.2)
        let force = (1.0 - normalized) * smoothFade * TouchRepulsionService.pxMaxDisplacement
        let angle = atan2(dy, dx)

        return CGPoint(
            x: cos(angle) * force,
            y: sin(angle) * force
        )
    }
    
    func body(content: Content) -> some View {
        content.offset(x: displacement.x, y: displacement.y)
    }
}

extension View {
    func liquidFloat(itemID: Int64) -> some View {
        modifier(LiquidFloatModifier(itemID: itemID))
    }
    
    func touchRepulsion(itemID: Int64, position: CGRect?) -> some View {
        modifier(TouchRepulsionModifier(itemID: itemID, itemPosition: position))
    }
}
