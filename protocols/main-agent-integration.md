# protocols/main-agent-integration.md — Production Integration

> **角色定义（冻结架构）**：Development Lead 是 **Main Agent 在 DEVELOPMENT_TASK 下承担的逻辑编排角色**，
> 不是独立 sub-agent，不是独立 Runtime。Main Agent 与 Development Lead 的区别是「职责/上下文边界」，不是两个独立 Agent。

## 角色关系（Lead = Main Agent 的逻辑编排角色）

### Main Agent（你 = OpenClaw Runtime Agent）

**职责**：
1. 接收用户消息
2. **Development Task Classification**（判断是否为开发任务）
3. 如果是 DEVELOPMENT_TASK → 创建 Task Contract → 进入 Development Lead 逻辑角色
4. 以 Development Lead 身份直接 spawn 各业务角色（不 spawn 独立 Lead）
5. 收口 development_result → 向用户汇报

### Development Lead（= Main Agent 的开发编排角色）

**职责**（Main Agent 在处理 DEVELOPMENT_TASK 时承担）：
1. 创建 Task Contract 后进入编排
2. 判断复杂度 → 动态委派 Role（直接 spawn Requirement/Researcher/Repository/Architect/Developer/Validator/Reviewer）
3. 校验每一步 Result
4. 处理失败 / rework / architecture revision
5. 最终收口 development_result 并交给用户

**你直接面对用户。** 结果经 announce 链收口回 Main Agent 当前 development task context。

## Development Task Classification Gate

Main Agent 收到用户消息后，**自己执行**这个判断：

### DEVELOPMENT_TASK（进入 Development Team）

满足**任一**条件：

1. 需要修改现有代码仓库（git 操作）
2. 需要新增/删除代码文件
3. 需要新增 Skill / Agent / Feature
4. 需要多步骤工程实施（架构 + 编码 + 测试 + Review）
5. 需要修复 bug（涉及代码修改）
6. 需要重构
7. 用户明确要求"开发"/"实现"/"写代码"/"修改"/"添加功能"/"修复"/"重构"

**示例**：
- ✅ "给 dlt-simulator 增加一个号码过滤策略" → DEVELOPMENT_TASK
- ✅ "修复这个 Skill 的 bug" → DEVELOPMENT_TASK
- ✅ "给 Agent OS 增加一个 Skill" → DEVELOPMENT_TASK
- ✅ "重构这个模块" → DEVELOPMENT_TASK
- ✅ "把这个功能接入 OpenClaw" → DEVELOPMENT_TASK

### NORMAL_TASK（Main Agent 自己处理）

满足**任一**条件：

1. 只需要读取/解释/分析（不需要修改）
2. 只需要搜索/调研
3. 只需要简单脚本（一次性，不涉及仓库）
4. 只需要回答问题
5. 只需要配置/管理
6. 闲聊

**示例**：
- ❌ "帮我看看这个代码是什么意思" → NORMAL_TASK
- ❌ "看看这个 GitHub 项目" → NORMAL_TASK
- ❌ "帮我写一个简单脚本" → NORMAL_TASK
- ❌ "这个报错是什么意思" → NORMAL_TASK
- ❌ "今天天气怎么样" → NORMAL_TASK

**NORMAL_TASK 不得启动 Development Team。** 否则过度工程化。

## Task Contract（Main Agent → Development Lead）

```yaml
type: development_task
task_id: DT-<YYYYMMDD>-<NNN>
user_request: "<用户原始需求>"
repository: "<仓库路径或 GitHub URL>"
working_directory: "<工作目录>"
constraints: []
priority: normal
acceptance_criteria: []
requester_session: "<Main Agent session>"
```

## Development Result（Development Lead → Main Agent）

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

## 架构图

```
USER
  │
  ▼
┌─────────────────────────┐
│      Main Agent         │
│      (OpenClaw)         │
│                         │
│  1. 接收用户消息         │
│  2. Task Classification │  ← DEVELOPMENT_TASK or NORMAL_TASK?
│  3. 创建 Task Contract  │
│  4. 进入 Development Lead 逻辑角色（不 spawn 独立 Lead）│
│  5. 直接 spawn 各业务角色│
│  6. 收口 development_result → 向用户汇报│
└──────────┬──────────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
NORMAL_TASK   DEVELOPMENT_TASK
     │           │
     ▼           ▼
Main Agent    ┌──────────────────────────────┐
自行处理       │ Development Lead（= Main Agent│
               │  的逻辑编排角色，非独立 Agent）│
               └──────────┬───────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   Requirement        Research          Repository
    Analyst           Researcher         Analyst
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ▼
                       Architect
                          │
                          ▼
                       Developer
                          │
                          ▼
                       Validator
                          │
                          ▼
                  Repository Reviewer
                          │
                 ┌────────┴────────┐
                 ▼                 ▼
              APPROVED           FAIL
                 │                 │
                 ▼                 ▼
         development_result    Rework → Developer
                 │
                 ▼
            Main Agent
                 │
                 ▼
               USER
```

## User Message Strategy

| 阶段 | 用户看到什么 |
|:--|:--|
| 收到开发需求 | "收到，开始开发 [任务简述]..." |
| 开发中 | 不主动推送（仅用户询问时） |
| 需要决策 | 问题 + 方案 + 推荐 + 风险 |
| 开发完成 | development_result 摘要 |
| 开发失败 | 失败原因 + 建议 |
