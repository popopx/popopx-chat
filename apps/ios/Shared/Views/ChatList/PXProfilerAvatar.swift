//
//  PXProfilerAvatar.swift
//  POPOPX
//
//  Standalone profiler avatar with revolver cylinder rotation
//  and identity wheel. Long-press to open identity selector.
//  Copyright © 2026 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct PXProfilerAvatar: View {
    @EnvironmentObject var chatModel: ChatModel
    @Binding var showProfilerWheel: Bool
    var onSwitchToProfileTab: (() -> Void)? = nil

    @State private var revolverAngle: Double = 0

    var body: some View {
        let currentUser = chatModel.currentUser

        avatarCircle(currentUser: currentUser)
            .frame(width: 36, height: 36)
    }

    private func avatarCircle(currentUser: User?) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 36, height: 36)

            Circle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 34, height: 34)

            if let imageStr = currentUser?.image {
                ProfileImage(imageStr: imageStr, size: 30)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .shadow(color: Color(hex: "#6E25C4").opacity(0.3), radius: 4, x: 0, y: 0)
        .rotation3DEffect(
            .degrees(revolverAngle),
            axis: (x: 0.2, y: 1, z: 0.1),
            perspective: 0.6
        )
        .contentShape(Circle())
        .accessibilityLabel(Text(currentUser?.displayName ?? String(localized: "Profile")))
        .accessibilityHint(String(localized: "Double-tap for profile. Long-press to switch identities."))
        .accessibilityAddTraits(.isButton)
        .gesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        showProfilerWheel = true
                        revolverAngle += 120
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    onSwitchToProfileTab?()
                }
        )
        .onChange(of: showProfilerWheel) { _, newValue in
            if !newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    revolverAngle = 0
                }
            }
        }
    }
}

// MARK: - Revolver Wheel View (rendered at NavigationStack level)

struct RevolverWheelView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var chatModel: ChatModel
    var onSwitchToProfileTab: (() -> Void)? = nil

    @State private var cylinderAngle: Double = 0
    @State private var showSwitchError: Bool = false

    private let wheelRadius: CGFloat = 80
    private let itemSize: CGFloat = 36

    var body: some View {
        let users = chatModel.users
        let totalItems = users.count + 1

        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissWheel()
                }

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: wheelRadius * 2 + itemSize + 20)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(hex: "#6E25C4").opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 4)

                ForEach(Array(users.enumerated()), id: \.element.user.userId) { index, userInfo in
                    let angle = angleFor(index: index, total: totalItems)
                    let isActive = chatModel.currentUser?.userId == userInfo.user.userId

                    profileItem(user: userInfo.user, isActive: isActive)
                        .offset(
                            x: cos(angle) * wheelRadius,
                            y: sin(angle) * wheelRadius
                        )
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                addButton
                    .offset(
                        x: cos(angleFor(index: users.count, total: totalItems)) * wheelRadius,
                        y: sin(angleFor(index: users.count, total: totalItems)) * wheelRadius
                    )
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
            .rotationEffect(.degrees(cylinderAngle))
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                cylinderAngle = 360
            }
        }
        .alert(NSLocalizedString("la_switch_profile_failed_title", comment: "Failed to switch profile alert title"), isPresented: $showSwitchError) {
            Button(NSLocalizedString("ok_button", comment: "OK button"), role: .cancel) {}
        }
    }

    private func angleFor(index: Int, total: Int) -> CGFloat {
        let step = (2 * .pi) / CGFloat(total)
        return -.pi / 2 + CGFloat(index) * step
    }

    private func dismissWheel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresented = false
            cylinderAngle = 0
        }
    }

    private func profileItem(user: User, isActive: Bool) -> some View {
        Button {
            Task {
                do {
                    try await changeActiveUserAsync_(user.userId, viewPwd: nil)
                    dismissWheel()
                } catch {
                    logger.error("Failed to switch to profile \(user.userId): \(error)")
                    showSwitchError = true
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: itemSize, height: itemSize)

                    if isActive {
                        Circle()
                            .stroke(Color(hex: "#00FFD2"), lineWidth: 2)
                            .frame(width: itemSize + 4, height: itemSize + 4)
                            .shadow(color: Color(hex: "#00FFD2").opacity(0.5), radius: 6)
                    } else {
                        Circle()
                            .strokeBorder(Color(hex: "#6E25C4").opacity(0.4), lineWidth: 1)
                            .frame(width: itemSize, height: itemSize)
                    }

                    if let imageStr = user.image {
                        ProfileImage(imageStr: imageStr, size: itemSize - 8)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#6E25C4"), Color(hex: "#00FFD2")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                Text(user.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 50)
            }
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            dismissWheel()
            onSwitchToProfileTab?()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: itemSize, height: itemSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(hex: "#6E25C4").opacity(0.4), lineWidth: 1)
                    )

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#6E25C4"))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - POPOPX
extension PXProfilerAvatar {
    static let pxComponentTag: String = "PX_PROFILER_AVATAR"
}
