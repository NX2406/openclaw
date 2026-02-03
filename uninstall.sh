#!/bin/bash
# ============================================================================
#                    OpenClaw / ClawdBot Uninstall Script
#                         Version: 1.0.0
#                    Complete Uninstaller with Menu
# ============================================================================
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/openclaw-uninstaller/main/uninstall.sh | bash
#   Or download and run: bash uninstall.sh
#
# Supported components:
#   - Docker containers and images
#   - npm/pnpm global packages
#   - Config files and data directories
#   - Gateway service
#   - Workspace files

set -e

# ============================================================================
# Color Definitions
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
# Global Variables
# ============================================================================
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/openclaw-uninstall-$(date +%Y%m%d_%H%M%S).log"
FOUND_COMPONENTS=()
REMOVED_COMPONENTS=()

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${PURPLE}"
    echo "============================================================================"
    echo "                                                                            "
    echo "     ___  ____  _____ _   _  ____  _        ___        __                   "
    echo "    / _ \|  _ \| ____| \ | |/ ___|| |      / \ \      / /                   "
    echo "   | | | | |_) |  _| |  \| | |    | |     / _ \ \ /\ / /                    "
    echo "   | |_| |  __/| |___| |\  | |___ | |___ / ___ \ V  V /                     "
    echo "    \___/|_|   |_____|_| \_|\____||_____/_/   \_\_/\_/                      "
    echo "                                                                            "
    echo "                    Uninstall Tool v${SCRIPT_VERSION}                       "
    echo "                                                                            "
    echo "============================================================================"
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
    read -r response
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

press_any_key() {
    echo ""
    echo -ne "  ${DIM}Press any key to continue...${NC}"
    read -n 1 -s
    echo ""
}

# ============================================================================
# Detection Functions
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
# Uninstall Functions
# ============================================================================

uninstall_docker_components() {
    print_section "Uninstall Docker Components"
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not installed, skipping"
        return
    fi
    
    echo -e "  ${BLUE}Searching for containers...${NC}"
    local containers=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$containers" ]]; then
        echo "$containers" | while read -r container; do
            print_info "Stopping container: $container"
            docker stop "$container" 2>/dev/null || true
            print_info "Removing container: $container"
            docker rm -f "$container" 2>/dev/null || true
            print_success "Removed container: $container"
        done
        REMOVED_COMPONENTS+=("Docker containers")
    else
        print_info "No related containers found"
    fi
    
    echo -e "\n  ${BLUE}Searching for images...${NC}"
    local images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$images" ]]; then
        echo "$images" | while read -r image; do
            print_info "Removing image: $image"
            docker rmi -f "$image" 2>/dev/null || true
            print_success "Removed image: $image"
        done
        REMOVED_COMPONENTS+=("Docker images")
    else
        print_info "No related images found"
    fi
    
    echo -e "\n  ${BLUE}Searching for volumes...${NC}"
    local volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$volumes" ]]; then
        echo "$volumes" | while read -r volume; do
            print_info "Removing volume: $volume"
            docker volume rm -f "$volume" 2>/dev/null || true
            print_success "Removed volume: $volume"
        done
        REMOVED_COMPONENTS+=("Docker volumes")
    else
        print_info "No related volumes found"
    fi
    
    echo -e "\n  ${BLUE}Searching for networks...${NC}"
    local networks=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -iE 'openclaw|clawdbot|moltbot' || true)
    
    if [[ -n "$networks" ]]; then
        echo "$networks" | while read -r network; do
            print_info "Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
            print_success "Removed network: $network"
        done
        REMOVED_COMPONENTS+=("Docker networks")
    else
        print_info "No related networks found"
    fi
}

uninstall_npm_packages() {
    print_section "Uninstall npm/pnpm Packages"
    
    local packages=("openclaw" "clawdbot" "moltbot" "@openclaw/cli" "@clawdbot/cli")
    
    if command -v npm &> /dev/null; then
        echo -e "  ${BLUE}Checking npm global packages...${NC}"
        for pkg in "${packages[@]}"; do
            if npm list -g "$pkg" &>/dev/null; then
                print_info "Uninstalling npm package: $pkg"
                npm uninstall -g "$pkg" 2>/dev/null || true
                print_success "Uninstalled: $pkg"
                REMOVED_COMPONENTS+=("npm: $pkg")
            fi
        done
    else
        print_info "npm not installed"
    fi
    
    if command -v pnpm &> /dev/null; then
        echo -e "\n  ${BLUE}Checking pnpm global packages...${NC}"
        for pkg in "${packages[@]}"; do
            if pnpm list -g "$pkg" &>/dev/null; then
                print_info "Uninstalling pnpm package: $pkg"
                pnpm remove -g "$pkg" 2>/dev/null || true
                print_success "Uninstalled: $pkg"
                REMOVED_COMPONENTS+=("pnpm: $pkg")
            fi
        done
    else
        print_info "pnpm not installed"
    fi
    
    if command -v yarn &> /dev/null; then
        echo -e "\n  ${BLUE}Checking yarn global packages...${NC}"
        for pkg in "${packages[@]}"; do
            if yarn global list 2>/dev/null | grep -q "$pkg"; then
                print_info "Uninstalling yarn package: $pkg"
                yarn global remove "$pkg" 2>/dev/null || true
                print_success "Uninstalled: $pkg"
                REMOVED_COMPONENTS+=("yarn: $pkg")
            fi
        done
    else
        print_info "yarn not installed"
    fi
}

uninstall_config_directories() {
    print_section "Remove Config and Data Directories"
    
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
            print_found "Found directory: $dir (Size: $size)"
            
            if confirm_action "Delete this directory?"; then
                rm -rf "$dir"
                print_success "Deleted: $dir"
                REMOVED_COMPONENTS+=("Directory: $dir")
            else
                print_warning "Skipped: $dir"
            fi
        fi
    done
}

uninstall_gateway_service() {
    print_section "Stop and Remove Services"
    
    if command -v clawdbot &> /dev/null; then
        print_info "Trying to stop service via clawdbot command..."
        clawdbot gateway stop 2>/dev/null || true
        clawdbot gateway uninstall 2>/dev/null || true
    fi
    
    if command -v openclaw &> /dev/null; then
        print_info "Trying to stop service via openclaw command..."
        openclaw gateway stop 2>/dev/null || true
        openclaw gateway uninstall 2>/dev/null || true
    fi
    
    if command -v systemctl &> /dev/null; then
        echo -e "\n  ${BLUE}Checking systemd services...${NC}"
        local services=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE 'openclaw|clawdbot' | awk '{print $1}' || true)
        
        for service in $services; do
            print_info "Stopping service: $service"
            sudo systemctl stop "$service" 2>/dev/null || true
            print_info "Disabling service: $service"
            sudo systemctl disable "$service" 2>/dev/null || true
            print_success "Stopped: $service"
            REMOVED_COMPONENTS+=("Service: $service")
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
                print_info "Removing service file: $file"
                sudo rm -f "$file" 2>/dev/null || true
                print_success "Removed: $file"
            fi
        done
        
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
    
    echo -e "\n  ${BLUE}Checking running processes...${NC}"
    local pids=$(pgrep -f 'openclaw|clawdbot' 2>/dev/null || true)
    
    if [[ -n "$pids" ]]; then
        print_warning "Found running processes:"
        ps aux | grep -E 'openclaw|clawdbot' | grep -v grep
        
        if confirm_action "Force kill these processes?"; then
            echo "$pids" | xargs -r kill -9 2>/dev/null || true
            print_success "All related processes terminated"
            REMOVED_COMPONENTS+=("Running processes")
        fi
    else
        print_info "No running processes found"
    fi
}

uninstall_binary_files() {
    print_section "Remove Binary Files"
    
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
            print_found "Found binary: $path"
            
            if [[ "$path" == /usr/* ]]; then
                sudo rm -f "$path" 2>/dev/null && print_success "Removed: $path" || print_error "Failed to remove: $path"
            else
                rm -f "$path" 2>/dev/null && print_success "Removed: $path" || print_error "Failed to remove: $path"
            fi
            REMOVED_COMPONENTS+=("Binary: $path")
        fi
    done
}

clean_shell_config() {
    print_section "Clean Shell Configuration"
    
    local shell_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.bash_profile"
        "$HOME/.profile"
    )
    
    for file in "${shell_files[@]}"; do
        if [[ -f "$file" ]] && grep -qiE 'openclaw|clawdbot' "$file" 2>/dev/null; then
            print_found "Found config file: $file"
            echo -e "  ${DIM}Contains these related lines:${NC}"
            grep -n -iE 'openclaw|clawdbot' "$file" | while read -r line; do
                echo -e "    ${DIM}$line${NC}"
            done
            
            if confirm_action "Remove related config from this file?"; then
                cp "$file" "${file}.bak.$(date +%Y%m%d_%H%M%S)"
                sed -i.tmp '/[Oo]pen[Cc]law\|[Cc]lawd[Bb]ot\|[Mm]olt[Bb]ot/d' "$file"
                rm -f "${file}.tmp"
                print_success "Cleaned: $file (backup saved)"
                REMOVED_COMPONENTS+=("Shell config: $file")
            fi
        fi
    done
}

clean_cache_and_temp() {
    print_section "Clean Cache and Temp Files"
    
    local cache_dirs=(
        "$HOME/.cache/openclaw"
        "$HOME/.cache/clawdbot"
        "/tmp/openclaw-*"
        "/tmp/clawdbot-*"
    )
    
    for pattern in "${cache_dirs[@]}"; do
        for dir in $pattern; do
            if [[ -e "$dir" ]]; then
                print_found "Found cache: $dir"
                rm -rf "$dir" 2>/dev/null && print_success "Removed: $dir" || print_warning "Failed to remove: $dir"
            fi
        done
    done
    
    if command -v npm &> /dev/null; then
        print_info "Cleaning npm cache..."
        npm cache clean --force 2>/dev/null || true
    fi
}

# ============================================================================
# Menu Functions
# ============================================================================

show_scan_results() {
    print_section "Scan Results"
    
    if [[ ${#FOUND_COMPONENTS[@]} -eq 0 ]]; then
        print_success "No OpenClaw/ClawdBot components found"
        print_info "System is already clean!"
        return 1
    fi
    
    echo -e "  ${YELLOW}Found the following components:${NC}\n"
    
    local count=1
    for component in "${FOUND_COMPONENTS[@]}"; do
        case "$component" in
            docker_containers) print_found "$count. Docker containers" ;;
            docker_images) print_found "$count. Docker images" ;;
            docker_volumes) print_found "$count. Docker volumes" ;;
            npm_packages) print_found "$count. npm global packages" ;;
            pnpm_packages) print_found "$count. pnpm global packages" ;;
            config_dir:*) print_found "$count. Config directory: ${component#config_dir:}" ;;
            systemd_service) print_found "$count. systemd service" ;;
            systemd_unit_file) print_found "$count. systemd unit file" ;;
            running_processes) print_found "$count. Running processes" ;;
            binary:*) print_found "$count. Binary file: ${component#binary:}" ;;
            shell_config:*) print_found "$count. Shell config: ${component#shell_config:}" ;;
            *) print_found "$count. $component" ;;
        esac
        ((count++))
    done
    
    echo ""
    return 0
}

show_main_menu() {
    print_header
    
    echo -e "${WHITE}  Please select an option:${NC}\n"
    echo -e "    ${GREEN}1.${NC} Scan System - Find installed components"
    echo -e "    ${GREEN}2.${NC} Full Uninstall - Remove all components"
    echo -e "    ${GREEN}3.${NC} Selective Uninstall - Choose what to remove"
    echo -e "    ${GREEN}4.${NC} View Uninstall Log"
    echo -e "    ${GREEN}5.${NC} Help"
    echo -e "    ${GREEN}0.${NC} Exit"
    echo ""
    echo -ne "  ${YELLOW}Enter option [0-5]:${NC} "
}

show_selective_menu() {
    print_header
    
    echo -e "${WHITE}  Select components to uninstall:${NC}\n"
    echo -e "    ${GREEN}1.${NC} Docker components (containers, images, volumes)"
    echo -e "    ${GREEN}2.${NC} npm/pnpm global packages"
    echo -e "    ${GREEN}3.${NC} Config and data directories"
    echo -e "    ${GREEN}4.${NC} System services (Gateway)"
    echo -e "    ${GREEN}5.${NC} Binary files"
    echo -e "    ${GREEN}6.${NC} Shell configuration"
    echo -e "    ${GREEN}7.${NC} Cache and temp files"
    echo -e "    ${GREEN}0.${NC} Back to main menu"
    echo ""
    echo -ne "  ${YELLOW}Enter option [0-7]:${NC} "
}

show_help() {
    print_header
    print_section "Help"
    
    echo -e "  ${WHITE}${BOLD}About This Script${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  This script completely uninstalls OpenClaw (formerly"
    echo -e "  ClawdBot/Moltbot). Supports Docker, npm, source install."
    echo ""
    echo -e "  ${WHITE}${BOLD}Supported Components${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  - Docker containers, images and volumes"
    echo -e "  - npm/pnpm/yarn global packages"
    echo -e "  - Config directories (~/.openclaw, ~/.clawdbot, etc.)"
    echo -e "  - Workspace directories (~/openclaw, ~/clawd, etc.)"
    echo -e "  - Gateway system services"
    echo -e "  - CLI binary files"
    echo -e "  - Shell config environment variables"
    echo ""
    echo -e "  ${WHITE}${BOLD}Usage Tips${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  1. First run ${GREEN}Scan System${NC} to see installed components"
    echo -e "  2. For complete cleanup, use ${GREEN}Full Uninstall${NC}"
    echo -e "  3. To remove specific items, use ${GREEN}Selective Uninstall${NC}"
    echo ""
    echo -e "  ${WHITE}${BOLD}Log Location${NC}"
    echo -e "  ---------------------------------------------------------"
    echo -e "  $LOG_FILE"
    echo ""
    
    press_any_key
}

run_full_uninstall() {
    print_header
    print_section "Full Uninstall"
    
    echo -e "  ${RED}${BOLD}WARNING${NC}"
    echo -e "  This will remove ALL OpenClaw/ClawdBot components"
    echo -e "  including config files, data and workspace content"
    echo ""
    
    if ! confirm_action "Are you sure you want to continue?" "n"; then
        print_info "Operation cancelled"
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
    
    print_section "Uninstall Complete"
    
    if [[ ${#REMOVED_COMPONENTS[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}Successfully removed:${NC}\n"
        for component in "${REMOVED_COMPONENTS[@]}"; do
            echo -e "    ${GREEN}[OK]${NC} $component"
        done
    else
        print_info "No components were removed"
    fi
    
    echo ""
    print_success "OpenClaw has been completely uninstalled!"
    print_info "Log saved to: $LOG_FILE"
    
    press_any_key
}

run_scan() {
    print_header
    print_section "Scanning System..."
    
    FOUND_COMPONENTS=()
    
    echo -e "  ${BLUE}Checking Docker components...${NC}"
    check_docker_components || true
    
    echo -e "  ${BLUE}Checking npm/pnpm packages...${NC}"
    check_npm_packages || true
    
    echo -e "  ${BLUE}Checking config directories...${NC}"
    check_config_directories || true
    
    echo -e "  ${BLUE}Checking Gateway service...${NC}"
    check_gateway_service || true
    
    echo -e "  ${BLUE}Checking binary files...${NC}"
    check_binary_files || true
    
    echo -e "  ${BLUE}Checking Shell config...${NC}"
    check_shell_config || true
    
    echo ""
    show_scan_results
    
    press_any_key
}

view_log() {
    print_header
    print_section "Uninstall Log"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "  ${WHITE}Log file: $LOG_FILE${NC}\n"
        echo -e "${DIM}"
        tail -50 "$LOG_FILE"
        echo -e "${NC}"
    else
        print_info "No log records yet"
    fi
    
    press_any_key
}

# ============================================================================
# Main Loop
# ============================================================================

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
                        *) print_error "Invalid option"; sleep 1 ;;
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
                echo -e "  ${GREEN}Thank you for using OpenClaw Uninstaller!${NC}"
                echo -e "  ${DIM}Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                print_error "Invalid option, please try again"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# Command Line Arguments
# ============================================================================

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -y, --yes       Auto-confirm all actions (non-interactive)"
    echo "  -s, --scan      Scan only, do not uninstall"
    echo "  --version       Show version"
    echo ""
    echo "Examples:"
    echo "  $0              Start interactive menu"
    echo "  $0 -y           Auto complete uninstall"
    echo "  $0 -s           Scan for installed components only"
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
            echo "OpenClaw Uninstaller v$SCRIPT_VERSION"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

if $AUTO_YES; then
    confirm_action() {
        echo -e "  ${YELLOW}[?]${NC} $1 [auto-confirmed]"
        return 0
    }
fi

# ============================================================================
# Main Entry
# ============================================================================

if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}[!] Running as root${NC}"
    echo -e "${YELLOW}    Recommend running as normal user, sudo will be requested when needed${NC}"
    echo ""
fi

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

main_loop
