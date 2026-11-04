//
//  DatabaseState.swift
//  POPOPX
//
//  Extracted from AppStateModel - Database initialization and migration state
//

import Foundation
import Combine
@preconcurrency import POPOPXSwitch

@MainActor
final class DatabaseState: ObservableObject {
    static let shared = DatabaseState()

    @Published var v3DBMigration: V3DBMigrationState = v3DBMigrationDefault.get()
    @Published var chatInitialized = false
    @Published var chatRunning: Bool?
    @Published var chatDbChanged = false
    @Published var chatDbEncrypted: Bool?
    @Published var chatDbStatus: DBMigrationResult?
    @Published var ctrlInitInProgress: Bool = false

    func reset() {
        v3DBMigration = v3DBMigrationDefault.get()
        chatInitialized = false
        chatRunning = nil
        chatDbChanged = false
        chatDbEncrypted = nil
        chatDbStatus = nil
        ctrlInitInProgress = false
    }
}
