# POPOPX Chat Terminal CLI 使用说明

## 概述

POPOPX Chat Terminal CLI 是一个功能完整的命令行聊天客户端，支持作为本地 WebSocket 服务器运行，为第三方应用提供 API 接口。

## 编译产物

### 可执行文件位置

所有可执行文件位于 `dist-newstyle/build/x86_64-linux/ghc-9.6.6/popopx-chat-7.1.0.3/x/` 目录下：

| 可执行文件 | 路径 | 大小 | 说明 |
|-----------|------|------|------|
| **popopx-chat** | `popopx-chat/build/popopx/popopx-chat` | 110MB | Terminal CLI + WebSocket 服务器 |
| **popopx-bot** | `popopx-bot/build/popopx-bot/popopx-bot` | 109MB | 简单示例 Bot（平方计算器） |
| **popopx-bot-advanced** | `popopx-bot-advanced/build/popopx-bot-advanced/popopx-bot-advanced` | 109MB | 高级事件驱动 Bot |
| **popopx-broadcast-bot** | `popopx-broadcast-bot/build/popopx-broadcast-bot/popopx-broadcast-bot` | 109MB | 消息广播 Bot |

---

## 1. POPOPX Chat Terminal CLI (popopx-chat)

### 功能特性

- 完整的命令行聊天界面
- **WebSocket 服务器模式**：提供 JSON API 接口
- 支持文件传输
- 支持群组聊天
- 支持消息加密
- 数据库自动迁移

### 启动方式

#### 基本启动

```bash
# 使用默认配置启动
./popopx-chat

# 启动 WebSocket 服务器在端口 8080
./popopx-chat -p 8080
```

#### 常用选项

```bash
# 指定数据库路径
./popopx-chat -d /path/to/database -p 8080

# 使用数据库加密密钥
./popopx-chat -k "your-secret-key" -p 8080

# 指定 SMP 服务器
./popopx-chat -s "smp1.example.com smp2.example.com" -p 8080

# 无交互模式（适合作为服务运行）
./popopx-chat --headless -p 8080

# 设置日志级别
./popopx-chat -l debug -p 8080

# 指定文件存储文件夹
./popopx-chat --files-folder /path/to/files -p 8080
```

#### 完整选项列表

```bash
./popopx-chat --help
```

**主要选项：**
- `-p,--chat-server-port PORT` - 在指定端口运行 WebSocket 服务器
- `-d,--database DB_FILE` - 数据库文件路径前缀（默认：`~/.popopx/popopx_v1`）
- `-k,--key KEY` - 数据库加密密钥
- `-s,--server SERVER` - SMP 服务器地址（空格分隔多个服务器）
- `--xftp-server SERVER` - XFTP 文件服务器地址
- `--headless` - 无交互模式运行
- `-l,--log-level LEVEL` - 日志级别（debug, info, warn, error, important）
- `--files-folder FOLDER` - 文件存储文件夹
- `--temp-folder FOLDER` - 临时文件文件夹
- `-f,--allow-instant-files` - 允许即时文件传输
- `-a,--auto-accept-files FILE_SIZE` - 自动接受指定大小的文件

### WebSocket API

#### 连接方式

使用 WebSocket 客户端连接到 `ws://localhost:<PORT>`

#### 请求格式

```json
{
  "corrId": "unique-correlation-id",
  "cmd": "API command string"
}
```

#### 响应格式

```json
{
  "corrId": "unique-correlation-id",
  "resp": {
    "csrBody": <response data or error>
  }
}
```

#### 示例

**发送命令：**
```json
{
  "corrId": "1",
  "cmd": "/help"
}
```

**接收响应：**
```json
{
  "corrId": "1",
  "resp": {
    "csrBody": {
      "right": "Available commands: ..."
    }
  }
}
```

---

## 2. POPOPX Bot 对比

### popopx-bot（简单 Bot）

**功能：** 最简单的示例 Bot，计算数字的平方

**特点：**
- 使用简单的 REPL（读取-求值-打印）模式
- 只能处理纯文本消息
- 适合学习和测试基本 Bot 功能

**启动：**
```bash
./popopx-bot -d /path/to/bot/database
```

**行为：**
- 发送欢迎消息："Hello! I am a simple squaring bot. If you send me a number, I will calculate its square"
- 接收数字后返回平方结果：`5 * 5 = 25`
- 接收非数字消息返回错误：`"hello" is not a number`

**适用场景：**
- 学习 Bot 开发基础
- 快速测试 Bot 框架
- 简单的数学计算服务

---

### popopx-bot-advanced（高级 Bot）

**功能：** 事件驱动的高级 Bot，同样计算平方，但使用更强大的事件处理机制

**特点：**
- 使用事件队列（`outputQ`）处理所有事件
- 可以监听多种事件类型：
  - `CEvtContactConnected` - 联系人连接事件
  - `CEvtNewChatItems` - 新消息事件
  - 等等...
- 支持异步并发处理
- 更灵活的事件过滤和响应

**启动：**
```bash
./popopx-bot-advanced -d /path/to/bot/database
```

**行为：**
- 与 popopx-bot 相同的功能（计算平方）
- 但使用事件驱动架构
- 可以更好地处理并发和复杂逻辑

**适用场景：**
- 需要处理多种事件类型
- 需要并发处理消息
- 构建复杂的交互式 Bot
- 生产环境 Bot 开发

**与 popopx-bot 的区别：**
| 特性 | popopx-bot | popopx-bot-advanced |
|------|-----------|---------------------|
| 架构 | 简单 REPL | 事件驱动 |
| 事件处理 | 有限 | 完整事件队列 |
| 并发支持 | 基本 | 高级（async/race） |
| 扩展性 | 低 | 高 |
| 复杂度 | 简单 | 中等 |

---

### popopx-broadcast-bot（广播 Bot）

**功能：** 消息广播 Bot，可以将消息转发给所有联系人

**特点：**
- 支持消息广播到所有联系人
- 权限控制：只有指定的发布者可以广播消息
- 支持多种消息类型：文本、链接、图片
- 自动删除未授权消息
- 广播结果反馈（成功/失败数量）

**启动：**
```bash
./popopx-broadcast-bot --help
```

**特殊选项：**
- `--publishers` - 指定允许广播的发布者列表
- `--welcome-message` - 自定义欢迎消息
- `--prohibited-message` - 未授权用户的提示信息

**行为：**
1. 用户连接时发送欢迎消息
2. 接收消息时检查发送者是否为授权发布者
3. 如果未授权：
   - 发送禁止消息提示
   - 删除该消息
4. 如果已授权且消息类型支持（文本/链接/图片）：
   - 广播消息给所有联系人
   - 反馈广播结果：`Forwarded to X contact(s), Y errors`

**支持的消息类型：**
- ✅ 文本消息（MCText）
- ✅ 链接消息（MCLink）
- ✅ 图片消息（MCImage）
- ❌ 其他类型（文件、视频等）

**适用场景：**
- 状态更新广播
- 公告发布系统
- 消息分发服务
- 通知推送 Bot

**示例用法：**
```bash
# 启动广播 Bot，指定发布者
./popopx-broadcast-bot \
  -d /path/to/bot/database \
  --publishers "alice,bob" \
  --welcome-message "Welcome to status updates!" \
  --prohibited-message "You are not authorized to broadcast"
```

---

## Bot 选择指南

| 需求 | 推荐 Bot | 原因 |
|------|---------|------|
| 学习 Bot 开发 | popopx-bot | 代码简单，易于理解 |
| 简单问答 Bot | popopx-bot | 基本的消息响应 |
| 复杂交互 Bot | popopx-bot-advanced | 事件驱动，灵活扩展 |
| 多事件处理 | popopx-bot-advanced | 完整的事件队列支持 |
| 消息广播 | popopx-broadcast-bot | 专门的广播功能 |
| 公告系统 | popopx-broadcast-bot | 权限控制 + 广播 |
| 生产环境 | popopx-bot-advanced | 稳定、可扩展 |
| WebSocket API | popopx-chat | 提供完整的 API 接口 |

---

## 常见问题

### 1. 如何查看 Bot 的 WebSocket 地址？

启动 Bot 后，会在控制台输出 Bot 的地址链接，格式如：
```
Bot address: popopx:/...
```

### 2. 如何让 Bot 在后台运行？

使用 `nohup` 或 `screen`/`tmux`：
```bash
nohup ./popopx-chat --headless -p 8080 > bot.log 2>&1 &
```

### 3. 如何重置 Bot 数据库？

删除数据库文件：
```bash
rm ~/.popopx/popopx_bot.db*
```

### 4. WebSocket 连接失败？

检查：
- 端口是否被占用：`netstat -tlnp | grep 8080`
- 防火墙设置
- 是否正确启动了 WebSocket 服务器（使用 `-p` 参数）

### 5. 如何自定义 Bot 逻辑？

参考源代码：
- 简单 Bot：`apps/popopx-bot/Main.hs`
- 高级 Bot：`apps/popopx-bot-advanced/Main.hs`
- 广播 Bot：`apps/popopx-broadcast-bot/src/Broadcast/Bot.hs`

---

## 技术架构

### 依赖关系

```
popopx-chat (CLI + WebSocket)
    ├── popopx-chat (核心库)
    │   ├── popopxmq (消息队列)
    │   └── 其他依赖...
    └── websockets (WebSocket 库)

popopx-bot (简单 Bot)
    └── popopx-chat (核心库)

popopx-bot-advanced (高级 Bot)
    ├── popopx-chat (核心库)
    ├── popopxmq (消息队列)
    ├── async (并发)
    └── stm (软件事务内存)

popopx-broadcast-bot (广播 Bot)
    ├── popopx-chat (核心库)
    ├── popopxmq (消息队列)
    ├── async (并发)
    ├── stm (软件事务内存)
    └── optparse-applicative (命令行解析)
```

### 数据库

- 默认位置：`~/.popopx/`
- 数据库类型：SQLite（默认）或 PostgreSQL
- 自动迁移：启动时自动执行数据库迁移

---

## 版本信息

- **POPOPX Chat 版本：** 7.1.0.3
- **Haskell 编译器：** GHC 9.6.6
- **构建系统：** Cabal 3.16.1.0
- **编译日期：** 2026-10-06

---

## 相关文档

- [Bot API 文档](../bots/api/README.md)
- [Bot 事件类型](../bots/api/EVENTS.md)
- [Bot 命令列表](../bots/api/COMMANDS.md)
- [Voucher Bot（TypeScript）](../bots/voucher-bot/README.md)

---

## 许可证

AGPL-3.0
