// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/12-FEATURE-ENCRYPTED-DOCS.md
import SwiftUI

@MainActor
private final class EphemeralCountdown: ObservableObject {
    @Published var remainingTime: TimeInterval
    @Published var progress: Double
    @Published var isDestroyed: Bool
    private let expiresAt: Date
    private let totalLifespan: TimeInterval
    private var timer: Timer?

    init(expiresAt: Date, createdAt: Date) {
        self.expiresAt = expiresAt
        self.totalLifespan = expiresAt.timeIntervalSince(createdAt)
        let now = Date()
        self.remainingTime = max(0, expiresAt.timeIntervalSince(now))
        self.progress = totalLifespan > 0 ? max(0, expiresAt.timeIntervalSince(now) / totalLifespan) : 0
        self.isDestroyed = now >= expiresAt
    }

    deinit { timer?.invalidate() }

    func start() {
        guard !isDestroyed else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                if now >= self.expiresAt {
                    self.remainingTime = 0
                    self.progress = 0
                    self.isDestroyed = true
                    self.stop()
                } else {
                    self.remainingTime = self.expiresAt.timeIntervalSince(now)
                    self.progress = self.totalLifespan > 0 ? self.remainingTime / self.totalLifespan : 0
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct EphemeralFileView: View {
    let fileName: String
    let expiresAt: Date
    let fileData: Data?
    var onOpen: (() -> Void)? = nil

    @StateObject private var countdown: EphemeralCountdown

    init(fileName: String, expiresAt: Date, createdAt: Date = Date(), fileData: Data? = nil, onOpen: (() -> Void)? = nil) {
        self.fileName = fileName
        self.expiresAt = expiresAt
        self.fileData = fileData
        self.onOpen = onOpen
        self._countdown = StateObject(wrappedValue: EphemeralCountdown(expiresAt: expiresAt, createdAt: createdAt))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            warningIcon

            fileInfoSection

            countdownSection

            progressBarSection

            actionButton

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { countdown.start() }
        .onDisappear { countdown.stop() }
        .popopxBranded()
    }

    private var warningIcon: some View {
        ZStack {
            Circle()
                .fill(QuantumColors.warning.opacity(0.15))
                .frame(width: 96, height: 96)

            Image(systemName: countdown.isDestroyed ? "xmark.bin.fill" : "flame.fill")
                .font(.system(size: 40))
                .foregroundColor(countdown.isDestroyed ? QuantumColors.error : QuantumColors.warning)
        }
    }

    private var fileInfoSection: some View {
        VStack(spacing: 8) {
            Text(fileName)
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(NSLocalizedString("ephemeral_self_destruct", comment: "Warning that the file will self-destruct"))
                .font(QuantumFonts.body)
                .fontWeight(.semibold)
                .foregroundColor(countdown.isDestroyed ? QuantumColors.error : QuantumColors.warning)
        }
    }

    private var countdownSection: some View {
        VStack(spacing: 4) {
            if countdown.isDestroyed {
                Text(NSLocalizedString("ephemeral_destroyed_label", comment: "Label shown when ephemeral file has been destroyed"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(QuantumColors.error)
            } else {
                Text(formatCountdown(countdown.remainingTime))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(countdown.remainingTime < 60 ? QuantumColors.error : QuantumColors.warning)
                    .animation(.easeInOut(duration: 0.3), value: countdown.remainingTime)

                Text(NSLocalizedString("ephemeral_remaining", comment: "Label indicating remaining time"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }
        }
    }

    private var progressBarSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .glassBackground()
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: progressColor,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * countdown.progress, height: 8)
                        .animation(.linear(duration: 1), value: countdown.progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text(NSLocalizedString("ephemeral_created", comment: "Label for file creation date"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
                Spacer()
                Text(NSLocalizedString("ephemeral_expiry", comment: "Label for file expiry date"))
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private var actionButton: some View {
        Button(action: {
            if !countdown.isDestroyed {
                onOpen?()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: countdown.isDestroyed ? "trash.fill" : "eye.fill")
                Text(countdown.isDestroyed
                    ? NSLocalizedString("ephemeral_file_destroyed", comment: "ephemeral file destroyed button label")
                    : NSLocalizedString("ephemeral_file_open_preview", comment: "ephemeral file open/preview button label"))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(countdown.isDestroyed ? QuantumColors.textSecondary : QuantumColors.textPrimary)
            .padding(.vertical, 14)
            .padding(.horizontal, 32)
            .glassButtonStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        countdown.isDestroyed ? QuantumColors.error.opacity(0.3) : QuantumColors.accent.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .disabled(countdown.isDestroyed)
    }

    private var progressColor: [Color] {
        if countdown.progress > 0.5 {
            return [QuantumColors.encryptionEnhanced, QuantumColors.success]
        } else if countdown.progress > 0.2 {
            return [QuantumColors.warning, QuantumColors.accentWarm]
        } else {
            return [QuantumColors.error, QuantumColors.accentWarm]
        }
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
