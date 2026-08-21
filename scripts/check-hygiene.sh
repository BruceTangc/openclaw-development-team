#!/usr/bin/env bash
# check-hygiene.sh — 仓库卫生扫描（R9）
set -u
REPO="${1:?用法: check-hygiene.sh <仓库路径>}"
cd "$REPO" || exit 1
echo "=== 疑似临时/构建产物 ==="
git ls-files | grep -iE '(\.log$|\.tmp$|\.bak|\.orig$|\.rej$|__pycache__|\.pyc$|\.DS_Store|node_modules|debug)' || echo "(none)"
echo "=== 大文件 >1MB ==="
git ls-files -z | while IFS= read -r -d '' f; do
  if [ -f "$f" ]; then
    sz=$(wc -c < "$f" 2>/dev/null || echo 0)
    [ "$sz" -gt 1000000 ] && echo "$f ($sz bytes)"
  fi
done
echo "=== gitignore 覆盖情况 ==="
git check-ignore -v $(git ls-files --others --exclude-standard 2>/dev/null) 2>/dev/null | head -5 || echo "(checked)"
