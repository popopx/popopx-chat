# PopopX Chat 编译命令说明

本文档包含 PopopX Chat 项目的所有编译和构建命令。

## 目录

- [Haskell 核心库编译](#haskell-核心库编译)
- [iOS 应用编译](#ios-应用编译)
- [PHP 后端编译](#php-后端编译)
- [Nix 构建](#nix-构建)
- [测试命令](#测试命令)
- [代码格式化](#代码格式化)

---

## Haskell 核心库编译

### 基础编译命令

```bash
# 编译所有组件
cabal build

# 编译特定可执行文件
cabal build exe:popopx-chat
cabal build exe:popopx-bot
cabal build exe:popopx-bot-advanced
cabal build exe:popopx-directory-service
cabal build exe:popopx-badge-service
cabal build exe:popopx-broadcast-bot

# 编译测试套件
cabal build test:popopx-chat-test

# 启用 Swift JSON 格式编译
cabal build --flag swift

# 仅编译客户端库（不包含服务器/CLI）
cabal build --flag client_library

# 使用 PostgreSQL 替代 SQLite
cabal build --flag client_postgres

# 清理并重新编译
cabal clean
cabal build
```

### 运行应用程序

```bash
# 运行主聊天应用
cabal run popopx-chat

# 查看版本
cabal run popopx-chat -- --version

# 运行机器人
cabal run popopx-bot
cabal run popopx-bot-advanced

# 运行目录服务
cabal run popopx-directory-service

# 运行徽章服务
cabal run popopx-badge-service

# 运行广播机器人
cabal run popopx-broadcast-bot
```

### 可执行文件位置

编译后的可执行文件位于：
```
dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopx-chat-7.1.0.10/x/
├── popopx-badge-service/build/popopx-badge-service/popopx-badge-service
├── popopx-bot/build/popopx-bot/popopx-bot
├── popopx-bot-advanced/build/popopx-bot-advanced/popopx-bot-advanced
├── popopx-broadcast-bot/build/popopx-broadcast-bot/popopx-broadcast-bot
├── popopx-chat/build/popopx-chat/popopx-chat
└── popopx-directory-service/build/popopx-directory-service/popopx-directory-service
```

---

## iOS 应用编译

### 前置要求

1. 必须先构建 Haskell iOS 库：
   ```bash
   nix build .#popopx-chat-lib-popopx-chat
   # 输出到 ./result-ios-sim
   ```

2. 库文件位置：
   - 模拟器：`apps/ios/Libraries/sim/`
   - macOS：`apps/ios/Libraries/mac-x86_64/`

### 编译命令

**重要：必须从 `apps/ios/` 目录运行**

```bash
cd apps/ios

# 基础编译命令
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,id=<DEVICE_ID>' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build

# Release 编译
xcodebuild -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,id=<DEVICE_ID>' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

### 模拟器管理

```bash
# 列出所有可用的模拟器设备
xcrun simctl list devices

# 启动模拟器
xcrun simctl boot <DEVICE_ID>

# 关闭模拟器
xcrun simctl shutdown <DEVICE_ID>

# 安装应用到模拟器
xcrun simctl install <DEVICE_ID> <APP_BUNDLE_PATH>

# 启动应用
xcrun simctl launch <DEVICE_ID> chat.popopx.app

# 截图
xcrun simctl io <DEVICE_ID> screenshot <FILE_PATH>
```

### 常用设备 ID

- iOS 26.4: iPhone 17 Pro (`2FB0FB12-4FFC-4717-86EC-114AAF6D7089`)
- 其他设备可通过 `xcrun simctl list devices` 查看

### 应用信息

- **Bundle ID**: `chat.popopx.app`
- **App Group**: `group.chat.popopx.app`

### 故障排除

如果构建失败，尝试清理 DerivedData：

```bash
# 杀死 Xcode 构建进程
pkill -9 -f xcodebuild
pkill -9 -f XCBuild

# 清理 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/POPOPX-*
```

### 真机构建

对于真机构建，需要设置 `DEVELOPMENT_TEAM`：

1. 创建 `apps/ios/Local.xcconfig` 文件（已被 gitignore）
2. 添加以下内容：
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

---

## PHP 后端编译

### 安装依赖

```bash
cd backend
composer install
```

### 运行测试

```bash
cd backend
composer test
```

---

## Nix 构建

### 主要构建目标

```bash
# 构建主项目（macOS）
nix build
# 输出到 ./result

# 构建 iOS 模拟器库
nix build .#popopx-chat-lib-popopx-chat
# 输出到 ./result-ios-sim

# 构建 mac2ios 工具
nix build .#mac2ios
# 输出到 ./result-mac2ios
```

### Nix 开发环境

```bash
# 进入 Nix 开发 shell
nix develop

# 在开发 shell 中可以使用所有构建工具
cabal build
cabal test
```

---

## 测试命令

### Haskell 测试

```bash
# 运行所有测试
cabal test

# 详细输出
cabal test --test-show-details=direct

# 运行特定测试套件
cabal test test:popopx-chat-test
```

### iOS 测试

```bash
cd apps/ios

# 通过 Xcode 运行测试
# Product > Test

# 或使用命令行
xcodebuild test \
  -project POPOPX.xcodeproj \
  -scheme "POPOPX (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### PHP 后端测试

```bash
cd backend
composer test
```

---

## 代码格式化

### Haskell 代码格式化

使用 fourmolu 格式化工具：

```bash
# 安装 fourmolu（如果未安装）
cabal install fourmolu

# 格式化单个文件
fourmolu --mode inplace <file.hs>

# 格式化整个目录
find src tests apps -name "*.hs" -exec fourmolu --mode inplace {} \;
```

**格式化配置**：
- 2 空格缩进
- 无列宽限制
- 尾随逗号
- 配置文件：`fourmolu.yaml`

### Swift 代码格式化

遵循 `apps/ios/Shared/` 目录中的现有模式。

### PHP 代码格式化

遵循 PSR-12 标准。

---

## 环境配置

### macOS 开发环境设置

1. **安装 Nix**：
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. **安装 Xcode**：
   - 需要 Xcode 26.5 或更高版本
   - 安装命令行工具：`xcode-select --install`

3. **安装 OpenSSL**：
   ```bash
   brew install openssl@3
   ```
   路径：`/usr/local/opt/openssl@3.0/`

4. **安装 ImageMagick**（用于图标生成）：
   ```bash
   brew install imagemagick
   ```

5. **安装 fourmolu**：
   ```bash
   cabal install fourmolu
   ```

### 关键配置

- **GHC 版本**：9.6.3（在 flake.nix 中固定）
- **包索引**：2023-12-12T00:00:00Z（在 cabal.project 中固定）
- **源包**：固定到特定提交（popopxmq, direct-sqlcipher 等）
- **OpenSSL 路径**：macOS 上为 `/usr/local/opt/openssl@3.0/`（见 `cabal.project.local`）

---

## 常见问题

### 编译错误：找不到模块

```bash
# 清理并重新构建
cabal clean
cabal update
cabal build
```

### iOS 构建失败：数据库锁定

```bash
pkill -9 -f xcodebuild
pkill -9 -f XCBuild
rm -rf ~/Library/Developer/Xcode/DerivedData/POPOPX-*
```

### Nix 构建失败

```bash
# 清理 Nix 存储
nix-collect-garbage -d

# 重新构建
nix build
```

### 测试失败：sqlite3 未找到

安装 sqlite3：
```bash
# macOS
brew install sqlite

# Ubuntu/Debian
sudo apt-get install sqlite3
```

---

## 版本信息

- **当前版本**：PopopX Chat v7.1.0.10
- **GHC 版本**：9.6.3
- **iOS 最低版本**：根据 Xcode 项目配置
- **PHP 版本**：8.1+

---

## 相关文档

- [AGENTS.md](../AGENTS.md) - AI 代理项目指南
- [README.md](../README.md) - 项目概述
- [CHANGELOG.md](../CHANGELOG.md) - 变更日志

---

**最后更新**：2026-10-10
