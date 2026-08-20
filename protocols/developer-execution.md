# protocols/developer-execution.md — Developer Execution Contract

> Phase 3 增强：Developer 是真正修改 Repository 的执行 Agent，必须遵循严格的执行契约。

## 输入

Developer 收到的任务必须包含：

| 输入 | 说明 |
|:--|:--|
| Implementation Plan | 来自 Architect（Phase 2 产物） |
| Requirement Result | 来自 Requirement Analyst |
| Repository Understanding | 来自 Repository Analyst |
| Architecture Result | 来自 Architect |
| Delegation Contract | 来自 Lead（含 task_id/attempt/scope/constraints） |

## 执行步骤（必须按顺序）

1. **阅读 Implementation Plan** — 理解要做什么、怎么做、验收标准
2. **阅读相关 Repository 文件** — 理解现有代码
3. **修改代码** — 只在 Plan 的 modify/create 范围内
4. **创建新文件** — 只在 Plan 的 create 范围内
5. **修改配置** — 只在 Plan 允许的范围内
6. **运行相关测试** — 执行 Plan 中指定的测试
7. **检查 git diff** — 确认变更符合预期
8. **检查意外修改** — 确认没有计划外的文件变更
9. **输出 Implementation Result** — 结构化产物

## 安全边界

**Plan 中的 modify/create 是默认允许修改范围。**

如果 Developer 发现需要修改计划之外的关键文件：

必须返回：

```
SCOPE_EXPANSION_REQUIRED
```

**不能偷偷扩大范围。** Lead 决定：
1. 扩大 Scope
2. 返回 Architect
3. HUMAN_DECISION_REQUIRED

## Execution State（执行开始时输出）

```yaml
type: execution_state
task_id: <task_id>
attempt: <attempt>
scope:
  modify: []
  create: []
planned_changes: []
```

## Implementation Result（执行结束后输出）

```yaml
type: implementation_result
task_id: <task_id>
attempt: <attempt>
status: <SUCCESS|FAILED|BLOCKED|SCOPE_EXPANSION_REQUIRED>
summary: ""
changed_files: []
created_files: []
deleted_files: []
tests:
  executed: []
  passed: []
  failed: []
acceptance_criteria:
  passed: []
  failed: []
scope_check:
  status: <MATCH|MISMATCH>
  unexpected_changes: []
git_diff_summary: ""
known_issues: []
evidence: []
next_recommended_stage: ""
```

### 禁止

- ❌ 只说"代码已完成"（必须有 changed_files/tests/evidence）
- ❌ 改 Plan 范围外的文件（SCOPE_EXPANSION_REQUIRED）
- ❌ 跳过测试
- ❌ 自动 push 到 remote

### Git 操作

Developer 可以：`git status` / `git diff` / `git log`
Developer 可以 commit（message 含 task_id）：`feat: implement X [DT-20260820-002]`
**禁止自动 push。**

## Commit 规范

```
<type>: <description> [<task_id>]

<detail>
```

示例：
```
feat: add statistics strategy [DT-20260820-002]
```

Review FAIL 时禁止把失败状态标记成最终完成。
