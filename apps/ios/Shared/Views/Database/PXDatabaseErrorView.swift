//
//  DatabaseErrorView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 04/09/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/database.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX extracted constants & view model

private enum PXDatabaseErrorConfig {
    static let horizontalPadding: CGFloat = 25
    static let topPadding: CGFloat = 75
    static let bottomPadding: CGFloat = 25
    static let verticalSpacing: CGFloat = 20
    static let buttonSpacing: CGFloat = 10
    static let keyFieldVerticalPadding: CGFloat = 10
    static let keyFieldCornerRadius: CGFloat = 10
    static let errorIconSize: CGFloat = 50
    static let warningIconWidth: CGFloat = 40
    static let warningIconHeight: CGFloat = 36
    static let errorViewSpacing: CGFloat = 35
    static let startDelay: Double = 0.1
    static let safeTimeDiff: TimeInterval = 10
    static let titleShadowOpacity: Double = 0.3
    static let titleShadowRadius: CGFloat = 8
    static let passphraseBottomPadding: CGFloat = 5
    static let progressScale: CGFloat = 2
    static let componentTag: String = "PX_DATABASE_ERROR_VIEW"
    static let errorIconName: String = "exclamationmark.triangle.fill"
    static let restoreIconName: String = "arrow.counterclockwise"
}

private struct PXDatabaseErrorViewModel {
    let status: DBMigrationResult
    let useKeychain: Bool
    let storedDBKey: String?
    let showRestoreButton: Bool

    var isWrongPassphrase: Bool {
        if case .errorNotADatabase = status, useKeychain, let key = storedDBKey, !key.isEmpty {
            return true
        }
        return false
    }

    var isEncryptedDB: Bool {
        if case .errorNotADatabase = status, !isWrongPassphrase {
            return true
        }
        return false
    }

    var isMigrationError: Bool {
        if case .errorMigration = status { return true }
        return false
    }

    var isSQLError: Bool {
        if case .errorSQL = status { return true }
        return false
    }

    var isKeychainError: Bool {
        if case .errorKeychain = status { return true }
        return false
    }

    var needsKeychainEntry: Bool {
        isWrongPassphrase || (isEncryptedDB && useKeychain)
    }

    var needsDirectEntry: Bool {
        isEncryptedDB && !useKeychain
    }
}

struct DatabaseErrorView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State var status: DBMigrationResult
    @State private var dbKey = ""
    @State private var storedDBKey = kcDatabasePassword.get()
    @State private var useKeychain = storeDBPassphraseGroupDefault.get()
    @State private var showRestoreDbButton = false
    @State private var starting = false

    private var vm: PXDatabaseErrorViewModel {
        PXDatabaseErrorViewModel(
            status: status,
            useKeychain: useKeychain,
            storedDBKey: storedDBKey,
            showRestoreButton: showRestoreDbButton
        )
    }

    var body: some View {
        ZStack {
            databaseErrorView().disabled(starting)
            if starting {
                ProgressView().scaleEffect(PXDatabaseErrorConfig.progressScale)
                    .accessibilityLabel(NSLocalizedString("Loading database", comment: "Accessibility"))
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX ViewBuilder helpers

    private var pxTitleShadowColor: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PXDatabaseErrorConfig.titleShadowOpacity) : .clear
    }

    private func databaseErrorView() -> some View {
        VStack(alignment: .center, spacing: PXDatabaseErrorConfig.verticalSpacing) {
            pxStatusContent
            if showRestoreDbButton {
                pxRestoreSection
            }
        }
        .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
        .padding(.top, PXDatabaseErrorConfig.topPadding)
        .padding(.bottom, PXDatabaseErrorConfig.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear() { showRestoreDbButton = shouldShowRestoreDbButton() }
    }

    @ViewBuilder
    private var pxStatusContent: some View {
        switch status {
        case let .errorNotADatabase(dbFile):
            pxNotADatabaseContent(dbFile)
        case let .errorMigration(dbFile, migrationError):
            switch migrationError {
            case let .upgrade(upMigrations):
                titleText(NSLocalizedString("dberr_upgrade", comment: "database upgrade title"))
                migrationsText(upMigrations.map(\.upName))
                Spacer()
                VStack(spacing: PXDatabaseErrorConfig.buttonSpacing) {
                    Button(NSLocalizedString("dberr_upgrade_and_open", comment: "database upgrade button")) {
                        runChat(confirmMigrations: .yesUp)
                    }
                    .buttonStyle(OnboardingButtonStyle(isDisabled: false))
                    .accessibilityLabel(NSLocalizedString("Upgrade database and open", comment: "Accessibility"))
                    fileNameText(dbFile)
                }
            case let .downgrade(downMigrations):
                let warnings = downMigrationWarnings(downMigrations).reversed()
                titleText(NSLocalizedString("dberr_downgrade", comment: "database downgrade title"))
                Spacer()
                Image(systemName: PXDatabaseErrorConfig.errorIconName)
                    .resizable()
                    .frame(width: PXDatabaseErrorConfig.warningIconWidth, height: PXDatabaseErrorConfig.warningIconHeight)
                    .foregroundColor(theme.colors.error)
                Text(NSLocalizedString("Warning: you may lose some data!", comment: "Database downgrade warning"))
                    .bold()
                    .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
                    .multilineTextAlignment(.center)
                if !warnings.isEmpty {
                    ForEach(warnings, id: \.self) { warning in
                        Text(warning)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
                    }
                }
                migrationsText(downMigrations)
                Spacer()
                VStack(spacing: PXDatabaseErrorConfig.buttonSpacing) {
                    Button(NSLocalizedString("dberr_downgrade_and_open", comment: "database downgrade button")) {
                        runChat(confirmMigrations: .yesUpDown)
                    }
                    .buttonStyle(OnboardingButtonStyle(isDisabled: false))
                    .accessibilityLabel(NSLocalizedString("Downgrade database and open", comment: "Accessibility"))
                    fileNameText(dbFile)
                }
            case let .migrationError(mtrError):
                titleText(NSLocalizedString("dberr_incompatible_version", comment: "incompatible database version title"))
                fileNameText(dbFile, font: .callout)
                errorView(Text(mtrErrorDescription(mtrError)))
            }
        case let .errorSQL(dbFile, migrationSQLError):
            titleText(NSLocalizedString("dberr_title", comment: "database error title"))
            fileNameText(dbFile, font: .callout)
            errorView(Text(String(format: NSLocalizedString("Error: %@", comment: "database error with description"), migrationSQLError)))
        case .errorKeychain:
            titleText(NSLocalizedString("dberr_keychain_title", comment: "keychain error title"))
            errorView(Text(NSLocalizedString("Cannot access keychain to save database password", comment: "Keychain error description")))
        case .errorKeyGeneration:
            titleText(NSLocalizedString("dberr_title", comment: "database error title"))
            errorView(Text(NSLocalizedString("Cannot generate random database passphrase", comment: "Key generation error description")))
        case .invalidConfirmation:
            titleText(NSLocalizedString("dberr_invalid_confirmation", comment: "invalid migration confirmation title"))
            errorView()
        case let .unknown(json):
            titleText(NSLocalizedString("dberr_title", comment: "database error title"))
            errorView(Text(String(format: NSLocalizedString("Unknown database error: %@", comment: "unknown database error with details"), json)))
        case .errorAgent:
            titleText(NSLocalizedString("dberr_title", comment: "database error title"))
            errorView(Text(NSLocalizedString("Agent error during database migration", comment: "agent error description")))
        case .ok:
            EmptyView()
        }
    }

    @ViewBuilder
    private func pxNotADatabaseContent(_ dbFile: String) -> some View {
        if vm.isWrongPassphrase {
            titleText(NSLocalizedString("dberr_wrong_passphrase", comment: "database error - wrong passphrase title"))
            Text(NSLocalizedString("Database passphrase is different from saved in the keychain.", comment: "Database error - wrong passphrase description"))
                .font(.callout)
                .foregroundColor(theme.colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
            databaseKeyField(onSubmit: saveAndRunChat)
            Spacer()
            VStack(spacing: PXDatabaseErrorConfig.buttonSpacing) {
                saveAndOpenButton()
                fileNameText(dbFile)
            }
        } else {
            titleText(NSLocalizedString("dberr_encrypted_db", comment: "database error - encrypted database title"))
            Text(NSLocalizedString("Database passphrase is required to open chat.", comment: "Database error - passphrase required description"))
                .font(.callout)
                .foregroundColor(theme.colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
                .padding(.bottom, PXDatabaseErrorConfig.passphraseBottomPadding)
            if useKeychain {
                databaseKeyField(onSubmit: saveAndRunChat)
                Spacer()
                saveAndOpenButton()
            } else {
                databaseKeyField(onSubmit: { runChat() })
                Spacer()
                openChatButton()
            }
        }
    }

    private var pxRestoreSection: some View {
        VStack {
            Spacer()
            Text(NSLocalizedString("The attempt to change database passphrase was not completed.", comment: "Database passphrase change incomplete notice"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
                .font(.footnote)
            restoreDbButton()
        }
    }

    // MARK: - POPOPX reusable components

    private func titleText(_ s: String) -> some View {
        Text(s)
            .font(.title.weight(.heavy))
            .multilineTextAlignment(.center)
            .shadow(color: pxTitleShadowColor, radius: PXDatabaseErrorConfig.titleShadowRadius, x: 0, y: 2)
    }

    private func fileNameText(_ f: String, font: Font = .caption) -> Text {
        Text(String(format: NSLocalizedString("File: %@", comment: "database file name"), (f as NSString).lastPathComponent)).font(font)
    }

    private func migrationsText(_ ms: [String]) -> some View {
        Text(pxBuildMigrationsAttributedString(ms))
            .multilineTextAlignment(.center)
            .padding(.horizontal, PXDatabaseErrorConfig.horizontalPadding)
    }

    private func pxBuildMigrationsAttributedString(_ ms: [String]) -> AttributedString {
        var pxResult = AttributedString(NSLocalizedString("dberr_migrations_label", comment: "database migrations list header"))
        pxResult.font = .subheadline
        pxResult += textNewLine
        var pxMigrations = AttributedString(ms.joined(separator: "\n"))
        pxMigrations.font = .caption
        pxResult += pxMigrations
        return pxResult
    }

    private func databaseKeyField(onSubmit: @escaping () -> Void) -> some View {
        PassphraseField(key: $dbKey, placeholder: NSLocalizedString("Enter passphrase…", comment: "Database passphrase field placeholder"), valid: validKey(dbKey), onSubmit: onSubmit)
            .padding(.vertical, PXDatabaseErrorConfig.keyFieldVerticalPadding)
            .padding(.horizontal)
            .glassBackground(cornerRadius: PXDatabaseErrorConfig.keyFieldCornerRadius)
    }

    private func saveAndOpenButton() -> some View {
        Button(NSLocalizedString("dberr_save_and_open", comment: "save passphrase and open chat button")) {
            saveAndRunChat()
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
        .accessibilityLabel(NSLocalizedString("Save passphrase and open chat", comment: "Accessibility"))
    }

    private func openChatButton() -> some View {
        Button(NSLocalizedString("dberr_open_chat", comment: "open chat button")) {
            runChat()
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
        .accessibilityLabel(NSLocalizedString("Open chat", comment: "Accessibility"))
    }

    private func errorView(_ s: Text? = nil) -> some View {
        VStack(spacing: PXDatabaseErrorConfig.errorViewSpacing) {
            Image(systemName: PXDatabaseErrorConfig.errorIconName)
                .resizable()
                .frame(width: PXDatabaseErrorConfig.errorIconSize, height: PXDatabaseErrorConfig.errorIconSize)
                .foregroundColor(QuantumColors.error)

            if let text = s {
                text
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - POPOPX actions

    private func saveAndRunChat() {
        if kcDatabasePassword.set(dbKey) {
            storeDBPassphraseGroupDefault.set(true)
            initialRandomDBPassphraseGroupDefault.set(false)
        }
        runChat()
    }

    private func runChat(confirmMigrations: MigrationConfirmation? = nil) {
        starting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + PXDatabaseErrorConfig.startDelay) {
            Task { @MainActor in
                await self.runChatSync(confirmMigrations: confirmMigrations)
                self.starting = false
            }
        }
    }

    private func runChatSync(confirmMigrations: MigrationConfirmation? = nil) async {
        do {
            resetChatCtrl()
            try await initializeChat(start: m.v3DBMigration.startChat, confirmStart: m.v3DBMigration.startChat && AppChatState.shared.value == .stopped, dbKey: useKeychain ? nil : dbKey, confirmMigrations: confirmMigrations)
            if let s = m.chatDbStatus {
                status = s
                let am = AlertManager.shared
                switch s {
                case .invalidConfirmation:
                    am.showAlert(Alert(title: Text(NSLocalizedString("dberr_invalid_confirmation", comment: "invalid migration confirmation title"))))
                case .errorNotADatabase:
                    am.showAlertMsg(
                        title: LocalizedStringKey(NSLocalizedString("Wrong passphrase!", comment: "Wrong passphrase alert title")),
                        message: LocalizedStringKey(NSLocalizedString("Enter correct passphrase.", comment: "Wrong passphrase alert message"))
                    )
                case .errorKeychain:
                    am.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("dberr_keychain_title", comment: "Keychain error alert title")))
                case .errorKeyGeneration:
                    am.showAlertMsg(title: "Database error", message: "Cannot generate random database passphrase")
                case let .errorSQL(_, error):
                    am.showAlert(Alert(
                        title: Text(NSLocalizedString("dberr_title", comment: "database error title")),
                        message: Text(verbatim: error)
                    ))
                case let .unknown(error):
                    am.showAlert(Alert(
                        title: Text(NSLocalizedString("dberr_unknown_error", comment: "unknown database error title")),
                        message: Text(verbatim: error)
                    ))
                case .errorMigration: ()
                case .errorAgent: ()
                case .ok: ()
                }
            }
        } catch let error {
            logger.error("initializeChat \(responseError(error))")
        }
    }

    private func shouldShowRestoreDbButton() -> Bool {
        if !encryptionStartedDefault.get() { return false }
        let startedAt = encryptionStartedAtDefault.get()
        return hasBackup(newerThan: startedAt - PXDatabaseErrorConfig.safeTimeDiff)
    }

    private func restoreDbButton() -> some View {
        Button() {
            AlertManager.shared.showAlert(Alert(
                title: Text(NSLocalizedString("dberr_restore_backup_title", comment: "restore database backup alert title")),
                message: Text(NSLocalizedString("dberr_restore_backup_message", comment: "restore database backup alert message")),
                primaryButton: .destructive(Text(NSLocalizedString("dberr_restore_button", comment: "restore database button"))) {
                    restoreDb()
                },
                secondaryButton: .cancel()
            ))
        } label: {
            Text(NSLocalizedString("dberr_restore_backup_label", comment: "restore database backup button label"))
        }
        .buttonStyle(OnboardingButtonStyle(isDisabled: false))
        .accessibilityLabel(NSLocalizedString("Restore database backup", comment: "Accessibility"))
    }

    private func restoreDb() {
        do {
            try restoreBackup()
            showRestoreDbButton = false
            encryptionStartedDefault.set(false)
        } catch {
            AlertManager.shared.showAlert(Alert(
                title: Text(NSLocalizedString("dberr_restore_error_title", comment: "restore database error title")),
                message: Text(verbatim: error.localizedDescription)
            ))
        }
    }
}

struct DatabaseErrorView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseErrorView(status: .errorNotADatabase(dbFile: "popopx_v1_chat.db"))
    }
}

// MARK: - POPOPX
extension DatabaseErrorView {
    var pxComponentTag: String { PXDatabaseErrorConfig.componentTag }
    var pxIsMigrationError: Bool { vm.isMigrationError }
    var pxIsKeychainMode: Bool { useKeychain }
    var pxShowRestoreAvailable: Bool { showRestoreDbButton }
}
