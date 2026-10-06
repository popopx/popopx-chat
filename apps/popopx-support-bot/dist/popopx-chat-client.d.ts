type EventHandler = (eventType: string, eventData: any) => void;
export declare class PopopxChatClient {
    private ws;
    private port;
    private pendingCommands;
    private eventHandlers;
    private reconnectTimer;
    private userId;
    private commandCounter;
    constructor(port?: number);
    connect(): Promise<void>;
    private scheduleReconnect;
    private handleMessage;
    private emitEvent;
    onEvent(handler: EventHandler): void;
    sendCommand(cmd: string, timeoutMs?: number): Promise<any>;
    private rejectAllPending;
    initialize(): Promise<void>;
    sendMessage(chatRef: string, text: string): Promise<void>;
    sendJsonMessage(chatRef: string, data: object): Promise<void>;
    getUserId(): number | null;
    disconnect(): void;
}
export declare const popopxChatClient: PopopxChatClient;
export {};
