"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.grokNoHistoryMessage = exports.grokErrorMessage = exports.grokUnavailableMessage = exports.grokInvitingMessage = exports.teamLockedMessage = exports.teamAlreadyInvitedMessage = exports.grokActivatedMessage = exports.welcomeMessage = void 0;
exports.queueMessage = queueMessage;
exports.teamAddedMessage = teamAddedMessage;
exports.noTeamMembersMessage = noTeamMembersMessage;
const util_js_1 = require("./util.js");
exports.welcomeMessage = `Hello! This is a *POPOPX team* support bot - not an AI.
*Join public groups* at https://popopx.chat/directory or [via directory bot](https://smp4.popopx.im/a#lXUjJW5vHYQzoLYgmi8GbxkGP41_kjefFvBrdwg-0Ok)

We just launched [equity crowdfunding on Wefunder](https://wefunder.com/popopx.chat)!

Please ask any questions about POPOPX Chat and about our crowdfunding.`;
function queueMessage(timezone, grokEnabled) {
    const hours = (0, util_js_1.isWeekend)(timezone) ? "48" : "24";
    const base = `The team will reply to your message within ${hours} hours.`;
    if (!grokEnabled)
        return base;
    return `${base}

If your question is about POPOPX, click /grok for an *instant Grok answer*.

Send /team to switch back.`;
}
exports.grokActivatedMessage = `*You are now chatting with Grok* - use any language.`;
function teamAddedMessage(timezone, grokPresent) {
    const hours = (0, util_js_1.isWeekend)(timezone) ? "48" : "24";
    const base = `We will reply within ${hours} hours.`;
    if (!grokPresent)
        return base;
    return `${base}
Grok will be answering your questions until then.`;
}
exports.teamAlreadyInvitedMessage = "A team member was invited to this conversation and will reply when available.";
exports.teamLockedMessage = "Only the team will now receive your messages.";
function noTeamMembersMessage(grokEnabled) {
    return grokEnabled
        ? "No team members are available yet. Please try again later or click /grok."
        : "No team members are available yet. Please try again later.";
}
exports.grokInvitingMessage = "Inviting Grok, please wait...";
exports.grokUnavailableMessage = "Grok is temporarily unavailable. Please try again later or send /team for a human team member.";
exports.grokErrorMessage = "Sorry, I couldn't process that. Please try again or send /team for a human team member.";
exports.grokNoHistoryMessage = "I just joined but couldn't see your earlier messages. Could you repeat your question?";
//# sourceMappingURL=messages.js.map