"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.profileMutex = void 0;
exports.isChatNotFound = isChatNotFound;
exports.getGroupInfo = getGroupInfo;
exports.getContact = getContact;
exports.isWeekend = isWeekend;
exports.log = log;
exports.logError = logError;
const async_mutex_1 = require("async-mutex");
const popopx_chat_1 = require("popopx-chat");
const types_1 = require("@popopx-chat/types");
exports.profileMutex = new async_mutex_1.Mutex();
function isChatNotFound(err, kind) {
    if (!(err instanceof popopx_chat_1.core.ChatAPIError))
        return false;
    if (err.chatError?.type !== "errorStore")
        return false;
    const seType = err.chatError.storeError.type;
    return kind === "group" ? seType === "groupNotFound" : seType === "contactNotFound";
}
async function getGroupInfo(chat, groupId) {
    try {
        const c = await chat.apiGetChat(types_1.T.ChatType.Group, groupId, 0);
        return c.chatInfo.type === "group" ? c.chatInfo.groupInfo : null;
    }
    catch (err) {
        if (isChatNotFound(err, "group"))
            return null;
        throw err;
    }
}
async function getContact(chat, contactId) {
    try {
        const c = await chat.apiGetChat(types_1.T.ChatType.Direct, contactId, 0);
        return c.chatInfo.type === "direct" ? c.chatInfo.contact : null;
    }
    catch (err) {
        if (isChatNotFound(err, "contact"))
            return null;
        throw err;
    }
}
function isWeekend(timezone) {
    const day = new Intl.DateTimeFormat("en-US", { timeZone: timezone, weekday: "short" }).format(new Date());
    return day === "Sat" || day === "Sun";
}
function log(msg, ...args) {
    const ts = new Date().toISOString();
    if (args.length > 0) {
        console.log(`[${ts}] ${msg}`, ...args);
    }
    else {
        console.log(`[${ts}] ${msg}`);
    }
}
function logError(msg, err) {
    const ts = new Date().toISOString();
    console.error(`[${ts}] ERROR: ${msg}`, err);
}
//# sourceMappingURL=util.js.map