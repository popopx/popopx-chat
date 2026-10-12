//
//  WhatsNewView.swift
//  POPOPX (iOS)
//
//  Created by Evgeny on 24/12/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/client/navigation.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import SwiftUI
import StoreKit
import POPOPXSwitch

private struct VersionDescription {
    var version: String
    var post: URL?
    var features: [Feature]
}

private enum Feature: Identifiable {
    case feature(Description)
    case view(FeatureView)
    
    var id: LocalizedStringKey {
        switch self {
        case let .feature(d): d.title
        case let .view(v): v.title
        }
    }
}

private struct Description {
    let icon: String?
    let title: LocalizedStringKey
    let description: LocalizedStringKey?
    var subfeatures: [(icon: String, description: LocalizedStringKey)] = []
}

private struct FeatureView {
    let icon: String?
    let title: LocalizedStringKey
    let view: () -> any View
}

let isInUS = {
    let code = SKStorefront().countryCode
    return code == "USA" || code == ""
}()

private let versionDescriptions: [VersionDescription] = [
    VersionDescription(
        version: "v4.2",
        post: URL(string: "https://popopxchat.com/blog/20221108-popopx-v4.2-security-audit-new-website.html"),
        features: [
            .feature(Description(
                icon: "checkmark.shield",
                title: LocalizedStringKey(NSLocalizedString("rn_v42_security_assessment", comment: "Release notes v4.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v42_security_assessment_desc", comment: "Release notes v4.2 description"))
            )),
            .feature(Description(
                icon: "person.2",
                title: LocalizedStringKey(NSLocalizedString("rn_v42_group_links", comment: "Release notes v4.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v42_group_links_desc", comment: "Release notes v4.2 description"))
            )),
            .feature(Description(
                icon: "checkmark",
                title: LocalizedStringKey(NSLocalizedString("rn_v42_auto_accept", comment: "Release notes v4.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v42_auto_accept_desc", comment: "Release notes v4.2 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v4.3",
        post: URL(string: "https://popopxchat.com/blog/20221206-popopx-v4.3-voice-messages.html"),
        features: [
            .feature(Description(
                icon: "mic",
                title: LocalizedStringKey(NSLocalizedString("rn_v43_voice_messages", comment: "Release notes v4.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v43_voice_messages_desc", comment: "Release notes v4.3 description"))
            )),
            .feature(Description(
                icon: "trash.slash",
                title: LocalizedStringKey(NSLocalizedString("rn_v43_irreversible_deletion", comment: "Release notes v4.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v43_irreversible_deletion_desc", comment: "Release notes v4.3 description"))
            )),
            .feature(Description(
                icon: "externaldrive.connected.to.line.below",
                title: LocalizedStringKey(NSLocalizedString("rn_v43_server_config", comment: "Release notes v4.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v43_server_config_desc", comment: "Release notes v4.3 description"))
            )),
            .feature(Description(
                icon: "eye.slash",
                title: LocalizedStringKey(NSLocalizedString("rn_v43_privacy_security", comment: "Release notes v4.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v43_privacy_security_desc", comment: "Release notes v4.3 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v4.4",
        post: URL(string: "https://popopxchat.com/blog/20230103-popopx-v4.4-disappearing-messages.html"),
        features: [
            .feature(Description(
                icon: "stopwatch",
                title: LocalizedStringKey(NSLocalizedString("rn_v44_disappearing_messages", comment: "Release notes v4.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v44_disappearing_messages_desc", comment: "Release notes v4.4 description"))
            )),
            .feature(Description(
                icon: "ellipsis.circle",
                title: LocalizedStringKey(NSLocalizedString("rn_v44_live_messages", comment: "Release notes v4.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v44_live_messages_desc", comment: "Release notes v4.4 description"))
            )),
            .feature(Description(
                icon: "checkmark.shield",
                title: LocalizedStringKey(NSLocalizedString("rn_v44_verify_security", comment: "Release notes v4.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v44_verify_security_desc", comment: "Release notes v4.4 description"))
            )),
            .feature(Description(
                icon: "camera",
                title: LocalizedStringKey(NSLocalizedString("rn_v44_gifs_stickers", comment: "Release notes v4.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v44_gifs_stickers_desc", comment: "Release notes v4.4 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v44_french_interface", comment: "Release notes v4.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v44_french_interface_desc", comment: "Release notes v4.4 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v4.5",
        post: URL(string: "https://popopxchat.com/blog/20230204-popopx-v4-5-user-chat-profiles.html"),
        features: [
            .feature(Description(
                icon: "person.crop.rectangle.stack",
                title: LocalizedStringKey(NSLocalizedString("rn_v45_multiple_profiles", comment: "Release notes v4.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v45_multiple_profiles_desc", comment: "Release notes v4.5 description"))
            )),
            .feature(Description(
                icon: "rectangle.and.pencil.and.ellipsis",
                title: LocalizedStringKey(NSLocalizedString("rn_v45_message_draft", comment: "Release notes v4.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v45_message_draft_desc", comment: "Release notes v4.5 description"))
            )),
            .feature(Description(
                icon: "network.badge.shield.half.filled",
                title: LocalizedStringKey(NSLocalizedString("release_notes_transport_isolation_title", comment: "Release notes feature title")),
                description: LocalizedStringKey(NSLocalizedString("release_notes_transport_isolation_desc", comment: "Release notes feature description"))
            )),
            .feature(Description(
                icon: "lock.doc",
                title: LocalizedStringKey(NSLocalizedString("rn_v45_private_filenames", comment: "Release notes v4.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v45_private_filenames_desc", comment: "Release notes v4.5 description"))
            )),
            .feature(Description(
                icon: "battery.25",
                title: LocalizedStringKey(NSLocalizedString("rn_v45_reduced_battery", comment: "Release notes v4.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v45_reduced_battery_desc", comment: "Release notes v4.5 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v45_italian_interface", comment: "Release notes v4.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v45_italian_interface_desc", comment: "Release notes v4.5 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v4.6",
        post: URL(string: "https://popopxchat.com/blog/20230328-popopx-v4-6-hidden-profiles.html"),
        features: [
            .feature(Description(
                icon: "lock",
                title: LocalizedStringKey(NSLocalizedString("rn_v46_hidden_profiles", comment: "Release notes v4.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v46_hidden_profiles_desc", comment: "Release notes v4.6 description"))
            )),
            .feature(Description(
                icon: "phone.arrow.up.right",
                title: LocalizedStringKey(NSLocalizedString("rn_v46_audio_video_calls", comment: "Release notes v4.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v46_audio_video_calls_desc", comment: "Release notes v4.6 description"))
            )),
            .feature(Description(
                icon: "flag",
                title: LocalizedStringKey(NSLocalizedString("rn_v46_group_moderation", comment: "Release notes v4.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v46_group_moderation_desc", comment: "Release notes v4.6 description"))
            )),
            .feature(Description(
                icon: "plus.message",
                title: LocalizedStringKey(NSLocalizedString("rn_v46_group_welcome", comment: "Release notes v4.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v46_group_welcome_desc", comment: "Release notes v4.6 description"))
            )),
            .feature(Description(
                icon: "battery.50",
                title: LocalizedStringKey(NSLocalizedString("rn_v46_further_battery", comment: "Release notes v4.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v46_further_battery_desc", comment: "Release notes v4.6 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v46_chinese_spanish", comment: "Release notes v4.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v46_chinese_spanish_desc", comment: "Release notes v4.6 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.0",
        post: URL(string: "https://popopxchat.com/blog/20230422-popopx-vision-funding-v5-videos-files-passcode.html"),
        features: [
            .feature(Description(
                icon: "arrow.up.doc",
                title: LocalizedStringKey(NSLocalizedString("rn_v50_videos_files", comment: "Release notes v5.0 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v50_videos_files_desc", comment: "Release notes v5.0 description"))
            )),
            .feature(Description(
                icon: "lock",
                title: LocalizedStringKey(NSLocalizedString("rn_v50_app_passcode", comment: "Release notes v5.0 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v50_app_passcode_desc", comment: "Release notes v5.0 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v50_polish_interface", comment: "Release notes v5.0 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v50_polish_interface_desc", comment: "Release notes v5.0 description"))
            )),
        ]
    ),
    // Also
    // preference to disable calls per contact
    // access welcome message via a group profile
    VersionDescription(
        version: "v5.1",
        post: URL(string: "https://popopxchat.com/blog/20230523-popopx-v5-1-message-reactions-self-destruct-passcode.html"),
        features: [
            .feature(Description(
                icon: "face.smiling",
                title: LocalizedStringKey(NSLocalizedString("rn_v51_message_reactions", comment: "Release notes v5.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v51_message_reactions_desc", comment: "Release notes v5.1 description"))
            )),
            .feature(Description(
                icon: "arrow.up.message",
                title: LocalizedStringKey(NSLocalizedString("rn_v51_better_messages", comment: "Release notes v5.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v51_better_messages_desc", comment: "Release notes v5.1 description"))
            )),
            .feature(Description(
                icon: "lock",
                title: LocalizedStringKey(NSLocalizedString("rn_v51_self_destruct_passcode", comment: "Release notes v5.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v51_self_destruct_passcode_desc", comment: "Release notes v5.1 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v51_japanese_interface", comment: "Release notes v5.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v51_japanese_interface_desc", comment: "Release notes v5.1 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.2",
        post: URL(string: "https://popopxchat.com/blog/20230722-popopx-v5-2-message-delivery-receipts.html"),
        features: [
            .feature(Description(
                icon: "checkmark",
                title: LocalizedStringKey(NSLocalizedString("rn_v52_delivery_receipts", comment: "Release notes v5.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v52_delivery_receipts_desc", comment: "Release notes v5.2 description"))
            )),
            .feature(Description(
                icon: "star",
                title: LocalizedStringKey(NSLocalizedString("rn_v52_find_chats", comment: "Release notes v5.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v52_find_chats_desc", comment: "Release notes v5.2 description"))
            )),
            .feature(Description(
                icon: "exclamationmark.arrow.triangle.2.circlepath",
                title: LocalizedStringKey(NSLocalizedString("rn_v52_keep_connections", comment: "Release notes v5.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v52_keep_connections_desc", comment: "Release notes v5.2 description"))
            )),
            .feature(Description(
                icon: "stopwatch",
                title: LocalizedStringKey(NSLocalizedString("rn_v52_one_message_disappear", comment: "Release notes v5.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v52_one_message_disappear_desc", comment: "Release notes v5.2 description"))
            )),
            .feature(Description(
                icon: "gift",
                title: LocalizedStringKey(NSLocalizedString("rn_v52_few_more_things", comment: "Release notes v5.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v52_few_more_things_desc", comment: "Release notes v5.2 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.3",
        post: URL(string: "https://popopxchat.com/blog/20230925-popopx-v5-3-desktop-app-local-file-encryption-directory-service.html"),
        features: [
            .feature(Description(
                icon: "desktopcomputer",
                title: LocalizedStringKey(NSLocalizedString("rn_v53_desktop_app", comment: "Release notes v5.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v53_desktop_app_desc", comment: "Release notes v5.3 description"))
            )),
            .feature(Description(
                icon: "lock",
                title: LocalizedStringKey(NSLocalizedString("rn_v53_encrypt_files", comment: "Release notes v5.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v53_encrypt_files_desc", comment: "Release notes v5.3 description"))
            )),
            .feature(Description(
                icon: "magnifyingglass",
                title: LocalizedStringKey(NSLocalizedString("rn_v53_discover_groups", comment: "Release notes v5.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v53_discover_groups_desc", comment: "Release notes v5.3 description"))
            )),
            .feature(Description(
                icon: "theatermasks",
                title: LocalizedStringKey(NSLocalizedString("rn_v53_incognito_mode", comment: "Release notes v5.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v53_incognito_mode_desc", comment: "Release notes v5.3 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(String(format: NSLocalizedString("rn_v53_new_languages %d", comment: "Release notes v5.3 title"), 4)),
                description: LocalizedStringKey(NSLocalizedString("rn_v53_new_languages_desc", comment: "Release notes v5.3 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.4",
        post: URL(string: "https://popopxchat.com/blog/20231125-popopx-v5-4-link-mobile-desktop-quantum-resistant-better-groups.html"),
        features: [
            .feature(Description(
                icon: "desktopcomputer",
                title: LocalizedStringKey(NSLocalizedString("rn_v54_link_apps", comment: "Release notes v5.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v54_link_apps_desc", comment: "Release notes v5.4 description"))
            )),
            .feature(Description(
                icon: "person.2",
                title: LocalizedStringKey(NSLocalizedString("rn_v54_better_groups", comment: "Release notes v5.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v54_better_groups_desc", comment: "Release notes v5.4 description"))
            )),
            .feature(Description(
                icon: "theatermasks",
                title: LocalizedStringKey(NSLocalizedString("rn_v54_incognito_groups", comment: "Release notes v5.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v54_incognito_groups_desc", comment: "Release notes v5.4 description"))
            )),
            .feature(Description(
                icon: "hand.raised",
                title: LocalizedStringKey(NSLocalizedString("rn_v54_block_members", comment: "Release notes v5.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v54_block_members_desc", comment: "Release notes v5.4 description"))
            )),
            .feature(Description(
                icon: "gift",
                title: LocalizedStringKey(NSLocalizedString("rn_v54_few_more_things", comment: "Release notes v5.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v54_few_more_things_desc", comment: "Release notes v5.4 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.5",
        post: URL(string: "https://popopxchat.com/blog/20240124-popopx-infrastructure-costs-v5-5-simplex-ux-private-notes-group-history.html"),
        features: [
            .feature(Description(
                icon: "folder",
                title: LocalizedStringKey(NSLocalizedString("rn_v55_private_notes", comment: "Release notes v5.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v55_private_notes_desc", comment: "Release notes v5.5 description"))
            )),
            .feature(Description(
                icon: "link",
                title: LocalizedStringKey(NSLocalizedString("rn_v55_paste_link", comment: "Release notes v5.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v55_paste_link_desc", comment: "Release notes v5.5 description"))
            )),
            .feature(Description(
                icon: "bubble.left.and.bubble.right",
                title: LocalizedStringKey(NSLocalizedString("rn_v55_join_groups", comment: "Release notes v5.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v55_join_groups_desc", comment: "Release notes v5.5 description"))
            )),
            .feature(Description(
                icon: "battery.50",
                title: LocalizedStringKey(NSLocalizedString("rn_v55_improved_delivery", comment: "Release notes v5.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v55_improved_delivery_desc", comment: "Release notes v5.5 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v55_turkish_interface", comment: "Release notes v5.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v55_turkish_interface_desc", comment: "Release notes v5.5 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.6",
        post: URL(string: "https://popopxchat.com/blog/20240323-simplex-network-privacy-non-profit-v5-6-quantum-resistant-e2e-encryption-simple-migration.html"),
        features: [
            .feature(Description(
                icon: "key",
                title: LocalizedStringKey(NSLocalizedString("rn_v56_quantum_encryption", comment: "Release notes v5.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v56_quantum_encryption_desc", comment: "Release notes v5.6 description"))
            )),
            .feature(Description(
                icon: "tray.and.arrow.up",
                title: LocalizedStringKey(NSLocalizedString("rn_v56_data_migration", comment: "Release notes v5.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v56_data_migration_desc", comment: "Release notes v5.6 description"))
            )),
            .feature(Description(
                icon: "phone",
                title: LocalizedStringKey(NSLocalizedString("rn_v56_pip_calls", comment: "Release notes v5.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v56_pip_calls_desc", comment: "Release notes v5.6 description"))
            )),
            .feature(Description(
                icon: "hand.raised",
                title: LocalizedStringKey(NSLocalizedString("rn_v56_safer_groups", comment: "Release notes v5.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v56_safer_groups_desc", comment: "Release notes v5.6 description"))
            )),
            .feature(Description(
                icon: "character",
                title: LocalizedStringKey(NSLocalizedString("rn_v56_hungarian_interface", comment: "Release notes v5.6 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v56_hungarian_interface_desc", comment: "Release notes v5.6 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.7",
        post: URL(string: "https://popopxchat.com/blog/20240426-simplex-legally-binding-transparency-v5-7-better-user-experience.html"),
        features: [
            .feature(Description(
                icon: "key",
                title: LocalizedStringKey(NSLocalizedString("rn_v57_quantum_encryption", comment: "Release notes v5.7 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v57_quantum_encryption_desc", comment: "Release notes v5.7 description"))
            )),
            .feature(Description(
                icon: "arrowshape.turn.up.forward",
                title: LocalizedStringKey(NSLocalizedString("rn_v57_forward_save", comment: "Release notes v5.7 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v57_forward_save_desc", comment: "Release notes v5.7 description"))
            )),
            .feature(Description(
                icon: "music.note",
                title: LocalizedStringKey(NSLocalizedString("rn_v57_incall_sounds", comment: "Release notes v5.7 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v57_incall_sounds_desc", comment: "Release notes v5.7 description"))
            )),
            .feature(Description(
                icon: "person.crop.square",
                title: LocalizedStringKey(NSLocalizedString("rn_v57_shape_images", comment: "Release notes v5.7 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v57_shape_images_desc", comment: "Release notes v5.7 description"))
            )),
            .feature(Description(
                icon: "antenna.radiowaves.left.and.right",
                title: LocalizedStringKey(NSLocalizedString("rn_v57_network_management", comment: "Release notes v5.7 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v57_network_management_desc", comment: "Release notes v5.7 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v5.8",
        post: URL(string: "https://popopxchat.com/blog/20240604-popopx-v5.8-private-message-routing-chat-themes.html"),
        features: [
            .feature(Description(
                icon: "arrow.forward",
                title: LocalizedStringKey(NSLocalizedString("rn_v58_private_routing", comment: "Release notes v5.8 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v58_private_routing_desc", comment: "Release notes v5.8 description"))
            )),
            .feature(Description(
                icon: "network.badge.shield.half.filled",
                title: LocalizedStringKey(NSLocalizedString("rn_v58_safely_receive_files", comment: "Release notes v5.8 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v58_safely_receive_files_desc", comment: "Release notes v5.8 description"))
            )),
            .feature(Description(
                icon: "battery.50",
                title: LocalizedStringKey(NSLocalizedString("rn_v58_improved_delivery", comment: "Release notes v5.8 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v58_improved_delivery_desc", comment: "Release notes v5.8 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v6.0",
        post: URL(string: "https://popopxchat.com/blog/20240814-popopx-vision-funding-v6-private-routing-new-user-experience.html"),
        features: [
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v60_new_chat_experience", comment: "Release notes v6.0 title")),
                description: nil,
                subfeatures: [
                    ("link.badge.plus", LocalizedStringKey(NSLocalizedString("rn_v60_sub_connect_faster", comment: "Release notes v6.0 subfeature"))),
                    ("archivebox", LocalizedStringKey(NSLocalizedString("rn_v60_sub_archive_contacts", comment: "Release notes v6.0 subfeature"))),
                    ("trash", LocalizedStringKey(NSLocalizedString("rn_v60_sub_delete_messages", comment: "Release notes v6.0 subfeature"))),
                    ("platter.filled.bottom.and.arrow.down.iphone", LocalizedStringKey(NSLocalizedString("rn_v60_sub_one_hand", comment: "Release notes v6.0 subfeature"))),
                    ("paintpalette", LocalizedStringKey(NSLocalizedString("rn_v60_sub_color_themes", comment: "Release notes v6.0 subfeature"))),
                ]
            )),
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v60_new_media_options", comment: "Release notes v6.0 title")),
                description: nil,
                subfeatures: [
                    ("square.and.arrow.up", LocalizedStringKey(NSLocalizedString("rn_v60_sub_share_apps", comment: "Release notes v6.0 subfeature"))),
                    ("play.circle", LocalizedStringKey(NSLocalizedString("rn_v60_sub_play_chat_list", comment: "Release notes v6.0 subfeature"))),
                    ("circle.filled.pattern.diagonalline.rectangle", LocalizedStringKey(NSLocalizedString("rn_v60_sub_blur_privacy", comment: "Release notes v6.0 subfeature")))
                ]
            )),
            .feature(Description(
                icon: "arrow.forward",
                title: LocalizedStringKey(NSLocalizedString("rn_v60_private_routing", comment: "Release notes v6.0 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v60_private_routing_desc", comment: "Release notes v6.0 description"))
            )),
            .feature(Description(
                icon: "network",
                title: LocalizedStringKey(NSLocalizedString("rn_v60_better_networking", comment: "Release notes v6.0 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v60_better_networking_desc", comment: "Release notes v6.0 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v6.1",
        post: URL(string: "https://popopxchat.com/blog/20241014-simplex-network-v6-1-security-review-better-calls-user-experience.html"),
        features: [
            .feature(Description(
                icon: "checkmark.shield",
                title: LocalizedStringKey(NSLocalizedString("rn_v61_better_security", comment: "Release notes v6.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v61_better_security_desc", comment: "Release notes v6.1 description"))
            )),
            .feature(Description(
                icon: "video",
                title: LocalizedStringKey(NSLocalizedString("rn_v61_better_calls", comment: "Release notes v6.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v61_better_calls_desc", comment: "Release notes v6.1 description"))
            )),
            .feature(Description(
                icon: "bolt",
                title: LocalizedStringKey(NSLocalizedString("rn_v61_better_notifications", comment: "Release notes v6.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v61_better_notifications_desc", comment: "Release notes v6.1 description"))
            )),
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v61_better_ux", comment: "Release notes v6.1 title")),
                description: nil,
                subfeatures: [
                    ("link", LocalizedStringKey(NSLocalizedString("rn_v61_sub_switch_profile", comment: "Release notes v6.1 subfeature"))),
                    ("message", LocalizedStringKey(NSLocalizedString("rn_v61_sub_message_shape", comment: "Release notes v6.1 subfeature"))),
                    ("calendar", LocalizedStringKey(NSLocalizedString("rn_v61_sub_message_dates", comment: "Release notes v6.1 subfeature"))),
                    ("arrowshape.turn.up.right", LocalizedStringKey(NSLocalizedString("rn_v61_sub_forward_messages", comment: "Release notes v6.1 subfeature"))),
                    ("flag", LocalizedStringKey(NSLocalizedString("rn_v61_sub_moderate_messages", comment: "Release notes v6.1 subfeature")))
                ]
            )),
        ]
    ),
    VersionDescription(
        version: "v6.2",
        post: URL(string: "https://popopxchat.com/blog/20241210-simplex-network-v6-2-servers-by-flux-business-chats.html"),
        features: [
            .view(FeatureView(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v62_network_decentralization", comment: "Release notes v6.2 title")),
                view: { NewOperatorsView() }
            )),
            .feature(Description(
                icon: "briefcase",
                title: LocalizedStringKey(NSLocalizedString("rn_v62_business_chats", comment: "Release notes v6.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v62_business_chats_desc", comment: "Release notes v6.2 description"))
            )),
            .feature(Description(
                icon: "bolt",
                title: LocalizedStringKey(NSLocalizedString("rn_v62_reliable_notifications", comment: "Release notes v6.2 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v62_reliable_notifications_desc", comment: "Release notes v6.2 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v6.3",
        post: URL(string: "https://popopxchat.com/blog/20250308-popopx-v6-3-new-user-experience-safety-in-public-groups.html"),
        features: [
            .feature(Description(
                icon: "at",
                title: LocalizedStringKey(NSLocalizedString("rn_v63_mention_members", comment: "Release notes v6.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v63_mention_members_desc", comment: "Release notes v6.3 description"))
            )),
            .feature(Description(
                icon: "flag",
                title: LocalizedStringKey(NSLocalizedString("rn_v63_private_reports", comment: "Release notes v6.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v63_private_reports_desc", comment: "Release notes v6.3 description"))
            )),
            .feature(Description(
                icon: "list.bullet",
                title: LocalizedStringKey(NSLocalizedString("rn_v63_organize_lists", comment: "Release notes v6.3 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v63_organize_lists_desc", comment: "Release notes v6.3 description"))
            )),
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v63_better_privacy", comment: "Release notes v6.3 title")),
                description: nil,
                subfeatures: [
                    ("eye.slash", LocalizedStringKey(NSLocalizedString("rn_v63_sub_private_media", comment: "Release notes v6.3 subfeature"))),
                    ("trash", LocalizedStringKey(NSLocalizedString("rn_v63_sub_message_expiration", comment: "Release notes v6.3 subfeature")))
                ]
            )),
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v63_better_groups_perf", comment: "Release notes v6.3 title")),
                description: nil,
                subfeatures: [
                    ("bolt", LocalizedStringKey(NSLocalizedString("rn_v63_sub_faster_sending", comment: "Release notes v6.3 subfeature"))),
                    ("person.2.slash", LocalizedStringKey(NSLocalizedString("rn_v63_sub_faster_deletion", comment: "Release notes v6.3 subfeature")))
                ]
            )),
        ]
    ),
    VersionDescription(
        version: "v6.4",
        post: URL(string: "https://popopxchat.com/blog/20250703-simplex-network-protocol-extension-for-securely-connecting-people.html"),
        features: [
            .feature(Description(
                icon: "person",
                title: LocalizedStringKey(NSLocalizedString("rn_v64_connect_faster", comment: "Release notes v6.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v64_connect_faster_desc", comment: "Release notes v6.4 description"))
            )),
            .feature(Description(
                icon: "person.bubble",
                title: LocalizedStringKey(NSLocalizedString("rn_v64_review_members", comment: "Release notes v6.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v64_review_members_desc", comment: "Release notes v6.4 description"))
            )),
            .feature(Description(
                icon: "questionmark.bubble",
                title: LocalizedStringKey(NSLocalizedString("rn_v64_chat_admins", comment: "Release notes v6.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v64_chat_admins_desc", comment: "Release notes v6.4 description"))
            )),
            .feature(Description(
                icon: "flag",
                title: LocalizedStringKey(NSLocalizedString("rn_v64_group_moderator", comment: "Release notes v6.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v64_group_moderator_desc", comment: "Release notes v6.4 description"))
            )),
            .feature(Description(
                icon: "battery.50",
                title: LocalizedStringKey(NSLocalizedString("rn_v64_improved_delivery", comment: "Release notes v6.4 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v64_improved_delivery_desc", comment: "Release notes v6.4 description"))
            )),
        ]
    ),
    VersionDescription(
        version: "v6.4.1",
        post: URL(string: "https://popopxchat.com/blog/20250729-popopx-v6-4-1-welcome-contacts-protect-groups-app-security.html"),
        features: [
            .feature(Description(
                icon: "hand.wave",
                title: LocalizedStringKey(NSLocalizedString("rn_v641_welcome_contacts", comment: "Release notes v6.4.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v641_welcome_contacts_desc", comment: "Release notes v6.4.1 description"))
            )),
            .feature(Description(
                icon: "stopwatch",
                title: LocalizedStringKey(NSLocalizedString("rn_v641_chats_clean", comment: "Release notes v6.4.1 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v641_chats_clean_desc", comment: "Release notes v6.4.1 description"))
            )),
            .view(FeatureView(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v641_short_address", comment: "Release notes v6.4.1 title")),
                view: { CreateUpdateAddressShortLink() }
            ))
        ]
    ),
    VersionDescription(
        version: "v6.5",
        post: URL(string: "https://popopxchat.com/blog/20260430-simplex-channels-v6-5-consortium-crowdfunding-freedom-of-speech.html"),
        features: [
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey(NSLocalizedString("rn_v65_public_channels", comment: "Release notes v6.5 title")),
                description: nil,
                subfeatures: [
                    ("antenna.radiowaves.left.and.right", LocalizedStringKey(NSLocalizedString("rn_v65_sub_reliability", comment: "Release notes v6.5 subfeature"))),
                    ("server.rack", LocalizedStringKey(NSLocalizedString("rn_v65_sub_ownership", comment: "Release notes v6.5 subfeature"))),
                    ("key.2.on.ring", LocalizedStringKey(NSLocalizedString("rn_v65_sub_security", comment: "Release notes v6.5 subfeature"))),
                    ("person.badge.shield.checkmark", LocalizedStringKey(NSLocalizedString("rn_v65_sub_privacy", comment: "Release notes v6.5 subfeature"))),
                ]
            )),
            .feature(Description(
                icon: "link.badge.plus",
                title: LocalizedStringKey(NSLocalizedString("rn_v65_invite_friends", comment: "Release notes v6.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v65_invite_friends_desc", comment: "Release notes v6.5 description"))
            )),
            .feature(Description(
                icon: "network.badge.shield.half.filled",
                title: LocalizedStringKey(NSLocalizedString("rn_v65_safe_web_links", comment: "Release notes v6.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v65_safe_web_links_desc", comment: "Release notes v6.5 description"))
            )),
            .feature(Description(
                icon: "network",
                title: LocalizedStringKey(NSLocalizedString("rn_v65_nonprofit_governance", comment: "Release notes v6.5 title")),
                description: LocalizedStringKey(NSLocalizedString("rn_v65_nonprofit_governance_desc", comment: "Release notes v6.5 description"))
            ))
        ]
    ),
    VersionDescription(
        version: isInUS ? "v7.0.1" : "v7.0",
        post: URL(string: "https://popopxchat.com/blog/20260819-popopx-crowdfunding.html"),
        features: [
            .feature(Description(
                icon: "at",
                title: LocalizedStringKey("release_v7_0_title_1"),
                description: LocalizedStringKey("release_v7_0_description_1")
            )),
            .feature(Description(
                icon: nil,
                title: LocalizedStringKey("release_v7_0_title_2"),
                description: nil,
                subfeatures: [
                    ("person.badge.plus", LocalizedStringKey("release_v7_0_sub_1")),
                    ("globe", LocalizedStringKey("release_v7_0_sub_2")),
                    ("server.rack", LocalizedStringKey("release_v7_0_sub_3")),
                    ("text.alignleft", LocalizedStringKey("release_v7_0_sub_4")),
                ]
            ))
        ]
    ),
    // TODO [badges] restore when badges ship, with final copy and the Read more link.
    /*
    VersionDescription(
        version: "v7.1",
        post: nil,
        features: [
            .view(FeatureView(
                icon: nil,
                title: NSLocalizedString("Supporter badge", comment: "Release notes v7.1 supporter badge title"),
                view: { SupporterBadgeWhatsNew() }
            ))
        ]
    ),
    */
]

private let lastVersion = versionDescriptions.last?.version ?? ""

func setLastVersionDefault() {
    UserDefaults.standard.set(lastVersion, forKey: DEFAULT_WHATS_NEW_VERSION)
}

func shouldShowWhatsNew() -> Bool {
    let v = UserDefaults.standard.string(forKey: DEFAULT_WHATS_NEW_VERSION)
    setLastVersionDefault()
    return v != lastVersion
}

fileprivate struct SupporterBadgeWhatsNew: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Supporter badge", comment: "Supporter badge whats new title"))
                    .font(.title3)
                    .bold()
                Text(NSLocalizedString("Help keep the network running — send files up to 2 GB.", comment: "Supporter badge whats new description"))
                    .multilineTextAlignment(.leading)
                    .lineLimit(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            heroThumbnail()
        }
    }

    @ViewBuilder
    private func heroThumbnail() -> some View {
        Image("badge-supporter")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
    }
}

fileprivate struct NewOperatorsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Image((operatorsInfo[.flux] ?? ServerOperator.dummyOperatorInfo).largeLogo)
                .resizable()
                .scaledToFit()
                .frame(height: 48)
            Text(NSLocalizedString("The second preset operator in the app!", comment: "New operator description"))
                .multilineTextAlignment(.leading)
                .lineLimit(10)
            HStack {
                Text(NSLocalizedString("Enable Flux in Network & servers settings for better metadata privacy.", comment: "Flux setup hint"))
            }
        }
        .popopxBranded()
    }
}

fileprivate struct CreateUpdateAddressShortLink: View {
    @EnvironmentObject private var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @State private var showAddressSheet = false
    @State private var progressIndicator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "link")
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(theme.colors.secondary)
                    .frame(minWidth: 30, alignment: .center)
                Text(NSLocalizedString("Short POPOPX address", comment: "Short address title")).font(.headline.weight(.bold))
            }
            Group {
                if let addr = chatModel.userAddress {
                    if addr.shouldBeUpgraded {
                        HStack(spacing: 8) {
                            Button(NSLocalizedString("Upgrade your address", comment: "Upgrade address button")) { upgradeAndShareAddressAlert(progressIndicator: $progressIndicator) }
                            if progressIndicator {
                                ProgressView()
                            }
                        }
                    } else {
                        Button(NSLocalizedString("Share your address", comment: "Share address button")) { addr.shareAddress(short: true) }
                    }
                } else {
                    Button(NSLocalizedString("Create your address", comment: "Create address button")) { showAddressSheet = true }
                }
            }
            .multilineTextAlignment(.leading)
            .lineLimit(10)
        }
        .sheet(isPresented: $showAddressSheet) {
            NavigationStack {
                UserAddressView(autoCreate: true)
                    .navigationTitle(NSLocalizedString("popopx_address_nav_title", comment: "POPOPX address navigation title"))
                    .navigationBarTitleDisplayMode(.large)
                    .modifier(ThemedBackground(grouped: true))
            }
        }
    }
}

private enum WhatsNewViewSheet: Identifiable {
    case showConditions

    var id: String {
        switch self {
        case .showConditions: return "showConditions"
        }
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) var dismiss: DismissAction
    @EnvironmentObject var theme: AppTheme
    @State var currentVersion = versionDescriptions.count - 1
    @State var currentVersionNav = versionDescriptions.count - 1
    var viaSettings = false
    var updatedConditions: Bool
    @State private var sheetItem: WhatsNewViewSheet? = nil

    var body: some View {
        whatsNewView()
            .sheet(item: $sheetItem) { item in
                switch item {
                case .showConditions:
                    UsageConditionsView(
                        currUserServers: Binding.constant([]),
                        userServers: Binding.constant([])
                    )
                    .modifier(ThemedBackground(grouped: true))
                }
            }
    }

    private func whatsNewView() -> some View {
        VStack {
            TabView(selection: $currentVersion) {
                ForEach(Array(versionDescriptions.enumerated()), id: \.0) { (i, v) in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(String(format: NSLocalizedString("New in %@", comment: "Version header"), v.version))
                                .font(.headline.weight(.bold))
                                .foregroundColor(theme.colors.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical)
                            ForEach(v.features) { f in
                                switch f {
                                case let .feature(d): featureDescription(d).padding(.bottom, 8)
                                case let .view(v): AnyView(v.view()).padding(.bottom, 8)
                                }
                            }
                            if let post = v.post {
                                ExternalLink(destination: post) {
                                    HStack {
                                        Text(NSLocalizedString("Read more", comment: "Read more link"))
                                        Image(systemName: "arrow.up.right.circle")
                                    }
                                }
                            }
                            if updatedConditions {
                                Button(NSLocalizedString("View updated conditions", comment: "View conditions button")) {
                                    sheetItem = .showConditions
                                }
                            }
                            if !viaSettings {
                                Spacer()

                                Button(NSLocalizedString("Ok", comment: "Dismiss button")) {
                                    dismiss()
                                }
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, alignment: .center)

                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            Spacer()
            pagination()
        }
        .padding()
        .onChange(of: currentVersion) {_, _ in
            currentVersionNav = currentVersion
        }
    }
    
    @ViewBuilder private func featureHeader(_ icon: String?, _ title: LocalizedStringKey) -> some View {
        if let icon {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: icon)
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(theme.colors.secondary)
                    .frame(minWidth: 30, alignment: .center)
                Text(title).font(.headline.weight(.bold))
            }
        } else {
            Text(title).font(.headline.weight(.bold))
        }
    }

    private func featureDescription(_ f: Description) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            featureHeader(f.icon, f.title)
            if let d = f.description {
                Text(d)
                    .multilineTextAlignment(.leading)
                    .lineLimit(10)
            }
            if f.subfeatures.count > 0 {
                ForEach(f.subfeatures, id: \.icon) { s in
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: s.icon)
                            .symbolRenderingMode(.monochrome)
                            .foregroundColor(theme.colors.secondary)
                            .frame(minWidth: 30, alignment: .center)
                        Text(s.description)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private func pagination() -> some View {
        HStack {
            if currentVersionNav > 0 {
                let prev = currentVersionNav - 1
                Button {
                    currentVersionNav = prev
                    withAnimation { currentVersion = prev }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(versionDescriptions[prev].version)
                    }
                }
            }
            Spacer()
            if currentVersionNav < versionDescriptions.count - 1 {
                let next = currentVersionNav + 1
                Button {
                    currentVersionNav = next
                    withAnimation { currentVersion = next }
                } label: {
                    HStack {
                        Text(versionDescriptions[next].version)
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
    }
}

struct NewFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewView(updatedConditions: false)
    }
}

// MARK: - POPOPX
extension WhatsNewView {
    static let pxComponentTag: String = "PX_RELEASE_NOTES_VIEW"
    static let pxSectionSpacing: CGFloat = 16
    static let pxFeatureBottomPadding: CGFloat = 8
    static let pxIconMinWidth: CGFloat = 30
}
