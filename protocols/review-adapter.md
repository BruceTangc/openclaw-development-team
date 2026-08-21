# protocols/review-adapter.md — Reviewer Workflow（集成后）

> V1 最终收敛：**Reviewer 是 Development Workflow 内部的阶段，由 Main Agent 自己执行，不是独立 Agent。**
> 核心检查能力从 `openclaw-github-repository-reviewer`（基准 `20583a7`）迁移而来，
> 但 Reviewer 本身不依赖该独立项目运行。
> 迁移原则：只迁 Development Team 真正需要的能力，不复制历史垃圾。

## 0. Agent OS Protocol 继承声明（P0 Compliance）

Reviewer 是 Development Team 的质量闸门，运行在以下协议层级之上，**继承而非覆盖** Agent OS 基础协议：

```
OpenClaw Runtime
  → Agent OS
    → X Agent OS Protocol（Core Protocol v1.3 / Architecture Contract v1.6 / MA-1.1 · ccef093）
      → Development Team 开发规范（PROTOCOL.md）
        → 本 review-adapter.md（Reviewer 执行契约）
```

- **Agent Identity**：Reviewer 是 Development Workflow 内部阶段，由 Main Agent 自己执行，不 spawn 独立 Agent。
- **Delegation Chain**：Reviewer 的审查权限来自 Main Agent 委派，遵循 Agent OS Multi-Agent 委托规则；它只审查 Development Team 交付物，不继承 Main Agent 其他能力。
- **Permission Gate**：Reviewer 只读遍历交付物 + 在受控临时目录（mktemp）执行验证，归 L0/L1；任何 L2+（发布/外发/生产变更）由 `release.md` 显式 Gate，Reviewer 不在这里授权。
- **Verification Levels**：Reviewer 的独立验证遵循 Agent OS V0-V4 分级（独立复核高于 Developer 自测）。
- **Protocol Compliance**：见 §3.7。Reviewer 必须验证交付物的 `x-agent-os` 声明 + Protocol Contract + Execution Record，FAIL → REJECT（禁止仅因功能测试通过而 APPROVE）。

---

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
  ├─ 3a. OpenClaw Native Compliance（涉 OpenClaw 能力时）
  ├─ 4. Security
  ├─ 5. Repository Review（含 5a GitHub Hygiene、5b Stranger User Audit）
  ├─ 6. Release Readiness
  └─ 7. Protocol Compliance（强制子步骤，见 §3.7；FAIL → REJECT → Release BLOCKED）
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

### 3.3a OpenClaw Native Compliance（涉及 OpenClaw 能力时强制）

当任务涉及 OpenClaw 能力（Skill / Agent / Plugin / Tool / 配置 / Gateway / CLI 等）时，以下检查**强制执行**，不可跳过：

- 代码使用的 OpenClaw API / 机制是否符合当前版本官方文档
- 是否使用了已废弃 / 旧版 API
- 是否重复实现 OpenClaw 已有能力
- 是否与当前 runtime / tool policy 冲突
- Implementation Plan 的 `openclaw_version` 与实际环境是否一致
- `docs_checked` 是否覆盖了任务涉及的 OpenClaw 能力域

> 非 OpenClaw 相关任务可跳过此步（标记 `openclaw_compliance.status = not_applicable`）。

### 3.4 Security

- Secrets / API Keys / 凭据扫描：`bash scripts/check-secrets.sh <repo>`
- 明显安全风险（危险命令、可疑脚本、权限越界）

### 3.5 Repository Review

- 工作树状态：`git status`
- 临时文件 / Debug 文件 / 无关文件：`bash scripts/check-hygiene.sh <repo>`
- Git 状态一致性
- 文档一致性（行为变了 → 受影响文档同步）

### 3.5a GitHub Hygiene Review（项目交付强制）

当任务是交付一个陌生用户可获取/运行的项目（新仓库 / 对外发布 / 完整项目交付）时，必须执行。看内容，不只是文件存在：

- [ ] README 在**根目录**
- [ ] 无临时文件（`*.tmp` / `*.log` / 调试残留）
- [ ] 无 `__pycache__` / 编译产物进版本控制
- [ ] 无 `.env` / secrets / API keys / 令牌 / 密码（扫内容，`bash scripts/check-secrets.sh <repo>`）
- [ ] 无本地绝对路径硬编码（`/home/<user>/...`、`C:\Users\...`）
- [ ] `.gitignore` 正确（忽略依赖/缓存/密钥/构建产物）
- [ ] 目录结构清晰、commit 信息清晰
- [ ] LICENSE 合适（如适用）
- [ ] CHANGELOG 合适（如适用）

> 可用 `bash scripts/project-readiness-check.sh <repo> <type>` 自动辅助（工具层检查 + STRANGER AUDIT 人工项）。

### 3.5b Stranger User Audit（项目交付强制）

当任务是交付可独立运行的项目（非仅内部代码改动）时，必须把项目 **clone 到干净临时目录**（`mktemp -d`），**完全按 README 执行**：安装 → 配置 → Quick Start → 运行 → 测试。

- **不允许依赖 Developer 没有写入文档的隐含知识**（不从 Developer 会话/注释/私聊取信息）。
- 文档缺失任何必要步骤 → 必须 `REJECT`。
- 全程可复现、无文档外依赖 → 通过；否则 REJECT。

> 判定边界：无法真实 clone 的外部仓库/环境缺失 → 标记 `NOT RUN`（禁止伪造 PASS），并由 Lead 决定是否放宽或升级。

### 3.6 Release Readiness

Reviewer 只判断「当前变更是否具备进入后续 Git / Version / Release 流程的条件」，产出 `review_gate` 结论。

`review_gate` ≠ GitHub Release Gate：真正的 Release Gate（含 Version bump + CHANGELOG 更新等前置条件）只由 `release.md` 定义，Reviewer 不在这里宣称「已可 Release」。

Reviewer 就绪判断维度：

1. Tests PASS
2. Independent Verification PASS
3. Review APPROVED
4. Repository Clean
5. **Protocol Compliance PASS**（§3.7；FAIL 则 `review_gate` 必须为 BLOCK）

（GitHub Release 的完整前置条件见 `release.md`）

### 3.7 Protocol Compliance（强制子步骤，P0）

> 依据 Agent OS `SKILL-INTEGRATION.md` + `PROTOCOL-CHECKLIST.md` + Execution Record schema。
> **Development Team 不新建独立 protocol-compliance Skill**，复用 Agent OS 现有标准作为 Reviewer 强制子步。

当**交付物是 Skill / Agent / Project**（含生成物声明 `x-agent-os` 或从 Development Team 产出）时，以下检查**强制执行，不可跳过**。若任务不生成 Skill/Agent/Project（仅改既有业务代码），标记 `protocol_compliance.status = not_applicable`（合法 N/A）。

Reviewer 必须确认：

1. **是否存在 `x-agent-os` 声明**：交付物（SKILL.md/_meta.json/AGENTS.md/README）是否声明 `x-agent-os` 接入块。
2. **是否符合当前 Protocol**：`protocol_version` 是否等于 Agent OS 当前版本（v1.3）；`layer`/`path`/`entry_mode`/`requires` 是否符合 `SKILL-INTEGRATION.md` 定义，字段是否虚构。
3. **是否满足适用的 checklist**：逐项对照 Agent OS `PROTOCOL-CHECKLIST.md` 的最低检查项（Identity / Context / Lifecycle / Memory-State / Delegation / Handoff / Communication / Error Handling / Recovery / Permissions / Skill Discovery / Installation / Versioning / Multi-Agent Compatibility）。
4. **N/A 是否合理**：不适用的项须显式标 N/A 并说明理由；无理由的 N/A → 视为未满足（FAIL）。
5. **是否经过规定节点**：交付物的 Execution Record（如适用）能否证明实际经过规定节点（context/goal/permission/execution/verification）。
6. **Execution Record 能否证明实际流程**：某节点声明 completed 但无证据 → 按「未经过」处理（FAIL）；条件性跳过须带 note。

**判定规则（对齐 Agent OS Contract）：**

- 应经过但未经过 → **FAIL**
- Contract 条件性跳过且注明 → 不 FAIL
- 合法 N/A（清晰标注理由）→ 不计
- 缺少 `x-agent-os` 声明（适用场景）→ **FAIL**
- 缺少 delegation（Multi-Agent 适用场景）→ **FAIL**
- Execution Record 缺失规定节点 → **FAIL**

**Protocol Compliance FAIL → 必须 REJECT**，禁止仅因为功能测试通过而 APPROVE，Release 必须 BLOCKED。

输出进 `templates/review-result.yaml` 的 `protocol_compliance` 字段（见 §5）。

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
| `repository_findings` | 仓库整洁/一致性 finding（含 GitHub Hygiene Review 结果） |
| `stranger_user_audit` | Stranger User Audit 结果（project_delivery 时）：status(clone/install/config/quickstart/run/test 每步 PASS/REJECT/NOT_RUN) + summary |
| `readiness_check` | Project Readiness Check 结果（PASS/FAIL/NOT_RUN + defects） |
| `review_gate` | Reviewer 审查结论：当前变更是否具备进入后续 Git/Push/Release 流程（tests_pass / independent_verification_pass / review_approved / repository_clean / version_ready / changelog_ready）。⚠️ 不是真正的 GitHub Release Gate（见 `release.md`） |
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

> 项目交付场景：Stranger User Audit 或 GitHub Hygiene REJECT → 必须 `REWORK_REQUIRED`（或缺文档）让 Developer/Lead 补齐 README 等交付件。

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
