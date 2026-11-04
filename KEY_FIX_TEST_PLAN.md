# SQLCipher Key Transmission Fix - Test Plan

## Problem Summary
iOS was sending pre-derived base64 keys to Haskell, but SQLCipher expected either:
1. A passphrase (which it derives internally with PBKDF2)
2. A raw key in hex format with `x'...'` syntax

This caused double derivation and iteration count mismatches (iOS: 600k, SQLCipher: 256k), resulting in "Wrong database passphrase" errors.

## Changes Made

### 1. Haskell (`popopxmq/src/Popopx/Messaging/Agent/Store/SQLite.hs`)
- Modified `keyString` function to detect hex format keys (`x'...'`)
- When key is in hex format, pass as-is to SQLCipher (raw key mode)
- Otherwise, wrap in quotes for passphrase mode (SQLCipher derives internally)

### 2. iOS API (`apps/ios/POPOPXSwitch/API.swift`)
- Modified `chatMigrateInit` to convert derived keys to hex format when salt exists
- Converts base64-derived key → raw bytes → hex string with `x'...'` prefix
- Ensures SQLCipher uses derived key directly without re-deriving

### 3. Database Encryption (`apps/ios/Shared/Views/Database/DatabaseEncryptionView.swift`)
- Updated `encryptDatabaseAsync` to convert both `currentKey` and `newKey` to hex format when salt exists
- Ensures encryption and re-encryption use consistent key formats

### 4. Migration Verification (`apps/ios/Shared/Views/Migration/PXMigrateFromDevice.swift`)
- Added salt handling in `verifyDatabasePassphrase`
- Derives key before testing if salt exists in KeyChain

## Test Scenarios

### Scenario 1: Fresh Install (No Salt)
**Steps:**
1. Delete app from simulator
2. Reinstall and launch
3. Complete onboarding
4. Check logs for "Opening database" messages

**Expected:**
- Database opens successfully
- Logs show PRAGMA key with quoted passphrase (not hex)
- No "ErrorCorrupt" or "Wrong database passphrase" errors

### Scenario 2: After Key Rotation (With Salt)
**Steps:**
1. Go to Settings > Database Encryption
2. Change passphrase (triggers key rotation with salt)
3. Restart app
4. Check logs

**Expected:**
- Database opens successfully
- Logs show PRAGMA key with hex format: `x'...'`
- Key length should be 64 hex chars (32 bytes)
- No derivation errors

### Scenario 3: Database Re-Encryption
**Steps:**
1. Go to Settings > Database Encryption
2. Change passphrase again
3. Verify old passphrase no longer works
4. Verify new passphrase works

**Expected:**
- Both currentKey and newKey converted to hex format
- Database re-encrypts successfully
- New passphrase unlocks database

### Scenario 4: Migration Verification
**Steps:**
1. Start migration flow
2. Enter passphrase
3. Verify database opens

**Expected:**
- If salt exists, key is derived and converted to hex before testing
- Verification succeeds with correct passphrase

## Success Criteria
- ✅ No "ErrorCorrupt" errors during database initialization
- ✅ No "Wrong database passphrase" errors
- ✅ Database opens successfully on fresh install
- ✅ Database opens successfully after key rotation
- ✅ Key rotation works correctly
- ✅ Migration verification works with salt

## Logging to Monitor
- `[DBInit] Setting PRAGMA key (key length: ...)`
- `chatMigrateInit: converted derived key to hex format (...)`
- `chatMigrateInit: deriving key from stored passphrase`
- Any SQLCipher errors

## Rollback Plan
If issues occur:
1. Revert all four files to previous versions
2. Rebuild Haskell library: `cabal build --flag swift --flag client_library --flag commoncrypto`
3. Rebuild iOS app in Xcode
4. Test with fresh install
