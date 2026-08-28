#!/usr/bin/env bash
# cost-report.sh — 成本/耗时汇总（P0 六.2，与运行日志联动）
#
# 读取 .runtime/manifest.jsonl，汇总：
#   - 日志总行数 / 按 model 统计次数
#   - tokens 累计（若记录了 --tokens）
#   - elapsed 累计（若记录了 --elapsed）
#   - 最近一次结束时间
#
# 用法：
#   scripts/cost-report.sh <仓库路径>
#   可选环境变量：DT_TIMEFRAME=12h|24h|7d 只统计最近时段（默认统计全部）

set -u
REPO="${1:?用法: cost-report.sh <仓库路径>}"
TIMEFRAME="${DT_TIMEFRAME:-}"

LOG="$REPO/.runtime/manifest.jsonl"
[ -f "$LOG" ] || { echo "无运行日志：$LOG（先运行 scripts/append-runtime-log.sh）" >&2; exit 0; }

if ! command -v python3 >/dev/null 2>&1; then
  echo '无 python3，无法生成汇总（日志行数如下）' >&2
  wc -l < "$LOG"
  exit 0
fi

python3 -c "
import json, os, sys
rows=[]
with open('$LOG','r',encoding='utf-8') as f:
    for line in f:
        line=line.strip()
        if not line: continue
        try: d=json.loads(line)
        except Exception: continue
        rows.append(d)

tf='$TIMEFRAME'
if tf:
    # 简单时间窗过滤（仅适用于 ts 形如 YYYY-MM-DDTHH:MM:SS）
    try:
        unit=tf[-1]; n=int(tf[:-1])
        mult={'h':3600,'d':86400,'m':60}.get(unit,3600)
        seconds=n*mult
        import time
        now=time.time()
        def to_epoch(ts):
            import re
            m=re.match(r'(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})', ts or '')
            if not m: return None
            import datetime
            try:
                dt=datetime.datetime.strptime(ts[:19],'%Y-%m-%dT%H:%M:%S')
                return dt.timestamp()
            except Exception: return None
        rows=[r for r in rows if (to_epoch(r.get('ts','')) or 0) >= now-seconds]
    except Exception:
        print('DT_TIMEFRAME 无法解析（示例 24h/7d/90m），忽略时间窗', file=sys.stderr)

model_count={}
total_tokens=0; have_tokens=0
total_elapsed=0.0; have_elapsed=0
for r in rows:
    m=r.get('model') or 'unset'
    model_count[m]=model_count.get(m,0)+1
    t=r.get('tokens')
    if t and str(t).strip().isdigit():
        total_tokens+=int(t); have_tokens+=1
    e=r.get('elapsed')
    if e and str(e).strip().replace('.','',1).isdigit():
        total_elapsed+=float(e); have_elapsed+=1

print('运行日志成本/耗时汇总（共 %d 条记录%s）' % (len(rows), ('，时间窗 '+tf) if tf else ''))
print('  按模型次数:')
for m,c in sorted(model_count.items(), key=lambda x:-x[1]):
    print('    %-28s %d' % (m,c))
print('  tokens 累计: %d（来自 %d 条记录）' % (total_tokens, have_tokens))
print('  elapsed 累计: %.1f 秒（%.2f 分钟，来自 %d 条记录）' % (total_elapsed, total_elapsed/60, have_elapsed))
if rows:
    ts_sorted=sorted([r.get('ts','') for r in rows], reverse=True)
    print('  最近记录时间: %s' % ts_sorted[0])
" || { echo 'cost-report 解析失败' >&2; exit 2; }
