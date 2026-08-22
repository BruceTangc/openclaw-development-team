# protocols/rework-loop.md — Rework Loop

> Developer → Reviewer 的失败→修复→再验证循环，含死循环防护。
> V1 收敛后，Rework 唯一触发源是 Reviewer 的 `REWORK_REQUIRED`（Developer 自测失败在 Developer 内部内循环处理）。

## 1. Rework 触发

| 触发源 | 条件 | Main Agent 下一步 |
|:--|:--|:--|
| Reviewer | final_decision = REWORK_REQUIRED | 读 findings → 生成 rework_instruction → Developer 重新 spawn |
| Reviewer | review.status = BLOCKED | HUMAN_DECISION / ESCALATE（见 human-decision.md） |
| Developer 自测超限 | 修复次数 > 3 | FAILED → Main Agent |

> Reviewer 发现架构问题（技术方案不成立）→ 回到 Development Workflow 重新 Plan，不是让 Developer 无限修补。
>
> **Rework 闭环（方案 A）**：`REWORK_REQUIRED → Developer 重新 spawn（修复）→ 再次 spawn Reviewer（复审）→ APPROVED`。
> 每次复审都是新的独立 Reviewer subagent（sessions_spawn，独立 context），不是复用上一次 Reviewer 会话；
> **Reviewer `completed` ≠ APPROVED**，复审 APPROVED 仍由 structured review result 驱动。

## 2. Rework Instruction 格式

```yaml
type: rework_instruction
task_id: <task_id>
attempt: <current_attempt>
reason: "<why rework>"
findings: []           # from Reviewer
required_changes: []   # 具体要改什么
scope:
  modify: []
  create: []
acceptance_criteria: [] # 必须满足
```

## 3. Rework Loop 限制

> **CNF-2 继承声明**：本节的失败/恢复策略**继承 Agent OS failure/recovery protocol**（Agent OS = contract），
> `MAX_REWORK_ATTEMPTS=3` 只是 Development Team 的 **domain policy**（DT = policy），
> 不声称重新定义 Agent OS 失败处理协议。失败后 diagnose → repair → retry → re-verify → escalate
> 遵循 Agent OS 循环；DT 只把「重试上限」具体化为 3 次。

| 规则 | 说明 |
|:--|:--|
| MAX_REWORK_ATTEMPTS | 3（DT domain policy；遵循 Agent OS failure/recovery protocol，超过 → ESCALATE/FAILED → Main Agent） |
| 相同根因 2 次 | → 回到 Development Workflow 重新 Plan |
| 每次 rework 必须记录 | attempt / failure_reason / previous_findings / required_changes |
| 禁止死循环 | Developer→REWORK_REQUIRED→Developer→…→无限循环 |

## 4. Rework Artifact

每次 rework 落盘 `.tasks/<task_id>/rework-*.yaml`，不覆盖历史结果。

## 5. 流程

```
Reviewer REWORK_REQUIRED
  → Main Agent 读 findings
  → 判断根因：
      ├─ 代码质量/实现问题 → Developer 修复（普通 rework）→ 再次 spawn Reviewer（复审）
      ├─ 架构问题 → 回 Development Workflow 重新 Plan
      ├─ 需求/IDEAL 理解错误 → 回 Understand / 检查 IDEAL
      ├─ 需要用户决策 → HUMAN_DECISION_REQUIRED
      ├─ Reviewer BLOCKED → HUMAN_DECISION / ESCALATE
      └─ 不确定 → 先尝试 Developer 修复
  → 检查 rework 次数：
      ├─ < 3 → 重新委派 Developer（释放旧 lease，重新 spawn）
      └─ = 3 → FAILED → Main Agent
```

## 6. 禁止项

- ❌ 无限重试（MAX 3）
- ❌ 相同根因重复 2 次不升级
- ❌ 不记录 rework 历史
- ❌ 不检查根因直接重试
