# protocols/artifact-persistence.md — Artifact Persistence

> 工程 Artifact 持久化到 `.tasks/<task_id>/`，用 repository filesystem，不设计复杂数据库。

## 1. 为什么持久化

1. 可审计：每个阶段产出可回看、可追溯。
2. 可回滚：某阶段出错，可回到上一份 Artifact 重来。
3. 跨 Agent 共享：Developer / Reviewer 互不相通（isolated context），靠落盘文件交接。
4. 抗上下文丢失：落盘文件是唯一可靠真值源。

## 2. 目录结构（收敛后）

```
.tasks/<task_id>/
├── development-task.yaml        # Development Task 契约
├── ideal-contract.yaml          # IDEAL（COMPLEX 任务）
├── implementation-plan.yaml     # Implementation Plan（Workflow 产出）
├── implementation-result.yaml   # Developer 产出
├── review-result.yaml           # Reviewer 产出
├── rework-001.yaml              # Rework 记录（如有）
└── handoff-log.md               # 交接日志
```

## 3. 落盘规则

1. task_id 稳定，贯穿所有文件。
2. 写完即落盘，再进入下一阶段。
3. handoff-log.md 追加交接记录。
4. 不丢中间产物（失败也保留，供诊断/回滚）。

## 4. handoff-log.md 格式

```markdown
## <task_id> 交接日志

| 时间 | 交接 | Artifact | 校验 |
|:--|:--|:--|:--|
| 2026-08-21T14:00:00+08:00 | workflow → developer | implementation-plan.yaml | PASS |
| ... | ... | ... | ... |
```

## 5. 边界

- 只持久化工程 Artifact（YAML/markdown 交接物），不持久化运行时状态/日志/临时文件。
- 不做数据库（不引入 SQLite/对象存储/消息队列）。
- `.tasks/` 纳入版本控制（commit/push 由 Main Agent 按 `git-workflow.md` 执行，Push ≠ Release）。

## 6. 安全

- 脱敏：无真实 key/token/邮箱/hash。
- 不含机器指纹、内部路径中暴露 secrets 的部分。
