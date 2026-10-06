import { api } from "popopx-chat";
export interface IdName {
    id: number;
    name: string;
}
export type Backend = "sqlite" | "postgres";
export interface Config {
    stateFile: string;
    db: api.DbConfig;
    teamGroup: IdName;
    teamMembers: IdName[];
    grokContactId: number | null;
    timezone: string;
    completeHours: number;
    cardFlushSeconds: number;
    contextFile: string | null;
    grokApiKey: string | null;
}
export declare function detectBackend(): Backend;
export declare function parseIdName(s: string): IdName;
export declare function parseConfig(args: string[]): Config;
