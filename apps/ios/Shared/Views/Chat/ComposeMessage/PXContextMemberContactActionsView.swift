//
//  ContextMemberContactActionsView.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 31.07.2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

struct ContextMemberContactActionsView: View {
    @EnvironmentObject var theme: AppTheme
    var contact: Contact
    var groupDirectInv: GroupDirectInvitation
    @UserDefault(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    @State private var inProgress = false
    @State private var progressByTimeout = false

    var body: some View {
        Group {
            VStack {
                if groupDirectInv.memberRemoved {
                    Label(NSLocalizedString("compose_member_deleted_cant_accept", comment: "Label when member is deleted and can't accept request"), systemImage: "info.circle")
                        .foregroundColor(theme.colors.secondary)
                        .font(.subheadline)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    HStack(spacing: 0) {
                        Button(role: .destructive, action: { showRejectMemberContactRequestAlert(contact) }) {
                            Label(NSLocalizedString("compose_reject", comment: "Reject contact request button"), systemImage: "multiply")
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)

                        Button {
                            acceptMemberContactRequest(contact, inProgress: $inProgress)
                        } label: {
                            Label(NSLocalizedString("compose_accept", comment: "Accept contact request button"), systemImage: "checkmark")
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
            }
        }
        .disabled(inProgress || groupDirectInv.memberRemoved)
        .frame(maxWidth: .infinity)
        .background(ToolbarMaterial.material(toolbarMaterial))
        .opacity(progressByTimeout ? 0.4 : 1)
        .overlay {
            if progressByTimeout {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: inProgress) {_,  inPrgrs in
            if inPrgrs {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000000000)
                    progressByTimeout = inProgress
                }
            } else {
                progressByTimeout = false
            }
        }
        .popopxBranded()
    }
}

func showRejectMemberContactRequestAlert(_ contact: Contact) {
    showAlert(
        NSLocalizedString("Reject contact request", comment: "alert title"),
        message: NSLocalizedString("The sender will NOT be notified", comment: "alert message"),
        actions: {[
            UIAlertAction(title: NSLocalizedString("Reject", comment: "alert action"), style: .destructive) { _ in
                deleteContact(contact)
            },
            cancelAlertAction
        ]}
    )
}

private func deleteContact(_ contact: Contact) {
    Task {
        do {
            _ = try await apiDeleteContact(id: contact.contactId, chatDeleteMode: .full(notify: false))
            await MainActor.run {
                ChatModel.shared.removeChat(contact.id)
                ChatModel.shared.chatId = nil
            }
        } catch let error {
            logger.error("apiDeleteContact: \(responseError(error))")
            await MainActor.run {
                showAlert(
                    NSLocalizedString("Error deleting chat!", comment: "alert title"),
                    message: responseError(error)
                )
            }
        }
    }
}

func acceptMemberContactRequest(_ contact: Contact, inProgress: Binding<Bool>? = nil) {
    Task {
        await acceptMemberContact(contactId: contact.contactId, inProgress: inProgress)
    }
}

#Preview {
    ContextMemberContactActionsView(
        contact: Contact.sampleData,
        groupDirectInv: GroupDirectInvitation.sampleData
    )
}

// MARK: - POPOPX
extension ContextMemberContactActionsView {
    var pxComponentTag: String { "px-ctx-member-contact" }
}
