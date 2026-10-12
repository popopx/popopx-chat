//
//  GroupWelcomeView.swift
//  POPOPX (iOS)
//
//  Created by Avently on 21/03/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXGroupWelcomeConfig {
    static let maxByteCount: Int = 1200
    static let previewMinHeight: CGFloat = 130
    static let clipboardExpiration: TimeInterval = 60
    static let editorHeight: CGFloat = 130
    static let editorHorizontalPadding: CGFloat = -5
    static let editorTopPadding: CGFloat = -8
    static let keyboardAppearDelayNanos: UInt64 = 1_000000000
    static let placeholderFontSize: CGFloat = 17
    static let footerErrorOpacity: Double = 0.9
    static let darkThemePreviewBoost: Double = 0.05
    static let editToggleIconPreview: String = "character"
    static let editToggleIconEdit: String = "pencil"
    static let copyIconName: String = "doc.on.doc"
}

// MARK: - POPOPX View Model
@MainActor
private struct PXGroupWelcomeViewModel {
    let groupInfo: GroupInfo
    let welcomeText: String

    var isUnchanged: Bool {
        welcomeText == groupInfo.groupProfile.description || (welcomeText == "" && groupInfo.groupProfile.description == nil)
    }

    var fitsLimit: Bool {
        chatJsonLength(welcomeText) <= PXGroupWelcomeConfig.maxByteCount
    }

    var canSave: Bool {
        !isUnchanged && fitsLimit
    }

    var shouldShowFooterError: Bool {
        !fitsLimit
    }

    var trimmedWelcomeForSave: String? {
        let trimmed = welcomeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 0 ? nil : trimmed
    }

    var isOwnerAndNotBusiness: Bool {
        groupInfo.isOwner && groupInfo.businessChat == nil
    }
}

struct GroupWelcomeView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @Binding var groupInfo: GroupInfo
    @State var groupProfile: GroupProfile
    @State var welcomeText: String
    @State private var editMode = true
    @FocusState private var keyboardVisible: Bool
    @State private var showSaveDialog = false
    @State private var showSecrets: Set<Int> = []

    var body: some View {
        VStack {
            if pxViewModel.isOwnerAndNotBusiness {
                pxEditorSection
            } else {
                pxReadOnlySection
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: PXGroupWelcomeConfig.keyboardAppearDelayNanos)
                keyboardVisible = true
            }
        }
        .popopxBranded()
    }

    // MARK: - POPOPX Extracted View Builders

    private var pxViewModel: PXGroupWelcomeViewModel {
        PXGroupWelcomeViewModel(groupInfo: groupInfo, welcomeText: welcomeText)
    }

    @ViewBuilder
    private var pxEditorSection: some View {
        editorView()
            .modifier(BackButton(disabled: Binding.constant(false)) {
                if pxViewModel.isUnchanged {
                    dismiss()
                } else {
                    showSaveDialog = true
                }
            })
            .confirmationDialog(
                pxViewModel.fitsLimit
                    ? NSLocalizedString("group_save_welcome", comment: "save welcome message confirmation")
                    : NSLocalizedString("group_welcome_too_long", comment: "welcome message too long warning"),
                isPresented: $showSaveDialog
            ) {
                if pxViewModel.fitsLimit {
                    Button(NSLocalizedString("group_save_and_update_profile", comment: "save and update group profile button")) { save() }
                }
                Button(NSLocalizedString("group_exit_without_saving", comment: "exit without saving button")) { dismiss() }
            }
    }

    @ViewBuilder
    private var pxReadOnlySection: some View {
        List {
            Section {
                textPreview()
                copyButton()
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
    }

    // MARK: - POPOPX Sub-views

    private func textPreview() -> some View {
        let r = markdownText(welcomeText, showSecrets: showSecrets, backgroundColor: theme.colors.background)
        return msgTextResultView(r, Text(AttributedString(r.string)), showSecrets: $showSecrets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: PXGroupWelcomeConfig.previewMinHeight, alignment: .topLeading)
    }

    private func editorView() -> some View {
        List {
            Section {
                pxEditorContent
                pxEditToggleButton
                copyButton()
            } footer: {
                pxEditorFooter
            }

            Section {
                saveButton()
            }
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
    }

    @ViewBuilder
    private var pxEditorContent: some View {
        if editMode {
            ZStack {
                Group {
                    if welcomeText.isEmpty {
                        TextEditor(text: Binding.constant(NSLocalizedString("Enter welcome message…", comment: "placeholder")))
                            .foregroundColor(theme.colors.secondary)
                            .disabled(true)
                    }
                    TextEditor(text: $welcomeText)
                        .focused($keyboardVisible)
                }
                .padding(.horizontal, PXGroupWelcomeConfig.editorHorizontalPadding)
                .padding(.top, PXGroupWelcomeConfig.editorTopPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: PXGroupWelcomeConfig.editorHeight, alignment: .topLeading)
            }
        } else {
            textPreview()
        }
    }

    private var pxEditToggleButton: some View {
        Button {
            editMode = !editMode
            keyboardVisible = editMode
        } label: {
            if editMode {
                Label(NSLocalizedString("group_welcome_preview", comment: "Preview mode"), systemImage: PXGroupWelcomeConfig.editToggleIconPreview)
            } else {
                Label(NSLocalizedString("group_welcome_edit", comment: "Edit mode"), systemImage: PXGroupWelcomeConfig.editToggleIconEdit)
            }
        }
        .disabled(welcomeText.isEmpty)
        .accessibilityLabel(editMode
            ? NSLocalizedString("Preview welcome message", comment: "")
            : NSLocalizedString("Edit welcome message", comment: ""))
    }

    private var pxEditorFooter: some View {
        Text(pxViewModel.shouldShowFooterError ? NSLocalizedString("group_welcome_message_too_large", comment: "Message too large error") : "")
            .foregroundColor(theme.colors.error)
            .opacity(isInDarkTheme() ? PXGroupWelcomeConfig.footerErrorOpacity : 1.0)
    }

    private func copyButton() -> some View {
        Button {
            UIPasteboard.general.setItems([["public.utf8-plain-text": welcomeText]], options: [.expirationDate: Date().addingTimeInterval(PXGroupWelcomeConfig.clipboardExpiration), .localOnly: true])
        } label: {
            Label(NSLocalizedString("group_welcome_copy", comment: "Copy button"), systemImage: PXGroupWelcomeConfig.copyIconName)
        }
        .accessibilityLabel(NSLocalizedString("Copy welcome message to clipboard", comment: ""))
    }

    private func saveButton() -> some View {
        Button(NSLocalizedString("group_save_and_update_profile", comment: "save and update group profile button")) {
            save()
        }
        .disabled(!pxViewModel.canSave)
        .accessibilityLabel(NSLocalizedString("Save and update group profile", comment: ""))
    }

    // MARK: - POPOPX Actions

    private func save() {
        logger.debug("POPOPX: GroupWelcomeView save")
        Task {
            do {
                groupProfile.description = pxViewModel.trimmedWelcomeForSave
                let gInfo = try await apiUpdateGroup(groupInfo.groupId, groupProfile)
                await MainActor.run {
                    groupInfo = gInfo
                    ChatModel.shared.updateGroup(gInfo)
                    dismiss()
                }
            } catch let error {
                logger.error("apiUpdateGroup error: \(responseError(error))")
            }
        }
    }
}

// MARK: - POPOPX
extension GroupWelcomeView {
    var pxComponentTag: String { "px-group-welcome" }
    var pxPreviewMinHeight: CGFloat { PXGroupWelcomeConfig.previewMinHeight }
    var pxClipboardExpiration: TimeInterval { PXGroupWelcomeConfig.clipboardExpiration }
    var pxMaxByteCount: Int { PXGroupWelcomeConfig.maxByteCount }
}

struct GroupWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        GroupProfileView(
            groupInfo: Binding.constant(GroupInfo.sampleData),
            groupProfile: GroupProfile.sampleData
        )
    }
}
