#!/usr/bin/env bash
# collect-state.sh — 采集仓库基础状态（DISCOVER/SNAPSHOT 前置，v1.0）
#
# v1.0：新增 working_tree_fingerprint（Exact Working Tree Fingerprint，
# 含 tracked/staged/unstaged/untracked 路径与内容，替代单一 git write-tree）。
set -u
REPO="${1:?用法: collect-state.sh <仓库路径>}"
cd "$REPO" || exit 1
DIR="$(dirname "$0")"

echo "repo=$(pwd)"
echo "branch=$(git branch --show-current 2>/dev/null)"
echo "head=$(git rev-parse HEAD 2>/dev/null)"
echo "index_tree=$(git write-tree 2>/dev/null)"
echo "working_tree_fingerprint=$(bash "$DIR/fingerprint-tree.sh" "$REPO")"
echo "remote=$(git remote get-url origin 2>/dev/null || echo '(no remote)')"
echo "--- status ---"
git status --short
echo "--- upstream ---"
git rev-parse origin/HEAD 2>/dev/null || echo "(no upstream)"