import { T } from "@popopx-chat/types";
import { api } from "popopx-chat";
import { Config } from "./config.js";
export type ConversationState = "WELCOME" | "QUEUE" | "GROK" | "TEAM-PENDING" | "TEAM";
export interface GroupComposition {
    grokMember: T.GroupMember | undefined;
    teamMembers: T.GroupMember[];
}
interface CardData {
    state?: ConversationState;
    cardItemId?: number;
    complete?: boolean;
}
export declare class CardManager {
    private chat;
    private config;
    private mainUserId;
    private pendingUpdates;
    private flushInterval;
    private customDataMutexes;
    constructor(chat: api.ChatApi, config: Config, mainUserId: number, flushIntervalMs?: number);
    private withMainProfile;
    private getCustomDataMutex;
    scheduleUpdate(groupId: number): void;
    createCard(groupId: number, groupInfo: T.GroupInfo): Promise<void>;
    flush(): Promise<void>;
    private flushOne;
    refreshAllCards(): Promise<void>;
    destroy(): void;
    getGroupComposition(groupId: number): Promise<GroupComposition>;
    deriveState(groupId: number): Promise<ConversationState>;
    getLastCustomerMessageTime(groupId: number, customerId: string): Promise<number | undefined>;
    getLastTeamOrGrokMessageTime(groupId: number): Promise<number | undefined>;
    getRawCustomData(groupId: number): Promise<Partial<CardData> | null>;
    mergeCustomData(groupId: number, patch: Partial<CardData>): Promise<void>;
    clearCustomData(groupId: number): Promise<void>;
    getChat(groupId: number, count: number): Promise<T.AChat>;
    private updateCard;
    private composeCard;
    private computeIcon;
    private computeWaitTime;
    private stateLabel;
    private buildPreview;
    private formatDuration;
}
export {};
