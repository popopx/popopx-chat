// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct MeshChatListView: View {
    @EnvironmentObject var chatModel: ChatModel
    @State private var showTransportSettings = false

    var body: some View {
        Group {
            if chatModel.meshConversations.isEmpty {
                emptyState
            } else {
                meshChatList
            }
        }
        .navigationTitle(NSLocalizedString("mesh_chat_list_title", comment: "Navigation title for mesh chat list"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTransportSettings = true
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(darkThemeAccentColor())
                }
                .accessibilityLabel(NSLocalizedString("Transport settings", comment: "Transport settings button"))
            }
        }
        .sheet(isPresented: $showTransportSettings) {
            NavigationStack {
                TransportSettingsView(chatModel: chatModel)
                    .navigationTitle(NSLocalizedString("Transport", comment: "Transport navigation title"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .popopxBranded()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("No mesh connections", comment: "Mesh chat empty state title"))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(NSLocalizedString("Enable mesh transport to discover nearby peers and chat without internet", comment: "Mesh chat empty state description"))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showTransportSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                    Text(NSLocalizedString("Configure Transport", comment: "Button to open transport settings"))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(darkThemeAccentColor())
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(darkThemeAccentColor().opacity(0.3), lineWidth: 0.5)
                )
            }
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var meshChatList: some View {
        List {
            ForEach(chatModel.meshConversations) { chat in
                NavigationLink {
                    MeshChatView(chat: chat)
                } label: {
                    MeshChatRow(chat: chat)
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct MeshChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(darkThemeAccentColor().opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(darkThemeAccentColor())
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.chatInfo.chatViewName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if case .meshPeer(let peer) = chat.chatInfo {
                        Circle()
                            .fill(peer.isConnected ? QuantumColors.success : .gray)
                            .frame(width: 6, height: 6)
                    }
                }

                if let lastItem = chat.chatItems.last {
                    Text(lastItem.meta.itemTs.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if chat.chatItems.count > 0 {
                Text("\(chat.chatItems.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("%@, %d messages", comment: "Mesh chat row accessibility label"), chat.chatInfo.chatViewName, chat.chatItems.count))
    }
}

struct MeshChatView: View {
    @EnvironmentObject var chatModel: ChatModel
    let chat: Chat
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    private var chatId: String { chat.chatInfo.id }

    private var isGroup: Bool {
        if case .meshGroup = chat.chatInfo { return true }
        return false
    }

    private var peerIDHex: String? {
        chatModel.meshBridge?.peerIDHex(from: chatId)
    }

    private var connectionStatus: String {
        if case .meshPeer(let peer) = chat.chatInfo {
            return peer.isConnected ? NSLocalizedString("Connected", comment: "Mesh peer connected status") : NSLocalizedString("Disconnected", comment: "Mesh peer disconnected status")
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputBar
        }
        .navigationTitle(chat.chatInfo.chatViewName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !connectionStatus.isEmpty {
                    Text(connectionStatus)
                        .font(.caption2)
                        .foregroundStyle(connectionStatus == NSLocalizedString("Connected", comment: "Mesh peer connected status") ? QuantumColors.success : .secondary)
                }
            }
        }
        .onAppear {
            if isGroup, let groupIDHex = peerIDHex {
                chatModel.meshBridge?.loadMeshGroupConversation(groupIDHex: groupIDHex)
            } else if let peerIDHex {
                chatModel.meshBridge?.loadMeshConversation(peerID: peerIDHex)
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let currentChat = chatModel.meshConversations.first(where: { $0.chatInfo.id == chatId }) {
                        ForEach(currentChat.chatItems) { item in
                            MeshMessageBubble(item: item)
                                .id(item.meta.itemId)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: chatModel.meshConversations.first(where: { $0.chatInfo.id == chatId })?.chatItems.count) {_, _ in
                if let lastID = chatModel.meshConversations.first(where: { $0.chatInfo.id == chatId })?.chatItems.last?.meta.itemId {
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(NSLocalizedString("Message", comment: "Message input placeholder"), text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($isInputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : darkThemeAccentColor())
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(NSLocalizedString("Send message", comment: "Send message button"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        if isGroup, let groupIDHex = peerIDHex {
            chatModel.meshBridge?.sendGroupText(text, groupIDHex: groupIDHex)
        } else if let peerIDHex {
            chatModel.meshBridge?.sendText(text, to: peerIDHex)
        }
    }
}

private struct MeshMessageBubble: View {
    let item: ChatItem

    private var isSent: Bool {
        item.chatDir.sent
    }

    private var senderName: String? {
        switch item.chatDir {
        case .meshRcv(let nickname): return nickname
        case .meshGroupRcv(let nickname): return nickname
        default: return nil
        }
    }

    private var messageText: String {
        switch item.content {
        case .sndMsgContent(let msgContent), .rcvMsgContent(let msgContent):
            return msgContent.text
        default:
            return ""
        }
    }

    var body: some View {
        HStack {
            if isSent { Spacer(minLength: 40) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                if let senderName, !isSent {
                    Text(senderName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(darkThemeAccentColor())
                }

                Text(messageText)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSent ? darkThemeAccentColor().opacity(0.2) : Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(item.meta.itemTs.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isSent { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        MeshChatListView()
            .environmentObject(ChatModel())
    }
}
