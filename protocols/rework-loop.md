# protocols/rework-loop.md — Rework Loop Protocol

> Phase 3 新增：Developer→Validator→Reviewer 的失败→修复→再验证循环，含死循环防护。

## Rework 触发条件

| 触发源 | 条件 | Lead 的下一步 |
|:--|:--|:--|
| Validator | status=FAIL | 读 findings → 判断(Developer修复/Architect重设计/Requirement重解释/HUMAN_DECISION_REQUIRED) |
| Reviewer | CHANGES_REQUIRED | 读 critical_findings → 生成 rework_instruction → Developer |
| Reviewer | BLOCKED | ESCALATE / HUMAN_DECISION_REQUIRED |

## Rework Instruction 格式

```yaml
type: rework_instruction
task_id: <task_id>
attempt: <current_attempt>
reason: "<why rework is needed>"
findings: []           # from Validator or Reviewer
required_changes: []   # specific changes to make
scope:                 # allowed modification scope
  modify: []
  create: []
acceptance_criteria: [] # must be satisfied
```

## Rework Loop 限制

| 规则 | 说明 |
|:--|:--|
| MAX_REWORK_ATTEMPTS | 3（超过 → HUMAN_DECISION_REQUIRED） |
| 相同根因 2 次 | → RETURN_TO_ARCHITECT（不能让 Developer 无限修补） |
| 每次 rework 必须记录 | attempt / failure_reason / previous_findings / required_changes |
| 禁止死循环 | Developer→FAIL→Developer→FAIL→Developer→FAIL→无限循环 |

## Rework Artifact

每次 rework 落盘到 `.tasks/<task_id>/`：

```
rework-001.yaml    # 第一次 rework
rework-002.yaml    # 第二次 rework
rework-003.yaml    # 第三次 rework（如果允许）
```

**不覆盖历史结果。** 所有 rework 记录保留。

## Architecture Revision

如果 Validator/Reviewer 发现**架构问题**（接口设计/数据流/模块边界/技术方案不成立）：

```
Validator/Reviewer → Lead → REVISIT_ARCHITECTURE
  → Architect → New Implementation Plan → Developer
```

**不能让 Developer 无限修补架构问题。**

## Lead 决策逻辑

```
收到 Validator/Reviewer FAIL
  → 读 findings
  → 判断根因：
      ├─ 代码质量/实现问题 → Developer 修复（普通 rework）
      ├─ 架构问题 → REVISIT_ARCHITECTURE
      ├─ 需求理解错误 → RETURN_TO_REQUIREMENT
      ├─ 需要用户决策 → HUMAN_DECISION_REQUIRED
      └─ 不确定 → 先尝试 Developer 修复
  → 检查 rework 次数：
      ├─ < 3 → 重新委派 Developer
      ├─ = 3 → HUMAN_DECISION_REQUIRED
      └─ 相同根因 2 次 → RETURN_TO_ARCHITECT
```

## 禁止

- ❌ 无限重试（MAX 3）
- ❌ 相同根因重复 2 次不升级
- ❌ 不记录 rework 历史
- ❌ 不检查根因直接重试
