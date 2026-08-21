# protocols/repository-cleanliness.md — Repository Cleanliness

> 开发任务完成后，必须检查 Repository 干净，才能标记完成。

## 1. 收尾检查清单

任务完成后，执行并确认：

| # | 检查 | 命令/方法 |
|:--|:--|:--|
| 1 | working tree 状态 | `git status` |
| 2 | 无无关修改 | 对比开发前 baseline（`git-workflow.md` 第 1 步） |
| 3 | 无临时文件 | 查找 `*.tmp` / `.bak` / 调试文件 |
| 4 | 无 debug 代码 | 检查 `print` 调试 / `console.log` / 断点残留 |
| 5 | 无 secret | 检查真实 key/token/邮箱/密码 |
| 6 | 无测试垃圾 | 检查临时测试脚本是否误提交 |
| 7 | 文档同步 | 新增功能是否同步了 SKILL.md / README 等 |
| 8 | 版本一致 | version 号与 CHANGELOG 一致 |

> **自动化辅助（迁移自 RR）**：临时文件/大文件/构建产物用 `scripts/check-hygiene.sh <repo>`；secrets 用 `scripts/check-secrets.sh <repo>`。

## 2. 目标状态

- working tree clean（除本次任务预期提交外）。
- 用户原有文件未被意外改动。
- 无临时文件 / debug / secret / 测试垃圾混入。

## 3. 发现问题的处理

- 临时文件 / 测试垃圾 → 清理（trash 优先，不 rm 关键文件）。
- 无关修改 → 确认是否本次任务产生，非本次 → 不提交。
- secret → 立即移除，并提醒用户。

## 4. 禁止项

- ❌ 带着临时文件 / debug / secret commit
- ❌ 收尾不看 git status
- ❌ 把无关修改混进本次 commit
