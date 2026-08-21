# Uninstall Guide — Development Team V1

Development Team V1 的卸载只删除它自己创建的内容，不会触碰你的用户文件。

---

## 卸载方式

### 方式一：交互式卸载（推荐）

```bash
bash ~/.openclaw/workspace/openclaw-development-team/uninstall.sh
```

会列出将删除的内容，要求确认后执行。

### 方式二：预览模式

```bash
bash ~/.openclaw/workspace/openclaw-development-team/uninstall.sh --dry-run
```

只显示将删除的内容，不实际删除。

### 方式三：指定 workspace

```bash
bash ~/.openclaw/workspace/openclaw-development-team/uninstall.sh --workspace /path/to/workspace
```

---

## 卸载内容

卸载器会删除以下 Development Team 创建的内容：

| 内容 | 路径 | 说明 |
|:--|:--|:--|
| 仓库主体 | `openclaw-development-team/` | AGENTS.md / PROTOCOL.md / protocols / scripts / templates / agents |
| Skill 入口 | `skills/development-team/` | SKILL.md |

---

## 安全保证

### 不会删除的内容

- ✅ 你的 `AGENTS.md`（用户 Agent 入口）
- ✅ 你的 `SOUL.md`（用户 Agent 人格）
- ✅ 你的 `MEMORY.md`（用户长期记忆）
- ✅ 你的 `USER.md` / `IDENTITY.md` / `TOOLS.md`
- ✅ 你已有的其他 `skills/` 下的 skill
- ✅ 你的 `memory/` 目录
- ✅ 你的 `HEARTBEAT.md` / `BOOT.md`
- ✅ 任何非 Development Team 创建的文件

### 安全检查

卸载器在删除前会验证：
1. `openclaw-development-team/` 确实是 Development Team 仓库（检查 AGENTS.md + PROTOCOL.md）
2. `skills/development-team/SKILL.md` 确实是 DT 的 skill（检查内容）
3. 非上述情况 → 中止卸载，防止误删

---

## 卸载后验证

```bash
# 确认已删除
ls ~/.openclaw/workspace/openclaw-development-team/
# 应输出: No such file or directory

ls ~/.openclaw/workspace/skills/development-team/
# 应输出: No such file or directory

# 确认用户文件未受影响
ls ~/.openclaw/workspace/AGENTS.md
# 应正常存在
```

---

## 重新安装

卸载后可以随时重新安装：

```bash
git clone https://github.com/BruceTangc/openclaw-development-team.git
cd openclaw-development-team
bash install.sh
```

---

## 手动卸载

如果卸载脚本不可用，手动删除：

```bash
rm -rf ~/.openclaw/workspace/openclaw-development-team/
rm -rf ~/.openclaw/workspace/skills/development-team/
```

仅此两步。Development Team 只在这两个位置创建文件。
