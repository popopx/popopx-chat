# POPOPX 上游同步深度检查报告

**检查时间**: 2026-10-20  
**当前版本**: 7.1.0.14  
**上游同步点**: fc3f3abd0 (2026-10-19)

---

## 1. 文件完整性检查 ✓

### 上游有但本地没有的文件
**无缺失文件**

上游的 `M20260603_simplex_name.hs` 已在本地对应为 `M20260603_popopx_name.hs`（正确重命名）

### 本地专有文件（POPOPX 特性）
- ✓ `Chat/BinThere/Protocol.hs` - BinThere 机器人协议
- ✓ `Chat/LinkEncryption.hs` - 链接加密模块
- ✓ `Chat/RemoteConfig.hs` - 远程配置模块
- ✓ `Chat/Store/BinThere.hs` - BinThere 存储
- ✓ `Chat/Store/SQLite/Migrations/M20260905_binthere_bots.hs`
- ✓ `Chat/Store/SQLite/Migrations/M20260906_bot_directory.hs`
- ✓ `Chat/Store/SQLite/Migrations/M20261009_binthere_bar_flag.hs`
- ✓ `tests/BinThereIntegrationTests.hs`
- ✓ `tests/BinThereStoreTests.hs`

---

## 2. 编译配置检查 ✓

### cabal.project
| 项目 | 上游 | 本地 | 状态 |
|------|------|------|------|
| MQ 库 | simplexmq | popopxmq | ✓ 正确 |
| MQ tag | 8bc4d3601 | 84a10d06f | ✓ 已更新 |
| 其他依赖 | 一致 | 一致 | ✓ |

### popopx-chat.cabal
| 项目 | 上游 | 本地 | 状态 |
|------|------|------|------|
| version | 7.1.0.14 | 7.1.0.14 | ✓ 一致 |
| 模块列表 | 基础模块 | 基础 + POPOPX 模块 | ✓ 正确 |
| popopxmq 依赖 | >=6.3 | >=7.0 | ✓ 更高版本 |

### flake.nix
**完全一致**（排除命名空间替换后无差异）

---

## 3. 代码一致性深度检查 ✓

### Simplex 引用检查
**Haskell 源码中 simplex 引用**: 0 行（排除版权头）

所有 `Simplex*` 类型已正确重命名为 `Popopx*`:
- ✓ `SimplexDomain` → `PopopxDomain`
- ✓ `SimplexDomainClaim` → `PopopxDomainClaim`
- ✓ `SimplexDomainProof` → `PopopxDomainProof`
- ✓ `SimpleXCallMediaKey` → `PopopXCallMediaKey`

### 关键文件代码对比

| 文件 | 差异行数 | 差异来源 | 状态 |
|------|---------|---------|------|
| Call.hs | 0 | - | ✓ 完全一致 |
| Commands.hs | 104 | burnAfterRead + bar 参数 | ✓ POPOPX 特性 |
| Internal.hs | 31 | burnAfterRead 参数 | ✓ POPOPX 特性 |
| Store/Messages.hs | 36 | burnAfterRead 参数 | ✓ POPOPX 特性 |

### 差异详情（均为 POPOPX 特性）

**1. burnAfterRead 参数**
- 添加到 `createNewSndChatItem`, `createNewRcvChatItem`, `createNewChatItem_`
- 添加到 `saveSndChatItems`, `saveRcvChatItem'`, `mkChatItem_`
- 添加到 `prepareGroupMsg`
- 功能：阅后即焚消息支持

**2. bar 参数（BinThere AR 标志）**
- 添加到 `APISendMessages` API 命令
- 传递到 `sendContactContentMessages`, `sendGroupContentMessages`
- 功能：BinThere 机器人自动回复控制

---

## 4. 迁移文件检查 ✓

### SQLite 迁移
- 上游迁移数量: 169 个
- 本地迁移数量: 172 个
- 差异: 3 个 POPOPX 专有迁移（BinThere）

### 关键迁移状态
- ✓ M20261018_autoincrement_ids.hs - 已同步
- ✓ chat_schema.sql - sqlite_sequence 表已添加
- ✓ roundDownToSecond - 时间戳规范化已实现
- ✓ rtcSession - WebRTC ICE 重启已实现

---

## 5. 构建配置一致性 ✓

### Nix 构建
- ✓ sha256map.nix - popopxmq hash 已更新
- ✓ 所有补丁文件存在
- ✓ GHC 配置一致

### 补丁状态
| 补丁 | 状态 | 说明 |
|------|------|------|
| direct-sqlcipher-*.patch | ✓ 已应用 | 上游同步 |
| basement-pr-573.patch | ✓ 已应用 | 上游同步 |
| memory-pr-99.patch | ✓ 已应用 | 上游同步 |
| popopxmq-base64url-decodeLenient.patch | ⚠️ 未应用 | 孤立文件 |
| popopxmq-crcv-upgrade-fix.patch | ⚠️ 未应用 | 孤立文件 |

---

## 6. Simplex 替换方案

### 已完成替换
✓ **Haskell 源码**: 0 处 simplex 引用（排除版权头）  
✓ **构建配置**: 全部替换为 popopx  
✓ **类型名称**: Simplex* → Popopx*  
✓ **常量**: SimpleX* → PopopX*  

### 保留的 Simplex 引用（正确）
- **版权头**: `-- Original Work Copyright (C) 2020-2022 simplex.chat`
  - 原因：原始作品归属，应保留

### 无需替换的项目
- 上游依赖包名（simplex-chat/hs-socks 等）- 第三方库
- 协议常量（来自 popopxmq 库）- 已在库层替换

---

## 7. 发现的问题

### ⚠️ 孤立补丁文件
两个 popopxmq 补丁存在于 `scripts/nix/` 但未在 `flake.nix` 中引用：

1. **popopxmq-base64url-decodeLenient.patch**
   - 功能：base64url 解码从严格模式改为宽松模式
   - 状态：未应用
   
2. **popopxmq-crcv-upgrade-fix.patch**
   - 功能：CRcv 连接升级修复
   - 状态：未应用

**建议处理方案**:
- 方案 A：在 flake.nix 中添加引用（推荐）
- 方案 B：提交到 popopxmq fork 仓库
- 方案 C：删除孤立文件（如果不再需要）

---

## 8. 总结

### ✓ 同步状态：完整
- 所有上游文件已同步
- 版本对齐（7.1.0.14）
- 编译配置一致
- 代码差异均为 POPOPX 特性
- 无遗漏的 simplex 引用

### ✓ POPOPX 特性保留：完整
- burnAfterRead（阅后即焚）
- BinThere 机器人系统
- LinkEncryption（链接加密）
- RemoteConfig（远程配置）
- 所有自定义迁移

### ⚠️ 待处理
- 2 个孤立补丁文件需要决策

---

**检查结论**: 上游同步完整，POPOPX 特性全部保留，代码质量良好。
