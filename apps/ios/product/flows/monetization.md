# Monetization & Compute Tokens

> Subscription tiers, compute-token store, and red-packet gifting.
>
> **Related spec:** [spec/services/monetization.md](../spec/services/monetization.md)

## Overview

POPOP Quantum adds three monetization layers on top of the core chat:

1. **Membership subscriptions** — annual Standard / Premium tiers via StoreKit 2 auto-renewable subscriptions.
2. **Compute-token store** — consumable in-app purchases that credit a token balance used for in-chat features.
3. **Red packets** — peer-to-peer token gifts sent as enriched text messages over the existing protocol.

## User Flows

### 1. Subscription (Membership)

| Step | User action | System behaviour |
|------|-------------|------------------|
| 1 | Open Settings > Membership | `SubscriptionView` loads products via StoreKit 2 |
| 2 | 3-day free trial starts automatically on first launch | `EntitlementStore.startTrialIfNeeded()` records trial start in app-group UserDefaults |
| 3 | Tap **Subscribe** on Standard or Premium card | `confirmationDialog` shows price, user confirms, StoreKit `product.purchase()` fires |
| 4 | Payment completes | `Transaction.currentEntitlements` updates; `SubscriptionManager.updateEntitlements()` persists tier + expiry |
| 5 | Trial expires without purchase | `PaywallView` locks the app; only subscription view is accessible |
| 6 | Within 10 days of expiry | `SubscriptionRenewalView` reminder is shown |

**Tier capabilities:**

| Capability | Free (trial) | Standard | Premium |
|------------|:---:|:---:|:---:|
| Chat, calls, groups | Yes | Yes | Yes |
| Compute-token store & gifts | Yes | Yes | Yes |
| Custom SMP servers | No | No | Yes |

**Subscription product IDs:**

| Plan | Price | Period | StoreKit ID |
|------|-------|--------|-------------|
| Standard Monthly | $9.99 | 1 month | `com.popopxchat.popopx.basic.monthly` |
| Standard Yearly | $99.00 | 1 year | `com.popopxchat.popopx.basic.yearly` |
| Premium Monthly | $29.99 | 1 month | `com.popopxchat.popopx.premium.monthly` |
| Premium Yearly | $299.00 | 1 year | `com.popopxchat.popopx.premium.yearly` |

### 2. Compute-Token Purchase

| Step | User action | System behaviour |
|------|-------------|------------------|
| 1 | Open compute store from settings | `ComputeStoreView` loads products + StoreKit catalog + balance |
| 2 | Tap a product card (Starter / Plus / Pro / Quantum) | `confirmationDialog` shows "Pay $X.XX" with token amount |
| 3 | Confirm payment | StoreKit 2 `product.purchase()` presents Apple Pay |
| 4 | Payment succeeds | JWS posted to backend `/orders`; on 200, `transaction.finish()` is called; success overlay shows "+N tokens" and updated balance |
| 5 | Payment pending | Alert explains tokens will be credited once Apple confirms |

**Mock mode:** When no backend URL is configured (Developer settings), purchases credit tokens locally without StoreKit. This is the default for development and testing.

**Product catalog:**

| Pack | Price | Tokens | StoreKit ID |
|------|-------|--------|-------------|
| Starter | $9.99 | 100 | `com.popopxchat.popopx.tokens.starter` |
| Plus | $29.99 | 350 | `com.popopxchat.popopx.tokens.plus` |
| Pro | $99.99 | 1,300 | `com.popopxchat.popopx.tokens.pro` |
| Quantum | $299.99 | 4,500 | `com.popopxchat.popopx.tokens.quantum` |

### 3. Red Packets (Compute-Token Gifts)

**Sending:**

| Step | User action | System behaviour |
|------|-------------|------------------|
| 1 | Tap "Send compute red packet" button in compute store | `SendRedPacketView` sheet opens |
| 2 | Enter token amount and optional greeting | Balance shown; button disabled if amount > balance |
| 3 | Tap "Send red packet" | `ComputeStore.debit(amount)` deducts tokens; `RedPacketInfo` encoded into message text via `encodeRedPacketMessage()` |
| 4 | Message sent | Appears as a gold-gradient chat bubble with gift icon |

**Receiving / Claiming:**

| Step | User action | System behaviour |
|------|-------------|------------------|
| 1 | See red-packet bubble in chat | `CIRedPacketView` renders with "Tap to claim compute tokens" |
| 2 | Tap the bubble | `claim()` runs: guard checks (not sender, not already claimed, not animating) |
| 3 | Claim succeeds | `ComputeStore.credit(amount)` adds tokens; `EntitlementStore.markClaimed(id)` persists claim; animated overlay shows "+N tokens" for 1.5s |
| 4 | After animation | Bubble text changes to "Claimed" |

**Edge cases:**
- Sender sees "You sent this red packet" (no tap action).
- Double-tap is prevented by the `isClaimed` guard (persisted in UserDefaults).
- If the sender has insufficient balance, the send button is disabled.

## Business Rules

1. Token balance is per-device (identified by a UUID stored in app-group UserDefaults).
2. Red packet claims are local-only in the current implementation; the backend gift endpoints exist but are not wired to the iOS client.
3. Subscription tiers are determined by `Transaction.currentEntitlements`, not by local state alone.
4. The 3-day trial starts on first app launch and cannot be restarted.
5. Mock mode (no backend URL) is intended for development only; real purchases require a configured backend.

## Source Files

| File | Role |
|------|------|
| `Shared/Model/Monetization.swift` | `EntitlementStore`, `SubscriptionManager`, `ComputeStore`, `PurchaseResult`, `ComputeProduct` |
| `Shared/Model/MessageMarkers.swift` | `RedPacketInfo`, `encodeRedPacketMessage()`, `parseRedPacketMessage()`, `formatTokens()` |
| `Shared/Views/Monetization/MonetizationViews.swift` | `SubscriptionView`, `PaywallView`, `ComputeStoreView`, `SendRedPacketView`, `CIRedPacketView`, `SubscriptionRenewalView` |
| `Shared/Views/UserSettings/DeveloperView.swift` | Backend URL configuration for compute store |
| `Products.storekit` | StoreKit test configuration (4 consumable + 4 subscription products) |
| `Tests iOS/MonetizationTests.swift` | Unit tests for encoding, claim tracking, credit/debit |
