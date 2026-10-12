//
//  PXVerifyCodeView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 10/12/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI

// MARK: - POPOPX Configuration
private enum PXVerifyCodeConfig {
    static let codePartLength: Int = 24
    static let codeLineLimit: Int = 20
    static let scanNavTitle: String = "Scan code"
    static let errorTitleKey: String = "Incorrect security code!"
    static let qrSmallMode: Bool = true
    static let codeFontStyle: Font = .body
    static let shareIconName: String = "square.and.arrow.up"
    static let verifiedIconName: String = "checkmark.shield"
    static let scanIconName: String = "qrcode"
    static let markVerifiedIconName: String = "checkmark.shield"
    static let clearVerificationIconName: String = "shield"
}

@MainActor
private struct PXVerifyCodeViewModel {
    let displayName: String
    let connectionCode: String?
    let connectionVerified: Bool

    var formattedCode: String {
        guard let code = connectionCode else { return "" }
        return pxSplitToParts(code, length: PXVerifyCodeConfig.codePartLength)
    }

    var statusText: String {
        connectionVerified
            ? "\(displayName) is verified"
            : "\(displayName) is not verified"
    }

    var isShowingVerified: Bool { connectionVerified }

    private func pxSplitToParts(_ s: String, length: Int) -> String {
        if length >= s.count { return s }
        return (0 ... (s.count - 1) / length)
            .map { s.dropFirst($0 * length).prefix(length) }
            .joined(separator: "\n")
    }
}

struct VerifyCodeView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    var displayName: String
    @State var connectionCode: String?
    @State var connectionVerified: Bool
    var verify: (String?) -> (Bool, String)?
    var verificationText: LocalizedStringKey? = nil
    @State private var showCodeError = false

    private var vm: PXVerifyCodeViewModel {
        PXVerifyCodeViewModel(
            displayName: displayName,
            connectionCode: connectionCode,
            connectionVerified: connectionVerified
        )
    }

    var body: some View {
        Group {
            if let code = connectionCode {
                pxVerifyCodeContent(code)
            }
        }
        .popopxBranded()
    }

    // MARK: - View Builders

    @ViewBuilder
    private func pxVerifyCodeContent(_ code: String) -> some View {
        let splitCode = vm.formattedCode
        let _ = logger.debug("VerifyCodeView.pxVerifyCodeContent — codeLength=\(code.count), verified=\(connectionVerified)")
        List {
            pxCodeDisplaySection(code, splitCode: splitCode)
            pxVerificationActionsSection(code, splitCode: splitCode)
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showShareSheet(items: [splitCode])
                } label: {
                    Image(systemName: PXVerifyCodeConfig.shareIconName)
                        .accessibilityLabel(Text(NSLocalizedString("Share security code", comment: "Accessibility label for share button")))
                }
            }
        }
        .onChange(of: connectionVerified) { _, _ in
            if connectionVerified { dismiss() }
        }
    }

    @ViewBuilder
    private func pxCodeDisplaySection(_ code: String, splitCode: String) -> some View {
        Section {
            QRCode(uri: code, small: PXVerifyCodeConfig.qrSmallMode)

            Text(splitCode)
                .multilineTextAlignment(.leading)
                .font(PXVerifyCodeConfig.codeFontStyle)
                .lineLimit(PXVerifyCodeConfig.codeLineLimit)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(Text(NSLocalizedString("Security code digits", comment: "Accessibility label for verification code text")))
        } header: {
            pxVerificationStatusHeader
        } footer: {
            Text(verificationText ?? LocalizedStringKey("To verify end-to-end encryption with your contact compare (or scan) the code on your devices."))
                .foregroundColor(theme.colors.secondary)
        }
    }

    @ViewBuilder
    private var pxVerificationStatusHeader: some View {
        if connectionVerified {
            HStack {
                Image(systemName: PXVerifyCodeConfig.verifiedIconName)
                    .foregroundColor(theme.colors.secondary)
                Text(String(localized: "\(displayName) is verified", comment: "Verification status when contact's security code has been verified"))
                    .textCase(.none)
            }
            .accessibilityLabel(Text(NSLocalizedString("Contact is verified", comment: "Accessibility label for verified status")))
        } else {
            Text(String(localized: "\(displayName) is not verified", comment: "Verification status when contact's security code has not been verified"))
                .textCase(.none)
                .accessibilityLabel(Text(NSLocalizedString("Contact is not verified", comment: "Accessibility label for unverified status")))
        }
    }

    @ViewBuilder
    private func pxVerificationActionsSection(_ code: String, splitCode: String) -> some View {
        Section {
            if connectionVerified {
                pxClearVerificationButton
            } else {
                pxScanAndVerifyButtons(code)
            }
        }
    }

    @ViewBuilder
    private var pxClearVerificationButton: some View {
        Button {
            pxVerifyCode(nil)
        } label: {
            Label(String(localized: "Clear verification", comment: "Button to clear/reset verification status"), systemImage: PXVerifyCodeConfig.clearVerificationIconName)
        }
        .accessibilityLabel(Text(NSLocalizedString("Clear verification status", comment: "Accessibility label for clear verification")))
    }

    @ViewBuilder
    private func pxScanAndVerifyButtons(_ code: String) -> some View {
        NavigationLink {
            ScanCodeView(connectionVerified: $connectionVerified, verify: verify)
                .navigationBarTitleDisplayMode(.large)
                .navigationTitle(NSLocalizedString(PXVerifyCodeConfig.scanNavTitle, comment: "Navigation title for QR code scanning screen"))
                .modifier(ThemedBackground())
        } label: {
            Label(String(localized: "Scan code", comment: "Button to open QR code scanner"), systemImage: PXVerifyCodeConfig.scanIconName)
        }
        .accessibilityLabel(Text(NSLocalizedString("Scan QR code", comment: "Accessibility label for scan button")))

        Button {
            pxVerifyCode(code) { verified in
                if !verified { showCodeError = true }
            }
        } label: {
            Label(String(localized: "Mark verified", comment: "Button to manually mark security code as verified"), systemImage: PXVerifyCodeConfig.markVerifiedIconName)
        }
        .accessibilityLabel(Text(NSLocalizedString("Mark as verified", comment: "Accessibility label for mark verified button")))
        .alert(isPresented: $showCodeError) {
            Alert(title: Text(NSLocalizedString(PXVerifyCodeConfig.errorTitleKey, comment: "Error message when entered security code doesn't match")))
        }
    }

    // MARK: - Verification Logic

    private func pxVerifyCode(_ code: String?, _ cb: ((Bool) -> Void)? = nil) {
        logger.debug("VerifyCodeView.pxVerifyCode — code=\(code != nil ? "present" : "nil")")
        if let (verified, existingCode) = verify(code) {
            connectionVerified = verified
            connectionCode = existingCode
            cb?(verified)
        }
    }
}

struct VerifyCodeView_Previews: PreviewProvider {
    static var previews: some View {
        VerifyCodeView(displayName: "alice", connectionCode: "12345 67890 12345 67890", connectionVerified: false, verify: {_ in nil})
            .environmentObject(CurrentColors.toAppTheme())
    }
}

// MARK: - POPOPX
extension VerifyCodeView {
    var pxComponentTag: String { "px-verify-code" }
    var pxVerificationBadge: String {
        "checkmark.shield.fill"
    }
    var pxCodeLengthPart: Int { PXVerifyCodeConfig.codePartLength }
    var pxIsVerified: Bool { connectionVerified }
    var pxContactName: String { displayName }
}
