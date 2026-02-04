#!/usr/bin/env bash
# ==============================================================================
# OpenClaw 完整管理工具（官方标准 + 交互式菜单）
# ------------------------------------------------------------------------------
# 目标：
# 1) 保留“原来的那种交互式菜单”体验（主菜单 + 子菜单）
# 2) 认证/模型（尤其 Codex OAuth）全部以 OpenClaw 官方 CLI 为准
# 3) Telegram 配置与 Pairing 审批以官方配置键与命令为准
# 4) 多账号管理模式：
#    - ✅ 采用「单一 agent（main）内的多 profile」方式（openai-codex:default / openai-codex:alt ...）
#    - ✅ 通过 auth order 做默认优先顺序/故障切换
#    - ✅ 通过 /model <provider/model>@<profileId> 做会话级固定账号
#    - ❌ 不再引导使用多个 agent 作为多账号隔离（避免“登录了但找不到账号”的困扰）
#
# 官方参考（关键点）：
# - Token 存储：按 agent 隔离，auth-profiles.json 位于：
#   ~/.openclaw/agents/<agentId>/agent/auth-profiles.json
#   这里我们约定统一使用 main agent：~/.openclaw/agents/main/agent/auth-profiles.json
# - 旧文件 ~/.openclaw/credentials/oauth.json 仅用于兼容导入（不是主存储）
# - 模型/认证：openclaw models status / openclaw models auth login --provider openai-codex
# - Telegram：channels.telegram.botToken / dmPolicy=pairing；Pairing 审批：openclaw pairing approve telegram <CODE>
# ==============================================================================

set -o pipefail

SCRIPT_VERSION="2.3.5"
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

# ------------------------------
# 单 agent 多账号：固定使用 main agent
# ------------------------------
DEFAULT_AGENT_ID="main"

# ------------------------------
# 性能/稳定性参数（可用环境变量覆盖）
# ------------------------------
OC_VERSION_TIMEOUT_SEC="${OC_VERSION_TIMEOUT_SEC:-2}"
OC_MODELS_STATUS_TIMEOUT_SEC="${OC_MODELS_STATUS_TIMEOUT_SEC:-20}"
OC_MODELS_CHECK_TIMEOUT_SEC="${OC_MODELS_CHECK_TIMEOUT_SEC:-20}"
OC_MODELS_SET_TIMEOUT_SEC="${OC_MODELS_SET_TIMEOUT_SEC:-20}"
OC_AUTH_ORDER_TIMEOUT_SEC="${OC_AUTH_ORDER_TIMEOUT_SEC:-15}"
OC_CONFIG_CMD_TIMEOUT_SEC="${OC_CONFIG_CMD_TIMEOUT_SEC:-15}"
# openclaw onboard 可能会打开 TUI/提示（远程环境偶发卡住）；这里提供超时保护（可覆盖）
OC_ONBOARD_TIMEOUT_SEC="${OC_ONBOARD_TIMEOUT_SEC:-600}"

# 兼容：有些系统无 /dev/tty（例如被管道调用）
TTY="/dev/tty"
[[ -t 0 ]] || TTY="/dev/stdin"
[[ -e /dev/tty ]] && TTY="/dev/tty"

# ------------------------------
# 基础工具
# ------------------------------
log() { printf '[%s] %s ' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"; }

run_cmd() {
  log "RUN: $*"
  "$@" 2>&1 | tee -a "$LOG_FILE"
  return ${PIPESTATUS[0]}
}

print_header() {
  printf "\033[2J\033[H"
  local w="${COLUMNS:-80}"
  (( w < 60 )) && w=60
  (( w > 120 )) && w=120
  local line
  printf -v line '%*s' "$w" ''
  line=${line// /━}
  echo -e "${CYAN}${line}${NC}"

  if (( w >= 78 )); then
    echo -e "${WHITE}${BOLD} ██████╗ ██████╗ ███████╗███╗ ██╗ ██████╗██╗ █████╗ ██╗ ██╗${NC}"
    echo -e "${WHITE}${BOLD} ██╔══██╗██╔══██╗██╔════╝████╗ ██║██╔════╝██║ ██╔══██╗██║ ██║${NC}"
    echo -e "${WHITE}${BOLD} ██████╔╝██████╔╝█████╗ ██╔██╗ ██║██║ ██║ ███████║██║ █╗ ██║${NC}"
    echo -e "${WHITE}${BOLD} ██╔═══╝ ██╔══██╗██╔══╝ ██║╚██╗██║██║ ██║ ██╔══██║██║███╗██║${NC}"
    echo -e "${WHITE}${BOLD} ██║ ██║ ██║███████╗██║ ╚████║╚██████╗███████╗██║ ██║╚███╔███╔╝${NC}"
    echo -e "${WHITE}${BOLD} ╚═╝ ╚═╝ ╚═╝╚══════╝╚═╝ ╚═══╝ ╚═════╝╚══════╝╚═╝ ╚═╝ ╚══╝╚══╝${NC}"
  else
    echo -e "${WHITE}${BOLD} OPENCLAW${NC}"
  fi

  echo -e "${DIM} OpenClaw 完整管理工具 v${SCRIPT_VERSION} · 官方标准优先 · 交互式菜单${NC}"
  echo -e "${DIM} 模式：单一 agent（${DEFAULT_AGENT_ID}）多账号（profiles + auth order）${NC}"
  echo -e "${DIM} 日志: ${LOG_FILE}${NC}"
  echo -e "${CYAN}${line}${NC}"
  echo ""
}

print_section() {
  echo -e "${BLUE}${BOLD}▶ $*${NC}"
  echo -e "${DIM}--------------------------------------------------------------${NC}"
}

ok() { echo -e " ${GREEN}✓${NC} $*"; log "OK: $*"; }
warn() { echo -e " ${YELLOW}!${NC} $*"; log "WARN: $*"; }
err() { echo -e " ${RED}✗${NC} $*"; log "ERR: $*"; }

# 交互回到菜单：默认最多等几秒，避免某些远程/无可用 TTY 的环境“看起来卡住”
PRESS_ANY_KEY_TIMEOUT_SEC="${PRESS_ANY_KEY_TIMEOUT_SEC:-3}"
press_any_key() {
  echo ""
  # 没有可交互 TTY 时，直接返回（不阻塞）
  if [[ ! -e "$TTY" ]]; then
    return 0
  fi
  # 0 表示不等待（立刻返回）
  if [[ "${PRESS_ANY_KEY_TIMEOUT_SEC}" == "0" ]]; then
    return 0
  fi
  # 有些环境 read -t 不支持（极少见），失败则降级为普通 read
  if read -r -n 1 -s -t "${PRESS_ANY_KEY_TIMEOUT_SEC}" -p " 按任意键返回菜单...（${PRESS_ANY_KEY_TIMEOUT_SEC}s 后自动返回）" <"$TTY"; then
    echo ""
  else
    echo ""
  fi
}

read_choice() {
  local choice
  IFS= read -r choice <"$TTY" || true
  choice="${choice:-}"
  echo "$choice"
}

confirm_action() {
  local prompt="$1"
  echo -ne " ${YELLOW}${prompt} [y/N]: ${NC}"
  local ans
  IFS= read -r ans <"$TTY" || true
  case "${ans,,}" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------
# 超时工具
# ------------------------------
TIMEOUT_BIN=""
if command_exists timeout; then
  TIMEOUT_BIN="timeout"
elif command_exists gtimeout; then
  TIMEOUT_BIN="gtimeout"
fi

run_cmd_timeout() {
  local seconds="$1"; shift || true
  if [[ -n "$TIMEOUT_BIN" && -n "$seconds" && "$seconds" != "0" ]]; then
    run_cmd "$TIMEOUT_BIN" "${seconds}s" "$@"
    return $?
  fi
  run_cmd "$@"
}

is_timeout_rc() {
  local rc="$1"
  [[ "$rc" == "124" || "$rc" == "137" ]]
}

# ------------------------------
# 版本缓存
# ------------------------------
_OPENCLAW_VERSION_CACHE=""
_OPENCLAW_VERSION_CACHE_READY=0
invalidate_openclaw_version_cache() {
  _OPENCLAW_VERSION_CACHE=""
  _OPENCLAW_VERSION_CACHE_READY=0
}

get_openclaw_version_cached() {
  if ! command_exists openclaw; then return 1; fi
  if [[ "${_OPENCLAW_VERSION_CACHE_READY:-0}" -eq 1 ]]; then
    printf '%s ' "$_OPENCLAW_VERSION_CACHE"
    return 0
  fi
  local v rc
  v=""; rc=0
  local t="${OC_VERSION_TIMEOUT_SEC:-2}"
  if [[ "$t" == "0" ]]; then
    v="已安装"
    rc=0
  elif [[ -n "$TIMEOUT_BIN" ]]; then
    v="$($TIMEOUT_BIN "${t}s" openclaw --version 2>/dev/null)"; rc=$?
    if is_timeout_rc "$rc"; then v="已安装（版本获取超时）"; rc=0; fi
  else
    v="$(openclaw --version 2>/dev/null)"; rc=$?
  fi
  if [[ $rc -ne 0 ]]; then v=""; fi
  v="${v%%$' '*}"
  [[ -n "$v" ]] || v="已安装（版本未知）"
  _OPENCLAW_VERSION_CACHE="$v"
  _OPENCLAW_VERSION_CACHE_READY=1
  printf '%s ' "$v"
}

ensure_dirs() { mkdir -p "$BACKUP_DIR" >/dev/null 2>&1 || true; }

backup_path() {
  local f="$1"
  ensure_dirs
  if [[ -f "$f" ]]; then
    local ts base
    ts="$(date +%Y%m%d_%H%M%S)"
    base="$(basename "$f")"
    cp -a "$f" "$BACKUP_DIR/${base}.${ts}.bak" 2>/dev/null || true
    ok "已备份: $f -> $BACKUP_DIR/${base}.${ts}.bak"
  fi
}

# ------------------------------
# Agent 路径（固定 main）
# ------------------------------
agent_root_dir() {
  local id="$1"
  echo "$STATE_DIR/agents/$id/agent"
}

# ------------------------------
# 状态栏
# ------------------------------
show_status_bar() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if command_exists openclaw; then
    local v
    v="$(get_openclaw_version_cached 2>/dev/null || true)"
    [[ -n "$v" ]] || v="已安装（版本未知）"
    echo -e " ${GREEN}● OpenClaw:${NC} $v"
  else
    echo -e " ${YELLOW}○ OpenClaw:${NC} 未安装"
  fi

  echo -e " ${BLUE}● State:${NC} $STATE_DIR"

  local cfg_mark agents_mark
  if [[ -f "$CONFIG_PATH" ]]; then cfg_mark="${GREEN}(存在)${NC}"; else cfg_mark="${YELLOW}(不存在)${NC}"; fi
  if [[ -d "$AGENTS_DIR" ]]; then agents_mark="${GREEN}(存在)${NC}"; else agents_mark="${YELLOW}(不存在)${NC}"; fi

  echo -e " ${BLUE}● Config:${NC} $CONFIG_PATH $cfg_mark"
  echo -e " ${BLUE}● Agents:${NC} $AGENTS_DIR $agents_mark"
  echo -e " ${BLUE}● Active agent:${NC} ${DEFAULT_AGENT_ID}"

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
    echo -e " ${GREEN}1.${NC} 官方 install.sh（推荐）"
    echo -e " ${GREEN}2.${NC} 官方 install-cli.sh（非 root / 自带 Node 前缀安装）"
    echo -e " ${GREEN}3.${NC} npm 全局安装 openclaw@latest（需要系统 Node 22+）"
    echo -e " ${GREEN}4.${NC} pnpm 全局安装 openclaw@latest（需要 pnpm + approve-builds）"
    echo -e " ${GREEN}5.${NC} 运行 onboarding（openclaw onboard --install-daemon）"
    echo -e " ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne " ${YELLOW}➤${NC} 请选择 [0-5]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1)
        print_header
        print_section "官方 install.sh（推荐）"
        echo -e " 将执行：curl -fsSL https://openclaw.ai/install.sh | bash"
        echo -e " ${DIM}提示：install.sh 会确保 Node 22+，并处理 Linux 上 npm EACCES 等常见问题。${NC}"
        echo ""
        echo -e " 选择安装方式："
        echo -e " ${GREEN}1${NC}) npm（默认）"
        echo -e " ${GREEN}2${NC}) git（从源码 checkout）"
        echo -ne " 请选择 [1-2]（回车=1）: "
        local m
        IFS= read -r m <"$TTY" || true
        m="${m:-1}"
        local method="npm"
        [[ "$m" == "2" ]] && method="git"
        if confirm_action "确认执行官方安装脚本（install-method=$method）？"; then
          run_cmd bash -lc "curl -fsSL https://openclaw.ai/install.sh | bash -s -- --install-method ${method}"
          invalidate_openclaw_version_cache
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
        echo -e " 将执行：curl -fsSL https://openclaw.ai/install-cli.sh | bash"
        echo -e " ${DIM}适合：不想改系统 Node/npm，或无 root 权限的机器。${NC}"
        if confirm_action "确认执行 install-cli.sh？"; then
          run_cmd bash -lc "curl -fsSL https://openclaw.ai/install-cli.sh | bash"
          invalidate_openclaw_version_cache
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
        echo -e " 将执行：npm install -g openclaw@latest"
        if ! command_exists npm; then
          err "未找到 npm。建议使用【1 官方 install.sh】自动处理 Node/npm。"
          press_any_key
          continue
        fi
        if confirm_action "确认继续 npm 全局安装？"; then
          run_cmd npm install -g openclaw@latest
          invalidate_openclaw_version_cache
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
        echo -e " 官方提示：pnpm 需要执行 pnpm approve-builds -g 并再次安装以运行 postinstall。"
        if ! command_exists pnpm; then
          warn "未找到 pnpm（可用 npm i -g pnpm 安装），或直接用【1 官方 install.sh】。"
        fi
        if confirm_action "继续尝试 pnpm 安装？"; then
          if ! command_exists pnpm; then run_cmd npm i -g pnpm; fi
          run_cmd pnpm add -g openclaw@latest
          invalidate_openclaw_version_cache
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
        echo -e " ${DIM}提示：为避免远程/无交互环境卡在 TUI 收尾界面，这里默认加 --skip-ui。${NC}"
        echo -e " ${DIM}如需完整 TUI 体验，请手动运行：openclaw onboard --install-daemon${NC}"
        if confirm_action "确认运行：openclaw onboard --install-daemon --skip-ui ？"; then
          # 关键：部分终端/远程环境里，即使 --skip-ui 也可能落到 TUI 收尾屏。
          # 加 --json 并断开 stdin，可强制走非交互输出，避免卡在最后一屏。
          run_cmd_timeout "${OC_ONBOARD_TIMEOUT_SEC}" bash -lc 'openclaw onboard --install-daemon --skip-ui --json </dev/null'
          local rc=$?
          if is_timeout_rc "$rc"; then
            warn "onboard 超时（${OC_ONBOARD_TIMEOUT_SEC}s）。可能仍在后台执行或被卡住；建议运行：openclaw doctor / openclaw gateway status"
          elif [[ $rc -eq 0 ]]; then
            ok "onboard 完成"
          else
            err "onboard 失败（$rc），请查看日志"
          fi
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
    echo -e " ${GREEN}1.${NC} openclaw status --all（推荐粘贴的只读报告）"
    echo -e " ${GREEN}2.${NC} openclaw health（健康检查）"
    echo -e " ${GREEN}3.${NC} openclaw doctor（诊断/修复建议）"
    echo -e " ${GREEN}4.${NC} openclaw gateway status --deep（服务探测）"
    echo -e " ${GREEN}5.${NC} openclaw models status（认证/模型概览）"
    echo -e " ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne " ${YELLOW}➤${NC} 请选择 [0-5]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1) print_header; print_section "openclaw status --all"; command_exists openclaw && run_cmd openclaw status --all || err "未安装 openclaw"; press_any_key ;;
      2) print_header; print_section "openclaw health"; command_exists openclaw && run_cmd openclaw health || err "未安装 openclaw"; press_any_key ;;
      3) print_header; print_section "openclaw doctor"; command_exists openclaw && run_cmd openclaw doctor || err "未安装 openclaw"; press_any_key ;;
      4) print_header; print_section "openclaw gateway status --deep"; command_exists openclaw && run_cmd openclaw gateway status --deep || err "未安装 openclaw"; press_any_key ;;
      5) print_header; print_section "openclaw models status"; command_exists openclaw && run_cmd openclaw models status || err "未安装 openclaw"; press_any_key ;;
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
  if ! command_exists openclaw; then err "未安装 openclaw，跳过官方卸载"; return 1; fi
  echo -e " 将执行：openclaw uninstall --all --yes"
  echo -e " ${DIM}说明：该命令卸载 Gateway 服务 + 本地数据（CLI 仍保留）。${NC}"
  if confirm_action "确认执行官方卸载？"; then
    run_cmd openclaw uninstall --all --yes
    return $?
  fi
  warn "已取消官方卸载"
  return 2
}

manual_cleanup() {
  print_section "兜底清理（手动）"
  echo -e " ${YELLOW}注意：这一步会删除本机 OpenClaw 状态目录（默认 ~/.openclaw）及可能的全局 npm 包。${NC}"
  if ! confirm_action "确认继续手动清理？"; then warn "已取消"; return 1; fi
  backup_path "$CONFIG_PATH"
  backup_path "$LEGACY_OAUTH_IMPORT_FILE"
  if command_exists npm; then
    warn "尝试 npm 卸载 openclaw（若为 npm 全局安装）..."
    run_cmd npm uninstall -g openclaw || true
    invalidate_openclaw_version_cache || true
  fi
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

require_phrase() {
  # require_phrase <phrase> <prompt>
  local phrase="$1"
  local prompt="$2"
  echo -ne " ${YELLOW}${prompt}${NC}"
  local got
  IFS= read -r got <"$TTY" || true
  [[ "$got" == "$phrase" ]]
}

full_purge_environment() {
  print_section "彻底删除 OpenClaw 环境（高危操作）"
  echo -e " ${RED}${BOLD}这会尽可能删除 OpenClaw 相关的所有内容（包括状态目录、profiles、daemon/service、npm 前缀等）。${NC}"
  echo -e " ${YELLOW}请确认你不需要保留任何历史/凭据/配置。${NC}"
  echo ""

  # 1) 先尝试停服务/卸载服务（官方）
  if command_exists openclaw; then
    warn "尝试停止/卸载 Gateway 服务（best-effort）..."
    run_cmd openclaw gateway stop || true
    run_cmd openclaw gateway uninstall || true
    # 官方卸载（会尽量清理状态；但不同版本可能保留 CLI）
    run_cmd openclaw uninstall --all --yes || true
  fi

  # 2) 终止残留进程（best-effort）
  warn "尝试终止残留进程（best-effort）..."
  pkill -f openclaw-gateway 2>/dev/null || true
  pkill -f "openclaw.*gateway" 2>/dev/null || true

  # 3) 删除 systemd user service 文件（Linux）
  local sd_user_dir="$HOME/.config/systemd/user"
  if [[ -d "$sd_user_dir" ]]; then
    warn "清理 systemd user service（OpenClaw Gateway）..."
    rm -f "$sd_user_dir"/openclaw-gateway*.service 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user reset-failed 2>/dev/null || true
  fi

  # 4) 删除 OpenClaw 状态目录（包含 profiles、media、sessions、extensions 等）
  warn "删除 OpenClaw state dir: $STATE_DIR"
  rm -rf "$STATE_DIR" 2>/dev/null || true

  # 同时清理同级 profiles（~/.openclaw-dev, ~/.openclaw-xxx）
  warn "删除 OpenClaw profiles（~/.openclaw-*）..."
  rm -rf "$HOME"/.openclaw-* 2>/dev/null || true

  # 5) 清理 install.sh 常见 npm prefix（~/.npm-global）
  warn "清理 npm prefix 目录（~/.npm-global；若被 install.sh 创建）..."
  rm -rf "$HOME/.npm-global" 2>/dev/null || true

  # 6) 尝试卸载全局 npm 包 openclaw（若存在）
  if command_exists npm; then
    warn "尝试 npm uninstall -g openclaw（best-effort）..."
    run_cmd npm uninstall -g openclaw || true
  fi

  # 7) 清理常见 user bin 中的 openclaw 可执行（best-effort，仅限 $HOME 下）
  warn "清理常见用户 bin 的 openclaw 可执行（best-effort）..."
  rm -f "$HOME/.local/bin/openclaw" 2>/dev/null || true
  rm -f "$HOME/.npm-global/bin/openclaw" 2>/dev/null || true

  # 8) 清理临时日志
  rm -rf /tmp/openclaw 2>/dev/null || true

  # 9) 清理 shell PATH 注入（保守：只移除 .npm-global 行）
  clean_shell_path_injection

  ok "彻底卸载/清理流程执行完毕（best-effort）。"
  warn "建议你重新打开一个新终端，执行：command -v openclaw（应为空）"
}

menu_full_uninstall() {
  print_header
  show_status_bar
  print_section "一键彻底卸载（删除环境）"
  echo -e " ${YELLOW}说明：官方 uninstall 可能保留 CLI；你要求的是“把环境完整删除”，这里会做 best-effort 清理。${NC}"
  echo -e " ${YELLOW}将删除：$STATE_DIR、~/.openclaw-*、~/.npm-global、systemd user service、临时日志等。${NC}"
  echo ""

  if ! confirm_action "确定继续？"; then
    warn "已取消"
    press_any_key
    return 0
  fi

  echo ""
  if require_phrase "DELETE" "为防误操作，请输入 ${BOLD}DELETE${NC}${YELLOW} 并回车确认： "; then
    full_purge_environment
    invalidate_openclaw_version_cache
  else
    warn "确认短语不匹配，已取消"
  fi
  press_any_key
}

# ==============================================================================
# 4) 选择性卸载/清理
# ==============================================================================
show_selective_menu() {
  print_header
  show_status_bar
  print_section "选择性卸载/清理（谨慎操作）"
  echo -e " ${GREEN}1.${NC} 仅卸载 Gateway 服务（openclaw gateway uninstall）"
  echo -e " ${GREEN}2.${NC} 仅删除状态目录（$STATE_DIR）"
  echo -e " ${GREEN}3.${NC} 仅删除配置文件（$CONFIG_PATH）"
  echo -e " ${GREEN}4.${NC} 仅卸载 npm 全局包 openclaw"
  echo -e " ${GREEN}5.${NC} 清理 shell PATH 注入（~/.bashrc ~/.zshrc 中的 ~/.npm-global 等）"
  echo -e " ${GREEN}6.${NC} 查看/打开备份目录（$BACKUP_DIR）"
  echo -e " ${GREEN}0.${NC} 返回主菜单"
  echo ""
  echo -ne " ${YELLOW}➤${NC} 请选择 [0-6]: "
}

uninstall_gateway_service_only() {
  print_header
  print_section "仅卸载 Gateway 服务"
  if ! command_exists openclaw; then err "未安装 openclaw"; return; fi
  echo -e " 将执行：openclaw gateway uninstall"
  if confirm_action "确认卸载 Gateway 服务？"; then run_cmd openclaw gateway uninstall; else warn "已取消"; fi
}

delete_state_dir_only() {
  print_header
  print_section "仅删除状态目录"
  echo -e " 目录：$STATE_DIR"
  if [[ ! -d "$STATE_DIR" ]]; then ok "目录不存在，无需删除"; return; fi
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
  echo -e " 文件：$CONFIG_PATH"
  if [[ ! -f "$CONFIG_PATH" ]]; then ok "文件不存在，无需删除"; return; fi
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
  if ! command_exists npm; then err "未找到 npm"; return; fi
  if confirm_action "确认执行 npm uninstall -g openclaw？"; then
    run_cmd npm uninstall -g openclaw
    invalidate_openclaw_version_cache
  else
    warn "已取消"
  fi
}

clean_shell_path_injection() {
  print_header
  print_section "清理 shell 配置中的 PATH 注入（保守）"
  echo -e " ${DIM}说明：官方 install.sh 可能会写入 ~/.bashrc / ~/.zshrc 以加入 ~/.npm-global/bin 到 PATH。${NC}"
  echo -e " 本工具仅移除包含 \".npm-global\" 的 PATH 行（不会动其它自定义 PATH）。"
  echo ""
  local files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
  local f
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -q "\.npm-global" "$f"; then
      backup_path "$f"
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
  echo -e " $BACKUP_DIR"
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
# 5) 模型与认证（单 agent 多账号）
# ==============================================================================
auth_profiles_file_for_agent() {
  local agent_id="$1"
  local p="$STATE_DIR/agents/$agent_id/agent/auth-profiles.json"
  [[ -f "$p" ]] && { echo "$p"; return 0; }
  local legacy="$STATE_DIR/agent/auth-profiles.json"
  [[ -f "$legacy" ]] && { echo "$legacy"; return 0; }
  return 1
}

fallback_models_status_local() {
  local agent_id="$1"
  print_section "本地兜底：已登录账号（从 auth-profiles.json 读取）"
  local f
  f="$(auth_profiles_file_for_agent "$agent_id" 2>/dev/null)" || {
    warn "未找到该 agent 的 auth-profiles.json（可能还没登录过任何 provider）"
    echo -e " 路径通常是：${STATE_DIR}/agents/${agent_id}/agent/auth-profiles.json"
    return 0
  }

  echo -e " 文件：$f"
  echo ""

  if ! command_exists python3; then
    warn "未检测到 python3，无法自动解析 JSON。你可以直接打开上面的文件查看 profiles。"
    return 0
  fi

  python3 - "$f" <<'PY'
import json,sys
path=sys.argv[1]
try:
  with open(path,'r',encoding='utf-8') as fp:
    data=json.load(fp)
except Exception as e:
  print(f"(无法读取/解析 {path}: {e})")
  sys.exit(0)
profiles=data.get("profiles", {})
prov_map={}

def add(prov,pid):
  prov_map.setdefault(prov, [])
  if pid not in prov_map[prov]:
    prov_map[prov].append(pid)

def guess_provider(pid,obj):
  prov=None
  if isinstance(obj, dict):
    prov=obj.get("provider")
  if not prov and isinstance(pid,str) and ":" in pid:
    prov=pid.split(":",1)[0]
  if not prov:
    prov="unknown"
  return prov

if isinstance(profiles, dict):
  for pid,obj in profiles.items():
    if not isinstance(pid,str):
      continue
    prov=guess_provider(pid,obj)
    add(prov,pid)
elif isinstance(profiles, list):
  for obj in profiles:
    if not isinstance(obj, dict):
      continue
    pid=obj.get("id") or obj.get("profileId") or obj.get("profile_id")
    if not pid:
      continue
    prov=obj.get("provider") or "unknown"
    add(prov,pid)

if not prov_map:
  print("(profiles 为空：尚未配置任何账号)")
  sys.exit(0)

for prov in sorted(prov_map.keys()):
  ids=sorted(prov_map[prov])
  print(f"{prov} ({len(ids)})")
  for pid in ids[:15]:
    print(f" - {pid}")
  if len(ids) > 15:
    print(f" ... 另有 {len(ids)-15} 个未显示")
PY
}

models_status_for_agent() {
  local agent_id="$1"
  print_section "models status（agent=${agent_id}）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  local rc=0
  run_cmd_timeout "${OC_MODELS_STATUS_TIMEOUT_SEC}" openclaw models status --plain --agent "$agent_id"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    if is_timeout_rc "$rc"; then warn "openclaw models status 超时（${OC_MODELS_STATUS_TIMEOUT_SEC}s）。已使用本地兜底展示。";
    else warn "openclaw models status 执行失败（exit=$rc）。已使用本地兜底展示。"; fi
    echo ""
    fallback_models_status_local "$agent_id"
  fi
  return 0
}

models_check_for_agent() {
  local agent_id="$1"
  print_section "models status --check（agent=${agent_id}）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  local rc=0
  run_cmd_timeout "${OC_MODELS_CHECK_TIMEOUT_SEC}" openclaw models status --check --plain --agent "$agent_id"
  rc=$?
  if is_timeout_rc "$rc"; then
    warn "models status --check 超时（${OC_MODELS_CHECK_TIMEOUT_SEC}s）。请稍后重试，或运行 openclaw doctor 排查。"
    return 0
  fi
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
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi

  echo -e " 选择登录方式（均为官方 CLI 路径）："
  echo -e " ${GREEN}1${NC}) openclaw models auth login --provider openai-codex  ${DIM}(推荐；只做认证)${NC}"
  echo -e " ${GREEN}2${NC}) openclaw onboard --auth-choice openai-codex           ${DIM}(兜底；向导式，适合远程/TTY 异常)${NC}"
  echo ""
  echo -ne " 请选择 [1-2]（回车=1）: "
  local m
  IFS= read -r m <"$TTY" || true
  m="${m:-1}"

  if ! confirm_action "确认开始登录？"; then
    warn "已取消"
    return 1
  fi

  local agent_dir
  agent_dir="$(agent_root_dir "$agent_id")"
  mkdir -p "$agent_dir" >/dev/null 2>&1 || true

  case "$m" in
    2)
      echo -e " 将执行：openclaw onboard --auth-choice openai-codex"
      echo -e " ${DIM}提示：该向导会检测 existing config；请选择 'Use existing values' 避免覆盖其它设置。${NC}"
      run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw onboard --auth-choice openai-codex
      ;;
    *)
      echo -e " 将执行：openclaw models auth login --provider openai-codex"
      echo -e " ${DIM}说明：这是 ChatGPT/Codex 订阅 OAuth（官方推荐命令）。${NC}"
      echo -e " ${DIM}若为远程/无浏览器环境，登录流程可能要求粘贴回调 URL/代码。${NC}"
      run_cmd env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models auth login --provider openai-codex
      ;;
  esac

  local rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "登录流程完成（建议立即查看 models status 验证）"
  else
    err "登录失败（$rc）。若你刚选的是 1，可以重试并改选 2（onboard 兜底）。"
  fi
}

models_auth_login_generic() {
  local agent_id="$1"
  print_section "Provider 登录（models auth login）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -ne " 输入 provider id（例如 anthropic / openrouter / ...）: "
  local pid
  IFS= read -r pid <"$TTY" || true
  pid="${pid:-}"
  if [[ -z "$pid" ]]; then warn "未输入 provider id，取消"; return 1; fi
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
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -ne " 输入 provider id（例如 anthropic / openrouter / ...）: "
  local pid
  IFS= read -r pid <"$TTY" || true
  pid="${pid:-}"
  if [[ -z "$pid" ]]; then warn "未输入 provider id，取消"; return 1; fi
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
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -e " 将执行：openclaw models auth setup-token --provider anthropic"
  echo -e " ${DIM}提示：setup-token 通常来自另一台机器运行 claude setup-token 生成。${NC}"
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
  print_section "切换默认模型（openclaw models set）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -e " 输入格式：${GREEN}provider/model${NC}（例如 openai-codex/gpt-5.2）或一个 alias。"
  echo -e " ${DIM}小技巧：输入 list 查看模型列表（可能较慢）。回车取消。${NC}"
  echo ""
  local model=""
  while true; do
    echo -ne " 请输入模型（provider/model 或 alias）: "
    IFS= read -r model <"$TTY" || true
    model="${model:-}"
    if [[ -z "$model" ]]; then warn "未输入模型，已取消"; return 1; fi
    case "${model,,}" in
      list|ls|\?)
        echo ""
        print_section "models list"
        run_cmd_timeout "${OC_CONFIG_CMD_TIMEOUT_SEC}" openclaw models list --plain || true
        echo ""
        continue
        ;;
      *) break ;;
    esac
  done
  if ! confirm_action "确认设置为默认模型：${model} ？"; then warn "已取消"; return 1; fi
  local agent_dir
  agent_dir="$(agent_root_dir "$agent_id")"
  mkdir -p "$agent_dir" >/dev/null 2>&1 || true
  local rc=0
  run_cmd_timeout "${OC_MODELS_SET_TIMEOUT_SEC}" env OPENCLAW_AGENT_DIR="$agent_dir" openclaw models set "$model"
  rc=$?
  if is_timeout_rc "$rc"; then
    warn "models set 超时（${OC_MODELS_SET_TIMEOUT_SEC}s）。可能是 CLI/网络卡住；建议稍后重试或运行 openclaw doctor。"
    return 0
  fi
  if [[ $rc -eq 0 ]]; then ok "已设置默认模型（会话可能有 stickiness；如未生效请 /new 或 /reset 开新会话）"; else err "models set 失败（exit=$rc）"; fi
  return 0
}

# ------------------------------------------------------------------------------
# 5.x Codex 多账号（同一 agent 内）切换：auth order + <profileId>
# ------------------------------------------------------------------------------
json_array() {
  local out="[" first=1 s
  for s in "$@"; do
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    if [[ $first -eq 1 ]]; then first=0; else out+=","; fi
    out+="\"$s\""
  done
  out+="]"
  echo "$out"
}

codex_profile_ids_for_agent() {
  local agent_id="$1" provider="openai-codex"
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
profiles=data.get('profiles', {})
ids=[]

def add(pid):
  if isinstance(pid,str) and pid and pid not in ids:
    ids.append(pid)

if isinstance(profiles, dict):
  for pid,obj in profiles.items():
    if not isinstance(pid,str):
      continue
    if pid.startswith(provider+':'):
      add(pid)
    elif isinstance(obj, dict) and obj.get('provider')==provider:
      add(pid)
elif isinstance(profiles, list):
  for obj in profiles:
    if not isinstance(obj, dict):
      continue
    pid=obj.get('id') or obj.get('profileId') or obj.get('profile_id')
    prov=obj.get('provider')
    if isinstance(pid,str) and (pid.startswith(provider+':') or prov==provider):
      add(pid)

for pid in sorted(ids):
  print(pid)
PY
    return 0
  fi
  return 2
}

codex_profiles_table_for_agent() {
  local agent_id="$1" provider="openai-codex"
  local f
  f="$(auth_profiles_file_for_agent "$agent_id")" || { warn "未找到该 agent 的 auth-profiles.json（请先登录一次）"; return 1; }
  print_section "Codex profiles（agent=${agent_id}）"
  echo -e " 文件：$f"
  echo ""
  if ! command_exists python3; then
    warn "未检测到 python3，无法解析并显示 profiles 表格。"
    return 0
  fi
  python3 - "$f" "$provider" <<'PY'
import json,sys,datetime
path=sys.argv[1]
provider=sys.argv[2]

def fmt_ms(ms):
  if not isinstance(ms,(int,float)):
    return ''
  try:
    dt=datetime.datetime.fromtimestamp(ms/1000, tz=datetime.timezone.utc)
    return dt.isoformat().replace('+00:00','Z')
  except Exception:
    return str(ms)

with open(path,'r',encoding='utf-8') as fp:
  data=json.load(fp)

profiles=data.get('profiles', {})
usage=data.get('usageStats', {}) if isinstance(data.get('usageStats', {}), dict) else {}
rows=[]

if isinstance(profiles, dict):
  for pid,obj in profiles.items():
    if not isinstance(pid,str):
      continue
    if not (pid.startswith(provider+':') or (isinstance(obj, dict) and obj.get('provider')==provider)):
      continue
    typ=ident=exp=''
    if isinstance(obj, dict):
      typ=str(obj.get('type') or obj.get('mode') or '')
      ident=str(obj.get('email') or obj.get('accountId') or obj.get('account_id') or '')
      exp=fmt_ms(obj.get('expires'))
    stat=usage.get(pid, {}) if isinstance(usage, dict) else {}
    cooldown=fmt_ms(stat.get('cooldownUntil')) if isinstance(stat, dict) else ''
    disabled=fmt_ms(stat.get('disabledUntil')) if isinstance(stat, dict) else ''
    rows.append((pid, typ, ident, exp, cooldown, disabled))

rows.sort(key=lambda r:r[0])

if not rows:
  print('(未找到 openai-codex profiles；请先执行 Codex OAuth 登录：openclaw models auth login --provider openai-codex)')
  sys.exit(0)

hdr=('profileId','type','email/accountId','expires(UTC)','cooldownUntil','disabledUntil')
print(f"{hdr[0]:<42} {hdr[1]:<8} {hdr[2]:<28} {hdr[3]:<24} {hdr[4]:<24} {hdr[5]:<24}")
for pid,typ,ident,exp,cd,ds in rows:
  ident=(ident or '')[:28]
  print(f"{pid:<42} {typ:<8} {ident:<28} {exp[:24]:<24} {cd[:24]:<24} {ds[:24]:<24}")
PY
}

codex_auth_order_get() {
  local agent_id="$1"
  print_section "查看当前 Codex 账号优先顺序（auth order，agent=${agent_id}）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  local rc=0
  run_cmd_timeout "${OC_AUTH_ORDER_TIMEOUT_SEC}" openclaw models auth order get --provider openai-codex --agent "$agent_id"
  rc=$?
  if [[ $rc -eq 0 ]]; then return 0; fi
  if is_timeout_rc "$rc"; then warn "models auth order get 超时（${OC_AUTH_ORDER_TIMEOUT_SEC}s）。"; else warn "models auth order get 失败（exit=$rc）。"; fi
  warn "尝试从配置读取 auth.order[openai-codex] 作为兜底。"
  run_cmd_timeout "${OC_CONFIG_CMD_TIMEOUT_SEC}" openclaw config get 'auth.order["openai-codex"]' || true
  return 0
}

codex_auth_order_set() {
  local agent_id="$1"; shift || true
  local ids=("$@")
  if [[ ${#ids[@]} -eq 0 ]]; then warn "未提供 profileId，取消"; return 1; fi
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -e " 将设置 openai-codex 的账号优先顺序为："
  local i
  for i in "${ids[@]}"; do echo -e " - ${GREEN}${i}${NC}"; done
  echo ""
  if ! confirm_action "确认写入该 agent 的 Codex 顺序？"; then warn "已取消"; return 1; fi
  local rc=0
  run_cmd_timeout "${OC_AUTH_ORDER_TIMEOUT_SEC}" openclaw models auth order set --provider openai-codex --agent "$agent_id" "${ids[@]}"
  rc=$?
  if [[ $rc -eq 0 ]]; then ok "已设置（会话可能有 stickiness；建议 /new 或 /reset 开新会话测试）"; return 0; fi
  if is_timeout_rc "$rc"; then warn "models auth order set 超时（${OC_AUTH_ORDER_TIMEOUT_SEC}s）。将尝试配置兜底写入。";
  else warn "models auth order set 失败（exit=$rc）。将尝试配置兜底写入。"; fi
  local arr_json
  arr_json="$(json_array "${ids[@]}")"
  run_cmd_timeout "${OC_CONFIG_CMD_TIMEOUT_SEC}" openclaw config set 'auth.order["openai-codex"]' "$arr_json" --json || true
  ok "已写入配置兜底（仍建议稍后用 models status 验证，并必要时重启 gateway）"
  return 0
}

codex_auth_order_clear() {
  local agent_id="$1"
  print_section "清除 Codex 账号优先顺序（恢复自动选择/自动轮询）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  if ! confirm_action "确认清除该 agent 的 openai-codex 顺序覆盖？"; then warn "已取消"; return 1; fi
  local rc=0
  run_cmd_timeout "${OC_AUTH_ORDER_TIMEOUT_SEC}" openclaw models auth order clear --provider openai-codex --agent "$agent_id"
  rc=$?
  if [[ $rc -eq 0 ]]; then ok "已清除（恢复默认顺序/轮询）"; return 0; fi
  if is_timeout_rc "$rc"; then warn "models auth order clear 超时（${OC_AUTH_ORDER_TIMEOUT_SEC}s）。将尝试配置兜底清除。";
  else warn "models auth order clear 失败（exit=$rc）。将尝试配置兜底清除。"; fi
  run_cmd_timeout "${OC_CONFIG_CMD_TIMEOUT_SEC}" openclaw config unset 'auth.order["openai-codex"]' || true
  ok "已执行兜底清除（仍建议稍后 models status 验证，并必要时重启 gateway）"
  return 0
}

codex_set_preferred_profile_interactive() {
  local agent_id="$1"
  local ids=()
  if mapfile -t ids < <(codex_profile_ids_for_agent "$agent_id"); then :; else warn "无法自动读取 profileId（可能未登录或缺少解析工具）。"; fi
  if [[ ${#ids[@]} -eq 0 ]]; then
    warn "未发现任何 openai-codex profiles。请先执行：openclaw models auth login --provider openai-codex"
    return 1
  fi

  print_section "选择要优先使用的 Codex profile（agent=${agent_id}）"
  local i
  for i in "${!ids[@]}"; do
    printf " %s) %s\n" "$((i+1))" "${ids[$i]}"
  done
  echo -ne " 请选择序号 [1-${#ids[@]}]（回车取消）: "
  local pick
  IFS= read -r pick <"$TTY" || true
  pick="${pick:-}"
  if [[ -z "$pick" ]]; then warn "已取消"; return 1; fi
  if ! [[ "$pick" =~ ^[0-9]+$ ]]; then warn "输入不是数字"; return 1; fi
  if (( pick < 1 || pick > ${#ids[@]} )); then warn "超出范围"; return 1; fi

  local chosen="${ids[$((pick-1))]}"
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
  echo -e " 示例：openai-codex:default openai-codex:alt"
  echo -ne " 输入 profileId 列表（回车取消）: "
  local line
  IFS= read -r line <"$TTY" || true
  line="${line:-}"
  if [[ -z "$line" ]]; then warn "已取消"; return 1; fi
  # shellcheck disable=SC2206
  local ids=($line)
  if [[ ${#ids[@]} -eq 0 ]]; then warn "未解析到 profileId"; return 1; fi
  codex_auth_order_set "$agent_id" "${ids[@]}"
}

codex_make_session_pin_command() {
  print_section "生成 /model …@<profileId>（会话级固定账号）"
  echo -e " ${DIM}说明：这是“会话级”固定账号，不改全局顺序。${NC}"
  echo -e " ${DIM}格式：/model <provider/model>@<profileId>${NC}"
  echo -e " ${DIM}例如：/model openai-codex/gpt-5.2@openai-codex:alt${NC}"
  echo ""
  echo -ne " 输入模型（回车=openai-codex/gpt-5.2）: "
  local model
  IFS= read -r model <"$TTY" || true
  model="${model:-openai-codex/gpt-5.2}"
  echo -ne " 输入 profileId（例如 openai-codex:default / openai-codex:alt）: "
  local pid
  IFS= read -r pid <"$TTY" || true
  pid="${pid:-}"
  if [[ -z "$pid" ]]; then warn "未输入 profileId，取消"; return 1; fi
  echo ""
  ok "复制下面这行到 Telegram/控制台对话里："
  echo -e " ${BOLD}/model ${model}@${pid}${NC}"
  echo ""
  echo -e " ${DIM}注意：OpenClaw 有 session stickiness；要让新的 pinned 生效，可能需要 /new 或 /reset 开新会话。${NC}"
}

menu_codex_profiles() {
  local agent_id="$DEFAULT_AGENT_ID"
  while true; do
    print_header
    show_status_bar
    print_section "Codex 多账号（同一 agent）：选择默认账号 / 设置优先顺序"
    echo -e " 当前 agent: ${GREEN}${agent_id}${NC}"
    echo -e " ${DIM}说明：同一 agent 可保存多个 openai-codex OAuth profile。你可以：${NC}"
    echo -e " ${DIM}- 设定“默认账号优先顺序”（全局生效）${NC}"
    echo -e " ${DIM}- 在聊天里用 /model …@profileId 给“当前会话”固定账号${NC}"
    echo ""
    echo -e " ${GREEN}1.${NC} 查看已登录的 Codex 账号列表（profiles）"
    echo -e " ${GREEN}2.${NC} 查看当前“默认账号优先顺序”（auth order）"
    echo -e " ${GREEN}3.${NC} 选一个账号作为默认（其他账号自动备用）"
    echo -e " ${GREEN}4.${NC} 手动设置优先顺序（输入多个 profileId）"
    echo -e " ${GREEN}5.${NC} 清空优先顺序（恢复自动选择）"
    echo -e " ${GREEN}6.${NC} 生成会话固定命令（/model …@profileId）"
    echo -e " ${GREEN}0.${NC} 返回上级菜单"
    echo ""
    echo -ne " ${YELLOW}➤${NC} 请选择 [0-6]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1) print_header; codex_profiles_table_for_agent "$agent_id"; press_any_key ;;
      2) print_header; codex_auth_order_get "$agent_id"; press_any_key ;;
      3) print_header; codex_set_preferred_profile_interactive "$agent_id"; press_any_key ;;
      4) print_header; codex_set_order_manual "$agent_id"; press_any_key ;;
      5) print_header; codex_auth_order_clear "$agent_id"; press_any_key ;;
      6) print_header; codex_make_session_pin_command; press_any_key ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

menu_models_auth() {
  local agent_id="$DEFAULT_AGENT_ID"
  while true; do
    print_header
    show_status_bar
    print_section "模型与账号授权（单 agent 多账号：登录、换模型、设置默认账号顺序）"
    echo -e " 当前 agent 固定为：${GREEN}${agent_id}${NC}"
    echo ""
    echo -e " ${GREEN}1.${NC} 查看状态（当前模型 / 已登录账号）"
    echo -e " ${GREEN}2.${NC} 一键检查登录是否可用（缺失/过期/将过期）"
    echo -e " ${GREEN}3.${NC} 登录 Codex（ChatGPT 订阅 / OAuth）"
    echo -e " ${GREEN}4.${NC} 登录其它平台（选择 provider）"
    echo -e " ${GREEN}5.${NC} 填写/更新 API Key（粘贴 token）"
    echo -e " ${GREEN}6.${NC} Claude 订阅：导入 setup-token"
    echo -e " ${GREEN}7.${NC} 切换默认模型（只影响 main agent）"
    echo -e " ${GREEN}8.${NC} Codex 多账号管理（profiles / auth order / 会话固定）"
    echo -e " ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne " ${YELLOW}➤${NC} 请选择 [0-8]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1) print_header; models_status_for_agent "$agent_id"; press_any_key ;;
      2) print_header; models_check_for_agent "$agent_id"; press_any_key ;;
      3) print_header; models_auth_login_codex "$agent_id"; echo ""; models_status_for_agent "$agent_id" || true; press_any_key ;;
      4) print_header; models_auth_login_generic "$agent_id"; press_any_key ;;
      5) print_header; models_auth_paste_token "$agent_id"; press_any_key ;;
      6) print_header; models_auth_setup_token_anthropic "$agent_id"; press_any_key ;;
      7) print_header; models_set_default_model "$agent_id"; press_any_key ;;
      8) menu_codex_profiles ;;
      0) return 0 ;;
      *) warn "无效选项"; press_any_key ;;
    esac
  done
}

# ==============================================================================
# 6) Telegram 机器人管理
# ==============================================================================
telegram_set_bot_token() {
  print_section "配置 Telegram botToken（写入 openclaw.json）"
  if ! command_exists openclaw; then err "未安装 openclaw"; return 1; fi
  echo -e " 参考官方配置键：channels.telegram.botToken（以及 enabled / dmPolicy）。"
  echo -ne " 输入 Bot Token（形如 123456:ABC...）: "
  local token
  IFS= read -r token <"$TTY" || true
  token="${token:-}"
  if [[ -z "$token" ]]; then warn "未输入 token，取消"; return 1; fi
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
  echo -ne " 输入 pairing CODE（DM 未授权用户时给出的短码）: "
  local code
  IFS= read -r code <"$TTY" || true
  code="${code:-}"
  if [[ -z "$code" ]]; then warn "未输入 code，取消"; return 1; fi
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
    echo -e " ${GREEN}1.${NC} 运行渠道配置向导（openclaw configure --section channels）"
    echo -e " ${GREEN}2.${NC} 写入 botToken 并启用 Telegram（config set）"
    echo -e " ${GREEN}3.${NC} 查看当前 Telegram 配置（config get channels.telegram）"
    echo -e " ${GREEN}4.${NC} 查看 pairing 列表（pairing list telegram）"
    echo -e " ${GREEN}5.${NC} 批准 pairing code（pairing approve telegram <CODE>）"
    echo -e " ${GREEN}6.${NC} channels status（频道健康检查）"
    echo -e " ${GREEN}7.${NC} 查看 Gateway 日志（openclaw logs --follow）"
    echo -e " ${GREEN}8.${NC} 重启 Gateway（gateway restart）"
    echo -e " ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne " ${YELLOW}➤${NC} 请选择 [0-8]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1) print_header; print_section "openclaw configure --section channels"; command_exists openclaw && run_cmd openclaw configure --section channels || err "未安装 openclaw"; press_any_key ;;
      2) print_header; telegram_set_bot_token; press_any_key ;;
      3) print_header; print_section "config get channels.telegram"; command_exists openclaw && run_cmd openclaw config get channels.telegram || err "未安装 openclaw"; press_any_key ;;
      4) print_header; telegram_pairing_list; press_any_key ;;
      5) print_header; telegram_pairing_approve; press_any_key ;;
      6) print_header; telegram_channels_status; press_any_key ;;
      7) print_header; print_section "openclaw logs --follow"; if command_exists openclaw; then echo -e " ${DIM}按 Ctrl+C 退出日志跟随${NC}"; run_cmd openclaw logs --follow; else err "未安装 openclaw"; fi; press_any_key ;;
      8) print_header; telegram_restart_gateway; press_any_key ;;
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
    echo -e " ${GREEN}1.${NC} 查看本脚本日志（tail -n 200）"
    echo -e " ${GREEN}2.${NC} 跟随本脚本日志（tail -f）"
    echo -e " ${GREEN}3.${NC} 查看 Gateway 日志（openclaw logs --limit 200）"
    echo -e " ${GREEN}4.${NC} 跟随 Gateway 日志（openclaw logs --follow）"
    echo -e " ${GREEN}0.${NC} 返回主菜单"
    echo ""
    echo -ne " ${YELLOW}➤${NC} 请选择 [0-4]: "
    local c
    c="$(read_choice)"
    case "$c" in
      1) print_header; print_section "脚本日志（tail -n 200）"; tail -n 200 "$LOG_FILE" 2>/dev/null || true; press_any_key ;;
      2) print_header; print_section "跟随脚本日志（Ctrl+C 退出）"; tail -f "$LOG_FILE" 2>/dev/null || true; press_any_key ;;
      3) print_header; print_section "Gateway 日志（limit 200）"; command_exists openclaw && run_cmd openclaw logs --limit 200 || err "未安装 openclaw"; press_any_key ;;
      4) print_header; print_section "跟随 Gateway 日志（Ctrl+C 退出）"; command_exists openclaw && run_cmd openclaw logs --follow || err "未安装 openclaw"; press_any_key ;;
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
  cat <<EOF
1) 多账号（Codex OAuth）怎么用？
   - 在【主菜单 5 -> 3】执行登录（每登录一次会多一个 profileId）
   - 在【主菜单 5 -> 8】管理 profiles：
     - 查看 profiles 列表
     - 设置默认优先顺序（auth order）= 默认账号 + 故障切换
     - 生成 /model ...@profileId 用于会话级固定账号

2) “配置了 Codex 账号但提示找不到账号 / Missing auth”
   - 本脚本采用单一 agent(main) 模式，避免 agent 不一致导致的找不到账号
   - 仍可用【主菜单 5 -> 1】查看 models status

3) Telegram 不回消息 / DM 没权限
   - 默认 DM 策略 pairing：先 DM 机器人拿到 code，再用【主菜单 6 -> 5】approve
   - 用【主菜单 6 -> 6】channels status / 【主菜单 2】doctor/health 排查

4) 安装推荐
   - 优先用【主菜单 1 -> 1】官方 install.sh：确保 Node 22+ 并处理 Linux npm 常见坑
EOF
  press_any_key
}

# ==============================================================================
# 主菜单
# ==============================================================================
show_main_menu() {
  print_header
  show_status_bar
  echo -e "${WHITE} 主菜单${NC} "
  echo -e " ${GREEN}1.${NC} 安装/更新 OpenClaw"
  echo -e " ${GREEN}2.${NC} 扫描/诊断（status/health/doctor）"
  echo -e " ${GREEN}3.${NC} 一键完整卸载（官方优先 + 兜底清理）"
  echo -e " ${GREEN}4.${NC} 选择性卸载/清理"
  echo -e " ${GREEN}5.${NC} 模型与认证（单 agent 多账号：Codex/OAuth/API Key）"
  echo -e " ${GREEN}6.${NC} Telegram 机器人管理"
  echo -e " ${GREEN}7.${NC} 查看日志"
  echo -e " ${GREEN}8.${NC} 帮助信息"
  echo -e " ${GREEN}0.${NC} 退出"
  echo ""
  echo -ne " ${YELLOW}➤${NC} 请选择 [0-8]: "
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
