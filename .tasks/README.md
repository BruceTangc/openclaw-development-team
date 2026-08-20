# .tasks/ 目录说明

此目录持久化 Development Team 的所有工程 Artifact（YAML + handoff-log）。

按 `protocols/artifact-persistence.md`，每个任务的目录结构：

```
.tasks/<task_id>/
├── development-task.yaml
├── requirement-result.yaml
├── solution-discovery-result.yaml   # 复杂路径
├── repository-understanding.yaml    # 中/复杂路径
├── architecture-result.yaml
├── implementation-plan.yaml
└── handoff-log.md
```

Phase 2 施工期间，用一个真实任务（DT-20260820-002，「给 dlt-simulator 增加统计分析策略」）跑通主链路，Artifact 见 `.tasks/DT-20260820-002/`。

注意：`.tasks/` 内容脱敏（无真实 key/token/邮箱/hash）。
