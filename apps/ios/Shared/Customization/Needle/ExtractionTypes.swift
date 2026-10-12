// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import Foundation

extension Notification.Name {
    static let needleExtractionCompleted = Notification.Name("needleExtractionCompleted")
}

enum ExtractionType: String, Codable, CaseIterable, Sendable {
    case calendar
    case expense
    case todo
    case note
    case asset
    case contact

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .expense: return "dollarsign.circle"
        case .todo: return "checkmark.circle"
        case .note: return "note.text"
        case .asset: return "vault"
        case .contact: return "person.crop.circle"
        }
    }

    var tint: String {
        switch self {
        case .calendar: return "blue"
        case .expense: return "orange"
        case .todo: return "green"
        case .note: return "gray"
        case .asset: return "purple"
        case .contact: return "teal"
        }
    }

    var displayName: String {
        switch self {
        case .calendar: return NSLocalizedString("needle.type.calendar", comment: "")
        case .expense: return NSLocalizedString("needle.type.expense", comment: "")
        case .todo: return NSLocalizedString("needle.type.todo", comment: "")
        case .note: return NSLocalizedString("needle.type.note", comment: "")
        case .asset: return NSLocalizedString("needle.type.asset", comment: "")
        case .contact: return NSLocalizedString("needle.type.contact", comment: "")
        }
    }
}

struct Extraction: Codable, Identifiable, Sendable {
    let id: UUID
    let type: ExtractionType
    let data: [String: String]
    let sourceText: String
    let chatId: String?
    let createdAt: Date

    init(id: UUID = UUID(), type: ExtractionType, data: [String: String], sourceText: String, chatId: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.data = data
        self.sourceText = sourceText
        self.chatId = chatId
        self.createdAt = createdAt
    }
}
