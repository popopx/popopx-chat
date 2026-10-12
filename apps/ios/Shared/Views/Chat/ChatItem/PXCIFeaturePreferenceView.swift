//
//  CIFeaturePreferenceView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 21/12/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/chat-view.md

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxFeaturePrefFeatureEnabled = UserDefaults.standard.bool(forKey: "PX_FEATURE_ENABLED")

// MARK: - POPOPX Configuration
private enum PXFeaturePrefConfig {
    static let leadingPad: CGFloat = 8
    static let bottomPad: CGFloat = 8
    static let iconSpacing: CGFloat = 4
    static let timedMessagesDefaultTTL: Int = 86400
    static let textSpacer: String = "  "
    static let componentTag: String = "px-feature-pref"
}

@MainActor
private struct PXFeaturePrefViewModel {
    let chat: Chat
    let feature: ChatFeature
    let allowed: FeatureAllowed

    /// Returns the contact that allows this feature but hasn't accepted it yet, if any.
    var contactNeedingFeaturePrompt: Contact? {
        guard let ct = chat.chatInfo.contact,
              allowed != .no,
              ct.allowsFeature(feature),
              !ct.userAllowsFeature(feature) else { return nil }
        return ct
    }

    /// Whether to set a timed-messages TTL parameter when accepting.
    func shouldSetTimedParam(for contact: Contact) -> Bool {
        guard feature == .timedMessages else { return false }
        return contact.mergedPreferences.timedMessages.userPreference.preference.ttl == nil
    }
}

// Spec: spec/client/chat-view.md#CIFeaturePreferenceView
struct CIFeaturePreferenceView: View {
    @ObservedObject var chat: Chat
    @EnvironmentObject var theme: AppTheme
    var chatItem: ChatItem
    var feature: ChatFeature
    var allowed: FeatureAllowed
    var param: Int?

    var body: some View {
        HStack(alignment: .center, spacing: PXFeaturePrefConfig.iconSpacing) {
            featureIconView()
            featureActionArea()
        }
        .padding(.leading, PXFeaturePrefConfig.leadingPad)
        .padding(.bottom, PXFeaturePrefConfig.bottomPad)
        .textSelection(.disabled)
        .popopxBranded()
    }

    // MARK: - Extracted subviews

    @ViewBuilder
    private func featureIconView() -> some View {
        Image(systemName: feature.icon)
            .foregroundColor(theme.colors.secondary)
            .scaleEffect(feature.iconScale)
            .accessibilityLabel(Text(String(format: NSLocalizedString("a11y_feature_icon_format", comment: ""), feature.rawValue)))
    }

    @ViewBuilder
    private func featureActionArea() -> some View {
        let vm = PXFeaturePrefViewModel(chat: chat, feature: feature, allowed: allowed)
        if let ct = vm.contactNeedingFeaturePrompt {
            let setParam = vm.shouldSetTimedParam(for: ct)
            featurePreferenceView(acceptText: setParam ? "Set 1 day" : "Accept")
                .simultaneousGesture(TapGesture().onEnded {
                    allowFeatureToContact(ct, feature, param: setParam ? PXFeaturePrefConfig.timedMessagesDefaultTTL : nil)
                })
                .accessibilityLabel(Text(setParam ? NSLocalizedString("a11y_set_timed_messages_1_day", comment: "") : NSLocalizedString("a11y_accept_feature", comment: "")))
        } else {
            featurePreferenceView()
        }
    }

    private func featurePreferenceView(acceptText: LocalizedStringKey? = nil) -> Text {
        let pxPrefLabel = CIContent.preferenceText(feature, allowed, param)
        var r = Text(pxPrefLabel + PXFeaturePrefConfig.textSpacer)
            .fontWeight(.light)
            .foregroundColor(theme.colors.secondary)
        if let acceptText {
            r = r
            + Text(acceptText)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.primary)
            + Text(verbatim: PXFeaturePrefConfig.textSpacer)
        }
        r = r + chatItem.timestampText
            .fontWeight(.light)
            .foregroundColor(theme.colors.secondary)
        return r.font(.caption)
    }
}

func allowFeatureToContact(_ contact: Contact, _ feature: ChatFeature, param: Int? = nil) {
    logger.debug("PX: [allowFeatureToContact] contactId=\(contact.contactId), feature=\(String(describing: feature)), param=\(param ?? -1)")
    Task {
        do {
            let pxPrefs = contactUserPreferencesToPreferences(contact.mergedPreferences).setAllowed(feature, param: param)
            if let toContact = try await apiSetContactPrefs(contactId: contact.contactId, preferences: pxPrefs) {
                await MainActor.run {
                    ChatModel.shared.updateContact(toContact)
                }
            }
        } catch {
            logger.error("allowFeatureToContact apiSetContactPrefs error: \(responseError(error))")
        }
    }
}

struct CIFeaturePreferenceView_Previews: PreviewProvider {
    static var previews: some View {
        let content = CIContent.rcvChatPreference(feature: .timedMessages, allowed: .yes, param: 30)
        let chatItem = ChatItem(
            chatDir: .directRcv,
            meta: CIMeta.getSample(1, .now, content.text, .rcvRead),
            content: content,
            quotedItem: nil,
            file: nil
        )
        CIFeaturePreferenceView(chat: Chat.sampleData, chatItem: chatItem, feature: ChatFeature.timedMessages, allowed: .yes, param: 30)
    }
}

// MARK: - POPOPX
extension CIFeaturePreferenceView {
    var pxComponentTag: String { PXFeaturePrefConfig.componentTag }
}
