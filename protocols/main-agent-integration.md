# protocols/main-agent-integration.md — Production Integration

> Main Agent 如何判断是否进入 Development Team 流程，以及如何收口结果。

## 1. 角色关系

- **Main Agent** = OpenClaw Runtime Agent，直接面对用户。
- **Development Workflow** = Main Agent 在 DEVELOPMENT_TASK 下承担的逻辑编排（不是独立 Agent）。
- **Developer** = 唯一独立执行体（`sessions_spawn`）。
- **Reviewer** = Development Workflow 内部的阶段（Main Agent 自己执行，不 spawn）。

## 2. Development Task Classification

Main Agent 收到用户消息后**自己判断**：

**DEVELOPMENT_TASK**（进入开发流程）——满足任一：
1. 需修改代码仓库（git 操作）
2. 需新增/删除代码文件
3. 需多步骤工程实施（架构+编码+测试+Review）
4. 需修复 bug / 重构
5. 用户明确要求「开发/实现/写代码/修改/添加功能/修复/重构」

**NORMAL_TASK**（Main Agent 自己处理）——满足任一：
1. 只读/解释/分析/搜索/调研
2. 一次性简单脚本（不涉及仓库）
3. 回答问题/闲聊/配置管理

> 用户提到 GitHub/代码 ≠ 自动进入开发流程。必须有真实工程实施需求。

## 3. 收口

```
DEVELOPMENT_TASK
  → 复杂度判断（SIMPLE/FEATURE/COMPLEX）
  → Development Workflow（Main Agent 自己的步骤）
  → Developer（sessions_spawn）→ Reviewer
  → Git / Version / Changelog / Release
  → development_result → Main Agent → 决定是否通知用户
```

## 4. User Message Strategy

| 阶段 | 用户看到什么 |
|:--|:--|
| 收到开发需求 | 「收到，开始开发 [任务简述]...」 |
| 开发中 | 不主动推送（仅用户询问时） |
| 需要决策 | 问题 + 方案 + 推荐 + 风险 |
| 开发完成 | development_result 摘要 |
| 开发失败 | 失败原因 + 建议 |

## 5. 结果通知原则

- 不默认把内部开发结果 announce 给用户。
- 只有 HUMAN_DECISION_REQUIRED 或最终完成结果才由 Main Agent 决定通知。
