# POPOPX Chat Developer Notes

This document contains important technical notes for developers working on the POPOPX Chat codebase.

## GHC 9.6.3 Optimizer Bug Workaround

### Issue

When compiling the test suite with GHC 9.6.3 using optimization levels `-O1` or `-O2`, the test runtime crashes with:

```
internal error: scavenge_stack: weird activation record found on stack: 2497353
```

This is a known GHC optimizer bug that occurs during garbage collection in specific code patterns present in the test suite.

### Solution

The test suite in `popopx-chat.cabal` (line 736) uses `-O0` (no optimization) to work around this bug:

```cabal
-- NOTE: Using -O0 to work around GHC 9.6.3 optimizer bug (scavenge_stack error)
ghc-options: -O0 -Weverything ...
```

**Important**: The production library and executables still use `-O2` for optimal performance. Only the test suite uses `-O0`.

### Future Maintenance

When upgrading to GHC 9.8 or later:
1. Try removing the `-O0` flag from the test suite
2. Test with `-O2` to see if the bug is fixed
3. If tests pass without crashing, you can restore the original optimization level

### Related Files

- `popopx-chat.cabal` - Test suite configuration
- `PROJECT_MEMORY_TEST_FIXES.md` - Detailed fix documentation

---

## API Documentation Requirements

### Overview

POPOPX Chat uses Template Haskell to automatically generate API documentation from the Haskell type definitions. When adding new features, you must update the documentation in three places:

1. **Commands** - `bots/src/API/Docs/Commands.hs`
2. **Responses** - `bots/src/API/Docs/Responses.hs`
3. **Types** - `bots/src/API/Docs/Types.hs`

### Adding New API Commands

When you add a new command to `src/Popopx/Chat/Controller.hs`:

1. **Add command documentation** in `bots/src/API/Docs/Commands.hs`:
   - Find the appropriate command category (or create a new one)
   - Add the command with its parameters, responses, and syntax
   - Example:
   ```haskell
   ("APIYourNewCommand", [], "Description of what it does.", 
     ["CRYourResponse", "CRChatCmdError"], [], Nothing, 
     "/_your_command " <> Param "param1" <> " " <> Json "param2")
   ```

2. **Add response documentation** in `bots/src/API/Docs/Responses.hs`:
   - Add your response constructor to `chatResponsesDocsData` with a description
   - Remove it from `undocumentedResponses` if it was there
   - Example:
   ```haskell
   ("CRYourResponse", "Description of the response")
   ```

3. **Add type documentation** in `bots/src/API/Docs/Types.hs` (if needed):
   - If your command/response uses new types, add them to `chatTypesDocsData`
   - Ensure the type has a `Generic` instance
   - Example:
   ```haskell
   deriving instance Generic YourNewType
   -- ...
   (sti @YourNewType, STRecord, "", [], "", "")
   ```

### Handling NoJSON Fields

If a type contains a field wrapped in `NoJSON` (meaning it shouldn't be serialized to JSON), you must exclude it from API documentation:

```haskell
-- In bots/src/API/Docs/Types.hs
(removeField "fieldName" $ sti @TypeName, STRecord, "", [], "", "")
```

**Example**: The `GroupMember` type has `memberBadgeProof :: NoJSON BadgeProof`, which is excluded using:
```haskell
(removeField "memberBadgeProof" $ sti @GroupMember, STRecord, "", [], "", "")
```

### POPOPX-Specific Command Categories

POPOPX adds several command categories not present in upstream SimpleX Chat:

1. **BinThere bot commands** - Bot directory and management system
   - `APIListBinThereBots`
   - `APIAddBinThereBot`
   - `APIUpdateBinThereBot`
   - `APIDeleteBinThereBot`

2. **Badge purchase commands** - Supporter badge system
   - `APICreateBadgeInvoice`
   - `APIPurchaseBadge`

3. **Group commands** (extended)
   - `APIAddMemberViaGroup` - Add member via group invitation

When adding new POPOPX-specific features, create appropriate command categories in `Commands.hs`.

### Testing API Documentation

Run the API documentation tests to verify completeness:

```bash
# Build test suite with -O0 (required for GHC 9.6.3)
cabal build test:popopx-chat-test --ghc-options="-O0"

# Run only API docs tests
./dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopx-chat-7.1.0.14/t/popopx-chat-test/build/popopx-chat-test/popopx-chat-test -m "Bot API docs"
```

Expected output:
```
Bot API docs
  API commands
Documented commands: 67/358
    should be documented [✔]
    should have field names [✔]
    should have defined responses [✔]
```

**Note**: The test suite may crash after these tests pass due to the GHC optimizer bug mentioned above. This is a known issue and doesn't affect the validity of the API documentation tests.

---

## Upstream Sync Notes

### Module Naming

All modules use `Popopx.Chat.*` instead of upstream's `Simplex.Chat.*`. When syncing:

```bash
# Replace module names
find src -name "*.hs" -exec sed -i 's/Simplex\.Chat/Popopx.Chat/g' {} \;
find src -name "*.hs" -exec sed -i 's/simplex-chat/popopx-chat/g' {} \;
```

### MQ Library

POPOPX uses `popopxmq` (fork) instead of `simplexmq`. In `cabal.project`:

```
source-package ../popopxmq/popopxmq.cabal
```

**Important**: Function names may differ between forks. For example:
- Upstream: `resolvePopopxName`
- POPOPX: `resolvePoName`

Always check function signatures after syncing.

### POPOPX-Specific Features (DO NOT REMOVE)

These features are unique to POPOPX and must be preserved during upstream syncs:

1. **burnAfterRead** - Read-after-burn messaging with TTL
2. **BinThere bots** - Bot system with API commands
3. **Custom FFI exports** - `cChatMigrateInitKeyBytes`, migration logging
4. **peerType/chat_peer_type** - Profile peer type field
5. **LinkEncryption** - Custom encryption module
6. **RemoteConfig** - Remote configuration module
7. **Database migrations**:
   - `M20260905_binthere_bots`
   - `M20260906_bot_directory`
   - `M20261009_binthere_bar_flag`
   - `M20261012_delivery_job_notification`
   - `M20261016_badge_store_receipts`
   - `M20261018_autoincrement_ids`

---

## Build Commands

### Development Build

```bash
# Build all targets
cabal build

# Build with Swift JSON format (for iOS)
cabal build --flag swift

# Build client library only
cabal build --flag client_library

# Build with PostgreSQL instead of SQLite
cabal build --flag client_postgres
```

### Testing

```bash
# Run all tests (may crash due to GHC bug)
cabal test

# Run specific test suite
cabal test --test-show-details=direct

# Run with explicit -O0 (workaround for GHC 9.6.3)
cabal build test:popopx-chat-test --ghc-options="-O0"
./dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopx-chat-7.1.0.14/t/popopx-chat-test/build/popopx-chat-test/popopx-chat-test
```

### Code Formatting

```bash
# Install fourmolu
cabal install fourmolu

# Format Haskell files
fourmolu --mode inplace src/**/*.hs
fourmolu --mode inplace tests/**/*.hs
fourmolu --mode inplace bots/src/**/*.hs
```

---

## Known Issues

### 1. Test Suite Crashes

**Symptom**: Segmentation fault (exit code 139) during test execution  
**Cause**: GHC 9.6.3 optimizer bug  
**Workaround**: Use `-O0` for test compilation  
**Status**: Affects cleanup/exit, not test correctness  

### 2. Redundant Constraint Warnings

**Symptom**: Warnings about `UserProtocol p` being redundant in `Popopx.Chat.Operators`  
**Cause**: Upstream code pattern, not a bug  
**Status**: Safe to ignore, does not affect functionality  

### 3. SQLCipher Compatibility

**Symptom**: Schema dump test skipped  
**Cause**: SQLCipher compatibility issue in test environment  
**Status**: Does not affect production builds  

---

## Resources

- **Project Memory**: `PROJECT_MEMORY_TEST_FIXES.md` - Detailed fix documentation
- **AGENTS.md**: Build commands, code style, and architecture overview
- **Upstream Repository**: `/home/ubuntu/simplex-chat` (local) or https://github.com/simplex-chat/simplex-chat
- **GHC Bug Tracker**: https://www.haskell.org/ghc/reportabug

---

**Last Updated**: 2026-10-20  
**GHC Version**: 9.6.3  
**POPOPX Version**: 7.1.0.14
