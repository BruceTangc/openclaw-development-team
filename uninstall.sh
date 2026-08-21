#!/usr/bin/env bash
# uninstall.sh — Development Team V1 卸载
# 只删除 Development Team 自己创建的内容，不触碰用户已有文件
# 用法：bash uninstall.sh [--workspace <path>] [--dry-run]
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

WORKSPACE="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)
      echo "用法: bash uninstall.sh [--workspace <path>] [--dry-run]"
      echo "  --workspace  OpenClaw workspace 路径"
      echo "  --dry-run    只显示将删除的内容，不实际删除"
      exit 0 ;;
    *) error "未知参数: $1" ;;
  esac
done

info "=== Development Team V1 卸载 ==="
info "Workspace: $WORKSPACE"
[[ "$DRY_RUN" == "true" ]] && info "(DRY RUN 模式，不实际删除)"

DT_DIR="$WORKSPACE/openclaw-development-team"
SKILL_DIR="$WORKSPACE/skills/development-team"

# ─── 列出将删除的内容 ───
TO_DELETE=()

if [[ -d "$DT_DIR" ]]; then
  TO_DELETE+=("$DT_DIR")
fi

if [[ -d "$SKILL_DIR" ]]; then
  TO_DELETE+=("$SKILL_DIR")
fi

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  info "没有找到 Development Team 安装内容，无需卸载。"
  exit 0
fi

info ""
info "将删除以下内容："
for f in "${TO_DELETE[@]}"; do
  echo "  🗑️  $f"
done

# ─── 安全检查 ───
# 确认 openclaw-development-team/ 是 DT 仓库（有 AGENTS.md + PROTOCOL.md）
if [[ -d "$DT_DIR" ]]; then
  if [[ ! -f "$DT_DIR/AGENTS.md" ]] || [[ ! -f "$DT_DIR/PROTOCOL.md" ]]; then
    error "openclaw-development-team/ 存在但不是 Development Team 仓库（缺少 AGENTS.md 或 PROTOCOL.md），中止卸载"
  fi
fi

# 确认 skills/development-team/SKILL.md 是 DT 的 skill
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
  if ! grep -q "development-team" "$SKILL_DIR/SKILL.md" 2>/dev/null; then
    error "skills/development-team/SKILL.md 不是 Development Team 的 skill，中止卸载"
  fi
fi

# ─── 执行删除 ───
if [[ "$DRY_RUN" == "true" ]]; then
  info ""
  info "DRY RUN 完成，未实际删除。"
  exit 0
fi

echo ""
read -p "确认删除以上内容？(y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  info "已取消。"
  exit 0
fi

for f in "${TO_DELETE[@]}"; do
  info "删除: $f"
  rm -rf "$f"
done

# ─── 清理空的 skills/ 目录（如果删完后变空） ───
if [[ -d "$WORKSPACE/skills" ]]; then
  SKILL_REMAINING=$(find "$WORKSPACE/skills" -name "SKILL.md" 2>/dev/null | wc -l)
  if [[ "$SKILL_REMAINING" -eq 0 ]]; then
    warn "skills/ 目录已空，保留目录（不删除）"
  fi
fi

# ─── 结果 ───
echo ""
info "🎉 卸载完成。Development Team V1 已移除。"
echo ""
echo "  已删除："
for f in "${TO_DELETE[@]}"; do
  echo "    - $f"
done
echo ""
echo "  未触碰：用户已有的 AGENTS.md、SOUL.md、MEMORY.md、skills/ 等文件"
