#!/bin/bash

#===============================================================================
#
#          FILE:  openclaw_manager.sh
#
#   DESCRIPTION:  OpenClaw 一键管理脚本 (修复版 v1.5.0)
#                 修复：插件匹配问题、Agent显示乱码、JQ文件读取错误
#                 特性：单Agent自动锁定、多账号切换、完整系统支持
#
#        AUTHOR:  Antigravity AI Assistant
#       VERSION:  1.5.0
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
SCRIPT_VERSION="1.5.0"
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

# 检查 jq 是否安装
check_jq() {
    if ! command -v jq &> /dev/null; then
        error_msg "未安装 jq，脚本多账号功能依赖此工具。"
        echo -e "${YELLOW}正在尝试自动安装 jq...${NC}"
        install_dependencies
        if ! command -v jq &> /dev/null; then
            error_msg "jq 安装失败，请手动运行: apt install jq 或 yum install jq"
            exit 1
        fi
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
# 系统更新和依赖检查 (完整保留)
#===============================================================================

# 更新系统
update_system() {
    info_msg "正在更新系统包管理器..."
    echo ""
    
    case $OS_ID in
        ubuntu|debian|linuxmint|pop|elementary|kali|zorin|deepin)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y
            apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
            ;;
        centos|rhel|fedora|rocky|almalinux|ol|amzn|scientific|eurolinux)
            if command -v dnf &> /dev/null; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        arch|manjaro|endeavouros|artix|garuda)
            pacman -Syu --noconfirm
            ;;
        alpine)
            apk update
            apk upgrade
            ;;
        opensuse*|sles|suse)
            zypper refresh
            zypper update -y
            ;;
        *)
            warn_msg "未知的操作系统 ($OS_ID)，跳过系统更新"
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
        ubuntu|debian|linuxmint|pop|elementary|kali|zorin|deepin)
            apt-get install -y $packages
            ;;
        centos|rhel|fedora|rocky|almalinux|ol|amzn|scientific|eurolinux)
            if command -v dnf &> /dev/null; then
                dnf install -y $packages
            else
                yum install -y $packages
            fi
            ;;
        arch|manjaro|endeavouros|artix|garuda)
            pacman -S --noconfirm $packages
            ;;
        alpine)
            apk add $packages
            ;;
        opensuse*|sles|suse)
            zypper install -y $packages
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
        ubuntu|debian|linuxmint|pop|elementary|kali|zorin|deepin)
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
            ;;
        centos|rhel|fedora|rocky|almalinux|ol|amzn|scientific|eurolinux)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
            if command -v dnf &> /dev/null; then
                dnf install -y nodejs
            else
                yum install -y nodejs
            fi
            ;;
        arch|manjaro|endeavouros|artix|garuda)
            pacman -S --noconfirm nodejs npm
            ;;
        alpine)
            apk add nodejs npm
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
    
    mkdir -p ~/.npm
    mkdir -p ~/.npm-global
    npm config set prefix ~/.npm-global 2>/dev/null || true
    export PATH=~/.npm-global/bin:$PATH
    
    local path_line='export PATH=~/.npm-global/bin:$PATH'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc" ] && ! grep -q ".npm-global" "$rc" 2>/dev/null; then
            echo "$path_line" >> "$rc"
        fi
    done
    
    npm cache clean --force 2>/dev/null || true
    success_msg "npm 权限修复完成"
}

#===============================================================================
# 功能1: 一键安装 OpenClaw
#===============================================================================

install_openclaw() {
    show_banner
    echo -e "${GREEN}${BOLD}【 一键安装 OpenClaw 】${NC}"
    print_line
    echo ""
    
    detect_os
    info_msg "检测到操作系统: $OS ($OS_ID)"
    echo ""
    
    if command -v openclaw &> /dev/null; then
        warn_msg "检测到 OpenClaw 已安装!"
        local oc_version=$(timeout 3 openclaw --version 2>/dev/null | head -1 || echo "未知版本")
        echo -e "   当前版本: ${CYAN}$oc_version${NC}"
        echo -e "${YELLOW}是否继续安装/更新? [y/N]: ${NC}"
        read -r reinstall_choice </dev/tty
        if [[ ! "$reinstall_choice" =~ ^[Yy]$ ]]; then
            info_msg "已取消安装"
            return 0
        fi
    fi
    
    update_system
    install_dependencies
    
    if ! check_nodejs; then
        install_nodejs
        if ! check_nodejs; then
            error_msg "Node.js 安装失败，请手动安装后重试"
            press_any_key
            return 1
        fi
    fi
    
    fix_npm_permissions
    
    info_msg "正在运行 OpenClaw 官方安装脚本..."
    warn_msg "提示: 看到 'Onboarding complete' 后，请按 Ctrl+C 返回主菜单"
    echo ""
    
    curl -fsSL https://openclaw.ai/install.sh | bash
    
    echo ""
    if command -v openclaw &> /dev/null; then
        success_msg "OpenClaw 已成功安装!"
        info_msg "您可以通过以下命令启动 OpenClaw: openclaw"
    else
        warn_msg "请检查上方安装日志确认安装状态"
    fi
    
    press_any_key
}

#===============================================================================
# 功能2: 一键卸载 OpenClaw
#===============================================================================

uninstall_openclaw() {
    show_banner
    echo -e "${RED}${BOLD}【 一键卸载 OpenClaw 】${NC}"
    print_line
    echo ""
    
    warn_msg "此操作将完全删除 OpenClaw 及其所有数据!"
    echo -e "${YELLOW}确定要卸载 OpenClaw 吗? [y/N]: ${NC}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info_msg "已取消卸载操作"
        return 0
    fi
    
    info_msg "开始卸载 OpenClaw..."
    
    pkill -f "openclaw" 2>/dev/null && success_msg "已停止 OpenClaw 进程"
    
    if npm list -g openclaw &>/dev/null 2>&1; then
        npm uninstall -g openclaw 2>/dev/null
        success_msg "已卸载 npm 全局包"
    fi
    
    if [ -f "$HOME/.local/bin/openclaw" ]; then
        rm -f "$HOME/.local/bin/openclaw"
    fi
    
    rm -rf "$HOME/.openclaw" "$HOME/.config/openclaw" "$HOME/.cache/openclaw" "$HOME/openclaw" "$HOME/.local/share/openclaw"
    
    success_msg "OpenClaw 卸载完成!"
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
    
    if ! command -v openclaw &> /dev/null; then
        error_msg "未检测到 OpenClaw 安装!"
        press_any_key
        return 1
    fi
    
    info_msg "请在 Telegram 中找到 OpenClaw 机器人并获取对接码。"
    echo -e "${CYAN}请输入您的 Telegram 对接码 (输入 q 返回): ${NC}"
    read -r link_code </dev/tty
    
    if [ "$link_code" == "q" ] || [ -z "$link_code" ]; then
        return 0
    fi
    
    openclaw pairing approve telegram "$link_code"
    
    if [ $? -eq 0 ]; then
        success_msg "Telegram 机器人对接成功!"
    else
        error_msg "对接失败，请检查 OpenClaw 是否正在运行，或验证码是否过期。"
    fi
    
    press_any_key
}

#===============================================================================
# 功能4: 多账号管理 (单 Agent 模式 + 修复版)
#===============================================================================

ACCOUNTS_CONFIG="$OPENCLAW_HOME/accounts_manager.json"
PROFILES_DIR="$OPENCLAW_HOME/account-profiles"

# --- 1. Agent 自动探测 (FIXED: 纯净输出，无杂音) ---

get_single_active_agent() {
    local agents_dir="$OPENCLAW_HOME/agents"
    
    # 优先使用 main
    if [ -d "$agents_dir/main" ]; then
        echo "main"
        return
    fi

    # 查找第一个目录
    if [ -d "$agents_dir" ]; then
        local first_agent=$(ls -1 "$agents_dir" 2>/dev/null | head -n 1)
        if [ -n "$first_agent" ]; then
            echo "$first_agent"
            return
        fi
    fi

    echo "main"
}

get_auth_profile_path() {
    local agent_name="$1"
    echo "$OPENCLAW_HOME/agents/$agent_name/agent/auth-profiles.json"
}

# --- 2. 插件自动修复 (FIXED: 映射修复) ---

auth_helper_plugin_for_provider() {
    local provider="$1"
    case "$provider" in
        # 修正：OpenClaw 官方插件通常就叫 openai，不需要 -codex 后缀
        openai-codex) echo "openai" ;; 
        openai) echo "openai" ;;
        
        # Google
        google-antigravity) echo "google" ;;
        google) echo "google" ;;
        
        # Anthropic
        anthropic) echo "anthropic" ;;
        
        *) echo "$provider" ;;
    esac
}

ensure_provider_plugins() {
    local provider="${1:-}"
    # 获取真实的插件包名
    local pkg=$(auth_helper_plugin_for_provider "$provider")
    
    info_msg "检查插件环境: Provider=[$provider] -> Package=[$pkg]"
    
    # 尝试安装并启用
    if [ -n "$pkg" ]; then
        openclaw plugins install "$pkg" >/dev/null 2>&1
        openclaw plugins enable "$pkg" >/dev/null 2>&1
        success_msg "已尝试激活插件: $pkg"
    fi
}

# --- 3. 账号存储管理 ---

init_accounts_config() {
    mkdir -p "$(dirname "$ACCOUNTS_CONFIG")"
    if [ ! -f "$ACCOUNTS_CONFIG" ]; then
        echo '{"accounts": [], "active_idx": 0}' > "$ACCOUNTS_CONFIG"
    fi
}

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

# --- 4. 添加 API Key 账号 ---

add_apikey_account() {
    show_banner
    echo -e "${BLUE}${BOLD}【 添加 API Key 账号 】${NC}"
    print_line
    
    check_jq
    init_accounts_config

    local target_agent=$(get_single_active_agent)
    info_msg "已自动锁定目标 Agent: ${GREEN}$target_agent${NC}"
    echo ""

    echo -e "${CYAN}请输入账号名称 (别名): ${NC}"
    read -r account_name
    [ -z "$account_name" ] && account_name="未命名账号_$(date +%s)"

    # 提供标准选项
    echo -e "${CYAN}请选择 Provider:${NC}"
    echo -e "   1. OpenAI"
    echo -e "   2. Anthropic"
    echo -e "   3. DeepSeek"
    echo -e "   4. 手动输入"
    read -r p_opt
    
    local provider
    case $p_opt in
        1) provider="openai" ;;
        2) provider="anthropic" ;;
        3) provider="deepseek" ;;
        4) echo -e "${CYAN}请输入 Provider 代码 (如 deepseek): ${NC}"; read -r provider ;;
        *) provider="openai" ;;
    esac

    echo -e "${CYAN}请输入 API Key (sk-...): ${NC}"
    read -r api_key
    if [ -z "$api_key" ]; then
        error_msg "API Key 不能为空"
        press_any_key
        return
    fi

    echo -e "${CYAN}请输入 API Base URL (可选): ${NC}"
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
    local profile_id="$(date +%Y%m%d_%H%M%S)_${provider}_apikey"
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
            storage: {
                authProfiles: {
                    agentId: $agent,
                    entry: $entry
                }
            }
        }' > "$profile_file"

    if [ $? -eq 0 ]; then
        success_msg "配置已保存: $profile_file"
        register_account_to_manager "$account_name" "api_key" "$provider" "$profile_file" "$target_agent"
        
        echo -e "${CYAN}是否立即切换到此账号? [y/N]: ${NC}"
        read -r activate
        if [[ "$activate" =~ ^[Yy]$ ]]; then
            apply_profile_to_openclaw "$profile_file"
        fi
    else
        error_msg "保存文件失败"
    fi
    press_any_key
}

# --- 5. 添加 OAuth 账号 (FIXED: 修复插件名与文件读取) ---

add_oauth_account() {
    show_banner
    echo -e "${BLUE}${BOLD}【 添加 OAuth 账号 】${NC}"
    print_line
    
    check_jq
    init_accounts_config

    local target_agent=$(get_single_active_agent)
    info_msg "已自动锁定目标 Agent: ${GREEN}$target_agent${NC}"
    echo ""

    echo -e "${CYAN}请输入账号名称 (别名): ${NC}"
    read -r account_name
    [ -z "$account_name" ] && account_name="OAuth_$(date +%s)"

    # 修正：使用标准 Provider 名称，不再使用 -codex 后缀，解决插件不匹配问题
    echo -e "${CYAN}选择 Provider:${NC}"
    echo -e "   1. OpenAI (标准版)"
    echo -e "   2. Anthropic (Claude)"
    echo -e "   3. Google (Gemini)"
    read -r p_choice

    local provider
    case $p_choice in
        1) provider="openai" ;;      # 修正为 openai
        2) provider="anthropic" ;;   # 修正为 anthropic
        3) provider="google" ;;      # 修正为 google
        *) warn_msg "默认使用 openai"; provider="openai" ;;
    esac

    # 1. 强制修复插件
    ensure_provider_plugins "$provider"

    # 2. 备份当前配置
    local auth_file=$(get_auth_profile_path "$target_agent")
    local backup_auth="${auth_file}.bak.temp"
    if [ -f "$auth_file" ]; then cp "$auth_file" "$backup_auth"; fi

    info_msg "即将启动浏览器登录 (Provider: $provider)..."
    
    # 3. 执行登录 (尝试新旧两种命令，隐藏错误输出)
    # 优先使用 models auth login，它是新版标准
    if openclaw models auth login --provider "$provider" --method oauth; then
        success_msg "登录命令执行完毕"
    else
        # 尝试回退命令，但只有在上面失败时才执行
        warn_msg "标准登录命令失败，尝试备用命令..."
        if ! openclaw auth login --provider "$provider"; then
            error_msg "登录失败。请检查网络或插件是否正确安装。"
            # 恢复备份并退出
            if [ -f "$backup_auth" ]; then mv "$backup_auth" "$auth_file"; fi
            press_any_key
            return
        fi
    fi

    # 4. 捕获新凭证 (FIXED: 安全读取)
    if [ ! -f "$auth_file" ]; then
        error_msg "未检测到凭证文件 ($auth_file)"
        if [ -f "$backup_auth" ]; then mv "$backup_auth" "$auth_file"; fi
        press_any_key; return
    fi

    local entry=$(jq -r --arg p "$provider" '.[$p] // empty' "$auth_file")
    
    # 兼容旧版 oauth.json
    if [ -z "$entry" ] || [ "$entry" == "null" ]; then
        local oauth_json="$OPENCLAW_HOME/credentials/oauth.json"
        if [ -f "$oauth_json" ]; then
            entry=$(jq -r --arg p "$provider" '.[$p] // empty' "$oauth_json")
        fi
    fi

    if [ -z "$entry" ] || [ "$entry" == "null" ]; then
        error_msg "无法从配置文件中捕获凭证，登录可能未成功或未保存。"
        if [ -f "$backup_auth" ]; then mv "$backup_auth" "$auth_file"; fi
        press_any_key; return
    fi

    # 5. 保存 Profile
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
            storage: {
                authProfiles: {
                    agentId: $agent,
                    entry: $entry
                }
            }
        }' > "$profile_file"

    success_msg "OAuth 凭证已捕获并存档。"
    
    # 6. 询问保留状态
    # 先恢复旧环境，让用户手动决定是否切换，保证逻辑统一
    if [ -f "$backup_auth" ]; then
        mv "$backup_auth" "$auth_file"
        info_msg "已恢复环境到登录前状态 (凭证已另存为 Profile)。"
    fi

    register_account_to_manager "$account_name" "oauth" "$provider" "$profile_file" "$target_agent"
    
    echo -e "${CYAN}是否立即切换到此账号? [y/N]: ${NC}"
    read -r activate
    if [[ "$activate" =~ ^[Yy]$ ]]; then
        apply_profile_to_openclaw "$profile_file"
    fi

    press_any_key
}

# --- 6. 切换账号执行 ---

apply_profile_to_openclaw() {
    local profile_file="$1"
    
    if [ ! -f "$profile_file" ]; then
        error_msg "Profile 文件不存在: $profile_file"
        return 1
    fi

    local agent_name=$(jq -r '.targetAgent // "main"' "$profile_file")
    local provider=$(jq -r '.provider' "$profile_file")
    local auth_entry=$(jq '.storage.authProfiles.entry' "$profile_file")
    
    local target_auth_file=$(get_auth_profile_path "$agent_name")
    
    info_msg "正在应用账号到 Agent: $agent_name (Provider: $provider)..."
    
    # 确保目录存在
    mkdir -p "$(dirname "$target_auth_file")"
    if [ ! -f "$target_auth_file" ]; then echo '{}' > "$target_auth_file"; fi
    
    # 备份
    cp "$target_auth_file" "${target_auth_file}.bak"

    # 写入配置 (仅更新该 Provider 的部分，保留其他 Provider)
    local tmp=$(mktemp)
    jq --arg p "$provider" --argjson e "$auth_entry" '.[$p] = $e' "$target_auth_file" > "$tmp"
    
    if [ $? -eq 0 ]; then
        mv "$tmp" "$target_auth_file"
        success_msg "账号切换成功！(配置已写入 $agent_name)"
        return 0
    else
        error_msg "配置文件写入失败，已回滚。"
        cp "${target_auth_file}.bak" "$target_auth_file"
        return 1
    fi
}

# --- 7. 账号列表与操作 ---

list_and_switch_accounts() {
    show_banner
    check_jq
    init_accounts_config
    
    local count=$(jq '.accounts | length' "$ACCOUNTS_CONFIG")
    if [ "$count" -eq 0 ]; then
        warn_msg "暂无账号，请先添加。"
        press_any_key
        return
    fi

    echo -e "${WHITE}已保存的账号列表 (全部绑定到唯一 Agent):${NC}"
    echo -e "${GRAY}ID   名称                  类型      Provider        Agent${NC}"
    echo -e "${GRAY}------------------------------------------------------------${NC}"

    for ((i=0; i<count; i++)); do
        local name=$(jq -r ".accounts[$i].name" "$ACCOUNTS_CONFIG")
        local type=$(jq -r ".accounts[$i].type" "$ACCOUNTS_CONFIG")
        local prov=$(jq -r ".accounts[$i].provider" "$ACCOUNTS_CONFIG")
        local agent=$(jq -r ".accounts[$i].targetAgent // \"main\"" "$ACCOUNTS_CONFIG")
        
        printf " %-3d %-21s %-9s %-15s %s\n" $((i+1)) "${name:0:20}" "$type" "${prov:0:14}" "$agent"
    done
    echo ""
    echo -e "${CYAN}输入序号进行切换 (输入 d + 序号删除，例如 d1): ${NC}"
    read -r cmd

    # 删除功能
    if [[ "$cmd" =~ ^d([0-9]+)$ ]]; then
        local idx=${BASH_REMATCH[1]}
        idx=$((idx-1))
        local tmp=$(mktemp)
        jq "del(.accounts[$idx])" "$ACCOUNTS_CONFIG" > "$tmp" && mv "$tmp" "$ACCOUNTS_CONFIG"
        success_msg "账号已从列表中移除"
        press_any_key
        return
    fi

    # 切换功能
    if [[ "$cmd" =~ ^[0-9]+$ ]]; then
        local idx=$((cmd-1))
        local file=$(jq -r ".accounts[$idx].profileFile" "$ACCOUNTS_CONFIG")
        apply_profile_to_openclaw "$file"
        press_any_key
    fi
}

#===============================================================================
# 多账号管理子菜单
#===============================================================================

multi_account_manage() {
    while true; do
        show_banner
        echo -e "${PURPLE}${BOLD}【 多账号管理 】${NC}"
        print_line
        
        echo -e "   ${GREEN}1.${NC} 列出 / 切换账号"
        echo -e "   ${BLUE}2.${NC} 添加 OAuth 账号 (Browser Login)"
        echo -e "   ${BLUE}3.${NC} 添加 API Key 账号 (Manual Input)"
        echo -e "   ${GRAY}0.${NC} 返回主菜单"
        echo ""
        echo -e "${CYAN}请输入选项: ${NC}"
        read -r sub_choice
        
        case $sub_choice in
            1) list_and_switch_accounts ;;
            2) add_oauth_account ;;
            3) add_apikey_account ;;
            0) return ;;
            *) ;;
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
    
    if command -v openclaw &> /dev/null; then
        local oc_version=$(timeout 3 openclaw --version 2>/dev/null | head -1 || echo "")
        echo -e "   OpenClaw: ${GREEN}已安装 ($oc_version)${NC}"
    else
        echo -e "   OpenClaw: ${GRAY}未安装${NC}"
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
            0) clear_screen; exit 0 ;;
            *) warn_msg "无效的选项，请重新选择"; sleep 1 ;;
        esac
    done
}

# 运行主程序
main "$@"
