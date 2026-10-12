//
//  ScanProtocolServer.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 19/11/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/architecture.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import AVFoundation
import POPOPXSwitch
import CodeScanner

// MARK: - POPOPX Layout Config
private enum PXScanServerConfig {
    static let cornerRadius: CGFloat = 10
    static let titleVerticalPadding: CGFloat = 8
    static let titleSize: CGFloat = 28
    static let titleWeight: Font.Weight = .semibold
    static let minScaleFactor: CGFloat = 0.6
    static let scannerAspectRatio: CGFloat = 1.0
    static let qrCodeTypes = [AVMetadataObject.ObjectType.qr]
}

// MARK: - POPOPX View Model
private struct PXScanServerViewModel {
    let titleText: String
    let titleColor: Color

    var pxTitleAttributes: some ViewModifier { PXScanTitleModifier() }
}

private struct PXScanTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: PXScanServerConfig.titleSize, weight: PXScanServerConfig.titleWeight))
            .minimumScaleFactor(PXScanServerConfig.minScaleFactor)
            .bold()
    }
}

struct ScanProtocolServer: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @Binding var userServers: [UserOperatorServers]
    @Binding var serverErrors: [UserServersError]
    @Binding var serverWarnings: [UserServersWarning]

    var body: some View {
        pxMainLayout
    }

    // MARK: - POPOPX View Builders

    @ViewBuilder
    private var pxMainLayout: some View {
        VStack(alignment: .leading) {
            pxTitleView
            pxScannerView
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(ThemedBackground(grouped: true))
        .accessibilityElement(children: .contain)
        .popopxBranded()
    }

    @ViewBuilder
    private var pxTitleView: some View {
        Text(NSLocalizedString("scan_server_qr_title", comment: "Scan server QR code title"))
            .font(.system(size: PXScanServerConfig.titleSize, weight: PXScanServerConfig.titleWeight))
            .minimumScaleFactor(PXScanServerConfig.minScaleFactor)
            .bold()
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : .primary)
            .padding(.vertical, PXScanServerConfig.titleVerticalPadding)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var pxScannerView: some View {
        CodeScannerView(codeTypes: PXScanServerConfig.qrCodeTypes, scanMode: .oncePerCode, completion: processQRCode)
            .aspectRatio(PXScanServerConfig.scannerAspectRatio, contentMode: .fit)
            .cornerRadius(PXScanServerConfig.cornerRadius)
            .padding(.top)
            .accessibilityLabel(Text(NSLocalizedString("a11y_qr_scanner_server_address", comment: "")))
    }

    func processQRCode(_ resp: Result<ScanResult, ScanError>) {
        switch resp {
        case let .success(r):
            var server: UserServer = .empty
            server.server = r.string
            addServer(server, $userServers, $serverErrors, $serverWarnings, dismiss)
        case let .failure(e):
            logger.error("ScanProtocolServer.processQRCode QR code error: \(e.localizedDescription)")
            dismiss()
        }
    }
}

// MARK: - POPOPX
extension ScanProtocolServer {
    /// Unique POPOPX component tag for analytics and diffing
    var pxComponentTag: String { "PX_SCAN_PROTOCOL_SERVER" }

    /// POPOPX scanner aspect ratio
    var pxScannerAspectRatio: CGFloat { PXScanServerConfig.scannerAspectRatio }

    /// POPOPX accent for scanner border
    var pxScannerBorderColor: Color { isInDarkTheme() ? darkThemeAccentColor().opacity(0.3) : .gray.opacity(0.2) }

    /// POPOPX scanner corner style
    var pxScannerCornerRadius: CGFloat { PXScanServerConfig.cornerRadius }
}

struct ScanProtocolServer_Previews: PreviewProvider {
    static var previews: some View {
        ScanProtocolServer(
            userServers: Binding.constant([UserOperatorServers.sampleDataNilOperator]),
            serverErrors: Binding.constant([]),
            serverWarnings: Binding.constant([])
        )
    }
}
