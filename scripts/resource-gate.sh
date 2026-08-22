#!/usr/bin/env bash
# resource-gate.sh — Development Team Resource Governance Gate（Phase 2.1）
# ============================================================================
# 在 OpenClaw Runtime 与 DT Workflow 之间加轻量资源门槛，防止多个 Agent /
# sessions_spawn 并发压垮服务器。
#
# 职责（只做一件事）：
#   是否允许 DT 发起新的 expensive execution。不实现 Runtime/scheduler/
#   process manager/模型 API；复用 OpenClaw 原生 + 轻量计数。
#
# 输入：resource-budget.yaml（可配置预算）
# 输出：ALLOW / QUEUE / REJECT + 逐项明细
#
# 退出码（gate 模式）：
#   0 = ALLOW（可以 spawn）
#   1 = QUEUE（软超限，建议稍后重试）
#   2 = REJECT（硬超限，服务器保护优先，禁止 spawn）
#   3 = 用法错误 / budget 缺失（fail-closed → REJECT）
#
# 子命令（lease 生命周期，按 role 分离）：
#   resource-gate.sh <repo> acquire <role> <session_id>
#       — 占用一条租约（role=developer | reviewer），落盘 .runtime/leases/<role>/<session_id>（含 timestamp）
#   resource-gate.sh <repo> release <role> <session_id>
#       — 释放一条租约（删除对应 lease 文件）
#   resource-gate.sh <repo> status
#       — 打印当前各 role 的 active/stale lease 明细（只读）
#
# ── Lease 生命周期（Orchestrator 强制）─────────────────────────────────────
#   Developer lease 与 Reviewer lease 按 role 分离管理：
#     1. spawn Developer 前：acquire role=developer <dev_session_id>
#     2. Developer RUNTIME_COMPLETED 后：release role=developer <dev_session_id>
#     3. 进入 Review 前：acquire role=reviewer <rev_session_id>（释放 Developer lease 之后）
#     4. Reviewer 结束（APPROVED/REWORK_REQUIRED/BLOCKED）后：release role=reviewer
#   - Reviewer 计入 max_active_reviewers，**不是**新的 Development Task（不计 max_active_development_tasks）。
#   - crash/timeout：lease 带 timestamp，超过 lease_ttl_seconds 未释放 → 视为 stale，
#     `status`/`acquire`/gate 计数都会自动剔除 stale lease（由 Orchestrator 回收）。
#
# 资源读取（无 cgroup v2 兼容环境用 /proc）：
#   - 内存：/proc/meminfo  MemTotal vs MemAvailable
#   - CPU  ：/proc/loadavg 1min-load 折算到 CPU 核数（≈ 使用率）
#   - 并发：<<repo_root>/.runtime/leases/<role>/<session_id> 租约文件（DT 自身维护，非自建 runtime 调度）
set -u

REPO="${1:?用法: resource-gate.sh <repo 路径> [acquire|release|status <role> <session_id>]}"
if [[ ! -d "$REPO" ]]; then
  echo "RESOURCE_GATE=REJECT"; echo "  reason: 仓库路径不存在 $REPO"
  exit 2
fi

# ─── 读取预算（fail-closed：budget 缺失 = REJECT）───
BUDGET="$REPO/resource-budget.yaml"
if [[ ! -f "$BUDGET" ]]; then
  echo "RESOURCE_GATE=REJECT"; echo "  reason: resource-budget.yaml 缺失（fail-closed）"
  exit 2
fi

# 解析 YAML 关键值（宽松正则可解析本文件固定结构；异常值回退默认）
parse_budget() {
  local key="$1" def="${2:-}"
  local v
  v=$(grep -E "^[[:space:]]*${key}:[[:space:]]*" "$BUDGET" 2>/dev/null | head -1 | sed -E 's/^[^:]+:[[:space:]]*//' | sed -E 's/[[:space:]]+#.*$//' | tr -d ' "\r')
  [[ -n "$v" ]] && echo "$v" || echo "$def"
}
CPU_SOFT=$(parse_budget cpu_soft_limit_percent 80)
CPU_HARD=$(parse_budget cpu_hard_limit_percent 95)
MEM_SOFT=$(parse_budget memory_soft_limit_percent 80)
MEM_HARD=$(parse_budget memory_hard_limit_percent 90)
MAX_DEV=$(parse_budget max_active_developers 1)
MAX_REV=$(parse_budget max_active_reviewers 1)
MAX_TASK=$(parse_budget max_active_development_tasks 1)
COOLDOWN=$(parse_budget spawn_cooldown_seconds 10)
LEASE_TTL=$(parse_budget lease_ttl_seconds 1800)

# ─── 租约目录 / 计数 ───
RUNTIME_DIR="$REPO/.runtime"
LEASE_DIR="$RUNTIME_DIR/leases"
now=$(date +%s)

# 统计某 role 的 active/stale lease 数（lease 文件含 timestamp；超过 TTL 视为 stale 剔除）
lease_counts() {
  local role="$1"
  local active=0 stale=0
  local d="$LEASE_DIR/$role"
  [[ -d "$d" ]] || { echo "$active $stale"; return; }
  local f ts age
  for f in "$d"/*; do
    [[ -f "$f" ]] || continue
    ts=$(cat "$f" 2>/dev/null | tr -cd '0-9')
    [[ -n "$ts" ]] || ts=0
    age=$(( now - ts ))
    if [[ "$age" -gt "$LEASE_TTL" ]]; then
      stale=$((stale+1))
    else
      active=$((active+1))
    fi
  done
  echo "$active $stale"
}

# 兼容旧计数文件（.runtime/active_developers 等）——仅当 lease 目录不存在时 fallback
count_file_or_lease() {
  local role="$1" countfile="$2"
  if [[ -d "$LEASE_DIR" ]]; then
    read -r ACTIVE STALE <<< "$(lease_counts "$role")"
    echo "$ACTIVE"
  else
    cat "$RUNTIME_DIR/$countfile" 2>/dev/null || echo 0
  fi
}

# ─── 子命令分发 ───
CMD="${2:-gate}"
if [[ "$CMD" == "acquire" || "$CMD" == "release" || "$CMD" == "status" ]]; then
  ROLE="${3:-}"
  SID="${4:-}"
  case "$CMD" in
    acquire)
      [[ -n "$ROLE" && -n "$SID" ]] || { echo "用法: $0 <repo> acquire <role> <session_id>"; exit 3; }
      mkdir -p "$LEASE_DIR/$ROLE"
      echo "$now" > "$LEASE_DIR/$ROLE/$SID"
      echo "LEASE_ACQUIRED role=$ROLE session_id=$SID ts=$now"
      exit 0
      ;;
    release)
      [[ -n "$ROLE" && -n "$SID" ]] || { echo "用法: $0 <repo> release <role> <session_id>"; exit 3; }
      rm -f "$LEASE_DIR/$ROLE/$SID"
      echo "LEASE_RELEASED role=$ROLE session_id=$SID"
      exit 0
      ;;
    status)
      echo "=== Resource Lease Status ==="
      for role in developer reviewer; do
        read -r A S <<< "$(lease_counts "$role")"
        echo "  role=$role active=$A stale=$S max=$(parse_budget "max_active_${role}s" 1) ttl=${LEASE_TTL}s"
        if [[ -d "$LEASE_DIR/$role" ]]; then
          for f in "$LEASE_DIR/$role"/*; do
            [[ -f "$f" ]] || continue
            ts=$(cat "$f" 2>/dev/null | tr -cd '0-9')
            age=$(( now - ${ts:-0} ))
            local_mark="active"
            [[ "$age" -gt "$LEASE_TTL" ]] && local_mark="STALE"
            echo "    - $(basename "$f") ts=${ts:-0} age=${age}s [$local_mark]"
          done
        fi
      done
      exit 0
      ;;
  esac
fi

# ─── 系统资源 /proc 读取 ───
CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
# 内存使用率 %
MEM_PCT=0
if [[ -f /proc/meminfo ]]; then
  TOT=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
  AVAIL=$(awk '/MemAvailable:/{print $2}' /proc/meminfo)
  if [[ -n "$TOT" && -n "$AVAIL" && "$TOT" -gt 0 ]]; then
    MEM_PCT=$(( (TOT - AVAIL) * 100 / TOT ))
  fi
fi
# CPU 使用率 %（loadavg 1min / cores，封顶 100）
CPU_PCT=0
if [[ -f /proc/loadavg ]]; then
  LOAD1=$(awk '{print $1}' /proc/loadavg)
  CPU_PCT=$(python3 -c "print(min(100, int(float('$LOAD1')/$CORES*100)))" 2>/dev/null || echo 0)
fi

# ─── 并发计数（租约文件 / 兼容计数文件，按 role 分离，含 stale 剔除）───
COUNT_DEV="$(count_file_or_lease developer active_developers)"
COUNT_REV="$(count_file_or_lease reviewer active_reviewers)"
COUNT_TASK="$(cat "$RUNTIME_DIR/active_tasks" 2>/dev/null || echo 0)"
read -r _ STALE_DEV <<< "$(lease_counts developer)"
read -r _ STALE_REV <<< "$(lease_counts reviewer)"

# ─── 判定 ───
echo "=== Resource Gate ==="
echo "  budget: cpu_soft=$CPU_SOFT% cpu_hard=$CPU_HARD% mem_soft=$MEM_SOFT% mem_hard=$MEM_HARD% lease_ttl=${LEASE_TTL}s"
echo "  current: cpu=$CPU_PCT% mem=$MEM_PCT% dev=$COUNT_DEV/$MAX_DEV rev=$COUNT_REV/$MAX_REV task=$COUNT_TASK/$MAX_TASK"
echo "  stale: dev=$STALE_DEV rev=$STALE_REV（超 ${LEASE_TTL}s 未释放，将被/已被回收）"
echo "  cores=$CORES load1=$(awk '{print $1}' /proc/loadavg 2>/dev/null)"

DECISION="ALLOW"
REASONS=()

# 硬超限 → 无条件 REJECT（保护服务器优先于完成任务）
if [[ "$MEM_PCT" -ge "$MEM_HARD" ]]; then REASONS+=("内存达硬上限 ${MEM_PCT}%≥${MEM_HARD}%"); DECISION="REJECT"; fi
if [[ "$CPU_PCT" -ge "$CPU_HARD" ]]; then REASONS+=("CPU 达硬上限 ${CPU_PCT}%≥${CPU_HARD}%"); DECISION="REJECT"; fi

# 软超限（若未硬 REJECT）
if [[ "$DECISION" == "ALLOW" ]]; then
  if [[ "$MEM_PCT" -ge "$MEM_SOFT" ]]; then REASONS+=("内存软超限 ${MEM_PCT}%≥${MEM_SOFT}%"); DECISION="QUEUE"; fi
  if [[ "$CPU_PCT" -ge "$CPU_SOFT" ]]; then REASONS+=("CPU 软超限 ${CPU_PCT}%≥${CPU_SOFT}%"); DECISION="QUEUE"; fi
  # 并发超限 → QUEUE（not reject，等槽位释放）；stale lease 不计入 active
  if [[ "$COUNT_DEV" -ge "$MAX_DEV" ]]; then REASONS+=("Developer 并发满 ${COUNT_DEV}/${MAX_DEV}"); DECISION="QUEUE"; fi
  if [[ "$COUNT_REV" -ge "$MAX_REV" ]]; then REASONS+=("Reviewer 并发满 ${COUNT_REV}/${MAX_REV}"); DECISION="QUEUE"; fi
  if [[ "$COUNT_TASK" -ge "$MAX_TASK" ]]; then REASONS+=("任务并发满 ${COUNT_TASK}/${MAX_TASK}"); DECISION="QUEUE"; fi
fi

if [[ ${#REASONS[@]} -gt 0 ]]; then
  for r in "${REASONS[@]}"; do echo "  → $r"; done
fi
echo "RESOURCE_GATE=$DECISION"
case "$DECISION" in
  REJECT) exit 2 ;;
  QUEUE)  exit 1 ;;
  *)      exit 0 ;;
esac
