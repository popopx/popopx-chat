//
//  DismissSheets.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 04/08/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import Foundation
import UIKit

// MARK: - POPOPX Configuration

private enum PXSheetDismissConfig {
    static let componentTag: String = "PX_DISMISS_SHEETS"
    static let fallbackActivationState: UIScene.ActivationState = .foregroundInactive
}

// MARK: - POPOPX Window Resolution

// https://github.com/fatbobman/SheetKit/blob/main/Sources/SheetKit/SheetKit.swift
private func pxKeyWindow() -> UIWindow? {
    let connectedScenes = UIApplication.shared.connectedScenes
    var scene = connectedScenes
        .filter { $0.activationState == .foregroundActive }
        .first { $0 is UIWindowScene } as? UIWindowScene
    // Fall back to foregroundInactive if no active scene (happens during UI transitions)
    if scene == nil {
        scene = connectedScenes
            .filter { $0.activationState == PXSheetDismissConfig.fallbackActivationState }
            .first { $0 is UIWindowScene } as? UIWindowScene
    }
    return scene?.windows
        .filter { $0.isKeyWindow }.first
}

// MARK: - Public API

func dismissAllSheets(animated flag: Bool = true, completion: (() -> Void)? = nil) {
    guard let rootController = pxKeyWindow()?.rootViewController else {
        completion?()
        return
    }
    rootController.dismiss(animated: flag, completion: completion)
}

// MARK: - POPOPX Component Tag

extension NSObject {
    @objc var pxSheetDismissTag: String { PXSheetDismissConfig.componentTag }
}
