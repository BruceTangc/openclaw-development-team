---
name: development-team
description: 软件开发专用 Workflow。当用户要求修改代码、新增/删除功能、修复 Bug、重构、修改已有仓库、多文件工程任务，或明确要求开发/实现/写代码时触发。简单问题、解释代码、普通咨询不要触发。
# x-agent-os 接入声明（遵循 Agent OS SKILL-INTEGRATION.md v1.3，不自行发明字段）
x-agent-os:
  protocol_version: "1.3"
  layer: "business"
  trigger: "user|heartbeat|cron|hook"
  path:
    fast: true
    full: true
  entry_mode: "both"
  requires:
    context: true
    goal_task_semantics: true
    task: conditional
    decision: conditional
    orchestrator: conditional
    permission: true
    verification: true
    evaluation: conditional
    writeback: conditional
    evolution: conditional
  permissions: []
  delegation:
    max_level: "L1"
    inherit_parent: false
    requires_scope: true
  outputs:
    success_condition: required
    evidence: required
  verification: "V2"
  memory_write: "governed"
  knowledge_write: "governed"
  evolution_feedback: true
  # P0-2 结构化错误处理/恢复/通信声明（替代自然语言描述；validator 只读这些字段）
  error_handling:
    declared: true
  recovery:
    declared: true
    mechanism: retry
  communication:
    parallel_runtime: false
---

# Development Team（软件开发专用 Workflow）

Development Team 是**软件开发生命周期专用 Workflow**，不是通用任务编排。触发后按复杂度走 SIMPLE / FEATURE / COMPLEX 三档路由。

## 何时触发（满足任一）

- 用户要求修改代码 / 修改已有仓库
- 新增功能 / 删除功能
- Bug 修复 / 重构
- 多文件工程任务
- 用户明确要求「开发 / 实现 / 写代码 / 落地成代码」

## 何时不触发（Main Agent 自己处理）

- 简单问题、解释代码、普通咨询、只读分析 / 调研
- 用户提到 GitHub/代码 ≠ 自动进入开发流程，必须有**真实工程实施需求**

## 触发后做什么

1. 读 Development Team 入口：`~/.openclaw/workspace/openclaw-development-team/AGENTS.md`
2. 遵循协议总纲：`~/.openclaw/workspace/openclaw-development-team/PROTOCOL.md`
3. 复杂度判断 + 三档路由见 `routing.md`

## 架构铁律（不可违反）

- **Developer 是唯一独立执行 Agent**（抽象能力 `developer`，非具体模型；默认 runtime=openclaw / model=deepseek/deepseek-v4-flash，`sessions_spawn`）
- **不 spawn Reviewer**：Reviewer 是 Workflow 内部阶段，由 Main Agent 自己执行
- **不 spawn Validator**：独立验证是 Reviewer 的强制子步骤，不是独立角色
- 其余能力（需求理解 / Repository 分析 / Research / Plan / IDEAL）都是 Development Workflow 内部步骤，不 spawn

## 边界（与 Agent OS 不互相吞并）

- **Development Team** = 软件开发生命周期专用 Workflow
- **orchestrator** = 通用任务编排；**task-manager** = 通用任务状态管理
- 软件开发任务优先走 Development Team，**不要让 orchestrator 与 DT 同时拆解/路由同一开发任务**
