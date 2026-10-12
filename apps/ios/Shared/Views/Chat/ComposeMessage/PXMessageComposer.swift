// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch
import SwiftyGif
import PhotosUI

// A badge only helps below the largest badge's limit, and not in incognito chats, so outside that
// the alert is informational as before.
@MainActor
func showLargeFileAlert(_ fileSize: Int64, incognito: Bool, senderProfile: LocalProfile?) {
    let title = NSLocalizedString("Large file!", comment: "file alert title")
    let message = largeFileMessage(fileSize, incognito: incognito, badgeIssue: expiredBadgeReason(fileSize, senderProfile))
    if !incognito && fileSize <= MAX_FILE_SIZE_XFTP_LEGEND && noShownBadge() {
        showAlert(title, message: message) { [supportPopopxAlertAction, okAlertAction] }
    } else {
        showAlert(title, message: message)
    }
}

// Spec: spec/client/compose.md#ComposeView
struct ComposeView: View {
    @EnvironmentObject var chatModel: ChatModel
    @EnvironmentObject var theme: AppTheme
    @ObservedObject var chat: Chat
    @ObservedObject var im: ItemsModel
    @Binding var composeState: ComposeState
    @Binding var showCommandsMenu: Bool
    @Binding var keyboardVisible: Bool
    @Binding var keyboardHiddenDate: Date
    @Binding var selectedRange: NSRange

    @State private var audioRecorder: AudioRecorder?
    @State private var voiceMessageRecordingTime: TimeInterval?
    @State private var startingRecording: Bool = false
    // for some reason voice message preview playback occasionally
    // fails to stop on ComposeVoiceView.playbackMode().onDisappear,
    // this is a workaround to fire an explicit event in certain cases
    @State private var stopPlayback: Bool = false
    @State private var holdingBroadcastVMR = false

    @State var linkUrl: String? = nil
    @State var hasPopopxLink: Bool = false
    @State var prevLinkUrl: String? = nil
    @State var pendingLinkUrl: String? = nil
    @State var cancelledLinks: Set<String> = []

    @Environment(\.colorScheme) private var colorScheme
    @State private var showChooseSource = false
    @State private var showMediaPicker = false
    @State private var showTakePhoto = false
    @State var chosenMedia: [UploadContent] = []
    @State private var showFileImporter = false
    @State private var showLocationPicker = false
    @State private var showSendRedPacket = false
    @State private var showCreateBinThere = false

    @UserDefault(DEFAULT_PRIVACY_SAVE_LAST_DRAFT) private var saveLastDraft = true
    @UserDefault(DEFAULT_TOOLBAR_MATERIAL) private var toolbarMaterial = ToolbarMaterial.defaultMaterial
    @AppStorage(GROUP_DEFAULT_INCOGNITO, store: groupDefaults) private var incognitoDefault = false
    @AppStorage(GROUP_DEFAULT_PRIVACY_SANITIZE_LINKS, store: groupDefaults) private var privacySanitizeLinks = false
    @AppStorage(GROUP_DEFAULT_PRIVACY_LINK_PREVIEWS, store: groupDefaults) private var useLinkPreviews = true
    @AppStorage(GROUP_DEFAULT_PRIVACY_LINK_PREVIEWS_SHOW_ALERT, store: groupDefaults) private var linkPreviewsShowAlert = true
    @State private var updatingCompose = false
    @State private var relayListExpanded = false
    @ObservedObject private var channelRelaysModel = ChannelRelaysModel.shared

    // Spec: spec/client/compose.md#body
    var body: some View {
        composeBodyView()
        .popopxBranded()
    }

    @ViewBuilder private func composeBodyView() -> some View {
        // POPOPX: compose bar background gradient and border
        let pxDarkBorderOpacity: Double = 0.5
        let pxDarkBorderSecondaryOpacity: Double = 0.3
        let pxBorderHeight: CGFloat = 0.75
        let pxShadowRadius: CGFloat = 12
        let pxShadowYOffset: CGFloat = -4
        VStack(spacing: 0) {
            GlassDivider()

            if chat.chatInfo.nextConnectPrepared,
               !composeState.inProgress,
               let user = chatModel.currentUser {
                ContextProfilePickerView(
                    chat: chat,
                    selectedUser: user
                )
                GlassDivider()
            }

            channelRelayBarsView()
            composeDisabledGroup()
        }
        .background {
            ZStack(alignment: .top) {
                Color(hex: "#110D1A").opacity(0.1)
                    .overlay(.ultraThinMaterial)
                if isInDarkTheme() {
                    LinearGradient(
                        colors: [
                            darkThemeAccentColor().opacity(0.06),
                            neonGradientSecondary().opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            if isInDarkTheme() {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                darkThemeAccentColor().opacity(pxDarkBorderOpacity),
                                neonGradientSecondary().opacity(pxDarkBorderSecondaryOpacity)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: pxBorderHeight)
            }
        }
        .shadow(color: isInDarkTheme() ? darkThemeAccentColor().opacity(0.15) : .clear, radius: pxShadowRadius, x: 0, y: pxShadowYOffset)
        .onChange(of: composeState.message) {_,  msg in
            handleMessageChange(msg)
        }
        .onChange(of: chat.chatInfo.sendMsgEnabled) {_,  sendEnabled in
            if !sendEnabled {
                cancelCurrentVoiceRecording()
                clearCurrentDraft()
                clearState()
            }
        }
        .onChange(of: composeState.inProgress) {_,  inProgress in
            // POPOPX: progress timeout delay extracted to constant
            let pxProgressTimeoutNs: UInt64 = 1_000000000
            if inProgress {
                Task {
                    try? await Task.sleep(nanoseconds: pxProgressTimeoutNs)
                    composeState.progressByTimeout = composeState.inProgress
                }
            } else {
                composeState.progressByTimeout = false
            }
        }
        .confirmationDialog(LocalizedStringKey(NSLocalizedString("chat_attach", comment: "attachment dialog title")), isPresented: $showChooseSource, titleVisibility: .visible) {
            Button(LocalizedStringKey(NSLocalizedString("chat_take_picture", comment: "attachment option"))) {
                showTakePhoto = true
            }
            Button(LocalizedStringKey(NSLocalizedString("chat_choose_from_library", comment: "attachment option"))) {
                showMediaPicker = true
            }
            if UIPasteboard.general.hasImages {
                Button(LocalizedStringKey(NSLocalizedString("chat_paste_image", comment: "attachment option"))) {
                    UIPasteboard.general.itemProviders.forEach { p in
                        if p.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                            p.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                                if let url = url, let image = UploadContent.loadFromURL(url: url) {
                                    DispatchQueue.main.async {
                                        chosenMedia.append(image)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Button(LocalizedStringKey(NSLocalizedString("chat_choose_file", comment: "attachment option"))) {
                showFileImporter = true
            }
            Button(LocalizedStringKey(NSLocalizedString("chat_share_location", comment: "attachment option"))) {
                showLocationPicker = true
            }
            Button(LocalizedStringKey(NSLocalizedString("chat_compute_red_packet", comment: "attachment option"))) {
                showSendRedPacket = true
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView { loc in
                sendEncodedTextMessage(encodeLocationMessage(loc))
            }
            .environmentObject(theme)
        }
        .sheet(isPresented: $showSendRedPacket) {
            SendRedPacketView { packet in
                sendEncodedTextMessage(encodeRedPacketMessage(packet), debitAmount: packet.amount)
            }
            .environmentObject(theme)
        }
        .sheet(isPresented: $showCreateBinThere) {
            CreateBinThereView { marker in
                sendEncodedTextMessage(marker)
            }
            .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showTakePhoto) {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                CameraImageListPicker(images: $chosenMedia)
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            LibraryMediaListPicker(addMedia: addMediaContent, selectionLimit: 10, finishedPreprocessing: finishedPreprocessingMediaContent) { itemsSelected in
                await MainActor.run {
                    showMediaPicker = false
                    if itemsSelected {
                        composeState = composeState.copy(preview: .mediaPreviews(mediaPreviews: []))
                    }
                }
            }
        }
        .onChange(of: chosenMedia) {_,  selected in
            processChosenMedia(selected)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .onDisappear {
            handleComposeDisappear()
        }
        .onChange(of: chatModel.stopPreviousRecPlay) {_, _ in
            if !startingRecording {
                if composeState.voiceMessageRecordingState == .recording {
                    finishVoiceMessageRecording()
                }
            } else {
                startingRecording = false
            }
        }
        .onChange(of: chat.chatInfo.featureEnabled(.voice)) {_,  vmAllowed in
            if !vmAllowed && composeState.voicePreview,
               let fileName = composeState.voiceMessageRecordingFileName {
                cancelVoiceMessageRecording(fileName)
                clearState()
            }
        }
        .onAppear {
            if case let .voicePreview(_, duration) = composeState.preview {
                voiceMessageRecordingTime = TimeInterval(duration)
            }
        }
    }

    private func processChosenMedia(_ selected: [UploadContent]) {
        Task {
            var media: [(String, UploadContent)] = []
            for content in selected {
                if let img = await resizeImageToStrSize(content.uiImage, maxDataSize: 14000) {
                    media.append((img, content))
                    await MainActor.run {
                        composeState = composeState.copy(preview: .mediaPreviews(mediaPreviews: media))
                    }
                }
            }
            if media.count == 0 {
                await MainActor.run {
                    composeState = composeState.copy(preview: .noPreview)
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        if case let .success(files) = result, let fileURL = files.first {
            do {
                var fileSize: Int? = nil
                if fileURL.startAccessingSecurityScopedResource() {
                    defer { fileURL.stopAccessingSecurityScopedResource() }
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    fileSize = resourceValues.fileSize
                }
                if let fileSize, fileSize <= maxFileSize {
                    composeState = composeState.copy(preview: .filePreview(fileName: fileURL.lastPathComponent, file: fileURL))
                } else {
                    showLargeFileAlert(Int64(fileSize ?? 0), incognito: sendIncognito, senderProfile: sendProfile)
                }
            } catch {
                logger.error("ComposeView fileImporter error \(error.localizedDescription)")
            }
        }
    }

    private func handleComposeDisappear() {
        if composeState.liveMessage != nil
            && (!composeState.message.isEmpty || composeState.liveMessage?.sentMsg != nil) {
            cancelCurrentVoiceRecording()
            clearCurrentDraft()
            sendMessage(ttl: nil)
            resetLinkPreview()
        } else if composeState.inProgress {
            clearCurrentDraft()
        } else if !composeState.empty {
            if case .recording = composeState.voiceMessageRecordingState {
                finishVoiceMessageRecording()
                if let fileName = composeState.voiceMessageRecordingFileName {
                    chatModel.filesToDelete.insert(getAppFilePath(fileName))
                }
            }
            if saveLastDraft {
                saveCurrentDraft()
            }
        } else {
            cancelCurrentVoiceRecording()
            clearCurrentDraft()
            clearState()
        }
        chatModel.removeLiveDummy(animated: false)
    }

    private func handleMessageChange(_ msg: String) {
        if updatingCompose {
            updatingCompose = false
            return
        }
        var parsedMsg = parseMarkdown(msg)
        if privacySanitizeLinks, let parsed = parsedMsg {
            let r = sanitizeMessage(parsed)
            if let sanitizedPos = r.sanitizedPos {
                updatingCompose = true
                composeState = composeState.copy(message: r.message, parsedMessage: r.parsedMsg)
                if sanitizedPos < selectedRange.location {
                    selectedRange = NSRange(location: sanitizedPos, length: 0)
                }
                parsedMsg = r.parsedMsg
            } else {
                composeState = composeState.copy(parsedMessage: parsedMsg)
            }
        } else {
            composeState = composeState.copy(parsedMessage: parsedMsg ?? FormattedText.plain(msg))
        }
        if composeState.linkPreviewAllowed && useLinkPreviews {
            if !msg.isEmpty {
                showLinkPreview(parsedMsg)
            } else {
                resetLinkPreview()
                hasPopopxLink = false
                composeState = composeState.copy(preview: .noPreview)
            }
        } else {
            resetLinkPreview()
            hasPopopxLink = !msg.isEmpty && !chat.groupFeatureEnabled(.popopxLinks) && getMessageLinks(parsedMsg).hasPopopxLink
            if composeState.linkPreviewAllowed {
                composeState = composeState.copy(preview: .noPreview)
            }
        }
    }

    private var ownerRelayState: (relays: [GroupRelay], activeCount: Int, failedCount: Int, removedCount: Int, noActiveRelays: Bool)? {
        guard let gInfo = chat.chatInfo.groupInfo, gInfo.useRelays,
              gInfo.membership.memberRole == .owner,
              ![.memLeft, .memRemoved, .memGroupDeleted].contains(gInfo.membership.memberStatus)
        else { return nil }
        guard channelRelaysModel.groupId == gInfo.groupId else { return nil }
        let relays = channelRelaysModel.groupRelays
        guard !relays.isEmpty else { return ([], 0, 0, 0, true) }
        let relayMembers = relays.map { relay in
            (relay, chatModel.groupMembers.first(where: { $0.wrapped.groupMemberId == relay.groupMemberId })?.wrapped)
        }
        let removedCount = relayMembers.filter { (_, m) in relayMemberRemoved(m?.memberStatus) }.count
        let activeCount = relayMembers.filter { (relay, m) in !relayMemberRemoved(m?.memberStatus) && relay.relayStatus == .active && m?.activeConn?.connFailedErr == nil }.count
        let failedCount = relayMembers.filter { (_, m) in !relayMemberRemoved(m?.memberStatus) && m?.activeConn?.connFailedErr != nil }.count
        let noActiveRelays = activeCount == 0 && (failedCount + removedCount) == relays.count
        return (relays, activeCount, failedCount, removedCount, noActiveRelays)
    }

    private var disabledText: LocalizedStringKey? {
        chat.chatInfo.userCantSendReason(allRelaysBroken: ownerRelayState?.noActiveRelays ?? false)?.composeLabel
    }

    @ViewBuilder private func ownerChannelRelayBar(relays: [GroupRelay], activeCount: Int, failedCount: Int, removedCount: Int) -> some View {
        let total = relays.count
        let allBroken = activeCount == 0 && (failedCount + removedCount) == total
        let sorted = relays.map { relay in
            (relay, chatModel.groupMembers.first(where: { $0.wrapped.groupMemberId == relay.groupMemberId })?.wrapped)
        }.sorted { relayDisplayName($0.0) < relayDisplayName($1.0) }
        VStack(spacing: 0) {
            relayBarHeader {
                if !allBroken && activeCount + failedCount + removedCount < total {
                    RelayProgressIndicator(active: activeCount, total: total)
                }
                if total == 0 {
                    Text(NSLocalizedString("chat_no_relays", comment: "channel relay bar"))
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(QuantumColors.warning)
                        .accessibilityHidden(true)
                } else if allBroken {
                    if removedCount == total {
                        Text(NSLocalizedString("chat_all_relays_removed", comment: "channel relay bar"))
                    } else if failedCount == total {
                        Text(NSLocalizedString("chat_all_relays_failed", comment: "channel relay bar"))
                    } else {
                        Text(NSLocalizedString("chat_no_active_relays", comment: "channel relay bar"))
                    }
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(QuantumColors.warning)
                        .accessibilityHidden(true)
                } else if activeCount + failedCount + removedCount >= total {
                    if failedCount > 0 && removedCount > 0 {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d relays not active", comment: "channel relay bar"), failedCount + removedCount))
                    } else if failedCount > 0 {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d relays failed", comment: "channel relay bar"), failedCount))
                    } else {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d relays removed", comment: "channel relay bar"), removedCount))
                    }
                } else if failedCount > 0 && removedCount > 0 {
                    Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays active, %d errors", comment: "channel relay bar"), activeCount, total, failedCount + removedCount))
                } else if failedCount > 0 {
                    Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays active, %d failed", comment: "channel relay bar"), activeCount, total, failedCount))
                } else if removedCount > 0 {
                    Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays active, %d removed", comment: "channel relay bar"), activeCount, total, removedCount))
                } else {
                    Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays active", comment: "channel relay bar progress"), activeCount, total))
                }
            }
            if relayListExpanded {
                if allBroken {
                    Text(NSLocalizedString("chat_add_relays_restore_delivery", comment: "channel relay bar hint"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                        .padding(.leading, 12)
                        .padding(.trailing)
                        .padding(.bottom, 4)
                }
                ForEach(sorted, id: \.0.id) { (relay, m) in
                    if let err = m?.activeConn?.connFailedErr {
                        Button {
                            showAlert(
                                NSLocalizedString("chat_relay_connection_failed", comment: "alert title"),
                                message: err
                            )
                        } label: {
                            ownerRelayDetailRow(relay, connFailed: true, memberStatus: m?.memberStatus)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ownerRelayDetailRow(relay, connFailed: false, memberStatus: m?.memberStatus)
                    }
                }
            }
        }
        .padding(.bottom, relayListExpanded ? 4 : 0)
        .animation(nil, value: relayListExpanded)
    }

    private func ownerRelayDetailRow(_ relay: GroupRelay, connFailed: Bool, memberStatus: GroupMemberStatus?) -> some View {
        relayBarDetailRow {
            Text(relayDisplayName(relay)).foregroundColor(theme.colors.secondary)
            Spacer()
            relayStatusIndicator(relay.relayStatus, connFailed: connFailed, memberStatus: memberStatus)
        }
    }

    @ViewBuilder private func subscriberChannelRelayBar(
        hostnames: [String],
        relayMembers: [GMember],
        connectedCount: Int,
        removedCount: Int,
        failedCount: Int,
        total: Int,
        showProgress: Bool
    ) -> some View {
        let errorCount = removedCount + failedCount
        let allBroken = connectedCount == 0 && errorCount == total
        VStack(spacing: 0) {
            relayBarHeader {
                if total == 0 {
                    Text(NSLocalizedString("chat_no_relays", comment: "channel subscriber relay bar"))
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(QuantumColors.warning)
                        .accessibilityHidden(true)
                } else if allBroken {
                    if removedCount == total {
                        Text(NSLocalizedString("chat_all_relays_removed", comment: "channel subscriber relay bar"))
                    } else if failedCount == total {
                        Text(NSLocalizedString("chat_all_relays_failed", comment: "channel subscriber relay bar"))
                    } else {
                        Text(NSLocalizedString("chat_no_active_relays", comment: "channel subscriber relay bar"))
                    }
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(QuantumColors.warning)
                        .accessibilityHidden(true)
                } else {
                    if showProgress && connectedCount + errorCount < total {
                        RelayProgressIndicator(active: connectedCount, total: total)
                    }
                    if connectedCount + removedCount + failedCount >= total, removedCount + failedCount > 0 {
                        if failedCount > 0 && removedCount > 0 {
                            Text(String.localizedStringWithFormat(NSLocalizedString("%d relays not active", comment: "channel subscriber relay bar"), failedCount + removedCount))
                        } else if failedCount > 0 {
                            Text(String.localizedStringWithFormat(NSLocalizedString("%d relays failed", comment: "channel subscriber relay bar"), failedCount))
                        } else if removedCount > 0 {
                            Text(String.localizedStringWithFormat(NSLocalizedString("%d relays removed", comment: "channel subscriber relay bar"), removedCount))
                        }
                    } else if failedCount > 0 && removedCount > 0 {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays connected, %d errors", comment: "channel subscriber relay bar"), connectedCount, total, errorCount))
                    } else if failedCount > 0 {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays connected, %d failed", comment: "channel subscriber relay bar"), connectedCount, total, failedCount))
                    } else if removedCount > 0 {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays connected, %d removed", comment: "channel subscriber relay bar"), connectedCount, total, removedCount))
                    } else {
                        Text(String.localizedStringWithFormat(NSLocalizedString("%d/%d relays connected", comment: "channel subscriber relay bar progress"), connectedCount, total))
                    }
                }
            }
            if relayListExpanded {
                if allBroken {
                    Text(NSLocalizedString("chat_waiting_owner_add_relays", comment: "subscriber relay bar hint"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)
                        .foregroundColor(theme.colors.secondary)
                        .padding(.leading, 12)
                        .padding(.trailing)
                        .padding(.bottom, 4)
                }
                if relayMembers.isEmpty {
                    ForEach(hostnames, id: \.self) { relay in
                        relayBarDetailRow {
                            Text(String.localizedStringWithFormat(NSLocalizedString("via %@", comment: "relay hostname"), hostFromRelayLink(relay)))
                                .foregroundColor(theme.colors.secondary)
                            Spacer()
                        }
                    }
                } else {
                    ForEach(relayMembers) { member in
                        let m = member.wrapped
                        let host = m.relayLink.map { hostFromRelayLink($0) }
                        let failedErr = m.activeConn?.connFailedErr
                        if let err = failedErr {
                            Button {
                                showAlert(
                                    NSLocalizedString("chat_relay_connection_failed", comment: "alert title"),
                                    message: err
                                )
                            } label: {
                                subscriberRelayDetailRow(m, host: host, connFailed: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            subscriberRelayDetailRow(m, host: host, connFailed: false)
                        }
                    }
                }
            }
        }
        .padding(.bottom, relayListExpanded ? 4 : 0)
        .animation(nil, value: relayListExpanded)
    }

    @ViewBuilder
    private func subscriberRelayDetailRow(_ m: GroupMember, host: String?, connFailed: Bool) -> some View {
        // POPOPX: status indicator circle size extracted to constant
        let pxStatusDotSize: CGFloat = 8
        relayBarDetailRow {
            Text(String.localizedStringWithFormat(NSLocalizedString("via %@", comment: "relay hostname"), host ?? m.chatViewName))
                .foregroundColor(theme.colors.secondary)
            Spacer()
            let status = relayConnStatus(m)
            Circle()
                .fill(status.color)
                .frame(width: pxStatusDotSize, height: pxStatusDotSize)
            Text(status.text)
                .foregroundColor(theme.colors.secondary)
            if connFailed {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
            }
        }
    }

    private func relayBarHeader<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button {
            withAnimation(nil) { relayListExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                content()
                Spacer()
                Image(systemName: relayListExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundColor(theme.colors.secondary)
                    .opacity(0.7)
                    .accessibilityLabel(relayListExpanded 
                        ? Text(NSLocalizedString("Collapse", comment: "collapse relay list"))
                        : Text(NSLocalizedString("Expand", comment: "expand relay list")))
            }
            .font(.callout)
            .foregroundColor(theme.colors.secondary)
            .padding(.top, 8)
            .padding(.bottom, relayListExpanded ? 4 : 8)
            .padding(.leading, 12)
            .padding(.trailing)
        }
    }

    // POPOPX: relay bar detail row with consistent padding
    @ViewBuilder
    private func relayBarDetailRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let pxDetailLeadingPad: CGFloat = 12
        let pxDetailVerticalPad: CGFloat = 2
        HStack {
            content()
        }
        .font(.caption)
        .padding(.leading, pxDetailLeadingPad)
        .padding(.trailing)
        .padding(.vertical, pxDetailVerticalPad)
    }


    private func relayMemberRemoved(_ status: GroupMemberStatus?) -> Bool {
        status.map { [.memLeft, .memRemoved, .memGroupDeleted].contains($0) } ?? false
    }

    @ViewBuilder private func channelRelayBarsView() -> some View {
        let ownerState = ownerRelayState
        if let gInfo = chat.chatInfo.groupInfo, gInfo.useRelays,
           ![.memRejected, .memLeft, .memRemoved, .memGroupDeleted].contains(gInfo.membership.memberStatus) {
            if gInfo.membership.memberRole == .owner {
                if let s = ownerState, s.relays.isEmpty || s.activeCount < s.relays.count {
                    ownerChannelRelayBar(relays: s.relays, activeCount: s.activeCount, failedCount: s.failedCount, removedCount: s.removedCount)
                }
            } else {
                let hostnames = (chatModel.channelRelayHostnames[gInfo.groupId] ?? []).sorted()
                let relayMembers = chatModel.groupMembers
                    .filter { $0.wrapped.memberRole == .relay && ![.memRemoved, .memGroupDeleted].contains($0.wrapped.memberStatus) }
                    .sorted { hostFromRelayLink($0.wrapped.relayLink ?? "") < hostFromRelayLink($1.wrapped.relayLink ?? "") }
                let showProgress = !gInfo.nextConnectPrepared || composeState.inProgress
                let removedCount = relayMembers.filter { relayMemberRemoved($0.wrapped.memberStatus) }.count
                let connectedCount = relayMembers.filter { !relayMemberRemoved($0.wrapped.memberStatus) && $0.wrapped.activeConn?.connStatus == .ready && $0.wrapped.activeConn?.connFailedErr == nil }.count
                let failedCount = relayMembers.filter { !relayMemberRemoved($0.wrapped.memberStatus) && $0.wrapped.activeConn?.connFailedErr != nil }.count
                let resolvedCount = connectedCount + removedCount + failedCount
                let total = relayMembers.count > 0 ? relayMembers.count : hostnames.count
                if total > 0 || chatModel.membersLoaded {
                    if total == 0 || removedCount + failedCount > 0 || resolvedCount < total {
                        subscriberChannelRelayBar(
                            hostnames: hostnames,
                            relayMembers: relayMembers,
                            connectedCount: connectedCount,
                            removedCount: removedCount,
                            failedCount: failedCount,
                            total: total,
                            showProgress: showProgress
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private func composeDisabledGroup() -> some View {
        let ownerState = ownerRelayState
        let userCantSendReason = chat.chatInfo.userCantSendReason(allRelaysBroken: ownerState?.noActiveRelays ?? false)
        let composeEnabled = (
            userCantSendReason == nil ||
            (chat.chatInfo.groupInfo?.nextConnectPrepared ?? false) ||
            (chat.chatInfo.contact?.nextAcceptContactRequest ?? false)
        )
        Group {
            composeInputGroup()
        }
        .disabled(!composeEnabled)
        .if(!composeEnabled) { v in
            v.onTapGesture {
                if let reason = userCantSendReason {
                    AlertManager.shared.showAlertMsg(
                        title: LocalizedStringKey(NSLocalizedString("chat_cannot_send_messages", comment: "alert title")),
                        message: reason.alertMessage
                    )
                }
            }
        }
    }

    @ViewBuilder private func composeInputGroup() -> some View {
        if let groupInfo = chat.chatInfo.groupInfo,
           case let .groupChatScopeContext(groupScopeInfo) = im.secondaryIMFilter,
           case let .memberSupport(member) = groupScopeInfo,
           let member = member,
           member.memberPending,
           composeState.contextItem == .noContextItem,
           composeState.noPreview {
            ContextPendingMemberActionsView(
                groupInfo: groupInfo,
                member: member
            )
            GlassDivider()
        }

        if case let .reportedItem(_, reason) = composeState.contextItem {
            reportReasonView(reason)
            GlassDivider()
        }
        let popopxLinkProhibited = im.secondaryIMFilter == nil && hasPopopxLink && !chat.groupFeatureEnabled(.popopxLinks)
        let fileProhibited = im.secondaryIMFilter == nil && composeState.attachmentPreview && !chat.groupFeatureEnabled(.files)
        let voiceProhibited = composeState.voicePreview && !chat.chatInfo.featureEnabled(.voice)
        let disableSendButton = popopxLinkProhibited || fileProhibited || voiceProhibited
        if popopxLinkProhibited {
            msgNotAllowedView(LocalizedStringKey(NSLocalizedString("chat_links_not_allowed", comment: "compose warning")), icon: "link")
            GlassDivider()
        } else if fileProhibited {
            msgNotAllowedView(LocalizedStringKey(NSLocalizedString("chat_files_media_not_allowed", comment: "compose warning")), icon: "doc")
            GlassDivider()
        } else if voiceProhibited {
            msgNotAllowedView(LocalizedStringKey(NSLocalizedString("chat_voice_messages_not_allowed", comment: "compose warning")), icon: "mic")
            GlassDivider()
        }
        contextItemView()
        switch (composeState.editing, composeState.preview) {
        case (true, .filePreview): EmptyView()
        case (true, .voicePreview): EmptyView()
        default: previewView()
        }

        let contact = chat.chatInfo.contact
        composeConnectionView(contact: contact, disableSendButton: disableSendButton)
    }

    @ViewBuilder private func composeConnectionView(contact: Contact?, disableSendButton: Bool) -> some View {
        if chat.chatInfo.groupInfo?.nextConnectPrepared == true {
            if chat.chatInfo.groupInfo?.businessChat == nil {
                let isChannel = chat.chatInfo.groupInfo?.useRelays == true
                connectButtonView(
                    isChannel ? LocalizedStringKey(NSLocalizedString("chat_join_channel", comment: "connect button")) : LocalizedStringKey(NSLocalizedString("chat_join_group", comment: "connect button")),
                    icon: isChannel ? "antenna.radiowaves.left.and.right.circle.fill" : "person.2.fill",
                    connect: connectPreparedGroup
                )
            } else {
                sendContactRequestView(disableSendButton, icon: "briefcase.fill", sendRequest: connectPreparedGroup)
            }
        } else if contact?.nextSendGrpInv == true {
            contextSendMessageToConnect(LocalizedStringKey(NSLocalizedString("chat_send_direct_message_to_connect", comment: "compose hint")))
            GlassDivider()
            HStack (alignment: .center) {
                attachmentAndCommandsButtons().disabled(true)
                sendMessageView(disableSendButton, sendToConnect: sendMemberContactInvitation)
            }
            .padding(.horizontal, 12)
        } else if let contact,
                  contact.nextConnectPrepared == true,
                  let linkType = contact.preparedContact?.uiConnLinkType {
            switch linkType {
            case .inv:
                connectButtonView(LocalizedStringKey(NSLocalizedString("chat_connect", comment: "connect button")), icon: "person.fill.badge.plus", connect: sendConnectPreparedContact)
            case .con:
                if contact.isBot {
                    connectButtonView(LocalizedStringKey(NSLocalizedString("chat_connect", comment: "connect button")), icon: "bolt.fill", connect: sendConnectPreparedContact)
                } else {
                    sendContactRequestView(disableSendButton, icon: "person.fill.badge.plus", sendRequest: sendConnectPreparedContactRequest)
                }
            }
        } else if contact?.nextAcceptContactRequest == true, let crId = contact?.contactRequestId {
            PXContactRequestActions(contactRequestId: crId)
        } else if let ct = contact, ct.nextAcceptContactRequest, let groupDirectInv = ct.groupDirectInv {
            ContextMemberContactActionsView(contact: ct, groupDirectInv: groupDirectInv)
        } else {
            sendMessageView(
                disableSendButton,
                placeholder: chat.chatInfo.groupInfo.map { gi in
                    gi.useRelays && gi.membership.memberRole >= .owner && chat.chatInfo.groupChatScope() == nil
                    ? NSLocalizedString("Broadcast", comment: "compose placeholder for channel owner")
                    : NSLocalizedString("Text something transient...", comment: "compose placeholder hint")
                } ?? NSLocalizedString("Text something transient...", comment: "compose placeholder hint"),
                attachmentButtons: { AnyView(attachmentAndCommandsButtons()) }
            )
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorScheme == .light ? Color.white.opacity(0.95) : Color(hex: "#110D1A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color(hex: "#00FFD2").opacity(0.7), lineWidth: 1.0)
                    )
            )
        }
    }

    @ViewBuilder
    private func connectButtonView(_ label: LocalizedStringKey, icon: String, connect: @escaping () -> Void) -> some View {
        let pxConnectBtnHeight: CGFloat = 57
        Button(action: connect) {
            ZStack(alignment: .trailing) {
                Label(label, systemImage: icon)
                    .frame(maxWidth: .infinity)
                if composeState.progressByTimeout && chat.chatInfo.groupInfo?.useRelays != true {
                    ProgressView()
                        .padding()
                }
            }
        }
        .frame(height: pxConnectBtnHeight)
        .disabled(composeState.inProgress)
    }

    @ViewBuilder
    private func sendContactRequestView(_ disableSendButton: Bool, icon: String, sendRequest: @escaping () -> Void) -> some View {
        let pxRequestHorizontalPad: CGFloat = 12
        let pxRequestInnerPad: CGFloat = 8
        HStack (alignment: .center) {
            sendMessageView(
                disableSendButton,
                placeholder: NSLocalizedString("chat_add_message", comment: "placeholder for sending contact request"),
                sendToConnect: sendRequest
            )
            if composeState.whitespaceOnly {
                Button(action: sendRequest) {
                    HStack {
                        Text(NSLocalizedString("chat_connect", comment: "connect button")).fontWeight(.medium)
                        Image(systemName: icon)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, pxRequestInnerPad)
                .disabled(composeState.inProgress)
            }
        }
        .padding(.horizontal, pxRequestHorizontalPad)
    }

    // Spec: spec/client/compose.md#sendMessageView
    @ViewBuilder
    private func sendMessageView(_ disableSendButton: Bool, placeholder: String? = nil, sendToConnect: (() -> Void)? = nil, attachmentButtons: (() -> AnyView)? = nil) -> some View {
        let pxMessageTextPad: CGFloat = 12
        ZStack(alignment: .leading) {
            SendMessageView(
                placeholder: disabledText != nil ? nil : placeholder,
                composeState: $composeState,
                selectedRange: $selectedRange,
                sendMessage: { ttl in
                    sendMessage(ttl: ttl)
                    resetLinkPreview()
                },
                sendLiveMessage: chat.chatInfo.chatType != .local ? sendLiveMessage : nil,
                updateLiveMessage: updateLiveMessage,
                cancelLiveMessage: {
                    composeState.liveMessage = nil
                    chatModel.removeLiveDummy()
                },
                sendToConnect: sendToConnect,
                hideSendButton: chat.chatInfo.nextConnect && chat.chatInfo.contact?.nextSendGrpInv != true && composeState.whitespaceOnly,
                voiceMessageAllowed: chat.chatInfo.featureEnabled(.voice),
                disableSendButton: disableSendButton,
                showEnableVoiceMessagesAlert: chat.chatInfo.showEnableVoiceMessagesAlert,
                startVoiceMessageRecording: {
                    Task {
                        await startVoiceMessageRecording()
                    }
                },
                finishVoiceMessageRecording: finishVoiceMessageRecording,
                allowVoiceMessagesToContact: allowVoiceMessagesToContact,
                timedMessageAllowed: chat.chatInfo.featureEnabled(.timedMessages),
                onMediaAdded: { media in if !media.isEmpty { chosenMedia = media }},
                attachmentButtons: attachmentButtons,
                keyboardVisible: $keyboardVisible,
                keyboardHiddenDate: $keyboardHiddenDate,
                sendButtonColor: chat.chatInfo.incognito
                ? QuantumColors.accent.opacity(colorScheme == .dark ? 1 : 0.7)
                : theme.colors.primary
            )
            .disabled(!chat.chatInfo.sendMsgEnabled)

            if let disabledText {
                Text(disabledText)
                    .italic()
                    .padding(.horizontal, pxMessageTextPad)
                    .foregroundColor(theme.colors.secondary)
            }
        }
    }

    @ViewBuilder private func attachmentAndCommandsButtons() -> some View {
        let pxAttachmentSpacing: CGFloat = 3
        let msg = composeState.message.trimmingCharacters(in: .whitespaces)
        let showAttachment = chat.chatInfo.contact?.profile.peerType != .bot || chat.chatInfo.featureEnabled(.files)
        let showCommands = chat.chatInfo.useCommands && (!showAttachment || msg.isEmpty || msg.starts(with: "/"))
        if showCommands {
            commandsButton()
        }
        if showAttachment {
            attachmentButton()
                .padding(.trailing, pxAttachmentSpacing)
                .if(showCommands) { v in v.padding(.leading, pxAttachmentSpacing) }
        }
        locationButton()
        tokenGiftButton()
        binThereButton()
        broadcastVoiceButton()
    }

    @ViewBuilder
    private func locationButton() -> some View {
        let pxIconSize: CGFloat = 22
        Button {
            showLocationPicker = true
        } label: {
            Image(systemName: "location.fill")
                .resizable()
        }
        .disabled(!chat.chatInfo.sendMsgEnabled)
        .frame(width: pxIconSize, height: pxIconSize)
        .tint(theme.colors.primary)
        .padding(.bottom, 2)
        .padding(.leading, 3)
    }

    @ViewBuilder
    private func tokenGiftButton() -> some View {
        let pxIconSize: CGFloat = 22
        Button {
            showSendRedPacket = true
        } label: {
            Image(systemName: "gift.fill")
                .resizable()
        }
        .disabled(!chat.chatInfo.sendMsgEnabled)
        .frame(width: pxIconSize, height: pxIconSize)
        .tint(theme.colors.secondary)
        .padding(.bottom, 2)
        .padding(.leading, 3)
    }

    @ViewBuilder
    private func binThereButton() -> some View {
        let pxIconSize: CGFloat = 22
        Button {
            showCreateBinThere = true
        } label: {
            Image(systemName: "lock.fill")
                .resizable()
        }
        .disabled(!chat.chatInfo.sendMsgEnabled)
        .frame(width: pxIconSize, height: pxIconSize)
        .tint(QuantumColors.accent)
        .padding(.bottom, 2)
        .padding(.leading, 3)
    }

    @ViewBuilder
    private func broadcastVoiceButton() -> some View {
        let bridge = chatModel.meshBridge
        let isMesh = chatModel.currentTransportID == "bluetooth"
        let isRecording = bridge?.isBroadcastVoiceRecording ?? false
        if isMesh, bridge != nil {
            Image(systemName: isRecording ? "dot.radiowaves.left.and.right" : "dot.radiowaves.right")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(isRecording ? QuantumColors.error : theme.colors.primary)
                .opacity(holdingBroadcastVMR ? 0.7 : 1)
                .frame(width: 22, height: 22)
                .padding([.bottom, .trailing], 2)
                ._onButtonGesture { down in
                    if down {
                        holdingBroadcastVMR = true
                        Task { await bridge?.startBroadcastVoiceRecording() }
                    } else {
                        holdingBroadcastVMR = false
                        Task { await bridge?.finishBroadcastVoiceRecording() }
                    }
                } perform: {}
                .accessibilityLabel(Text(NSLocalizedString("chat_broadcast_voice", comment: "accessibility label for broadcast voice button")))
        }
    }

    @ViewBuilder
    private func commandsButton() -> some View {
        let pxCommandsBtnSize: CGFloat = 25
        Button {
            showCommandsMenu.toggle()
        } label: {
            Text(verbatim: "//")
                .font(.title3)
                .italic()
                .contentShape(Rectangle())
        }
        .disabled(!chat.chatInfo.sendMsgEnabled || chat.chatInfo.menuCommands.isEmpty)
        .frame(width: pxCommandsBtnSize, height: pxCommandsBtnSize)
        .tint(theme.colors.primary)
        .padding(.bottom, 2)
    }

    @ViewBuilder private func attachmentButton() -> some View {
        let pxAttachBtnSize: CGFloat = 25
        let pxAttachDisabledOpacity = 0.4
        let b = Button {
            showChooseSource = true
        } label: {
            Image(systemName: "paperclip")
                .resizable()
        }
            .disabled(composeState.attachmentDisabled || !chat.chatInfo.sendMsgEnabled)
            .frame(width: pxAttachBtnSize, height: pxAttachBtnSize)
            .tint(theme.colors.primary)
        if im.secondaryIMFilter == nil,
           !chat.chatInfo.featureEnabled(.files) {
            Button {
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("chat_files_media_prohibited", comment: "alert title")),
                    message: chat.chatInfo.groupInfo == nil ? nil : LocalizedStringKey(NSLocalizedString("chat_only_owners_enable_files", comment: "alert message"))
                )
            } label: {
                Image(systemName: "paperclip")
                    .resizable()
                    .frame(width: pxAttachBtnSize, height: pxAttachBtnSize)
                    .opacity(pxAttachDisabledOpacity)
            }
            .buttonStyle(PlainButtonStyle())
            .tint(theme.colors.primary)
        } else {
            b
        }
    }

    private func sendMemberContactInvitation() {
        Task {
            do {
                await MainActor.run { hideKeyboard() }
                if let mc = connectCheckLinkPreview() {
                    await sending()
                    let contact = try await apiSendMemberContactInvitation(chat.chatInfo.apiId, mc)
                    await MainActor.run {
                        self.chatModel.updateContact(contact)
                        clearState()
                    }
                } else {
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("chat_empty_message", comment: "alert title")))
                }
            } catch {
                await MainActor.run { composeState.inProgress = false }
                logger.error("ChatView.sendMemberContactInvitation error: \(error.localizedDescription)")
                AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error sending member contact invitation", comment: "alert title")), message: LocalizedStringKey(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
            }
        }
    }

    private func sendConnectPreparedContactRequest() {
        hideKeyboard()
        let empty = composeState.whitespaceOnly
        AlertManager.shared.showAlert(Alert(
            title: Text(NSLocalizedString("chat_send_contact_request", comment: "alert title")),
            message: Text(NSLocalizedString("chat_messages_only_after_accepted", comment: "alert message")),
            primaryButton: .default(
                Text(empty ? NSLocalizedString("chat_send_request_no_message", comment: "alert button") : NSLocalizedString("chat_send_request", comment: "alert button")),
                action: sendConnectPreparedContact
            ),
            secondaryButton:
                empty
                ? .cancel(Text(NSLocalizedString("chat_add_message", comment: "alert button")), action: hideKeyboard)
                : .cancel()
        ))
    }

    private func sendConnectPreparedContact() {
        Task {
            await MainActor.run { hideKeyboard() }
            await sending()
            let mc = connectCheckLinkPreview()
            let incognito = chat.chatInfo.profileChangeProhibited ? chat.chatInfo.incognito : incognitoDefault
            if let contact = await apiConnectPreparedContact(contactId: chat.chatInfo.apiId, incognito: incognito, msg: mc) {
                await MainActor.run {
                    self.chatModel.updateContact(contact)
                    clearState()
                }
            } else {
                await MainActor.run { composeState.inProgress = false }
            }
        }
    }

    private func connectPreparedGroup() {
        Task {
            await MainActor.run { hideKeyboard() }
            await sending()
            let mc = connectCheckLinkPreview()
            let incognito = chat.chatInfo.profileChangeProhibited ? chat.chatInfo.incognito : incognitoDefault
            if let (groupInfo, relayResults) = await apiConnectPreparedGroup(groupId: chat.chatInfo.apiId, incognito: incognito, msg: mc) {
                await MainActor.run {
                    self.chatModel.updateGroup(groupInfo)
                    self.chatModel.channelRelayHostnames.removeValue(forKey: groupInfo.groupId)
                    self.chatModel.groupMembers = relayResults.map { GMember($0.relayMember) }
                    self.chatModel.populateGroupMembersIndexes()
                    clearState()
                }
            } else {
                await MainActor.run { composeState.inProgress = false }
            }
        }
    }

    @inline(__always)
    private func connectCheckLinkPreview() -> MsgContent? {
        let msgText = composeState.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return msgText.isEmpty ? nil : checkLinkPreview_(msgText)
    }

    @inline(__always)
    private func checkLinkPreview() -> MsgContent {
        checkLinkPreview_(composeState.message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func checkLinkPreview_(_ msgText: String) -> MsgContent {
        switch (composeState.preview) {
        case let .linkPreview(linkPreview: linkPreview):
            if let parsedMsg = parseMarkdown(msgText),
               let url = getMessageLinks(parsedMsg).url,
               let linkPreview = linkPreview,
               url == linkPreview.uri {
                return .link(text: msgText, preview: linkPreview)
            } else {
                return .text(msgText)
            }
        default:
            return .text(msgText)
        }
    }

    // Spec: spec/client/compose.md#addMediaContent
    private func addMediaContent(_ content: UploadContent) async {
        if let img = await resizeImageToStrSize(content.uiImage, maxDataSize: 14000) {
            var newMedia: [(String, UploadContent?)] = []
            if case var .mediaPreviews(media) = composeState.preview {
                media.append((img, content))
                newMedia = media
            } else {
                newMedia = [(img, content)]
            }
            await MainActor.run {
                composeState = composeState.copy(preview: .mediaPreviews(mediaPreviews: newMedia))
            }
        }
    }

    // When error occurs while converting video, remove media preview
    private func finishedPreprocessingMediaContent() {
        if case let .mediaPreviews(media) = composeState.preview, media.isEmpty {
            DispatchQueue.main.async {
                composeState = composeState.copy(preview: .noPreview)
            }
        }
    }

    // no badge is presented in incognito chats, so it does not raise the limit there
    private var sendIncognito: Bool {
        chat.chatInfo.profileChangeProhibited ? chat.chatInfo.incognito : incognitoDefault
    }

    private var sendProfile: LocalProfile? { sendIncognito ? nil : chatModel.currentUser?.profile }

    private var maxFileSize: Int64 { getMaxFileSize(.xftp, sendProfile) }

    // Spec: spec/client/compose.md#sendLiveMessage
    private func sendLiveMessage() async {
        let typedMsg = composeState.message
        let lm = composeState.liveMessage
        if (composeState.sendEnabled || composeState.quoting)
            && (lm == nil || lm?.sentMsg == nil),
           let ci = await sendMessageAsync(typedMsg, live: true, ttl: nil) {
            await MainActor.run {
                composeState = composeState.copy(liveMessage: LiveMessage(chatItem: ci, typedMsg: typedMsg, sentMsg: typedMsg))
            }
        } else if lm == nil {
            let cItem = chatModel.addLiveDummy(chat.chatInfo)
            await MainActor.run {
                composeState = composeState.copy(liveMessage: LiveMessage(chatItem: cItem, typedMsg: typedMsg, sentMsg: nil))
            }
        }
    }

    // Spec: spec/client/compose.md#updateLiveMessage
    private func updateLiveMessage() async {
        let typedMsg = composeState.message
        if let liveMessage = composeState.liveMessage {
            if let sentMsg = liveMessageToSend(liveMessage, typedMsg),
               let ci = await sendMessageAsync(sentMsg, live: true, ttl: nil) {
                await MainActor.run {
                    composeState = composeState.copy(liveMessage: LiveMessage(chatItem: ci, typedMsg: typedMsg, sentMsg: sentMsg))
                }
            } else if liveMessage.typedMsg != typedMsg {
                await MainActor.run {
                    var lm = liveMessage
                    lm.typedMsg = typedMsg
                    composeState = composeState.copy(liveMessage: lm)
                }
            }
        }
    }

    // Spec: spec/client/compose.md#liveMessageToSend
    private func liveMessageToSend(_ lm: LiveMessage, _ t: String) -> String? {
        let s = t != lm.typedMsg ? truncateToWords(t) : t
        return s != lm.sentMsg && (lm.sentMsg != nil || !s.isEmpty) ? s : nil
    }

    private func truncateToWords(_ s: String) -> String {
        var acc = ""
        var word = ""
        for c in s {
            if c.isLetter || c.isNumber {
                word = word + String(c)
            } else {
                acc = acc + word + String(c)
                word = ""
            }
        }
        return acc + word
    }

    @ViewBuilder func previewView() -> some View {
        switch composeState.preview {
        case .noPreview:
            EmptyView()
        case let .linkPreview(linkPreview: preview):
            ComposeLinkView(
                linkPreview: preview,
                cancelPreview: cancelLinkPreview,
                cancelEnabled: !composeState.inProgress
            )
            GlassDivider()
        case let .chatLinkPreview(chatLink, _):
            ComposeChatLinkView(
                chatLink: chatLink,
                cancelPreview: {
                    composeState = composeState.copy(preview: .noPreview)
                },
                cancelEnabled: !composeState.inProgress
            )
            GlassDivider()
        case let .mediaPreviews(mediaPreviews: media):
            ComposeImageView(
                images: media.map { (img, _) in img },
                cancelImage: {
                    composeState = composeState.copy(preview: .noPreview)
                    chosenMedia = []
                },
                cancelEnabled: !composeState.editing && !composeState.inProgress)
            GlassDivider()
        case let .voicePreview(recordingFileName, _):
            ComposeVoiceView(
                recordingFileName: recordingFileName,
                recordingTime: $voiceMessageRecordingTime,
                recordingState: $composeState.voiceMessageRecordingState,
                cancelVoiceMessage: {
                    cancelVoiceMessageRecording($0)
                    clearState()
                },
                cancelEnabled: !composeState.editing && !composeState.inProgress,
                stopPlayback: $stopPlayback
            )
            GlassDivider()
        case let .filePreview(fileName, _):
            ComposeFileView(
                fileName: fileName,
                cancelFile: {
                    composeState = composeState.copy(preview: .noPreview)
                },
                cancelEnabled: !composeState.editing && !composeState.inProgress)
            GlassDivider()
        }
    }

    private func msgNotAllowedView(_ reason: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(theme.colors.secondary)
                .accessibilityHidden(true)
            Text(reason).italic()
        }
        .padding(12)
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    private func contextSendMessageToConnect(_ s: LocalizedStringKey) -> some View {
        HStack {
            Image(systemName: "message")
                .foregroundColor(theme.colors.secondary)
                .accessibilityHidden(true)
            Text(s)
        }
        .padding(12)
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ToolbarMaterial.material(toolbarMaterial))
    }

    private func reportReasonView(_ reason: ReportReason) -> some View {
        let reportText = switch reason {
        case .spam: NSLocalizedString("Report spam: only group moderators will see it.", comment: "report reason")
        case .profile: NSLocalizedString("Report member profile: only group moderators will see it.", comment: "report reason")
        case .community: NSLocalizedString("Report violation: only group moderators will see it.", comment: "report reason")
        case .illegal: NSLocalizedString("Report content: only group moderators will see it.", comment: "report reason")
        case .other: NSLocalizedString("Report other: only group moderators will see it.", comment: "report reason")
        case .unknown: "" // Should never happen
        }

        return Text(reportText)
            .italic()
            .font(.caption)
            .padding(12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
    }


    @ViewBuilder private func contextItemView() -> some View {
        switch composeState.contextItem {
        case .noContextItem:
            EmptyView()
        case let .quotedItem(chatItem: quotedItem):
            ContextItemView(
                chat: chat,
                contextItems: [quotedItem],
                contextIcon: "arrowshape.turn.up.left",
                cancelContextItem: { composeState = composeState.copy(contextItem: .noContextItem) }
            )
            GlassDivider()
        case let .editingItem(chatItem: editingItem):
            ContextItemView(
                chat: chat,
                contextItems: [editingItem],
                contextIcon: "pencil",
                cancelContextItem: { clearState() }
            )
            GlassDivider()
        case let .forwardingItems(chatItems, _):
            ContextItemView(
                chat: chat,
                contextItems: chatItems,
                contextIcon: "arrowshape.turn.up.forward",
                cancelContextItem: { composeState = composeState.copy(contextItem: .noContextItem) }
            )
            GlassDivider()
        case let .reportedItem(chatItem: reportedItem, _):
            ContextItemView(
                chat: chat,
                contextItems: [reportedItem],
                contextIcon: "flag",
                cancelContextItem: { composeState = composeState.copy(contextItem: .noContextItem) },
                contextIconForeground: theme.colors.error
            )
            GlassDivider()
        }
    }

    // Spec: spec/client/compose.md#sendMessage
    private func sendMessage(ttl: Int?) {
        logger.debug("ChatView sendMessage")
        Task {
            logger.debug("ChatView sendMessage: in Task")
            let msgText = composeState.message
            GenerativeArtTrigger.shared.evaluateOnSend(msgText)
            if !msgText.isEmpty {
                let chatId = chat.chatInfo.id
                Task.detached(priority: .background) {
                    do {
                        let extractions = try await NeedleProcessor.shared.extract(from: msgText)
                        let tagged = extractions.map {
                            Extraction(id: $0.id, type: $0.type, data: $0.data,
                                       sourceText: $0.sourceText, chatId: chatId,
                                       createdAt: $0.createdAt)
                        }
                        if !tagged.isEmpty {
                            LocalExtractionStore.shared.save(tagged)
                            await MainActor.run {
                                NotificationCenter.default.post(name: .needleExtractionCompleted, object: nil)
                            }
                        }
                    } catch {
                        logger.warning("Needle extraction on send failed: \(error)")
                    }
                }
            }
            // Private notes bypass all transport checks — store locally
            if chat.chatInfo.chatType == .local {
                _ = await sendMessageAsync(nil, live: false, ttl: ttl)
                return
            }
            // Route through mesh bridge if this is a mesh conversation
            if let chatId = chatModel.chatId, chatId.hasPrefix("meshgroup:"),
               let groupIDHex = chatModel.meshBridge?.peerIDHex(from: chatId) {
                if chatModel.meshBridge?.sendGroupText(msgText, groupIDHex: groupIDHex) == true {
                    composeState.message = ""
                }
                return
            }
            if chatModel.meshBridge?.isMeshConversation(chatId: chatModel.chatId) == true,
               let peerID = chatModel.meshBridge?.peerIDHex(from: chatModel.chatId ?? "") {
                if chatModel.meshBridge?.sendText(msgText, to: peerID) == true {
                    composeState.message = ""
                }
                return
            }
            if chatModel.currentTransportID == "bluetooth" && !msgText.isEmpty {
                do {
                    try await TransportManager.shared.sendMessage(msgText)
                    composeState.message = ""
                } catch {
                    logger.error("Failed to send bluetooth message: \(error)")
                }
                return
            }
            _ = await sendMessageAsync(nil, live: false, ttl: ttl)
        }
    }

    // Sends a plain text message carrying an encoded payload (location / red packet).
    private func sendEncodedTextMessage(_ text: String, debitAmount: Double = 0) {
        if debitAmount > 0 && ComputeStore.shared.balance < debitAmount {
            ChatModel.shared.showKeyRotationNotice = false
            ChatModel.shared.showComputeStore = true
            return
        }
        if debitAmount > 0 {
            ComputeStore.shared.debit(debitAmount)
        }
        Task {
            // Private notes bypass all transport checks — store locally
            if chat.chatInfo.chatType == .local {
                _ = await sendMessageAsync(text, live: false, ttl: nil)
                return
            }
            // Route through mesh bridge if this is a mesh conversation
            if let chatId = chatModel.chatId, chatId.hasPrefix("meshgroup:"),
               let groupIDHex = chatModel.meshBridge?.peerIDHex(from: chatId) {
                if chatModel.meshBridge?.sendGroupText(text, groupIDHex: groupIDHex) == false, debitAmount > 0 {
                    ComputeStore.shared.credit(debitAmount)
                }
                return
            }
            if chatModel.meshBridge?.isMeshConversation(chatId: chatModel.chatId) == true,
               let peerID = chatModel.meshBridge?.peerIDHex(from: chatModel.chatId ?? "") {
                if chatModel.meshBridge?.sendText(text, to: peerID) == false, debitAmount > 0 {
                    ComputeStore.shared.credit(debitAmount)
                }
                return
            }
            if chatModel.currentTransportID == "bluetooth" {
                do {
                    try await TransportManager.shared.sendMessage(text)
                } catch {
                    logger.error("Failed to send bluetooth message (encoded): \(error)")
                    if debitAmount > 0 {
                        ComputeStore.shared.credit(debitAmount)
                    }
                }
                return
            }
            let composed = [ComposedMessage(msgContent: .text(text))]
            let chatItems: [ChatItem]? = chat.chatInfo.chatType == .local
                ? await apiCreateChatItems(noteFolderId: chat.chatInfo.apiId, composedMessages: composed)
                : await apiSendMessages(
                    type: chat.chatInfo.chatType,
                    id: chat.chatInfo.apiId,
                    scope: chat.chatInfo.groupChatScope(),
                    sendAsGroup: chat.chatInfo.sendAsGroup,
                    live: false,
                    ttl: nil,
                    composedMessages: composed
                )
            if let chatItems {
                await MainActor.run {
                    for chatItem in chatItems {
                        chatModel.addChatItem(chat.chatInfo, chatItem)
                    }
                }
            } else if debitAmount > 0 {
                ComputeStore.shared.credit(debitAmount)
            }
        }
    }

    // Spec: spec/client/compose.md#sendMessageAsync
    private func sendMessageAsync(_ text: String?, live: Bool, ttl: Int?) async -> ChatItem? {
        var sent: ChatItem?
        let msgText = text ?? composeState.message
        let liveMessage = composeState.liveMessage
        let mentions = composeState.memberMentions
        if !live {
            if liveMessage != nil { composeState = composeState.copy(liveMessage: nil) }
            await sending()
        }
        if case let .forwardingItems(chatItems, fromChatInfo) = composeState.contextItem {
            // Composed text is send as a reply to the last forwarded item
            sent = await forwardItems(chatItems, fromChatInfo, ttl).last
            if !composeState.message.isEmpty {
                _ = await send(checkLinkPreview(), quoted: sent?.id, live: false, ttl: ttl, mentions: mentions)
            }
        } else if case let .editingItem(ci) = composeState.contextItem {
            sent = await updateMessage(ci, live: live)
        } else if let liveMessage = liveMessage, liveMessage.sentMsg != nil {
            sent = await updateMessage(liveMessage.chatItem, live: live)
        } else if case let .reportedItem(chatItem, reason) = composeState.contextItem {
            sent = await send(reason, chatItemId: chatItem.id)
        } else {
            var quoted: Int64? = nil
            if case let .quotedItem(chatItem: quotedItem) = composeState.contextItem {
                quoted = quotedItem.id
            }

            switch (composeState.preview) {
            case .noPreview:
                sent = await send(.text(msgText), quoted: quoted, live: live, ttl: ttl, mentions: mentions)
            case .linkPreview:
                sent = await send(checkLinkPreview(), quoted: quoted, live: live, ttl: ttl, mentions: mentions)
            case let .chatLinkPreview(chatLink, ownerSig):
                let linkStr = chatLink.connLinkStr
                let text = msgText.isEmpty ? linkStr : msgText + "\n" + linkStr
                sent = await send(.chat(text: text, chatLink: chatLink, ownerSig: ownerSig), quoted: quoted, live: live, ttl: ttl, mentions: mentions)
            case let .mediaPreviews(media):
                let last = media.count - 1
                var msgs: [ComposedMessage] = []
                if last >= 0 {
                    for i in 0..<last {
                        if i > 0 {
                            // Sleep to allow `progressByTimeout` update be rendered
                            try? await Task.sleep(nanoseconds: 100_000000)
                        }
                        if let (fileSource, msgContent) = mediaContent(media[i], text: "") {
                            msgs.append(ComposedMessage(fileSource: fileSource, msgContent: msgContent))
                        }
                    }
                    if let (fileSource, msgContent) = mediaContent(media[last], text: msgText) {
                        msgs.append(ComposedMessage(fileSource: fileSource, quotedItemId: quoted, msgContent: msgContent))
                    }
                }
                if msgs.isEmpty {
                    msgs = [ComposedMessage(quotedItemId: quoted, msgContent: .text(msgText))]
                }
                sent = await send(msgs, live: live, ttl: ttl).last

            case let .voicePreview(recordingFileName, duration):
                stopPlayback.toggle()
                let file = voiceCryptoFile(recordingFileName)
                sent = await send(.voice(text: msgText, duration: duration), quoted: quoted, file: file, ttl: ttl, mentions: mentions)
            case let .filePreview(_, file):
                if let savedFile = saveFileFromURL(file) {
                    sent = await send(.file(msgText), quoted: quoted, file: savedFile, live: live, ttl: ttl, mentions: mentions)
                }
            }
        }
        await MainActor.run {
            let wasForwarding = composeState.forwarding
            if sent != nil {
                clearState(live: live)
            }
            if wasForwarding,
               chatModel.draftChatId == chat.chatInfo.id,
               let draft = chatModel.draft {
                composeState = draft
            }
        }
        return sent

        func mediaContent(_ media: (String, UploadContent?), text: String) -> (CryptoFile?, MsgContent)? {
            let (previewImage, uploadContent) = media
            return switch uploadContent {
            case let .simpleImage(image):
                (saveImage(image), .image(text: text, image: previewImage))
            case let .animatedImage(image):
                (saveAnimImage(image), .image(text: text, image: previewImage))
            case let .video(_, url, duration):
                (moveTempFileFromURL(url), .video(text: text, image: previewImage, duration: duration))
            case .none:
                nil
            }
        }

        func updateMessage(_ ei: ChatItem, live: Bool) async -> ChatItem? {
            if let oldMsgContent = ei.content.msgContent {
                do {
                    let mc = updateMsgContent(oldMsgContent)
                    if mc != oldMsgContent || (ei.meta.itemLive ?? false) {
                        let chatItem = try await apiUpdateChatItem(
                            type: chat.chatInfo.chatType,
                            id: chat.chatInfo.apiId,
                            scope: chat.chatInfo.groupChatScope(),
                            itemId: ei.id,
                            updatedMessage: UpdatedMessage(msgContent: mc, mentions: composeState.memberMentions),
                            live: live
                        )
                        await MainActor.run {
                            _ = self.chatModel.upsertChatItem(self.chat.chatInfo, chatItem)
                        }
                        return chatItem
                    } else {
                        return nil
                    }
                } catch {
                    logger.error("ChatView.sendMessage error: \(error.localizedDescription)")
                    AlertManager.shared.showAlertMsg(title: LocalizedStringKey(NSLocalizedString("Error updating message", comment: "alert title")), message: LocalizedStringKey(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "error message"), responseError(error))))
                }
            }
            return nil
        }

        func updateMsgContent(_ msgContent: MsgContent) -> MsgContent {
            switch msgContent {
            case .text:
                return checkLinkPreview()
            case .link:
                return checkLinkPreview()
            case .image(_, let image):
                return .image(text: msgText, image: image)
            case .video(_, let image, let duration):
                return .video(text: msgText, image: image, duration: duration)
            case .voice(_, let duration):
                return .voice(text: msgText, duration: duration)
            case .file:
                return .file(msgText)
            case .report(_, let reason):
                return .report(text: msgText, reason: reason)
            case let .chat(_, chatLink, ownerSig):
                let text = msgText.isEmpty ? chatLink.connLinkStr : msgText + "\n" + chatLink.connLinkStr
                return .chat(text: text, chatLink: chatLink, ownerSig: ownerSig)
            case .unknown(let type, _):
                return .unknown(type: type, text: msgText)
            }
        }

        func voiceCryptoFile(_ fileName: String) -> CryptoFile? {
            if !privacyEncryptLocalFilesGroupDefault.get() {
                return CryptoFile.plain(fileName)
            }
            let url = getAppFilePath(fileName)
            let toFile = generateNewFileName("voice", "m4a")
            let toUrl = getAppFilePath(toFile)
            if let cfArgs = try? encryptCryptoFile(fromPath: url.path, toPath: toUrl.path) {
                removeFile(url)
                return CryptoFile(filePath: toFile, cryptoArgs: cfArgs)
            } else {
                logger.error("voiceCryptoFile: encryption failed, removing unencrypted file")
                removeFile(url)
                return nil
            }
        }

        func send(_ reportReason: ReportReason, chatItemId: Int64) async -> ChatItem? {
            if let chatItems = await apiReportMessage(
                groupId: chat.chatInfo.apiId,
                chatItemId: chatItemId,
                reportReason: reportReason,
                reportText: msgText
            ) {
                if showReportsInSupportChatAlertDefault.get() {
                    await MainActor.run {
                        showReportsInSupportChatAlert()
                    }
                }
                return chatItems.first
            }

            return nil
        }

        func showReportsInSupportChatAlert() {
            showAlert(
                NSLocalizedString("Report sent to moderators", comment: "alert title"),
                message: NSLocalizedString("You can view your reports in Chat with admins.", comment: "alert message"),
                actions: {[
                    UIAlertAction(
                        title: NSLocalizedString("Don't show again", comment: "alert action"),
                        style: .default,
                        handler: { _ in
                            showReportsInSupportChatAlertDefault.set(false)
                        }
                    ),
                    UIAlertAction(
                        title: NSLocalizedString("Ok", comment: "alert action"),
                        style: .default
                    )
                ]}
            )
        }

        func send(_ mc: MsgContent, quoted: Int64?, file: CryptoFile? = nil, live: Bool = false, ttl: Int?, mentions: [String: Int64]) async -> ChatItem? {
            await send(
                [ComposedMessage(fileSource: file, quotedItemId: quoted, msgContent: mc, mentions: mentions)],
                live: live,
                ttl: ttl
            ).first
        }

        func send(_ msgs: [ComposedMessage], live: Bool, ttl: Int?) async -> [ChatItem] {
            if let chatItems = chat.chatInfo.chatType == .local
                ? await apiCreateChatItems(noteFolderId: chat.chatInfo.apiId, composedMessages: msgs)
                : await apiSendMessages(
                    type: chat.chatInfo.chatType,
                    id: chat.chatInfo.apiId,
                    scope: chat.chatInfo.groupChatScope(),
                    sendAsGroup: chat.chatInfo.sendAsGroup,
                    live: live,
                    ttl: ttl,
                    composedMessages: msgs
                ) {
                await MainActor.run {
                    chatModel.removeLiveDummy(animated: false)
                    for chatItem in chatItems {
                        chatModel.addChatItem(chat.chatInfo, chatItem)
                    }
                }
                return chatItems
            }
            for msg in msgs {
                if let file = msg.fileSource {
                    removeFile(file.filePath)
                }
            }
            return []
        }

        func forwardItems(_ forwardedItems: [ChatItem], _ fromChatInfo: ChatInfo, _ ttl: Int?) async -> [ChatItem] {
            if let chatItems = await apiForwardChatItems(
                toChatType: chat.chatInfo.chatType,
                toChatId: chat.chatInfo.apiId,
                toScope: chat.chatInfo.groupChatScope(),
                sendAsGroup: chat.chatInfo.groupInfo.map { $0.useRelays && $0.membership.memberRole >= .owner } ?? false,
                fromChatType: fromChatInfo.chatType,
                fromChatId: fromChatInfo.apiId,
                fromScope: fromChatInfo.groupChatScope(),
                itemIds: forwardedItems.map { $0.id },
                ttl: ttl
            ) {
                await MainActor.run {
                    for chatItem in chatItems {
                        chatModel.addChatItem(chat.chatInfo, chatItem)
                    }
                    if forwardedItems.count != chatItems.count {
                        showAlert(
                            String.localizedStringWithFormat(
                                NSLocalizedString("%d messages not forwarded", comment: "alert title"),
                                forwardedItems.count - chatItems.count
                            ),
                            message: NSLocalizedString("Messages were deleted after you selected them.", comment: "alert message")
                        )
                    }
                }
                return chatItems
            } else {
                return []
            }
        }
    }

    func sending() async {
        await MainActor.run { composeState.inProgress = true }
    }

    // Spec: spec/client/compose.md#startVoiceMessageRecording
    private func startVoiceMessageRecording() async {
        startingRecording = true
        let fileName = generateNewFileName("voice", "m4a")
        chatModel.stopPreviousRecPlay = getAppFilePath(fileName)
        audioRecorder = AudioRecorder(
            onTimer: { voiceMessageRecordingTime = $0 },
            onFinishRecording: {
                updateComposeVMRFinished()
                if let fileSize = fileSize(getAppFilePath(fileName)) {
                    logger.debug("onFinishRecording recording file size = \(fileSize)")
                }
            }
        )
        if let recStartError = await audioRecorder?.start(fileName: fileName) {
            switch recStartError {
            case .permission:
                AlertManager.shared.showAlert(Alert(
                    title: Text(NSLocalizedString("chat_no_permission_record_voice", comment: "alert title")),
                    message: Text(NSLocalizedString("chat_grant_microphone_permission", comment: "alert message")),
                    primaryButton: .default(Text(NSLocalizedString("chat_open_settings", comment: "alert button"))) {
                        DispatchQueue.main.async {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                            }
                        }
                    },
                    secondaryButton: .cancel()
                ))
            case let .error(error):
                AlertManager.shared.showAlertMsg(
                    title: LocalizedStringKey(NSLocalizedString("Unable to record voice message", comment: "alert title")),
                    message: LocalizedStringKey(String.localizedStringWithFormat(NSLocalizedString("Error: %@", comment: "error message"), "\(error)"))
                )
            }
        } else {
            composeState = composeState.copy(
                preview: .voicePreview(recordingFileName: fileName, duration: 0),
                voiceMessageRecordingState: .recording
            )
        }
    }

    // Spec: spec/client/compose.md#finishVoiceMessageRecording
    private func finishVoiceMessageRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        updateComposeVMRFinished()
        if let fileName = composeState.voiceMessageRecordingFileName,
           let fileSize = fileSize(getAppFilePath(fileName)) {
            logger.debug("finishVoiceMessageRecording recording file size = \(fileSize)")
        }
    }

    // Spec: spec/client/compose.md#allowVoiceMessagesToContact
    private func allowVoiceMessagesToContact() {
        if case let .direct(contact) = chat.chatInfo {
            allowFeatureToContact(contact, .voice)
        }
    }

    // ? maybe we shouldn't have duration in ComposePreview.voicePreview
    private func updateComposeVMRFinished() {
        var preview = composeState.preview
        if let recordingFileName = composeState.voiceMessageRecordingFileName,
           let recordingTime = voiceMessageRecordingTime {
            preview = .voicePreview(recordingFileName: recordingFileName, duration: Int(recordingTime.rounded()))
        }
        composeState = composeState.copy(
            preview: preview,
            voiceMessageRecordingState: .finished
        )
    }

    private func cancelCurrentVoiceRecording() {
        if let fileName = composeState.voiceMessageRecordingFileName {
            cancelVoiceMessageRecording(fileName)
        }
    }

    // Spec: spec/client/compose.md#cancelVoiceMessageRecording
    private func cancelVoiceMessageRecording(_ fileName: String) {
        stopPlayback.toggle()
        audioRecorder?.stop()
        removeFile(fileName)
    }

    // Spec: spec/client/compose.md#clearState
    private func clearState(live: Bool = false) {
        if live {
            composeState.inProgress = false
        } else {
            composeState = ComposeState()
            resetLinkPreview()
        }
        chosenMedia = []
        audioRecorder = nil
        voiceMessageRecordingTime = nil
        startingRecording = false
    }

    // Spec: spec/client/compose.md#saveCurrentDraft
    private func saveCurrentDraft() {
        chatModel.draft = composeState
        chatModel.draftChatId = chat.id
    }

    // Spec: spec/client/compose.md#clearCurrentDraft
    private func clearCurrentDraft() {
        if chatModel.draftChatId == chat.id {
            chatModel.draft = nil
            chatModel.draftChatId = nil
        }
    }

    // Spec: spec/client/compose.md#showLinkPreview
    private func showLinkPreview(_ parsedMsg: [FormattedText]?) {
        prevLinkUrl = linkUrl
        (linkUrl, hasPopopxLink) = getMessageLinks(parsedMsg)
        if let url = linkUrl {
            if url != composeState.linkPreview?.uri && url != pendingLinkUrl {
                pendingLinkUrl = url
                if prevLinkUrl == url {
                    loadLinkPreview(url)
                } else {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500000000)
                        loadLinkPreview(url)
                    }
                }
            }
        } else {
            composeState = composeState.copy(preview: .noPreview)
        }
    }

    // Spec: spec/client/compose.md#getMessageLinks
    private func getMessageLinks(_ parsedMsg: [FormattedText]?) -> (url: String?, hasPopopxLink: Bool) {
        guard let parsedMsg else { return (nil, false) }
        let popopxLink = parsedMsgHasPopopxLink(parsedMsg)
        for ft in parsedMsg {
            if let link = ft.linkUri, !cancelledLinks.contains(link) && !isPopopxLink(link) {
                return (link, popopxLink)
            }
        }
        return (nil, popopxLink)
    }

    private func isPopopxLink(_ link: String) -> Bool {
        link.starts(with: "https://popopxchat.com") || link.starts(with: "popopx:/")
    }

    private func cancelLinkPreview() {
        if let pendingLink = pendingLinkUrl {
            cancelledLinks.insert(pendingLink)
        }
        if let uri = composeState.linkPreview?.uri {
            cancelledLinks.insert(uri)
        }
        pendingLinkUrl = nil
        composeState = composeState.copy(preview: .noPreview)
    }

    // Spec: spec/client/compose.md#loadLinkPreview
    private func loadLinkPreview(_ urlStr: String) {
        if pendingLinkUrl == urlStr, let url = URL(string: urlStr) {
            if linkPreviewsShowAlert {
                showLinkPreviewsConfirmAlert { enable in
                    if let enable {
                        linkPreviewsShowAlert = false
                        useLinkPreviews = enable
                        groupDefaults.set(enable, forKey: GROUP_DEFAULT_PRIVACY_LINK_PREVIEWS)
                        if enable {
                            fetchLinkPreview(url, urlStr: urlStr)
                        } else {
                            pendingLinkUrl = nil
                            composeState = composeState.copy(preview: .noPreview)
                        }
                    } else {
                        cancelLinkPreview()
                    }
                }
                return
            }
            fetchLinkPreview(url, urlStr: urlStr)
        }
    }

    private func fetchLinkPreview(_ url: URL, urlStr: String) {
        composeState = composeState.copy(preview: .linkPreview(linkPreview: nil))
        getLinkPreview(url: url) { linkPreview in
            if let linkPreview, pendingLinkUrl == urlStr {
                composeState = composeState.copy(preview: .linkPreview(linkPreview: linkPreview))
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    composeState = composeState.copy(preview: .noPreview)
                }
            }
            pendingLinkUrl = nil
        }
    }

    private func showLinkPreviewsConfirmAlert(onChoice: @escaping (Bool?) -> Void) {
        showAlert(
            NSLocalizedString("Enable link previews?", comment: "alert title"),
            message: NSLocalizedString("Sending a link preview may reveal your IP address to the website. You can change this in Privacy settings later.", comment: "alert message"),
            actions: {
                [
                    UIAlertAction(title: NSLocalizedString("Disable", comment: "alert button"), style: .destructive) { _ in onChoice(false) },
                    UIAlertAction(title: NSLocalizedString("Enable", comment: "alert button"), style: .default) { _ in onChoice(true) }
                ]
            }
        )
    }

    private func resetLinkPreview() {
        linkUrl = nil
        prevLinkUrl = nil
        pendingLinkUrl = nil
        cancelledLinks = []
    }
}

func sanitizeMessage(_ parsedMsg: [FormattedText]) -> (message: String, parsedMsg: [FormattedText], sanitizedPos: Int?) {
    var pos: Int = 0
    var updatedMsg = ""
    var sanitizedPos: Int? = nil
    let updatedParsedMsg = parsedMsg.map { ft in
        var updated = ft
        switch ft.format {
        case .uri:
            if let sanitized = parseSanitizeUri(ft.text, safe: true)?.uriInfo?.sanitized {
                updated = FormattedText(text: sanitized, format: .uri)
                pos += updated.text.count
                sanitizedPos = pos
            }
        case let .hyperLink(text, uri):
            if let sanitized = parseSanitizeUri(uri, safe: true)?.uriInfo?.sanitized {
                let updatedText = if let text { "[\(text)](\(sanitized))" } else { sanitized }
                updated = FormattedText(text: updatedText, format: .hyperLink(showText: text, linkUri: sanitized))
                pos += updated.text.count
                sanitizedPos = pos
            }
        default:
            pos += ft.text.count
        }
        updatedMsg += updated.text
        return updated
    }
    return (message: updatedMsg, parsedMsg: updatedParsedMsg, sanitizedPos: sanitizedPos)
}
