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

- **Development Team 自身的权威版本源 = 根目录 `VERSION` 文件**（单文件，例如 `1.0.0`）。
- `VERSION`、`CHANGELOG` 顶部版本、git tag、GitHub Release **必须四者一致**。
- 发布前必须校验：`VERSION` 内容 == `CHANGELOG.md` 顶部 `## [x.y.z]` == 最新 git tag `vx.y.z` == GitHub Release 版本。
- 每次 **Version bump**（按 §2）同步更新 `VERSION` → `CHANGELOG` → （满足条件）git tag + Release。
- **禁止每个 commit 自动 bump**（见 §6）。
- 优先读仓库现有版本（`VERSION` / package.json / git tag）；无版本 → 从 0.1.0 起。

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
