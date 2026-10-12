// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI
import BitchatMesh

struct MeshGroupsView: View {
    @ObservedObject var chatModel: ChatModel
    @State private var showCreate = false
    @State private var newGroupName = ""

    var body: some View {
        Group {
            let groups = chatModel.meshBridge?.meshGroups ?? []
            if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(LocalizedStringKey(NSLocalizedString("mesh_no_groups", comment: "No mesh groups empty state")))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(NSLocalizedString("mesh_create_group_hint", comment: "Mesh create group hint")))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showCreate = true
                    } label: {
                        Text(LocalizedStringKey(NSLocalizedString("mesh_create_group_button", comment: "Create group button")))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groups) { group in
                        GroupRow(group: group, chatModel: chatModel)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(NSLocalizedString("Mesh Groups", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(darkThemeAccentColor())
                }
                .accessibilityLabel(NSLocalizedString("Create group", comment: ""))
            }
        }
        .alert(NSLocalizedString("Create Group", comment: "alert title"), isPresented: $showCreate) {
            TextField(NSLocalizedString("Group name", comment: ""), text: $newGroupName)
            Button(NSLocalizedString("Create", comment: "")) {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                chatModel.meshBridge?.createMeshGroup(named: name)
                newGroupName = ""
            }
            .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(NSLocalizedString("cancel_button", comment: "Cancel button"), role: .cancel) {
                newGroupName = ""
            }
        } message: {
            Text(LocalizedStringKey(NSLocalizedString("mesh_enter_group_name", comment: "Enter group name prompt")))
        }
        .popopxBranded()
    }
}

private struct GroupRow: View {
    let group: PublicGroupInfo
    let chatModel: ChatModel

    var body: some View {
        Button {
            let chatId = "meshgroup:\(group.groupIDHex)"
            chatModel.chatId = chatId
            chatModel.meshBridge?.loadMeshGroupConversation(groupIDHex: group.groupIDHex)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .font(.body)
                    .foregroundStyle(darkThemeAccentColor())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d member", comment: "mesh group member count"), group.memberCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(LocalizedStringKey("·"))
                            .foregroundStyle(.secondary)

                        Text(LocalizedStringKey("epoch \(group.epoch)"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !group.memberNicknames.isEmpty {
                    Text(group.memberNicknames.prefix(3).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .frame(minHeight: 44)
        }
        .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("Group %@, %d members", comment: "Mesh group row accessibility label"), group.name, group.memberCount))
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .buttonStyle(.plain)
    }
}
