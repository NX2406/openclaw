#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    OpenClaw / ClawdBot 一键卸载脚本                        ║
# ║                         Version: 1.0.0                                    ║
# ║                    支持多种安装方式的完整卸载                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/openclaw-uninstaller/main/uninstall.sh | bash
#   或者下载后执行: bash uninstall.sh
#
# 支持的卸载项目:
#   - Docker 容器和镜像
#   - npm/pnpm 全局包
#   - 配置文件和数据目录
#   - Gateway 服务
#   - 工作区文件

set -e

# ═══════════════════════════════════════════════════════════════════════════
# 颜色定义
# ═══════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# ═══════════════════════════════════════════════════════════════════════════
# 全局变量
# ═══════════════════════════════════════════════════════════════════════════
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/openclaw-uninstall-$(date +%Y%m%d_%H%M%S).log"
FOUND_COMPONENTS=()
REMOVED_COMPONENTS=()

# ═══════════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                       ║"
    echo "║   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗██╗      █████╗ ██╗    ██╗║"
    echo "║  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║     ██╔══██╗██║    ██║║"
    echo "║  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║     ███████║██║ █╗ ██║║"
    echo "║  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║     ██╔══██║██║███╗██║║"
    echo "║  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗███████╗██║  ██║╚███╔███╔╝║"
    echo "║   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ║"
    echo "║                                                                       ║"
    echo "║                    🧹 一键卸载工具 v${SCRIPT_VERSION}                         ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    log "WARNING: $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
    log "ERROR: $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
    log "INFO: $1"
}

print_found() {
    echo -e "  ${PURPLE}►${NC} $1"
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    echo -ne "  ${YELLOW}?${NC} $prompt"
    read -r response
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

press_any_key() {
    echo ""
    echo -ne "  ${DIM}按任意键继续...${NC}"
    read -n 1 -s
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# 检测函数
# ═══════════════════════════════════════════════════════════════════════════

check_docker_components() {
    local found=0
    
    if command -v docker &> /dev/null; then
        # 检查 OpenClaw 相关容器
        local containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$containers" ]]; then
            FOUND_COMPONENTS+=("docker_containers")
            found=1
        fi
        
        # 检查相关镜像
        local images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
        if [[ -n "$images" ]]; then
            FOUND_COMPONENTS+=("docker_images")
            found=1
        fi
        
        # 检查相关卷
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
    
    # 检查 systemd 服务
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
    
    # 检查运行中的进程
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

# ═══════════════════════════════════════════════════════════════════════════
# 卸载函数
# ═══════════════════════════════════════════════════════════════════════════

uninstall_docker_components() {
    print_section "卸载 Docker 组件"
    
    if ! command -v docker &> /dev/null; then
        print_warning "未安装 Docker，跳过此步骤"
        return
    fi
    
    # 停止并删除容器
    echo -e "  ${BLUE}正在查找相关容器...${NC}"
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
    
    # 删除镜像
    echo -e "\n  ${BLUE}正在查找相关镜像...${NC}"
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
    
    # 删除卷
    echo -e "\n  ${BLUE}正在查找相关数据卷...${NC}"
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
    
    # 清理网络
    echo -e "\n  ${BLUE}正在查找相关网络...${NC}"
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
    
    # npm 卸载
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
    
    # pnpm 卸载
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
    
    # yarn 卸载
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
    
    # 添加环境变量指定的目录
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
    
    # 尝试使用内置命令停止
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
    
    # 停止 systemd 服务
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
        
        # 删除服务文件
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
    
    # 终止相关进程
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
                # 创建备份
                cp "$file" "${file}.bak.$(date +%Y%m%d_%H%M%S)"
                # 删除相关行
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
        # 使用 glob 展开
        for dir in $pattern; do
            if [[ -e "$dir" ]]; then
                print_found "发现缓存: $dir"
                rm -rf "$dir" 2>/dev/null && print_success "已删除: $dir" || print_warning "删除失败: $dir"
            fi
        done
    done
    
    # 清理 npm 缓存中的相关内容
    if command -v npm &> /dev/null; then
        print_info "清理 npm 缓存..."
        npm cache clean --force 2>/dev/null || true
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 菜单函数
# ═══════════════════════════════════════════════════════════════════════════

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
    
    echo -e "${WHITE}  请选择操作:${NC}\n"
    echo -e "    ${GREEN}1.${NC} 🔍 扫描系统 - 查找已安装的组件"
    echo -e "    ${GREEN}2.${NC} 🚀 一键完整卸载 - 删除所有组件"
    echo -e "    ${GREEN}3.${NC} 📋 选择性卸载 - 自定义卸载项目"
    echo -e "    ${GREEN}4.${NC} 📊 查看卸载日志"
    echo -e "    ${GREEN}5.${NC} ❓ 帮助信息"
    echo -e "    ${GREEN}0.${NC} 🚪 退出"
    echo ""
    echo -ne "  ${YELLOW}请输入选项 [0-5]:${NC} "
}

show_selective_menu() {
    print_header
    
    echo -e "${WHITE}  选择要卸载的组件:${NC}\n"
    echo -e "    ${GREEN}1.${NC} 🐳 Docker 组件 (容器、镜像、卷)"
    echo -e "    ${GREEN}2.${NC} 📦 npm/pnpm 全局包"
    echo -e "    ${GREEN}3.${NC} 📁 配置和数据目录"
    echo -e "    ${GREEN}4.${NC} ⚙️  系统服务 (Gateway)"
    echo -e "    ${GREEN}5.${NC} 🔧 可执行文件"
    echo -e "    ${GREEN}6.${NC} 📝 Shell 配置清理"
    echo -e "    ${GREEN}7.${NC} 🗑️  缓存和临时文件"
    echo -e "    ${GREEN}0.${NC} ↩️  返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}请输入选项 [0-7]:${NC} "
}

show_help() {
    print_header
    print_section "帮助信息"
    
    echo -e "  ${WHITE}${BOLD}关于此脚本${NC}"
    echo -e "  ─────────────────────────────────────────────────────"
    echo -e "  此脚本用于完整卸载 OpenClaw (原名 ClawdBot/Moltbot)"
    echo -e "  支持多种安装方式，包括 Docker、npm、源码安装等。"
    echo ""
    echo -e "  ${WHITE}${BOLD}支持的组件${NC}"
    echo -e "  ─────────────────────────────────────────────────────"
    echo -e "  • Docker 容器、镜像和数据卷"
    echo -e "  • npm/pnpm/yarn 全局安装的包"
    echo -e "  • 配置目录 (~/.openclaw, ~/.clawdbot 等)"
    echo -e "  • 工作区目录 (~/openclaw, ~/clawd 等)"
    echo -e "  • Gateway 系统服务"
    echo -e "  • CLI 可执行文件"
    echo -e "  • Shell 配置中的环境变量"
    echo ""
    echo -e "  ${WHITE}${BOLD}使用建议${NC}"
    echo -e "  ─────────────────────────────────────────────────────"
    echo -e "  1. 首先运行${GREEN}扫描系统${NC}查看已安装的组件"
    echo -e "  2. 如需完全清理，选择${GREEN}一键完整卸载${NC}"
    echo -e "  3. 如只需删除特定组件，使用${GREEN}选择性卸载${NC}"
    echo ""
    echo -e "  ${WHITE}${BOLD}日志位置${NC}"
    echo -e "  ─────────────────────────────────────────────────────"
    echo -e "  $LOG_FILE"
    echo ""
    
    press_any_key
}

run_full_uninstall() {
    print_header
    print_section "一键完整卸载"
    
    echo -e "  ${RED}${BOLD}⚠️  警告${NC}"
    echo -e "  此操作将删除所有 OpenClaw/ClawdBot 相关组件"
    echo -e "  包括配置文件、数据和工作区内容"
    echo ""
    
    if ! confirm_action "确定要继续吗?" "n"; then
        print_info "操作已取消"
        press_any_key
        return
    fi
    
    echo ""
    
    # 按顺序执行所有卸载步骤
    uninstall_gateway_service
    uninstall_docker_components
    uninstall_npm_packages
    uninstall_binary_files
    uninstall_config_directories
    clean_shell_config
    clean_cache_and_temp
    
    # 显示卸载总结
    print_section "卸载完成"
    
    if [[ ${#REMOVED_COMPONENTS[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}已成功删除以下组件:${NC}\n"
        for component in "${REMOVED_COMPONENTS[@]}"; do
            echo -e "    ${GREEN}✓${NC} $component"
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

# ═══════════════════════════════════════════════════════════════════════════
# 主循环
# ═══════════════════════════════════════════════════════════════════════════

main_loop() {
    while true; do
        show_main_menu
        read -r choice
        
        case "$choice" in
            1)
                run_scan
                ;;
            2)
                run_full_uninstall
                ;;
            3)
                while true; do
                    show_selective_menu
                    read -r sub_choice
                    
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
            4)
                view_log
                ;;
            5)
                show_help
                ;;
            0)
                print_header
                echo -e "  ${GREEN}感谢使用 OpenClaw 卸载工具!${NC}"
                echo -e "  ${DIM}Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# 命令行参数处理
# ═══════════════════════════════════════════════════════════════════════════

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      显示此帮助信息"
    echo "  -y, --yes       自动确认所有操作 (非交互模式)"
    echo "  -s, --scan      仅扫描,不执行卸载"
    echo "  --version       显示版本信息"
    echo ""
    echo "示例:"
    echo "  $0              启动交互式菜单"
    echo "  $0 -y           自动完整卸载"
    echo "  $0 -s           仅扫描已安装组件"
}

# 参数解析
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
            echo "OpenClaw Uninstaller v$SCRIPT_VERSION"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 重写 confirm_action 函数以支持自动模式
if $AUTO_YES; then
    confirm_action() {
        echo -e "  ${YELLOW}?${NC} $1 [自动确认]"
        return 0
    }
fi

# ═══════════════════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════════════════

# 检查是否为 root (某些操作可能需要)
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}⚠ 检测到以 root 身份运行${NC}"
    echo -e "${YELLOW}  建议使用普通用户运行此脚本，需要时会自动请求 sudo 权限${NC}"
    echo ""
fi

# 初始化日志
log "=== OpenClaw Uninstaller v$SCRIPT_VERSION started ==="
log "User: $(whoami), Home: $HOME"

if $SCAN_ONLY; then
    run_scan
    exit 0
fi

if $AUTO_YES; then
    print_header
    run_full_uninstall
    exit 0
fi

# 启动交互式菜单
main_loop
