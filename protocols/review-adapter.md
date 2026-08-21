# protocols/review-adapter.md — Reviewer Workflow（集成后）

> V1 最终收敛：**Reviewer 是 Development Workflow 内部的阶段，由 Main Agent 自己执行，不是独立 Agent。**
> 核心检查能力从 `openclaw-github-repository-reviewer`（基准 `20583a7`）迁移而来，
> 但 Reviewer 本身不依赖该独立项目运行。
> 迁移原则：只迁 Development Team 真正需要的能力，不复制历史垃圾。

## 1. 定位

Reviewer 与 Developer 的判断**相对独立**。不默认相信 Developer 的「tests pass」，必须自己复核关键结果。
Reviewer ≠ Fixer：只产出 findings / required_actions，修复由 Developer 完成（见 `rework-loop.md`）。

## 2. 标准流程（6 步，冻结顺序）

```
Developer
  ↓
Developer Self-Test
  ↓
Developer Result
  ↓
Reviewer Workflow（Main Agent 执行，非独立 Agent，不 spawn）
  ├─ 1. Independent Verification（强制子步骤）
  ├─ 2. Requirement / IDEAL Compliance
  ├─ 3. Code Review
  ├─ 4. Security
  ├─ 5. Repository Review
  └─ 6. Release Gate
  ↓
final_decision: APPROVED | REWORK_REQUIRED
```

## 3. 六步详解

### 3.1 Independent Verification（强制子步骤）

独立检查，不能因 Developer 报告「tests pass」就直接通过：

- 独立读 Git Diff：`bash scripts/collect-diff.sh <repo>`
- 独立读实际代码
- 独立复跑测试：`bash scripts/check-verification.sh <repo>`
- 检查边界条件
- 检查 Regression
- 必要时增加临时验证（放 /tmp，不改仓库文件）

> 原则：工具不存在 / 环境不满足 ≠ 测试失败（NOT_APPLICABLE ≠ FAILED），结合风险判断。

### 3.2 Requirement / IDEAL Compliance

- 用户需求是否满足
- IDEAL 的 `acceptance_criteria` 每条是否可验证满足
- 声明改动 = 实际改动（scope 漂移检查，见 `git-workflow.md` baseline）

### 3.3 Code Review

- 逻辑正确性
- 异常处理
- 边界条件
- 可维护性
- 不必要修改（Unrelated Changes）

### 3.4 Security

- Secrets / API Keys / 凭据扫描：`bash scripts/check-secrets.sh <repo>`
- 明显安全风险（危险命令、可疑脚本、权限越界）

### 3.5 Repository Review

- 工作树状态：`git status`
- 临时文件 / Debug 文件 / 无关文件：`bash scripts/check-hygiene.sh <repo>`
- Git 状态一致性
- 文档一致性（行为变了 → 受影响文档同步）

### 3.6 Release Gate

只有以下**全部满足**才允许进入 Version → CHANGELOG → Tag → GitHub Release：

1. Tests PASS
2. Independent Verification PASS
3. Review APPROVED
4. Repository Clean

（见 `release.md`）

## 4. 快照 / Invalidation

- 审核开始冻结快照：`bash scripts/fingerprint-tree.sh <repo>`（HEAD+index+staged+unstaged+untracked 内容 sha256）
- 审核结束校验：`bash scripts/verify-tree.sh <repo> <期望fingerprint>`
- 期间工作树变化（含 untracked 增删改）→ INVALIDATED → 重新审核，不做「应该是小修改」假设。

## 5. Review Result（输出格式）

见 `templates/review-result.yaml`。字段：

| 字段 | 含义 |
|:--|:--|
| `status` | Reviewer 执行状态（COMPLETED / INCOMPLETE / BLOCKED） |
| `independent_verification` | 是否执行独立验证子步骤（performed / code_read / git_diff_reviewed） |
| `tests_reproduced` | 独立复跑的测试（executed / passed / failed） |
| `regression_status` | NONE / MINOR / BLOCKING |
| `requirement_compliance` | 需求/IDEAL 符合性（status / unmet） |
| `code_findings` | 代码/架构 finding（severity / file / message / required_action） |
| `security_findings` | 安全 finding |
| `repository_findings` | 仓库整洁/一致性 finding |
| `release_gate` | Release Gate 四前置条件（tests_pass / independent_verification_pass / review_approved / repository_clean） |
| `final_decision` | APPROVED / REWORK_REQUIRED |
| `required_actions` | 必须修复项（REWORK_REQUIRED 时非空） |

**finding 结构**（从 RR 迁移，去 gate 化）：

```yaml
- severity: P0 | P1 | P2     # P0=安全/破坏性，P1=必须修复，P2=建议
  file: <path>
  message: "..."
  required_action: "..."
```

## 6. 路由决策

| final_decision | Main Agent 下一步 |
|:--|:--|
| APPROVED | → 进入 Git / Version / Changelog / Release |
| REWORK_REQUIRED | → Rework 循环（见 `rework-loop.md`） |

## 7. 迁移来源说明

检查能力迁移自 `openclaw-github-repository-reviewer`（基准 commit `20583a73b067245852f803d01366af6876207ea3`）：

| 能力 | 来源 | 落地 |
|:--|:--|:--|
| Secrets 扫描 | RR `scripts/check-secrets.sh` | `scripts/check-secrets.sh` |
| 卫生扫描 | RR `scripts/check-hygiene.sh` | `scripts/check-hygiene.sh` |
| 验证状态机 | RR `scripts/check-verification.sh` | `scripts/check-verification.sh` |
| 工作树指纹 / Invalidation | RR `fingerprint-tree.sh` / `verify-tree.sh` | `scripts/` 同名 |
| Diff 采集 | RR `collect-diff.sh` / `collect-state.sh` | `scripts/` 同名 |
| finding 结构 | RR `schemas/finding.json` | 并入 `templates/review-result.yaml` |
| Release Gate 语义 | RR R10 | 并入 `release.md` |

原项目 `openclaw-github-repository-reviewer` 保留不动，作为独立成熟 Reviewer 项目存在；Development Team V1 不依赖它运行。

## 8. 禁止项

- ❌ 把 Reviewer 做成独立 Agent / Runtime（Reviewer 是 Workflow 内部阶段）
- ❌ 新增 Validator Agent（独立验证是 Reviewer 子步骤，不是新角色）
- ❌ 绕过 Reviewer（必须真实执行）
- ❌ mock Reviewer / 只读文档算审核
- ❌ 仅凭 Developer 的「tests pass」直接 APPROVED（必须独立复核）
- ❌ Reviewer 自己修复代码（Reviewer ≠ Fixer）
