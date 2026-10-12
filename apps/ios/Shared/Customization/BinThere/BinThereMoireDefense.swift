// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  BinThereMoireDefense.swift
//  POPOPX (iOS)
//
//  Anti-photography defense overlay for BinThere burn-after-read views.
//  Renders ultra-fine alternating line patterns at 60Hz that are invisible
//  to the naked eye but cause visible Moiré interference when captured
//  by an external camera (phone, DSLR) due to rolling shutter interaction.
//
//  Based on the industrial approach from safescreen.rtf:
//  "以高于肉眼、但低于主流手机相机快门同步率的频率快速交替扰动纹理"
//

import SwiftUI

struct BinThereMoireDefense: View {
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let lineCount = Int(size.height * 0.8)
                guard lineCount > 0 else { return }
                let lineHeight = size.height / CGFloat(lineCount)

                for i in 0..<lineCount {
                    let y = CGFloat(i) * lineHeight
                    let phase = sin(t * 120.0 + Double(i) * 0.15)
                    let brightness = 0.5 + 0.5 * phase
                    let opacity = 0.015 + 0.025 * brightness

                    let hue = Double(i).truncatingRemainder(dividingBy: 3.0) / 3.0
                    let color = Color(hue: hue, saturation: 0.1, brightness: 1.0)
                        .opacity(opacity)

                    let rect = CGRect(x: 0, y: y, width: size.width, height: max(1, lineHeight * 0.5))
                    context.fill(Path(rect), with: .color(color))
                }

                let scanY = CGFloat((t * 200.0).truncatingRemainder(dividingBy: Double(size.height)))
                let scanRect = CGRect(x: 0, y: scanY, width: size.width, height: 2)
                context.fill(Path(scanRect), with: .color(.white.opacity(0.02)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
