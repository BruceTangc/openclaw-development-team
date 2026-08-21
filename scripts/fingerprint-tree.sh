#!/usr/bin/env bash
# fingerprint-tree.sh — 计算 Exact Working Tree Fingerprint（v1.0，P0 修复）
#
# 为什么不用 git write-tree：
#   write-tree 只反映 Git index/tree，不包含 untracked 文件。
#   若 Main Agent 在审核期间新增 untracked 文件（如 debug.py / .env），
#   write-tree 不变 → Reviewer 误判 TREE_UNCHANGED → 错误 APPROVED。
#
# 本脚本把以下全部纳入指纹（任一变化 → 指纹变 → INVALIDATED）：
#   - HEAD sha
#   - index tree（tracked + staged 状态）
#   - staged diff（--binary，含新增/修改的完整内容）
#   - unstaged diff（--binary）
#   - untracked 文件路径 + 内容（-z 安全处理空格/换行文件名）
#
# 输出：仅一行 sha256 指纹。
set -u
REPO="${1:?用法: fingerprint-tree.sh <仓库路径>}"
cd "$REPO" || exit 1

{
  echo "HEAD=$(git rev-parse HEAD 2>/dev/null || echo unborn)"
  echo "---index-tree---"
  git write-tree 2>/dev/null
  echo "---staged---"
  git diff --cached --binary 2>/dev/null
  echo "---unstaged---"
  git diff --binary 2>/dev/null
  echo "---untracked---"
  git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
    echo "FILE:$f"
    cat "$f" 2>/dev/null
  done
} | sha256sum | awk '{print $1}'