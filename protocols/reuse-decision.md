# protocols/reuse-decision.md — Reuse Decision（复用决策机制）

> Development Workflow 的 Research 步骤 + Plan 步骤协同决定「复用 / 修改 / 新增」。
> 核心原则：**Existing Solutions Preflight**——先查现成，再决定。不再有独立 Researcher/Architect 角色。

## 1. 复用决策三问（Plan 前必须逐条回答）

1. **Agent OS 是否已有相同能力？** 有 → `REUSE_EXISTING_CAPABILITY`，禁止重复实现。
2. **现有 Skill 是否已有相同能力？** 有 → 复用/修改，禁止另起炉灶。
3. **外部开源/GitHub/官方 SDK 是否有成熟方案？** 有 → 按 reuse_level 决策（DIRECT_REUSE / ADAPT / LEARN_AND_BUILD）。

## 2. reuse_level 判定（Research 步骤产出）

| 级别 | 含义 | 触发条件 |
|:--|:--|:--|
| DIRECT_REUSE | 直接拿来用 | 功能完全匹配 + license 允许 + 维护活跃 + 可无改集成 |
| ADAPT | 改一改再用 | 核心可用但需适配（接口/平台/范围微调） |
| LEARN_AND_BUILD | 学习其思路自建 | 思路可借鉴，但不可直接复用（license/耦合/范围） |
| NOT_SUITABLE | 不适合 | 不匹配 / license 冲突 / 过时 / 安全风险 |

## 3. 复用 vs 新建的判定表（Plan 落地）

| 现状（来自 Repository Analysis） | 决策 | 理由要求 |
|:--|:--|:--|
| 已有几乎一样的模块 | **复用** | 不动，直接引用/调用 |
| 已有相近但不完全匹配 | **修改** | 说明改什么、为什么不推倒重来 |
| 完全没有 | **新建** | 说明为什么复用现有行不通（充分理由） |

## 4. 禁止项

- ❌ 已有现成能力却重复实现（违 Existing Solutions Preflight）。
- ❌ Agent OS 已有相同能力仍自建（`REUSE_EXISTING_CAPABILITY` 必须 STOP）。
- ❌ 虚构外部项目假装「找到现成」（没找到必须 NO_SUITABLE_EXISTING_SOLUTION）。
- ❌ license 冲突仍硬复用（GPL 污染 / 无 license 商用风险）。

## 5. 决策留痕

每次 reuse 决策在 Implementation Plan 的 `reuse` / `modify` / `create` 里写明 `component + reason`。
