// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import AppIntents
import Foundation

struct ExtractTextIntent: AppIntent {
    static var title: LocalizedStringResource = "needle_extract_title"
    static var description = IntentDescription("needle_extract_desc")
    static var isDiscoverable = true

    @Parameter(title: "needle_param_text", description: "needle_param_text_desc")
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let extractions = try await NeedleProcessor.shared.extract(from: text)

        if extractions.isEmpty {
            return .result(dialog: IntentDialog(stringLiteral: NSLocalizedString("needle_no_data_found", comment: "No structured data found in the text.")))
        }

        let summary = extractions.map { extraction in
            let type = extraction.type.rawValue.capitalized
            let details = extraction.data.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "\(type): \(details)"
        }.joined(separator: "\n")

        return .result(dialog: IntentDialog(stringLiteral: "Extracted \(extractions.count) items:\n\(summary)"))
    }
}

struct ListExtractionsIntent: AppIntent {
    static var title: LocalizedStringResource = "needle_list_title"
    static var description = IntentDescription("needle_list_desc")
    static var isDiscoverable = true

    @Parameter(title: "needle_param_type", description: "needle_param_type_desc")
    var type: String?

    init() {}

    init(type: String? = nil) {
        self.type = type
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = LocalExtractionStore.shared
        let items: [Extraction]

        if let type, let extractionType = ExtractionType(rawValue: type) {
            items = store.fetchByType(extractionType)
        } else {
            items = store.fetchAll()
        }

        if items.isEmpty {
            return .result(dialog: IntentDialog(stringLiteral: NSLocalizedString("needle_no_extractions_found", comment: "No extractions found.")))
        }

        let summary = items.prefix(20).map { item in
            let type = item.type.rawValue.capitalized
            let details = item.data.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "[\(type)] \(details)"
        }.joined(separator: "\n")

        let countMessage = items.count > 20 ? " (showing first 20 of \(items.count))" : ""
        return .result(dialog: IntentDialog(stringLiteral: "\(items.count) extractions\(countMessage):\n\(summary)"))
    }
}

struct GetExtractionStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "needle_stats_title"
    static var description = IntentDescription("needle_stats_desc")
    static var isDiscoverable = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = LocalExtractionStore.shared
        let allItems = store.fetchAll()

        let stats = Dictionary(grouping: allItems, by: \.type)
            .map { "\($0.key.rawValue.capitalized): \($0.value.count)" }
            .sorted()
            .joined(separator: "\n")

        let message = String(format: NSLocalizedString("needle_stats_summary", comment: ""), allItems.count, stats)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
