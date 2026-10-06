#!/bin/bash
# POPOPX 会员系统 - 服务器部署脚本
# 部署 PHP 后端 + H5 购买页
#
# 用法: ./deploy_server.sh [--dry-run]
# 前提: 在服务器上执行，需要 root 或 www-data 权限

set -euo pipefail

# ============================================================
# 配置区（根据实际情况修改）
# ============================================================
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
WEB_ROOT="${WEB_ROOT:-/var/www/popopx}"
API_ROOT="${API_ROOT:-/var/www/popopx/api}"
MEMBERSHIP_ROOT="${MEMBERSHIP_ROOT:-/var/www/popopx/membership}"
PHP_USER="${PHP_USER:-www-data}"
PHP_GROUP="${PHP_GROUP:-www-data}"

# MySQL 配置（从环境变量读取，避免硬编码密码）
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_DB="${MYSQL_DB:-popopx_api}"
MYSQL_USER="${MYSQL_USER:-popopx}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

# 检查密码是否设置
if [[ -z "$MYSQL_PASSWORD" ]]; then
    echo "[ERROR] MYSQL_PASSWORD 环境变量未设置" >&2
    echo "请先设置: export MYSQL_PASSWORD=\"your_password\"" >&2
    exit 1
fi

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
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

check_prerequisites() {
    log "检查前置条件..."

    command -v mysql >/dev/null 2>&1 || error "mysql 命令不可用"
    command -v php >/dev/null 2>&1 || error "php 命令不可用"

    # 检查 sodium 扩展
    php -m | grep -q sodium || error "PHP sodium 扩展未安装 (apt install php-sodium)"

    log "测试 MySQL 连接..."
    if ! mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "SELECT 1;" >/dev/null 2>&1; then
        error "MySQL 连接失败！请检查：
  MYSQL_HOST=$MYSQL_HOST
  MYSQL_USER=$MYSQL_USER
  MYSQL_PASSWORD=(已设置)
  
测试命令:
  mysql -h $MYSQL_HOST -u $MYSQL_USER -p
  
常见原因:
  1. MySQL 服务未启动: sudo systemctl status mysql
  2. 用户名或密码错误
  3. 用户没有访问 $MYSQL_DB 数据库的权限
  4. 数据库 $MYSQL_DB 不存在"
    fi

    log "前置条件检查通过"
}

# ============================================================
# Step 1: 数据库迁移
# ============================================================
deploy_database() {
    log "Step 1: 数据库迁移..."

    MIGRATION_FILE="$PROJECT_ROOT/popopx_api/migrations/005_membership_nullifier.sql"

    if [[ ! -f "$MIGRATION_FILE" ]]; then
        error "迁移文件不存在: $MIGRATION_FILE"
    fi

    # 检查迁移是否已执行（检查表是否存在）
    log "检查数据库连接..."
    if ! mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        "$MYSQL_DB" -N -e "SELECT 1;" >/dev/null 2>&1; then
        error "MySQL 连接失败，请检查：
  - MYSQL_HOST=$MYSQL_HOST
  - MYSQL_USER=$MYSQL_USER
  - MYSQL_PASSWORD 是否正确
  - 数据库 $MYSQL_DB 是否存在
  测试命令: mysql -h $MYSQL_HOST -u $MYSQL_USER -p $MYSQL_DB"
    fi

    TABLE_EXISTS=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        "$MYSQL_DB" -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DB' AND table_name='nullifier_set';")

    if [[ "$TABLE_EXISTS" == "1" ]]; then
        log "表 nullifier_set 已存在，跳过迁移"
    else
        log "执行迁移: 005_membership_nullifier.sql"
        run mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            "$MYSQL_DB" < "$MIGRATION_FILE"
        log "数据库迁移完成"
    fi

    # 验证表结构（dry-run 模式跳过）
    if ! $DRY_RUN; then
        log "验证表结构..."
        for table in nullifier_set voucher_codes signing_keys; do
            COUNT=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
                "$MYSQL_DB" -N -e \
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DB' AND table_name='$table';")
            if [[ "$COUNT" != "1" ]]; then
                error "表 $table 不存在"
            fi
            log "  ✓ $table"
        done
    else
        log "[DRY RUN] 跳过表结构验证"
    fi
}

# ============================================================
# Step 2: 部署 PHP 后端 API
# ============================================================
deploy_api() {
    log "Step 2: 部署 PHP 后端 API..."

    API_SRC="$PROJECT_ROOT/popopx_api"

    if [[ ! -d "$API_SRC" ]]; then
        error "API 源码目录不存在: $API_SRC"
    fi

    # 创建目标目录
    run mkdir -p "$API_ROOT"

    # 同步文件（排除敏感文件和开发文件）
    log "同步 API 文件..."
    run rsync -av --progress \
        --exclude='.env' \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='data/rate_limits/*' \
        --exclude='*.log' \
        "$API_SRC/" "$API_ROOT/"

    # 确保 data 目录存在
    run mkdir -p "$API_ROOT/data/rate_limits"

    # 设置权限
    log "设置文件权限..."
    run chown -R "$PHP_USER:$PHP_GROUP" "$API_ROOT"
    run find "$API_ROOT" -type d -exec chmod 755 {} \;
    run find "$API_ROOT" -type f -exec chmod 644 {} \;

    # data 目录需要写权限
    run chmod 755 "$API_ROOT/data"
    run chmod 755 "$API_ROOT/data/rate_limits"

    # config.php 不应该被其他用户读取
    run chmod 640 "$API_ROOT/config.php"

    log "API 部署完成: $API_ROOT"
}

# ============================================================
# Step 3: 部署 H5 购买页
# ============================================================
deploy_h5() {
    log "Step 3: 部署 H5 购买页..."

    H5_SRC="$PROJECT_ROOT/popopx_web/membership"

    if [[ ! -d "$H5_SRC" ]]; then
        error "H5 源码目录不存在: $H5_SRC"
    fi

    run mkdir -p "$MEMBERSHIP_ROOT"

    log "同步 H5 文件..."
    run rsync -av --progress \
        --exclude='.env' \
        --exclude='*.log' \
        "$H5_SRC/" "$MEMBERSHIP_ROOT/"

    run chown -R "$PHP_USER:$PHP_GROUP" "$MEMBERSHIP_ROOT"
    run find "$MEMBERSHIP_ROOT" -type d -exec chmod 755 {} \;
    run find "$MEMBERSHIP_ROOT" -type f -exec chmod 644 {} \;

    log "H5 部署完成: $MEMBERSHIP_ROOT"
}

# ============================================================
# Step 4: 验证部署
# ============================================================
verify_deployment() {
    log "Step 4: 验证部署..."

    # 检查 API 健康状态
    API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/api/v1/health" 2>/dev/null || echo "000")
    if [[ "$API_HEALTH" == "200" ]]; then
        log "  ✓ API 健康检查通过"
    else
        log "  ⚠ API 健康检查失败 (HTTP $API_HEALTH)，请检查 Web 服务器配置"
    fi

    # 检查 H5 页面
    H5_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/membership/" 2>/dev/null || echo "000")
    if [[ "$H5_STATUS" == "200" ]]; then
        log "  ✓ H5 页面可访问"
    else
        log "  ⚠ H5 页面不可访问 (HTTP $H5_STATUS)，请检查 Web 服务器配置"
    fi

    # 检查 PHP sodium
    if php -m | grep -q sodium; then
        log "  ✓ PHP sodium 扩展已加载"
    else
        log "  ⚠ PHP sodium 扩展未加载"
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    log "=========================================="
    log "POPOPX 会员系统 - 服务器部署"
    log "=========================================="

    check_prerequisites
    deploy_database
    deploy_api
    deploy_h5
    verify_deployment

    log "=========================================="
    log "部署完成！"
    log "=========================================="
    log ""
    log "后续步骤："
    log "  1. 确认 config.php 中的 ADMIN_SECRET 和 APPLE_SHARED_SECRET"
    log "  2. 配置 Web 服务器（Nginx/Apache）指向 $API_ROOT 和 $MEMBERSHIP_ROOT"
    log "  3. 部署 Bot（运行 deploy_bot.sh）"
    log "  4. 生成 Ed25519 密钥对并配置到 Bot 和 config.php"
}

main "$@"
