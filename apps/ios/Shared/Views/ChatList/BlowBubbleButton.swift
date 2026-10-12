//
//  BlowBubbleButton.swift
//  POPOPX
//
//  Bottom "Blow a Bubble" circular CTA with microphone blow detection.
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct BlowBubbleButton: View {
    @EnvironmentObject var chatModel: ChatModel
    @Binding var showNewChatSheet: Bool
    @Environment(\.scenePhase) private var scenePhase: ScenePhase
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @StateObject private var blowDetector = MicrophoneBlowDetector()
    @State private var showOneTimeLink = false
    @State private var oneTimeLinkWorkItem: DispatchWorkItem?
    @State private var showCenterBalloon = false

    var body: some View {
        ZStack {
            buttonBody

            // Center balloon overlay when blowing
            if showCenterBalloon {
                centerBalloonOverlay
            }
        }
        .onDisappear {
            oneTimeLinkWorkItem?.cancel()
        }
        .sheet(isPresented: $showOneTimeLink) {
            NavigationStack {
                PXNewChat(selection: .invite, hidePicker: true)
                    .modifier(ThemedBackground(grouped: true))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var buttonBody: some View {
        ZStack {
            blowingIndicator
        }
        .frame(width: 56, height: 56)
        .shadow(color: Color(hex: "#00FFD2").opacity(0.2), radius: 4)
        .onLongPressGesture(
            minimumDuration: 0.3,
            perform: {
                // Long press completed - start microphone monitoring and show center balloon
                showCenterBalloon = true
                blowDetector.startMonitoring()
            },
            onPressingChanged: { pressing in
                if !pressing && blowDetector.isHoldingButton {
                    // Capture scale before stopping to check threshold
                    let inflatedScale = blowDetector.currentScale
                    
                    // Released - stop monitoring and hide center balloon
                    blowDetector.stopMonitoring()
                    showCenterBalloon = false

                    // Check if balloon was inflated enough
                    if inflatedScale > 1.5 {
                        let workItem = DispatchWorkItem {
                            showOneTimeLink = true
                        }
                        oneTimeLinkWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                    }
                }
            }
        )
    }

    private var blowingIndicator: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#1E1433"))
                .frame(width: 56, height: 56)
                .overlay(
                    // POPOPX: Replaced repeatForever(60fps) with TimelineView 1fps for battery efficiency
                    TimelineView(.animation(minimumInterval: 1.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let pulse = 0.2 + 0.3 * (0.5 + 0.5 * sin(t * .pi / 1.5))
                        Circle()
                            .strokeBorder(
                                Color(hex: "#00FFD2").opacity(pulse),
                                lineWidth: 1.5
                            )
                    }
                )

            blowingIcon
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#00FFD2"), Color(hex: "#6E25C4")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(blowDetector.isHoldingButton ? 1.15 : 1.0)
        }
    }

    private var blowingIcon: some View {
        // Air/wind symbol representing blowing action
        Image(systemName: "wind")
            .font(.system(size: 24, weight: .semibold))
    }

    private var centerBalloonOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                balloon3D
                    .scaleEffect(blowDetector.currentScale)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
            }
        }
        .ignoresSafeArea()
    }

    private var balloon3D: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#A855F7"), Color(hex: "#6E25C4"), Color(hex: "#4A1A8A")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: 28
                    )
                )
                .frame(width: 80, height: 80)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 40, height: 28)
                .offset(x: -12, y: -16)

            Path { p in
                p.move(to: CGPoint(x: 16, y: 36))
                p.addQuadCurve(to: CGPoint(x: 64, y: 44), control: CGPoint(x: 40, y: 56))
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 1)

            Path { p in
                p.move(to: CGPoint(x: 24, y: 24))
                p.addQuadCurve(to: CGPoint(x: 56, y: 60), control: CGPoint(x: 48, y: 36))
            }
            .stroke(Color.white.opacity(0.06), lineWidth: 1)

            Circle()
                .fill(Color(hex: "#6E25C4"))
                .frame(width: 12, height: 12)
                .offset(y: 46)
        }
        .shadow(color: Color(hex: "#6E25C4").opacity(0.5), radius: 20)
        .shadow(color: Color(hex: "#00FFD2").opacity(0.3), radius: 30)
    }
}
