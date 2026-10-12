//
//  PXMailComposer.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 01.05.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import UIKit
import MessageUI

// MARK: - POPOPX Mail Configuration
private enum PXMailConfig {
    static let defaultIsHTML = true
    static let componentIdentifier = "PX_MAIL_VIEW"
}

/// SwiftUI wrapper for MFMailComposeViewController.
/// Handles mail composition with subject and HTML body support.
struct PXMailComposer: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?
    var subject = ""
    var messageBody = ""

    // MARK: - Coordinator

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isShowing: Bool
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(isShowing: Binding<Bool>,
             result: Binding<Result<MFMailComposeResult, Error>?>) {
            _isShowing = isShowing
            _result = result
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            defer { isShowing = false }
            guard let composeError = error else {
                self.result = .success(result)
                return
            }
            self.result = .failure(composeError)
        }
    }

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(isShowing: $isShowing, result: $result)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<PXMailComposer>) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        return pxApplyConfiguration(composer, context: context)
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<PXMailComposer>) {
        // No dynamic updates needed; composer is configured once at creation.
    }

    // MARK: - POPOPX Configuration

    private func pxApplyConfiguration(_ composer: MFMailComposeViewController,
                                      context: UIViewControllerRepresentableContext<PXMailComposer>) -> MFMailComposeViewController {
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: PXMailConfig.defaultIsHTML)
        composer.mailComposeDelegate = context.coordinator
        composer.view.accessibilityIdentifier = PXMailConfig.componentIdentifier
        return composer
    }
}

// MARK: - POPOPX Component Identity
extension PXMailComposer {
    var pxComponentTag: String { PXMailConfig.componentIdentifier }

    /// Whether the mail composer is currently presented
    var pxIsPresented: Bool { isShowing }
}
