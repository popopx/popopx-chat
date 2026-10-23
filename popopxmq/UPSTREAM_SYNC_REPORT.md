# Upstream Sync Analysis Report
**Date:** 2026-10-20  
**Upstream Version:** 7.1.0.14  
**Local Version:** 7.1.0.14

## Summary

Local project is already synced with upstream v7.1.0.14. All files exist and the differences are primarily rebranding (SimpleX → Popopx). However, there are remaining SimpleX references that need to be replaced.

## File Comparison

### Source Files (src/)
- **Total upstream files:** 220
- **Total local files:** 219 (renamed from Simplex to Popopx)
- **Files with differences:** 216
- **Nature of differences:** All are rebranding (SimpleX → Popopx)

### Missing Files
✅ **No missing files** - All upstream files exist locally (after rebranding)

### Extra Local Files
- `PROJECT_MEMORY.md`
- `BRAND_UPDATE_REPORT.md`
- `REBRANDING_VERIFICATION.md`
- `CHANGELOG.md` (with local version history)
- `NOTICE`
- `release/` directory
- `release-assets/` directory
- `popopxmq.cabal` (renamed from simplexmq.cabal)
- Various Popopx-specific protocol docs and RFCs

## Build Configuration

### Cabal File
- ✅ Same structure (664 lines each)
- ✅ Same sections (library, executables, test-suite)
- ✅ Same dependencies
- ✅ Only rebranding differences

### cabal.project
- ✅ Identical to upstream

## Remaining SimpleX References

### Critical String Literals (Must Replace)

These are cryptographic constants and protocol strings that affect functionality:

1. **src/Popopx/Messaging/Crypto.hs**
   - `"SimpleXSbChainInit"` → `"PopopxSbChainInit"`
   - `"SimpleXSbChain"` → `"PopopxSbChain"`

2. **src/Popopx/Messaging/Crypto/Ratchet.hs**
   - `"SimpleXX3DH"` → `"PopopxX3DH"`
   - `"SimpleXVerifyCode"` → `"PopopxVerifyCode"`
   - `"SimpleXRootRatchet"` → `"PopopxRootRatchet"`
   - `"SimpleXChainRatchet"` → `"PopopxChainRatchet"`

3. **src/Popopx/Messaging/Crypto/Entitlement.hs**
   - `"SimpleX badges v1"` → `"Popopx badges v1"`

4. **src/Popopx/Messaging/Crypto/ShortLink.hs**
   - `"SimpleXContactLink"` → `"PopopxContactLink"`
   - `"SimpleXInvLink"` → `"PopopxInvLink"`

5. **src/Popopx/Messaging/Agent.hs**
   - `"SimpleXService"` → `"PopopxService"`

6. **src/Popopx/FileTransfer/Client/Main.hs**
   - `"SimpleX XFTP client v"` → `"Popopx XFTP client v"`

7. **src/Popopx/FileTransfer/Server/Main.hs**
   - `"SimpleX XFTP server v"` → `"Popopx XFTP server v"` (already replaced)
   - **Extra import to remove:** `import qualified Data.ByteString.Char8 as B` (line 18)

### Protocol Strings (Must Replace)

8. **src/Popopx/Messaging/Agent/Protocol.hs**
   - `"simplex:"` → `"popopx:"`
   - `SLSSimplex` → `SLSPopopx`

9. **src/Popopx/Messaging/ServiceScheme.hs**
   - `"simplex:"` → `"popopx:"`
   - `SSSimplex` → `SSPopopx`
   - `simplexChat` → `popopxChat`
   - `"simplex.chat"` → `"popopx.chat"`

10. **src/Popopx/Messaging/SimplexName.hs**
    - `"simplex:/name"` → `"popopx:/name"`
    - `"simplex"` → `"popopx"`
    - `SimplexDomain` → `PopopxDomain`
    - `TLDSimplex` → `TLDPopopx`

### Prometheus Metrics (Must Replace)

11. **src/Popopx/Messaging/Server/Prometheus.hs**
    - `simplex_smp_*` → `popopx_smp_*` (all metrics)

12. **src/Popopx/Messaging/Notifications/Server/Prometheus.hs**
    - `simplex_ntf_*` → `popopx_ntf_*` (all metrics)

### SQLite Function Names (Must Replace)

13. **src/Popopx/Messaging/Agent/Store/SQLite.hs**
    - `"simplex_xor_md5_combine"` → `"popopx_xor_md5_combine"`

### Server CLI (Must Replace)

14. **src/Popopx/Messaging/Server/CLI.hs**
    - `"O = SimpleX"` → `"O = Popopx"`

### Comments (Should Replace)

15. Various files have comments mentioning "SimpleX" that should be updated:
    - `src/Popopx/Messaging/Agent.hs`: "Resolve a SimpleX name"
    - `src/Popopx/Messaging/Protocol.hs`: "Resolve SimpleX name", "What the router knows about a SimpleX name"
    - `src/Popopx/Messaging/Names/Record.hs`: "held for SimpleX"

### Credentials (Should Replace)

16. **src/Popopx/Messaging/Agent/Client.hs**
    - `"simplex"` credential name → `"popopx"`

17. **src/Popopx/Messaging/Notifications/Server/Env.hs**
    - `"simplex"` credential name → `"popopx"`

## Code Issues Found

### Extra Import
**File:** `src/Popopx/FileTransfer/Server/Main.hs`  
**Line:** 18  
**Issue:** Extra import not in upstream: `import qualified Data.ByteString.Char8 as B`  
**Action:** Remove this import

## Recommendations

### Phase 1: Critical Replacements (Affects Functionality)
1. Replace all cryptographic string constants
2. Replace all protocol strings
3. Replace all Prometheus metric names
4. Replace SQLite function names
5. Remove extra import in FileTransfer/Server/Main.hs

### Phase 2: Branding Replacements (User-Visible)
1. Replace version strings
2. Replace CLI display strings
3. Replace credential names

### Phase 3: Comment Updates (Documentation)
1. Update all comments mentioning SimpleX

## Verification Steps

After replacements:
1. Run full test suite
2. Verify cryptographic operations still work
3. Check protocol compatibility
4. Verify Prometheus metrics are correctly named
5. Build all executables
6. Run integration tests

## Files Requiring Changes

Total: 14 files with critical changes, plus comments in ~5 more files

### Critical Changes:
1. src/Popopx/Messaging/Crypto.hs
2. src/Popopx/Messaging/Crypto/Ratchet.hs
3. src/Popopx/Messaging/Crypto/Entitlement.hs
4. src/Popopx/Messaging/Crypto/ShortLink.hs
5. src/Popopx/Messaging/Agent.hs
6. src/Popopx/Messaging/Agent/Protocol.hs
7. src/Popopx/Messaging/ServiceScheme.hs
8. src/Popopx/Messaging/SimplexName.hs
9. src/Popopx/Messaging/Server/Prometheus.hs
10. src/Popopx/Messaging/Notifications/Server/Prometheus.hs
11. src/Popopx/Messaging/Agent/Store/SQLite.hs
12. src/Popopx/Messaging/Server/CLI.hs
13. src/Popopx/FileTransfer/Client/Main.hs
14. src/Popopx/FileTransfer/Server/Main.hs

### Additional Changes:
15. src/Popopx/Messaging/Agent/Client.hs
16. src/Popopx/Messaging/Notifications/Server/Env.hs
17. src/Popopx/Messaging/Protocol.hs (comments)
18. src/Popopx/Messaging/Names/Record.hs (comments)
