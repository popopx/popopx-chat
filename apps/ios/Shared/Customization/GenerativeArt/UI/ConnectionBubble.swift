// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

struct ConnectionBubbleView: View {
    let connectionLink: String
    let bubbleSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var powerMode = PowerModeObserver.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPickedUp = false
    @State private var dragOffset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var showShareSheet = false

    private let palette: [Color] = [
        Color(hex: "#00FFFF"),
        Color(hex: "#8B5CF6"),
        Color(hex: "#FF00FF"),
        Color(hex: "#818CF8")
    ]

    var body: some View {
        ZStack {
            iridescentSphere

            VStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: bubbleSize * 0.2, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Text("POPOPX")
                    .font(.system(size: bubbleSize * 0.1, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: bubbleSize, height: bubbleSize)
        .clipShape(Circle())
        .shadow(color: Color(hex: "#8B5CF6").opacity(0.3), radius: 8, x: 0, y: 4)
        .offset(dragOffset)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(isPickedUp ? 1.15 : 1.0)
        .gesture(throwGesture)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [connectionLink])
        }
        .animation(.spring(response: 0.3), value: isPickedUp)
        .accessibilityLabel(String(localized: "Connection link"))
        .accessibilityHint(String(localized: "Long-press and throw to share. Double-tap to copy."))
        .accessibilityAddTraits(.isButton)
        .popopxBranded()
    }

    private var iridescentSphere: some View {
        Group {
            if reduceMotion {
                staticGradient
            } else {
                animatedGradient
            }
        }
    }

    private var animatedGradient: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 2.0, paused: powerMode.isLowPowerMode || scenePhase != .active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(t * 40)

            Circle()
                .fill(
                    AngularGradient(
                        colors: palette + [palette[0]],
                        center: .center,
                        angle: angle
                    )
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.35, y: 0.3),
                                startRadius: 0,
                                endRadius: bubbleSize * 0.4
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        }
    }

    private var staticGradient: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: palette + [palette[0]],
                    center: .center
                )
            )
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: bubbleSize * 0.4
                        )
                    )
            )
    }

    private var throwGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                isPickedUp = true
                BubbleHapticsManager.shared.popAuto()
            }
            .sequenced(before: DragGesture())
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    dragOffset = drag.translation
                    rotation = Double(drag.translation.width / bubbleSize) * 15
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    let distance = sqrt(
                        drag.translation.width * drag.translation.width +
                        drag.translation.height * drag.translation.height
                    )
                    if distance > bubbleSize * 0.5 {
                        launchBubble(velocity: drag.translation)
                    } else {
                        resetBubble()
                    }
                default:
                    resetBubble()
                }
            }
    }

    private func launchBubble(velocity: CGSize) {
        BubbleHapticsManager.shared.popManual()
        withAnimation(.easeOut(duration: 0.4)) {
            dragOffset = CGSize(
                width: velocity.width * 3,
                height: velocity.height * 3 - 200
            )
            rotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showShareSheet = true
            resetBubble()
        }
    }

    private func resetBubble() {
        isPickedUp = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            dragOffset = .zero
            rotation = 0
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - POPOPX
extension ConnectionBubbleView {
    static let pxComponentTag: String = "PX_CONNECTION_BUBBLE"
    static let pxDefaultSize: CGFloat = 80
}
