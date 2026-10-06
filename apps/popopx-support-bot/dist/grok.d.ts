export interface GrokMessage {
    role: "system" | "user" | "assistant";
    content: string;
}
export declare class GrokApiClient {
    private readonly apiKey;
    private readonly initialContext;
    constructor(apiKey: string, initialContext: readonly GrokMessage[]);
    chatRaw(messages: GrokMessage[]): Promise<string>;
    chat(history: GrokMessage[], userMessage: string): Promise<string>;
}
