# PROTOCOL.md — Development Team V1 协议总纲

> 架构已收敛。V1 = 一个自动化软件开发流水线，角色模型固定为：
> `Main Agent → Development Workflow → Developer（capability=developer）→ Reviewer → Git/Version/Changelog/Release`。

## 0. X Agent OS Protocol 继承声明（P0 Compliance）

本协议在以下层级之上运行，**继承而非覆盖** Agent OS 基础协议：

```
OpenClaw Runtime
  → Agent OS
    → X Agent OS Protocol（Core Protocol v1.3 / Architecture Contract v1.6 / MA-1.1 · commit ccef093）
      → Development Team 开发规范（本协议）
        → 具体项目规范
          → Skill / Agent / Project 自身规则
```

**Development Team 只定义开发业务领域规则**，不得覆盖或重新定义 Agent OS 的 foundational behavior（agent lifecycle / identity / context / memory/state / delegation / inter-agent communication / permission / verification / skill loading / agent initialization / recovery）。

- Agent OS Protocol 是最高优先级；冲突时以 Agent OS Protocol 为准。
- 禁止创建第二套 Agent OS Protocol。
- 本协议定义的 Developer / Reviewer / routing / readiness / review 全部是 Agent OS 业务域实例化，不改变 Agent OS 基础执行链（Mandatory 链 + Conditional 节点）。

本文是协议索引 + 核心原则。各协议细节见 `protocols/` 目录。

---

## 1. 角色模型（冻结）

只有**一个独立执行体（Developer）+ 一个 Workflow 阶段（Reviewer）**：

| 执行体 | 形态 | 关键协议 |
|:--|:--|:--|
| Developer | capability=developer（runtime=openclaw，implementation=native_subagent） | `agents/developer/AGENTS.md` |
| Reviewer | Workflow 内部阶段（Main Agent 执行，不 spawn） | `review-adapter.md` |

**Developer 是 Capability，不是某个具体模型。** Protocol 层面只依赖 `capability: developer`，
不把任何具体 model 作为 Developer 身份定义：

```yaml
developer:
  capability: developer           # Protocol 只依赖此抽象能力
  runtime: openclaw               # 或 acp
  implementation: native_subagent # 或 codex / claude-code
  model: deepseek/deepseek-v4-flash  # 仅当前 default implementation，非 protocol requirement
```

- `model` 字段属于 deployment/config 层，是**默认实现**，不是协议约束；协议不得把
  `model="deepseek/..."` 当作 Developer 身份定义。
- Developer Capability → Runtime Adapter → Native Subagent / ACP / Other Coding Harness。
- 切换 runtime/model 只改 deployment，不改协议与 Workflow 语义。

其余能力（需求理解 / Repository 分析 / Research / Plan / IDEAL / Reviewer 检查）全部是 **Development Workflow**（Main Agent 自己执行的步骤），不是独立角色、不 spawn。

---

## 2. 核心流程（三档）

| 档位 | 流程 | 协议 |
|:--|:--|:--|
| SIMPLE | Understand → Implement → Test → Review(按需，见 routing.md 触发条件) → Commit | `routing.md` |
| FEATURE | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Rework → Commit → Version/Changelog | `routing.md` |
| COMPLEX | 检查 IDEAL → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Rework → Git → Version → Release | `routing.md` + `ideal-contract.md` |

> FEATURE / COMPLEX 默认 feature branch 或 worktree（优先 worktree），见 `git-workflow.md`。
> Commit ≠ Push ≠ Release：Push 是正常开发闭环，Release 才是正式发布（见 `release.md`）。

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

## 4. 状态机（Development Task 状态，P0-3 收口）

> 本状态机是 **Agent OS task-manager state machine 的 software-development domain projection**，
> 不重新定义 Agent OS task lifecycle；只把「软件开发子会话」的完成语义映射到 Agent OS 任务状态。
> 关键语义（P0-3）：**OpenClaw session completion ≠ task success**。
> `sessions_spawn completed` 只表示「子会话运行结束」，不代表任务成功。

```
NEW → DELEGATED → RUNNING → RUNTIME_COMPLETED → ARTIFACT_PENDING_VERIFICATION → REVIEWING → APPROVED / DONE
                            ↘ RUNTIME_FAILED / TIMEOUT → RECOVERY
REVIEWING → REWORK_REQUIRED → (rework) → RUNNING
```

| 起始 | 事件 | 目标 | 语义 |
|:--|:--|:--|:--|
| NEW | 填 Task + Delegation | DELEGATED | 目标已固化，准备委派 |
| DELEGATED | sessions_spawn 成功 | RUNNING | 子会话已在运行 |
| RUNNING | completion(completed) | RUNTIME_COMPLETED | **仅表示子会话运行结束，≠ 任务成功** |
| RUNNING | completion(failed) / 不可达 | RUNTIME_FAILED | 运行期失败，≠ 直接 IMPLEMENTATION_COMPLETED |
| RUNNING | 超时 | TIMEOUT → RECOVERY | 走 result-closure 阶梯 |
| RUNTIME_COMPLETED | 收到结构化 Artifact（implementation_result） | ARTIFACT_PENDING_VERIFICATION | 产物待验证 |
| RUNTIME_COMPLETED | 无结构化 Artifact / 仅「完成了」 | RUNTIME_FAILED | 无产物不得视为完成 |
| ARTIFACT_PENDING_VERIFICATION | 提交 Reviewer | REVIEWING | 进入质量闸门 |
| REVIEWING | APPROVED | IMPLEMENTATION_VERIFIED → PROJECT_READY（按需） | 仅 artifact+verification+review 全过才 IMPLEMENTATION_VERIFIED |
| REVIEWING | REWORK_REQUIRED | REWORK → RUNNING | 回退重做 |

> `IMPLEMENTATION_COMPLETED` 只作为 Developer 的**自述边界**（「实现+自测完成」），
> 不再是 Workflow 的 task success 状态。只有 artifact + verification + review 全部通过后，
> 才 `IMPLEMENTATION_VERIFIED`，最终 `PROJECT_READY`（见 `result-closure.md`）。

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
