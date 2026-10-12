//
//  PXCommandsMenuView.swift
//  POPOPX (iOS)
//
//  Slash-command menu overlay with keyboard filtering and sub-menu navigation.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - Layout Constants

private enum PXCommandLayout {
    /// Height of each command row in the menu
    static let rowHeight: CGFloat = 48
    /// Maximum number of visible rows before scrolling
    static let maxVisibleRows: CGFloat = 5.8
    /// Corner radius for the menu container
    static let menuCornerRadius: CGFloat = 12
    /// Horizontal padding around the menu
    static let menuHorizontalPadding: CGFloat = 8
    /// Bottom padding of the menu
    static let menuBottomPadding: CGFloat = 8
    /// Border stroke width
    static let borderLineWidth: CGFloat = 0.75
    /// Shadow radius for dark theme
    static let shadowRadius: CGFloat = 8
    /// Shadow y-offset for dark theme
    static let shadowYOffset: CGFloat = 4
}

struct CommandsMenuView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    @Binding var composeState: ComposeState
    @Binding var selectedRange: NSRange
    @Binding var showCommandsMenu: Bool

    @State private var currentCommands: [ChatBotCommand] = []
    @State private var menuTreeBackPath: [(label: String, commands: [ChatBotCommand])] = []
    @State private var keywordWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if !currentCommands.isEmpty {
                Color.white.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showCommandsMenu = false
                        currentCommands = []
                        menuTreeBackPath = []
                    }
                VStack(spacing: 0) {
                    Spacer()
                    let cmdsCount = currentCommands.count + (menuTreeBackPath.isEmpty ? 0 : 1)
                    let scroll = ScrollView {
                        VStack(spacing: 0) {
                            if let prev = menuTreeBackPath.last {
                                GlassDivider()
                                menuLabelRow(prev)
                            }
                            ForEach(currentCommands, id: \.self, content: commandRow)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: PXCommandLayout.rowHeight * min(PXCommandLayout.maxVisibleRows, CGFloat(cmdsCount)))
                    .background(
                        RoundedRectangle(cornerRadius: PXCommandLayout.menuCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: PXCommandLayout.menuCornerRadius, style: .continuous)
                            .fill(theme.colors.background.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PXCommandLayout.menuCornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: isInDarkTheme()
                                    ? [darkThemeAccentColor().opacity(0.3), neonGradientSecondary().opacity(0.15)]
                                    : [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: PXCommandLayout.borderLineWidth
                            )
                    )
                    .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.1) : .clear, radius: PXCommandLayout.shadowRadius, x: 0, y: PXCommandLayout.shadowYOffset)
                    .padding(.horizontal, PXCommandLayout.menuHorizontalPadding)
                    .padding(.bottom, PXCommandLayout.menuBottomPadding)

                    scroll.scrollDismissesKeyboard(.never)
                }
                .onPreferenceChange(DetermineWidth.Key.self) { keywordWidth = $0 }
            }
        }
        .onChange(of: composeState.message) {_,  message in
            let msg = message.trimmingCharacters(in: .whitespaces)
            if msg == "/" {
                currentCommands = chat.chatInfo.menuCommands
            } else if msg.first == "/" {
                currentCommands = filterShownCommands(chat.chatInfo.menuCommands, msg.dropFirst())
            } else {
                showCommandsMenu = false
                currentCommands = []
            }
            menuTreeBackPath = []
        }
        .onChange(of: showCommandsMenu) {_,  show in
            currentCommands = show ? chat.chatInfo.menuCommands : []
            menuTreeBackPath = []
        }
        .popopxBranded()
    }

    private func menuLabelRow(_ prev: (label: String, commands: [ChatBotCommand])) -> some View {
        HStack {
            Image(systemName: "chevron.left")
                .foregroundColor(isInDarkTheme() ? darkThemeAccentColor() : theme.colors.secondary)
            Text(prev.label)
                .font(.system(.footnote).weight(.medium))
                .foregroundColor(isInDarkTheme() ? theme.colors.onBackground : .primary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: PXCommandLayout.rowHeight, alignment: .center)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(format: NSLocalizedString("back_to_label", comment: "Back button accessibility label"), prev.label))
        .onTapGesture {
            if !menuTreeBackPath.isEmpty {
                currentCommands = menuTreeBackPath.removeLast().commands
            }
        }
    }

    @ViewBuilder
    private func commandRow(_ command: ChatBotCommand) -> some View {
        GlassDivider()
        switch command {
        case let .command(keyword, label, params):
            HStack {
                Text(label)
                    .lineLimit(1)
                    .foregroundColor(isInDarkTheme() ? theme.colors.onBackground : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(LocalizedStringKey("/\(keyword)"))
                    .font(.system(.footnote))
                    .lineLimit(1)
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(0.8) : theme.colors.secondary)
                    .frame(minWidth: keywordWidth, alignment: .trailing)
                    .overlay(DetermineWidth())
            }
            .padding(.horizontal)
            .frame(height: PXCommandLayout.rowHeight, alignment: .center)
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .onTapGesture {
                if let params {
                    composeState.message = "/\(keyword) \(params)"
                    selectedRange = NSRange(location: composeState.message.count, length: 0)
                } else {
                    composeState.message = ""
                    sendCommandMsg(chat, "/\(keyword)")
                }
                showCommandsMenu = false
                currentCommands = []
                menuTreeBackPath = []
            }
        case let .menu(label, cmds):
            HStack {
                Text(label)
                    .fontWeight(.medium)
                    .foregroundColor(isInDarkTheme() ? theme.colors.onBackground : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(isInDarkTheme() ? neonGradientSecondary().opacity(0.7) : theme.colors.secondary)
            }
            .padding(.horizontal)
            .frame(height: PXCommandLayout.rowHeight, alignment: .center)
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .onTapGesture {
                menuTreeBackPath.append((label: label, commands: currentCommands))
                currentCommands = cmds
            }
        }
    }

    private func filterShownCommands(_ commands: [ChatBotCommand], _ msg: String.SubSequence) -> [ChatBotCommand] {
        var cmds: [ChatBotCommand] = []
        for command in commands {
            switch command {
            case let .command(keyword, _, _):
                if keyword.starts(with: msg) {
                    cmds.append(command)
                }
            case let .menu(_, innerCmds):
                cmds.append(contentsOf: filterShownCommands(innerCmds, msg))
            }
        }
        return cmds
    }
}

@MainActor
func sendCommandMsg(_ chat: Chat, _ cmd: String) {
    if chat.chatInfo.sndReady {
        Task {
            if let chatItems = await apiSendMessages(
                type: chat.chatInfo.chatType,
                id: chat.chatInfo.apiId,
                scope: chat.chatInfo.groupChatScope(),
                composedMessages: [ComposedMessage(msgContent: .text(cmd))]
            ) {
                await MainActor.run {
                    for ci in chatItems {
                        ChatModel.shared.addChatItem(chat.chatInfo, ci)
                    }
                }
            }
        }
    } else {
        showAlert(
            NSLocalizedString("You can't send messages!", comment: "alert title"),
            message: NSLocalizedString("To send commands you must be connected.", comment: "alert message"),
            actions: { [okAlertAction] }
        )
    }
}

// MARK: - POPOPX
extension CommandsMenuView {
    var pxCommandCount: Int { 0 }
}
