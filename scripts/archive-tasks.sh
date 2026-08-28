#!/usr/bin/env bash
# archive-tasks.sh — .tasks/ 证据目录归档（P0 五.3，防 git 膨胀）
#
# 将「已关闭且距离 closed_at 超过 N 天」的任务目录，从 .tasks/<task_id> 移到
# .tasks.archived/<task_id>，并 git rm 原目录（保留 archived 副本便于追溯）。
#
# 「已关闭」判定（development-task.yaml 的 status 命中任一终态）：
#   APPROVED / IMPLEMENTATION_VERIFIED / PROJECT_READY / COMPLETED / CLOSED
# 「关闭时间」：
#   - 优先读 development-task.yaml 里的 closed_at（若有该字段）
#   - 否则退回 development-task.yaml 文件 mtime（保证向后兼容，不强制改模板）
#
# 用法：
#   scripts/archive-tasks.sh <仓库路径> [天数]
#     天数 = 归档「关闭超过 N 天」的任务（默认 30 天）
#
# 行为：
#   - 对每个待归档任务：确认无未提交改动 → git rm -r → merge 到 .tasks.archived/<task_id>
#   - 仅 `git rm`（不自动 commit；commit 由 Main Agent 按 git-workflow.md 决定，push≠release）
#   - 幂等：已归档目录跳过；无待归档时输出提示并以 0 退出
#
# ✓ 保留周期：.tasks.archived/ 建议同样纳入版本控制保留最近一个周期，必要时人工清理；
#   或按团队策略整体 .gitignore（见 README「保留周期」声明）。本脚本默认不 gitignore archived。

set -u
REPO="${1:?用法: archive-tasks.sh <仓库路径> [天数]}"
DAYS="${2:-30}"

cd "$REPO" || exit 1

ARCHIVED="$REPO/.tasks.archived"
TASKS_DIR="$REPO/.tasks"
mkdir -p "$ARCHIVED"

# 终端状态集合（空格分隔）
TERMINAL="APPROVED IMPLEMENTATION_VERIFIED PROJECT_READY COMPLETED CLOSED"

now_epoch="$(date +%s)"
threshold=$(( now_epoch - DAYS*86400 ))

archived=0
skipped=0

while IFS= read -r taskfile; do
  [ -f "$taskfile" ] || continue
  task_id="$(basename "$(dirname "$taskfile")")"
  taskdir="$(dirname "$taskfile")"

  # 已归档则跳过
  [ -d "$ARCHIVED/$task_id" ] && { skipped=$((skipped+1)); continue; }

  status="$(sed -n 's/^status:[[:space:]]*//p' "$taskfile" | head -1 | tr -d '[:space:]')"

  # 是否为终态
  is_terminal=0
  for t in $TERMINAL; do
    [ "$status" = "$t" ] && { is_terminal=1; break; }
  done
  [ "$is_terminal" = 1 ] || { skipped=$((skipped+1)); continue; }

  # 关闭时间（优先 closed_at 字段，否则 mtime）
  closed_line="$(sed -n 's/^closed_at:[[:space:]]*//p' "$taskfile" | head -1 | tr -d '[:space:]')"
  if [ -n "$closed_line" ]; then
    closed_epoch="$(date -d "$closed_line" +%s 2>/dev/null || echo '')"
  else
    closed_epoch=""
  fi
  if [ -z "$closed_epoch" ]; then
    closed_epoch="$(stat -c %Y "$taskfile")"
  fi

  if [ "$closed_epoch" -gt "$threshold" ]; then
    skipped=$((skipped+1)); continue   # 关闭未满 N 天，暂不归档
  fi

  # 确认无未提交改动（保护用户 dirty 文件——继承 git-workflow.md 原则）
  if [ -n "$(git status --porcelain -- "$taskdir")" ]; then
    echo "跳过 $task_id：目录有未提交改动（不归档，保护 dirty 文件）"
    skipped=$((skipped+1)); continue
  fi

  # 归档：合并到 archived 目录 + 从 git 清理（不自动 commit）
  cp -r "$taskdir" "$ARCHIVED/$task_id"
  git rm -r -q --ignore-unmatch "$taskdir"
  archived=$((archived+1))
  echo "archived: $task_id  (status=$status, 关闭超过 ${DAYS} 天) → .tasks.archived/$task_id"
done < <(find "$TASKS_DIR" -maxdepth 2 -name development-task.yaml 2>/dev/null)

echo "---"
echo "已归档 $archived 个任务，跳过 $skipped（未关闭/未满${DAYS}天/已归档/有 dirty）。"
if [ "$archived" -eq 0 ]; then
  echo "无待归档任务。可调天数：scripts/archive-tasks.sh <仓库路径> <天数>"
fi
echo "说明：已 git rm 并从 .tasks/ 清出；如需入库请自行 commit（按 git-workflow.md）。"
