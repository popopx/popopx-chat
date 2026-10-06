#!/bin/bash
# Haskell iOS 库编译脚本
# 用法: ./scripts/ios/build-haskell-libs.sh
#
# 功能:
# 1. 使用 Nix 交叉编译 popopx-chat iOS 库 (GHC 9.6.6)
# 2. 解压库文件到 Libraries 目录
# 3. 使用 mac2ios 修补库文件
# 4. 复制 Vendor 依赖库 (libcurl 等)
#
# 依赖:
# - Nix 包管理器 (/nix/var/nix/profiles/default/bin/nix)
# - Xcode Command Line Tools
# - mac2ios (由 Nix 自动提供)

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要工具
check_dependencies() {
    log_info "检查依赖..."
    
    # 检查 Nix
    if [ ! -f "/nix/var/nix/profiles/default/bin/nix" ]; then
        log_error "Nix 未安装于 /nix/var/nix/profiles/default/bin/nix"
        exit 1
    fi
    export PATH="/nix/var/nix/profiles/default/bin:$PATH"
    
    # 检查 git
    if ! command -v git &> /dev/null; then
        log_error "git 未安装"
        exit 1
    fi
    
    log_info "依赖检查通过"
}

# 查找 mac2ios 工具
find_mac2ios() {
    log_info "查找 mac2ios 工具..."
    MAC2IOS=$(find /nix/store -name mac2ios -type f 2>/dev/null | head -1)
    
    if [ -z "$MAC2IOS" ]; then
        log_error "mac2ios 工具未找到。请先运行 Nix 构建。"
        exit 1
    fi
    
    log_info "mac2ios: $MAC2IOS"
}

# Nix 交叉编译
nix_build() {
    log_info "开始 Nix 交叉编译 (GHC 9.6.6)..."
    
    cd "$PROJECT_ROOT"
    
    nix build .#'aarch64-darwin-ios:lib:popopx-chat' \
        --extra-experimental-features "nix-command flakes" \
        2>&1 | tee /tmp/haskell-ios-build-$(date +%Y%m%d-%H%M%S).log
    
    if [ ! -f "./result/pkg-ios-aarch64-swift-json.zip" ]; then
        log_error "Nix 构建失败，未生成 zip 文件"
        exit 1
    fi
    
    log_info "Nix 构建成功"
}

# 解压库文件
extract_libs() {
    log_info "解压库文件到 Libraries 目录..."
    
    cd "$IOS_DIR"
    
    # 清理旧目录
    rm -rf Libraries/mac Libraries/ios Libraries/sim
    mkdir -p Libraries/mac Libraries/ios Libraries/sim
    
    # 解压
    unzip -o ../../result/pkg-ios-aarch64-swift-json.zip -d Libraries/mac
    chmod +w Libraries/mac/*
    
    # 复制到 ios 和 sim
    cp Libraries/mac/* Libraries/ios
    cp Libraries/mac/* Libraries/sim
    
    log_info "库文件解压完成"
}

# 使用 mac2ios 修补库
patch_libs() {
    log_info "使用 mac2ios 修补库文件..."
    
    cd "$IOS_DIR"
    
    # 修补 iOS 设备库
    log_info "修补 iOS 设备库 (Libraries/ios/)..."
    for f in Libraries/ios/*.a; do
        if [ -f "$f" ]; then
            $MAC2IOS "$f" > /dev/null 2>&1 || true
        fi
    done
    
    # 修补 iOS 模拟器库
    log_info "修补 iOS 模拟器库 (Libraries/sim/)..."
    for f in Libraries/sim/*.a; do
        if [ -f "$f" ]; then
            $MAC2IOS -s "$f" > /dev/null 2>&1 || true
        fi
    done
    
    log_info "库文件修补完成"
}

# 复制 Vendor 依赖库
copy_vendor_deps() {
    log_info "复制 Vendor 依赖库..."
    
    cd "$IOS_DIR"
    
    # libcurl
    if [ -f "Vendor/cactus/cactus-engine/libs/curl/ios/device/libcurl.a" ]; then
        cp Vendor/cactus/cactus-engine/libs/curl/ios/device/libcurl.a Libraries/ios/
        cp Vendor/cactus/cactus-engine/libs/curl/ios/simulator/libcurl.a Libraries/sim/
        cp Vendor/cactus/cactus-engine/libs/curl/macos/libcurl.a Libraries/mac/
        log_info "libcurl.a 已复制"
    else
        log_warn "Vendor libcurl 未找到，跳过"
    fi
    
    # 可以在这里添加其他 Vendor 依赖
    # cp Vendor/.../libXXX.a Libraries/ios/
    # cp Vendor/.../libXXX.a Libraries/sim/
    # cp Vendor/.../libXXX.a Libraries/mac/
    
    log_info "Vendor 依赖复制完成"
}

# 创建符号链接（保持 Xcode 兼容性）
create_symlinks() {
    log_info "创建符号链接以保持 Xcode 兼容性..."
    
    cd "$IOS_DIR"
    
    # 查找新生成的库文件
    NEW_GHC_LIB=$(find Libraries/mac -name "libHSpopopx-chat-*-ghc9.6.6.a" -type f | head -1)
    NEW_CORE_LIB=$(find Libraries/mac -name "libHSpopopx-chat-*.a" -type f ! -name "*-ghc*" | head -1)
    
    if [ -z "$NEW_GHC_LIB" ] || [ -z "$NEW_CORE_LIB" ]; then
        log_warn "未找到新生成的库文件，跳过符号链接创建"
        return
    fi
    
    NEW_GHC_NAME=$(basename "$NEW_GHC_LIB")
    NEW_CORE_NAME=$(basename "$NEW_CORE_LIB")
    
    # 为每个目录创建符号链接
    for dir in mac ios sim; do
        cd "Libraries/$dir"
        
        # 查找旧的 Xcode 项目引用的文件名
        for old_lib in libHSpopopx-chat-*-ghc9.6.4.a; do
            if [ -f "$old_lib" ] || [ -L "$old_lib" ]; then
                rm -f "$old_lib"
                ln -sf "$NEW_GHC_NAME" "$old_lib"
            fi
        done
        
        for old_lib in libHSpopopx-chat-*.a; do
            if [[ "$old_lib" != *"-ghc"* ]] && ([ -f "$old_lib" ] || [ -L "$old_lib" ]); then
                # 跳过新生成的文件
                if [ "$old_lib" != "$NEW_CORE_NAME" ]; then
                    rm -f "$old_lib"
                    ln -sf "$NEW_CORE_NAME" "$old_lib"
                fi
            fi
        done
        
        cd ../..
    done
    
    log_info "符号链接创建完成"
}

# 验证库文件
verify_libs() {
    log_info "验证库文件..."
    
    cd "$IOS_DIR"
    
    # 检查 iOS 设备库
    if [ -d "Libraries/ios" ]; then
        IOS_LIB_COUNT=$(find Libraries/ios -name "*.a" -type f | wc -l)
        log_info "iOS 设备库: $IOS_LIB_COUNT 个文件"
        
        # 检查架构
        FIRST_LIB=$(find Libraries/ios -name "libHSpopopx-chat*.a" -type f | head -1)
        if [ -n "$FIRST_LIB" ]; then
            ARCH=$(ar t "$FIRST_LIB" 2>/dev/null | head -1)
            if [ -n "$ARCH" ]; then
                ar x "$FIRST_LIB" "$ARCH" 2>/dev/null
                FILE_INFO=$(file "$ARCH" 2>/dev/null)
                rm -f "$ARCH"
                if echo "$FILE_INFO" | grep -q "arm64"; then
                    log_info "库文件架构: arm64 ✓"
                else
                    log_warn "库文件架构可能不正确: $FILE_INFO"
                fi
            fi
        fi
    fi
    
    # 检查 libcurl
    if [ -f "Libraries/ios/libcurl.a" ]; then
        log_info "libcurl.a 存在 ✓"
    else
        log_warn "libcurl.a 未找到"
    fi
    
    log_info "验证完成"
}

# 显示结果
show_result() {
    log_info "编译完成！"
    echo ""
    echo "库文件位置:"
    echo "  macOS:     $IOS_DIR/Libraries/mac/"
    echo "  iOS 设备:  $IOS_DIR/Libraries/ios/"
    echo "  iOS 模拟器: $IOS_DIR/Libraries/sim/"
    echo ""
    echo "主要文件:"
    cd "$IOS_DIR"
    ls -lh Libraries/mac/libHSpopopx-chat*.a 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo "下一步:"
    echo "  1. 在 Xcode 中构建项目验证"
    echo "  2. 如遇链接错误，检查 Vendor 依赖是否完整"
    echo ""
}

# 主函数
main() {
    # 设置路径
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    IOS_DIR="$PROJECT_ROOT/apps/ios"
    
    echo "========================================"
    echo "Haskell iOS 库编译脚本"
    echo "========================================"
    echo ""
    echo "项目根目录: $PROJECT_ROOT"
    echo "iOS 目录:   $IOS_DIR"
    echo ""
    
    check_dependencies
    find_mac2ios
    nix_build
    extract_libs
    patch_libs
    copy_vendor_deps
    create_symlinks
    verify_libs
    show_result
}

# 运行主函数
main "$@"
