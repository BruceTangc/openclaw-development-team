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
IMPLEMENTATION_SPEC.md           # 实现规范 + E2E 验收清单（CASE 1-10）
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
scripts/                         # E2E 脚本（CASE 1-10）
.tasks/                          # 工程 Artifact 持久化
```

---

## Reviewer 的独立验证子步骤（关键设计）

Validator 角色已取消，但「独立验证能力」保留，作为 Reviewer 的**强制子步骤**：

```
Reviewer
  ├─ 1. Independent Verification（独立读代码/Git Diff、独立复跑测试、查边界、查 Regression）
  ├─ 2. Requirement / IDEAL Compliance
  ├─ 3. Code / Architecture Review
  ├─ 4. Repository Consistency
  └─ 5. Final Review Decision → APPROVED / REWORK_REQUIRED
```

这样既不重新膨胀成多个 Agent，又不因砍掉 Validator 而降低质量。

---

## 验收标准

V1 完成需真实 E2E 验证至少 10 个 Case（每个 Case 必须有真实证据，不能只写文档）：

- CASE 1: SIMPLE TASK
- CASE 2: FEATURE TASK
- CASE 3: COMPLEX TASK + IDEAL
- CASE 4: Developer FAIL → REWORK → PASS
- CASE 5: Reviewer FAIL → REWORK → PASS
- CASE 6: Result Closure
- CASE 7: Git / Version / Changelog
- CASE 8: GitHub Release
- CASE 9: 已有用户修改不能被覆盖
- CASE 10: 真实 dlt-simulator

详见 `IMPLEMENTATION_SPEC.md`。
