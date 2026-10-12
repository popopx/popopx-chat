// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

struct NeedleBubbleGuardModifier: ViewModifier {
    let messageText: String
    let chatItemId: ChatItem.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var needlePhase: NeedlePhase = .idle
    @State private var showPop = false
    @State private var needleWorkItems: [DispatchWorkItem] = []

    enum NeedlePhase {
        case idle
        case approaching
        case piercing
        case retracting
    }

    func body(content: Content) -> some View {
        content
            .overlay(needleOverlay)
            .overlay(popOverlay)
            .onAppear {
                checkForSensitiveContent()
            }
            .onDisappear {
                needleWorkItems.forEach { $0.cancel() }
            }
    }

    @ViewBuilder
    private var needleOverlay: some View {
        if needlePhase != .idle && !reduceMotion {
            Image(systemName: "needle")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(white: 0.75))
                .shadow(color: Color(red: 0.55, green: 0.36, blue: 0.96, opacity: 0.5), radius: 3)
                .offset(needleOffset)
                .rotationEffect(.degrees(needleRotation))
                .opacity(needleOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var needleOffset: CGSize {
        switch needlePhase {
        case .idle: return CGSize(width: 60, height: -60)
        case .approaching: return CGSize(width: 20, height: -20)
        case .piercing: return .zero
        case .retracting: return CGSize(width: -40, height: -40)
        }
    }

    private var needleRotation: Double {
        switch needlePhase {
        case .idle: return -45
        case .approaching: return -30
        case .piercing: return 0
        case .retracting: return 15
        }
    }

    private var needleOpacity: Double {
        switch needlePhase {
        case .idle: return 0
        case .approaching: return 0.8
        case .piercing: return 1.0
        case .retracting: return 0.5
        }
    }

    @ViewBuilder
    private var popOverlay: some View {
        if showPop {
            BubblePopExplosion(
                startDate: Date(),
                puncturePoint: CGPoint(x: 40, y: 40),
                bubbleSize: CGSize(width: 200, height: 60),
                particleCount: 200,
                onCompletion: nil
            )
            .accessibilityHidden(true)
        }
    }

    private func checkForSensitiveContent() {
        let patterns = NeedleBubbleGuardModifier.sensitivePatterns
        let detected = patterns.contains { pattern in
            messageText.range(of: pattern, options: .regularExpression) != nil
        }

        if detected {
            triggerNeedleAnimation()
            NeedleThreatState.shared.trigger()
        }
    }

    private func triggerNeedleAnimation() {
        withAnimation(.easeIn(duration: 0.3)) {
            needlePhase = .approaching
        }

        let workItem1 = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.15)) {
                self.needlePhase = .piercing
            }
            BubbleHapticsManager.shared.popAuto()
        }
        needleWorkItems.append(workItem1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem1)

        let workItem2 = DispatchWorkItem {
            self.showPop = true
            BubbleHapticsManager.shared.popManual()
        }
        needleWorkItems.append(workItem2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem2)

        let workItem3 = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.2)) {
                self.needlePhase = .retracting
            }
        }
        needleWorkItems.append(workItem3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem3)

        let workItem4 = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                self.needlePhase = .idle
            }
        }
        needleWorkItems.append(workItem4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem4)

        let workItem5 = DispatchWorkItem {
            self.showPop = false
        }
        needleWorkItems.append(workItem5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: workItem5)
    }

    static let sensitivePatterns: [String] = [
        "\\b\\d{11}\\b",
        "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b",
        "\\b\\d{17}[\\dXx]\\b",
        "\\b\\d{16,19}\\b"
    ]
}

extension View {
    func needleBubbleGuard(messageText: String, chatItemId: ChatItem.ID) -> some View {
        modifier(NeedleBubbleGuardModifier(messageText: messageText, chatItemId: chatItemId))
    }
}

// MARK: - POPOPX
extension NeedleBubbleGuardModifier {
    static let pxComponentTag: String = "PX_NEEDLE_BUBBLE_GUARD"
}
