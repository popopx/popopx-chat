//
//  DatabaseEncryptionView.swift
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

// MARK: - POPOPX Configuration
private enum PXDBEncryptionConfig {
    static let progressScale: CGFloat = 2
    static let footerSpacing: CGFloat = 16
    static let footerTopPadding: CGFloat = 1
    static let headerOpacityDark: Double = 0.9
    static let passphraseIconWidth: CGFloat = 20
    static let passphraseIconHeight: CGFloat = 22
    static let passphraseFieldLeading: CGFloat = 36
}

enum DatabaseEncryptionAlert: Identifiable {
    case keychainRemoveKey
    case encryptDatabaseSaved
    case encryptDatabase
    case changeDatabaseKeySaved
    case changeDatabaseKey
    case databaseEncrypted
    case currentPassphraseError
    case error(title: LocalizedStringKey, error: LocalizedStringKey = "")

    var id: String {
        switch self {
        case .keychainRemoveKey: return "keychainRemoveKey"
        case .encryptDatabaseSaved: return "encryptDatabaseSaved"
        case .encryptDatabase: return "encryptDatabase"
        case .changeDatabaseKeySaved: return "changeDatabaseKeySaved"
        case .changeDatabaseKey: return "changeDatabaseKey"
        case .databaseEncrypted: return "databaseEncrypted"
        case .currentPassphraseError: return "currentPassphraseError"
        case let .error(title, _): return "error \(title)"
        }
    }
}

// Spec: spec/database.md#DatabaseEncryptionView
struct DatabaseEncryptionView: View {
    @EnvironmentObject private var m: ChatModel
    @EnvironmentObject private var theme: AppTheme
    @Binding var useKeychain: Bool
    var migration: Bool
    @State private var alert: DatabaseEncryptionAlert? = nil
    @State private var progressIndicator = false
    @State private var useKeychainToggle = storeDBPassphraseGroupDefault.get()
    @State private var initialRandomDBPassphrase = initialRandomDBPassphraseGroupDefault.get()
    @State private var storedKey = kcDatabasePassword.get() != nil
    @State private var currentKey = ""
    @State private var newKey = ""
    @State private var confirmNewKey = ""
    @State private var currentKeyShown = false

    let stopChatRunBlockStartChat: (Binding<Bool>, @escaping () async throws -> Bool) -> Void

    var body: some View {
        ZStack {
            List {
                if migration {
                    pxMigrationStoppedView
                }
                pxEncryptionFormSection
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            if progressIndicator {
                ProgressView().scaleEffect(PXDBEncryptionConfig.progressScale)
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX View Builders

    private var pxMigrationStoppedView: some View {
        chatStoppedView()
    }

    private var pxEncryptionFormSection: some View {
        databaseEncryptionView()
    }

    private var pxHeaderColor: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PXDBEncryptionConfig.headerOpacityDark) : theme.colors.secondary
    }

    private func databaseEncryptionView() -> some View {
        Section {
            settingsRow(storedKey ? "key.fill" : "key", color: storedKey ? QuantumColors.success : theme.colors.secondary) {
                Toggle(NSLocalizedString("Save passphrase in Keychain", comment: ""), isOn: $useKeychainToggle)
                    .onChange(of: useKeychainToggle) {_, _ in
                        if useKeychainToggle {
                            pxSetUseKeychain(true)
                        } else if storedKey && !migration {
                            // Don't show in migration process since it will remove the key after successfull encryption
                            alert = .keychainRemoveKey
                        } else {
                            pxSetUseKeychain(false)
                        }
                    }
                    .disabled(initialRandomDBPassphrase && !migration)
                    .accessibilityLabel(NSLocalizedString("Toggle keychain passphrase storage", comment: "Accessibility label for keychain toggle"))
            }

            if !initialRandomDBPassphrase && m.chatDbEncrypted == true {
                PassphraseField(key: $currentKey, placeholder: NSLocalizedString("Current passphrase…", comment: ""), valid: pxValidateKey(currentKey))
            }

            PassphraseField(key: $newKey, placeholder: NSLocalizedString("New passphrase…", comment: ""), valid: pxValidateKey(newKey), showStrength: true)
            PassphraseField(key: $confirmNewKey, placeholder: NSLocalizedString("Confirm new passphrase…", comment: ""), valid: confirmNewKey == "" || newKey == confirmNewKey)

            settingsRow("lock.rotation", color: theme.colors.secondary) {
                Button(migration ? NSLocalizedString("Set passphrase", comment: "") : NSLocalizedString("Update database passphrase", comment: "")) {
                    alert = currentKey == ""
                    ? (useKeychain ? .encryptDatabaseSaved : .encryptDatabase)
                    : (useKeychain ? .changeDatabaseKeySaved : .changeDatabaseKey)
                }
                .accessibilityLabel(migration ? NSLocalizedString("Set database passphrase", comment: "") : NSLocalizedString("Update database passphrase", comment: ""))
            }
            .disabled(
                (m.chatDbEncrypted == true && currentKey == "") ||
                currentKey == newKey ||
                newKey != confirmNewKey ||
                newKey == "" ||
                !pxValidateKey(currentKey) ||
                !pxValidateKey(newKey)
            )
        } header: {
            Text(migration ? NSLocalizedString("Database passphrase", comment: "") : "")
                .font(.caption.weight(.bold))
                .foregroundColor(pxHeaderColor)
                .textCase(.uppercase)
        } footer: {
            pxSectionFooter
        }
        .onAppear {
            if initialRandomDBPassphrase { currentKey = kcDatabasePassword.get() ?? "" }
        }
        .disabled(progressIndicator)
        .alert(item: $alert) { item in pxResolveAlert(item) }
    }

    // MARK: - POPOPX Footer Builder

    @ViewBuilder private var pxSectionFooter: some View {
        VStack(alignment: .leading, spacing: PXDBEncryptionConfig.footerSpacing) {
            if m.chatDbEncrypted == false {
                Text(NSLocalizedString("Your chat database is not encrypted - set passphrase to encrypt it.", comment: ""))
            } else if useKeychain {
                if storedKey {
                    Text(NSLocalizedString("iOS Keychain is used to securely store passphrase - it allows receiving push notifications.", comment: ""))
                    if initialRandomDBPassphrase && !migration {
                        Text(NSLocalizedString("Database is encrypted using a random passphrase, you can change it.", comment: ""))
                    } else {
                        Text(NSLocalizedString("**Please note**: you will NOT be able to recover or change passphrase if you lose it.", comment: ""))
                    }
                } else {
                    Text(NSLocalizedString("iOS Keychain will be used to securely store passphrase after you restart the app or change passphrase - it will allow receiving push notifications.", comment: ""))
                }
            } else {
                Text(NSLocalizedString("You have to enter passphrase every time the app starts - it is not stored on the device.", comment: ""))
                Text(NSLocalizedString("**Please note**: you will NOT be able to recover or change passphrase if you lose it.", comment: ""))
                if  m.notificationMode == .instant && m.notificationPreview != .hidden && !migration {
                    Text(NSLocalizedString("**Warning**: Instant push notifications require passphrase saved in Keychain.", comment: ""))
                }
            }
        }
        .foregroundColor(theme.colors.secondary)
        .padding(.top, PXDBEncryptionConfig.footerTopPadding)
        .font(.callout)
    }

    // MARK: - POPOPX Encryption Logic

    private func encryptDatabaseAsync() async -> Bool {
        await MainActor.run {
            progressIndicator = true
        }

        return await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                encryptionStartedDefault.set(true)
                encryptionStartedAtDefault.set(Date.now)
                if !m.chatDbChanged {
                    try apiSaveAppSettings(settings: AppSettings.current.prepareForExport())
                }

                // Derive key from passphrase using PBKDF2
                let salt = generateRandomSalt()
                guard let derived = deriveKey(from: newKey, salt: salt) else {
                    throw ChatError.errorDatabase(databaseError: .errorExport(sqliteError: .errorNotADatabase))
                }

                // Use the derived key for encryption
                try await apiStorageEncryption(currentKey: currentKey, newKey: derived.key)
                if currentKey != newKey {
                    shouldDeleteDatabaseBackupsDefault.set(true)
                }

                try Task.checkCancellation()
                encryptionStartedDefault.set(false)
                initialRandomDBPassphraseGroupDefault.set(false)

                if migration {
                    storeDBPassphraseGroupDefault.set(useKeychain)
                }

                if useKeychain {
                    guard kcDatabaseSalt.set(derived.salt) else {
                        await pxResetFormAfterEncryption()
                        await pxOperationEnded(.error(title: LocalizedStringKey(NSLocalizedString("Keychain error", comment: "")), error: LocalizedStringKey(NSLocalizedString("Error saving salt to keychain", comment: ""))))
                        return false
                    }
                    guard kcDatabasePassword.set(newKey) else {
                        _ = kcDatabaseSalt.remove()
                        await pxResetFormAfterEncryption()
                        await pxOperationEnded(.error(title: LocalizedStringKey(NSLocalizedString("Keychain error", comment: "")), error: LocalizedStringKey(NSLocalizedString("Error saving passphrase to keychain", comment: ""))))
                        return false
                    }
                    await pxResetFormAfterEncryption(true)
                    await pxOperationEnded(.databaseEncrypted)

                    if UserDefaults.standard.bool(forKey: "databaseKeyRotationNeeded") {
                        completeKeyRotation(newPassphrase: newKey, salt: derived.salt)
                    }
                } else {
                    if migration {
                        removePassphraseFromKeyChain()
                    }
                    await pxResetFormAfterEncryption()
                    await pxOperationEnded(.databaseEncrypted)
                }
                return true
            } catch is CancellationError {
                await MainActor.run {
                    progressIndicator = false
                    alert = .error(title: LocalizedStringKey(NSLocalizedString("Encryption cancelled", comment: "")))
                }
                return false
            } catch let error {
                if case .errorDatabase(.errorExport(.errorNotADatabase)) = error as? ChatError {
                    await pxOperationEnded(.currentPassphraseError)
                } else {
                    await pxOperationEnded(.error(title: LocalizedStringKey(NSLocalizedString("Error encrypting database", comment: "")), error: LocalizedStringKey("\(responseError(error))")))
                }
                return false
            }
        } onCancel: {
            // Cleanup if needed
        }
    }

    private func encryptDatabase() {
        // it will try to stop and start the chat in case of: non-migration && successful encryption. In migration the chat will remain stopped
        if migration {
            Task {
                await encryptDatabaseAsync()
            }
        } else {
            stopChatRunBlockStartChat($progressIndicator) {
                return await encryptDatabaseAsync()
            }
        }
    }

    private func pxResetFormAfterEncryption(_ stored: Bool = false) async {
        await MainActor.run {
            m.chatDbEncrypted = true
            initialRandomDBPassphrase = false
            currentKey = ""
            newKey = ""
            confirmNewKey = ""
            storedKey = stored
        }
    }

    private func pxSetUseKeychain(_ value: Bool) {
        useKeychain = value
        // Postpone it when migrating to the end of encryption process
        if !migration {
            storeDBPassphraseGroupDefault.set(value)
        }
    }

    // MARK: - POPOPX Alert Resolution

    private func pxResolveAlert(_ alertItem: DatabaseEncryptionAlert) -> Alert {
        switch alertItem {
        case .keychainRemoveKey:
            return Alert(
                title: Text(NSLocalizedString("Remove passphrase from keychain?", comment: "")),
                message: Text(NSLocalizedString("Instant push notifications will be hidden!\n", comment: "")) + pxStoreSecurelyDanger(),
                primaryButton: .destructive(Text(NSLocalizedString("Remove", comment: ""))) {
                    removePassphraseFromKeyChain()
                },
                secondaryButton: .cancel() {
                    withAnimation { useKeychainToggle = true }
                }
            )
        case .encryptDatabaseSaved:
            return Alert(
                title: Text(NSLocalizedString("Encrypt database?", comment: "")),
                message: Text(NSLocalizedString("Database will be encrypted and the passphrase stored in the keychain.\n", comment: "")) + pxStoreSecurelySaved(),
                primaryButton: .default(Text(NSLocalizedString("Encrypt", comment: "")))  { encryptDatabase() },
                secondaryButton: .cancel()
            )
        case .encryptDatabase:
            return Alert(
                title: Text(NSLocalizedString("Encrypt database?", comment: "")),
                message: Text(NSLocalizedString("Database will be encrypted.\n", comment: "")) + pxStoreSecurelyDanger(),
                primaryButton: .destructive(Text(NSLocalizedString("Encrypt", comment: ""))) { encryptDatabase() },
                secondaryButton: .cancel()
            )
        case .changeDatabaseKeySaved:
            return Alert(
                title: Text(NSLocalizedString("Change database passphrase?", comment: "")),
                message: Text(NSLocalizedString("Database encryption passphrase will be updated and stored in the keychain.\n", comment: "")) + pxStoreSecurelySaved(),
                primaryButton: .default(Text(NSLocalizedString("Update", comment: ""))) { encryptDatabase() },
                secondaryButton: .cancel()
            )
        case .changeDatabaseKey:
            return Alert(
                title: Text(NSLocalizedString("Change database passphrase?", comment: "")),
                message: Text(NSLocalizedString("Database encryption passphrase will be updated.\n", comment: "")) + pxStoreSecurelyDanger(),
                primaryButton: .destructive(Text(NSLocalizedString("Update", comment: ""))) { encryptDatabase() },
                secondaryButton: .cancel()
            )
        case .databaseEncrypted:
            return Alert(title: Text(NSLocalizedString("Database encrypted!", comment: "")))
        case .currentPassphraseError:
            return Alert(
                title: Text(NSLocalizedString("Wrong passphrase!", comment: "")),
                message: Text(NSLocalizedString("Please enter correct current passphrase.", comment: ""))
            )
        case let .error(title, error):
            return Alert(title: Text(title), message: Text(error))
        }
    }

    private func removePassphraseFromKeyChain() {
        if kcDatabasePassword.remove() {
            logger.debug("passphrase removed from keychain")
            pxSetUseKeychain(false)
            storedKey = false
        } else {
            alert = .error(title: LocalizedStringKey(NSLocalizedString("Keychain error", comment: "")), error: LocalizedStringKey(NSLocalizedString("Failed to remove passphrase", comment: "")))
        }
    }

    private func pxStoreSecurelySaved() -> Text {
        Text(NSLocalizedString("Please store passphrase securely, you will NOT be able to change it if you lose it.", comment: ""))
    }

    private func pxStoreSecurelyDanger() -> Text {
        Text(NSLocalizedString("Please store passphrase securely, you will NOT be able to access chat if you lose it.", comment: ""))
    }

    private func pxOperationEnded(_ dbAlert: DatabaseEncryptionAlert) async {
        await MainActor.run {
            m.chatDbChanged = true
            m.chatInitialized = false
            progressIndicator = false
            alert = dbAlert
        }
    }
}


struct PassphraseField: View {
    @EnvironmentObject var theme: AppTheme
    @Binding var key: String
    var placeholder: String
    var valid: Bool
    var showStrength = false
    var onSubmit: () -> Void = {}
    @State private var showKey = false

    var body: some View {
        ZStack(alignment: .leading) {
            let pxIconTint = pxResolvedIconColor
            Button {
                showKey = !showKey
            } label: {
                Image(systemName: valid ? (showKey ? "eye.slash" : "eye") : "exclamationmark.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: PXDBEncryptionConfig.passphraseIconWidth, height: PXDBEncryptionConfig.passphraseIconHeight, alignment: .center)
                    .foregroundColor(pxIconTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showKey ? NSLocalizedString("db_hide_passphrase", comment: "Hide passphrase accessibility label") : NSLocalizedString("db_show_passphrase", comment: "Show passphrase accessibility label"))
            pxTextFieldContent
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .submitLabel(.done)
                .padding(.leading, PXDBEncryptionConfig.passphraseFieldLeading)
                .onSubmit(onSubmit)
        }
    }

    private var pxResolvedIconColor: Color {
        valid
        ? (showStrength && key != "" ? PassphraseStrength(passphrase: key).color : theme.colors.secondary)
        : QuantumColors.error
    }

    @ViewBuilder private var pxTextFieldContent: some View {
        if showKey {
            TextField(placeholder, text: $key)
        } else {
            SecureField(placeholder, text: $key)
        }
    }
}

// MARK: - POPOPX Passphrase Utilities

/// Computes passphrase entropy based on character pool size
private func pxComputePassphraseEntropy(_ s: String) -> Double {
    guard !s.isEmpty else { return 0 }
    var hasDigits = false
    var hasUppercase = false
    var hasLowercase = false
    var hasSymbols = false
    for c in s {
        if c.isNumber {
            hasDigits = true
        } else if c.isLetter {
            if c.isUppercase { hasUppercase = true }
            else { hasLowercase = true }
        } else if c.isASCII {
            hasSymbols = true
        }
    }
    let poolSize: Double = (hasDigits ? 10 : 0) + (hasUppercase ? 26 : 0) + (hasLowercase ? 26 : 0) + (hasSymbols ? 32 : 0)
    return Double(s.count) * log2(poolSize)
}

enum PassphraseStrength {
    case veryWeak
    case weak
    case reasonable
    case strong

    init(passphrase s: String) {
        let entropy = pxComputePassphraseEntropy(s)
        self = entropy > 100
                ? .strong
                : entropy > 70
                ? .reasonable
                : entropy > 40
                ? .weak
                : .veryWeak
    }

    var color: Color {
        switch self {
        case .veryWeak: return QuantumColors.error
        case .weak: return QuantumColors.warning
        case .reasonable: return QuantumColors.warning
        case .strong: return QuantumColors.success
        }
    }
}

func validKey(_ s: String) -> Bool {
    for c in s { if c.isWhitespace || !c.isASCII { return false } }
    return true
}

private func pxValidateKey(_ s: String) -> Bool {
    validKey(s)
}

struct DatabaseEncryptionView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseEncryptionView(useKeychain: Binding.constant(true), migration: false, stopChatRunBlockStartChat: { _, _ in })
    .previewEnvironment()
    }
}
