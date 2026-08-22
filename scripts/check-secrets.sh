#!/usr/bin/env bash
# check-secrets.sh — 仓库 secrets 扫描（Reviewer 步骤 4 Security）
#
# P0-3 Verifier Hardening：删除内嵌 PATTERNS，改为 source scripts/secret-patterns.sh
# 统一规则库（SECRET_PATTERNS_ALL），确保 readiness / check-secrets / reviewer 三者
# 使用同一套 secret pattern 单一来源（C1：禁止第二套规则）。
#
# v1.0：修复 F-004-1 子 shell 计数丢失 bug（跨子 shell 计数聚合）。
# v2.0（P0-3）：secret 规则唯一来源 = scripts/secret-patterns.sh。
set -u
REPO="${1:?用法: check-secrets.sh <仓库路径>}"
cd "$REPO" || exit 1

# ---- 加载唯一 secret 规则库（P0-3：单一来源）----
# 解析脚本真实目录（兼容相对路径调用）：BASH_SOURCE[0] 可能是相对路径，先取绝对
SRC="${BASH_SOURCE[0]}"
if [[ "$SRC" != /* ]]; then SRC="$(pwd)/$SRC"; fi
SCRIPT_DIR="$(cd "$(dirname "$SRC")" && pwd)"
SECRET_PATTERN_COUNT=0
SECRET_PATTERNS_ALL=()
if [[ -f "$SCRIPT_DIR/secret-patterns.sh" ]]; then
  source "$SCRIPT_DIR/secret-patterns.sh"
else
  echo "ERROR: 统一 secret 规则库缺失 (scripts/secret-patterns.sh) — 无法执行 secret 检测 [BLOCK, fail-closed]" >&2
  exit 1
fi

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

# 统一匹配函数：逐条子正则 -e 匹配（复用 SECRET_PATTERNS_ALL，非内嵌）
match_text() { # $1=文本 stdin
  local l
  while IFS= read -r l; do
    for pat in "${SECRET_PATTERNS_ALL[@]}"; do
      if grep -qiE -- "$pat" <<< "$l" 2>/dev/null; then
        echo "$l"
        return 0
      fi
    done
  done
  return 1
}

echo "=== 1/4 tracked diff（staged + unstaged, --binary） ==="
# 同时扫 staged(--cached) 与 unstaged(--binary)。git diff HEAD 对已 add 的新文件输出为空，
# 必须额外扫 --cached 才能覆盖 staged 文件中的 secret。（P0-3 修复历史盲区）
{
  git diff HEAD --binary 2>/dev/null
  git diff --cached --binary 2>/dev/null
} | match_text | head -20 | while IFS= read -r l; do
  hit "diff: ${l%%:*}"
done
[ "$(total)" = 0 ] && echo "  (clean)"

echo "=== 2/4 untracked 文件内容扫描 ==="
git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
  if [ -f "$f" ]; then
    for pat in "${SECRET_PATTERNS_ALL[@]}"; do
      if grep -qiE -- "$pat" "$f" 2>/dev/null; then
        hit "untracked($(basename "$f")): secret 内容"
        break
      fi
    done
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
echo "secret 规则来源: scripts/secret-patterns.sh (${SECRET_PATTERN_COUNT} 条统一规则)"
if [ "$(total)" -gt 0 ]; then echo "SECRET_FOUND=$(total)"; exit 1; else echo "SECRET_FOUND=0 (clean)"; exit 0; fi
