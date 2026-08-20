# protocols/result-closure.md — Result Closure（P0 核心协议）

> 子代理结果必须可靠回到 Development Lead。Lead 是 result_owner。这是 Phase 1 的 P0 铁律。
> 完整版见 `PROTOCOL.md` §1。

## 1. 首选路径（OpenClaw 原生 announce 链）

```
Lead → sessions_spawn → Developer 执行 → completion/announce（agent turn，幂等 key）
  → requester session → sessions_yield → Lead 消费 → Validator 校验
```

## 2. 等待原语

- **用 `sessions_yield`**：结束当前 turn，等 completion 事件作为下一条消息到达。
- **禁止 polling loop**：不用 sleep / sessions_history / sessions_list / subagents list 轮询等完成。

## 3. 结果语义

- `Result` = 子代理最新可见 assistant 文本（tool/toolResult 不提升）。
- `Status` 由 runtime 派生（ok/error/timeout/unknown），非文本推断。
- 结果必须结构化（Implementation Result），禁止只返回"完成了"。

## 4. 回传机制

- 回传**默认靠 announce 链**，不要求 Developer 用 sessions_send（原生 sub-agent 无此工具）。
- `sessions_send` 仅供 Lead 主动追加指令（fire-and-forget），非回传机制。

## 5. Recovery（超时/失败阶梯）

| 阶 | 动作 | 条件 |
|:--|:--|:--|
| R1 | Retry | 首次超时/失败，同参重 spawn，attempt+1（≤3） |
| R2 | 接管 | Retry 仍失败 / 子代理不可达，Lead 直接执行 |
| R3 | ESCALATE | 连续失败 ≥3 / HUMAN_DECISION_REQUIRED，转主会话 |

- 超时诊断用 `subagents` / `sessions_history`（recovery 手段，非正常等待）。
- 每次 retry 记录 `attempt / failure_reason / previous_result / new_strategy`。

## 6. Provenance + Anti-loop

- 每次 spawn/回传保留 `agent_id / session_id / task_id / operation_id / correlation_id / parent_task_id`。
- 每 cycle 带 `cycle_id / retry_count / action_signature / last_action_time`。
- 相同动作无新证据 → NOOP/IGNORE，不重复 spawn。
