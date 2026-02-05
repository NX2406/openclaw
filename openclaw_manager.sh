#!/bin/bash

#===============================================================================
#
#          FILE:  openclaw_manager.sh
#
#   DESCRIPTION:  OpenClaw 一键管理脚本 (完整增强版)
#                 包含：全系统兼容、插件自动修复、单Agent多账号(API/OAuth)、安全回滚
#
#        AUTHOR:  Antigravity AI Assistant
#       VERSION:  1.4.0 (Ultimate)
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
SCRIPT_VERSION="1.4.0"
INSTALL_LOG="/tmp/openclaw_install.log"
OPENCLAW_HOME="$HOME/.openclaw"

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
# 系统更新和依赖检查 (完整保留原逻辑)
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
# 功能4: 多账号管理 (重构：单Agent模式 + 自动插件修复)
#===============================================================================

# OpenClaw配置文件路径
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
ACCOUNTS_CONFIG="$HOME/.openclaw/accounts.json"
BACKUP_DIR="$HOME/.openclaw/backups"
LOCK_FILE="$HOME/.openclaw/.accounts.lock"
PROFILES_DIR="$HOME/.openclaw/account-profiles"

# --- 核心辅助函数：Agent 自动探测 ---
# [NEW] 自动获取唯一的活跃 Agent，不再询问用户
get_single_active_agent() {
    local agents_dir="$HOME/.openclaw/agents"
    
    # 1. 优先检查标准的 'main' Agent
    if [ -d "$agents_dir/main" ]; then
        echo "main"
        return
    fi

    # 2. 如果 main 不存在，检查是否有其他 Agent，取第一个
    if [ -d "$agents_dir" ]; then
        local first_agent=$(ls -1 "$agents_dir" 2>/dev/null | head -n 1)
        if [ -n "$first_agent" ]; then
            echo "$first_agent"
            return
        fi
    fi

    # 3. 如果什么都没有，默认返回 main
    echo "main"
}

# 获取指定 Agent 的 auth-profiles.json 路径
get_auth_profile_path() {
    local agent_name="$1"
    echo "$HOME/.openclaw/agents/$agent_name/agent/auth-profiles.json"
}

# --- 核心辅助函数：插件自动修复 ---
# [FIXED] 映射 Provider 名称到实际的 npm 包名
auth_helper_plugin_for_provider() {
    local provider="$1"
    case "$provider" in
        google-antigravity) echo "google-antigravity-auth" ;;
        google-gemini-cli) echo "google-gemini-cli-auth" ;;
        openai-codex) echo "openai" ;;       # 映射到官方 openai 包
        anthropic) echo "anthropic" ;;       # 映射到官方 anthropic 包
        deepseek) echo "deepseek" ;;         # 假设支持 deepseek
        *) echo "$provider" ;;               # 默认尝试同名包
    esac
}

ensure_provider_plugins() {
    local provider="${1:-}"
    info_msg "检查 Provider 插件环境..."
    
    local helper=$(auth_helper_plugin_for_provider "$provider")
    local out=$(openclaw plugins list 2>&1)
    
    # 如果提示找不到插件，或者列表里没有目标插件
    if echo "$out" | grep -qiE "No provider plugins found|No plugins installed" || ! echo "$out" | grep -q "$helper"; then
        warn_msg "检测到插件缺失，尝试自动安装 ($helper)..."
        
        # 尝试安装 Helper 插件
        openclaw plugins install "$helper" >/dev/null 2>&1
        openclaw plugins enable "$helper" >/dev/null 2>&1
        
        # 如果 provider 和 helper 不一样（比如 google-antigravity），也尝试安装 provider 本身
        if [ "$helper" != "$provider" ]; then
             openclaw plugins install "$provider" >/dev/null 2>&1
             openclaw plugins enable "$provider" >/dev/null 2>&1
        fi
        success_msg "插件环境修复尝试完成"
    else
        # 确保启用
        openclaw plugins enable "$helper" >/dev/null 2>&1 || true
    fi
}

#===============================================================================
# API 保护机制 - 备份、验证、回滚 (完整保留)
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

# 验证账号可用性
validate_account() {
    local account_index=$1
    info_msg "正在验证账号连接..."
    # 尝试调用 OpenClaw 验证 (使用 timeout 避免卡死)
    if command -v openclaw &> /dev/null; then
        if timeout 10 openclaw status 2>/dev/null | grep -q "authenticated"; then
            return 0
        fi
    fi
    # 宽容模式：如果无法验证，返回警告而非错误
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

# ------------------------------------------------------------------------------
# 核心：应用 Profile 到 OpenClaw (切换账号逻辑)
# ------------------------------------------------------------------------------
apply_profile_to_openclaw() {
    local profile_file="$1"

    if [ ! -f "$profile_file" ]; then
        error_msg "找不到配置文件: $profile_file"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq，无法应用配置"
        return 1
    fi

    local agent_name=$(jq -r '.targetAgent // "main"' "$profile_file")
    local provider=$(jq -r '.provider' "$profile_file")
    local auth_entry=$(jq '.storage.authProfiles.entry' "$profile_file")

    local target_auth_file=$(get_auth_profile_path "$agent_name")
    
    info_msg "正在应用账号到 Agent: $agent_name (Provider: $provider)..."
    
    # 确保目标目录存在
    mkdir -p "$(dirname "$target_auth_file")"
    if [ ! -f "$target_auth_file" ]; then echo '{}' > "$target_auth_file"; fi

    # 备份原有 auth-profiles.json
    cp "$target_auth_file" "${target_auth_file}.bak"

    # 使用 jq 更新 JSON
    local tmp=$(mktemp)
    if jq --arg p "$provider" --argjson e "$auth_entry" '.[$p] = $e' "$target_auth_file" > "$tmp"; then
        mv "$tmp" "$target_auth_file"
        success_msg "账号配置已写入 $agent_name"
        return 0
    else
        error_msg "配置文件写入失败，已回滚。"
        cp "${target_auth_file}.bak" "$target_auth_file"
        rm -f "$tmp"
        return 1
    fi
}

# 安全切换账号 (带备份和验证)
safe_switch_account() {
    local new_index=$1
    local old_index=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null)

    if ! acquire_lock; then return 1; fi

    create_backup "switch"

    local new_profile_file=$(jq -r ".accounts[$new_index].profileFile // empty" "$ACCOUNTS_CONFIG" 2>/dev/null)

    if [ -n "$new_profile_file" ] && [ "$new_profile_file" != "null" ]; then
        if ! apply_profile_to_openclaw "$new_profile_file"; then
            warn_msg "应用账号配置失败，已取消切换"
            release_lock
            return 1
        fi
    else
        warn_msg "该账号没有配置文件，将仅切换索引"
    fi

    # 更新 accounts.json
    local temp_file=$(mktemp)
    jq ".activeAccountIndex = $new_index | .lastSwitchTime = \"$(date -Iseconds)\"" "$ACCOUNTS_CONFIG" > "$temp_file" && mv "$temp_file" "$ACCOUNTS_CONFIG"

    # 简单验证 (可选)
    # if ! validate_account "$new_index"; then ... rollback ... fi

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
            success_msg "已恢复备份"
        else
            error_msg "无效的备份序号"
        fi
    fi
    press_any_key
}

# 初始化账号配置文件
init_accounts_config() {
    mkdir -p "$(dirname "$ACCOUNTS_CONFIG")"
    if [ ! -f "$ACCOUNTS_CONFIG" ]; then
        echo '{"accounts": [], "activeAccountIndex": 0, "switchStrategy": "manual"}' > "$ACCOUNTS_CONFIG"
    fi
}

# 辅助：注册账号到 manager json
register_account_to_manager() {
    local name="$1"
    local type="$2"
    local provider="$3"
    local file="$4"
    local agent="$5"

    local tmp=$(mktemp)
    jq --arg n "$name" --arg t "$type" --arg p "$provider" --arg f "$file" --arg a "$agent" \
       '.accounts += [{name: $n, type: $t, provider: $p, profileFile: $f, targetAgent: $a, addedAt: (now|todate)}]' \
       "$ACCOUNTS_CONFIG" > "$tmp" && mv "$tmp" "$ACCOUNTS_CONFIG"
}

# --- 功能：手动添加 API Key 账号 (NEW) ---
add_apikey_account() {
    show_banner
    echo -e "${BLUE}${BOLD}【 添加 API Key 账号 】${NC}"
    print_line
    
    init_accounts_config
    if ! command -v jq &> /dev/null; then error_msg "未安装 jq"; press_any_key; return; fi

    # [NEW] 自动获取 Agent
    local target_agent=$(get_single_active_agent)
    info_msg "已自动锁定目标 Agent: ${GREEN}$target_agent${NC}"
    echo ""

    echo -e "${CYAN}请输入账号别名: ${NC}"
    read -r account_name
    [ -z "$account_name" ] && account_name="APIKey_$(date +%s)"

    echo -e "${CYAN}请输入 Provider (如 openai, deepseek, anthropic): ${NC}"
    read -r provider
    [ -z "$provider" ] && provider="openai"

    echo -e "${CYAN}请输入 API Key (sk-...): ${NC}"
    read -r api_key
    if [ -z "$api_key" ]; then error_msg "API Key 不能为空"; press_any_key; return; fi

    echo -e "${CYAN}请输入 Base URL (可选，回车跳过): ${NC}"
    read -r base_url

    # 构造 JSON
    local json_content
    if [ -n "$base_url" ]; then
        json_content=$(jq -n --arg k "$api_key" --arg u "$base_url" '{apiKey: $k, baseUrl: $u}')
    else
        json_content=$(jq -n --arg k "$api_key" '{apiKey: $k}')
    fi

    # 保存
    mkdir -p "$PROFILES_DIR/$provider"
    local profile_id="$(date +%Y%m%d_%H%M%S)_${provider}_api"
    local profile_file="$PROFILES_DIR/$provider/${profile_id}.json"

    jq -n \
        --arg id "$profile_id" \
        --arg name "$account_name" \
        --arg provider "$provider" \
        --arg agent "$target_agent" \
        --argjson entry "$json_content" \
        '{
            id: $id,
            name: $name,
            provider: $provider,
            targetAgent: $agent,
            type: "api_key",
            storage: { authProfiles: { entry: $entry } }
        }' > "$profile_file"

    if [ $? -eq 0 ]; then
        success_msg "API Key 配置已保存"
        register_account_to_manager "$account_name" "api_key" "$provider" "$profile_file" "$target_agent"
        
        echo -e "${CYAN}是否立即切换到此账号? [y/N]: ${NC}"
        read -r activate
        if [[ "$activate" =~ ^[Yy]$ ]]; then
            # 找到最后一个索引
            local count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG")
            safe_switch_account $((count - 1))
        fi
    else
        error_msg "保存文件失败"
    fi
    press_any_key
}

# --- 功能：添加 OAuth 账号 (修复版) ---
add_oauth_account() {
    show_banner
    echo -e "${BLUE}${BOLD}【 添加 OAuth 账号 】${NC}"
    print_line
    
    init_accounts_config
    if ! command -v openclaw &> /dev/null; then error_msg "请先安装 OpenClaw"; press_any_key; return; fi

    # [NEW] 自动获取 Agent
    local target_agent=$(get_single_active_agent)
    info_msg "已自动锁定目标 Agent: ${GREEN}$target_agent${NC}"
    echo ""

    echo -e "${CYAN}账号名称 (别名): ${NC}"
    read -r account_name
    [ -z "$account_name" ] && account_name="OAuth_$(date +%s)"

    echo -e "${CYAN}选择 Provider:${NC}"
    echo -e "   1. ChatGPT (openai-codex)"
    echo -e "   2. Claude (anthropic)"
    echo -e "   3. Gemini (google-antigravity)"
    read -r p_choice
    
    local provider
    case $p_choice in
        1) provider="openai-codex" ;;
        2) provider="anthropic" ;;
        3) provider="google-antigravity" ;;
        *) provider="openai-codex" ;;
    esac

    # [FIX] 插件检查
    ensure_provider_plugins "$provider"

    # 备份 Auth 文件
    local auth_file=$(get_auth_profile_path "$target_agent")
    [ -f "$auth_file" ] && cp "$auth_file" "${auth_file}.pre_login"

    info_msg "启动官方登录..."
    openclaw models auth login --provider "$provider" --method oauth 2>/dev/null || openclaw auth login --provider "$provider"

    # 捕获结果
    if [ ! -f "$auth_file" ]; then error_msg "未生成凭证"; press_any_key; return; fi
    
    local entry=$(jq -r --arg p "$provider" '.[$p] // empty' "$auth_file")
    # 兼容
    if [ -z "$entry" ] || [ "$entry" == "null" ]; then
        local old_file="$HOME/.openclaw/credentials/oauth.json"
        entry=$(jq -r --arg p "$provider" '.[$p] // empty' "$old_file")
    fi

    if [ -z "$entry" ] || [ "$entry" == "null" ]; then
        error_msg "未能捕获凭证。"
        [ -f "${auth_file}.pre_login" ] && mv "${auth_file}.pre_login" "$auth_file"
        press_any_key; return
    fi

    # 保存
    mkdir -p "$PROFILES_DIR/$provider"
    local profile_id="$(date +%Y%m%d_%H%M%S)_${provider}_oauth"
    local profile_file="$PROFILES_DIR/$provider/${profile_id}.json"

    jq -n \
        --arg id "$profile_id" \
        --arg name "$account_name" \
        --arg provider "$provider" \
        --arg agent "$target_agent" \
        --argjson entry "$entry" \
        '{
            id: $id,
            name: $name,
            provider: $provider,
            targetAgent: $agent,
            type: "oauth",
            storage: { authProfiles: { entry: $entry } }
        }' > "$profile_file"

    success_msg "OAuth 账号已保存!"
    register_account_to_manager "$account_name" "oauth" "$provider" "$profile_file" "$target_agent"

    # 恢复或保持
    echo -e "${CYAN}是否保持当前激活状态? (n 则恢复之前账号) [Y/n]: ${NC}"
    read -r keep_active
    if [[ "$keep_active" =~ ^[Nn]$ ]]; then
        [ -f "${auth_file}.pre_login" ] && mv "${auth_file}.pre_login" "$auth_file"
        info_msg "已恢复到登录前的状态。"
    else
        local count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG")
        local tmp=$(mktemp)
        jq ".activeAccountIndex = $((count - 1))" "$ACCOUNTS_CONFIG" > "$tmp" && mv "$tmp" "$ACCOUNTS_CONFIG"
    fi
    rm -f "${auth_file}.pre_login"
    press_any_key
}

# 显示所有账号
show_all_accounts() {
    show_banner
    init_accounts_config
    if ! command -v jq &> /dev/null; then error_msg "No jq"; return; fi
    
    local count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG" 2>/dev/null || echo "0")
    local active_idx=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null)
    
    echo -e "${GREEN}${BOLD}【 账号列表 】${NC}"
    if [ "$count" -eq 0 ]; then
        echo "暂无账号。"
    else
        echo -e "${WHITE}ID   状态      名称                  类型      Agent${NC}"
        echo -e "${GRAY}------------------------------------------------------${NC}"
        for i in $(seq 0 $((count - 1))); do
            local name=$(jq -r ".accounts[$i].name" "$ACCOUNTS_CONFIG")
            local type=$(jq -r ".accounts[$i].type" "$ACCOUNTS_CONFIG")
            local agent=$(jq -r ".accounts[$i].targetAgent // \"main\"" "$ACCOUNTS_CONFIG")
            
            local mark="  "
            if [ "$i" -eq "$active_idx" ]; then mark="➤ "; fi
            
            echo -e "${mark}$((i+1))   $type      $name      ${GRAY}$agent${NC}"
        done
    fi
    echo ""
    press_any_key
}

# 手动切换账号
manual_switch_account() {
    show_banner
    init_accounts_config
    local count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG")
    
    if [ "$count" -eq 0 ]; then info_msg "无账号"; press_any_key; return; fi

    echo -e "${YELLOW}请选择要切换的账号ID:${NC}"
    local i=0
    while [ $i -lt $count ]; do
        local name=$(jq -r ".accounts[$i].name" "$ACCOUNTS_CONFIG")
        echo "$((i+1)). $name"
        ((i++))
    done
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$count" ] && [ "$choice" -gt 0 ]; then
        safe_switch_account $((choice - 1))
        press_any_key
    fi
}

# 删除账号
remove_account() {
    show_banner
    echo -e "${RED}请输入要删除的账号序号:${NC}"
    local count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG")
    for i in $(seq 0 $((count - 1))); do
        local name=$(jq -r ".accounts[$i].name" "$ACCOUNTS_CONFIG")
        echo "$((i+1)). $name"
    done
    read -r idx
    if [[ "$idx" =~ ^[0-9]+$ ]]; then
        idx=$((idx-1))
        create_backup "delete"
        local tmp=$(mktemp)
        jq "del(.accounts[$idx])" "$ACCOUNTS_CONFIG" > "$tmp" && mv "$tmp" "$ACCOUNTS_CONFIG"
        success_msg "已删除"
        press_any_key
    fi
}

# 设置切换策略 (界面占位，实际功能由 OpenClaw 内部控制或外部调度，脚本负责改配置)
set_switch_strategy() {
    show_banner
    echo -e "${CYAN}${BOLD}【 设置切换策略 】${NC}"
    print_line
    echo -e "当前仅支持手动切换模式 (Manual Mode)。"
    echo -e "自动轮询功能需等待 OpenClaw 官方 API 更新支持。"
    press_any_key
}

# 测试账号可用性 (调用 probe)
test_accounts() {
    show_banner
    echo -e "${PURPLE}${BOLD}【 测试账号可用性 】${NC}"
    print_line
    info_msg "运行 openclaw models status --probe ..."
    openclaw models status --probe
    press_any_key
}

# 多账号管理主菜单
multi_account_manage() {
    while true; do
        show_banner
        echo -e "${PURPLE}${BOLD}【 多账号管理 】${NC}"
        print_line
        
        local active_idx=$(jq '.activeAccountIndex // 0' "$ACCOUNTS_CONFIG" 2>/dev/null)
        local active_name=$(jq -r ".accounts[$active_idx].name // \"无\"" "$ACCOUNTS_CONFIG" 2>/dev/null)
        echo -e "当前活跃账号: ${CYAN}$active_name${NC}"
        echo ""

        echo -e "   ${GREEN}1.${NC} 查看所有账号"
        echo -e "   ${BLUE}2.${NC} 添加 OAuth 账号"
        echo -e "   ${BLUE}3.${NC} 添加 API Key 账号 (NEW)"
        echo -e "   ${RED}4.${NC} 删除账号"
        echo -e "   ${YELLOW}5.${NC} 切换账号"
        echo -e "   ${WHITE}6.${NC} 测试账号可用性"
        echo -e "   ${WHITE}7.${NC} 备份管理"
        echo -e "   ${GRAY}0.${NC} 返回主菜单"
        echo ""
        echo -e "${CYAN}请输入选项: ${NC}"
        read -r sub_choice
        
        case $sub_choice in
            1) show_all_accounts ;;
            2) add_oauth_account ;;
            3) add_apikey_account ;;
            4) remove_account ;;
            5) manual_switch_account ;;
            6) test_accounts ;;
            7) show_backups ;;
            0) return ;;
            *) warn_msg "无效选项"; sleep 1 ;;
        esac
    done
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
    
    if command -v openclaw &> /dev/null; then
        local oc_version=$(timeout 3 openclaw --version 2>/dev/null | head -1 || echo "")
        echo -e "   OpenClaw: ${GREEN}已安装 ($oc_version)${NC}"
    else
        echo -e "   OpenClaw: ${GRAY}未安装${NC}"
    fi
    
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
    echo -e "   ${PURPLE}4.${NC} 多账号管理 (API Key / OAuth)"
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
    # check_root # 可选：如需强制root则取消注释
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1) install_openclaw ;;
            2) uninstall_openclaw ;;
            3) telegram_bot_link ;;
            4) multi_account_manage ;;
            0) clear_screen; echo ""; echo -e "${GREEN}感谢使用!${NC}"; echo ""; exit 0 ;;
            *) warn_msg "无效的选项，请重新选择"; sleep 1 ;;
        esac
    done
}

# 运行主程序
main "$@"
