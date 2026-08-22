#!/usr/bin/env bash
#
# protocol-compliance-check.sh — Generated Artifact Protocol Compliance Gate（P0，Verifier Hardening 版）
# ===============================================================================
# 依据 Agent OS SKILL-INTEGRATION.md v1.3（当前真实 Protocol）。
# P0-1: 值校验由 scripts/verify_artifact.py（结构化 YAML parser）执行，本脚本不再 grep 字段存在。
# P0-4: 协议基线从 scripts/protocol-baseline.sh 单一来源读取，本脚本不硬编码版本号。
#
# 用途：
#   1) Author（Developer/Lead）提交前自检生成物（Skill/Agent/Project）
#   2) Reviewer §3.7 作为 Protocol Compliance 子步的自动辅助（最终判定仍由 Reviewer 人工确认）
#
# 用法：
#   ./scripts/protocol-compliance-check.sh <artifact-dir> [skill|agent|project|auto]
#
# 退出码：
#   0 = PASS（或全部合法 N/A）
#   1 = FAIL（值非法 / 缺关键结构 / 自然语言绕过 / ER 缺证据）
#   2 = WARN（部分项需 Reviewer 确认，不自动阻断）
#   3 = 用法错误 / 目录不存在 / python 缺失
set -u

ARTIFACT_DIR="${1:-}"
TYPE="${2:-auto}"
if [[ -z "$ARTIFACT_DIR" ]]; then
  echo "用法: $0 <artifact-dir> [skill|agent|project|auto]" >&2
  exit 3
fi
if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "ERROR: 目录不存在: $ARTIFACT_DIR" >&2
  exit 3
fi

# 本脚本目录（绝对路径）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 依赖：verify_artifact.py（结构化 validator）
VALIDATOR="$SCRIPT_DIR/verify_artifact.py"
if [[ ! -f "$VALIDATOR" ]]; then
  echo "ERROR: 缺少 validator 脚本: $VALIDATOR（需与 protocol-baseline.sh 同目录）" >&2
  exit 3
fi

# 需要 python3 + PyYAML
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: 需要 python3" >&2
  exit 3
fi
command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null \
  || { echo "ERROR: 需要 PyYAML（pip install pyyaml）" >&2; exit 3; }

# 委托给结构化 validator（唯一判定逻辑）：只取退出码，输出直接透传 stdout/stderr
$(command -v python3) "$VALIDATOR" "$ARTIFACT_DIR" "$TYPE"
exit $?
