//
//  MigrateToGroupView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 20/06/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/database.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX migration layout metrics
private enum PXMigMetrics {
    static let pxTitleTopPadding: CGFloat = 60
    static let pxSectionSpacing: CGFloat = 18
    static let pxInnerStackSpacing: CGFloat = 10
    static let pxProgressScale: CGFloat = 2.2
    static let pxShadowRadius: CGFloat = 10
    static let pxShadowOffsetY: CGFloat = 3
    static let pxShadowOpacity: Double = 0.25
    static let pxErrorTopPadding: CGFloat = 60
}

enum V3DBMigrationState: String {
    case offer
    case postponed
    case exporting
    case export_error
    case exported
    case migrating
    case migration_error
    case migrated
    case ready

    // POPOPX: quick check whether this state allows entering the chat
    var startChat: Bool {
        switch self {
        case .postponed: return true
        case .ready: return true
        default: return false
        }
    }
}

let v3DBMigrationDefault = EnumDefault<V3DBMigrationState>(
    defaults: UserDefaults.standard,
    forKey: DEFAULT_CHAT_V3_DB_MIGRATION,
    withDefault: .offer
)

struct MigrateToAppGroupView: View {
    @EnvironmentObject var chatModel: ChatModel
    @State private var migrationError = ""
    @AppStorage(DEFAULT_CHAT_ARCHIVE_NAME) private var chatArchiveName: String?
    @AppStorage(DEFAULT_CHAT_ARCHIVE_TIME) private var chatArchiveTime: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(NSLocalizedString("Push notifications", comment: ""))
                .shadow(color: pxTitleShadowColor, radius: PXMigMetrics.pxShadowRadius, x: 0, y: PXMigMetrics.pxShadowOffsetY)
                .font(.title.weight(.heavy))

            switch chatModel.v3DBMigration {
            case .offer:
                pxOfferSection
            case .exporting:
                pxExportingSection
            case .export_error:
                pxExportErrorSection
            case .exported:
                center {
                    Text(NSLocalizedString("Exported database archive.", comment: ""))
                }
            case .migrating:
                pxMigratingSection
            case .migration_error:
                pxMigrationErrorSection
            case .migrated:
                pxMigratedSection
            default:
                pxUnexpectedStateSection
            }
        }
        .popopxBranded()
        .padding()
    }

    // MARK: - POPOPX section builders

    private var pxTitleShadowColor: Color {
        isInDarkTheme() ? darkThemeAccentColor().opacity(PXMigMetrics.pxShadowOpacity) : .clear
    }

    private var pxOfferSection: some View {
        Group {
            VStack(alignment: .leading, spacing: PXMigMetrics.pxSectionSpacing) {
                Text(NSLocalizedString("To support instant push notifications the chat database has to be migrated.", comment: ""))
                Text(NSLocalizedString("If you need to use the chat now tap **Do it later** below (you will be offered to migrate the database when you restart the app).", comment: ""))
            }
            .padding(.top, PXMigMetrics.pxTitleTopPadding)
            center {
                Button {
                    migrateDatabaseToV3()
                } label: {
                    Text(NSLocalizedString("Start migration", comment: ""))
                        .frame(maxWidth: .infinity)
                        .font(.title)
                }
            }
            skipMigration()
        }
    }

    private var pxExportingSection: some View {
        Group {
            center {
                Text(NSLocalizedString("Exporting database archive…", comment: ""))
                ProgressView(value: 0.33)
            }
            migrationProgress()
        }
    }

    private var pxExportErrorSection: some View {
        VStack(spacing: 0) {
            migrationFailed().padding(.top, PXMigMetrics.pxErrorTopPadding)
            center {
                Text(migrationError)
                Text(NSLocalizedString("Export error:", comment: "")).font(.headline)
            }
            skipMigration()
        }
    }

    private var pxMigratingSection: some View {
        Group {
            center {
                Text(NSLocalizedString("Migrating database archive…", comment: ""))
                ProgressView(value: 0.67)
            }
            migrationProgress()
        }
    }

    private var pxMigrationErrorSection: some View {
        Group {
            VStack(alignment: .leading, spacing: PXMigMetrics.pxSectionSpacing) {
                Text(NSLocalizedString("The created archive is available via app Settings / Database / Old database archive.", comment: ""))
                migrationFailed()
            }
            .padding(.top, PXMigMetrics.pxTitleTopPadding)
            center {
                Text(migrationError)
                Text(NSLocalizedString("Migration error:", comment: "")).font(.headline)
            }
            skipMigration()
        }
    }

    private var pxMigratedSection: some View {
        VStack(spacing: 0) {
            center {
                Text(NSLocalizedString("Migration is completed", comment: ""))
                ProgressView(value: 1.0)
            }
            VStack {
                Spacer()
                Spacer()
                Spacer()
                Button {
                    Task { @MainActor in
                        do {
                            resetChatCtrl()
                            try await initializeChat(start: true)
                            advanceOnboarding(to: .step2_NetworkAndCommitments)
                            setV3DBMigration(.ready)
                        } catch let error {
                            dbContainerGroupDefault.set(.documents)
                            setV3DBMigration(.migration_error)
                            migrationError = String.localizedStringWithFormat(NSLocalizedString("Error starting chat: %@", comment: ""), responseError(error))
                        }
                        deleteOldChatArchive()
                    }
                } label: {
                    Text(NSLocalizedString("Start chat", comment: ""))
                        .frame(maxWidth: .infinity)
                        .font(.title)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var pxUnexpectedStateSection: some View {
        VStack {
            Spacer()
            Text(LocalizedStringKey("\(chatModel.v3DBMigration.rawValue)"))
            Text(NSLocalizedString("Unexpected migration state", comment: ""))
            Spacer()
            skipMigration()
        }
    }

    // POPOPX: centered content helper with adjusted spacing
    private func center<Content>(@ViewBuilder c: @escaping () -> Content) -> some View where Content: View {
        VStack(alignment: .leading, spacing: PXMigMetrics.pxInnerStackSpacing) { c() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func migrationProgress() -> some View {
        VStack {
            Spacer()
            ProgressView().scaleEffect(PXMigMetrics.pxProgressScale)
            Spacer()
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func migrationFailed() -> some View {
        Text(NSLocalizedString("Migration failed. Tap **Skip** below to continue using the current database. Please report the issue to the app developers via chat or email [support@popopxchat.com](mailto:support@popopxchat.com).", comment: ""))
    }

    private func skipMigration() -> some View {
        ZStack {
            Button {
                setV3DBMigration(.postponed)
                do {
                    try startChat()
                } catch let error {
                    logger.error("Failed to start or load chats: \(responseError(error))")
                    migrationError = responseError(error)
                }
            } label: {
                Text(NSLocalizedString("Do it later", comment: ""))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func setV3DBMigration(_ state: V3DBMigrationState) {
        chatModel.v3DBMigration = state
        v3DBMigrationDefault.set(state)
    }

    // POPOPX: migration orchestration split into export + import phases
    func migrateDatabaseToV3() {
        setV3DBMigration(.exporting)
        let pxArchiveTimestamp = Date.now
        let pxArchiveFileName = "popopx.\(pxArchiveTimestamp.ISO8601Format()).zip"
        chatArchiveTime = pxArchiveTimestamp.timeIntervalSince1970
        chatArchiveName = pxArchiveFileName
        let pxExportConfig = ArchiveConfig(archivePath: getDocumentsDirectory().appendingPathComponent(pxArchiveFileName).path)
        Task {
            await pxPerformExportPhase(config: pxExportConfig)
            await pxPerformImportPhase(config: pxExportConfig)
        }
    }

    private func pxPerformExportPhase(config: ArchiveConfig) async {
        do {
            try apiSaveAppSettings(settings: AppSettings.current.prepareForExport())
            try? FileManager.default.createDirectory(at: getWallpaperDirectory(), withIntermediateDirectories: true)
            _ = try await apiExportArchive(config: config)
            await MainActor.run { setV3DBMigration(.exported) }
        } catch let error {
            await MainActor.run {
                setV3DBMigration(.export_error)
                migrationError = responseError(error)
            }
        }
    }

    private func pxPerformImportPhase(config: ArchiveConfig) async {
        guard chatModel.v3DBMigration == .exported else { return }
        do {
            await MainActor.run { setV3DBMigration(.migrating) }
            dbContainerGroupDefault.set(.group)
            resetChatCtrl()
            try await initializeChat(start: false)
            let _ = try await apiImportArchive(config: config)
            let pxImportedSettings = try apiGetAppSettings(settings: AppSettings.current.prepareForExport())
            await MainActor.run {
                pxImportedSettings.importIntoApp()
                setV3DBMigration(.migrated)
            }
        } catch let error {
            dbContainerGroupDefault.set(.documents)
            await MainActor.run {
                setV3DBMigration(.migration_error)
                migrationError = responseError(error)
            }
        }
    }
}

func exportChatArchive(_ storagePath: URL? = nil) async throws -> (URL, [ArchiveError]) {
    let pxNow = Date.now
    let pxFormatted = pxNow.ISO8601Format(Date.ISO8601FormatStyle(timeSeparator: .omitted))
    let pxFinalArchiveName = "popopx.\(pxFormatted).zip"
    let pxTargetPath = (storagePath ?? getDocumentsDirectory()).appendingPathComponent(pxFinalArchiveName)
    let pxConfig = ArchiveConfig(archivePath: pxTargetPath.path)
    // POPOPX: save settings before passphrase change to avoid DB migration prerequisite
    let pxChatDbChanged = await MainActor.run { ChatModel.shared.chatDbChanged }
    if !pxChatDbChanged {
        let pxSettings = await MainActor.run { AppSettings.current.prepareForExport() }
        try apiSaveAppSettings(settings: pxSettings)
    }
    try? FileManager.default.createDirectory(at: getWallpaperDirectory(), withIntermediateDirectories: true)
    let pxExportErrors = try await apiExportArchive(config: pxConfig)
    if storagePath == nil {
        deleteOldChatArchive()
        UserDefaults.standard.set(pxFinalArchiveName, forKey: DEFAULT_CHAT_ARCHIVE_NAME)
        chatArchiveTimeDefault.set(pxNow)
    }
    return (pxTargetPath, pxExportErrors)
}

/// Deprecated. Remove in the end of 2025. All unused archives should be deleted for the most users til then.
/// Remove DEFAULT_CHAT_ARCHIVE_NAME and DEFAULT_CHAT_ARCHIVE_TIME as well
func deleteOldChatArchive() {
    let pxDefaults = UserDefaults.standard
    if let pxStoredName = pxDefaults.string(forKey: DEFAULT_CHAT_ARCHIVE_NAME) {
        do {
            try FileManager.default.removeItem(atPath: getDocumentsDirectory().appendingPathComponent(pxStoredName).path)
            pxDefaults.set(nil, forKey: DEFAULT_CHAT_ARCHIVE_NAME)
            pxDefaults.set(0, forKey: DEFAULT_CHAT_ARCHIVE_TIME)
        } catch let error {
            logger.error("removeItem error \(String(describing: error))")
        }
    }
}

struct MigrateToGroupView_Previews: PreviewProvider {
    static var previews: some View {
        let chatModel = ChatModel()
        chatModel.v3DBMigration = .migrated
        return MigrateToAppGroupView()
            .environmentObject(chatModel)
    }
}

// MARK: - POPOPX
extension MigrateToAppGroupView {
    var pxMigrationTitle: String {
        NSLocalizedString("POPOPX Data Migration", comment: "POPOPX migration branding")
    }
}
