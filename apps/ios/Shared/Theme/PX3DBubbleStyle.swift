//
//  PX3DBubbleStyle.swift
//  POPOPX
//
//  Layered shadow + inner highlight + CoreMotion micro-tilt
//  for 3D capsule bubble appearance (no Metal shaders required).
//  Copyright © 2026 POPOPX. All rights reserved.
//

import SwiftUI

struct PX3DBubbleStyle: ViewModifier {
    let isUnread: Bool
    let isTTLActive: Bool
    var enableMotionTilt: Bool = true
    @EnvironmentObject private var motionService: MotionGravityService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
            .shadow(color: glowColor.opacity(isUnread ? 0.35 : 0.15),
                    radius: isUnread ? 14 : 8, x: 0, y: 0)
            .overlay(innerHighlight)
            .rotation3DEffect(tiltAngle,
                axis: (x: tiltAxisX, y: tiltAxisY, z: 0),
                perspective: 0.4)
    }

    private var innerHighlight: some View {
        Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear, .white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
            .allowsHitTesting(false)
    }

    private var glowColor: Color {
        if isTTLActive { return Color(hex: "#FF00A0") }
        if isUnread { return Color(hex: "#00FFD2") }
        return Color(hex: "#6E25C4")
    }

    private var tiltAngle: Angle {
        guard !reduceMotion, enableMotionTilt else { return .degrees(0) }
        let gx = motionService.gravityVector.dx
        let gy = motionService.gravityVector.dy
        let magnitude = sqrt(gx * gx + gy * gy)
        return .degrees(min(Double(magnitude) / 1500.0, 3.0))
    }

    private var tiltAxisX: CGFloat {
        guard !reduceMotion, enableMotionTilt else { return 0 }
        return motionService.gravityVector.dy / 5000.0
    }

    private var tiltAxisY: CGFloat {
        guard !reduceMotion, enableMotionTilt else { return 0 }
        return -motionService.gravityVector.dx / 5000.0
    }
}

extension View {
    func px3DBubble(isUnread: Bool, isTTLActive: Bool) -> some View {
        modifier(PX3DBubbleStyle(isUnread: isUnread, isTTLActive: isTTLActive))
    }
}

// MARK: - POPOPX
extension PX3DBubbleStyle {
    static let pxComponentTag: String = "PX_3D_BUBBLE_STYLE"
}
