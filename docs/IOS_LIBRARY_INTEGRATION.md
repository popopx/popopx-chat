# POPOPX iOS 库集成文档

## 概述

本文档说明如何将 Nix 构建的 Haskell 核心库集成到 POPOPX iOS 项目中。

## 构建产物

### 库文件位置

**Nix 构建输出：**
- 设备库：`result/pkg-ios-aarch64-swift-json.zip` (70 MB)
- 模拟器库：`result-ios-sim/pkg-ios-aarch64-simulator-swift-json.zip` (70 MB)

**项目目录：**
- 设备库：`apps/ios/Libraries/ios/`
- 模拟器库：`apps/ios/Libraries/sim/`

### 库文件清单

每个平台包含以下库文件：

| 库文件 | 大小 | 说明 |
|--------|------|------|
| `libHSpopopx-chat-7.1.0.14-6PK52CEPL6eGI19KO8TWaq.a` | 82 MB | 主 Haskell 库 |
| `libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a` | 293 MB | GHC 运行时库 |
| `libgmp.a` | 828 KB | GMP 数学库 |
| `libgmpxx.a` | 32 KB | GMP C++ 绑定 |
| `libffi.a` | 52 KB | 外部函数接口库 |
| `libcurl.a` | 1.3 MB | HTTP 客户端库 (Vendor) |
| `libcactus_engine.a` | 11 MB | Cactus 引擎 (Vendor) |
| `libneedle.a` | 14 MB | Needle 搜索库 (Vendor) |

## 构建流程

### 1. Nix 构建

```bash
# 设备库
nix build .#packages.aarch64-darwin."aarch64-darwin-ios:lib:popopx-chat"

# 模拟器库
nix build .#packages.aarch64-darwin."aarch64-darwin-ios-simulator:lib:popopx-chat"
```

### 2. 创建符号链接

```bash
ln -sf result result-ios-rebuild
ln -sf /nix/store/<simulator-hash>-popopx-chat-lib-popopx-chat-7.1.0.14 result-ios-sim
```

### 3. 运行 prepare.sh

```bash
./scripts/ios/prepare.sh
```

该脚本执行：
- 解压库文件到 `Libraries/mac/`、`Libraries/ios/`、`Libraries/sim/`
- 使用 `mac2ios` 转换平台标识（macOS → iOS/iOS Simulator）

### 4. 复制 Vendor 库

```bash
# 模拟器
cp apps/ios/Vendor/cactus/cactus-engine/libs/curl/ios/simulator/libcurl.a apps/ios/Libraries/sim/
cp apps/ios/Vendor/CactusEngine/Libraries/sim/libcactus_engine.a apps/ios/Libraries/sim/
cp apps/ios/Vendor/Needle2/Libraries/sim/libneedle.a apps/ios/Libraries/sim/

# 设备
cp apps/ios/Vendor/cactus/cactus-engine/libs/curl/ios/device/libcurl.a apps/ios/Libraries/ios/
cp apps/ios/Vendor/CactusEngine/Libraries/ios/libcactus_engine.a apps/ios/Libraries/ios/
cp apps/ios/Vendor/Needle2/Libraries/ios/libneedle.a apps/ios/Libraries/ios/
```

### 5. 重命名 GHC 库

Xcode 项目期望特定的库名称：

```bash
# 模拟器
mv apps/ios/Libraries/sim/libHSpopopx-chat-7.1.0.14-6PK52CEPL6eGI19KO8TWaq-ghc9.6.3.a \
   apps/ios/Libraries/sim/libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a

# 设备
mv apps/ios/Libraries/ios/libHSpopopx-chat-7.1.0.14-6PK52CEPL6eGI19KO8TWaq-ghc9.6.3.a \
   apps/ios/Libraries/ios/libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a
```

### 6. 补丁模拟器库（关键步骤）

模拟器库需要使用 `patch_iossim.py` 补丁，将 `LC_VERSION_MIN_IPHONEOS` 替换为 `LC_BUILD_VERSION` (platform 7)：

```bash
cd apps/ios/Libraries/sim
for lib in libgmp.a libffi.a libgmpxx.a \
           libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a \
           libHSpopopx-chat-7.1.0.14-6PK52CEPL6eGI19KO8TWaq.a; do
    python3 ../patch_iossim.py "$lib" "$lib.tmp"
    mv "$lib.tmp" "$lib"
done
```

**为什么需要这个补丁？**
- Nix 构建的库只有 `LC_VERSION_MIN_IPHONEOS` 加载命令
- Xcode 17+ 的链接器要求 `LC_BUILD_VERSION` 明确指定平台
- `patch_iossim.py` 将平台标识从 iOS (2) 改为 iOS Simulator (7)

### 7. Xcode 构建

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

## 依赖项

### Haskell 核心依赖

- **GHC 9.6.3**: Haskell 编译器
- **popopxmq 7.1.0.14**: 消息队列库
- **direct-sqlcipher**: SQLite 加密
- **aeson**: JSON 处理

### 系统依赖

- **libgmp**: GNU 多精度算术库
- **libffi**: 外部函数接口
- **libcurl**: HTTP 客户端
- **libc++**: C++ 标准库
- **libiconv**: 字符编码转换
- **zlib**: 压缩库

### Vendor 依赖

- **CactusEngine**:  mesh 网络引擎
- **Needle2**: 搜索库
- **WebRTC**: 实时通信

## 编译配置

### cabal.project 标志

```
package popopxmq
    flags: +client_library +swift +commoncrypto

package popopx-chat
    flags: +client_library +swift
```

### Xcode 链接标志

```
-lgmp -lffi -lgmpxx -lHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3 -lcactus_engine
```

## 验证

### 检查库平台

```bash
# 检查库是否包含 LC_BUILD_VERSION
otool -l libgmp.a | grep -A 5 "LC_BUILD_VERSION"

# 应该显示：
# cmd LC_BUILD_VERSION
#   cmdsize 24
#  platform 7  # 7 = iOS Simulator, 2 = iOS
#     minos 11.0
#       sdk n/a
```

### 测试模拟器构建

```bash
# 构建
cd apps/ios
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# 安装
xcrun simctl install <DEVICE_ID> \
  ~/Library/Developer/Xcode/DerivedData/POPOPX-*/Build/Products/Debug-iphonesimulator/POPOPX.app

# 启动 (Bundle ID: com.popopxchat.popopx)
xcrun simctl launch <DEVICE_ID> com.popopxchat.popopx

# 截图
xcrun simctl io <DEVICE_ID> screenshot /tmp/test.png
```

## 常见问题

### 1. 链接错误："building for 'iOS-simulator', but linking in object file built for 'iOS'"

**原因：** 库文件缺少 `LC_BUILD_VERSION` 或平台标识不正确

**解决：** 使用 `patch_iossim.py` 补丁所有模拟器库

### 2. 链接错误："library 'HSpopopx-chat-7.1.0.14-inplace-ghc9.6.3' not found"

**原因：** GHC 库文件名不匹配

**解决：** 重命名为 `libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a`

### 3. DerivedData 锁定

**解决：**
```bash
pkill -9 -f xcodebuild
pkill -9 -f XCBuild
rm -rf ~/Library/Developer/Xcode/DerivedData/POPOPX-*
```

### 4. mac2ios 路径错误

**解决：** 更新 `scripts/ios/prepare.sh` 中的 mac2ios 路径：
```bash
MAC2IOS=/nix/store/<hash>-mac2ios/bin/mac2ios
```

查找当前路径：
```bash
find /nix/store -name "mac2ios" -type f
```

## 自动化脚本

创建一键构建脚本 `scripts/ios/build-all.sh`：

```bash
#!/bin/bash
set -e

echo "=== Building Nix libraries ==="
nix build .#packages.aarch64-darwin."aarch64-darwin-ios:lib:popopx-chat"
nix build .#packages.aarch64-darwin."aarch64-darwin-ios-simulator:lib:popopx-chat"

echo "=== Creating symlinks ==="
ln -sf result result-ios-rebuild
# Update simulator symlink with current hash

echo "=== Running prepare.sh ==="
./scripts/ios/prepare.sh

echo "=== Copying vendor libraries ==="
# Copy vendor libs...

echo "=== Renaming GHC libraries ==="
# Rename...

echo "=== Patching simulator libraries ==="
cd apps/ios/Libraries/sim
for lib in libgmp.a libffi.a libgmpxx.a \
           libHSpopopx-chat-7.1.0.14-inplace-ghc9.6.3.a \
           libHSpopopx-chat-7.1.0.14-6PK52CEPL6eGI19KO8TWaq.a; do
    python3 ../patch_iossim.py "$lib" "$lib.tmp"
    mv "$lib.tmp" "$lib"
done

echo "=== Building iOS app ==="
cd /Users/elliot/POPOPX/popopx-chat/apps/ios
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

echo "=== Build complete ==="
```

## 版本信息

- **popopx-chat**: 7.1.0.14
- **GHC**: 9.6.3
- **mac2ios**: mobile-core-tools
- **Xcode**: 27.1+
- **iOS Deployment Target**: 17.6

## 参考

- [AGENTS.md](../../AGENTS.md) - 项目构建说明
- [project-ios-build-process.md](~/.qoder-cn/projects/-Users-elliot-POPOPX-popopx-chat/memory/project-ios-build-process.md) - 构建流程记忆
- [project-ios-lib-build-both.md](~/.qoder-cn/projects/-Users-elliot-POPOPX-popopx-chat/memory/project-ios-lib-build-both.md) - 库构建说明

---

**最后更新**: 2026-10-27  
**维护者**: POPOPX Team
