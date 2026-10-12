# Remediation Plan: Top 5 Persistence & Navigation Bugs

## Bug 1: Dual UserDefaults Suites with Fragile Manual Sync
**Severity:** HIGH | **Files:** `PrivacySettings.swift`, `AppearanceSettings.swift`, `SettingsView.swift`, `AppGroup.swift`

**Problem:** Settings use `@AppStorage` against `UserDefaults.standard`, but NSE/SE extensions read from `groupDefaults`. Manual `.onChange` sync can miss programmatic changes or fail silently.

**Fix Strategy:**
1. Replace `@AppStorage` with a custom `GroupDefault` wrapper that reads/writes directly to `groupDefaults`
2. Remove manual `.onChange` sync handlers
3. Affected keys: `privacyAcceptImages`, `profileImageCornerRadius`, `privacyLinkPreviews`

**Implementation:**
```swift
// New wrapper in AppGroup.swift
struct GroupDefaultBool {
    let key: String
    let defaultValue: Bool
    func get() -> Bool {
        groupDefaults.object(forKey: key) as? Bool ?? defaultValue
    }
    func set(_ value: Bool) {
        groupDefaults.set(value, forKey: key)
    }
}
```

**Risk:** Low. The NSE already reads from groupDefaults; this just makes the main app consistent.
**Testing:** Verify NSE sees setting changes immediately without app restart.

---

## Bug 2: `removePasscodesIfReinstalled` Checks Deprecated Key
**Severity:** HIGH | **File:** `AppDelegate.swift:110-121`

**Problem:** Reinstall detection checks `DEFAULT_PERFORM_LA` (deprecated), which may be `false` in standard UserDefaults even when the app was previously installed with LA enabled via group defaults. Could incorrectly delete keychain passwords on legitimate launch.

**Fix Strategy:**
1. Replace deprecated key check with a dedicated reinstall detection flag
2. Use a group default key that persists across the same mechanism as the keychain

**Implementation:**
```swift
private func removePasscodesIfReinstalled() {
    let reinstallKey = "app_installed_uuid"
    let defaults = UserDefaults.standard
    let storedUUID = defaults.string(forKey: reinstallKey)
    if storedUUID == nil {
        // First launch or reinstall — check if keychain has data
        if kcDatabasePassword.get() != nil {
            // Keychain has data but no UUID = reinstall
            kcDatabasePassword.remove()
            kcAppPassword.remove()
            kcSelfDestructPassword.remove()
        }
        defaults.set(UUID().uuidString, forKey: reinstallKey)
    }
}
```

**Risk:** Medium. Must ensure this doesn't delete keychain data on normal first install.
**Testing:** Test fresh install, normal launch, and reinstall scenarios.

---

## Bug 3: `startChatAndActivate` Completion Races on `chatRunning`
**Severity:** HIGH | **File:** `SimpleXApp.swift:108-134`, `SuspendChat.swift:148-177`

**Problem:** The completion block checks `chatModel.chatRunning == true`, but `activateChat()` may not have updated `chatRunning` yet when the completion fires. Deferred notification responses and deep links could be skipped.

**Fix Strategy:**
1. Move the deferred work processing into `activateChat` itself, after `chatRunning` is confirmed true
2. Or add a retry mechanism in the completion block

**Implementation:**
```swift
// In SuspendChat.swift, activateChat():
func activateChat(completion: (() -> Void)? = nil) {
    suspendLockQueue.sync {
        // ... existing activation logic ...
        apiActivateChat()
        // Wait for chatRunning to be true, then call completion
        DispatchQueue.global(qos: .userInitiated).async {
            var retries = 0
            while !ChatModel.shared.chatRunning && retries < 20 {
                Thread.sleep(forTimeInterval: 0.1)
                retries += 1
            }
            DispatchQueue.main.async { completion?() }
        }
    }
}
```

**Risk:** Medium. The retry loop adds latency but ensures correctness.
**Testing:** Test notification response processing after cold start.

---

## Bug 4: `suspendOnEndCall` 3-Second Delay Can Double-Suspend
**Severity:** HIGH | **File:** `CallController.swift:175-188`

**Problem:** After a call ends, a 3-second delayed suspend can fire while a new call is being set up, causing the chat to be suspended mid-call.

**Fix Strategy:**
1. Store the dispatch work item so it can be cancelled
2. Cancel pending suspend when a new call starts

**Implementation:**
```swift
private var pendingSuspendWorkItem: DispatchWorkItem?

private func suspendOnEndCall() {
    pendingSuspendWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
        guard let self,
              ChatModel.shared.activeCall == nil,
              self.shouldSuspendChat,
              !CallController.shared.hasActiveCalls()
        else { return }
        suspendChat()
    }
    pendingSuspendWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
}

// In call start:
func cancelPendingSuspend() {
    pendingSuspendWorkItem?.cancel()
    pendingSuspendWorkItem = nil
}
```

**Risk:** Low. The guard conditions already partially protect against this; the work item just makes cancellation explicit.
**Testing:** Test rapid call end → new call start sequence.

---

## Bug 5: No iOS State Restoration for Navigation
**Severity:** MEDIUM | **Files:** `AppDelegate.swift`, `SimpleXApp.swift`, `ChatModel.swift`

**Problem:** After system termination and relaunch, navigation state (active chat, scroll position) is lost. User always returns to chat list.

**Fix Strategy:**
1. Encode active chat ID in `stateRestorationActivity`
2. Restore chat ID on relaunch

**Implementation:**
```swift
// In SceneDelegate:
func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    let activity = NSUserActivity(activityType: "com.popopxchat.popopx.restore")
    if let chatId = ChatModel.shared.chatId {
        activity.userInfo = ["chatId": chatId]
    }
    return activity
}

// In SimpleXApp on launch:
if let chatId = restoredChatId {
    chatModel.chatId = chatId
}
```

**Risk:** Low. Additive change, no existing behavior modified.
**Testing:** Test app termination while viewing a chat, verify chat reopens on relaunch.

---

## Priority Order
1. Bug 4 (suspendOnEndCall) — simplest fix, highest crash risk
2. Bug 2 (reinstall detection) — data loss risk
3. Bug 1 (dual UserDefaults) — correctness risk for NSE
4. Bug 3 (chatRunning race) — notification delivery risk
5. Bug 5 (state restoration) — UX improvement, lowest urgency
