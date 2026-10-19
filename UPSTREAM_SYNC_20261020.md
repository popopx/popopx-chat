# Upstream Sync Log - 2026-10-20

## Sync Summary
Successfully synced with upstream simplex-chat repository from version 7.1.0.12 to 7.1.0.14.

**Commit**: `8e2fc440e`  
**Previous version**: 7.1.0.12  
**New version**: 7.1.0.14  
**popopxmq tag**: `84a10d06f59fc98fb8d392622490309f7c2b9cbc`

## Changes Applied

### 1. Version Bump
- **File**: `popopx-chat.cabal`
- **Change**: Version `7.1.0.12` → `7.1.0.14`

### 2. popopxmq Update
- **File**: `cabal.project`
- **Change**: Updated popopxmq tag from `a1c48854b11d8659b8a5eb7b77d784e8841b2646` to `84a10d06f59fc98fb8d392622490309f7c2b9cbc`
- **Purpose**: Sync with upstream simplexmq v7.1.0.14

### 3. Schema Fix - sqlite_sequence Table
- **File**: `src/Popopx/Chat/Store/SQLite/Migrations/chat_schema.sql`
- **Change**: Added `CREATE TABLE sqlite_sequence(name,seq);` after users table definition
- **Purpose**: Required by AUTOINCREMENT feature added in v7.1.0.12 sync
- **Note**: Previous sync (2026-10-19) incorrectly removed this line. SQLite automatically creates this table when AUTOINCREMENT is used, but the schema dump must include it for consistency.

### 4. Nix Build Configuration Cleanup
- **File**: `scripts/nix/sha256map.nix`
- **Changes**:
  - Removed 3 stale local file:// paths (`file:///Users/elliot/POPOPX/popopxmq`)
  - Removed 3 old popopxmq tag hashes (`f6fac82`, `cb189f9`, `fd72854`)
  - Added new hash for tag `84a10d06f`: `191x2a3v23sa8pdhcjvmnac2niph2wzq1vapiav2jvkqsww7m2kw`
- **Purpose**: Clean up development artifacts and update to current popopxmq version

## Upstream Changes Since Last Sync (v7.1.0.12 → v7.1.0.14)

The following upstream commits were already synced in v7.1.0.12 (2026-10-19) but version bump to 7.1.0.14 was missed:

1. **`3e6fd3836`** - core: round down time of sent messages
   - Already synced: `roundDownToSecond` function in Internal.hs, Commands.hs, Messages.hs
   
2. **`58bc94bc7`** - core: carry ICE restart session in call extra info
   - Already synced: `rtcSession :: Maybe Text` field in Call.hs
   
3. **`634fa5ecf`** - core: autoincrement database IDs
   - Already synced: M20261018_autoincrement_ids.hs migration
   
4. **`5a02b906e`** - core: 7.1.0.14 (simplexmq 7.1.0.14)
   - **This sync**: Version bump and popopxmq tag update

## POPOPX-Specific Features Preserved

All local features maintained throughout sync:
- ✓ burnAfterRead parameter threading in chat item creation functions
- ✓ BinThere AR flag (bar) in APISendMessages and message sending pipeline
- ✓ PopopxDomain/PopopxName types (renamed from SimplexDomain/SimplexName)
- ✓ PopopXCallMediaKey constant (renamed from SimpleXCallMediaKey)
- ✓ BinThere migrations (M20260905, M20260906, M20261009)
- ✓ LinkEncryption module
- ✓ RemoteConfig module
- ✓ Custom FFI exports (cChatMigrateInitKeyBytes, etc.)
- ✓ peerType/chat_peer_type field
- ✓ All POPOPX-specific database migrations

## Build Configuration Verification

### Verified Consistent with Upstream
- ✓ flake.nix: Only namespace differences (popopx vs simplex)
- ✓ Nix patches: POPOPX-specific patches preserved (popopxmq-base64url-decodeLenient.patch, popopxmq-crcv-upgrade-fix.patch)
- ✓ DLL def file: libpopopx.dll.def present
- ✓ Module list: All upstream modules present + POPOPX modules
- ✓ popopxmq dependency: `>=7.0` (higher than upstream's `simplexmq >=6.3`)

### Remaining Simplex References (Intentional)
- Copyright headers: `-- Original Work Copyright (C) 2020-2022 simplex.chat`
  - Correct attribution to original authors, kept as-is

## Files Modified

1. `cabal.project` - popopxmq tag update
2. `popopx-chat.cabal` - version bump
3. `scripts/nix/sha256map.nix` - hash cleanup and update
4. `src/Popopx/Chat/Store/SQLite/Migrations/chat_schema.sql` - sqlite_sequence table

## Verification Checklist

- [x] Upstream changes applied
- [x] Version bumped to 7.1.0.14
- [x] popopxmq tag updated to 84a10d06f
- [x] Nix sha256 hash computed and verified
- [x] POPOPX namespace maintained (Popopx.Chat.* not Simplex.Chat.*)
- [x] popopxmq fork references preserved (not simplexmq)
- [x] All local features preserved
- [x] Build configs aligned with upstream
- [x] Schema SQL validated
- [x] Stale local paths removed from sha256map.nix
- [ ] CI checks passing (queued: Linux, macOS, Windows builds)
- [ ] Test suite fully passing

## CI Status

10 check runs queued:
- ubuntu-24.04-aarch64 (CLI,Desktop), GHC: 9.6.3
- ubuntu-24.04-x86_64 (CLI,Desktop), GHC: 9.6.3
- macos-latest (CLI,Desktop), GHC: 9.6.3
- ubuntu-22.04-aarch64 (CLI,Desktop), GHC: 9.6.3
- ubuntu-22.04-x86_64 (CLI,Desktop), GHC: 8.10.7
- ubuntu-22.04-x86_64 (CLI,Desktop), GHC: 9.6.3
- windows-latest (CLI,Desktop), GHC: 9.6.3
- macos-15-intel (CLI,Desktop), GHC: 9.6.3
- maybe-release
- variables

## Notes

This sync corrects the version number that should have been bumped in the 2026-10-19 sync. The upstream code changes (roundDownToSecond, ICE restart, AUTOINCREMENT) were already present in the codebase, but the version number and popopxmq tag were not updated to reflect v7.1.0.14.

The sqlite_sequence table was incorrectly removed in the previous sync. While SQLite automatically creates this table when AUTOINCREMENT is used, the schema dump file must include it for consistency and documentation purposes.
