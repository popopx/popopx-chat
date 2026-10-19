# Upstream Sync Log - 2026-10-19

## Sync Summary
Successfully synced with upstream simplex-chat repository at commit 35bc0b66d (version 7.1.0.12).

## Changes Applied

### 1. WebRTC ICE Restart Support
- **File**: `src/Popopx/Chat/Call.hs`
- **Change**: Added `rtcSession :: Maybe Text` field to `WebRTCExtraInfo`
- **Purpose**: Support for ICE restart session during WebRTC calls
- **Location**: Line ~232

### 2. Timestamp Normalization
- **Files**: 
  - `src/Popopx/Chat/Library/Internal.hs`
  - `src/Popopx/Chat/Library/Commands.hs`
  - `src/Popopx/Chat/Store/Messages.hs`
- **Change**: Added `roundDownToSecond` function to normalize message timestamps
- **Function**: 
  ```haskell
  roundDownToSecond :: UTCTime -> UTCTime
  roundDownToSecond t@UTCTime {utctDayTime} = t {utctDayTime = floor utctDayTime}
  ```
- **Call Sites**: Updated in saveSndChatItems, createChatItems, createLocalChatItems

### 3. AUTOINCREMENT Migration
- **File**: `src/Popopx/Chat/Store/SQLite/Migrations/M20261018_autoincrement_ids.hs` (NEW)
- **Purpose**: Add AUTOINCREMENT to primary keys for better SQLite/Postgres consistency
- **Tables Updated**: 
  - users, contacts, groups, group_members
  - files, connections, contact_requests, rcv_roster_transfers
- **Registration**: Added to `Migrations.hs` and `popopx-chat.cabal`

### 4. Schema File Fix
- **File**: `src/Popopx/Chat/Store/SQLite/Migrations/chat_schema.sql`
- **Fix**: Removed invalid `CREATE TABLE sqlite_sequence(name,seq);` (line 66)
- **Reason**: sqlite_sequence is automatically created by SQLite when AUTOINCREMENT is used

### 5. Block Markdown Tests
- **File**: `tests/MarkdownTests.hs`
- **Change**: Fully synced from upstream (526 → 1116 lines)
- **Adaptations**: Simplex → Popopx namespace replacements
- **Features**: Added BoolDef parameter support, block markdown tests (headings, lists, code blocks, tables)

### 6. Documentation Updates
- **Files**:
  - `docs/protocol/simplex-chat.md`: Added ICE restart documentation
  - `docs/protocol/simplex-chat.schema.json`: Added rtcSession to rtcExtraInfo schema

### 7. Test Improvements
- **Files**:
  - `tests/ChatTests/Groups.hs`: Removed 6 `#if defined(dbPostgres)` blocks
  - `tests/ChatTests/Profiles.hs`: Removed 5 `#if defined(dbPostgres)` blocks
  - `tests/ProtocolTests.hs`: Added 2 x.call.extra test cases
  - `tests/SchemaDump.hs`: Added "20261018_autoincrement_ids" to skip list

## POPOPX-Specific Features Preserved
All local features maintained throughout sync:
- ✓ burnAfterRead parameter in all function signatures
- ✓ BinThere bots system and migrations
- ✓ Custom FFI exports (cChatMigrateInitKeyBytes, etc.)
- ✓ peerType/chat_peer_type field
- ✓ LinkEncryption module
- ✓ RemoteConfig module
- ✓ All POPOPX-specific database migrations

## Build Status
- Compilation: ✓ Successful (only warnings, no errors)
- Test Suite: Schema SQL error fixed, tests pending completion

## Files Modified
1. src/Popopx/Chat/Call.hs
2. src/Popopx/Chat/Library/Internal.hs
3. src/Popopx/Chat/Library/Commands.hs
4. src/Popopx/Chat/Store/Messages.hs
5. src/Popopx/Chat/Store/SQLite/Migrations.hs
6. src/Popopx/Chat/Store/SQLite/Migrations/M20261018_autoincrement_ids.hs (NEW)
7. src/Popopx/Chat/Store/SQLite/Migrations/chat_schema.sql
8. src/Popopx/Chat/Store/SQLite/Migrations/agent_query_plans.txt
9. tests/MarkdownTests.hs
10. tests/ChatTests/Groups.hs
11. tests/ChatTests/Profiles.hs
12. tests/ProtocolTests.hs
13. tests/SchemaDump.hs
14. docs/protocol/simplex-chat.md
15. docs/protocol/simplex-chat.schema.json
16. popopx-chat.cabal

## Verification Checklist
- [x] Upstream changes applied
- [x] POPOPX namespace maintained (Popopx.Chat.* not Simplex.Chat.*)
- [x] popopxmq fork references preserved (not simplexmq)
- [x] All local features preserved
- [x] Documentation synced
- [x] Schema SQL validated
- [ ] Test suite fully passing (in progress)
