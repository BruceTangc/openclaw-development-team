#!/usr/bin/env bash
# check-verification.sh — R7 Verification 状态机（v1.0）
#
# 状态：NOT_APPLICABLE / NOT_RUN / RUNNING / PASSED / FAILED / BLOCKED / INCOMPLETE
# 原则：工具不存在 / 环境不满足 ≠ 测试失败 → INCOMPLETE，由 Reviewer 结合风险判定是否阻止发布。
set -u
REPO="${1:?用法: check-verification.sh <仓库路径>}"
cd "$REPO" || exit 1

run_test() {
  local name="$1" cmd="$2"
  if ! command -v "${cmd%% *}" >/dev/null 2>&1; then
    echo "  [NOT_APPLICABLE] $name — 工具 ${cmd%% *} 不存在，跳过"
    return 0
  fi
  if ! eval "$cmd" >/dev/null 2>&1; then
    echo "  [FAILED] $name — $cmd 执行失败"
    FAILED=$((FAILED+1))
    return 1
  fi
  echo "  [PASSED] $name"
  return 0
}

echo "=== 项目已有测试（存在才跑，不存在 = NOT_APPLICABLE） ==="
FAILED=0
[ -f pytest.ini ] && run_test "pytest" "pytest" || true
[ -f package.json ] && { grep -q '"test"' package.json && run_test "npm test" "npm test" || echo "  [NOT_RUN] package.json 无 test script（依赖描述，跳过）"; }
[ -f Cargo.toml ] && run_test "cargo test" "cargo test" || true
[ -f go.mod ] && run_test "go test" "go test ./..." || true

echo "=== OpenClaw 原生验证（存在才跑） ==="
run_test "openclaw doctor" "openclaw doctor" || true
run_test "openclaw security audit" "openclaw security audit --json" || true
run_test "openclaw skills check" "openclaw skills check" || true   # verify 需 skill-ref 参数，无参用 check

echo "---"
[ "$FAILED" -gt 0 ] && { echo "VERIFY_RESULT=FAILED"; exit 1; } || { echo "VERIFY_RESULT=PASSED_OR_NA"; exit 0; }