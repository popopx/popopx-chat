# iOS Rebranding Verification Report

**Date:** 2026-09-29  
**Commit:** fcc818f57  
**Branch:** release/v1.2

## Summary

All 7 phases of the iOS SimpleX → POPOPX rebranding have been completed and verified.

## Phases Completed

### Phase 1: JSON Protocol Fixes (CRITICAL) ✅
Fixed Haskell-Swift JSON boundary mismatches that were breaking the app:
- `simplexLink` → `popopxLink`
- `simplexName` → `popopxName`
- `simplex` (TLD) → `popopx`
- `simplexDomainNotReady` → `popopxDomainNotReady`
- `simplexLinks` → `popopxLinks`
- `simplexmqVersion`/`simplexmqCommit` → `popopxmqVersion`/`popopxmqCommit`
- `ServerContactAddress.simplex` → `popopx`
- `ConnectionErrorType.SIMPLEX` → `ONE_WAY`

**Files:** ChatTypes.swift, APITypes.swift, AppAPITypes.swift + 15 caller files

### Phase 2: Swift Type Renames ✅
Renamed 10 types:
- `SimplexDomainClaim` → `PopopxDomainClaim`
- `SimplexDomainProof` → `PopopxDomainProof`
- `SimplexLinkType` → `PopopxLinkType`
- `SimplexNameInfo` → `PopopxNameInfo`
- `SimplexNameDomain` → `PopopxNameDomain`
- `SimplexTLD` → `PopopxTLD`
- `SimplexDomainError` → `PopopxDomainError`
- `SimplexNameType` → `PopopxNameType`
- `SimplexAddress` → `PopopxAddress`
- `SimplexLockView` → `PopopxLockView`

### Phase 3: Swift Function Renames ✅
Renamed 10+ functions:
- `sendSimpleXCmd()` → `sendPopopxCmd()`
- `sendSimpleXCmdStr()` → `sendPopopxCmdStr()`
- `recvSimpleXMsg()` → `recvPopopxMsg()`
- `simplexChatUri()` → `popopxChatUri()`
- `simplexChatLink()` → `popopxChatLink()`
- `hasSimplexLink()` → `hasPopopxLink()`
- `parsedMsgHasSimplexLink()` → `parsedMsgHasPopopxLink()`
- `isSimplexLink` → `isPopopxLink`
- `strIsSimplexLink()` → `strIsPopopxLink()`

**Files:** API.swift, POPOPXAPI.swift, NotificationService.swift, ShareAPI.swift, ShareModel.swift, PXTerminalView.swift + 15 caller files

### Phase 4: Properties, Variables, UserDefaults ✅
Renamed properties and UserDefaults keys:
- `hasSimplexLink` → `hasPopopxLink`
- `searchShowingSimplexLink` → `searchShowingPopopxLink`
- `simplexLinkMode` → `popopxLinkMode`
- `verifySimplexNames` → `verifyPopopxNames`
- `pxSimplex` → `pxPopopx`
- `privacySimplexLinkMode` → `privacyPopopxLinkMode` (UserDefaults key)
- `privacyVerifySimplexNames` → `privacyVerifyPopopxNames` (UserDefaults key)

**Note:** UserDefaults keys intentionally break user settings (no migration code per user decision)

### Phase 5: DispatchQueue Labels & View IDs ✅
Updated 5 DispatchQueue labels and 5 view IDs:
- `chat.simplex.*` → `chat.popopx.*`
- `simplex-qrcode-*` → `popopx-qrcode-*`

### Phase 6: Compile Flag & Bridging Header ✅
- `SIMPLEX_ASSETS` → `POPOPX_ASSETS` (8 locations, 6 files)
- `POPOPXSwitch/SimpleX.h` → `POPOPXSwitch/Popopx.h` (file rename + 6 pbxproj edits)

### Phase 7: Localization xcloc Filenames ✅
Renamed 28 files across 17 locales:
- `SimpleXChat-InfoPlist.strings` → `PopopxChat-InfoPlist.strings`
- `SimpleX--iOS--InfoPlist.strings` → `Popopx--iOS--InfoPlist.strings`
- `SimpleX NSE/` → `POPOPX NSE/`
- `SimpleX SE/` → `POPOPX SE/`

## Additional Fixes

### Image Asset References ✅
Fixed broken image asset references in PXUserAddressView.swift:
- `simplex-address-small` → `popopx-address-small`
- `simplex-address-small-light` → `popopx-address-small-light`
- `simplex-address` → `popopx-address`
- `simplex-address-light` → `popopx-address-light`

**Note:** Actual image files need to be created separately (not in repo)

## Protected Identifiers (NOT Changed)

The following were intentionally preserved:
1. **FFI C function names:** `chat_migrate_init_key`, `chat_send_cmd_retry`, `chat_recv_msg_wait`
2. **Haskell library filenames:** `libHSpopopx-chat-*.a`
3. **AGPL attribution:** `"Copyright (c) SimpleX Chat"`
4. **Protocol-level strings:** `".simplex"` TLD, `"simplex_link"`, `simplex:/` in `normalizeForParsing()`
5. **HS RTS arg:** `"simplex"` in `hs_init.c`
6. **Upstream URLs:** `github.com/simplex-chat`, blog post URLs with "simplex" in slug
7. **Original website:** `https://simplex.chat` (attribution)

## Remaining "simplex" References (23 total)

All remaining references are safe and intentional:
- **8 comments** explaining code behavior
- **5 NSLocalizedString developer comments** (not user-visible)
- **8 upstream blog post URLs** (real URLs)
- **1 attribution URL** (`originalWebsite`)
- **1 dead enum case** (`OperatorTag.simplex` - kept for old cached data compatibility)

## Build Verification

All 5 build targets verified clean:
- ✅ POPOPX (iOS)
- ✅ POPOPX NSE
- ✅ POPOPX SE
- ✅ POPOPXSwitch
- ✅ Tests iOS

## Statistics

- **Files changed:** 146
- **Insertions:** 518
- **Deletions:** 282
- **Net change:** +236 lines

## Next Steps

The iOS rebranding is complete. Remaining work (if desired):
1. Create `popopx-address-*` image assets (design task)
2. Rebrand Android app (Kotlin Multiplatform)
3. Rebrand web frontend
4. Update documentation

---

**Status:** ✅ COMPLETE AND VERIFIED
