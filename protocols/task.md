# protocols/task.md — Development Task Contract

> 每个开发目标在委派前必须固化为一个 Development Task。目标不清 → ASK，不硬开。

## 语义

Development Task 描述「要做什么、做到什么算成」，是 Delegation Contract 的输入。

## 字段（最小集）

| 字段 | 说明 |
|:--|:--|
| `task_id` | 全局唯一 id（如 `DT-20260821-001`） |
| `task_type` | SIMPLE / FEATURE / COMPLEX |
| `project` | 所属项目/仓库 |
| `goal` | 一句话目标 |
| `objective` | 可验证的达成目标 |
| `scope` | 范围（在/不在范围内） |
| `constraints` | 边界（只读/不 push/不改安全配置） |
| `acceptance_criteria` | 可验证成功条件（V2 级，可观测） |
| `requester_session` | 请求发起 session |
| `result_owner` | **Main Agent / requester session**（非最终用户） |
| `status` | NEW → DELEGATED → ... |
| `attempt` | 第几次尝试 |
| `created_at` | 创建时间戳 |

## 模板

见 `templates/development-task.yaml`。

## 硬约束

- `acceptance_criteria` 必须可验证；不可验证 → 补，不硬开。
- `result_owner` 必须是 Main Agent / requester session。
- 每个 task 有稳定 `task_id`，贯穿 Task → Delegation → Result → Review 全链路。
