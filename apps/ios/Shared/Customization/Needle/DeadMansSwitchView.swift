// Copyright (C) 2026 POPOPX Team <chat@popopx.xyz>
// This file is part of POPOPX iOS. Licensed under AGPL-3.0.

import SwiftUI

struct DeadMansSwitchView: View {
    @ObservedObject private var switchManager = DeadMansSwitch.shared
    @State private var showingAddAction = false
    @State private var showingAddContact = false
    @State private var newActionText = ""
    @State private var newContactId = ""

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("dms_status", comment: "DMS status section header"))) {
                Toggle(NSLocalizedString("dms_enable_switch", comment: "Toggle to enable Dead Man's Switch"), isOn: Binding(
                    get: { switchManager.config.enabled },
                    set: { newValue in
                        var config = switchManager.config
                        config.enabled = newValue
                        switchManager.updateConfig(config)
                    }
                ))

                if switchManager.config.enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: switchManager.isWarningPhase ? "exclamationmark.triangle.fill" : "clock")
                                .foregroundColor(switchManager.isWarningPhase ? .orange : .green)
                            Text(String(format: NSLocalizedString("dms_days_remaining", comment: "Days remaining counter"), switchManager.daysRemaining))
                                .fontWeight(.medium)
                        }

                        let dateStr = switchManager.config.lastActivityDate.formatted(date: .abbreviated, time: .shortened)
                        Text(String(format: NSLocalizedString("dms_last_activity", comment: "Last activity date"), dateStr))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text(NSLocalizedString("dms_settings", comment: "DMS settings section header"))) {
                Stepper(String(format: NSLocalizedString("dms_inactivity_threshold", comment: "Inactivity threshold setting"), switchManager.config.inactivityDays),
                        value: Binding(
                            get: { switchManager.config.inactivityDays },
                            set: { newValue in
                                var config = switchManager.config
                                config.inactivityDays = newValue
                                switchManager.updateConfig(config)
                            }
                        ),
                        in: 1...365)

                Stepper(String(format: NSLocalizedString("dms_warning_period", comment: "Warning period setting"), switchManager.config.warningDays),
                        value: Binding(
                            get: { switchManager.config.warningDays },
                            set: { newValue in
                                var config = switchManager.config
                                config.warningDays = min(newValue, config.inactivityDays - 1)
                                switchManager.updateConfig(config)
                            }
                        ),
                        in: 1...30)
            }

            Section(header: Text(String(format: NSLocalizedString("dms_actions_count", comment: "Actions section header with count"), switchManager.config.actions.count))) {
                ForEach(switchManager.config.actions) { action in
                    ActionRow(action: action) {
                        if let index = switchManager.config.actions.firstIndex(where: { $0.id == action.id }) {
                            switchManager.removeAction(at: index)
                        }
                    }
                }

                Button(action: { showingAddContact = false; showingAddAction = true }) {
                    Label(NSLocalizedString("dms_add_action", comment: "Add action button"), systemImage: "plus.circle")
                }
            }

            Section(header: Text(String(format: NSLocalizedString("dms_trusted_contacts_count", comment: "Trusted contacts section header with count"), switchManager.config.trustedContacts.count))) {
                ForEach(switchManager.config.trustedContacts, id: \.self) { contactId in
                    HStack {
                        Text(contactId)
                            .lineLimit(1)
                        Spacer()
                        Button(action: { switchManager.removeTrustedContact(contactId) }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }

                Button(action: { showingAddAction = false; showingAddContact = true }) {
                    Label(NSLocalizedString("dms_add_contact", comment: "Add contact button"), systemImage: "plus.circle")
                }
            }

            Section {
                Button(role: .destructive) {
                    var config = switchManager.config
                    config.enabled = false
                    config.actions = []
                    config.trustedContacts = []
                    switchManager.updateConfig(config)
                } label: {
                    Text(NSLocalizedString("dms_reset_configuration", comment: "Reset configuration button"))
                }
            }
        }
        .navigationTitle(NSLocalizedString("dms_navigation_title", comment: "Dead Man's Switch navigation title"))
        .sheet(isPresented: $showingAddAction) {
            AddActionSheet { action in
                switchManager.addAction(action)
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactSheet { contactId in
                switchManager.addTrustedContact(contactId)
            }
        }
    }
}

struct ActionRow: View {
    let action: DeadMansSwitch.SwitchAction
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(actionTitle)
                    .fontWeight(.medium)
                Text(actionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    private var actionTitle: String {
        switch action {
        case .sendMessage:
            return NSLocalizedString("dms_action_send_message", comment: "Action type: send message")
        case .deleteAllData:
            return NSLocalizedString("dms_action_delete_all_data", comment: "Action type: delete all data")
        case .exportData:
            return NSLocalizedString("dms_action_export_data", comment: "Action type: export data")
        case .runShortcut:
            return NSLocalizedString("dms_action_run_shortcut", comment: "Action type: run shortcut")
        }
    }

    private var actionDescription: String {
        switch action {
        case .sendMessage(let contactId, let text):
            return String(format: NSLocalizedString("dms_desc_send_message", comment: "Send message action description: contact and text"), contactId, text)
        case .deleteAllData:
            return NSLocalizedString("dms_desc_delete_all_data", comment: "Delete all data action description")
        case .exportData(let recipientId):
            return String(format: NSLocalizedString("dms_desc_export_data", comment: "Export data action description: recipient"), recipientId)
        case .runShortcut(let name):
            return String(format: NSLocalizedString("dms_desc_run_shortcut", comment: "Run shortcut action description: shortcut name"), name)
        }
    }
}

struct AddActionSheet: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (DeadMansSwitch.SwitchAction) -> Void

    @State private var selectedActionType = 0
    @State private var contactId = ""
    @State private var messageText = ""
    @State private var shortcutName = ""

    let actionTypes = [
        NSLocalizedString("dms_action_send_message", comment: "Action type: send message"),
        NSLocalizedString("dms_action_delete_all_data", comment: "Action type: delete all data"),
        NSLocalizedString("dms_action_export_data", comment: "Action type: export data"),
        NSLocalizedString("dms_action_run_shortcut", comment: "Action type: run shortcut")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("dms_action_type", comment: "Action type section header"))) {
                    Picker(NSLocalizedString("dms_type", comment: "Type picker label"), selection: $selectedActionType) {
                        ForEach(0..<actionTypes.count, id: \.self) { index in
                            Text(actionTypes[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if selectedActionType == 0 || selectedActionType == 2 {
                    Section(header: Text(NSLocalizedString("dms_contact", comment: "Contact section header"))) {
                        TextField(NSLocalizedString("dms_contact_id_placeholder", comment: "Contact ID text field placeholder"), text: $contactId)
                    }
                }

                if selectedActionType == 0 {
                    Section(header: Text(NSLocalizedString("dms_message", comment: "Message section header"))) {
                        TextField(NSLocalizedString("dms_message_text_placeholder", comment: "Message text field placeholder"), text: $messageText, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                if selectedActionType == 3 {
                    Section(header: Text(NSLocalizedString("dms_shortcut", comment: "Shortcut section header"))) {
                        TextField(NSLocalizedString("dms_shortcut_name_placeholder", comment: "Shortcut name field placeholder"), text: $shortcutName)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("dms_add_action_title", comment: "Add action navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("dms_cancel", comment: "Cancel button")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("dms_add", comment: "Add button")) {
                        let action = createAction()
                        if let action = action {
                            onAdd(action)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        switch selectedActionType {
        case 0: return !contactId.isEmpty && !messageText.isEmpty
        case 1: return true
        case 2: return !contactId.isEmpty
        case 3: return !shortcutName.isEmpty
        default: return false
        }
    }

    private func createAction() -> DeadMansSwitch.SwitchAction? {
        switch selectedActionType {
        case 0:
            return .sendMessage(contactId: contactId, text: messageText)
        case 1:
            return .deleteAllData
        case 2:
            return .exportData(recipientContactId: contactId)
        case 3:
            return .runShortcut(shortcutName: shortcutName)
        default:
            return nil
        }
    }
}

struct AddContactSheet: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (String) -> Void

    @State private var contactId = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("dms_contact_id", comment: "Contact ID section header"))) {
                    TextField(NSLocalizedString("dms_enter_contact_id", comment: "Enter contact ID placeholder"), text: $contactId)
                }
            }
            .navigationTitle(NSLocalizedString("dms_add_contact_title", comment: "Add contact navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("dms_cancel", comment: "Cancel button")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("dms_add", comment: "Add button")) {
                        if !contactId.isEmpty {
                            onAdd(contactId)
                            dismiss()
                        }
                    }
                    .disabled(contactId.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DeadMansSwitchView()
    }
}
