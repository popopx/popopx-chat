# POPOPX Rebrand Changelog — 2026-10-16

## Full SimpleX → POPOPX Rebrand

Comprehensive rebranding of all user-visible strings, code identifiers, build configurations, localization files, SDK packages, and documentation from "SimpleX" to "POPOPX".

### Statistics

- **Before**: 32,594 lines containing "simplex" references
- **After**: ~4,774 lines remaining (all protected or historical)
- **Files changed**: 1,077 (across 2 commits)
- **Insertions**: 22,755 / **Deletions**: 61,671
- **Commits**: `4901f663a` (main rebrand) + `15814bf9b` (2 follow-up fixes)
- **Pushed to**: `origin` (github.com/popopx/popopx-chat.git)

### Dependency Updates

- **2026-10-16**: `popopxmq` updated to tag `cb189f9111a9998e64eef8660edc3dc41e4114ee` (commit `6a0061e53`)

### What was changed

#### iOS App (apps/ios/)
- Swift source code: `.simplexLink` → `.popopxLink`, `simplexUri` → `popopxUri`, etc.
- Onboarding: `step1_SimpleXInfo` → `step1_PopopXInfo`
- 105 Localizable.strings files (20+ languages): keys and values rebranded
- 27 .xliff localization files in .xcloc bundles
- ConfigBot, BinThereBot: imports and descriptions updated
- POPOPXSwitch: exported symbols comments, build settings
- Build artifacts (BitchatMesh/build/): 16 tracked files removed

#### Android / Multiplatform (apps/multiplatform/)
- 533 Kotlin files rebranded
- 37 files/directories renamed (SimpleXAPI.kt → PopopXAPI.kt, etc.)
- Package renamed: `chat.simplex` → `chat.popopx`
- 45+ XML localization files updated across all locales
- AndroidManifest.xml: scheme `simplex` → `popopx`
- Greek translation fix: `SImpleX` → `POPOPX`

#### SDK Packages (packages/)
- `simplex-chat-python/` → `popopx-chat-python/` (directory renamed)
- `simplex-chat-nodejs/` → `popopx-chat-nodejs/` (directory renamed)
- `simplex-chat-client/` → removed (popopx-chat-client/ already existed)
- `simplex-chat-webrtc/` → removed (popopx-chat-webrtc/ already existed)
- All Python/TypeScript imports, module names, CLI commands updated

#### Build Scripts & CI (scripts/, .github/)
- 30 files modified + 2 script files renamed
- Fixed 3 broken paths: `src/Simplex/Chat/Mobile.hs` → `src/Popopx/Chat/Mobile/`
- Debian package metadata: maintainer, description rebranded
- iOS build scripts: asset names, Xcode project references updated
- Badge service, calculator-bot, relay Dockerfiles updated
- GitHub Actions: binary names, trigger paths, cache keys updated
- Flatpak: app ID, name, icons rebranded

#### Documentation & Website
- docs/: 108 files (guides, RFCs, protocol specs, translations)
- website/: 139 files (HTML, JS, CSS, 26 language JSON files)
- CHANGELOG.md: release notes rebranded
- Dockerfile: build targets and binary names updated
- fastlane/: app store metadata updated

#### Bots
- popopx-calculator-bot: `@simplex-chat/types` → `@popopx-chat/types`
- popopx-support-bot-light: Haskell source path references updated

### What was intentionally preserved

1. **Copyright headers** (AGPL 3.0 requirement): `Copyright (C) simplex.chat`
2. **Upstream GitHub URLs**: `github.com/simplex-chat/*` (forked repos)
3. **Upstream domain URLs**: `simplex.chat`, `simplex.im` (protocol servers)
4. **Attribution constants**: `originalCredit`, `originalRepo`, `originalWebsite`
5. **Apple Developer certificates**: `SimpleX Chat Ltd (5NN7GUYB6T)`
6. **CI secrets**: `APPLE_SIMPLEX_NOTARIZATION_*`, `STATUS_SIMPLEX_WEBHOOK_*`
7. **Historical content**: blog/ and plans/ directories
8. **Legal documents**: PRIVACY.md (references SimpleX Chat Ltd as legal entity)
9. **Blog URL slugs**: popopxchat.com/blog/*-simplex-* (would break links)
10. **Social media URLs**: mastodon, twitter, reddit (external platforms)
11. **External article URLs**: itsfoss.com, heise.de, monerica.com, etc.
