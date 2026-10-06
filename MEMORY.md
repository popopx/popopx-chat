# POPOPX Chat - 项目记忆

## 基本信息

- **项目**: POPOPX Chat v7.1.0.3
- **仓库**: https://github.com/popopx/popopx-chat
- **协议**: AGPL v3
- **上游**: SimpleX Chat (https://github.com/simplex-chat/simplex-chat)
- **二次开发**: POPOPX Team (chat@popopx.chat), 起始于 2026年07月

## 项目结构

```
popopx-chat/
├── src/                    # Haskell 核心库 (Popopx.Chat.*)
├── apps/
│   ├── popopx-chat/        # 主程序 (服务器/CLI)
│   ├── popopx-bot/         # 简单聊天机器人
│   ├── popopx-bot-advanced/# 高级聊天机器人
│   ├── popopx-broadcast-bot/  # 广播机器人
│   ├── popopx-directory-service/  # 目录服务
│   └── popopx-support-bot/ # 支持机器人 (Node.js)
├── packages/
│   ├── popopx-chat-nodejs/ # Node.js 绑定
│   ├── popopx-chat-python/ # Python 绑定
│   ├── popopx-chat-client/ # TypeScript 客户端
│   └── popopx-chat-webrtc/ # WebRTC 支持
├── backend/                # PHP 后端
├── tests/                  # 测试套件
├── scripts/                # 构建和工具脚本
└── install.sh              # CLI 安装脚本
```

## 构建命令

### Haskell 核心
```bash
cabal build          # 构建全部
cabal test           # 运行测试
cabal clean          # 清除缓存
```

### iOS (需从 apps/ios/ 目录执行)
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

### PHP 后端
```bash
cd backend && composer install && composer test
```

## Release 信息

- **最新版本**: v7.1.0.3
- **Release 页面**: https://github.com/popopx/popopx-chat/releases/tag/v7.1.0.3
- **Linux 二进制**: `popopx-chat-ubuntu-22_04-x86_64` (110 MB)
- **安装命令**: `curl -o- https://raw.githubusercontent.com/popopx/popopx-chat/stable/install.sh | bash`

## AGPL v3 合规

- ✅ README.md 包含二次开发声明
- ✅ NOTICE 文件已创建（根目录）
- ✅ 338 个 .hs 文件添加了 Section 5(a) 修改标记
- ✅ 原始版权 `Copyright (C) 2020-2022 simplex.chat` 保留

## .gitignore 规则

排除项:
- `dist-newstyle/` - 编译产物
- `result`, `result-*` - Nix 构建产物
- `node_modules/` - Node 依赖
- `__pycache__/`, `*.pyc`, `*.pyo`, `*.egg-info/` - Python 缓存
- `*.so`, `*.dylib` - 二进制库
- `cabal.project.local` - Cabal 本地配置
- `.qoder/` - 本地设置
- `.DS_Store`, `Thumbs.db` - OS 文件
- `*.swp`, `*.swo`, `*~`, `.idea/`, `.vscode/` - IDE 文件
- `bots/voucher-bot/` - 排除的机器人
- `MEMBERSHIP_SYSTEM.md`, `REBRANDING_CHANGELOG.md`, `REBRANDING_SUMMARY.md` - 排除的文档

## 已完成工作 (2026-10-06)

1. 清除编译缓存，重新编译
2. 添加 AGPL v3 合规声明（README、NOTICE、338 个 .hs 文件）
3. 更新 GitHub 地址: `popopx-chat/popopx-chat` → `popopx/popopx-chat`
4. 重写 README，移除不存在的内容（docs/、blog/、捐赠、翻译表等）
5. 删除 images/ 和 media-logos/ 目录（上游品牌资源）
6. 清理 node_modules（1561 个文件从 git 跟踪中移除）
7. 创建 Release v7.1.0.3 并上传 Linux 二进制
8. 初始化 git 仓库并推送到 GitHub

## 待办事项

- [ ] 构建并上传 macOS 二进制 (`popopx-chat-macos-x86-64`)
- [ ] 构建并上传 Android APK (`popopx-aarch64.apk`)
- [ ] 配置 git 用户信息（当前使用默认 ubuntu@localhost）

## 关键文件

- `popopx-chat.cabal` - Haskell 项目配置
- `cabal.project` - 依赖源配置
- `install.sh` - CLI 安装脚本
- `NOTICE` - AGPL 合规声明
- `LICENSE` - AGPL v3 全文
- `AGENTS.md` - AI 辅助开发指南
