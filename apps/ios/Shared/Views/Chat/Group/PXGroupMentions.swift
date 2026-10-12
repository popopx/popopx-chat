//
//  GroupMentions.swift
//  POPOPX (iOS)
//
//  Created by Diogo Cunha on 30/01/2025.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxMentionFilterEnabled = UserDefaults.standard.bool(forKey: "PX_MENTION_FILTER_ENABLED")

// POPOPX: mention parsing constants
private enum PXMentionMetrics {
    static let pxMemberCellHeight: CGFloat = 64
    static let pxMaxVisibleCells: CGFloat = 4.5
    static let pxMemberAvatarSize: CGFloat = 44
    static let pxAvatarTrailingPad: CGFloat = 5
    static let pxDisabledAlpha: CGFloat = 0.50
    static let pxDividerInset: CGFloat = 54
    static let pxDismissTapAlpha: CGFloat = 0.02
}

let MENTION_START: Character = "@"
let QUOTE: Character = "'"
let MEMBER_ROW_SIZE: CGFloat = PXMentionMetrics.pxMemberCellHeight
let MAX_VISIBLE_MEMBER_ROWS: CGFloat = PXMentionMetrics.pxMaxVisibleCells

struct GroupMentionsView: View {
    @EnvironmentObject var m: ChatModel
    @EnvironmentObject var theme: AppTheme
    var im: ItemsModel
    var groupInfo: GroupInfo
    @Binding var composeState: ComposeState
    @Binding var selectedRange: NSRange
    @Binding var keyboardVisible: Bool

    @State private var isVisible = false
    @State private var currentMessage: String = ""
    @State private var mentionName: String = ""
    @State private var mentionRange: NSRange?
    @State private var mentionMemberId: String?
    @State private var sortedMembers: [GMember] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            if isVisible {
                let pxFiltered = pxComputeFiltered()
                if pxFiltered.count > 0 {
                    Color.white.opacity(PXMentionMetrics.pxDismissTapAlpha)
                        .onTapGesture {
                            isVisible = false
                        }
                    VStack(spacing: 0) {
                        Spacer()
                        GlassDivider()
                        let pxScroll = ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(pxFiltered.enumerated()), id: \.element.wrapped.groupMemberId) { pxIndex, pxMember in
                                    let pxIsMentioned = mentionMemberId == pxMember.wrapped.memberId
                                    let pxIsDisabled = composeState.memberMentions.count >= MAX_NUMBER_OF_MENTIONS && !pxIsMentioned
                                    ZStack(alignment: .bottom) {
                                        pxBuildMemberRow(pxMember.wrapped, pxIsMentioned)
                                            .frame(height: PXMentionMetrics.pxMemberCellHeight)
                                            .padding(.horizontal)
                                            .opacity(pxIsDisabled ? PXMentionMetrics.pxDisabledAlpha : 1)
                                            .disabled(pxIsDisabled)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                memberSelected(pxMember)
                                            }

                                        GlassDivider()
                                            .padding(.leading, PXMentionMetrics.pxDividerInset)
                                    }
                                }
                            }
                        }
                            .background(theme.colors.background)
                            .frame(maxHeight: PXMentionMetrics.pxMemberCellHeight * min(PXMentionMetrics.pxMaxVisibleCells, CGFloat(pxFiltered.count)))

                        pxScroll.scrollDismissesKeyboard(.never)
                    }
                }
            }
        }
        .popopxBranded()
        .onChange(of: composeState.parsedMessage) {_, pxParsed in
            currentMessage = composeState.message
            messageChanged(currentMessage, pxParsed, selectedRange)
        }
        .onChange(of: selectedRange) {_, pxRange in
            // POPOPX: prevent messageChanged called twice – formattedText triggers later
            if currentMessage == composeState.message {
                messageChanged(currentMessage, composeState.parsedMessage, pxRange)
            }
        }
        .onAppear {
            currentMessage = composeState.message
        }
    }

    // POPOPX: compute filtered members with logging
    private func pxComputeFiltered() -> [GMember] {
        let pxTerm = mentionName.lowercased()
        logger.debug("PX: [filteredMembers] term=\(pxTerm), totalMembers=\(sortedMembers.count)")
        let pxResult = sortedMembers.filter {
            contextMemberFilter($0.wrapped)
            && (pxTerm.isEmpty || $0.wrapped.localAliasAndFullName.localizedLowercase.contains(pxTerm))
        }
        logger.debug("PX: [filteredMembers] filtered count=\(pxResult.count)")
        return pxResult
    }

    func contextMemberFilter(_ member: GroupMember) -> Bool {
        switch im.secondaryIMFilter {
        case nil:
            return true
        case let .groupChatScopeContext(groupScopeInfo):
            switch (groupScopeInfo) {
            case let .memberSupport(groupMember_):
                if let scopeMember = groupMember_ {
                    return member.memberRole >= .moderator || member.groupMemberId == scopeMember.groupMemberId
                } else {
                    return member.memberRole >= .moderator
                }
            case .reports:
                return false
            }
        case .msgContentTagContext:
            return false
        }
    }

    private func filteredMembers() -> [GMember] {
        pxComputeFiltered()
    }

    // POPOPX: handle message text changes and detect mention triggers
    private func messageChanged(_ msg: String, _ parsedMsg: [FormattedText], _ range: NSRange) {
        logger.info("POPOPX: messageChanged triggered, range length=\(range.length)")
        if let (ft, r) = selectedMarkdown(parsedMsg, range) {
            switch ft.format {
            case let .mention(name):
                pxOpenMentionList(name: name, range: r)
                return
            case .none: () //
                let pxPos = range.location
                if range.length == 0, let (at, atRange) = getCharacter(msg, pxPos - 1), at == "@" {
                    let pxPrevChar = getCharacter(msg, pxPos - 2)?.char
                    if pxPrevChar == nil || pxPrevChar == " " || pxPrevChar == "\n" {
                        pxOpenMentionList(name: "", range: atRange)
                        return
                    }
                }
            default: ()
            }
        }
        closeMemberList()
    }

    // POPOPX: open the mention list and load members if needed
    private func pxOpenMentionList(name: String, range: NSRange) {
        isVisible = true
        mentionName = name
        mentionRange = range
        mentionMemberId = composeState.memberMentions[name] != nil ? composeState.mentions[name]?.memberId : nil
        if !m.membersLoaded {
            Task {
                await m.loadGroupMembers(groupInfo)
                sortMembers()
            }
        }
    }

    private func sortMembers() {
        sortedMembers = m.groupMembers.filter({ m in
            let status = m.wrapped.memberStatus
            return status != .memLeft && status != .memRemoved && status != .memInvited
        })
        .sorted { $0.wrapped.memberRole > $1.wrapped.memberRole }
    }

    private func getCharacter(_ s: String, _ pos: Int) -> (char: String.SubSequence, range: NSRange)? {
        if pos < 0 || pos >= s.count { return nil }
        let r = NSRange(location: pos, length: 1)
        return if let range = Range(r, in: s) {
            (s[range], r)
        } else {
            nil
        }
    }
    
    private func selectedMarkdown(_ parsedMsg: [FormattedText], _ range: NSRange) -> (FormattedText, NSRange)? {
        if parsedMsg.isEmpty { return nil }
        var i = 0
        var pos: Int = 0
        while i < parsedMsg.count && pos + parsedMsg[i].text.count < range.location {
            pos += parsedMsg[i].text.count
            i += 1
        }
        // the second condition will be true when two markdowns are selected
        return i >= parsedMsg.count || range.location + range.length > pos + parsedMsg[i].text.count
            ? nil
            : (parsedMsg[i], NSRange(location: pos, length: parsedMsg[i].text.count))
    }
    
    private func memberSelected(_ member: GMember) {
        logger.debug("PX: [memberSelected] memberId=\(member.wrapped.memberId)")
        if let range = mentionRange, mentionMemberId == nil || mentionMemberId != member.wrapped.memberId {
            addMemberMention(member, range)
        }
    }
    
    // POPOPX: insert the @mention into the compose message
    private func addMemberMention(_ member: GMember, _ r: NSRange) {
        logger.debug("PX: [addMemberMention] adding mention for member=\(member.wrapped.memberId)")
        guard let range = Range(r, in: composeState.message) else { return }
        var mentions = composeState.mentions
        var pxResolvedName: String
        if let mm = mentions.first(where: { $0.value.memberId == member.wrapped.memberId }) {
            pxResolvedName = mm.key
        } else {
            pxResolvedName = composeState.mentionMemberName(member.wrapped.memberProfile.displayName)
        }
        mentions[pxResolvedName] = CIMention(groupMember: member.wrapped)
        let pxNeedsQuotes = pxResolvedName.contains(" ") || pxResolvedName.last?.isPunctuation == true
        var pxMentionText = pxNeedsQuotes
                        ? "@'\(pxResolvedName)'"
                        : "@\(pxResolvedName)"
        var pxCursorPos = r.location + pxMentionText.count
        let pxNewMsgLen = composeState.message.count + pxMentionText.count - r.length
        if pxCursorPos == pxNewMsgLen {
            pxMentionText += " "
            pxCursorPos += 1
        }
        composeState = composeState.copy(
            message: composeState.message.replacingCharacters(in: range, with: pxMentionText),
            mentions: mentions
        )
        selectedRange = NSRange(location: pxCursorPos, length: 0)
        closeMemberList()
        keyboardVisible = true
    }
    
    private func closeMemberList() {
        logger.debug("PX: [closeMemberList] closing mention list")
        isVisible = false
        mentionName = ""
        mentionRange = nil
        mentionMemberId = nil
    }
    
    // POPOPX: build a single member row with avatar, name, and optional checkmark
    private func pxBuildMemberRow(_ member: GroupMember, _ mentioned: Bool) -> some View {
        return HStack {
            MemberProfileImage(member, size: PXMentionMetrics.pxMemberAvatarSize)
                .padding(.trailing, PXMentionMetrics.pxAvatarTrailingPad)
            VStack(alignment: .leading) {
                let pxNameText = Text(member.localAliasAndFullName).foregroundColor(member.memberIncognito ? QuantumColors.accent : theme.colors.onBackground)
                (member.verified ? pxVerifiedShield() + pxNameText : pxNameText)
                    .lineLimit(1)
            }
            Spacer()
            if mentioned {
                Image(systemName: "checkmark")
            }
        }

        func pxVerifiedShield() -> Text {
            (Text(Image(systemName: "checkmark.shield")) + textSpace)
                .kerning(-2)
                .font(.caption)
                .baselineOffset(2)
                .foregroundColor(theme.colors.secondary)
        }
    }

    private func memberRowView(_ member: GroupMember, _ mentioned: Bool) -> some View {
        pxBuildMemberRow(member, mentioned)
    }
}

// MARK: - POPOPX

extension GroupMentionsView {
    var pxComponentTag: String { "PX_GROUP_MENTIONS" }
    var pxSortedMemberCount: Int { sortedMembers.count }
    var pxMentionActive: Bool { isVisible && !mentionName.isEmpty }
    var pxMentionAnimDuration: Double { 0.24 }
    var pxFilteredMemberCount: Int { pxComputeFiltered().count }
}
