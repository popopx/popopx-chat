//
//  ShareViewController.swift
//  POPOPX SE
//
//  Created by Levitating Pineapple on 08/07/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import UIKit
import SwiftUI
import POPOPXSwitch

/// Extension Entry point
/// System will create this controller each time share sheet is invoked
/// using `NSExtensionPrincipalClass` in the info.plist
@objc(ShareViewController)
class ShareViewController: UIHostingController<ShareView> {
    private let model = ShareModel()
    // Assuming iOS continues to only allow single share sheet to be presented at once
    static var isVisible: Bool = false

    @objc init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(rootView: ShareView(model: model))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        logger.error("ShareViewController: init(coder:) is unavailable")
        return nil
    }

    override func viewDidLoad() {
        ShareModel.CompletionHandler.isEventLoopEnabled = false
        guard let context = extensionContext else {
            logger.error("ShareViewController: extensionContext is nil")
            return
        }
        model.setup(context: context)
    }

    override func viewWillAppear(_ animated: Bool) {
        logger.debug("ShareSheet will appear")
        super.viewWillAppear(animated)
        Self.isVisible = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        logger.debug("ShareSheet will dissappear")
        super.viewWillDisappear(animated)
        ShareModel.CompletionHandler.isEventLoopEnabled = false
        Self.isVisible = false
    }
}
