#!/usr/bin/env bash
#
# test-verify-artifact.sh — verify_artifact.py 对抗测试（t1-t18 口径）
# ==================================================================
# 验证 P0-2 整改后：
#   - 非法值 → FAIL（rc=1）
#   - 合法值 → PASS（rc=0）
#   - 错误处理/恢复项判定口径 = 结构化字段（error_handling/recovery/communication）
#     （不再依赖正文自然语言 Regex）
#
# 用法：
#   bash scripts/test-verify-artifact.sh
#
# 退出码：0 = 全部通过；1 = 有断言失败
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/verify_artifact.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS_N=0; FAIL_N=0

assert_rc() {
  # $1=name  $2=expected_rc  $3=actual_rc
  if [[ "$3" -eq "$2" ]]; then
    PASS_N=$((PASS_N+1)); echo "  [PASS] $1 (rc=$3)"
  else
    FAIL_N=$((FAIL_N+1)); echo "  [FAIL] $1 — 期望 rc=$2 实际 rc=$3"
  fi
}

# 写一个 skill fixture（$1=dir, $2=frontmatter body 片段）
mk_skill() {
  local d="$1"
  local body="${2:-}"
  mkdir -p "$d"
  cat > "$d/SKILL.md" <<EOF
---
name: test-skill
description: adversarial test fixture
x-agent-os:
  protocol_version: "1.3"
  layer: "business"
  entry_mode: "both"
  path:
    fast: true
    full: true
  requires:
    context: true
    permission: true
    verification: true
  delegation:
    max_level: "L1"
    inherit_parent: false
    requires_scope: true
$body
---
# test-skill
EOF
}

echo "=== verify_artifact.py 对抗测试（结构化字段口径）==="
echo "Fixture root: $TMP"

# ── 非法值类（应 FAIL rc=1）──
mk_skill "$TMP/t01-layer" "  layer: \"bogus\""
"$VALIDATOR" "$TMP/t01-layer" skill >/dev/null 2>&1; assert_rc "t01 layer 非法值" 1 $?

mk_skill "$TMP/t02-entry" "  entry_mode: \"bogus\""
"$VALIDATOR" "$TMP/t02-entry" skill >/dev/null 2>&1; assert_rc "t02 entry_mode 非法值" 1 $?

mk_skill "$TMP/t03-protocol" "  protocol_version: \"9.9\""
"$VALIDATOR" "$TMP/t03-protocol" skill >/dev/null 2>&1; assert_rc "t03 protocol_version 与 baseline 不一致" 1 $?

mk_skill "$TMP/t04-perm" "  requires:
    context: true
    permission: false
    verification: true"
"$VALIDATOR" "$TMP/t04-perm" skill >/dev/null 2>&1; assert_rc "t04 requires.permission=false" 1 $?

mk_skill "$TMP/t05-semver" "  version: \"1.0\""
"$VALIDATOR" "$TMP/t05-semver" skill >/dev/null 2>&1; assert_rc "t05 version 非 SemVer" 1 $?

mk_skill "$TMP/t06-deleg" "  delegation:
    max_level: \"L9\"
    inherit_parent: false
    requires_scope: true"
"$VALIDATOR" "$TMP/t06-deleg" skill >/dev/null 2>&1; assert_rc "t06 delegation max_level 非法" 1 $?

# ── 结构化否定 / 违规类（应 FAIL rc=1，替代旧自然语言 Regex）──
mk_skill "$TMP/t07-eh-false" "  error_handling:
    declared: false"
"$VALIDATOR" "$TMP/t07-eh-false" skill >/dev/null 2>&1; assert_rc "t07 error_handling.declared=false" 1 $?

mk_skill "$TMP/t08-rec-false" "  recovery:
    declared: false"
"$VALIDATOR" "$TMP/t08-rec-false" skill >/dev/null 2>&1; assert_rc "t08 recovery.declared=false" 1 $?

mk_skill "$TMP/t09-comm-true" "  communication:
    parallel_runtime: true"
"$VALIDATOR" "$TMP/t09-comm-true" skill >/dev/null 2>&1; assert_rc "t09 communication.parallel_runtime=true" 1 $?

mk_skill "$TMP/t10-eh-bad" "  error_handling: \"yes we handle errors\""
"$VALIDATOR" "$TMP/t10-eh-bad" skill >/dev/null 2>&1; assert_rc "t10 error_handling 非结构化" 1 $?

mk_skill "$TMP/t11-rec-bad" "  recovery: \"we retry\""
"$VALIDATOR" "$TMP/t11-rec-bad" skill >/dev/null 2>&1; assert_rc "t11 recovery 非结构化" 1 $?

mk_skill "$TMP/t12-comm-bad" "  communication: \"no scheduler\""
"$VALIDATOR" "$TMP/t12-comm-bad" skill >/dev/null 2>&1; assert_rc "t12 communication 非结构化" 1 $?

# ── 合法值类（应 PASS rc=0，无 false FAIL）──
mk_skill "$TMP/t13-valid-full" "  error_handling:
    declared: true
  recovery:
    declared: true
    mechanism: retry
  communication:
    parallel_runtime: false
  provenance:
    owner: test-agent
  outputs:
    success_condition: required
    evidence: required
  memory_write: \"governed\"
  version: \"1.0.0\""
# 补充 Execution Record（避免 ER 缺失 WARN，使完整合法 skill 得到 rc=0）
cat > "$TMP/t13-valid-full/execution_record.yaml" <<'EOF'
execution_record:
  context:
    status: completed
  goal:
    status: completed
  permission:
    status: completed
  execution:
    status: completed
  verification:
    status: completed
EOF
"$VALIDATOR" "$TMP/t13-valid-full" skill >/dev/null 2>&1; assert_rc "t13 完整结构化合法 skill" 0 $?

mk_skill "$TMP/t14-valid-noer" ""
"$VALIDATOR" "$TMP/t14-valid-noer" skill >/dev/null 2>&1
# 缺 error_handling/recovery/communication 结构化字段 → WARN（rc=2），不得 FAIL
assert_rc "t14 缺结构化字段 → WARN 非 FAIL" 2 $?

mk_skill "$TMP/t15-valid-mech" "  error_handling:
    declared: true
  recovery:
    declared: true
    mechanism: escalate"
"$VALIDATOR" "$TMP/t15-valid-mech" skill >/dev/null 2>&1
# 有 error/recovery 结构化声明但无 communication 声明 → WARN（rc=2），非 FAIL
assert_rc "t15 有 error/recovery 无 communication → WARN" 2 $?

# ── 旧自然语言绕过不再 FAIL（证明语义判断已移除）──
# 正文写 "no error handling" 但无结构化字段 → 应 WARN（rc=2），不再是 FAIL
mk_skill "$TMP/t16-body-neg" ""
printf '\n\nThis skill does no error handling and never recovers.\n' >> "$TMP/t16-body-neg/SKILL.md"
"$VALIDATOR" "$TMP/t16-body-neg" skill >/dev/null 2>&1; assert_rc "t16 正文否定词不再触发 FAIL" 2 $?

echo ""
echo "=== 结果 ==="
echo "PASS=$PASS_N FAIL=$FAIL_N"
if [[ "$FAIL_N" -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
