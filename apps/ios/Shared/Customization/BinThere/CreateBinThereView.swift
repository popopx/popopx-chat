// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

//
//  CreateBinThereView.swift
//  POPOPX (iOS)
//
//  Compose sheet for creating a burn-after-read message.
//  Supports text and image content. Encrypts locally, stores ciphertext via Bot, sends marker to chat.
//

import CryptoKit
import OSLog
import PhotosUI
import SwiftUI

struct CreateBinThereView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss

    var onSend: (String) -> Void

    @State private var plaintext: String = ""
    @State private var selectedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var sending: Bool = false
    @State private var errorMsg: String?

    private var canSend: Bool {
        guard !sending else { return false }
        if selectedImage != nil { return true }
        return !plaintext.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundStyle(QuantumColors.accent.gradient)
                    Text(NSLocalizedString("Burn-after-read message", comment: ""))
                        .font(.title3).bold()
                    Text(NSLocalizedString("Encrypted locally. Destroyed after reading.", comment: ""))
                        .font(.footnote)
                        .foregroundColor(theme.colors.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassCard(tint: QuantumColors.accent)

                if selectedImage != nil {
                    imagePreviewCard
                } else {
                    textEditorCard
                }

                HStack(spacing: 12) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedImage != nil ? "photo.badge.checkmark" : "photo")
                            Text(selectedImage != nil
                                 ? NSLocalizedString("Change Image", comment: "")
                                 : NSLocalizedString("Add Image", comment: ""))
                        }
                        .font(.subheadline)
                        .foregroundColor(QuantumColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(QuantumColors.accent.opacity(0.12))
                        )
                    }

                    if selectedImage != nil {
                        Button {
                            selectedImage = nil
                            pickerItem = nil
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text(NSLocalizedString("Remove Image", comment: ""))
                            }
                            .font(.subheadline)
                            .foregroundColor(QuantumColors.error)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(QuantumColors.error.opacity(0.12))
                            )
                        }
                    }
                }

                if let errorMsg {
                    Text(errorMsg)
                        .font(.footnote)
                        .foregroundColor(QuantumColors.error)
                }

                GradientButton(
                    title: LocalizedStringKey(NSLocalizedString("Encrypt & Send", comment: "")),
                    systemImage: "paperplane.fill",
                    gradient: LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    disabled: !canSend
                ) {
                    Task { await encryptAndSend() }
                }
            }
            .padding()
            .modifier(ThemedBackground(grouped: true))
            .navigationTitle(NSLocalizedString("New Burn Note", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }
        }
        .popopxBranded()
    }

    private var textEditorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Secret message", comment: ""))
                .font(.subheadline)
                .foregroundColor(theme.colors.secondary)
            TextEditor(text: $plaintext)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
        }
        .padding()
        .glassCard()
    }

    private var imagePreviewCard: some View {
        VStack(spacing: 8) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text(NSLocalizedString("Image will be encrypted and destroyed after reading", comment: ""))
                .font(.footnote)
                .foregroundColor(theme.colors.secondary)
        }
        .padding()
        .glassCard()
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                errorMsg = NSLocalizedString("Failed to load image", comment: "")
                return
            }
            selectedImage = image
            errorMsg = nil
        } catch {
            os_log(.error, "CreateBinThere loadImage: %{public}@", error.localizedDescription)
            errorMsg = NSLocalizedString("Failed to load image", comment: "")
        }
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1920
        let maxBytes = 1_000_000
        let absoluteMaxBytes = 2_000_000

        var working = image
        if max(image.size.width, image.size.height) > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            if let resized = renderer.image(actions: { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }) as UIImage? {
                working = resized
            }
        }

        var quality: CGFloat = 0.9
        while quality >= 0.3 {
            if let data = working.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }

        guard let fallback = working.jpegData(compressionQuality: 0.3) else { return nil }
        if fallback.count <= absoluteMaxBytes { return fallback }
        return nil
    }

    private func encryptAndSend() async {
        sending = true
        errorMsg = nil

        if let image = selectedImage {
            await encryptAndSendImage(image)
        } else {
            await encryptAndSendText()
        }
    }

    private func encryptAndSendText() async {
        let text = plaintext.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let data = text.data(using: .utf8) else {
            errorMsg = NSLocalizedString("Empty message", comment: "")
            sending = false
            return
        }

        do {
            let key = BinThereCrypto.generateCEK()
            let combined = try BinThereCrypto.encrypt(plaintext: data, key: key)
            let ciphertextB64 = combined.base64EncodedString()

            let pasteId = try await BinThereClient.shared.storePaste(ciphertextB64: ciphertextB64)
            let keyB64 = BinThereCrypto.exportKey(key)

            var info = BinThereInfo(pid: pasteId, key: keyB64, bot: "")
            info.contentType = "text"
            let marker = encodeBinThereMessage(info)

            onSend(marker)
            dismiss()
        } catch {
            os_log(.error, "CreateBinThere text: %{public}@", error.localizedDescription)
            errorMsg = error.localizedDescription
            sending = false
        }
    }

    private func encryptAndSendImage(_ image: UIImage) async {
        guard let imageData = compressImage(image) else {
            errorMsg = NSLocalizedString("Image too large — please select a smaller image (max 2MB after compression)", comment: "")
            sending = false
            return
        }

        do {
            let key = BinThereCrypto.generateCEK()
            let combined = try BinThereCrypto.encrypt(plaintext: imageData, key: key)
            let ciphertextB64 = combined.base64EncodedString()

            let pasteId = try await BinThereClient.shared.storePaste(ciphertextB64: ciphertextB64)
            let keyB64 = BinThereCrypto.exportKey(key)

            var info = BinThereInfo(pid: pasteId, key: keyB64, bot: "")
            info.contentType = "image"
            info.imageWidth = image.size.width
            info.imageHeight = image.size.height
            let marker = encodeBinThereMessage(info)

            onSend(marker)
            dismiss()
        } catch {
            os_log(.error, "CreateBinThere image: %{public}@", error.localizedDescription)
            errorMsg = error.localizedDescription
            sending = false
        }
    }
}
