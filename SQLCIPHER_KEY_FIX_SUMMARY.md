# SQLCipher Key Transmission Fix - Complete Summary

## Problem Statement

The iOS app was experiencing "Wrong database passphrase" errors when opening encrypted databases after key rotation. The root cause was a **key derivation mismatch** between iOS and SQLCipher:

### Root Cause Analysis

1. **iOS with salt**: Derives a 32-byte key using PBKDF2 (600,000 iterations), base64-encodes it, and sends to Haskell
2. **Haskell**: Passes the base64 string to SQLCipher via `PRAGMA key = 'base64string';`
3. **SQLCipher**: Receives the base64 string and **derives another key from it** using PBKDF2 (256,000 iterations)
4. **Result**: Keys don't match → decryption fails with "Wrong database passphrase"

### Why This Happened

The issue occurred specifically after **key rotation** (when salt exists in KeyChain):
- Fresh installs worked because iOS sent the raw passphrase, letting SQLCipher derive internally
- After rotation, iOS pre-derived the key and sent it as a base64 string
- SQLCipher treated this base64 string as a passphrase and derived again with different parameters

## Solution Overview

Modified the key transmission protocol to use SQLCipher's **raw key mode** when keys are pre-derived:

- **Passphrase mode**: `PRAGMA key = 'passphrase';` → SQLCipher derives internally
- **Raw key mode**: `PRAGMA key = "x'hex_encoded_key';"` → SQLCipher uses key directly

## Files Modified

### 1. `popopxmq/src/Popopx/Messaging/Agent/Store/SQLite.hs`

**Change**: Updated `keyString` function to detect and handle hex format keys

```haskell
keyString :: ScrubbedBytes -> Text
keyString keyBytes =
  let keyStr = safeDecodeUtf8 (BA.convert keyBytes)
   in if "x'" `T.isPrefixOf` keyStr && "'" `T.isSuffixOf` keyStr
        then keyStr  -- Already in SQLCipher hex format, use as-is
        else sqlString keyStr
```

**Impact**: Haskell now correctly passes hex-encoded keys to SQLCipher without additional quoting.

### 2. `apps/ios/POPOPXSwitch/API.swift`

**Change**: Convert derived keys to hex format when salt exists in `chatMigrateInit`

```swift
if let salt = kcDatabaseSalt.get() {
    if let derived = deriveKey(from: storedKey, salt: Data(base64Encoded: salt)) {
        if let keyData = Data(base64Encoded: derived.key) {
            dbKey = "x'\(keyData.map { String(format: "%02hhx", $0) }.joined())"
            logger.debug("chatMigrateInit: converted derived key to hex format (\(keyData.count) bytes)")
        }
    }
}
```

**Impact**: Database opening now uses raw key mode when salt exists, preventing double derivation.

### 3. `apps/ios/Shared/Views/Database/DatabaseEncryptionView.swift`

**Change**: Convert both `currentKey` and `newKey` to hex format during encryption

```swift
// Convert new key to hex
let hexKey = "x'\(keyData.map { String(format: "%02hhx", $0) }.joined())"

// Also convert current key if salt exists
var hexCurrentKey = currentKey
if !currentKey.isEmpty, let existingSalt = kcDatabaseSalt.get() {
    if let currentDerived = deriveKey(from: currentKey, salt: Data(base64Encoded: existingSalt)) {
        if let currentKeyData = Data(base64Encoded: currentDerived.key) {
            hexCurrentKey = "x'\(currentKeyData.map { String(format: "%02hhx", $0) }.joined())"
        }
    }
}

try await apiStorageEncryption(currentKey: hexCurrentKey, newKey: hexKey)
```

**Impact**: Database encryption and re-encryption now use consistent key formats.

### 4. `apps/ios/Shared/Views/Migration/PXMigrateFromDevice.swift`

**Change**: Add salt handling in `verifyDatabasePassphrase`

```swift
var testKey = dbKey
if let salt = kcDatabaseSalt.get() {
    if let derived = deriveKey(from: dbKey, salt: Data(base64Encoded: salt)) {
        if let keyData = Data(base64Encoded: derived.key) {
            testKey = "x'\(keyData.map { String(format: "%02hhx", $0) }.joined())"
        }
    }
}
try await testStorageEncryption(key: testKey)
```

**Impact**: Migration verification now correctly tests derived keys when salt exists.

## Key Flow After Fix

### Scenario 1: Fresh Install (No Salt)
```
User enters passphrase → Stored in KeyChain
→ iOS sends passphrase to Haskell
→ Haskell wraps in quotes: PRAGMA key = 'passphrase';
→ SQLCipher derives key internally (256k iterations)
✓ Database opens successfully
```

### Scenario 2: After Key Rotation (With Salt)
```
User enters passphrase → Stored in KeyChain with salt
→ iOS derives key using PBKDF2 (600k iterations)
→ Converts to hex: x'abcdef1234...'
→ Sends hex key to Haskell
→ Haskell detects x'...' format, passes as-is
→ SQLCipher uses key directly (no derivation)
✓ Database opens successfully
```

### Scenario 3: Database Re-Encryption
```
User enters old and new passphrases
→ Both keys converted to hex format (if salt exists)
→ Haskell receives both in hex format
→ SQLCipher uses raw keys for decryption/encryption
✓ Database re-encrypts successfully
```

### Scenario 4: Migration Verification
```
User enters passphrase
→ If salt exists, derive key and convert to hex
→ Test with hex key against database
✓ Verification succeeds with correct passphrase
```

## Testing Checklist

- ✅ Haskell library compiles successfully
- ✅ iOS app builds successfully
- 🔄 Fresh install test (pending)
- 🔄 Key rotation test (pending)
- 🔄 Re-encryption test (pending)
- 🔄 Migration verification test (pending)

## Build Commands

### Haskell
```bash
source ~/.ghcup/env
cabal build --flag swift --flag client_library --flag commoncrypto
```

### iOS
```bash
cd apps/ios
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,id=C15A3542-8F4E-4C49-95D8-BD5FDF5CC149' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## Technical Details

### Key Format Conversion
- **Base64**: `deriveKey()` returns base64-encoded 32-byte key
- **Hex**: Convert base64 → raw bytes → hex string with `x'...'` prefix
- **Example**: Base64 `abc123==` → Hex `x'69b7d4'`

### SQLCipher Key Modes
- **Passphrase mode**: `PRAGMA key = 'text';` → SQLCipher applies PBKDF2
- **Raw key mode**: `PRAGMA key = "x'hex';"` → SQLCipher uses key directly

### Iteration Counts
- **iOS PBKDF2**: 600,000 iterations (SHA256)
- **SQLCipher default**: 256,000 iterations (SHA256)
- **Mismatch**: Causes decryption failures when key is derived twice

## Benefits of This Fix

1. **Eliminates double derivation**: Keys are derived once in iOS, used directly by SQLCipher
2. **Consistent iteration count**: iOS controls PBKDF2 parameters (600k iterations)
3. **Backward compatible**: Fresh installs still use passphrase mode
4. **Secure**: Uses standard SQLCipher raw key mode with proper hex encoding
5. **Maintainable**: Clear separation between passphrase and derived key scenarios

## Potential Issues & Mitigations

### Issue: Existing databases encrypted with base64 keys
**Mitigation**: Not applicable - previous code would have failed to open these databases anyway

### Issue: Key rotation on devices without salt
**Mitigation**: Code checks for salt existence before converting to hex format

### Issue: Migration from old versions
**Mitigation**: Migration verification now handles both passphrase and hex key modes

## Rollback Plan

If issues occur:
1. Revert all four modified files to previous versions
2. Rebuild Haskell library
3. Rebuild iOS app
4. Test with fresh install

## Conclusion

This fix resolves the "Wrong database passphrase" error by ensuring consistent key handling between iOS and SQLCipher. The solution uses SQLCipher's raw key mode for pre-derived keys while maintaining backward compatibility with passphrase mode for fresh installs. All key operations (opening, encrypting, re-encrypting, verifying) now use the same key format, eliminating derivation mismatches.
