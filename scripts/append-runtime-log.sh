#!/usr/bin/env bash
# append-runtime-log.sh — 向 .runtime/manifest.jsonl 追加一行结构化运行日志（P0 二.1+六.2）
#
# 目的：给 Development Team 提供统一的轻量运行时执行日志（runId/复杂度判定/Reviewer 决策/
#       commit hash/耗时/可选 model+token），作为「最近失败复盘」(recent-failures.sh) 与
#       「成本/耗时汇总」(cost-report.sh) 的数据源。纯增量，不改变任何现有协议/逻辑。
#
# 调用时机（Main Agent / Orchestrator 按需）：
#   spawn（DEV/REV 子代理发起）、决策（decision）、review 完成、commit 完成
#
# 用法：
#   scripts/append-runtime-log.sh <repository> \
#     --task <task_id> [--stage <stage>] [--status <status>] [--decision <词>] \
#     [--review-status <s>] [--commit <hash>] [--commit-msg <msg>] \
#     [--elapsed <seconds>] [--model <model>] [--tokens <n>] [--evidence <path>] [--note <text>]
#
# 追加行的字段（JSONL，一行一个 JSON 对象）：
#   ts            ISO-8601 时间戳（本机时区）
#   task_id       任务 id（如 DT-YYYYMMDD-001）
#   stage         spawn | decision | review | commit | resume（默认 misc）
#   decision      Agent OS 决策词：EXECUTE/ASK/ESCALATE/QUEUE/...（可空）
#   review_status APPROVED | REWORK_REQUIRED | BLOCKED | RUNTIME_FAILED ...（可空）
#   status        通用结果状态（FAILED / RUNTIME_FAILED / COMPLETED / ESCALATE ...）
#   commit        commit hash（如已提交）
#   elapsed       阶段/任务耗时（秒，便于 cost-report 汇总）
#   model         模型名（可选，成本归属）
#   tokens        消耗 token 数（可选）
#   evidence      evidence/artifact 相对路径（复盘时可直接打开）
#   note          备注（自由文本，保持脱敏规范）
#
# ✓ 脱敏：只记录计数字段与相对路径，不记录 key/token 明文/邮箱/hash。
# ✓ .runtime/ 已在 .gitignore（Phase2.1 资源治理计数用），本日志不入库。

set -u
REPO="${1:?用法: append-runtime-log.sh <仓库路径> [--task ...] [--stage ...] ...}"
shift

[ -d "$REPO/.git" ] || { echo "错误：不是 git 仓库：$REPO" >&2; exit 2; }

# ---- 解析可选参数 ----
task_id=""
stage="misc"
status=""
decision=""
review_status=""
commit=""
commit_msg=""
elapsed=""
model=""
tokens=""
evidence=""
note=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task)           task_id="${2:-}";          shift 2 ;;
    --stage)          stage="${2:-misc}";        shift 2 ;;
    --status)         status="${2:-}";           shift 2 ;;
    --decision)       decision="${2:-}";         shift 2 ;;
    --review-status)  review_status="${2:-}";    shift 2 ;;
    --commit)         commit="${2:-}";           shift 2 ;;
    --commit-msg)     commit_msg="${2:-}";       shift 2 ;;
    --elapsed)        elapsed="${2:-}";          shift 2 ;;
    --model)          model="${2:-}";            shift 2 ;;
    --tokens)         tokens="${2:-}";           shift 2 ;;
    --evidence)       evidence="${2:-}";         shift 2 ;;
    --note)           note="${2:-}";             shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed '1d' | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "未知选项：$1" >&2; exit 2 ;;
  esac
done

# 派生前置：若处于 spawn 阶段且未显式给 status，则回读当前开发任务状态
if [ "$stage" = "spawn" ] && [ -z "$status" ] && [ -n "$task_id" ]; then
  tf="$REPO/.tasks/$task_id/development-task.yaml"
  if [ -f "$tf" ]; then
    status="$(sed -n 's/^status:[[:space:]]*//p' "$tf" | head -1)"
  fi
fi

# ---- 组装 JSON（用 python3 做 JSON 转义，字段经环境变量安全传递）----
ts="$(date +%Y-%m-%dT%H:%M:%S%z)"
if command -v python3 >/dev/null 2>&1; then
  json="$(REPO_TS="$ts" REPO_TASK_ID="$task_id" REPO_STAGE="$stage" REPO_STATUS="$status" \
    REPO_DECISION="$decision" REPO_REVIEW_STATUS="$review_status" REPO_COMMIT="$commit" \
    REPO_COMMIT_MSG="$commit_msg" REPO_ELAPSED="$elapsed" REPO_MODEL="$model" \
    REPO_TOKENS="$tokens" REPO_EVIDENCE="$evidence" REPO_NOTE="$note" \
    python3 -c "
import os, json
field_env = {
    'task_id':'REPO_TASK_ID','stage':'REPO_STAGE','status':'REPO_STATUS',
    'decision':'REPO_DECISION','review_status':'REPO_REVIEW_STATUS',
    'commit':'REPO_COMMIT','commit_msg':'REPO_COMMIT_MSG','elapsed':'REPO_ELAPSED',
    'model':'REPO_MODEL','tokens':'REPO_TOKENS','evidence':'REPO_EVIDENCE','note':'REPO_NOTE',
}
d = {'ts': os.environ.get('REPO_TS','')}
for name, envk in field_env.items():
    v = os.environ.get(envk,'')
    if v != '':
        d[name] = v
print(json.dumps(d, ensure_ascii=False))
")"
  [ -z "$json" ] && { echo "错误：JSON 组装失败" >&2; exit 2; }
else
  # 无 python3 降级
  json="{\"ts\":\"$ts\",\"task_id\":\"$task_id\",\"stage\":\"$stage\",\"status\":\"$status\",\"decision\":\"$decision\",\"review_status\":\"$review_status\",\"commit\":\"$commit\",\"commit_msg\":\"$commit_msg\",\"elapsed\":\"$elapsed\",\"model\":\"$model\",\"tokens\":\"$tokens\",\"evidence\":\"$evidence\",\"note\":\"$note\"}"
  echo "警告：无 python3，未做 JSON 转义" >&2
fi

# ---- 追加到 .runtime/manifest.jsonl ----
mkdir -p "$REPO/.runtime"
printf '%s\n' "$json" >> "$REPO/.runtime/manifest.jsonl"
echo "logged: .runtime/manifest.jsonl += $json"
