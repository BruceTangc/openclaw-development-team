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

## 3. 分支 / worktree 策略（按档位）

| 档位 | 默认工作方式 |
|:--|:--|
| **SIMPLE** | 允许在当前工作分支直接修改（但仍必须遵守 baseline 记录 + 保护用户已有修改 + 禁止 reset/checkout 覆盖 + 禁止 force push + 禁止改未知分支历史） |
| **FEATURE / COMPLEX** | **默认 feature branch 或 `git worktree`**（优先 worktree） |

FEATURE / COMPLEX 标准流程：

```
baseline → feature branch / worktree → implementation → tests
  → Reviewer → APPROVED → commit → merge/push
```

> 若当前仓库环境不适合建 branch/worktree（如无权限、或目标仓库不允许），可降级到当前分支，但**必须明确记录降级原因**。
> 不要强制 SIMPLE 也建 branch。

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

## 6. push 策略（Push ≠ Release）

- Developer 禁止自动 push。
- push 由 Main Agent 执行，是**正常开发闭环**的一部分，不等于正式发布。
- 满足以下**全部**条件时，Main Agent 可正常 push（无需用户逐次确认）：
  1. Review 已 APPROVED
  2. Git 保护检查通过（无用户未授权修改被包含）
  3. 无临时文件/debug/secret 被纳入
- **GitHub Release 才需要谨慎**（见 `release.md`）：Release 是正式产品发布，若项目要求人工确认则在创建 Release 前请求用户确认。
- 不要把普通 push 和 Release 混为一个动作。

## 7. Repository Cleanliness 收尾

见 `repository-cleanliness.md`。开发完成必须检查 git status 干净、无临时文件/debug/secret。
