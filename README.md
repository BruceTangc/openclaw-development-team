# OpenClaw Development Team v1.0 — Phase 1

最小可运行 E2E 链路（Minimum Viable End-to-End），核心目标是 **Result Closure（结果闭环）**：
子代理执行结果必须可靠回到 Development Lead，且经过 Minimal Validator 判定 PASS。

> 施工目录，与 `../openclaw-development-team`（全量版，Phase 2 目标）**完全隔离**。本目录只做 Phase 1。

---

## 版本与范围

- **Phase**：1（Minimal Viable E2E）
- **OpenClaw**：2026.7.1-2
- **目标**：跑通 `Lead → sessions_spawn → Developer sub-agent → completion → Lead → sessions_yield → Validator PASS`

### 本阶段实现（8 项）

| # | 组件 | 说明 |
|:--|:--|:--|
| 1 | Development Lead | = Main Agent（本机角色），负责委派与消费结果 |
| 2 | Developer Role | 原生 sub-agent 执行 |
| 3 | Development Task | 最小 Task Contract |
| 4 | Delegation Contract | 委派契约（result_owner = Lead，非最终用户） |
| 5 | Implementation Result | 结构化实现结果（必有 evidence） |
| 6 | Result Closure | P0 结果闭环 |
| 7 | Minimal Validator Stub | 最小校验（changed_files / tests / acceptance / git diff） |
| 8 | E2E Test | 真实链路验证 |

### 本阶段不实现（Phase 2）

Requirement Analyst / Solution Researcher / Repository Analyst / Architect / 完整 Validator / 完整 Repository Reviewer / Release Manager —— **全部不做**。

---

## 目录结构

```
dev-team-phase1/
├── README.md                 # 本文件
├── AGENTS.md                 # Development Lead 角色定义
├── PROTOCOL.md               # Phase 1 协议（Result Closure P0 + 状态机）
├── IMPLEMENTATION_SPEC.md    # 实现规范 + E2E 验收清单
├── agents/
│   └── developer/
│       └── AGENTS.md         # Developer 角色定义
├── protocols/
│   ├── task.md               # Task Contract
│   ├── delegation.md         # Delegation Contract
│   ├── result-closure.md     # Result Closure（P0）
│   └── verification.md       # Minimal Validator
├── templates/
│   ├── development-task.yaml
│   ├── delegation-contract.yaml
│   ├── implementation-result.yaml
│   └── verification-result.yaml
└── scripts/
    ├── e2e_runner.py         # E2E 驱动（供 Main Agent 会话执行 spawn/yield）
    └── e2e_target.py         # 极小测试目标（hello 函数 + 自测）
```

---

## 关键结论（基于官方文档，已确认，不重复验证）

- `sessions_spawn` **非阻塞**：spawn 后立即返回 `{ status: "accepted", runId, childSessionKey }`，不等子代理完成。
- completion **push 式**：子代理完成时 OpenClaw 生成一个 `agent` turn 回到 requester session（带幂等 key）。
- 等待原语是 **`sessions_yield`**：结束当前 turn，让 completion 事件作为下一个模型可见消息到达。
- **禁止**用 sleep / sessions_history / sessions_list / subagents list 轮询作为正常等待（仅异常诊断）。
- 原生 sub-agent **默认无 message / sessions_send** → 不要求 Developer 自己回传，回传靠 announce 链。

---

## 状态机（最小）

```
NEW → DELEGATED → WAITING_RESULT → IMPLEMENTATION_COMPLETED → VERIFYING → VERIFIED
                        │                                        │
                        ├─→ FAILED                                └─→ FAILED → REWORK
                        └─→ TIMEOUT → RECOVERY
```

详见 `PROTOCOL.md`。

---

## 安全红线

- 文件/代码/测试中**不含**真实 API key / token / 邮箱真实地址 / 机器 hash。
- git 身份使用 noreply 邮箱。
- 不改主会话 OpenClaw 配置/权限/安全/AGENTS/MEMORY/SOUL。
- 不 self-edit 权限。
- 出现 `HUMAN_DECISION_REQUIRED` 不瞎猜，回报主会话。
