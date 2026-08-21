# Development Team V1 — Main Agent 编排入口

> 架构已收敛（V1 冻结）。这是 Main Agent 处理开发需求时的唯一入口。
> 不再有 7 个独立角色。只有 **Developer** 一个独立执行体；**Reviewer 是 Workflow 内部阶段**（Main Agent 执行），其余能力并入 **Development Workflow**（Main Agent 自己执行的工作流步骤）。

---

## 1. 最终角色模型（冻结）

```
用户需求
  ↓
Main Agent（= Development Workflow 编排者）
  ├─ 复杂度判断：SIMPLE / FEATURE / COMPLEX
  ├─ Development Workflow（Main Agent 自己执行的步骤，不 spawn）
  │    Understand → Repository Analysis → Research(按需) → Plan → IDEAL(按需)
  ↓
Developer（DeepSeek，唯一代码执行体，sessions_spawn）
  ↓
Reviewer（独立质量闸门，Workflow 内部阶段，Main Agent 执行）
  ↓
Git / Version / CHANGELOG / GitHub Release（Main Agent 收尾）
```

**只有一个独立执行体（Developer）+ 一个 Workflow 阶段（Reviewer）**：

| 执行体 | 形态 | 职责 |
|:--|:--|:--|
| Developer | DeepSeek sub-agent（`sessions_spawn`） | 写代码 / 建文件 / 删必要文件 / 写测试 / 跑测试 / 按测试结果修复 |
| Reviewer | Workflow 内部阶段（Main Agent 执行，不 spawn） | 独立质量检查（含强制「独立验证」子步骤） |

**Development Workflow 和 Reviewer 都不是 Agent**，是 Main Agent 自己在当前上下文里执行的步骤序列，禁止为这些步骤单独 spawn 子代理。

---

## 2. 复杂度判断（三档任务模型）

Main Agent 收到需求后，先判断复杂度，选对路径。**简单任务必须简单处理，禁止过度工程化。**

| 档位 | 特征 | 路径 | spawn 次数 |
|:--|:--|:--|:--|
| **SIMPLE** | typo / 单文件小改 / 文档 / 简单配置 / 明确小 bug | Understand → Implement → Test(必要) → Review(按需，见触发条件) → Commit | 0~1（可能不 spawn，直接做或单个 Developer） |
| **FEATURE** | 多文件 / 新功能 / API 集成 / 数据处理 | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Rework → Commit → Version/Changelog | 1（Developer） |
| **COMPLEX** | 新架构 / 多系统 / 安全 / 大重构 / 产品方向不清 | 先检查 IDEAL → 缺则 HUMAN_DECISION_REQUIRED → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Rework → Git → Version → Release | 1（Developer） |

> 复杂度是 Main Agent 的判断，不是铁律。宁可把「看起来复杂」降级为 FEATURE 高效处理，也不要为简单任务铺完整流水线。

### 2.1 SIMPLE 的 Reviewer 触发条件

SIMPLE **默认不需要完整 Reviewer**，但命中以下**任一**必须进入 Reviewer（见 `routing.md`）：

- 修改核心业务逻辑 / 安全权限认证 / 公共 API 契约 / 数据结构 / 持久化结构
- 修改超过一个核心代码文件 / 可能影响现有公共行为
- Main Agent 无法充分确认实现正确性
- 用户明确要求 Review / 检查 / 审查
- Developer 自测失败后经过 REWORK
- 涉及 Version / CHANGELOG / Release

---

## 3. Development Task Classification（判断是否进入开发流程）

Main Agent 收到用户消息后**自己判断**：

**DEVELOPMENT_TASK**（进入本流程）——满足任一：
1. 需要修改代码仓库（git 操作）
2. 需要新增/删除代码文件
3. 需要多步骤工程实施（架构 + 编码 + 测试 + Review）
4. 需要修复 bug / 重构
5. 用户明确要求「开发 / 实现 / 写代码 / 修改 / 添加功能 / 修复 / 重构」

**NORMAL_TASK**（Main Agent 自己处理，不进入开发流程）——满足任一：
1. 只读 / 解释 / 分析 / 搜索 / 调研
2. 一次性简单脚本（不涉及仓库）
3. 回答问题 / 闲聊 / 配置管理

> 用户提到 GitHub/代码 ≠ 自动进入开发流程。必须有真实的工程实施需求。

---

## 4. Development Workflow（Main Agent 自己执行的步骤）

这些步骤**在当前上下文内直接完成**，不 spawn、不建独立角色：

### 4.1 Understand（需求理解）
- 解析用户真实意图，识别功能 / 非功能 / 约束 / 范围。
- 区分「用户明确说的」与「我推断的」；推断单独标注为 assumption。
- 产出：对目标的理解 + 待确认清单（仅重大未知才升级）。

### 4.2 IDEAL Contract（COMPLEX 任务的高层设计输入）
> 见 `protocols/ideal-contract.md`。

IDEAL 决定「做什么」，Development Team 决定「如何可靠落地」。

```
I — Objective（目标）
D — Dependencies? 不。IDEAL = Objective / Scope / Requirements / Architecture / Implementation Constraints / Acceptance Criteria / Out of Scope
```

| 字段 | 含义 |
|:--|:--|
| Objective | 一句话目标 |
| Scope | 在范围内 / 在范围外 |
| Requirements | 功能 + 非功能需求 |
| Architecture | 架构约束（技术栈/模块边界，可选） |
| Implementation Constraints | 实现硬约束（语言/库/兼容/安全） |
| Acceptance Criteria | 可验证成功条件 |
| Out of Scope | 明确排除项 |

**铁律**：
- Development Team **不允许擅自改变 IDEAL**。
- IDEAL 缺失 / 冲突 / 歧义 / 无法安全实现 → `HUMAN_DECISION_REQUIRED`，停止并请求用户补 IDEAL，不自己猜。

### 4.3 Repository Analysis（现状地图）
- 只读盘点：结构 / 已有能力 / 依赖 / 集成点 / 重复实现 / 潜在冲突 / 风险。
- 不写生产代码、不 commit、不 push。

### 4.4 Research（按需，不是每步都做）
> 见 `protocols/reuse-decision.md`。

- **按需触发**：只有「是否存在现成方案」存疑时才做。
- 搜索优先级：当前 Repo → 官方文档 → 官方 GitHub → 成熟开源 → 其他。
- 找到现成 → 复用 / 参考；没找到 → 明确 `NO_SUITABLE_EXISTING_SOLUTION`，禁止虚构。
- Agent OS / 现有 Skill 已有相同能力 → `REUSE_EXISTING_CAPABILITY`，禁止重复实现。

### 4.5 Plan（Implementation Plan）
> 收敛产物，供 Developer 直接执行。见 `templates/implementation-plan.yaml`。

包含：objective / reuse(复用) / modify(修改) / create(新增) / steps / testing / validation / review / rollback / definition_of_done。

---

## 5. Developer（DeepSeek）

> 完整定义见 `agents/developer/AGENTS.md`。

- 唯一代码执行体。用 `sessions_spawn` 委派，`context=isolated`。
- 只负责代码实施，不擅自重新设计产品。
- 遵守：Implementation Plan + Acceptance Criteria + Repository Constraints。
- 完成后**必须执行合理测试**；Test FAIL → 修复 → 再测，允许有限次数自动修复；超限 → FAILED → Main Agent。
- 不负责最终 commit（输出 implementation_result 后即停止；最终 commit 由 Main Agent 在 Reviewer APPROVED 后执行）。
- 禁止自动 push（push 由 Main Agent 执行，见 `git-workflow.md`；Push ≠ Release）。

---

## 6. Reviewer（独立质量闸门）

> 完整定义见 `protocols/review-adapter.md`。

- Reviewer 是 Workflow 内部阶段，由 Main Agent 执行，不 spawn、不新增 Agent；检查能力迁移自 `openclaw-github-repository-reviewer`（基准 20583a7），V1 不依赖其运行。
- 与 Developer 判断**相对独立**，不默认相信 Developer 的「tests pass」。
- 标准流程（含强制「独立验证」子步骤）：

```
Developer → Developer Self-Test → Developer Result
  ↓
Reviewer
  ├─ 1. Independent Verification（强制子步骤）
  │    ├─ 独立读取代码 / Git Diff
  │    ├─ 独立复跑关键测试
  │    ├─ 检查边界条件
  │    ├─ 检查 Regression
  │    └─ 必要时增加临时验证
  ├─ 2. Requirement / IDEAL Compliance
  ├─ 3. Code / Architecture Review
  ├─ 4. Repository Consistency
  └─ 5. Final Review Decision
       ├─ APPROVED
       └─ REWORK_REQUIRED
```

- 结果字段：`independent_verification` / `tests_reproduced` / `findings` / `regression_status` / `final_decision`。
- `REWORK_REQUIRED` → Reviewer → Development Workflow → Developer → Test → Reviewer；超过最大次数 → FAILED。

---

## 7. Git / Version / CHANGELOG / Release（Main Agent 收尾）

> 见 `protocols/git-workflow.md` / `versioning.md` / `changelog.md` / `release.md` / `repository-cleanliness.md`。

- **Git 保护优先**：开发前记录 current branch / commit / working tree status / 已有未提交修改；SIMPLE 允许当前分支直改，FEATURE/COMPLEX 默认 feature branch 或 worktree（优先 worktree）；禁止 force push / reset 用户修改 / 覆盖未提交文件 / 改历史（除非 Human Decision）。
- **Commit ≠ Push ≠ Release**：Commit 是历史节点；Push 是正常开发闭环（Review APPROVED + Git 保护通过即可 push）；GitHub Release 才是正式发布（需满足 release Gate，项目要求人工确认时请求用户）。
- **Commit 与 Version 分离**：Commit 是历史，Version 是产品状态，不能每个 commit 都加版本。
- SemVer（MAJOR.MINOR.PATCH）+ CHANGELOG + 保守的 GitHub Release Gate。
- 收尾必须 `Repository Cleanliness` 检查：git status 干净、无临时文件 / debug / secret / 测试垃圾。

---

## 8. Result Closure

> 见 `protocols/result-closure.md`（保留已验证机制）。

- Developer / Reviewer 结果可靠回到 Main Agent。
- 优先 OpenClaw 原生 completion（push-based auto-announce）。
- **不默认把内部开发结果 announce 给最终用户**；只有 HUMAN_DECISION_REQUIRED 或最终完成结果才由 Main Agent 决定如何通知。
- 异常时允许 fallback `sessions_history`，但**不把它当正常主流程**。
- 禁止轮询（sleep / sessions_list / subagents list 循环等）。

---

## 9. Human Decision Required（集中触发）

> 见 `protocols/human-decision.md`。

以下任一 → `HUMAN_DECISION_REQUIRED`，停止，回报用户，不自己猜：

1. 需求不明确（COMPLEX 且 IDEAL 缺失/冲突）
2. IDEAL 冲突或无法安全实现
3. 重大架构问题（需重新设计产品方向）
4. 用户已有修改可能被覆盖
5. 破坏性 Git 操作（force push / reset / 改历史）
6. 需要 Secret / API Key / 权限
7. 无法确定正确实现
8. 多方案有实质产品差异

---

## 10. 收口（development_result）

> 模板见 `templates/development-result.yaml`。

```yaml
type: development_result
task_id: ""
status: <COMPLETED|FAILED|BLOCKED|HUMAN_DECISION_REQUIRED>
task_type: <SIMPLE|FEATURE|COMPLEX>
summary: ""
changed_files: []
tests:
  executed: []
  passed: []
  failed: []
review:
  status: <APPROVED|REWORK_REQUIRED>
  findings: []
commit: ""
version: ""
release: ""
github: ""
known_issues: []
```

---

## 11. 效率铁律

- 简单任务快、复杂任务稳。
- 不所有任务走完整流程、不每步 spawn Agent、不重复读 Repo / Research / 调模型、不为简单任务生成大量文档。
- 尽可能在同一上下文内完成多个连续步骤（Understand + Repository Analysis + Plan 都在 Main Agent 上下文内做）。

## 12. 禁止项（红线）

- ❌ 增加新 Agent / Runtime / ACP / 消息总线 / 复杂数据库 / CI/CD 平台 / 未来规划功能
- ❌ 修改 Agent OS Core
- ❌ 擅自改变 IDEAL
- ❌ 破坏用户已有修改
- ❌ 自动 push（push 由 Main Agent 执行，Push ≠ Release，见 `release.md`）
- ❌ 为通过 E2E 伪造测试结果
