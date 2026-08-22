#!/usr/bin/env bash
#
# dt-version.sh — Development Team Runtime Version Chain report
# ==================================================================
# 极简运行时版本链：让任意安装副本能回答——
#   Development Team Version / Protocol Baseline / Git Commit / Installed At /
#   OpenClaw Discovery / Agent Eligibility
#
# 用途：Source of Truth（GitHub repo）与 Installed Runtime State（安装副本）脱节的
#   最小自证工具。不 invent 复杂 registry，只读本地 VERSION / 协议基线 / install 时
#   落盘的 manifest，并复用 OpenClaw 原生 skills info 做 discovery/eligibility 校验。
#
# 用法：
#   bash scripts/dt-version.sh [<dt-dir>]
#
# 退出码：
#   0 = 版本链可完整报告（version/commit/protocol 齐全）
#   2 = 部分字段缺失（installed_at/commit 未落盘，仍输出其余字段）
set -u

DT_DIR="${1:-}"
if [[ -z "$DT_DIR" ]]; then
  DT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ── version ──
VERSION="$(tr -d '[:space:]' < "$DT_DIR/VERSION" 2>/dev/null || echo 'unknown')"

# ── protocol baseline（复用单一真源，不硬编码）──
PROTO_LABEL="unknown"; PROTO_COMMIT="unknown"
if [[ -f "$DT_DIR/scripts/protocol-baseline.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DT_DIR/scripts/protocol-baseline.sh"
  PROTO_LABEL="${AGENT_OS_BASELINE_LABEL:-unknown}"
  PROTO_COMMIT="${AGENT_OS_BASELINE_COMMIT:-unknown}"
fi

# ── commit ──
COMMIT="unknown"
if git -C "$DT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  COMMIT="$(git -C "$DT_DIR" rev-parse HEAD)"
elif [[ -f "$DT_DIR/VERSION_COMMIT" ]]; then
  COMMIT="$(tr -d '[:space:]' < "$DT_DIR/VERSION_COMMIT")"
fi

# ── installed_at ──
INSTALLED_AT="unknown"
if [[ -f "$DT_DIR/INSTALLED_AT" ]]; then
  INSTALLED_AT="$(tr -d '[:space:]' < "$DT_DIR/INSTALLED_AT")"
fi

# ── OpenClaw discovery / eligibility（复用原生 skills info，不解析内部文件）──
DISCOVERED="NOT_RUN"; ELIGIBLE="NOT_RUN"
if command -v openclaw >/dev/null 2>&1; then
  INFO="$(openclaw skills info development-team --json 2>/dev/null)"
  if [[ -n "$INFO" ]]; then
    FP="$(echo "$INFO" | python3 -c "import sys,json;
try: d=json.load(sys.stdin); print(d.get('filePath','') or '')
except: print('')" 2>/dev/null)"
    EL="$(echo "$INFO" | python3 -c "import sys,json;
try: d=json.load(sys.stdin); print(str(d.get('eligible','')).lower())
except: print('')" 2>/dev/null)"
    [[ -n "$FP" ]] && DISCOVERED="PASS"
    [[ "$EL" == "true" ]] && ELIGIBLE="PASS"
  fi
fi

echo "Development Team"
echo "  version:      $VERSION"
echo "  commit:       $COMMIT"
echo "  protocol:     $PROTO_LABEL / $PROTO_COMMIT"
echo "  installed_at: $INSTALLED_AT"
echo "  discovered:   $DISCOVERED"
echo "  eligible:     $ELIGIBLE"

if [[ "$VERSION" == "unknown" || "$COMMIT" == "unknown" ]]; then
  exit 2
fi
exit 0
