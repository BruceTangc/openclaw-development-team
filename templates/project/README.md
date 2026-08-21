# templates/project — 项目交付模板

每个项目类型提供适合该类型的 README、.gitignore 和必要文件，作为 Development Team
交付陌生用户可运行的完整项目的起点。

## 类型

| 目录 | 适用 | 关键文件 |
|:--|:--|:--|
| `generic/` | 无特定语言/框架的通用项目 | README, .gitignore |
| `python/` | Python 项目 | README, .gitignore, pyproject.toml.example |
| `node/` | Node.js 项目 | README, .gitignore, package.json.example |
| `openclaw-skill/` | OpenClaw Skill 项目 | SKILL.md + README.md, .gitignore |
| `docker/` | 容器化项目 | README, .gitignore, Dockerfile.example |

> 规则：**不要要求所有项目拥有完全相同文件**。按类型选择模板，再按项目裁剪。
> 参见 `docs/PROJECT-DELIVERY-STANDARD.md`。

## 使用

将一个类型的模板复制为交付仓库骨架：

```bash
cp -r templates/project/python ~/workspace/<new-project>/
# 然后按项目填 README，删掉不需要的 example 文件
```

交付前运行 `scripts/project-readiness-check.sh <project-dir> <type>` 验证。
