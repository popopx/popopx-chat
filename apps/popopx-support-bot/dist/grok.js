"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GrokApiClient = void 0;
const util_js_1 = require("./util.js");
class GrokApiClient {
    apiKey;
    initialContext;
    constructor(apiKey, initialContext) {
        this.apiKey = apiKey;
        this.initialContext = initialContext;
    }
    async chatRaw(messages) {
        const response = await fetch("https://api.x.ai/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.apiKey}`,
            },
            body: JSON.stringify({
                model: "grok-latest",
                messages,
                temperature: 0.3,
                max_tokens: 1024,
            }),
            signal: AbortSignal.timeout(60_000),
        });
        if (!response.ok) {
            const body = await response.text();
            (0, util_js_1.logError)(`Grok API HTTP ${response.status}`, body);
            throw new Error(`Grok API error: HTTP ${response.status}`);
        }
        const data = await response.json();
        const content = data.choices?.[0]?.message?.content;
        if (!content)
            throw new Error("Grok API returned empty response");
        (0, util_js_1.log)(`Grok API response: ${content.length} chars`);
        return content;
    }
    async chat(history, userMessage) {
        (0, util_js_1.log)(`Grok API call: ${this.initialContext.length} context msgs, ${history.length} history msgs, user msg ${userMessage.length} chars`);
        return this.chatRaw([
            ...this.initialContext,
            ...history,
            { role: "user", content: userMessage },
        ]);
    }
}
exports.GrokApiClient = GrokApiClient;
//# sourceMappingURL=grok.js.map