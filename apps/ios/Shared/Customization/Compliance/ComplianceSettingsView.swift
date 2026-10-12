// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import Foundation
import UIKit
import UserNotifications
import POPOPXSwitch

// MARK: - Compliance Settings View

struct ComplianceSettingsView: View {
    @ObservedObject private var manager = ComplianceManager.shared

    @State private var showDeleteConfirmation = false
    @State private var showExportFormatPicker = false
    @State private var selectedExportFormat: DataExportRequest.ExportFormat = .json

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                complianceScoreSection
                dataRetentionInfoSection
                consentManagementSection
                dataExportSection
                dataDeletionSection
            }
            .padding()
        }
        .background(QuantumColors.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("Compliance", comment: "navigation title for compliance settings"))
        .alert(NSLocalizedString("Delete All Data", comment: "alert title for data deletion"), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("Cancel", comment: "cancel action"), role: .cancel) {}
            Button(NSLocalizedString("Delete Everything", comment: "destructive action to delete all data"), role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text(NSLocalizedString("This will permanently delete all consent records, export requests, and associated data. This action cannot be undone.", comment: "data deletion confirmation message"))
        }
        .alert(NSLocalizedString("Error", comment: "error alert title"), isPresented: Binding(
            get: { erasureError != nil },
            set: { if !$0 { erasureError = nil } }
        )) {
            Button(NSLocalizedString("compliance_ok", comment: "OK button to dismiss error alert")) { erasureError = nil }
        } message: {
            Text(erasureError ?? "")
        }
        .confirmationDialog(NSLocalizedString("Export Format", comment: "export format picker title"), isPresented: $showExportFormatPicker) {
            ForEach(DataExportRequest.ExportFormat.allCases, id: \.self) { format in
                Button(localizedExportFormat(format)) {
                    selectedExportFormat = format
                    requestExport()
                }
            }
            Button(NSLocalizedString("Cancel", comment: "cancel action"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Choose export format", comment: "export format dialog message"))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(QuantumColors.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("Compliance", comment: "compliance section header"))
                        .font(QuantumFonts.headerTitle)
                        .foregroundColor(QuantumColors.textPrimary)
                    Text(NSLocalizedString("Data management & privacy tools", comment: "compliance section subtitle"))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                }
                Spacer()
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    // MARK: - Compliance Score

    @ViewBuilder
    private var complianceScoreSection: some View {
        let score = manager.complianceScore()
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gauge.medium")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("Compliance Score", comment: "compliance score section header"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(QuantumColors.surface, lineWidth: 8)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(
                            scoreColor(for: score),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: score)

                    Text(LocalizedStringKey("\(score)"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(scoreColor(for: score))
                }

                VStack(alignment: .leading, spacing: 6) {
                    scoreDetailRow(icon: "lock.shield", text: NSLocalizedString("Consents granted", comment: "compliance score detail"), value: "\(manager.consentRecords.filter { $0.granted }.count)/\(manager.consentRecords.count)")
                    scoreDetailRow(icon: "clock", text: NSLocalizedString("Retention", comment: "compliance score detail"), value: "\(manager.dataRetentionDays)d")
                    scoreDetailRow(icon: "trash", text: NSLocalizedString("Auto-delete", comment: "compliance score detail"), value: manager.autoDeleteEnabled ? NSLocalizedString("On", comment: "auto-delete on state") : NSLocalizedString("Off", comment: "auto-delete off state"))
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 75 { return QuantumColors.success }
        if score >= 50 { return QuantumColors.warning }
        return QuantumColors.error
    }

    private func scoreDetailRow(icon: String, text: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(QuantumColors.textTertiary)
            Text(text)
                .font(QuantumFonts.caption)
                .foregroundColor(QuantumColors.textSecondary)
            Spacer()
            Text(value)
                .font(QuantumFonts.caption.weight(.semibold))
                .foregroundColor(QuantumColors.textPrimary)
        }
    }

    // MARK: - Data Retention Policy

    private var dataRetentionInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("Data Retention Policy", comment: "data retention section header"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            Text(LocalizedStringKey(String(format: NSLocalizedString("compliance_data_retention_desc", comment: "Data retention policy description"), manager.dataRetentionDays)))
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    // MARK: - Consent Management

    private var consentManagementSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("Consent Management", comment: "consent management section header"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            ForEach(manager.consentRecords) { record in
                consentRow(record)
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func consentRow(_ record: ConsentRecord) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(record.granted ? QuantumColors.success : QuantumColors.textTertiary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.purpose)
                    .font(QuantumFonts.body.weight(.medium))
                    .foregroundColor(QuantumColors.textPrimary)
                Text(record.description)
                    .font(QuantumFonts.caption)
                    .foregroundColor(QuantumColors.textSecondary)
                    .lineLimit(2)

                if let date = record.grantedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(String(format: NSLocalizedString("compliance_granted_format", comment: ""), date.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(QuantumColors.success.opacity(0.8))
                } else if let date = record.revokedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.caption2)
                        Text(String(format: NSLocalizedString("compliance_revoked_format", comment: ""), date.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(QuantumColors.error.opacity(0.8))
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { record.granted },
                set: { newValue in
                    manager.updateConsent(id: record.id, granted: newValue)
                }
            ))
            .toggleStyle(.switch)
            .tint(QuantumColors.accent)
            .labelsHidden()
            .accessibilityLabel(String(format: NSLocalizedString("Toggle consent for %@", comment: "compliance consent toggle accessibility"), record.purpose))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(QuantumColors.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(record.granted ? QuantumColors.success.opacity(0.2) : QuantumColors.textTertiary.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Data Export

    private var dataExportSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundColor(QuantumColors.accent)
                Text(NSLocalizedString("Data Export", comment: "data export section header"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            Button(action: {
                showExportFormatPicker = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text(NSLocalizedString("Request Export", comment: "button to request data export"))
                }
                .font(QuantumFonts.body.weight(.semibold))
                .foregroundColor(QuantumColors.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(QuantumColors.accent)
                )
            }
            .accessibilityLabel(NSLocalizedString("Request data export", comment: "accessibility label for export button"))

            if manager.exportRequests.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundColor(QuantumColors.textTertiary)
                    Text(NSLocalizedString("No export requests yet", comment: "empty state for export list"))
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(manager.exportRequests) { request in
                    exportRequestRow(request)
                }
            }
        }
        .padding()
        .glassBackground(cornerRadius: 16)
    }

    private func exportRequestRow(_ request: DataExportRequest) -> some View {
        HStack(spacing: 12) {
            exportStatusIcon(request.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedExportFormatLabel(request.format))
                    .font(QuantumFonts.body.weight(.medium))
                    .foregroundColor(QuantumColors.textPrimary)

                HStack(spacing: 8) {
                    Text(request.requestedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)

                    Text(request.dataCategories.joined(separator: ", "))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(localizedExportStatus(request.status))
                .font(QuantumFonts.caption.weight(.semibold))
                .foregroundColor(exportStatusColor(request.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(exportStatusColor(request.status).opacity(0.15))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(QuantumColors.surface.opacity(0.6))
        )
    }

    private func exportStatusIcon(_ status: DataExportRequest.ExportStatus) -> some View {
        Group {
            switch status {
            case .pending:
                ProgressView()
                    .tint(QuantumColors.warning)
                    .frame(width: 24, height: 24)
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(QuantumColors.success)
            case .expired:
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 20))
                    .foregroundColor(QuantumColors.textTertiary)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(QuantumColors.success)
            }
        }
    }

    private func exportStatusColor(_ status: DataExportRequest.ExportStatus) -> Color {
        switch status {
        case .pending: return QuantumColors.warning
        case .ready: return QuantumColors.success
        case .expired: return QuantumColors.textTertiary
        case .completed: return QuantumColors.success
        }
    }

    private func localizedExportFormat(_ format: DataExportRequest.ExportFormat) -> String {
        switch format {
        case .json: return NSLocalizedString("compliance_format_json", comment: "")
        case .csv: return NSLocalizedString("compliance_format_csv", comment: "")
        case .archive: return NSLocalizedString("compliance_format_archive", comment: "")
        }
    }

    private func localizedExportFormatLabel(_ format: DataExportRequest.ExportFormat) -> String {
        String(format: NSLocalizedString("compliance_format_export", comment: ""), localizedExportFormat(format))
    }

    private func localizedExportStatus(_ status: DataExportRequest.ExportStatus) -> String {
        switch status {
        case .pending: return NSLocalizedString("compliance_status_processing", comment: "")
        case .ready: return NSLocalizedString("compliance_status_ready", comment: "")
        case .expired: return NSLocalizedString("compliance_status_expired", comment: "")
        case .completed: return NSLocalizedString("compliance_status_completed", comment: "")
        }
    }

    // MARK: - Data Deletion

    private var dataDeletionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(QuantumColors.error)
                Text(NSLocalizedString("Data Deletion", comment: "data deletion section header"))
                    .font(QuantumFonts.sectionHeader)
                    .foregroundColor(QuantumColors.textPrimary)
                Spacer()
            }

            Text(NSLocalizedString("Permanently delete all consent records, export history, and associated personal data. This action cannot be reversed.", comment: "data deletion description"))
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)

            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text(NSLocalizedString("Delete All My Data", comment: "button to delete all personal data"))
                }
                .font(QuantumFonts.body.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(QuantumColors.error)
                )
            }
            .accessibilityLabel(NSLocalizedString("Delete all personal data", comment: "accessibility label for delete all data button"))
        }
        .padding()
        .glassBackground(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(QuantumColors.error.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func requestExport() {
        let categories = manager.consentRecords
            .filter { $0.granted }
            .map { $0.purpose }
        let exportCategories = categories.isEmpty ? [NSLocalizedString("popopx_compliance_all_data", comment: "all data category")] : categories
        manager.requestDataExport(categories: exportCategories, format: selectedExportFormat)
    }

    @State private var erasureError: String?
    @State private var isDeleting = false

    private func deleteAllData() {
        isDeleting = true
        manager.consentRecords.removeAll()
        manager.exportRequests.removeAll()
        manager.rightToErasureRequested = true

        let m = ChatModel.shared

        Task {
            do {
                _ = try await ServerAPI.shared.post("compliance/erasure", body: ["request": "full_erasure"])

                while m.ctrlInitInProgress {
                    try await Task.sleep(nanoseconds: 50_000000)
                }

                if m.chatRunning == true {
                    try await stopChatAsync()
                }
                if m.chatInitialized {
                    ffiQueue.sync { chatCloseStore() }
                }

                ServerAPI.clearAuthToken()
                _ = kcAppPassword.remove()
                _ = kcSelfDestructPassword.remove()
                EntitlementStore.shared.resetTrial()
                _ = kcDatabaseSalt.remove()

                deleteAppDatabaseAndFiles()

                m.chatId = nil
                ItemsModel.shared.reversedChatItems = []
                ItemsModel.shared.chatState.clear()
                ChatModel.shared.secondaryIM?.reversedChatItems = []
                ChatModel.shared.secondaryIM?.chatState.clear()
                m.updateChats([])
                m.users = []

                groupDefaults.removePersistentDomain(forName: APP_GROUP_NAME)
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")

                await NtfManager.shared.removeAllNotifications()
                UIApplication.shared.unregisterForRemoteNotifications()

                m.chatDbChanged = true
                m.chatInitialized = false
                resetChatCtrl()

                try await initializeChat(start: true)
                m.chatDbChanged = false

                if m.currentUser == nil && m.chatInitialized {
                    m.currentUser = try apiCreateActiveUser(
                        Profile(displayName: NSLocalizedString("User", comment: "default display name after erasure"), fullName: ""),
                        pastTimestamp: true
                    )
                    advanceOnboarding(to: .step1_WelcomeIdentity)
                    try startChat()
                }
            } catch {
                await MainActor.run {
                    erasureError = String(format: NSLocalizedString("popopx_compliance_erasure_error", comment: "data erasure error message"), error.localizedDescription)
                }
            }
            await MainActor.run {
                isDeleting = false
            }
        }
    }
}
