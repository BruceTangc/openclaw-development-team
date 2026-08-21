#!/usr/bin/env bash
#
# protocol-compliance-check.sh — Generated Artifact Protocol Compliance Gate（P0）
# ===============================================================================
# 依据 Agent OS SKILL-INTEGRATION.md + PROTOCOL-CHECKLIST.md + Execution Record schema。
# Development Team 不新建独立 protocol-compliance skill；此脚本是 Reviewer §3.7 / readiness
# 用的 Author-side 工具，复用 Agent OS 现有标准，不发明新协议字段。
#
# 用途：
#   1) Author（Developer/Lead）提交前自检生成物（Skill/Agent/Project）是否满足 x-agent-os 声明 + 14 项 checklist。
#   2) Reviewer §3.7 作为 Protocol Compliance 子步的自动辅助（最终判定仍由 Reviewer 人工确认）。
#
# 用法：
#   ./scripts/protocol-compliance-check.sh <artifact-dir> [type]
#     type: skill | agent | project | auto（默认 auto，尝试从内容推断）
#
# 退出码：
#   0 = PASS（或全部合法 N/A）
#   1 = FAIL（存在应经过但未经过 / x-agent-os 缺失 / delegation 缺失 / Execution Record 缺失节点）
#   2 = WARN（部分项 N/A 理由缺失，需 Reviewer 确认）
#   3 = 用法错误
#
# 判定语义（对齐 Agent OS Contract）：
#   应经过但未经过 → FAIL；Contract 条件性跳过且注明 → 不 FAIL；合法 N/A（清晰理由）→ 不计。
#   本脚本只做可自动验证项；内容/可运行性/Execution Record 真实性由 Reviewer 人工确认。
set -u

ARTIFACT_DIR="${1:-}"
TYPE="${2:-auto}"
if [[ -z "$ARTIFACT_DIR" ]]; then
  echo "用法: $0 <artifact-dir> [skill|agent|project|auto]" >&2
  exit 3
fi
if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "ERROR: 目录不存在: $ARTIFACT_DIR" >&2
  exit 3
fi

PASS=0; FAIL=0; WARN=0
p() { PASS=$((PASS+1)); echo "  [PASS] $1"; }
f() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }
w() { WARN=$((WARN+1)); echo "  [WARN] $1"; }

echo "Artifact: $ARTIFACT_DIR  Type: $TYPE"
echo "Agent OS Protocol: v1.3 (Architecture Contract v1.6 / MA-1.1 ccef093)"
echo ""

# 定位声明文件（SKILL.md / _meta.json / AGENTS.md / README）
SKILL_MD="$(find "$ARTIFACT_DIR" -maxdepth 2 -name 'SKILL.md' 2>/dev/null | head -1)"
META_JSON="$(find "$ARTIFACT_DIR" -maxdepth 2 -name '_meta.json' 2>/dev/null | head -1)"
AGENTS_MD="$(find "$ARTIFACT_DIR" -maxdepth 2 -name 'AGENTS.md' 2>/dev/null | head -1)"
README="$(find "$ARTIFACT_DIR" -maxdepth 2 -name 'README.md' 2>/dev/null | head -1)"
# 推断类型
if [[ "$TYPE" == "auto" ]]; then
  if [[ -n "$SKILL_MD" || -n "$META_JSON" ]]; then TYPE=skill; fi
  if [[ "$TYPE" == "skill" && -n "$AGENTS_MD" ]]; then TYPE=project; fi
  if [[ -z "$SKILL_MD" && -z "$META_JSON" && -n "$AGENTS_MD" ]]; then TYPE=agent; fi
  if [[ -z "$SKILL_MD" && -z "$META_JSON" && -z "$AGENTS_MD" && -n "$README" ]]; then TYPE=project; fi
  [[ -z "$TYPE" || "$TYPE" == "auto" ]] && { echo "ERROR: 无法推断类型，请显式传 type" >&2; exit 3; }
  echo "(auto->$TYPE)"
fi

# 收集所有声明候选文件（合并 list，供下面匹配）
DECL_FILES=()
[[ -n "$SKILL_MD" ]] && DECL_FILES+=("$SKILL_MD")
[[ -n "$META_JSON" ]] && DECL_FILES+=("$META_JSON")
[[ -n "$AGENTS_MD" ]] && DECL_FILES+=("$AGENTS_MD")
[[ -n "$README" ]] && DECL_FILES+=("$README")

# 判断文件是否含 x-agent-os 声明
has_xagentos() {
  local f
  for f in "${DECL_FILES[@]}"; do
    if grep -qE 'x-agent-os' "$f" 2>/dev/null; then return 0; fi
  done
  return 1
}
# 从声明文件提取某 yaml 键的值（校验字段是否出现）
field_present() {
  local key="$1"
  for f in "${DECL_FILES[@]}"; do
    if grep -qE "^[[:space:]]*${key}[[:space:]]*:" "$f" 2>/dev/null; then return 0; fi
  done
  return 1
}

echo "=== Protocol Compliance Checks (14 项标准 + x-agent-os 声明) ==="

# 0. x-agent-os 声明存在（Identity 前提）——所有生成的 skill/agent/project 必须
if has_xagentos; then
  p "x-agent-os 声明存在 ($([ ${#DECL_FILES[@]} -gt 0 ] && echo "${DECL_FILES[0]}" || echo none))"
else
  # 非生成的纯项目（无 skill/agent 语义）可 N/A？——按 P0：适用场景必须声明
  if [[ "$TYPE" == "project" && -z "$SKILL_MD" && -z "$AGENTS_MD" ]]; then
    w "x-agent-os 缺失，但为纯项目（非 skill/agent）— 需 Reviewer 确认是否适用（一般 N/A）"
  else
    f "缺少 x-agent-os 声明（适用场景必须）"
  fi
fi

# 1. Identity
if field_present "layer"; then p "Identity: layer 声明"; else w "Identity: layer 未显式声明（简单生成物可 N/A，需理由）"; fi

# 2. Context
if field_present "requires"; then p "Context: requires 节点矩阵声明"; else w "Context: requires 未声明（简单生成物可 N/A，需理由）"; fi

# 3. Lifecycle
if field_present "entry_mode"; then p "Lifecycle: entry_mode (Fast/Full Path) 声明"; else w "Lifecycle: entry_mode 未声明（无任务型生成物可 N/A，需理由）"; fi

# 4. Memory/State
if field_present "memory_write"; then p "Memory/State: memory_write 声明"; else w "Memory/State: memory_write 未声明（无状态生成物可 N/A，需理由）"; fi

# 5. Delegation（Multi-Agent 适用场景必须）——skill/agent 生成物一般适用
has_delegation=0
decl_nomulti=0
for f in "${DECL_FILES[@]}"; do
  if grep -qE '^[[:space:]]*delegation[[:space:]]*:' "$f" 2>/dev/null; then has_delegation=1; break; fi
done
# 识别「显式声明独立/单 agent/无 Multi-Agent 场景」→ delegation 合法 N/A
for f in "${DECL_FILES[@]}"; do
  if grep -qiE '独立|单 ?agent|不 ?被 ?子 ?agent|无 ?Multi-?Agent|无 ?子 ?代理|standalone|not.*delegat|independent' "$f" 2>/dev/null; then decl_nomulti=1; break; fi
done
if [[ "$has_delegation" -eq 1 ]]; then
  p "Delegation: delegation 块声明"
elif [[ "$TYPE" == "project" && -z "$AGENTS_MD" && -z "$SKILL_MD" ]]; then
  p "Delegation: NOT_APPLICABLE（纯项目，无 Multi-Agent 语义）"
elif [[ "$decl_nomulti" -eq 1 ]]; then
  p "Delegation: NOT_APPLICABLE（显式声明独立/单 agent、无 Multi-Agent 场景）"
else
  f "Delegation: 缺少 delegation（Multi-Agent 适用场景必须）"
fi

# 6. Handoff
has_handoff=0
for f in "${DECL_FILES[@]}"; do
  if grep -qiE 'handoff|回传|回传路径|result.*(path|回传)|outputs' "$f" 2>/dev/null; then has_handoff=1; break; fi
done
[[ "$has_handoff" -eq 1 ]] && p "Handoff: 结果回传路径明确" || w "Handoff: 未显式声明回传路径（简单生成物可 N/A，需理由）"

# 7. Communication（用 OpenClaw 原生，不建并行 runtime）
has_comm=1; # 默认 OpenClaw 原生，无需额外声明；检查是否误声明并行组件
for f in "${DECL_FILES[@]}"; do
  if grep -qiE 'scheduler|event bus|task runtime|memory runtime|permission runtime|agent runtime' "$f" 2>/dev/null; then
    f "Communication: 声明了 Agent OS 禁止的并行 runtime 组件"
    has_comm=0; break
  fi
done
[[ "$has_comm" -eq 1 ]] && p "Communication: 使用 OpenClaw 原生（未声明并行 runtime）"

# 8. Error Handling
has_err=0
for f in "${DECL_FILES[@]}"; do
  if grep -qiE 'error|失败|FAILED|rework|recovery|retry' "$f" 2>/dev/null; then has_err=1; break; fi
done
[[ "$has_err" -eq 1 ]] && p "Error Handling: 失败处理路径存在" || w "Error Handling: 未说明失败处理（内置型可 N/A，需理由）"

# 9. Recovery
has_rec=0
for f in "${DECL_FILES[@]}"; do
  if grep -qiE 'recovery|recover|escalat|retry|重试|升级' "$f" 2>/dev/null; then has_rec=1; break; fi
done
[[ "$has_rec" -eq 1 ]] && p "Recovery: retry/escalate 路径存在" || w "Recovery: 未说明恢复路径（简单生成物可 N/A，需理由）"

# 10. Permissions（L2+ 一律 true）
has_perm=0
for f in "${DECL_FILES[@]}"; do
  if grep -qE '^[[:space:]]*permission|permissions[[:space:]]*:' "$f" 2>/dev/null; then has_perm=1; break; fi
done
if [[ "$has_perm" -eq 1 ]]; then
  p "Permissions: permission 声明存在（L2+ 应 true）"
else
  # 检查是否纯 L0-L1 生成物（无法自动判 L 级 → WARN 交 Reviewer）
  w "Permissions: 未显式声明 permission（需确认是否为纯 L0-L1；L2+ 必须 enable）"
fi

# 11. Skill Discovery（仅 skill 类）
if [[ "$TYPE" == "skill" || -n "$SKILL_MD" ]]; then
  if grep -qE '^name:|^description:' "$SKILL_MD" 2>/dev/null; then p "Skill Discovery: frontmatter name/description 存在"; else f "Skill Discovery: SKILL.md 缺 name/description"; fi
else
  p "Skill Discovery: NOT_APPLICABLE（非 skill）"
fi

# 12. Installation（非 skill 类 N/A）
if [[ "$TYPE" == "project" && -n "$README" ]]; then
  grep -qiE 'install|安装' "$README" 2>/dev/null && p "Installation: README 有安装说明" || w "Installation: README 未提及安装（可能 N/A）"
else
  p "Installation: N/A（当前评估对象非可安装项目）"
fi

# 13. Versioning
has_ver=0
for f in "${DECL_FILES[@]}"; do
  if grep -qE '^[[:space:]]*version[[:space:]]*:|^[[:space:]]*protocol_version[[:space:]]*:' "$f" 2>/dev/null; then has_ver=1; break; fi
done
[[ "$has_ver" -eq 1 ]] && p "Versioning: version/protocol_version 可版本化" || w "Versioning: 未声明版本（可 N/A，需理由）"

# 14. Multi-Agent Compatibility（delegation + provenance）
if [[ "$has_delegation" -eq 1 ]]; then
  has_prov=0
  for f in "${DECL_FILES[@]}"; do
    grep -qiE 'provenance|来源|owner|归属' "$f" 2>/dev/null && { has_prov=1; break; }
  done
  [[ "$has_prov" -eq 1 ]] && p "Multi-Agent: delegation + provenance 齐备" || w "Multi-Agent: 有 delegation 但 provenance 未显式（需 Reviewer 确认）"
else
  p "Multi-Agent: NOT_APPLICABLE（无 delegation 场景）"
fi

# Execution Record（生成物如声明了 execution record，须含规定节点）
ER_FILE="$(find "$ARTIFACT_DIR" -maxdepth 3 -type f \( -iname '*execution-record*' -o -iname '*execution_record*' \) 2>/dev/null | head -1)"
if [[ -n "$ER_FILE" ]]; then
  # 规定节点：必须在 steps: 下以「两空格缩进的 key:」实际列出（排除注释/普通字样匹配）
  required_nodes=(context goal_task permission execution verification)
  er_fail=0
  for node in "${required_nodes[@]}"; do
    # 匹配 steps 下缩进的节点 key（允许 context/goal_task 等）
    if grep -qE "^[[:space:]]{2}${node}(_task)?[[:space:]]*:" "$ER_FILE" 2>/dev/null; then
      :
    else
      echo "  [FAIL] Execution Record 缺失规定节点: ${node}"
      FAIL=$((FAIL+1)); er_fail=1
    fi
  done
  grep -qiE 'completed|skipped|conditional' "$ER_FILE" 2>/dev/null && p "Execution Record: status 三态可用" || w "Execution Record: 无 status 三态标注"
else
  w "Execution Record: 未找到（如为 Full Path/涉及 L2+ 产物应生成；Reader 确认是否 N/A）"
fi

echo ""
echo "=== 汇总 ==="
echo "PASS=$PASS WARN=$WARN FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL"
  echo "→ Protocol Compliance FAIL：Reviewer 必须 REJECT，Release BLOCKED"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "RESULT: WARN（存在需 Reviewer 人工确认的 N/A / 未显式项，不自动 FAIL）"
  exit 2
else
  echo "RESULT: PASS"
  exit 0
fi
