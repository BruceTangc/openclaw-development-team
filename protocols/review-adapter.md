# protocols/review-adapter.md — Repository Reviewer Adapter

> Phase 3 新增：调用现有 Repository Reviewer，不重造，只做 invoke → consume → route。

## 定位

Repository Reviewer 是**外部质量闸门**。Development Team 只负责：
1. 准备 Review Context
2. 调用现有 Reviewer
3. 接收 Review Result
4. 解析结果
5. 路由（APPROVED → DONE / CHANGES_REQUIRED → Rework / BLOCKED → ESCALATE）

**禁止复制 Reviewer 的审核规则。**

## 调用方式

通过 OpenClaw 的 `sessions_send` 调用现有 `repository-reviewer` agent：

```
sessions_send(
  agentId: "repository-reviewer",
  message: "<Review Context>",
  timeoutSeconds: 600
)
```

## Review Context（发送给 Reviewer 的内容）

```
请对以下变更执行 10 Gate 审核（R1-R10）：

【被审仓库】
- 本地路径：<repository_path>
- 最新 commit：<commit_hash>

【变更内容】
- task_id: <task_id>
- changed_files: <file_list>
- commit message: <message>

【参考材料】
- Implementation Plan: <plan_summary>
- Verification Result: <verification_status>

请按 REVIEW-PROTOCOL.md 标准流程执行 R1-R10。给出结论：BLOCKED / CHANGES_REQUIRED / APPROVED_WITH_WARNINGS / APPROVED，附 findings。
```

## Review Result Adapter（最小适配）

Reviewer 返回的标准 Result 包含 `review_status` / `findings` / `recommendation`。我们做最小适配：

```yaml
type: review_result
task_id: <task_id>
review_status: <APPROVED|CHANGES_REQUIRED|BLOCKED|HUMAN_DECISION_REQUIRED>
findings:
  critical: []    # 必须修复
  warning: []     # 建议修复
  info: []        # 可选修复
recommendation: ""
evidence: []
reviewer_session: "<reviewer_session_key>"
review_id: "<review_id>"
```

## 路由决策

| Review Status | Lead 的下一步 |
|:--|:--|
| APPROVED | → DONE |
| APPROVED_WITH_WARNINGS | → DONE（记录 warnings） |
| CHANGES_REQUIRED | → 生成 rework_instruction → Developer |
| BLOCKED | → ESCALATE / HUMAN_DECISION_REQUIRED |
| HUMAN_DECISION_REQUIRED | → 回报用户 |

## 禁止

- ❌ 复制 Reviewer 的 10 Gate 规则
- ❌ 绕过 Reviewer（必须真实调用）
- ❌ mock Reviewer（必须真实调用现有 repository-reviewer agent）
- ❌ 自动 push（Release Gate 在主会话）
