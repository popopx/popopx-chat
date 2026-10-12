//
//  SelectableChatItemToolbars.swift
//  POPOPX (iOS)
//
//  Created by Stanislav Dmitrenko on 30.07.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Toolbar Configuration
private enum PXToolbarsConfig {
    static let topToolbarWidth: CGFloat = 220
    static let iconSize: CGFloat = 20
    static let toolbarPadding: CGFloat = 12
    static let toolbarHeight: CGFloat = 55.5
    static let maxDeleteCount: Int = 200
    static let maxForwardCount: Int = 20
    static let contentShapeInset: CGFloat = 12
    static let dividerThickness: CGFloat = 0.5
}

@MainActor
private struct PXToolbarViewModel {
    let chatInfo: ChatInfo
    let itemsModel: ItemsModel
    let selectedItems: Set<Int64>?

    var selectionCount: Int { selectedItems?.count ?? 0 }

    var isGroupChat: Bool {
        if case ChatInfo.group = chatInfo { return true }
        return false
    }

    var groupInfo: GroupInfo? {
        if case let ChatInfo.group(groupInfo: info, _) = chatInfo { return info }
        return nil
    }

    var isDeleteProhibited: Bool {
        selectionCount == 0 || selectionCount > PXToolbarsConfig.maxDeleteCount
    }

    var isForwardProhibited: Bool {
        selectionCount == 0 || selectionCount > PXToolbarsConfig.maxForwardCount
    }
}

struct SelectedItemsTopToolbar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    @Binding var selectedChatItems: Set<Int64>?

    var body: some View {
        let count = selectedChatItems?.count ?? 0
        return Text(count == 0 ? NSLocalizedString("toolbar_nothing_selected", comment: "Nothing selected") : String(format: NSLocalizedString("toolbar_selected_count_format", comment: "Selected count"), count))
            .font(.headline)
            .foregroundColor(theme.colors.onBackground)
            .frame(width: PXToolbarsConfig.topToolbarWidth)
            .accessibilityLabel(Text(count == 0
                ? NSLocalizedString("No items selected", comment: "Accessibility label for empty selection")
                : NSLocalizedString("Items selected", comment: "Accessibility label for selection count")
            ))
            .popopxBranded()
    }
}

struct SelectedItemsBottomToolbar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var theme: AppTheme
    let im: ItemsModel
    @Binding var selectedChatItems: Set<Int64>?
    var chatInfo: ChatInfo
    // Bool - delete for everyone is possible
    var deleteItems: (Bool) -> Void
    var archiveItems: () -> Void
    var moderateItems: () -> Void
    //var shareItems: () -> Void
    var forwardItems: () -> Void
    @State var deleteEnabled: Bool = false
    @State var deleteForEveryoneEnabled: Bool = false

    @State var canArchiveReports: Bool = false

    @State var canModerate: Bool = false
    @State var moderateEnabled: Bool = false

    @State var forwardEnabled: Bool = false

    @State var deleteCountProhibited = false
    @State var forwardCountProhibited = false

    private var vm: PXToolbarViewModel {
        PXToolbarViewModel(chatInfo: chatInfo, itemsModel: im, selectedItems: selectedChatItems)
    }

    var body: some View {
        VStack(spacing: 0) {
            GlassDivider()
            pxToolbarActions
        }
        .onAppear { pxRecheckItems() }
        .onChange(of: chatInfo) { _, _ in pxRecheckItems() }
        .onChange(of: im.reversedChatItems) { _, _ in pxRecheckItems() }
        .onChange(of: selectedChatItems) { _, _ in pxRecheckItems() }
        .frame(height: PXToolbarsConfig.toolbarHeight)
        .background(.ultraThinMaterial)
        .popopxBranded()
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var pxToolbarActions: some View {
        HStack(alignment: .center) {
            pxDeleteButton
            Spacer()
            pxModerateButton
            Spacer()
            pxForwardButton
        }
        .frame(maxHeight: .infinity)
        .padding([.leading, .trailing], PXToolbarsConfig.toolbarPadding)
    }

    @ViewBuilder
    private var pxDeleteButton: some View {
        Button {
            if canArchiveReports {
                archiveItems()
            } else {
                deleteItems(deleteForEveryoneEnabled)
            }
        } label: {
            Image(systemName: "trash")
                .resizable()
                .scaledToFit()
                .frame(width: PXToolbarsConfig.iconSize, height: PXToolbarsConfig.iconSize, alignment: .center)
                .foregroundColor(!deleteEnabled || deleteCountProhibited ? theme.colors.secondary : theme.colors.error)
                .accessibilityLabel(Text(NSLocalizedString("Delete", comment: "delete selected items")))
        }
        .contentShape(Rectangle().inset(by: -PXToolbarsConfig.contentShapeInset))
        .disabled(!deleteEnabled || deleteCountProhibited)
    }

    @ViewBuilder
    private var pxModerateButton: some View {
        Button {
            moderateItems()
        } label: {
            Image(systemName: "flag")
                .resizable()
                .scaledToFit()
                .frame(width: PXToolbarsConfig.iconSize, height: PXToolbarsConfig.iconSize, alignment: .center)
                .foregroundColor(!moderateEnabled || deleteCountProhibited || im.secondaryIMFilter != nil ? theme.colors.secondary : theme.colors.error)
                .accessibilityLabel(Text(NSLocalizedString("Report", comment: "report selected items")))
        }
        .contentShape(Rectangle().inset(by: -PXToolbarsConfig.contentShapeInset))
        .disabled(!moderateEnabled || deleteCountProhibited || im.secondaryIMFilter != nil)
        .opacity(canModerate ? 1 : 0)
    }

    @ViewBuilder
    private var pxForwardButton: some View {
        Button {
            forwardItems()
        } label: {
            Image(systemName: "arrowshape.turn.up.forward")
                .resizable()
                .scaledToFit()
                .frame(width: PXToolbarsConfig.iconSize, height: PXToolbarsConfig.iconSize, alignment: .center)
                .foregroundColor(!forwardEnabled || forwardCountProhibited || im.secondaryIMFilter != nil ? theme.colors.secondary : theme.colors.primary)
                .accessibilityLabel(Text(NSLocalizedString("Forward", comment: "forward selected items")))
        }
        .contentShape(Rectangle().inset(by: -PXToolbarsConfig.contentShapeInset))
        .disabled(!forwardEnabled || forwardCountProhibited || im.secondaryIMFilter != nil)
    }

    // MARK: - Item State Checking

    private func pxRecheckItems() {
        pxRecheckItems(chatInfo, im.reversedChatItems, selectedChatItems)
    }

    private func pxRecheckItems(_ chatInfo: ChatInfo, _ chatItems: [ChatItem], _ selectedItems: Set<Int64>?) {
        let count = selectedItems?.count ?? 0
        deleteCountProhibited = count == 0 || count > PXToolbarsConfig.maxDeleteCount
        forwardCountProhibited = count == 0 || count > PXToolbarsConfig.maxForwardCount
        canModerate = pxPossibleToModerate(chatInfo)
        let groupInfo: GroupInfo? = if case let ChatInfo.group(groupInfo: info, _) = chatInfo {
            info
        } else {
             nil
        }
        if let selected = selectedItems {
            let me: Bool
            let onlyOwnGroupItems: Bool
            (deleteEnabled, deleteForEveryoneEnabled, canArchiveReports, me, onlyOwnGroupItems, forwardEnabled, selectedChatItems) = chatItems.reduce((true, true, true, true, true, true, [])) { (r, ci) in
                if selected.contains(ci.id) {
                    var (de, dee, ar, me, onlyOwnGroupItems, fe, sel) = r
                    de = de && ci.canBeDeletedForSelf
                    dee = dee && ci.meta.deletable && !ci.localNote && !ci.isReport
                    ar = ar && ci.isActiveReport && ci.chatDir != .groupSnd && (groupInfo.map { $0.membership.memberRole >= .moderator } ?? false)
                    onlyOwnGroupItems = onlyOwnGroupItems && ci.chatDir == .groupSnd && !ci.isReport
                    me = me && ci.content.msgContent != nil && ci.memberToModerate(chatInfo) != nil && !ci.isReport
                    fe = fe && ci.content.msgContent != nil && ci.meta.itemDeleted == nil && !ci.isLiveDummy && !ci.isReport
                    sel.insert(ci.id) // we are collecting new selected items here to account for any changes in chat items list
                    return (de, dee, ar, me, onlyOwnGroupItems, fe, sel)
                } else {
                    return r
                }
            }
            moderateEnabled = me && !onlyOwnGroupItems
        }
    }

    private func pxPossibleToModerate(_ chatInfo: ChatInfo) -> Bool {
        return switch chatInfo {
        case let .group(groupInfo, _):
            groupInfo.membership.memberRole >= .moderator
        default: false
        }
    }
}

// MARK: - POPOPX
extension SelectedItemsTopToolbar {
    var pxComponentTag: String { "PX_SELECTED_TOP_TOOLBAR" }
    var pxSelectionCountLabel: String {
        let n = selectedChatItems?.count ?? 0
        return n == 0 ? "px:none" : "px:\(n)"
    }
}

extension SelectedItemsBottomToolbar {
    var pxComponentTag: String { "PX_SELECTED_BOTTOM_TOOLBAR" }
    var pxActiveActionCount: Int {
        var count = 0
        if deleteEnabled { count += 1 }
        if forwardEnabled { count += 1 }
        if moderateEnabled { count += 1 }
        return count
    }
}
