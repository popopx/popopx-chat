//
//  MemberAdmissionView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 28.04.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXMemberAdmissionConfig {
    static let pickerHeight: CGFloat = 36
    static let sectionInset: CGFloat = 8
    static let footerOpacity: CGFloat = 0.8
    static let sectionSpacing: CGFloat = 12
    static let saveButtonTag: String = "px-admission-save"
    static let resetButtonTag: String = "px-admission-reset"
    static let darkThemeFooterColor: Color = Color.white.opacity(0.7)
}

// MARK: - POPOPX ViewModel
@MainActor
private struct PXMemberAdmissionVM {
    let admission: GroupMemberAdmission
    let currentAdmission: GroupMemberAdmission
    let isOwner: Bool
    let creatingGroup: Bool

    var hasUnsavedChanges: Bool {
        currentAdmission != admission
    }

    var saveButtonText: LocalizedStringKey {
        creatingGroup ? LocalizedStringKey(NSLocalizedString("group_save", comment: "Save")) : LocalizedStringKey(NSLocalizedString("group_save_notify_members", comment: "Save and notify group members"))
    }

    var isSaveDisabled: Bool {
        currentAdmission == admission
    }

    var canDismissCleanly: Bool {
        currentAdmission == admission
    }
}

private let memberCriterias: [(criteria: MemberCriteria?, text: LocalizedStringKey)] = [
    (nil, "off"),
    (.all, "all")
]

struct MemberAdmissionView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @Binding var groupInfo: GroupInfo
    @Binding var admission: GroupMemberAdmission
    var currentAdmission: GroupMemberAdmission
    let creatingGroup: Bool
    let saveAdmission: () -> Void
    @State private var showSaveDialogue = false

    private var pxVM: PXMemberAdmissionVM {
        PXMemberAdmissionVM(
            admission: admission,
            currentAdmission: currentAdmission,
            isOwner: groupInfo.isOwner,
            creatingGroup: creatingGroup
        )
    }

    var body: some View {
        let saveText = pxVM.saveButtonText
        VStack {
            List {
                admissionSection(
                    NSLocalizedString("Review members", comment: "admission stage"),
                    NSLocalizedString("Review members before admitting (\"knocking\").", comment: "admission stage description"),
                    $admission.review
                )

                if groupInfo.isOwner {
                    Section {
                        Button(NSLocalizedString("Reset", comment: "")) { admission = currentAdmission }
                            .accessibilityLabel(Text(NSLocalizedString("Reset admission settings", comment: "reset button")))
                        Button(saveText) { saveAdmission() }
                            .accessibilityLabel(Text(saveText))
                    }
                    .disabled(pxVM.isSaveDisabled)
                }
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .modifier(ThemedBackground(grouped: true))
        }
        .modifier(BackButton(disabled: Binding.constant(false)) {
            if pxVM.canDismissCleanly {
                dismiss()
            } else {
                showSaveDialogue = true
            }
        })
        .confirmationDialog(NSLocalizedString("Save admission settings?", comment: "confirmation dialog title"), isPresented: $showSaveDialogue) {
            Button(saveText) {
                saveAdmission()
                dismiss()
            }
            Button(NSLocalizedString("Exit without saving", comment: "")) {
                admission = currentAdmission
                dismiss()
            }
        }
        .popopxBranded()
    }

    private func admissionSection(_ admissionStageStr: String, _ admissionStageDescrStr: String, _ memberCriteria: Binding<MemberCriteria?>) -> some View {
        let darkTheme = isInDarkTheme()
        return Section {
            if groupInfo.isOwner {
                Picker(admissionStageStr, selection: memberCriteria) {
                    ForEach(memberCriterias, id: \.criteria) { mc in
                        Text(mc.text)
                    }
                }
                .frame(height: PXMemberAdmissionConfig.pickerHeight)
            } else {
                infoRow(Text(admissionStageStr), memberCriteria.wrappedValue?.text ?? NSLocalizedString("off", comment: "member criteria value"))
            }
        } footer: {
            Text(admissionStageDescrStr)
                .foregroundColor(darkTheme ? PXMemberAdmissionConfig.darkThemeFooterColor : theme.colors.secondary)
                .padding(.horizontal, PXMemberAdmissionConfig.sectionInset)
                .opacity(darkTheme ? PXMemberAdmissionConfig.footerOpacity : 1.0)
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - POPOPX
extension MemberAdmissionView {
    var pxComponentTag: String { "px-member-admission" }
    var pxAdmissionStageLabel: String { "admission-stage" }
    var pxHasUnsavedChanges: Bool { pxVM.hasUnsavedChanges }
}

#Preview {
    MemberAdmissionView(
        groupInfo: Binding.constant(GroupInfo.sampleData),
        admission: Binding.constant(GroupMemberAdmission.sampleData),
        currentAdmission: GroupMemberAdmission.sampleData,
        creatingGroup: false,
        saveAdmission: {}
    )
}
