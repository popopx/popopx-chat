// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  CIBinThereView.swift
//  POPOPX (iOS)
//
//  Chat bubble card for a burn-after-read message.
//  Tap to fetch ciphertext from Bot, decrypt locally, and reveal.
//  Supports both text and image content types.
//

import OSLog
import POPOPXSwitch
import SwiftUI

struct CIBinThereView: View {
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    var info: BinThereInfo
    var maxWidth: CGFloat = .infinity

    @State private var showConfirm = false
    @State private var showReveal = false
    @State private var showImageReveal = false
    @State private var loading = false
    @State private var revealed = false
    @State private var persistedConsumed = false
    @State private var errorMsg: String?
    @State private var revealedText: String?
    @State private var revealedImageData: Data?

    private var isSent: Bool { chatItem.chatDir.sent }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: contentIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contentTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    if revealed {
                        Text(persistedConsumed ? NSLocalizedString("Already destroyed", comment: "") : NSLocalizedString("Revealed", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text(NSLocalizedString("Tap to reveal", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }

            if loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("Fetching...", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            if let errorMsg {
                Text(errorMsg)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(14)
        .frame(maxWidth: maxWidth == .infinity ? 260 : maxWidth, alignment: .leading)
        .background(
            LinearGradient(
                colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { handleTap() }
        .onAppear {
            if BinThereConsumed.isConsumed(info.pid) {
                revealed = true
                persistedConsumed = true
            }
        }
        .confirmationDialog(
            NSLocalizedString("Reveal this message?", comment: ""),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Reveal & Destroy", comment: "")) {
                Task { await fetchAndReveal() }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("It will be permanently destroyed after reading.", comment: ""))
        }
        .fullScreenCover(isPresented: $showReveal) {
            if let plaintext = revealedText {
                BinThereRevealView(text: plaintext) {
                    revealedText = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showImageReveal) {
            if let imageData = revealedImageData {
                BinThereImageRevealView(imageData: imageData) {
                    revealedImageData = nil
                }
            }
        }
        .popopxBranded()
    }

    private var contentIcon: String {
        if info.isImage {
            return revealed ? "photo.fill" : "photo"
        }
        return revealed ? "lock.open.fill" : "lock.fill"
    }

    private var contentTitle: String {
        if info.isImage {
            return NSLocalizedString("Burn-after-read image", comment: "")
        }
        return NSLocalizedString("Burn-after-read message", comment: "")
    }

    private func handleTap() {
        guard !loading, !revealed else { return }
        if isSent { return }
        if BinThereConsumed.isConsumed(info.pid) {
            revealed = true
            persistedConsumed = true
            return
        }
        showConfirm = true
    }

    private func fetchAndReveal() async {
        loading = true
        errorMsg = nil

        do {
            let combined = try await BinThereClient.shared.fetchPaste(pasteId: info.pid)

            guard let key = BinThereCrypto.importKey(info.key) else {
                throw BinThereError.keyImportFailed
            }

            let decrypted = try BinThereCrypto.decrypt(combined: combined, key: key)

            if info.isImage {
                revealedImageData = decrypted
                revealed = true
                BinThereConsumed.markConsumed(info.pid)
                Task { await BinThereClient.shared.burnPaste(pasteId: info.pid) }
                showImageReveal = true
            } else {
                guard let text = String(data: decrypted, encoding: .utf8) else {
                    throw BinThereError.decryptionFailed
                }
                revealedText = text
                revealed = true
                BinThereConsumed.markConsumed(info.pid)
                Task { await BinThereClient.shared.burnPaste(pasteId: info.pid) }
                showReveal = true
            }
        } catch {
            os_log(.error, "CIBinThere: %{public}@", error.localizedDescription)
            if let btErr = error as? BinThereError {
                switch btErr {
                case .pasteGone:
                    errorMsg = NSLocalizedString("Already destroyed or expired", comment: "")
                case .botTimeout:
                    errorMsg = NSLocalizedString("Bot did not respond", comment: "")
                case .decryptionFailed:
                    errorMsg = NSLocalizedString("Decryption failed", comment: "")
                default:
                    errorMsg = btErr.localizedDescription
                }
            } else {
                errorMsg = error.localizedDescription
            }
        }

        loading = false
    }
}
