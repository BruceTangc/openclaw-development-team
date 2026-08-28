# USAGE.md — 本机实际使用 Quick Start / 决策速查表（Daily Cheat Sheet）

> 面向「每天怎么用」的速查。安装/卸载见 [INSTALL.md](INSTALL.md) / [UNINSTALL.md](UNINSTALL.md)，
> 协议细节见 [PROTOCOL.md](PROTOCOL.md) 与 `protocols/`。只回答「何时进 DT、三档怎么选、
> 何时必须 Review、失败怎么恢复、常用脚本在哪」。

---

## 一、何时进入 Development Team（DT）

用户提出**开发需求**（新增/修 Bug/重构/改仓库）时进入 DT。咨询、解释代码、纯资料整理**不进 DT**。

目标不清 → `ASK`，不硬开。

## 二、三档怎么选（routing.md）

| 档位 | 典型 | 路径 | spawn Developer |
|:--|:--|:--|:--|
| **SIMPLE** | 单文件小改、typo、文档 | Understand→Implement→Test→Review(按需)→Readiness→Commit | 0~1 |
| **FEATURE** | 新功能、多文件 | Understand→Repo Analysis→Plan→Developer→Test→Reviewer→Commit→Version/Changelog | 1 |
| **COMPLEX** | 新架构、多系统、安全 | 检查 IDEAL→…→Research→Plan→Developer→Test→Reviewer→Git→Readiness→Version→Release | 1 |

- 简单任务**禁止**铺完整流水线（防止过度工程化）。
- 复杂度由 Main Agent 按 `routing.md §5.1` 判定，SIMPLE 命中触发条件才强制 Review。

## 三、何时必须 Review / 交独立 Reviewer

- 非 SIMPLE 档强制 spawn 独立 Reviewer（只读质量闸门）。
- SIMPLE 仅「命中 §5.1 强制 Review 触发条件（涉及版本/安全/对外发布等）」时才强制 Review。
- Reviewer `completed` ≠ `APPROVED`：以结构化 `review-result.yaml`（status+verification+evidence+decision.rationale）为准。

## 四、失败怎么恢复（result-closure.md / rework-loop.md）

1. **当时**：R1（同参重试 ≤3）→ R2（Main Agent 接管）→ R3（ESCALATE / HUMAN_DECISION）。
2. **事后复盘**：`scripts/recent-failures.sh <repo> [N]` — 看最近失败/退出/升级记录（含 task/阶段/evidence）。
3. **断点续跑**：`scripts/resume-task.sh <repo> <task_id>` → 恢复命令 `continue <task_id>`。
4. Rework 上限 3 次，超过 → ESCALATE/FAILED → Main Agent。

## 五、常用脚本位置

| 目的 | 命令 |
|:--|:--|
| 采集中间状态（repo/branch/head/fingerprint） | `scripts/collect-state.sh <repo>` |
| 追加运行日志 | `scripts/append-runtime-log.sh <repo> --task <id> --stage <s> [--status ..] [--elapsed ..]` |
| 失败复盘 | `scripts/recent-failures.sh <repo> [N]` |
| 成本/耗时汇总 | `scripts/cost-report.sh <repo>`（可 `DT_TIMEFRAME=24h`） |
| 断点续跑查看 | `scripts/resume-task.sh <repo> <task_id>` |
| 归档超期已关闭任务 | `scripts/archive-tasks.sh <repo> [天数]` |
| 资源门槛检查 | `scripts/resource-gate.sh <repo> status`（读 `resource-budget.yaml`） |
| 项目交付就绪检查（提交大门） | `scripts/project-readiness-check.sh` |
| 版本一致性 | `scripts/check-version-consistency.sh` / `scripts/dt-version.sh` |

## 六、关键路径

- **运行日志**：`.runtime/manifest.jsonl`（gitignore，不入库）
- **工程 Artifact**：`.tasks/<task_id>/`（YAML + handoff-log，纳入版本控制）
- **归档证据**：`.tasks.archived/<task_id>/`（archive-tasks.sh 移入）
- **资源预算**：`resource-budget.yaml`（并发/lease TTL/429 退避等）
- **默认模型**：`deepseek/deepseek-v4-flash`（可用 `$DEVELOPER_MODEL` 覆盖，见 README「模型可配置」）

## 七、红线速查（不可逾越）

- 不覆盖用户已有未提交修改；HUMAN_DECISION 后仍不凭空替用户决定。
- 不 push / 不建 PR / 不 release，除非用户明确要求。
- 产出脱敏：无真实 key/token/邮箱/hash。
- 改动前先看协议；涉及 OpenClaw 能力先查官方文档并 record `openclaw_version`。
