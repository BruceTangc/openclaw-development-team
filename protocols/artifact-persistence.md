# protocols/artifact-persistence.md — Artifact Persistence（工程 Artifact 持久化协议）

> 工程 Artifact 必须持久化到 `.tasks/<task_id>/`，不能只存在于某个 Agent 的短期上下文。用 repository filesystem，**不设计复杂数据库**。

## 1. 为什么持久化

1. **可审计**：每个阶段产出可回看、可追溯。
2. **可回滚**：某阶段出错，可回到上一份 Artifact 重来。
3. **跨 Agent 共享**：不同角色子代理互不相通（isolated context），靠落盘文件交接。
4. **抗上下文丢失**：Agent 短期上下文可能被截断/遗忘，落盘文件是唯一可靠真值源。

## 2. 目录结构

```
.tasks/<task_id>/
├── development-task.yaml           # Development Task 契约（Lead 建）
├── requirement-result.yaml         # Requirement Analyst 产出
├── solution-discovery-result.yaml  # Solution Researcher 产出（复杂路径）
├── repository-understanding.yaml   # Repository Analyst 产出（中/复杂路径）
├── architecture-result.yaml        # Architect 产出
├── implementation-plan.yaml        # Architect 最终核心产物
└── handoff-log.md                  # 交接日志（谁 → 谁 → 什么 Artifact → 时间）
```

## 3. 落盘规则

1. **task_id 稳定**：一个 task 一个目录，task_id 贯穿所有文件。
2. **写完即落盘**：每个角色产出 Artifact 后，Lead 立即写到 `.tasks/<task_id>/<artifact>.yaml`，再进入下一阶段。
3. **handoff-log.md 追加**：每次交接追加一行 `时间 | 产出者 → 消费者 | artifact 文件名 | 校验结论`。
4. **不丢中间产物**：即使某阶段失败，已落盘的 Artifact 保留（供诊断/回滚）。

## 4. handoff-log.md 格式

```markdown
## <task_id> 交接日志

| 时间 | 交接 | Artifact | Lead 校验 |
|:--|:--|:--|:--|
| 2026-08-20T19:30:00+08:00 | requirement_analyst → lead | requirement-result.yaml | PASS |
| 2026-08-20T19:32:00+08:00 | lead → repository_analyst | (委派) | — |
| ... | ... | ... | ... |
```

## 5. 边界

- 只持久化**工程 Artifact**（YAML/markdown 交接物），不持久化运行时状态/日志/临时文件。
- 不做数据库（不引入 SQLite/对象存储/消息队列）。
- `.tasks/` 纳入版本控制（随仓库 commit），保证可追溯（具体 commit/push 仍由主会话走 Release Gate）。

## 6. 安全

- `.tasks/` 内容脱敏：无真实 key/token/邮箱/hash。
- 不含机器指纹、内部路径中暴露 secrets 的部分。
