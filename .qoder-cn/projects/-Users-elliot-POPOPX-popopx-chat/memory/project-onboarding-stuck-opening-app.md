---
name: project-onboarding-stuck-opening-app
description: App stuck on "Opening app" screen when onboarding stage is complete but no user exists
metadata:
  type: project
---

## Problem
App stuck on "Opening app..." screen on second launch after database is recreated.

## Root Cause
When database is deleted/recreated but `onboardingStage` in UserDefaults persists as `.onboardingComplete`:
1. `initializeChat()` calls `apiGetActiveUser()` → returns nil (no user in fresh DB)
2. Code checks: `currentUser == nil && onboardingStage == .onboardingComplete && hasDatabase() == true`
3. Falls into `else` branch that does nothing (just logs "keeping onboarding stage")
4. `chatInitialized()` returns early because `currentUser == nil`
5. `startChat()` never called, user never loaded
6. ContentView shows `initializationView()` ("Opening app...") forever

## Fix
In `POPOPXAPI.swift:initializeChat()`, when no active user but onboarding is complete and database exists:
- Call `listUsers()` to check if database has any users
- If users list is empty → reset onboarding to `.step1_WelcomeIdentity`
- If users list fails (error) → reset onboarding (DB might be corrupted)
- If users exist but none active → keep onboarding stage (user selection handled elsewhere)

## Code Change
File: `apps/ios/Shared/Model/POPOPXAPI.swift` around line 1971-1984

```swift
if m.currentUser == nil {
    let currentStage = onboardingStageDefault.get()
    if currentStage != .onboardingComplete {
        advanceOnboarding(to: .step1_WelcomeIdentity)
    } else if !hasDatabase() {
        advanceOnboarding(to: .step1_WelcomeIdentity)
    } else {
        // NEW: Check if database has any users
        do {
            let users = try listUsers()
            if users.isEmpty {
                logger.debug("initializeChat: no user, onboarding complete, database exists but empty - resetting to step1")
                advanceOnboarding(to: .step1_WelcomeIdentity)
            } else {
                logger.debug("initializeChat: no active user but \(users.count) users exist, keeping onboarding stage")
            }
        } catch {
            logger.error("initializeChat: failed to list users: \(error), resetting to step1")
            advanceOnboarding(to: .step1_WelcomeIdentity)
        }
    }
    privacyDeliveryReceiptsSet.set(true)
}
```

## Verification
- Fresh install: Shows onboarding screen ✓
- Relaunch after database recreation: Shows onboarding screen ✓
- No more stuck on "Opening app..." screen ✓

## Related
- Similar to SQLCipher ErrorCorrupt fix where database state and onboarding stage were out of sync
- UserDefaults persists across app reinstalls on simulator unless explicitly cleared
