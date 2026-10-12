# POPOPX Config Bot 部署指南

## 概述

Config Bot 替代原有的集中式 REST API (`https://api.popopxchat.com/api/v1/servers/config`)，通过 POPOPX 消息协议分发服务器配置和 Bot 目录。

### 数据流

```
iOS App (ConfigBotClient)
  → 发送 POPOPX 消息 "/config"
  → Config Bot (Python) 返回 JSON
  → App 缓存到 RemoteConfigCache (UserDefaults)
  → chatSendCmd(/_remote_config json) → Haskell 更新 SMP/XFTP
  → chatSendCmd(/_bot_directory_sync json) → Haskell 持久化 Bot 目录
```

### Bot 命令

| 命令 | 返回 | 说明 |
|------|------|------|
| `/config` | 完整 JSON | ICE servers + 运营商配置 + Bot 目录 |
| `/ice` | `{"ice_servers": [...]}` | 仅 WebRTC ICE 服务器 |
| `/bots` | `{"bot_directory": [...]}` | 仅 Bot 目录 |
| `/ping` | `pong` | 健康检查 |
| `/help` | 命令列表 | 使用说明 |

---

## 前置条件

- **服务器**: Ubuntu 22.04+ VPS（需要稳定网络，建议海外节点）
- **Python**: 3.10+
- **popopx-chat 库**: 位于 `packages/popopx-chat-python/`（本仓库内）
- **libpopopx**: popopx-chat 底层依赖（由 Python 库自动处理）

---

## 第一步：服务器环境准备

### 1.1 系统更新 + 安装依赖

```bash
# SSH 登录服务器
ssh root@your-vps-ip

# 系统更新
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y python3 python3-pip python3-venv git curl

# 验证 Python 版本（需要 3.10+）
python3 --version
```

### 1.2 创建专用用户（推荐）

```bash
# 创建 popopx 用户
sudo adduser --disabled-password --gecos "" popopx

# 创建部署目录
sudo mkdir -p /opt/popopx/config-bot
sudo chown popopx:popopx /opt/popopx/config-bot
```

---

## 第二步：部署 Bot 代码

### 2.1 上传文件

从本地开发机上传（二选一）：

**方式 A: scp 直接上传**

```bash
# 在本地执行
cd /Users/elliot/simple-chat/POPOPX/apps/ios/ConfigBot

# 上传 bot 代码和配置
scp config_bot.py config.json popopx@your-vps-ip:/opt/popopx/config-bot/

# 上传 popopx-chat Python 库
scp -r ../../packages/popopx-chat-python popopx@your-vps-ip:/opt/popopx/
```

**方式 B: git clone（如果仓库可访问）**

```bash
ssh popopx@your-vps-ip
cd /opt/popopx
git clone <your-repo-url> popopx-chat
cd config-bot
# 手动复制 config_bot.py 和 config.json
```

### 2.2 创建虚拟环境 + 安装依赖

```bash
ssh popopx@your-vps-ip
cd /opt/popopx/config-bot

# 创建 Python 虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装 popopx-chat 库（从本地路径）
pip install /opt/popopx/popopx-chat-python

# 验证安装
python -c "from popopx_chat import Bot; print('OK')"
```

### 2.3 目录结构确认

```
/opt/popopx/config-bot/
├── config_bot.py      # Bot 主程序
├── config.json        # 服务器配置文件
└── venv/              # Python 虚拟环境
```

---

## 第三步：配置 config.json

编辑 `/opt/popopx/config-bot/config.json`：

```json
{
  "ice_servers": [
    "stun:stun.popopxchat.com:443",
    "turns:turn.popopxchat.com:443?transport=tcp"
  ],
  "preset_operators": [
    {
      "operator_tag": "popopx",
      "trade_name": "PopopX Switch",
      "smp_servers": [
        "smp://q5TvFxQPkloaEGYhlLHejVWW7K31C57wq-YXjuwb258=@smp1.popopxchat.com,...",
        "smp://h87w8XV_Q8bczkZvugDVB7RmqqpmBhIbgqYgXeZaQ4k=@ps1.popopxchat.xyz,..."
      ],
      "xftp_servers": [
        "xftp://R8vT2mN5qW7jL9hK3xP4fY6cB0dA1gE8iO4kM7nPxQz=@xftp1.popopxchat.com,...",
        "xftp://J6kL2mP9xR4vT8wZ0cB3dA5fG7iO1qR5sV9wX2yZ6mN=@xftp2.popopxchat.com,..."
      ]
    }
  ],
  "bot_directory": [
    {
      "bot_address": "",
      "bot_name": "BinThere",
      "bot_type": "binthere",
      "description": "阅后即焚加密消息",
      "icon_url": null,
      "token_count": 0,
      "pricing_unit": null,
      "pricing_amount": 0
    }
  ]
}
```

### 配置字段说明

#### `ice_servers`
WebRTC STUN/TURN 服务器地址数组，用于语音/视频通话。

格式：
- STUN: `stun:host:port`
- TURN: `turns:username:password@host:port?transport=tcp`

#### `preset_operators`
SMP/XFTP 服务器运营商配置。

| 字段 | 类型 | 说明 |
|------|------|------|
| `operator_tag` | string | 运营商标识（如 "popopx"） |
| `trade_name` | string | 显示名称 |
| `smp_servers` | [string] | SMP 服务器 URI 列表 |
| `xftp_servers` | [string] | XFTP 服务器 URI 列表 |

#### `bot_directory`
可用服务 Bot 列表。

| 字段 | 类型 | 说明 |
|------|------|------|
| `bot_address` | string | Bot 的 POPOPX 地址（空 = 未部署） |
| `bot_name` | string | 显示名称 |
| `bot_type` | string | Bot 类型标识 |
| `description` | string? | 用户可见的描述 |
| `icon_url` | string? | 图标 URL |
| `token_count` | int | Token 数量 |
| `pricing_unit` | string? | "month"（包月）或 "use"（按次） |
| `pricing_amount` | int | Token 数量 |

---

## 第四步：首次启动 — 获取 Bot 地址

```bash
cd /opt/popopx/config-bot
source venv/bin/activate
python config_bot.py
```

首次启动会：
1. 初始化 POPOPX agent 数据库（`config_bot.db`）
2. 注册 Bot 身份
3. **打印 Bot 的 POPOPX 地址到终端**

示例输出：
```
Bot address: simplex:/v1-2@abc123def456...
```

> **重要：复制并保存这个地址！** 下一步需要写入 Haskell 代码。

按 `Ctrl+C` 停止 Bot。

---

## 第五步：更新 Haskell 代码

在本地开发机，更新 Bot 地址：

**文件**: `src/Simplex/Chat/Operators/Presets.hs`

```haskell
defaultConfigBot :: (Text, Text)
defaultConfigBot =
  ( "config",
    "simplex:/v1-2@abc123def456..."  -- ← 粘贴第四步获取的地址
  )
```

### 重新编译 + 部署

```bash
cd /Users/elliot/simple-chat/POPOPX

# 1. 编译 Haskell 库
nix build .#aarch64-darwin-ios:lib:popopx-chat

# 2. 更新 iOS 库
bash apps/ios/scripts/update_ios_libs.sh

# 3. 构建 iOS App
cd apps/ios
xcodebuild -project POPOPX.xcodeproj -scheme "POPOPX (iOS)" build
```

---

## 第六步：生产环境部署（systemd）

### 6.1 创建 systemd 服务

```bash
ssh popopx@your-vps-ip

sudo tee /etc/systemd/system/popopx-config-bot.service > /dev/null <<'EOF'
[Unit]
Description=POPOPX Config Bot
After=network.target

[Service]
Type=simple
User=popopx
WorkingDirectory=/opt/popopx/config-bot
ExecStart=/opt/popopx/config-bot/venv/bin/python config_bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

### 6.2 启动服务

```bash
# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启动并设为开机自启
sudo systemctl enable --now popopx-config-bot

# 检查状态
sudo systemctl status popopx-config-bot
```

### 6.3 验证运行

```bash
# 查看日志
sudo journalctl -u popopx-config-bot -f

# 应看到类似输出：
# Sep 05 12:00:00 vps systemd[1]: Started POPOPX Config Bot.
# Sep 05 12:00:01 vps python[12345]: Bot started, waiting for messages...
```

---

## 第七步：验证部署

### 7.1 Bot 端验证

在服务器上发送测试消息（或通过另一台 POPOPX 客户端）：

```
/ping
```

应回复：`pong`

```
/config
```

应返回完整的 JSON 配置。

### 7.2 iOS App 端验证

1. 启动 iOS App
2. 观察日志：Config Bot 应自动连接
3. 手动刷新：Settings → Network & Servers → 下拉刷新
4. 验证 SMP/XFTP 服务器列表已更新

```bash
# 查看 App 日志
tail -f ~/Library/Logs/POPOPX/*.log

# 检查 SQLite 数据库
sqlite3 ~/Library/Application\ Support/POPOPX/chat.db
> SELECT * FROM binthere_bots WHERE bot_type = 'config';
> SELECT * FROM protocol_servers WHERE domain LIKE '%popopx%';
```

---

## 更新配置

修改服务器配置无需重新部署 Bot 代码：

```bash
# 1. 编辑配置
ssh popopx@your-vps-ip
nano /opt/popopx/config-bot/config.json

# 2. 重启 Bot（使配置生效）
sudo systemctl restart popopx-config-bot

# 3. 用户下次请求 /config 时获取新配置
```

---

## 监控 + 运维

### 常用命令

```bash
# 查看状态
sudo systemctl status popopx-config-bot

# 实时日志
sudo journalctl -u popopx-config-bot -f

# 最近 100 行日志
sudo journalctl -u popopx-config-bot -n 100

# 重启
sudo systemctl restart popopx-config-bot

# 停止
sudo systemctl stop popopx-config-bot

# 查看资源占用
ps aux | grep config_bot
```

### 日志轮转（可选）

创建 `/etc/logrotate.d/popopx-config-bot`：

```
/var/log/popopx/config-bot.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 popopx popopx
}
```

---

## Docker 部署（可选）

### Dockerfile

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# 安装 popopx-chat 库
COPY packages/popopx-chat-python /tmp/popopx-chat-python
RUN pip install /tmp/popopx-chat-python && rm -rf /tmp/popopx-chat-python

# 复制 Bot 文件
COPY apps/ios/ConfigBot/config_bot.py apps/ios/ConfigBot/config.json ./

CMD ["python", "config_bot.py"]
```

### 构建 + 运行

```bash
# 在仓库根目录
cd /Users/elliot/simple-chat/POPOPX

# 构建镜像
docker build -t popopx-config-bot -f apps/ios/ConfigBot/Dockerfile .

# 运行
docker run -d \
  --name config-bot \
  --restart always \
  popopx-config-bot

# 查看日志
docker logs -f config-bot
```

### Docker Compose

```yaml
version: '3.8'
services:
  config-bot:
    build:
      context: .
      dockerfile: apps/ios/ConfigBot/Dockerfile
    container_name: popopx-config-bot
    restart: always
    volumes:
      - ./config-bot-data:/app/data  # 持久化 Bot 数据库
```

---

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| Bot 无法启动 | 检查 Python 版本（3.10+），确认 `pip install` 成功 |
| App 无法连接 | 确认 `Presets.hs` 中的 Bot 地址与 Bot 实际地址一致 |
| 配置不更新 | 编辑 `config.json` 后重启 Bot |
| `/config` 返回空 | 检查 `config.json` 是否存在且为合法 JSON |
| systemd 启动失败 | `journalctl -u popopx-config-bot -n 50` 查看详细错误 |
| 数据库损坏 | 删除 `config_bot.db` 后重启（Bot 会重新生成，但地址不变） |

---

## 安全说明

- Bot 仅分发**公开配置信息**，不含敏感数据
- 无需认证 — 任何人可查询
- Bot 为**只读模式** — 不接受用户数据
- 配置变更需要服务器访问权限（客户端无法远程修改）
- Bot 的 POPOPX 地址硬编码在 App 二进制中

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `apps/ios/ConfigBot/config_bot.py` | Bot 主程序 |
| `apps/ios/ConfigBot/config.json` | 服务器配置数据 |
| `apps/ios/ConfigBot/README.md` | 本文档 |
| `packages/popopx-chat-python/` | POPOPX Chat Python 库 |
| `src/Simplex/Chat/Operators/Presets.hs` | `defaultConfigBot` 地址常量 |
| `apps/ios/Shared/Customization/ConfigBot/ConfigBotClient.swift` | iOS 客户端 |
