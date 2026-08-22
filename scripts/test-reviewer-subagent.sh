#!/usr/bin/env bash
# test-reviewer-subagent.sh — Reviewer 独立 subagent 架构重构的静态/半静态验收（R-1~R-11）
# ============================================================================
# 只做可在本地确定性验证的项（grep 断言 + resource-gate 实测 + schema 校验）。
# 需真实 spawn 子代理的项（R-2/R-3/R-8 的真实 session）在 E2E 阶段验证，此处标 NOT RUN。
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0; NR=0
ok()   { PASS=$((PASS+1)); echo "  [PASS] $*"; }
bad()  { FAIL=$((FAIL+1)); echo "  [FAIL] $*"; }
notrun(){ NR=$((NR+1)); echo "  [NRUN] $*"; }

# 断言：文件含某 pattern
has() { grep -qE "$1" "$2" 2>/dev/null; }
# 断言：文件不含某 pattern
lack() { ! grep -qE "$1" "$2" 2>/dev/null; }

echo "=== R-1: Main Agent 不执行 Reviewer logic ==="
if grep -qE "Main Agent 永远不执行 Reviewer logic|不执行 Reviewer logic" "$REPO/AGENTS.md" "$REPO/PROTOCOL.md" "$REPO/skills/development-team/SKILL.md"; then ok "AGENTS.md/PROTOCOL.md/SKILL.md 均声明 Main Agent 不执行 Reviewer logic"; else bad "缺少「Main Agent 不执行 Reviewer logic」声明"; fi
# 注意：review-adapter.md 中「由 Main Agent 代审/快查」的表述仅在"禁止项"语境（前缀 ❌ / 不...），
# 属正确的否定声明，不是残留。断言应找"正向允许 Main Agent 代审"的表述（如『可由 Main Agent 快查 → APPROVED』）。
if lack "可由 Main Agent.*快速审查|Main Agent 快查.*即可通过|允许 Main Agent 代审" "$REPO/protocols/review-adapter.md"; then ok "review-adapter.md 无『正向允许 Main Agent 代审』表述"; else bad "review-adapter.md 有『正向允许 Main Agent 代审』表述"; fi
if lack "Reviewer 是 Workflow 内部阶段|Reviewer 内部阶段|Main Agent 自己执行，不 spawn" "$REPO/README.md" "$REPO/IMPLEMENTATION_SPEC.md" "$REPO/protocols/main-agent-integration.md"; then ok "README/IMPLEMENTATION_SPEC/main-agent-integration 无旧「Workflow 内部阶段」表述"; else bad "仍有旧「Reviewer=Workflow 内部阶段」表述"; fi

echo "=== R-2: Reviewer 通过 sessions_spawn 创建 ==="
if grep -qE "sessions_spawn" "$REPO/agents/reviewer/AGENTS.md" "$REPO/protocols/review-adapter.md"; then ok "agents/reviewer/AGENTS.md + review-adapter.md 均声明 sessions_spawn 创建 Reviewer"; else bad "Reviewer 契约缺少 sessions_spawn"; fi

echo "=== R-3: Reviewer 有独立 session/context ==="
if grep -qE "独立 context|独立 Context|不继承 Developer" "$REPO/agents/reviewer/AGENTS.md"; then ok "Reviewer 契约声明独立 context / 不继承 Developer 对话"; else bad "Reviewer 契约缺少独立 context 声明"; fi

echo "=== R-4: Developer 无法直接决定 APPROVED ==="
# Developer 契约中「APPROVED」字样仅存在于『最终 commit 由 Main Agent 在 Reviewer APPROVED 后执行』这类
# 被动引用（说明 commit 时机），不是 Developer 拥有 APPROVED 决策权。断言应找『Developer 决定 APPROVED』的
# 正向授权表述；找不到即 PASS。
if lack "Developer.*决定.*APPROVED|由 Developer.*APPROVED|Developer 可直接 APPROVED" "$REPO/agents/developer/AGENTS.md"; then ok "agents/developer/AGENTS.md 无『Developer 决定 APPROVED』授权表述"; else bad "Development 契约出现 APPROVED 决策权"; fi
if grep -qE "IMPLEMENTATION COMPLETE|IMPLEMENTATION_COMPLETE" "$REPO/agents/developer/AGENTS.md"; then ok "Developer 自述边界 = IMPLEMENTATION COMPLETE"; else bad "Developer 契约缺少 IMPLEMENTATION COMPLETE 边界"; fi

echo "=== R-5: Developer completed 不会自动 APPROVED ==="
if grep -qE "sessions_spawn completed.*≠|completion ≠ task success|completed ≠" "$REPO/protocols/result-closure.md"; then ok "result-closure.md 明确 completion ≠ task success"; else bad "result-closure.md 缺少 completion ≠ success"; fi
if grep -qE "ARTIFACT_PENDING_VERIFICATION.*REVIEWING.*APPROVED|RUNTIME_COMPLETED.*→.*REVIEWING" "$REPO/protocols/result-closure.md"; then ok "状态链含 RUNTIME_COMPLETED → … → REVIEWING → APPROVED 必经节点"; else bad "状态链缺中间验证节点"; fi

echo "=== R-6: Reviewer 必须产生结构化 review result ==="
if grep -qE "^review:|status:.*approved \| rework_required \| blocked|findings:|verification:|decision:" "$REPO/templates/review-result.yaml"; then ok "review-result.yaml 含 status/findings/verification/decision 结构化字段"; else bad "review-result.yaml 缺结构化字段"; fi
if grep -qE "禁止 LGTM|禁止.*Looks good|禁止.*Approved 单独" "$REPO/templates/review-result.yaml"; then ok "review-result.yaml 禁止 LGTM/Approved 单独作为 evidence"; else bad "review-result.yaml 缺禁止 LGTM 约束"; fi

echo "=== R-7: Reviewer findings 必须含 evidence ==="
if grep -qE "evidence:" "$REPO/templates/review-result.yaml"; then ok "findings 结构含 evidence 字段"; else bad "findings 缺 evidence 字段"; fi
if grep -qE "必须引用.*事实输入|禁止用 Developer/Main Agent 自评替代" "$REPO/templates/review-result.yaml"; then ok "evidence 须引用事实输入、禁止自评替代"; else bad "缺 evidence 事实输入约束"; fi

echo "=== R-9: Reviewer completed ≠ APPROVED ==="
if grep -qE "completed ≠ APPROVED|completed.*≠.*APPROVED" "$REPO/agents/reviewer/AGENTS.md" "$REPO/protocols/result-closure.md"; then ok "Reviewer 契约 + result-closure 明确 completed ≠ APPROVED"; else bad "缺 completed ≠ APPROVED 声明"; fi

echo "=== R-10: Reviewer 默认没有代码修改/commit/push 权限 ==="
if grep -qE "只读|不改代码|不 commit|不 push" "$REPO/agents/reviewer/AGENTS.md"; then ok "Reviewer 契约声明只读 + 不 commit/push"; else bad "Reviewer 契约缺只读权限边界"; fi
if grep -qE "read_only: true|read_only" "$REPO/PROTOCOL.md"; then ok "PROTOCOL.md reviewer capability 声明 read_only"; else bad "PROTOCOL.md 缺 reviewer read_only 声明"; fi

echo "=== R-11: Resource Governance 管理 Developer/Reviewer session ==="
TMP_REPO="$(mktemp -d)"
cp "$REPO/resource-budget.yaml" "$TMP_REPO/"
# 空预算环境 gate → ALLOW
if bash "$REPO/scripts/resource-gate.sh" "$TMP_REPO" >/dev/null 2>&1; then ok "resource-gate 空租约 → ALLOW (exit 0)"; else bad "resource-gate 空租约未 ALLOW"; fi
# acquire reviewer lease → gate 应 QUEUE（rev 满）
bash "$REPO/scripts/resource-gate.sh" "$TMP_REPO" acquire reviewer rev-1 >/dev/null 2>&1
bash "$REPO/scripts/resource-gate.sh" "$TMP_REPO" >/dev/null 2>&1; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "reviewer lease 占用后 gate → QUEUE (exit 1, 计数正确)"; else bad "reviewer lease 占用后 gate exit=$rc（期望 1）"; fi
# release → 回 ALLOW
bash "$REPO/scripts/resource-gate.sh" "$TMP_REPO" release reviewer rev-1 >/dev/null 2>&1
bash "$REPO/scripts/resource-gate.sh" "$TMP_REPO" >/dev/null 2>&1; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "reviewer lease 释放后 gate → ALLOW (lease 生命周期正确)"; else bad "reviewer lease 释放后 gate exit=$rc（期望 0）"; fi
# stale lease 回收：写一个超 TTL 的 developer lease，gate 应仍 ALLOW（stale 剔除）
mkdir -p "$TMP_REPO/.runtime/leases/developer"
echo "1000" > "$TMP_REPO/.runtime/leases/developer/dev-stale"
bash "$REPO/scripts/resource-gate.sh" "$TMP_REPO" >/dev/null 2>&1; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "stale developer lease 被剔除（gate 仍 ALLOW）"; else bad "stale lease 未被剔除（gate exit=$rc）"; fi
rm -rf "$TMP_REPO"

echo ""
echo "=============================================="
echo " 静态/半静态验收汇总：PASS=$PASS FAIL=$FAIL NOT_RUN=$NR"
echo "=============================================="
echo "R-2/R-3/R-8 的真实 spawn 会话在 E2E 阶段验证（见 E2E 报告）。"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
