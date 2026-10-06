import WebSocket from 'ws';

interface PendingCommand {
  resolve: (response: any) => void;
  reject: (error: Error) => void;
  timeout: NodeJS.Timeout;
}

type EventHandler = (eventType: string, eventData: any) => void;

export class PopopxChatClient {
  private ws: WebSocket | null = null;
  private port: number;
  private pendingCommands: Map<string, PendingCommand> = new Map();
  private eventHandlers: EventHandler[] = [];
  private reconnectTimer: NodeJS.Timeout | null = null;
  private userId: number | null = null;
  private commandCounter = 0;

  constructor(port: number = 5225) {
    this.port = port;
  }

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      const url = `ws://localhost:${this.port}`;
      console.log(`[POPOPX] Connecting to chat CLI at ${url}...`);

      this.ws = new WebSocket(url);

      this.ws.on('open', () => {
        console.log('[POPOPX] Connected to chat CLI WebSocket');
        resolve();
      });

      this.ws.on('message', (data: WebSocket.Data) => {
        this.handleMessage(data.toString());
      });

      this.ws.on('error', (err: Error) => {
        console.error('[POPOPX] WebSocket error:', err.message);
        if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
          reject(err);
        }
      });

      this.ws.on('close', () => {
        console.log('[POPOPX] WebSocket closed, reconnecting in 5s...');
        this.rejectAllPending('WebSocket closed');
        this.scheduleReconnect();
      });
    });
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(async () => {
      this.reconnectTimer = null;
      try {
        await this.connect();
        await this.initialize();
      } catch (err) {
        console.error('[POPOPX] Reconnect failed:', err);
        this.scheduleReconnect();
      }
    }, 5000);
  }

  private handleMessage(raw: string): void {
    let msg: any;
    try {
      msg = JSON.parse(raw);
    } catch {
      console.error('[POPOPX] Invalid JSON:', raw.substring(0, 200));
      return;
    }

    if (msg.corrId && this.pendingCommands.has(msg.corrId)) {
      const pending = this.pendingCommands.get(msg.corrId)!;
      clearTimeout(pending.timeout);
      this.pendingCommands.delete(msg.corrId);
      pending.resolve(msg.resp);
      return;
    }

    if (msg.resp) {
      this.emitEvent(msg.resp.type, msg.resp);
    }
  }

  private emitEvent(type: string, data: any): void {
    for (const handler of this.eventHandlers) {
      try {
        handler(type, data);
      } catch (err) {
        console.error('[POPOPX] Event handler error:', err);
      }
    }
  }

  onEvent(handler: EventHandler): void {
    this.eventHandlers.push(handler);
  }

  async sendCommand(cmd: string, timeoutMs: number = 30000): Promise<any> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket not connected');
    }

    const corrId = `cmd_${++this.commandCounter}_${Date.now()}`;
    const payload = JSON.stringify({ corrId, cmd });

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingCommands.delete(corrId);
        reject(new Error(`Command timeout: ${cmd.substring(0, 50)}`));
      }, timeoutMs);

      this.pendingCommands.set(corrId, { resolve, reject, timeout });
      this.ws!.send(payload);
    });
  }

  private rejectAllPending(reason: string): void {
    for (const [, pending] of this.pendingCommands) {
      clearTimeout(pending.timeout);
      pending.reject(new Error(reason));
    }
    this.pendingCommands.clear();
  }

  async initialize(): Promise<void> {
    console.log('[POPOPX] Initializing bot...');

    try {
      const userResp = await this.sendCommand('/user');
      if (userResp.type === 'activeUser' && userResp.user) {
        this.userId = userResp.user.userId;
        console.log(`[POPOPX] Active user: ${userResp.user.displayName} (id=${this.userId})`);
      }
    } catch (err) {
      console.error('[POPOPX] Failed to get active user:', err);
      return;
    }

    if (!this.userId) {
      console.error('[POPOPX] No active user, cannot initialize');
      return;
    }

    try {
      const addrResp = await this.sendCommand(`/_show_address ${this.userId}`);
      if (addrResp.type === 'userContactLink') {
        console.log('[POPOPX] Address exists:', addrResp.contactLink?.contactLinkUri?.substring(0, 60) + '...');
      } else if (addrResp.type === 'chatCmdError') {
        console.log('[POPOPX] No address found, creating...');
        const createResp = await this.sendCommand(`/_address ${this.userId}`);
        if (createResp.type === 'userContactLinkCreated') {
          console.log('[POPOPX] Address created');
        } else {
          console.error('[POPOPX] Failed to create address:', createResp);
        }
      }
    } catch (err) {
      console.error('[POPOPX] Address check failed:', err);
    }

    try {
      await this.sendCommand(`/_address_settings ${this.userId} {"autoAccept":true}`);
      console.log('[POPOPX] Auto-accept enabled');
    } catch {
      // auto-accept may already be enabled or settings format may differ
    }

    console.log('[POPOPX] Initialization complete');
  }

  async sendMessage(chatRef: string, text: string): Promise<void> {
    const composedMessage = {
      msgContent: { type: 'text', text }
    };
    const cmd = `/_send ${chatRef} json [${JSON.stringify(composedMessage)}]`;
    const resp = await this.sendCommand(cmd);
    if (resp.type === 'chatCmdError') {
      console.error('[POPOPX] Send failed:', resp);
    }
  }

  async sendJsonMessage(chatRef: string, data: object): Promise<void> {
    const text = JSON.stringify(data);
    await this.sendMessage(chatRef, text);
  }

  getUserId(): number | null {
    return this.userId;
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.rejectAllPending('Disconnecting');
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

export const popopxChatClient = new PopopxChatClient(5225);
