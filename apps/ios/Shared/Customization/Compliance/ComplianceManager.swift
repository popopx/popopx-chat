// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation
import os

enum DataRegion: String, CaseIterable {
    case eu = "European Union"
    case us = "United States"
    case cn = "China"
    case other = "Other"

    var regulations: [String] {
        switch self {
        case .eu: return ["GDPR", "ePrivacy Directive"]
        case .us: return ["CCPA", "HIPAA (if applicable)"]
        case .cn: return ["PIPL", "DSL", "CSL"]
        case .other: return ["Local regulations apply"]
        }
    }

    var icon: String {
        switch self {
        case .eu: return "flag.fill"
        case .us: return "star.fill"
        case .cn: return "building.columns.fill"
        case .other: return "globe"
        }
    }
}

struct DataExportRequest: Identifiable, Codable {
    let id: String
    var requestedAt: Date
    var status: ExportStatus
    var dataCategories: [String]
    var format: ExportFormat

    enum ExportStatus: String, Codable {
        case pending = "Processing"
        case ready = "Ready for Download"
        case expired = "Expired"
        case completed = "Completed"
    }

    enum ExportFormat: String, CaseIterable, Codable {
        case json = "JSON"
        case csv = "CSV"
        case archive = "ZIP Archive"
    }
}

struct ConsentRecord: Identifiable, Codable {
    let id: String
    var purpose: String
    var granted: Bool
    var grantedAt: Date?
    var revokedAt: Date?
    var description: String
}

@MainActor
class ComplianceManager: ObservableObject {
    static let shared = ComplianceManager()

    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.popopxchat.popopx") ?? .standard
    private static let consentRecordsKey = "complianceConsentRecords"
    private static let exportRequestsKey = "complianceExportRequests"

    @Published var selectedRegion: DataRegion = .eu
    @Published var consentRecords: [ConsentRecord] = [] {
        didSet { saveConsentRecords() }
    }
    @Published var exportRequests: [DataExportRequest] = [] {
        didSet { saveExportRequests() }
    }
    @Published var dataRetentionDays: Int = 90
    @Published var autoDeleteEnabled: Bool = true
    @Published var rightToErasureRequested: Bool = false

    init() {
        loadPersistedState()
        if consentRecords.isEmpty {
            loadDefaultConsents()
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let defaults = Self.appGroupDefaults
        if let encrypted = defaults.data(forKey: Self.consentRecordsKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encrypted)
                consentRecords = try JSONDecoder().decode([ConsentRecord].self, from: data)
            } catch {
                os_log(.error, "Compliance: failed to decrypt/decode consent records: %{public}@ — clearing stale data", error.localizedDescription)
                defaults.removeObject(forKey: Self.consentRecordsKey)
            }
        }
        if let encrypted = defaults.data(forKey: Self.exportRequestsKey) {
            do {
                let data = try CryptoEncrypt.shared.decrypt(encrypted)
                exportRequests = try JSONDecoder().decode([DataExportRequest].self, from: data)
            } catch {
                os_log(.error, "Compliance: failed to decrypt/decode export requests: %{public}@ — clearing stale data", error.localizedDescription)
                defaults.removeObject(forKey: Self.exportRequestsKey)
            }
        }
    }

    private func saveConsentRecords() {
        do {
            let data = try JSONEncoder().encode(consentRecords)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: Self.consentRecordsKey)
        } catch {
            os_log(.error, "Compliance: failed to encrypt/save consent records: %{public}@", error.localizedDescription)
        }
    }

    private func saveExportRequests() {
        do {
            let data = try JSONEncoder().encode(exportRequests)
            let encrypted = try CryptoEncrypt.shared.encrypt(data)
            Self.appGroupDefaults.set(encrypted, forKey: Self.exportRequestsKey)
        } catch {
            os_log(.error, "Compliance: failed to encrypt/save export requests: %{public}@", error.localizedDescription)
        }
    }

    func updateConsent(id: String, granted: Bool) {
        if let index = consentRecords.firstIndex(where: { $0.id == id }) {
            consentRecords[index].granted = granted
            if granted {
                consentRecords[index].grantedAt = Date()
                consentRecords[index].revokedAt = nil
            } else {
                consentRecords[index].revokedAt = Date()
                consentRecords[index].grantedAt = nil
            }
        }
    }

    func requestDataExport(categories: [String], format: DataExportRequest.ExportFormat) {
        let request = DataExportRequest(
            id: UUID().uuidString,
            requestedAt: Date(),
            status: .pending,
            dataCategories: categories,
            format: format
        )
        exportRequests.insert(request, at: 0)

        Task { @MainActor in
            do {
                let _ = try await ServerAPI.shared.post(
                    "compliance/export",
                    body: [
                        "request_id": request.id,
                        "categories": categories,
                        "format": format.rawValue
                    ]
                )
                if let idx = self.exportRequests.firstIndex(where: { $0.id == request.id }) {
                    self.exportRequests[idx].status = .ready
                }
            } catch {
                os_log(.error, "Compliance: data export request failed: %{public}@", error.localizedDescription)
                if let idx = self.exportRequests.firstIndex(where: { $0.id == request.id }) {
                    self.exportRequests[idx].status = .expired
                }
            }
        }
    }

    func requestErasure() {
        rightToErasureRequested = true
        Task { @MainActor in
            do {
                let _ = try await ServerAPI.shared.post("compliance/erasure", body: ["request": "full_erasure"])
            } catch {
                os_log(.error, "Compliance: erasure request failed: %{public}@", error.localizedDescription)
                self.rightToErasureRequested = false
            }
        }
    }

    func complianceScore() -> Int {
        let totalConsents = consentRecords.count
        guard totalConsents > 0 else { return 0 }
        let grantedCount = consentRecords.filter { $0.granted }.count
        let consentRatio = 1.0 - (Double(grantedCount) / Double(totalConsents))

        var score = Int(consentRatio * 50)
        if dataRetentionDays <= 90 { score += 20 }
        if autoDeleteEnabled { score += 15 }
        if rightToErasureRequested { score += 15 }

        return min(score, 100)
    }

    private func loadDefaultConsents() {
        consentRecords = [
            ConsentRecord(id: "1", purpose: "Analytics", granted: false, grantedAt: nil, revokedAt: nil, description: "Anonymous usage analytics to improve the app"),
            ConsentRecord(id: "2", purpose: "Crash Reports", granted: false, grantedAt: nil, revokedAt: nil, description: "Send crash reports to help fix bugs"),
            ConsentRecord(id: "3", purpose: "Personalization", granted: false, grantedAt: nil, revokedAt: nil, description: "Personalize content and recommendations"),
            ConsentRecord(id: "4", purpose: "Third-party Sharing", granted: false, grantedAt: nil, revokedAt: nil, description: "Share data with trusted third-party partners"),
            ConsentRecord(id: "5", purpose: "Marketing Communications", granted: false, grantedAt: nil, revokedAt: nil, description: "Receive marketing emails and notifications"),
        ]
    }
}
