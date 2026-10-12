# Monetization — Technical Specification

> StoreKit 2 integration, PHP backend for purchase verification, message-marker protocol for red packets.
>
> **Related product:** [product/flows/monetization.md](../product/flows/monetization.md)

## Architecture

```
┌──────────────┐     StoreKit 2      ┌──────────────────┐
│  iOS App     │ ◄──────────────────► │  Apple App Store │
│              │                      └────────┬─────────┘
│ ComputeStore │     POST /orders              │
│ (Swift)      │ ──────────────────► ┌────────┴─────────┐
│              │     {jws, tx_id}    │  PHP Backend      │
│ Entitlement  │                     │  (Apache + MySQL) │
│ Store        │ ◄────────────────── │                   │
│              │     {balance}       │ AppleReceipt      │
└──────────────┘                     │ Verifier (JWS)    │
                                     └───────────────────┘
```

## iOS Layer

### EntitlementStore

Singleton persisting monetization state in app-group `UserDefaults` (`groupDefaults`).

| Property | Key | Type | Notes |
|----------|-----|------|-------|
| `trialStart` | `monTrialStart` | `TimeInterval` | Unix timestamp of first launch |
| `storedTier` | `monUserTier` | `String` (`UserTier.rawValue`) | `.free`, `.basic`, `.premium` |
| `subscriptionExpiryDate` | `monSubscriptionExpiry` | `TimeInterval?` | Set from StoreKit entitlement |
| `tokenBalance` | `monTokenBalance` | `Double` | Local token balance |
| `storeBaseURL` | `monComputeStoreBaseURL` | `String` | PHP backend URL (empty = mock mode) |
| `claimedPackets` | `monClaimedPackets` | `[String]` | Red packet IDs already claimed |
| `deviceId` | `monDeviceId` | `String` | UUID generated on first access |

**Source:** [`EntitlementStore`](Shared/Model/Monetization.swift#L50-L114)

### SubscriptionManager

`@MainActor` `ObservableObject` managing StoreKit 2 auto-renewable subscriptions.

- Loads products: `Product.products(for: [PRODUCT_BASIC_YEARLY, PRODUCT_PREMIUM_YEARLY])`
- Entitlement check: iterates `Transaction.currentEntitlements` for verified, non-revoked transactions
- Listens for updates via `Transaction.updates` async sequence (runs in `Task.detached`)
- Derived state: `effectiveTier` (paid > trial premium > free), `isLocked`, `canAddSMPServer`, `needsRenewalReminder`

**Source:** [`SubscriptionManager`](Shared/Model/Monetization.swift#L118-L256)

### ComputeStore

`@MainActor` `ObservableObject` managing consumable token products.

**Product loading:**
- `loadProducts()` — fetches catalog from `GET /products` or falls back to `mockProducts`
- `loadStoreKitProducts()` — calls `Product.products(for:)` with StoreKit IDs from the catalog

**Purchase flow (`purchase(_:)`):**

```
purchase(product)
├── Mock mode (no baseURL): credit(tokenAmount) → .success
└── Real mode:
    ├── Find StoreKit Product by storeKitProductId
    ├── product.purchase() → VerificationResult
    ├── submitVerification(verification, for: product)
    │   ├── Extract JWS via verification.jwsRepresentation
    │   ├── POST /orders {device_id, transaction_id, product_id, jws}
    │   ├── 200: transaction.finish() + update balance → .success
    │   ├── 4xx: transaction.finish() + show error → .failure
    │   └── 5xx: keep transaction open + show error → .failure
    └── Handle .pending / .userCancelled
```

**Transaction listener (`startListeningForConsumableUpdates()`):**
- Runs in a regular `Task` (inherits `@MainActor`)
- Filters `StoreKit.Transaction.updates` for `ALL_TOKEN_PRODUCT_IDS`
- Submits each verified transaction to the backend for balance reconciliation

**Local operations:**
- `credit(amount)` — adds to `@Published balance` + persists to `EntitlementStore`
- `debit(amount)` — subtracts if sufficient; returns `false` otherwise

**Source:** [`ComputeStore`](Shared/Model/Monetization.swift#L286-L493)

### Red Packet Message Protocol

Red packets are encoded as text messages that travel over the existing POPOPX protocol without core changes.

**Encoding format:**
```
🧧SXRP:<base64-encoded JSON>\n🧧 <message> · <amount> tokens
```

**JSON payload (`RedPacketInfo`):**
```json
{
  "id": "uuid-string",
  "amount": 50.0,
  "message": "Happy New Year",
  "from": "Alice"
}
```

**Functions:**
- `encodeRedPacketMessage(_:)` — serializes `RedPacketInfo` to the marker format
- `parseRedPacketMessage(_:)` — extracts and decodes from a raw message string
- Older clients see the fallback text line: `🧧 Happy New Year · 50 tokens`

**Source:** [`MessageMarkers.swift`](Shared/Model/MessageMarkers.swift)

## PHP Backend

### Directory Structure

```
backend/
├── public/
│   ├── index.php              # Front controller / router
│   └── .htaccess              # Apache URL rewrite
├── config/
│   ├── database.php           # PDO MySQL connection
│   ├── app.php                # Bundle ID, cert paths, rate limits
│   └── certs/
│       └── AppleRootCA-G3.cer # Apple Root CA for JWS verification
├── src/
│   ├── Database.php           # PDO wrapper with prepared statements
│   ├── AppleReceiptVerifier.php  # StoreKit 2 JWS verification
│   └── Controllers/
│       ├── ProductController.php   # GET /products
│       ├── BalanceController.php   # GET /balance
│       ├── OrderController.php     # POST /orders
│       └── GiftController.php      # POST /gift, POST /gift/{id}/claim
└── migrations/
    └── 001_initial_schema.sql # MySQL schema + seed data
```

### API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/products` | None | Return active product catalog |
| GET | `/balance?device_id=<uuid>` | None | Return token balance for device |
| POST | `/orders` | None | Verify JWS transaction, credit tokens |
| POST | `/gift` | None | Create red packet (debit balance) |
| POST | `/gift/{id}/claim` | None | Claim red packet (credit balance) |

### Database Schema (MySQL)

**`devices`** — One row per client device.
- `device_id` VARCHAR(36) PK
- `created_at`, `last_seen_at` TIMESTAMP

**`balances`** — Token balance per device.
- `device_id` VARCHAR(36) FK → devices
- `balance` DECIMAL(20,4)
- `updated_at` TIMESTAMP

**`products`** — Token product catalog (seeded).
- `product_id` VARCHAR(100) PK
- `title`, `price_usd`, `token_amount`, `icon`, `active`

**`transactions`** — Purchase records with idempotency.
- `id` BIGINT AUTO_INCREMENT PK
- `device_id` FK → devices
- `apple_transaction_id` VARCHAR(64) **UNIQUE** — prevents double-crediting
- `product_id` FK → products
- `jws` TEXT — raw JWS for audit
- `token_amount` DECIMAL(20,4)
- `status` ENUM('pending','completed','failed','refunded')
- `created_at`, `completed_at` TIMESTAMP

**`gifts`** — Red packet records.
- `id` VARCHAR(36) PK (UUID)
- `sender_id` FK → devices
- `amount` DECIMAL(20,4)
- `message` TEXT
- `status` ENUM('active','claimed','expired')
- `created_at` TIMESTAMP

**`gift_claims`** — Who claimed which gift.
- `gift_id` FK → gifts
- `claimer_id` FK → devices
- `amount` DECIMAL(20,4)
- `claimed_at` TIMESTAMP
- Composite PK: (gift_id, claimer_id)

### AppleReceiptVerifier (JWS Verification)

The verifier validates StoreKit 2 transaction signatures without calling Apple's server.

**Algorithm:**

1. Split JWS into header, payload, signature (base64url-decoded)
2. Decode header JSON; validate `alg` is `ES256`
3. Extract `x5c` certificate chain (leaf + intermediate)
4. Load Apple Root CA G3 from `config/certs/AppleRootCA-G3.cer`
5. Verify certificate chain: leaf → intermediate → Apple Root CA G3
6. Extract public key from leaf certificate
7. Verify ECDSA signature over `header.payload` using the public key
8. Decode payload JSON; validate `bundleId` matches expected
9. Check `revocationDate` is null
10. Return decoded payload or null on any failure

**Source:** [`AppleReceiptVerifier.php`](../../backend/src/AppleReceiptVerifier.php)

### Order Processing (POST /orders)

1. Validate inputs: `device_id` (UUID format), `transaction_id`, `product_id`, `jws`
2. Idempotency: check if `apple_transaction_id` already exists with status `completed` → return existing balance
3. Verify JWS via `AppleReceiptVerifier`
4. Cross-check: payload `productId` matches claimed `product_id`; payload `transactionId` matches claimed `transaction_id`
5. Check `revocationDate` is null
6. Look up product in `products` table
7. Begin MySQL transaction:
   - INSERT into `transactions` (status = `completed`)
   - UPDATE `balances` SET balance = balance + token_amount
8. Commit; return `{status: "completed", balance, tokens_credited}`

**Error handling:**
- Invalid JWS → 400
- Duplicate transaction → 200 (idempotent, return existing balance)
- Product not found → 404
- Network/DB error → 500

## Configuration

### iOS Developer Settings

The backend URL is configured in Developer settings (`DeveloperView.swift`):
- Empty URL → mock mode (local credit/debit, no StoreKit)
- Any URL → real mode (StoreKit purchase + backend verification)

### PHP Backend

Environment variables (or defaults in `config/database.php`):
- `DB_HOST` (default: `127.0.0.1`)
- `DB_NAME` (default: `popopx_compute`)
- `DB_USER` (default: `root`)
- `DB_PASS` (default: empty)

Application config (`config/app.php`):
- `bundle_id`: must match the iOS app's bundle identifier
- `apple_root_cert_path`: path to `AppleRootCA-G3.cer`

## Testing

### iOS Unit Tests

`Tests iOS/MonetizationTests.swift` covers:
- Red packet encode/decode roundtrip (normal, empty message, fractional amount)
- Cross-type parse rejection (location message → nil for red packet parser)
- `formatTokens` for whole and fractional values
- `EntitlementStore` claim tracking (mark, idempotency, multiple packets)
- Device ID persistence and UUID validity
- `ComputeStore` credit/debit (increase, decrease, insufficient funds, zero, negative)
- Red packet send/claim flow integration
- Mock product validation (StoreKit IDs, positive token amounts)

### Manual Testing

1. **Mock purchase:** Leave backend URL empty → tap any product → tokens credited locally
2. **StoreKit sandbox:** Configure StoreKit test configuration (`Products.storekit`) → test purchase flow in simulator
3. **Red packet:** Send a red packet → verify sender balance decreases → receive on another device → tap to claim → verify balance increases
4. **Backend:** Run PHP locally (`php -S localhost:8080 -t backend/public`) → set URL in Developer settings → test real purchase flow
