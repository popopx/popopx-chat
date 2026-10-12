//
//  PXScanCodeView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 10/12/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import CodeScanner

struct ScanCodeView: View {
    // MARK: - POPOPX constants
    private static let pxScannerCorner: CGFloat = 10
    private static let pxOverlayOpacity: Double = 0.4
    private static let pxShadowRadius: CGFloat = 8
    private static let pxShadowYOffset: CGFloat = 4
    private static let pxDarkBorderOpacity: Double = 0.2

    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var connectionVerified: Bool
    var verify: (String?) async -> (Bool, String)?
    @State private var showCodeError = false

    var body: some View {
        VStack(alignment: .leading) {
            CodeScannerView(codeTypes: [.qr], scanMode: .oncePerCode, completion: processQRCode)
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(Self.pxScannerCorner)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.pxScannerCorner)
                        .strokeBorder(
                            isInDarkTheme() ? darkThemeAccentColor().opacity(Self.pxOverlayOpacity) : theme.colors.background.opacity(Self.pxDarkBorderOpacity),
                            lineWidth: 1
                        )
                )
                .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : .clear, radius: Self.pxShadowRadius, x: 0, y: Self.pxShadowYOffset)
            Text(NSLocalizedString("compose_scan_security_code", comment: "Instructions to scan contact's security code"))
                .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert(isPresented: $showCodeError) {
            Alert(title: Text(NSLocalizedString("compose_incorrect_security_code", comment: "Alert title for incorrect security code")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .popopxBranded()
    }

    func processQRCode(_ resp: Result<ScanResult, ScanError>) {
        let outcomeLabel: String = { if case .success = resp { return "success" } else { return "failure" } }()
        logger.debug("ScanCodeView.processQRCode — result: \(outcomeLabel)")
        switch resp {
        case let .success(r):
            Task {
                if let (ok, _) = await verify(r.string) {
                    await MainActor.run {
                        connectionVerified = ok
                        if ok {
                            dismiss()
                        } else {
                            showCodeError = true
                        }
                    }
                }
            }
        case let .failure(e):
            logger.error("ScanCodeView.processQRCode QR code error: \(e.localizedDescription)")
            dismiss()
        }
    }
}

struct ScanCodeView_Previews: PreviewProvider {
    static var previews: some View {
        ScanCodeView(connectionVerified: Binding.constant(true), verify: {_ in nil})
    }
}

// MARK: - POPOPX
extension ScanCodeView {
    var pxComponentTag: String { "px-scan-code" }
    private var pxScanHaptic: UIImpactFeedbackGenerator {
        UIImpactFeedbackGenerator(style: .medium)
    }
    var pxScannerCornerValue: CGFloat { Self.pxScannerCorner }
    var pxIsScanning: Bool { !showCodeError }
}
