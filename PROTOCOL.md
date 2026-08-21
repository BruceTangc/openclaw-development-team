# PROTOCOL.md — Development Team V1 协议总纲

> 架构已收敛。V1 = 一个自动化软件开发流水线，角色模型固定为：
> `Main Agent → Development Workflow → Developer（DeepSeek）→ Reviewer → Git/Version/Changelog/Release`。

本文是协议索引 + 核心原则。各协议细节见 `protocols/` 目录。

---

## 1. 角色模型（冻结）

只有**一个独立执行体（Developer）+ 一个 Workflow 阶段（Reviewer）**：

| 执行体 | 形态 | 关键协议 |
|:--|:--|:--|
| Developer | DeepSeek sub-agent（sessions_spawn） | `agents/developer/AGENTS.md` |
| Reviewer | Workflow 内部阶段（Main Agent 执行，不 spawn） | `review-adapter.md` |

其余能力（需求理解 / Repository 分析 / Research / Plan / IDEAL / Reviewer 检查）全部是 **Development Workflow**（Main Agent 自己执行的步骤），不是独立角色、不 spawn。

---

## 2. 核心流程（三档）

| 档位 | 流程 | 协议 |
|:--|:--|:--|
| SIMPLE | Understand → Implement → Test → Review(按需) → Commit | `routing.md` |
| FEATURE | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Rework → Commit → Version/Changelog | `routing.md` |
| COMPLEX | 检查 IDEAL → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Rework → Git → Version → Release | `routing.md` + `ideal-contract.md` |

---

## 3. 协议清单

| 协议 | 定位 |
|:--|:--|
| `result-closure.md` | P0 结果闭环（保留已验证机制） |
| `ideal-contract.md` | IDEAL 高层设计输入（COMPLEX 必查） |
| `routing.md` | 复杂度判断 + 三档路由 |
| `task.md` | Development Task 契约 |
| `delegation.md` | Delegation 契约 |
| `agents/developer/AGENTS.md` | Developer 执行契约（DeepSeek） |
| `review-adapter.md` | Reviewer 独立质量闸门（含独立验证子步骤） |
| `rework-loop.md` | Rework 循环 + 死循环防护 |
| `reuse-decision.md` | Research / 复用决策 |
| `artifact-persistence.md` | Artifact 持久化 |
| `git-workflow.md` | Git 保护（本次重点） |
| `versioning.md` | SemVer |
| `changelog.md` | CHANGELOG |
| `release.md` | GitHub Release Gate |
| `repository-cleanliness.md` | 仓库整洁检查 |
| `human-decision.md` | Human Decision 触发条件 |
| `main-agent-integration.md` | Production Integration |

---

## 4. 状态机（最小）

```
NEW → DELEGATED → WAITING_RESULT → IMPLEMENTATION_COMPLETED → REVIEWING → APPROVED/DONE
                                    ↘ FAILED/TIMEOUT → RECOVERY
REVIEWING → REWORK_REQUIRED → (rework) → WAITING_RESULT
```

| 起始 | 事件 | 目标 |
|:--|:--|:--|
| NEW | 填 Task + Delegation | DELEGATED |
| DELEGATED | sessions_spawn 成功 | WAITING_RESULT |
| WAITING_RESULT | completion(completed) | IMPLEMENTATION_COMPLETED |
| WAITING_RESULT | completion(failed) / 不可达 | FAILED |
| WAITING_RESULT | 超时 | TIMEOUT → RECOVERY |
| IMPLEMENTATION_COMPLETED | 提交 Reviewer | REVIEWING |
| REVIEWING | APPROVED | DONE |
| REVIEWING | REWORK_REQUIRED | REWORK → WAITING_RESULT |

---

## 5. Result Closure（P0）

> 详见 `result-closure.md`。

- 优先 OpenClaw 原生 completion（push-based auto-announce）。
- 禁止轮询（sleep / sessions_list / subagents list 循环）。
- 不默认把内部结果 announce 给最终用户。
- 异常 fallback `sessions_history`（仅 recovery，非正常流程）。

---

## 6. 安全红线

- 无真实 key/token/邮箱/hash；git 用 noreply。
- 不改主会话 OpenClaw 配置 / 权限 / 安全 / AGENTS / MEMORY / SOUL。
- 不 self-edit 权限。
- 不破坏用户已有修改（见 `git-workflow.md`）。
- HUMAN_DECISION_REQUIRED → 回报用户（见 `human-decision.md`）。

---

## 7. Definition of Done

Task 完成 = Requirement/IDEAL 满足 + Implementation Plan 完成 + Developer 完成 + Reviewer APPROVED + Git 干净 + Version/Changelog 正确。

缺一不可，否则不能向用户报告「开发完成」。
