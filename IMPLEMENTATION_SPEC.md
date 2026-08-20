# IMPLEMENTATION_SPEC.md — 实现规范 + E2E 验收清单

OpenClaw Development Team v1.0 Phase 1 的实现规范。

---

## 1. 组件清单（8 项，对齐范围）

| # | 组件 | 实现方式 | 落地文件 |
|:--|:--|:--|:--|
| 1 | Development Lead | Main Agent 角色（本机） | `AGENTS.md` |
| 2 | Developer Role | 原生 sub-agent | `agents/developer/AGENTS.md` |
| 3 | Development Task | Task Contract | `protocols/task.md` + `templates/development-task.yaml` |
| 4 | Delegation Contract | 委派契约 | `protocols/delegation.md` + `templates/delegation-contract.yaml` |
| 5 | Implementation Result | 结构化实现结果 | `templates/implementation-result.yaml` |
| 6 | Result Closure | P0 闭环 | `protocols/result-closure.md` |
| 7 | Minimal Validator Stub | 最小校验 | `protocols/verification.md` + `templates/verification-result.yaml` |
| 8 | E2E Test | 真实链路 | `scripts/e2e_runner.py` + `scripts/e2e_target.py` |

---

## 2. OpenClaw API 使用方式（施工依据）

- **委派**：`sessions_spawn(task=..., taskName=..., label=..., cwd=..., model=...)`
  - 返回 `{ status: "accepted", runId, childSessionKey }`，非阻塞。
  - `context` 默认 `isolated`（本任务独立，无需 fork 上下文）。
- **等待**：`sessions_yield` —— 结束当前 turn，让 completion 事件作为下一条模型消息到达。
- **消费**：completion/announce 回到 requester session，含 `Status` + 子代理 assistant 文本（含 stats line：sessionKey/sessionId/transcript path）。
- **诊断（仅异常）**：`subagents` / `sessions_history` / `/subagents list|log|info`。
- **追加（可选，非回传机制）**：`sessions_send`（timeoutSeconds: 0 = fire-and-forget）。

> 注意：`sessions_yield` 必须在 session 有效工具列表里才可用。若 profile 未暴露，不要造 polling loop，直接回报主会话。

---

## 3. 契约字段（最小集）

### Development Task
```
task_id / project / goal / objective / scope / constraints / acceptance_criteria /
requester_session / result_owner / status / attempt / created_at
```

### Delegation Contract
```
task_id / role / objective / context / scope / constraints / acceptance_criteria /
expected_output / result_owner / timeout / attempt
```
> `result_owner` **必须是 Development Lead / requester session**，不是最终用户。

### Implementation Result
```
type / task_id / status(COMPLETED|FAILED|BLOCKED|PARTIAL) / summary / changed_files /
tests / acceptance_criteria / known_issues / evidence / next_recommended_stage
```
> 禁止只返回"完成了"，必须有 evidence。

### Verification Result
```
task_id / status(PASS|FAIL|BLOCKED) / tests / acceptance_criteria / findings / evidence
```

---

## 4. Minimal Validator Stub 校验项

| 检查 | 内容 |
|:--|:--|
| changed_files 存在 | 有实际文件变更清单且非空 |
| 是否执行测试 | tests 字段有执行记录 |
| 测试是否通过 | tests 全部通过（无 failing） |
| acceptance_criteria 满足 | 每条 criteria 有对应满足证据 |
| git diff 合理 | diff 非空且与 changed_files 一致（无意外文件） |

输出 `verification_result`：`task_id/status/tests/acceptance_criteria/findings/evidence`，`status ∈ {PASS, FAIL, BLOCKED}`。

---

## 5. E2E 验收清单（硬性，不接受 mock）

必须真实跑通一次：

1. [ ] Lead 建 Development Task + Delegation Contract
2. [ ] `sessions_spawn` 委派给 Developer sub-agent
3. [ ] Developer 在极小测试项目加一个 `hello` 函数，自测通过，回传 Implementation Result
4. [ ] completion 回到 Lead（`sessions_yield` 消费）
5. [ ] Lead 解析 Implementation Result
6. [ ] Minimal Validator 校验 → `status=PASS`
7. [ ] 记录证据：OpenClaw version / sessions_spawn 参数 / requester session / child session / completion delivery route / 实际结果

---

## 6. Failure 测试（超时 / 失败路径）

1. [ ] 构造一个超时 task → 期望 `SUBAGENT_TIMEOUT`
2. [ ] Lead 用 `subagents` / `sessions_history` 诊断（recovery）
3. [ ] Retry（attempt+1，最多 3 次）或 ESCALATE

---

## 7. 当前已知限制

- 本项目为 **subagent 运行时**（depth 1 leaf），工具集不含 `sessions_spawn` / `sessions_yield` / `subagents` / `sessions_history`。
  - 因此真正 spawn/yield 的 E2E 必须由 **Main Agent 会话**（本机 `main` 角色，已授予 `sessions_spawn`/`sessions_send`/`subagents`）执行。
  - `sessions_yield` 当前**不在** `tools.allow` 白名单中（见配置），需要确认主会话是否可用；不可用则记录并回报，不造 polling loop。
- 详见 `README.md` 与最终施工报告。
