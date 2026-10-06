# Haskell iOS 库编译指南

## 概述

本文档说明如何使用 Nix 交叉编译 popopx-chat 和 popopxmq 的 iOS 库。

## 环境要求

- macOS (aarch64-darwin)
- Nix 包管理器（安装于 `/nix/var/nix/profiles/default/bin/nix`）
- Xcode Command Line Tools
- mac2ios 工具（由 Nix 自动提供）

## 目录结构

```
POPOPX/
├── cabal.project              # Haskell 项目配置
├── flake.nix                  # Nix 构建配置
├── popopxmq/                  # popopxmq 子模块
├── scripts/nix/               # Nix 补丁文件
│   ├── popopxmq-base64url-decodeLenient.patch
│   └── popopxmq-crcv-upgrade-fix.patch
└── apps/ios/
    ├── Libraries/
    │   ├── mac/               # macOS ARM64 库
    │   ├── ios/               # iOS 设备库（ARM64）
    │   └── sim/               # iOS 模拟器库（ARM64）
    └── Vendor/
        └── cactus/cactus-engine/libs/
            ├── curl/          # libcurl 静态库
            ├── cactus_engine/ # CactusEngine 库
            └── needle/        # Needle 库
```

## 编译步骤

### 1. 配置检查

确保 `cabal.project` 包含正确的 flag 配置：

```cabal
packages: 
  .
  ./popopxmq

package popopxmq
    flags: +client_library +swift +commoncrypto

package popopx-chat
    flags: +client_library +swift +commoncrypto
```

确保 `flake.nix` 使用正确的 GHC 版本：

```nix
compiler-nix-name = "ghc966";
```

### 2. Nix 交叉编译

```bash
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
cd /Users/elliot/simple-chat/POPOPX

nix build .#'aarch64-darwin-ios:lib:popopx-chat' \
  --extra-experimental-features "nix-command flakes"
```

编译完成后，生成 `result/pkg-ios-aarch64-swift-json.zip`。

### 3. 解压库文件

```bash
cd apps/ios
rm -rf Libraries/mac Libraries/ios Libraries/sim
mkdir -p Libraries/mac Libraries/ios Libraries/sim

unzip -o ../../result/pkg-ios-aarch64-swift-json.zip -d Libraries/mac
chmod +w Libraries/mac/*

cp Libraries/mac/* Libraries/ios
cp Libraries/mac/* Libraries/sim
```

### 4. 使用 mac2ios 修补库

```bash
MAC2IOS="/nix/store/czc52zsr0aqbn5nbad3pcbm1zms91jx5-mac2ios/bin/mac2ios"

# 修补 iOS 设备库
for f in Libraries/ios/*.a; do
  $MAC2IOS "$f"
done

# 修补 iOS 模拟器库
for f in Libraries/sim/*.a; do
  $MAC2IOS -s "$f"
done
```

**注意：** mac2ios 的 Nix store 路径可能会变化，使用 `find /nix/store -name mac2ios -type f` 查找。

### 5. 复制 Vendor 依赖库

Haskell 库需要额外的 C 依赖库，这些库来自 Vendor 目录：

```bash
# libcurl
cp Vendor/cactus/cactus-engine/libs/curl/ios/device/libcurl.a Libraries/ios/
cp Vendor/cactus/cactus-engine/libs/curl/ios/simulator/libcurl.a Libraries/sim/
cp Vendor/cactus/cactus-engine/libs/curl/macos/libcurl.a Libraries/mac/

# 其他 Vendor 库（如需要）
# cp Vendor/cactus/cactus-engine/libs/... Libraries/...
```

### 6. 创建符号链接（保持 Xcode 兼容性）

如果 Xcode 项目引用旧文件名，创建符号链接：

```bash
for dir in mac ios sim; do
  cd Libraries/$dir
  # 示例：将旧文件名链接到新文件名
  ln -sf libHSpopopx-chat-NEW_HASH-ghc9.6.6.a \
         libHSpopopx-chat-OLD_HASH-ghc9.6.4.a
  ln -sf libHSpopopx-chat-NEW_HASH.a \
         libHSpopx-chat-OLD_HASH.a
  cd ../..
done
```

## 生成的库文件

Nix 构建生成以下文件：

| 文件 | 大小 | 说明 |
|------|------|------|
| `libHSpopopx-chat-*-ghc9.6.6.a` | ~264MB | 完整静态库（含所有依赖） |
| `libHSpopx-chat-*.a` | ~70MB | 核心库 |
| `libffi.a` | ~54KB | FFI 库 |
| `libgmp.a` | ~881KB | GMP 数学库 |
| `libgmpxx.a` | ~33KB | GMP C++ 接口 |

## 补丁文件维护

### popopxmq-base64url-decodeLenient.patch

修改 Base64URL 解码为宽松模式。

**关键：** 路径必须使用 `Popopx` 而非 `Popopx`：
```diff
--- a/src/Popopx/Messaging/Encoding/String.hs
+++ b/src/Popopx/Messaging/Encoding/String.hs
```

### popopxmq-crcv-upgrade-fix.patch

修复 CRcv 连接升级逻辑。

**关键：**
- 路径使用 `Popopx` 而非 `Popopx`
- 连接错误类型使用 `ONE_WAY` 而非 `POPOPX` 或 `POPOPX`

```diff
--- a/src/Popopx/Messaging/Agent.hs
+++ b/src/Popopx/Messaging/Agent.hs
...
+          Nothing -> pure $ Left (CONN ONE_WAY "sendMessagesB_: CRcv, no reply queues")
```

## Xcode 项目配置

### 库搜索路径

```
LIBRARY_SEARCH_PATHS[sdk=iphoneos*] = $(PROJECT_DIR)/Libraries/ios
LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*] = $(PROJECT_DIR)/Libraries/sim
```

### 链接标志

```
-lcurl
-lpopopx-chat-7.1.0.3-*-ghc9.6.6
-lpopopx-chat-7.1.0.3-*
-lgmp
-lgmpxx
-lffi
```

## 常见问题

### Q: Nix 构建失败，提示 GHC 编译错误

**A:** 检查 `flake.nix` 中的 `compiler-nix-name`。当前使用 `ghc966`（GHC 9.6.6）。GHC 9.6.4 在 Nix 中构建有问题。

### Q: 链接错误 "Library 'curl' not found"

**A:** 复制 Vendor 中的 libcurl.a 到 Libraries 目录：
```bash
cp Vendor/cactus/cactus-engine/libs/curl/ios/device/libcurl.a Libraries/ios/
cp Vendor/cactus/cactus-engine/libs/curl/ios/simulator/libcurl.a Libraries/sim/
cp Vendor/cactus/cactus-engine/libs/curl/macos/libcurl.a Libraries/mac/
```

### Q: 补丁应用失败

**A:** 确保补丁文件中的路径使用 `Popopx` 而非 `Popopx`。检查：
- `popopxmq-base64url-decodeLenient.patch`
- `popopxmq-crcv-upgrade-fix.patch`

### Q: mac2ios 工具找不到

**A:** 使用 `find /nix/store -name mac2ios -type f` 查找。路径示例：
```
/nix/store/czc52zsr0aqbn5nbad3pcbm1zms91jx5-mac2ios/bin/mac2ios
```

## 验证

### 检查库文件架构

```bash
cd apps/ios/Libraries/ios
ar t libHSpopopx-chat-*-ghc9.6.6.a | head -3 | while read obj; do
  ar x libHSpopopx-chat-*-ghc9.6.6.a "$obj" 2>/dev/null
  file "$obj"
  rm -f "$obj"
done
```

期望输出：`Mach-O 64-bit object arm64`

### 检查 Xcode 构建

```bash
cd apps/ios
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## 版本信息

- **GHC 版本：** 9.6.6
- **popopx-chat 版本：** 7.1.0.3
- **popopxmq 版本：** 7.0.1.0
- **Nix haskell.nix 分支：** armv7a
- **编译日期：** 2026-10-05

## 参考

- 上游 POPOPX Chat flake.nix
- haskell.nix 文档：https://haskell-nix.readthedocs.io/
- mac2ios 工具：https://github.com/zw3rk/mobile-core-tools
