#!/usr/bin/env bash
# install.sh — Development Team V1 installer
# 幂等：重复执行安全，不覆盖用户已有文件
# 用法：bash install.sh [--workspace <path>] [--repo <path>] [--skip-preflight]
# 多 Agent 说明：Development Team 是 Main Agent / Team-level capability，默认安装到
#   shared managed skills（~/.openclaw/skills，所有本机 agent 可见），不复制到每个
#   Developer/Reviewer 私有 workspace。安装前自动运行 Multi-Agent Installation
#   Context Preflight（scripts/agent-context-check.sh，只读无副作用）。
set -euo pipefail

# ─── 颜色 ───
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── 动态解析路径（不硬编码） ───
# 优先环境变量，其次从 OpenClaw 运行时解析；无 openclaw 时不得静默 fallback。
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"

# 路径解析状态变量（0=dynamic 成功, 1=legacy fallback, 2=未解析）
WS_RESOLVED=0; MANAGED_RESOLVED=0; AGENT_RESOLVED=0

# 调用 openclaw skills check 并取出指定 JSON 字段；失败输出空
openclaw_field() { # $1=字段名
  openclaw skills check --json 2>/dev/null | python3 -c "
import sys, json
field='$1'
try:
    d=json.load(sys.stdin); print(d.get(field,'') or '')
except Exception:
    print('')" 2>/dev/null
}

# 解析当前 agent workspace（用 openclaw skills check 官方 API）
# 返回：0=dynamic 成功, 1=fallback（显式标记 LEGACY FALLBACK）
resolve_workspace() {
  if [[ -n "${OPENCLAW_WORKSPACE_DIR:-}" ]]; then
    echo "$OPENCLAW_WORKSPACE_DIR"; WS_RESOLVED=0; return 0
  fi
  local out="$(openclaw_field workspaceDir)"
  if [[ -n "$out" ]]; then
    echo "$out"; WS_RESOLVED=0; return 0
  fi
  # openclaw API 无法解析 → 不静默放行，显式标记 LEGACY FALLBACK
  echo "$OPENCLAW_HOME/workspace"
  WS_RESOLVED=1
  echo "  [LEGACY FALLBACK] openclaw 无法解析 workspaceDir → 使用旧默认 $OPENCLAW_HOME/workspace" >&2
  return 1
}

# 解析 shared managed skills 目录
resolve_managed_skills() {
  local out="$(openclaw_field managedSkillsDir)"
  if [[ -n "$out" ]]; then
    echo "$out"; MANAGED_RESOLVED=0; return 0
  fi
  echo "$OPENCLAW_HOME/skills"
  MANAGED_RESOLVED=1
  echo "  [LEGACY FALLBACK] openclaw 无法解析 managedSkillsDir → 使用旧默认 $OPENCLAW_HOME/skills" >&2
  return 1
}

# 解析 openclaw.json 中的 Main Agent id（按指定 agent 查询；无参只作 fallback）
# 修复：无参 `openclaw skills check` 会落到 CLI default agent（如本机=宝总），
#       可能并非真正 Main Agent。因此优先用户显式 --main-agent；
#       否则用显式 --workspace 推断的 agent；最后才 fallback 到无参 API。
resolve_main_agent() {
  # 1) 用户显式指定
  if [[ -n "${MAIN_AGENT_EXPLICIT:-}" ]]; then
    echo "$MAIN_AGENT_EXPLICIT"; AGENT_RESOLVED=0; return 0
  fi
  # 2) 若用户显式给了 workspace，尝试从该 agent 推断（用带 --agent 查询反推 workspace 匹配）
  if [[ "$WORKSPACE_EXPLICIT" -eq 1 && -n "${OPENCLAW_HOME:-}" ]]; then
    local cfg="$OPENCLAW_HOME/openclaw.json"
    if [[ -f "$cfg" ]]; then
      local ws="$(cd "$WORKSPACE" && pwd 2>/dev/null)"
      local match="$(python3 -c "
import json,os,re
p='$cfg'
try:
    d=json.load(open(p))
    for a in d.get('agents',{}).get('list',[]):
        w=a.get('workspace','')
        w=os.path.expanduser(w)
        if os.path.realpath(w)==os.path.realpath('$WORKSPACE'):
            print(a.get('id','')); break
except Exception: pass
" 2>/dev/null)"
      if [[ -n "$match" ]]; then
        echo "$match"; AGENT_RESOLVED=0; return 0
      fi
    fi
  fi
  # 3) fallback：无参 API（可能落到 CLI 默认 agent，标 LEGACY FALLBACK 提醒）
  local out="$(openclaw_field agentId)"
  if [[ -n "$out" ]]; then
    AGENT_RESOLVED=1
    echo "  [LEGACY FALLBACK] 未指定 Main Agent，openclaw 默认解析为 '$out'（可能是 CLI 默认 agent 而非主 agent，请用 --main-agent 显式指定）" >&2
    echo "$out"; return 0
  fi
  AGENT_RESOLVED=1
  echo "  [LEGACY FALLBACK] openclaw 无法解析 agentId" >&2
  echo ""
  return 1
}

# ─── 参数解析 ───
WORKSPACE=""
REPO_DIR=""
SKIP_PREFLIGHT=0
WORKSPACE_EXPLICIT=0
MAIN_AGENT_EXPLICIT=""
SKILL_MODE=""   # shared | agent
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; WORKSPACE_EXPLICIT=1; shift 2 ;;
    --main-agent) MAIN_AGENT_EXPLICIT="$2"; shift 2 ;;
    --skill-location) SKILL_MODE="$2"; shift 2 ;;
    --repo)      REPO_DIR="$2"; shift 2 ;;
    --skip-preflight) SKIP_PREFLIGHT=1; shift ;;
    -h|--help)
      echo "用法: bash install.sh [--workspace <path>] [--main-agent <id>] [--skill-location shared|agent] [--repo <path>] [--skip-preflight]"
      echo "  --workspace        Development Team 主体安装到哪个 workspace（默认 openclaw 解析）"
      echo "  --main-agent       主 Agent id（如 jarvis）。避免 openclaw 误判为 CLI 默认 agent（如宝总）"
      echo "  --skill-location    Skill 安装为 shared managed（默认, 所有 agent 可见）或 agent 私有"
      echo "  --repo             Development Team 仓库路径 (默认: 自动 clone)"
      echo "  --skip-preflight   跳过 Multi-Agent Installation Context Preflight"
      exit 0 ;;
    *) error "未知参数: $1" ;;
  esac
done

# ─── 预检 ───
info "=== Development Team V1 安装 ==="
command -v git  >/dev/null 2>&1 || error "需要 git，请先安装"
command -v bash >/dev/null 2>&1 || error "需要 bash"

# 未手动指定 workspace → 动态解析
if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="$(resolve_workspace)"
  if [[ "$WS_RESOLVED" -eq 1 ]]; then
    warn "路径采用 LEGACY FALLBACK（openclaw 动态解析失败）— 不会被当作动态解析成功"
  else
    info "Main Agent workspace (openclaw 动态解析): $WORKSPACE"
  fi
fi

# 解析 Main Agent + managed skills 目录
MAIN_AGENT="$(resolve_main_agent)"
MANAGED_SKILLS="$(resolve_managed_skills)"
SHARED_SKILL_SRC="$MANAGED_SKILLS"

if [[ -n "$MAIN_AGENT" ]]; then
  info "Main Agent: $MAIN_AGENT"
else
  warn "未能识别 Main Agent id（openclaw skills check 未返回 agentId）"
fi
if [[ "$AGENT_RESOLVED" -eq 1 || "$MANAGED_RESOLVED" -eq 1 ]]; then
  warn "部分路径解析为 LEGACY FALLBACK，后续 preflight/安装请结合 NOT RUN / INSTALL BLOCKED 判定"
fi

# ─── Multi-Agent Installation Context Preflight ───
# 只读、无副作用；验证环境能力 + discovery 原则，不执行真实安装。
# 三态结果处理：exited 0=PASS / 2=WARN / 3=NOT RUN / 1=BLOCKING FAIL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SKIP_PREFLIGHT" -eq 1 ]]; then
  warn "已 --skip-preflight 跳过 Preflight — 安装前环境未验证，请自行确保就绪"
elif [[ -f "$SCRIPT_DIR/scripts/agent-context-check.sh" ]]; then
  info "=== Multi-Agent Installation Context Preflight ==="
  # 用 `|| rc=$?` 捕获退出码，避免 set -e 在非零时直接终止而吞掉状态处理
  PREFLIGHT_RC=0
  PREFLIGHT_REPO="$REPO_DIR"
  # 未指定 --repo（将自动 clone/或用本地）：让 preflight 用 DT 仓库本体路径作为调用链源，避免 NOT RUN 死锁
  if [[ -z "$PREFLIGHT_REPO" ]]; then
    PREFLIGHT_REPO="$SCRIPT_DIR"
  fi
  if [[ -n "$MAIN_AGENT" ]]; then
    bash "$SCRIPT_DIR/scripts/agent-context-check.sh" --agent "$MAIN_AGENT" --repo "$PREFLIGHT_REPO" || PREFLIGHT_RC=$?
  else
    bash "$SCRIPT_DIR/scripts/agent-context-check.sh" --repo "$PREFLIGHT_REPO" || PREFLIGHT_RC=$?
  fi
  case "$PREFLIGHT_RC" in
    0) info "Preflight → PASS" ;;
    2) warn "Preflight → WARN（有非阻断警告，继续安装，请留意）" ;;
    3) error "Preflight → NOT RUN（存在无法验证项，不认定为 PASS）→ INSTALL BLOCKED" ;;
    *) error "Preflight → BLOCKING FAIL（存在阻断缺陷）→ INSTALL BLOCKED" ;;
  esac
else
  error "未找到 agent-context-check.sh，无法执行必需的 Multi-Agent Preflight → INSTALL BLOCKED（可用 --skip-preflight 显式跳过）"
fi

# 检查 workspace 是否存在
if [[ ! -d "$WORKSPACE" ]]; then
  info "Workspace 不存在，创建: $WORKSPACE"
  mkdir -p "$WORKSPACE"
fi

# 确定安装位置：Team-level capability → shared managed skills（所有 agent 可见）
# 不把 Development Team Skill 重复复制到每个 Developer/Reviewer 私有 workspace。
# 修复：skill 位置由 --skill-location 显式决定（默认 shared），不再因 --workspace 自动变私有——
#       旧逻辑会导致「显式 --workspace 时 skill 装到私有，而未覆盖 shared」，产生重复副本。
if [[ "$SKILL_MODE" == "agent" ]]; then
  SKILL_PARENT="$WORKSPACE/skills"
  info "Skill 安装位置（--skill-location=agent 私有）: $WORKSPACE/skills/development-team"
elif [[ -n "$SHARED_SKILL_SRC" ]] && [[ -d "$SHARED_SKILL_SRC" ]]; then
  SKILL_PARENT="$SHARED_SKILL_SRC"
  info "Skill 安装位置（shared managed，Team-level，所有 agent 可见）: $SHARED_SKILL_SRC/development-team"
else
  SKILL_PARENT="$WORKSPACE/skills"
  info "Skill 安装位置（Main Agent workspace）: $WORKSPACE/skills/development-team"
fi

DT_DIR="$WORKSPACE/openclaw-development-team"
SKILL_DIR="$SKILL_PARENT/development-team"

# ─── 获取仓库 ───
if [[ -n "$REPO_DIR" ]]; then
  # 用本地仓库（复制）
  if [[ ! -d "$REPO_DIR" ]]; then
    error "仓库路径不存在: $REPO_DIR"
  fi
  info "从本地仓库安装: $REPO_DIR"
  INSTALL_MODE="copy"
else
  # clone 到临时目录
  INSTALL_MODE="clone"
fi

# ─── 安装核心文件 ───
install_files() {
  local src="$1"

  # 1. 复制仓库主体到 openclaw-development-team/
  if [[ -d "$DT_DIR" ]]; then
    warn "openclaw-development-team/ 已存在，跳过（不覆盖）"
  else
    info "安装仓库主体 → openclaw-development-team/"
    mkdir -p "$DT_DIR"
    # 复制除 .git 外的所有文件
    (cd "$src" && tar --exclude='.git' -cf - .) | tar -xf - -C "$DT_DIR"
  fi

  # 版本链 manifest（P0 交付一致性：让安装副本可报告 commit / installed_at）
  # 只在本次实际写入时更新；已存在目录不覆盖文件，但 manifest 始终刷新到最新安装源。
  if [[ -d "$DT_DIR" ]]; then
    local _commit="unknown"
    if git -C "$src" rev-parse HEAD >/dev/null 2>&1; then
      _commit="$(git -C "$src" rev-parse HEAD)"
    elif [[ -f "$src/.git/HEAD" ]]; then
      _commit="$(tr -d '[:space:]' < "$src/.git/HEAD" 2>/dev/null)"
    fi
    printf '%s' "$_commit" > "$DT_DIR/VERSION_COMMIT"
    date +%Y-%m-%dT%H:%M:%S%z > "$DT_DIR/INSTALLED_AT"
    info "版本链 manifest 已写入: VERSION_COMMIT=$_commit"
  fi

  # 2. 安装 Skill 入口（不覆盖已有）
  mkdir -p "$SKILL_DIR"
  if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
    warn "skills/development-team/SKILL.md 已存在，跳过（不覆盖）"
  else
    info "安装 Skill → skills/development-team/SKILL.md"
    cp "$src/skills/development-team/SKILL.md" "$SKILL_DIR/SKILL.md"
  fi

  # 3. 确保脚本可执行（显式错误处理：失败不再 || true 静默吞掉，而是记录原因）
  if [[ -d "$DT_DIR/scripts" ]]; then
    if ! chmod +x "$DT_DIR/scripts/"*.sh 2>/dev/null; then
      warn "chmod +x *.sh 失败（部分脚本可能不可执行）— 安装继续，但 Reviewer 前请检查"
    fi
    if ! chmod +x "$DT_DIR/scripts/"*.py 2>/dev/null; then
      warn "chmod +x *.py 失败（部分脚本可能不可执行）— 安装继续，但 Reviewer 前请检查"
    fi
  fi
}

if [[ "$INSTALL_MODE" == "copy" ]]; then
  install_files "$REPO_DIR"
else
  # clone 到临时目录
  TMPDIR_CLONE=$(mktemp -d)
  trap 'rm -rf "$TMPDIR_CLONE"' EXIT
  info "Clone 仓库..."
  git clone --depth 1 https://github.com/BruceTangc/openclaw-development-team.git "$TMPDIR_CLONE/repo" 2>&1 | tail -3
  install_files "$TMPDIR_CLONE/repo"
fi

# ─── Smoke Test ───
info ""
info "=== Smoke Test ==="
PASS=true

# 1. Skill 文件存在
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
  info "✅ Skill 文件存在: $SKILL_DIR/SKILL.md"
else
  error "❌ Skill 文件缺失"
  PASS=false
fi

# 2. AGENTS.md 入口存在
if [[ -f "$DT_DIR/AGENTS.md" ]]; then
  info "✅ AGENTS.md 入口存在: $DT_DIR/AGENTS.md"
else
  error "❌ AGENTS.md 缺失"
  PASS=false
fi

# 3. 协议目录存在
if [[ -d "$DT_DIR/protocols" ]]; then
  PROTOCOL_COUNT=$(ls "$DT_DIR/protocols/"*.md 2>/dev/null | wc -l)
  info "✅ 协议目录存在: $PROTOCOL_COUNT 个协议文件"
else
  error "❌ protocols/ 缺失"
  PASS=false
fi

# 4. 脚本可执行
if [[ -f "$DT_DIR/scripts/check-hygiene.sh" ]] && [[ -x "$DT_DIR/scripts/check-hygiene.sh" ]]; then
  info "✅ 脚本可执行: check-hygiene.sh"
else
  warn "⚠️  脚本不可执行（非致命）"
fi

# 5. Developer Agent 定义存在
if [[ -f "$DT_DIR/agents/developer/AGENTS.md" ]]; then
  info "✅ Developer Agent 定义存在"
else
  warn "⚠️  agents/developer/AGENTS.md 缺失（非致命）"
fi

# 6. 检查无个人绝对路径
if grep -r "/root/\|/home/[^/]*" "$DT_DIR" --include="*.md" --include="*.sh" --include="*.yaml" 2>/dev/null | grep -v "example\|template\|placeholder\|# " | head -5; then
  warn "⚠️  发现潜在个人路径（请检查）"
else
  info "✅ 无个人绝对路径"
fi

# 7. OpenClaw Discovery / Eligibility（P0-6：SKILL.md exists ≠ 安装成功）
# 三层判定：installed（文件就位）→ discovered（OpenClaw 可见）→ eligible（可被 Agent 使用）。
# 优先用 openclaw skills info 官方 discovery API，不自己解析 OpenClaw 内部文件实现第二套 discovery。
SKILL_NAME="development-team"
DISCOVERED=false
ELIGIBLE=false
if command -v openclaw >/dev/null 2>&1; then
  SKILL_INFO="$(openclaw skills info "$SKILL_NAME" --json 2>/dev/null)"
  if [[ -n "$SKILL_INFO" ]]; then
    INFO_ELIGIBLE="$(echo "$SKILL_INFO" | python3 -c "import sys,json;
try: d=json.load(sys.stdin); print(str(d.get('eligible','')).lower())
except: print('')" 2>/dev/null)"
    INFO_PATH="$(echo "$SKILL_INFO" | python3 -c "import sys,json;
try: d=json.load(sys.stdin); print(d.get('filePath','') or '')
except: print('')" 2>/dev/null)"
    if [[ -n "$INFO_PATH" ]]; then
      DISCOVERED=true
      info "✅ OpenClaw 发现 skill（discovered）: $INFO_PATH"
      if [[ "$INFO_ELIGIBLE" == "true" ]]; then
        ELIGIBLE=true
        info "✅ Skill eligible（Agent 可使用）"
      else
        warn "⚠️  Skill 被发现但 not eligible（eligible=$INFO_ELIGIBLE）— 检查 allowlist / agent filter / requirements"
      fi
    fi
  fi
  # fallback：skills check --agent（显式指定 main agent，避免落到 CLI 默认 agent 如宝总）
  if [[ "$DISCOVERED" != "true" && -n "$MAIN_AGENT" ]]; then
    if openclaw skills check --agent "$MAIN_AGENT" --json 2>/dev/null | python3 -c "import sys,json;
try:
 d=json.load(sys.stdin); sys.exit(0 if '$SKILL_NAME' in d.get('eligible',[]) else 1)
except: sys.exit(1)" 2>/dev/null; then
      DISCOVERED=true; ELIGIBLE=true
      info "✅ Skill discovered + eligible（skills check --agent $MAIN_AGENT）"
    fi
  fi
else
  warn "⚠️  openclaw CLI 不可用 — 无法做 discovery/eligibility 验证（LEGACY FALLBACK）"
fi

if [[ "$DISCOVERED" == "true" ]]; then
  if [[ "$ELIGIBLE" == "true" ]]; then
    info "✅ Discovery Verification: installed + discovered + eligible 全部通过"
  else
    warn "⚠️  Discovery Verification: installed + discovered，但 not eligible — 安装不完整，请检查"
  fi
else
  # 最终发现不到 → FAIL（不能 copy succeeded → PASS）
  error "❌ OpenClaw 未发现 development-team skill（discovered=false）— 安装不成功；SKILL.md exists 不足以判定安装成功"
  PASS=false
fi

# 7b. 项目交付就绪检查脚本存在且可执行
if [[ -f "$DT_DIR/scripts/project-readiness-check.sh" ]] && [[ -x "$DT_DIR/scripts/project-readiness-check.sh" ]]; then
  info "✅ 项目交付就绪检查脚本: project-readiness-check.sh"
else
  warn "⚠️  project-readiness-check.sh 缺失或不可执行（非致命）"
fi

# ─── 版本链报告（P0 交付一致性）───
info ""
info "=== Development Team Version Chain ==="
if [[ -f "$DT_DIR/scripts/dt-version.sh" ]]; then
  bash "$DT_DIR/scripts/dt-version.sh" "$DT_DIR" || warn "版本链部分字段缺失（commit/installed_at 未落盘），见上"
else
  warn "⚠️  缺少 dt-version.sh，无法报告版本链"
fi

# ─── 结果 ───
echo ""
if [[ "$PASS" == "true" ]]; then
  info "🎉 安装完成！Development Team V1 已就绪。"
  echo ""
  echo "  文件位置: $DT_DIR"
  echo "  Skill:    $SKILL_DIR/SKILL.md"
  echo ""
  echo "  下一步:"
  echo "    1. 确保 DeepSeek API key 已配置（Developer 模型需要）"
  echo "    2. 确保 gh CLI 已安装并认证（GitHub Release 需要）"
  echo "    3. 对 Agent 说「开发 XXX 功能」即可触发 Development Team 流程"
  echo ""
  echo "  卸载: bash $DT_DIR/uninstall.sh --workspace $WORKSPACE"
else
  error "安装失败，请检查上方错误信息"
fi
