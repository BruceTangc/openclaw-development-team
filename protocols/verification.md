# protocols/verification.md — Minimal Validator Stub

> 最小校验：判断 Implementation Result 是否可判 PASS。Phase 2 才做完整 Validator。

## 校验项（5 项）

| # | 检查 | 判定 |
|:--|:--|:--|
| 1 | changed_files 存在 | 有非空文件清单 |
| 2 | 是否执行测试 | tests 字段有执行记录 |
| 3 | 测试是否通过 | 所有 tests.result == pass |
| 4 | acceptance_criteria 满足 | 每条 criteria 有满足证据 |
| 5 | git diff 合理 | diff 非空且与 changed_files 一致，无意外文件 |

## 输出

`verification_result`（见 `templates/verification-result.yaml`）：

```
task_id / status(PASS|FAIL|BLOCKED) / tests / acceptance_criteria / findings / evidence
```

- **PASS**：5 项全过。
- **FAIL**：任一项不过（如测试未通过、criteria 未满足）。
- **BLOCKED**：无法判定（如 diff 不可得、文件缺失导致无法检查）。

## 位置

- Phase 1：由 **Development Lead 内联执行**这一最小校验逻辑（或调用 `scripts/verifier.py`）。
- Phase 2：才独立为 Validator 角色 / 完整 Repository Reviewer。

## 铁律

- 校验结果必须给 evidence，不能只写 PASS。
- 工具成功 ≠ 任务成功：Validator 的 PASS 需要对应可观测证据。
- 不越权做完整 Reviewer（那是 Phase 2）。
