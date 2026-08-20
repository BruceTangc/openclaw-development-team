# OpenClaw Development Team v1.0 — Phase 2

在 Phase 1（Result Closure 最小闭环）基础上扩展为**完整的需求→方案→仓库理解→架构→实施方案**分析流程。

> 吸收 MetaGPT 核心思想（Role separation / SOP / structured handoff / artifact driven workflow / staged development），
> 不复制 MetaGPT；Developer 执行方式参考 OpenHands 事件驱动，但不引入 OpenHands Runtime。

---

## 版本与范围

- **Phase**：2（需求分析 + 方案发现 + 仓库分析 + 架构设计 + 实施方案）
- **OpenClaw**：2026.7.1-2
- **目标**：证明这是一套"真正的开发流程"——角色间 Artifact 真实衔接、Lead 真实动态路由，并跑通一条真实主链路验收。

### 本阶段实现（Phase 2 新增，在 Phase 1 基础上扩展）

| # | 组件 | 说明 |
|:--|:--|:--|
| 1 | Requirement Analyst | 自然语言需求 → 结构化 Requirement Specification |
| 2 | Solution Researcher | 搜索优先级 + GitHub 分析 → Solution Discovery Result |
| 3 | Repository Analyst | 只读理解当前项目 → Repository Understanding |
| 4 | Architect | 三份输入 → Architecture Result + Implementation Plan |
| 5 | Implementation Plan | Architect 最终核心产物（reuse/modify/create/steps/DoD） |
| 6 | Development Lead 动态决策 | 唯一 Orchestrator，复杂度路由 + 六项校验 + 动态委派 |
| 7 | Role Handoff | 结构化 Artifact 交接（禁止"我觉得应该这样做"） |
| 8 | Artifact Persistence | 工程 Artifact 持久化到 `.tasks/<task_id>/` |
| 9 | E2E 测试 5 个 | 路由逻辑 + Artifact 链真实跑通 |

### 本阶段不实现（Phase 3+）

完整 Developer 重构 / ACP / OpenHands Runtime / Codex Runtime / Claude Code Runtime / 自定义 Scheduler / 自定义 Message Bus / 新数据库 / 新 Agent Runtime / 修改 Agent OS Core / 重写 Repository Reviewer / Release automation —— **全部不做**。

---

## 目录结构（Phase 2 完整版）

```
dev-team-phase1/
├── README.md                      # 本文件
├── AGENTS.md                      # Development Lead（唯一 Orchestrator，动态路由+六项校验）
├── PROTOCOL.md                    # 协议（Phase 1 Result Closure + Phase 2 Handoff/Persistence/Routing/Reuse）
├── IMPLEMENTATION_SPEC.md         # 实现规范 + E2E 验收清单
├── agents/
│   ├── developer/AGENTS.md        # Developer（终端执行角色）
│   ├── requirement-analyst/AGENTS.md    # 需求分析师
│   ├── solution-researcher/AGENTS.md    # 方案研究员
│   ├── repository-analyst/AGENTS.md     # 仓库分析师（只读）
│   └── architect/AGENTS.md       # 架构师
├── protocols/
│   ├── task.md / delegation.md / result-closure.md / verification.md   # Phase 1
│   ├── role-handoff.md           # 结构化 Artifact 交接
│   ├── artifact-persistence.md   # Artifact 持久化
│   ├── routing.md                # Lead 动态路由（决策树+复杂度）
│   └── reuse-decision.md         # 复用决策机制
├── templates/
│   ├── development-task.yaml / delegation-contract.yaml
│   ├── implementation-result.yaml / verification-result.yaml           # Phase 1
│   ├── requirement-result.yaml   # 需求规格
│   ├── solution-discovery-result.yaml  # 方案发现
│   ├── repository-understanding.yaml   # 仓库理解
│   ├── architecture-result.yaml       # 架构结果
│   └── implementation-plan.yaml       # 实施方案
├── .tasks/
│   └── DT-20260820-002/          # 真实验收任务（dlt-simulator 新增统计分析策略）
│       ├── development-task.yaml
│       ├── requirement-result.yaml
│       ├── solution-discovery-result.yaml
│       ├── repository-understanding.yaml
│       ├── architecture-result.yaml
│       ├── implementation-plan.yaml
│       └── handoff-log.md
└── scripts/
    ├── e2e_runner.py / e2e_target.py / verifier.py            # Phase 1
    ├── e2e_phase2.py             # Phase 2 Artifact 链 + 路由逻辑 E2E
    └── e2e_scenarios.py          # 5 个 E2E 场景
```

---

## Artifact 流转（核心）

```
Requirement Result → Solution Discovery → Repository Understanding → Architecture Result → Implementation Plan
```

每个 Artifact 是上游角色的结构化产出、下游角色的输入，含 `type/task_id/status/producer/artifacts/evidence`。

---

## Lead 动态路由（非固定流水线）

| 复杂度 | 路径 |
|:--|:--|
| 简单（typo/单文件/文档/配置/bug） | Requirement → Developer |
| 中等（多文件/新 Skill/新功能/API/数据处理） | Requirement → Repository Analyst → Architect → Developer |
| 复杂（新Agent/Team/架构/Agent OS/Runtime/DB/多系统/安全/大refactor） | Requirement → Solution Researcher → Repository Analyst → Architect → Developer |

> 复杂度是建议，最终 Lead 判断。详见 `protocols/routing.md`。

---

## 验收：真实任务跑通主链路

用一个真实任务（**DT-20260820-002：给 dlt-simulator 增加一个统计分析（遗漏回归）策略**）真实跑通
Requirement → Solution Researcher（GitHub 搜索）→ Repository Analyst → Architect → Implementation Plan 的 Artifact 流转。

- 5 个 schema 被**真实填充**（非空定义），见 `.tasks/DT-20260820-002/`。
- Solution Researcher 真实搜索 GitHub，结论 `NO_SUITABLE_EXISTING_SOLUTION` + `LEARN_AND_BUILD`（有证据，非虚构）。
- Repository Analyst 真实读了 generator.py / statistics.py / common.py / SKILL.md，产出真实现状地图。
- Architect 真实回答了七问，产出架构 + 实施方案。

完整证据见 `E2E_REPORT.md`。

---

## 安全红线

- 文件/代码/模板中**不含**真实 API key / token / 邮箱真实地址（git 用 noreply）/ 机器 hash。
- 不改主会话 OpenClaw 配置/权限/安全/AGENTS/MEMORY/SOUL。
- 不 self-edit 权限。
- 出现 `HUMAN_DECISION_REQUIRED` 不瞎猜，回报主会话。
- 不 push（Release Gate 在主会话）。
