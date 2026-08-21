# protocols/routing.md — 复杂度判断 + 三档路由

> Main Agent 判断复杂度，选择正确路径。**简单任务必须简单处理，禁止过度工程化。**

## 1. 三档任务模型

| 档位 | 特征 | 路径 | spawn |
|:--|:--|:--|:--|
| **SIMPLE** | typo / 单文件小改 / 文档 / 简单配置 / 明确小 bug | Understand → Implement → Test(必要) → Review(按需) → Commit | 0~1 |
| **FEATURE** | 多文件 / 新功能 / API 集成 / 数据处理 | Understand → Repository Analysis → Plan → Developer → Test → Reviewer → Rework → Commit → Version/Changelog | 1~2 |
| **COMPLEX** | 新架构 / 多系统 / 安全 / 大重构 / 产品方向不清 | 检查 IDEAL → Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Rework → Git → Version → Release | 1~2 + Research |

## 2. 复杂度判断规则

Main Agent 收到需求后，按「实质特征」判断，不是按字面：

- 已有几乎一样的模块 → 降级为 SIMPLE（复用即可）。
- 单文件、影响面小、无架构决策 → SIMPLE。
- 多文件、有明确功能边界、无产品方向歧义 → FEATURE。
- 涉及架构、多系统集成、安全、大重构、或「做什么」本身不清晰 → COMPLEX。

> 宁可把「看起来复杂」降级为 FEATURE 高效处理，也不要为简单任务铺完整流水线。

## 3. 各档位细节

### 3.1 SIMPLE
- Main Agent 自己 Understand → 直接改（或单个 Developer）→ 必要测试 → 按需 Review → Commit。
- **不 spawn 完整流水线**，不建 Requirement/Architect 等角色。
- 若改动极小且自信，可 Main Agent 直接实施（0 spawn）。

### 3.2 FEATURE
- Understand + Repository Analysis + Plan 都在 Main Agent 上下文内完成。
- spawn Developer 实施 → 测试 → spawn Reviewer 审查 → Rework → Commit → Version/Changelog。

### 3.3 COMPLEX
- **先检查 IDEAL**：缺 IDEAL → HUMAN_DECISION_REQUIRED。
- Repository Analysis → Research(按需) → Plan → Developer → Test → Reviewer → Rework → Git → Version → Release。

## 4. Research 按需触发

只有「是否存在现成方案」存疑时才做 Research（见 `reuse-decision.md`）。已知领域、纯内部实现 → 跳过 Research，不重复调研。

## 5. Reviewer 按风险决定

- SIMPLE：Reviewer 按需（低风险可跳过，或 Main Agent 快速自查）。
- FEATURE / COMPLEX：Reviewer 必须执行。

## 6. 分支语义（Workflow 内部）

| 分支 | 含义 | 动作 |
|:--|:--|:--|
| HUMAN_DECISION_REQUIRED | IDEAL 缺失 / 需求不清 / 重大矛盾 | 停止，回报用户 |
| REUSE_EXISTING_CAPABILITY | 已有相同能力 | STOP，记录复用结论 |
| REWORK_REQUIRED | Reviewer 抓缺陷 | 回 Developer 修复（≤最大次数） |
| FAILED | 超限失败 | 回报 Main Agent |

## 7. 禁止项

- ❌ 固定流水线（不看复杂度一律走全流程）
- ❌ 简单任务 spawn 一堆角色
- ❌ 重复 Research / 重复读 Repo
- ❌ 失败无新证据地无限重试
