//
//  DatabaseView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 19/06/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/database.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

enum DatabaseAlert: Identifiable {
    case stopChat
    case exportProhibited
    case importArchive
    case archiveImported
    case archiveImportedWithErrors(archiveErrors: [ArchiveError])
    case archiveExportedWithErrors(archivePath: URL, archiveErrors: [ArchiveError])
    case deleteChat
    case chatDeleted
    case deleteLegacyDatabase
    case deleteFilesAndMedia
    case setChatItemTTL(ttl: ChatItemTTL)
    case error(title: String, error: String = "")

    var id: String {
        switch self {
        case .stopChat: return "stopChat"
        case .exportProhibited: return "exportProhibited"
        case .importArchive: return "importArchive"
        case .archiveImported: return "archiveImported"
        case .archiveImportedWithErrors: return "archiveImportedWithErrors"
        case .archiveExportedWithErrors: return "archiveExportedWithErrors"
        case .deleteChat: return "deleteChat"
        case .chatDeleted: return "chatDeleted"
        case .deleteLegacyDatabase: return "deleteLegacyDatabase"
        case .deleteFilesAndMedia: return "deleteFilesAndMedia"
        case .setChatItemTTL: return "setChatItemTTL"
        case let .error(title, _): return "error \(title)"
        }
    }
}

// Spec: spec/database.md#DatabaseView
struct DatabaseView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    let dismissSettingsSheet: DismissAction
    @State private var runChat = false
    @State private var stoppingChat = false
    @State private var alert: DatabaseAlert? = nil
    @State private var showFileImporter = false
    @State private var importedArchivePath: URL?
    @State private var progressIndicator = false
    @AppStorage(DEFAULT_CHAT_ARCHIVE_NAME) private var chatArchiveName: String?
    @AppStorage(DEFAULT_CHAT_ARCHIVE_TIME) private var chatArchiveTime: Double = 0
    @State private var dbContainer = dbContainerGroupDefault.get()
    @State private var legacyDatabase = hasLegacyDatabase()
    @State private var useKeychain = storeDBPassphraseGroupDefault.get()
    @State private var appFilesCountAndSize: (Int, Int)?

    @State private var showDatabaseEncryptionView = false

    @State var chatItemTTL: ChatItemTTL
    @State private var currentChatItemTTL: ChatItemTTL = .none

    var body: some View {
        ZStack {
            chatDatabaseView()
            if progressIndicator {
                // BrandedProgressView.swift is not yet in the Xcode project; using ProgressView as placeholder.
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .navigationDestination(isPresented: $showDatabaseEncryptionView) {
            DatabaseEncryptionView(useKeychain: $useKeychain, migration: false, stopChatRunBlockStartChat: { progressIndicator, block in
                stopChatRunBlockStartChat(false, progressIndicator, block)
            })
                .navigationTitle(NSLocalizedString("Database passphrase", comment: ""))
                .modifier(ThemedBackground(grouped: true))
        }
    }

    @ViewBuilder
    private func chatDatabaseView() -> some View {

        List {
            let stopped = m.chatRunning == false
            Section {
                Picker(NSLocalizedString("db_delete_messages_after", comment: "Delete messages after picker label"), selection: $chatItemTTL) {
                    ForEach(ChatItemTTL.values) { ttl in
                        Text(ttl.deleteAfterText).tag(ttl)
                    }
                    if case .seconds = chatItemTTL {
                        Text(chatItemTTL.deleteAfterText).tag(chatItemTTL)
                    }
                }
                .frame(height: 36)
                .disabled(stopped || progressIndicator)
            } header: {
                Text(NSLocalizedString("Messages", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                    .textCase(.uppercase)
            } footer: {
                Text(String.localizedStringWithFormat(NSLocalizedString("This setting applies to messages in your current chat profile **%@**.", comment: ""), m.currentUser?.displayName ?? ""))
                    .foregroundColor(theme.colors.secondary)
            }

            Section {
                settingsRow(
                    stopped ? "exclamationmark.octagon.fill" : "play.fill",
                    color: stopped ? QuantumColors.error : QuantumColors.success
                ) {
                    Toggle(
                        stopped ? NSLocalizedString("Chat is stopped", comment: "") : NSLocalizedString("Chat is running", comment: ""),
                        isOn: $runChat
                    )
                    .onChange(of: runChat) {_, _ in
                        if runChat {
                            DatabaseView.startChat($runChat, $progressIndicator)
                        } else if !stoppingChat {
                            stoppingChat = false
                            alert = .stopChat
                        }
                    }
                }
            } header: {
                Text(NSLocalizedString("Run chat", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                    .textCase(.uppercase)
            } footer: {
                if case .documents = dbContainer {
                    Text(NSLocalizedString("Database will be migrated when the app restarts", comment: ""))
                        .foregroundColor(theme.colors.secondary)
                }
            }

            Section {
                let unencrypted = m.chatDbEncrypted == false
                let color: Color = unencrypted ? QuantumColors.warning : theme.colors.secondary
                settingsRow(unencrypted ? "lock.open" : useKeychain ? "key" : "lock", color: color) {
                    NavigationLink {
                        DatabaseEncryptionView(useKeychain: $useKeychain, migration: false, stopChatRunBlockStartChat: { progressIndicator, block in
                            stopChatRunBlockStartChat(false, progressIndicator, block)
                        })
                            .navigationTitle(NSLocalizedString("Database passphrase", comment: ""))
                            .modifier(ThemedBackground(grouped: true))
                    } label: {
                        Text(NSLocalizedString("Database passphrase", comment: ""))
                    }
                }
                settingsRow("square.and.arrow.up", color: theme.colors.secondary) {
                    Button(NSLocalizedString("Export database", comment: "")) {
                        if initialRandomDBPassphraseGroupDefault.get() && !unencrypted {
                            showDatabaseEncryptionView = true
                            Task {
                                try? await Task.sleep(for: .seconds(1))
                                guard showDatabaseEncryptionView else { return }
                                alert = .exportProhibited
                            }
                        } else {
                            stopChatRunBlockStartChat(stopped, $progressIndicator) {
                                await exportArchive()
                            }
                        }
                    }
                }
                settingsRow("square.and.arrow.down", color: theme.colors.secondary) {
                    Button(NSLocalizedString("Import database", comment: ""), role: .destructive) {
                        showFileImporter = true
                    }
                }
                settingsRow("trash.slash", color: theme.colors.secondary) {
                    Button(NSLocalizedString("Delete database", comment: ""), role: .destructive) {
                        alert = .deleteChat
                    }
                }
            } header: {
                Text(NSLocalizedString("Chat database", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                    .textCase(.uppercase)
            } footer: {
                Text(NSLocalizedString("You must use the most recent version of your chat database on one device ONLY, otherwise you may stop receiving the messages from some contacts.", comment: ""))
                .foregroundColor(theme.colors.secondary)
            }
            .disabled(progressIndicator)

            if case .group = dbContainer, legacyDatabase {
                Section(header: Text(NSLocalizedString("Old database", comment: "")).font(isInDarkTheme() ? darkThemeHeaderFont() : .body).foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)) {
                    settingsRow("trash", color: theme.colors.secondary) {
                        Button(NSLocalizedString("Delete old database", comment: "")) {
                            alert = .deleteLegacyDatabase
                        }
                    }
                }
            }

            Section {
                Button(m.users.count > 1 ? NSLocalizedString("Delete files for all chat profiles", comment: "") : NSLocalizedString("Delete all files", comment: ""), role: .destructive) {
                    alert = .deleteFilesAndMedia
                }
                .disabled(progressIndicator || appFilesCountAndSize?.0 == 0)
            } header: {
                Text(NSLocalizedString("Files & media", comment: ""))
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.9) : theme.colors.secondary)
                    .textCase(.uppercase)
            } footer: {
                if let (fileCount, size) = appFilesCountAndSize {
                    if fileCount == 0 {
                        Text(NSLocalizedString("No received or sent files", comment: ""))
                            .foregroundColor(theme.colors.secondary)
                    } else {
                        Text(LocalizedStringKey(String(format: NSLocalizedString("%d file(s) with total size of %@", comment: "Database file count and size"), fileCount, ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .binary))))
                            .foregroundColor(theme.colors.secondary)
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .onAppear {
            runChat = m.chatRunning ?? true
            appFilesCountAndSize = directoryFileCountAndSize(getAppFilesDirectory())
            currentChatItemTTL = chatItemTTL
        }
        .onChange(of: chatItemTTL) {_,  ttl in
            if ttl < currentChatItemTTL {
                alert = .setChatItemTTL(ttl: ttl)
            } else if ttl != currentChatItemTTL {
                setCiTTL(ttl)
            }
        }
        .alert(item: $alert) { item in databaseAlert(item) }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(files) = result, let fileURL = files.first {
                importedArchivePath = fileURL
                alert = .importArchive
            }
        }
    }

    private func databaseAlert(_ alertItem: DatabaseAlert) -> Alert {
        switch alertItem {
        case .stopChat:
            return Alert(
                title: Text(NSLocalizedString("Stop chat?", comment: "")),
                message: Text(NSLocalizedString("Stop chat to export, import or delete chat database. You will not be able to receive and send messages while the chat is stopped.", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("Stop", comment: ""))) {
                    authStopChat()
                },
                secondaryButton: .cancel {
                    withAnimation { runChat = true }
                }
            )
        case .exportProhibited:
            return Alert(
                title: Text(NSLocalizedString("Set passphrase to export", comment: "")),
                message: Text(NSLocalizedString("Database is encrypted using a random passphrase. Please change it before exporting.", comment: ""))
            )
        case .importArchive:
            if let fileURL = importedArchivePath {
                return Alert(
                    title: Text(NSLocalizedString("Import chat database?", comment: "")),
                    message: Text(NSLocalizedString("Your current chat database will be DELETED and REPLACED with the imported one.", comment: "")) + Text(LocalizedStringKey(" ")) + Text(NSLocalizedString("This action cannot be undone - your profile, contacts, messages and files will be irreversibly lost.", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Import", comment: ""))) {
                        stopChatRunBlockStartChat(m.chatRunning == false, $progressIndicator) {
                            await DatabaseView.importArchive(fileURL, $progressIndicator, $alert, false)
                        }
                    },
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(title: Text(NSLocalizedString("Error: no database file", comment: "")))
            }
        case .archiveImported:
            let (title, message) = archiveImportedAlertText()
            return Alert(title: Text(title), message: Text(message))
        case let .archiveImportedWithErrors(errs):
            let (title, message) = archiveImportedWithErrorsAlertText(errs: errs)
            return Alert(title: Text(title), message: Text(message))
        case let .archiveExportedWithErrors(archivePath, errs):
            return Alert(
                title: Text(NSLocalizedString("Chat database exported", comment: "")),
                message: Text(NSLocalizedString("You may save the exported archive.", comment: "")) + textNewLine + Text(NSLocalizedString("Some file(s) were not exported:", comment: "")) + Text(archiveErrorsText(errs)),
                dismissButton: .default(Text(NSLocalizedString("Continue", comment: ""))) {
                    showShareSheet(items: [archivePath])
                }
            )
        case .deleteChat:
            return Alert(
                title: Text(NSLocalizedString("Delete chat profile?", comment: "")),
                message: Text(NSLocalizedString("This action cannot be undone - your profile, contacts, messages and files will be irreversibly lost.", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                    let wasStopped = m.chatRunning == false
                    stopChatRunBlockStartChat(wasStopped, $progressIndicator) {
                        _ = await deleteChat()
                        return true
                    }
                },
                secondaryButton: .cancel()
            )
        case .chatDeleted:
            let (title, message) = chatDeletedAlertText()
            return Alert(title: Text(title), message: Text(message))
        case .deleteLegacyDatabase:
            return Alert(
                title: Text(NSLocalizedString("Delete old database?", comment: "")),
                message: Text(NSLocalizedString("The old database was not removed during the migration, it can be deleted.", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                    deleteLegacyDatabase()
                },
                secondaryButton: .cancel()
            )
        case .deleteFilesAndMedia:
            return Alert(
                title: Text(NSLocalizedString("Delete files and media?", comment: "")),
                message: Text(NSLocalizedString("This action cannot be undone - all received and sent files and media will be deleted. Low resolution pictures will remain.", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                    stopChatRunBlockStartChat(m.chatRunning == false, $progressIndicator) {
                        deleteFiles()
                        return true
                    }
                },
                secondaryButton: .cancel()
            )
        case let .setChatItemTTL(ttl):
            return Alert(
                title: Text(NSLocalizedString("Enable automatic message deletion?", comment: "")),
                message: Text(NSLocalizedString("This action cannot be undone - the messages sent and received earlier than selected will be deleted. It may take several minutes.", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("Delete messages", comment: ""))) {
                    setCiTTL(ttl)
                },
                secondaryButton: .cancel() {
                    chatItemTTL = currentChatItemTTL
                }
            )
        case let .error(title, error):
            return Alert(title: Text(title), message: Text(error))
        }
    }

    private func authStopChat(_ onStop: (() -> Void)? = nil) {
        if UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA) {
            authenticate(reason: NSLocalizedString("Stop POPOPX", comment: "authentication reason")) { laResult in
                switch laResult {
                case .success: stopChat(onStop)
                case .unavailable: stopChat(onStop)
                case .failed: withAnimation { runChat = true }
                }
            }
        } else {
            stopChat(onStop)
        }
    }

    private func stopChat(_ onStop: (() -> Void)? = nil) {
        Task {
            do {
                try await stopChatAsync()
                onStop?()
            } catch let error {
                await MainActor.run {
                    runChat = true
                    showAlert(NSLocalizedString("Error stopping chat", comment: ""), message: responseError(error))
                }
            }
        }
    }

    func stopChatRunBlockStartChat(
        _ stopped: Bool,
        _ progressIndicator: Binding<Bool>,
        _ block: @escaping () async throws -> Bool
    ) {
        // if the chat was running, the sequence is: stop chat, run block, start chat.
        // Otherwise, just run block and do nothing - the toggle will be visible anyway and the user can start the chat or not
        if stopped {
            Task {
                do {
                    _ = try await block()
                } catch {
                    logger.error("Error while executing block: \(error)")
                }
            }
        } else {
            authStopChat {
                stoppingChat = true
                runChat = false
                Task {
                    // if it throws, let's start chat again anyway
                    var canStart = false
                    do {
                        canStart = try await block()
                    } catch {
                        logger.error("Error executing block: \(error)")
                        canStart = true
                    }
                    if canStart {
                        await MainActor.run {
                            DatabaseView.startChat($runChat, $progressIndicator)
                        }
                    }
                }
            }
        }
    }

    static func startChat(_ runChat: Binding<Bool>, _ progressIndicator: Binding<Bool>) {
        progressIndicator.wrappedValue = true
        let m = ChatModel.shared
        if m.chatDbChanged {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Task { @MainActor in
                    resetChatCtrl()
                    do {
                        let hadDatabase = hasDatabase()
                        try await initializeChat(start: true)
                        m.chatDbChanged = false
                        AppChatState.shared.set(.active)
                        if m.chatDbStatus != .ok || !hadDatabase {
                            // Hide current view and show `DatabaseErrorView`
                            dismissAllSheets(animated: true)
                        }
                    } catch let error {
                        logger.error("DatabaseView: Error starting chat \(responseError(error))")
                        showAlert(NSLocalizedString("Error starting chat", comment: ""), message: responseError(error))
                    }
                    progressIndicator.wrappedValue = false
                }
            }
        } else {
            do {
                _ = try apiStartChat()
                runChat.wrappedValue = true
                m.chatRunning = true
                ChatReceiver.shared.start()
                chatLastStartGroupDefault.set(Date.now)
                AppChatState.shared.set(.active)
                if shouldDeleteDatabaseBackupsDefault.get() {
                    deleteDatabaseBackups()
                    shouldDeleteDatabaseBackupsDefault.set(false)
                }
            } catch let error {
                runChat.wrappedValue = false
                showAlert(NSLocalizedString("Error starting chat", comment: ""), message: responseError(error))
            }
            progressIndicator.wrappedValue = false
        }
    }

    private func exportArchive() async -> Bool {
        await MainActor.run {
            progressIndicator = true
        }
        do {
            let (archivePath, archiveErrors) = try await exportChatArchive()
            if archiveErrors.isEmpty {
                showShareSheet(items: [archivePath])
                await MainActor.run { progressIndicator = false }
            } else {
                await MainActor.run {
                    alert = .archiveExportedWithErrors(archivePath: archivePath, archiveErrors: archiveErrors)
                    progressIndicator = false
                }
            }
        } catch let error {
            await MainActor.run {
                alert = .error(title: NSLocalizedString("Error exporting chat database", comment: "alert title"), error: responseError(error))
                progressIndicator = false
            }
        }
        return false
    }

    static func importArchive(
        _ archivePath: URL,
        _ progressIndicator: Binding<Bool>,
        _ alert: Binding<DatabaseAlert?>,
        _ migration: Bool
    ) async -> Bool {
        if archivePath.startAccessingSecurityScopedResource() {
            defer {
                archivePath.stopAccessingSecurityScopedResource()
            }
            await MainActor.run {
                progressIndicator.wrappedValue = true
            }
            do {
                try await apiDeleteStorage()
                try? FileManager.default.createDirectory(at: getWallpaperDirectory(), withIntermediateDirectories: true)
                do {
                    let config = ArchiveConfig(archivePath: archivePath.path)
                    let archiveErrors = try await apiImportArchive(config: config)
                    shouldImportAppSettingsDefault.set(true)
                    if archiveErrors.isEmpty {
                        _ = kcDatabasePassword.remove()
                        await operationEnded(.archiveImported, progressIndicator, alert)
                        return true
                    } else {
                        _ = kcDatabasePassword.remove()
                        await operationEnded(.archiveImportedWithErrors(archiveErrors: archiveErrors), progressIndicator, alert)
                        return migration
                    }
                } catch let error {
                    await operationEnded(.error(title: NSLocalizedString("Error importing chat database", comment: "alert title"), error: responseError(error)), progressIndicator, alert)
                }
            } catch let error {
                await operationEnded(.error(title: NSLocalizedString("Error deleting chat database", comment: "alert title"), error: responseError(error)), progressIndicator, alert)
            }
        } else {
            showAlert(NSLocalizedString("Error accessing database file", comment: ""))
        }
        return false
    }

    private func deleteChat() async -> Bool {
        await MainActor.run {
            progressIndicator = true
        }
        do {
            try await deleteChatAsync()
            appFilesCountAndSize = directoryFileCountAndSize(getAppFilesDirectory())
            await DatabaseView.operationEnded(.chatDeleted, $progressIndicator, $alert)
            return true
        } catch let error {
            await DatabaseView.operationEnded(.error(title: NSLocalizedString("Error deleting database", comment: "alert title"), error: responseError(error)), $progressIndicator, $alert)
            return false
        }
    }

    private func deleteLegacyDatabase() {
        if removeLegacyDatabaseAndFiles() {
            legacyDatabase = false
        } else {
            alert = .error(title: NSLocalizedString("Error deleting old database", comment: "alert title"))
        }
    }

    private static func operationEnded(_ dbAlert: DatabaseAlert, _ progressIndicator: Binding<Bool>, _ alert: Binding<DatabaseAlert?>) async {
        await MainActor.run {
            let m = ChatModel.shared
            m.chatDbChanged = true
            m.chatInitialized = false
            progressIndicator.wrappedValue = false
        }
        await withCheckedContinuation { cont in
            let okAlertActionWaiting = UIAlertAction(title: NSLocalizedString("Ok", comment: "alert button"), style: .default, handler: { _ in cont.resume() })
            // show these alerts globally so they are visible when all sheets will be hidden
            if case .archiveImported = dbAlert {
                let (title, message) = archiveImportedAlertText()
                showAlert(title, message: message, actions: { [okAlertActionWaiting] })
            } else if case .archiveImportedWithErrors(let errs) = dbAlert {
                let (title, message) = archiveImportedWithErrorsAlertText(errs: errs)
                showAlert(title, message: message, actions: { [okAlertActionWaiting] })
            } else if case .chatDeleted = dbAlert {
                let (title, message) = chatDeletedAlertText()
                showAlert(title, message: message, actions: { [okAlertActionWaiting] })
            } else if case let .error(title, error) = dbAlert {
                showAlert(title, message: error, actions: { [okAlertActionWaiting] })
            } else {
                alert.wrappedValue = dbAlert
                cont.resume()
            }
        }
    }

    private func setCiTTL(_ ttl: ChatItemTTL) {
        logger.debug("DatabaseView setChatItemTTL \(ttl.seconds)")
        progressIndicator = true
        Task {
            do {
                try await setChatItemTTL(ttl)
                await MainActor.run {
                    m.chatItemTTL = ttl
                    currentChatItemTTL = ttl
                    afterSetCiTTL()
                }
            } catch {
                await MainActor.run {
                    alert = .error(title: NSLocalizedString("Error changing setting", comment: "alert title"), error: responseError(error))
                    chatItemTTL = currentChatItemTTL
                    afterSetCiTTL()
                }
            }
        }
    }

    private func afterSetCiTTL() {
        progressIndicator = false
        appFilesCountAndSize = directoryFileCountAndSize(getAppFilesDirectory())
        do {
            let chats = try apiGetChats()
            m.updateChats(chats)
        } catch let error {
            logger.error("apiGetChats: cannot update chats \(responseError(error))")
        }
    }

    private func deleteFiles() {
        deleteAppFiles()
        appFilesCountAndSize = directoryFileCountAndSize(getAppFilesDirectory())
    }
}

func archiveImportedAlertText() -> (String, String) {
    (
        NSLocalizedString("Chat database imported", comment: ""),
        NSLocalizedString("Restart the app to use imported chat database", comment: "")
    )
}
func archiveImportedWithErrorsAlertText(errs: [ArchiveError]) -> (String, String) {
    (
        NSLocalizedString("Chat database imported", comment: ""),
        NSLocalizedString("Restart the app to use imported chat database", comment: "") + "\n" + NSLocalizedString("Some non-fatal errors occurred during import:", comment: "") + archiveErrorsText(errs)
    )
}

private func chatDeletedAlertText() -> (String, String) {
    (
        NSLocalizedString("Chat database deleted", comment: ""),
        NSLocalizedString("Restart the app to create a new chat profile", comment: "")
    )
}

func archiveErrorsText(_ errs: [ArchiveError]) -> String {
    return "\n" + errs.map(showArchiveError).joined(separator: "\n")
    
    func showArchiveError(_ err: ArchiveError) -> String {
        switch err {
        case let .import(importError): importError
        case let .fileError(file, fileError): "\(file): \(fileError)"
        }
    }
}

func stopChatAsync() async throws {
    try await apiStopChat()
    await ChatReceiver.shared.stop()
    await MainActor.run { ChatModel.shared.chatRunning = false }
    await AppChatState.shared.set(.stopped)
}

func deleteChatAsync() async throws {
    try await apiDeleteStorage()
    _ = kcDatabasePassword.remove()
    storeDBPassphraseGroupDefault.set(true)
    deleteAppDatabaseAndFiles()
    // Clean state so when creating new user the app will start chat automatically (see CreateProfile:createProfile())
    DispatchQueue.main.async {
        ChatModel.shared.users = []
    }
}

struct DatabaseView_Previews: PreviewProvider {
    @Environment(\.dismiss) static var mockDismiss

    static var previews: some View {
        DatabaseView(dismissSettingsSheet: mockDismiss, chatItemTTL: .none)
    .previewEnvironment()
    }
}
