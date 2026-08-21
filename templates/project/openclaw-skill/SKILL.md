# <Skill 名称>

<!-- SKILL.md 面向 Agent：告诉 Agent 何时用、怎么跑、用什么、安全边界 -->

## Purpose

- **when to use**：什么场景触发这个 Skill；什么场景不该用。
- **what it does**：一句话描述功能与产出。

## Prerequisites

- 环境 / 依赖 / 数据前提。
- 需要的 API key / 配置如何提供。

## Workflow（execution workflow）

按顺序执行步骤：
1. ...
2. ...

## Tools & Commands

- 可用工具 / 脚本 / 命令及调用方式。

## Safety

- 数据边界：读哪些、写哪些、不允许碰哪些。
- 权限红线：哪些操作禁止自动执行。
- 副作用：外发 / 删除 / 生产变更需确认。

## Agent Instructions

- 输出的结构化格式。
- 失败处理与上报方式。
- 验证方法与完成标准（V0-V4）。

---

## Metadata（示例 frontmatter 片段，视 _meta.json 而定）

```yaml
name: <skill-name>
description: <一句话，160 字节内>
```
