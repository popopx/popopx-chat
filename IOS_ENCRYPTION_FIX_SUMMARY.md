# iOS Database Encryption - Upstream Compatibility Fix

**Date:** 2026-10-29  
**Status:** Code changes complete, requires real device testing

## Problem

POPOPX iOS app was failing with `errorNotADatabase` / `ErrorCorrupt` when initializing encrypted databases. The root cause was a mismatch between POPOPX's key handling and upstream simplex-chat.

## Root Cause

POPOPX was converting PBKDF2-derived keys from base64 to hex format (`x'...'`) and passing them as raw bytes to `chat_migrate_init_key_bytes`. This caused SQLCipher to receive ASCII bytes of the hex string instead of the actual encryption key.

**POPOPX (incorrect):**
```swift
// Convert base64 → hex → raw bytes
let hexKey = "x'\(keyData.map { String(format: "%02hhx", $0) }.joined())"
chat_migrate_init_key_bytes(..., keyBytes, ...)  // ASCII bytes of hex string
```

**Upstream (correct):**
```swift
// Pass base64 string directly as UTF-8
dbKey = derived.key  // base64 string
chat_migrate_init_key(..., &cKey, ...)  // UTF-8 CString
```

## Changes Made

### 1. apps/ios/POPOPXSwitch/API.swift

**Main FFI call (line ~344):**
- Changed from `chat_migrate_init_key_bytes` to `chat_migrate_init_key`
- Removed hex conversion: `dbKey = derived.key` (base64 string)
- Pass key as UTF-8 CString: `var cKey = dbKey.cString(using: .utf8)`

**Retry path 1 (line ~378):**
- Changed from `chat_migrate_init_key_bytes` to `chat_migrate_init_key`
- Removed `SecureData` wrapper
- Pass key as UTF-8 CString

**Retry path 2 (line ~462):**
- Changed from `chat_migrate_init_key_bytes` to `chat_migrate_init_key`
- Removed `SecureData` wrapper
- Pass key as UTF-8 CString

**Key derivation (line ~294):**
- Removed hex conversion
- Use base64 string directly: `dbKey = derived.key`

### 2. apps/ios/Shared/Views/Database/DatabaseEncryptionView.swift

**encryptDatabaseAsync (line ~208):**
- Removed hex conversion for new key: `let derivedKey = derived.key`
- Removed hex conversion for current key: `derivedCurrentKey = currentDerived.key`
- Pass base64 strings to `apiStorageEncryption`

### 3. apps/ios/Shared/Views/Migration/PXMigrateFromDevice.swift

**verifyDatabasePassphrase (line ~821):**
- Removed hex conversion: `testKey = derived.key`
- Pass base64 string to `testStorageEncryption`

## Haskell Side Verification

The Haskell FFI function `mobileDbOpts` in `src/Popopx/Chat/Options/SQLite.hs` already matches upstream:

```haskell
mobileDbOpts fp key = do
  dbFilePrefix <- peekCString fp
  dbKey <- BA.convert <$> B.packCString key  -- UTF-8 CString → ByteString
  pure $ ChatDbOpts { dbFilePrefix, dbKey, ... }
```

This is identical to upstream `src/Simplex/Chat/Options/SQLite.hs:98-108`.

The `cChatMigrateInit_` function also matches upstream, using `mobileDbOpts fp key`.

**Note:** `cChatMigrateInitKeyBytes` is POPOPX-specific and no longer called from Swift after these changes. It remains in the codebase for backward compatibility but is effectively dead code.

## Key Flow (After Fix)

1. **Fresh install:**
   - Generate random 32-byte key → base64 string
   - Store base64 string in Keychain
   - Pass base64 string to FFI as UTF-8 CString
   - Haskell receives UTF-8 CString → ByteString
   - SQLCipher treats as passphrase, does its own PBKDF2

2. **Subsequent launch:**
   - Retrieve base64 passphrase from Keychain
   - Retrieve salt from Keychain
   - Derive key using PBKDF2 → base64 string
   - Pass base64 string to FFI as UTF-8 CString
   - Haskell receives UTF-8 CString → ByteString
   - SQLCipher treats as passphrase, does its own PBKDF2
   - Result matches original key → database opens successfully

3. **Database encryption:**
   - User provides passphrase
   - Generate salt, derive key using PBKDF2 → base64 string
   - Pass base64 string to `apiStorageEncryption`
   - Haskell sends to SQLCipher as passphrase

## Testing

### Simulator Test (Failed)
- Build: ✅ SUCCESS
- Install: ✅ SUCCESS
- Launch: ❌ FAIL - Keychain error -34018 (errSecMissingEntitlement)
- **Reason:** Simulator uses ad-hoc signing which doesn't support keychain access
- **Not a code issue** - environment limitation

### Real Device Test (Required)
To verify the fix works:
1. Build for real device with proper development certificate
2. Install on device
3. Launch app
4. Verify database initializes without errorNotADatabase
5. Test migration from another device
6. Test database encryption/decryption

## Compatibility

These changes make POPOPX iOS fully compatible with upstream simplex-chat's key handling:
- Same FFI function: `chat_migrate_init_key`
- Same key format: base64 string passed as UTF-8 CString
- Same derivation flow: Swift PBKDF2 → SQLCipher PBKDF2 (double derivation, but consistent)
- Same Keychain storage: base64 passphrase + salt

## Files Modified

1. `apps/ios/POPOPXSwitch/API.swift` - 3 FFI call sites updated
2. `apps/ios/Shared/Views/Database/DatabaseEncryptionView.swift` - encryption flow updated
3. `apps/ios/Shared/Views/Migration/PXMigrateFromDevice.swift` - verification flow updated

## Files Verified (No Changes Needed)

1. `src/Popopx/Chat/Mobile.hs` - already matches upstream
2. `src/Popopx/Chat/Options/SQLite.hs` - already matches upstream
3. `apps/ios/POPOPXSwitch/Popopx.h` - both FFI functions declared
4. `apps/ios/POPOPXSwitch/dummy.m` - wrapper for backward compatibility

## Next Steps

1. Test on real device with proper code signing
2. Verify database initialization works
3. Test migration from another device
4. Test database encryption/decryption
5. Consider removing `chat_migrate_init_key_bytes` from codebase (dead code)
6. Consider removing `SecureData` class from API.swift (no longer used)
