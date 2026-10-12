# Task List: Retain Cycle & Deprecated Key Detection Fixes

## Task 1: MiniAppWebView Coordinator Retain Cycle [FIXED]
**Status:** COMPLETED (P0-5)
**File:** `Shared/Customization/DeveloperPlatform/MiniAppWebView.swift`

**What was done:**
- Added `static func dismantleUIView(_:context:)` to remove script message handler
- This breaks the retain path: WKUserContentController → Coordinator → parent

**Verification needed:**
- [ ] Confirm no crash when navigating to/from mini app views repeatedly
- [ ] Check Instruments for memory leaks in MiniAppWebView

---

## Task 2: Deprecated Key Detection in `removePasscodesIfReinstalled`
**Status:** TODO
**File:** `Shared/AppDelegate.swift:110-121`

**Current problem:**
```swift
private func removePasscodesIfReinstalled() {
    if !UserDefaults.standard.bool(forKey: DEFAULT_PERFORM_LA) && !hasDatabase() {
        kcDatabasePassword.remove()
        kcAppPassword.remove()
        kcSelfDestructPassword.remove()
    }
}
```
- `DEFAULT_PERFORM_LA` is deprecated, replaced by `GROUP_DEFAULT_APP_LOCAL_AUTH_ENABLED`
- If LA was enabled via group defaults, `DEFAULT_PERFORM_LA` in standard UserDefaults is `false`
- Combined with `!hasDatabase()` check, this could incorrectly delete keychain passwords

**Fix steps:**
1. Replace deprecated key with a dedicated reinstall detection UUID
2. On first launch, generate and store a UUID in standard UserDefaults
3. On subsequent launches, if UUID exists → not a reinstall
4. If UUID is missing AND keychain has data → reinstall detected → clear keychain
5. If UUID is missing AND keychain is empty → fresh install → just set UUID

**Implementation:**
```swift
private func removePasscodesIfReinstalled() {
    let reinstallKey = "app_instance_uuid"
    let defaults = UserDefaults.standard
    guard defaults.string(forKey: reinstallKey) == nil else { return }
    // No stored UUID — either fresh install or reinstall
    if kcDatabasePassword.get() != nil {
        // Keychain has data from previous install
        kcDatabasePassword.remove()
        kcAppPassword.remove()
        kcSelfDestructPassword.remove()
        logger.debug("removePasscodesIfReinstalled: cleared keychain (reinstall detected)")
    }
    defaults.set(UUID().uuidString, forKey: reinstallKey)
}
```

**Testing:**
- [ ] Fresh install: keychain empty, UUID created
- [ ] Normal relaunch: UUID exists, no keychain changes
- [ ] Reinstall (delete + reinstall): UUID missing, keychain cleared
- [ ] Keychain shared via App Group: verify NSE can still access after reinstall

---

## Task 3: Audit Other Potential Retain Cycles
**Status:** TODO
**Priority:** Medium

**Suspects to investigate:**
1. **EphemeralFileView Timer** (`EncryptedDocs/EphemeralFileView.swift:172`)
   - Timer closure captures struct state; SwiftUI struct copies may cause unexpected behavior
   - Fix: Use ObservableObject wrapper or invalidate timer in onDisappear

2. **ProposalView Timer** (`Community/ProposalView.swift:95-121`)
   - Timer added to RunLoop.current in .common mode
   - Fix: Store timer in @State, invalidate in onDisappear

3. **BotPlatformManager** (`DeveloperPlatform/BotSettingsView.swift`)
   - Singleton with @StateObject — verify no retain path through closures

4. **DataMarketManager** (`DataMarket/DataMarketManager.swift`)
   - Singleton with @StateObject — verify cleanup on view dismissal

**Verification:**
- [ ] Run Instruments Leaks template on each view
- [ ] Navigate to/from each view 10+ times, check memory doesn't grow

---

## Task 4: Verify Deprecated Key Usage Across Codebase
**Status:** TODO
**Priority:** Low

**Files using `DEFAULT_PERFORM_LA`:**
- `Shared/Views/UserSettings/PrivacySettings.swift:24`
- `Shared/ContentView.swift:45`
- `Shared/Views/TerminalView.swift:18`

**Fix steps:**
1. Replace all `@AppStorage(DEFAULT_PERFORM_LA)` with `@AppStorage` using the group default key
2. Or create a computed property that reads from the correct source
3. Remove `DEFAULT_PERFORM_LA` constant after migration
4. Add migration logic in `setGroupDefaults()` to copy old key to new key on first launch

**Testing:**
- [ ] Verify local auth toggle works in Privacy Settings
- [ ] Verify ContentView reads correct auth state
- [ ] Verify Terminal reads correct auth state
