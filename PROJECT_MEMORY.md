# POPOPX Chat 项目记忆

## 项目概述
POPOPX Chat 是一个隐私优先的消息平台，基于 simplex-chat 上游 fork 而来，完全重命名品牌。

## 上游同步状态

### 当前版本
- **本地版本**: 7.1.0.14
- **上游同步点**: fc3f3abd0 (2026-10-19)
- **popopxmq 版本**: tag 84a10d06f59fc98fb8d392622490309f7c2b9cbc
- **最后同步日期**: 2026-10-20

### 同步历史
1. **2026-10-19**: 同步到 v7.1.0.12
   - WebRTC ICE restart 支持
   - AUTOINCREMENT 数据库迁移
   - 时间戳规范化 (roundDownToSecond)
   
2. **2026-10-20**: 同步到 v7.1.0.14
   - 版本升级 7.1.0.12 → 7.1.0.14
   - popopxmq 更新到 tag 84a10d06f
   - 修复 chat_schema.sql (添加 sqlite_sequence 表)
   - 清理 sha256map.nix (移除过时的本地路径)

## 品牌重命名规则

### 命名空间映射
```
Simplex.* → Popopx.*
simplex → popopx
SimpleX → PopopX
SIMPLEX → POPOPX
```

### 函数名映射（重要）
```
resolveSimplexName → resolvePopopxName (不是 resolvePoName!)
```

**注意**: 所有从上游 simplexmq 库导入的函数都需要完整重命名，不能使用缩写。

### 已完成的替换
- ✅ Haskell 源码中 simplex 引用: 0 处（排除版权头）
- ✅ 构建配置: 全部替换
- ✅ 类型名称: SimplexDomain → PopopxDomain 等
- ✅ 常量: SimpleXCallMediaKey → PopopXCallMediaKey

### 保留的 Simplex 引用（正确）
- 版权头: `-- Original Work Copyright (C) 2020-2022 simplex.chat`
  - 原因: 原始作品归属，必须保留

## POPOPX 专有特性

### 核心功能
1. **burnAfterRead** - 阅后即焚消息
   - 参数贯穿整个消息创建流程
   - 影响函数: createNewSndChatItem, createNewRcvChatItem, saveSndChatItems 等

2. **BinThere 机器人系统**
   - `bar` 参数控制自动回复
   - 迁移: M20260905_binthere_bots, M20260906_bot_directory, M20261009_binthere_bar_flag
   - 模块: Chat/BinThere/Protocol.hs, Chat/Store/BinThere.hs

3. **LinkEncryption** - 链接加密模块
   - 文件: Chat/LinkEncryption.hs

4. **RemoteConfig** - 远程配置模块
   - 文件: Chat/RemoteConfig.hs

### 自定义 FFI 导出
- cChatMigrateInitKeyBytes
- 迁移日志功能

### 数据库迁移
- peerType/chat_peer_type 字段
- 所有 BinThere 相关迁移
- M20260603_popopx_name (对应上游 M20260603_simplex_name)

## 构建配置

### cabal.project
```
popopxmq tag: 84a10d06f59fc98fb8d392622490309f7c2b9cbc
popopxmq 依赖: >=7.0 (上游 simplexmq >=6.3)
```

### Nix 构建
- sha256map.nix: popopxmq hash = `191x2a3v23sa8pdhcjvmnac2niph2wzq1vapiav2jvkqsww7m2kw`
- flake.nix: 与上游完全一致（排除命名空间）

### 补丁文件
**已应用**:
- direct-sqlcipher-*.patch (Linux/Windows/Android)
- basement-pr-573.patch
- memory-pr-99.patch

**⚠️ 孤立补丁** (存在于 scripts/nix/ 但未在 flake.nix 中引用):
- popopxmq-base64url-decodeLenient.patch
  - 功能: base64url 解码从严格模式改为宽松模式
  - 状态: 未应用
  
- popopxmq-crcv-upgrade-fix.patch
  - 功能: CRcv 连接升级修复
  - 状态: 未应用

**待决策**: 需要在 flake.nix 中添加引用、提交到 popopxmq fork、或删除

## 文件结构

### 上游有但本地没有的文件
无缺失文件

### 本地专有文件（9个）
- Chat/BinThere/Protocol.hs
- Chat/LinkEncryption.hs
- Chat/RemoteConfig.hs
- Chat/Store/BinThere.hs
- Chat/Store/SQLite/Migrations/M20260905_binthere_bots.hs
- Chat/Store/SQLite/Migrations/M20260906_bot_directory.hs
- Chat/Store/SQLite/Migrations/M20261009_binthere_bar_flag.hs
- tests/BinThereIntegrationTests.hs
- tests/BinThereStoreTests.hs

## 已知问题与修复

### 2026-10-20: resolvePoName 错误
**问题**: Commands.hs:5243 使用了错误的函数名 `resolvePoName`
**修复**: 改为 `resolvePopopxName`
**原因**: 上游函数 `resolveSimplexName` 应该完整重命名为 `resolvePopopxName`，不能使用缩写
**影响**: 编译失败，修复后编译成功

## 编译验证

### 成功编译命令
```bash
cabal build --flag client_library --flag swift
```

### 编译状态
- ✅ 2026-10-20: 编译成功（只有警告，无错误）
- 警告类型: 未使用的导入、未使用的变量、冗余约束

## GitHub 仓库

### 实际仓库
- **路径**: github.com/popopx/popopx-chat
- **组织**: popopx (不是 popopx-chat)
- **可见性**: Public

### 不存在的仓库
- ❌ github.com/popopx-chat/ (组织和用户都不存在)

## 同步检查清单

进行上游同步时，检查以下项目:

- [ ] 版本对齐 (popopx-chat.cabal)
- [ ] popopxmq tag 更新 (cabal.project)
- [ ] sha256map.nix hash 更新
- [ ] chat_schema.sql 与上游一致
- [ ] 所有上游模块已同步
- [ ] POPOPX 专有特性保留
- [ ] 无遗漏的 simplex 引用（排除版权头）
- [ ] 函数名完整重命名（不使用缩写）
- [ ] 编译测试通过
- [ ] 迁移文件完整

## 关键文件路径

### 同步文档
- UPSTREAM_SYNC_20261019.md - v7.1.0.12 同步日志
- UPSTREAM_SYNC_20261020.md - v7.1.0.14 同步日志
- DEEP_SYNC_CHECK_20261020.md - 深度同步检查报告

### 配置文件
- AGENTS.md - 项目指南和同步流程
- cabal.project - 依赖配置
- popopx-chat.cabal - 包配置
- flake.nix - Nix 构建配置
- scripts/nix/sha256map.nix - Nix hash 映射

## 经验教训

1. **函数名重命名必须完整**: 不能使用缩写（如 resolvePoName），必须使用完整名称（resolvePopopxName）
2. **版权头必须保留**: 原始作品的归属不能修改
3. **补丁文件需要跟踪**: 孤立的补丁文件需要定期清理或集成
4. **编译验证是必须的**: 每次同步后必须编译测试
5. **GitHub 组织名称**: 实际是 `popopx`，不是 `popopx-chat`

## 待办事项

- [ ] 决策: 处理 2 个孤立的 popopxmq 补丁文件
- [ ] 考虑: 是否需要创建 popopx-chat GitHub 组织
- [ ] 监控: CI 构建状态（10 个检查已排队）

---

**最后更新**: 2026-10-20  
**维护者**: POPOPX 团队
