// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import Combine

@MainActor
class ScreenshotDefenseManager: ObservableObject {
    static let shared = ScreenshotDefenseManager()

    @Published var isDefended = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.triggerDefense()
            }
            .store(in: &cancellables)
    }

    private func triggerDefense() {
        isDefended = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.isDefended = false
            }
        }
    }
}

struct ScreenshotDefenseOverlay: View {
    @ObservedObject var manager = ScreenshotDefenseManager.shared

    var body: some View {
        if manager.isDefended {
            Color.black
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(9999)
        }
    }
}

// MARK: - POPOPX
extension ScreenshotDefenseManager {
    static let pxComponentTag: String = "PX_SCREENSHOT_DEFENSE"
}
