# BinThere BAR 功能验证计划

## 概述

验证 burn-after-read (BAR) 功能的完整实现，包括端到端工作流、数据库持久化和测试覆盖率。

## 验证环境

- **应用程序**: `dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopx-chat-7.1.0.10/x/popopx-chat/build/popopx-chat/popopx-chat`
- **数据库**: SQLite（默认位置：`~/.local/share/popopx-chat/` 或当前目录）
- **测试用户**: alice, bob
- **测试时间**: 2026-10-09

## 验证步骤

### 阶段 1: 端到端功能验证

#### 1.1 启动应用程序
```bash
./dist-newstyle/build/x86_64-linux/ghc-9.6.3/popopx-chat-7.1.0.10/x/popopx-chat/build/popopx-chat/popopx-chat
```

#### 1.2 创建用户和连接
1. 创建 alice 用户（实例 1）
2. 创建 bob 用户（实例 2）
3. alice 创建联系人地址：`/address`
4. bob 连接到 alice：`/connect <alice的地址>`
5. 验证连接建立

#### 1.3 注册 BinThere Bot
在 alice 的实例中：
```
/_binthere add <userId> {"botAddress":"<alice的地址>","botName":"Alice BAR Bot","botType":"binthere","enabled":true}
```

验证：
- 返回 `CRBinThereBotAdded` 响应
- bot 已注册到数据库

#### 1.4 发送 BAR 消息
在 bob 的实例中：
```
/_send @2 bar=on text 这是秘密消息
```

验证：
- 消息成功发送
- alice 收到消息
- 消息显示为定时消息（30 秒 TTL）

#### 1.5 验证 Bot 使用计数
在 alice 的实例中：
```
/_binthere list <userId>
```

验证：
- `usageCount` 已递增（应该为 1 或更多）

#### 1.6 验证自动删除
等待 30 秒后验证：
- 消息已从 alice 和 bob 的聊天记录中删除
- 收到 "timed message deleted" 通知

### 阶段 2: 数据库持久化验证

#### 2.1 定位数据库文件
```bash
find ~/.local/share/popopx-chat -name "*.db" -o -name "*.sqlite"
# 或
find . -name "popopx_chat*.db"
```

#### 2.2 检查表结构
```bash
sqlite3 <数据库文件> ".schema chat_items" | grep burn_after_read
```

预期输出：
```sql
burn_after_read INTEGER NOT NULL DEFAULT 0
```

#### 2.3 检查索引
```bash
sqlite3 <数据库文件> ".indices chat_items" | grep burn_after_read
```

预期输出：
```sql
idx_chat_items_burn_after_read
```

#### 2.4 查询 BAR 消息
```bash
sqlite3 <数据库文件> "SELECT chat_item_id, item_text, burn_after_read, timed_ttl, timed_delete_at FROM chat_items WHERE burn_after_read = 1 ORDER BY chat_item_id DESC LIMIT 10;"
```

验证：
- `burn_after_read` 列值为 1
- `timed_ttl` 为 30
- `timed_delete_at` 已设置

#### 2.5 检查 BinThere Bots 表
```bash
sqlite3 <数据库文件> "SELECT * FROM binthere_bots;"
```

验证：
- bot 记录存在
- `usage_count` 已递增

### 阶段 3: 测试覆盖率验证

#### 3.1 运行测试套件
```bash
cabal test --test-show-details=direct
```

#### 3.2 检查 BinThere 测试
验证以下测试执行并通过：
- `BinThere Store` 测试套件
  - creates and reads a bot by id
  - reads a bot by address
  - lists all bots
  - updates a bot
  - deletes a bot
  - increments usage count
  - returns Nothing for non-existent bot

- `BinThere integration` 测试套件
  - burn-after-read messages
    - send BAR message with 30-second TTL

#### 3.3 代码覆盖率（如果可用）
```bash
# 如果配置了 hpc
cabal test --enable-coverage
# 查看报告
firefox dist-newstyle/build/*/hpc/vanilla/html/popopx-chat-*/hpc_index.html
```

验证：
- `Popopx.Chat.Library.Commands` 覆盖率 > 80%
- `Popopx.Chat.Store.Messages` 覆盖率 > 80%
- `Popopx.Chat.Store.BinThere` 覆盖率 > 90%

## 预期结果

### 成功标准
1. ✅ BAR 消息可以发送和接收
2. ✅ 消息标记为 30 秒 TTL
3. ✅ 消息在 30 秒后自动删除
4. ✅ Bot 使用计数正确递增
5. ✅ 数据库中 `burn_after_read` 标志正确持久化
6. ✅ 所有 BinThere 测试通过

### 失败处理
如果任何验证步骤失败：
1. 记录错误信息和日志
2. 检查相关代码实现
3. 修复问题并重新验证
4. 更新本文档记录发现的问题和解决方案

## 验证报告模板

```
验证日期: 2026-10-09
验证人员: AI Assistant
应用程序版本: 7.1.0.10

阶段 1: 端到端功能验证
- [ ] 应用程序启动成功
- [ ] 用户创建和连接建立
- [ ] BinThere bot 注册成功
- [ ] BAR 消息发送和接收
- [ ] Bot 使用计数递增
- [ ] 消息自动删除（30 秒）

阶段 2: 数据库持久化验证
- [ ] chat_items 表包含 burn_after_read 列
- [ ] 索引 idx_chat_items_burn_after_read 存在
- [ ] BAR 消息正确写入数据库
- [ ] binthere_bots 表记录正确

阶段 3: 测试覆盖率验证
- [ ] BinThere Store 测试全部通过
- [ ] BinThere integration 测试通过
- [ ] 代码覆盖率达标

总体结果: PASS / FAIL
备注: [记录任何发现的问题或特殊情况]
```

## 附录

### 相关代码文件
- `src/Popopx/Chat/Controller.hs` - APISendMessages 定义
- `src/Popopx/Chat/Library/Commands.hs` - 发送逻辑和 bot 使用追踪
- `src/Popopx/Chat/Library/Internal.hs` - 消息保存逻辑
- `src/Popopx/Chat/Store/Messages.hs` - 数据库操作
- `src/Popopx/Chat/Store/BinThere.hs` - BinThere bot 存储
- `tests/BinThereIntegrationTests.hs` - 集成测试

### 相关数据库表
- `chat_items` - 聊天消息表（包含 `burn_after_read` 列）
- `binthere_bots` - BinThere bot 目录表

### CLI 命令参考
- `/_send @<contactId> bar=on text <message>` - 发送 BAR 消息
- `/_binthere list <userId>` - 列出所有 bot
- `/_binthere add <userId> <json>` - 添加 bot
- `/_binthere update <userId> <json>` - 更新 bot
- `/_binthere delete <userId> <botId>` - 删除 bot
