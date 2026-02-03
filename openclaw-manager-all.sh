#!/bin/bash
# ============================================================================
#                    OpenClaw 完整管理工具
#                         Version: 2.0.0
#            安装 | 卸载 | OAuth 多账号管理 | TG 机器人对接
# ============================================================================
#
# 使用方法:
#   bash <(curl -fsSL https://raw.githubusercontent.com/NX2406/openclaw-uninstaller/main/openclaw-manager-all.sh)
#   或者下载后执行: bash openclaw-manager-all.sh
#
# 功能模块:
#   1. 安装/更新 OpenClaw (集成官方安装脚本)
#   2. 完整卸载管理 (保留原有全部功能)
#   3. OAuth 多账号管理与自动切换
#   4. Telegram 机器人对接码管理
#   5. 配置备份与恢复

# ============================================================================
# 颜色定义
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ============================================================================
# 全局变量
# ============================================================================
SCRIPT_VERSION="2.0.0"
LOG_FILE="/tmp/openclaw-manager-$(date +%Y%m%d_%H%M%S).log"
FOUND_COMPONENTS=()
REMOVED_COMPONENTS=()

# OpenClaw 配置路径
OPENCLAW_HOME="${HOME}/.openclaw"
OPENCLAW_CREDENTIALS="${OPENCLAW_HOME}/credentials"
OAUTH_CONFIG="${OPENCLAW_CREDENTIALS}/oauth.json"
OAUTH_STAGING="${OPENCLAW_CREDENTIALS}/oauth-staging.json"
BACKUP_DIR="${OPENCLAW_HOME}/backups"
TG_CONFIG="${OPENCLAW_HOME}/telegram-config.json"

# ============================================================================
# 辅助函数
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${WHITE}"
    echo "================================================================================"
    echo ""
    echo "     ___   ____  _____ _   _  ____  _        ___  __        __               "
    echo "    / _ \ |  _ \| ____| \ | |/ ___|| |      / \ \ \      / /               "
    echo "   | | | || |_) |  _| |  \| | |    | |     / _ \ \ \ /\ / /                "
    echo "   | |_| ||  __/| |___| |\  | |___ | |___ / ___ \ \ V  V /                 "
    echo "    \___/ |_|   |_____|_| \_|\____||_____/_/   \_\ \_/\_/                  "
    echo ""
    echo "                       管理工具 v${SCRIPT_VERSION}"
    echo ""
    echo "                  安装 | 卸载 | OAuth | TG Bot"
    echo ""
    echo "================================================================================"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "\n${CYAN}----------------------------------------------------------------------------${NC}"
    echo -e "${WHITE}${BOLD}  $1${NC}"
    echo -e "${CYAN}----------------------------------------------------------------------------${NC}\n"
}

print_success() {
    echo -e "  ${GREEN}[OK]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "  ${YELLOW}[!]${NC} $1"
    log "WARNING: $1"
}

print_error() {
    echo -e "  ${RED}[X]${NC} $1"
    log "ERROR: $1"
}

print_info() {
    echo -e "  ${BLUE}[i]${NC} $1"
    log "INFO: $1"
}

print_found() {
    echo -e "  ${PURPLE}[>]${NC} $1"
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    echo -ne "  ${YELLOW}[?]${NC} $prompt"
    read -r response </dev/tty
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

press_any_key() {
    echo ""
    echo -ne "  ${DIM}按任意键继续...${NC}"
    read -n 1 -s </dev/tty
    echo ""
}

read_choice() {
    read -r choice </dev/tty
    echo "$choice"
}

read_input() {
    local prompt="$1"
    echo -ne "  ${CYAN}$prompt:${NC} "
    read -r input </dev/tty
    echo "$input"
}

# ============================================================================
# 新功能模块 - 安装/OAuth/TG
# ============================================================================

# ------------------------------
#  安装模块函数
# ------------------------------

install_nodejs() {
    print_info "正在安装 Node.js..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            brew install node@22
            brew link node@22 --overwrite --force 2>/dev/null || true
        else
            print_error "未安装 Homebrew"
            return 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v yum &>/dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
        else
            print_error "无法检测包管理器"
            return 1
        fi
    fi
    
    if command -v node &>/dev/null; then
        print_success "Node.js 安装成功: $(node --version)"
    fi
}

install_git() {
    print_info "正在安装 Git..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y git
        elif command -v yum &>/dev/null; then
            sudo yum install -y git
        fi
    fi
}

# ------------------------------
#  系统资源检测函数
# ------------------------------

check_memory_and_swap() {
    print_section "系统资源检测"
    
    # 获取内存信息（单位: MB）
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local free_mem=$(free -m | awk '/^Mem:/{print $4}')
    local swap_total=$(free -m | awk '/^Swap:/{print $2}')
    local swap_free=$(free -m | awk '/^Swap:/{print $4}')
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BLUE}物理内存:${NC} ${total_mem}MB (可用: ${free_mem}MB)"
    echo -e "  ${BLUE}交换分区:${NC} ${swap_total}MB (可用: ${swap_free}MB)"
    
    # 检测当前 swappiness
    local current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    echo -e "  ${BLUE}Swappiness:${NC} ${current_swappiness}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 推荐配置
    local recommended_swap=0
    local needs_swap=false
    
    # 内存小于2GB，强烈建议swap
    if [[ $total_mem -lt 2048 ]]; then
        recommended_swap=$((total_mem * 2))
        needs_swap=true
        print_warning "⚠️  内存不足 2GB，强烈建议配置 Swap"
    # 内存2-4GB，建议swap
    elif [[ $total_mem -lt 4096 ]]; then
        recommended_swap=$total_mem
        needs_swap=true
        print_warning "内存较小，建议配置 Swap"
    # 内存充足
    else
        print_success "✓ 内存充足 (>= 4GB)"
        return 0
    fi
    
    # 检查是否已有足够swap
    if [[ $swap_total -ge $recommended_swap ]]; then
        print_success "✓ Swap 已配置 (${swap_total}MB >= ${recommended_swap}MB)"
        
        # 询问是否调整 swappiness
        echo ""
        if confirm_action "是否优化 Swappiness 参数? (当前: $current_swappiness)"; then
            configure_swappiness
        fi
        return 0
    fi
    
    # 需要创建swap
    if $needs_swap; then
        local swap_needed=$((recommended_swap - swap_total))
        echo ""
        echo -e "${YELLOW}建议创建 ${swap_needed}MB Swap 以确保系统稳定运行${NC}"
        echo -e "${DIM}OpenClaw 编译和运行需要较多内存${NC}"
        echo ""
        
        if confirm_action "是否立即创建 Swap?"; then
            create_swap_file "$swap_needed"
        else
            print_warning "跳过 Swap 配置，可能影响安装稳定性"
        fi
    fi
}

create_swap_file() {
    local swap_size_mb=$1
    local swap_file="/swapfile"
    
    print_info "正在创建 ${swap_size_mb}MB Swap 文件..."
    
    # 检查是否已存在
    if [[ -f "$swap_file" ]]; then
        print_warning "Swap 文件已存在: $swap_file"
        if ! confirm_action "是否删除并重建?"; then
            return 1
        fi
        sudo swapoff "$swap_file" 2>/dev/null || true
        sudo rm -f "$swap_file"
    fi
    
    # 创建swap文件
    echo -e "  ${BLUE}[1/5]${NC} 分配磁盘空间..."
    if ! sudo dd if=/dev/zero of="$swap_file" bs=1M count="$swap_size_mb" status=progress 2>&1 | tail -n 1; then
        print_error "创建 Swap 文件失败"
        return 1
    fi
    
    echo -e "  ${BLUE}[2/5]${NC} 设置权限..."
    sudo chmod 600 "$swap_file"
    
    echo -e "  ${BLUE}[3/5]${NC} 格式化为 Swap..."
    if ! sudo mkswap "$swap_file" &>/dev/null; then
        print_error "格式化失败"
        return 1
    fi
    
    echo -e "  ${BLUE}[4/5]${NC} 启用 Swap..."
    if ! sudo swapon "$swap_file"; then
        print_error "启用失败"
        return 1
    fi
    
    print_success "✅ Swap 已启用"
    
    # 询问是否永久保存
    echo ""
    echo -e "${YELLOW}Swap 配置选项:${NC}"
    echo -e "  ${GREEN}1.${NC} 临时生效 (重启后失效)"
    echo -e "  ${GREEN}2.${NC} 永久生效 (写入 /etc/fstab)"
    echo ""
    echo -ne "  ${YELLOW}请选择 [1-2]:${NC} "
    
    choice=$(read_choice)
    
    if [[ "$choice" == "2" ]]; then
        # 检查fstab中是否已存在
        if grep -q "$swap_file" /etc/fstab 2>/dev/null; then
            print_info "fstab 已包含 swap 配置"
        else
            echo -e "  ${BLUE}[5/5]${NC} 写入 /etc/fstab..."
            echo "$swap_file none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
            print_success "✅ 已写入永久配置"
        fi
    else
        print_info "✓ Swap 已临时启用（重启后需重新配置）"
    fi
    
    # 配置 swappiness
    echo ""
    if confirm_action "是否配置 Swappiness 参数?"; then
        configure_swappiness "$choice"
    fi
}

configure_swappiness() {
    local permanent_choice=${1:-""}
    
    echo ""
    print_section "配置 Swap 积极程度 (Swappiness)"
    
    local current=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BLUE}当前值:${NC} $current"
    echo -e "  ${DIM}范围: 0-100 (0=最少使用, 100=积极使用)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}推荐配置:${NC}"
    echo -e "  ${GREEN}1.${NC} 100 - 积极使用 Swap ${DIM}(内存<2GB推荐)${NC}"
    echo -e "  ${GREEN}2.${NC} 60  - 默认平衡"
    echo -e "  ${GREEN}3.${NC} 10  - 尽量少用 Swap ${DIM}(内存充足)${NC}"
    echo -e "  ${GREEN}4.${NC} 自定义值"
    echo ""
    echo -ne "  ${YELLOW}请选择 [1-4]:${NC} "
    
    choice=$(read_choice)
    
    local new_swappiness
    case "$choice" in
        1) new_swappiness=100 ;;
        2) new_swappiness=60 ;;
        3) new_swappiness=10 ;;
        4)
            echo -ne "  ${CYAN}请输入值 [0-100]:${NC} "
            read -r new_swappiness </dev/tty
            if ! [[ "$new_swappiness" =~ ^[0-9]+$ ]] || [[ $new_swappiness -gt 100 ]]; then
                print_error "无效值，使用默认 60"
                new_swappiness=60
            fi
            ;;
        *)
            print_warning "无效选择，保持当前值"
            return
            ;;
    esac
    
    # 应用设置
    echo ""
    print_info "设置 Swappiness = $new_swappiness"
    sudo sysctl vm.swappiness="$new_swappiness" >/dev/null
    print_success "✅ 已应用"
    
    # 询问持久化
    if [[ -z "$permanent_choice" ]]; then
        echo ""
        echo -e "${YELLOW}配置选项:${NC}"
        echo -e "  ${GREEN}1.${NC} 临时生效 (重启后恢复默认)"
        echo -e "  ${GREEN}2.${NC} 永久生效 (写入 /etc/sysctl.conf)"
        echo ""
        echo -ne "  ${YELLOW}请选择 [1-2]:${NC} "
        permanent_choice=$(read_choice)
    fi
    
    if [[ "$permanent_choice" == "2" ]]; then
        local sysctl_conf="/etc/sysctl.conf"
        
        # 移除旧配置
        sudo sed -i '/vm.swappiness/d' "$sysctl_conf" 2>/dev/null || true
        
        # 添加新配置
        echo "vm.swappiness=$new_swappiness" | sudo tee -a "$sysctl_conf" >/dev/null
        print_success "✅ 已写入永久配置"
    else
        print_info "✓ 已临时应用（重启后恢复）"
    fi
    
    echo ""
}

# ------------------------------
#  安装依赖检测
# ------------------------------

check_install_dependencies() {
    print_section "检查安装依赖"
    
    # Node.js
    if command -v node &>/dev/null; then
        local node_version=$(node --version | sed 's/v//')
        local major=$(echo "$node_version" | cut -d'.' -f1)
        
        if [[ "$major" -ge 22 ]]; then
            print_success "Node.js $node_version"
        else
            print_warning "Node.js 版本过低，需要 v22+"
            if confirm_action "是否安装 Node.js v22?"; then
                install_nodejs
            fi
        fi
    else
        print_warning "未安装 Node.js"
        if confirm_action "是否安装?"; then
            install_nodejs
        else
            return 1
        fi
    fi
    
    # Git
    if command -v git &>/dev/null; then
        print_success "Git 已安装"
    else
        print_warning "未安装 Git"
        if confirm_action "是否安装?"; then
            install_git
        fi
    fi
    
    return 0
}

menu_install() {
    print_header
    print_section "安装 OpenClaw"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 检查是否已安装
    if command -v openclaw &>/dev/null; then
        local version=$(openclaw --version 2>/dev/null || echo '未知')
        echo -e "  ${YELLOW}⚠ OpenClaw 已安装${NC}"
        echo -e "  ${BLUE}当前版本:${NC} $version"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        if ! confirm_action "是否重新安装/更新?"; then
            press_any_key
            return
        fi
    else
        echo -e "  ${BLUE}ℹ OpenClaw 未安装${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}${BOLD}步骤 1/4: 系统资源检测${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 检测内存和swap
    check_memory_and_swap
    
    echo ""
    echo -e "${WHITE}${BOLD}步骤 2/4: 检查依赖${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 检查依赖
    if ! check_install_dependencies; then
        print_error "依赖检查失败"
        press_any_key
        return
    fi
    
    echo ""
    echo -e "${WHITE}${BOLD}步骤 3/4: 选择安装方式${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}1.${NC} 🚀 官方安装脚本 ${DIM}(推荐)${NC}"
    echo -e "  ${GREEN}2.${NC} 📦 npm 全局安装 ${DIM}(快速)${NC}"
    echo -e "  ${GREEN}3.${NC} 🔧 Git 源码安装 ${DIM}(开发)${NC}"
    echo ""
    echo -ne "  ${YELLOW}请选择 [1-3]:${NC} "
    
    choice=$(read_choice)
    
    echo ""
    echo -e "${WHITE}${BOLD}步骤 4/4: 执行安装${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    case "$choice" in
        1)
            print_info "📥 正在下载官方安装脚本..."
            bash <(curl -fsSL https://openclaw.bot/install.sh) || {
                print_error "安装失败"
                press_any_key
                return
            }
            ;;
        2)
            print_info "📦 正在通过 npm 安装..."
            npm install -g openclaw@latest || {
                print_error "安装失败"
                press_any_key
                return
            }
            ;;
        3)
            print_info "📂 正在克隆源码仓库..."
            local repo_dir="${HOME}/openclaw-src"
            if [[ ! -d "$repo_dir" ]]; then
                git clone https://github.com/openclaw/openclaw.git "$repo_dir" || {
                    print_error "克隆失败"
                    press_any_key
                    return
                }
            fi
            cd "$repo_dir"
            print_info "🔨 正在编译..."
            npm install && npm run build && npm link || {
                print_error "编译失败"
                press_any_key
                return
            }
            ;;
        *)
            print_error "无效选项"
            press_any_key
            return
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 验证安装
    if command -v openclaw &>/dev/null; then
        echo -e "${GREEN}${BOLD}"
        echo "  ✅ 安装成功！"
        echo -e "${NC}"
        echo -e "  ${BLUE}版本:${NC} $(openclaw --version 2>/dev/null || echo '未知')"
        echo ""
        echo -e "  ${WHITE}${BOLD}🎉 下一步:${NC}"
        echo -e "  ${DIM}1. 选择 [5] OAuth 账号管理 → 添加账号${NC}"
        echo -e "  ${DIM}2. 选择 [6] Telegram 机器人 → 批准配对${NC}"
    else
        print_error "安装似乎未成功，请检查错误信息"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    press_any_key
}

# ------------------------------
#  OAuth 模块函数
# ------------------------------

check_jq() {
    if ! command -v jq &>/dev/null; then
        print_warning "未安装 jq (OAuth 功能需要)"
        if confirm_action "是否安装 jq?"; then
            install_jq
        else
            return 1
        fi
    fi
    return 0
}

install_jq() {
    print_info "正在安装 jq..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &>/dev/null; then
            sudo yum install -y jq
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y jq
        fi
    fi
    
    if command -v jq &>/dev/null; then
        print_success "jq 安装成功"
    else
        return 1
    fi
}

ensure_oauth_config() {
    mkdir -p "$OPENCLAW_CREDENTIALS" "$BACKUP_DIR"
    
    if [[ ! -f "$OAUTH_CONFIG" ]]; then
        echo '{"accounts": [], "auto_switch": false, "active_account_id": ""}' > "$OAUTH_CONFIG"
    fi
}

backup_oauth_config() {
    ensure_oauth_config
    local timestamp=$(date +%Y%m%d_%H%M%S)
    if [[ -f "$OAUTH_CONFIG" ]]; then
        cp "$OAUTH_CONFIG" "${BACKUP_DIR}/oauth.json.backup.${timestamp}"
        print_success "配置已备份"
        
        # 保留最近 10 个
        ls -t "${BACKUP_DIR}"/oauth.json.backup.* 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    fi
}

oauth_list_accounts() {
    print_header
    print_section "OAuth 账号列表"
    
    if ! check_jq; then
        press_any_key
        return 1
    fi
    
    ensure_oauth_config
    
    local count=$(jq '.accounts | length' "$OAUTH_CONFIG" 2>/dev/null || echo "0")
    
    if [[ "$count" == "0" ]]; then
        echo ""
        print_warning "未配置任何账号"
        echo ""
        echo -e "  ${DIM}💡 提示: 选择 '2. 添加新账号' 开始配置${NC}"
        press_any_key
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  总计: ${WHITE}$count${BLUE} 个账号${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 表头
    printf "  ${WHITE}${BOLD}%-20s %-18s %-30s %-10s${NC}\n" "账号 ID" "提供商" "邮箱" "状态"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────────────────────${NC}"
    
    # 账号列表
    jq -r '.accounts[] | "\(.id)|\(.provider)|\(.email)|\(if .is_active then "✓ 活动" else "  未活动" end)"' "$OAUTH_CONFIG" 2>/dev/null | while IFS='|' read -r id provider email status; do
        if [[ "$status" == *"活动"* ]]; then
            printf "  ${GREEN}%-20s${NC} %-18s %-30s ${GREEN}${BOLD}%-10s${NC}\n" "$id" "$provider" "$email" "$status"
        else
            printf "  ${DIM}%-20s %-18s %-30s %-10s${NC}\n" "$id" "$provider" "$email" "$status"
        fi
    done
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 显示自动切换状态
    local auto_switch=$(jq -r '.auto_switch' "$OAUTH_CONFIG" 2>/dev/null || echo "false")
    if [[ "$auto_switch" == "true" ]]; then
        echo -e "  ${BLUE}🔄 自动切换:${NC} ${GREEN}已启用${NC}"
    else
        echo -e "  ${BLUE}🔄 自动切换:${NC} ${YELLOW}已禁用${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo ""
    press_any_key
}

oauth_add_account() {
    print_header
    print_section "添加 OAuth 账号"
    
    if ! check_jq; then
        press_any_key
        return 1
    fi
    
    ensure_oauth_config
    
    echo -e "${BLUE}选择提供商:${NC}\n"
    echo -e "  ${GREEN}1.${NC} Google Gemini"
    echo -e "  ${GREEN}2.${NC} Claude (Anthropic)"
    echo -e "  ${GREEN}3.${NC} 其他"
    echo ""
    
    provider=""
    choice=$(read_input "请选择 [1-3]")
    
    case "$choice" in
        1) provider="google-gemini" ;;
        2) provider="claude" ;;
        3) provider=$(read_input "请输入提供商名称") ;;
        *) print_error "无效选择"; press_any_key; return 1 ;;
    esac
    
    echo ""
    print_info "提供商: $provider"
    
    email=$(read_input "邮箱地址")
    account_id="account-$(date +%s)"
    
    print_info "正在调用 OpenClaw 认证流程..."
    echo ""
    
    if command -v openclaw &>/dev/null; then
        print_info "执行: openclaw auth add --provider $provider"
        
        if openclaw auth add --provider "$provider" 2>&1; then
            print_success "OAuth 认证成功!"
        else
            print_error "认证失败"
            press_any_key
            return 1
        fi
    else
        print_warning "未安装 openclaw"
        print_info "请手动完成 OAuth 认证"
        echo ""
        
        access_token=$(read_input "access_token")
        refresh_token=$(read_input "refresh_token")
        
        backup_oauth_config
        
        local new_account=$(jq -n \
            --arg id "$account_id" \
            --arg provider "$provider" \
            --arg email "$email" \
            --arg access_token "$access_token" \
            --arg refresh_token "$refresh_token" \
            '{
                id: $id,
                provider: $provider,
                email: $email,
                access_token: $access_token,
                refresh_token: $refresh_token,
                is_active: false,
                added_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            }')
        
        jq ".accounts += [$new_account]" "$OAUTH_CONFIG" > "${OAUTH_CONFIG}.tmp" && mv "${OAUTH_CONFIG}.tmp" "$OAUTH_CONFIG"
        
        print_success "账号已添加"
    fi
    
    echo ""
    print_info "账号 ID: $account_id"
    
    press_any_key
}

oauth_switch_account() {
    print_header
    oauth_list_accounts
    
    echo ""
    account_id=$(read_input "请输入要激活的账号 ID")
    
    if ! check_jq; then
        return 1
    fi
    
    backup_oauth_config
    
    jq --arg id "$account_id" '
        .accounts = (.accounts | map(
            if .id == $id then .is_active = true else .is_active = false end
        )) |
        .active_account_id = $id
    ' "$OAUTH_CONFIG" > "${OAUTH_CONFIG}.tmp" && mv "${OAUTH_CONFIG}.tmp" "$OAUTH_CONFIG"
    
    print_success "已切换到账号: $account_id"
    
    if pgrep -f "openclaw" &>/dev/null; then
        if confirm_action "是否重启 OpenClaw 服务以应用新配置?"; then
            pkill -f "openclaw"
            sleep 2
            print_info "请手动重启 OpenClaw"
        fi
    fi
    
    press_any_key
}

oauth_delete_account() {
    print_header
    oauth_list_accounts
    
    echo ""
    account_id=$(read_input "请输入要删除的账号 ID")
    
    if ! confirm_action "确定要删除账号 $account_id?"; then
        print_info "已取消"
        press_any_key
        return
    fi
    
    backup_oauth_config
    
    jq --arg id "$account_id" '.accounts = (.accounts | map(select(.id != $id)))' "$OAUTH_CONFIG" > "${OAUTH_CONFIG}.tmp" && mv "${OAUTH_CONFIG}.tmp" "$OAUTH_CONFIG"
    
    print_success "账号已删除"
    press_any_key
}

oauth_toggle_auto_switch() {
    if ! check_jq; then
        return 1
    fi
    
    local current=$(jq -r '.auto_switch' "$OAUTH_CONFIG" 2>/dev/null || echo "false")
    
    if [[ "$current" == "true" ]]; then
        jq '.auto_switch = false' "$OAUTH_CONFIG" > "${OAUTH_CONFIG}.tmp" && mv "${OAUTH_CONFIG}.tmp" "$OAUTH_CONFIG"
        print_success "已禁用自动切换"
    else
        jq '.auto_switch = true' "$OAUTH_CONFIG" > "${OAUTH_CONFIG}.tmp" && mv "${OAUTH_CONFIG}.tmp" "$OAUTH_CONFIG"
        print_success "已启用自动切换"
    fi
    
    press_any_key
}

menu_oauth() {
    while true; do
        print_header
        print_section "OAuth 账号管理"
        
        # 状态显示
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        if command -v jq &>/dev/null && [[ -f "$OAUTH_CONFIG" ]]; then
            local count=$(jq '.accounts | length' "$OAUTH_CONFIG" 2>/dev/null || echo "0")
            local auto=$(jq -r '.auto_switch' "$OAUTH_CONFIG" 2>/dev/null || echo "false")
            local active_id=$(jq -r '.active_account_id' "$OAUTH_CONFIG" 2>/dev/null || echo "")
            
            echo -e "  ${BLUE}📊 账号总数:${NC} ${WHITE}$count${NC} 个"
            if [[ "$auto" == "true" ]]; then
                echo -e "  ${BLUE}🔄 自动切换:${NC} ${GREEN}已启用${NC}"
            else
                echo -e "  ${BLUE}🔄 自动切换:${NC} ${YELLOW}已禁用${NC}"
            fi
            if [[ -n "$active_id" && "$active_id" != "null" ]]; then
                echo -e "  ${BLUE}✓ 活动账号:${NC} ${GREEN}$active_id${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ 未配置或 jq 未安装${NC}"
        fi
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo ""
        echo -e "${WHITE}${BOLD}  功能菜单${NC}\n"
        echo -e "    ${GREEN}1.${NC} 📋 查看所有账号"
        echo -e "    ${GREEN}2.${NC} ➕ 添加新账号"
        echo -e "    ${GREEN}3.${NC} 🔄 切换活动账号"
        echo -e "    ${GREEN}4.${NC} 🗑️  删除账号"
        echo -e "    ${GREEN}5.${NC} ⚙️  启用/禁用自动切换"
        echo -e "    ${GREEN}0.${NC} ⬅️  返回主菜单"
        echo ""
        echo -ne "  ${YELLOW}请输入选项 [0-5]:${NC} "
        
        choice=$(read_choice)
        
        case "$choice" in
            1) oauth_list_accounts ;;
            2) oauth_add_account ;;
            3) oauth_switch_account ;;
            4) oauth_delete_account ;;
            5) oauth_toggle_auto_switch ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ------------------------------
#  TG Bot 模块函数
# ------------------------------

tg_check_openclaw() {
    if ! command -v openclaw &>/dev/null; then
        print_error "未安装 OpenClaw"
        print_info "请先安装 OpenClaw"
        press_any_key
        return 1
    fi
    return 0
}

tg_approve_pairing() {
    print_header
    print_section "批准 Telegram 配对"
    
    if ! tg_check_openclaw; then
        return 1
    fi
    
    if openclaw pairing list telegram 2>/dev/null; then
        echo ""
    fi
    
    code=$(read_input "请输入配对码")
    
    if [[ -z "$code" ]]; then
        print_error "配对码不能为空"
        press_any_key
        return 1
    fi
    
    print_info "正在批准配对码: $code"
    echo ""
    
    if openclaw pairing approve telegram "$code" 2>&1; then
        echo ""
        print_success "配对成功!"
    else
        echo ""
        print_error "配对失败"
    fi
    
    press_any_key
}

tg_reject_pairing() {
    print_header
    print_section "拒绝 Telegram 配对"
    
    if ! tg_check_openclaw; then
        return 1
    fi
    
    code=$(read_input "请输入要拒绝的配对码")
    
    if [[ -z "$code" ]]; then
        print_error "配对码不能为空"
        press_any_key
        return 1
    fi
    
    if openclaw pairing reject telegram "$code" 2>&1; then
        print_success "已拒绝配对请求"
    else
        print_error "操作失败"
    fi
    
    press_any_key
}

tg_list_devices() {
    print_header
    print_section "Telegram 已连接设备"
    
    if ! tg_check_openclaw; then
        return 1
    fi
    
    if openclaw channels list 2>/dev/null | grep -i telegram; then
        echo ""
        print_success "以上是已连接的 Telegram 频道"
    else
        print_warning "未找到已连接的设备"
    fi
    
    press_any_key
}

tg_revoke_device() {
    print_header
    tg_list_devices
    
    echo ""
    device_id=$(read_input "请输入要撤销的设备 ID")
    
    if [[ -z "$device_id" ]]; then
        print_error "设备 ID 不能为空"
        press_any_key
        return 1
    fi
    
    if ! confirm_action "确定要撤销设备 $device_id?"; then
        print_info "已取消"
        press_any_key
        return
    fi
    
    if openclaw channels remove "$device_id" 2>&1; then
        print_success "设备连接已撤销"
    else
        print_error "操作失败"
    fi
    
    press_any_key
}

tg_show_status() {
    print_header
    print_section "Telegram 机器人状态"
    
    # OpenClaw 服务状态
    echo -e "${BLUE}OpenClaw 服务:${NC}"
    if pgrep -f "openclaw" &>/dev/null; then
        print_success "正在运行"
        echo -e "  PID: $(pgrep -f 'openclaw' | head -n 1)"
    else
        print_warning "未运行"
        echo -e "  ${YELLOW}提示: 运行 'openclaw' 启动服务${NC}"
    fi
    
    echo ""
    
    # Telegram 频道
    echo -e "${BLUE}Telegram 频道:${NC}"
    if command -v openclaw &>/dev/null; then
        local tg_count=$(openclaw channels list 2>/dev/null | grep -ic telegram || echo "0")
        if [[ "$tg_count" -gt 0 ]]; then
            print_success "$tg_count 个已连接"
        else
            print_warning "未连接"
        fi
    fi
    
    echo ""
    
    # 待批准配对
    echo -e "${BLUE}待批准配对:${NC}"
    if command -v openclaw &>/dev/null; then
        local pending=$(openclaw pairing list telegram 2>/dev/null | wc -l || echo "0")
        if [[ "$pending" -gt 0 ]]; then
            print_info "$pending 个待批准"
        else
            print_info "无"
        fi
    fi
    
    press_any_key
}

menu_telegram() {
    while true; do
        print_header
        print_section "Telegram 机器人管理"
        
        # 状态显示
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # OpenClaw 状态
        if pgrep -f "openclaw" &>/dev/null; then
            local pid=$(pgrep -f "openclaw" | head -n 1)
            echo -e "  ${GREEN}✓ OpenClaw 服务:${NC} ${GREEN}${BOLD}运行中${NC} (PID: $pid)"
        else
            echo -e "  ${RED}✗ OpenClaw 服务:${NC} ${RED}${BOLD}未运行${NC}"
            echo -e "  ${DIM}  提示: 运行 'openclaw' 启动服务${NC}"
        fi
        
        # TG 连接状态
        if command -v openclaw &>/dev/null; then
            local tg_count=$(openclaw channels list 2>/dev/null | grep -ic telegram || echo "0")
            if [[ "$tg_count" -gt 0 ]]; then
                echo -e "  ${BLUE}📱 TG 频道:${NC} ${GREEN}$tg_count 个已连接${NC}"
            else
                echo -e "  ${BLUE}📱 TG 频道:${NC} ${YELLOW}未连接${NC}"
            fi
            
            # 待批准数量
            local pending=$(openclaw pairing list telegram 2>/dev/null | wc -l || echo "0")
            if [[ "$pending" -gt 0 ]]; then
                echo -e "  ${BLUE}⏳ 待批准:${NC} ${YELLOW}$pending 个配对请求${NC}"
            else
                echo -e "  ${BLUE}⏳ 待批准:${NC} ${GREEN}无${NC}"
            fi
        fi
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo ""
        echo -e "${WHITE}${BOLD}  功能菜单${NC}\n"
        echo -e "    ${GREEN}1.${NC} ✅ 批准配对请求"
        echo -e "    ${GREEN}2.${NC} ❌ 拒绝配对请求"
        echo -e "    ${GREEN}3.${NC} 📋 查看已连接设备"
        echo -e "    ${GREEN}4.${NC} 🗑️  撤销设备连接"
        echo -e "    ${GREEN}5.${NC} 📊 查看机器人状态"
        echo -e "    ${GREEN}0.${NC} ⬅️  返回主菜单"
        echo ""
        echo -ne "  ${YELLOW}请输入选项 [0-5]:${NC} "
        
        choice=$(read_choice)
        
        case "$choice" in
            1) tg_approve_pairing ;;
            2) tg_reject_pairing ;;
            3) tg_list_devices ;;
            4) tg_revoke_device ;;
            5) tg_show_status ;;
            0) return ;;
            *) print_error "无效选项"; sleep 1 ;;
        esac
    done
}

# ============================================================================
# 卸载功能 - 检测函数
# ============================================================================

check_docker_components() {
    local found=0
    
    if command -v docker &> /dev/null; then
        local containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$containers" ]]; then
            FOUND_COMPONENTS+=("docker_containers")
            found=1
        fi
        
        local images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$images" ]]; then
            FOUND_COMPONENTS+=("docker_images")
            found=1
        fi
        
        local volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$volumes" ]]; then
            FOUND_COMPONENTS+=("docker_volumes")
            found=1
        fi
    fi
    
    return $found
}

check_npm_packages() {
    local found=0
    
    if command -v npm &> /dev/null; then
        local npm_global=$(npm list -g --depth=0 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$npm_global" ]]; then
            FOUND_COMPONENTS+=("npm_packages")
            found=1
        fi
    fi
    
    if command -v pnpm &> /dev/null; then
        local pnpm_global=$(pnpm list -g --depth=0 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$pnpm_global" ]]; then
            FOUND_COMPONENTS+=("pnpm_packages")
            found=1
        fi
    fi
    
    return $found
}

check_config_directories() {
    local found=0
    local dirs=(
        "$HOME/.openclaw"
        "$HOME/.clawdbot"
        "$HOME/.moltbot"
        "$HOME/openclaw"
        "$HOME/clawdbot"
        "$HOME/clawd"
        "${CLAWDBOT_STATE_DIR:-}"
        "${OPENCLAW_CONFIG_DIR:-}"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -n "$dir" && -d "$dir" ]]; then
            FOUND_COMPONENTS+=("config_dir:$dir")
            found=1
        fi
    done
    
    return $found
}

check_gateway_service() {
    local found=0
    
    if command -v systemctl &> /dev/null; then
        if systemctl list-units --type=service 2>/dev/null | grep -qiE 'openclaw|clawdbot'; then
            FOUND_COMPONENTS+=("systemd_service")
            found=1
        fi
        if systemctl list-unit-files --type=service 2>/dev/null | grep -qiE 'openclaw|clawdbot'; then
            FOUND_COMPONENTS+=("systemd_unit_file")
            found=1
        fi
    fi
    
    if pgrep -f 'openclaw|clawdbot' &> /dev/null; then
        FOUND_COMPONENTS+=("running_processes")
        found=1
    fi
    
    return $found
}

check_binary_files() {
    local found=0
    local paths=(
        "/usr/local/bin/openclaw"
        "/usr/local/bin/clawdbot"
        "/usr/bin/openclaw"
        "/usr/bin/clawdbot"
        "$HOME/.local/bin/openclaw"
        "$HOME/.local/bin/clawdbot"
    )
    
    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            FOUND_COMPONENTS+=("binary:$path")
            found=1
        fi
    done
    
    return $found
}

check_shell_config() {
    local found=0
    local shell_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.bash_profile"
        "$HOME/.profile"
    )
    
    for file in "${shell_files[@]}"; do
        if [[ -f "$file" ]] && grep -qiE 'openclaw|clawdbot' "$file" 2>/dev/null; then
            FOUND_COMPONENTS+=("shell_config:$file")
            found=1
        fi
    done
    
    return $found
}

# ============================================================================
# 卸载函数
# ============================================================================

uninstall_docker_components() {
    print_section "卸载 Docker 组件"
    
    if ! command -v docker &> /dev/null; then
        print_warning "未安装 Docker，跳过"
        return
    fi
    
    echo -e "  ${BLUE}正在查找容器...${NC}"
    local containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$containers" ]]; then
        echo "$containers" | while read -r container; do
            print_info "停止容器: $container"
            docker stop "$container" 2>/dev/null || true
            print_info "删除容器: $container"
            docker rm -f "$container" 2>/dev/null || true
            print_success "已删除容器: $container"
        done
        REMOVED_COMPONENTS+=("Docker 容器")
    else
        print_info "未找到相关容器"
    fi
    
    echo -e "\n  ${BLUE}正在查找镜像...${NC}"
    local images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$images" ]]; then
        echo "$images" | while read -r image; do
            print_info "删除镜像: $image"
            docker rmi -f "$image" 2>/dev/null || true
            print_success "已删除镜像: $image"
        done
        REMOVED_COMPONENTS+=("Docker 镜像")
    else
        print_info "未找到相关镜像"
    fi
    
    echo -e "\n  ${BLUE}正在查找数据卷...${NC}"
    local volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$volumes" ]]; then
        echo "$volumes" | while read -r volume; do
            print_info "删除数据卷: $volume"
            docker volume rm -f "$volume" 2>/dev/null || true
            print_success "已删除数据卷: $volume"
        done
        REMOVED_COMPONENTS+=("Docker 数据卷")
    else
        print_info "未找到相关数据卷"
    fi
    
    echo -e "\n  ${BLUE}正在查找网络...${NC}"
    local networks=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$networks" ]]; then
        echo "$networks" | while read -r network; do
            print_info "删除网络: $network"
            docker network rm "$network" 2>/dev/null || true
            print_success "已删除网络: $network"
        done
        REMOVED_COMPONENTS+=("Docker 网络")
    else
        print_info "未找到相关网络"
    fi
}

uninstall_npm_packages() {
    print_section "卸载 npm/pnpm 全局包"
    
    local packages=("openclaw" "clawdbot" "moltbot" "@openclaw/cli" "@clawdbot/cli")
    
    if command -v npm &> /dev/null; then
        echo -e "  ${BLUE}检查 npm 全局包...${NC}"
        for pkg in "${packages[@]}"; do
            if npm list -g "$pkg" &>/dev/null; then
                print_info "卸载 npm 包: $pkg"
                npm uninstall -g "$pkg" 2>/dev/null || true
                print_success "已卸载: $pkg"
                REMOVED_COMPONENTS+=("npm: $pkg")
            fi
        done
    else
        print_info "未安装 npm"
    fi
    
    if command -v pnpm &> /dev/null; then
        echo -e "\n  ${BLUE}检查 pnpm 全局包...${NC}"
        for pkg in "${packages[@]}"; do
            if pnpm list -g "$pkg" &>/dev/null; then
                print_info "卸载 pnpm 包: $pkg"
                pnpm remove -g "$pkg" 2>/dev/null || true
                print_success "已卸载: $pkg"
                REMOVED_COMPONENTS+=("pnpm: $pkg")
            fi
        done
    else
        print_info "未安装 pnpm"
    fi
    
    if command -v yarn &> /dev/null; then
        echo -e "\n  ${BLUE}检查 yarn 全局包...${NC}"
        for pkg in "${packages[@]}"; do
            if yarn global list 2>/dev/null | grep -q "$pkg"; then
                print_info "卸载 yarn 包: $pkg"
                yarn global remove "$pkg" 2>/dev/null || true
                print_success "已卸载: $pkg"
                REMOVED_COMPONENTS+=("yarn: $pkg")
            fi
        done
    else
        print_info "未安装 yarn"
    fi
}

uninstall_config_directories() {
    print_section "删除配置和数据目录"
    
    local dirs=(
        "$HOME/.openclaw"
        "$HOME/.clawdbot"
        "$HOME/.moltbot"
        "$HOME/openclaw"
        "$HOME/clawdbot"
        "$HOME/clawd"
    )
    
    [[ -n "${CLAWDBOT_STATE_DIR:-}" ]] && dirs+=("$CLAWDBOT_STATE_DIR")
    [[ -n "${OPENCLAW_CONFIG_DIR:-}" ]] && dirs+=("$OPENCLAW_CONFIG_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            print_found "发现目录: $dir (大小: $size)"
            
            if confirm_action "删除此目录?"; then
                rm -rf "$dir"
                print_success "已删除: $dir"
                REMOVED_COMPONENTS+=("目录: $dir")
            else
                print_warning "已跳过: $dir"
            fi
        fi
    done
}

uninstall_gateway_service() {
    print_section "停止并删除服务"
    
    if command -v clawdbot &> /dev/null; then
        print_info "尝试使用 clawdbot 命令停止服务..."
        clawdbot gateway stop 2>/dev/null || true
        clawdbot gateway uninstall 2>/dev/null || true
    fi
    
    if command -v openclaw &> /dev/null; then
        print_info "尝试使用 openclaw 命令停止服务..."
        openclaw gateway stop 2>/dev/null || true
        openclaw gateway uninstall 2>/dev/null || true
    fi
    
    if command -v systemctl &> /dev/null; then
        echo -e "\n  ${BLUE}检查 systemd 服务...${NC}"
        local services=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE 'openclaw|clawdbot' | awk '{print $1}' || true)
        
        for service in $services; do
            print_info "停止服务: $service"
            sudo systemctl stop "$service" 2>/dev/null || true
            print_info "禁用服务: $service"
            sudo systemctl disable "$service" 2>/dev/null || true
            print_success "已停止: $service"
            REMOVED_COMPONENTS+=("服务: $service")
        done
        
        local unit_files=(
            "/etc/systemd/system/openclaw.service"
            "/etc/systemd/system/clawdbot.service"
            "/etc/systemd/system/openclaw-gateway.service"
            "/etc/systemd/system/clawdbot-gateway.service"
            "/usr/lib/systemd/system/openclaw.service"
            "/usr/lib/systemd/system/clawdbot.service"
        )
        
        for file in "${unit_files[@]}"; do
            if [[ -f "$file" ]]; then
                print_info "删除服务文件: $file"
                sudo rm -f "$file" 2>/dev/null || true
                print_success "已删除: $file"
            fi
        done
        
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
    
    echo -e "\n  ${BLUE}检查运行中的进程...${NC}"
    local pids=$(pgrep -f 'openclaw|clawdbot' 2>/dev/null || true)
    
    if [[ -n "$pids" ]]; then
        print_warning "发现以下进程仍在运行:"
        ps aux | grep -E 'openclaw|clawdbot' | grep -v grep
        
        if confirm_action "强制终止这些进程?"; then
            echo "$pids" | xargs -r kill -9 2>/dev/null || true
            print_success "已终止所有相关进程"
            REMOVED_COMPONENTS+=("运行中的进程")
        fi
    else
        print_info "没有运行中的相关进程"
    fi
}

uninstall_binary_files() {
    print_section "删除可执行文件"
    
    local paths=(
        "/usr/local/bin/openclaw"
        "/usr/local/bin/clawdbot"
        "/usr/local/bin/moltbot"
        "/usr/bin/openclaw"
        "/usr/bin/clawdbot"
        "/usr/bin/moltbot"
        "$HOME/.local/bin/openclaw"
        "$HOME/.local/bin/clawdbot"
        "$HOME/.local/bin/moltbot"
    )
    
    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            print_found "发现可执行文件: $path"
            
            if [[ "$path" == /usr/* ]]; then
                sudo rm -f "$path" 2>/dev/null && print_success "已删除: $path" || print_error "删除失败: $path"
            else
                rm -f "$path" 2>/dev/null && print_success "已删除: $path" || print_error "删除失败: $path"
            fi
            REMOVED_COMPONENTS+=("二进制: $path")
        fi
    done
}

clean_shell_config() {
    print_section "清理 Shell 配置"
    
    local shell_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.bash_profile"
        "$HOME/.profile"
    )
    
    for file in "${shell_files[@]}"; do
        if [[ -f "$file" ]] && grep -qiE 'openclaw|clawdbot' "$file" 2>/dev/null; then
            print_found "发现配置文件: $file"
            echo -e "  ${DIM}包含以下相关行:${NC}"
            grep -n -iE 'openclaw|clawdbot' "$file" | while read -r line; do
                echo -e "    ${DIM}$line${NC}"
            done
            
            if confirm_action "从此文件中删除相关配置?"; then
                cp "$file" "${file}.bak.$(date +%Y%m%d_%H%M%S)"
                sed -i.tmp '/[Oo]pen[Cc]law\|[Cc]lawd[Bb]ot\|[Mm]olt[Bb]ot/d' "$file"
                rm -f "${file}.tmp"
                print_success "已清理: $file (备份已保存)"
                REMOVED_COMPONENTS+=("Shell配置: $file")
            fi
        fi
    done
}

clean_cache_and_temp() {
    print_section "清理缓存和临时文件"
    
    local cache_dirs=(
        "$HOME/.cache/openclaw"
        "$HOME/.cache/clawdbot"
        "/tmp/openclaw-*"
        "/tmp/clawdbot-*"
    )
    
    for pattern in "${cache_dirs[@]}"; do
        for dir in $pattern; do
            if [[ -e "$dir" ]]; then
                print_found "发现缓存: $dir"
                rm -rf "$dir" 2>/dev/null && print_success "已删除: $dir" || print_warning "删除失败: $dir"
            fi
        done
    done
    
    if command -v npm &> /dev/null; then
        print_info "清理 npm 缓存..."
        npm cache clean --force 2>/dev/null || true
    fi
}

# ============================================================================
# 菜单函数
# ============================================================================

show_scan_results() {
    print_section "扫描结果"
    
    if [[ ${#FOUND_COMPONENTS[@]} -eq 0 ]]; then
        print_success "未发现任何 OpenClaw/ClawdBot 相关组件"
        print_info "系统已经是干净的!"
        return 1
    fi
    
    echo -e "  ${YELLOW}发现以下组件:${NC}\n"
    
    local count=1
    for component in "${FOUND_COMPONENTS[@]}"; do
        case "$component" in
            docker_containers) print_found "$count. Docker 容器" ;;
            docker_images) print_found "$count. Docker 镜像" ;;
            docker_volumes) print_found "$count. Docker 数据卷" ;;
            npm_packages) print_found "$count. npm 全局包" ;;
            pnpm_packages) print_found "$count. pnpm 全局包" ;;
            config_dir:*) print_found "$count. 配置目录: ${component#config_dir:}" ;;
            systemd_service) print_found "$count. systemd 服务" ;;
            systemd_unit_file) print_found "$count. systemd 单元文件" ;;
            running_processes) print_found "$count. 运行中的进程" ;;
            binary:*) print_found "$count. 可执行文件: ${component#binary:}" ;;
            shell_config:*) print_found "$count. Shell 配置: ${component#shell_config:}" ;;
            *) print_found "$count. $component" ;;
        esac
        ((count++))
    done
    
    echo ""
    return 0
}

show_main_menu() {
    print_header
    
    # 显示当前状态 - 更紧凑
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if command -v openclaw &>/dev/null; then
        local version=$(openclaw --version 2>/dev/null | head -n 1 || echo "未知")
        echo -e "  ${GREEN}● OpenClaw:${NC} 已安装 ($version)"
    else
        echo -e "  ${YELLOW}○ OpenClaw:${NC} 未安装"
    fi
    
    # OAuth 状态
    if [[ -f "$OAUTH_CONFIG" ]] && command -v jq &>/dev/null 2>&1; then
        local account_count=$(jq '.accounts | length' "$OAUTH_CONFIG" 2>/dev/null || echo "0")
        local auto_switch=$(jq -r '.auto_switch' "$OAUTH_CONFIG" 2>/dev/null || echo "false")
        if [[ "$auto_switch" == "true" ]]; then
            echo -e "  ${BLUE}○ OAuth:${NC} $account_count 个账号 (自动切换)"
        else
            echo -e "  ${BLUE}○ OAuth:${NC} $account_count 个账号"
        fi
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo ""
    echo -e "${WHITE}【安装/更新】${NC} ${GREEN}1${NC}.安装OpenClaw  ${WHITE}【OAuth】${NC} ${GREEN}5${NC}.账号管理  ${WHITE}【其他】${NC} ${GREEN}7${NC}.日志 ${GREEN}8${NC}.帮助"
    echo -e "${WHITE}【卸载管理】${NC} ${GREEN}2${NC}.扫描 ${GREEN}3${NC}.完整卸载 ${GREEN}4${NC}.选择性  ${WHITE}【TG Bot】${NC} ${GREEN}6${NC}.机器人  ${WHITE}【退出】${NC} ${GREEN}0${NC}.Exit"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-8]: "
}
}

show_selective_menu() {
    print_header
    
    echo -e "${WHITE}  选择要卸载的组件:${NC}\n"
    echo -e "    ${GREEN}1.${NC} Docker 组件 (容器、镜像、卷)"
    echo -e "    ${GREEN}2.${NC} npm/pnpm 全局包"
    echo -e "    ${GREEN}3.${NC} 配置和数据目录"
    echo -e "    ${GREEN}4.${NC} 系统服务 (Gateway)"
    echo -e "    ${GREEN}5.${NC} 可执行文件"
    echo -e "    ${GREEN}6.${NC} Shell 配置清理"
    echo -e "    ${GREEN}7.${NC} 缓存和临时文件"
    echo -e "    ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}请输入选项 [0-7]:${NC} "
}

show_help() {
    print_header
    print_section "帮助信息"
    
    echo -e "  ${WHITE}${BOLD}关于此工具${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  OpenClaw 完整管理工具 v${SCRIPT_VERSION}"
    echo -e "  提供安装、卸载、OAuth 管理和 TG 机器人对接功能"
    echo ""
    echo -e "  ${WHITE}${BOLD}主要功能${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  ${GREEN}1. 安装/更新${NC} - 支持官方脚本/npm/Git 三种方式"
    echo -e "  ${GREEN}2-4. 卸载管理${NC} - 完整或选择性卸载所有组件"
    echo -e "  ${GREEN}5. OAuth 管理${NC} - 多账号管理与自动切换"
    echo -e "  ${GREEN}6. TG 机器人${NC} - 配对码批准与设备管理"
    echo ""
    echo -e "  ${WHITE}${BOLD}支持的组件${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  - Docker 容器、镜像和数据卷"
    echo -e "  - npm/pnpm/yarn 全局安装的包"
    echo -e "  - 配置目录 (~/.openclaw, ~/.clawdbot 等)"
    echo -e "  - OAuth 账号配置与自动切换"
    echo -e "  - Telegram 机器人配对"
    echo -e "  - Gateway 系统服务"
    echo -e "  - CLI 可执行文件"
    echo ""
    echo -e "  ${WHITE}${BOLD}快速开始${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  ${WHITE}新用户:${NC}"
    echo -e "    1) 选择 ${GREEN}1. 安装/更新 OpenClaw${NC}"
    echo -e "    2) 选择 ${GREEN}5. OAuth 账号管理${NC} → 添加账号"
    echo -e "    3) 选择 ${GREEN}6. Telegram 机器人${NC} → 批准配对"
    echo ""
    echo -e "  ${WHITE}卸载:${NC}"
    echo -e "    1) 选择 ${GREEN}2. 扫描已安装组件${NC} (查看)"
    echo -e "    2) 选择 ${GREEN}3. 一键完整卸载${NC} (或 4. 选择性卸载)"
    echo ""
    echo -e "  ${WHITE}${BOLD}文件位置${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  配置: ~/.openclaw/credentials/oauth.json"
    echo -e "  备份: ~/.openclaw/backups/"
    echo -e "  日志: $LOG_FILE"
    echo ""
    
    press_any_key
}

run_full_uninstall() {
    print_header
    print_section "一键完整卸载"
    
    echo -e "  ${RED}${BOLD}!! 警告 !!${NC}"
    echo -e "  此操作将删除所有 OpenClaw/ClawdBot 相关组件"
    echo -e "  包括配置文件、数据和工作区内容"
    echo ""
    
    if ! confirm_action "确定要继续吗?" "n"; then
        print_info "操作已取消"
        press_any_key
        return
    fi
    
    echo ""
    
    uninstall_gateway_service
    uninstall_docker_components
    uninstall_npm_packages
    uninstall_binary_files
    uninstall_config_directories
    clean_shell_config
    clean_cache_and_temp
    
    print_section "卸载完成"
    
    if [[ ${#REMOVED_COMPONENTS[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}已成功删除以下组件:${NC}\n"
        for component in "${REMOVED_COMPONENTS[@]}"; do
            echo -e "    ${GREEN}[OK]${NC} $component"
        done
    else
        print_info "没有删除任何组件"
    fi
    
    echo ""
    print_success "OpenClaw 已完全卸载!"
    print_info "日志已保存到: $LOG_FILE"
    
    press_any_key
}

run_scan() {
    print_header
    print_section "正在扫描系统..."
    
    FOUND_COMPONENTS=()
    
    echo -e "  ${BLUE}检查 Docker 组件...${NC}"
    check_docker_components || true
    
    echo -e "  ${BLUE}检查 npm/pnpm 包...${NC}"
    check_npm_packages || true
    
    echo -e "  ${BLUE}检查配置目录...${NC}"
    check_config_directories || true
    
    echo -e "  ${BLUE}检查 Gateway 服务...${NC}"
    check_gateway_service || true
    
    echo -e "  ${BLUE}检查可执行文件...${NC}"
    check_binary_files || true
    
    echo -e "  ${BLUE}检查 Shell 配置...${NC}"
    check_shell_config || true
    
    echo ""
    show_scan_results
    
    press_any_key
}

view_log() {
    print_header
    print_section "卸载日志"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "  ${WHITE}日志文件: $LOG_FILE${NC}\n"
        echo -e "${DIM}"
        tail -50 "$LOG_FILE"
        echo -e "${NC}"
    else
        print_info "暂无日志记录"
    fi
    
    press_any_key
}

# ============================================================================
# 主循环
# ============================================================================

main_loop() {
    while true; do
        show_main_menu
        choice=$(read_choice)
        
        case "$choice" in
            1)
                # 安装/更新 OpenClaw
                menu_install
                ;;
            2)
                # 扫描已安装组件
                run_scan
                ;;
            3)
                # 一键完整卸载
                run_full_uninstall
                ;;
            4)
                # 选择性卸载
                while true; do
                    show_selective_menu
                    sub_choice=$(read_choice)
                    
                    case "$sub_choice" in
                        1) print_header; uninstall_docker_components; press_any_key ;;
                        2) print_header; uninstall_npm_packages; press_any_key ;;
                        3) print_header; uninstall_config_directories; press_any_key ;;
                        4) print_header; uninstall_gateway_service; press_any_key ;;
                        5) print_header; uninstall_binary_files; press_any_key ;;
                        6) print_header; clean_shell_config; press_any_key ;;
                        7) print_header; clean_cache_and_temp; press_any_key ;;
                        0) break ;;
                        *) print_error "无效选项"; sleep 1 ;;
                    esac
                done
                ;;
            5)
                # OAuth 账号管理
                menu_oauth
                ;;
            6)
                # Telegram 机器人管理
                menu_telegram
                ;;
            7)
                # 查看日志
                view_log
                ;;
            8)
                # 帮助信息
                show_help
                ;;
            0)
                # 退出
                print_header
                echo -e "  ${GREEN}感谢使用 OpenClaw 管理工具!${NC}"
                echo -e "  ${DIM}再见!${NC}\n"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# 命令行参数
# ============================================================================

show_usage() {
    echo "OpenClaw 完整管理工具 v${SCRIPT_VERSION}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help      显示此帮助信息"
    echo "  -y, --yes       自动确认所有操作 (卸载模式)"
    echo "  -s, --scan      仅扫描已安装组件"
    echo "  --version       显示版本信息"
    echo ""
    echo "示例:"
    echo "  $0              启动交互式菜单 (推荐)"
    echo "  $0 -y           自动完整卸载"
    echo "  $0 -s           仅扫描组件"
    echo ""
    echo "功能:"
    echo "  • 安装/更新 OpenClaw"
    echo "  • 完整或选择性卸载"
    echo "  • OAuth 多账号管理"
    echo "  • Telegram 机器人配对"
}

AUTO_YES=false
SCAN_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -s|--scan)
            SCAN_ONLY=true
            shift
            ;;
        --version)
            echo "OpenClaw 管理工具 v$SCRIPT_VERSION"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
done

if $AUTO_YES; then
    confirm_action() {
        echo -e "  ${YELLOW}[?]${NC} $1 [自动确认]"
        return 0
    }
fi

# ============================================================================
# 主入口
# ============================================================================

if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}[!] 检测到以 root 身份运行${NC}"
    echo -e "${YELLOW}    建议使用普通用户运行此脚本，需要时会自动请求 sudo 权限${NC}"
    echo ""
fi

log "=== OpenClaw 管理工具 v$SCRIPT_VERSION 启动 ==="
log "用户: $(whoami), Home: $HOME"

if $SCAN_ONLY; then
    run_scan
    exit 0
fi

if $AUTO_YES; then
    print_header
    run_full_uninstall
    exit 0
fi

main_loop
