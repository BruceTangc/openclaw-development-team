#!/usr/bin/env bash
#
# check-version-consistency.sh — 校验 Development Team 自身版本一致性
# ==================================================================
# 验证根目录 VERSION、CHANGELOG 顶部、git tag、GitHub Release 四者一致。
# VERSION 是权威源。发布前必须全部一致。
#
# 用法：
#   bash scripts/check-version-consistency.sh [<repo>]
#
# 退出码：
#   0 = 一致（PASS）
#   1 = 不一致（FAIL）

set -u
REPO="${1:-$(pwd)}"
cd "$REPO" || exit 1

VERSION_FILE="$REPO/VERSION"
CHANGELOG_FILE="$REPO/CHANGELOG.md"

echo "=== Development Team Version Consistency ==="
echo "Repo: $REPO"

# 1. VERSION 文件
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "  [FAIL] 缺少 VERSION 文件（权威版本源）"
  exit 1
fi
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
echo "  VERSION       = $VERSION"

# 2. CHANGELOG 顶部
if [[ ! -f "$CHANGELOG_FILE" ]]; then
  echo "  [FAIL] 缺少 CHANGELOG.md"
  exit 1
fi
CH_VER="$(grep -oP '^## \[\K[0-9.]+' "$CHANGELOG_FILE" 2>/dev/null | head -1)"
[[ -n "$CH_VER" ]] || { echo "  [FAIL] CHANGELOG 顶部无版本号"; exit 1; }
echo "  CHANGELOG     = $CH_VER"

# 3. git tag
TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo '(no tag)')"
TAG_VER="$(echo "$TAG" | sed 's/^v//')"
echo "  git tag       = $TAG"

OK=1
[[ "$VERSION" == "$CH_VER" ]] || { echo "  [FAIL] VERSION($VERSION) ≠ CHANGELOG($CH_VER)"; OK=0; }
if [[ "$TAG" != "(no tag)" ]]; then
  [[ "$VERSION" == "$TAG_VER" ]] || { echo "  [FAIL] VERSION($VERSION) ≠ tag($TAG)"; OK=0; }
else
  echo "  [NOTE] 暂无 git tag（首次发布前应打 v$VERSION）"
  # 无 tag 不阻断本次版本文件一致性，但发布时必须存在
fi

if [[ "$OK" -eq 1 ]]; then
  echo "  RESULT: PASS（VERSION/CHANGELOG一致；tag/Release 需在发布时对齐）"
  echo ""
  echo "发布前必须确认：VERSION == CHANGELOG 顶部 == git tag vX.Y.Z == GitHub Release。"
  exit 0
else
  echo "  RESULT: FAIL（版本不一致，禁止发布）"
  exit 1
fi
