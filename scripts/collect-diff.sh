#!/usr/bin/env bash
# collect-diff.sh — 采集完整变更（Reviewer 步骤 1 输入；迁移自 RR，见 protocols/review-adapter.md §7）
set -u
REPO="${1:?用法: collect-diff.sh <仓库路径>}"
cd "$REPO" || exit 1
echo "=== name-status (HEAD) ==="
git diff HEAD --name-status
echo "=== staged stat ==="
git diff --cached --stat
echo "=== unstaged stat ==="
git diff --stat
echo "=== untracked ==="
git ls-files --others --exclude-standard
echo "=== diff HEAD (full) ==="
git diff HEAD
