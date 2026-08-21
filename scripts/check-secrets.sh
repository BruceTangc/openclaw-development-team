#!/usr/bin/env bash
# check-secrets.sh — 仓库 secrets 扫描（Reviewer 步骤 4 Security；迁移自 RR，见 protocols/review-adapter.md §7）
#
# v1.0：修复 F-004-1 子 shell 计数丢失 bug——
# 第 1、2 节的 HITS 在管道 `| while` 子 shell 中自增不传导父 shell，
# 导致命中 secret 却 SECRET_FOUND=0 / exit 0（false-clean）。
# 改用临时计数文件聚合，跨子 shell 累加，杜绝泄漏。
set -u
REPO="${1:?用法: check-secrets.sh <仓库路径>}"
cd "$REPO" || exit 1

PATTERNS='ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|Bearer [A-Za-z0-9._-]{20,}|-----BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY-----|password\s*[=:]\s*[^ ]{4,}|secret\s*[=:]\s*[^ ]{6,}|api[_-]?key\s*[=:]\s*[^ ]{8,}|token\s*[=:]\s*[^ ]{8,}'

# 临时计数文件（聚合跨子 shell 的 hit 计数，修 F-004-1）
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

echo "=== 1/4 tracked diff（staged + unstaged, --binary） ==="
git diff HEAD --binary 2>/dev/null | grep -niE "$PATTERNS" | head -20 | while IFS= read -r l; do
  hit "diff: ${l%%:*}"
done
[ "$(total)" = 0 ] && echo "  (clean)"

echo "=== 2/4 untracked 文件内容扫描 ==="
git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
  if [ -f "$f" ] && grep -qiE "$PATTERNS" "$f" 2>/dev/null; then
    hit "untracked($(basename "$f")): secret 内容"
  fi
done
[ "$(total)" = 0 ] && echo "  (clean)"

echo "=== 3/4 tracked 敏感文件名 ==="
SENS=$(git ls-files | grep -iE '(\.env$|\.pem$|\.key$|credentials|\.secret$|secrets?\.json$)' | grep -v '^scripts/check-secrets\.sh$' || true)
if [ -n "$SENS" ]; then
  echo "$SENS" | while IFS= read -r f; do hit "tracked 敏感文件: $f"; done
else
  echo "  (none)"
fi

echo "=== 4/4 untracked 敏感文件名 ==="
UNSENS=$(git ls-files --others --exclude-standard | grep -iE '(\.env$|\.pem$|\.key$|credentials|\.secret$|secrets?\.json$)' || true)
if [ -n "$UNSENS" ]; then
  echo "$UNSENS" | while IFS= read -r f; do hit "untracked 敏感文件: $f"; done
else
  echo "  (none)"
fi

echo "---"
if [ "$(total)" -gt 0 ]; then echo "SECRET_FOUND=$(total)"; exit 1; else echo "SECRET_FOUND=0 (clean)"; exit 0; fi