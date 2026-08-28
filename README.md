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

> 详细安装说明见 [INSTALL.md](INSTALL.md)，卸载见 [UNINSTALL.md](UNINSTALL.md)，
> **日常使用/决策速查见 [USAGE.md](USAGE.md)**（三档怎么选 / 何时 Review / 失败恢复 / 常用脚本）。

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
Developer（DeepSeek，独立 subagent）
  ↓
Reviewer（独立 subagent，只读质量闸门）
  ↓
Git / Version / Changelog / GitHub Release
```

**两个独立执行体（Developer + Reviewer）**：

- **Developer**：DeepSeek 编码，唯一代码执行 sub-agent。
- **Reviewer**：独立质量闸门 subagent（`sessions_spawn` 创建，独立 context、只读、不 commit/push），不是 Workflow 内部阶段、不由 Main Agent 自己执行。

Requirement / Research / Repository Analysis / Architect / Validator 不再是独立角色，全部收敛为 Development Workflow 内部步骤或能力。

---

## 三档任务模型

| 档位 | 路径 | 说明 |
|:--|:--|:--|
| SIMPLE | Understand → Implement → Test → Review(按需) → Readiness Check → Commit | 单文件小改、typo、文档 |
| FEATURE | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Readiness Check → Commit → Version/Changelog | 新功能、多文件 |
| COMPLEX | 检查 IDEAL → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Git → Readiness Check → Version → Release | 新架构、多系统、安全 |

> **项目交付标准**：任何可独立运行的项目（新仓库/对外发布），Developer 提交前必须跑
> `scripts/project-readiness-check.sh` 并通过；Developer 只能宣布 `IMPLEMENTATION COMPLETE`，
> `PROJECT COMPLETE` 由 Reviewer + Lead 判定。详见 `docs/PROJECT-DELIVERY-STANDARD.md`。

---

## 仓库结构

```
AGENTS.md                        # Main Agent 编排入口（角色模型 + 复杂度判断 + 流程）
PROTOCOL.md                      # 协议总纲
IMPLEMENTATION_SPEC.md           # 实现规范 + E2E 验收清单（CASE 1-10，参考）
agents/
  developer/AGENTS.md            # Developer（DeepSeek）唯一代码执行体
  reviewer/AGENTS.md             # Reviewer（独立 subagent，只读质量闸门）
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
scripts/
  project-readiness-check.sh     # 项目交付就绪检查（提交大门，见 docs/PROJECT-DELIVERY-STANDARD.md）
  # 其余 V1 辅助验收/断言脚本（Git/Version/Changelog/Release/Protection）
docs/
  PROJECT-DELIVERY-STANDARD.md   # 项目级 Definition of Done（代码完成≠项目完成）
templates/
  project/                       # 交付项目模板：generic / python / node / openclaw-skill / docker
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
  ├─ 5. Repository Review（含 5a GitHub Hygiene、5b Stranger User Audit，项目交付时强制）
  └─ 6. Release Readiness
  ↓
final_decision: APPROVED | REWORK_REQUIRED
```

这样既不重新膨胀成多个 Agent，又不因砍掉 Validator 而降低质量。

> Reviewer 的完整 6 步冻结顺序与字段定义见 `protocols/review-adapter.md`。
> 项目交付时 Reviewer 还必须执行 **Stranger User Audit**（clone 到干净目录、严格按 README 复现
> 安装/配置/Quick Start/运行/测试）与 **GitHub Hygiene Review**，见 `docs/PROJECT-DELIVERY-STANDARD.md` §6-§7。

---

## 验收标准

V1 已完成**最小验收**：4 个真实测试（SIMPLE / FEATURE / FAIL→REWORK→PASS / RESULT CLOSURE）+ 6 项实现级检查（Git protection / Version / CHANGELOG / Release Gate / Cleanliness / IDEAL+HUMAN_DECISION），全部 PASS。

CASE 1-10 是能力覆盖参考清单（见 `IMPLEMENTATION_SPEC.md`），**不要求重做 10-Case 自动化 E2E**。

真实验收证据见 `E2E_REPORT.md` / `V1_ACCEPTANCE_REPORT.md`。

---

## 日常维护 & 运行时工具（P0 增量，纯旁路不改核心流程）

以下脚本为**可观测性/维护增强**，不进入三档核心流水线；Main Agent / Orchestrator 按需调用，
与 Agent OS 的 Fast/Full Path、Execution Record、task-manager 状态机对齐。**均为纯增量、可逆，不改变任何现有协议**。

### 结构化运行日志（append-runtime-log.sh）

每次 `spawn` / `decision` / `review` / `commit` 时向 `.runtime/manifest.jsonl`（已 gitignore，不入库）追加一行 JSONL：
`ts/task_id/stage/status/decision/review_status/commit/elapsed/model/tokens/evidence/note`。

```bash
scripts/append-runtime-log.sh <repo> --task DT-XXXX --stage spawn --status RUNNING --model deepseek/deepseek-v4-flash
scripts/append-runtime-log.sh <repo> --task DT-XXXX --stage review --review-status REWORK_REQUIRED --elapsed 8
scripts/append-runtime-log.sh <repo> --task DT-XXXX --stage commit --commit <hash> --elapsed 3 --tokens 1200
```

### 失败复盘（recent-failures.sh）

```bash
scripts/recent-failures.sh <repo> [N]     # 默认最近 10 条；过滤 status∈{FAILED,RUNTIME_FAILED} / decision=ESCALATE / review in {FAILED,BLOCKED}
```

### 成本/耗时汇总（cost-report.sh）

```bash
scripts/cost-report.sh <repo>              # 全部
DT_TIMEFRAME=24h scripts/cost-report.sh <repo>   # 最近 24 小时
```

### 断点续跑「continue <task_id>」（resume-task.sh）

中途失败/超时/断电后，恢复上次任务：读 `.tasks/<task_id>/development-task.yaml` 的 `status` 字段
（`NEW→DELEGATED→RUNNING→RUNTIME_COMPLETED→APPROVED`）与该任务已落盘的 plan/result/review artifact，输出续跑指针。

```bash
scripts/resume-task.sh <repo> DT-XXXX        # 查看续跑指针（只读，不自动 spawn）
# 恢复命令（Main Agent 语义）：continue <task_id>
```

```
continue DT-20260821-001
```

> 恢复 = `resume-task.sh`（看状态/下一步）→ 按需重新 spawn Developer/Reviewer → 续跑完成后
> 用 `append-runtime-log.sh --stage resume` 记录一次断点续跑。真正执行由 Main Agent/Orchestrator 依输出决定。

### .tasks/ 归档（archive-tasks.sh）

把「已关闭（status∈{APPROVED,IMPLEMENTATION_VERIFIED,PROJECT_READY,COMPLETED,CLOSED}）且关闭超 N 天」的任务
从 `.tasks/` 移到 `.tasks.archived/<task_id>` 并从 git index 清出（保留副本，便于追溯）：

```bash
scripts/archive-tasks.sh <repo> [天数]       # 默认 30 天
```

- **保留周期**：`archive-tasks.sh` 只把**超期已关闭**任务移入 `.tasks.archived/`（非当前活跃证据）；
  当前 `.tasks/` 仍按 `artifact-persistence.md` 纳入版本控制。
- `.tasks.archived/` 默认**不 gitignore**（建议随仓库保留一个归档周期供追溯），可自主清理最旧的归档。

### 模型可配置（$DEVELOPER_MODEL）

Developer 是抽象能力 `developer`（非具体模型）。默认实现为 `deepseek/deepseek-v4-flash`；若需切换模型，
可通过环境变量覆盖（详见 [INSTALL.md](INSTALL.md)「模型切换」）：

```bash
DEVELOPER_MODEL=other/provider-xyz scripts/... # 或按 INSTALL.md 在部署层引入
```

---

## 安装与卸载

- **安装**：`bash install.sh`（详见 [INSTALL.md](INSTALL.md)）
- **卸载**：`bash uninstall.sh`（详见 [UNINSTALL.md](UNINSTALL.md)）
- 安装器幂等，可重复执行；卸载器只删除 DT 自己创建的内容
