# protocols/ideal-contract.md — IDEAL Contract

> IDEAL 是**高层设计输入**，决定「做什么」。Development Team 决定「如何可靠落地」。
> COMPLEX 任务在进入 Repository Analysis 前，必须检查 IDEAL 是否齐全。

## 1. IDEAL 定义

```
I — Objective（目标）
D — （无）
E — （无）
A — （无）
L — （无）
```

> 注：IDEAL 不是逐字母缩写，是五个字段的首字母约定：

| 字段 | 全称 | 含义 |
|:--|:--|:--|
| **I** | Objective | 一句话目标 |
| **D** | (Scope/Requirements) | 范围 + 需求 |
| **E** | (Acceptance Criteria) | 可验证验收标准 |
| **A** | (Architecture) | 架构约束（技术栈/模块边界，可选） |
| **L** | (Out of Scope) | 明确排除项 |

为清晰起见，完整字段集固定如下：

```yaml
type: ideal_contract
task_id: ""
objective: ""                 # 一句话目标
scope:
  included: []
  excluded: []
requirements:
  functional: []
  non_functional: []
architecture: ""              # 架构约束（可选）
implementation_constraints: []  # 语言/库/兼容/安全硬约束
acceptance_criteria: []       # 可验证成功条件
out_of_scope: []              # 明确排除项
```

## 2. IDEAL 的来源

- 用户明确给出的高层设计 / 产品需求 → 直接作为 IDEAL。
- 用户给了需求但缺架构/验收标准 → Main Agent 归纳出 IDEAL **草案**，但重大歧义必须请求确认。
- COMPLEX 任务缺 IDEAL → `HUMAN_DECISION_REQUIRED`，停止，请求用户补 IDEAL。

## 3. 铁律

1. **Development Team 不允许擅自改变 IDEAL**。
2. IDEAL 冲突 / 歧义 / 无法安全实现 → `HUMAN_DECISION_REQUIRED`。
3. 不允许为了完成任务而偷偷改变 IDEAL（把「做不到的」改写成「做到了的」）。
4. IDEAL 的 `acceptance_criteria` 必须可验证（V2 级可观测）。
5. 每个重大架构决策若超出 IDEAL 范围 → 必须回到 IDEAL 检查或请求确认。

## 4. 与 Implementation Plan 的关系

```
IDEAL（做什么，不可擅自改）
  ↓ 由 Development Workflow 落地
Implementation Plan（怎么做，可被 Developer 执行）
```

- Implementation Plan **必须对齐** IDEAL 的 acceptance_criteria。
- Plan 不能「降级」IDEAL 的需求（例如把核心功能标记为 out of scope）。
