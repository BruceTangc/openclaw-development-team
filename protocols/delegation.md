# protocols/delegation.md — Delegation Contract

> 委派给 Developer sub-agent 的正式契约。每次 `sessions_spawn` 前必须填好。

> **CNF-3 继承声明**：Multi-Agent 权限不变量（`Child Effective Authority ⊆ Delegation Scope ⊆ Parent Authority`、
> 默认不继承、不可再委托放大）**继承 Agent OS ACTION-PROTOCOL §5**，本文件不复制；
> DT 只补充 Developer-specific 约束（scope / expected_output / result_owner / timeout 阶梯）。
> 最终执行边界永远是 OpenClaw native policy / approval / sandbox。

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
| `timeout` | Workflow 层任务控制字段（非 sessions_spawn 参数），超时/恢复由 Main Agent 依据 sessions_history / subagents 状态判断 |
| `attempt` | 第几次尝试 |

## 硬约束

- `result_owner` **必须是 Main Agent / requester session，不是最终用户**。
- `context` 在 `isolated` 模式下要自足：Developer 看不到 Main Agent 的会话上下文。
- `expected_output` 指向 `templates/implementation-result.yaml` 结构。

## 模板

见 `templates/delegation-contract.yaml`。

## 委派动作

填好后用 `sessions_spawn` 委派（**Developer 唯一独立执行体，必须显式指定 context / taskName**）：

```text
sessions_spawn(
  task = <把 Delegation Contract 关键内容 + 回传格式写进 task 文本>,
  taskName = <task_id 的小写匹配名>,
  label = <human-readable label>,
  cwd = <目标工作目录, 可选>,
  model = "deepseek/deepseek-v4-flash",   # 仅当前默认 implementation；protocol 只依赖 capability=developer，不依赖具体 model
  context = "isolated"                      # 必须 isolated
)
```

> **Developer Capability 说明**：`model` 是 deployment/config 层的默认实现，非协议约束。
> Protocol 只要求委派一个 `capability: developer` 的执行体（runtime=openclaw，implementation=native_subagent）；
> 换 model/runtime 只改 deployment，不改本契约语义。

> **timeout 说明**：`timeout` 是 Workflow 层的任务控制字段，**不是 `sessions_spawn` 参数**（`sessions_spawn` 不支持 per-call timeout）。超时与恢复由 Main Agent 依据 `sessions_history` / `subagents` 状态 / completion 判断，走 `result-closure.md` 的 R1（Retry）→ R2（接管）→ R3（ESCALATE）阶梯。
