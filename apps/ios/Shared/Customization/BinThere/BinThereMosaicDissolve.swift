// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereMosaicDissolve.swift
//  POPOPX (iOS)
//
//  Canvas-based mosaic pixelation dissolve overlay for burn-after-read reveal views.
//  Equivalent to the Metal mosaic_fragment_shader from safescreen.rtf reference,
//  implemented in SwiftUI Canvas to avoid pbxproj .metal file integration.
//
//  When activated, progressively pixelates the screen over 0.8s:
//  block size 1px → 60px, opacity 0 → 1.0, then calls onComplete.
//

import SwiftUI

struct BinThereMosaicDissolve: View {
    @Binding var isActive: Bool
    var onComplete: () -> Void
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var progress: CGFloat = 0
    @State private var startDate: Date?

    private let duration: TimeInterval = 0.8
    private let maxBlockSize: CGFloat = 60
    private let fps: Double = 30.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / fps, paused: powerMode.isLowPowerMode || scenePhase != .active || !isActive)) { timeline in
            Canvas { context, size in
                guard isActive else { return }

                let blockSize = max(1, progress * maxBlockSize)
                let alpha = min(1.0, progress * 1.5)
                let cols = Int(ceil(size.width / blockSize))
                let rows = Int(ceil(size.height / blockSize))

                let centerX = size.width / 2
                let centerY = size.height / 2
                let maxDist = sqrt(centerX * centerX + centerY * centerY)

                for row in 0..<rows {
                    for col in 0..<cols {
                        let rect = CGRect(
                            x: CGFloat(col) * blockSize,
                            y: CGFloat(row) * blockSize,
                            width: blockSize,
                            height: blockSize
                        )

                        let blockCenterX = rect.midX
                        let blockCenterY = rect.midY
                        let dist = sqrt(
                            (blockCenterX - centerX) * (blockCenterX - centerX) +
                            (blockCenterY - centerY) * (blockCenterY - centerY)
                        )
                        let radialFactor = 1.0 - (dist / maxDist) * 0.3

                        let localAlpha = alpha * radialFactor

                        let hueShift = (col + row) % 3
                        let color: Color
                        switch hueShift {
                        case 0:
                            color = Color(hex: "#06040A")
                        case 1:
                            color = Color(hex: "#141021")
                        default:
                            color = Color(hex: "#6E25C4").opacity(0.15)
                        }

                        context.fill(Path(rect), with: .color(color.opacity(localAlpha)))
                    }
                }
            }
            .onChange(of: timeline.date) { _, newDate in
                guard isActive else { return }
                if startDate == nil {
                    startDate = newDate
                }
                let elapsed = newDate.timeIntervalSince(startDate!)
                let newProgress = min(1.0, CGFloat(elapsed / duration))
                if newProgress != progress {
                    progress = newProgress
                }
                if progress >= 1.0 {
                    onComplete()
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(isActive)
    }
}
