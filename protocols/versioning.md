# protocols/versioning.md — Semantic Versioning

> Commit 与 Version 分离。Commit 是开发历史，Version 是产品状态。

## 1. 核心原则

- **Commit 是开发历史**，每次代码改动都可 commit。
- **Version 是产品状态**，只在「产品状态变化」时才 bump。
- **不能每个 commit 都自动增加版本号**。

## 2. SemVer 规则

```
MAJOR.MINOR.PATCH
```

| 段 | 何时 bump | 示例 |
|:--|:--|:--|
| PATCH | bug fix / 小修复（向后兼容） | 1.2.3 → 1.2.4 |
| MINOR | 向后兼容的新功能 | 1.2.3 → 1.3.0 |
| MAJOR | Breaking Change / 不兼容改动 | 1.2.3 → 2.0.0 |

## 3. 版本决策必须有依据

每次 bump 必须说明**为什么 bump**：

- 依据是「产品状态变化」的类型（fix / feature / breaking）。
- 不能凭空加版本、不能为「显得在推进」而 bump。

## 4. 版本号来源

- 优先读仓库现有版本（package.json / VERSION 文件 / CHANGELOG 顶部 / git tag）。
- 无版本 → 从 0.1.0 起（或按项目现状判断）。
- bump 后同步更新 CHANGELOG（见 `changelog.md`）。

## 5. 与 CHANGELOG / Release 的关系

```
Version bump → 更新 CHANGELOG → （条件满足）→ GitHub Release
```

- 先 bump version，再写 CHANGELOG，最后（若满足 Release 条件）打 tag + Release。

## 6. 禁止项

- ❌ 每个 commit 自动 bump version
- ❌ 无依据地 bump MAJOR
- ❌ bump version 但 CHANGELOG 不更新
- ❌ 版本号与 CHANGELOG 不一致
