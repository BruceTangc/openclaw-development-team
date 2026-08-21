# protocols/release.md — GitHub Release Gate

> Release 是**正式产品发布**，条件严格。保守、可追溯。

## 1. Release 前置条件（全部满足才允许）

| # | 条件 |
|:--|:--|
| 1 | Test 全部 PASS |
| 2 | Reviewer APPROVED |
| 3 | Repository clean（无临时文件/debug/secret/无关修改） |
| 4 | Version 已正确 bump（见 `versioning.md`） |
| 5 | CHANGELOG 已更新（见 `changelog.md`） |

缺一不可。条件不满足 → 不 Release。

> **快照一致性（R10 语义，迁移自 RR）**：Reviewer APPROVED 时的 working_tree_fingerprint 必须等于最终 commit 的树（`scripts/verify-tree.sh <repo> <fingerprint>` 校验）；期间工作树变化（含 untracked 增删改）→ INVALIDATED → 重新审核，不做「应该是小修改」假设。

## 2. Release 流程

```
main 分支
  → 打 version tag（如 v1.3.0）
  → 创建 GitHub Release（附 CHANGELOG 内容）
```

## 3. 保守原则

- 项目没有 Release 策略 → **先建立最小策略**，再 Release。
- Release 是可逆性低的操作，涉及对外发布 → 走 Human Decision / 用户确认。

## 4. Commit ≠ Push ≠ Release（三者解耦）

三个动作是不同层级，不可混为一谈：

| 动作 | 语义 | 触发条件 |
|:--|:--|:--|
| **Commit** | 开发历史节点 | Reviewer APPROVED 后允许创建 |
| **Push** | 把已完成 commit 推到 GitHub，正常开发闭环的一部分 | Review APPROVED + Git 保护通过 + 无未授权修改被包含 → Main Agent 正常 push |
| **GitHub Release** | 正式产品版本发布 | 见 §1 前置条件全部满足，且项目要求人工确认时先请求用户确认 |

> **Push 不等于正式发布。** 不要每次 push 都让用户确认，也不要把 push 和 Release 当成同一个动作。

## 5. 禁止项

- ❌ 测试未过就 Release
- ❌ Reviewer 未 APPROVED 就 Release
- ❌ 仓库不干净就 Release
- ❌ 无 tag / 无 CHANGELOG 就 Release
