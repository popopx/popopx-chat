"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.detectBackend = detectBackend;
exports.parseIdName = parseIdName;
exports.parseConfig = parseConfig;
const commander_1 = require("commander");
// Mirrors packages/popopx-chat-nodejs/src/download-libs.js so runtime detection
// matches what was used at install time. Works whether the user installed via
// POPOPX_BACKEND env var, .npmrc (→ npm_config_popopx_backend), or the
// --popopx_backend=postgres CLI flag (also surfaced as npm_config_*).
function detectBackend() {
    const raw = (process.env.POPOPX_BACKEND || process.env.npm_config_popopx_backend || "sqlite").toLowerCase();
    if (raw !== "sqlite" && raw !== "postgres") {
        throw new Error(`Invalid POPOPX_BACKEND: "${raw}". Must be "sqlite" or "postgres".`);
    }
    return raw;
}
function parseIdName(s) {
    const i = s.indexOf(":");
    if (i < 1)
        throw new Error(`Invalid ID:name format: "${s}"`);
    const id = parseInt(s.slice(0, i), 10);
    if (isNaN(id))
        throw new Error(`Invalid ID:name format (non-numeric ID): "${s}"`);
    return { id, name: s.slice(i + 1) };
}
function parseNonNegativeInt(flag) {
    return (raw) => {
        const n = parseInt(raw, 10);
        if (!Number.isFinite(n) || n < 0) {
            throw new Error(`${flag} must be a non-negative integer, got "${raw}"`);
        }
        return n;
    };
}
function buildCommand() {
    return new commander_1.Command()
        .name("popopx-chat-support-bot")
        .description("business-address triage bot")
        .requiredOption("--team-group <name>", "team group display name")
        .option("--state-file <path>", "state JSON path", "./data/state.json")
        .option("--sqlite-file-prefix <path>", "SQLite DB file prefix", "./data/popopx")
        .option("--sqlite-key <key>", "SQLCipher encryption key (default: unencrypted)")
        .option("--pg-conn <conn>", "PostgreSQL connection string (required for postgres)")
        .option("--pg-schema <prefix>", "PostgreSQL schema prefix (default: popopx_v1)")
        .option("-a, --auto-add-team-members <list>", "comma-separated ID:name pairs (e.g. 1:Alice,2:Bob)")
        .option("--timezone <iana>", "IANA timezone for weekend detection", "UTC")
        .option("--complete-hours <n>", "auto-complete chats after N hours idle (0 disables)", parseNonNegativeInt("--complete-hours"), 3)
        .option("--card-flush-seconds <n>", "debounce card state writes", parseNonNegativeInt("--card-flush-seconds"), 300)
        .option("--context-file <path>", "text file with Grok system context (required if GROK_API_KEY set)")
        .addHelpText("after", "\nEnvironment:\n  GROK_API_KEY     xAI API key — enables Grok replies\n  POPOPX_BACKEND  sqlite | postgres — alternative to .npmrc for backend selection\n");
}
function parseConfig(args) {
    const cmd = buildCommand().exitOverride();
    try {
        cmd.parse(args, { from: "user" });
    }
    catch (err) {
        const code = err.code;
        if (code === "commander.helpDisplayed" || code === "commander.version")
            process.exit(0);
        throw err;
    }
    const opts = cmd.opts();
    const grokApiKey = process.env.GROK_API_KEY || null;
    const backend = detectBackend();
    let db;
    if (backend === "sqlite") {
        db = opts.sqliteKey
            ? { type: "sqlite", filePrefix: opts.sqliteFilePrefix, encryptionKey: opts.sqliteKey }
            : { type: "sqlite", filePrefix: opts.sqliteFilePrefix };
    }
    else {
        if (!opts.pgConn) {
            throw new Error("--pg-conn is required when backend is postgres (PostgreSQL connection string)");
        }
        db = opts.pgSchema
            ? { type: "postgres", connectionString: opts.pgConn, schemaPrefix: opts.pgSchema }
            : { type: "postgres", connectionString: opts.pgConn };
    }
    const teamGroup = { id: 0, name: opts.teamGroup };
    const teamMembersRaw = opts.autoAddTeamMembers ?? "";
    const teamMembers = teamMembersRaw
        ? teamMembersRaw.split(",").map(parseIdName)
        : [];
    try {
        new Intl.DateTimeFormat("en-US", { timeZone: opts.timezone, weekday: "short" });
    }
    catch (err) {
        throw new Error(`--timezone "${opts.timezone}" is not a valid IANA time zone: ${err.message}`);
    }
    const contextFile = opts.contextFile ?? null;
    if (grokApiKey && !contextFile) {
        throw new Error("GROK_API_KEY is set but --context-file is not provided. Grok requires a context file.");
    }
    return {
        stateFile: opts.stateFile,
        db,
        teamGroup,
        teamMembers,
        grokContactId: null,
        timezone: opts.timezone,
        completeHours: opts.completeHours,
        cardFlushSeconds: opts.cardFlushSeconds,
        contextFile,
        grokApiKey,
    };
}
//# sourceMappingURL=config.js.map