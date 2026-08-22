# Project Delivery Standard

> **项目级 Definition of Done** — Development Team 交付的任何项目，都必须是陌生用户
> 从 GitHub 获取后能**独立理解、安装、配置、运行和验证**的完整项目。

核心原则：**代码完成 != 项目完成。**

本文档是「项目交付」的硬性验收标准，叠加在 PROTOCOL.md（任务级 DoD）之上。
Developer / Reviewer / GitHub Hygiene 强制按此执行，不能停留在文档层。

---

## 1. 项目完成的 11 项硬条件（Definition of Done）

一个项目只有**全部**满足才算完成（项目 COMPLETE）。缺任何一项 = 项目未完成 = REJECT。

| # | 条件 | 说明 |
|:--|:--|:--|
| 1 | **代码完成** | 实现全部验收标准，功能可用 |
| 2 | **测试完成** | 测试已编写并通过；无法实际运行的测试必须显式标记 `NOT RUN` |
| 3 | **README 完整** | 见 §3 README 标准 |
| 4 | **安装说明完整** | 陌生用户可独立完成安装 |
| 5 | **配置说明完整** | 所有配置项/环境变量/参数有明确说明 |
| 6 | **使用说明完整** | 用户知道怎么用、有什么功能、怎么调用 |
| 7 | **Quick Start 可执行** | 最小可运行路径，陌生用户可照做跑通 |
| 8 | **测试方法明确** | 用户/Reviewer 知道如何运行测试 |
| 9 | **GitHub Hygiene 通过** | 见 §6 GitHub Hygiene Review |
| 10 | **陌生用户可独立运行** | 仅凭 README 完成安装 + 运行（Stranger User Audit） |
| 11 | **Reviewer 实际验证通过** | 见 §7 Stranger User Audit 流程 |

---

## 2. 不要「一刀切」：按项目类型定文件清单

**不要要求所有项目拥有完全相同的文件。** 按项目类型决定需要的交付文件。

### 判断原则
- 有构建/包管理的项目 → `pyproject.toml` / `package.json` 等。
- 需要部署环境的项目 → `Dockerfile` / compose。
- OpenClaw Skill → `SKILL.md`（面向 Agent）+ `README.md`（面向用户），**两者缺一不可**。
- 所有可执行项目 → README + .gitignore + LICENSE（如适用）。

### 各类型最低清单（供 `project-readiness-check.sh` 按类型校验）

| 类型 | 必含 |
|:--|:--|
| generic | README.md, .gitignore |
| python | README.md, pyproject.toml 或 requirements.txt, .gitignore, 测试 |
| node | README.md, package.json, .gitignore, 测试 |
| openclaw-skill | README.md + SKILL.md（双文档）, _meta.json(可选), .gitignore |
| docker | README.md, Dockerfile(或 compose), .gitignore, 入口脚本 |

模板见 `templates/project/<type>/`。

---

## 3. README 标准

README 是陌生用户的第一（常常是唯一）文档，**面向用户**。至少包含（按需裁剪）：
- overview / requirements / installation / configuration / usage / examples
- testing / troubleshooting / upgrade / uninstall（如适用）

**缺任何对新用户无法推断的必要步骤 = REJECT。**

---

## 4. SKILL.md 与 README.md 分工（OpenClaw Skill 项目特殊规则）

OpenClaw Skill 项目有**两份必须同时存在**的文档：

| 文件 | 面向 | 负责内容 |
|:--|:--|:--|
| **SKILL.md** | **Agent** | when to use, execution workflow, tools, safety, agent instructions |
| **README.md** | **GitHub 用户** | overview, requirements, installation, configuration, usage, examples, testing, troubleshooting, upgrade/uninstall |

两者缺一即 REJECT，不得用一份替代另一份。

---

## 5. 强制工作流（写入 Developer / Reviewer 协议）

### Developer 流程
```
需求 → 架构 → 开发 → 测试 → 文档 → Project Readiness Check → Git commit → GitHub → 提交 Reviewer
```
- Developer **只能宣布 `IMPLEMENTATION COMPLETE`**，**不得宣布 PROJECT COMPLETE**。
- Git commit 前必须跑 `scripts/project-readiness-check.sh` 并通过。

### Reviewer 流程
```
clone 到干净临时目录 → 严格按 README 执行(安装/配置/Quick Start/运行/测试)
  → GitHub Hygiene Review → Stranger User Audit → PASS / REJECT
```
- **不允许依赖 Developer 没有写入文档的隐含知识。**
- README 缺少任何必要步骤 → 必须 **REJECT**。

---

## 6. GitHub Hygiene Review

看内容，不只是文件存在：

- [ ] README 在**根目录**
- [ ] 无临时文件（`*.tmp` / `*.log` / 调试残留）
- [ ] 无 `__pycache__` / 编译产物
- [ ] 无 `.env`（或已 gitignore；真实 secrets 不进仓库）
- [ ] 无 secrets / API keys / 令牌 / 密码（扫内容）
- [ ] 无本地绝对路径硬编码（`/home/<user>/...`、`C:\Users\...`）
- [ ] `.gitignore` 正确
- [ ] 目录结构清晰
- [ ] commit 信息清晰
- [ ] LICENSE 合适（如适用）
- [ ] CHANGELOG 合适（如适用）

---

## 7. Stranger User Audit（Reviewer 强制流程）

1. **clone 到干净临时目录**（`mktemp -d`），不使用 Developer 工作区。
2. **完全按 README 执行**：安装 → 配置 → Quick Start → 运行 → 测试。
3. **只使用文档化信息**：不从 Developer 会话/注释/私聊获取隐含知识；文档缺失任何必要步骤 → 交付缺陷。
4. **判定**：全程可复现、无文档外依赖 → PASS；否则 REJECT。

---

## 8. 与现有协议关系

- PROTOCOL.md §DoD 定义**任务级**完成；本文档定义**项目级**交付。
- 两者叠加：任务 DONE（RELEASED）+ 项目满足 11 项 → 才可宣称「项目完整交付」。

Developer 只给 `IMPLEMENTATION COMPLETE`；只有全部验证 + Reviewer Stranger User Audit PASS
后，Lead 才能对外宣布「项目完成」。

---

## 9. 红线

- **禁止伪造 PASS**：无法实际运行的测试/验证必须标 `NOT RUN` 并说明原因。伪造 PASS 是严重违规。
- **禁止修改用户项目的 `AGENTS.md` / `SOUL.md` / `MEMORY.md`**。
- **禁止只写文档不落地**：规则必须进入 Developer / Reviewer 强制工作流与 `scripts/project-readiness-check.sh`。

---

## 9a. 生成物 Protocol Compliance（P0，强制）

> 依据 Agent OS `SKILL-INTEGRATION.md` + `PROTOCOL-CHECKLIST.md` + Execution Record。
> Development Team 不新建独立 protocol-compliance Skill，复用 Agent OS 现有标准。

Development Team 产出的任何 **Skill / Agent / Project**，在 Reviewer 判定前必须经过 **Protocol Compliance**。

### 最低检查项（对齐 Agent OS PROTOCOL-CHECKLIST，不适用的必须显式标 N/A）

| # | 检查项 | 要求 | N/A 判定 |
|:--|:--|:--|:--|
| 1 | Identity | 声明身份 + `x-agent-os.layer` | 所有 |
| 2 | Context | requires 节点矩阵声明 | 简单生成物可 N/A |
| 3 | Lifecycle | 遵循 Fast/Full Path | 无任务型生成物 N/A |
| 4 | Memory/State | memory_write=governed 或显式 N/A | 无状态生成物 N/A |
| 5 | Delegation | Multi-Agent 场景声明 `delegation` | 不被子 agent 调用 N/A |
| 6 | Handoff | 结果回传路径明确 | N/A |
| 7 | Communication | 用 OpenClaw 原生 | N/A |
| 8 | Error Handling | 失败处理路径 | 内置型 N/A |
| 9 | Recovery | retry/escalate 路径 | N/A |
| 10 | Permissions | `requires.permission`（L2+ 一律 true） | 纯 L0-L1 可 N/A |
| 11 | Skill Discovery | `x-agent-os` + frontmatter name/description | 非 skill N/A |
| 12 | Installation | 可安装性 | 非 skill N/A |
| 13 | Versioning | frontmatter version / 可版本化 | N/A |
| 14 | Multi-Agent compat | delegation + provenance | 单 agent N/A |

**原则：不强制不存在的能力；不适用的标 N/A 并说明理由。**

### 判定规则（对齐 Agent OS Contract）

- 应经过但未经过 → **FAIL**
- Contract 条件性跳过且注明 → 不 FAIL
- 合法 N/A（清晰标注理由）→ 不计
- 缺少 `x-agent-os` 声明（适用场景）→ **FAIL**
- 缺少 delegation（Multi-Agent 适用场景）→ **FAIL**
- Execution Record 缺失规定节点 → **FAIL**
- **禁止自行增加 Agent OS 未定义的协议要求**（不得发明新字段/新强制项）

**Protocol Compliance：<skill|agent|project> 全被判定 FAIL → 交付物不达标，Reviewer 必须 REJECT，Release 必须 BLOCKED。**

## 10. 多 Agent 环境（OpenClaw Multi-Agent）

Development Team 默认属于 **Main Agent / Team-level capability**：

- **不默认分别复制安装到 Developer / Reviewer Agent**。Developer 与 Reviewer 都是被 `sessions_spawn` 的独立 subagent（capability=developer / reviewer），都不需要独立持有 Development Team Skill；Reviewer 是被 spawn 的只读质量闸门子代理，执行契约见 `agents/reviewer/AGENTS.md`。
- **Skill 安装位置由当前 OpenClaw 实际环境动态确定**（用 `openclaw skills check` 官方 API），**严禁硬编码** `~/.openclaw/workspace/skills` 等固定路径。

安装前必须运行 **多 Agent Installation Context Preflight**（`scripts/agent-context-check.sh`，只读、无副作用、不执行真实安装）：

1. 检测 OpenClaw 是否存在及版本
2. 识别当前 Main Agent / workspace
3. 确定 Development Team Skill 实际安装位置（shared managed 或 Main Agent workspace）
4. 验证 Main Agent 能否发现 Development Team Skill
5. 验证 Skill discovery **不依赖 Developer/Reviewer 的私有 workspace**
6. 验证调用链 Main Agent → Development Team → Developer → Reviewer
7. **不默认把 Skill 重复安装到 Developer / Reviewer**
8. **无法验证某 Agent discovery 行为 → 标记 `NOT RUN`，禁止假设 PASS**

真正的多 Agent 安装/运行验证由 **Reviewer Stranger User Audit / E2E Test** 完成，Preflight 不替代真实安装验证。
