//
//  SkeletonView.swift
//  POPOPX
//
//  Skeleton loading placeholders for better UX during data loading.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - Skeleton View Component

struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = DesignTokens.cornerRadiusMedium
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase = 0.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.25),
                        Color.gray.opacity(0.15)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: reduceMotion ? 0 : geometry.size.width * (phase - 0.5))
                    .animation(
                        reduceMotion ? nil :
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                    .onAppear {
                        if !reduceMotion && scenePhase == .active && !powerMode.isLowPowerMode {
                            phase = 1.0
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase != .active || powerMode.isLowPowerMode {
                            phase = 0.0
                        } else if !reduceMotion {
                            phase = 1.0
                        }
                    }
                }
            )
            .clipped()
            .accessibilityHidden(true)
        .popopxBranded()
    }
}

// MARK: - Chat List Skeleton

struct ChatListSkeletonView: View {
    var body: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            ForEach(0..<6) { index in
                HStack(spacing: DesignTokens.spacingMD) {
                    // Profile image placeholder
                    SkeletonView(width: 48, height: 48, cornerRadius: 24)
                    
                    // Text content placeholders
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(height: 16)
                        SkeletonView(width: 200, height: 14)
                    }
                    
                    Spacer()
                    
                    // Timestamp placeholder
                    SkeletonView(width: 40, height: 14)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
            }
        }
    }
}

// MARK: - Preview

struct SkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SkeletonView(height: 50)
                .previewLayout(.fixed(width: 300, height: 50))
            
            ChatListSkeletonView()
                .previewLayout(.sizeThatFits)
        }
    }
}
