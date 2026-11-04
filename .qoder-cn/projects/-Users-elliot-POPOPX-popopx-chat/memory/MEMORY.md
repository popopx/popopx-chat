---
name: MEMORY.md
description: Project-scope durable memories index
metadata:
  type: index
---

- [iOS Haskell build process](project-ios-haskell-build.md) — Nix build, cabal.project flags, library patching for simulator (2026-10-07)
- [ErrorCorrupt database init](project-errorcorrupt-database-init.md) — ErrorCorrupt persists on fresh simulator despite correct SQLCipher build and code logic
- [Rebrand completed](project-rebrand-verification.md) — simplex→popopx rebrand complete: 528 replacements, compile errors fixed, lib builds clean (2026-10-08)
- [Full rebrand + dep update pushed](project-simplex-rebrand-complete.md) — 3 commits: rebrand 4901f663a, fixes 15814bf9b, popopxmq→cb189f9 6a0061e53 (2026-10-16)
- [SimpleX capital-X rebrand gap](feedback-simplex-capital-x-rebrand.md) — upstream sync must include SimpleX→PopopX rule; original rebrand missed it
- [POPOPX-specific modules](project-popopx-specific-modules.md) — 5 POPOPX-only modules (LinkEncryption, RemoteConfig, Directory.Util, 2 migrations)
- [iOS lib build both targets](project-ios-lib-build-both.md) — always build both device + simulator libs; patch sim with patch_iossim.py; copy vendor libs
- [iOS build process](project-ios-build-process.md) — Complete Nix + Xcode build flow for device and simulator, prepare.sh, mac2ios usage (2026-10-13)
- [iOS build blocked on nix-tools download](project-ios-build-nix-tools-download.md) — GitHub download unstable, retry loop needed for 223MB nix-tools-static.zip (2026-10-14)
- [Upstream sync v7.1.0.12 complete](project-upstream-sync-v7.1.0.12-complete.md) — badge in-app purchase, CPTAgent, chat_peer_type fix, popopxmq→v7.1.0.12, 3 commits on master (2026-10-18)
- [Simplex residual analysis](project-simplex-residual-analysis-2026-10-16.md) — 15,671 references found; breakdown by directory, priority plan, AGPL exclusions documented (2026-10-16)
- [Rebrand archive](project-rebrand-archive-2026-10-16.md) — complete session archive: 4 commits, 10 agents, 1080 files, 85.4% replaced (2026-10-16)
- [haskell.nix armv7a resolved](project-haskell-nix-ghc963-revision.md) — armv7a 分支已稳定指向 d0c35e75 (GHC 9.6.3)，无需特殊锁定 (2026-10-18)
- [Nix flake aligned with upstream](project-hackage-nix-fix.md) — haskellNix armv7a + hackageNix default, all locked revisions match upstream (2026-10-18)
- [SQLCipher ErrorCorrupt debugging](project-sqlcipher-errorcorrupt-debugging.md) — Adding detailed logging to diagnose ErrorCorrupt during CREATE TABLE contact_profiles (2026-10-17)
- [SQLCipher iOS simulator ErrorCorrupt](project-sqlcipher-ios-simulator-errorcorrupt.md) — SQLCipher CREATE TABLE fails with ErrorCorrupt on iOS simulator despite correct key management (2026-10-17)
- [Upstream sync badge proof complete](project-upstream-sync-badge-proof.md) — ProofPresHeader, cross-group invites, notification flags (2026-10-18)
- [KeyDerivation security audit](project-key-derivation-audit.md) — PBKDF2 合规，3 修复 + 恒定时间比较 +Keychain 属性验证 (2026-10-18)
- [popopxmq update + deps push](project-popopxmq-update-2026-10-18.md) — popopxmq→v7.1.0.12 (a1c48854), cabal.project tag 更新，264/264 modules (2026-10-18)
- [iOS native Cabal build](project-ios-native-cabal-build.md) — Method 3: cabal build + mac2ios patching, cabal.project.local iOS config, lib naming & deps (2026-10-21)
- [SQLCipher migration fix](project-sqlcipher-migration-fix.md) — ErrorCorrupt fix: switch from SQLite3.exec to SQL.execute_ with statement splitting (2026-10-23)
- [SQLCipher iOS encryption parameters](project-sqlcipher-ios-encryption-parameters.md) — ErrorCorrupt fix: add cipher_page_size=4096, cipher_compatibility=4 PRAGMAs for iOS device (2026-10-25)
- [SQLCipher simplified initialization](project-sqlcipher-simplified-init.md) — Final fix: use only PRAGMA key, remove redundant sqlite3_key API and cipher PRAGMAs (2026-10-25)
- [SQLCipher ErrorCorrupt final fix](project-sqlcipher-errorcorrupt-final-fix.md) — 最终方案：分割语句+SQL.execute_执行每个语句，避免 sqlite3_exec 破坏事务 (2026-10-25)
- [SQLCipher experiment 7 status](project-experiment7-status.md) — 实验 7 代码已提交 (迁移顺序调整),Nix 构建被 hnix OOM 阻塞，需内存充足时重试 (2026-10-26)
- [iOS minos version fix](project-ios-minos-fix.md) — patch_minos.py fixes mac2ios minos 27.0 → 17.6 to match Xcode deployment target (2026-10-26)
- [SQLCipher migration fix complete](project-sqlcipher-migration-fix-complete.md) — Complete fix: table reordering + execSQL split + PRAGMA settings + patch_iossim.py, all pushed to GitHub, iOS build SUCCESS (2026-10-27)
- [popopxmq tag update 71148d99](project-popopxmq-tag-71148d99.md) — popopxmq→71148d99, SHA256 must use --fetch-submodules for cbits/blst+libbbs (2026-10-28)
- [SQLCipher 密钥传输和迁移事务修复](project-sqlcipher-key-migration-fix-2026-10-29.md) — hex 格式密钥传输 + 迁移 SQL 分割 +popopxmq f4c3cc5+direct-sqlcipher f814ee68+Nix 哈希修正 (2026-10-29)
- [SQLCipher ErrorCorrupt root cause and fix](project-sqlcipher-errorcorrupt-root-cause.md) — 最终根因：cipher_* PRAGMAs 在 PRAGMA key 之前导致 SQLITE_NOTADB; 对齐上游：key 优先，删除 cipher_page_size/cipher_compatibility (2026-10-29)
- [SQLCipher PRAGMA key order rule](feedback-sqlcipher-pragma-key-order.md) — PRAGMA key 必须是 DB.open 后第一个操作; cipher_compatibility 会触发 DB 读取导致 NOTADB; 对齐上游 simplexmq 模式 (2026-10-29)
- [iOS SDK deprecation fixes](project-ios-sdk-deprecation-fixes-2026-10-29.md) — iOS 26/27 SDK: LocalizedStringKey interpolation, UIScreen.main, CLGeocoder, previewLayout, Text+, AVAssetExportSession.status (2026-10-29)
- [Onboarding stuck opening app fix](project-onboarding-stuck-opening-app.md) — App stuck on "Opening app" when onboarding complete but no user; fix: check listUsers() and reset onboarding if empty (2026-10-29)
