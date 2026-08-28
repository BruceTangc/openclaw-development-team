#!/usr/bin/env bash
# resume-task.sh — 继续上次未完成任务（P0 三.2，WIP/断点续跑）
#
# 读取 .tasks/<task_id>/development-task.yaml 的 status 字段，结合该任务目录下已落盘的
# plan/result/review artifact，输出「续跑指针」：当前状态、下一步该做什么、可参考的 evidence。
#
# 用途：
#   - 中途失败/超时/断电后，Main Agent 执行「continue <task_id>」恢复上次任务。
#   - 通过 status（NEW→DELEGATED→RUNNING→RUNTIME_COMPLETED→REVIEWING→APPROVED/FAILED）
#     与已存在的 artifact，判断是从头、接续实施、还是进 Review。
#
# 用法：
#   scripts/resume-task.sh <仓库路径> <task_id>
#
# 退出码：任务目录存在且可续跑 → 0；不存在 → 1；无 plan → 1。
#
# ✓ 纯读操作，不修改任何文件；不自动 spawn。真正继续由 Main Agent 依输出决定（配合
#   append-runtime-log.sh 记录一次 stage=resume）。

set -u
REPO="${1:?用法: resume-task.sh <仓库路径> <task_id>}"
TASK_ID="${2:?用法: resume-task.sh <仓库路径> <task_id>}"

TASKDIR="$REPO/.tasks/$TASK_ID"
TASKFILE="$TASKDIR/development-task.yaml"
[ -f "$TASKFILE" ] || { echo "任务不存在：$TASKFILE（$TASK_ID）" >&2; exit 1; }

status="$(sed -n 's/^status:[[:space:]]*//p' "$TASKFILE" | head -1 | tr -d '[:space:]')"
task_type="$(sed -n 's/^task_type:[[:space:]]*//p' "$TASKFILE" | head -1 | tr -d '[:space:]')"
goal="$(sed -n 's/^goal:[[:space:]]*//p' "$TASKFILE" | head -1)"

echo "Resume 指针: $TASK_ID"
echo "  task_type : ${task_type:-?}"
echo "  status    : ${status:-?}"
echo "  goal      : ${goal:-?}"
echo "  已落盘 Artifact : "
# 列出任务目录下除 development-task.yaml 外的所有 artifact
has_artifact=0
for f in "$TASKDIR"/*.yaml "$TASKDIR"/handoff-log.md; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = "development-task.yaml" ] && continue
  echo "      - $f"
  has_artifact=1
done
[ "$has_artifact" = 0 ] && echo "      （无其他 artifact，仅 development-task.yaml）"

# 依据 status 给下一步建议
case "$status" in
  NEW)
    echo "  下一步: 尚未委派 — 从 delegation 阶段继续（status→DELEGATED 后 spawn Developer）。" ;;
  DELEGATED|RUNNING)
    echo "  下一步: 实施中 — 若上次 Developer 未产出结构化 result → 重新 spawn Developer；" \
         "已产出 implementation-result → 继续 Test/Review。" ;;
  RUNTIME_COMPLETED|ARTIFACT_PENDING_VERIFICATION|REVIEWING)
    echo "  下一步: 进 Review — spawn Reviewer 独立验证；出 review result 后再决定。" ;;
  APPROVED|IMPLEMENTATION_VERIFIED|PROJECT_READY|COMPLETED|CLOSED)
    echo "  下一步: 该任务已关闭（status=$status），无需继续；如需增量请开新 task。" ;;
  FAILED|RUNTIME_FAILED)
    echo "  下一步: 上次失败 — 先 scripts/recent-failures.sh 复盘，再 R1(重试)/R2(接管)/R3(ESCALATE)。" ;;
  *)
    echo "  下一步: 状态『${status:-（空）}』未知 — 参照 plan/result 与 handoff-log.md 判断续跑点。" ;;
esac

# 完成后可记录 stage=resume 到运行日志
echo "  提示: 续跑后建议执行 scripts/append-runtime-log.sh $REPO --task $TASK_ID --stage resume --status RUNNING"
