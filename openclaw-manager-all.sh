#!/usr/bin/env bash
# ==============================================================================
# OpenClaw 完整管理工具（官方标准 + 交互式菜单）
# ------------------------------------------------------------------------------
# 目标：
# 1) 保留“原来的那种交互式菜单”体验（主菜单 + 子菜单）
# 2) 认证/模型（尤其 Codex OAuth）全部以 OpenClaw 官方 CLI 为准，避免旧的 oauth.json 误导
# 3) Telegram 配置与 Pairing 审批以官方配置键与命令为准
# 4) 安装/卸载尽量走官方脚本与官方命令；手动清理作为兜底
#
# 官方参考（关键点）：
# - 官方安装脚本：curl -fsSL https://openclaw.ai/install.sh | bash ...  (Install & installer internals)
# - Node 要求：Node.js 22.12.0+（安全建议）/ install.sh 会确保 Node 22+ (SECURITY.md + installer)
# - Token 存储：按 agent 隔离，auth-profiles.json 位于：
#     ~/.openclaw/agents/<agentId>/agent/auth-profiles.json
#   旧文件 ~/.openclaw/credentials/oauth.json 仅用于兼容导入（不是主存储）
# - 模型/认证：openclaw models status / openclaw models auth login --provider openai-codex
# - Telegram：channels.telegram.botToken / dmPolicy=pairing；Pairing 审批：openclaw pairing approve telegram <CODE>
# ==============================================================================

set -o pipefail

SCRIPT_VERSION="2.3.0"
LOG_FILE="/tmp/openclaw-manager-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"

# ------------------------------
# 颜色
# ------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ------------------------------
# 官方目录（支持 OPENCLAW_* 覆盖）
# ------------------------------
STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$STATE_DIR/openclaw.json}"
AGENTS_DIR="$STATE_DIR/agents"
LEGACY_OAUTH_IMPORT_FILE="$STATE_DIR/credentials/oauth.json"
BACKUP_DIR="$STATE_DIR/backups"

# 兼容：有些系统无 /dev/tty（例如被管道调用）
TTY="/dev/tty"
[[ -t 0 ]] || TTY="/dev/stdin"
[[ -e /dev/tty ]] && TTY="/dev/tty"

# ------------------------------
# 基础工具
# ------------------------------
log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

run_cmd() {
  # 用法：run_cmd <cmd> [args...]
  log "RUN: $*"
  "$@" 2>&1 | tee -a "$LOG_FILE"
  return ${PIPESTATUS[0]}
}

print_header() {
  clear
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${WHITE}${BOLD}    ___   ____  _____ _   ________    ___        ____________ ${NC}"
  echo -e "${WHITE}${BOLD}   / _ \ / __ \/ ___// | / / ____/   /   |      / /  _/ ____/ ${NC}"
  echo -e "${WHITE}${BOLD}  /  __// /_/ / /   /  |/ / /       / /| |__  / // // /      ${NC}"
  echo -e "${WHITE}${BOLD}  \___/ \____/_/   /_/|_/_/       /_/  |_/ /_/ /___/_/       ${NC}"
  echo -e "${DIM}  OpenClaw 完整管理工具 v${SCRIPT_VERSION} | 官方标准优先 | 交互式菜单 | 日志: ${LOG_FILE}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

print_section() {
  echo -e "${BLUE}${BOLD}▶ $*${NC}"
  echo -e "${DIM}--------------------------------------------------------------${NC}"
}

ok() { echo -e "  ${GREEN}✓${NC} $*"; log "OK: $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; log "WARN: $*"; }
err() { echo -e "  ${RED}✗${NC} $*"; log "ERR: $*"; }

press_any_key() {
  echo ""
  read -r -n 1 -s -p "  按任意键返回菜单..." <"$TTY" || true
  echo ""
}

read_choice() {
  local choice
  IFS= read -r choice <"$TTY" || true
  choice="${choice:-}"
  echo "$choice"
}

confirm_action() {
  # confirm_action "提示文本"
  local prompt="$1"
  echo -ne "  ${YELLOW}${prompt} [y/N]: ${NC}"
  local ans
  IFS= read -r ans <"$TTY" || true
  case "${ans,,}" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

ensure_dirs() {
  mkdir -p "$BACKUP_DIR" >/dev/null 2>&1 || true
}

backup_path() {
  # backup_path <file>
  local f="$1"
  ensure_dirs
  if [[ -f "$f" ]]; then
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local base
    base="$(basename "$f")"
    cp -a "$f" "$BACKUP_DIR/${base}.${ts}.bak" 2>/dev/null || true
    ok "已备份: $f -> $BACKUP_DIR/${base}.${ts}.bak"
  fi
}

# ------------------------------
# Agent 相关
# ------------------------------
list_agents_local() {
  # 从状态目录列出 agentId（本地兜底）
  if [[ -d "$AGENTS_DIR" ]]; then
    (cd "$AGENTS_DIR" && ls -1 2>/dev/null) | sed '/^\s*$/d' || true
  fi
}

pick_agent_id() {
  # 输出 agentId（空=默认 main）
  echo ""
  print_section "选择 Agent（凭据/模型按 Agent 隔离）"
  echo -e "  ${DIM}提示：默认 agent 通常是 main（目录: ~/.openclaw/agents/main/agent）${NC}"
  local agents
  agents="$(list_agents_local | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"
  if [[ -n "$agents" ]]; then
    echo -e "  发现本地 Agents: ${GREEN}${agents}${NC}"
  else
    echo -e "  ${DIM}未在 $AGENTS_DIR 发现 agent 目录（可能尚未运行 onboard / agents add）${NC}"
  fi
  echo ""
  echo -ne "  请输入 agentId（回车=main）: "
  local id
  IFS= read -r id <"$TTY" || true
  id="${id:-main}"
  echo "$id"
}

agent_root_dir() {
  # agent_root_dir <agentId> -> ~/.openclaw/agents/<id>/agent
  local id="$1"
  echo "$STATE_DIR/agents/$id/agent"
}

# ------------------------------
# 状态展示
# ------------------------------
show_status_bar() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if command_exists openclaw; then
    local v
    v="$(openclaw --version 2>/dev/null | head -n 1 || true)"
    [[ -n "$v" ]] || v="已安装（版本未知）"
    echo -e "  ${GREEN}● OpenClaw:${NC} $v"
  else
    echo -e "  ${YELLOW}○ OpenClaw:${NC} 未安装"
  fi

  echo -e "  ${BLUE}● State:${NC} $STATE_DIR"
  echo -e "  ${BLUE}● Config:${NC} $CONFIG_PATH $( [[ -f "$CONFIG_PATH" ]] && echo -e "${GREEN}(存在)${NC}" || echo -e "${YELLOW}(不存在)${NC}" )"
  echo -e "  ${BLUE}● Agents:${NC} $AGENTS_DIR $( [[ -d "$AGENTS_DIR" ]] && echo -e "${GREEN}(存在)${NC}" || echo -e "${YELLOW}(不存在)${NC}" )"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# ==============================================================================
# 1) 安装/更新
# ==============================================================================
menu_install() {
  while true; do
    print_header
    show_status_bar
    print_section "安装 / 更新（官方推荐优先）"
    echo -e "  ${GREEN}1.${NC} 官方 install.sh（推荐）"
    echo -e "  ${GREEN}2.${NC} 官方 install-cli.sh（非 root / 自带 Node 前缀安装）"
    echo -e "  ${GREEN}3.${NC} npm 全局安装 openclaw@latest（需要系统 Node 22+）"
    echo -e "  ${GREEN}4.${NC} pnpm 全局安装 openclaw@latest（需要 pnpm + approve-builds）"
    echo -e "  ${GREEN}5.${NC} 运行 onboarding（openclaw onboard --install-daemon）"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-5]: "
    local c
    c="$(read_choice)"

    case "$c" in
      1)
        print_header
        print_section "官方 install.sh（推荐）"
        echo -e "  将执行：curl -fsSL https://openclaw.ai/install.sh | bash"
        echo -e "  ${DIM}提示：install.sh 会确保 Node 22+，并处理 Linux 上 npm EACCES 等常见问题。${NC}"
        echo ""
        echo -e "  选择安装方式："
        echo -e "    ${GREEN}1${NC}) npm（默认）"
        echo -e "    ${GREEN}2${NC}) git（从源码 checkout）"
        echo -ne "  请选择 [1-2]（回车=1）: "
        local m
        IFS= read -r m <"$TTY" || true
        m="${m:-1}"
        local method="npm"
        [[ "$m" == "2" ]] && method="git"

        if confirm_action "确认执行官方安装脚本（install-method=$method）？"; then
          # 官方文档示例：curl -fsSL https://openclaw.ai/install.sh | bash -s -- --install-method npm|git
          run_cmd bash -lc "curl -fsSL https://openclaw.ai/install.sh | bash -s -- --install-method ${method}"
          local rc=$?
          if [[ $rc -eq 0 ]]; then ok "安装/更新完成"; else err "安装脚本返回非 0（$rc），请查看日志：$LOG_FILE"; fi
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      2)
        print_header
        print_section "官方 install-cli.sh（非 root / 自带 Node）"
        echo -e "  将执行：curl -fsSL https://openclaw.ai/install-cli.sh | bash"
        echo -e "  ${DIM}适合：不想改系统 Node/npm，或无 root 权限的机器。${NC}"
        if confirm_action "确认执行 install-cli.sh？"; then
          run_cmd bash -lc "curl -fsSL https://openclaw.ai/install-cli.sh | bash"
          local rc=$?
          if [[ $rc -eq 0 ]]; then ok "安装完成"; else err "安装脚本返回非 0（$rc），请查看日志：$LOG_FILE"; fi
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      3)
        print_header
        print_section "npm 全局安装（需要 Node 22.12.0+）"
        echo -e "  将执行：npm install -g openclaw@latest"
        if ! command_exists npm; then
          err "未找到 npm。建议使用【1 官方 install.sh】自动处理 Node/npm。"
          press_any_key
          continue
        fi
        if confirm_action "确认继续 npm 全局安装？"; then
          run_cmd npm install -g openclaw@latest
          local rc=$?
          if [[ $rc -eq 0 ]]; then ok "npm 安装完成"; else err "npm 安装失败（$rc），请查看日志：$LOG_FILE"; fi
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      4)
        print_header
        print_section "pnpm 全局安装（需要 approve-builds）"
        echo -e "  官方提示：pnpm 需要执行 pnpm approve-builds -g 并再次安装以运行 postinstall。"
        if ! command_exists pnpm; then
          warn "未找到 pnpm（可用 npm i -g pnpm 安装），或直接用【1 官方 install.sh】。"
        fi
        if confirm_action "继续尝试 pnpm 安装？"; then
          if ! command_exists pnpm; then
            run_cmd npm i -g pnpm
          fi
          run_cmd pnpm add -g openclaw@latest
          warn "如出现 Ignored build scripts，请运行：pnpm approve-builds -g，然后再执行 pnpm add -g openclaw@latest"
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      5)
        print_header
        print_section "运行 onboarding（安装 daemon + 配置模型/渠道）"
        if ! command_exists openclaw; then
          err "未检测到 openclaw。请先安装。"
          press_any_key
          continue
        fi
        if confirm_action "确认运行：openclaw onboard --install-daemon ？"; then
          run_cmd openclaw onboard --install-daemon
          local rc=$?
          if [[ $rc -eq 0 ]]; then ok "onboard 完成"; else err "onboard 失败（$rc），请查看日志"; fi
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 2) 扫描/诊断
# ==============================================================================
menu_diagnose() {
  while true; do
    print_header
    show_status_bar
    print_section "诊断 / 状态（官方命令）"
    echo -e "  ${GREEN}1.${NC} openclaw status --all（推荐粘贴的只读报告）"
    echo -e "  ${GREEN}2.${NC} openclaw health（健康检查）"
    echo -e "  ${GREEN}3.${NC} openclaw doctor（诊断/修复建议）"
    echo -e "  ${GREEN}4.${NC} openclaw gateway status --deep（服务探测）"
    echo -e "  ${GREEN}5.${NC} openclaw models status（认证/模型概览）"
    echo -e "  ${GREEN}6.${NC} 扫描本机可能的残留（手动扫描）"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-6]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        print_section "openclaw status --all"
        if command_exists openclaw; then
          run_cmd openclaw status --all
        else
          err "未安装 openclaw"
        fi
        press_any_key
        ;;
      2)
        print_header
        print_section "openclaw health"
        if command_exists openclaw; then
          run_cmd openclaw health
        else
          err "未安装 openclaw"
        fi
        press_any_key
        ;;
      3)
        print_header
        print_section "openclaw doctor"
        if command_exists openclaw; then
          run_cmd openclaw doctor
        else
          err "未安装 openclaw"
        fi
        press_any_key
        ;;
      4)
        print_header
        print_section "openclaw gateway status --deep"
        if command_exists openclaw; then
          run_cmd openclaw gateway status --deep
        else
          err "未安装 openclaw"
        fi
        press_any_key
        ;;
      5)
        print_header
        print_section "openclaw models status"
        if command_exists openclaw; then
          run_cmd openclaw models status
        else
          err "未安装 openclaw"
        fi
        press_any_key
        ;;
      6)
        print_header
        print_section "手动扫描（兜底）"
        echo -e "  openclaw: $(command_exists openclaw && echo -e "${GREEN}$(command -v openclaw)${NC}" || echo -e "${YELLOW}未找到${NC}")"
        echo -e "  npm:      $(command_exists npm && echo -e "${GREEN}$(command -v npm)${NC}" || echo -e "${YELLOW}未找到${NC}")"
        echo -e "  node:     $(command_exists node && echo -e "${GREEN}$(command -v node)${NC}" || echo -e "${YELLOW}未找到${NC}")"
        echo -e "  state dir: $STATE_DIR $( [[ -d "$STATE_DIR" ]] && echo -e "${GREEN}(存在)${NC}" || echo -e "${YELLOW}(不存在)${NC}" )"
        echo -e "  config:    $CONFIG_PATH $( [[ -f "$CONFIG_PATH" ]] && echo -e "${GREEN}(存在)${NC}" || echo -e "${YELLOW}(不存在)${NC}" )"
        echo -e "  legacy oauth(import-only): $LEGACY_OAUTH_IMPORT_FILE $( [[ -f "$LEGACY_OAUTH_IMPORT_FILE" ]] && echo -e "${YELLOW}(存在)${NC}" || echo -e "${DIM}(无)${NC}" )"
        echo ""
        echo -e "  ${DIM}提示：认证/账号问题优先用【主菜单 5 模型与认证】查看 models status。${NC}"
        press_any_key
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 3) 卸载（官方优先） + 兜底清理
# ==============================================================================
run_official_uninstall() {
  print_section "官方卸载（openclaw uninstall）"
  if ! command_exists openclaw; then
    err "未安装 openclaw，跳过官方卸载"
    return 1
  fi
  echo -e "  将执行：openclaw uninstall --all --yes"
  echo -e "  ${DIM}说明：该命令卸载 Gateway 服务 + 本地数据（CLI 仍保留）。${NC}"
  if confirm_action "确认执行官方卸载？"; then
    run_cmd openclaw uninstall --all --yes
    return $?
  fi
  warn "已取消官方卸载"
  return 2
}

# 兜底清理：尽量保守，只清理 OpenClaw 默认目录与常见 npm 包
manual_cleanup() {
  print_section "兜底清理（手动）"
  echo -e "  ${YELLOW}注意：这一步会删除本机 OpenClaw 状态目录（默认 ~/.openclaw）及可能的全局 npm 包。${NC}"
  if ! confirm_action "确认继续手动清理？"; then
    warn "已取消"
    return 1
  fi

  # 备份重要文件
  backup_path "$CONFIG_PATH"
  backup_path "$LEGACY_OAUTH_IMPORT_FILE"

  # 尝试通过 npm 卸载（若存在）
  if command_exists npm; then
    warn "尝试 npm 卸载 openclaw（若为 npm 全局安装）..."
    run_cmd npm uninstall -g openclaw || true
  fi

  # 删除状态目录（默认）
  if [[ -d "$STATE_DIR" ]]; then
    warn "删除目录：$STATE_DIR"
    rm -rf "$STATE_DIR"
    ok "已删除：$STATE_DIR"
  else
    ok "未发现：$STATE_DIR"
  fi

  ok "手动清理完成"
  return 0
}

menu_full_uninstall() {
  print_header
  show_status_bar
  print_section "一键完整卸载"
  echo -e "  推荐顺序：先跑官方卸载，再做兜底清理。"
  echo ""
  if confirm_action "继续执行一键卸载流程？"; then
    run_official_uninstall || true
    echo ""
    manual_cleanup || true
  else
    warn "已取消"
  fi
  press_any_key
}

# ==============================================================================
# 4) 选择性卸载/清理（保留原交互式菜单风格）
# ==============================================================================
show_selective_menu() {
  print_header
  show_status_bar
  print_section "选择性卸载/清理（谨慎操作）"
  echo -e "  ${GREEN}1.${NC} 仅卸载 Gateway 服务（openclaw gateway uninstall）"
  echo -e "  ${GREEN}2.${NC} 仅删除状态目录（$STATE_DIR）"
  echo -e "  ${GREEN}3.${NC} 仅删除配置文件（$CONFIG_PATH）"
  echo -e "  ${GREEN}4.${NC} 仅卸载 npm 全局包 openclaw"
  echo -e "  ${GREEN}5.${NC} 清理 shell PATH 注入（~/.bashrc ~/.zshrc 中的 ~/.npm-global 等）"
  echo -e "  ${GREEN}6.${NC} 查看/打开备份目录（$BACKUP_DIR）"
  echo -e "  ${GREEN}0.${NC} 返回主菜单"
  echo ""
  echo -ne "  ${YELLOW}➤${NC} 请选择 [0-6]: "
}

uninstall_gateway_service_only() {
  print_header
  print_section "仅卸载 Gateway 服务"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return
  fi
  echo -e "  将执行：openclaw gateway uninstall"
  if confirm_action "确认卸载 Gateway 服务？"; then
    run_cmd openclaw gateway uninstall
  else
    warn "已取消"
  fi
}

delete_state_dir_only() {
  print_header
  print_section "仅删除状态目录"
  echo -e "  目录：$STATE_DIR"
  if [[ ! -d "$STATE_DIR" ]]; then
    ok "目录不存在，无需删除"
    return
  fi
  if confirm_action "确认删除该目录？"; then
    backup_path "$CONFIG_PATH"
    rm -rf "$STATE_DIR"
    ok "已删除：$STATE_DIR"
  else
    warn "已取消"
  fi
}

delete_config_only() {
  print_header
  print_section "仅删除配置文件"
  echo -e "  文件：$CONFIG_PATH"
  if [[ ! -f "$CONFIG_PATH" ]]; then
    ok "文件不存在，无需删除"
    return
  fi
  if confirm_action "确认删除配置文件？"; then
    backup_path "$CONFIG_PATH"
    rm -f "$CONFIG_PATH"
    ok "已删除：$CONFIG_PATH"
  else
    warn "已取消"
  fi
}

uninstall_npm_only() {
  print_header
  print_section "仅卸载 npm 全局 openclaw"
  if ! command_exists npm; then
    err "未找到 npm"
    return
  fi
  if confirm_action "确认执行 npm uninstall -g openclaw？"; then
    run_cmd npm uninstall -g openclaw
  else
    warn "已取消"
  fi
}

clean_shell_path_injection() {
  print_header
  print_section "清理 shell 配置中的 PATH 注入（保守）"
  echo -e "  ${DIM}说明：官方 install.sh 可能会写入 ~/.bashrc / ~/.zshrc 以加入 ~/.npm-global/bin 到 PATH。${NC}"
  echo -e "  本工具仅移除包含 \".npm-global\" 的 PATH 行（不会动其它自定义 PATH）。"
  echo ""
  local files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -q "\.npm-global" "$f"; then
      backup_path "$f"
      # 删除含 .npm-global 的行（简单保守）
      sed -i.bak_openclaw_manager '/\.npm-global/d' "$f" 2>/dev/null || true
      ok "已处理：$f（已备份）"
    fi
  done
  ok "清理完成（如需彻底检查，请手动打开 shell 配置文件确认）"
}

open_backup_dir() {
  print_header
  print_section "备份目录"
  ensure_dirs
  echo -e "  $BACKUP_DIR"
  ls -la "$BACKUP_DIR" 2>/dev/null || true
}

menu_selective_uninstall() {
  while true; do
    show_selective_menu
    local c
    c="$(read_choice)"
    case "$c" in
      1) uninstall_gateway_service_only; press_any_key ;;
      2) delete_state_dir_only; press_any_key ;;
      3) delete_config_only; press_any_key ;;
      4) uninstall_npm_only; press_any_key ;;
      5) clean_shell_path_injection; press_any_key ;;
      6) open_backup_dir; press_any_key ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 5) 模型与认证（Codex / OAuth / API Key）—— 修复“找不到已配置账号”的核心入口
# ==============================================================================
models_status_for_agent() {
  local agent_id="$1"
  print_section "models status（agent=${agent_id}）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  # models status 支持 --agent（官方文档）
  run_cmd openclaw models status --agent "$agent_id"
}

models_check_for_agent() {
  local agent_id="$1"
  print_section "models status --check（agent=${agent_id}）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  set +e
  openclaw models status --check --agent "$agent_id" 2>&1 | tee -a "$LOG_FILE"
  local rc=${PIPESTATUS[0]}
  set -e 2>/dev/null || true
  case "$rc" in
    0) ok "认证状态 OK（未过期/未缺失）" ;;
    1) warn "存在 Missing/Expired（exit=1）。请执行登录或粘贴 token。" ;;
    2) warn "存在即将过期（exit=2）。建议提前刷新/重新登录。" ;;
    *) warn "返回码：$rc（请查看上方输出）" ;;
  esac
  return 0
}

models_auth_login_codex() {
  local agent_id="$1"
  print_section "Codex OAuth 登录（openai-codex）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi

  echo -e "  将执行：openclaw models auth login --provider openai-codex"
  echo -e "  ${DIM}说明：这是 ChatGPT/Codex 订阅 OAuth（官方推荐命令）。${NC}"
  echo -e "  ${DIM}若为远程/无浏览器环境，登录流程可能要求粘贴回调 URL/代码。${NC}"

  if confirm_action "确认开始登录？"; then
    local agent_dir
    agent_dir="$(agent_root_dir "$agent_id")"
    mkdir -p "$agent_dir" >/dev/null 2>&1 || true

    # 使用 OPENCLAW_AGENT_DIR 强制写入目标 agent 的 auth-profiles.json（更通用）
    run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models auth login --provider openai-codex
    local rc=$?
    if [[ $rc -eq 0 ]]; then
      ok "登录流程完成（建议立即查看 models status 验证）"
    else
      err "登录失败（$rc）"
    fi
  else
    warn "已取消"
  fi
}

models_auth_login_generic() {
  local agent_id="$1"
  print_section "Provider 登录（models auth login）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  echo -ne "  输入 provider id（例如 openai-codex / anthropic / openrouter ...）: "
  local pid
  IFS= read -r pid <"$TTY" || true
  pid="${pid:-}"
  if [[ -z "$pid" ]]; then
    warn "未输入 provider id，取消"
    return 1
  fi
  if confirm_action "确认登录 provider=${pid}？"; then
    local agent_dir
    agent_dir="$(agent_root_dir "$agent_id")"
    mkdir -p "$agent_dir" >/dev/null 2>&1 || true
    run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models auth login --provider "$pid"
  else
    warn "已取消"
  fi
}

models_auth_paste_token() {
  local agent_id="$1"
  print_section "粘贴 token / API key（models auth paste-token）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  echo -ne "  输入 provider id（例如 anthropic / openrouter / ...）: "
  local pid
  IFS= read -r pid <"$TTY" || true
  pid="${pid:-}"
  if [[ -z "$pid" ]]; then
    warn "未输入 provider id，取消"
    return 1
  fi
  if confirm_action "确认继续（将进入交互式粘贴 token）？"; then
    local agent_dir
    agent_dir="$(agent_root_dir "$agent_id")"
    mkdir -p "$agent_dir" >/dev/null 2>&1 || true
    run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models auth paste-token --provider "$pid"
  else
    warn "已取消"
  fi
}

models_auth_setup_token_anthropic() {
  local agent_id="$1"
  print_section "Anthropic setup-token（订阅）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  echo -e "  将执行：openclaw models auth setup-token --provider anthropic"
  echo -e "  ${DIM}提示：setup-token 通常来自另一台机器运行 claude setup-token 生成。${NC}"
  if confirm_action "确认继续？"; then
    local agent_dir
    agent_dir="$(agent_root_dir "$agent_id")"
    mkdir -p "$agent_dir" >/dev/null 2>&1 || true
    run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models auth setup-token --provider anthropic
  else
    warn "已取消"
  fi
}

models_set_default_model() {
  local agent_id="$1"
  print_section "设置默认模型（models set）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  echo -e "  格式：provider/model（例如 openai-codex/gpt-5.2）"
  echo -ne "  输入模型："
  local model
  IFS= read -r model <"$TTY" || true
  model="${model:-}"
  if [[ -z "$model" ]]; then
    warn "未输入模型，取消"
    return 1
  fi
  if confirm_action "确认设置为默认模型：$model ？"; then
    local agent_dir
    agent_dir="$(agent_root_dir "$agent_id")"
    mkdir -p "$agent_dir" >/dev/null 2>&1 || true
    run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models set "$model"
  else
    warn "已取消"
  fi
}


# ------------------------------------------------------------------------------
# 5.x Codex 多账号（同一 agent 内）切换：auth order + /model ...@<profileId>
# ------------------------------------------------------------------------------
json_array() {
  # json_array <str1> <str2> ...
  # 仅用于构造 openclaw config set --json 的数组值（兜底）
  local out="["
  local first=1
  local s
  for s in "$@"; do
    # minimal JSON escaping
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    if [[ $first -eq 1 ]]; then
      first=0
    else
      out+=","
    fi
    out+="\"$s\""
  done
  out+="]"
  echo "$out"
}

auth_profiles_file_for_agent() {
  # auth_profiles_file_for_agent <agentId> -> echo path (优先新路径，兼容 legacy)
  local agent_id="$1"
  local p="$STATE_DIR/agents/$agent_id/agent/auth-profiles.json"
  if [[ -f "$p" ]]; then
    echo "$p"
    return 0
  fi
  local legacy="$STATE_DIR/agent/auth-profiles.json"
  if [[ -f "$legacy" ]]; then
    echo "$legacy"
    return 0
  fi
  return 1
}

codex_profile_ids_for_agent() {
  # 输出该 agent 的 openai-codex profileId（每行一个）
  local agent_id="$1"
  local provider="openai-codex"
  local f
  f="$(auth_profiles_file_for_agent "$agent_id")" || return 1

  if command_exists python3; then
    python3 - "$f" "$provider" <<'PY'
import json,sys
path=sys.argv[1]
provider=sys.argv[2]
try:
    with open(path,'r',encoding='utf-8') as fp:
        data=json.load(fp)
except Exception:
    sys.exit(2)

profiles=data.get("profiles", {})
ids=[]

def add(pid):
    if isinstance(pid,str) and pid and pid not in ids:
        ids.append(pid)

if isinstance(profiles, dict):
    for pid,obj in profiles.items():
        if not isinstance(pid,str):
            continue
        if pid.startswith(provider + ":"):
            add(pid)
        elif isinstance(obj, dict) and obj.get("provider")==provider:
            add(pid)
elif isinstance(profiles, list):
    for obj in profiles:
        if not isinstance(obj, dict):
            continue
        pid=obj.get("id") or obj.get("profileId") or obj.get("profile_id")
        prov=obj.get("provider")
        if isinstance(pid,str) and (pid.startswith(provider + ":") or prov==provider):
            add(pid)

for pid in sorted(ids):
    print(pid)
PY
    return 0
  fi

  if command_exists jq; then
    jq -r --arg p "$provider" '.profiles | keys[] | select(startswith($p + ":"))' "$f" 2>/dev/null || true
    return 0
  fi

  # 无 python3/jq：无法自动解析
  return 2
}

codex_profiles_table_for_agent() {
  local agent_id="$1"
  local provider="openai-codex"
  local f
  f="$(auth_profiles_file_for_agent "$agent_id")" || { warn "未找到该 agent 的 auth-profiles.json（请先登录一次）"; return 1; }

  print_section "Codex profiles（agent=${agent_id}）"
  echo -e "  文件：$f"
  echo ""

  if ! command_exists python3; then
    warn "未检测到 python3，无法解析并显示 profiles 表格。"
    echo -e "  你仍然可以："
    echo -e "  1) 通过 openclaw models status 查看 OAuth profiles"
    echo -e "  2) 或在下方菜单里手动输入 profileId（例如 openai-codex:default / openai-codex:<email>）"
    return 0
  fi

  python3 - "$f" "$provider" <<'PY'
import json,sys,datetime
path=sys.argv[1]
provider=sys.argv[2]

def fmt_ms(ms):
    if not isinstance(ms,(int,float)):
        return ""
    try:
        dt=datetime.datetime.fromtimestamp(ms/1000, tz=datetime.timezone.utc)
        return dt.isoformat().replace("+00:00","Z")
    except Exception:
        return str(ms)

with open(path,'r',encoding='utf-8') as fp:
    data=json.load(fp)

profiles=data.get("profiles", {})
usage=data.get("usageStats", {}) if isinstance(data.get("usageStats", {}), dict) else {}

rows=[]
if isinstance(profiles, dict):
    for pid,obj in profiles.items():
        if not isinstance(pid,str):
            continue
        if not (pid.startswith(provider + ":") or (isinstance(obj, dict) and obj.get("provider")==provider)):
            continue
        typ=""
        ident=""
        exp=""
        if isinstance(obj, dict):
            typ=str(obj.get("type") or obj.get("mode") or "")
            ident=str(obj.get("email") or obj.get("accountId") or obj.get("account_id") or "")
            exp=fmt_ms(obj.get("expires"))
        stat=usage.get(pid, {}) if isinstance(usage, dict) else {}
        cooldown=fmt_ms(stat.get("cooldownUntil")) if isinstance(stat, dict) else ""
        disabled=fmt_ms(stat.get("disabledUntil")) if isinstance(stat, dict) else ""
        rows.append((pid, typ, ident, exp, cooldown, disabled))

rows.sort(key=lambda r:r[0])

if not rows:
    print("(未找到 openai-codex profiles；请先执行 Codex OAuth 登录：openclaw models auth login --provider openai-codex)")
    sys.exit(0)

hdr=("profileId","type","email/accountId","expires(UTC)","cooldownUntil","disabledUntil")
print(f"{hdr[0]:<42} {hdr[1]:<8} {hdr[2]:<28} {hdr[3]:<24} {hdr[4]:<24} {hdr[5]:<24}")
for pid,typ,ident,exp,cd,ds in rows:
    ident=(ident or "")[:28]
    print(f"{pid:<42} {typ:<8} {ident:<28} {exp[:24]:<24} {cd[:24]:<24} {ds[:24]:<24}")
PY
}

codex_auth_order_get() {
  local agent_id="$1"
  print_section "查看当前 Codex auth order（agent=${agent_id}）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi

  # 官方命令（优先）
  run_cmd openclaw models auth order get --provider openai-codex --agent "$agent_id"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    warn "models auth order get 失败（可能是旧版本 CLI）。尝试从配置读取 auth.order[openai-codex] 作为兜底。"
    run_cmd openclaw config get 'auth.order["openai-codex"]' || true
  fi
  return 0
}

codex_auth_order_set() {
  # codex_auth_order_set <agentId> <profileId...>
  local agent_id="$1"
  shift || true
  local ids=("$@")
  if [[ ${#ids[@]} -eq 0 ]]; then
    warn "未提供 profileId，取消"
    return 1
  fi
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi

  echo -e "  将设置 openai-codex 的 auth order 为："
  local i
  for i in "${ids[@]}"; do
    echo -e "    - ${GREEN}${i}${NC}"
  done
  echo ""
  if ! confirm_action "确认写入该 agent 的 Codex 顺序？"; then
    warn "已取消"
    return 1
  fi

  # 官方命令（优先）
  run_cmd openclaw models auth order set --provider openai-codex --agent "$agent_id" "${ids[@]}"
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "已设置（注意：已有会话可能存在“session stickiness”，建议 /new 或 /reset 开新会话测试）"
    return 0
  fi

  warn "models auth order set 失败（可能是旧版本 CLI）。尝试写入 openclaw.json 的 auth.order 作为兜底。"
  local arr_json
  arr_json="$(json_array "${ids[@]}")"
  run_cmd openclaw config set 'auth.order["openai-codex"]' "$arr_json" --json
  ok "已写入配置兜底（仍建议 models status 验证，并必要时重启 gateway）"
  return 0
}

codex_auth_order_clear() {
  local agent_id="$1"
  print_section "清除 Codex auth order（恢复自动轮询/自动切换）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  if ! confirm_action "确认清除该 agent 的 openai-codex 顺序覆盖？"; then
    warn "已取消"
    return 1
  fi

  run_cmd openclaw models auth order clear --provider openai-codex --agent "$agent_id"
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "已清除（恢复默认顺序/轮询）"
    return 0
  fi

  warn "models auth order clear 失败（可能是旧版本 CLI）。尝试从配置中移除 auth.order[openai-codex] 作为兜底。"
  run_cmd openclaw config unset 'auth.order["openai-codex"]' || true
  ok "已执行兜底清除（仍建议 models status 验证，并必要时重启 gateway）"
  return 0
}

codex_set_preferred_profile_interactive() {
  local agent_id="$1"

  # 收集 profiles
  local ids=()
  if mapfile -t ids < <(codex_profile_ids_for_agent "$agent_id"); then
    :
  else
    warn "无法自动读取 profileId（可能未登录或缺少解析工具）。"
  fi

  if [[ ${#ids[@]} -eq 0 ]]; then
    warn "未发现任何 openai-codex profiles。请先执行：openclaw models auth login --provider openai-codex"
    return 1
  fi

  print_section "选择要优先使用的 Codex profile（agent=${agent_id}）"
  local i
  for i in "${!ids[@]}"; do
    printf "  %s) %s\n" "$((i+1))" "${ids[$i]}"
  done
  echo ""
  echo -ne "  请选择序号 [1-${#ids[@]}]（回车取消）: "
  local pick
  IFS= read -r pick <"$TTY" || true
  pick="${pick:-}"
  if [[ -z "$pick" ]]; then
    warn "已取消"
    return 1
  fi
  if ! [[ "$pick" =~ ^[0-9]+$ ]]; then
    warn "输入不是数字"
    return 1
  fi
  if (( pick < 1 || pick > ${#ids[@]} )); then
    warn "超出范围"
    return 1
  fi

  local chosen="${ids[$((pick-1))]}"

  # 选择一个作为首选，其他作为备选保持在后面（更适合稳定/自动 failover）
  local new_order=("$chosen")
  for i in "${ids[@]}"; do
    [[ "$i" == "$chosen" ]] && continue
    new_order+=("$i")
  done

  codex_auth_order_set "$agent_id" "${new_order[@]}"
}

codex_set_order_manual() {
  local agent_id="$1"
  print_section "手动设置 Codex auth order（空格分隔多个 profileId）"
  echo -e "  示例：openai-codex:work@example.com openai-codex:personal@example.com"
  echo -ne "  输入 profileId 列表（回车取消）: "
  local line
  IFS= read -r line <"$TTY" || true
  line="${line:-}"
  if [[ -z "$line" ]]; then
    warn "已取消"
    return 1
  fi

  # shellcheck disable=SC2206
  local ids=($line)
  if [[ ${#ids[@]} -eq 0 ]]; then
    warn "未解析到 profileId"
    return 1
  fi
  codex_auth_order_set "$agent_id" "${ids[@]}"
}

codex_make_session_pin_command() {
  local agent_id="$1"
  print_section "生成 /model …@<profileId>（会话级固定账号）"
  echo -e "  ${DIM}说明：这是“会话级”固定账号，不改全局顺序。${NC}"
  echo -e "  ${DIM}格式：/model <provider/model>@<profileId>${NC}"
  echo -e "  ${DIM}例如：/model openai-codex/gpt-5.2@openai-codex:work@example.com${NC}"
  echo ""

  echo -ne "  输入模型（回车=openai-codex/gpt-5.2）: "
  local model
  IFS= read -r model <"$TTY" || true
  model="${model:-openai-codex/gpt-5.2}"

  echo -ne "  输入 profileId（例如 openai-codex:default / openai-codex:<email>）: "
  local pid
  IFS= read -r pid <"$TTY" || true
  pid="${pid:-}"
  if [[ -z "$pid" ]]; then
    warn "未输入 profileId，取消"
    return 1
  fi

  echo ""
  ok "复制下面这行到 Telegram/控制台对话里："
  echo -e "  ${BOLD}/model ${model}@${pid}${NC}"
  echo ""
  echo -e "  ${DIM}注意：OpenClaw 有 session stickiness；要让新的 pinned 生效，可能需要 /new 或 /reset 开新会话。${NC}"
}

menu_codex_profiles() {
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    press_any_key
    return 1
  fi

  local agent_id
  agent_id="$(pick_agent_id)"

  while true; do
    print_header
    show_status_bar
    print_section "Codex 多账号（同一 agent 内）切换/排序（官方 auth order + /model @profileId）"
    echo -e "  当前 agent: ${GREEN}${agent_id}${NC}"
    echo -e "  ${DIM}说明：同一 agent 可保存多个 openai-codex OAuth profile。你可以：${NC}"
    echo -e "  ${DIM}- 用 auth order 设定“全局优先账号”（对该 agent 生效）${NC}"
    echo -e "  ${DIM}- 用 /model ...@profileId 对“当前会话”固定账号${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 列出该 agent 的 Codex profiles（从 auth-profiles.json 解析）"
    echo -e "  ${GREEN}2.${NC} 查看当前 auth order（models auth order get）"
    echo -e "  ${GREEN}3.${NC} 选择一个账号作为首选（其余作为备选）"
    echo -e "  ${GREEN}4.${NC} 手动设置 auth order（输入多个 profileId）"
    echo -e "  ${GREEN}5.${NC} 清除 auth order（恢复自动轮询/自动切换）"
    echo -e "  ${GREEN}6.${NC} 生成 /model …@profileId（会话级固定账号）"
    echo -e "  ${GREEN}7.${NC} 切换 agent"
    echo -e "  ${GREEN}0.${NC} 返回上级菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-7]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        codex_profiles_table_for_agent "$agent_id"
        press_any_key
        ;;
      2)
        print_header
        codex_auth_order_get "$agent_id"
        press_any_key
        ;;
      3)
        print_header
        codex_set_preferred_profile_interactive "$agent_id"
        press_any_key
        ;;
      4)
        print_header
        codex_set_order_manual "$agent_id"
        press_any_key
        ;;
      5)
        print_header
        codex_auth_order_clear "$agent_id"
        press_any_key
        ;;
      6)
        print_header
        codex_make_session_pin_command "$agent_id"
        press_any_key
        ;;
      7)
        agent_id="$(pick_agent_id)"
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}
sync_auth_profiles_between_agents() {
  print_section "同步 auth-profiles.json（解决“登录了但找不到账号”）"
  echo -e "  ${DIM}说明：认证存储按 agent 隔离，文件在：${NC}"
  echo -e "  ${DIM}  ~/.openclaw/agents/<agentId>/agent/auth-profiles.json${NC}"
  echo -e "  ${DIM}如果你在 agent A 登录，但 Gateway/会话使用 agent B，就会表现为“找不到配置的账户”。${NC}"
  echo ""

  local src
  echo -ne "  源 agentId（回车=main）: "
  IFS= read -r src <"$TTY" || true
  src="${src:-main}"

  local dst
  echo -ne "  目标 agentId（回车=main）: "
  IFS= read -r dst <"$TTY" || true
  dst="${dst:-main}"

  if [[ "$src" == "$dst" ]]; then
    warn "源与目标相同，无需同步"
    return 0
  fi

  local src_file="$STATE_DIR/agents/$src/agent/auth-profiles.json"
  local dst_dir="$STATE_DIR/agents/$dst/agent"
  local dst_file="$dst_dir/auth-profiles.json"
  local dst_cache="$dst_dir/auth.json"

  echo -e "  源文件：$src_file"
  echo -e "  目标文件：$dst_file"
  if [[ ! -f "$src_file" ]]; then
    err "源文件不存在（请先在源 agent 登录一次）"
    return 1
  fi

  if confirm_action "确认复制（会覆盖目标的 auth-profiles.json）？"; then
    mkdir -p "$dst_dir" >/dev/null 2>&1 || true
    backup_path "$dst_file"
    cp -a "$src_file" "$dst_file"
    ok "已复制 auth-profiles.json"
    # 清理目标运行时缓存，让它重新加载
    rm -f "$dst_cache" >/dev/null 2>&1 || true
    ok "已清理目标 auth.json 缓存（如存在）"
    echo ""
    if command_exists openclaw; then
      run_cmd openclaw models status --agent "$dst"
    else
      warn "未安装 openclaw，跳过验证"
    fi
  else
    warn "已取消"
  fi
}

agents_menu() {
  while true; do
    print_header
    show_status_bar
    print_section "Agents 管理（隔离账号/工作区/路由）"
    echo -e "  ${GREEN}1.${NC} 列出 agents（openclaw agents list）"
    echo -e "  ${GREEN}2.${NC} 新增 agent（openclaw agents add <id>）"
    echo -e "  ${GREEN}3.${NC} 删除 agent（openclaw agents delete <id>）"
    echo -e "  ${GREEN}0.${NC} 返回上级菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-3]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        print_section "openclaw agents list"
        if command_exists openclaw; then run_cmd openclaw agents list; else err "未安装 openclaw"; fi
        press_any_key
        ;;
      2)
        print_header
        print_section "新增 agent"
        if ! command_exists openclaw; then err "未安装 openclaw"; press_any_key; continue; fi
        echo -ne "  输入新 agentId（例如 work / personal）: "
        local id
        IFS= read -r id <"$TTY" || true
        id="${id:-}"
        if [[ -z "$id" ]]; then warn "未输入，取消"; press_any_key; continue; fi
        if confirm_action "确认创建 agent：$id ？"; then
          run_cmd openclaw agents add "$id"
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      3)
        print_header
        print_section "删除 agent"
        if ! command_exists openclaw; then err "未安装 openclaw"; press_any_key; continue; fi
        echo -ne "  输入要删除的 agentId: "
        local id
        IFS= read -r id <"$TTY" || true
        id="${id:-}"
        if [[ -z "$id" ]]; then warn "未输入，取消"; press_any_key; continue; fi
        warn "删除 agent 会移除该 agent 的隔离配置/凭据/会话等（请先备份）"
        if confirm_action "确认删除 agent：$id ？"; then
          run_cmd openclaw agents delete "$id"
        else
          warn "已取消"
        fi
        press_any_key
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

menu_models_auth() {
  while true; do
    print_header
    show_status_bar
    print_section "模型与认证（官方 models/auth，重点修复 Codex 账号问题）"
    echo -e "  ${GREEN}1.${NC} 查看 models status（选择 agent）"
    echo -e "  ${GREEN}2.${NC} 快速检查 auth（models status --check）"
    echo -e "  ${GREEN}3.${NC} Codex OAuth 登录（openai-codex）"
    echo -e "  ${GREEN}4.${NC} 其他 provider 登录（models auth login）"
    echo -e "  ${GREEN}5.${NC} 粘贴 token/API key（models auth paste-token）"
    echo -e "  ${GREEN}6.${NC} Anthropic setup-token（订阅）"
    echo -e "  ${GREEN}7.${NC} 设置默认模型（models set）"
    echo -e "  ${GREEN}8.${NC} 同步 auth-profiles.json（A 登录、B 找不到时用）"
    echo -e "  ${GREEN}9.${NC} Agents 管理（list/add/delete）"
    echo -e "  ${GREEN}10.${NC} Codex profiles 切换（同一 agent，auth order / /model）"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-10]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_status_for_agent "$agent_id"
        press_any_key
        ;;
      2)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_check_for_agent "$agent_id"
        press_any_key
        ;;
      3)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_auth_login_codex "$agent_id"
        echo ""
        models_status_for_agent "$agent_id" || true
        press_any_key
        ;;
      4)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_auth_login_generic "$agent_id"
        press_any_key
        ;;
      5)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_auth_paste_token "$agent_id"
        press_any_key
        ;;
      6)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_auth_setup_token_anthropic "$agent_id"
        press_any_key
        ;;
      7)
        print_header
        local agent_id
        agent_id="$(pick_agent_id)"
        models_set_default_model "$agent_id"
        press_any_key
        ;;
      8)
        print_header
        sync_auth_profiles_between_agents
        press_any_key
        ;;
      9)
        agents_menu
        ;;
      10)
        menu_codex_profiles
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 6) Telegram 机器人管理（官方配置键 + Pairing）
# ==============================================================================
telegram_set_bot_token() {
  print_section "配置 Telegram botToken（写入 openclaw.json）"
  if ! command_exists openclaw; then
    err "未安装 openclaw"
    return 1
  fi
  echo -e "  参考官方配置键：channels.telegram.botToken（以及 enabled / dmPolicy）。"
  echo -ne "  输入 Bot Token（形如 123456:ABC...）: "
  local token
  IFS= read -r token <"$TTY" || true
  token="${token:-}"
  if [[ -z "$token" ]]; then
    warn "未输入 token，取消"
    return 1
  fi
  if confirm_action "确认写入配置并启用 Telegram？"; then
    backup_path "$CONFIG_PATH"
    run_cmd openclaw config set channels.telegram.enabled true --json
    run_cmd openclaw config set channels.telegram.botToken "$token"
    run_cmd openclaw config set channels.telegram.dmPolicy "pairing"
    ok "已写入配置。按需重启 Gateway。"
  else
    warn "已取消"
  fi
}

telegram_pairing_list() {
  print_section "查看 Telegram pairing 列表"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  run_cmd openclaw pairing list telegram
}

telegram_pairing_approve() {
  print_section "批准 Telegram pairing code"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -ne "  输入 pairing CODE（DM 未授权用户时给出的短码）: "
  local code
  IFS= read -r code <"$TTY" || true
  code="${code:-}"
  if [[ -z "$code" ]]; then
    warn "未输入 code，取消"
    return 1
  fi
  if confirm_action "确认批准该 code？"; then
    run_cmd openclaw pairing approve telegram "$code"
  else
    warn "已取消"
  fi
}

telegram_channels_status() {
  print_section "channels status（检查 Gateway + 频道健康）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  run_cmd openclaw channels status
}

telegram_restart_gateway() {
  print_section "重启 Gateway"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  if confirm_action "确认重启 Gateway？"; then
    run_cmd openclaw gateway restart
  else
    warn "已取消"
  fi
}

telegram_menu() {
  while true; do
    print_header
    show_status_bar
    print_section "Telegram 机器人管理（官方配置 + Pairing）"
    echo -e "  ${GREEN}1.${NC} 运行渠道配置向导（openclaw configure --section channels）"
    echo -e "  ${GREEN}2.${NC} 写入 botToken 并启用 Telegram（config set）"
    echo -e "  ${GREEN}3.${NC} 查看当前 Telegram 配置（config get channels.telegram）"
    echo -e "  ${GREEN}4.${NC} 查看 pairing 列表（pairing list telegram）"
    echo -e "  ${GREEN}5.${NC} 批准 pairing code（pairing approve telegram <CODE>）"
    echo -e "  ${GREEN}6.${NC} channels status（频道健康检查）"
    echo -e "  ${GREEN}7.${NC} 查看 Gateway 日志（openclaw logs --follow）"
    echo -e "  ${GREEN}8.${NC} 重启 Gateway（gateway restart）"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-8]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        print_section "openclaw configure --section channels"
        if command_exists openclaw; then run_cmd openclaw configure --section channels; else err "未安装 openclaw"; fi
        press_any_key
        ;;
      2)
        print_header
        telegram_set_bot_token
        press_any_key
        ;;
      3)
        print_header
        print_section "config get channels.telegram"
        if command_exists openclaw; then run_cmd openclaw config get channels.telegram; else err "未安装 openclaw"; fi
        press_any_key
        ;;
      4)
        print_header
        telegram_pairing_list
        press_any_key
        ;;
      5)
        print_header
        telegram_pairing_approve
        press_any_key
        ;;
      6)
        print_header
        telegram_channels_status
        press_any_key
        ;;
      7)
        print_header
        print_section "openclaw logs --follow"
        if command_exists openclaw; then
          echo -e "  ${DIM}按 Ctrl+C 退出日志跟随${NC}"
          run_cmd openclaw logs --follow
        else
          err "未安装 openclaw"
        fi
        press_any_key
        ;;
      8)
        print_header
        telegram_restart_gateway
        press_any_key
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 7) 查看日志
# ==============================================================================
view_logs_menu() {
  while true; do
    print_header
    show_status_bar
    print_section "日志"
    echo -e "  ${GREEN}1.${NC} 查看本脚本日志（tail -n 200）"
    echo -e "  ${GREEN}2.${NC} 跟随本脚本日志（tail -f）"
    echo -e "  ${GREEN}3.${NC} 查看 Gateway 日志（openclaw logs --limit 200）"
    echo -e "  ${GREEN}4.${NC} 跟随 Gateway 日志（openclaw logs --follow）"
    echo -e "  ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne "  ${YELLOW}➤${NC} 请选择 [0-4]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        print_section "脚本日志（tail -n 200）"
        tail -n 200 "$LOG_FILE" 2>/dev/null || true
        press_any_key
        ;;
      2)
        print_header
        print_section "跟随脚本日志（Ctrl+C 退出）"
        tail -f "$LOG_FILE" 2>/dev/null || true
        press_any_key
        ;;
      3)
        print_header
        print_section "Gateway 日志（limit 200）"
        if command_exists openclaw; then run_cmd openclaw logs --limit 200; else err "未安装 openclaw"; fi
        press_any_key
        ;;
      4)
        print_header
        print_section "跟随 Gateway 日志（Ctrl+C 退出）"
        if command_exists openclaw; then run_cmd openclaw logs --follow; else err "未安装 openclaw"; fi
        press_any_key
        ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 8) 帮助
# ==============================================================================
show_help() {
  print_header
  print_section "帮助 / 常见问题"
  cat <<'EOF'
  1) “配置了 Codex 账号但提示找不到账号 / Missing auth”
     - 先在【主菜单 5 -> 1】看 models status，确认缺的是哪个 provider
     - Codex 订阅 OAuth：用【主菜单 5 -> 3】执行 openai-codex 登录
     - 重点：认证是“按 agent 隔离”的。如果你在 agent A 登录但实际会话用 agent B，会表现为找不到账号
       解决：用【主菜单 5 -> 8】把 auth-profiles.json 从 A 同步到 B，或直接在 B 登录一次

  2) Telegram 不回消息 / DM 没权限
     - 确认 config 里 channels.telegram.enabled=true 且 channels.telegram.botToken 正确
     - 默认 DM 策略是 pairing：先 DM 机器人拿到 code，再用【主菜单 6 -> 5】approve
     - 用【主菜单 6 -> 6】channels status / 【主菜单 2】doctor/health 排查

  3) 安装推荐
     - 优先用【主菜单 1 -> 1】官方 install.sh：它会确保 Node 22+、处理 Linux npm EACCES，并默认规避 sharp/libvips 坑

  4) 生成可粘贴的诊断信息
     - 【主菜单 2 -> 1】openclaw status --all

EOF
  press_any_key
}

# ==============================================================================
# 主菜单（保留原交互式风格）
# ==============================================================================
show_main_menu() {
  print_header
  show_status_bar

  echo -e "${WHITE}  主菜单${NC}\n"
  echo -e "  ${GREEN}1.${NC} 安装/更新 OpenClaw"
  echo -e "  ${GREEN}2.${NC} 扫描/诊断（status/health/doctor）"
  echo -e "  ${GREEN}3.${NC} 一键完整卸载（官方优先 + 兜底清理）"
  echo -e "  ${GREEN}4.${NC} 选择性卸载/清理"
  echo -e "  ${GREEN}5.${NC} 模型与认证（Codex/OAuth/API Key）"
  echo -e "  ${GREEN}6.${NC} Telegram 机器人管理"
  echo -e "  ${GREEN}7.${NC} 查看日志"
  echo -e "  ${GREEN}8.${NC} 帮助信息"
  echo -e "  ${GREEN}0.${NC} 退出"
  echo ""
  echo -ne "  ${YELLOW}➤${NC} 请选择 [0-8]: "
}

main_loop() {
  ensure_dirs
  while true; do
    show_main_menu
    local choice
    choice="$(read_choice)"
    case "$choice" in
      1) menu_install ;;
      2) menu_diagnose ;;
      3) menu_full_uninstall ;;
      4) menu_selective_uninstall ;;
      5) menu_models_auth ;;
      6) telegram_menu ;;
      7) view_logs_menu ;;
      8) show_help ;;
      0) print_header; ok "再见！"; exit 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

main_loop
