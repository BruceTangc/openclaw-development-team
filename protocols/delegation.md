# protocols/delegation.md — Delegation Contract

> 委派给 Developer sub-agent 的正式契约。每次 `sessions_spawn` 前必须填好。

## 语义

Delegation Contract 是 Main Agent 交给 Developer 的「工作说明书」：明确做什么、边界在哪、怎么算完成、结果归谁。

## 字段（最小集）

| 字段 | 说明 |
|:--|:--|
| `task_id` | 关联 Development Task |
| `role` | 委派角色（V1：`developer`） |
| `objective` | 可验证达成目标 |
| `context` | 背景/必要上下文（isolation 下要写清楚） |
| `scope` | 在范围内/在范围外 |
| `constraints` | 边界（只读路径/不 push/不改安全/脱敏） |
| `acceptance_criteria` | 可验证成功条件 |
| `expected_output` | 产出格式（Implementation Result YAML） |
| `result_owner` | **Main Agent / requester session**（非最终用户） |
| `timeout` | 超时策略 |
| `attempt` | 第几次尝试 |

## 硬约束

- `result_owner` **必须是 Main Agent / requester session，不是最终用户**。
- `context` 在 `isolated` 模式下要自足：Developer 看不到 Main Agent 的会话上下文。
- `expected_output` 指向 `templates/implementation-result.yaml` 结构。

## 模板

见 `templates/delegation-contract.yaml`。

## 委派动作

填好后用 `sessions_spawn` 委派：

```text
sessions_spawn(
  task = <把 Delegation Contract 关键内容 + 回传格式写进 task 文本>,
  taskName = <task_id 的小写匹配名>,
  label = <human-readable label>,
  cwd = <目标工作目录, 可选>,
  context = isolated
)
```
