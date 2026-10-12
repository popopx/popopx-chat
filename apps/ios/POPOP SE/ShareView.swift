//
//  ShareView.swift
//  POPOPX SE
//
//  Created by Levitating Pineapple on 09/07/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ShareView: View {
    @ObservedObject var model: ShareModel
    @Environment(\.colorScheme) var colorScheme
    @State private var password = String()
    @AppStorage(GROUP_DEFAULT_PROFILE_IMAGE_CORNER_RADIUS, store: groupDefaults) private var radius = defaultProfileImageCorner

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                if model.isLoaded {
                    List {
                        if !model.meshPeers.isEmpty {
                            Section(NSLocalizedString("Mesh Peers", comment: "share extension section header")) {
                                ForEach(model.meshPeers) { peer in
                                    let isSelected = model.selectedMeshPeer == peer
                                    HStack {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(peer.isConnected ? .green : .secondary)
                                        VStack(alignment: .leading) {
                                            Text(peer.nickname)
                                            Text(peer.isConnected
                                                ? NSLocalizedString("se_mesh_connected", comment: "mesh peer connected in share extension")
                                                : NSLocalizedString("se_mesh_disconnected", comment: "mesh peer disconnected in share extension"))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .imageScale(.large)
                                            .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                                    }
                                    .contentShape(Rectangle().inset(by: -10))
                                    .onTapGesture {
                                        if isSelected {
                                            model.selectedMeshPeer = nil
                                        } else {
                                            model.selectedMeshPeer = peer
                                            model.selected = nil
                                        }
                                    }
                                }
                            }
                        }
                        Section(NSLocalizedString("Chats", comment: "share extension section header")) {
                            ForEach(model.filteredChats) { chat in
                                let isProhibited = model.isProhibited(chat)
                                let isSelected = model.selected == chat
                                HStack {
                                    profileImage(
                                        chatInfoId: chat.chatInfo.id,
                                        iconName: chatIconName(chat.chatInfo),
                                        size: 30
                                    )
                                    Text(chat.chatInfo.displayName).foregroundStyle(
                                        isProhibited ? .secondary : .primary
                                    )
                                    Spacer()
                                    radioButton(selected: isSelected && !isProhibited)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isProhibited {
                                        model.errorAlert = prohibitedForwardAlert()
                                    } else {
                                        model.selected = isSelected ? nil : chat
                                        model.selectedMeshPeer = nil
                                    }
                                }
                                .tag(chat)
                            }
                        }
                    }
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .navigationTitle(Text(NSLocalizedString("Share", comment: "share extension navigation_title")))
            .safeAreaInset(edge: .bottom) {
                switch model.bottomBar {
                case .sendButton:
                    compose(isLoading: false)
                case .loadingSpinner:
                    compose(isLoading: true)
                case .loadingBar(let progress):
                    loadingBar(progress: progress)
                }
            }
        }
        .searchable(
            text: $model.search,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .alert($model.errorAlert) { alert in
            if model.alertRequiresPassword {
                SecureField(NSLocalizedString("se_passphrase_placeholder", comment: "share extension passphrase field placeholder"), text: $password)
                Button(LocalizedStringKey(NSLocalizedString("Ok", comment: "alert button"))) {
                    model.setup(with: password)
                    password = String()
                }
                Button(LocalizedStringKey(NSLocalizedString("Cancel", comment: "alert button")), role: .cancel) { model.completion() }
            } else {
                Button(LocalizedStringKey(NSLocalizedString("Ok", comment: "alert button"))) { model.completion() }
            }
        }
        .onChange(of: model.comment) { _, newValue in
            model.hasPopopxLink = hasPopopxLink(newValue)
        }
    }

    private func compose(isLoading: Bool) -> some View {
        VStack(spacing: 0) {
            Divider()
            if let content = model.sharedContent  {
               itemPreview(content)
            }
            HStack {
                Group {
                    if #available(iOSApplicationExtension 16.0, *) {
                        TextField(NSLocalizedString("se_comment_placeholder", comment: "share extension comment field placeholder"), text: $model.comment, axis: .vertical).lineLimit(6)
                    } else {
                        TextField(NSLocalizedString("se_comment_placeholder", comment: "share extension comment field placeholder"), text: $model.comment)
                    }
                }
                .contentShape(Rectangle())
                .disabled(isLoading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(action: model.send) {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .accessibilityLabel(Text(NSLocalizedString("Send", comment: "accessibility label for send button")))
                        }
                        .contentShape(Rectangle().inset(by: -8))
                        .disabled(model.isSendDisabled)
                    }
                }
                .frame(width: 28, height: 28)
                .padding(6)

            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.secondary, lineWidth: 0.5).opacity(0.7)
            )
            .padding(8)
        }
        .background(.thinMaterial)
    }

    @ViewBuilder private func itemPreview(_ content: SharedContent) -> some View {
        switch content {
        case let .image(preview, _): imagePreview(preview)
        case let .movie(preview, _, _): imagePreview(preview)
        case let .url(preview): linkPreview(preview)
        case let .data(cryptoFile):
            previewArea {
                Image(systemName: "doc.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                    .padding(.leading, 4)
                Text(cryptoFile.filePath)
            }
        case .text: EmptyView()
        }
    }

    @ViewBuilder private func imagePreview(_ imgStr: String) -> some View {
        if let img = imageFromBase64(imgStr) {
            previewArea {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: 40, maxHeight: 60)
            }
        } else {
            EmptyView()
        }
    }

    private func linkPreview(_ linkPreview: LinkPreview) -> some View {
        previewArea {
            HStack(alignment: .center, spacing: 8) {
                if let uiImage = imageFromBase64(linkPreview.image) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 80, maxHeight: 60)
                }
                VStack(alignment: .center, spacing: 4) {
                    Text(linkPreview.title)
                        .lineLimit(1)
                    Text(linkPreview.uri)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
    }

    @ViewBuilder private func previewArea<V: View>(@ViewBuilder content: @escaping () -> V) -> some View {
        HStack(alignment: .center, spacing: 8) {
            content()
            Spacer()
        }
        .padding(.vertical, 1)
        .frame(minHeight: 54)
        .background {
            switch colorScheme {
            case .light: LightColorPaletteApp.sentMessage
            case .dark: DarkColorPaletteApp.sentMessage
            @unknown default: Color(.tertiarySystemBackground)
            }
        }
        Divider()
    }

    private func loadingBar(progress: Double) -> some View {
        VStack {
            Text(NSLocalizedString("Sending message…", comment: ""))
            ProgressView(value: progress)
        }
        .padding()
        .background(Material.ultraThin)
    }

    @ViewBuilder private func profileImage(chatInfoId: ChatInfo.ID, iconName: String, size: Double) -> some View {
        if let uiImage = model.profileImages[chatInfoId] {
            clipProfileImage(Image(uiImage: uiImage), size: size, radius: radius)
        } else {
            Image(systemName: iconName)
                .resizable()
                .foregroundColor(Color(uiColor: .tertiaryLabel))
                .frame(width: size, height: size)
// add background when adding themes to SE
//                .background(Circle().fill(backgroundColor != nil ? backgroundColor! : .clear))
        }
    }

    private func prohibitedForwardAlert() -> ErrorAlert {
        ErrorAlert(
            title: LocalizedStringKey(NSLocalizedString("se_cannot_forward_title", comment: "share extension cannot forward message alert title")),
            message: LocalizedStringKey(NSLocalizedString("se_cannot_forward_message", comment: "share extension cannot forward message alert body"))
        )
    }

    private func radioButton(selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .imageScale(.large)
            .foregroundStyle(selected ? Color.accentColor : Color(.tertiaryLabel))
    }
}
