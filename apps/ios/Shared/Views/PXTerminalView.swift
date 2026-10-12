//
//  TerminalView.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 27/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX: Terminal display configuration
private enum PXTerminalConfig {
    /// Font used for terminal log entries
    static let pxTerminalFont: Font = Font.custom("Menlo", size: 14)
    /// Maximum number of terminal items retained in memory
    static let pxMaxItemCapacity: Int = 48000
    /// Delay before auto-scrolling when keyboard appears
    static let pxKeyboardScrollDelay: Double = 0.3
    /// Duration of the scroll animation on keyboard show
    static let pxKeyboardScrollDuration: Double = 0.85
    /// Horizontal padding for the message input area
    static let pxInputHorizontalPad: CGFloat = 16
    /// Shadow opacity for the navigation title
    static let pxTitleShadowOpacity: Double = 0.35
    /// Shadow radius for the navigation title
    static let pxTitleShadowRadius: CGFloat = 6
    /// Max label width in the terminal item list row
    static let pxLabelMaxHeight: CGFloat = 34
}

#if DEBUG

struct PXTerminal: View {
    @EnvironmentObject var chatModel: ChatModel
    @AppStorage(DEFAULT_PERFORM_LA) private var prefPerformLA = false
    @AppStorage(DEFAULT_DEVELOPER_TOOLS) private var developerTools = false
    @State var composeState: ComposeState = ComposeState()
    @State var selectedRange = NSRange()
    @State private var keyboardVisible = false
    @State private var keyboardHiddenDate = Date.now
    @State var authorized = !UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA)
    @State private var terminalItem: TerminalItem?
    @State private var pxHasScrolled = false
    @State private var pxIsShowing = false

    var body: some View {
        Group {
        if authorized {
            pxTerminalListView()
                .onAppear {
                    if pxIsShowing { return }
                    pxIsShowing = true
                    Task {
                        let pxLoadedItems = await TerminalItems.shared.items()
                        await MainActor.run {
                            chatModel.terminalItems = pxLoadedItems
                            chatModel.showingTerminal = true
                        }
                    }
                }
                .onDisappear {
                    if terminalItem == nil {
                        chatModel.showingTerminal = false
                        chatModel.terminalItems = []
                    }
                }
        } else {
            Button(action: pxRunAuthentication) { Label(NSLocalizedString("unlock_button", comment: "Unlock button label"), systemImage: "lock") }
            .onAppear(perform: pxRunAuthentication)
        }
        }
        .popopxBranded()
    }

    /// Triggers local authentication with the appropriate reason string
    private func pxRunAuthentication() {
        authorize(NSLocalizedString("Open chat console", comment: "authentication reason"), $authorized)
    }

    // MARK: - POPOPX: main terminal scroll view with input
    private func pxTerminalListView() -> some View {
        VStack {
            ScrollViewReader { pxScrollProxy in
                ScrollView {
                    LazyVStack {
                        ForEach(chatModel.terminalItems) { pxItem in
                            Button {
                                terminalItem = pxItem
                            } label: {
                                HStack {
                                    Text(pxItem.id.formatted(date: .omitted, time: .standard))
                                    Text(pxItem.label)
                                        .frame(maxWidth: .infinity, maxHeight: PXTerminalConfig.pxLabelMaxHeight, alignment: .leading)
                                }
                                .font(PXTerminalConfig.pxTerminalFont)
                                .padding(.horizontal)
                            }
                        }
                        .onAppear {
                            if !pxHasScrolled {
                                pxScrollToBottom(pxScrollProxy)
                                pxHasScrolled = true
                            }
                        }
                        .onChange(of: chatModel.terminalItems.count) {_, _ in pxScrollToBottom(pxScrollProxy) }
                        .onChange(of: keyboardVisible) {_, _ in
                            if keyboardVisible {
                                DispatchQueue.main.asyncAfter(deadline: .now() + PXTerminalConfig.pxKeyboardScrollDelay) {
                                    pxScrollToBottom(pxScrollProxy, animation: .easeInOut(duration: PXTerminalConfig.pxKeyboardScrollDuration))
                                }
                            }
                        }
                        .background(pxTerminalNavDestination)
                    }
                }

                Spacer()

                SendMessageView(
                    composeState: $composeState,
                    selectedRange: $selectedRange,
                    sendMessage: { _ in pxConsoleSendMessage() },
                    showVoiceMessageButton: false,
                    onMediaAdded: { _ in },
                    keyboardVisible: $keyboardVisible,
                    keyboardHiddenDate: $keyboardHiddenDate
                )
                .padding(.horizontal, PXTerminalConfig.pxInputHorizontalPad)
            }
        }
        .toolbar {
            // Redaction broken for `.navigationTitle` - using a toolbar item instead.
            ToolbarItem(placement: .principal) {
                Text(LocalizedStringKey(NSLocalizedString("chat_console_title", comment: "Chat console title")))
                    .font(.headline.weight(.bold))
                    .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(PXTerminalConfig.pxTitleShadowOpacity) : .clear, radius: PXTerminalConfig.pxTitleShadowRadius, x: 0, y: 1)
            }
        }
        .modifier(ThemedBackground())
    }

    /// Scrolls to the last terminal item with optional animation
    func pxScrollToBottom(_ pxProxy: ScrollViewProxy, animation pxAnim: Animation = .default) {
        if let pxLastId = chatModel.terminalItems.last?.id {
            withAnimation(pxAnim) {
                pxProxy.scrollTo(pxLastId, anchor: .bottom)
            }
        }
    }

    // MARK: - POPOPX: detail view for a single terminal item
    func pxTerminalItemDetailView() -> some View {
        let pxDetailText = terminalItem?.details ?? ""
        return ScrollView {
            Text(pxDetailText.prefix(PXTerminalConfig.pxMaxItemCapacity))
                .padding()
                .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showShareSheet(items: [pxDetailText]) } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onDisappear { terminalItem = nil }
        .modifier(ThemedBackground())
    }

    @ViewBuilder
    private var pxTerminalNavDestination: some View {
        let pxIsPresented = Binding<Bool>(
            get: { terminalItem != nil },
            set: { _ in }
        )
        Color.clear
            .navigationDestination(isPresented: pxIsPresented) {
                pxTerminalItemDetailView()
            }
    }

    /// Dispatches the composed message to the terminal command handler
    func pxConsoleSendMessage() {
        if composeState.message.starts(with: "/sql") && (!prefPerformLA || !developerTools) {
            let pxEmptyResp: APIResult<ChatResponse2> = APIResult.error(ChatError.error(errorType: ChatErrorType.commandError(message: "Failed reading: empty")), seq: 0)
            Task {
                await TerminalItems.shared.addCommand(.now, .string(composeState.message), pxEmptyResp)
            }
        } else {
            let pxCmdText = composeState.message
            DispatchQueue.global().async {
                Task {
                    await MainActor.run { composeState.inProgress = true }
                    await pxExecuteTerminalCommand(pxCmdText)
                    await MainActor.run { composeState.inProgress = false }
                }
            }
        }
        composeState = ComposeState()
    }
}

/// Sends a command string to the POPOPX terminal and records the result
func pxExecuteTerminalCommand(_ pxCmd: String) async {
    let pxStartTime: Date = .now
    await withCheckedContinuation { (pxCont: CheckedContinuation<Void, Never>) in
        let pxRawData = sendPopopxCmdStr(pxCmd, retryNum: 0)
        Task {
            guard let pxRawData else {
                await TerminalItems.shared.addCommand(pxStartTime, ChatCommand.string(pxCmd), APIResult<ChatResponse2>.error(.invalidJSON(json: nil), seq: 0))
                return
            }
            let pxResult0: APIResult<ChatResponse0> = decodeAPIResult(pxRawData)
            guard case .invalid = pxResult0 else {
                await TerminalItems.shared.addCommand(pxStartTime, .string(pxCmd), pxResult0)
                return
            }
            let pxResult1: APIResult<ChatResponse1> = decodeAPIResult(pxRawData)
            guard case .invalid = pxResult1 else {
                await TerminalItems.shared.addCommand(pxStartTime, .string(pxCmd), pxResult1)
                return
            }
            let pxResult2: APIResult<ChatResponse2> = decodeAPIResult(pxRawData)
            await TerminalItems.shared.addCommand(pxStartTime, .string(pxCmd), pxResult2)
        }
        pxCont.resume(returning: ())
    }
}

struct PXTerminal_Previews: PreviewProvider {
    static var previews: some View {
        let chatModel = ChatModel()
        chatModel.terminalItems = [
            .err(.now, APIResult<ChatResponse2>.invalid(type: "contactSubscribed", json: "{}".data(using: .utf8) ?? Data()).unexpected),
            .err(.now, APIResult<ChatResponse2>.invalid(type: "newChatItems", json: "{}".data(using: .utf8) ?? Data()).unexpected)
        ]
        return NavigationStack {
            PXTerminal()
                .environmentObject(chatModel)
        }
    }
}

#endif
