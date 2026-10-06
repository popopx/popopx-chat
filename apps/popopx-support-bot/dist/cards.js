"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CardManager = void 0;
const types_1 = require("@popopx-chat/types");
const popopx_chat_1 = require("popopx-chat");
const async_mutex_1 = require("async-mutex");
const util_js_1 = require("./util.js");
function isConversationState(x) {
    return x === "WELCOME" || x === "QUEUE" || x === "GROK" || x === "TEAM-PENDING" || x === "TEAM";
}
function isActiveMember(m) {
    return m.memberStatus === types_1.T.GroupMemberStatus.Connected
        || m.memberStatus === types_1.T.GroupMemberStatus.Complete
        || m.memberStatus === types_1.T.GroupMemberStatus.Announced;
}
// Prevent ! from triggering POPOPX markdown styled text (color/small).
// The parser treats !N<space> as color markup (N: 1-6, r, g, b, y, c, m, -)
// and closes at the next !. No escape mechanism exists in the parser,
// so we insert a zero-width space to break the trigger pattern.
function escapeStyledMarkdown(text) {
    return text.replace(/!([1-6rgbycm-])/g, "!\u200B$1");
}
// Truncate a single message to ~maxChars, appending [truncated] if needed
function truncateMsg(text, maxChars) {
    if (text.length <= maxChars)
        return text;
    return text.slice(0, maxChars) + "… [truncated]";
}
// Describe non-text content types
function contentTypeLabel(ci) {
    const content = ci.content;
    if (content.type !== "rcvMsgContent" && content.type !== "sndMsgContent")
        return null;
    const mc = content.msgContent;
    switch (mc.type) {
        case "image": return "[image]";
        case "video": return "[video]";
        case "voice": return "[voice]";
        case "file": return "[file]";
        default: return null;
    }
}
class CardManager {
    chat;
    config;
    mainUserId;
    pendingUpdates = new Set();
    flushInterval;
    // Outer lock; profileMutex (via withMainProfile) is the inner lock.
    customDataMutexes = new Map();
    constructor(chat, config, mainUserId, flushIntervalMs = 300 * 1000) {
        this.chat = chat;
        this.config = config;
        this.mainUserId = mainUserId;
        this.flushInterval = setInterval(() => this.flush(), flushIntervalMs);
        this.flushInterval.unref();
    }
    async withMainProfile(fn) {
        return util_js_1.profileMutex.runExclusive(async () => {
            await this.chat.apiSetActiveUser(this.mainUserId);
            return fn();
        });
    }
    getCustomDataMutex(groupId) {
        let m = this.customDataMutexes.get(groupId);
        if (!m) {
            m = new async_mutex_1.Mutex();
            this.customDataMutexes.set(groupId, m);
        }
        return m;
    }
    scheduleUpdate(groupId) {
        this.pendingUpdates.add(groupId);
    }
    async createCard(groupId, groupInfo) {
        const { text } = await this.composeCard(groupId, groupInfo);
        const chatRef = { chatType: types_1.T.ChatType.Group, chatId: this.config.teamGroup.id };
        const items = await this.withMainProfile(() => this.chat.apiSendMessages(chatRef, [
            { msgContent: { type: "text", text }, mentions: {} },
        ]));
        await this.mergeCustomData(groupId, { cardItemId: items[0].chatItem.meta.itemId });
    }
    async flush() {
        const groups = [...this.pendingUpdates];
        this.pendingUpdates.clear();
        for (const groupId of groups) {
            try {
                await this.flushOne(groupId);
            }
            catch (err) {
                (0, util_js_1.logError)(`Card flush failed for group ${groupId}`, err);
            }
        }
    }
    // Dispatches to create-path when cardItemId is absent so a failed createCard retries.
    async flushOne(groupId) {
        const groupInfo = await this.withMainProfile(() => (0, util_js_1.getGroupInfo)(this.chat, groupId));
        if (!groupInfo)
            return;
        const data = groupInfo.customData;
        if (typeof data?.cardItemId === "number") {
            await this.updateCard(groupId);
        }
        else {
            await this.createCard(groupId, groupInfo);
        }
    }
    async refreshAllCards() {
        // Scan the most recently active 1000 chats. Active cards live on
        // recently-active customer chats by definition — a card stays open
        // while the conversation is in flight. If the bot has been offline
        // long enough that an active card has fallen outside this window, the
        // card refreshes lazily on the next customer message (which moves the
        // chat back into the recent window).
        const chats = await this.withMainProfile(() => this.chat.apiGetChats(this.mainUserId, { type: "last", count: 1000 }));
        const activeCards = [];
        for (const c of chats) {
            if (c.chatInfo.type !== "group")
                continue;
            const groupInfo = c.chatInfo.groupInfo;
            const customData = groupInfo.customData;
            if (customData && typeof customData.cardItemId === "number" && !customData.complete) {
                activeCards.push({ groupId: groupInfo.groupId, cardItemId: customData.cardItemId });
            }
        }
        if (activeCards.length === 0)
            return;
        // Sort ascending by cardItemId — higher ID = more recently updated card.
        // Oldest-updated cards refresh first; newest-updated refresh last,
        // so the most recent cards end up at the bottom of the team group.
        activeCards.sort((a, b) => a.cardItemId - b.cardItemId);
        (0, util_js_1.log)(`Startup: refreshing ${activeCards.length} card(s)`);
        for (const { groupId } of activeCards) {
            try {
                await this.updateCard(groupId);
            }
            catch (err) {
                (0, util_js_1.logError)(`Startup card refresh failed for group ${groupId}`, err);
            }
        }
    }
    destroy() {
        clearInterval(this.flushInterval);
    }
    // --- State derivation ---
    async getGroupComposition(groupId) {
        const members = await this.withMainProfile(() => this.chat.apiListMembers(groupId));
        return {
            grokMember: members.find(m => this.config.grokContactId !== null
                && m.memberContactId === this.config.grokContactId
                && isActiveMember(m)),
            teamMembers: members.filter(m => this.config.teamMembers.some(tm => tm.id === m.memberContactId)
                && isActiveMember(m)),
        };
    }
    async deriveState(groupId) {
        const data = await this.getRawCustomData(groupId);
        return data?.state ?? "WELCOME";
    }
    async getLastCustomerMessageTime(groupId, customerId) {
        const chat = await this.getChat(groupId, 20);
        for (let i = chat.chatItems.length - 1; i >= 0; i--) {
            const ci = chat.chatItems[i];
            if (ci.chatDir.type === "groupRcv" && ci.chatDir.groupMember.memberId === customerId) {
                return new Date(ci.meta.createdAt).getTime();
            }
        }
        return undefined;
    }
    async getLastTeamOrGrokMessageTime(groupId) {
        const chat = await this.getChat(groupId, 20);
        for (let i = chat.chatItems.length - 1; i >= 0; i--) {
            const ci = chat.chatItems[i];
            if (ci.chatDir.type === "groupRcv") {
                const contactId = ci.chatDir.groupMember.memberContactId;
                const isTeam = this.config.teamMembers.some(tm => tm.id === contactId);
                const isGrok = this.config.grokContactId !== null && contactId === this.config.grokContactId;
                if (isTeam || isGrok)
                    return new Date(ci.meta.createdAt).getTime();
            }
            if (ci.chatDir.type === "groupSnd") {
                // Bot's own messages don't count
            }
        }
        return undefined;
    }
    // --- Custom data ---
    async getRawCustomData(groupId) {
        const group = await this.withMainProfile(() => (0, util_js_1.getGroupInfo)(this.chat, groupId));
        if (!group?.customData)
            return null;
        const data = group.customData;
        const result = {};
        if (isConversationState(data.state))
            result.state = data.state;
        if (typeof data.cardItemId === "number")
            result.cardItemId = data.cardItemId;
        if (data.complete === true)
            result.complete = true;
        return result;
    }
    async mergeCustomData(groupId, patch) {
        return this.getCustomDataMutex(groupId).runExclusive(async () => {
            const current = (await this.getRawCustomData(groupId)) ?? {};
            const merged = { ...current, ...patch };
            for (const key of Object.keys(merged)) {
                if (merged[key] === undefined)
                    delete merged[key];
            }
            await this.withMainProfile(() => this.chat.apiSetGroupCustomData(groupId, merged));
        });
    }
    async clearCustomData(groupId) {
        return this.getCustomDataMutex(groupId).runExclusive(() => this.withMainProfile(() => this.chat.apiSetGroupCustomData(groupId)));
    }
    // --- Chat history access ---
    async getChat(groupId, count) {
        return this.withMainProfile(() => this.chat.apiGetChat(types_1.T.ChatType.Group, groupId, count));
    }
    // --- Internal ---
    async updateCard(groupId) {
        const groupInfo = await this.withMainProfile(() => (0, util_js_1.getGroupInfo)(this.chat, groupId));
        if (!groupInfo)
            return;
        const customData = groupInfo.customData;
        const cardItemId = customData?.cardItemId;
        if (typeof cardItemId !== "number")
            return;
        try {
            await this.withMainProfile(() => this.chat.apiDeleteChatItems(types_1.T.ChatType.Group, this.config.teamGroup.id, [cardItemId], types_1.T.CIDeleteMode.Broadcast));
        }
        catch {
            // card may already be deleted
        }
        const { text, complete } = await this.composeCard(groupId, groupInfo);
        const chatRef = { chatType: types_1.T.ChatType.Group, chatId: this.config.teamGroup.id };
        const items = await this.withMainProfile(() => this.chat.apiSendMessages(chatRef, [
            { msgContent: { type: "text", text }, mentions: {} },
        ]));
        const patch = {
            cardItemId: items[0].chatItem.meta.itemId,
            complete: complete ? true : undefined,
        };
        await this.mergeCustomData(groupId, patch);
    }
    async composeCard(groupId, groupInfo) {
        const rawName = groupInfo.groupProfile.displayName || `group-${groupId}`;
        const customerName = rawName.replace(/\n+/g, " ");
        const bc = groupInfo.businessChat;
        const customerId = bc?.customerId;
        const state = await this.deriveState(groupId);
        const { teamMembers } = await this.getGroupComposition(groupId);
        const icon = await this.computeIcon(groupId, state, customerId ?? undefined);
        const waitStr = await this.computeWaitTime(groupId, state, customerId ?? undefined);
        const chat = await this.getChat(groupId, 100);
        const msgCount = chat.chatItems.filter((ci) => ci.chatDir.type !== "groupSnd").length;
        const stateLabel = this.stateLabel(state);
        const agentNames = teamMembers.map(m => m.memberProfile.displayName);
        const agentStr = agentNames.length > 0 ? ` · ${agentNames.join(", ")}` : "";
        const preview = this.buildPreview(chat.chatItems, customerName, customerId);
        // Final line uses /'join <id>' quoting so POPOPX clients render the full
        // command (including the argument) as a single clickable token.
        const joinCmd = `/'join ${groupId}'`;
        const line1 = `${icon} *${customerName}* · ${waitStr} · ${msgCount} msgs`;
        const line2 = `${stateLabel}${agentStr}`;
        return { text: `${line1}\n${line2}\n${preview}\n${joinCmd}`, complete: icon === "✅" };
    }
    async computeIcon(groupId, state, customerId) {
        const now = Date.now();
        const completeMs = this.config.completeHours * 3600_000;
        // Check auto-complete: last team/Grok message time vs customer silence
        const lastTeamGrokTime = await this.getLastTeamOrGrokMessageTime(groupId);
        if (lastTeamGrokTime) {
            const lastCustTime = customerId
                ? await this.getLastCustomerMessageTime(groupId, customerId)
                : undefined;
            // Auto-complete if team/grok replied and customer hasn't responded since, for completeHours
            if (!lastCustTime || lastCustTime < lastTeamGrokTime) {
                if (now - lastTeamGrokTime >= completeMs)
                    return "✅";
            }
        }
        switch (state) {
            case "QUEUE": {
                const lastCustTime = customerId
                    ? await this.getLastCustomerMessageTime(groupId, customerId)
                    : undefined;
                if (!lastCustTime)
                    return "🟡";
                const waitMs = now - lastCustTime;
                if (waitMs < 5 * 60_000)
                    return "🆕";
                if (waitMs < 2 * 3600_000)
                    return "🟡";
                return "🔴";
            }
            case "GROK":
                return "🤖";
            case "TEAM-PENDING":
                return "👋";
            case "TEAM": {
                // Check if customer follow-up unanswered > 2h
                const lastCustTime = customerId
                    ? await this.getLastCustomerMessageTime(groupId, customerId)
                    : undefined;
                if (lastCustTime && lastTeamGrokTime && lastCustTime > lastTeamGrokTime) {
                    return (now - lastCustTime > 2 * 3600_000) ? "⏰" : "💬";
                }
                return "💬";
            }
            default:
                return "🟡";
        }
    }
    async computeWaitTime(groupId, _state, customerId) {
        const now = Date.now();
        const completeMs = this.config.completeHours * 3600_000;
        const lastTeamGrokTime = await this.getLastTeamOrGrokMessageTime(groupId);
        if (lastTeamGrokTime) {
            const lastCustTime = customerId
                ? await this.getLastCustomerMessageTime(groupId, customerId)
                : undefined;
            if (!lastCustTime || lastCustTime < lastTeamGrokTime) {
                if (now - lastTeamGrokTime >= completeMs)
                    return "done";
            }
        }
        const lastCustTime = customerId
            ? await this.getLastCustomerMessageTime(groupId, customerId)
            : undefined;
        if (!lastCustTime)
            return "<1m";
        return this.formatDuration(now - lastCustTime);
    }
    stateLabel(state) {
        switch (state) {
            case "QUEUE": return "Queue";
            case "GROK": return "Grok";
            case "TEAM-PENDING": return "Team – pending";
            case "TEAM": return "Team";
            default: return "Queue";
        }
    }
    buildPreview(chatItems, customerName, customerId) {
        const maxTotal = 500;
        const maxPer = 200;
        // Collect entries in chronological order (oldest first)
        const entries = [];
        for (const ci of chatItems) {
            if (ci.chatDir.type === "groupSnd")
                continue;
            let text = (popopx_chat_1.util.ciContentText(ci)?.trim() || "").replace(/\n+/g, " ");
            const mediaLabel = contentTypeLabel(ci);
            if (mediaLabel && !text)
                text = mediaLabel;
            else if (mediaLabel)
                text = `${mediaLabel} ${text}`;
            if (!text)
                continue;
            let senderId = "";
            let name = "";
            if (ci.chatDir.type === "groupRcv") {
                const member = ci.chatDir.groupMember;
                const contactId = member.memberContactId;
                senderId = member.memberId;
                if (this.config.grokContactId !== null && contactId === this.config.grokContactId) {
                    name = "Grok";
                }
                else if (customerId && member.memberId === customerId) {
                    name = customerName;
                }
                else {
                    name = member.memberProfile.displayName;
                }
            }
            entries.push({ senderId, name, text: truncateMsg(text, maxPer) });
        }
        // Compute prefixed lines in chronological order (sender prefix on first msg of each run)
        const lines = [];
        let lastSenderId = "";
        for (const entry of entries) {
            let line = entry.text;
            if (entry.senderId !== lastSenderId && entry.name) {
                line = `${entry.name}: ${line}`;
                lastSenderId = entry.senderId;
            }
            lines.push({ line, senderId: entry.senderId, name: entry.name });
        }
        // Take from the end (newest) until maxTotal exceeded — oldest messages are truncated
        const selected = [];
        let totalLen = 0;
        let firstSelectedIdx = lines.length;
        for (let i = lines.length - 1; i >= 0; i--) {
            if (totalLen + lines[i].line.length > maxTotal && selected.length > 0) {
                break;
            }
            selected.push(lines[i].line);
            totalLen += lines[i].line.length;
            firstSelectedIdx = i;
        }
        selected.reverse();
        // If truncation happened, ensure the first visible message has a sender prefix
        if (firstSelectedIdx > 0 && selected.length > 0) {
            const first = lines[firstSelectedIdx];
            if (first.name && !selected[0].startsWith(`${first.name}: `)) {
                selected[0] = `${first.name}: ${selected[0]}`;
            }
            selected.unshift("[truncated]");
        }
        const preview = selected.map(escapeStyledMarkdown).join(" !3 /! ");
        return preview ? `"${preview}"` : '""';
    }
    formatDuration(ms) {
        if (ms < 60_000)
            return "<1m";
        if (ms < 3_600_000)
            return `${Math.floor(ms / 60_000)}m`;
        if (ms < 86_400_000)
            return `${Math.floor(ms / 3_600_000)}h`;
        return `${Math.floor(ms / 86_400_000)}d`;
    }
}
exports.CardManager = CardManager;
//# sourceMappingURL=cards.js.map