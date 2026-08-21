# IMPLEMENTATION_SPEC.md — Development Team V1 实现规范

> 架构已收敛。本文定义 V1 的实现规范 + E2E 验收清单。

---

## 1. 角色模型

```
Main Agent（= Development Workflow 编排者）
  ↓
Development Workflow（Main Agent 自己的步骤，不 spawn）
  Understand → Repository Analysis → Research(按需) → Plan → IDEAL(按需)
  ↓
Developer（DeepSeek，sessions_spawn）
  ↓
Reviewer（Workflow 内部阶段，Main Agent 执行）
  ↓
Git / Version / CHANGELOG / GitHub Release（Main Agent 收尾）
```

**只有一个独立执行体（Developer）+ 一个 Workflow 阶段（Reviewer）**。

---

## 2. Development Workflow 步骤（Main Agent 自己执行）

### 2.1 Understand
解析用户真实意图 → 识别功能/非功能/约束/范围 → 区分 fact 与 assumption → 产出待确认清单（仅重大未知升级）。

### 2.2 IDEAL Contract（COMPLEX 必查）
> 详见 `protocols/ideal-contract.md` + `templates/ideal-contract.yaml`。

IDEAL = Objective / Scope / Requirements / Architecture / Implementation Constraints / Acceptance Criteria / Out of Scope。

Development Team **不允许擅自改变 IDEAL**。缺失/冲突/歧义/无法安全实现 → HUMAN_DECISION_REQUIRED。

### 2.3 Repository Analysis
只读盘点现状（结构/能力/依赖/集成点/重复/冲突/风险）。

### 2.4 Research（按需）
> 详见 `protocols/reuse-decision.md`。

只有「是否存在现成方案」存疑才做。优先级：当前 Repo → 官方文档 → 官方 GitHub → 成熟开源 → 其他。找不到 → NO_SUITABLE_EXISTING_SOLUTION（禁止虚构）。

### 2.5 Plan
收敛为 Implementation Plan（`templates/implementation-plan.yaml`）。

---

## 3. Developer（DeepSeek）

> 详见 `agents/developer/AGENTS.md`。

- 唯一代码执行体，sessions_spawn（context=isolated）。
- 职责：改代码 / 建文件 / 删必要文件 / 写测试 / 执行测试 / 按测试结果修复。
- 不擅自重新设计产品。
- 测试失败 → 修复 → 再测，有限次数自动修复，超限 → FAILED。
- 禁止自动 push。

---

## 4. Reviewer

> 详见 `protocols/review-adapter.md`。

- Reviewer 是 Workflow 内部阶段，由 Main Agent 执行，不 spawn；检查能力迁移自 `openclaw-github-repository-reviewer`（基准 20583a7），V1 不依赖其运行。
- 强制「独立验证」子步骤（独立读代码/Git Diff、独立复跑关键测试、查边界、查 Regression、必要时加临时验证）。
- 检查：IDEAL/Requirement、Acceptance Criteria、Implementation、Git Diff、Regression、Tests、Documentation、Unrelated Changes、Repository Consistency。
- 结果：APPROVED / REWORK_REQUIRED。
- REWORK_REQUIRED → Development Workflow → Developer → Test → Reviewer，超限 → FAILED。

---

## 5. Git / Version / Changelog / Release

> 详见 `protocols/git-workflow.md` / `versioning.md` / `changelog.md` / `release.md` / `repository-cleanliness.md`。

- Git 保护优先：开发前记录 branch/commit/status/已有修改；优先 feature branch 或 worktree；禁止 force push/reset/覆盖未提交文件/改历史（除非 Human Decision）。
- Commit 与 Version 分离。
- SemVer + CHANGELOG + 保守 Release Gate。
- 收尾 Repository Cleanliness 检查。

---

## 6. development_result 结构

> 详见 `templates/development-result.yaml`。

```yaml
type: development_result
task_id: ""
status: <COMPLETED|FAILED|BLOCKED|HUMAN_DECISION_REQUIRED>
task_type: <SIMPLE|FEATURE|COMPLEX>
summary: ""
changed_files: []
tests: {executed: [], passed: [], failed: []}
review: {status: <APPROVED|REWORK_REQUIRED>, findings: []}
commit: ""
version: ""
release: ""
github: ""
known_issues: []
```

---

## 7. E2E 验收清单（CASE 1-10）

> 每个 Case 必须有真实证据，不能只写文档说「测试通过」。

| Case | 内容 | 关键验证点 |
|:--|:--|:--|
| CASE 1 | SIMPLE TASK | 简单任务快速完成，不 spawn 完整流水线 |
| CASE 2 | FEATURE TASK | 标准流程：Plan → Developer → Test → Reviewer → Commit |
| CASE 3 | COMPLEX TASK + IDEAL | IDEAL 缺失时 HUMAN_DECISION_REQUIRED |
| CASE 4 | Developer FAIL → REWORK → PASS | 测试失败自动修复回环 |
| CASE 5 | Reviewer FAIL → REWORK → PASS | Reviewer 抓缺陷 → Rework → 复验 |
| CASE 6 | Result Closure | 结果可靠回 Main Agent，不轮询 |
| CASE 7 | Git / Version / Changelog | Commit 与 Version 分离、SemVer、CHANGELOG |
| CASE 8 | GitHub Release | Release Gate 条件满足才 release |
| CASE 9 | 已有用户修改不被覆盖 | Git 保护：不覆盖用户未提交修改 |
| CASE 10 | 真实 dlt-simulator | 真实仓库完整闭环 |

**完成定义**：以上 10 个 Case 全部真实 PASS，才标记 V1 完成。

---

## 8. 禁止项

- ❌ 增加新 Agent / Runtime / ACP / 消息总线 / 复杂数据库 / CI/CD / 未来规划功能
- ❌ 修改 Agent OS Core
- ❌ 擅自改变 IDEAL
- ❌ 破坏用户已有修改
- ❌ 自动 push（push 走 Release Gate，需用户确认）
- ❌ 为通过 E2E 伪造测试结果
