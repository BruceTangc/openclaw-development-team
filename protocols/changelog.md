# protocols/changelog.md — CHANGELOG

> 正式版本变化时更新 CHANGELOG。CHANGELOG 是「产品状态变化」的记录，不是 commit log。

## 1. 何时更新

- 每次 **Version bump**（见 `versioning.md`）都必须同步更新 CHANGELOG。
- 非版本化的内部 commit 不写 CHANGELOG（CHANGELOG ≠ commit log）。

## 2. 格式（Keep a Changelog 风格）

```markdown
# Changelog

## [1.3.0] - 2026-08-21

### Added
- 新增 XXX 功能

### Changed
- 调整 YYY 行为

### Fixed
- 修复 ZZZ bug

### Breaking Changes
- （若 MAJOR bump，必须列出）
```

## 3. 规则

- 新版本放在最上面。
- 版本号与 `versioning.md` 决策一致。
- 内容描述「产品状态变化」，面向用户，不写内部实现细节。
- Breaking Changes 必须显式列出。

## 4. 与 Version / Release 关系

```
Version bump → CHANGELOG 更新 → （条件满足）→ GitHub Release
```

## 5. 禁止项

- ❌ 把 CHANGELOG 当 commit log 用
- ❌ bump version 但不更新 CHANGELOG
- ❌ CHANGELOG 版本号与实际版本号不一致
