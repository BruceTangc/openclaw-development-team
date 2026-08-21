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

## 4. push 与 Release 的关系

- Developer 禁止 push。
- push 由 Main Agent 走 Release Gate，**需用户确认**（涉及对外操作）。

## 5. 禁止项

- ❌ 测试未过就 Release
- ❌ Reviewer 未 APPROVED 就 Release
- ❌ 仓库不干净就 Release
- ❌ 无 tag / 无 CHANGELOG 就 Release
