//
//  PXMigrateToDevice.swift
//  POPOPX (iOS)
//
//  Created by Avently on 23.02.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/database.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import CodeScanner
import POPOPXSwitch

// MARK: - POPOPX extracted constants & view model

private enum PXMigrateToDeviceConfig {
    static let brand: String = "POPOPX"
    static let migrationTimeout: UInt64 = 5 * 60 * 1_000_000_000
    static let pollInterval: UInt64 = 7_500_000
    static let archiveFileExtension: String = "zip"
    static let componentTag: String = "PX_MIGRATE_TO_DEVICE"
    static let downloadDelay: Double = 0.5
    static let archiveNameSeparator: String = "."
    static let linkPrefixPopopx: String = "popopx:/file"
    static let linkPrefixPopop: String = "popop:/file"
    static let linkPrefixHTTPS: String = "https://popopxchat.com/file"
    static let sectionHeaderFontSize: Font = .caption.weight(.bold)
    static let footerFont: Font = .callout
    static let pickerHeight: CGFloat = 36
    static let progressScale: CGFloat = 2
    static let backupDBFileName: String = "db_backup_before_import"
    static let migrationTempSubDir: String = "migration"
    static let migrationTempDBExtension: String = "db"
}

private struct PXMigrateToDeviceViewModel {
    let migrationState: MigrationToState?

    var isBackDisabled: Bool {
        switch migrationState {
        case nil, .pasteOrScanLink, .linkDownloading, .downloadProgress, .downloadFailed, .archiveImportFailed:
            return false
        case .archiveImport, .passphrase, .migrationConfirmation, .migration, .onion:
            return true
        }
    }

    var isDownloading: Bool {
        if case .downloadProgress = migrationState { return true }
        return false
    }

    var isImporting: Bool {
        if case .archiveImport = migrationState { return true }
        return false
    }

    var needsPasteboard: Bool {
        if case .pasteOrScanLink = migrationState { return true }
        return false
    }

    var stateDescription: String {
        switch migrationState {
        case nil: return "idle"
        case .pasteOrScanLink: return "paste_or_scan"
        case .linkDownloading: return "link_downloading"
        case .downloadProgress: return "downloading"
        case .downloadFailed: return "download_failed"
        case .archiveImport: return "importing"
        case .archiveImportFailed: return "import_failed"
        case .passphrase: return "passphrase"
        case .migrationConfirmation: return "confirmation"
        case .migration: return "migrating"
        case .onion: return "onion"
        }
    }
}

private let pxMigrationBrand = PXMigrateToDeviceConfig.brand

enum MigrationToDeviceState: Codable, Equatable {
    case downloadProgress(link: String, archiveName: String)
    case archiveImport(archiveName: String)
    case passphrase

    // Here we check whether it's needed to show migration process after app restart or not
    // It's important to NOT show the process when archive was corrupted/not fully downloaded
    static func makeMigrationState() -> MigrationToState? {
        guard let raw = UserDefaults.standard.string(forKey: DEFAULT_MIGRATION_TO_STAGE),
              let state: MigrationToDeviceState = decodeJSON(raw) else { return nil }
        var initial: MigrationToState? = .pasteOrScanLink
        switch state {
        case .downloadProgress:
            logger.debug("MigrateToDevice: archive wasn't fully downloaded, removed broken file")
            initial = nil
        case let .archiveImport(archiveName):
            let archivePath = getMigrationTempFilesDirectory().path + "/" + archiveName
            initial = .archiveImportFailed(archivePath: archivePath)
        case .passphrase:
            initial = .passphrase(passphrase: "")
        }
        if initial == nil {
            UserDefaults.standard.removeObject(forKey: DEFAULT_MIGRATION_TO_STAGE)
            try? FileManager.default.removeItem(at: getMigrationTempFilesDirectory())
        }
        return initial
    }

    static func save(_ state: MigrationToDeviceState?) {
        if let state {
            UserDefaults.standard.setValue(encodeJSON(state), forKey: DEFAULT_MIGRATION_TO_STAGE)
        } else {
            UserDefaults.standard.removeObject(forKey: DEFAULT_MIGRATION_TO_STAGE)
        }
    }
}

enum MigrationToState: Equatable {
    case pasteOrScanLink
    case linkDownloading(link: String)
    case downloadProgress(downloadedBytes: Int64, totalBytes: Int64, fileId: Int64, link: String, archivePath: String, ctrl: chat_ctrl?)
    case downloadFailed(totalBytes: Int64, link: String, archivePath: String)
    case archiveImport(archivePath: String)
    case archiveImportFailed(archivePath: String)
    case passphrase(passphrase: String)
    case migrationConfirmation(status: DBMigrationResult, passphrase: String, useKeychain: Bool)
    case migration(passphrase: String, confirmation: MigrationConfirmation, useKeychain: Bool)
    case onion(appSettings: AppSettings)
}

private enum MigrateToDeviceViewAlert: Identifiable {
    case chatImportedWithErrors(title: LocalizedStringKey = "Chat database imported",
                                text: LocalizedStringKey = "Some non-fatal errors occurred during import - you may see Chat console for more details.")

    case wrongPassphrase(title: LocalizedStringKey = "Wrong passphrase!", message: LocalizedStringKey = "Enter correct passphrase.")
    case invalidConfirmation(title: LocalizedStringKey = "Invalid migration confirmation")
    case keychainError(_ title: LocalizedStringKey = "Keychain error")
    case databaseError(_ title: LocalizedStringKey = "Database error", message: String)
    case unknownError(_ title: LocalizedStringKey = "Unknown error", message: String)

    case error(title: LocalizedStringKey, error: String = "")

    var id: String {
        switch self {
        case .chatImportedWithErrors: return "chatImportedWithErrors"

        case .wrongPassphrase: return "wrongPassphrase"
        case .invalidConfirmation: return "invalidConfirmation"
        case .keychainError: return "keychainError"
        case let .databaseError(title, message): return "\(title) \(message)"
        case let .unknownError(title, message): return "\(title) \(message)"

        case let .error(title, _): return "error \(title)"
        }
    }
}

struct MigrateToDevice: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss: DismissAction
    @Binding var migrationState: MigrationToState?
    @State private var useKeychain = storeDBPassphraseGroupDefault.get()
    @State private var alert: MigrateToDeviceViewAlert?
    @State private var databaseAlert: DatabaseAlert? = nil
    private let tempDatabaseUrl = urlForTemporaryDatabase()
    @State private var chatReceiver: MigrationChatReceiver? = nil
    // Prevent from hiding the view until migration is finished or app deleted
    @State private var backDisabled: Bool = false
    @State private var showQRCodeScanner: Bool = true
    @State private var pasteboardHasStrings = UIPasteboard.general.hasStrings

    @State private var importingArchiveFromFileProgressIndicator = false
    @State private var showFileImporter = false

    private var vm: PXMigrateToDeviceViewModel {
        PXMigrateToDeviceViewModel(migrationState: migrationState)
    }

    var body: some View {
        VStack {
            pxStateContainer
        }
        .onAppear {
            backDisabled = vm.isBackDisabled
        }
        .onChange(of: migrationState) {_,  state in
            backDisabled = PXMigrateToDeviceViewModel(migrationState: state).isBackDisabled
        }
        .onDisappear {
            Task {
                if case .archiveImportFailed = migrationState {
                    // Original database is not exist, nothing is setup correctly for showing to a user yet. Return to clean state
                    deleteAppDatabaseAndFiles()
                    await initChatAndMigrate()
                } else if case let .downloadProgress(_, _, fileId, _, _, ctrl) = migrationState, let ctrl {
                    await stopArchiveDownloading(fileId, ctrl)
                }
                chatReceiver?.stopAndCleanUp()
                if !backDisabled {
                    try? FileManager.default.removeItem(at: getMigrationTempFilesDirectory())
                    MigrationToDeviceState.save(nil)
                }
            }
        }
        .alert(item: $alert) { alert in
            pxAlertForItem(alert)
        }
        .alert(item: $databaseAlert) { item in
            pxDatabaseAlertForItem(item)
        }
        .interactiveDismissDisabled(backDisabled)
        .popopxBranded()
    }

    // MARK: - POPOPX ViewBuilder helpers

    @ViewBuilder
    private var pxStateContainer: some View {
        switch migrationState {
        case nil: EmptyView()
        case .pasteOrScanLink:
            pasteOrScanLinkView()
        case let .linkDownloading(link):
            linkDownloadingView(link)
        case let .downloadProgress(downloaded, total, _, _, _, _):
            downloadProgressView(downloaded, totalBytes: total)
        case let .downloadFailed(total, link, archivePath):
            downloadFailedView(totalBytes: total, link, archivePath)
        case let .archiveImport(archivePath):
            archiveImportView(archivePath)
        case let .archiveImportFailed(archivePath):
            archiveImportFailedView(archivePath)
        case let .passphrase(passphrase):
            PassphraseEnteringView(migrationState: $migrationState, currentKey: passphrase, alert: $alert)
        case let .migrationConfirmation(status, passphrase, useKeychain):
            migrationConfirmationView(status, passphrase, useKeychain)
        case let .migration(passphrase, confirmation, useKeychain):
            migrationView(passphrase, confirmation, useKeychain)
        case let .onion(appSettings):
            OnionView(appSettings: appSettings, finishMigration: finishMigration)
        }
    }

    private func pxSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(PXMigrateToDeviceConfig.sectionHeaderFontSize)
            .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.primary)
            .textCase(.uppercase)
    }

    private func pxSectionFooter(_ text: String) -> some View {
        Text(text)
            .foregroundColor(theme.colors.secondary)
            .font(PXMigrateToDeviceConfig.footerFont)
    }

    private func pxAlertForItem(_ alert: MigrateToDeviceViewAlert) -> Alert {
        switch alert {
        case let .chatImportedWithErrors(title, text):
            return Alert(title: Text(title), message: Text(text))
        case let .wrongPassphrase(title, message):
            return Alert(title: Text(title), message: Text(message))
        case let .invalidConfirmation(title):
            return Alert(title: Text(title))
        case let .keychainError(title):
            return Alert(title: Text(title))
        case let .databaseError(title, message):
            return Alert(title: Text(title), message: Text(verbatim: message))
        case let .unknownError(title, message):
            return Alert(title: Text(title), message: Text(verbatim: message))
        case let .error(title, error):
            return Alert(title: Text(title), message: Text(verbatim: error))
        }
    }

    private func pxDatabaseAlertForItem(_ item: DatabaseAlert) -> Alert {
        switch item {
        case .archiveImported:
            let (title, message) = archiveImportedAlertText()
            return Alert(title: Text(title), message: Text(message))
        case let .archiveImportedWithErrors(errs):
            let (title, message) = archiveImportedWithErrorsAlertText(errs: errs)
            return Alert(title: Text(title), message: Text(message))
        case let .error(title, error):
            return Alert(title: Text(title), message: Text(verbatim: error))
        default:
            return Alert(title: Text(LocalizedStringKey(NSLocalizedString("migration_error_generic", comment: "Generic error title"))))
        }
    }

    private func pasteOrScanLinkView() -> some View {
        ZStack {
            List {
                Section(header: pxSectionHeader(NSLocalizedString("Scan QR code", comment: ""))) {
                    ScannerInView(showQRCodeScanner: $showQRCodeScanner) { resp in
                        pxHandleQRResponse(resp)
                    }
                }
                Section(header: pxSectionHeader(NSLocalizedString("Or paste archive link", comment: ""))) {
                    pasteLinkView()
                }
                Section(header: pxSectionHeader(NSLocalizedString("Or import archive file", comment: ""))) {
                    archiveImportFromFileView()
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            if importingArchiveFromFileProgressIndicator {
                progressView()
            }
        }
    }

    private func pasteLinkView() -> some View {
        Button {
            if let str = UIPasteboard.general.string {
                pxHandlePastedLink(str)
            }
        } label: {
            Text(NSLocalizedString("Tap to paste link", comment: ""))
        }
        .disabled(!pasteboardHasStrings)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel(NSLocalizedString("Paste migration archive link", comment: "Accessibility"))
    }

    private func archiveImportFromFileView() -> some View {
        Button {
            showFileImporter = true
        } label: {
            Label(NSLocalizedString("Import database", comment: ""), systemImage: "square.and.arrow.down")
        }
        .disabled(importingArchiveFromFileProgressIndicator)
        .accessibilityLabel(NSLocalizedString("Import database archive file", comment: "Accessibility"))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(files) = result, let fileURL = files.first {
                Task {
                    let success = await DatabaseView.importArchive(fileURL, $importingArchiveFromFileProgressIndicator, $databaseAlert, true)
                    if success {
                        DatabaseView.startChat(
                            Binding.constant(false),
                            $importingArchiveFromFileProgressIndicator
                        )
                        hideView()
                    }
                }
            }
        }
    }


    private func linkDownloadingView(_ link: String) -> some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Downloading link details", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            progressView()
        }
        .onAppear {
            downloadLinkDetails(link)
        }
    }

    private func downloadProgressView(_ downloadedBytes: Int64, totalBytes: Int64) -> some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Downloading archive", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            let ratio = Float(downloadedBytes) / Float(max(totalBytes, 1))
            MigrateFromDevice.largeProgressView(ratio, "\(Int(ratio * 100))%", "\(ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .binary)) downloaded", theme.colors.primary)
        }
    }

    private func downloadFailedView(totalBytes: Int64, _ link: String, _ archivePath: String) -> some View {
        List {
            Section {
                Button(action: {
                    try? FileManager.default.removeItem(atPath: archivePath)
                    migrationState = .linkDownloading(link: link)
                }) {
                    settingsRow("tray.and.arrow.down", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Repeat download", comment: "")).foregroundColor(theme.colors.primary)
                    }
                }
                .accessibilityLabel(NSLocalizedString("Retry archive download", comment: "Accessibility"))
            } header: {
                Text(NSLocalizedString("Download failed", comment: ""))
                    .foregroundColor(theme.colors.secondary)
            } footer: {
                pxSectionFooter(NSLocalizedString("You can give another try.", comment: ""))
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onAppear {
            chatReceiver?.stopAndCleanUp()
            try? FileManager.default.removeItem(atPath: archivePath)
            MigrationToDeviceState.save(nil)
        }
    }

    private func archiveImportView(_ archivePath: String) -> some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Importing archive", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            progressView()
        }
        .onAppear {
            importArchive(archivePath)
        }
    }

    private func archiveImportFailedView(_ archivePath: String) -> some View {
        List {
            Section {
                Button(action: {
                    migrationState = .archiveImport(archivePath: archivePath)
                }) {
                    settingsRow("square.and.arrow.down", color: theme.colors.secondary) {
                        Text(NSLocalizedString("Repeat import", comment: "")).foregroundColor(theme.colors.primary)
                    }
                }
                .accessibilityLabel(NSLocalizedString("Retry archive import", comment: "Accessibility"))
            } header: {
                Text(NSLocalizedString("Import failed", comment: ""))
                    .foregroundColor(theme.colors.secondary)
            } footer: {
                pxSectionFooter(NSLocalizedString("You can give another try.", comment: ""))
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func migrationConfirmationView(_ status: DBMigrationResult, _ passphrase: String, _ useKeychain: Bool) -> some View {
        List {
            let (header, button, footer, confirmation): (LocalizedStringKey, LocalizedStringKey?, String, MigrationConfirmation?) = switch status {
            case let .errorMigration(_, migrationError):
                switch migrationError {
                case .upgrade:
                    ("Database upgrade",
                    "Upgrade and open chat",
                     "",
                     .yesUp)
                case let .downgrade(downMigrations):
                    ("Database downgrade",
                    "Downgrade and open chat",
                     ([NSLocalizedString("Warning: you may lose some data!", comment: "")]
                        + downMigrationWarnings(downMigrations).reversed())
                        .joined(separator: "\n"),
                    .yesUpDown)
                case let .migrationError(mtrError):
                    ("Incompatible database version",
                     nil,
                     "\(NSLocalizedString("Error: ", comment: "")) \(mtrErrorDescription(mtrError))",
                     nil)
                }
            default: ("Error", nil, "Unknown error", nil)
            }
            Section {
                if let button, let confirmation {
                    Button(action: {
                        migrationState = .migration(passphrase: passphrase, confirmation: confirmation, useKeychain: useKeychain)
                    }) {
                        settingsRow("square.and.arrow.down", color: theme.colors.secondary) {
                            Text(button).foregroundColor(theme.colors.primary)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("Confirm migration action", comment: "Accessibility"))
                } else {
                    EmptyView()
                }
            } header: {
                Text(header)
                    .foregroundColor(theme.colors.secondary)
            } footer: {
                pxSectionFooter(footer)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private func migrationView(_ passphrase: String, _ confirmation: MigrationConfirmation, _ useKeychain: Bool) -> some View {
        ZStack {
            List {
                Section {} header: {
                    Text(NSLocalizedString("Migrating", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            progressView()
        }
        .onAppear {
            startChat(passphrase, confirmation, useKeychain)
        }
    }

    struct OnionView: View {
        @EnvironmentObject var theme: AppTheme
        @State var appSettings: AppSettings
        @State private var onionHosts: OnionHosts = .no
        var finishMigration: (AppSettings) -> Void

        var body: some View {
            List {
                Section {
                    Button(action: {
                        guard let currentConfig = appSettings.networkConfig else { return }
                        var updated = currentConfig
                        let (hostMode, requiredHostMode) = onionHosts.hostMode
                        updated.hostMode = hostMode
                        updated.requiredHostMode = requiredHostMode
                        updated.socksProxy = nil
                        appSettings.networkConfig = updated
                        finishMigration(appSettings)
                    }) {
                        settingsRow("checkmark", color: theme.colors.secondary) {
                            Text(LocalizedStringKey(NSLocalizedString("migration_apply_button", comment: "Apply button"))).foregroundColor(theme.colors.primary)
                        }
                    }
                    .accessibilityLabel(NSLocalizedString("Apply network settings", comment: "Accessibility"))
                } header: {
                    Text(NSLocalizedString("Confirm network settings", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundColor(theme.colors.primary)
                        .textCase(.uppercase)
                } footer: {
                    Text(NSLocalizedString("Please confirm that network settings are correct for this device.", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                        .font(.callout)
                }

                Section(header: Text(NSLocalizedString("Network settings", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(theme.colors.primary)
                    .textCase(.uppercase)) {
                    Picker(NSLocalizedString("migration_use_onion_hosts", comment: "Use .onion hosts picker label"), selection: $onionHosts) {
                        ForEach(OnionHosts.values, id: \.self) { Text($0.text) }
                    }
                    .frame(height: PXMigrateToDeviceConfig.pickerHeight)
                    .accessibilityLabel(NSLocalizedString("Onion routing mode", comment: "Accessibility"))
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - POPOPX actions

    private func pxHandleQRResponse(_ resp: Result<ScanResult, ScanError>) {
        switch resp {
        case let .success(r):
            let link = r.string
            if pxStrHasFileLink(link.trimmingCharacters(in: .whitespaces)) {
                migrationState = .linkDownloading(link: link.trimmingCharacters(in: .whitespaces))
            } else {
                alert = .error(title: LocalizedStringKey(NSLocalizedString("Invalid link", comment: "invalid migration link alert title")), error: NSLocalizedString("The text you pasted is not a \(pxMigrationBrand) link.", comment: "invalid link alert message"))
            }
        case let .failure(e):
            logger.error("processQRCode QR code error: \(e.localizedDescription)")
            alert = .error(title: LocalizedStringKey(NSLocalizedString("Invalid link", comment: "invalid migration link alert title")), error: NSLocalizedString("The text you pasted is not a \(pxMigrationBrand) link.", comment: "invalid link alert message"))
        }
    }

    private func pxHandlePastedLink(_ str: String) {
        if pxStrHasFileLink(str.trimmingCharacters(in: .whitespaces)) {
            migrationState = .linkDownloading(link: str.trimmingCharacters(in: .whitespaces))
        } else {
            alert = .error(title: LocalizedStringKey(NSLocalizedString("Invalid link", comment: "invalid migration link alert title")), error: NSLocalizedString("The text you pasted is not a \(pxMigrationBrand) link.", comment: "invalid link alert message"))
        }
    }

    private func pxStrHasFileLink(_ text: String) -> Bool {
        text.starts(with: PXMigrateToDeviceConfig.linkPrefixPopopx)
            || text.starts(with: PXMigrateToDeviceConfig.linkPrefixPopop)
            || text.starts(with: PXMigrateToDeviceConfig.linkPrefixHTTPS)
    }

    private func downloadLinkDetails(_ link: String) {
        let archiveTime = Date.now
        let ts = archiveTime.ISO8601Format(Date.ISO8601FormatStyle(timeSeparator: .omitted))
        let archiveName = "\(PXMigrateToDeviceConfig.brand.lowercased())\(PXMigrateToDeviceConfig.archiveNameSeparator)\(ts).\(PXMigrateToDeviceConfig.archiveFileExtension)"
        let archivePath = getMigrationTempFilesDirectory().appendingPathComponent(archiveName)

        startDownloading(0, link, archivePath.path)
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

    private func startDownloading(_ totalBytes: Int64, _ link: String, _ archivePath: String) {
        Task {
            guard let ctrlAndUser = initTemporaryDatabase() else {
                return migrationState = .downloadFailed(totalBytes: totalBytes, link: link, archivePath: archivePath)
            }
            let (ctrl, user) = ctrlAndUser
            chatReceiver = MigrationChatReceiver(ctrl: ctrl, databaseUrl: tempDatabaseUrl) { msg in
                await MainActor.run {
                    switch msg {
                    case let .result(.rcvFileProgressXFTP(_, _, receivedSize, totalSize, rcvFileTransfer), _):
                        migrationState = .downloadProgress(downloadedBytes: receivedSize, totalBytes: totalSize, fileId: rcvFileTransfer.fileId, link: link, archivePath: archivePath, ctrl: ctrl)
                        MigrationToDeviceState.save(.downloadProgress(link: link, archiveName: URL(fileURLWithPath: archivePath).lastPathComponent))
                    case .result(.rcvStandaloneFileComplete, _):
                        DispatchQueue.main.asyncAfter(deadline: .now() + PXMigrateToDeviceConfig.downloadDelay) {
                            // User closed the whole screen before new state was saved
                            if migrationState == nil {
                                MigrationToDeviceState.save(nil)
                            } else {
                                migrationState = .archiveImport(archivePath: archivePath)
                                MigrationToDeviceState.save(.archiveImport(archiveName: URL(fileURLWithPath: archivePath).lastPathComponent))
                            }
                        }
                    case .result(.rcvFileError, _):
                        alert = .error(title: LocalizedStringKey(NSLocalizedString("Download failed", comment: "download error alert title")), error: NSLocalizedString("File was deleted or link is invalid", comment: "download failed alert message"))
                        migrationState = .downloadFailed(totalBytes: totalBytes, link: link, archivePath: archivePath)
                    case .error(.error(.noRcvFileUser), _):
                        alert = .error(title: LocalizedStringKey(NSLocalizedString("Download failed", comment: "download error alert title")), error: NSLocalizedString("File was deleted or link is invalid", comment: "download failed alert message"))
                        migrationState = .downloadFailed(totalBytes: totalBytes, link: link, archivePath: archivePath)
                    default:
                        logger.debug("unsupported event: \(msg.responseType)")
                    }
                }
            }
            chatReceiver?.start()

            let (res, error) = await downloadStandaloneFile(user: user, url: link, file: CryptoFile.plain(URL(fileURLWithPath: archivePath).lastPathComponent), ctrl: ctrl)
            if res == nil {
                await MainActor.run {
                    migrationState = .downloadFailed(totalBytes: totalBytes, link: link, archivePath: archivePath)
                }
                return alert = .error(title: LocalizedStringKey(NSLocalizedString("Error downloading the archive", comment: "archive download error alert title")), error: error ?? "")
            }
        }
    }

    private func importArchive(_ archivePath: String) {
        Task {
            let fm = FileManager.default
            guard fm.fileExists(atPath: archivePath) else {
                await MainActor.run {
                    migrationState = .archiveImportFailed(archivePath: archivePath)
                }
                alert = .error(title: LocalizedStringKey(NSLocalizedString("Archive not found", comment: "archive import error title")), error: NSLocalizedString("The archive file does not exist at the specified path.", comment: "archive not found error message"))
                return
            }
            let attrs = try? fm.attributesOfItem(atPath: archivePath)
            let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize > 0 else {
                await MainActor.run {
                    migrationState = .archiveImportFailed(archivePath: archivePath)
                }
                alert = .error(title: LocalizedStringKey(NSLocalizedString("Archive is empty", comment: "archive import error title")), error: NSLocalizedString("The archive file is empty.", comment: "archive empty error message"))
                return
            }

            let dbURL = getAppDatabasePath()
            let backupURL = dbURL.deletingLastPathComponent().appendingPathComponent(PXMigrateToDeviceConfig.backupDBFileName)
            let dbFiles = [dbURL.path, "\(dbURL.path)-wal", "\(dbURL.path)-shm"]

            do {
                if !hasChatCtrl() {
                    chatInitControllerRemovingDatabases()
                } else if ChatModel.shared.chatRunning == true {
                    try await stopChatAsync()
                }

                try fm.createDirectory(at: backupURL, withIntermediateDirectories: true)
                for path in dbFiles {
                    if fm.fileExists(atPath: path) {
                        let src = URL(fileURLWithPath: path)
                        let dst = backupURL.appendingPathComponent(src.lastPathComponent)
                        try fm.copyItem(at: src, to: dst)
                    }
                }

                // Verify backup integrity before proceeding with destructive import
                let mainBackup = backupURL.appendingPathComponent(URL(fileURLWithPath: dbFiles[0]).lastPathComponent)
                guard fm.fileExists(atPath: mainBackup.path) else {
                    throw NSError(domain: "Migration", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Backup verification failed: main database backup not found"
                    ])
                }
                let backupAttrs = try fm.attributesOfItem(atPath: mainBackup.path)
                let backupSize = (backupAttrs[.size] as? NSNumber)?.int64Value ?? 0
                guard backupSize > 0 else {
                    throw NSError(domain: "Migration", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Backup verification failed: backup database is empty"
                    ])
                }

                try await apiDeleteStorage()
                try? fm.createDirectory(at: getWallpaperDirectory(), withIntermediateDirectories: true)
                do {
                    let config = ArchiveConfig(archivePath: archivePath)
                    let archiveErrors = try await apiImportArchive(config: config)
                    if !archiveErrors.isEmpty {
                        alert = .chatImportedWithErrors()
                    }
                    try? fm.removeItem(at: backupURL)
                    await MainActor.run {
                        migrationState = .passphrase(passphrase: "")
                        MigrationToDeviceState.save(.passphrase)
                    }
                } catch let error {
                    restoreBackup(dbFiles: dbFiles, backupURL: backupURL)
                    await MainActor.run {
                        migrationState = .archiveImportFailed(archivePath: archivePath)
                    }
                    alert = .error(title: LocalizedStringKey(NSLocalizedString("Error importing chat database", comment: "import archive error title")), error: responseError(error))
                }
            } catch let error {
                restoreBackup(dbFiles: dbFiles, backupURL: backupURL)
                await MainActor.run {
                    migrationState = .archiveImportFailed(archivePath: archivePath)
                }
                alert = .error(title: LocalizedStringKey(NSLocalizedString("Error deleting chat database", comment: "delete database error title")), error: responseError(error))
            }
        }
    }

    private func restoreBackup(dbFiles: [String], backupURL: URL) {
        let fm = FileManager.default
        var failedFiles: [String] = []
        for path in dbFiles {
            let src = URL(fileURLWithPath: path)
            let backupFile = backupURL.appendingPathComponent(src.lastPathComponent)
            if fm.fileExists(atPath: backupFile.path) {
                try? fm.removeItem(at: URL(fileURLWithPath: path))
                do {
                    try fm.moveItem(at: backupFile, to: URL(fileURLWithPath: path))
                } catch {
                    logger.error("restoreBackup: failed to restore \(src.lastPathComponent): \(error.localizedDescription)")
                    failedFiles.append(src.lastPathComponent)
                }
            }
        }
        if !failedFiles.isEmpty {
            logger.error("restoreBackup: failed to restore files: \(failedFiles.joined(separator: ", "))")
        }
        try? fm.removeItem(at: backupURL)
    }


    private func stopArchiveDownloading(_ fileId: Int64, _ ctrl: chat_ctrl) async {
        _ = await apiCancelFile(fileId: fileId, ctrl: ctrl)
    }

    private func startChat(_ passphrase: String, _ confirmation: MigrationConfirmation, _ useKeychain: Bool) {
        if useKeychain {
            _ = kcDatabasePassword.set(passphrase)
        } else {
            _ = kcDatabasePassword.remove()
        }
        storeDBPassphraseGroupDefault.set(useKeychain)
        initialRandomDBPassphraseGroupDefault.set(false)
        AppChatState.shared.set(.active)
        Task {
            do {
                resetChatCtrl()
                try await initializeChat(start: false, confirmStart: false, dbKey: passphrase, refreshInvitations: true, confirmMigrations: confirmation)
                var appSettings = try apiGetAppSettings(settings: AppSettings.current.prepareForExport())
                let hasOnionConfigured = appSettings.networkConfig?.socksProxy != nil || appSettings.networkConfig?.hostMode == .onionHost
                appSettings.networkConfig?.socksProxy = nil
                appSettings.networkConfig?.hostMode = .publicHost
                appSettings.networkConfig?.requiredHostMode = true
                await MainActor.run {
                    if hasOnionConfigured {
                        migrationState = .onion(appSettings: appSettings)
                    } else {
                        finishMigration(appSettings)
                    }
                }
            } catch let error {
                hideView()
                AlertManager.shared.showAlert(Alert(title: Text(LocalizedStringKey(NSLocalizedString("migration_error_starting_chat", comment: "Error starting chat"))), message: Text(verbatim: responseError(error))))
            }
        }
    }

    private func finishMigration(_ appSettings: AppSettings) {
        do {
            try? FileManager.default.removeItem(at: getMigrationTempFilesDirectory())
            MigrationToDeviceState.save(nil)
            try POPOPXExceptionCatcher.catchException {
                appSettings.importIntoApp()
            }
            do {
                try POPOPX.startChat(refreshInvitations: true)
                AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Chat migrated!", comment: "migration success alert title")), message: LocalizedStringKey(NSLocalizedString("Finalize migration on another device.", comment: "migration success alert message")))
            } catch let error {
                AlertManager.shared.showAlert(Alert(title: Text(LocalizedStringKey(NSLocalizedString("migration_error_starting_chat", comment: "Error starting chat"))), message: Text(verbatim: responseError(error))))
            }
        } catch let error {
            logger.error("Error importing settings: \(error.localizedDescription)")
            AlertManager.shared.showAlert(
                Alert(
                    title: Text(LocalizedStringKey(NSLocalizedString("migration_error_migrating_settings", comment: "Error migrating settings"))),
                    message: Text("\(NSLocalizedString("Some app settings were not migrated.", comment: "settings migration error"))\n\(responseError(error))"))
            )
        }
        hideView()
    }

    private func hideView() {
        advanceOnboarding(to: .onboardingComplete)
        m.migrationState = nil
        MigrationToDeviceState.save(nil)
        dismiss()
    }

    // MARK: - POPOPX helpers

    private func pxBrandLabel(_ text: String) -> String {
        "\(PXMigrateToDeviceConfig.brand) – \(text)"
    }

    private static func urlForTemporaryDatabase() -> URL {
        URL(fileURLWithPath: generateNewFileName(getMigrationTempFilesDirectory().path + "/" + PXMigrateToDeviceConfig.migrationTempSubDir, PXMigrateToDeviceConfig.migrationTempDBExtension, fullPath: true))
    }
}

private struct PassphraseEnteringView: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var migrationState: MigrationToState?
    @State private var useKeychain = true
    @State var currentKey: String
    @State private var verifyingPassphrase: Bool = false
    @FocusState private var keyboardVisible: Bool
    @Binding var alert: MigrateToDeviceViewAlert?

    var body: some View {
        ZStack {
            List {
                Section {
                    settingsRow("key", color: theme.colors.secondary) {
                        Toggle(NSLocalizedString("Save passphrase in Keychain", comment: ""), isOn: $useKeychain)
                            .accessibilityLabel(NSLocalizedString("Store passphrase in Keychain", comment: "Accessibility"))
                    }

                    PassphraseField(key: $currentKey, placeholder: NSLocalizedString("migrate_current_passphrase_placeholder", comment: "Current passphrase placeholder"), valid: validKey(currentKey))
                        .focused($keyboardVisible)
                    Button(action: {
                        verifyingPassphrase = true
                        hideKeyboard()
                        Task {
                            let (status, _) = chatInitTemporaryDatabase(url: getAppDatabasePath(), key: currentKey, confirmation: .yesUp)
                            let success = switch status {
                            case .ok, .invalidConfirmation: true
                            default: false
                            }
                            if success {
                                await MainActor.run {
                                    migrationState = .migration(passphrase: currentKey, confirmation: .yesUp, useKeychain: useKeychain)
                                }
                            } else if case .errorMigration = status {
                                await MainActor.run {
                                    migrationState = .migrationConfirmation(status: status, passphrase: currentKey, useKeychain: useKeychain)
                                }
                            } else {
                                showErrorOnMigrationIfNeeded(status, $alert)
                            }
                            verifyingPassphrase = false
                        }
                    }) {
                        settingsRow("key", color: theme.colors.secondary) {
                            Text(NSLocalizedString("Open chat", comment: ""))
                        }
                    }
                    .disabled(verifyingPassphrase || currentKey.isEmpty)
                    .accessibilityLabel(NSLocalizedString("Verify passphrase and open chat", comment: "Accessibility"))
                } header: {
                    Text(NSLocalizedString("Enter passphrase", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundColor(theme.colors.primary)
                        .textCase(.uppercase)
                } footer: {
                    VStack(alignment: .leading, spacing: 16) {
                        if useKeychain {
                            Text(NSLocalizedString("iOS Keychain is used to securely store passphrase - it allows receiving push notifications.", comment: ""))
                        } else {
                            Text(NSLocalizedString("You have to enter passphrase every time the app starts - it is not stored on the device.", comment: ""))
                            Text(NSLocalizedString("**Please note**: you will NOT be able to recover or change passphrase if you lose it.", comment: ""))
                            Text(NSLocalizedString("**Warning**: Instant push notifications require passphrase saved in Keychain.", comment: ""))
                        }
                    }
                    .foregroundColor(theme.colors.secondary)
                    .font(.callout)
                    .padding(.top, 1)
                    .onTapGesture { keyboardVisible = false }
                }
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000000000)
                        keyboardVisible = true
                    }
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            if verifyingPassphrase {
                progressView()
            }
        }
    }
}

private func showErrorOnMigrationIfNeeded(_ status: DBMigrationResult, _ alert: Binding<MigrateToDeviceViewAlert?>) {
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
        ProgressView().scaleEffect(PXMigrateToDeviceConfig.progressScale)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity )
}

private class MigrationChatReceiver {
    let ctrl: chat_ctrl
    let databaseUrl: URL
    let processReceivedMsg: (APIResult<ChatEvent>) async -> Void
    private var receiveLoop: Task<Void, Never>?
    private var watchdogLoop: Task<Void, Never>?
    private let receiveMessagesLock = NSLock()
    private var _receiveMessages = true
    private var lastActivityTime = DispatchTime.now().uptimeNanoseconds
    private let lastActivityLock = NSLock()

    init(ctrl: chat_ctrl, databaseUrl: URL, _ processReceivedMsg: @escaping (APIResult<ChatEvent>) async -> Void) {
        self.ctrl = ctrl
        self.databaseUrl = databaseUrl
        self.processReceivedMsg = processReceivedMsg
    }

    var receiveMessages: Bool {
        get { receiveMessagesLock.lock(); defer { receiveMessagesLock.unlock() }; return _receiveMessages }
        set { receiveMessagesLock.lock(); defer { receiveMessagesLock.unlock() }; _receiveMessages = newValue }
    }

    private func getLastActivityTime() -> UInt64 {
        lastActivityLock.lock(); defer { lastActivityLock.unlock() }; return lastActivityTime
    }

    private func updateLastActivityTime() {
        lastActivityLock.lock(); lastActivityTime = DispatchTime.now().uptimeNanoseconds; lastActivityLock.unlock()
    }

    func start() {
        logger.debug("MigrationChatReceiver.start")
        receiveMessages = true
        if receiveLoop != nil { return }
        receiveLoop = Task { await receiveMsgLoop() }
        watchdogLoop = Task {
            let timeout: UInt64 = PXMigrateToDeviceConfig.migrationTimeout
            while receiveMessages {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !receiveMessages { break }
                let last = getLastActivityTime()
                if DispatchTime.now().uptimeNanoseconds - last > timeout {
                    logger.error("Migration timed out: no messages received for 5 minutes")
                    receiveMessages = false
                    break
                }
            }
        }
    }

    func receiveMsgLoop() async {
        while receiveMessages {
            if let msg = await chatRecvMsg(ctrl) {
                updateLastActivityTime()
                Task {
                    await TerminalItems.shared.addResult(msg)
                }
                logger.debug("processReceivedMsg: \(msg.responseType)")
                await processReceivedMsg(msg)
            }
            if receiveMessages {
                _ = try? await Task.sleep(nanoseconds: PXMigrateToDeviceConfig.pollInterval)
            }
        }
    }

    func stopAndCleanUp() {
        logger.debug("MigrationChatReceiver.stop")
        receiveMessages = false
        receiveLoop?.cancel()
        receiveLoop = nil
        watchdogLoop?.cancel()
        watchdogLoop = nil
        chat_close_store(ctrl)
        try? FileManager.default.removeItem(atPath: "\(databaseUrl.path)_chat.db")
        try? FileManager.default.removeItem(atPath: "\(databaseUrl.path)_agent.db")
    }
}

struct MigrateToDevice_Previews: PreviewProvider {
    static var previews: some View {
        MigrateToDevice(migrationState: Binding.constant(.pasteOrScanLink))
    .previewEnvironment()
    }
}

// MARK: - POPOPX
extension MigrationToDeviceState {
    var pxLocalizedTitle: String {
        switch self {
        case .downloadProgress: return NSLocalizedString("Downloading archive", comment: "POPOPX migration")
        case .archiveImport: return NSLocalizedString("Importing archive", comment: "POPOPX migration")
        case .passphrase: return NSLocalizedString("Enter passphrase", comment: "POPOPX migration")
        }
    }
}

extension MigrateToDevice {
    static let pxComponentTag: String = PXMigrateToDeviceConfig.componentTag
    static let pxMigrationTimeout: UInt64 = PXMigrateToDeviceConfig.migrationTimeout
    static let pxPollInterval: UInt64 = PXMigrateToDeviceConfig.pollInterval
    static let pxArchiveFileExtension: String = PXMigrateToDeviceConfig.archiveFileExtension
    var pxStateDescription: String { vm.stateDescription }
    var pxIsBackLocked: Bool { vm.isBackDisabled }
}
