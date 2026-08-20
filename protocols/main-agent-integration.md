# protocols/main-agent-integration.md — Phase 4: Production Integration

> 让 OpenClaw Main Agent 真正把 Development Team 当成自己的"软件开发部门"使用。

## 定位

Phase 4 不增加新角色。只做 Main Agent → Development Team → Main Agent 的生产链路。

## Task Router（Main Agent 决策树）

Main Agent 收到用户消息后，按以下优先级路由：

| 类型 | 特征 | 路由 |
|:--|:--|:--|
| **开发任务** | 涉及代码修改/新功能/bug修复/Skill开发/新Agent | → Development Team |
| **研究任务** | 需要搜索/调研/对比/分析 | → Research（web_search / Solution Researcher） |
| **管理任务** | 日历/邮件/提醒/配置 | → 对应 Skill |
| **闲聊** | 不需要工具 | → 直接回复 |
| **其他** | 不确定 | → ASK |

## 判定条件（是否调用 Development Team）

满足以下**任一**条件 → 调用 Development Team：

1. 用户明确说"开发"/"实现"/"写代码"/"修改"/"添加功能"
2. 需要修改现有代码仓库
3. 需要创建新文件/模块/Skill
4. 需要修复 bug
5. 需要重构
6. 涉及 git 操作（commit/push/PR）

不满足 → Main Agent 自己处理。

## Task Contract（Main Agent → Development Lead）

Main Agent 交给 Development Team 的标准格式：

```yaml
type: development_task
task_id: DT-<YYYYMMDD>-<NNN>
user_request: "<用户原始需求>"
repository: "<仓库路径或 GitHub URL>"
working_directory: "<工作目录>"
constraints:
  - "<限制条件>"
priority: <low|normal|high>
acceptance_criteria:
  - "<可验证的成功条件>"
```

## Development Result（Development Lead → Main Agent）

Development Team 最终只返回一个标准结果：

```yaml
type: development_result
task_id: ""
status: <COMPLETED|FAILED|BLOCKED|HUMAN_DECISION_REQUIRED>
summary: ""
changed_files: []
created_files: []
tests:
  executed: []
  passed: []
  failed: []
validation:
  status: <PASS|FAIL>
  findings: []
review:
  status: <APPROVED|CHANGES_REQUIRED|BLOCKED>
  findings: []
commit: ""
known_issues: []
next_action: ""
```

## Human Decision（只在必要时打扰用户）

以下情况 → HUMAN_DECISION_REQUIRED：

1. 两种架构都合理但成本/风险明显不同
2. 需要扩大 Scope（超出原始需求）
3. 需要破坏兼容性
4. 需要危险操作（删除生产数据、修改权限等）
5. 连续修复失败（≥3 次）
6. 需要用户提供无法推断的信息

**其他所有情况不打扰用户。** Lead 自主处理 Developer FAIL / Validator FAIL / Reviewer FAIL。

## Failure Recovery（Lead 自主处理）

| 失败类型 | Lead 的处理 |
|:--|:--|
| TIMEOUT | 检查 subagent status → 必要时 sessions_history 诊断 → retry / takeover |
| SUBAGENT_FAILURE | 检查错误原因 → retry（≤3）→ 失败则 ESCALATE |
| VALIDATION_FAILURE | 读 findings → 判断根因 → Developer 修复或 RETURN_TO_ARCHITECT |
| REVIEW_FAILURE | 读 critical_findings → 生成 rework_instruction → Developer |
| REWORK_LIMIT | 达到 MAX_REWORK_ATTEMPTS → HUMAN_DECISION_REQUIRED |
| ARCHITECTURE_REVISION | Validator/Reviewer 发现架构问题 → RETURN_TO_ARCHITECT |

## Main Agent 集成方式

### 方式 1：通过 sessions_spawn 委派（推荐）

```
Main Agent
  → sessions_spawn(task="<Development Task>", model="xiaomi/mimo-v2.5")
  → Development Lead（子代理）自主执行全流程
  → completion 回到 Main Agent
  → Main Agent 消费 development_result
  → 回复用户
```

### 方式 2：Main Agent 直接扮演 Development Lead

如果 sessions_spawn 不可用或任务简单，Main Agent 可以直接扮演 Lead：
1. 自己执行 Requirement → Solution Research → Repository Analyst → Architect
2. sessions_spawn Developer
3. 等 completion
4. sessions_spawn Validator
5. sessions_send 调用 Reviewer
6. 返回 development_result

### 方式 3：fire-and-forget（后台任务）

对于非紧急开发任务：
```
Main Agent
  → sessions_spawn(task="...", mode="run")
  → 不等待 completion
  → 任务完成后通过 announce 推送结果给用户
```

## 用户可见消息策略

| 阶段 | 用户看到什么 |
|:--|:--|
| 收到开发需求 | "收到，开始开发 [任务简述]..." |
| 开发中（可选） | "正在 [阶段]..."（仅用户主动询问时） |
| 需要决策 | 问题 + 方案 + 推荐 + 风险 + 准确决策点 |
| 开发完成 | development_result 摘要（changed_files/tests/review/commit） |
| 开发失败 | 失败原因 + 已尝试的修复 + 建议的下一步 |

**不打扰用户**：内部阶段结果（Requirement/Architecture/Implementation）不需要主动推送。
