# OpenClaw Development Team v1.0

> Application-layer development team built on OpenClaw native sub-agents.
> Absorbs MetaGPT's core ideas (Role separation / SOP / structured handoff / artifact driven workflow / staged development) without copying MetaGPT.
> Repository Reviewer is the final quality gate — not reimplemented.

## Phases

| Phase | Scope | Status |
|:--|:--|:--|
| **Phase 1** | Result Closure (spawn → completion → yield → Lead) | ✅ Verified |
| **Phase 2** | Requirement / Solution Research / Repository Analysis / Architecture | ✅ Verified |
| **Phase 3** | Developer Execution / Validator / Reviewer Adapter / Rework Loop | ✅ Verified |
| **Phase 3.2** | Independent Audit: P0-1~P0-5 all PASS (real sub-agents, real dlt-simulator dev) | ✅ Verified |
| **Phase 4** | Production Integration: Main Agent → Development Team → Main Agent | ✅ Verified (Phase 4.1: E2E 1 normal dev PASS + E2E 2 FAIL→REWORK→PASS, 15/15 pytest, real dlt-simulator, real sub-agents, real reviewer) |

## Quick Start

```bash
# E2E tests
python3 scripts/e2e_phase3.py    # Phase 3 schema tests
python3 scripts/e2e_phase2.py    # Phase 2 artifact chain tests
python3 scripts/e2e_scenarios.py # Phase 2 routing tests
```

## Complete Flow (Phase 4 Production)

```
User: "给 dlt-simulator 增加 XXX 功能"
  → Main Agent (Task Router)
    → Development Team
      → Development Lead（= Main Agent 的开发编排角色）
        → Requirement Analyst
        → Solution Researcher
        → Repository Analyst
        → Architect
        → Developer
        → Validator
        → Repository Reviewer
      → development_result
  → Main Agent
  → User
```

## Directory Structure

```
openclaw-development-team/
├── README.md
├── AGENTS.md                     # Development Lead（= Main Agent 的开发编排角色）
├── PROTOCOL.md                   # Core protocols (§1-16, Phase 4 = §16)
├── IMPLEMENTATION_SPEC.md
├── agents/
│   ├── developer/AGENTS.md
│   ├── validator/AGENTS.md
│   ├── architect/AGENTS.md
│   ├── requirement-analyst/AGENTS.md
│   ├── solution-researcher/AGENTS.md
│   └── repository-analyst/AGENTS.md
├── protocols/
│   ├── main-agent-integration.md # Phase 4: Task Router + Development Result
│   ├── developer-execution.md
│   ├── review-adapter.md
│   ├── rework-loop.md
│   ├── verification.md
│   ├── task.md / delegation.md / result-closure.md
│   ├── artifact-persistence.md / role-handoff.md / routing.md / reuse-decision.md
├── templates/
│   ├── development-result.yaml   # Phase 4: 标准输出
│   ├── (all Phase 1-3 templates)
├── scripts/                      # E2E test scripts
└── .tasks/<task_id>/             # Persisted artifacts
```

## Definition of Done

Task = Requirement 满足 + Implementation Plan 完成 + Developer 完成 + Validator PASS + Repository Reviewer APPROVED → status = DONE

## Phase 4: Production Integration

Main Agent 通过 Task Router 判断是否调用 Development Team：
- 开发任务 → Development Team
- 研究任务 → Research
- 管理任务 → 对应 Skill
- 闲聊 → 直接回复

Development Team 最终只返回一个 `development_result`（含 status/summary/changed_files/tests/validation/review/commit/known_issues/next_action）。

Human Decision 只在必要时打扰用户。Failure Recovery 由 Lead 自主处理。

## Constraints

- No ACP / OpenHands Runtime / Codex Runtime / Claude Code Runtime
- No custom scheduler / message bus / database / agent runtime
- No modifying Agent OS Core
- No reimplementing Repository Reviewer
- No auto-push to remote (Release Gate in main session)
- Max 3 rework attempts; same root cause 2x → RETURN_TO_ARCHITECT
- HUMAN_DECISION_REQUIRED only when truly unable to auto-decide
