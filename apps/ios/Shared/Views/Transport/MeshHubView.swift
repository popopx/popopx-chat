// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import BitchatMesh

struct MeshHubView: View {
    @ObservedObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    var onBackToHome: (() -> Void)? = nil
    @State private var selectedTab: MeshHubTab = .chat

    enum MeshHubTab: String, CaseIterable, Identifiable {
        case popopx = "mesh_hub_tab_chats"
        case chat = "mesh_hub_tab_public"
        case groups = "mesh_hub_tab_groups"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .popopx: return "dot.radiowaves.left.and.right"
            case .chat: return "message.fill"
            case .groups: return "person.3.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button in top-left corner
            HStack {
                Button {
                    if chatModel.chatId != nil {
                        chatModel.chatId = nil
                    } else {
                        onBackToHome?()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.colors.primary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Picker(NSLocalizedString("mesh_hub_picker_label", comment: "Mesh Hub picker label"), selection: $selectedTab) {
                ForEach(MeshHubTab.allCases) { tab in
                    Label(NSLocalizedString(tab.rawValue, comment: "Mesh hub tab label"), systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Group {
                switch selectedTab {
                case .popopx:
                    MeshChatListView()
                        .environmentObject(chatModel)
                case .chat:
                    BitchatBridgeView()
                case .groups:
                    MeshGroupsView(chatModel: chatModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(NSLocalizedString("mesh_hub", comment: "navigation title for mesh hub view"))
        .navigationBarTitleDisplayMode(.inline)
        .popopxBranded()
    }
}
