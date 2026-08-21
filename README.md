# OpenClaw Development Team V1

**OpenClaw 上的自动化软件开发流水线。**

用户提出开发需求后，OpenClaw 根据任务复杂度选择合适的开发路径，自主完成：

```
需求理解 → Repository 分析 → 必要时 Research → Implementation Plan
  → DeepSeek 编码 → 测试 → Review → Rework
  → Git 管理 → Version → Changelog → GitHub Release
```

最终得到一个「代码正确、测试通过、Review 通过、Git 历史清晰、版本明确、GitHub 仓库干净、可以继续迭代」的成品。

---

## Quick Start（3 步安装）

```bash
# 1. 克隆仓库
git clone https://github.com/BruceTangc/openclaw-development-team.git
cd openclaw-development-team

# 2. 运行安装器（幂等，可重复执行）
bash install.sh

# 3. 开始使用 — 对 Agent 说开发需求即可
# "帮我给 XXX 仓库新增 YYY 功能"
```

> 详细安装说明见 [INSTALL.md](INSTALL.md)，卸载见 [UNINSTALL.md](UNINSTALL.md)。

---

## 依赖

### 必需

| 依赖 | 最低版本 | 说明 |
|:--|:--|:--|
| **OpenClaw** | ≥ 1.x | 运行时环境（sessions_spawn / subagents / tools） |
| **Git** | ≥ 2.x | 版本控制 + worktree 支持 |
| **Bash** | ≥ 4.x | 安装脚本和 Reviewer 辅助脚本 |

### 推荐（完整功能）

| 依赖 | 说明 |
|:--|:--|
| **DeepSeek API Key** | Developer 模型（deepseek-v4-flash）需要 |
| **gh CLI** | GitHub Release / repo 操作需要 |
| **Python 3** | E2E 验收脚本需要 |
| **SSH key 或 gh auth** | Git push / GitHub 操作需要 |

详见 [INSTALL.md](INSTALL.md) 的依赖配置章节。

---

## 定位与原则

**IDEAL 决定「做什么」，Development Team 决定「如何可靠落地」。**

核心原则：

1. 简单任务必须简单处理
2. 复杂任务才走完整流程
3. 不为了流程增加 Agent
4. 不为了自主性让 Agent 猜测用户意图
5. DeepSeek 负责代码实施，Reviewer 负责独立质量检查
6. Git/GitHub 管理标准、保守、可追溯
7. 不破坏用户已有修改
8. 不擅自改变 IDEAL
9. 流程高效，避免不必要的 sessions_spawn

---

## 角色模型（V1 收敛）

```
Main Agent
  ↓
Development Workflow（Main Agent 自己的步骤，不 spawn）
  ↓
Developer（DeepSeek）
  ↓
Reviewer（独立质量闸门）
  ↓
Git / Version / Changelog / GitHub Release
```

**只有一个独立执行体（Developer）+ 一个 Workflow 阶段（Reviewer）**：

- **Developer**：DeepSeek 编码，唯一 sub-agent。
- **Reviewer**：独立质量闸门，但它是 Development Workflow 内部阶段（Main Agent 自己执行，不 spawn）。

Requirement / Research / Repository Analysis / Architect / Validator 不再是独立角色，全部收敛为 Development Workflow 内部步骤或能力。

---

## 三档任务模型

| 档位 | 路径 | 说明 |
|:--|:--|:--|
| SIMPLE | Understand → Implement → Test → Review(按需) → Commit | 单文件小改、typo、文档 |
| FEATURE | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Commit → Version/Changelog | 新功能、多文件 |
| COMPLEX | 检查 IDEAL → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Git → Version → Release | 新架构、多系统、安全 |

---

## 仓库结构

```
AGENTS.md                        # Main Agent 编排入口（角色模型 + 复杂度判断 + 流程）
PROTOCOL.md                      # 协议总纲
IMPLEMENTATION_SPEC.md           # 实现规范 + E2E 验收清单（CASE 1-10，参考）
agents/
  developer/AGENTS.md            # Developer（DeepSeek）唯一代码执行体
protocols/
  result-closure.md              # 结果闭环（P0，保留已验证机制）
  ideal-contract.md              # IDEAL 高层设计输入
  routing.md                     # 复杂度判断 + 三档路由
  task.md                        # Development Task 契约
  delegation.md                  # Delegation 契约
  agents/developer/AGENTS.md    # Developer 执行契约（DeepSeek）
  review-adapter.md              # Reviewer 独立质量闸门（含独立验证子步骤）
  rework-loop.md                 # Rework 循环
  reuse-decision.md              # Research / 复用决策
  artifact-persistence.md        # Artifact 持久化
  git-workflow.md                # Git 保护（本次重点）
  versioning.md                  # SemVer
  changelog.md                   # CHANGELOG
  release.md                     # GitHub Release Gate
  repository-cleanliness.md      # 仓库整洁检查
  human-decision.md              # Human Decision 触发条件
  main-agent-integration.md      # Production Integration
templates/                       # 收敛后的 YAML 模板
scripts/                         # V1 辅助验收/断言脚本（Git/Version/Changelog/Release/Protection）
.tasks/                          # 工程 Artifact 持久化
```

---

## Reviewer 的独立验证子步骤（关键设计）

Validator 角色已取消，但「独立验证能力」保留，作为 Reviewer 的**强制子步骤**：

```
Reviewer
  ├─ 1. Independent Verification（强制子步骤：独立读代码/Git Diff、独立复跑测试、查边界、查 Regression）
  ├─ 2. Requirement / IDEAL Compliance
  ├─ 3. Code Review
  ├─ 4. Security
  ├─ 5. Repository Review
  └─ 6. Release Readiness
  ↓
final_decision: APPROVED | REWORK_REQUIRED
```

这样既不重新膨胀成多个 Agent，又不因砍掉 Validator 而降低质量。

> Reviewer 的完整 6 步冻结顺序与字段定义见 `protocols/review-adapter.md`。

---

## 验收标准

V1 已完成**最小验收**：4 个真实测试（SIMPLE / FEATURE / FAIL→REWORK→PASS / RESULT CLOSURE）+ 6 项实现级检查（Git protection / Version / CHANGELOG / Release Gate / Cleanliness / IDEAL+HUMAN_DECISION），全部 PASS。

CASE 1-10 是能力覆盖参考清单（见 `IMPLEMENTATION_SPEC.md`），**不要求重做 10-Case 自动化 E2E**。

真实验收证据见 `E2E_REPORT.md` / `V1_ACCEPTANCE_REPORT.md`。

---

## 安装与卸载

- **安装**：`bash install.sh`（详见 [INSTALL.md](INSTALL.md)）
- **卸载**：`bash uninstall.sh`（详见 [UNINSTALL.md](UNINSTALL.md)）
- 安装器幂等，可重复执行；卸载器只删除 DT 自己创建的内容
