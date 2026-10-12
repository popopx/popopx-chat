//
//  TacticalHeaderComponent.swift
//  POPOPX
//
//  Tactical header per main.rtf spec: Profiler avatar, brand title, Needle AI pin
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - Brand Title

struct BrandTitleView: View {
    @ObservedObject private var popCoordinator = ChatPopCoordinator.shared
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HStack(spacing: 0) {
            Text("popop")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(hex: "#6E25C4"))
            if reduceMotion {
                Text("x")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "#6E25C4"))
            } else {
                TimelineView(.animation(minimumInterval: 1.0/10.0, paused: powerMode.isLowPowerMode || scenePhase != .active || !popCoordinator.isPopping)) { context in
                    let phase = popCoordinator.isPopping
                        ? (sin(context.date.timeIntervalSinceReferenceDate * 8 * .pi) + 1) / 2
                        : 1.0
                    let opacity = popCoordinator.isPopping ? 0.3 + phase * 0.7 : 1.0
                    Text("x")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(hex: "#6E25C4"))
                        .opacity(opacity)
                        .shadow(color: Color(hex: "#6E25C4").opacity(0.5 * opacity), radius: 4, x: 0, y: 0)
                }
            }
        }
        .minimumScaleFactor(0.6)
    }
}

// MARK: - Needle Pin

struct HeaderNeedlePinView: View {
    @ObservedObject private var threatState = NeedleThreatState.shared
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showExtractions = false

    var body: some View {
        Button {
            showExtractions = true
        } label: {
            if reduceMotion {
                let pinColor = threatState.isThreatActive ? Color(red: 1.0, green: 0.23, blue: 0.19) : Color(hex: "#6E25C4")
                Image(systemName: "pin.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(pinColor)
                    .shadow(color: pinColor.opacity(0.5), radius: 4, x: 0, y: 0)
            } else {
                // POPOPX: Reduced from 10fps to 1fps for battery efficiency
                TimelineView(.animation(minimumInterval: 1.0/1.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let isThreat = threatState.isThreatActive
                    let threatCycle = isThreat ? t.truncatingRemainder(dividingBy: 0.3) / 0.3 : 0.0
                    let glowOpacity = isThreat ? 0.4 + 0.4 * sin(threatCycle * .pi) : 0.3 + 0.3 * sin(t * 2.0 * .pi / 2.0)
                    let pinColor = isThreat ? Color(red: 1.0, green: 0.23, blue: 0.19) : Color(hex: "#6E25C4")

                    Image(systemName: "pin.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(pinColor)
                        .shadow(color: pinColor.opacity(glowOpacity), radius: 4, x: 0, y: 0)
                }
            }
        }
        .accessibilityLabel(NSLocalizedString("needle_extractions_accessibility", comment: "Needle AI extractions accessibility label"))
        .sheet(isPresented: $showExtractions) {
            ExtractionListView()
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    @Binding var showNewChatSheet: Bool

    var body: some View {
        Button {
            ConnectProgressManager.shared.cancelConnectProgress()
            showNewChatSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#6E25C4"))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .strokeBorder(Color(hex: "#6E25C4").opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityLabel(NSLocalizedString("new_chat_accessibility", comment: "New chat accessibility label"))
    }
}

// MARK: - Mesh Button

struct MeshButton: View {
    var onSwitchToMesh: (() -> Void)? = nil

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSwitchToMesh?()
        } label: {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#6E25C4"))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .strokeBorder(Color(hex: "#6E25C4").opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityLabel(NSLocalizedString("switch_to_mesh_accessibility", comment: "Switch to mesh network accessibility label"))
    }
}

// MARK: - Discover Button

struct DiscoverButton: View {
    var onSwitchToDiscover: (() -> Void)? = nil

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSwitchToDiscover?()
        } label: {
            Image(systemName: "safari.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#6E25C4"))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .strokeBorder(Color(hex: "#6E25C4").opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityLabel(NSLocalizedString("switch_to_discover_accessibility", comment: "Switch to discover accessibility label"))
    }
}

// MARK: - Legacy TacticalHeaderView (kept for compatibility)

struct TacticalHeaderView: View {
    @Binding var showNewChatSheet: Bool
    @Binding var showProfilerWheel: Bool
    @EnvironmentObject var chatModel: ChatModel
    @ObservedObject private var popCoordinator = ChatPopCoordinator.shared
    @ObservedObject private var threatState = NeedleThreatState.shared
    @State private var showExtractions = false
    var onSwitchToProfileTab: (() -> Void)? = nil
    var onSwitchToMesh: (() -> Void)? = nil
    var onSwitchToDiscover: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            PXProfilerAvatar(showProfilerWheel: $showProfilerWheel, onSwitchToProfileTab: onSwitchToProfileTab)
            Spacer()
            BrandTitleView()
            Spacer()
            HStack(spacing: 8) {
                MeshButton(onSwitchToMesh: onSwitchToMesh)
                DiscoverButton(onSwitchToDiscover: onSwitchToDiscover)
                HeaderNeedlePinView()
                QuickActionButton(showNewChatSheet: $showNewChatSheet)
            }
        }
        .padding(.horizontal, 4)
    }
}
