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
NA=0
FAIL_MSGS=()
WARN_MSGS=()

ok()   { PASS_COUNT=$((PASS_COUNT+1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL+1)); FAIL_MSGS+=("$1"); echo "  [FAIL] $1"; }
warn() { WARN=$((WARN+1)); WARN_MSGS+=("(warn) $1"); echo "  [WARN] $1"; }
skip() { SKIP=$((SKIP+1)); echo "  [SKIP] $1 (需人工验证)"; }

# NOT_APPLICABLE：明确不适用的检查项（不计 FAIL，也不冒充通过）
na()   { NA=$((NA+1)); echo "  [N/A ] $1"; }

# 检测 README 是否包含「可执行的安装/运行命令」
# 命中： bash/python/node/docker 常见命令前缀 + 命令行提示符($或#) 或 markdown 代码块中的命令
has_cli_cmd() { # $1=关键词（命令/工具名） $2=额外命令词缀（可选）
  local kw="$1"; local extra="${2:-}"
  if [[ "$SIZE" -eq 0 ]]; then return 1; fi
  # 1) 代码块中或行首含命令提示符的命令行
  if grep -qiE "[\$#>][[:space:]]*($kw|${extra})" README.md; then return 0; fi
  # 2) markdown 围栏代码块中的命令（bash/shell/console 块）
  if grep -qiE "^\`\`\`(bash|sh|shell|console|python|yaml)?[[:space:]]*$" README.md \
     && grep -qiE "^[[:space:]]*($kw|\$[[:space:]]*$kw|pip[[:space:]].*$kw|npm[[:space:]].*$kw|git[[:space:]].*$kw)" README.md; then return 0; fi
  return 1
}

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
# 设计：必要项缺失 → FAIL（与 PROJECT-DELIVERY-STANDARD 的「缺必要步骤 = REJECT」对齐）；
#      明确不适用项 → N/A（不计 FAIL）；尽量验证 README 含「实际可执行命令」而非仅关键词。
echo "--- [2] Documentation Coverage ---"
if [[ "$SIZE" -eq 0 ]]; then
  # README 不存在已在上方 fail，这里不再重复判定
  echo "  [SKIP] README 不存在，文档覆盖检查跳过 (已在 [1] fail)"
  SKIP=$((SKIP+1))
else
  # 2.1 安装（installation）— 所有可运行项目必要
  case "$PROJECT_TYPE" in
    generic|python|node|docker|openclaw-skill)
      if grep -qiE "(^|### )?(installation|安装)" README.md || grep -qE "[\$[:space:]]*(git clone|pip install|npm (install|ci)|docker (build|compose))" README.md; then
        # 含安装章节/关键词：再验证是否有可执行命令（$提示符 或 代码块裸命令）
        if grep -qE "^[[:space:]]*\$[[:space:]]+(git clone|pip install|npm (install|ci)|uv |python -m venv|poetry )" README.md \
           || grep -qE "^[[:space:]]*(git clone|pip install|npm (install|ci)|uv |python -m venv|poetry )" README.md \
           || grep -qiE "(^|#)?[[:space:]]*(clone|install)[[:space:]]" README.md; then
          ok "安装说明存在且含可执行命令"
        else
          # 有安装章节关键词但无实际命令
          if grep -qiE "installation|安装" README.md; then
            fail "安装章节存在但未给出可执行的安装命令（如 git clone / pip install / npm install）"
          else
            fail "缺少 installation 说明（含安装命令）"
          fi
        fi
      else
        fail "缺少 installation 说明（安装关键词+命令）"
      fi
      ;;
    *) na "安装检查不适用 (type=$PROJECT_TYPE)" ;;
  esac

  # 2.2 配置（configuration）— 仅当项目有配置需求时必要；否则 N/A
  if grep -qiE "(^|### )?(configuration|配置|environment|env|环境变量)" README.md \
     || grep -qiE "ENV[[:space:]]|[[:space:]]--[a-z-]+[[:space:]]*[=<]" README.md \
     || grep -qE "\.env|settings|config\." README.md; then
    if grep -qiE "(^|### )?(configuration|配置)" README.md \
       || grep -qiE "[[:space:]](--[a-z-]+|ENV[[:space:]]|\$.+)" README.md; then
      ok "配置说明存在"
    else
      fail "README 提及配置需求（env/参数），但缺少 configuration 说明"
    fi
  else
    na "配置检查不适用（README 无配置需求迹象）"
  fi

  # 2.3 使用（usage）— 所有可运行项目必要，且应含可执行运行命令
  case "$PROJECT_TYPE" in
    generic|python|node|docker|openclaw-skill)
      if grep -qiE "(^|### )?(usage|使用|用法|example|examples|运行|Example)" README.md; then
        # 验证是否有实际运行命令
        run_kw="$PROJECT_TYPE"
        if [[ "$PROJECT_TYPE" == "python" ]]; then run_kw="python|pytest"; fi
        if [[ "$PROJECT_TYPE" == "node" ]];   then run_kw="npm|node|yarn"; fi
        if [[ "$PROJECT_TYPE" == "docker" ]]; then run_kw="docker"; fi
        if [[ "$PROJECT_TYPE" == "openclaw-skill" ]]; then run_kw="openclaw|agent|SKILL|skill"; fi
        if [[ "$PROJECT_TYPE" == "generic" ]]; then run_kw="run|./|bash|sh|start|example"; fi
        # 判定运行命令：带 $ 提示符 / 代码块中的纯命令行 / 示例关键词
        if grep -qE "^[[:space:]]*\$[[:space:]]+($run_kw)" README.md \
           || grep -qE "^[[:space:]]*($run_kw)([[:space:]-].*|$)" README.md \
           || grep -qiE "example|示例" README.md; then
          ok "使用说明存在且含可执行命令/示例"
        else
          fail "使用说明存在但缺少可执行的运行命令/示例"
        fi
      else
        fail "缺少 useage/example（使用说明）"
      fi
      ;;
    *) na "使用检查不适用 (type=$PROJECT_TYPE)" ;;
  esac

  # 2.4 测试（testing）— 仅当项目包含测试（文件/依赖/脚本）时必要；否则 N/A
  has_tests=0
  case "$PROJECT_TYPE" in
    python) [[ -d tests || -f test_*.py || -f tests.py || -d test ]] && has_tests=1 ;;
    node)   [[ -d test || -d tests || -f *.test.js || -f *.spec.js ]] && has_tests=1 ;;
    generic|docker|openclaw-skill)
      # 松散检查：存在 test* 目录/文件视为有测试
      [[ -n "$(find . -maxdepth 2 -iname 'test*' 2>/dev/null | head -1)" ]] && has_tests=1 ;;
  esac
  if [[ "$has_tests" -eq 1 ]]; then
    if grep -qiE "(^|### )?(testing|test|测试)" README.md && grep -qiE "\$[[:space:]]*(pytest|npm test|npm run test|python -m |test|make test)" README.md; then
      ok "测试说明存在且含可执行测试命令"
    elif grep -qiE "(^|### )?(testing|test|测试)" README.md; then
      fail "仓库含测试文件，但 README 未给出可执行的测试命令"
    else
      fail "仓库含测试文件，但缺少 testing 说明"
    fi
  else
    na "测试检查不适用（未发现测试文件）"
  fi
fi

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
echo "  N/A  : $NA (明确不适用)"
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
