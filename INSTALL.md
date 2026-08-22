# Installation Guide — Development Team V1

Development Team 是 OpenClaw 上的自动化软件开发流水线。本文档指导你从零完成安装。

---

## 前置条件

### 必需

| 依赖 | 最低版本 | 说明 | 安装方式 |
|:--|:--|:--|:--|
| **OpenClaw** | ≥ 1.x | 运行时环境，需要 `sessions_spawn` / `subagents` / `tools` | [docs.openclaw.ai](https://docs.openclaw.ai) |
| **Git** | ≥ 2.x | 版本控制 + worktree 支持 | `apt install git` / `brew install git` |
| **Bash** | ≥ 4.x | 安装脚本和 Reviewer 辅助脚本 | 系统自带（macOS 需 Homebrew bash） |

### 推荐（完整功能）

| 依赖 | 说明 | 安装方式 |
|:--|:--|:--|
| **DeepSeek API Key** | Developer 模型（deepseek-v4-flash）需要 | [platform.deepseek.com](https://platform.deepseek.com) |
| **gh CLI** | GitHub Release / repo 操作需要 | `apt install gh` / `brew install gh` / [cli.github.com](https://cli.github.com) |
| **Python 3** | E2E 验收脚本需要 | `apt install python3` / 系统自带 |
| **SSH key 或 gh auth** | Git push / GitHub 操作需要 | `ssh-keygen` 或 `gh auth login` |

### 模型要求

- **Developer（唯一 spawn Agent）**：需要 `deepseek/deepseek-v4-flash` 或同等 DeepSeek 模型
- 确保 OpenClaw 已配置 DeepSeek provider（`~/.openclaw/openclaw.json` 中的 `providers`）

---

## 安装

### 方式一：一键安装（推荐）

```bash
# 克隆仓库
git clone https://github.com/BruceTangc/openclaw-development-team.git
cd openclaw-development-team

# 运行安装器
bash install.sh
```

安装器会自动：
1. 运行 **Multi-Agent Installation Context Preflight**（只读、无副作用，验证 OpenClaw 环境与多 Agent discovery 原则）
2. **动态解析** Main Agent workspace 与 shared managed skills 目录（用 `openclaw skills check` 官方 API，不硬编码路径）
3. 将仓库主体复制到 Main Agent workspace 的 `openclaw-development-team/`
4. 将 Skill 安装到 **shared managed skills**（`~/.openclaw/skills/development-team/`，所有本机 agent 可见）
5. 确保脚本可执行
6. 运行 smoke test 验证安装

> **多 Agent 原则**：Development Team 是 **Main Agent / Team-level capability**，默认安装到 shared managed
> skills（所有 agent 可见），**不复制到每个 Developer/Reviewer 的私有 workspace**。

### 方式二：指定 workspace

如果你的 OpenClaw main agent workspace 不在默认位置（或要显式指定安装目标）：

```bash
bash install.sh --workspace /path/to/your/workspace
```

> 显式指定 `--workspace` 时，Skill 将随该 workspace 安装到 `<workspace>/skills/`。

### 方式三：从本地仓库安装

如果你已经 clone 了仓库：

```bash
bash install.sh --repo /path/to/openclaw-development-team
```

### 跳过 Preflight

```bash
bash install.sh --skip-preflight
```

### 幂等性

安装器**支持重复执行**：
- 已存在的文件**不会被覆盖**（跳过并警告）
- 已存在的 Skill **不会被覆盖**
- 安全运行多次不会产生副作用

---

## 验证

安装完成后，安装器会自动运行 smoke test。你也可以手动验证：

```bash
# 以下 <workspace> / <shared-skills> 为占位符：实际值必须以 install.sh 输出为准（动态解析），
# 不要直接复制这些示例路径。典型默认：<workspace>≈~/.openclaw/workspace/<agent-id>，
# <shared-skills>≈~/.openclaw/skills。

# 1. 检查文件结构
ls <workspace>/openclaw-development-team/
# 应包含: AGENTS.md PROTOCOL.md protocols/ scripts/ templates/ agents/ skills/

# 2. 检查 Skill（shared managed skills）
cat <shared-skills>/development-team/SKILL.md
# 应包含: name: development-team

# 3. 检查脚本可执行
ls -la <workspace>/openclaw-development-team/scripts/*.sh
# 应有 x 权限

# 4. 测试 Reviewer 辅助脚本（仓库路径以实际安装为准）
bash <workspace>/openclaw-development-team/scripts/check-hygiene.sh <workspace>
# 应输出: HYGIENE_FOUND=0 (clean)
```

---

## 使用

安装完成后，直接对你的 OpenClaw Agent 说开发需求即可：

```
"帮我给 XXX 仓库新增 YYY 功能"
"修复 ZZZ 的 bug"
"重构 AAA 模块"
```

Agent 会自动：
1. 判断任务复杂度（SIMPLE / FEATURE / COMPLEX）
2. 选择对应路径
3. 调用 Developer（DeepSeek）执行
4. Reviewer 审查
5. Git / Version / CHANGELOG 管理

详见 [README.md](README.md) 了解完整流程。

---

## 依赖配置

### DeepSeek API Key

```bash
# 方式一：环境变量
export DEEPSEEK_API_KEY="sk-..."

# 方式二：OpenClaw 配置（推荐）
# 编辑 ~/.openclaw/openclaw.json，在 providers 中添加 DeepSeek
```

### gh CLI（GitHub 操作）

```bash
# 安装
sudo apt install gh  # Ubuntu/Debian
brew install gh       # macOS

# 认证
gh auth login
```

### Git SSH（推送代码）

```bash
# 生成 SSH key
ssh-keygen -t ed25519 -C "your@email.com"

# 添加到 GitHub
ssh-copy-id -i ~/.ssh/id_ed25519.pub git@github.com

# 测试
ssh -T git@github.com
```

---

## 卸载

```bash
# <workspace> 为安装目标占位符，实际值以 install.sh 输出为准
bash <workspace>/openclaw-development-team/uninstall.sh
```

或指定 workspace：

```bash
bash <workspace>/openclaw-development-team/uninstall.sh --workspace /path/to/your/workspace
```

卸载器会：
- 只删除 Development Team 自己创建的内容
- 不触碰用户已有的 AGENTS.md、SOUL.md、MEMORY.md、skills/ 等文件
- 卸载前要求确认
- 支持 `--dry-run` 预览

详见 [UNINSTALL.md](UNINSTALL.md)。

---

## 故障排除

### Skill 未被 OpenClaw 识别

- 确认 `skills/development-team/SKILL.md` 存在
- 确认文件包含正确的 frontmatter（`name: development-team`）
- 重启 OpenClaw Gateway：`openclaw gateway restart`

### Developer 模型不可用

- 确认 DeepSeek API key 已配置
- 确认 `deepseek/deepseek-v4-flash` 在 OpenClaw 模型列表中
- 测试：`openclaw status` 查看模型配置

### 脚本权限不足

```bash
chmod +x <workspace>/openclaw-development-team/scripts/*.sh
chmod +x <workspace>/openclaw-development-team/scripts/*.py
```

### gh CLI 未认证

```bash
gh auth login
# 按提示完成认证
```

---

## 文件结构（安装后）

> ⚠️ 以下路径为**默认位置示意**，实际路径由 `install.sh` 动态解析（`openclaw skills check` 官方 API），
> 不硬编码。你的 Main Agent workspace 与 shared managed skills 目录可能与下图不同。
> 若你显式指定 `--workspace <path>` / `--main-agent <id>`，以上路径按实际目标变化，以 install.sh 输出为准。

```
<Main Agent workspace>/             # 默认约 ~/.openclaw/workspace/<agent-id>/，以实际解析为准
├── AGENTS.md                       # 你的 Agent 入口（不被覆盖）
├── SOUL.md                         # 你的 Agent 人格（不被覆盖）
├── MEMORY.md                       # 你的长期记忆（不被覆盖）
├── skills/
│   └── development-team/
│       └── SKILL.md                # DT Skill 入口（安装器创建）
└── openclaw-development-team/      # DT 仓库主体（安装器创建）
    ├── AGENTS.md                   # DT 编排入口
    ├── PROTOCOL.md                 # 协议总纲
    ├── IMPLEMENTATION_SPEC.md      # 实现规范
    ├── protocols/                  # 15 个协议文件
    ├── scripts/                    # 辅助脚本
    ├── templates/                  # YAML 模板
    ├── agents/
    │   └── developer/
    │       └── AGENTS.md           # Developer Agent 定义
    └── install.sh / uninstall.sh   # 安装/卸载器
```

> **shared managed skills**（所有本机 agent 可见）：默认 `~/.openclaw/skills/development-team/`（见 §安装方式一）。
