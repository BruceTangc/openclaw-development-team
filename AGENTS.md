# Development Team V1 — Main Agent 编排入口

> Multi-Agent 收口。Main Agent 是 **Orchestrator**（不执行 Reviewer logic），
> Developer 与 Reviewer 都是独立 subagent（sessions_spawn）。

## 1. 角色模型（Multi-Agent 收口）

```
用户需求
  ↓
Main Agent（= Orchestrator：调度 Developer / Reviewer，不亲自 Review）
  ├─ 复杂度判断：SIMPLE / FEATURE / COMPLEX
  ├─ Development Workflow（Main Agent 编排步骤：需求/分析/Plan/调度）
  ↓
Developer（独立 subagent，capability=developer，sessions_spawn）
  ├─ 改代码 / 写测试 / 跑测试
  ↓
Reviewer（独立 subagent，capability=reviewer，sessions_spawn）
  ├─ 独立 context，只读，验证 Developer artifact
  ↓
structured review result（APPROVED / REWORK_REQUIRED / BLOCKED）
  ↓
Git / Version / CHANGELOG / GitHub Release（Main Agent 收尾）
```

- **Developer**：独立 subagent，抽象能力 `developer`（非具体模型），默认 runtime=openclaw / implementation=native_subagent / model=deepseek/deepseek-v4-flash（仅默认实现）。完整定义见 `agents/developer/AGENTS.md`。
- **Reviewer**：独立 subagent，抽象能力 `reviewer`，通过 OpenClaw 原生 `sessions_spawn` 创建，独立 context、不继承 Developer 完整对话、只读、不 commit/push。完整定义见 `agents/reviewer/AGENTS.md` + `protocols/review-adapter.md`。
- **Main Agent 是 Orchestrator**：接收需求 → 启动 workflow → `sessions_spawn` 调度 Developer / Reviewer → 接收结构化结果 → 决定 transition → 向用户汇报。**Main Agent 永远不执行 Reviewer logic。**
- **Review 进入规则**：只有「需要 Review」的任务才 spawn Reviewer；一旦进入 Review，必须由 Reviewer subagent 执行，不得出现「Main Agent 快查 → APPROVED」的例外。
  - SIMPLE + 不需要 Review → 不 spawn Reviewer
  - SIMPLE + 需要 Review / FEATURE / COMPLEX → spawn Reviewer

## 2. 复杂度判断（三档任务模型）

| 档位 | 特征 | 路径 | spawn |
|:--|:--|:--|:--|
| **SIMPLE** | typo / 单文件小改 / 文档 / 简单配置 / 明确小 bug | Understand → Implement → Test(必要) → Review(按需) → Commit | 0~1 |
| **FEATURE** | 多文件 / 新功能 / API 集成 / 数据处理 | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Rework → Commit → Version/Changelog | 1（Developer） |
| **COMPLEX** | 新架构 / 多系统 / 安全 / 大重构 / 产品方向不清 | 先检查 IDEAL → 缺则 HUMAN_DECISION_REQUIRED → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Rework → Git → Version → Release | 1（Developer） |

- 简单任务必须简单处理，禁止过度工程化。宁可降级为 FEATURE，不为简单任务铺完整流水线。
- SIMPLE 命中以下**任一**必须进入 Reviewer（详见 `routing.md`）：核心业务/安全/公共 API/数据结构/多核心文件/无法自证正确/用户要求 Review/REWORK 过/涉及 Version。

## 3. Task Classification（是否进入开发流程）

- **DEVELOPMENT_TASK**：改仓库（git）、增删代码文件、多步工程实施、修 bug/重构、用户明确要求「开发/实现/写代码」。
- **NORMAL_TASK**（不进流程）：只读/解释/分析/搜索、一次性简单脚本、问答/闲聊/配置管理。
- 用户提到 GitHub/代码 ≠ 自动进入流程；必须有真实工程实施需求。

## 4. Development Workflow（Main Agent 上下文内执行）

Understand（需求理解）→ IDEAL（仅 COMPLEX，见 `ideal-contract.md`）→ Repository Analysis（只读盘点）→ Research（按需，见 `reuse-decision.md`）→ Plan（见 `templates/implementation-plan.yaml`）。

- **IDEAL 铁律**：DT 不允许擅自改变 IDEAL；缺失/冲突/无法安全实现 → `HUMAN_DECISION_REQUIRED`，不自己猜。
- **复用优先**：Agent OS / 现有 Skill 已有相同能力 → `REUSE_EXISTING_CAPABILITY`，禁止重复实现。

## 5. Developer（capability=developer）

见 `agents/developer/AGENTS.md`。要点：
- 唯一代码执行体，`sessions_spawn` + `context=isolated`，只按 Plan 的 modify/create 范围实施。
- 完成必须跑测试；FAIL→修复→再测（≤3 次）；超限→FAILED。不负责最终 commit；禁止自动 push。
- **只能宣布 `IMPLEMENTATION COMPLETE`（自述边界），不得宣布 `PROJECT COMPLETE`**。

## 6. Reviewer（独立 Subagent）

见 `agents/reviewer/AGENTS.md` + `protocols/review-adapter.md`。要点：
- **独立 subagent**（`sessions_spawn` 创建，独立 context），不是 Workflow 内部阶段；与 Developer 判断**相对独立**，不默认相信「tests pass」。
- 只基于事实输入（Requirement/Acceptance/Actual Diff/Repo State/Test Results/Execution Evidence/Developer Artifact）判定；不把 Developer/Main Agent 自评当 evidence。
- 输出 `review.status: approved | rework_required | blocked` + findings + verification + decision rationale（禁止 LGTM/Approved 单独作为 evidence，见 `templates/review-result.yaml`）。
- 需 Review 才 spawn Reviewer（Main Agent 不代审）；一旦进入 Review 必须由 Reviewer subagent 执行。

## 7. Git / Version / Release（Main Agent 收尾）

见 `git-workflow.md` / `versioning.md` / `changelog.md` / `release.md`。要点：
- **Git 保护优先**：开发前记录 baseline；禁止 force push / reset / checkout 覆盖 / 改历史（除非 Human Decision）。
- **Commit ≠ Push ≠ Release**：Commit 是历史；Push 是正常闭环（Review APPROVED + Git 保护通过）；Release 才是正式发布（需 release Gate）。

## 8. Result Closure

见 `result-closure.md`。要点：
- 优先 OpenClaw 原生 completion（push-based auto-announce）；**禁止轮询**。
- **completion ≠ task success**：`sessions_spawn completed` 只表示「子会话运行结束」；只有 artifact + verification + review 全过才 `IMPLEMENTATION_VERIFIED` → `PROJECT_READY`。
- 不默认把内部结果 announce 给最终用户。

## 9. Human Decision Required（集中触发）

见 `human-decision.md`。以下任一 → 停止，回报用户，不自己猜：
1. 需求不明确（COMPLEX 且 IDEAL 缺失/冲突）2. IDEAL 冲突或无法安全实现 3. 重大架构问题 4. 用户已有修改可能被覆盖 5. 破坏性 Git 操作 6. 需要 Secret/API Key/权限 7. 无法确定正确实现 8. 多方案有实质产品差异。

## 10. 收口（development_result）

模板见 `templates/development-result.yaml`（status / task_type / changed_files / tests / review / commit / version / release / known_issues）。

## 11. 禁止项（红线）

- ❌ 增加新 Agent / Runtime / ACP / 消息总线 / 复杂数据库 / CI/CD 平台 / 未来规划功能
- ❌ 修改 Agent OS Core
- ❌ 擅自改变 IDEAL
- ❌ 破坏用户已有修改
- ❌ 自动 push（push 由 Main Agent 执行，Push ≠ Release）
- ❌ 为通过 E2E 伪造测试结果
