#!/usr/bin/env bash
# recent-failures.sh — 一键复盘最近失败（P0 二.2）
#
# 读取 .runtime/manifest.jsonl（由 append-runtime-log.sh 追加），按 status / decision / review_status
# 过滤失败/退出/升级行，输出最近 N 条（含 task/阶段/evidence 路径），按时间倒序，便于快速复盘「上一单为什么失败」。
#
# 失败判定（任一命中即视为失败行）：
#   status        ∈ FAILED | RUNTIME_FAILED
#   decision      ∈ ESCALATE
#   review_status ∈ BLOCKED | RUNTIME_FAILED | FAILED
#
# 用法：
#   scripts/recent-failures.sh <仓库路径> [N]
#     N  = 输出最近 N 条（默认 10）
#
# 依赖：python3（用于标准 JSON 解析）。无 python3 时降级用 grep。

set -u
REPO="${1:?用法: recent-failures.sh <仓库路径> [N]}"
N="${2:-10}"

LOG="$REPO/.runtime/manifest.jsonl"
[ -f "$LOG" ] || { echo "无运行日志：$LOG（先运行 scripts/append-runtime-log.sh）" >&2; exit 0; }

if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import json, sys
fails=['FAILED','RUNTIME_FAILED','ESCALATE','BLOCKED']
rows=[]
with open('$LOG','r',encoding='utf-8') as f:
    for line in f:
        line=line.strip()
        if not line: continue
        try: d=json.loads(line)
        except Exception: continue
        status=(d.get('status') or '').upper()
        dec=(d.get('decision') or '').upper()
        rev=(d.get('review_status') or '').upper()
        if status in ('FAILED','RUNTIME_FAILED') or dec=='ESCALATE' or rev in ('FAILED','RUNTIME_FAILED','BLOCKED'):
            rows.append(d)
rows.sort(key=lambda r:r.get('ts',''), reverse=True)
rows=rows[:$N]
if not rows:
    print('（无失败记录）')
    sys.exit(0)
print('最近 %d 条失败/退出/升级记录（倒序）：' % len(rows))
for d in rows:
    ev=d.get('evidence') or ''
    print('  %s  task=%s  stage=%s  status=%s  decision=%s  review=%s' % (
        d.get('ts','?'), d.get('task_id',''), d.get('stage',''),
        d.get('status','') or '-', d.get('decision','') or '-',
        d.get('review_status','') or '-'))
    if ev: print('        evidence: %s' % ev)
    if d.get('note'): print('        note: %s' % d['note'])
" 2>/dev/null || {
  echo 'python3 解析失败，降级用 grep 过滤' >&2
  grep -E 'FAILED|RUNTIME_FAILED|ESCALATE|BLOCKED' "$LOG" | tail -n "$N"
}
else
  echo '警告：无 python3，降级用 grep 粗过滤（无法可靠解析 JSONL）' >&2
  grep -E 'FAILED|RUNTIME_FAILED|ESCALATE|BLOCKED' "$LOG" | tail -n "$N"
fi
