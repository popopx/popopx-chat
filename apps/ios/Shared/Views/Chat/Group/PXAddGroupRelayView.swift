//
//  AddGroupRelayView.swift
//  POPOPX (iOS)
//
//  Created by POPOPX Team on 29.04.2026.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Layout Configuration
private enum PXAddGroupRelayConfig {
    static let operatorNamePadding: CGFloat = 8
    static let relayRowIconSize: CGFloat = 24
    static let rowVerticalSpacing: CGFloat = 3
    static let rowLineLimit: Int = 1
    static let selectedIconName: String = "checkmark.circle.fill"
    static let unselectedIconName: String = "circle"
    static let iconTransitionScale: CGFloat = 1.15
    static let rowHorizontalPadding: CGFloat = 4
    static let operatorNameFont: Font = .caption
    static let emptyStateOpacity: Double = 0.7
    static let darkThemeOpacityBoost: Double = 0.15
}

// MARK: - POPOPX View Model
@MainActor
private struct PXAddGroupRelayViewModel {
    let groupInfo: GroupInfo
    let existingRelayIds: Set<Int64>

    var groupIdDisplay: String {
        "\(groupInfo.groupId)"
    }

    func shouldIncludeRelay(_ relay: UserChatRelay, operatorEnabled: Bool?) -> Bool {
        guard operatorEnabled != false else { return false }
        return relay.enabled && !relay.deleted && relay.chatRelayId != nil
    }

    func filterNewRelays(from servers: [UserOperatorServers]) -> [(relayId: Int64, relay: UserChatRelay, operatorName: String?)] {
        var relays: [(relayId: Int64, relay: UserChatRelay, operatorName: String?)] = []
        for op in servers {
            if let oper = op.operator, oper.enabled != true { continue }
            let opName: String? = op.operator?.operatorTag != nil ? op.operator?.tradeName : nil
            for relay in op.chatRelays {
                if relay.enabled && !relay.deleted,
                   let relayId = relay.chatRelayId,
                   !existingRelayIds.contains(relayId) {
                    relays.append((relayId, relay, opName))
                }
            }
        }
        return relays
    }
}

struct AddGroupRelayView: View {
    var groupInfo: GroupInfo
    var existingRelayIds: Set<Int64>
    var onRelayAdded: () -> Void
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) var dismiss
    @State private var availableRelays: [(relayId: Int64, relay: UserChatRelay, operatorName: String?)] = []
    @State private var selectedRelayIds: Set<Int64> = []
    @State private var isLoading = true
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            pxNavigationContent
        }
        .task { await loadAvailableRelays() }
        .popopxBranded()
    }

    // MARK: - POPOPX Extracted View Builders

    @ViewBuilder
    private var pxNavigationContent: some View {
        List {
            pxListContent
        }
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .modifier(ThemedBackground(grouped: true))
        .navigationTitle(NSLocalizedString("Add relays", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            pxToolbarContent
        }
    }

    @ViewBuilder
    private var pxListContent: some View {
        if isLoading {
            pxLoadingSection
        } else if availableRelays.isEmpty {
            pxEmptyStateSection
        } else {
            pxRelayListSection
        }
    }

    private var pxLoadingSection: some View {
        Section {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    private var pxEmptyStateSection: some View {
        Section {
            Text(NSLocalizedString("group_no_available_relays", comment: "Empty state when no relays available"))
                .foregroundColor(theme.colors.secondary)
                .opacity(isInDarkTheme()
                         ? PXAddGroupRelayConfig.emptyStateOpacity + PXAddGroupRelayConfig.darkThemeOpacityBoost
                         : PXAddGroupRelayConfig.emptyStateOpacity)
        }
    }

    private var pxRelayListSection: some View {
        Section {
            ForEach(availableRelays, id: \.relayId) { item in
                pxRelayCheckRow(item.relayId, item.relay, operatorName: item.operatorName)
            }
        }
    }

    @ToolbarContentBuilder
    private var pxToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                .accessibilityLabel(NSLocalizedString("Cancel", comment: ""))
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(NSLocalizedString("Add", comment: "")) { addSelectedRelays() }
                .disabled(selectedRelayIds.isEmpty || isAdding)
                .accessibilityLabel(NSLocalizedString("Add selected relays", comment: ""))
        }
    }

    // MARK: - POPOPX Relay Row

    private func pxRelayCheckRow(_ relayId: Int64, _ relay: UserChatRelay, operatorName: String?) -> some View {
        let selected = selectedRelayIds.contains(relayId)
        return Button {
            logger.debug("PX: [relayCheckRow] toggling relay \(relayId), selected=\(!selected)")
            pxToggleRelaySelection(relayId)
        } label: {
            HStack {
                pxRelayInfoView(relay: relay, operatorName: operatorName)
                Spacer()
                pxSelectionIndicator(selected: selected)
            }
            .padding(.horizontal, PXAddGroupRelayConfig.rowHorizontalPadding)
        }
        .accessibilityLabel(Text(chatRelayDisplayName(relay)))
        .accessibilityAddTraits(.isButton)
    }

    private func pxRelayInfoView(relay: UserChatRelay, operatorName: String?) -> some View {
        VStack(alignment: .leading, spacing: PXAddGroupRelayConfig.rowVerticalSpacing) {
            Text(chatRelayDisplayName(relay))
                .foregroundColor(theme.colors.onBackground)
                .lineLimit(PXAddGroupRelayConfig.rowLineLimit)
            if let opName = operatorName {
                Text(opName)
                    .foregroundColor(theme.colors.secondary)
                    .font(PXAddGroupRelayConfig.operatorNameFont)
                    .lineLimit(PXAddGroupRelayConfig.rowLineLimit)
            }
        }
    }

    private func pxSelectionIndicator(selected: Bool) -> some View {
        Image(systemName: selected ? PXAddGroupRelayConfig.selectedIconName : PXAddGroupRelayConfig.unselectedIconName)
            .foregroundColor(selected ? theme.colors.primary : Color(uiColor: .tertiaryLabel).asAnotherColorFromSecondary(theme))
            .scaleEffect(selected ? PXAddGroupRelayConfig.iconTransitionScale : 1.0)
            .animation(.easeInOut(duration: 0.15), value: selected)
    }

    // MARK: - POPOPX Actions

    private func pxToggleRelaySelection(_ relayId: Int64) {
        if selectedRelayIds.contains(relayId) {
            selectedRelayIds.remove(relayId)
        } else {
            selectedRelayIds.insert(relayId)
        }
    }

    private func loadAvailableRelays() async {
        logger.info("POPOPX: loadAvailableRelys started for group \(groupInfo.groupId)")
        do {
            let servers = try await getUserServers()
            let relays = PXAddGroupRelayViewModel(groupInfo: groupInfo, existingRelayIds: existingRelayIds)
                .filterNewRelays(from: servers)
            await MainActor.run {
                availableRelays = relays
                isLoading = false
            }
        } catch {
            logger.error("loadAvailableRelays error: \(responseError(error))")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func addSelectedRelays() {
        logger.info("POPOPX: addSelectedRelays started, count=\(selectedRelayIds.count)")
        let relayIds = Array(selectedRelayIds)
        guard !relayIds.isEmpty else { return }
        isAdding = true
        Task {
            do {
                guard let result = try await apiAddGroupRelays(groupInfo.groupId, relayIds: relayIds) else {
                    await MainActor.run { isAdding = false }
                    return
                }
                await MainActor.run {
                    isAdding = false
                    switch result {
                    case let .added(gInfo, _, relays):
                        pxOnRelaysAddedSuccessfully(gInfo: gInfo, relays: relays)
                    case let .addFailed(results):
                        pxHandlePartialAddFailure(results)
                    }
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    showAlert(NSLocalizedString("Error adding relays", comment: "alert title"), message: responseError(error))
                }
            }
        }
    }

    private func pxOnRelaysAddedSuccessfully(gInfo: GroupInfo, relays: [GroupRelay]) {
        ChannelRelaysModel.shared.set(groupId: gInfo.groupId, groupRelays: relays)
        onRelayAdded()
        dismiss()
    }

    private func pxHandlePartialAddFailure(_ results: [AddRelayResult]) {
        let successIds = Set(results.filter { $0.relayError == nil }.compactMap { $0.relay.chatRelayId })
        if !successIds.isEmpty {
            selectedRelayIds.subtract(successIds)
            availableRelays.removeAll { successIds.contains($0.relayId) }
            onRelayAdded()
        }
        let errorLines = results.filter { $0.relayError != nil }
            .map { "\(chatRelayDisplayName($0.relay)): \($0.relayError.map { connErrorText($0) } ?? "")" }
        let successNames = results.filter { $0.relayError == nil }
            .map { chatRelayDisplayName($0.relay) }
        var msg = errorLines.joined(separator: "\n")
        if !successNames.isEmpty {
            msg += "\n" + String.localizedStringWithFormat(NSLocalizedString("Relays added: %@.", comment: "alert message"), successNames.joined(separator: ", "))
        }
        showAlert(
            NSLocalizedString("Error adding relays", comment: "alert title"),
            message: msg
        )
    }
}

// MARK: - POPOPX
extension AddGroupRelayView {
    var pxComponentTag: String { "PX_ADD_GROUP_RELAY" }
    var pxAvailableRelayCount: Int { availableRelays.count }
    var pxSelectedRelayCount: Int { selectedRelayIds.count }
    var pxRowIconSize: CGFloat { PXAddGroupRelayConfig.relayRowIconSize }
}
