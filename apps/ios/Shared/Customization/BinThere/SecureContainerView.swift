// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  SecureContainerView.swift
//  POPOPX (iOS)
//
//  Anti-screenshot / anti-screen-recording container.
//  Uses the UITextField isSecureTextEntry hardware-level secure canvas
//  (_UITextLayoutCanvasView) to black out protected content in screenshots,
//  screen recordings, AirPlay mirrors, and app-switcher previews.
//
//  Based on the technique used by ScreenShieldKit / ScreenProtectorKit.
//

import UIKit
import SwiftUI
import os

private let secLogger = Logger(subsystem: "im.popopx", category: "SecureContainer")

// MARK: - Secure Container (UIKit)

class SecureContainerView: UIView {

    private let secureTextField = UITextField()
    private var secureCanvas: UIView?
    private var blackoutOverlay: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSecureField()
        registerLifecycleObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSecureField()
        registerLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupSecureField() {
        backgroundColor = .black

        secureTextField.isSecureTextEntry = true
        secureTextField.isUserInteractionEnabled = false
        secureTextField.autocorrectionType = .no
        secureTextField.keyboardType = .default
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(secureTextField)

        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyBlackout),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(removeBlackout),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    @objc private func applyBlackout() {
        if blackoutOverlay == nil {
            let overlay = UIView()
            overlay.backgroundColor = .black
            overlay.translatesAutoresizingMaskIntoConstraints = false
            addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: topAnchor),
                overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
                overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            blackoutOverlay = overlay
        }
    }

    @objc private func removeBlackout() {
        blackoutOverlay?.removeFromSuperview()
        blackoutOverlay = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if secureCanvas == nil {
            findSecureCanvas()
        }
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.debugVerify()
        }
        #endif
    }

    /// Mount a content view into the hardware secure canvas.
    /// In screenshots / recordings / AirPlay the canvas is zeroed (black);
    /// on the physical screen the content renders normally.
    func protect(contentView: UIView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false

        if secureCanvas == nil { findSecureCanvas() }

        let host = secureCanvas ?? self
        host.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: host.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
        ])
    }

    /// Debug: logs the view hierarchy to verify canvas discovery.
    func debugVerify() {
        #if DEBUG
        let canvasFound = secureCanvas != nil
        let canvasType = secureCanvas.map { String(describing: type(of: $0)) } ?? "nil"
        secLogger.debug("canvas found: \(canvasFound), type: \(canvasType)")
        secLogger.debug("hierarchy:")
        printHierarchy(self, indent: 0)
        #endif
    }

    #if DEBUG
    private func printHierarchy(_ view: UIView, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let typeName = String(describing: type(of: view))
        let frameStr = "(\(view.frame.origin.x), \(view.frame.origin.y), \(view.frame.size.width), \(view.frame.size.height))"
        secLogger.debug("\(prefix)\(typeName) frame=\(frameStr)")
        for sub in view.subviews {
            printHierarchy(sub, indent: indent + 1)
        }
    }
    #endif

    private func findSecureCanvas() {
        secureTextField.layoutIfNeeded()

        if let canvas = locateCanvas(in: secureTextField) {
            secureCanvas = canvas
            #if DEBUG
            secLogger.debug("canvas found immediately: \(String(describing: type(of: canvas)))")
            #endif
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.secureCanvas == nil else { return }
            if let canvas = self.locateCanvas(in: self.secureTextField) {
                self.secureCanvas = canvas
                #if DEBUG
                secLogger.debug("canvas found (deferred): \(String(describing: type(of: canvas)))")
                #endif
            } else {
                #if DEBUG
                secLogger.debug("WARNING: secure canvas not found — content falls back to direct mounting")
                self.dumpViewTree()
                #endif
            }
        }
    }

    private func locateCanvas(in view: UIView) -> UIView? {
        for sub in view.subviews {
            let typeName = String(describing: type(of: sub))
            if typeName.contains("Canvas") || typeName.contains("LayoutCanvas") {
                return sub
            }
        }
        return deepFindCanvas(in: view)
    }

    private func deepFindCanvas(in view: UIView) -> UIView? {
        for sub in view.subviews {
            let typeName = String(describing: type(of: sub))
            if typeName.contains("Canvas") || typeName.contains("LayoutCanvas") {
                return sub
            }
            if let found = deepFindCanvas(in: sub) {
                return found
            }
        }
        return nil
    }

    #if DEBUG
    private func dumpViewTree() {
        secLogger.debug("full view tree of UITextField:")
        printHierarchy(secureTextField, indent: 1)
    }
    #endif
}
