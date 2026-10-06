# AGENTS.md

This file provides guidance to the AI agent when working with code in this repository.

## Project Overview

POPOPX Chat - privacy-focused messaging platform with no user identifiers. Multi-platform: Haskell core library, iOS (SwiftUI), Android (Kotlin Multiplatform), PHP backend.

## Build Commands

### Haskell Core
```bash
cabal build                          # Build all
cabal test                           # Run tests
cabal build --flag swift             # Enable Swift JSON format
cabal build --flag client_library    # Client-only build (no server/CLI)
cabal build --flag client_postgres   # PostgreSQL instead of SQLite
```

### iOS App
**Must run from `apps/ios/` directory:**
```bash
cd apps/ios
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,id=<DEVICE_ID>' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

**iOS Simulator commands:**
```bash
xcrun simctl list devices                    # List devices
xcrun simctl boot <DEVICE_ID>                # Boot device
xcrun simctl install <DEVICE_ID> <APP_BUNDLE> # Install app
xcrun simctl launch <DEVICE_ID> chat.popopx.app  # Launch app
xcrun simctl io <DEVICE_ID> screenshot <FILE>     # Screenshot
```

**Bundle ID:** `chat.popopx.app`  
**App Group:** `group.chat.popopx.app`

### Backend (PHP)
```bash
cd backend
composer install
composer test                    # Run PHPUnit tests
```

## Code Style

### Haskell
- **Formatter:** fourmolu (2-space indent, no column limit, trailing commas)
- **Config:** `fourmolu.yaml`
- **Install:** `cabal install fourmolu` (not in PATH by default)
- Run: `fourmolu --mode inplace <file>`

### Swift
- Follow existing patterns in `Shared/` directory
- Use `ObservableObject` for state management
- FFI calls wrapped in `POPOPXChat/API.swift`

### PHP
- PSR-12 style
- PHPUnit for tests

## Critical Gotchas

### iOS Build
1. **Always build from `apps/ios/` directory** - building from root produces incomplete bundles
2. **Code signing flags required** for simulator builds (see above)
3. **DerivedData locks** - if build fails with "database locked", run:
   ```bash
   pkill -9 -f xcodebuild
   pkill -9 -f XCBuild
   rm -rf ~/Library/Developer/Xcode/DerivedData/POPOPX-*
   ```
4. **Icon assets** - `Contents.json` references files as `20.png`, `40.png` etc. (NOT `Icon-40.png`)
5. **Haskell libraries** pre-compiled in `Libraries/sim/` (simulator) and `Libraries/mac-x86_64/` (macOS)
6. **Local.xcconfig** (gitignored) for `DEVELOPMENT_TEAM` - set your Apple Team ID for device builds

### Haskell
- **GHC version:** 9.6.3 (pinned in flake.nix)
- **Package index:** 2023-12-12T00:00:00Z (pinned in cabal.project)
- **Source packages** pinned to specific commits (popopxmq, direct-sqlcipher, etc.)
- **OpenSSL path** on macOS: `/usr/local/opt/openssl@3.0/` (see `cabal.project.local`)

### Nix
- **Flake inputs:** haskell.nix, mac2ios (for iOS cross-compilation)
- **Build:** `nix build` (outputs to `./result`)
- **iOS lib:** `nix build .#popopx-chat-lib-popopx-chat` → `./result-ios-sim`

## Architecture

### Haskell Core
- Main library: `Popopx.Chat.*` modules in `src/`
- FFI exports in `POPOPXChat/POPOPX.h`:
  - `chat_migrate_init_key()` - DB init/migration
  - `chat_send_cmd_retry()` - Send commands
  - `chat_recv_msg_wait()` - Receive messages
- **Heap sizes:** Main app 64MB, NSE 512KB, SE 1MB

### iOS App Structure
- **Entry:** `Shared/POPOPXApp.swift`
- **State:** `ChatModel` (singleton ObservableObject), `ItemsModel`
- **Targets:** POPOPX (iOS), POPOPX NSE (notifications), POPOPX SE (share)
- **Shared data:** App Group + Keychain (`kcDatabasePassword`, `kcAppPassword`)

### Backend
- PHP 8.1+ with PDO, OpenSSL
- Compute store for token purchases
- Tests in `backend/tests/`

## Testing

### Haskell
```bash
cabal test                           # All tests
cabal test --test-show-details=direct # Verbose output
```
Test files in `tests/` directory. Fixtures in `tests/fixtures/`.

### iOS
- UI tests in `Tests iOS/` target
- Run via Xcode: Product > Test
- Or: `xcodebuild test -scheme "POPOPX (iOS)" -destination 'platform=iOS Simulator,name=iPhone 15'`

### Backend
```bash
cd backend && composer test
```

## Branch & PR Conventions

- **Main branches:** `master` (development), `stable` (release)
- **Release tags:** `v*` (triggers CI release workflow)
- **CI triggers:** Changes to `src/`, `apps/`, `tests/`, `bots/`, `popopx-chat.cabal`, `cabal.project`
- **Commit style:** Conventional commits with scope (e.g., `ios:`, `backend:`, `nix:`)

## Environment Setup

### macOS Development
1. Install Nix: `curl -L https://nixos.org/nix/install | sh`
2. Install Xcode 26.5+ + Command Line Tools
3. OpenSSL: `brew install openssl@3` (path: `/usr/local/opt/openssl@3.0/`)
4. ImageMagick (for icon generation): `brew install imagemagick`
5. fourmolu: `cabal install fourmolu`

### Nix Build Outputs
- `./result` → mac2ios tool
- `./result-ios-sim` → Haskell iOS simulator library
- `./result-mac2ios` → mac2ios tool (symlink)

### Simulator Devices
- iOS 26.4: iPhone 17 Pro (`2FB0FB12-4FFC-4717-86EC-114AAF6D7089`) - commonly used
- iOS 26.0/26.5: Also available

### Key Paths
- iOS app: `apps/ios/`
- Haskell source: `src/Popopx/Chat/`
- Backend: `backend/`
- Scripts: `scripts/`
- Nix config: `flake.nix`, `cabal.project`
- OpenSSL config: `cabal.project.local`
