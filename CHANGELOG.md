# Changelog

所有显著的「产品状态变化」都会记录在此文件。本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

> 权威版本源是根目录 `VERSION` 文件。本文件的版本号、git tag、GitHub Release 必须与 `VERSION` 一致。

## [1.0.0] - 2026-08-21

### Added
- Development Team 完整安装系统：`INSTALL.md`、`UNINSTALL.md`、`install.sh`、`uninstall.sh`（幂等、安全、只删自建内容）。
- OpenClaw Native Compliance 机制（涉及 OpenClaw 能力时强制 Reviewer 检查官方文档/弃用 API/重复能力/运行时冲突）。
- **项目交付标准（Definition of Done）**：`docs/PROJECT-DELIVERY-STANDARD.md` — 代码完成 ≠ 项目完成，11 项硬性交付条件。
- **Project Readiness Check**：`scripts/project-readiness-check.sh` — 提交大门，检查 README/安装/配置/使用/测试/.gitignore/secret/临时文件/绝对路径/目录卫生；按类型区分必要项与 NOT APPLICABLE，验证真实可执行命令。
- **项目交付模板**：`templates/project/` — generic / python / node / openclaw-skill / docker 五类 README + .gitignore + 必要文件。
- **Multi-Agent Installation Context Preflight**：`scripts/agent-context-check.sh` — 只读无副作用，验证 OpenClaw 环境、Main Agent workspace、Skill discovery 原则（Team-level shared，不复制到 Developer/Reviewer）、调用链；明确三态 PASS / WARN / NOT RUN。
- Developer 流程：只能宣布 `IMPLEMENTATION COMPLETE`，不得宣称 `PROJECT COMPLETE`；提交前必须跑 Readiness Check。
- Reviewer 流程：新增 GitHub Hygiene Review + Stranger User Audit（clone 干净目录、严格按 README 复现安装/配置/Quick Start/运行/测试、缺必要步骤 REJECT）。
- OpenClaw Skill 项目特殊规则：SKILL.md（面向 Agent）与 README.md（面向用户）必须同时存在。

### Changed
- `install.sh`：移除硬编码路径，改用 OpenClaw 官方 API 动态解析；自动运行 Preflight；Blocking FAIL / NOT RUN → `INSTALL BLOCKED`；明确 LEGACY FALLBACK 标记（不冒充动态解析成功）。
- 动态路径解析策略：OpenClaw API 成功 → 用动态路径；API 失败 → 不静默放行，标记 `NOT RUN` / `INSTALL BLOCKED` / `LEGACY FALLBACK`。

### Fixed
- 项目交付标准与 Readiness Check 一致性：必要项缺失由 WARN 提升为 FAIL（对齐「缺必要步骤 = REJECT」）。
- Preflight 调用链死锁：调用链基于 DT 仓库源文件（`--repo`）而非安装目标 workspace，避免「未装 → NOT RUN → 永远 INSTALL BLOCKED」。
