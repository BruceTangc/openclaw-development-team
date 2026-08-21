#!/usr/bin/env bash
# install.sh — Development Team V1 installer
# 幂等：重复执行安全，不覆盖用户已有文件
# 用法：bash install.sh [--workspace <path>] [--repo <path>]
set -euo pipefail

# ─── 颜色 ───
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── 参数解析 ───
WORKSPACE="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
REPO_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --repo)      REPO_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "用法: bash install.sh [--workspace <path>] [--repo <path>]"
      echo "  --workspace  OpenClaw workspace 路径 (默认: ~/.openclaw/workspace)"
      echo "  --repo       Development Team 仓库路径 (默认: 自动 clone)"
      exit 0 ;;
    *) error "未知参数: $1" ;;
  esac
done

# ─── 预检 ───
info "=== Development Team V1 安装 ==="
info "Workspace: $WORKSPACE"

command -v git  >/dev/null 2>&1 || error "需要 git，请先安装"
command -v bash >/dev/null 2>&1 || error "需要 bash"

# 检查 workspace 是否存在
if [[ ! -d "$WORKSPACE" ]]; then
  info "Workspace 不存在，创建: $WORKSPACE"
  mkdir -p "$WORKSPACE"
fi

# ─── 获取仓库 ───
DT_DIR="$WORKSPACE/openclaw-development-team"
SKILL_DIR="$WORKSPACE/skills/development-team"

if [[ -n "$REPO_DIR" ]]; then
  # 用本地仓库（复制）
  if [[ ! -d "$REPO_DIR" ]]; then
    error "仓库路径不存在: $REPO_DIR"
  fi
  info "从本地仓库安装: $REPO_DIR"
  INSTALL_MODE="copy"
else
  # clone 到临时目录
  INSTALL_MODE="clone"
fi

# ─── 安装核心文件 ───
install_files() {
  local src="$1"

  # 1. 复制仓库主体到 openclaw-development-team/
  if [[ -d "$DT_DIR" ]]; then
    warn "openclaw-development-team/ 已存在，跳过（不覆盖）"
  else
    info "安装仓库主体 → openclaw-development-team/"
    mkdir -p "$DT_DIR"
    # 复制除 .git 外的所有文件
    (cd "$src" && tar --exclude='.git' -cf - .) | tar -xf - -C "$DT_DIR"
  fi

  # 2. 安装 Skill 入口（不覆盖已有）
  mkdir -p "$SKILL_DIR"
  if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
    warn "skills/development-team/SKILL.md 已存在，跳过（不覆盖）"
  else
    info "安装 Skill → skills/development-team/SKILL.md"
    cp "$src/skills/development-team/SKILL.md" "$SKILL_DIR/SKILL.md"
  fi

  # 3. 确保脚本可执行
  if [[ -d "$DT_DIR/scripts" ]]; then
    chmod +x "$DT_DIR/scripts/"*.sh 2>/dev/null || true
    chmod +x "$DT_DIR/scripts/"*.py 2>/dev/null || true
  fi
}

if [[ "$INSTALL_MODE" == "copy" ]]; then
  install_files "$REPO_DIR"
else
  # clone 到临时目录
  TMPDIR_CLONE=$(mktemp -d)
  trap 'rm -rf "$TMPDIR_CLONE"' EXIT
  info "Clone 仓库..."
  git clone --depth 1 https://github.com/BruceTangc/openclaw-development-team.git "$TMPDIR_CLONE/repo" 2>&1 | tail -3
  install_files "$TMPDIR_CLONE/repo"
fi

# ─── Smoke Test ───
info ""
info "=== Smoke Test ==="
PASS=true

# 1. Skill 文件存在
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
  info "✅ Skill 文件存在: $SKILL_DIR/SKILL.md"
else
  error "❌ Skill 文件缺失"
  PASS=false
fi

# 2. AGENTS.md 入口存在
if [[ -f "$DT_DIR/AGENTS.md" ]]; then
  info "✅ AGENTS.md 入口存在: $DT_DIR/AGENTS.md"
else
  error "❌ AGENTS.md 缺失"
  PASS=false
fi

# 3. 协议目录存在
if [[ -d "$DT_DIR/protocols" ]]; then
  PROTOCOL_COUNT=$(ls "$DT_DIR/protocols/"*.md 2>/dev/null | wc -l)
  info "✅ 协议目录存在: $PROTOCOL_COUNT 个协议文件"
else
  error "❌ protocols/ 缺失"
  PASS=false
fi

# 4. 脚本可执行
if [[ -f "$DT_DIR/scripts/check-hygiene.sh" ]] && [[ -x "$DT_DIR/scripts/check-hygiene.sh" ]]; then
  info "✅ 脚本可执行: check-hygiene.sh"
else
  warn "⚠️  脚本不可执行（非致命）"
fi

# 5. Developer Agent 定义存在
if [[ -f "$DT_DIR/agents/developer/AGENTS.md" ]]; then
  info "✅ Developer Agent 定义存在"
else
  warn "⚠️  agents/developer/AGENTS.md 缺失（非致命）"
fi

# 6. 检查无个人绝对路径
if grep -r "/root/\|/home/[^/]*" "$DT_DIR" --include="*.md" --include="*.sh" --include="*.yaml" 2>/dev/null | grep -v "example\|template\|placeholder\|# " | head -5; then
  warn "⚠️  发现潜在个人路径（请检查）"
else
  info "✅ 无个人绝对路径"
fi

# 7. Skill 可被 OpenClaw 发现
if [[ -d "$WORKSPACE/skills" ]]; then
  SKILL_COUNT=$(find "$WORKSPACE/skills" -name "SKILL.md" 2>/dev/null | wc -l)
  info "✅ skills/ 目录存在，共 $SKILL_COUNT 个 skill"
else
  warn "⚠️  skills/ 目录不存在"
fi

# 7b. 项目交付就绪检查脚本存在且可执行
if [[ -f "$DT_DIR/scripts/project-readiness-check.sh" ]] && [[ -x "$DT_DIR/scripts/project-readiness-check.sh" ]]; then
  info "✅ 项目交付就绪检查脚本: project-readiness-check.sh"
else
  warn "⚠️  project-readiness-check.sh 缺失或不可执行（非致命）"
fi

# ─── 结果 ───
echo ""
if [[ "$PASS" == "true" ]]; then
  info "🎉 安装完成！Development Team V1 已就绪。"
  echo ""
  echo "  文件位置: $DT_DIR"
  echo "  Skill:    $SKILL_DIR/SKILL.md"
  echo ""
  echo "  下一步:"
  echo "    1. 确保 DeepSeek API key 已配置（Developer 模型需要）"
  echo "    2. 确保 gh CLI 已安装并认证（GitHub Release 需要）"
  echo "    3. 对 Agent 说「开发 XXX 功能」即可触发 Development Team 流程"
  echo ""
  echo "  卸载: bash $DT_DIR/uninstall.sh --workspace $WORKSPACE"
else
  error "安装失败，请检查上方错误信息"
fi
