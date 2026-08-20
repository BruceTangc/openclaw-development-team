# protocols/routing.md — Lead 动态路由协议（决策树 + 复杂度判断）

> Development Lead 是唯一 Orchestrator，不固定流水线。本协议定义 Lead 如何根据需求特征动态路由角色。

## 1. 复杂度判断（路由建议，最终 Lead 定）

| 复杂度 | 特征（示例） | 路由路径 |
|:--|:--|:--|
| **简单** | typo / 单文件小改 / 文档 / 简单配置 / 明确 bug | Requirement Analyst → Developer |
| **中等** | 多文件 / 新 Skill / 新功能 / API 集成 / 数据处理 | Requirement Analyst → Repository Analyst → Architect → Developer |
| **复杂** | 新 Agent / 新 Team / 新架构 / Agent OS 集成 / Runtime 集成 / 数据库 / 多系统 / 安全 / 大 refactor | Requirement Analyst → Solution Researcher → Repository Analyst → Architect → Developer |

> 复杂度是**建议**，不是铁律。Lead 依据需求实质特征（如仓库已有几乎一样模块 → 降级为简单+复用）最终判断。

## 2. 决策树（核心流转）

```
收到需求
  → Requirement Analyst → requirement_result
      ├─ HUMAN_DECISION_REQUIRED → 回报主会话，等用户
      ├─ REUSE_EXISTING_CAPABILITY → STOP（记录复用结论，禁止重复实现）
      └─ 正常 → 按复杂度路由：
          ├─ 简单 → Developer
          ├─ 中等 → Repository Analyst → Architect → Developer
          └─ 复杂 → Solution Researcher → Repository Analyst → Architect → Developer
  → 每步 Result 六项校验：
      ├─ 不完整 → RETRY_ROLE
      ├─ 需求与现状冲突 → RETURN_TO_ARCHITECT
      ├─ 需求不清 → HUMAN_DECISION_REQUIRED
      └─ 完整 → 下一阶段
  → Architect 产出 implementation_plan → 校验 DoD 完整 → 交付（Phase 2 终点）
```

## 3. Result 六项校验

| # | 检查 | 不满足 → |
|:--|:--|:--|
| 1 | `task_id` 匹配 | 丢弃/纠正 |
| 2 | `status` 合法 | RETRY_ROLE |
| 3 | `required fields` 齐全（按角色 schema） | RETRY_ROLE |
| 4 | `acceptance_criteria` 满足且有证据 | RETRY_ROLE |
| 5 | `evidence` 非空可追溯 | RETRY_ROLE |
| 6 | `blocking issue`（冲突/重大未知） | 冲突 → RETURN_TO_ARCHITECT；需求不清 → HUMAN_DECISION_REQUIRED |

## 4. 分支语义

| 分支 | 含义 | Lead 动作 |
|:--|:--|:--|
| RETRY_ROLE | 同角色产出不达标 | 重新委派同角色，attempt+1（≤3），记录 failure_reason / new_strategy |
| RETURN_TO_ARCHITECT | 需求与现状/架构冲突 | 回给 Architect 重新设计，不推进 Developer |
| HUMAN_DECISION_REQUIRED | 需求不清 / 重大矛盾 / 重大未知 | 回报主会话，不瞎猜 |
| REUSE_EXISTING_CAPABILITY | Agent OS / 现有 Skill 已有相同能力 | STOP，记录复用结论，禁止重复实现 |
| 进入下一阶段 | Result 完整达标 | 委派下一角色 |

## 5. 禁止项

- ❌ 固定流水线（不看需求复杂度一律走全 5 角色）。
- ❌ Lead 亲自干满全程（专业工作必须委派对应 Role）。
- ❌ 不校验就放行到下一阶段。
- ❌ 失败无新证据地无限 RETRY（≥3 → ESCALATE）。
