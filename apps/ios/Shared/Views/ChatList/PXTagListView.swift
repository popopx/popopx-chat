//
//  PXTagFilterList.swift
//  POPOPX (iOS)
//
//  Created by Diogo Cunha on 31/12/2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import ElegantEmojiPicker

// MARK: - POPOPX Configuration

private enum PXTagListConfig {
    static let componentTag: String = "PX_TAG_LIST_VIEW"
    static let editorComponentTag: String = "PX_TAG_LIST_EDITOR"
    /// Leading padding for tag text after icon
    static let tagTextLeadingPadding: CGFloat = 12
    /// Minimum tap target size for tag rows
    static let tagRowMinHeight: CGFloat = 44
    /// Opacity for header edit button in dark theme
    static let darkThemeHeaderOpacity: Double = 0.9
    /// Opacity for header edit button in light theme
    static let lightThemeHeaderOpacity: Double = 1.0
    /// Haptic feedback style for tag interactions
    static let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
}

// MARK: - Haptic Feedback Helper

private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

struct TagEditorNavParams {
    let chat: Chat?
    let chatListTag: ChatTagData?
    let tagId: Int64?
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXTagListViewModel {
    let chat: Chat?
    let chatTagsIds: [Int64]
    let primaryColor: Color
    let isDark: Bool

    func isSelected(tagId: Int64) -> Bool {
        chatTagsIds.contains(tagId)
    }

    var headerOpacity: Double {
        isDark ? PXTagListConfig.darkThemeHeaderOpacity : PXTagListConfig.lightThemeHeaderOpacity
    }

    var isChatMode: Bool {
        chat != nil
    }
}

// Spec: spec/client/chat-list.md#PXTagFilterList
struct PXTagFilterList: View {
    var chat: Chat? = nil
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var chatTagsModel: ChatTagsModel
    @EnvironmentObject var m: ChatModel
    @State private var editMode = EditMode.inactive
    @State private var tagEditorNavParams: TagEditorNavParams? = nil

    var chatTagsIds: [Int64] { chat?.chatInfo.contact?.chatTags ?? chat?.chatInfo.groupInfo?.chatTags ?? [] }

    var body: some View {
        let vm = PXTagListViewModel(
            chat: chat,
            chatTagsIds: chatTagsIds,
            primaryColor: theme.colors.primary,
            isDark: isInDarkTheme()
        )
        List {
            Section {
                tagRowsSection(vm)
                createListLink
            } header: {
                listHeader(vm)
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .environment(\.editMode, $editMode)
        .popopxBranded()
    }

    // MARK: - Sub-views

    private func tagRowsSection(_ vm: PXTagListViewModel) -> some View {
        ForEach(chatTagsModel.userTags, id: \.id) { tag in
            let text = tag.chatTagText
            let emoji = tag.chatTagEmoji
            let tagId = tag.chatTagId
            let selected = vm.isSelected(tagId: tagId)

            HStack {
                tagLeadingIcon(emoji: emoji)
                Text(text)
                    .padding(.leading, PXTagListConfig.tagTextLeadingPadding)
                Spacer()
                if vm.isChatMode {
                    radioButtonView(selected: selected)
                }
            }
            .frame(minHeight: PXTagListConfig.tagRowMinHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                triggerHapticFeedback(PXTagListConfig.hapticStyle)
                if let c = chat {
                    setChatTag(tagId: selected ? nil : tagId, chat: c) { dismiss() }
                } else {
                    tagEditorNavParams = TagEditorNavParams(chat: nil, chatListTag: ChatTagData(emoji: emoji, text: text), tagId: tagId)
                }
            }
            .accessibilityLabel(Text(text))
            .accessibilityValue(selected ? NSLocalizedString("Selected", comment: "tag selected") : "")
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteSwipeAction(text: text, tagId: tagId)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                editSwipeAction(emoji: emoji, text: text, tagId: tagId)
            }
            .background(tagEditorNavDestination)
        }
        .onMove(perform: moveItem)
    }

    private func tagLeadingIcon(emoji: String?) -> some View {
        Group {
            if let emoji {
                Text(emoji)
            } else {
                Image(systemName: "tag")
            }
        }
        .accessibilityHidden(true)
    }

    private func deleteSwipeAction(text: String, tagId: Int64) -> some View {
        Button {
            showAlert(
                NSLocalizedString("delete_list_title", comment: "Alert title for deleting list"),
                message: String.localizedStringWithFormat(NSLocalizedString("delete_list_message", comment: "Alert message for deleting list"), text),
                actions: {[
                    cancelAlertAction,
                    UIAlertAction(
                        title: NSLocalizedString("delete_action", comment: "Button to delete list"),
                        style: .destructive,
                        handler: { _ in
                            deleteTag(tagId)
                        }
                    )
                ]}
            )
        } label: {
            Label(NSLocalizedString("delete_action", comment: "Button to delete list"), systemImage: "trash.fill")
        }
        .tint(QuantumColors.error)
    }

    private func editSwipeAction(emoji: String?, text: String, tagId: Int64) -> some View {
        Button {
            tagEditorNavParams = TagEditorNavParams(chat: nil, chatListTag: ChatTagData(emoji: emoji, text: text), tagId: tagId)
        } label: {
            Label(NSLocalizedString("edit_action", comment: "Button to edit list"), systemImage: "pencil")
        }
        .tint(theme.colors.primary)
    }

    private func listHeader(_ vm: PXTagListViewModel) -> some View {
        Group {
            if !vm.isChatMode {
                editTagsButton(vm)
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .font(.caption.weight(.bold))
                    .foregroundColor(isInDarkTheme() ? darkThemeAccentColor().opacity(vm.headerOpacity) : theme.colors.secondary)
                    .accessibilityLabel(Text(editMode.isEditing
                        ? NSLocalizedString("Done", comment: "")
                        : NSLocalizedString("Edit", comment: "")))
            }
        }
    }

    private func editTagsButton(_ vm: PXTagListViewModel) -> some View {
        if editMode.isEditing {
            Button(NSLocalizedString("Done", comment: "")) {
                editMode = .inactive
                dismiss()
            }
        } else {
            Button(NSLocalizedString("Edit", comment: "")) {
                editMode = .active
            }
        }
    }

    private var createListLink: some View {
        NavigationLink {
            TagListEditor(chat: chat)
        } label: {
            Label(NSLocalizedString("create_list", comment: "Button to create new chat list"), systemImage: "plus")
                .font(.system(.body))
        }
        .accessibilityLabel(Text(NSLocalizedString("create_list", comment: "Button to create new chat list")))
    }

    private func radioButtonView(selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .imageScale(.large)
            .foregroundStyle(selected ? Color.accentColor : Color(.tertiaryLabel))
            .accessibilityLabel(selected
                ? Text(NSLocalizedString("Deselect tag", comment: "tag deselect accessibility"))
                : Text(NSLocalizedString("Select tag", comment: "tag select accessibility")))
    }

    @ViewBuilder
    private var tagEditorNavDestination: some View {
        let isPresented = Binding<Bool>(
            get: { tagEditorNavParams != nil },
            set: { if !$0 { tagEditorNavParams = nil } }
        )
        Color.clear
            .navigationDestination(isPresented: isPresented) {
                if let params = tagEditorNavParams {
                    TagListEditor(
                        chat: params.chat,
                        tagId: params.tagId,
                        emoji: params.chatListTag?.emoji,
                        name: params.chatListTag?.text ?? ""
                    )
                }
            }
    }

    // MARK: - Actions

    private func moveItem(from source: IndexSet, to destination: Int) {
        Task {
            do {
                var tags = chatTagsModel.userTags
                tags.move(fromOffsets: source, toOffset: destination)
                try await apiReorderChatTags(tagIds: tags.map { $0.chatTagId })

                await MainActor.run {
                    chatTagsModel.userTags = tags
                }
            } catch let error {
                showAlert(
                    NSLocalizedString("error_reordering_lists", comment: "Alert title for error reordering lists"),
                    message: responseError(error)
                )
            }
        }
    }

    private func deleteTag(_ tagId: Int64) {
        Task {
            try? await apiDeleteChatTag(tagId: tagId)

            await MainActor.run {
                chatTagsModel.userTags = chatTagsModel.userTags.filter { $0.chatTagId != tagId }
                if case let .userTag(tag) = chatTagsModel.activeFilter, tagId == tag.chatTagId {
                    chatTagsModel.activeFilter = nil
                }
                m.chats.forEach { c in
                    if var contact = c.chatInfo.contact, contact.chatTags.contains(tagId) {
                        contact.chatTags = contact.chatTags.filter({ $0 != tagId })
                        m.updateContact(contact)
                    } else if var group = c.chatInfo.groupInfo, group.chatTags.contains(tagId) {
                        group.chatTags = group.chatTags.filter({ $0 != tagId })
                        m.updateGroup(group)
                    }
                }
            }
        }
    }
}

private func setChatTag(tagId: Int64?, chat: Chat, closeSheet: @escaping () -> Void) {
    Task {
        do {
            let tagIds: [Int64] = if let t = tagId { [t] } else {[]}
            let (userTags, chatTags) = try await apiSetChatTags(
                type: chat.chatInfo.chatType,
                id: chat.chatInfo.apiId,
                tagIds: tagIds
            )

            await MainActor.run {
                let m = ChatModel.shared
                let tm = ChatTagsModel.shared
                tm.userTags = userTags
                if chat.unreadTag, let tags = chat.chatInfo.chatTags {
                    tm.decTagsReadCount(tags)
                }
                if var contact = chat.chatInfo.contact {
                    contact.chatTags = chatTags
                    m.updateContact(contact)
                } else if var group = chat.chatInfo.groupInfo {
                    group.chatTags = chatTags
                    m.updateGroup(group)
                }
                ChatTagsModel.shared.updateChatTagRead(chat, wasUnread: false)
                closeSheet()
            }
        } catch let error {
            showAlert(
                NSLocalizedString("error_saving_chat_list", comment: "Alert title for error saving chat list"),
                message: responseError(error)
            )
        }
    }
}

// MARK: - Emoji Picker

struct EmojiPickerView: UIViewControllerRepresentable {
    @Binding var selectedEmoji: String?
    @Binding var showingPicker: Bool
    @Environment(\.presentationMode) var presentationMode

    class Coordinator: NSObject, ElegantEmojiPickerDelegate, UIAdaptivePresentationControllerDelegate {
        var parent: EmojiPickerView

        init(parent: EmojiPickerView) {
            self.parent = parent
        }

        func emojiPicker(_ picker: ElegantEmojiPicker, didSelectEmoji emoji: Emoji?) {
            parent.selectedEmoji = emoji?.emoji
            parent.showingPicker = false
            picker.dismiss(animated: true)
        }

        // Called when the picker is dismissed manually (without selection)
        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            parent.showingPicker = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let config = ElegantConfiguration(showRandom: false, showReset: true, showClose: false)
        let picker = ElegantEmojiPicker(delegate: context.coordinator, configuration: config)

        picker.presentationController?.delegate = context.coordinator

        let viewController = UIViewController()
        DispatchQueue.main.async {
            if let topVC = getTopViewController() {
                topVC.present(picker, animated: true)
            }
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No need to update the controller after creation
    }
}

// MARK: - Tag List Editor

// MARK: - POPOPX Configuration

private enum PXTagEditorConfig {
    static let componentTag: String = "PX_TAG_LIST_EDITOR"
    /// Opacity for duplicate warning icon in dark theme
    static let darkThemeWarningOpacity: Double = 0.9
    /// Opacity for duplicate warning icon in light theme
    static let lightThemeWarningOpacity: Double = 1.0
}

// MARK: - POPOPX ViewModel

@MainActor
private struct PXTagEditorViewModel {
    let isDuplicate: Bool
    let saving: Bool?
    let trimmedName: String
    let originalName: String
    let originalEmoji: String?
    let newEmoji: String?
    let isChatMode: Bool

    var saveDisabled: Bool {
        saving != nil || isUnchanged || trimmedName.isEmpty || (isDuplicate && saving != false)
    }

    var isUnchanged: Bool {
        trimmedName == originalName && newEmoji == originalEmoji
    }

    var saveButtonText: String {
        isChatMode
            ? NSLocalizedString("add_to_list", comment: "Button to add chat to list")
            : NSLocalizedString("save_list", comment: "Button to save new list")
    }
}

struct TagListEditor: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var chatTagsModel: ChatTagsModel
    @EnvironmentObject var theme: AppTheme
    var chat: Chat? = nil
    var tagId: Int64? = nil
    var emoji: String?
    var name: String = ""
    @State private var newEmoji: String?
    @State private var newName: String = ""
    @State private var isPickerPresented = false
    @State private var saving: Bool?

    var body: some View {
        let vm = PXTagEditorViewModel(
            isDuplicate: isDuplicateEmojiOrName,
            saving: saving,
            trimmedName: trimmedName,
            originalName: name,
            originalEmoji: emoji,
            newEmoji: newEmoji,
            isChatMode: chat != nil
        )
        VStack {
            List {
                editorFormSection(vm)
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)

            if isPickerPresented {
                EmojiPickerView(selectedEmoji: $newEmoji, showingPicker: $isPickerPresented)
            }
        }
        .modifier(ThemedBackground(grouped: true))
        .onAppear {
            newEmoji = emoji
            newName = name
        }
    }

    // MARK: - Sub-views

    private func editorFormSection(_ vm: PXTagEditorViewModel) -> some View {
        Section {
            emojiAndNameRow
            saveButton(vm)
        } footer: {
            duplicateWarningFooter(vm)
        }
    }

    private var emojiAndNameRow: some View {
        HStack {
            Button {
                triggerHapticFeedback(PXTagListConfig.hapticStyle)
                isPickerPresented = true
            } label: {
                if let newEmoji {
                    Text(newEmoji)
                } else {
                    Image(systemName: "face.smiling")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel(Text(NSLocalizedString("Choose emoji", comment: "emoji picker accessibility")))
            TextField(NSLocalizedString("List name...", comment: ""), text: $newName)
                .accessibilityLabel(Text(NSLocalizedString("List name...", comment: "")))
        }
    }

    private func saveButton(_ vm: PXTagEditorViewModel) -> some View {
        Button {
            triggerHapticFeedback(PXTagListConfig.hapticStyle)
            saving = true
            if let tId = tagId {
                updateChatTag(tagId: tId, chatTagData: ChatTagData(emoji: newEmoji, text: trimmedName))
            } else {
                createChatTag()
            }
        } label: {
            Text(vm.saveButtonText)
        }
        .disabled(vm.saveDisabled)
        .accessibilityLabel(Text(vm.saveButtonText))
    }

    private func duplicateWarningFooter(_ vm: PXTagEditorViewModel) -> some View {
        Group {
            if vm.isDuplicate && saving != false {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(theme.colors.error)
                        .opacity(isInDarkTheme() ? PXTagEditorConfig.darkThemeWarningOpacity : PXTagEditorConfig.lightThemeWarningOpacity)
                    Text(NSLocalizedString("unique_list_name_emoji", comment: "Error message when list name or emoji duplicates another"))
                        .foregroundColor(theme.colors.secondary)
                }
                .accessibilityLabel(Text(NSLocalizedString("unique_list_name_emoji", comment: "Error message when list name or emoji duplicates another")))
            }
        }
    }

    // MARK: - Computed

    var trimmedName: String {
        newName.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicateEmojiOrName: Bool {
        chatTagsModel.userTags.contains { tag in
            tag.chatTagId != tagId &&
            ((newEmoji != nil && tag.chatTagEmoji == newEmoji) || tag.chatTagText == trimmedName)
        }
    }

    // MARK: - Actions

    private func createChatTag() {
        Task {
            do {
                let text = trimmedName
                let userTags = try await apiCreateChatTag(
                    tag: ChatTagData(emoji: newEmoji , text: text)
                )
                await MainActor.run {
                    saving = false
                    chatTagsModel.userTags = userTags
                }
                if let chat, let tag = userTags.first(where: { $0.chatTagText == text && $0.chatTagEmoji == newEmoji}) {
                    setChatTag(tagId: tag.chatTagId, chat: chat) { dismiss() }
                } else {
                    await MainActor.run { dismiss() }
                }
            } catch let error {
                await MainActor.run {
                    saving = nil
                    showAlert(
                        NSLocalizedString("error_creating_list", comment: "Alert title for error creating list"),
                        message: responseError(error)
                    )
                }
            }
        }
    }

    private func updateChatTag(tagId: Int64, chatTagData: ChatTagData) {
        Task {
            do {
                try await apiUpdateChatTag(tagId: tagId, tag: chatTagData)
                await MainActor.run {
                    saving = false
                    for i in 0..<chatTagsModel.userTags.count {
                        if chatTagsModel.userTags[i].chatTagId == tagId {
                            chatTagsModel.userTags[i] = ChatTag(
                                chatTagId: tagId,
                                chatTagText: chatTagData.text,
                                chatTagEmoji: chatTagData.emoji
                            )
                        }
                    }
                    dismiss()
                }
            } catch let error {
                await MainActor.run {
                    saving = nil
                    showAlert(
                        NSLocalizedString("error_creating_list", comment: "Alert title for error creating list"),
                        message: responseError(error)
                    )
                }
            }
        }
    }
}

// MARK: - POPOPX
extension PXTagFilterList {
    static let pxComponentTag: String = PXTagListConfig.componentTag
}

extension TagListEditor {
    static let pxComponentTag: String = PXTagEditorConfig.componentTag
}
