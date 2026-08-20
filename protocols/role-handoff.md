# protocols/role-handoff.md — Role Handoff（结构化 Artifact 交接协议）

> 所有角色间通过**结构化 Artifact** 交接，禁止"我觉得应该这样做"这类无结构、无字段、无证据的口头式结论。

## 1. 交接链（Artifact Flow）

```
Requirement Result → Solution Discovery → Repository Understanding → Architecture Result → Implementation Plan
```

每个 Artifact 是**下游角色的输入**，字段可被下游直接消费、校验、引用。

| Artifact | 产出者 | 下游消费者 |
|:--|:--|:--|
| `requirement_result` | Requirement Analyst | Lead（路由）/ Solution Researcher / Repository Analyst / Architect |
| `solution_discovery_result` | Solution Researcher | Architect |
| `repository_understanding` | Repository Analyst | Architect |
| `architecture_result` | Architect | Lead（校验）/ Developer（实现依据） |
| `implementation_plan` | Architect（最终收敛） | Developer / Lead（交付判定） |

## 2. 每个 Result 必须含的公共字段

所有 Artifact 都必须有：

```yaml
type: <artifact 类型>
task_id: <全局唯一 task_id>
status: <该 Artifact 的完成状态>       # COMPLETED | FAILED | BLOCKED
producer: <产出角色>                    # requirement_analyst | solution_researcher | repository_analyst | architect | developer
artifacts: [<本 Artifact 产出的结构化内容>]
evidence: [<可追溯证据：路径/命令输出/数据摘要>]
```

> 这些字段让 Lead 的六项校验（task_id/status/required fields/acceptance/evidence/blocking）有统一抓手。

## 3. 交接规则

1. **字段可消费**：下游角色读上游 Artifact 时，只认字段，不认"上游说应该这样"。
2. **task_id 贯穿全链**：同一 task 的所有 Artifact 共用同一 task_id。
3. **evidence 强制**：claim 必须有证据，无证据的 claim 视为未完成。
4. **状态显式**：每个 Artifact 有自己的 status，不跨角色隐式继承。
5. **冲突向上抛**：下游发现上游 Artifact 有重大冲突/缺失 → 显式标 `blocking issue`，回报 Lead，不自行脑补。

## 4. 禁止项

- ❌ 用自然语言"我觉得应该这样做"代替结构化 Artifact。
- ❌ 跳字段：缺 acceptance_criteria 或 evidence 就交接。
- ❌ 篡改上游 task_id / 数据，交接过程中私自扩大或缩小需求。

## 5. 与 Lead 校验的关系

Lead 收到每个 Result 后按 `AGENTS.md` 的六项校验：
- 字段齐全 / acceptance 满足 / evidence 非空 → 进入下一阶段。
- 缺字段 / 无 evidence / acceptance 不达标 → RETRY_ROLE。
- 重大冲突 → RETURN_TO_ARCHITECT；需求不清 → HUMAN_DECISION_REQUIRED。

## 6. 落盘

每个 Artifact 按 `protocols/artifact-persistence.md` 持久化到 `.tasks/<task_id>/`。
