#!/bin/bash
# POPOPX 会员系统 - Bot 部署脚本
# 部署 POPOPX Chat CLI + voucher-bot
#
# 用法: ./deploy_bot.sh [--generate-keys] [--dry-run] [--install-chat]
# 前提: 需要 Node.js 18+ 和 npm

set -euo pipefail

# ============================================================
# 配置区
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

BOT_DIR="$PROJECT_ROOT/bots/voucher-bot"
SERVICE_NAME="popopx-voucher-bot"
CHAT_SERVICE="popopx-chat"
NODE_USER="${NODE_USER:-ubuntu}"
NODE_ENV="${NODE_ENV:-production}"
CHAT_PORT="${POPOPX_CHAT_PORT:-5225}"
CHAT_DATA_DIR="${POPOPX_CHAT_DATA_DIR:-/home/${NODE_USER}/.popopx}"
CHAT_BIN="/usr/local/bin/popopx-chat"

DRY_RUN=false
GENERATE_KEYS=false
INSTALL_CHAT=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --generate-keys) GENERATE_KEYS=true ;;
        --install-chat) INSTALL_CHAT=true ;;
    esac
done

if $DRY_RUN; then
    echo "[DRY RUN] 不会执行实际操作"
fi

# ============================================================
# 辅助函数
# ============================================================
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }
run() {
    if $DRY_RUN; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

# ============================================================
# Step 0: 生成 Ed25519 密钥对（可选）
# ============================================================
generate_keys() {
    if ! $GENERATE_KEYS; then
        return
    fi

    log "生成 Ed25519 密钥对..."

    if [[ ! -d "$BOT_DIR" ]]; then
        error "Bot 目录不存在: $BOT_DIR"
    fi

    cd "$BOT_DIR"

    if [[ ! -d "node_modules" ]]; then
        log "安装依赖..."
        run npm install
    fi

    KEYS=$(node -e "
const nacl = require('tweetnacl');
const keypair = nacl.sign.keyPair();
console.log(JSON.stringify({
    privateKey: Buffer.from(keypair.secretKey).toString('hex'),
    publicKey: Buffer.from(keypair.publicKey).toString('hex')
}));
" 2>/dev/null) || error "密钥生成失败，请确保 tweetnacl 已安装"

    PRIVATE_KEY=$(echo "$KEYS" | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).privateKey))")
    PUBLIC_KEY=$(echo "$KEYS" | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).publicKey))")

    log "=========================================="
    log "Ed25519 密钥对已生成"
    log "=========================================="
    log ""
    log "Public Key (可公开，配置到 iOS/H5):"
    log "  $PUBLIC_KEY"
    log ""
    log "Private Key (机密，仅 Bot 持有):"
    log "  $PRIVATE_KEY"
    log ""
    log "请将以上密钥填入 .env 文件："
    log "  ED25519_PRIVATE_KEY=$PRIVATE_KEY"
    log "  ED25519_PUBLIC_KEY=$PUBLIC_KEY"
    log ""
    log "=========================================="

    if [[ -f "$BOT_DIR/.env" ]]; then
        log "检测到 .env 文件，自动填入密钥..."
        sed -i.bak "s|^ED25519_PRIVATE_KEY=.*|ED25519_PRIVATE_KEY=$PRIVATE_KEY|" "$BOT_DIR/.env"
        sed -i.bak "s|^ED25519_PUBLIC_KEY=.*|ED25519_PUBLIC_KEY=$PUBLIC_KEY|" "$BOT_DIR/.env"
        rm -f "$BOT_DIR/.env.bak"
        log ".env 已更新"
    fi
}

# ============================================================
# Step 1: 安装 POPOPX Chat CLI (popopx-chat 二进制)
# ============================================================
install_chat_cli() {
    if ! $INSTALL_CHAT; then
        if command -v popopx-chat >/dev/null 2>&1; then
            log "POPOPX Chat CLI 已安装: $(which popopx-chat)"
            return
        fi
        log "POPOPX Chat CLI 未安装，使用 --install-chat 安装"
        log "  或手动下载: https://github.com/popopx/popopx-chat/releases"
        return
    fi

    log "安装 POPOPX Chat CLI..."

    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s)

    local download_url=""
    case "${os}_${arch}" in
        Linux_x86_64)
            download_url="https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat-ubuntu-22_04-x86_64"
            ;;
        Linux_aarch64)
            download_url="https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat-ubuntu-22_04-aarch64"
            ;;
        Darwin_*)
            download_url="https://github.com/popopx/popopx-chat/releases/latest/download/popopx-chat-macos-x86-64"
            ;;
        *)
            error "不支持的平台: ${os}_${arch}"
            ;;
    esac

    log "  下载: $download_url"
    run curl -L -o /tmp/popopx-chat-bin "$download_url"
    run chmod +x /tmp/popopx-chat-bin

    if [[ $EUID -eq 0 ]]; then
        run mv /tmp/popopx-chat-bin "$CHAT_BIN"
    else
        run mkdir -p "$HOME/.local/bin"
        CHAT_BIN="$HOME/.local/bin/popopx-chat"
        run mv /tmp/popopx-chat-bin "$CHAT_BIN"
    fi

    if command -v popopx-chat >/dev/null 2>&1; then
        log "  ✓ POPOPX Chat CLI 已安装: $(popopx-chat --version 2>/dev/null || echo 'unknown version')"
    else
        log "  ✓ POPOPX Chat CLI 已安装: $CHAT_BIN"
        log "  提示: 将 $HOME/.local/bin 加入 PATH"
    fi
}

# ============================================================
# Step 2: 检查前置条件
# ============================================================
check_prerequisites() {
    log "检查前置条件..."

    if ! command -v node >/dev/null 2>&1; then
        error "Node.js 未安装 (需要 v18+)"
    fi

    NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_VERSION" -lt 18 ]]; then
        error "Node.js 版本过低: $(node --version)，需要 v18+"
    fi
    log "  ✓ Node.js $(node --version)"
    log "  ✓ npm $(npm --version)"

    if ! command -v popopx-chat >/dev/null 2>&1; then
        local local_path="$HOME/.local/bin/popopx-chat"
        if [[ -x "$local_path" ]]; then
            log "  ✓ POPOPX Chat CLI: $local_path"
        else
            log "  ⚠ POPOPX Chat CLI 未安装 (运行: $0 --install-chat)"
        fi
    else
        log "  ✓ POPOPX Chat CLI: $(which popopx-chat)"
    fi

    if [[ ! -d "$BOT_DIR" ]]; then
        error "Bot 目录不存在: $BOT_DIR"
    fi

    if [[ ! -f "$BOT_DIR/.env" ]]; then
        log "  ⚠ .env 文件不存在，从模板创建..."
        run cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
        log "  请编辑 $BOT_DIR/.env 填入配置"
    fi

    if [[ -f "$BOT_DIR/.env" ]]; then
        source "$BOT_DIR/.env" 2>/dev/null || true

        if [[ -z "${ED25519_PRIVATE_KEY:-}" ]]; then
            log "  ⚠ ED25519_PRIVATE_KEY 未配置"
            log "    运行: $0 --generate-keys"
        fi
    fi

    log "前置条件检查完成"
}

# ============================================================
# Step 3: 安装依赖并构建
# ============================================================
build_bot() {
    log "Step 3: 安装依赖并构建..."

    cd "$BOT_DIR"

    log "安装 npm 依赖..."
    run npm install --production=false

    log "构建 TypeScript..."
    run npm run build

    if $DRY_RUN; then
        log "[DRY RUN] 跳过构建验证"
    elif [[ ! -f "dist/index.js" ]]; then
        error "构建失败: dist/index.js 不存在"
    fi

    log "构建完成"
}

# ============================================================
# Step 4: 创建 systemd 服务
# ============================================================
setup_systemd() {
    log "Step 4: 配置 systemd 服务..."

    if [[ $EUID -ne 0 ]]; then
        log "  ⚠ 需要 root 权限创建 systemd 服务"
        log "  请手动运行: sudo $0"
        return
    fi

    local chat_bin
    chat_bin=$(command -v popopx-chat 2>/dev/null || echo "$HOME/.local/bin/popopx-chat")

    mkdir -p "$CHAT_DATA_DIR"
    chown "${NODE_USER}:${NODE_USER}" "$CHAT_DATA_DIR"

    # POPOPX Chat CLI service (WebSocket server)
    local CHAT_SERVICE_FILE="/etc/systemd/system/${CHAT_SERVICE}.service"
    cat > "$CHAT_SERVICE_FILE" <<EOF
[Unit]
Description=POPOPX Chat CLI (WebSocket server for Bot)
After=network.target
Wants=network.target

[Service]
Type=simple
User=${NODE_USER}
Group=${NODE_USER}
WorkingDirectory=${CHAT_DATA_DIR}
ExecStart=${chat_bin} -p ${CHAT_PORT}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${CHAT_SERVICE}

NoNewPrivileges=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    log "  POPOPX Chat 服务: $CHAT_SERVICE_FILE"

    # voucher-bot service (depends on POPOPX Chat CLI)
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=POPOPX Membership Voucher Bot
Documentation=https://github.com/your-org/popopx
After=network.target ${CHAT_SERVICE}.service
Wants=network.target
Requires=${CHAT_SERVICE}.service

[Service]
Type=simple
User=${NODE_USER}
Group=${NODE_USER}
WorkingDirectory=${BOT_DIR}
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# 安全加固
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${BOT_DIR}

# 环境变量
Environment=NODE_ENV=${NODE_ENV}
Environment=POPOPX_CHAT_PORT=${CHAT_PORT}
EnvironmentFile=${BOT_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF
    log "  voucher-bot 服务: $SERVICE_FILE"

    run systemctl daemon-reload
    run systemctl enable "$CHAT_SERVICE"
    run systemctl enable "$SERVICE_NAME"

    log "  两个服务已启用"
}

# ============================================================
# Step 5: 启动服务
# ============================================================
start_bot() {
    log "Step 5: 启动服务..."

    if [[ $EUID -ne 0 ]]; then
        log "  ⚠ 需要 root 权限启动服务"
        log "  手动启动:"
        log "    sudo systemctl start $CHAT_SERVICE"
        log "    sudo systemctl start $SERVICE_NAME"
        return
    fi

    run systemctl restart "$CHAT_SERVICE"
    log "  等待 POPOPX Chat CLI 启动..."
    sleep 3

    if systemctl is-active --quiet "$CHAT_SERVICE"; then
        log "  ✓ POPOPX Chat CLI 已启动 (port $CHAT_PORT)"
    else
        log "  ⚠ POPOPX Chat CLI 启动失败:"
        log "    sudo journalctl -u $CHAT_SERVICE -n 20"
        return
    fi

    run systemctl restart "$SERVICE_NAME"
    sleep 3

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "  ✓ voucher-bot 已启动"
    else
        log "  ⚠ voucher-bot 启动失败:"
        log "    sudo journalctl -u $SERVICE_NAME -n 20"
    fi
}

# ============================================================
# Step 6: 验证
# ============================================================
verify_bot() {
    log "Step 6: 验证..."

    if [[ $EUID -eq 0 ]]; then
        if systemctl is-active --quiet "$CHAT_SERVICE"; then
            log "  ✓ POPOPX Chat CLI: active"
        else
            log "  ⚠ POPOPX Chat CLI: inactive"
        fi

        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log "  ✓ voucher-bot: active"
        else
            log "  ⚠ voucher-bot: inactive"
        fi

        log ""
        log "  Chat CLI 日志:"
        journalctl -u "$CHAT_SERVICE" -n 3 --no-pager 2>/dev/null | while read -r line; do
            log "    $line"
        done

        log "  voucher-bot 日志:"
        journalctl -u "$SERVICE_NAME" -n 3 --no-pager 2>/dev/null | while read -r line; do
            log "    $line"
        done
    fi

    log ""
    log "验证清单:"
    log "  □ POPOPX Chat CLI 已安装"
    log "  □ .env 中 ED25519_PRIVATE_KEY 和 ED25519_PUBLIC_KEY 已配置"
    log "  □ .env 中 ADMIN_SECRET 与 PHP 后端一致"
    log "  □ .env 中 BACKEND_API_URL 指向正确的 PHP 后端"
    log "  □ Chat CLI 首次运行需手动初始化（创建 profile）"
    log "    运行: popopx-chat -p $CHAT_PORT"
    log "    然后按提示创建 profile 和地址"
}

# ============================================================
# 主流程
# ============================================================
main() {
    log "=========================================="
    log "POPOPX 会员系统 - Bot 部署"
    log "=========================================="

    generate_keys
    install_chat_cli
    check_prerequisites
    build_bot
    setup_systemd
    start_bot
    verify_bot

    log "=========================================="
    log "部署完成！"
    log "=========================================="
    log ""
    log "服务架构:"
    log "  POPOPX Chat CLI (WebSocket :${CHAT_PORT})"
    log "       ↕"
    log "  voucher-bot (TypeScript, ws://localhost:${CHAT_PORT})"
    log "       ↕"
    log "  PHP 后端 API (Nullifier Set)"
    log ""
    log "常用命令:"
    log "  查看 Chat CLI: sudo systemctl status $CHAT_SERVICE"
    log "  查看 voucher-bot: sudo systemctl status $SERVICE_NAME"
    log "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
    log "  重启全部: sudo systemctl restart $CHAT_SERVICE $SERVICE_NAME"
    log ""
    log "首次使用 POPOPX Chat CLI:"
    log "  1. sudo systemctl stop $CHAT_SERVICE"
    log "  2. popopx-chat -p $CHAT_PORT"
    log "  3. 按提示创建 profile，设置 Bot 名称"
    log "  4. 创建地址: /address"
    log "  5. 退出后: sudo systemctl start $CHAT_SERVICE"
}

main "$@"
