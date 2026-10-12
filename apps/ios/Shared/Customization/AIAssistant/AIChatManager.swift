// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/ai-assistant
import SwiftUI
import Combine

enum AIModel: String, CaseIterable, Identifiable {
    case gpt4 = "GPT-4"
    case gpt35 = "GPT-3.5"
    case claude = "Claude"

    var id: String { rawValue }

    var provider: String {
        switch self {
        case .gpt4, .gpt35: return "OpenAI"
        case .claude: return "Anthropic"
        }
    }

    var costPerToken: String {
        switch self {
        case .gpt4: return NSLocalizedString("$0.06 / 1K tokens", comment: "GPT-4 cost per token")
        case .gpt35: return NSLocalizedString("$0.002 / 1K tokens", comment: "GPT-3.5 cost per token")
        case .claude: return NSLocalizedString("$0.008 / 1K tokens", comment: "Claude cost per token")
        }
    }
}

struct AIMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    var content: String
    let timestamp: Date = Date()
}

@MainActor
class AIChatManager: ObservableObject {
    static let shared = AIChatManager()

    @Published var messages: [AIMessage] = []
    @Published var selectedModel: AIModel = .gpt4
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let maxMessages = 200
    private let keepMessages = 100

    private let privacyGuard = AIPrivacyGuard()

    func sendMessage(_ text: String) async {
        let sanitized = privacyGuard.sanitize(text)
        let userMessage = AIMessage(role: "user", content: sanitized)
        messages.append(userMessage)
        trimMessages()

        isLoading = true
        errorMessage = nil

        do {
            let response = try await ServerAPI.shared.post(
                "ai/chat",
                body: [
                    "model": selectedModel.rawValue,
                    "messages": messages.map { ["role": $0.role, "content": $0.content] }
                ]
            )

            if let json = try JSONSerialization.jsonObject(with: response) as? [String: Any],
               let reply = json["reply"] as? String {
                let assistantMessage = AIMessage(role: "assistant", content: reply)
                messages.append(assistantMessage)
                trimMessages()
            } else {
                errorMessage = NSLocalizedString("Invalid response from server", comment: "AI chat invalid server response error")
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cannotConnectToHost || urlError.code == .cannotFindHost {
                errorMessage = NSLocalizedString("AI service is currently unavailable. Please check your connection or try again later.", comment: "AI service unavailable error")
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func clearHistory() {
        messages.removeAll()
        errorMessage = nil
    }

    private func trimMessages() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(keepMessages))
        }
    }
}
