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
//  Based on the industrial solution from safescreen.rtf:
//  "以高于肉眼、但低于主流手机相机快门同步率的频率快速交替扰动纹理"
//

import SwiftUI
import os

private let moireLogger = Logger(subsystem: "im.popopx", category: "MoireDefense")

struct BinThereMoireDefense: View {
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var performanceMonitor = MoirePerformanceMonitor()

    var body: some View {
        TimelineView(.animation(minimumInterval: performanceMonitor.targetFrameInterval, paused: shouldPause)) { timeline in
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
            .onChange(of: timeline.date) { _, newDate in
                performanceMonitor.recordFrame(at: newDate)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            performanceMonitor.startMonitoring()
        }
        .onDisappear {
            performanceMonitor.stopMonitoring()
        }
    }

    private var shouldPause: Bool {
        powerMode.isLowPowerMode || scenePhase != .active || performanceMonitor.shouldReduceQuality
    }
}

// MARK: - Performance Monitor

@MainActor
class MoirePerformanceMonitor: ObservableObject {
    @Published private(set) var currentFPS: Double = 0
    @Published private(set) var shouldReduceQuality: Bool = false
    
    private var frameTimes: [Date] = []
    private var lastAdjustmentTime: Date = .distantPast
    private let adjustmentInterval: TimeInterval = 2.0
    private let lowFPSThreshold: Double = 20.0
    private let highFPSThreshold: Double = 50.0
    
    var targetFrameInterval: TimeInterval {
        shouldReduceQuality ? 1.0 / 15.0 : 1.0 / 30.0
    }
    
    func recordFrame(at date: Date) {
        frameTimes.append(date)
        
        // Keep only last 2 seconds of frame times
        let cutoff = date.addingTimeInterval(-2.0)
frameTimes = frameTimes.filter { $0 > cutoff }
        
        // Calculate FPS every 0.5 seconds
        if frameTimes.count >= 2 {
            let elapsed = date.timeIntervalSince(frameTimes.first!)
            if elapsed > 0 {
                let fps = Double(frameTimes.count) / elapsed
                updateFPS(fps)
            }
        }
    }
    
    private func updateFPS(_ fps: Double) {
        currentFPS = fps
        
        let now = Date()
        guard now.timeIntervalSince(lastAdjustmentTime) >= adjustmentInterval else { return }
        
        // Adjust quality based on FPS
        if fps < lowFPSThreshold && !shouldReduceQuality {
            shouldReduceQuality = true
            lastAdjustmentTime = now
            moireLogger.warning("Low FPS detected (\(fps)), reducing quality")
        } else if fps > highFPSThreshold && shouldReduceQuality {
            shouldReduceQuality = false
            lastAdjustmentTime = now
            moireLogger.info("FPS recovered (\(fps)), restoring quality")
        }
    }
    
    func startMonitoring() {
        moireLogger.debug("Performance monitoring started")
    }
    
    func stopMonitoring() {
        frameTimes.removeAll()
        currentFPS = 0
        shouldReduceQuality = false
        moireLogger.debug("Performance monitoring stopped")
    }
}
