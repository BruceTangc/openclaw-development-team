# protocols/review-adapter.md — Reviewer（独立质量闸门）

> V1 收敛：Reviewer 是唯一质量闸门。**Validator 不再作为独立 sub-agent / Runtime / Agent**，
> 但「独立验证能力」保留，作为 Reviewer 的**强制子步骤**。
> Reviewer 复用现有 `repository-reviewer` agent，不重造。

## 1. 定位

Reviewer 与 Developer 的判断**相对独立**。不默认相信 Developer 的「tests pass」，必须自己复核关键结果。

## 2. 标准流程（冻结）

```
Developer
  ↓
Developer Self-Test
  ↓
Developer Result
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

## 3. 独立验证子步骤（关键设计）

1. **Independent Verification 必须与 Developer Self-Test 逻辑上独立**。
2. Reviewer 不能仅因为 Developer 报告「tests pass」就直接通过。
3. Reviewer 必须自己复核关键结果（独立读代码、独立跑测试、查边界、查 Regression）。
4. 发现 Developer 漏掉的 Bug 时，必须进入 `REWORK_REQUIRED`。
5. 独立验证可增加临时验证脚本（放 /tmp，不改仓库文件）。

## 4. 检查清单

| # | 检查项 | 说明 |
|:--|:--|:--|
| 1 | IDEAL / Requirement | 是否满足需求 / IDEAL 验收标准 |
| 2 | Acceptance Criteria | 每条是否可验证满足 |
| 3 | Implementation | 实现是否符合 Plan |
| 4 | Git Diff | 变更是否符合预期，无计划外改动 |
| 5 | Regression | 是否引入回归 |
| 6 | Tests | 测试是否真实通过（独立复跑） |
| 7 | Documentation | 文档是否同步 |
| 8 | Unrelated Changes | 有无无关改动 |
| 9 | Repository Consistency | 仓库一致性 |

## 5. Review Result（输出格式）

```yaml
type: review_result
task_id: <task_id>
review_id: <review_id>
independent_verification:
  performed: true
  code_read: true
  git_diff_reviewed: true
tests_reproduced:
  executed: []
  passed: []
  failed: []
findings:
  critical: []    # 必须修复 → REWORK_REQUIRED
  warning: []     # 建议修复
  info: []
regression_status: <NONE|MINOR|BLOCKING>
final_decision: <APPROVED|REWORK_REQUIRED>
recommendation: ""
evidence: []
```

## 6. 路由决策

| final_decision | Main Agent 下一步 |
|:--|:--|
| APPROVED | → 进入 Git / Version / Changelog / Release |
| REWORK_REQUIRED | → Rework 循环（见 `rework-loop.md`） |

## 7. 调用方式

复用现有 `repository-reviewer` agent：

```
sessions_send(
  agentId: "repository-reviewer",
  message: "<Review Context：仓库路径 + commit + changed_files + Plan 摘要 + 要求含独立验证子步骤>",
  timeoutSeconds: 600
)
```

## 8. 禁止项

- ❌ 复制 Reviewer 的审核规则到别的角色
- ❌ 绕过 Reviewer（必须真实调用）
- ❌ mock Reviewer
- ❌ 仅凭 Developer 的「tests pass」直接 APPROVED（必须独立复核）
- ❌ 新增 Validator Agent（独立验证是 Reviewer 的子步骤，不是新角色）
