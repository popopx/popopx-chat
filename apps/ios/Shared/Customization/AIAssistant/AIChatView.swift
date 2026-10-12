// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/ai-assistant
import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var theme: AppTheme
    @ObservedObject private var chatManager = AIChatManager.shared
    @State private var inputText: String = ""
    @State private var showModelSelector: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatManager.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: QuantumColors.accent))
                                Text(NSLocalizedString("ai_thinking", comment: "Status text while AI is processing"))
                                    .font(QuantumFonts.caption)
                                    .foregroundColor(QuantumColors.textSecondary)
                            }
                            .padding(.vertical, 8)
                        }

                        if let error = chatManager.errorMessage {
                            Text(error)
                                .font(QuantumFonts.caption)
                                .foregroundColor(QuantumColors.error)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatManager.messages.count) {_, _ in
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            GlassDivider()
                .glassBackground(cornerRadius: 12)

            // Input bar
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text(NSLocalizedString("ai_message_placeholder", comment: "Placeholder text in AI chat input field"))
                            .foregroundColor(QuantumColors.textSecondary)
                            .padding(.horizontal, 14)
                    }
                    TextField("", text: $inputText)
                        .font(QuantumFonts.body)
                        .foregroundColor(QuantumColors.textPrimary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassBackground(cornerRadius: 20)
                }

                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    inputText = ""
                    Task {
                        await chatManager.sendMessage(text)
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(QuantumColors.background)
                        .frame(width: 36, height: 36)
                        .glassProminentButton()
                        .clipShape(Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isLoading)
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isLoading ? 0.6 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .navigationTitle(NSLocalizedString("ai_assistant_title", comment: "Navigation title for AI assistant chat"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showModelSelector = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "cpu")
                            .font(.system(size: 14))
                        Text(chatManager.selectedModel.rawValue)
                            .font(QuantumFonts.encryptionLabel)
                    }
                    .foregroundColor(QuantumColors.accent)
                }
                .accessibilityLabel(Text(NSLocalizedString("ai_select_model", comment: "Accessibility label for AI model selector button")))
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    chatManager.clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(QuantumColors.textSecondary)
                }
                .accessibilityLabel(Text(NSLocalizedString("ai_clear_history", comment: "Accessibility label for clear chat history button")))
            }
        }
        .sheet(isPresented: $showModelSelector) {
            AIModelSelector(selectedModel: $chatManager.selectedModel)
        }
        .popopxBranded()
    }
}

private struct MessageBubble: View {
    let message: AIMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            messageContent
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if isUser {
            Text(message.content)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [QuantumColors.primaryStart, QuantumColors.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            Text(message.content)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassBackground()
        }
    }
}
