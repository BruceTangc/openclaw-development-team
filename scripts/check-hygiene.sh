#!/usr/bin/env bash
# check-hygiene.sh — 仓库卫生扫描（Reviewer 步骤 5 Repository Review；迁移自 RR，见 protocols/review-adapter.md §7）
#
# v1.1：修复 untracked 临时文件漏检——
# 原版只 `git ls-files`（仅 tracked），未跟踪的 debug.log / test.tmp / foo.pyc 会被漏掉。
# 现增加 `git ls-files --others --exclude-standard` 扫描 untracked 层，
# 同时大文件扫描也覆盖 tracked + untracked。
set -u
REPO="${1:?用法: check-hygiene.sh <仓库路径>}"
cd "$REPO" || exit 1

# 临时/构建/调试产物模式（tracked + untracked 共用）
# 只匹配「临时/构建/调试」特征，不误伤正常 source（.json/.md/.py 等不命中）。
PATTERN='(\.log$|\.tmp$|\.bak$|\.bak\.[0-9]+$|\.orig$|\.rej$|\.py[co]$|__pycache__|\.DS_Store|node_modules|(^|/)dist/|(^|/)build/|(^|/)target/|(^|[/._-])debug([._-]|$))'

# 临时计数文件（聚合跨子 shell 的 hit 计数，与 check-secrets.sh 同款，修子 shell 计数丢失）
CNT="$(mktemp)"; echo 0 > "$CNT"
cleanup() { rm -f "$CNT"; }
trap cleanup EXIT

hit() {
  local n
  n=$(cat "$CNT")
  echo $((n+1)) > "$CNT"
  echo "  ⚠️ $1"
}
total() { cat "$CNT"; }

echo "=== 1/3 tracked 临时/构建/调试产物 ==="
git ls-files | grep -iE "$PATTERN" | while IFS= read -r f; do
  hit "tracked: $f"
done
[ "$(total)" = 0 ] && echo "  (none)"

echo "=== 2/3 untracked 临时/构建/调试产物 ==="
git ls-files --others --exclude-standard | grep -iE "$PATTERN" | while IFS= read -r f; do
  hit "untracked: $f"
done
[ "$(total)" = 0 ] && echo "  (none)"

echo "=== 3/3 大文件 >1MB（tracked + untracked） ==="
{ git ls-files -z; git ls-files --others --exclude-standard -z; } | while IFS= read -r -d '' f; do
  if [ -f "$f" ]; then
    sz=$(wc -c < "$f" 2>/dev/null || echo 0)
    [ "$sz" -gt 1000000 ] && hit "大文件: $f ($sz bytes)"
  fi
done
[ "$(total)" = 0 ] && echo "  (none)"

echo "---"
if [ "$(total)" -gt 0 ]; then echo "HYGIENE_FOUND=$(total)"; exit 1; else echo "HYGIENE_FOUND=0 (clean)"; exit 0; fi
