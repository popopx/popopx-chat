// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct MeshBoardView: View {
    @ObservedObject var chatModel: ChatModel
    @ObservedObject private var locationService = MeshLocationService.shared
    @State private var posts: [MeshBoardPost] = []
    @State private var showCompose = false
    @State private var filterScope: BoardScope = .mesh

    enum BoardScope: String, CaseIterable {
        case mesh = "mesh_scope_mesh"
        case all = "mesh_scope_all"
    }

    var body: some View {
        Group {
            if posts.isEmpty {
                emptyState
            } else {
                postsList
            }
        }
        .navigationTitle(NSLocalizedString("mesh_board_title", comment: "Navigation title for mesh board"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCompose) {
            BoardComposeSheet(geohash: locationService.currentGeohash) { content, isUrgent in
                if let bridge = chatModel.meshBridge {
                    bridge.postToBoard(content: content, geohash: locationService.currentGeohash, isUrgent: isUrgent)
                    refreshPosts()
                }
            }
        }
        .onAppear {
            locationService.startUpdating()
            refreshPosts()
        }
        .onDisappear {
            locationService.stopUpdating()
        }
        .onChange(of: filterScope) {_, _ in refreshPosts() }
        .onChange(of: chatModel.meshBridge?.meshBoardPosts.count ?? 0) {_, _ in refreshPosts() }
        .onChange(of: locationService.currentGeohash) {_, _ in refreshPosts() }
        .popopxBranded()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showCompose = true
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(darkThemeAccentColor())
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(NSLocalizedString("New post", comment: "Board new post button accessibility label"))
        }
        ToolbarItem(placement: .principal) {
            Picker(NSLocalizedString("mesh_board_scope_picker", comment: "Board scope picker label"), selection: $filterScope) {
                ForEach(BoardScope.allCases, id: \.self) { scope in
                    Text(NSLocalizedString(scope.rawValue, comment: "Board scope picker label")).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pin.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("mesh_no_posts", comment: "Empty state when no board posts exist"))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(NSLocalizedString("mesh_no_posts_description", comment: "Description for empty board state"))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var postsList: some View {
        List {
            ForEach(posts) { post in
                BoardPostRow(post: post)
            }
        }
        .listStyle(.plain)
    }

    private func refreshPosts() {
        let geohash = filterScope == .mesh ? locationService.currentGeohash : ""
        let allPosts = chatModel.meshBridge?.loadBoardPosts(geohash: geohash) ?? []
        posts = allPosts.map { post in
            MeshBoardPost(
                id: post.postIDHex,
                content: post.content,
                authorNickname: post.authorNickname,
                createdAt: post.createdAt,
                isUrgent: post.isUrgent,
                geohash: post.geohash
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}

struct MeshBoardPost: Identifiable {
    let id: String
    let content: String
    let authorNickname: String
    let createdAt: Date
    let isUrgent: Bool
    let geohash: String
}

private struct BoardPostRow: View {
    let post: MeshBoardPost

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("@\(post.authorNickname)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(neonGradientSecondary())

                if post.isUrgent {
                    Text(NSLocalizedString("mesh_urgent_label", comment: "Label indicating an urgent board post"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(QuantumColors.error)
                        .cornerRadius(3)
                        .accessibilityLabel(NSLocalizedString("Urgent post", comment: "Board urgent post accessibility label"))
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(post.content)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.isUrgent
            ? String.localizedStringWithFormat(NSLocalizedString("Urgent, post by %@: %@", comment: "Board urgent post accessibility label"), post.authorNickname, post.content)
            : String.localizedStringWithFormat(NSLocalizedString("Post by %@: %@", comment: "Board post accessibility label"), post.authorNickname, post.content))
    }
}

private struct BoardComposeSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @State private var isUrgent = false
    let geohash: String
    let onPost: (String, Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text(NSLocalizedString("mesh_compose_placeholder", comment: "Placeholder text for board compose message"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(darkThemeAccentColor().opacity(0.3), lineWidth: 0.5)
                        )
                }

                let trimmedCount = content.trimmingCharacters(in: .whitespacesAndNewlines).count

                HStack {
                    Text("\(trimmedCount)/512")
                        .font(.caption2)
                        .foregroundStyle(trimmedCount > 512 ? QuantumColors.error : .secondary)
                        .accessibilityLabel(String.localizedStringWithFormat(NSLocalizedString("%d of 512 characters used", comment: "Board compose character count accessibility label"), trimmedCount))
                    Spacer()
                    Toggle(isOn: $isUrgent) {
                        Text(NSLocalizedString("mesh_urgent_toggle", comment: "Toggle label for marking board post as urgent"))
                            .font(.footnote.weight(.semibold))
                    }
                    .tint(QuantumColors.error)
                }

                Button {
                    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, trimmed.count <= 512 else { return }
                    onPost(trimmed, isUrgent)
                    dismiss()
                } label: {
                    Text(NSLocalizedString("mesh_post_to_board", comment: "Button to post message to board"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(darkThemeAccentColor())
                        .cornerRadius(8)
                }
                .disabled(trimmedCount == 0 || trimmedCount > 512)
            }
            .padding()
            .navigationTitle(NSLocalizedString("mesh_new_post", comment: "Navigation title for new board post compose sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("mesh_cancel", comment: "Cancel button to dismiss compose sheet")) { dismiss() }
                        .font(.footnote)
                }
            }
        }
    }
}
