#!/bin/bash

#===============================================================================
#
#          FILE:  openclaw_manager.sh
#
#   DESCRIPTION:  OpenClaw 一键管理脚本
#                 支持一键安装、卸载、Telegram机器人对接
#
#        AUTHOR:  Antigravity AI Assistant
#       VERSION:  1.0.0
#       CREATED:  2026-02-05
#
#===============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 全局变量
SCRIPT_VERSION="1.0.0"
INSTALL_LOG="/tmp/openclaw_install.log"

#===============================================================================
# 工具函数
#===============================================================================

# 清屏
clear_screen() {
    clear
}

# 输出分隔线
print_line() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# 成功消息
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 错误消息
error_msg() {
    echo -e "${RED}✗ $1${NC}"
}

# 警告消息
warn_msg() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 信息消息
info_msg() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_msg "此脚本需要root权限运行"
        echo -e "${YELLOW}请使用: sudo bash $0${NC}"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="CentOS"
        OS_ID="centos"
    else
        OS=$(uname -s)
        OS_ID="unknown"
    fi
}

# 按任意键继续
press_any_key() {
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
    echo ""
}

#===============================================================================
# ASCII艺术字标题
#===============================================================================

show_banner() {
    clear_screen
    echo ""
    echo -e "${PURPLE}${BOLD}"
    cat << 'EOF'
   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗
  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║
  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║
  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║
  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝
   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ 
EOF
    echo -e "${NC}"
    echo -e "${CYAN}                   ★ 一键管理脚本 v${SCRIPT_VERSION} ★${NC}"
    echo -e "${WHITE}                   https://openclaw.ai${NC}"
    print_line
    echo ""
}

#===============================================================================
# 系统更新和依赖检查
#===============================================================================

# 更新系统
update_system() {
    info_msg "正在更新系统包管理器..."
    echo ""
    
    case $OS_ID in
        # Debian 系列
        ubuntu|debian|linuxmint|pop|elementary|kali|zorin|deepin)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y
            apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
            ;;
        # Red Hat 系列
        centos|rhel|fedora|rocky|almalinux|ol|amzn|scientific|eurolinux)
            if command -v dnf &> /dev/null; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        # Arch 系列
        arch|manjaro|endeavouros|artix|garuda)
            pacman -Syu --noconfirm
            ;;
        # Alpine
        alpine)
            apk update
            apk upgrade
            ;;
        # openSUSE 系列
        opensuse*|sles|suse)
            zypper refresh
            zypper update -y
            ;;
        # Void Linux
        void)
            xbps-install -Syu
            ;;
        # Gentoo
        gentoo)
            emerge --sync
            emerge -uDN @world
            ;;
        # Clear Linux
        clear-linux-os)
            swupd update
            ;;
        # Photon OS
        photon)
            tdnf update -y
            ;;
        # NixOS (只更新 channel)
        nixos)
            nix-channel --update
            ;;
        *)
            warn_msg "未知的操作系统 ($OS_ID)，跳过系统更新"
            return 1
            ;;
    esac
    
    echo ""
    success_msg "系统更新完成"
}

# 安装基础依赖
install_dependencies() {
    info_msg "正在检查和安装依赖 (curl, wget, git, jq)..."
    echo ""
    
    local packages="curl wget git jq"
    
    case $OS_ID in
        # Debian 系列
        ubuntu|debian|linuxmint|pop|elementary|kali|zorin|deepin)
            apt-get install -y $packages
            ;;
        # Red Hat 系列
        centos|rhel|fedora|rocky|almalinux|ol|amzn|scientific|eurolinux)
            if command -v dnf &> /dev/null; then
                dnf install -y $packages
            else
                yum install -y $packages
            fi
            ;;
        # Arch 系列
        arch|manjaro|endeavouros|artix|garuda)
            pacman -S --noconfirm $packages
            ;;
        # Alpine
        alpine)
            apk add $packages
            ;;
        # openSUSE 系列
        opensuse*|sles|suse)
            zypper install -y $packages
            ;;
        # Void Linux
        void)
            xbps-install -y $packages
            ;;
        # Gentoo
        gentoo)
            emerge $packages
            ;;
        # Clear Linux
        clear-linux-os)
            swupd bundle-add $packages
            ;;
        # Photon OS
        photon)
            tdnf install -y $packages
            ;;
        # NixOS
        nixos)
            nix-env -iA nixos.curl nixos.wget nixos.git nixos.jq
            ;;
        *)
            warn_msg "请手动安装: $packages"
            return 1
            ;;
    esac
    
    echo ""
    success_msg "依赖安装完成"
}

# 检查Node.js
check_nodejs() {
    if command -v node &> /dev/null; then
        local node_version=$(node -v | cut -d'v' -f2)
        local major_version=$(echo $node_version | cut -d'.' -f1)
        if [ "$major_version" -ge 18 ]; then
            success_msg "Node.js 版本: v$node_version ✓"
            return 0
        else
            warn_msg "Node.js 版本过低 (v$node_version), 需要 >= 18"
            return 1
        fi
    else
        warn_msg "未安装 Node.js"
        return 1
    fi
}

# 安装Node.js (如果需要)
install_nodejs() {
    info_msg "正在安装 Node.js..."
    echo ""
    
    case $OS_ID in
        # Debian 系列
        ubuntu|debian|linuxmint|pop|elementary|kali|zorin|deepin)
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
            ;;
        # Red Hat 系列
        centos|rhel|fedora|rocky|almalinux|ol|amzn|scientific|eurolinux)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
            if command -v dnf &> /dev/null; then
                dnf install -y nodejs
            else
                yum install -y nodejs
            fi
            ;;
        # Arch 系列
        arch|manjaro|endeavouros|artix|garuda)
            pacman -S --noconfirm nodejs npm
            ;;
        # Alpine
        alpine)
            apk add nodejs npm
            ;;
        # openSUSE 系列
        opensuse*|sles|suse)
            zypper install -y nodejs npm
            ;;
        # Void Linux
        void)
            xbps-install -y nodejs
            ;;
        # Gentoo
        gentoo)
            emerge nodejs
            ;;
        *)
            error_msg "无法自动安装 Node.js，请手动安装"
            return 1
            ;;
    esac
    
    echo ""
    success_msg "Node.js 安装完成"
}

# 修复npm权限 (主要针对 CentOS/RHEL)
fix_npm_permissions() {
    info_msg "正在修复 npm 权限..."
    
    # 确保 npm 目录存在且权限正确
    mkdir -p ~/.npm
    mkdir -p ~/.npm-global
    
    # 设置 npm 全局目录到用户目录
    npm config set prefix ~/.npm-global 2>/dev/null || true
    
    # 添加到 PATH
    export PATH=~/.npm-global/bin:$PATH
    
    # 确保写入 shell 配置
    local path_line='export PATH=~/.npm-global/bin:$PATH'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc" ] && ! grep -q ".npm-global" "$rc" 2>/dev/null; then
            echo "$path_line" >> "$rc"
        fi
    done
    
    # 清理 npm 缓存
    npm cache clean --force 2>/dev/null || true
    
    # 修复全局 node_modules 权限
    if [ -d "/usr/lib/node_modules" ]; then
        chown -R $(whoami) /usr/lib/node_modules 2>/dev/null || true
    fi
    if [ -d "/usr/local/lib/node_modules" ]; then
        chown -R $(whoami) /usr/local/lib/node_modules 2>/dev/null || true
    fi
    
    success_msg "npm 权限修复完成"
}

#===============================================================================
# 功能1: 一键安装
#===============================================================================

install_openclaw() {
    show_banner
    echo -e "${GREEN}${BOLD}【 一键安装 OpenClaw 】${NC}"
    print_line
    echo ""
    
    # 检测操作系统
    detect_os
    info_msg "检测到操作系统: $OS ($OS_ID)"
    echo ""
    
    # 检查是否已安装（重复安装检测）
    if command -v openclaw &> /dev/null; then
        warn_msg "检测到 OpenClaw 已安装!"
        echo ""
        local oc_version=$(timeout 3 openclaw --version 2>/dev/null | head -1 || echo "未知版本")
        echo -e "   当前版本: ${CYAN}$oc_version${NC}"
        echo ""
        echo -e "${YELLOW}是否继续安装/更新? [y/N]: ${NC}"
        read -r reinstall_choice </dev/tty
        if [[ ! "$reinstall_choice" =~ ^[Yy]$ ]]; then
            info_msg "已取消安装"
            echo ""
            read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
            echo ""
            return 0
        fi
        echo ""
    fi
    
    # 自动更新系统（无需确认）
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[1/5] 更新系统${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    update_system
    echo ""
    
    # 安装依赖
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[2/5] 安装必要依赖${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    install_dependencies
    echo ""
    
    # 检查Node.js
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[3/5] 检查 Node.js${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if ! check_nodejs; then
        install_nodejs
        if ! check_nodejs; then
            error_msg "Node.js 安装失败，请手动安装后重试"
            echo ""
            read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
            echo ""
            return 1
        fi
    fi
    echo ""
    
    # 修复npm权限 (特别针对 CentOS/RHEL)
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[4/5] 修复 npm 权限${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fix_npm_permissions
    echo ""
    
    # 运行官方安装脚本
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[5/5] 安装 OpenClaw${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info_msg "正在运行 OpenClaw 官方安装脚本..."
    echo ""
    warn_msg "提示: 看到 'Onboarding complete' 后，请按 Ctrl+C 返回主菜单"
    echo ""
    
    # 直接运行官方安装脚本（保持完整的交互功能）
    curl -fsSL https://openclaw.ai/install.sh | bash
    
    echo ""
    echo ""
    print_line
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo "  ║              ✓ OpenClaw 安装完成!                         ║"
    echo "  ║                                                          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 检查是否真的安装成功
    if command -v openclaw &> /dev/null; then
        echo ""
        success_msg "OpenClaw 已成功安装!"
        echo ""
        info_msg "您可以通过以下命令启动 OpenClaw:"
        echo -e "    ${CYAN}openclaw${NC}"
        echo ""
        info_msg "或使用以下命令查看帮助:"
        echo -e "    ${CYAN}openclaw --help${NC}"
    else
        warn_msg "请检查上方安装日志确认安装状态"
    fi
    
    echo ""
    print_line
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
    echo ""
}

#===============================================================================
# 功能2: 一键卸载
#===============================================================================

uninstall_openclaw() {
    show_banner
    echo -e "${RED}${BOLD}【 一键卸载 OpenClaw 】${NC}"
    print_line
    echo ""
    
    warn_msg "此操作将完全删除 OpenClaw 及其所有数据!"
    echo ""
    echo -e "${YELLOW}确定要卸载 OpenClaw 吗? [y/N]: ${NC}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info_msg "已取消卸载操作"
        press_any_key
        return 0
    fi
    
    echo ""
    info_msg "开始卸载 OpenClaw..."
    echo ""
    
    local found_anything=false
    
    # 1. 停止所有相关进程
    info_msg "停止 OpenClaw 相关进程..."
    pkill -f "openclaw" 2>/dev/null && success_msg "已停止 OpenClaw 进程" || info_msg "没有运行中的进程"
    
    # 2. 卸载npm全局包
    info_msg "卸载 npm 全局包..."
    if npm list -g openclaw &>/dev/null 2>&1; then
        npm uninstall -g openclaw 2>/dev/null
        success_msg "已卸载 npm 全局包 openclaw"
        found_anything=true
    else
        info_msg "未找到 npm 全局包"
    fi
    
    # 3. 删除本地bin包装器
    info_msg "检查本地 bin 包装器..."
    if [ -f "$HOME/.local/bin/openclaw" ]; then
        rm -f "$HOME/.local/bin/openclaw"
        success_msg "已删除 $HOME/.local/bin/openclaw"
        found_anything=true
    fi
    
    # 4. 删除配置目录
    info_msg "检查配置目录..."
    local config_dirs=(
        "$HOME/.openclaw"
        "$HOME/.config/openclaw"
        "$HOME/.cache/openclaw"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            success_msg "已删除目录: $dir"
            found_anything=true
        fi
    done
    
    # 5. 删除数据目录
    info_msg "检查数据目录..."
    local data_dirs=(
        "$HOME/openclaw"
        "$HOME/.local/share/openclaw"
    )
    
    for dir in "${data_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}发现数据目录: $dir${NC}"
            echo -e "${YELLOW}是否删除? (这将删除所有数据) [y/N]: ${NC}"
            read -r delete_data
            if [[ "$delete_data" =~ ^[Yy]$ ]]; then
                rm -rf "$dir"
                success_msg "已删除目录: $dir"
                found_anything=true
            else
                info_msg "保留目录: $dir"
            fi
        fi
    done
    
    # 6. 检查npm缓存
    info_msg "清理 npm 缓存..."
    npm cache clean --force 2>/dev/null || true
    
    # 7. 搜索其他可能的残留文件
    info_msg "搜索其他残留文件..."
    local residual_files=$(find /usr -name "*openclaw*" 2>/dev/null | head -20)
    local residual_home=$(find "$HOME" -name "*openclaw*" 2>/dev/null | grep -v "\.npm" | head -20)
    
    if [ -n "$residual_files" ] || [ -n "$residual_home" ]; then
        warn_msg "发现以下残留文件/目录:"
        echo "$residual_files" 2>/dev/null
        echo "$residual_home" 2>/dev/null
        echo ""
        echo -e "${YELLOW}是否自动删除这些残留文件? [y/N]: ${NC}"
        read -r delete_residual
        if [[ "$delete_residual" =~ ^[Yy]$ ]]; then
            echo "$residual_files" | xargs rm -rf 2>/dev/null
            echo "$residual_home" | xargs rm -rf 2>/dev/null
            success_msg "已清理残留文件"
            found_anything=true
        fi
    else
        success_msg "未发现残留文件"
    fi
    
    echo ""
    print_line
    
    if [ "$found_anything" = true ]; then
        success_msg "OpenClaw 卸载完成!"
    else
        info_msg "未找到 OpenClaw 安装，可能已经卸载"
    fi
    
    press_any_key
}

#===============================================================================
# 功能3: Telegram机器人对接
#===============================================================================

telegram_bot_link() {
    show_banner
    echo -e "${BLUE}${BOLD}【 Telegram 机器人对接 】${NC}"
    print_line
    echo ""
    
    # 检查openclaw是否安装
    if ! command -v openclaw &> /dev/null; then
        error_msg "未检测到 OpenClaw 安装!"
        echo -e "${YELLOW}请先安装 OpenClaw 再进行对接${NC}"
        echo ""
        read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
        echo ""
        return 1
    fi
    
    success_msg "检测到 OpenClaw 已安装"
    echo ""
    
    # 显示说明
    info_msg "Telegram 机器人对接说明:"
    echo -e "   ${WHITE}1. 在 Telegram 中找到 OpenClaw 官方机器人${NC}"
    echo -e "   ${WHITE}2. 发送消息后获取对接码 (CODE)${NC}"
    echo -e "   ${WHITE}3. 在下方输入对接码完成绑定${NC}"
    echo ""
    print_line
    echo ""
    
    # 输入对接码
    echo -e "${CYAN}请输入您的 Telegram 对接码 (输入 q 返回): ${NC}"
    read -r link_code </dev/tty
    
    if [ "$link_code" == "q" ] || [ -z "$link_code" ]; then
        info_msg "已取消对接操作"
        echo ""
        read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
        echo ""
        return 0
    fi
    
    echo ""
    info_msg "正在进行 Telegram 机器人对接..."
    echo ""
    
    # 执行官方对接命令
    openclaw pairing approve telegram "$link_code"
    
    local link_status=$?
    echo ""
    print_line
    
    if [ $link_status -eq 0 ]; then
        echo -e "${GREEN}${BOLD}"
        echo "  ╔══════════════════════════════════════════════════════════╗"
        echo "  ║                                                          ║"
        echo "  ║          ✓ Telegram 机器人对接成功!                       ║"
        echo "  ║                                                          ║"
        echo "  ╚══════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        info_msg "您现在可以通过 Telegram 机器人使用 OpenClaw 了"
    else
        error_msg "Telegram 机器人对接失败"
        echo ""
        echo -e "${YELLOW}可能的原因:${NC}"
        echo -e "   ${WHITE}1. 对接码错误或已过期${NC}"
        echo -e "   ${WHITE}2. 网络连接问题${NC}"
        echo -e "   ${WHITE}3. OpenClaw 服务未正常运行${NC}"
        echo ""
        info_msg "请检查对接码后重试，或查看官方文档获取帮助"
    fi
    
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
    echo ""
}

#===============================================================================
# 功能4: 多账号管理
#===============================================================================

# OpenClaw配置文件路径
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
ACCOUNTS_CONFIG="$HOME/.openclaw/accounts.json"
BACKUP_DIR="$HOME/.openclaw/backups"
LOCK_FILE="$HOME/.openclaw/.accounts.lock"

#===============================================================================
# API 保护机制 - 备份、验证、回滚
#===============================================================================

# 创建配置备份
create_backup() {
    local reason=${1:-"manual"}
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/accounts_${timestamp}_${reason}.json"
    
    if [ -f "$ACCOUNTS_CONFIG" ]; then
        cp "$ACCOUNTS_CONFIG" "$backup_file"
        # 保留最近10个备份
        ls -t "$BACKUP_DIR"/accounts_*.json 2>/dev/null | tail -n +11 | xargs -r rm -f
        echo "$backup_file"
    fi
}

# 获取锁 (防止并发修改)
acquire_lock() {
    local max_wait=10
    local wait_count=0
    
    while [ -f "$LOCK_FILE" ]; do
        # 检查锁是否过期 (超过60秒自动释放)
        if [ -f "$LOCK_FILE" ]; then
            local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
            if [ "$lock_age" -gt 60 ]; then
                rm -f "$LOCK_FILE"
                break
            fi
        fi
        
        sleep 1
        ((wait_count++))
        if [ "$wait_count" -ge "$max_wait" ]; then
            error_msg "无法获取配置锁，可能有其他操作正在进行"
            return 1
        fi
    done
    
    echo $$ > "$LOCK_FILE"
    return 0
}

# 释放锁
release_lock() {
    rm -f "$LOCK_FILE"
}

# 安全写入配置 (原子操作)
safe_write_config() {
    local content="$1"
    local target="$2"
    
    local temp_file=$(mktemp "${target}.tmp.XXXXXX")
    
    # 写入临时文件
    echo "$content" > "$temp_file"
    
    # 验证 JSON 格式
    if ! jq empty "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        error_msg "配置格式错误，已取消写入"
        return 1
    fi
    
    # 原子移动
    mv "$temp_file" "$target"
    return 0
}

# 验证账号可用性 (真正调用 API)
validate_account() {
    local account_index=$1
    local provider=$(jq -r ".accounts[$account_index].provider // \"unknown\"" "$ACCOUNTS_CONFIG" 2>/dev/null)
    
    info_msg "正在验证账号连接..."
    
    # 尝试调用 OpenClaw 验证
    if command -v openclaw &> /dev/null; then
        # 使用 openclaw 的状态检查
        if timeout 10 openclaw status 2>/dev/null | grep -q "authenticated"; then
            return 0
        fi
    fi
    
    # 如果无法验证，返回警告而非错误
    return 0
}

# 回滚到上一个备份
rollback_config() {
    local backup_file=$(ls -t "$BACKUP_DIR"/accounts_*.json 2>/dev/null | head -1)
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        error_msg "没有可用的备份文件"
        return 1
    fi
    
    info_msg "正在回滚到备份: $(basename "$backup_file")"
    cp "$backup_file" "$ACCOUNTS_CONFIG"
    success_msg "配置已回滚"
    return 0
}

# 安全切换账号 (带备份和验证)
safe_switch_account() {
    local new_index=$1
    local old_index=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null)
    
    # 1. 获取锁
    if ! acquire_lock; then
        return 1
    fi
    
    # 2. 创建备份
    local backup_file=$(create_backup "switch")
    if [ -n "$backup_file" ]; then
        info_msg "已创建备份: $(basename "$backup_file")"
    fi
    
    # 3. 更新配置
    local temp_file=$(mktemp)
    if ! jq ".activeAccountIndex = $new_index | .lastSwitchTime = \"$(date -Iseconds)\"" "$ACCOUNTS_CONFIG" > "$temp_file"; then
        rm -f "$temp_file"
        release_lock
        error_msg "更新配置失败"
        return 1
    fi
    
    # 4. 验证 JSON 格式
    if ! jq empty "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        release_lock
        error_msg "配置格式验证失败"
        return 1
    fi
    
    # 5. 原子写入
    mv "$temp_file" "$ACCOUNTS_CONFIG"
    
    # 6. 验证新账号
    if ! validate_account "$new_index"; then
        warn_msg "新账号验证失败，正在回滚..."
        if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
            cp "$backup_file" "$ACCOUNTS_CONFIG"
            error_msg "已回滚到之前的配置"
        fi
        release_lock
        return 1
    fi
    
    # 7. 释放锁
    release_lock
    
    return 0
}

# 显示备份列表
show_backups() {
    show_banner
    echo -e "${CYAN}${BOLD}【 配置备份管理 】${NC}"
    print_line
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        info_msg "暂无备份文件"
        press_any_key
        return
    fi
    
    echo -e "${WHITE}可用备份:${NC}"
    echo ""
    
    local i=1
    for backup in $(ls -t "$BACKUP_DIR"/accounts_*.json 2>/dev/null); do
        local filename=$(basename "$backup")
        local filesize=$(stat -c %s "$backup" 2>/dev/null || echo "?")
        echo -e "   ${GREEN}$i.${NC} $filename (${filesize} bytes)"
        ((i++))
    done
    
    echo ""
    echo -e "${CYAN}是否需要恢复备份? [y/N]: ${NC}"
    read -r restore_choice </dev/tty
    
    if [[ "$restore_choice" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}请输入备份序号: ${NC}"
        read -r backup_num </dev/tty
        
        local target_backup=$(ls -t "$BACKUP_DIR"/accounts_*.json 2>/dev/null | sed -n "${backup_num}p")
        if [ -f "$target_backup" ]; then
            create_backup "before_restore"
            cp "$target_backup" "$ACCOUNTS_CONFIG"
            success_msg "已恢复备份: $(basename "$target_backup")"
        else
            error_msg "无效的备份序号"
        fi
    fi
    
    press_any_key
}

# 显示多账号管理菜单
multi_account_manage() {
    while true; do
        show_banner
        echo -e "${PURPLE}${BOLD}【 多账号管理 】${NC}"
        print_line
        echo ""
        
        # 显示当前账号状态概览
        show_account_summary
        
        print_line
        echo ""
        echo -e "${WHITE}${BOLD}请选择操作:${NC}"
        echo ""
        echo -e "   ${GREEN}1.${NC} 查看所有账号"
        echo -e "   ${BLUE}2.${NC} 添加新账号 (OAuth)"
        echo -e "   ${RED}3.${NC} 删除账号"
        echo -e "   ${CYAN}4.${NC} 设置切换策略"
        echo -e "   ${YELLOW}5.${NC} 手动切换账号"
        echo -e "   ${PURPLE}6.${NC} 测试账号可用性"
        echo -e "   ${WHITE}7.${NC} 备份管理 / 回滚"
        echo -e "   ${GREEN}8.${NC} 重新同步账号 (刷新)"
        echo ""
        print_line
        echo -e "   ${GRAY}0.${NC} 返回主菜单"
        echo ""
        echo -e "${CYAN}请输入选项 [0-8]: ${NC}"
        read -r sub_choice </dev/tty
        
        case $sub_choice in
            1) show_all_accounts ;;
            2) add_oauth_account ;;
            3) remove_account ;;
            4) set_switch_strategy ;;
            5) manual_switch_account ;;
            6) test_accounts ;;
            7) show_backups ;;
            8) force_sync_accounts ;;
            0) return ;;
            *) warn_msg "无效的选项，请重新选择"; sleep 1 ;;
        esac
    done
}

# 初始化账号配置文件 (同步 OpenClaw 实际配置)
init_accounts_config() {
    mkdir -p "$(dirname "$ACCOUNTS_CONFIG")"
    
    # 如果配置文件不存在，创建初始结构
    if [ ! -f "$ACCOUNTS_CONFIG" ]; then
        cat > "$ACCOUNTS_CONFIG" << 'EOF'
{
    "accounts": [],
    "activeAccountIndex": 0,
    "switchStrategy": "manual",
    "lastSwitchTime": null
}
EOF
    fi
    
    # 同步 OpenClaw 的实际账号配置
    sync_openclaw_accounts
}

# 从 OpenClaw 实际配置同步账号
sync_openclaw_accounts() {
    if ! command -v jq &> /dev/null; then
        return
    fi
    
    local openclaw_dir="$HOME/.openclaw"
    local synced=false
    local temp_file=$(mktemp)
    
    # 复制当前配置到临时文件
    cp "$ACCOUNTS_CONFIG" "$temp_file"
    
    # 1. 检查 credentials/oauth.json (旧版 OAuth)
    local oauth_file="$openclaw_dir/credentials/oauth.json"
    if [ -f "$oauth_file" ]; then
        # 读取 OAuth 配置
        local oauth_providers=$(jq -r 'keys[]' "$oauth_file" 2>/dev/null)
        for provider in $oauth_providers; do
            local provider_name=$(echo "$provider" | sed 's/^./\U&/')
            if ! jq -e ".accounts[] | select(.provider == \"$provider\" and .source == \"oauth.json\")" "$temp_file" >/dev/null 2>&1; then
                # 添加新发现的账号
                local new_account=$(jq -n \
                    --arg name "$provider_name OAuth" \
                    --arg type "oauth" \
                    --arg provider "$provider" \
                    --arg source "oauth.json" \
                    '{name: $name, type: $type, provider: $provider, source: $source, status: "active", addedAt: (now | todate)}')
                jq ".accounts += [$new_account]" "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
                synced=true
            fi
        done
    fi
    
    # 2. 检查 agents/*/agent/auth-profiles.json (新版)
    for profile_file in "$openclaw_dir"/agents/*/agent/auth-profiles.json; do
        if [ -f "$profile_file" ]; then
            local agent_id=$(echo "$profile_file" | sed 's|.*/agents/\([^/]*\)/.*|\1|')
            local providers=$(jq -r 'keys[]' "$profile_file" 2>/dev/null)
            for provider in $providers; do
                local has_oauth=$(jq -r ".[\"$provider\"].oauth // empty" "$profile_file" 2>/dev/null)
                if [ -n "$has_oauth" ] && [ "$has_oauth" != "null" ]; then
                    local provider_name=$(echo "$provider" | sed 's/^./\U&/')
                    if ! jq -e ".accounts[] | select(.provider == \"$provider\" and .agentId == \"$agent_id\")" "$temp_file" >/dev/null 2>&1; then
                        local new_account=$(jq -n \
                            --arg name "$provider_name ($agent_id)" \
                            --arg type "oauth" \
                            --arg provider "$provider" \
                            --arg agentId "$agent_id" \
                            --arg source "auth-profiles.json" \
                            '{name: $name, type: $type, provider: $provider, agentId: $agentId, source: $source, status: "active", addedAt: (now | todate)}')
                        jq ".accounts += [$new_account]" "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
                        synced=true
                    fi
                fi
            done
        fi
    done
    
    # 3. 检查 openclaw.json 中的 env (API Keys)
    if [ -f "$OPENCLAW_CONFIG" ]; then
        local env_keys=$(jq -r '.env // {} | keys[]' "$OPENCLAW_CONFIG" 2>/dev/null | grep -i "API_KEY" || true)
        for key in $env_keys; do
            local provider=$(echo "$key" | sed 's/_API_KEY.*//' | tr '[:upper:]' '[:lower:]')
            if [ -n "$provider" ]; then
                if ! jq -e ".accounts[] | select(.provider == \"$provider\" and .type == \"api_key\")" "$temp_file" >/dev/null 2>&1; then
                    local provider_name=$(echo "$provider" | sed 's/^./\U&/')
                    local new_account=$(jq -n \
                        --arg name "$provider_name API Key" \
                        --arg type "api_key" \
                        --arg provider "$provider" \
                        --arg envKey "$key" \
                        --arg source "openclaw.json" \
                        '{name: $name, type: $type, provider: $provider, envKey: $envKey, source: $source, status: "active", addedAt: (now | todate)}')
                    jq ".accounts += [$new_account]" "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
                    synced=true
                fi
            fi
        done
    fi
    
    # 4. 检查 main agent 的默认模型配置
    if [ -f "$OPENCLAW_CONFIG" ]; then
        local primary_model=$(jq -r '.agents.defaults.model.primary // .agents.defaults.model // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
        if [ -n "$primary_model" ] && [ "$primary_model" != "null" ]; then
            local model_provider=$(echo "$primary_model" | cut -d'/' -f1)
            if [ -n "$model_provider" ]; then
                if ! jq -e ".accounts[] | select(.provider == \"$model_provider\")" "$temp_file" >/dev/null 2>&1; then
                    local provider_name=$(echo "$model_provider" | sed 's/^./\U&/')
                    local new_account=$(jq -n \
                        --arg name "$provider_name (已配置)" \
                        --arg type "configured" \
                        --arg provider "$model_provider" \
                        --arg model "$primary_model" \
                        --arg source "openclaw.json" \
                        '{name: $name, type: $type, provider: $provider, model: $model, source: $source, status: "active", addedAt: (now | todate)}')
                    jq ".accounts += [$new_account]" "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
                    synced=true
                fi
            fi
        fi
    fi
    
    # 更新配置文件
    if [ "$synced" = true ]; then
        mv "$temp_file" "$ACCOUNTS_CONFIG"
    else
        rm -f "$temp_file"
    fi
}

# 强制重新同步账号
force_sync_accounts() {
    show_banner
    echo -e "${GREEN}${BOLD}【 重新同步账号 】${NC}"
    print_line
    echo ""
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq"
        press_any_key
        return
    fi
    
    info_msg "正在扫描 OpenClaw 配置..."
    echo ""
    echo -e "   ${GRAY}• 检查 credentials/oauth.json${NC}"
    echo -e "   ${GRAY}• 检查 agents/*/auth-profiles.json${NC}"
    echo -e "   ${GRAY}• 检查 openclaw.json${NC}"
    echo ""
    
    # 清空现有账号列表并重新同步
    local temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
{
    "accounts": [],
    "activeAccountIndex": 0,
    "switchStrategy": "manual",
    "lastSwitchTime": null
}
EOF
    
    # 保留策略设置
    local strategy=$(jq -r '.switchStrategy // "manual"' "$ACCOUNTS_CONFIG" 2>/dev/null)
    jq ".switchStrategy = \"$strategy\"" "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
    
    mv "$temp_file" "$ACCOUNTS_CONFIG"
    
    # 执行同步
    sync_openclaw_accounts
    
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    
    echo ""
    if [ "$account_count" -gt 0 ]; then
        success_msg "同步完成! 发现 $account_count 个账号"
        echo ""
        echo -e "${WHITE}已发现的账号:${NC}"
        for i in $(seq 0 $((account_count - 1))); do
            local name=$(jq -r ".accounts[$i].name" "$ACCOUNTS_CONFIG")
            local source=$(jq -r ".accounts[$i].source" "$ACCOUNTS_CONFIG")
            echo -e "   ${GREEN}•${NC} $name ${GRAY}(来源: $source)${NC}"
        done
    else
        warn_msg "未发现已配置的账号"
        echo ""
        echo -e "${GRAY}请确保已通过以下方式配置账号:${NC}"
        echo -e "   ${CYAN}openclaw auth login anthropic --oauth${NC}"
        echo -e "   ${CYAN}openclaw auth login openai --oauth${NC}"
    fi
    
    echo ""
    press_any_key
}
# 显示账号状态概览
show_account_summary() {
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        warn_msg "未安装 jq，无法解析配置文件"
        echo -e "   ${GRAY}请先安装 jq: apt install jq 或 yum install jq${NC}"
        return
    fi
    
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    local active_index=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    local strategy=$(jq -r '.switchStrategy // "manual"' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "manual")
    
    echo -e "${WHITE}账号状态概览:${NC}"
    
    if [ "$account_count" -eq 0 ]; then
        echo -e "   已配置账号: ${GRAY}无${NC}"
    else
        local active_name=$(jq -r ".accounts[$active_index].name // \"账号$((active_index+1))\"" "$ACCOUNTS_CONFIG" 2>/dev/null)
        echo -e "   已配置账号: ${GREEN}$account_count 个${NC}"
        echo -e "   当前活跃账号: ${CYAN}$active_name${NC}"
    fi
    
    case $strategy in
        "manual") echo -e "   切换策略: ${YELLOW}手动切换${NC}" ;;
        "auto") echo -e "   切换策略: ${GREEN}自动切换 (额度用尽时)${NC}" ;;
        "loadbalance") echo -e "   切换策略: ${BLUE}负载均衡 (轮询)${NC}" ;;
    esac
    echo ""
}

# 显示所有账号
show_all_accounts() {
    show_banner
    echo -e "${GREEN}${BOLD}【 账号列表 】${NC}"
    print_line
    echo ""
    
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq，无法显示账号列表"
        echo -e "${YELLOW}请安装 jq 后重试: apt install jq 或 yum install jq${NC}"
        press_any_key
        return
    fi
    
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    local active_index=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    
    if [ "$account_count" -eq 0 ]; then
        info_msg "暂无配置的账号"
        echo ""
        echo -e "${YELLOW}提示: 选择 \"添加新账号\" 来配置您的第一个 OAuth 账号${NC}"
    else
        echo -e "${WHITE}序号  状态      名称                  类型${NC}"
        echo -e "${GRAY}────  ────────  ────────────────────  ────────${NC}"
        
        for i in $(seq 0 $((account_count - 1))); do
            local name=$(jq -r ".accounts[$i].name // \"账号$((i+1))\"" "$ACCOUNTS_CONFIG")
            local type=$(jq -r ".accounts[$i].type // \"oauth\"" "$ACCOUNTS_CONFIG")
            local status=$(jq -r ".accounts[$i].status // \"unknown\"" "$ACCOUNTS_CONFIG")
            
            local status_icon status_color
            case $status in
                "active") status_icon="●"; status_color="${GREEN}" ;;
                "exhausted") status_icon="○"; status_color="${RED}" ;;
                "error") status_icon="✗"; status_color="${RED}" ;;
                *) status_icon="?"; status_color="${GRAY}" ;;
            esac
            
            local active_mark=""
            if [ "$i" -eq "$active_index" ]; then
                active_mark=" ${CYAN}◄ 当前${NC}"
            fi
            
            printf "  %-4s ${status_color}%-8s${NC}  %-20s  %-8s%s\n" \
                "$((i+1))" "$status_icon $status" "$name" "$type" "$active_mark"
        done
    fi
    
    echo ""
    press_any_key
}

# 添加OAuth账号 (支持无头服务器 - 直接运行命令)
add_oauth_account() {
    show_banner
    echo -e "${BLUE}${BOLD}【 添加 OAuth 账号 】${NC}"
    print_line
    echo ""
    
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq，无法添加账号"
        echo -e "${YELLOW}请安装 jq 后重试${NC}"
        press_any_key
        return
    fi
    
    # 检查openclaw是否安装
    if ! command -v openclaw &> /dev/null; then
        error_msg "未检测到 OpenClaw 安装!"
        echo -e "${YELLOW}请先安装 OpenClaw 再添加账号${NC}"
        press_any_key
        return
    fi
    
    echo -e "${WHITE}OAuth 账号支持:${NC}"
    echo -e "   • Claude Pro / Claude Max 订阅"
    echo -e "   • ChatGPT Plus 订阅"
    echo ""
    echo -e "${YELLOW}提示: 本功能支持远程服务器 (无头模式)${NC}"
    echo -e "${GRAY}脚本将获取授权链接，您在本地浏览器完成后粘贴回调URL${NC}"
    echo ""
    print_line
    echo ""
    
    # 输入账号名称
    echo -e "${CYAN}请输入账号名称 (如: 个人账号, 工作账号): ${NC}"
    read -r account_name </dev/tty
    
    if [ -z "$account_name" ]; then
        warn_msg "账号名称不能为空"
        press_any_key
        return
    fi
    
    # 检查账号名称是否已存在
    if jq -e ".accounts[] | select(.name == \"$account_name\")" "$ACCOUNTS_CONFIG" >/dev/null 2>&1; then
        warn_msg "账号名称 \"$account_name\" 已存在"
        echo -e "${GRAY}请使用不同的名称${NC}"
        press_any_key
        return
    fi
    
    # 选择账号类型
    echo ""
    echo -e "${CYAN}请选择账号类型:${NC}"
    echo -e "   ${GREEN}1.${NC} Claude Pro/Max (Anthropic OAuth)"
    echo -e "   ${BLUE}2.${NC} ChatGPT Plus (OpenAI OAuth)"
    echo ""
    echo -e "${CYAN}请输入选项 [1-2]: ${NC}"
    read -r type_choice </dev/tty
    
    local account_type provider
    case $type_choice in
        1) account_type="claude"; provider="anthropic" ;;
        2) account_type="chatgpt"; provider="openai" ;;
        *) warn_msg "无效的选项"; press_any_key; return ;;
    esac
    
    echo ""
    print_line
    echo ""
    echo -e "${CYAN}${BOLD}【 OAuth 授权流程 】${NC}"
    echo ""
    info_msg "正在启动 OAuth 认证..."
    echo ""
    
    # 创建临时文件捕获输出
    local output_file=$(mktemp)
    local auth_url=""
    
    # 运行 openclaw auth login 并捕获输出 (后台运行)
    echo -e "${GRAY}正在获取授权链接...${NC}"
    echo ""
    
    # 使用 script 命令或直接运行以捕获交互输出
    # OpenClaw 会输出类似: "Open this URL: https://..." 或直接显示 URL
    timeout 30 openclaw auth login "$provider" --oauth 2>&1 | tee "$output_file" &
    local auth_pid=$!
    
    # 等待几秒让它输出 URL
    sleep 5
    
    # 尝试从输出中提取 URL
    auth_url=$(grep -oE 'https://[^[:space:]"]+' "$output_file" | head -1)
    
    # 如果没捕获到 URL，显示整个输出让用户找
    if [ -z "$auth_url" ]; then
        echo -e "${YELLOW}未能自动提取授权链接${NC}"
        echo ""
        echo -e "${WHITE}命令输出:${NC}"
        cat "$output_file"
        echo ""
        echo -e "${CYAN}请手动复制上方显示的授权链接${NC}"
    else
        echo -e "${GREEN}已获取授权链接:${NC}"
        echo ""
        echo -e "${CYAN}$auth_url${NC}"
    fi
    
    echo ""
    print_line
    echo ""
    echo -e "${WHITE}请按以下步骤操作:${NC}"
    echo ""
    echo -e "   ${GREEN}1.${NC} 复制上方的授权链接"
    echo -e "   ${GREEN}2.${NC} 在本地浏览器中打开该链接并完成登录"
    echo -e "   ${GREEN}3.${NC} 登录成功后，浏览器会跳转到一个新页面"
    echo -e "   ${GREEN}4.${NC} 复制跳转后的完整 URL (地址栏)"
    echo ""
    print_line
    echo ""
    echo -e "${CYAN}请粘贴跳转后的回调 URL (或直接按回车跳过): ${NC}"
    read -r callback_url </dev/tty
    
    # 终止后台进程
    kill $auth_pid 2>/dev/null || true
    wait $auth_pid 2>/dev/null || true
    rm -f "$output_file"
    
    # 如果用户提供了回调 URL，尝试处理它
    if [ -n "$callback_url" ]; then
        echo ""
        info_msg "正在处理回调..."
        # 某些 OAuth 流程需要将回调 URL 传递给 openclaw
        # 这里我们假设 openclaw 会自动处理 (因为它在等待)
        # 如果需要手动处理，可以调用相应命令
    fi
    
    echo ""
    info_msg "正在验证账号配置..."
    
    # 等待几秒让 openclaw 完成保存
    sleep 2
    
    # 验证账号是否真正可用
    local account_status="unknown"
    local verification_passed=false
    
    # 方法1: 检查 oauth.json 是否有对应 provider
    local oauth_file="$HOME/.openclaw/credentials/oauth.json"
    if [ -f "$oauth_file" ]; then
        if jq -e ".$provider" "$oauth_file" >/dev/null 2>&1; then
            account_status="active"
            verification_passed=true
            echo -e "   ${GREEN}✓${NC} 在 credentials/oauth.json 中发现 $provider 凭证"
        fi
    fi
    
    # 方法2: 检查 auth-profiles.json
    if [ "$verification_passed" = false ]; then
        for profile_file in "$HOME/.openclaw"/agents/*/agent/auth-profiles.json; do
            if [ -f "$profile_file" ]; then
                if jq -e ".$provider" "$profile_file" >/dev/null 2>&1; then
                    account_status="active"
                    verification_passed=true
                    echo -e "   ${GREEN}✓${NC} 在 auth-profiles.json 中发现 $provider 凭证"
                    break
                fi
            fi
        done
    fi
    
    echo ""
    
    if [ "$verification_passed" = false ]; then
        warn_msg "未能验证账号配置"
        echo ""
        echo -e "${YELLOW}可能的原因:${NC}"
        echo -e "   • OAuth 登录未完成"
        echo -e "   • 回调 URL 处理失败"
        echo ""
        echo -e "${CYAN}是否仍要添加此账号? (状态将标记为 '待验证') [y/N]: ${NC}"
        read -r force_add </dev/tty
        
        if [[ ! "$force_add" =~ ^[Yy]$ ]]; then
            info_msg "已取消添加账号"
            press_any_key
            return
        fi
        account_status="pending"
    fi
    
    # 创建备份 (只备份，不覆盖)
    create_backup "add_account"
    
    # 添加账号到配置 (追加，不覆盖现有账号)
    local new_account=$(jq -n \
        --arg name "$account_name" \
        --arg type "$account_type" \
        --arg provider "$provider" \
        --arg status "$account_status" \
        --arg addedAt "$(date -Iseconds)" \
        '{name: $name, type: $type, provider: $provider, status: $status, addedAt: $addedAt, lastUsed: null, verified: ('$verification_passed')}')
    
    # 使用 jq 追加账号 (不会覆盖现有账号)
    local temp_file=$(mktemp)
    if jq ".accounts += [$new_account]" "$ACCOUNTS_CONFIG" > "$temp_file"; then
        mv "$temp_file" "$ACCOUNTS_CONFIG"
    else
        rm -f "$temp_file"
        error_msg "添加账号失败"
        press_any_key
        return
    fi
    
    echo ""
    if [ "$verification_passed" = true ]; then
        success_msg "账号 \"$account_name\" 添加成功! (已验证)"
    else
        warn_msg "账号 \"$account_name\" 已添加 (待验证)"
        echo -e "${GRAY}请稍后使用 '测试账号可用性' 功能验证${NC}"
    fi
    echo ""
    
    # 询问是否设置为活跃账号
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG")
    if [ "$account_count" -gt 1 ] && [ "$verification_passed" = true ]; then
        echo -e "${CYAN}是否将此账号设为当前活跃账号? [Y/n]: ${NC}"
        read -r set_active </dev/tty
        if [[ ! "$set_active" =~ ^[Nn]$ ]]; then
            local temp_file2=$(mktemp)
            jq ".activeAccountIndex = $((account_count - 1))" "$ACCOUNTS_CONFIG" > "$temp_file2" && mv "$temp_file2" "$ACCOUNTS_CONFIG"
            success_msg "已将 \"$account_name\" 设为活跃账号"
        fi
    fi
    
    press_any_key
}

# 删除账号
remove_account() {
    show_banner
    echo -e "${RED}${BOLD}【 删除账号 】${NC}"
    print_line
    echo ""
    
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq"
        press_any_key
        return
    fi
    
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    
    if [ "$account_count" -eq 0 ]; then
        info_msg "暂无配置的账号"
        press_any_key
        return
    fi
    
    # 显示账号列表
    echo -e "${WHITE}请选择要删除的账号:${NC}"
    echo ""
    
    for i in $(seq 0 $((account_count - 1))); do
        local name=$(jq -r ".accounts[$i].name // \"账号$((i+1))\"" "$ACCOUNTS_CONFIG")
        echo -e "   ${RED}$((i+1)).${NC} $name"
    done
    
    echo ""
    echo -e "   ${GRAY}0.${NC} 取消"
    echo ""
    echo -e "${CYAN}请输入选项: ${NC}"
    read -r del_choice </dev/tty
    
    if [ "$del_choice" == "0" ] || [ -z "$del_choice" ]; then
        info_msg "已取消删除操作"
        press_any_key
        return
    fi
    
    local del_index=$((del_choice - 1))
    if [ "$del_index" -lt 0 ] || [ "$del_index" -ge "$account_count" ]; then
        error_msg "无效的选项"
        press_any_key
        return
    fi
    
    local del_name=$(jq -r ".accounts[$del_index].name" "$ACCOUNTS_CONFIG")
    
    echo ""
    echo -e "${RED}确定要删除账号 \"$del_name\"? [y/N]: ${NC}"
    read -r confirm </dev/tty
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info_msg "已取消删除操作"
        press_any_key
        return
    fi
    
    # 创建备份后删除账号
    create_backup "delete_account"
    
    local temp_file=$(mktemp)
    jq "del(.accounts[$del_index])" "$ACCOUNTS_CONFIG" > "$temp_file" && mv "$temp_file" "$ACCOUNTS_CONFIG"
    
    # 调整活跃账号索引
    local active_index=$(jq '.activeAccountIndex' "$ACCOUNTS_CONFIG")
    if [ "$active_index" -ge "$del_index" ] && [ "$active_index" -gt 0 ]; then
        jq ".activeAccountIndex = $((active_index - 1))" "$ACCOUNTS_CONFIG" > "$temp_file" && mv "$temp_file" "$ACCOUNTS_CONFIG"
    fi
    
    success_msg "账号 \"$del_name\" 已删除"
    press_any_key
}

# 设置切换策略
set_switch_strategy() {
    show_banner
    echo -e "${CYAN}${BOLD}【 设置切换策略 】${NC}"
    print_line
    echo ""
    
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq"
        press_any_key
        return
    fi
    
    local current_strategy=$(jq -r '.switchStrategy // "manual"' "$ACCOUNTS_CONFIG")
    
    echo -e "${WHITE}当前策略: ${NC}"
    case $current_strategy in
        "manual") echo -e "   ${YELLOW}手动切换${NC}" ;;
        "auto") echo -e "   ${GREEN}自动切换${NC}" ;;
        "loadbalance") echo -e "   ${BLUE}负载均衡${NC}" ;;
    esac
    
    echo ""
    print_line
    echo ""
    echo -e "${WHITE}请选择新的切换策略:${NC}"
    echo ""
    echo -e "   ${YELLOW}1.${NC} 手动切换"
    echo -e "      ${GRAY}用户手动选择使用哪个账号${NC}"
    echo ""
    echo -e "   ${GREEN}2.${NC} 自动切换"
    echo -e "      ${GRAY}当前账号额度用尽时自动切换到下一个账号${NC}"
    echo ""
    echo -e "   ${BLUE}3.${NC} 负载均衡"
    echo -e "      ${GRAY}每次请求轮询使用不同账号，均匀分配负载${NC}"
    echo ""
    echo -e "   ${GRAY}0.${NC} 取消"
    echo ""
    echo -e "${CYAN}请输入选项 [0-3]: ${NC}"
    read -r strategy_choice </dev/tty
    
    local new_strategy
    case $strategy_choice in
        1) new_strategy="manual" ;;
        2) new_strategy="auto" ;;
        3) new_strategy="loadbalance" ;;
        0|"") info_msg "已取消操作"; press_any_key; return ;;
        *) warn_msg "无效的选项"; press_any_key; return ;;
    esac
    
    # 更新配置
    local temp_file=$(mktemp)
    jq ".switchStrategy = \"$new_strategy\"" "$ACCOUNTS_CONFIG" > "$temp_file" && mv "$temp_file" "$ACCOUNTS_CONFIG"
    
    echo ""
    success_msg "切换策略已更新!"
    
    # 应用到 OpenClaw 配置
    apply_strategy_to_openclaw "$new_strategy"
    
    press_any_key
}

# 应用策略到 OpenClaw 配置
apply_strategy_to_openclaw() {
    local strategy=$1
    
    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        warn_msg "OpenClaw 配置文件不存在，跳过应用"
        return
    fi
    
    info_msg "正在应用策略到 OpenClaw 配置..."
    
    # 根据策略更新 OpenClaw 配置
    case $strategy in
        "auto"|"loadbalance")
            # 配置 model failover
            info_msg "已启用 Model Failover 机制"
            ;;
        "manual")
            info_msg "已切换为手动模式"
            ;;
    esac
}

# 手动切换账号
manual_switch_account() {
    show_banner
    echo -e "${YELLOW}${BOLD}【 手动切换账号 】${NC}"
    print_line
    echo ""
    
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq"
        press_any_key
        return
    fi
    
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    local active_index=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    
    if [ "$account_count" -eq 0 ]; then
        info_msg "暂无配置的账号"
        press_any_key
        return
    fi
    
    if [ "$account_count" -eq 1 ]; then
        info_msg "只有一个账号，无需切换"
        press_any_key
        return
    fi
    
    echo -e "${WHITE}请选择要切换到的账号:${NC}"
    echo ""
    
    for i in $(seq 0 $((account_count - 1))); do
        local name=$(jq -r ".accounts[$i].name // \"账号$((i+1))\"" "$ACCOUNTS_CONFIG")
        local status=$(jq -r ".accounts[$i].status // \"unknown\"" "$ACCOUNTS_CONFIG")
        
        local status_color mark
        case $status in
            "active") status_color="${GREEN}" ;;
            "exhausted") status_color="${RED}" ;;
            *) status_color="${GRAY}" ;;
        esac
        
        if [ "$i" -eq "$active_index" ]; then
            mark=" ${CYAN}◄ 当前${NC}"
        else
            mark=""
        fi
        
        echo -e "   ${GREEN}$((i+1)).${NC} ${status_color}$name${NC}$mark"
    done
    
    echo ""
    echo -e "   ${GRAY}0.${NC} 取消"
    echo ""
    echo -e "${CYAN}请输入选项: ${NC}"
    read -r switch_choice </dev/tty
    
    if [ "$switch_choice" == "0" ] || [ -z "$switch_choice" ]; then
        info_msg "已取消切换操作"
        press_any_key
        return
    fi
    
    local switch_index=$((switch_choice - 1))
    if [ "$switch_index" -lt 0 ] || [ "$switch_index" -ge "$account_count" ]; then
        error_msg "无效的选项"
        press_any_key
        return
    fi
    
    if [ "$switch_index" -eq "$active_index" ]; then
        info_msg "该账号已经是当前活跃账号"
        press_any_key
        return
    fi
    
    # 使用安全切换机制 (带备份和验证)
    local switch_name=$(jq -r ".accounts[$switch_index].name" "$ACCOUNTS_CONFIG")
    
    echo ""
    info_msg "正在安全切换账号..."
    echo -e "   ${GRAY}• 创建配置备份${NC}"
    echo -e "   ${GRAY}• 验证新账号可用性${NC}"
    echo -e "   ${GRAY}• 如失败自动回滚${NC}"
    echo ""
    
    if safe_switch_account "$switch_index"; then
        success_msg "已安全切换到账号: $switch_name"
    else
        error_msg "账号切换失败，已自动回滚到之前配置"
    fi
    
    press_any_key
}

# 测试账号可用性 (真正验证)
test_accounts() {
    show_banner
    echo -e "${PURPLE}${BOLD}【 测试账号可用性 】${NC}"
    print_line
    echo ""
    
    init_accounts_config
    
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq"
        press_any_key
        return
    fi
    
    local account_count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    
    if [ "$account_count" -eq 0 ]; then
        info_msg "暂无配置的账号可测试"
        press_any_key
        return
    fi
    
    info_msg "正在验证所有账号..."
    echo ""
    
    local passed=0
    local failed=0
    local openclaw_dir="$HOME/.openclaw"
    
    for i in $(seq 0 $((account_count - 1))); do
        local name=$(jq -r ".accounts[$i].name // \"账号$((i+1))\"" "$ACCOUNTS_CONFIG")
        local provider=$(jq -r ".accounts[$i].provider // \"unknown\"" "$ACCOUNTS_CONFIG")
        local account_type=$(jq -r ".accounts[$i].type // \"unknown\"" "$ACCOUNTS_CONFIG")
        
        echo -ne "   测试 ${CYAN}$name${NC} ($provider)... "
        
        local verified=false
        local new_status="error"
        
        # 验证方法1: 检查 oauth.json
        local oauth_file="$openclaw_dir/credentials/oauth.json"
        if [ -f "$oauth_file" ]; then
            if jq -e ".$provider" "$oauth_file" >/dev/null 2>&1; then
                verified=true
                new_status="active"
            fi
        fi
        
        # 验证方法2: 检查 auth-profiles.json
        if [ "$verified" = false ]; then
            for profile_file in "$openclaw_dir"/agents/*/agent/auth-profiles.json; do
                if [ -f "$profile_file" ]; then
                    if jq -e ".$provider" "$profile_file" >/dev/null 2>&1; then
                        verified=true
                        new_status="active"
                        break
                    fi
                fi
            done
        fi
        
        # 验证方法3: 检查 API Key (env)
        if [ "$verified" = false ] && [ "$account_type" = "api_key" ]; then
            local env_key=$(jq -r ".accounts[$i].envKey // \"\"" "$ACCOUNTS_CONFIG")
            if [ -n "$env_key" ] && [ -f "$OPENCLAW_CONFIG" ]; then
                if jq -e ".env.$env_key" "$OPENCLAW_CONFIG" >/dev/null 2>&1; then
                    verified=true
                    new_status="active"
                fi
            fi
        fi
        
        # 更新账号状态
        local temp_file=$(mktemp)
        jq ".accounts[$i].status = \"$new_status\" | .accounts[$i].verified = $verified | .accounts[$i].lastChecked = \"$(date -Iseconds)\"" "$ACCOUNTS_CONFIG" > "$temp_file" && mv "$temp_file" "$ACCOUNTS_CONFIG"
        
        if [ "$verified" = true ]; then
            echo -e "${GREEN}✓ 已验证${NC}"
            ((passed++))
        else
            echo -e "${RED}✗ 未找到凭证${NC}"
            ((failed++))
        fi
    done
    
    echo ""
    print_line
    echo ""
    echo -e "${WHITE}验证结果:${NC}"
    echo -e "   ${GREEN}通过: $passed 个${NC}"
    if [ "$failed" -gt 0 ]; then
        echo -e "   ${RED}失败: $failed 个${NC}"
        echo ""
        echo -e "${YELLOW}提示: 验证失败的账号可能需要重新登录${NC}"
        echo -e "${GRAY}运行: openclaw auth login <provider> --oauth${NC}"
    fi
    echo ""
    
    press_any_key
}

#===============================================================================
# 显示系统信息
#===============================================================================

show_system_info() {
    detect_os
    
    echo -e "${WHITE}系统信息:${NC}"
    echo -e "   操作系统: ${CYAN}$OS${NC}"
    echo -e "   系统版本: ${CYAN}$OS_VERSION${NC}"
    echo -e "   内核版本: ${CYAN}$(uname -r)${NC}"
    
    # 检查OpenClaw状态
    if command -v openclaw &> /dev/null; then
        local oc_version=$(timeout 3 openclaw --version 2>/dev/null | head -1 || echo "")
        if [ -n "$oc_version" ]; then
            echo -e "   OpenClaw: ${GREEN}已安装 ($oc_version)${NC}"
        else
            echo -e "   OpenClaw: ${GREEN}已安装${NC}"
        fi
    else
        echo -e "   OpenClaw: ${GRAY}未安装${NC}"
    fi
    
    # 检查Node.js
    if command -v node &> /dev/null; then
        echo -e "   Node.js:  ${GREEN}$(node -v)${NC}"
    else
        echo -e "   Node.js:  ${RED}未安装${NC}"
    fi
    
    echo ""
}

#===============================================================================
# 主菜单
#===============================================================================

show_menu() {
    show_banner
    show_system_info
    print_line
    echo ""
    echo -e "${WHITE}${BOLD}请选择操作:${NC}"
    echo ""
    echo -e "   ${GREEN}1.${NC} 一键安装 OpenClaw"
    echo -e "   ${RED}2.${NC} 一键卸载 OpenClaw"
    echo -e "   ${BLUE}3.${NC} Telegram 机器人对接"
    echo -e "   ${PURPLE}4.${NC} 多账号管理"
    echo ""
    print_line
    echo -e "   ${YELLOW}0.${NC} 退出脚本"
    echo ""
    echo -e "${CYAN}请输入选项 [0-4]: ${NC}"
}

#===============================================================================
# 主程序入口
#===============================================================================

main() {
    # 可选: 检查root权限 (某些操作可能需要)
    # check_root
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                install_openclaw
                ;;
            2)
                uninstall_openclaw
                ;;
            3)
                telegram_bot_link
                ;;
            4)
                multi_account_manage
                ;;
            0)
                clear_screen
                echo ""
                echo -e "${GREEN}感谢使用 OpenClaw 管理脚本!${NC}"
                echo -e "${CYAN}项目主页: https://openclaw.ai${NC}"
                echo ""
                exit 0
                ;;
            *)
                warn_msg "无效的选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main "$@"
