// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import POPOPXSwitch

struct PrivacyChoiceView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("onboarding_notification_mode") private var notificationModeRaw: String = NotificationsMode.instant.rawValue

    @State private var showServerOperators = false
    @State private var operators: [ServerOperator] = []
    @State private var selectedOperatorIds = Set<Int64>()
    @State private var operatorsLoading = false
    @State private var operatorsLoaded = false

    private var notificationMode: NotificationsMode {
        get { NotificationsMode(rawValue: notificationModeRaw) ?? .instant }
        set { notificationModeRaw = newValue.rawValue }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy First")
                            .font(QuantumFonts.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Your privacy, your choice")
                            .font(QuantumFonts.body)
                            .foregroundColor(QuantumColors.textSecondary)
                    }

                    // Notification Mode Card
                    privacyCard(
                        icon: "bell.badge",
                        title: "Notifications",
                        description: "Choose when to receive notifications"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            notificationOption(
                                mode: .instant,
                                title: "Instant",
                                description: "Notify immediately for all messages"
                            )

                            notificationOption(
                                mode: .periodic,
                                title: "Periodic",
                                description: "Check for messages periodically"
                            )

                            notificationOption(
                                mode: .off,
                                title: "Off",
                                description: "No notifications, check manually"
                            )
                        }
                    }

                    // Server Operators Card
                    privacyCard(
                        icon: "server.rack",
                        title: "Server Operators",
                        description: "Choose who operates your servers"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            if operatorsLoaded && !operators.isEmpty {
                                ForEach(operators) { op in
                                    serverOperatorRow(op)
                                }
                            } else if operatorsLoading {
                                HStack {
                                    ProgressView()
                                    Text("Loading operators...")
                                        .font(QuantumFonts.callout)
                                        .foregroundColor(QuantumColors.textSecondary)
                                }
                            } else {
                                Button("Select Operators") {
                                    showServerOperators = true
                                }
                                .font(QuantumFonts.bodySemibold)
                                .foregroundColor(QuantumColors.accent)
                            }
                        }
                    }

                    // Privacy Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Built-in Privacy")
                            .font(QuantumFonts.sectionHeader)
                            .foregroundColor(QuantumColors.textPrimary)

                        privacyFeature(
                            icon: "lock.shield.fill",
                            title: "End-to-End Encrypted",
                            description: "All messages encrypted by default"
                        )

                        privacyFeature(
                            icon: "eye.slash.fill",
                            title: "No Metadata",
                            description: "We don't track who you talk to"
                        )

                        privacyFeature(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "No Phone Number",
                            description: "Create profile without personal info"
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(QuantumColors.background.ignoresSafeArea())

            // Continue Button
            VStack {
                Spacer()
                continueButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            if !operatorsLoaded {
                operatorsLoaded = true
                operators = ChatModel.shared.conditions.serverOperators
                selectedOperatorIds = Set(operators.filter { $0.enabled }.map { $0.operatorId })
                if operators.isEmpty {
                    loadOperators()
                }
            }
        }
        .onChange(of: notificationModeRaw) { _, newValue in
            ChatModel.shared.notificationMode = NotificationsMode(rawValue: newValue) ?? .instant
        }
    }

    // MARK: - Components

    private func privacyCard<Content: View>(
        icon: String,
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(QuantumColors.accent.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(QuantumFonts.sectionHeader)
                        .foregroundColor(QuantumColors.textPrimary)

                    Text(description)
                        .font(QuantumFonts.callout)
                        .foregroundColor(QuantumColors.textSecondary)
                }
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(QuantumColors.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private func notificationOption(mode: NotificationsMode, title: String, description: String) -> some View {
        Button {
            notificationModeRaw = mode.rawValue
        } label: {
            HStack(spacing: 12) {
                Image(systemName: notificationMode == mode ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(notificationMode == mode ? QuantumColors.accent : QuantumColors.textTertiary)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(QuantumFonts.bodySemibold)
                        .foregroundColor(QuantumColors.textPrimary)

                    Text(description)
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func serverOperatorRow(_ op: ServerOperator) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(QuantumColors.accent)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(op.tradeName)
                    .font(QuantumFonts.body)
                    .foregroundColor(QuantumColors.textPrimary)

                Text(op.serverDomains.first ?? "")
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func privacyFeature(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(QuantumColors.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(QuantumFonts.bodySemibold)
                    .foregroundColor(QuantumColors.textPrimary)

                Text(description)
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
            }

            Spacer()
        }
    }

    private var continueButton: some View {
        Button {
            advanceToNextStage()
        } label: {
            Text("Continue")
                .font(QuantumFonts.bodySemibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [QuantumColors.accent, QuantumColors.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func advanceToNextStage() {
        advanceOnboarding(to: .step4_GetStarted)
    }

    private func loadOperators() {
        operatorsLoading = true
        Task {
            do {
                let conditions = try await apiGetServerOperators()
                await MainActor.run {
                    operators = conditions.serverOperators
                    selectedOperatorIds = Set(operators.filter { $0.enabled }.map { $0.operatorId })
                    operatorsLoading = false
                }
            } catch {
                await MainActor.run {
                    operatorsLoading = false
                }
            }
        }
    }
}

#Preview {
    PrivacyChoiceView()
        .environmentObject(ChatModel())
        .environmentObject(AppTheme.shared)
}
