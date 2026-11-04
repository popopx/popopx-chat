# GHC GC Crash Investigation

## Crash Summary
- **Location**: `stg_gc_fun_info` (GHC garbage collector)
- **Thread**: ghc_worker (Thread 17)
- **Fault**: `KERN_INVALID_ADDRESS at 0x91006294f9400a7e`
- **Context**: During `chatMigrateInit` FFI call

## Root Cause Analysis

The crash is **heap corruption in the Haskell runtime**, not a stack overflow. The invalid address `0x91006294f9400a7e` indicates a corrupted pointer in the GHC heap.

### Possible Causes

1. **SQLCipher C FFI memory corruption** (most likely)
   - SQLCipher is a C library that interacts with Haskell via FFI
   - Buffer overflow or use-after-free in SQLCipher could corrupt Haskell heap
   - Recent migration changes may have triggered edge cases

2. **GHC 9.6.3 non-moving GC bug**
   - The `-xn` flag enables non-moving GC (new in 9.6)
   - Known to have issues with certain workloads
   - Could be triggered by large allocation patterns during migration

3. **FFI boundary issue**
   - Incorrect memory management when passing data between Swift and Haskell
   - StablePtr misuse or premature finalization

## Evidence

### What Works
- ✅ FFI stack overflow fixes committed (prevents SIGBUS)
- ✅ Swift-side JSON decoding works (API.swift:1057)
- ✅ `chatMigrateInit` executes on ffiQueue correctly

### What Fails
- ❌ GHC GC crashes during heap traversal
- ❌ Invalid pointer in heap suggests corruption

## Recommendations

### Immediate (try in order)

1. **Disable non-moving GC**
   ```c
   // In hs_init.c, change:
   "-xn", // non-moving GC
   // to:
   // (remove -xn flag, use default moving GC)
   ```

2. **Rebuild Haskell library with debug info**
   ```bash
   nix build .#popopx-chat-lib-popopx-chat
   # Rebuild with -debug flag for better crash reports
   ```

3. **Check SQLCipher version**
   ```bash
   grep -r "sqlcipher" cabal.project
   # Verify using compatible version
   ```

### Investigation Steps

1. **Enable GHC RTS debugging**
   ```c
   char *argv[] = {
       "popopx",
       "+RTS",
       "-A64m",
       "-H64m",
       "-D",  // Enable debug output
       "-s",  // GC statistics
       0
   };
   ```

2. **Run with memory sanitizer** (if possible)
   - Rebuild with AddressSanitizer to detect heap corruption

3. **Check upstream issues**
   - Search simplex-chat GitHub for similar GC crashes
   - Check GHC 9.6.3 release notes for known GC bugs

## FFI Fixes Status

✅ **Committed** in `f3e48b298`:
- All FFI calls wrapped in `ffiQueue.sync` with deadlock guard
- NSE heap increased to 2MB
- Prevents main thread stack overflow (SIGBUS)

The FFI fixes are **correct and necessary** - they prevent the original stack overflow crash. The GC crash is a **separate issue** that needs independent investigation.

## Next Steps

1. Try disabling `-xn` flag first (lowest risk change)
2. If that doesn't help, rebuild Haskell library with debug RTS
3. Consider reporting to upstream if it's a GHC bug
