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

## Quick Start

```bash
# E2E tests (all phases)
python3 scripts/e2e_phase3.py    # Phase 3: 8/8 tests
python3 scripts/e2e_phase2.py    # Phase 2: 8/8 tests
python3 scripts/e2e_scenarios.py # Phase 2 routing: 5/5 tests
```

## Complete Flow

```
User Request
  → Development Lead
    → Requirement Analyst    → requirement_result
    → Solution Researcher    → solution_discovery_result
    → Repository Analyst     → repository_understanding
    → Architect              → architecture_result + implementation_plan
  → Developer                → implementation_result
  → Validator                → verification_result
  → Repository Reviewer      → review_result
    ├─ APPROVED → DONE
    └─ CHANGES_REQUIRED → Rework → Developer → Validator → Reviewer
```

## Directory Structure

```
openclaw-development-team/
├── README.md                     # This file
├── AGENTS.md                     # Development Lead role + decision tree
├── PROTOCOL.md                   # Core protocols (Result Closure / Routing / Rework)
├── IMPLEMENTATION_SPEC.md        # Implementation specification
├── agents/
│   ├── developer/AGENTS.md       # Developer (execution layer)
│   ├── validator/AGENTS.md       # Validator (independent verification)
│   ├── architect/AGENTS.md       # Architect
│   ├── requirement-analyst/AGENTS.md
│   ├── solution-researcher/AGENTS.md
│   └── repository-analyst/AGENTS.md
├── protocols/
│   ├── task.md                   # Development Task Contract
│   ├── delegation.md             # Delegation Contract
│   ├── result-closure.md         # Result Closure (P0)
│   ├── developer-execution.md    # Developer Execution Contract
│   ├── verification.md           # Validator (full)
│   ├── review-adapter.md         # Repository Reviewer Adapter
│   ├── rework-loop.md            # Rework Loop Protocol
│   ├── artifact-persistence.md   # Artifact persistence
│   ├── role-handoff.md           # Role Handoff
│   ├── routing.md                # Dynamic routing
│   └── reuse-decision.md         # Reuse decision
├── templates/                    # YAML templates for all artifacts
├── scripts/                      # E2E test scripts
└── .tasks/<task_id>/             # Persisted artifacts per task
```

## Definition of Done

A task is DONE only when **all** of:

1. Requirement met
2. Implementation Plan completed
3. Developer completed
4. Validator PASS
5. Repository Reviewer APPROVED

## Constraints

- No ACP / OpenHands Runtime / Codex Runtime / Claude Code Runtime
- No custom scheduler / message bus / database / agent runtime
- No modifying Agent OS Core
- No reimplementing Repository Reviewer
- No auto-push to remote (Release Gate in main session)
- Max 3 rework attempts; same root cause 2x → RETURN_TO_ARCHITECT
- HUMAN_DECISION_REQUIRED only when truly unable to auto-decide
