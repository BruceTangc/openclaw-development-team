#!/usr/bin/env bash
#
# project-readiness-check.sh
# ==========================
# OpenClaw Development Team — Project Readiness Gate
#
# 在 Developer 宣布 IMPLEMENTATION COMPLETE 之前必须通过此检查。
# 检查不只是「文件是否存在」，而是验证内容是否符合交付标准。
#
# 用法：
#   ./scripts/project-readiness-check.sh <project-dir> [project-type]
#     project-type: generic | python | node | openclaw-skill | docker | auto
#                   (auto = 尝试从项目内容推断，默认)
#
# 退出码：
#   0  = 全部通过（PASS）
#   1  = 存在阻断性缺陷（FAIL）
#   2  = 存在非阻断警告，但同时有阻断性缺陷
#   3  = 用法错误 / 项目目录不存在
#
# 判定语义：
#   本脚本只判断工具层面可自动验证的项。
#   - 内容/可运行性验证由 Test & Runtime Validator + Reviewer Stranger User Audit 负责。
#   - 无法自动验证的项（如「陌生用户能否独立运行」）标记 SKIP，由下游 Reviewer 人工验证，
#     绝不伪造 PASS。

set -u

# ---------- 配置 ----------
PROJECT_DIR="${1:-}"
PROJECT_TYPE="${2:-auto}"

if [[ -z "$PROJECT_DIR" ]]; then
  echo "ERROR: 缺少项目目录参数" >&2
  echo "用法: $0 <project-dir> [project-type]" >&2
  exit 3
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: 目录不存在: $PROJECT_DIR" >&2
  exit 3
fi

cd "$PROJECT_DIR" || exit 3

# ---------- 状态 ----------
PASS_COUNT=0
FAIL=0
WARN=0
SKIP=0
FAIL_MSGS=()
WARN_MSGS=()

ok()   { PASS_COUNT=$((PASS_COUNT+1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL+1)); FAIL_MSGS+=("$1"); echo "  [FAIL] $1"; }
warn() { WARN=$((WARN+1)); WARN_MSGS+=("(warn) $1"); echo "  [WARN] $1"; }
skip() { SKIP=$((SKIP+1)); echo "  [SKIP] $1 (需人工验证)"; }

# ---------- 类型推断 ----------
detect_type() {
  if [[ -f "SKILL.md" && -f "README.md" ]]; then
    echo "openclaw-skill"; return
  fi
  if [[ -f "Dockerfile" || -f "compose.yaml" || -f "compose.yml" ]]; then
    echo "docker"; return
  fi
  if [[ -f "pyproject.toml" || -f "requirements.txt" || -f "setup.py" ]]; then
    echo "python"; return
  fi
  if [[ -f "package.json" ]]; then
    echo "node"; return
  fi
  echo "generic"
}

if [[ "$PROJECT_TYPE" == "auto" ]]; then
  PROJECT_TYPE="$(detect_type)"
fi

echo ""
echo "=============================================="
echo " Project Readiness Check"
echo "=============================================="
echo "  Directory : $PROJECT_DIR"
echo "  Type      : $PROJECT_TYPE"
echo ""

# ---------- 0. Git 仓库卫生 ----------
echo "--- [0] Repository Hygiene ---"
if [[ -d ".git" ]]; then
  ok "是 Git 仓库 (.git 存在)"
else
  fail "不是 Git 仓库 (.git 缺失) — 无法提交到 GitHub"
fi

if command -v git >/dev/null 2>&1; then
  TRACKED_SUSPECT="$(git ls-files 2>/dev/null | grep -E '(^|/)(__pycache__|\.env|.*\.pyc|\.DS_Store|.*\.log)(/|$)' || true)"
  if [[ -z "$TRACKED_SUSPECT" ]]; then
    ok "版本控制文件无 __pycache__/.env/*.pyc/.DS_Store/*.log"
  else
    fail "版本控制中包含不应有的文件:"
    echo "$TRACKED_SUSPECT" | sed 's/^/        /'
  fi
fi

FOUND_TEMP="$(find . -not -path './.git/*' -not -path './node_modules/*' \
  \( -name '*.tmp' -o -name '*.bak' -o -name '*.log' -o -name '.env' -o -name '*.env' \) 2>/dev/null | head -20)"
if [[ -z "$FOUND_TEMP" ]]; then
  ok "工作区无临时/日志/环境文件(.tmp/.bak/.log/.env)"
else
  warn "工作区存在临时/环境文件（若未 gitignore 或不应保留请处理）:"
  echo "$FOUND_TEMP" | sed 's/^/        /'
fi

# ---------- 1. README ----------
echo "--- [1] README ---"
SIZE=0
if [[ -f "README.md" ]]; then
  ok "README.md 位于项目根目录"
  SIZE="$(wc -c < README.md)"
  if [[ "$SIZE" -lt 120 ]]; then
    fail "README.md 过短(<120字节)，几乎没有可执行内容"
  else
    ok "README.md 有实际内容 ($SIZE 字节)"
  fi
else
  fail "缺少 README.md"
fi

# OpenClaw Skill: SKILL.md + README.md 必须同时存在
if [[ "$PROJECT_TYPE" == "openclaw-skill" ]]; then
  echo "--- [1b] OpenClaw Skill 双文档 ---"
  if [[ -f "SKILL.md" ]]; then
    ok "SKILL.md 存在 (面向 Agent)"
  else
    fail "openclaw-skill 缺少 SKILL.md (面向 Agent)"
  fi
  if [[ -f "README.md" ]]; then
    ok "README.md 存在 (面向 GitHub 用户)"
  else
    fail "openclaw-skill 缺少 README.md (面向用户)"
  fi
fi

# ---------- 2. 安装 / 配置 / 使用 / 测试 文档 ----------
echo "--- [2] Documentation Coverage ---"
doc_check() { # $1=项名 $2=关键词 $3=附加关键词(可选)
  local label="$1"; local kw="$2"; local kw2="${3:-}"
  if [[ "$SIZE" -eq 0 ]]; then
    return  # README 不存在已在上方 fail
  fi
  if grep -qiE "$kw" README.md; then
    if [[ -n "$kw2" ]] && ! grep -qiE "$kw2" README.md; then
      warn "$label 章节关键词缺失: $kw2"
    else
      ok "$label 章节存在"
    fi
  else
    warn "$label 章节缺失（关键词: $kw）— 建议补充"
  fi
}
doc_check "安装 (installation)"  "install"            "pip|npm|clone|setup|requirements|package.json"
doc_check "配置 (configuration)" "config"             "env|config|environment|参数"
doc_check "使用 (usage)"         "usage|使用|用法|run|运行|example" ""
doc_check "测试 (testing)"       "test|测试"           ""

# ---------- 3. 依赖 / 构建文件（按类型） ----------
echo "--- [3] Dependency / Build File ---"
case "$PROJECT_TYPE" in
  python)
    if [[ -f "pyproject.toml" || -f "requirements.txt" || -f "setup.py" ]]; then
      ok "Python 依赖文件存在"
    else
      fail "Python 项目缺少 pyproject.toml / requirements.txt / setup.py"
    fi
    ;;
  node)
    if [[ -f "package.json" ]]; then
      ok "node 项目存在 package.json"
    else
      fail "node 项目缺少 package.json"
    fi
    ;;
  docker)
    if [[ -f "Dockerfile" || -f "compose.yaml" || -f "compose.yml" ]]; then
      ok "Docker 构建文件存在"
    else
      fail "docker 项目缺少 Dockerfile / compose 文件"
    fi
    ;;
  openclaw-skill)
    ok "OpenClaw Skill 类型：以 SKILL.md 为运行契约（无需独立构建文件）"
    ;;
  generic)
    ok "generic 类型：不强制依赖文件"
    ;;
esac

# ---------- 4. .gitignore ----------
echo "--- [4] .gitignore ---"
# 按类型选择应覆盖的常见项（避免跨类型误报）
GITIGNORE_PATTERNS="env pyc"
case "$PROJECT_TYPE" in
  node)       GITIGNORE_PATTERNS="$GITIGNORE_PATTERNS node_modules dist build coverage" ;;
  python)     GITIGNORE_PATTERNS="$GITIGNORE_PATTERNS __pycache__ venv .venv pytest_cache" ;;
  docker)     GITIGNORE_PATTERNS="$GITIGNORE_PATTERNS node_modules data" ;;
  generic)    GITIGNORE_PATTERNS="$GITIGNORE_PATTERNS node_modules dist build data" ;;
esac
if [[ -f ".gitignore" ]]; then
  ok ".gitignore 存在"
  for pattern in $GITIGNORE_PATTERNS; do
    if grep -qE "$pattern" .gitignore 2>/dev/null; then
      ok "  .gitignore 覆盖: $pattern"
    else
      warn "  .gitignore 未覆盖常见项: $pattern — 建议补充"
    fi
  done
else
  warn ".gitignore 缺失 — 建议添加"
fi

# ---------- 5. Secrets / API Keys ----------
echo "--- [5] Secrets / API Keys ---"
SCAN_FILES="$(find . -not -path './.git/*' -not -path './node_modules/*' -not -path '*/cache/*' -type f 2>/dev/null)"
SECRET_FOUND=0
for f in $SCAN_FILES; do
  test -f "$f" || continue
  case "$f" in
    .gitignore|package-lock.json|yarn.lock|poetry.lock|scripts/project-readiness-check.sh) continue ;;
  esac
  if grep -qE '(sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|sk_live_[0-9a-z]{20,})' "$f" 2>/dev/null; then
    echo "  [SECRET] 疑似密钥硬编码: $f"
    SECRET_FOUND=1
  fi
done
if [[ "$SECRET_FOUND" -eq 0 ]]; then
  ok "未在文件中发现疑似 API key / 令牌硬编码"
else
  fail "发现疑似密钥硬编码，必须移除或改用环境变量 + .gitignore"
fi

# ---------- 6. 本地绝对路径 ----------
echo "--- [6] Local Absolute Paths ---"
PATHS=0
for f in $SCAN_FILES; do
  test -f "$f" || continue
  case "$f" in
    .gitignore|package-lock.json|yarn.lock|poetry.lock|scripts/project-readiness-check.sh) continue ;;
  esac
  if grep -qE "(/home/[A-Za-z0-9_]+/|C:\\\\Users\\\\)" "$f" 2>/dev/null; then
    echo "  [PATH] 本地绝对路径: $f"
    PATHS=1
  fi
done
if [[ "$PATHS" -eq 0 ]]; then
  ok "未发现硬编码的本地绝对路径 (/home/... 或 C:\\Users\\...)"
else
  warn "发现本地绝对路径 — 若用于文档示例请标注为占位/相对路径"
fi

# ---------- 7. 目录结构 ----------
echo "--- [7] Repository Structure ---"
TOP_LEVEL="$(ls -A 2>/dev/null | grep -vE '^(\.git|\.gitignore|LICENSE|CHANGELOG|__pycache__)$' | head -30)"
if [[ -n "$TOP_LEVEL" ]]; then
  ok "根目录有清晰文件/目录结构"
else
  fail "根目录为空或异常"
fi

# ---------- 8. Quick Start / 测试可执行 ----------
echo "--- [8] Quick Start / Test Executability (deferred) ---"
skip "Quick Start 实际可执行性 — 需 Test & Runtime Validator / Reviewer 实测"
skip "README 之外的隐含知识检查 — 需 Reviewer Stranger User Audit"

# ---------- 汇总 ----------
echo ""
echo "=============================================="
echo " Summary"
echo "=============================================="
echo "  PASS : $PASS_COUNT"
echo "  FAIL : $FAIL"
echo "  WARN : $WARN"
echo "  SKIP : $SKIP (人工验证项)"
if [[ ${#FAIL_MSGS[@]} -gt 0 ]]; then
  echo ""
  echo " 阻断性缺陷 (FAIL):"
  for m in "${FAIL_MSGS[@]}"; do echo "   - $m"; done
fi
if [[ ${#WARN_MSGS[@]} -gt 0 ]]; then
  echo ""
  echo " 非阻断警告 (WARN):"
  for m in "${WARN_MSGS[@]}"; do echo "   - $m"; done
fi
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: PASS (工具层无阻断缺陷；可运行性须 + 下游 Runtime 验证 + Reviewer Audit)"
  exit 0
else
  echo "RESULT: FAIL (存在 $FAIL 个阻断缺陷，修正后重跑)"
  exit 1
fi
