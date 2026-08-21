# .tasks/ 目录说明

此目录持久化 Development Team 的所有工程 Artifact（YAML + handoff-log）。

按 `protocols/artifact-persistence.md`，每个任务的目录结构（收敛后）：

```
.tasks/<task_id>/
├── development-task.yaml
├── ideal-contract.yaml          # COMPLEX 任务
├── implementation-plan.yaml
├── implementation-result.yaml
├── review-result.yaml
├── rework-*.yaml                # 如有 rework
└── handoff-log.md
```

注意：`.tasks/` 内容脱敏（无真实 key/token/邮箱/hash）。
