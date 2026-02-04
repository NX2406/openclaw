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
        ubuntu|debian)
            # 设置非交互模式，自动保留旧配置文件
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y
            apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        arch|manjaro)
            pacman -Syu --noconfirm
            ;;
        alpine)
            apk update
            apk upgrade
            ;;
        *)
            warn_msg "未知的操作系统，跳过系统更新"
            return 1
            ;;
    esac
    
    echo ""
    success_msg "系统更新完成"
}

# 安装基础依赖
install_dependencies() {
    info_msg "正在检查和安装依赖 (curl, wget, git)..."
    echo ""
    
    local packages="curl wget git"
    
    case $OS_ID in
        ubuntu|debian)
            apt-get install -y $packages
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf install -y $packages
            else
                yum install -y $packages
            fi
            ;;
        arch|manjaro)
            pacman -S --noconfirm $packages
            ;;
        alpine)
            apk add $packages
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
    
    case $OS_ID in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> "$INSTALL_LOG" 2>&1
            apt-get install -y nodejs >> "$INSTALL_LOG" 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >> "$INSTALL_LOG" 2>&1
            if command -v dnf &> /dev/null; then
                dnf install -y nodejs >> "$INSTALL_LOG" 2>&1
            else
                yum install -y nodejs >> "$INSTALL_LOG" 2>&1
            fi
            ;;
        arch|manjaro)
            pacman -S --noconfirm nodejs npm >> "$INSTALL_LOG" 2>&1
            ;;
        alpine)
            apk add nodejs npm >> "$INSTALL_LOG" 2>&1
            ;;
        *)
            error_msg "无法自动安装 Node.js，请手动安装"
            return 1
            ;;
    esac
    
    success_msg "Node.js 安装完成"
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
    
    # 自动更新系统（无需确认）
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[1/4] 更新系统${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    update_system
    echo ""
    
    # 安装依赖
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[2/4] 安装必要依赖${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    install_dependencies
    echo ""
    
    # 检查Node.js
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[3/4] 检查 Node.js${NC}"
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
    
    # 运行官方安装脚本
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[4/4] 安装 OpenClaw${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info_msg "正在运行 OpenClaw 官方安装脚本..."
    echo ""
    
    # 下载脚本到临时文件然后执行，避免管道占用stdin
    local tmp_script="/tmp/openclaw_install_$$.sh"
    curl -fsSL https://openclaw.ai/install.sh -o "$tmp_script"
    chmod +x "$tmp_script"
    bash "$tmp_script"
    local install_status=$?
    rm -f "$tmp_script"
    
    echo ""
    echo ""
    print_line
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo "  ║              ✓ OpenClaw 安装完成!                        ║"
    echo "  ║                                                          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [ $install_status -eq 0 ]; then
        echo ""
        info_msg "您可以通过以下命令启动 OpenClaw:"
        echo -e "    ${CYAN}openclaw${NC}"
        echo ""
        info_msg "或使用以下命令查看帮助:"
        echo -e "    ${CYAN}openclaw --help${NC}"
    else
        error_msg "安装过程中可能出现问题，请检查上方日志"
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
        press_any_key
        return 1
    fi
    
    success_msg "检测到 OpenClaw 已安装"
    echo ""
    
    # 显示说明
    info_msg "Telegram 机器人对接说明:"
    echo -e "   ${WHITE}1. 在 Telegram 中找到 OpenClaw 官方机器人${NC}"
    echo -e "   ${WHITE}2. 获取您的对接码 (通常为一串字符)${NC}"
    echo -e "   ${WHITE}3. 在下方输入对接码完成绑定${NC}"
    echo ""
    print_line
    echo ""
    
    # 输入对接码
    echo -e "${CYAN}请输入您的 Telegram 对接码 (输入 q 返回): ${NC}"
    read -r link_code
    
    if [ "$link_code" == "q" ] || [ -z "$link_code" ]; then
        info_msg "已取消对接操作"
        press_any_key
        return 0
    fi
    
    echo ""
    info_msg "正在进行 Telegram 机器人对接..."
    echo ""
    
    # 执行对接命令
    # OpenClaw 的 Telegram 对接命令
    openclaw telegram link "$link_code"
    
    local link_status=$?
    echo ""
    print_line
    
    if [ $link_status -eq 0 ]; then
        success_msg "Telegram 机器人对接成功!"
        echo ""
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
        local oc_version=$(openclaw --version 2>/dev/null || echo "未知")
        echo -e "   OpenClaw: ${GREEN}已安装 ($oc_version)${NC}"
    else
        echo -e "   OpenClaw: ${RED}未安装${NC}"
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
    echo ""
    print_line
    echo -e "   ${YELLOW}0.${NC} 退出脚本"
    echo ""
    echo -e "${CYAN}请输入选项 [0-3]: ${NC}"
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
