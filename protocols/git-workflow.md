# protocols/git-workflow.md — Git 保护（V1 重点）

> Development Team 必须保护 Repository。**不破坏用户已有修改是第一原则。**

## 1. 开发前必须记录（Baseline Snapshot）

在动任何文件前，记录：

| 项 | 命令 |
|:--|:--|
| current branch | `git rev-parse --abbrev-ref HEAD` |
| current commit | `git rev-parse HEAD` |
| working tree status | `git status --porcelain` |
| existing changed files | 上面命令的未跟踪/已修改文件清单 |

这些是**回滚基线**。若开发过程中发现工作树出现计划外的变化，用这份快照判断哪些是「我造成的」、哪些是「用户原有的」。

## 2. 保护用户已有修改

- **不能覆盖用户已有未提交修改**。
- 若目标文件已被用户修改（非本次任务产生）→ 先请求 Human Decision，不强行覆盖。
- 开发结束后，`git status` 里不应出现「用户原有文件被意外改动」。

## 3. 分支 / worktree 策略

- 开发任务**优先使用 feature branch** 或 `git worktree`，避免在用户当前工作分支上直接改。
- 若无权限建分支/worktree，或任务极简单，可在当前分支直接改，但必须遵守第 1 步的 baseline 记录。

## 4. 开发完成流程

```
Developer → Test → Reviewer → Commit
```

- Commit 前确认：只包含本次任务的文件，不含临时文件/debug/secret。
- Commit message 规范：`<type>: <description> [<task_id>]`。

## 5. 禁止项（除非 Human Decision）

- ❌ force push
- ❌ `git reset --hard`（丢弃用户修改）
- ❌ `git checkout -- <file>`（覆盖用户未提交修改）
- ❌ 删除未知分支
- ❌ 覆盖用户未提交文件
- ❌ 修改 Git 历史（rebase / amend 已推送历史）

## 6. push 策略

- Developer 禁止自动 push。
- push 由 Main Agent 走 Release Gate（见 `release.md`），需用户确认。

## 7. Repository Cleanliness 收尾

见 `repository-cleanliness.md`。开发完成必须检查 git status 干净、无临时文件/debug/secret。
