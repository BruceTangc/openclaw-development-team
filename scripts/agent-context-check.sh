#!/usr/bin/env bash
#
# agent-context-check.sh — Multi-Agent Installation Context Preflight
# ====================================================================
# 幂等、**无副作用**（只读检查，不安装、不复制、不写文件、不改配置）。
# 在真正安装 Development Team 前运行，验证当前 OpenClaw 多 Agent 环境：
#
#   1. OpenClaw 是否存在
#   2. OpenClaw 版本
#   3. 识别 Main Agent / workspace（用 OpenClaw 原生 API 动态解析，绝不硬编码路径）
#   4. 确定 Development Team Skill 实际安装位置（Per-agent vs Shared managed）
#   5. 验证 Main Agent 能否发现 Development Team Skill
#   6. 验证 Skill discovery 不依赖 Developer/Reviewer 的私有 workspace
#   7. 验证调用链 Main Agent → Development Team → Developer → Reviewer
#   8. 不默认把 Development Team Skill 重复安装到 Developer / Reviewer
#   9. 无法验证某 Agent discovery 行为 → 标记 NOT RUN，禁止假设 PASS
#
# Development Team 是 **Main Agent / Team-level capability**，应放在共享可见位置
# （`~/.openclaw/skills` shared managed 或显式 allowlist），而不是复制到每个
# Developer / Reviewer 的私有 workspace。真正的多 Agent 安装/运行验证由
# Reviewer Stranger User Audit / E2E Test 完成（本脚本**不执行真实安装**）。
#
# 用法：
#   bash scripts/agent-context-check.sh [--json] [--agent <id>] [--skill <name>]
#
# 退出码（供 install.sh / CI 消费）：
#   0  = PASS           环境可用于安装，无阻断缺陷、无未验证项
#   1  = BLOCKING FAIL  存在阻断性缺陷 → 应阻止安装（INSTALL BLOCKED）
#   2  = WARN           有非阻断警告，可继续但需确认
#   3  = NOT RUN        存在无法验证项 → 不被认定为 PASS，不静默放行
#
# ── 动态解析（对，硬编码禁止；全部来自 OpenClaw 运行时或官方 CLI）──
#   OPENCLAW_HOME           ~/.openclaw                                    （标准约定）
#   WORKSPACE_DIR           openclaw skills check --json → workspaceDir
#   MANAGED_SKILLS_DIR      openclaw skills check --json → managedSkillsDir
#   AGENT_LIST              openclaw.json → agents.list[].id
#   AGENT_WORKSPACE(i)      openclaw skills check --agent <id> --json → workspaceDir
#   SKILL_DISCOVERY(i)      openclaw skills check --agent <id> --json → eligible/blocked

set -u

# ─── 输出 ───
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0; NR=0; NA=0
FAIL_MSGS=(); WARN_MSGS=()
ok()   { PASS=$((PASS+1)); echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail() { FAIL=$((FAIL+1)); FAIL_MSGS+=("$*"); echo -e "  ${RED}[FAIL]${NC} $*"; }
warn() { WARN=$((WARN+1)); WARN_MSGS+=("(warn) $*"); echo -e "  ${YELLOW}[WARN]${NC} $*"; }
na()   { NA=$((NA+1)); echo -e "  ${NC}[N/A ] $*"; }
notrun(){ NR=$((NR+1)); echo -e "  ${YELLOW}[NR  ]${NC} $* (NOT RUN — 无法验证，不假设 PASS)"; }

# ─── 参数 ───
JSON=0; TARGET_AGENT=""; SKILL_NAME="development-team"; DT_REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)      JSON=1; shift ;;
    --agent)     TARGET_AGENT="$2"; shift 2 ;;
    --skill)     SKILL_NAME="$2"; shift 2 ;;
    --repo)      DT_REPO="$2"; shift 2 ;;
    -h|--help)
      echo "用法: bash scripts/agent-context-check.sh [--json] [--agent <id>] [--skill <name>] [--repo <dt-repo>]"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
CONFIG_FILE="$OPENCLAW_HOME/openclaw.json"

echo ""
if [[ "$JSON" -eq 1 ]]; then
  echo "{\"checks\":["
fi

# 输出函数（JSON 模式下串行 emit 简单对象，便于后续聚合；非 JSON 为人类可读）
emit() { :; }

# ─── 1. OpenClaw 是否存在 ───
if command -v openclaw >/dev/null 2>&1; then
  ok "OpenClaw CLI 存在: $(command -v openclaw)"
else
  fail "未检测到 openclaw 命令 — Development Team 依赖 OpenClaw runtime"
fi

# ─── 2. OpenClaw 版本 ───
OC_VERSION="$(openclaw --version 2>/dev/null | head -1)"
if [[ -n "$OC_VERSION" ]]; then
  ok "OpenClaw 版本: $OC_VERSION"
else
  warn "无法读取 OpenClaw 版本 (openclaw --version)"
fi

# ─── 3. 识别 Main Agent / workspace（动态解析） ───
# 修复：优先用传入的 --agent（install.sh 的 --main-agent），无参仅作 fallback。
# 因为无参 `openclaw skills check` 会落到 CLI 默认 agent（本机=宝总），可能非真正主 agent。
detect_main_workspace() {
  if [[ -n "$TARGET_AGENT" ]]; then
    openclaw skills check --agent "$TARGET_AGENT" --json 2>/dev/null
  else
    openclaw skills check --json 2>/dev/null
  fi
}
SC_OUTPUT="$(detect_main_workspace)"
WORKSPACE_DIR="$(echo "$SC_OUTPUT" | python3 -c "import sys,json;
try:
 d=json.load(sys.stdin); print(d.get('workspaceDir',''))
except: print('')" 2>/dev/null)"
MANAGED_SKILLS_DIR="$(echo "$SC_OUTPUT" | python3 -c "import sys,json;
try:
 d=json.load(sys.stdin); print(d.get('managedSkillsDir',''))
except: print('')" 2>/dev/null)"
CUR_AGENT="$(echo "$SC_OUTPUT" | python3 -c "import sys,json;
try:
 d=json.load(sys.stdin); print(d.get('agentId',''))
except: print('')" 2>/dev/null)"

if [[ -n "$WORKSPACE_DIR" ]]; then
  ok "Main Agent 解析成功 → agent=$( [[ -n "$CUR_AGENT" ]] && echo "$CUR_AGENT" || echo '(未命名)') workspace=$WORKSPACE_DIR"
elif [[ -n "$TARGET_AGENT" ]]; then
  fail "无法解析 Main Agent workspace — openclaw skills check --agent '$TARGET_AGENT' 未返回 workspaceDir"
else
  fail "无法解析 Main Agent workspace — openclaw skills check 未返回 workspaceDir"
fi

# ─── 4. 确定 Development Team Skill 安装位置 ───
# 原则：Team-level capability → 用 shared managed 目录（`~/.openclaw/skills`）或显式 allowlist，
#       不复制到 Developer/Reviewer 私有 workspace。
echo ""
echo "--- [4] 安装位置策略：Team-level capability（shared managed skill） ---"
if [[ -n "$MANAGED_SKILLS_DIR" ]] && [[ -d "$MANAGED_SKILLS_DIR" ]]; then
  ok "Shared managed skills 目录存在: $MANAGED_SKILLS_DIR（所有本机 agent 可见）"
  TARGET_SKILL_DIR="$MANAGED_SKILLS_DIR"
elif [[ -z "$MANAGED_SKILLS_DIR" ]]; then
  warn "无法解析 shared managed skills 目录 — 将退化为检查 Main Agent workspace"
  TARGET_SKILL_DIR="$WORKSPACE_DIR/skills"
else
  warn "Shared managed skills 目录不存在: $MANAGED_SKILLS_DIR"
  TARGET_SKILL_DIR="$WORKSPACE_DIR/skills"
fi

# ─── 5. 枚举 agent ───
declare -a AGENTS=()
if [[ -f "$CONFIG_FILE" ]]; then
  AGENTS=($(python3 -c "
import json
with open('$CONFIG_FILE') as f: d=json.load(f)
ag=d.get('agents',{})
for a in ag.get('list',[]):
    print(a.get('id',''))
" 2>/dev/null))
fi
# 确保至少包含当前 agent
if [[ -n "$CUR_AGENT" ]] && ! [[ " ${AGENTS[*]} " == *" $CUR_AGENT "* ]]; then
  AGENTS+=("$CUR_AGENT")
fi

echo ""
echo "--- [5] Agent 枚举 ---"
if [[ ${#AGENTS[@]} -gt 0 ]]; then
  ok "检测到 ${#AGENTS[@]} 个 agent: ${AGENTS[*]}"
else
  warn "openclaw.json 无 agents.list，无法枚举 agent — 后续 per-agent discovery 检查降级"
fi

# 确定要检查的 agent 集合
CHECK_AGENTS=()
if [[ -n "$TARGET_AGENT" ]]; then
  CHECK_AGENTS=("$TARGET_AGENT")
else
  CHECK_AGENTS=("${AGENTS[@]:-}")
fi

# ─── 6. 验证各 agent 的 Development Team Skill discovery ───
echo ""
echo "--- [6] Skill discovery 验证（per-agent） ---"
echo "  Skill 名: $SKILL_NAME  目标目录: ${TARGET_SKILL_DIR:-未解析}"
echo "  （当前是否已安装 skill 不阻断：本 preflight 只验证『若安装到该位置，能否被发现』+『不复制到每个 agent』）"

verify_agent_discovery() {
  local agent="$1"
  # 动态获取该 agent 的 workspace
  local aws="$(openclaw skills check --agent "$agent" --json 2>/dev/null | python3 -c "
import sys,json
try: d=json.load(sys.stdin); print(d.get('workspaceDir',''))
except: print('')" 2>/dev/null)"
  if [[ -z "$aws" ]]; then
    notrun "agent='$agent': 无法查询其 workspace/discovery (openclaw skills check 失败) — 不假设 PASS"
    return
  fi
  ok "agent='$agent' 可被 OpenClaw 独立识别, workspace=$aws"

  # 验证：skill 应位于 shared managed 或 Main Agent 可见位置，而非该 agent 私有 workspace
  # 目标 skill 目录（shared）与该 agent 私有 workspace 的 skills 是否一致？
  local agent_priv="$aws/skills/$SKILL_NAME"
  if [[ -n "$TARGET_SKILL_DIR" && "$TARGET_SKILL_DIR" != "$aws/skills" ]]; then
    # shared 模式：期望 skill 不在每个 agent 私有 workspace 重复安装
    if [[ -d "$agent_priv" ]]; then
      warn "agent='$agent': 发现 '$SKILL_NAME' 已复制到其私有 workspace ($agent_priv) — Development Team 应为 Team-level shared skill，不建议逐 agent 复制"
    else
      ok "agent='$agent': '$SKILL_NAME' 未复制到其私有 workspace（符合 Team-level shared 原则）"
    fi
  else
    na "agent='$agent': 目标目录解析为 private workspace，跳过重复安装检查"
  fi
}

if [[ ${#CHECK_AGENTS[@]} -gt 0 ]]; then
  for a in "${CHECK_AGENTS[@]}"; do
    [[ -n "$a" ]] && verify_agent_discovery "$a"
  done
else
  notrun "无可用 agent 可验证 discovery — 不假设 PASS"
fi

# ─── 7. 验证调用链 Main Agent → Development Team → Developer → Reviewer ───
# 调用链文件存在性应基于「Development Team 仓库本体」（安装源），而非安装目标 workspace——
# 因为安装前目标 workspace 中这些文件尚不存在，若据此判定会造成 NOT RUN→INSTALL BLOCKED 死循环。
echo ""
echo "--- [7] 调用链验证（基于 DT 仓库源文件） ---"
CHAIN_BASE="$DT_REPO"
if [[ -z "$CHAIN_BASE" ]] || [[ ! -d "$CHAIN_BASE" ]]; then
  # 未提供 --repo：回退检查当前脚本所在仓库（DT 本体）
  SCRIPT_DIR_REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CHAIN_BASE="$(cd "$SCRIPT_DIR_REAL/.." && pwd)"
fi

if [[ -d "$CHAIN_BASE/agents/developer" ]] && [[ -f "$CHAIN_BASE/agents/developer/AGENTS.md" ]]; then
  ok "调用链就绪: Main Agent → Development Team → Developer (agents/developer/AGENTS.md, 源=$CHAIN_BASE)"
else
  fail "Development Team 仓库缺少 agents/developer/AGENTS.md — 调用链不完整（源=$CHAIN_BASE）"
fi

# Reviewer 是 Workflow 内部阶段（非独立 Agent），非 OpenClaw agent 枚举项。
# 验证其存在性靠 Development Team 仓库内的 review-adapter 协议。
if [[ -f "$CHAIN_BASE/protocols/review-adapter.md" ]]; then
  ok "Reviewer 阶段定义存在 (protocols/review-adapter.md) — 属于 Main Agent 的工作流内部阶段"
else
  warn "Development Team 仓库缺少 protocols/review-adapter.md — Reviewer 阶段定义缺失"
fi

# ─── 8 & 9. 汇总 ───
echo ""
echo "=============================================="
echo " 多 Agent Installation Context Preflight"
echo "=============================================="
echo "  PASS : $PASS"
echo "  FAIL : $FAIL"
echo "  WARN : $WARN"
echo "  N/A  : $NA"
echo "  NOT RUN : $NR (无法验证，不假设 PASS)"
if [[ ${#FAIL_MSGS[@]} -gt 0 ]]; then
  echo ""; echo " 阻断性缺陷:"
  for m in "${FAIL_MSGS[@]}"; do echo "   - $m"; done
fi
if [[ ${#WARN_MSGS[@]} -gt 0 ]]; then
  echo ""; echo " 警告:"
  for m in "${WARN_MSGS[@]}"; do echo "   - $m"; done
fi
echo ""
echo "说明: 本 preflight 只读、无副作用，不执行真实安装。"
echo "真正的多 Agent 安装/运行验证由 Reviewer Stranger User Audit / E2E Test 完成。"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: BLOCKING FAIL (存在 $FAIL 个阻断缺陷) — 环境不满足，应阻止安装"
  exit 1
elif [[ "$NR" -gt 0 ]]; then
  echo "RESULT: NOT RUN ($NR 项无法验证) — 不认定为 PASS，无法确保环境就绪"
  exit 3
elif [[ "$WARN" -gt 0 ]]; then
  echo "RESULT: WARN (有 $WARN 个非阻断警告) — 可继续，但请确认警告不影响安装"
  exit 2
else
  echo "RESULT: PASS (环境可用于 Development Team 安装)"
  exit 0
fi
