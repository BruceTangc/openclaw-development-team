# protocols/result-closure.md — Result Closure（P0 核心协议）

> 子代理结果必须可靠回到 Main Agent / Development Workflow。这是 P0 铁律（保留已验证机制）。

## 1. 首选路径（OpenClaw 原生 announce 链）

```
Main Agent → sessions_spawn → Developer 执行 → completion/announce（agent turn，幂等 key）
  → requester session → 自动作为 user message 到达 → Main Agent 消费 → Reviewer
```

## 2. 等待原语

- **用 push-based auto-announce**：spawn 后结束当前 turn，等 completion 事件作为下一条 user message 自动到达。
- **禁止 polling loop**：不用 sleep / sessions_history / sessions_list / subagents list 轮询等完成。

## 3. 结果语义

- `Result` = 子代理最新可见 assistant 文本（tool/toolResult 不提升）。
- `Status` 由 runtime 派生（ok/error/timeout/unknown），非文本推断。
- 结果必须结构化（Implementation Result），禁止只返回「完成了」。

### 3.1 completion ≠ task success（P0-3）

- **OpenClaw session completion 只表示「子会话运行结束」，不代表任务成功。**
- `sessions_spawn completed` ≠ implementation passed ≠ task completed。
- 状态链（domain projection，见 PROTOCOL.md §4）：
  `DELEGATED → RUNNING → RUNTIME_COMPLETED → ARTIFACT_PENDING_VERIFICATION → REVIEWING → APPROVED`；
  失败态为 `RUNTIME_FAILED`（而非直接 IMPLEMENTATION_COMPLETED）。
- 只有 artifact + verification + review 全部通过后才 `IMPLEMENTATION_VERIFIED`，最终 `PROJECT_READY`。
- 仅返回「完成了」而无结构化 Artifact → `RUNTIME_FAILED`，不得视为完成。

## 4. 回传机制

- 回传**默认靠 announce 链**，不要求 Developer 用 sessions_send（原生 sub-agent 无此工具）。
- `sessions_send` 仅供 Main Agent 主动追加指令（fire-and-forget），非回传机制。

## 5. Recovery（超时/失败阶梯）

| 阶 | 动作 | 条件 |
|:--|:--|:--|
| R1 | Retry | 首次超时/失败，同参重 spawn，attempt+1（≤3） |
| R2 | 接管 | Retry 仍失败 / 子代理不可达，Main Agent 直接执行 |
| R3 | ESCALATE | 连续失败 ≥3 / HUMAN_DECISION_REQUIRED，转用户 |

- 超时诊断用 `subagents` / `sessions_history`（recovery 手段，非正常等待）。
- **允许 fallback `sessions_history`，但不把它当正常主流程。**

## 6. 结果通知原则

- **不默认把内部开发结果 announce 给最终用户。**
- 只有 `HUMAN_DECISION_REQUIRED` 或最终完成结果，才由 Main Agent 决定如何通知用户。

## 7. Provenance + Anti-loop

- 每次 spawn/回传保留 `agent_id / session_id / task_id / operation_id / correlation_id / parent_task_id`。
- 每 cycle 带 `cycle_id / retry_count / action_signature / last_action_time`。
- 相同动作无新证据 → NOOP/IGNORE，不重复 spawn。
