//
//  PXMigrateFromDevice.swift
//  POPOPX (iOS)
//
//  Created by Avently on 14.02.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/database.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

private enum MigrationFromState: Equatable {
    case chatStopInProgress
    case chatStopFailed(reason: String)
    case passphraseNotSet
    case passphraseConfirmation
    case uploadConfirmation
    case archiving
    case uploadProgress(uploadedBytes: Int64, totalBytes: Int64, fileId: Int64, archivePath: URL, ctrl: chat_ctrl?)
    case uploadFailed(totalBytes: Int64, archivePath: URL)
    case linkCreation
    case linkShown(fileId: Int64, link: String, archivePath: URL, ctrl: chat_ctrl)
    case finished(chatDeletion: Bool)
}

private enum MigrateFromDeviceViewAlert: Identifiable {
    case finishMigration(_ fileId: Int64, _ ctrl: chat_ctrl)
    case deleteChat(_ title: LocalizedStringKey = "Delete chat profile?", _ text: LocalizedStringKey = "This action cannot be undone - your profile, contacts, messages and files will be irreversibly lost.")
    case startChat(_ title: LocalizedStringKey = "Start chat?", _ text: LocalizedStringKey = "Warning: starting chat on multiple devices is not supported and will cause message delivery failures")

    case wrongPassphrase(title: LocalizedStringKey = "Wrong passphrase!", message: LocalizedStringKey = "Enter correct passphrase.")
    case invalidConfirmation(title: LocalizedStringKey = "Invalid migration confirmation")
    case keychainError(_ title: LocalizedStringKey = "Keychain error")
    case databaseError(_ title: LocalizedStringKey = "Database error", message: String)
    case unknownError(_ title: LocalizedStringKey = "Unknown error", message: String)
    case archiveExportedWithErrors(archivePath: URL, archiveErrors: [ArchiveError])

    case error(title: LocalizedStringKey, error: String = "")

    var id: String {
        switch self {
        case .finishMigration: return "finishMigration"
        case let .deleteChat(title, text): return "\(title) \(text)"
        case let .startChat(title, text): return "\(title) \(text)"

        case .wrongPassphrase: return "wrongPassphrase"
        case .invalidConfirmation: return "invalidConfirmation"
        case .keychainError: return "keychainError"
        case let .databaseError(title, message): return "\(title) \(message)"
        case let .unknownError(title, message): return "\(title) \(message)"
        case let .archiveExportedWithErrors(path, _): return "archiveExportedWithErrors \(path)"

        case let .error(title, _): return "error \(title)"
        }
    }
}

// MARK: - POPOPX Configuration

private enum PXMigrateConfig {
    static let progressFontSize: CGFloat = 56
    static let circleLineWidth: CGFloat = 29
    static let keyboardDelay: Double = 1.2
    static let migrationTimeout: UInt64 = 5 * 60 * 1_000_000_000
    static let pollInterval: UInt64 = 7_500_000
    static let progressScaleEffect: CGFloat = 2.2
    static let warningSectionSpacing: CGFloat = 18
    static let qrCornerRadius: CGFloat = 11
    static let shareIconTopInset: CGFloat = -8
    static let sectionHeaderOpacity: Double = 0.9
    static let redirectDelay: Double = 0.5
    static let progressDescriptionFont: Font = .title3
    static let progressCircleRotation: Double = 180
    static let calloutFont: Font = .callout
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXMigrateViewModel {
    let migrationState: MigrationFromState

    var isBackDisabled: Bool {
        switch migrationState {
        case .chatStopInProgress, .archiving, .linkShown, .finished: return true
        default: return false
        }
    }

    var isUploading: Bool {
        if case .uploadProgress = migrationState { return true }
        return false
    }

    var isComplete: Bool {
        if case .finished = migrationState { return true }
        return false
    }

    var uploadProgress: (uploaded: Int64, total: Int64, fileId: Int64, archivePath: URL, ctrl: chat_ctrl?)? {
        if case let .uploadProgress(uploaded, total, fileId, path, ctrl) = migrationState {
            return (uploaded, total, fileId, path, ctrl)
        }
        return nil
    }

    var uploadFailure: (total: Int64, archivePath: URL)? {
        if case let .uploadFailed(total, path) = migrationState {
            return (total, path)
        }
        return nil
    }

    var linkInfo: (fileId: Int64, link: String, archivePath: URL, ctrl: chat_ctrl)? {
        if case let .linkShown(fileId, link, path, ctrl) = migrationState {
            return (fileId, link, path, ctrl)
        }
        return nil
    }
}

struct MigrateFromDevice: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var showProgressOnSettings: Bool
    @State private var migrationState: MigrationFromState = .chatStopInProgress
    @State private var useKeychain = storeDBPassphraseGroupDefault.get()
    @AppStorage(GROUP_DEFAULT_INITIAL_RANDOM_DB_PASSPHRASE, store: groupDefaults) private var initialRandomDBPassphrase: Bool = false
    @State private var alert: MigrateFromDeviceViewAlert?
    @State private var authorized = !UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)
    private let tempDatabaseUrl = urlForTemporaryDatabase()
    @State private var chatReceiver: MigrationChatReceiver? = nil
    @State private var backDisabled: Bool = false

    private var pxVM: PXMigrateViewModel {
        PXMigrateViewModel(migrationState: migrationState)
    }

    var body: some View {
        Group {
        if authorized {
            migrateView()
        } else {
            Button(action: runAuth) { Label(NSLocalizedString("unlock_button", comment: "Unlock button label"), systemImage: "lock") }
                .onAppear(perform: runAuth)
        }
        }
        .popopxBranded()
    }

    private func runAuth() { authorize(NSLocalizedString("Open migration to another device", comment: "authentication reason"), $authorized) }

    func migrateView() -> some View {
        VStack {
            switch migrationState {
            case .chatStopInProgress:
                pxChatStopInProgress
            case let .chatStopFailed(reason):
                chatStopFailedView(reason)
            case .passphraseNotSet:
                passphraseNotSetView()
            case .passphraseConfirmation:
                PassphraseConfirmationView(migrationState: $migrationState, alert: $alert)
            case .uploadConfirmation:
                uploadConfirmationView()
            case .archiving:
                pxArchiving
            case let .uploadProgress(uploaded, total, _, archivePath, _):
                uploadProgressView(uploaded, totalBytes: total, archivePath)
            case let .uploadFailed(total, archivePath):
                uploadFailedView(totalBytes: total, archivePath)
            case .linkCreation:
                pxLinkCreation
            case let .linkShown(fileId, link, archivePath, ctrl):
                linkShownView(fileId, link, archivePath, ctrl)
            case let .finished(chatDeletion):
                finishedView(chatDeletion)
            }
        }
        .onChange(of: migrationState) {_,  state in
            backDisabled = pxVM.isBackDisabled
        }
        .onAppear {
            stopChat()
        }
        .onDisappear {
            Task {
                if !backDisabled {
                    await MainActor.run {
                        showProgressOnSettings = true
                    }
                    await startChatAndDismiss(false)
                    await MainActor.run {
                        showProgressOnSettings = false
                    }
                }
                if case let .uploadProgress(_, _, fileId, _, ctrl) = migrationState, let ctrl {
                    await cancelUploadedArchive(fileId, ctrl)
                }
                chatReceiver?.stopAndCleanUp()
                try? FileManager.default.removeItem(at: getMigrationTempFilesDirectory())
            }
        }
        .alert(item: $alert) { alert in
            pxAlertBuilder(alert)
        }
        .interactiveDismissDisabled(backDisabled)
    }

    // MARK: - POPOPX extracted phase views

    private var pxChatStopInProgress: some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Stopping chat", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            pxProgressOverlay
        }
    }

    private var pxArchiving: some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Archiving database", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            pxProgressOverlay
        }
        .onAppear {
            exportArchive()
        }
    }

    private var pxLinkCreation: some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Creating archive link", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            pxProgressOverlay
        }
    }

    private var pxProgressOverlay: some View {
        VStack {
            ProgressView().scaleEffect(PXMigrateConfig.progressScaleEffect)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(Text(NSLocalizedString("a11y_processing", comment: "")))
    }

    private func chatStopFailedView(_ reason: String) -> some View {
        List {
            Section {
                Text(reason)
                Button(action: stopChat) {
                    settingsRow("stop.fill", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Stop chat", comment: "")).foregroundColor(QuantumColors.error)
                    }
                }
            } header: {
                Text(NSLocalizedString("Error stopping chat", comment: ""))
                    .foregroundColor(theme.colors.secondary)
            } footer: {
                Text(NSLocalizedString("In order to continue, chat should be stopped.", comment: ""))
                    .foregroundColor(theme.colors.secondary)
                    .font(PXMigrateConfig.calloutFont)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func passphraseNotSetView() -> some View {
        DatabaseEncryptionView(useKeychain: $useKeychain, migration: true, stopChatRunBlockStartChat: { _, _ in
        })
            .onChange(of: initialRandomDBPassphrase) {_,  initial in
                if !initial {
                    migrationState = .uploadConfirmation
                }
            }
    }

    private func uploadConfirmationView() -> some View {
        List {
            Section {
                Button(action: { migrationState = .archiving }) {
                    settingsRow("tray.and.arrow.up", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Archive and upload", comment: "")).foregroundColor(theme.colors.primary)
                    }
                }
            } header: {
                Text(NSLocalizedString("Confirm upload", comment: ""))
                    .foregroundColor(theme.colors.secondary)
            } footer: {
                Text(NSLocalizedString("All your contacts, conversations and files will be securely encrypted and uploaded in chunks to configured XFTP relays.", comment: ""))
                    .foregroundColor(theme.colors.secondary)
                    .font(PXMigrateConfig.calloutFont)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func uploadProgressView(_ uploadedBytes: Int64, totalBytes: Int64, _ archivePath: URL) -> some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Uploading archive", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            let ratio = Float(uploadedBytes) / Float(totalBytes)
            MigrateFromDevice.largeProgressView(ratio, "\(Int(ratio * 100))%", "\(ByteCountFormatter.string(fromByteCount: uploadedBytes, countStyle: .binary)) uploaded", theme.colors.primary)
        }
        .onAppear {
            startUploading(totalBytes, archivePath)
        }
    }

    private func uploadFailedView(totalBytes: Int64, _ archivePath: URL) -> some View {
        List {
            Section {
                Button(action: {
                    migrationState = .uploadProgress(uploadedBytes: 0, totalBytes: totalBytes, fileId: 0, archivePath: archivePath, ctrl: nil)
                }) {
                    settingsRow("tray.and.arrow.up", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Repeat upload", comment: "")).foregroundColor(theme.colors.primary)
                    }
                }
            } header: {
                Text(NSLocalizedString("Upload failed", comment: ""))
                    .foregroundColor(theme.colors.secondary)
            } footer: {
                Text(NSLocalizedString("You can give another try.", comment: ""))
                    .foregroundColor(theme.colors.secondary)
                    .font(PXMigrateConfig.calloutFont)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onAppear {
            chatReceiver?.stopAndCleanUp()
        }
    }

    private func linkShownView(_ fileId: Int64, _ link: String, _ archivePath: URL, _ ctrl: chat_ctrl) -> some View {
        List {
            Section {
                Button(action: { cancelMigration(fileId, ctrl) }) {
                    settingsRow("multiply", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Cancel migration", comment: "")).foregroundColor(QuantumColors.error)
                    }
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y_cancel_migration", comment: "")))
                Button(action: { alert = .finishMigration(fileId, ctrl) }) {
                    settingsRow("checkmark", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Finalize migration", comment: "")).foregroundColor(theme.colors.primary)
                    }
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y_finalize_migration", comment: "")))
            } footer: {
                VStack(alignment: .leading, spacing: PXMigrateConfig.warningSectionSpacing) {
                    Text(LocalizedStringKey(NSLocalizedString("migration_warning_archive_removed", comment: "")))
                    Text(LocalizedStringKey(NSLocalizedString("migration_choose_migrate_scan", comment: "")))
                }
                .foregroundColor(theme.colors.secondary)
                .font(PXMigrateConfig.calloutFont)
            }
            Section(header: Text(NSLocalizedString("Show QR code", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(PXMigrateConfig.sectionHeaderOpacity) : theme.colors.secondary)
                .textCase(.uppercase)) {
                PXContactLinkQRCode(uri: link)
                    .padding()
                    .glassBackground(cornerRadius: PXMigrateConfig.qrCornerRadius)
                    .padding(.horizontal)
                                .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            Section(header: Text(NSLocalizedString("Or securely share this file link", comment: ""))
                .font(.caption.weight(.bold))
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(PXMigrateConfig.sectionHeaderOpacity) : theme.colors.secondary)
                .textCase(.uppercase)) {
                shareLinkView(link)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 10))
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func finishedView(_ chatDeletion: Bool) -> some View {
        ZStack {
            List {
                Section {
                    Button(action: { alert = .startChat() }) {
                        settingsRow("play.fill", color: theme.colors.secondary) {
                            Text(NSLocalizedString("Start chat", comment: "")).foregroundColor(QuantumColors.error)
                        }
                    }
                    .accessibilityLabel(Text(NSLocalizedString("a11y_start_chat", comment: "")))
                    Button(action: { alert = .deleteChat() }) {
                        settingsRow("trash.fill", color: theme.colors.secondary) {
                            Text(NSLocalizedString("Delete database from this device", comment: "")).foregroundColor(theme.colors.primary)
                        }
                    }
                    .accessibilityLabel(Text(NSLocalizedString("a11y_delete_database", comment: "")))
                } header: {
                    Text(NSLocalizedString("Migration complete", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(PXMigrateConfig.sectionHeaderOpacity) : theme.colors.secondary)
                        .textCase(.uppercase)
                } footer: {
                    VStack(alignment: .leading, spacing: PXMigrateConfig.warningSectionSpacing) {
                        Text(LocalizedStringKey(NSLocalizedString("migration_must_not_two_devices", comment: "")))
                        Text(LocalizedStringKey(NSLocalizedString("migration_please_note_security", comment: "")))
                    }
                    .foregroundColor(theme.colors.secondary)
                    .font(PXMigrateConfig.calloutFont)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            if chatDeletion {
                pxProgressOverlay
            }
        }
    }

    private func shareLinkView(_ link: String) -> some View {
        HStack {
            linkTextView(link)
            Button {
                showShareSheet(items: [link])
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .padding(.top, PXMigrateConfig.shareIconTopInset)
            }
            .accessibilityLabel(Text(NSLocalizedString("a11y_share_link", comment: "")))
        }
        .frame(maxWidth: .infinity)
    }

    private func linkTextView(_ link: String) -> some View {
        Text(link)
            .lineLimit(1)
            .font(.caption)
            .truncationMode(.middle)
    }

    static func largeProgressView(_ value: Float, _ title: String, _ description: LocalizedStringKey, _ primaryColor: Color) -> some View {
        ZStack {
            VStack {
                Text(description)
                    .font(PXMigrateConfig.progressDescriptionFont)
                    .hidden()

                Text(title)
                    .font(.system(size: PXMigrateConfig.progressFontSize))
                    .bold()
                    .foregroundColor(primaryColor)

                Text(description)
                    .font(PXMigrateConfig.progressDescriptionFont)
            }

            Circle()
                .trim(from: 0, to: CGFloat(value))
                .stroke(
                    primaryColor,
                    style: StrokeStyle(lineWidth: PXMigrateConfig.circleLineWidth)
                )
                .rotationEffect(.degrees(PXMigrateConfig.progressCircleRotation))
                .animation(.linear, value: value)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - POPOPX alert builder

    private func pxAlertBuilder(_ alert: MigrateFromDeviceViewAlert) -> Alert {
        switch alert {
        case let .finishMigration(fileId, ctrl):
            return Alert(
                title: Text(NSLocalizedString("remove_archive_confirm_title", comment: "")),
                message: Text(NSLocalizedString("remove_archive_confirm_message", comment: "")),
                primaryButton: .destructive(Text(LocalizedStringKey("Continue"))) {
                    finishMigration(fileId, ctrl)
                },
                secondaryButton: .cancel()
            )
        case let .startChat(title, text):
            return Alert(
                title: Text(title),
                message: Text(text),
                primaryButton: .destructive(Text(LocalizedStringKey("Start chat"))) {
                    Task {
                        await startChatAndDismiss()
                    }
                },
                secondaryButton: .cancel()
            )
        case let .deleteChat(title, text):
            return Alert(
                title: Text(title),
                message: Text(text),
                primaryButton: .default(Text(LocalizedStringKey("Delete"))) {
                    deleteChatAndDismiss()
                },
                secondaryButton: .cancel()
            )
        case let .wrongPassphrase(title, message):
            return Alert(title: Text(title), message: Text(message))
        case let .invalidConfirmation(title):
            return Alert(title: Text(title))
        case let .keychainError(title):
            return Alert(title: Text(title))
        case let .databaseError(title, message):
            return Alert(title: Text(title), message: Text(message))
        case let .unknownError(title, message):
            return Alert(title: Text(title), message: Text(message))
        case let .archiveExportedWithErrors(archivePath, errs):
            return Alert(
                title: Text(NSLocalizedString("chat_database_exported", comment: "")),
                message: Text(NSLocalizedString("chat_database_exported_msg", comment: "")) + textNewLine + Text(NSLocalizedString("some_files_not_exported", comment: "")) + Text(archiveErrorsText(errs)),
                dismissButton: .default(Text(LocalizedStringKey("Continue"))) {
                    Task { await uploadArchive(path: archivePath) }
                }
            )
        case let .error(title, error):
            return Alert(title: Text(title), message: Text(error))
        }
    }

    private func stopChat() {
        Task {
            do {
                try await stopChatAsync()
                do {
                    try apiSaveAppSettings(settings: AppSettings.current.prepareForExport())
                    await MainActor.run {
                        migrationState = initialRandomDBPassphraseGroupDefault.get() ? .passphraseNotSet :  .passphraseConfirmation
                    }
                } catch let error {
                    alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_saving_settings", comment: "Error saving settings")), error: error.localizedDescription)
                    migrationState = .chatStopFailed(reason: NSLocalizedString("migration_error_saving_settings", comment: "when migrating"))
                }
            } catch let e {
                await MainActor.run {
                    migrationState = .chatStopFailed(reason: e.localizedDescription)
                }
            }
        }
    }

    private func exportArchive() {
        Task {
            do {
                try? FileManager.default.createDirectory(at: getMigrationTempFilesDirectory(), withIntermediateDirectories: true)
                let (archivePath, errs) = try await exportChatArchive(getMigrationTempFilesDirectory())
                if errs.isEmpty {
                    await uploadArchive(path: archivePath)
                } else {
                    await MainActor.run {
                        alert = .archiveExportedWithErrors(archivePath: archivePath, archiveErrors: errs)
                        migrationState = .uploadConfirmation
                    }
                }
            } catch let error {
                await MainActor.run {
                    alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_exporting_db", comment: "Error exporting chat database")), error: responseError(error))
                    migrationState = .uploadConfirmation
                }
            }
        }
    }

    private func uploadArchive(path archivePath: URL) async {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: archivePath.path),
            let totalBytes = attrs[.size] as? Int64 {
            await MainActor.run {
                migrationState = .uploadProgress(uploadedBytes: 0, totalBytes: totalBytes, fileId: 0, archivePath: archivePath, ctrl: nil)
            }
        } else {
            await MainActor.run {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_file_not_exist", comment: "Exported file doesn't exist")))
                migrationState = .uploadConfirmation
            }
        }
    }

    private func initTemporaryDatabase() -> (chat_ctrl, User)? {
        let (status, ctrl) = chatInitTemporaryDatabase(url: tempDatabaseUrl)
        showErrorOnMigrationIfNeeded(status, $alert)
        do {
            if let ctrl, let user = try startChatWithTemporaryDatabase(ctrl: ctrl) {
                return (ctrl, user)
            }
        } catch let error {
            logger.error("Error while starting chat in temporary database: \(error.localizedDescription)")
        }
        return nil
    }

    private func startUploading(_ totalBytes: Int64, _ archivePath: URL) {
        Task {
            guard let ctrlAndUser = initTemporaryDatabase() else {
                return migrationState = .uploadFailed(totalBytes: totalBytes, archivePath: archivePath)
            }
            let (ctrl, user) = ctrlAndUser
            chatReceiver = MigrationChatReceiver(ctrl: ctrl, databaseUrl: tempDatabaseUrl) { msg in
                await MainActor.run {
                    switch msg {
                    case let .result(.sndFileProgressXFTP(_, _, fileTransferMeta, sentSize, totalSize), _):
                        if case let .uploadProgress(uploaded, total, _, _, _) = migrationState, uploaded != total {
                            migrationState = .uploadProgress(uploadedBytes: sentSize, totalBytes: totalSize, fileId: fileTransferMeta.fileId, archivePath: archivePath, ctrl: ctrl)
                        }
                    case .result(.sndFileRedirectStartXFTP, _):
                        DispatchQueue.main.asyncAfter(deadline: .now() + PXMigrateConfig.redirectDelay) {
                            migrationState = .linkCreation
                        }
                    case let .result(.sndStandaloneFileComplete(_, fileTransferMeta, rcvURIs), _):
                        let cfg = getNetCfg()
                        let proxy: NetworkProxy? = if cfg.socksProxy == nil {
                            nil
                        } else {
                            networkProxyDefault.get()
                        }
                        let data = MigrationFileLinkData.init(
                            networkConfig: MigrationFileLinkData.NetworkConfig(
                                socksProxy: cfg.socksProxy,
                                networkProxy: proxy,
                                hostMode: cfg.hostMode,
                                requiredHostMode: cfg.requiredHostMode
                            )
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + PXMigrateConfig.redirectDelay) {
                            guard let firstUri = rcvURIs.first else { return }
                            migrationState = .linkShown(fileId: fileTransferMeta.fileId, link: data.addToLink(link: firstUri), archivePath: archivePath, ctrl: ctrl)
                        }
                    case .result(.sndFileError, _):
                        alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_upload_failed", comment: "Upload failed title")), error: NSLocalizedString("migration_check_internet", comment: "Check your internet connection"))
                        migrationState = .uploadFailed(totalBytes: totalBytes, archivePath: archivePath)
                    default:
                        logger.debug("unsupported event: \(msg.responseType)")
                    }
                }
            }
            chatReceiver?.start()

            let (res, error) = await uploadStandaloneFile(user: user, file: CryptoFile.plain(archivePath.lastPathComponent), ctrl: ctrl)
            await MainActor.run {
                guard let res = res else {
                    migrationState = .uploadFailed(totalBytes: totalBytes, archivePath: archivePath)
                    return alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_uploading_archive", comment: "Error uploading the archive")), error: error ?? "")
                }
                migrationState = .uploadProgress(uploadedBytes: 0, totalBytes: res.fileSize, fileId: res.fileId, archivePath: archivePath, ctrl: ctrl)
            }
        }
    }

    private func cancelUploadedArchive(_ fileId: Int64, _ ctrl: chat_ctrl) async {
        _ = await apiCancelFile(fileId: fileId, ctrl: ctrl)
    }

    private func cancelMigration(_ fileId: Int64, _ ctrl: chat_ctrl) {
        Task {
            await cancelUploadedArchive(fileId, ctrl)
            await startChatAndDismiss()
        }
    }

    private func finishMigration(_ fileId: Int64, _ ctrl: chat_ctrl) {
        Task {
            await cancelUploadedArchive(fileId, ctrl)
            await MainActor.run {
                migrationState = .finished(chatDeletion: false)
            }
        }
    }

    private func deleteChatAndDismiss() {
        Task {
            do {
                try await deleteChatAsync()
                m.chatDbChanged = true
                m.chatInitialized = false
                migrationState = .finished(chatDeletion: true)
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    Task { @MainActor in
                        resetChatCtrl()
                        do {
                            try await initializeChat(start: false)
                            m.chatDbChanged = false
                            AppChatState.shared.set(.active)
                        } catch let error {
                            logger.error("MigrateFromDevice: Error starting chat \(responseError(error))")
                            alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_starting_chat", comment: "Error starting chat")), error: responseError(error))
                        }
                    }
                    dismissAllSheets(animated: true)
                }
            } catch let error {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_deleting_db", comment: "Error deleting database")), error: responseError(error))
            }
        }
    }

    private func startChatAndDismiss(_ dismiss: Bool = true) async {
        AppChatState.shared.set(.active)
        do {
            if m.chatDbChanged {
                resetChatCtrl()
                try await initializeChat(start: true)
                m.chatDbChanged = false
            } else {
                try startChat(refreshInvitations: true)
            }
        } catch let error {
            alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_starting_chat", comment: "Error starting chat")), error: responseError(error))
        }
        // Hide settings anyway if chatDbStatus is not ok, probably passphrase needs to be entered
        if dismiss || m.chatDbStatus != .ok {
            dismissAllSheets(animated: true)
        }
    }

    private static func urlForTemporaryDatabase() -> URL {
        URL(fileURLWithPath: generateNewFileName(getMigrationTempFilesDirectory().path + "/" + "migration", "db", fullPath: true))
    }
}

private struct PassphraseConfirmationView: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var migrationState: MigrationFromState
    @State private var useKeychain = storeDBPassphraseGroupDefault.get()
    @State private var currentKey: String = ""
    @State private var verifyingPassphrase: Bool = false
    @FocusState private var keyboardVisible: Bool
    @Binding var alert: MigrateFromDeviceViewAlert?

    var body: some View {
        ZStack {
            List {
                chatStoppedView()
                Section {
                    PassphraseField(key: $currentKey, placeholder: NSLocalizedString("migrate_current_passphrase_placeholder", comment: "Current passphrase placeholder"), valid: validKey(currentKey))
                        .focused($keyboardVisible)
                    Button(action: {
                        verifyingPassphrase = true
                        hideKeyboard()
                        Task {
                            await verifyDatabasePassphrase(currentKey)
                            verifyingPassphrase = false
                        }
                    }) {
                        settingsRow(useKeychain ? "key" : "lock", color: theme.colors.secondary) {
                            Text(LocalizedStringKey("Verify passphrase"))
                        }
                    }
                    .disabled(verifyingPassphrase || currentKey.isEmpty)
                    .accessibilityLabel(Text(NSLocalizedString("a11y_verify_passphrase", comment: "")))
                } header: {
                    Text(NSLocalizedString("verify_passphrase_header", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(PXMigrateConfig.sectionHeaderOpacity) : theme.colors.secondary)
                        .textCase(.uppercase)
                } footer: {
                    Text(NSLocalizedString("verify_passphrase_footer", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                        .font(PXMigrateConfig.calloutFont)
                }
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(PXMigrateConfig.keyboardDelay * 1_000_000_000))
                        keyboardVisible = true
                    }
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            if verifyingPassphrase {
                VStack {
                    ProgressView().scaleEffect(PXMigrateConfig.progressScaleEffect)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func verifyDatabasePassphrase(_ dbKey: String) async {
        do {
            // If salt exists, derive the key first
            var testKey = dbKey
            if let salt = kcDatabaseSalt.get() {
                if let derived = deriveKey(from: dbKey, salt: Data(base64Encoded: salt)) {
                    // Convert base64-derived key to hex format for SQLCipher
                    if let keyData = Data(base64Encoded: derived.key) {
                        testKey = "x'\(keyData.map { String(format: "%02hhx", $0) }.joined())"
                    } else {
                        alert = .error(title: LocalizedStringKey(NSLocalizedString("Error verifying passphrase:", comment: "")), error: "Failed to decode derived key")
                        return
                    }
                } else {
                    alert = .error(title: LocalizedStringKey(NSLocalizedString("Error verifying passphrase:", comment: "")), error: "Key derivation failed")
                    return
                }
            }
            try await testStorageEncryption(key: testKey)
            await MainActor.run {
                migrationState = .uploadConfirmation
            }
        } catch let error {
            if case .errorDatabase(.errorOpen(.errorNotADatabase)) = error as? ChatError {
                showErrorOnMigrationIfNeeded(.errorNotADatabase(dbFile: ""), $alert)
            } else {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("migration_error_title", comment: "Generic error alert title in migration")), error: NSLocalizedString("Error verifying passphrase:", comment: "") + " " + String(responseError(error)))
            }
        }
    }
}

private func showErrorOnMigrationIfNeeded(_ status: DBMigrationResult, _ alert: Binding<MigrateFromDeviceViewAlert?>) {
    switch status {
    case .invalidConfirmation:
        alert.wrappedValue = .invalidConfirmation()
    case .errorNotADatabase:
        alert.wrappedValue = .wrongPassphrase()
    case .errorKeychain:
        alert.wrappedValue = .keychainError()
    case let .errorSQL(_, error):
        alert.wrappedValue = .databaseError(message: error)
    case let .unknown(error):
        alert.wrappedValue = .unknownError(message: error)
    case .errorMigration: ()
    case .errorKeyGeneration: ()
    case .ok: ()
    }
}

private func progressView() -> some View {
    VStack {
        ProgressView().scaleEffect(PXMigrateConfig.progressScaleEffect)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity )
}

func chatStoppedView() -> some View {
    settingsRow("exclamationmark.octagon.fill", color: QuantumColors.error) {
        Text(NSLocalizedString("chat_is_stopped", comment: ""))
    }
}

private class MigrationChatReceiver {
    let ctrl: chat_ctrl
    let databaseUrl: URL
    let processReceivedMsg: (APIResult<ChatEvent>) async -> Void
    private var receiveLoop: Task<Void, Never>?
    private var watchdogLoop: Task<Void, Never>?
    private var receiveMessages = true
    let receiveMessagesLock = NSLock()
    private var lastActivityTime = DispatchTime.now().uptimeNanoseconds
    private let lastActivityLock = NSLock()
    var isReceiving: Bool {
        get { receiveMessagesLock.lock(); defer { receiveMessagesLock.unlock() }; return receiveMessages }
        set { receiveMessagesLock.lock(); receiveMessages = newValue; receiveMessagesLock.unlock() }
    }

    private func getLastActivityTime() -> UInt64 {
        lastActivityLock.lock(); defer { lastActivityLock.unlock() }; return lastActivityTime
    }

    private func updateLastActivityTime() {
        lastActivityLock.lock(); lastActivityTime = DispatchTime.now().uptimeNanoseconds; lastActivityLock.unlock()
    }

    init(ctrl: chat_ctrl, databaseUrl: URL, _ processReceivedMsg: @escaping (APIResult<ChatEvent>) async -> Void) {
        self.ctrl = ctrl
        self.databaseUrl = databaseUrl
        self.processReceivedMsg = processReceivedMsg
    }

    func start() {
        logger.debug("MigrationChatReceiver.start")
        isReceiving = true
        if receiveLoop != nil { return }
        receiveLoop = Task { await receiveMsgLoop() }
        watchdogLoop = Task {
            let timeout: UInt64 = PXMigrateConfig.migrationTimeout
            while isReceiving {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !isReceiving { break }
                let last = getLastActivityTime()
                if DispatchTime.now().uptimeNanoseconds - last > timeout {
                    logger.error("Migration timed out: no messages received for 5 minutes")
                    isReceiving = false
                    break
                }
            }
        }
    }

    func receiveMsgLoop() async {
        while isReceiving {
            if let msg: APIResult<ChatEvent> = await chatRecvMsg(ctrl) {
                updateLastActivityTime()
                Task {
                    await TerminalItems.shared.addResult(msg)
                }
                logger.debug("processReceivedMsg: \(msg.responseType)")
                await processReceivedMsg(msg)
            }
            if self.isReceiving {
                _ = try? await Task.sleep(nanoseconds: PXMigrateConfig.pollInterval)
            }
        }
    }

    func stopAndCleanUp() {
        logger.debug("MigrationChatReceiver.stop")
        isReceiving = false
        receiveLoop?.cancel()
        receiveLoop = nil
        watchdogLoop?.cancel()
        watchdogLoop = nil
        chat_close_store(ctrl)
        try? FileManager.default.removeItem(atPath: "\(databaseUrl.path)_chat.db")
        try? FileManager.default.removeItem(atPath: "\(databaseUrl.path)_agent.db")
    }
}

struct MigrateFromDevice_Previews: PreviewProvider {
    static var previews: some View {
        MigrateFromDevice(showProgressOnSettings: Binding.constant(false))
    .previewEnvironment()
    }
}

// MARK: - POPOPX
extension MigrateFromDevice {
    static let pxComponentTag: String = "PX_MIGRATE_FROM_DEVICE"
}
