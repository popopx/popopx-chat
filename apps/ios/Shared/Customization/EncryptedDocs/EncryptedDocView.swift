// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

// Spec: customization/12-FEATURE-ENCRYPTED-DOCS.md
import SwiftUI

struct EncryptedDocView: View {
    @EnvironmentObject var docManager: EncryptedDocManager
    @State var document: EncryptedDocument
    @State private var showShareSheet: Bool = false
    @State private var showExpiryPicker: Bool = false
    @State private var showRevokeConfirmation: Bool = false
    @State private var shareUserId: String = ""
    @State private var selectedExpiryDate: Date = Date().addingTimeInterval(86400 * 7)
    @State private var editText: String = ""
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var showEphemeralFiles: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if docManager.isExpired(document) {
                expiredOverlay
            } else {
                editorContent
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { debounceTask?.cancel() }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showShareSheet = false; showExpiryPicker = false; showEphemeralFiles = false; showEphemeralFiles = true }) {
                        Label(NSLocalizedString("Ephemeral Files", comment: "toolbar menu item for ephemeral files"), systemImage: "timer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(QuantumColors.accent)
                }

                Button(action: { showExpiryPicker = false; showEphemeralFiles = false; showShareSheet = true }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(QuantumColors.accent)
                }
                .accessibilityLabel(NSLocalizedString("Share with collaborator", comment: "encrypted doc share button accessibility"))

                Button(action: { showShareSheet = false; showEphemeralFiles = false; showExpiryPicker = true }) {
                    Image(systemName: "clock.badge")
                        .foregroundColor(QuantumColors.warning)
                }
                .accessibilityLabel(NSLocalizedString("Set expiry", comment: "encrypted doc set expiry button accessibility"))

                Button(action: { showRevokeConfirmation = true }) {
                    Image(systemName: "person.badge.minus")
                        .foregroundColor(QuantumColors.error)
                }
                .accessibilityLabel(NSLocalizedString("Revoke access", comment: "encrypted doc revoke access button accessibility"))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
        .sheet(isPresented: $showExpiryPicker) {
            expiryPickerSheet
        }
        .alert(NSLocalizedString("Revoke All Access?", comment: "alert title for revoking document access"), isPresented: $showRevokeConfirmation) {
            Button(NSLocalizedString("Revoke", comment: "destructive button to revoke access"), role: .destructive) {
                docManager.revokeAccess(document.id)
                refreshDocument()
            }
            Button(NSLocalizedString("Cancel", comment: "cancel action"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("All collaborators will lose access to this document.", comment: "revoke access confirmation message"))
        }
        .sheet(isPresented: $showEphemeralFiles) {
            EphemeralFileView(
                fileName: "Ephemeral Preview",
                expiresAt: Date().addingTimeInterval(3600)
            )
        }
        .popopxBranded()
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            collaboratorBar

            GlassDivider()
                .opacity(0.5)

            TextEditor(text: $editText)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textPrimary)
                .padding(16)
                .onChange(of: editText) {_,  newValue in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                        guard !Task.isCancelled else { return }
                        docManager.updateContent(document.id, content: newValue)
                    }
                }
                .onAppear {
                    do {
                        editText = try docManager.readContent(document)
                    } catch {
                        editText = ""
                    }
                }
        }
    }

    private var collaboratorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ownerAvatar
                ForEach(document.collaborators, id: \.self) { userId in
                    collaboratorAvatar(userId: userId)
                }
                if document.collaborators.isEmpty {
                    Text(NSLocalizedString("No collaborators", comment: "empty state for collaborator bar"))
                        .font(QuantumFonts.caption)
                        .foregroundColor(QuantumColors.textSecondary)
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .glassBackground()
    }

    private var ownerAvatar: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [QuantumColors.primaryStart, QuantumColors.primaryEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(QuantumColors.textPrimary)
            }
            Text(NSLocalizedString("Owner", comment: "label for document owner avatar"))
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(QuantumColors.accent)
        }
    }

    private func collaboratorAvatar(userId: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(QuantumColors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(userId.prefix(1)).uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(QuantumColors.textPrimary)
            }
            Text(String(userId.prefix(6)))
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(QuantumColors.textSecondary)
                .lineLimit(1)
        }
    }

    private var expiredOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(QuantumColors.error)

            Text(NSLocalizedString("Document Expired", comment: "title for expired document overlay"))
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)

            Text(NSLocalizedString("This document has passed its expiry date and can no longer be edited.", comment: "expired document description"))
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shareSheet: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("Share Document", comment: "title for share document sheet"))
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)

            TextField(NSLocalizedString("User ID to share with", comment: "placeholder for share user ID field"), text: $shareUserId)
                .font(QuantumFonts.body)
                .foregroundColor(QuantumColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .glassButtonStyle()
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button(action: { showShareSheet = false }) {
                    Text(NSLocalizedString("Cancel", comment: "cancel action"))
                        .fontWeight(.medium)
                        .foregroundColor(QuantumColors.textSecondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .glassButtonStyle()
                }

                Button(action: {
                    docManager.shareDocument(document.id, with: shareUserId)
                    refreshDocument()
                    showShareSheet = false
                    shareUserId = ""
                }) {
                    Text(NSLocalizedString("Share", comment: "button to share document"))
                        .fontWeight(.semibold)
                        .foregroundColor(QuantumColors.textPrimary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .glassProminentButton()
                }
                .disabled(shareUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expiryPickerSheet: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("Set Expiry", comment: "title for expiry picker sheet"))
                .font(QuantumFonts.sectionHeader)
                .foregroundColor(QuantumColors.textPrimary)

            DatePicker(
                NSLocalizedString("Expires at", comment: "date picker label for expiry date"),
                selection: $selectedExpiryDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .tint(QuantumColors.accent)
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button(action: { showExpiryPicker = false }) {
                    Text(NSLocalizedString("Cancel", comment: "cancel action"))
                        .fontWeight(.medium)
                        .foregroundColor(QuantumColors.textSecondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .glassButtonStyle()
                }

                Button(action: {
                    docManager.setExpiry(document.id, expiresAt: selectedExpiryDate)
                    refreshDocument()
                    showExpiryPicker = false
                }) {
                    Text(NSLocalizedString("Set Expiry", comment: "button to set document expiry"))
                        .fontWeight(.semibold)
                        .foregroundColor(QuantumColors.textPrimary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .glassProminentButton()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refreshDocument() {
        if let updated = docManager.documents.first(where: { $0.id == document.id }) {
            document = updated
        }
    }
}
