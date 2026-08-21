#!/usr/bin/env bash
# verify-tree.sh — 校验工作树是否与快照一致（INVALIDATION 检测，v1.0）
#
# v1.0：从 git write-tree 升级为 Exact Working Tree Fingerprint（fingerprint-tree.sh），
# 覆盖 tracked/staged/unstaged/untracked 路径与内容。
set -u
REPO="${1:?用法: verify-tree.sh <仓库路径> <期望fingerprint>}"
EXPECTED="${2:?用法: verify-tree.sh <仓库路径> <期望fingerprint>}"
cd "$REPO" || exit 1

NOW=$(bash "$(dirname "$0")/fingerprint-tree.sh" "$REPO")

if [ "$NOW" = "$EXPECTED" ]; then
  echo "TREE_UNCHANGED (fp=$NOW)"
  exit 0
else
  echo "TREE_CHANGED: $EXPECTED -> $NOW"
  exit 1
fi