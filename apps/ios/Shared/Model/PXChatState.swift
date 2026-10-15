//
//  ChatModel.swift
//  POPOPX
//
//  Created by Evgeny Poberezkin on 22/01/2022.
//  Copyright © 2025 POPOPX. All rights reserved.
//
// Spec: spec/state.md
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

import Foundation
import BitchatMesh
import Combine
import SwiftUI
import POPOPXSwitch

actor TerminalItems {
    private var terminalItems: [TerminalItem] = []

    static let shared = TerminalItems()

    func items() -> [TerminalItem] {
        terminalItems
    }

    func add(_ item: TerminalItem) async {
        addTermItem(&terminalItems, item)
        let showingTerminal = await MainActor.run { ChatModel.shared.showingTerminal }
        if showingTerminal {
            await MainActor.run {
                addTermItem(&ChatModel.shared.terminalItems, item)
            }
        }
    }

    func addCommand<R: ChatAPIResult>(_ start: Date, _ cmd: ChatCommand, _ res: APIResult<R>) async {
        await add(.cmd(start, cmd))
        await addResult(res)
    }

    func addResult<R: ChatAPIResult>(_ res: APIResult<R>) async {
        let item: TerminalItem = switch res {
        case let .result(r, _): .res(.now, r)
        case let .error(e, _): .err(.now, e)
        case let .invalid(type, json): .bad(.now, type, json)
        }
        await add(item)
    }
}

private func addTermItem(_ items: inout [TerminalItem], _ item: TerminalItem) {
    if items.count >= 200 {
        items.removeFirst()
    }
    items.append(item)
}

// analogue for SecondaryContextFilter in Kotlin
// Spec: spec/state.md#SecondaryItemsModelFilter
enum SecondaryItemsModelFilter {
    case groupChatScopeContext(groupScopeInfo: GroupChatScopeInfo)
    case msgContentTagContext(contentTag: MsgContentTag)

    func descr() -> String {
        switch self {
        case let .groupChatScopeContext(groupScopeInfo):
            return "groupChatScopeContext \(groupScopeInfo.toChatScope())"
        case let .msgContentTagContext(contentTag):
            return "msgContentTagContext \(contentTag.rawValue)"
        }
    }
}

// analogue for ChatsContext in Kotlin
// Spec: spec/state.md#ItemsModel
@MainActor
class ItemsModel: ObservableObject {
    static let shared = ItemsModel(secondaryIMFilter: nil)
    public var secondaryIMFilter: SecondaryItemsModelFilter?
    public var preloadState = PreloadState()
    private let publisher = ObservableObjectPublisher()
    private var bag = Set<AnyCancellable>()
    var reversedChatItems: [ChatItem] = [] {
        willSet { publisher.send() }
    }
    var itemAdded = false {
        willSet { publisher.send() }
    }

    let chatState = ActiveChatState()

    // Publishes directly to `objectWillChange` publisher,
    // this will cause reversedChatItems to be rendered without throttling
    @Published var isLoading = false
    @Published var showLoadingProgress: ChatId? = nil

    private var navigationTimeoutTask: Task<Void, Never>? = nil
    private var loadChatTask: Task<Void, Never>? = nil
    private var currentLoadTaskId: UUID? = nil

    var lastItemsLoaded: Bool {
        chatState.splits.isEmpty || chatState.splits.first != reversedChatItems.first?.id
    }

    init(secondaryIMFilter: SecondaryItemsModelFilter? = nil) {
        self.secondaryIMFilter = secondaryIMFilter
        publisher
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &bag)
        chatState.objectWillChange
            .sink { [weak self] _ in self?.publisher.send() }
            .store(in: &bag)
    }

    // Spec: spec/state.md#loadSecondaryChat
    static func loadSecondaryChat(_ chatId: ChatId, chatFilter: SecondaryItemsModelFilter, willNavigate: @escaping () -> Void = {}) {
        let im = ItemsModel(secondaryIMFilter: chatFilter)
        ChatModel.shared.secondaryIM = im
        im.loadOpenChat(chatId, willNavigate: willNavigate)
    }

    // Spec: spec/state.md#loadOpenChat
    func loadOpenChat(_ chatId: ChatId, willNavigate: @escaping () -> Void = {}) {
        navigationTimeoutTask?.cancel()
        loadChatTask?.cancel()
        let taskId = UUID()
        currentLoadTaskId = taskId
        navigationTimeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: 250_000000)
                await MainActor.run {
                    ChatModel.shared.chatId = chatId
                    willNavigate()
                }
            } catch is CancellationError {
                // POPOPX: expected when loadOpenChat is called again before timeout completes
            } catch {
                logger.error("ChatModel: navigation task failed: \(error)")
            }
        }
        loadChatTask = Task {
            await MainActor.run { self.isLoading = true }
            await loadChat(chatId: chatId, im: self)
            guard currentLoadTaskId == taskId, !Task.isCancelled else { return }
            await MainActor.run {
                self.isLoading = false
                self.showLoadingProgress = nil
            }
        }
    }

    // Spec: spec/state.md#loadOpenChatNoWait
    func loadOpenChatNoWait(_ chatId: ChatId, _ openAroundItemId: ChatItem.ID? = nil) {
        navigationTimeoutTask?.cancel()
        loadChatTask?.cancel()
        ChatModel.shared.chatId = chatId
        if openAroundItemId == nil {
            reversedChatItems = []
        }
        loadChatTask = Task {
            await loadChat(chatId: chatId, im: self, openAroundItemId: openAroundItemId, clearItems: openAroundItemId == nil)
        }
    }

    public var contentTag: MsgContentTag? {
        switch secondaryIMFilter {
        case nil: nil
        case .groupChatScopeContext: nil
        case let .msgContentTagContext(contentTag): contentTag
        }
    }

    public var groupScopeInfo: GroupChatScopeInfo? {
        switch secondaryIMFilter {
        case nil: nil
        case let .groupChatScopeContext(scopeInfo): scopeInfo
        case .msgContentTagContext: nil
        }
    }

    func reset() {
        navigationTimeoutTask?.cancel()
        loadChatTask?.cancel()
        navigationTimeoutTask = nil
        loadChatTask = nil
        currentLoadTaskId = nil
        reversedChatItems = []
        itemAdded = false
        isLoading = false
        showLoadingProgress = nil
        secondaryIMFilter = nil
        chatState.reset()
        preloadState.clear()
    }
}

class PreloadState {
    var prevFirstVisible: Int64 = Int64.min
    var prevItemsCount: Int = 0
    var preloading: Bool = false

    func clear() {
        prevFirstVisible = Int64.min
        prevItemsCount = 0
        preloading = false
    }
}

// Spec: spec/state.md#ChatTagsModel
@MainActor
class ChatTagsModel: ObservableObject {
    static let shared = ChatTagsModel()

    @Published var userTags: [ChatTag] = []
    @Published var activeFilter: ActiveFilter? = nil
    @Published var presetTags: [PresetTag:Int] = [:]
    @Published var unreadTags: [Int64:Int] = [:]

    func updateChatTags(_ chats: [Chat]) {
        var newPresetTags: [PresetTag:Int] = [:]
        var newUnreadTags: [Int64:Int] = [:]
        for chat in chats {
            for tag in PresetTag.allCases {
                if presetTagMatchesChat(tag, chat.chatInfo, chat.chatStats) {
                    newPresetTags[tag] = (newPresetTags[tag] ?? 0) + 1
                }
            }
            if chat.unreadTag, let tags = chat.chatInfo.chatTags {
                for tag in tags {
                    newUnreadTags[tag, default: 0] += 1
                }
            }
        }
        if presetTags != newPresetTags { presetTags = newPresetTags }
        if unreadTags != newUnreadTags { unreadTags = newUnreadTags }
        clearActiveChatFilterIfNeeded()
    }

    func updateChatFavorite(favorite: Bool, wasFavorite: Bool) {
        let count = presetTags[.favorites]
        if favorite && !wasFavorite {
            presetTags[.favorites] = (count ?? 0) + 1
        } else if !favorite && wasFavorite, let count {
            presetTags[.favorites] = max(0, count - 1)
            clearActiveChatFilterIfNeeded()
        }
    }

    func addPresetChatTags(_ chatInfo: ChatInfo, _ chatStats: ChatStats) {
        for tag in PresetTag.allCases {
            if presetTagMatchesChat(tag, chatInfo, chatStats) {
                presetTags[tag] = (presetTags[tag] ?? 0) + 1
            }
        }
    }

    func removePresetChatTags(_ chatInfo: ChatInfo, _ chatStats: ChatStats) {
        for tag in PresetTag.allCases {
            if presetTagMatchesChat(tag, chatInfo, chatStats) {
                if let count = presetTags[tag] {
                    if count > 1 {
                        presetTags[tag] = count - 1
                    } else {
                        presetTags.removeValue(forKey: tag)
                    }
                }
            }
        }
        clearActiveChatFilterIfNeeded()
    }

    func markChatTagRead(_ chat: Chat) -> Void {
        if chat.unreadTag, let tags = chat.chatInfo.chatTags {
            decTagsReadCount(tags)
        }
    }

    func updateChatTagRead(_ chat: Chat, wasUnread: Bool) -> Void {
        guard let tags = chat.chatInfo.chatTags else { return }
        let nowUnread = chat.unreadTag
        if nowUnread && !wasUnread {
            for tag in tags {
                unreadTags[tag] = (unreadTags[tag] ?? 0) + 1
            }
        } else if !nowUnread && wasUnread {
            decTagsReadCount(tags)
        }
    }

    func decTagsReadCount(_ tags: [Int64]) -> Void {
        for tag in tags {
            if let count = unreadTags[tag] {
                unreadTags[tag] = max(0, count - 1)
            }
        }
    }

    func changeGroupReportsTag(_ by: Int = 0) {
        if by == 0 { return }
        presetTags[.groupReports] = max(0, (presetTags[.groupReports] ?? 0) + by)
        clearActiveChatFilterIfNeeded()
    }

    func clearActiveChatFilterIfNeeded() {
        let clear = switch activeFilter {
        case let .presetTag(tag): (presetTags[tag] ?? 0) == 0
        case let .userTag(tag): !userTags.contains(tag)
        case .unread, nil: false
        }
        if clear { activeFilter = nil }
    }

    func reset() {
        userTags = []
        activeFilter = nil
        presetTags = [:]
        unreadTags = [:]
    }
}

/// ChatItemWithMenu can depend on previous or next item for it's appearance
/// This dummy model is used to force an update of all chat items,
/// when they might have changed appearance.
@MainActor
class ChatItemDummyModel: ObservableObject {
    static let shared = ChatItemDummyModel()
    func sendUpdate() { objectWillChange.send() }
}

@MainActor
class ConnectProgressManager: ObservableObject {
    @Published private var connectInProgress: String? = nil
    @Published private var connectProgressByTimeout: Bool = false
    private var onCancel: (() -> Void)?

    static let shared = ConnectProgressManager()

    func startConnectProgress(_ text: String, onCancel: (() -> Void)? = nil) {
        connectInProgress = text
        self.onCancel = onCancel
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                self?.connectProgressByTimeout = self?.connectInProgress != nil
            }
        }
    }

    func stopConnectProgress() {
        connectInProgress = nil
        onCancel = nil
        connectProgressByTimeout = false
    }

    func cancelConnectProgress() {
        onCancel?()
        stopConnectProgress()
    }

    var showConnectProgress: String? {
        connectProgressByTimeout ? connectInProgress : nil
    }

    var isInProgress: Bool {
        connectInProgress != nil
    }

    var connectInProgressText: String {
        connectInProgress ?? ""
    }
}

@MainActor
class ChannelRelaysModel: ObservableObject {
    static let shared = ChannelRelaysModel()
    @Published var groupId: Int64? = nil
    @Published var groupRelays: [GroupRelay] = []

    func set(groupId: Int64, groupRelays: [GroupRelay]) {
        self.groupId = groupId
        self.groupRelays = groupRelays
    }

    func updateRelay(_ groupInfo: GroupInfo, _ relay: GroupRelay) {
        if groupId == groupInfo.groupId {
            if let i = groupRelays.firstIndex(where: { $0.groupRelayId == relay.groupRelayId }) {
                groupRelays[i] = relay
            } else {
                groupRelays.append(relay)
            }
        }
    }

    func reset() {
        groupId = nil
        groupRelays = []
    }
}

// The badge of whichever profile it was last loaded for, kept current by the badgeChanged event so
// that a screen already open shows what the renewal worker did with no command behind it.
class BadgeModel: ObservableObject {
    static let shared = BadgeModel()
    @Published private(set) var userId: Int64?
    @Published private(set) var badgeState: BadgeState?
    @Published private(set) var alert: BadgeAlert?

    // alert follows the state: getUserBadgeState derives it on every read, so a badgeChanged is
    // never staler than the alert it carries - the invariant a new alert kind must keep
    func set(userId: Int64, badgeState: BadgeState?) {
        self.userId = userId
        self.badgeState = badgeState
        alert = badgeState?.alert
    }

    func setAlert(userId: Int64, alert: BadgeAlert) {
        if self.userId == userId {
            self.alert = alert
            badgeState?.alert = alert
        }
    }
}

enum ChatListBanner {
    case badgeExpired
    case badgeIssueFailed
    case badgePitch
    case getStake
}

// Spec: spec/state.md#ChatModel
@MainActor
final class ChatModel: ObservableObject {
    // Focused state objects (extracted from 81 @Published properties)
    let chatState = ChatState.shared
    let userState = UserState.shared
    let notificationState = NotificationState.shared
    let callState = CallManagerState.shared
    let appState = AppStateModel.shared

    private var stateCancellables = Set<AnyCancellable>()

    init() {
        // Load persisted onboarding stage directly without triggering setter validation
        // (currentUser not loaded yet at init time)
        let persisted = onboardingStageDefault.get()
        self._onboardingStage = persisted
        appState.onboardingStage = persisted
        chatState.objectWillChange.throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true).sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &stateCancellables)
        userState.objectWillChange.throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true).sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &stateCancellables)
        notificationState.objectWillChange.throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true).sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &stateCancellables)
        callState.objectWillChange.throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true).sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &stateCancellables)
        appState.objectWillChange.throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true).sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &stateCancellables)
    }

    // Backward-compatible computed properties - delegate to state objects
    // These will be removed in a follow-up refactoring once all call sites are updated

    // MARK: - Chat Properties (delegate to chatState)
    var chats: [Chat] { get { chatState.chats } set { chatState.chats = newValue } }
    var deletedChats: Set<String> { get { chatState.deletedChats } set { chatState.deletedChats = newValue } }
    var chatId: String? { get { chatState.chatId } set { chatState.chatId = newValue } }
    var chatAgentConnId: String? { get { chatState.chatAgentConnId } set { chatState.chatAgentConnId = newValue } }
    var chatSubStatus: SubscriptionStatus? { get { chatState.chatSubStatus } set { chatState.chatSubStatus = newValue } }
    var openAroundItemId: ChatItem.ID? { get { chatState.openAroundItemId } set { chatState.openAroundItemId = newValue } }
    var chatToTop: String? { get { chatState.chatToTop } set { chatState.chatToTop = newValue } }
    var creatingChannelId: String? { get { chatState.creatingChannelId } set { chatState.creatingChannelId = newValue } }
    var groupMembers: [GMember] { get { chatState.groupMembers } set { chatState.groupMembers = newValue } }
    var groupMembersIndexes: Dictionary<Int64, Int> { get { chatState.groupMembersIndexes } set { chatState.groupMembersIndexes = newValue } }
    var membersLoaded: Bool { get { chatState.membersLoaded } set { chatState.membersLoaded = newValue } }
    var channelRelayHostnames: [Int64: [String]] { get { chatState.channelRelayHostnames } set { chatState.channelRelayHostnames = newValue } }
    var chatItemTTL: ChatItemTTL { get { chatState.chatItemTTL } set { chatState.chatItemTTL = newValue } }
    var setDeliveryReceipts: Bool { get { chatState.setDeliveryReceipts } set { chatState.setDeliveryReceipts = newValue } }
    var secondaryIM: ItemsModel? { get { chatState.secondaryIM } set { chatState.secondaryIM = newValue } }
    var secondaryPendingInviteeChatOpened: Bool { get { chatState.secondaryPendingInviteeChatOpened } set { chatState.secondaryPendingInviteeChatOpened = newValue } }

    // MARK: - User Properties (delegate to userState)
    var currentUser: User? { get { userState.currentUser } set { userState.currentUser = newValue } }
    var users: [UserInfo] { get { userState.users } set { userState.users = newValue } }
    var userAddress: UserContactLink? { get { userState.userAddress } set { userState.userAddress = newValue } }

    // MARK: - Call Properties (delegate to callState)
    var callInvitations: Dictionary<ChatId, RcvCallInvitation> { get { callState.callInvitations } set { callState.callInvitations = newValue } }
    var activeCall: Call? { get { callState.activeCall } set { callState.activeCall = newValue } }
    var callCommand: WebRTCCommandProcessor { callState.callCommand }
    var showCallView: Bool { get { callState.showCallView } set { callState.showCallView = newValue } }
    var activeCallViewIsCollapsed: Bool { get { callState.activeCallViewIsCollapsed } set { callState.activeCallViewIsCollapsed = newValue } }

    // MARK: - Notification Properties (delegate to notificationState)
    var notificationResponse: UNNotificationResponse? { get { notificationState.notificationResponse } set { notificationState.notificationResponse = newValue } }
    var deviceToken: DeviceToken? { get { notificationState.deviceToken } set { notificationState.deviceToken = newValue } }
    var savedToken: DeviceToken? { get { notificationState.savedToken } set { notificationState.savedToken = newValue } }
    var tokenRegistered: Bool { get { notificationState.tokenRegistered } set { notificationState.tokenRegistered = newValue } }
    var reRegisterTknStatus: NtfTknStatus? { get { notificationState.reRegisterTknStatus } set { notificationState.reRegisterTknStatus = newValue } }
    var tokenStatus: NtfTknStatus? { get { notificationState.tokenStatus } set { notificationState.tokenStatus = newValue } }
    var notificationMode: NotificationsMode { get { notificationState.notificationMode } set { notificationState.notificationMode = newValue } }
    var notificationServer: String? { get { notificationState.notificationServer } set { notificationState.notificationServer = newValue } }
    var notificationPreview: NotificationPreviewMode { get { notificationState.notificationPreview } set { notificationState.notificationPreview = newValue } }
    var ntfContactRequest: NTFContactRequest? { get { notificationState.ntfContactRequest } set { notificationState.ntfContactRequest = newValue } }
    var ntfCallInvitationAction: (ChatId, NtfCallAction)? { get { notificationState.ntfCallInvitationAction } set { notificationState.ntfCallInvitationAction = newValue } }
    var ntfEnableLocal: Bool { notificationState.ntfEnableLocal }

    // MARK: - App Properties (delegate to appState)
    private var _onboardingStage: OnboardingStage?
    var onboardingStage: OnboardingStage? {
        get { _onboardingStage }
        set {
            _onboardingStage = newValue
            appState.onboardingStage = newValue
            if let stage = newValue {
                onboardingStageDefault.set(stage)
            } else {
                onboardingStageDefault.set(.onboardingComplete)
            }
        }
    }
    var v3DBMigration: V3DBMigrationState { get { appState.v3DBMigration } set { appState.v3DBMigration = newValue } }
    var chatInitialized: Bool { get { appState.chatInitialized } set { appState.chatInitialized = newValue } }
    var chatRunning: Bool? { get { appState.chatRunning } set { appState.chatRunning = newValue } }
    var chatDbChanged: Bool { get { appState.chatDbChanged } set { appState.chatDbChanged = newValue } }
    var chatDbEncrypted: Bool? { get { appState.chatDbEncrypted } set { appState.chatDbEncrypted = newValue } }
    var chatDbStatus: DBMigrationResult? { get { appState.chatDbStatus } set { appState.chatDbStatus = newValue } }
    var ctrlInitInProgress: Bool { get { appState.ctrlInitInProgress } set { appState.ctrlInitInProgress = newValue } }
    var contentViewAccessAuthenticated: Bool { get { appState.contentViewAccessAuthenticated } set { appState.contentViewAccessAuthenticated = newValue } }
    var laRequest: LocalAuthRequest? { get { appState.laRequest } set { appState.laRequest = newValue } }
    var showingTerminal: Bool { get { appState.showingTerminal } set { appState.showingTerminal = newValue } }
    var terminalItems: [TerminalItem] { get { appState.terminalItems } set { appState.terminalItems = newValue } }
    var appOpenUrl: URL? { get { appState.appOpenUrl } set { appState.appOpenUrl = newValue } }
    var appOpenUrlLater: URL? { get { appState.appOpenUrlLater } set { appState.appOpenUrlLater = newValue } }
    var clipboardDetectedLink: String? { get { appState.clipboardDetectedLink } set { appState.clipboardDetectedLink = newValue } }
    var switchToChatsTab: Bool { get { appState.switchToChatsTab } set { appState.switchToChatsTab = newValue } }
    var remoteCtrlSession: RemoteCtrlSession? { get { appState.remoteCtrlSession } set { appState.remoteCtrlSession = newValue } }
    var showingInvitation: ShowingInvitation? { get { appState.showingInvitation } set { appState.showingInvitation = newValue } }
    var migrationState: MigrationToState? { get { appState.migrationState } set { appState.migrationState = newValue } }
    var stopPreviousRecPlay: URL? { get { appState.stopPreviousRecPlay } set { appState.stopPreviousRecPlay = newValue } }
    var draft: ComposeState? { get { appState.draft } set { appState.draft = newValue } }
    var draftChatId: String? { get { appState.draftChatId } set { appState.draftChatId = newValue } }
    var networkInfo: UserNetworkInfo { get { appState.networkInfo } set { appState.networkInfo = newValue } }
    var transportRouter: TransportRouter { appState.transportRouter }
    var meshTransportEnabled: Bool { get { appState.meshTransportEnabled } set { appState.meshTransportEnabled = newValue } }
    var meshAutoSwitch: Bool { get { appState.meshAutoSwitch } set { appState.meshAutoSwitch = newValue } }
    var meshGatewayEnabled: Bool { get { appState.meshGatewayEnabled } set { appState.meshGatewayEnabled = newValue } }
    var currentTransportID: String { get { appState.currentTransportID } set { appState.currentTransportID = newValue } }
    var activeTransportName: String { get { appState.activeTransportName } set { appState.activeTransportName = newValue } }
    var queuedMessageCount: Int { get { appState.queuedMessageCount } set { appState.queuedMessageCount = newValue } }
    var nearbyMeshPeers: [PublicPeerSnapshot] { get { appState.nearbyMeshPeers } set { appState.nearbyMeshPeers = newValue } }
    var meshInboxMessages: [MeshInboxMessage] { get { appState.meshInboxMessages } set { appState.meshInboxMessages = newValue } }
    var meshBridge: MeshChatBridge? { get { appState.meshBridge } set { appState.meshBridge = newValue } }
    var meshConversations: [Chat] { get { appState.meshConversations } set { appState.meshConversations = newValue } }
    var bluetoothPermissionDenied: Bool { get { appState.bluetoothPermissionDenied } set { appState.bluetoothPermissionDenied = newValue } }
    var showComputeStore: Bool { get { appState.showComputeStore } set { appState.showComputeStore = newValue } }
    var showPaywall: Bool { get { appState.showPaywall } set { appState.showPaywall = newValue } }
    var showKeyRotationNotice: Bool { get { appState.showKeyRotationNotice } set { appState.showKeyRotationNotice = newValue } }
    var conditions: ServerOperatorConditions { get { appState.conditions } set { appState.conditions = newValue } }

    // messageDelivery entries are cleaned up via endTask callbacks (POPOPXAPI_Messages.swift).
    // As a safety net against leaks (e.g. missed callbacks from crashes or dropped status updates),
    // cap the dictionary size: if it exceeds 200 entries, call callbacks and drop oldest entries.
    private var _messageDelivery: Dictionary<Int64, () -> Void> = [:]
    var messageDelivery: Dictionary<Int64, () -> Void> {
        get { _messageDelivery }
        set {
            _messageDelivery = newValue
            if _messageDelivery.count > 200 {
                let keysToRemove = _messageDelivery.keys.sorted()
                let removeCount = _messageDelivery.count - 100
                for key in keysToRemove.prefix(removeCount) {
                    _messageDelivery.removeValue(forKey: key)?()
                }
            }
        }
    }

    func removeMessageDelivery(_ key: Int64) -> (() -> Void)? {
        _messageDelivery.removeValue(forKey: key)
    }

    // Event ordering diagnostics: tracks the last processed event sequence number
    // and per-chat item creation order to detect out-of-order event delivery.
    private var _lastEventSequence: UInt64 = 0
    private var _knownItemIds: Set<Int64> = []
    @discardableResult
    func nextEventSequence() -> UInt64 {
        _lastEventSequence += 1
        return _lastEventSequence
    }

    func trackNewItem(_ itemId: Int64) {
        _knownItemIds.insert(itemId)
    }

    func isKnownItem(_ itemId: Int64) -> Bool {
        _knownItemIds.contains(itemId)
    }

    @Published var filesToDelete: Set<URL> = []

    // the banner kind the chat list showed this app session: it keeps the slot until restart, so dismissing it never puts
    // another in its place; only the badge alert shows regardless. Set while rendering, so not published.
    var chatListBanner: ChatListBanner?

    var fileToOpen: (fileId: Int64, chatId: String?, open: (CIFile) -> Void)?

    func bannerSlotFree(for banner: ChatListBanner) -> Bool {
        chatListBanner == nil || chatListBanner == banner
    }

    func openWhenReceived(_ file: CIFile, open: @escaping (CIFile) -> Void) {
        fileToOpen = (fileId: file.fileId, chatId: chatId, open: open)
    }

    func receivedFileToOpen(_ file: CIFile) -> Bool {
        if let f = fileToOpen { f.fileId == file.fileId && f.chatId == chatId } else { false }
    }

    func openReceivedFile(_ file: CIFile) {
        if let f = fileToOpen, receivedFileToOpen(file) {
            fileToOpen = nil
            f.open(file)
        }
    }

    static let shared = ChatModel()

    let im = ItemsModel.shared

    static var ok: Bool { ChatModel.shared.chatDbStatus == .ok }

    var ntfEnablePeriodic: Bool {
        notificationMode != .off
    }

    var activeRemoteCtrl: Bool {
        remoteCtrlSession?.active ?? false
    }

    var addressShortLinkDataSet: Bool {
        userAddress?.shortLinkDataSet ?? true
    }

    // Spec: spec/state.md#getUser
    func getUser(_ userId: Int64) -> User? {
        currentUser?.userId == userId
        ? currentUser
        : users.first { $0.user.userId == userId }?.user
    }

    func getUserIndex(_ user: User) -> Int? {
        users.firstIndex { $0.user.userId == user.userId }
    }

    // Spec: spec/state.md#updateUser
    func updateUser(_ user: User) {
        if let i = getUserIndex(user) {
            users[i].user = user
        }
        if currentUser?.userId == user.userId {
            currentUser = user
        }
    }

    // Spec: spec/state.md#removeUser
    func removeUser(_ user: User) {
        if let i = getUserIndex(user) {
            users.remove(at: i)
        }
        if user.activeUser || users.isEmpty {
            resetAllState()
        }
    }

    func resetAllState() {
        logger.debug("PX: ChatModel.resetAllState called")
        // Preserve onboardingStage - it represents user's progress through onboarding
        // and should not be reset when app state is cleared
        chatState.reset()
        userState.reset()
        notificationState.reset()
        callState.reset()
        appState.reset()
        _messageDelivery.removeAll()
        chats = []
        chatId = nil
        currentUser = nil
        ItemsModel.shared.reset()
        ChatTagsModel.shared.reset()
        ChatItemDummyModel.shared.sendUpdate()
        ConnectProgressManager.shared.stopConnectProgress()
        ChannelRelaysModel.shared.reset()
    }

    func hasChat(_ id: String) -> Bool {
        chatState.hasChat(id)
    }

    // Spec: spec/state.md#getChat
    func getChat(_ id: String) -> Chat? {
        chatState.getChat(id)
    }

    func getContactChat(_ contactId: Int64) -> Chat? {
        chats.first { chat in
            if case let .direct(contact) = chat.chatInfo {
                return contact.contactId == contactId
            } else {
                return false
            }
        }
    }

    func getGroupChat(_ groupId: Int64) -> Chat? {
        chats.first { chat in
            if case let .group(groupInfo, _) = chat.chatInfo {
                return groupInfo.groupId == groupId
            } else {
                return false
            }
        }
    }

    func populateGroupMembersIndexes() {
        groupMembersIndexes.removeAll()
        for (i, member) in groupMembers.enumerated() {
            groupMembersIndexes[member.groupMemberId] = i
        }
    }

    func getGroupMember(_ groupMemberId: Int64) -> GMember? {
        if let i = groupMembersIndexes[groupMemberId] {
            return groupMembers[i]
        }
        return nil
    }

    func loadGroupMembers(_ groupInfo: GroupInfo, updateView: @escaping () -> Void = {}) async {
        let groupMembers = await apiListMembers(groupInfo.groupId)
        await MainActor.run {
            if chatId == groupInfo.id {
                self.groupMembers = groupMembers.map { GMember.init($0) }
                self.populateGroupMembersIndexes()
                self.membersLoaded = true
                updateView()
            }
        }
    }

    private func getChatIndex(_ id: String) -> Int? {
        chatState.getChatIndex(id)
    }

    // Spec: spec/state.md#addChat
    func addChat(_ chat: Chat) {
        if chatId == nil {
            withAnimation { addChat_(chat, at: 0) }
        } else {
            addChat_(chat, at: 0)
        }
        popChatCollector.throttlePopChat(chat.chatInfo.id, currentPosition: 0)
    }

    func addChat_(_ chat: Chat, at position: Int = 0) {
        chats.insert(chat, at: position)
    }

    // Spec: spec/state.md#updateChatInfo
    func updateChatInfo(_ cInfo: ChatInfo) {
        if let i = getChatIndex(cInfo.id) {
            if case let .group(groupInfo, groupChatScope) = cInfo, groupChatScope != nil {
                chats[i].chatInfo = .group(groupInfo: groupInfo, groupChatScope: nil)
            } else {
                chats[i].chatInfo = cInfo
            }
            chats[i].created = Date.now
        }
    }

    func updateContactConnection(_ contactConnection: PendingContactConnection) {
        updateChat(.contactConnection(contactConnection: contactConnection))
    }

    func updateContact(_ contact: Contact) {
        if BlockedContactsManager.shared.isBlocked(contact.contactId) {
            removeChat(ChatInfo.direct(contact: contact).id)
            return
        }
        updateChat(.direct(contact: contact), addMissing: contact.directOrUsed)
    }

    func updateContactConnectionStats(_ contact: Contact, _ connectionStats: ConnectionStats) {
        var updatedConn = contact.activeConn
        updatedConn?.connectionStats = connectionStats
        var updatedContact = contact
        updatedContact.activeConn = updatedConn
        updateContact(updatedContact)
    }

    func updateGroup(_ groupInfo: GroupInfo) {
        updateChat(.group(groupInfo: groupInfo, groupChatScope: nil))
    }

    private func updateChat(_ cInfo: ChatInfo, addMissing: Bool = true) {
        if hasChat(cInfo.id) {
            updateChatInfo(cInfo)
        } else if addMissing {
            addChat(Chat(chatInfo: cInfo, chatItems: []))
            ChatTagsModel.shared.addPresetChatTags(cInfo, ChatStats())
        }
    }

    private func _updateChat(_ id: ChatId, _ update: @escaping (Chat) -> Void) {
        if let i = getChatIndex(id) {
            // we need to separately update the chat object, as it is ObservedObject,
            // and chat in the list so the list view is updated...
            // simply updating chats[i] replaces the object without updating the current object in the list
            let chat = chats[i]
            update(chat)
            chats[i] = chat
        }
    }

    // Spec: spec/state.md#replaceChat
    func replaceChat(_ id: String, _ chat: Chat) {
        if let i = getChatIndex(id) {
            chats[i] = chat
        } else {
            // invalid state, correcting
            chats.insert(chat, at: 0)
        }
    }

    func updateChats(_ newChats: [ChatData], keepingChatId: String? = nil) {
        var finalChats = newChats.map { Chat($0) }
        if let keepingChatId,
           let i = finalChats.firstIndex(where: { $0.id == keepingChatId }),
           let existingChat = getChat(keepingChatId) {
            // Preserve runtime-only fields that aren't in ChatData
            let preservedPopSeq = existingChat.popSequence
            finalChats[i].popSequence = preservedPopSeq
            // Move to front
            let chat = finalChats.remove(at: i)
            finalChats.insert(chat, at: 0)
        }
        chats = finalChats
        Task { @MainActor in NtfManager.shared.setNtfBadgeCount(totalUnreadCountForAllUsers()) }
        popChatCollector.clear()
    }

//    func addGroup(_ group: POPOPXSwitch.Group) {
//        groups[group.groupInfo.id] = group
//    }

    func addChatItem(_ chatInfo: ChatInfo, _ cItem: ChatItem) {
        // updates membersRequireAttention
        let cInfo: ChatInfo
        if case let .direct(contact) = chatInfo, contact.chatDeleted {
            // mark chat non deleted
            var updatedContact = contact
            updatedContact.chatDeleted = false
            cInfo = .direct(contact: updatedContact)
        } else {
            cInfo = chatInfo
        }
        updateChatInfo(cInfo)
        // update chat list
        if let i = getChatIndex(cInfo.id) {
            // update preview
            if cInfo.groupChatScope() == nil || cInfo.groupInfo?.membership.memberPending ?? false {
                chats[i].chatItems = switch cInfo {
                case .group:
                    if let currentPreviewItem = chats[i].chatItems.first {
                        if cItem.meta.itemTs >= currentPreviewItem.meta.itemTs {
                            [cItem]
                        } else {
                            [currentPreviewItem]
                        }
                    } else {
                        [cItem]
                    }
                default:
                    [cItem]
                }
                if case .rcvNew = cItem.meta.itemStatus {
                    unreadCollector.changeUnreadCounter(cInfo.id, by: 1, unreadMentions: cItem.meta.userMention ? 1 : 0)
                }
            }
            // pop chat
            popChatCollector.throttlePopChat(cInfo.id, currentPosition: i)
        } else {
            if cInfo.groupChatScope() == nil {
                addChat(Chat(chatInfo: cInfo, chatItems: [cItem]))
            } else {
                addChat(Chat(chatInfo: cInfo, chatItems: []))
            }
        }
        // add to current scope
        if let ciIM = getCIItemsModel(cInfo, cItem) {
            _ = _upsertChatItem(ciIM, cInfo, cItem)
        } else if chatId == cInfo.id {
            logger.warning("addChatItem: item \(cItem.id) not added to ItemsModel for active chat \(cInfo.id) - filter mismatch")
        }
    }

    func getCIItemsModel(_ cInfo: ChatInfo, _ ci: ChatItem) -> ItemsModel? {
        let cInfoScope = cInfo.groupChatScope()
        return if let cInfoScope = cInfoScope {
            switch (cInfoScope, secondaryIM?.secondaryIMFilter) {
            case let (.memberSupport, .some(.groupChatScopeContext(groupScopeInfo))):
                // Chat with member or Chat with admins opened (secondaryIM has .groupChatScopeContext filter), cInfo has matching scope
                (cInfo.id == chatId && sameChatScope(cInfoScope, groupScopeInfo.toChatScope())) ? secondaryIM : nil

            case let (.memberSupport, .some(.msgContentTagContext(contentTag))):
                // Reports view opened (secondaryIM has .msgContentTagContext(.report) filter), we process event (cInfo has proper .memberSupport scope)
                (cInfo.id == chatId && ci.isReport && contentTag == .report) ? secondaryIM : nil

            case let (.reports, .some(.msgContentTagContext(contentTag))):
                // Reports view opened (secondaryIM has .msgContentTagContext(.report) filter), we process user action (cInfo has surrogate .reports scope)
                (cInfo.id == chatId && ci.isReport && contentTag == .report) ? secondaryIM : nil
            default:
                nil
            }
        } else {
            cInfo.id == chatId ? im : nil
        }
    }

    func upsertChatItem(_ cInfo: ChatInfo, _ cItem: ChatItem) -> Bool {
        // update chat list
        var itemAdded: Bool = false
        if cInfo.groupChatScope() == nil {
            if let chat = getChat(cInfo.id) {
                if let pItem = chat.chatItems.last {
                    // Always update preview when item matches the last preview item
                    if pItem.id == cItem.id {
                        chat.chatItems = [cItem]
                    } else if chatId == cInfo.id && im.reversedChatItems.first(where: { $0.id == cItem.id }) == nil {
                        // Also update if chat is open and item not yet in ItemsModel
                        chat.chatItems = [cItem]
                    }
                } else {
                    chat.chatItems = [cItem]
                }
            } else {
                addChat(Chat(chatInfo: cInfo, chatItems: [cItem]))
                itemAdded = true
            }
            if cItem.isDeletedContent || cItem.meta.itemDeleted != nil {
                VoiceItemState.stopVoiceInChatView(cInfo, cItem)
            }
        }
        // update current scope
        if let ciIM = getCIItemsModel(cInfo, cItem) {
            itemAdded = _upsertChatItem(ciIM, cInfo, cItem)
        }
        return itemAdded
    }

    private func _upsertChatItem(_ ciIM: ItemsModel, _ cInfo: ChatInfo, _ cItem: ChatItem) -> Bool {
        if let i = getChatItemIndex(ciIM, cItem) {
            let oldStatus = ciIM.reversedChatItems[i].meta.itemStatus
            let newStatus = cItem.meta.itemStatus
            var ci = cItem
            if shouldKeepOldSndCIStatus(oldStatus: oldStatus, newStatus: newStatus) {
                ci.meta.itemStatus = oldStatus
            }
            _updateChatItem(ciIM: ciIM, at: i, with: ci)
            ChatItemDummyModel.shared.sendUpdate()
            return false
        } else {
            ciIM.reversedChatItems.insert(cItem, at: hasLiveDummy ? 1 : 0)
            ciIM.chatState.itemAdded((cItem.id, cItem.isRcvNew), hasLiveDummy ? 1 : 0)
            ciIM.itemAdded = true
            ChatItemDummyModel.shared.sendUpdate()
            return true
        }

        func itemAnimation() -> Animation? {
            switch cItem.chatDir {
            case .directSnd, .groupSnd: return cItem.meta.isLive ? nil : .default
            default: return .default
            }
        }
    }

    func updateChatItem(_ cInfo: ChatInfo, _ cItem: ChatItem, status: CIStatus? = nil) {
        if let ciIM = getCIItemsModel(cInfo, cItem),
           let i = getChatItemIndex(ciIM, cItem) {
            pxWithConditionalAnimation {
                _updateChatItem(ciIM: ciIM, at: i, with: cItem)
            }
        }
    }

    private func _updateChatItem(ciIM: ItemsModel, at i: Int, with cItem: ChatItem) {
        ciIM.reversedChatItems[i] = cItem
        ciIM.reversedChatItems[i].viewTimestamp = .now
    }

    func getChatItemIndex(_ ciIM: ItemsModel, _ cItem: ChatItem) -> Int? {
        ciIM.reversedChatItems.firstIndex(where: { $0.id == cItem.id })
    }

    func removeChatItem(_ cInfo: ChatInfo, _ cItem: ChatItem) {
        // update chat list
        if cInfo.groupChatScope() == nil {
            if cItem.isRcvNew {
                unreadCollector.changeUnreadCounter(cInfo.id, by: -1, unreadMentions: cItem.meta.userMention ? -1 : 0)
            }
            // update previews
            if let chat = getChat(cInfo.id) {
                if let pItem = chat.chatItems.last, pItem.id == cItem.id {
                    chat.chatItems = [ChatItem.deletedItemDummy()]
                }
            }
        }
        // remove from current scope
        if let ciIM = getCIItemsModel(cInfo, cItem) {
            if let i = getChatItemIndex(ciIM, cItem) {
                withAnimation {
                    let item = ciIM.reversedChatItems.remove(at: i)
                    ciIM.chatState.itemsRemoved([(item.id, i, item.isRcvNew)], ciIM.reversedChatItems.reversed())
                }
            }
        }
        VoiceItemState.stopVoiceInChatView(cInfo, cItem)
    }

    func removeMemberItems(_ removedMember: GroupMember, byMember: GroupMember, _ groupInfo: GroupInfo) {
        if chatId == groupInfo.id {
            for i in stride(from: im.reversedChatItems.count - 1, through: 0, by: -1) {
                guard i < im.reversedChatItems.count else { continue }
                if let updatedItem = removedUpdatedItem(im.reversedChatItems[i]) {
                    _updateChatItem(ciIM: im, at: i, with: updatedItem)
                }
            }
        } else if let chat = getChat(groupInfo.id),
                  chat.chatItems.count > 0,
                  let updatedItem = removedUpdatedItem(chat.chatItems[0]) {
                chat.chatItems = [updatedItem]
        }

        func removedUpdatedItem(_ item: ChatItem) -> ChatItem? {
            let newContent: CIContent
            if case .groupSnd = item.chatDir, removedMember.groupMemberId == groupInfo.membership.groupMemberId {
                newContent = .sndModerated
            } else if case let .groupRcv(groupMember) = item.chatDir, groupMember.groupMemberId == removedMember.groupMemberId {
                newContent = .rcvModerated
            } else {
                return nil
            }
            var updatedItem = item
            updatedItem.meta.itemDeleted = .moderated(deletedTs: Date.now, byGroupMember: byMember)
            if groupInfo.fullGroupPreferences.fullDelete.on {
                updatedItem.content = newContent
            }
            if item.isActiveReport {
                decreaseGroupReportsCounter(groupInfo.id)
            }
            return updatedItem
        }
    }

    func nextChatItemData<T>(_ chatItemId: Int64, previous: Bool, map: @escaping (ChatItem) -> T?) -> T? {
        guard var i = im.reversedChatItems.firstIndex(where: { $0.id == chatItemId }) else { return nil }
        if previous {
            while i < im.reversedChatItems.count - 1 {
                i += 1
                if let res = map(im.reversedChatItems[i]) { return res }
            }
        } else {
            while i > 0 {
                i -= 1
                if let res = map(im.reversedChatItems[i]) { return res }
            }
        }
        return nil
    }

    func updateCurrentUser(_ newProfile: Profile, _ preferences: FullPreferences? = nil) {
        if let current = currentUser {
            currentUser?.profile = toLocalProfile(current.profile.profileId, newProfile, "")
            currentUser?.profile.localBadge = current.profile.localBadge
            currentUser?.profile.contactDomainVerified = current.profile.contactDomainVerified
            if let preferences = preferences {
                currentUser?.fullPreferences = preferences
            }
            if let current = currentUser, let i = users.firstIndex(where: { $0.user.userId == current.userId }) {
                users[i].user = current
            }
        }
    }

    func updateCurrentUserUiThemes(uiThemes: ThemeModeOverrides?) {
        guard var current = currentUser, current.uiThemes != uiThemes else { return }
        current.uiThemes = uiThemes
        let i = users.firstIndex(where: { $0.user.userId == current.userId })
        if let i {
            users[i].user = current
        }
        currentUser = current
    }

    func addLiveDummy(_ chatInfo: ChatInfo) -> ChatItem {
        let cItem = ChatItem.liveDummy(chatInfo.chatType)
        withAnimation {
            im.reversedChatItems.insert(cItem, at: 0)
            im.chatState.itemAdded((cItem.id, cItem.isRcvNew), 0)
            im.itemAdded = true
        }
        return cItem
    }

    func removeLiveDummy(animated: Bool = true) {
        if hasLiveDummy && !im.reversedChatItems.isEmpty {
            if animated {
                withAnimation { _ = im.reversedChatItems.removeFirst() }
            } else {
                _ = im.reversedChatItems.removeFirst()
            }
        }
    }

    private var hasLiveDummy: Bool {
        im.reversedChatItems.first?.isLiveDummy == true
    }

    func markAllChatItemsRead(_ chatIM: ItemsModel, _ cInfo: ChatInfo) {
        guard let user = self.currentUser else { return }
        // update preview
        _updateChat(cInfo.id) { chat in
            self.decreaseUnreadCounter(user: user, chat: chat)
            ChatTagsModel.shared.markChatTagRead(chat)
            chat.chatStats = ChatStats()
        }
        // update current chat
        if chatId == cInfo.id {
            var i = 0
            while i < im.reversedChatItems.count {
                markChatItemRead_(chatIM, i)
                i += 1
            }
            im.chatState.itemsRead(nil, im.reversedChatItems.reversed())
        }
    }
    func markChatUnread(_ cInfo: ChatInfo, unreadChat: Bool = true) {
        _updateChat(cInfo.id) { chat in
            let wasUnread = chat.unreadTag
            chat.chatStats.unreadChat = unreadChat
            ChatTagsModel.shared.updateChatTagRead(chat, wasUnread: wasUnread)
        }
    }

    func clearChat(_ cInfo: ChatInfo) {
        guard let user = self.currentUser else { return }
        // clear preview
        if let chat = getChat(cInfo.id) {
            self.decreaseUnreadCounter(user: user, chat: chat)
            chat.chatItems = []
            ChatTagsModel.shared.markChatTagRead(chat)
            chat.chatStats = ChatStats()
            chat.chatInfo = cInfo
        }
        // clear current chat
        if chatId == cInfo.id {
            im.reversedChatItems = []
            im.chatState.clear()
        }
    }

    func markChatItemsRead(_ chatIM: ItemsModel, _ cInfo: ChatInfo, _ itemIds: [ChatItem.ID], _ mentionsRead: Int) {
        if self.chatId == cInfo.id {
            var unreadItemIds: Set<ChatItem.ID> = []
            var i = 0
            var ids = Set(itemIds)
            while i < chatIM.reversedChatItems.count && !ids.isEmpty {
                let item = chatIM.reversedChatItems[i]
                if ids.contains(item.id) && item.isRcvNew {
                    markChatItemRead_(chatIM, i)
                    unreadItemIds.insert(item.id)
                    ids.remove(item.id)
                }
                i += 1
            }
            chatIM.chatState.itemsRead(unreadItemIds, chatIM.reversedChatItems.reversed())
        }
        self.unreadCollector.changeUnreadCounter(cInfo.id, by: -itemIds.count, unreadMentions: -mentionsRead)
    }

    private let unreadCollector = UnreadCollector()

    @MainActor
    class UnreadCollector {
        private let subject = PassthroughSubject<Void, Never>()
        private var bag = Set<AnyCancellable>()
        private var unreadCounts: [ChatId: (unread: Int, mentions: Int)] = [:]

        init() {
            subject
                .debounce(for: 1, scheduler: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self else { return }
                    let m = ChatModel.shared
                    for (chatId, (unread, mentions)) in self.unreadCounts {
                        if unread != 0 || mentions != 0, let i = m.getChatIndex(chatId) {
                            m.changeUnreadCounter(i, by: unread, unreadMentions: mentions)
                        }
                    }
                    self.unreadCounts = [:]
                }
                .store(in: &bag)
        }

        func changeUnreadCounter(_ chatId: ChatId, by count: Int, unreadMentions: Int) {
            let (unread, mentions) = self.unreadCounts[chatId] ?? (0, 0)
            self.unreadCounts[chatId] = (unread + count, mentions + unreadMentions)
            subject.send()
        }
    }

    let popChatCollector = PopChatCollector()

    @MainActor
    class PopChatCollector {
        private let subject = PassthroughSubject<Void, Never>()
        private var bag = Set<AnyCancellable>()
        private var chatsToPop: [ChatId: UInt64] = [:]
        private var popSequence: UInt64 = 0
        private let popSeqComparator = KeyPathComparator<Chat>(\.popSequence, order: .reverse)

        init() {
            subject
                .throttle(for: 2, scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] in self?.popCollectedChats() }
                .store(in: &bag)
        }

        func throttlePopChat(_ chatId: ChatId, currentPosition: Int) {
            let m = ChatModel.shared
            if currentPosition > 0 && m.chatId == chatId {
                m.chatToTop = chatId
            }
            if currentPosition > 0 || !chatsToPop.isEmpty {
                popSequence += 1
                chatsToPop[chatId] = popSequence
                subject.send()
            }
        }

        func clear() {
            chatsToPop = [:]
        }

        func popCollectedChats() {
            let m = ChatModel.shared
            var ixs: IndexSet = []
            var chs: [Chat] = []
            // collect chats that received updates
            for (chatId, popSeq) in self.chatsToPop {
                // Currently opened chat is excluded, removing it from the list would navigate out of it
                // It will be popped to top later when user exits from the list.
                if m.chatId != chatId, let i = m.getChatIndex(chatId) {
                    ixs.insert(i)
                    let ch = m.chats[i]
                    ch.popSequence = popSeq
                    chs.append(ch)
                }
            }

            let removeInsert = {
                // Consolidate remove+insert into a single array mutation to avoid
                // triggering chatIndexMap rebuild twice via didSet
                var newChats = m.chats
                newChats.remove(atOffsets: ixs)
                // sort chats by pop sequence in descending order
                newChats.insert(contentsOf: chs.sorted(using: self.popSeqComparator), at: 0)
                m.chats = newChats
            }

            if m.chatId == nil {
                withAnimation { removeInsert() }
            } else {
                removeInsert()
            }

            self.chatsToPop = [:]
        }
    }

    private func markChatItemRead_(_ chatIM: ItemsModel, _ i: Int) {
        let meta = chatIM.reversedChatItems[i].meta
        if case .rcvNew = meta.itemStatus {
            chatIM.reversedChatItems[i].meta.itemStatus = .rcvRead
            chatIM.reversedChatItems[i].viewTimestamp = .now
            if meta.itemLive != true, let ttl = meta.itemTimed?.ttl {
                chatIM.reversedChatItems[i].meta.itemTimed?.deleteAt = .now + TimeInterval(ttl)
            }
        }
    }

    func changeUnreadCounter(_ chatIndex: Int, by count: Int, unreadMentions: Int) {
        guard let user = currentUser else { return }
        let wasUnread = chats[chatIndex].unreadTag
        let stats = chats[chatIndex].chatStats
        chats[chatIndex].chatStats.unreadCount = max(0, stats.unreadCount + count)
        chats[chatIndex].chatStats.unreadMentions = max(0, stats.unreadMentions + unreadMentions)
        ChatTagsModel.shared.updateChatTagRead(chats[chatIndex], wasUnread: wasUnread)
        changeUnreadCounter(user: user, by: count)
    }

    func increaseUnreadCounter(user: any UserLike) {
        changeUnreadCounter(user: user, by: 1)
    }

    func decreaseUnreadCounter(user: any UserLike, chat: Chat) {
        let by = chat.chatInfo.chatSettings?.enableNtfs == .mentions
                ? chat.chatStats.unreadMentions
                : chat.chatStats.unreadCount
        decreaseUnreadCounter(user: user, by: by)
    }

    func decreaseUnreadCounter(user: any UserLike, by: Int = 1) {
        changeUnreadCounter(user: user, by: -by)
    }

    private func changeUnreadCounter(user: any UserLike, by: Int) {
        if let i = users.firstIndex(where: { $0.user.userId == user.userId }) {
            users[i].unreadCount = max(0, users[i].unreadCount + by)
        }
        Task { @MainActor in NtfManager.shared.changeNtfBadgeCount(by: by) }
    }

    // Spec: spec/state.md#totalUnreadCountForAllUsers
    func totalUnreadCountForAllUsers() -> Int {
        var unread: Int = 0
        for chat in chats {
            switch chat.chatInfo.chatSettings?.enableNtfs {
            case .all: unread += chat.chatStats.unreadCount
            case .mentions: unread += chat.chatStats.unreadMentions
            default: ()
            }
        }
        for u in users {
            if !u.user.activeUser {
                unread += u.unreadCount
            }
        }
        return unread
    }

    func increaseGroupReportsCounter(_ chatId: ChatId) {
        changeGroupReportsCounter(chatId, 1)
    }

    func decreaseGroupReportsCounter(_ chatId: ChatId, by: Int = 1) {
        changeGroupReportsCounter(chatId, -by)
    }

    private func changeGroupReportsCounter(_ chatId: ChatId, _ by: Int = 0) {
        if by == 0 { return }

        if let i = getChatIndex(chatId) {
            let chat = chats[i]
            let wasReportsCount = chat.chatStats.reportsCount
            chat.chatStats.reportsCount = max(0, chat.chatStats.reportsCount + by)
            let nowReportsCount = chat.chatStats.reportsCount
            let by = wasReportsCount == 0 && nowReportsCount > 0 ? 1 : (wasReportsCount > 0 && nowReportsCount == 0) ? -1 : 0
            ChatTagsModel.shared.changeGroupReportsTag(by)
        }
    }

    // this function analyses "connected" events and assumes that each member will be there only once
    func getConnectedMemberNames(_ chatItem: ChatItem) -> (Int, [String]) {
        var count = 0
        var ns: [String] = []
        if let ciCategory = chatItem.mergeCategory,
           var i = getChatItemIndex(im, chatItem) {
            while i < im.reversedChatItems.count {
                let ci = im.reversedChatItems[i]
                if ci.mergeCategory != ciCategory { break }
                if let m = ci.memberConnected {
                    ns.append(m.displayName)
                }
                count += 1
                i += 1
            }
        }
        return (count, ns)
    }

    // returns the index of the passed item and the next item (it has smaller index)
    func getNextChatItem(_ ci: ChatItem) -> (Int?, ChatItem?) {
        if let i = getChatItemIndex(im, ci) {
            (i, i > 0 ? im.reversedChatItems[i - 1] : nil)
        } else {
            (nil, nil)
        }
    }

    // returns the index of the first item in the same merged group (the first hidden item)
    // and the previous visible item with another merge category
    func getPrevShownChatItem(_ ciIndex: Int?, _ ciCategory: CIMergeCategory?) -> (Int?, ChatItem?) {
        guard var i = ciIndex else { return (nil, nil) }
        let fst = im.reversedChatItems.count - 1
        while i < fst {
            i = i + 1
            let ci = im.reversedChatItems[i]
            if ciCategory == nil || ciCategory != ci.mergeCategory {
                return (i - 1, ci)
            }
        }
        return (i, nil)
    }

    // returns the previous member in the same merge group and the count of members in this group
    func getPrevHiddenMember(_ member: GroupMember, _ range: ClosedRange<Int>) -> (GroupMember?, Int) {
        let items = im.reversedChatItems
        var prevMember: GroupMember? = nil
        var memberIds: Set<Int64> = []
        for i in range {
            if i < items.count {
                if case let .groupRcv(m) = items[i].chatDir {
                    if prevMember == nil && m.groupMemberId != member.groupMemberId { prevMember = m }
                    memberIds.insert(m.groupMemberId)
                }
            } else {
                logger.error("getPrevHiddenMember: index >= count of reversed items: \(i) vs \(items.count), range: \(String(describing: range))")
            }
        }
        return (prevMember, memberIds.count)
    }

    // Spec: spec/state.md#popChat
    func popChat(_ id: String) {
        if let i = getChatIndex(id) {
            // no animation here, for it not to look like it just moved when leaving the chat
            popChat_(i)
        }
    }

    private func popChat_(_ i: Int, to position: Int = 0) {
        // Consolidate remove+insert into a single array mutation to avoid
        // triggering chatIndexMap rebuild twice via didSet
        var newChats = chats
        let chat = newChats.remove(at: i)
        newChats.insert(chat, at: position)
        chats = newChats
    }

    func replaceConnReqView(_ id: String, _ withId: ChatId) {
        if id == showingInvitation?.pcc.id {
            markShowingInvitationUsed()
            dismissAllSheets(animated: true) {
                ItemsModel.shared.loadOpenChat(withId)
            }
        }
    }

    func dismissConnReqView(_ id: String) {
        if id == showingInvitation?.pcc.id {
            markShowingInvitationUsed()
            dismissAllSheets()
        }
    }

    func markShowingInvitationUsed() {
        showingInvitation?.connChatUsed = true
    }

    // Spec: spec/state.md#removeChat
    func removeChat(_ id: String) {
        var groupId: Int64?
        withAnimation {
            if let i = getChatIndex(id) {
                let removed = chats.remove(at: i)
                groupId = removed.chatInfo.groupInfo?.groupId
                ChatTagsModel.shared.removePresetChatTags(removed.chatInfo, removed.chatStats)
                removeWallpaperFilesFromChat(removed)
            }
        }
        if chatId == id {
            groupMembers = []
            groupMembersIndexes.removeAll()
            // Remove channelRelayHostnames for this channel only, preserving other prepared channels
            if let gId = groupId {
                channelRelayHostnames.removeValue(forKey: gId)
            }
            membersLoaded = false
        }
    }

    func upsertGroupMember(_ groupInfo: GroupInfo, _ member: GroupMember) -> Bool {
        // user member was updated
        if groupInfo.membership.groupMemberId == member.groupMemberId {
            updateGroup(groupInfo)
            return false
        }
        // update current chat or channel being created
        if chatId == groupInfo.id || creatingChannelId == groupInfo.id {
            if let i = groupMembersIndexes[member.groupMemberId] {
                let connStatusChanged = self.groupMembers[i].wrapped.activeConn?.connStatus != member.activeConn?.connStatus
                withAnimation(.default) {
                    self.groupMembers[i].wrapped = member
                    self.groupMembers[i].created = Date.now
                }
                // Updating wrapped on a reference-type GMember doesn't mutate the groupMembers array,
                // so ChatModel.objectWillChange doesn't fire automatically — notify views explicitly.
                if connStatusChanged {
                    objectWillChange.send()
                }
                return false
            } else {
                withAnimation {
                    groupMembers.append(GMember(member))
                    groupMembersIndexes[member.groupMemberId] = groupMembers.count - 1
                }
                return true
            }
        } else {
            return false
        }
    }

    func updateGroupMemberConnectionStats(_ groupInfo: GroupInfo, _ member: GroupMember, _ connectionStats: ConnectionStats) {
        if var conn = member.activeConn {
            conn.connectionStats = connectionStats
            var updatedMember = member
            updatedMember.activeConn = conn
            _ = upsertGroupMember(groupInfo, updatedMember)
        }
    }

    func removeWallpaperFilesFromChat(_ chat: Chat) {
        if case let .direct(contact) = chat.chatInfo {
            removeWallpaperFilesFromTheme(contact.uiThemes)
        } else if case let .group(groupInfo, _) = chat.chatInfo {
            removeWallpaperFilesFromTheme(groupInfo.uiThemes)
        }
    }

    func removeWallpaperFilesFromAllChats(_ user: User) {
        // TODO [TODO-FEATURE: low] Implement cleanup for inactive users. When a user is deactivated,
        // their chat data, cached messages, and associated state should be cleaned up
        // to free memory and storage.
        // Currently, only removing everything from currently active user is supported.
        if user.userId == currentUser?.userId {
            chats.forEach {
                removeWallpaperFilesFromChat($0)
            }
        }
    }
}

struct ShowingInvitation {
    var pcc: PendingContactConnection
    var connChatUsed: Bool
}

struct NTFContactRequest {
    var chatId: String
}

// Spec: spec/state.md#Chat
@MainActor
final class Chat: ObservableObject, @preconcurrency Identifiable, @preconcurrency ChatLike {
    @Published var chatInfo: ChatInfo
    @Published var chatItems: [ChatItem]
    @Published var chatStats: ChatStats
    var created = Date.now
    fileprivate var popSequence: UInt64?

    init(_ cData: ChatData) {
        self.chatInfo = cData.chatInfo
        self.chatItems = cData.chatItems
        self.chatStats = cData.chatStats
    }

    init(chatInfo: ChatInfo, chatItems: [ChatItem] = [], chatStats: ChatStats = ChatStats()) {
        self.chatInfo = chatInfo
        self.chatItems = chatItems
        self.chatStats = chatStats
    }

    func copy(chatInfo: ChatInfo? = nil, chatItems: [ChatItem]? = nil, chatStats: ChatStats? = nil) -> Chat {
        Chat(
            chatInfo: chatInfo ?? self.chatInfo,
            chatItems: chatItems ?? self.chatItems,
            chatStats: chatStats ?? self.chatStats
        )
    }

    var unreadTag: Bool {
        switch chatInfo.chatSettings?.enableNtfs {
        case .all: chatStats.unreadChat || chatStats.unreadCount > 0
        case .mentions: chatStats.unreadChat || chatStats.unreadMentions > 0
        default: chatStats.unreadChat
        }
    }

    var id: ChatId { get { chatInfo.id } }

    var viewId: String { get { "\(chatInfo.id) \(created.timeIntervalSince1970)" } }

    var supportUnreadCount: Int {
        switch chatInfo {
        case let .group(groupInfo, _):
            if groupInfo.canModerate {
                return groupInfo.membersRequireAttention
            } else {
                return groupInfo.membership.supportChat?.unread ?? 0
            }
        default: return 0
        }
    }

    public static var sampleData: Chat = Chat(chatInfo: ChatInfo.sampleData.direct, chatItems: [])
}

@MainActor
final class GMember: ObservableObject, @preconcurrency Identifiable {
    @Published var wrapped: GroupMember
    var created = Date.now

    init(_ member: GroupMember) {
        self.wrapped = member
    }

    var id: String { wrapped.id }
    var groupId: Int64 { wrapped.groupId }
    var groupMemberId: Int64 { wrapped.groupMemberId }
    var displayName: String { wrapped.displayName }
    var viewId: String { get { "\(wrapped.id) \(created.timeIntervalSince1970)" } }
    static let sampleData = GMember(GroupMember.sampleData)
}

struct RemoteCtrlSession {
    var ctrlAppInfo: CtrlAppInfo?
    var appVersion: String
    var sessionState: UIRemoteCtrlSessionState

    func updateState(_ state: UIRemoteCtrlSessionState) -> RemoteCtrlSession {
        RemoteCtrlSession(ctrlAppInfo: ctrlAppInfo, appVersion: appVersion, sessionState: state)
    }

    var active: Bool {
        if case .connected = sessionState { true } else { false }
    }

    var discovery: Bool {
        if case .searching = sessionState { true } else { false }
    }

    var sessionCode: String? {
        switch sessionState {
        case let .pendingConfirmation(_, sessionCode): sessionCode
        case let .connected(_, sessionCode): sessionCode
        default: nil
        }
    }
}

enum UIRemoteCtrlSessionState {
    case starting
    case searching
    case found(remoteCtrl: RemoteCtrlInfo, compatible: Bool)
    case connecting(remoteCtrl_: RemoteCtrlInfo?)
    case pendingConfirmation(remoteCtrl_: RemoteCtrlInfo?, sessionCode: String)
    case connected(remoteCtrl: RemoteCtrlInfo, sessionCode: String)
}

// MARK: - POPOPX
extension ChatModel {
    static let pxComponentTag: String = "PXChatState"
    static let pxTerminalItemLimit: Int = 200
    static let pxNavigationDelay: TimeInterval = 0.25
    static let pxMessageDeliveryCap: Int = 200
}
